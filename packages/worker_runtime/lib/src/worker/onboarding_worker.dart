import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart'
    show
        WorkerCleanupStatus,
        WorkerEventRecord,
        WorkerEventType,
        WorkerExecution,
        WorkerExecutionResult,
        WorkerExecutionStatus,
        WorkerFailureCode,
        WorkerExecutionRequest,
        WorkspaceDescriptor,
        ChangedFile,
        AgentRole,
        WorkerCleanupPolicy;
import 'package:worker_protocol/worker_protocol.dart';

import '../env/environment_policy.dart';
import '../store/worker_store.dart' show WorkerStore;
import '../workspace/git_workspace_inspector.dart';
import '../workspace/workspace_manager.dart';
import 'local_worker.dart'
    show
        WorkerBusyException,
        kDefaultWorkerAbandonStepBound,
        kDefaultWorkerDriveOverheadBound;
import 'worker.dart';

/// Thrown when onboarding preparation fails (git clone, build, test).
class OnboardingPrepareException implements Exception {
  OnboardingPrepareException(this.detail);

  final String detail;

  @override
  String toString() => 'OnboardingPrepareException: $detail';
}

/// Worker that handles Product onboarding: clones a repository at a pinned
/// revision, runs baseline build + test commands, and writes a
/// [WorkspaceDescriptor] so the platform owns the execution environment.
///
/// This worker does NOT use the agent execution driver — onboarding is a
/// deterministic platform operation (git + build + test), not an LLM-driven
/// coding task.
///
/// ## THE LEASE HAS A WHOLE-RUN BOUND (F-232)
///
/// This is the same defect F-226 closed on [LocalWorker], in the same shape.
/// There is no agent session here, but every OTHER await in the drive was
/// unbounded — the workspace prepare, every store write (events, transitions,
/// cleanup records, the terminal write), the worktree inspection and the
/// cleanup — so a wedge in any of them held `_leased` forever: the scheduler's
/// zombie sweep can orphan the durable execution row but has no path back to
/// the in-process slot, and the worker reports `busy 1/1` permanently. [run]
/// therefore bounds the drive as a whole at
/// `timeoutSeconds + workerLeaseGrace + driveOverheadBound` and, on expiry,
/// abandons the drive through [_abandonDrive]: the workspace cleanup is
/// attempted, an honest `timedOut` outcome is written where the store still
/// answers, and the lease is released by `run`'s finally regardless.
///
/// A bounded wait does not cancel the future it was waiting on, so the
/// abandoned drive keeps running detached. The drive's epoch tells it apart
/// from a later run: a stale drive cannot prepare a workspace nobody is
/// waiting for, cannot spawn the build/test commands, cannot record cleanup
/// or finish a run nobody is waiting for, and cannot clear the lease — those
/// are all owned by the run that holds the slot.
class OnboardingWorker implements Worker {
  OnboardingWorker({
    required this.workerId,
    required this.poolId,
    required Set<WorkerCapability> capabilities,
    required this.workspaceManager,
    required this.workerStore,
    this.platform,
    this.environmentPolicy = const EnvironmentPolicy(),
    this.inspector = const GitWorkspaceInspector(),
    this.gitTimeout = const Duration(minutes: 5),
    this.buildTimeout = const Duration(minutes: 10),
    this.testTimeout = const Duration(minutes: 10),
    this.workerLeaseGrace = const Duration(seconds: 60),
    this.driveOverheadBound = kDefaultWorkerDriveOverheadBound,
    this.abandonStepBound = kDefaultWorkerAbandonStepBound,
    this.eventSink,
  }) : _capabilities = capabilities;

  final String workerId;
  final String poolId;
  final Set<WorkerCapability> _capabilities;
  final String? platform;
  final WorkspaceManager workspaceManager;
  final WorkerStore workerStore;
  final EnvironmentPolicy environmentPolicy;
  final GitWorkspaceInspector inspector;
  final Duration gitTimeout;
  final Duration buildTimeout;
  final Duration testTimeout;
  final Duration workerLeaseGrace;

  /// The bound on the parts of a run that are not the request's own budget:
  /// prepare, event writes, inspection, cleanup and the terminal write. See
  /// [kDefaultWorkerDriveOverheadBound].
  final Duration driveOverheadBound;

  /// The bound applied to each step of [_abandonDrive]. See
  /// [kDefaultWorkerAbandonStepBound].
  final Duration abandonStepBound;

  /// Optional observer for normalized worker events (used by tests/audit).
  final void Function(WorkerEventRecord event)? eventSink;

  bool _leased = false;
  int _sequence = 0;

  /// The workspace the CURRENT run prepared, tracked so [_abandonDrive] can
  /// attempt its cleanup after the drive that owned it was given up on.
  /// Epoch-guarded like the lease: a drive that outlived its run must never
  /// overwrite a successor's.
  WorkspaceDescriptor? _activeDescriptor;

  /// The generation of the current [run]. A drive abandoned at the
  /// whole-run bound keeps running detached; the epoch is how it is told
  /// apart from a later run now holding the slot it used to own.
  int _driveEpoch = 0;

  /// The epoch of a drive that was explicitly abandoned. A drive is stale
  /// the moment its run is given up on — not only when a successor starts —
  /// so an abandoned drive that unwedges in the gap before the next [run]
  /// still cannot run work nobody is waiting for.
  int? _abandonedEpoch;

  bool _isStale(int epoch) => epoch != _driveEpoch || epoch == _abandonedEpoch;

  @override
  Set<WorkerCapability> get capabilities => _capabilities;

  @override
  bool get isAcquirable => !_leased;

  @override
  Future<void> acquire() async {
    if (_leased) throw WorkerBusyException(workerId);
    _leased = true;
  }

  @override
  Future<void> release() async {
    _leased = false;
    _activeDescriptor = null;
  }

  WorkerRegistration toRegistration({WorkerStatus status = WorkerStatus.idle}) {
    return WorkerRegistration(
      workerId: workerId,
      poolId: poolId,
      capabilities: {
        for (final capability in _capabilities)
          capability: CapabilitySpec(capability: capability, version: '1.0'),
      },
      status: status,
      currentLoad: _leased ? 1 : 0,
      maxConcurrency: 1,
      lastHeartbeat: DateTime.now().toUtc(),
      platform: platform,
      currentExecutionId: null,
    );
  }

  /// The ceiling on the WHOLE run: the request's own budget plus the grace
  /// the run already carries, plus the bound on everything else the drive
  /// does. Without it the lease is held by every unbounded await in the
  /// drive — a prepare, an event write, a cleanup, the terminal write —
  /// which is the F-226/F-232 starvation: the zombie sweep can orphan the
  /// durable row but has no path back to the in-process slot, so the worker
  /// reports `busy 1/1` for ever and every queued job defers `workerBusy`.
  Duration _runBound(WorkerExecutionRequest request) =>
      Duration(seconds: request.timeoutSeconds) +
      workerLeaseGrace +
      driveOverheadBound;

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    if (!_leased) await acquire();
    final epoch = ++_driveEpoch;
    try {
      return await _drive(request, epoch).timeout(_runBound(request));
    } on TimeoutException {
      return _abandonDrive(request, epoch);
    } finally {
      // The lease belongs to the CURRENT run only. A drive abandoned at the
      // bound is still unwinding detached; this guard keeps its late
      // completion — and only its late completion — from freeing a slot a
      // successor already owns.
      if (epoch == _driveEpoch) await release();
    }
  }

  /// Settles a run whose drive outlived [_runBound]: marks the drive's epoch
  /// dead so its detached continuation cannot run work or touch the slot,
  /// attempts the workspace cleanup, and writes an honest terminal outcome.
  /// Every step is bounded by [abandonStepBound] and best-effort — the
  /// abandon path exists to escape a wedge and must never wait on one, so a
  /// component that may itself be the wedge (the store, the workspace
  /// manager) is given [abandonStepBound] and no more. There is no agent
  /// session to cancel: onboarding's only spawned work is the build/test
  /// command, each of which already carries its own timeout. The lease
  /// itself is freed by [run]'s finally.
  Future<WorkerExecutionResult> _abandonDrive(
    WorkerExecutionRequest request,
    int epoch,
  ) async {
    _abandonedEpoch = epoch;
    final bound = _runBound(request);
    final failureDetail =
        'worker drive exceeded its whole-run bound of $bound and was '
        'abandoned; the wedged await continues detached but holds no lease';
    final descriptor = _activeDescriptor;

    var cleanupStatus = WorkerCleanupStatus.notApplicable;
    if (descriptor != null) {
      if (request.cleanupPolicy.preservesOnFailure) {
        cleanupStatus = WorkerCleanupStatus.preservedPerPolicy;
      } else {
        // KNOWN RACE, documented rather than solved: this cleanup runs while
        // the detached drive may still be inside an in-flight worktree
        // operation — the wedged await it was abandoned on (a command spawn,
        // an inspect) resumes to find its worktree being removed, or already
        // gone. Both directions are tolerated: the detached side's operation
        // fails or completes pointlessly and every write it could make
        // afterwards is epoch-fenced, and a removal that fails because a git
        // process still holds the directory reports the honest cleanupFailed
        // rather than wedging. What the race must never do is block — the
        // step bound is what keeps a stuck git from re-taking the lease.
        try {
          cleanupStatus = await workspaceManager
              .cleanup(descriptor)
              .timeout(abandonStepBound);
        } on Object {
          cleanupStatus = WorkerCleanupStatus.cleanupFailed;
        }
      }
    }

    try {
      return await _finish(
        WorkerExecution(
          workerExecutionId: request.workerExecutionId,
          workItemId: request.workItemId,
          repositoryPath: request.repositoryPath,
          requestedStartingRevision: request.startingRevision,
          requiredCapabilities: request.requiredCapabilities,
          status: WorkerExecutionStatus.agentExecuting,
          cleanupPolicy: request.cleanupPolicy,
          workerId: workerId,
          workspaceId: descriptor?.workspaceId,
          createdAt: DateTime.now().toUtc(),
          startedAt: DateTime.now().toUtc(),
        ),
        finalStatus: WorkerExecutionStatus.timedOut,
        cleanupStatus: cleanupStatus,
        failureCode: WorkerFailureCode.timedOut,
        failureDetail: failureDetail,
      ).timeout(abandonStepBound);
    } on Object {
      // The store itself may be the wedge — a locked connection pool is one
      // of the F-226 suspects — so the terminal write is attempted but never
      // awaited past the step bound. The result below is still the honest
      // outcome; the durable row is left for the scheduler's zombie sweep.
      return WorkerExecutionResult(
        workerExecutionId: request.workerExecutionId,
        workItemId: request.workItemId,
        status: WorkerExecutionStatus.timedOut,
        startingRevision: request.startingRevision,
        workerId: workerId,
        workspaceId: descriptor?.workspaceId ?? '',
        agentExecutionId: null,
        agentResultStatus: null,
        verificationId: null,
        verificationPassed: false,
        cleanupStatus: cleanupStatus,
        failureCode: WorkerFailureCode.timedOut,
        failureDetail: failureDetail,
        startedAt: DateTime.now().toUtc(),
        endedAt: DateTime.now().toUtc(),
      );
    }
  }

  /// The result a DETACHED drive returns when it unwedges and finds its run
  /// abandoned. Nobody awaits it — [run] already settled through
  /// [_abandonDrive] — and the epoch fences on the way here guarantee this is
  /// where the drive stops: no workspace prepare, no command spawn, no
  /// cleanup record, no terminal write.
  ///
  /// "Writes nothing" is a claim about the durable record only. A wedged
  /// await can still be holding an in-flight operation when the run is
  /// abandoned — a git invocation, a worktree touch, a spawned command —
  /// and that operation may complete when the await resumes (see the race
  /// note in [_abandonDrive]). What the fences guarantee is that nothing the
  /// detached drive does afterwards reaches the store a retry resolves.
  WorkerExecutionResult _detachedResult(WorkerExecution execution) {
    return WorkerExecutionResult(
      workerExecutionId: execution.workerExecutionId,
      workItemId: execution.workItemId,
      status: WorkerExecutionStatus.timedOut,
      startingRevision: execution.requestedStartingRevision,
      workerId: workerId,
      workspaceId: '',
      agentExecutionId: null,
      agentResultStatus: null,
      verificationId: null,
      verificationPassed: false,
      cleanupStatus: WorkerCleanupStatus.notApplicable,
      failureCode: WorkerFailureCode.timedOut,
      failureDetail:
          'the worker drive outlived its whole-run bound and was abandoned',
      startedAt: execution.startedAt ?? DateTime.now().toUtc(),
      endedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> cancel(String reason) async {
    // Onboarding worker has no agent session to cancel; the git process
    // will be killed by the timeout.
  }

  Future<WorkerExecutionResult> _drive(
    WorkerExecutionRequest request,
    int epoch,
  ) async {
    final startedAt = DateTime.now().toUtc();
    var execution = WorkerExecution(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      repositoryPath: request.repositoryPath,
      requestedStartingRevision: request.startingRevision,
      requiredCapabilities: request.requiredCapabilities,
      status: WorkerExecutionStatus.acquiring,
      cleanupPolicy: request.cleanupPolicy,
      workerId: workerId,
      createdAt: startedAt,
      startedAt: startedAt,
    );
    final acquired = await workerStore.inTransaction<bool>((tx) async {
      // If THIS transaction is where the drive wedged, the abandon path
      // already owns the run's ending by the time the body resumes: the
      // acquiring row and its event are blind upserts that would
      // resurrect a terminal record. The fence goes INSIDE the body —
      // the top of the body is the first statement to run post-resume.
      if (_isStale(epoch)) return false;
      await tx.saveWorkerExecution(execution);
      await _event(execution, WorkerEventType.workerAcquired, via: tx);
      return true;
    });
    if (!acquired) {
      return _detachedResult(execution);
    }

    WorkspaceDescriptor? descriptor;
    var cleanupStatus = WorkerCleanupStatus.notApplicable;
    var failureCode = WorkerFailureCode.none;
    String? failureDetail;
    WorkerExecutionStatus finalStatus = WorkerExecutionStatus.executedFail;
    String? endingRevision;
    List<ChangedFile> changedFiles = const [];
    String? diffSummary;

    try {
      execution = await _transition(
        execution,
        WorkerExecutionStatus.workspacePreparing,
        epoch: epoch,
      );

      // 1. Prepare workspace (clone at pinned revision via worktree)
      try {
        descriptor = await workspaceManager.prepare(
          request,
          workerId: workerId,
        );
        if (!_isStale(epoch)) _activeDescriptor = descriptor;
      } on Object catch (e) {
        if (_isStale(epoch)) {
          // Abandoned while wedged inside prepare, which then threw —
          // commonly the abandon cleanup removing the worktree under it.
          // The prepareFailed event and the terminal write below belong
          // to a run that already settled as timedOut.
          return _detachedResult(execution);
        }
        failureCode = WorkerFailureCode.prepareFailed;
        failureDetail = 'workspace prepare failed: $e';
        finalStatus = WorkerExecutionStatus.prepareFailed;
        await _event(
          execution,
          WorkerEventType.prepareFailed,
          payload: {'detail': failureDetail},
        );
        return _finish(
          execution,
          epoch: epoch,
          finalStatus: finalStatus,
          cleanupStatus: cleanupStatus,
          failureCode: failureCode,
          failureDetail: failureDetail,
        );
      }

      if (_isStale(epoch)) {
        // A drive abandoned while it was wedged inside prepare resumes
        // here: the workspaceReady event and the agentExecuting
        // transition below are fresh writes on a run the abandon path
        // already ended. Unwind the workspace it just prepared — the
        // abandon path never learned about it (the _activeDescriptor
        // guard above refused it) — and stop.
        try {
          await workspaceManager.cleanup(descriptor);
        } on Object {
          // Best-effort, exactly as in the post-transition bail below.
        }
        return _detachedResult(execution);
      }
      await _event(execution, WorkerEventType.workspaceReady);
      execution = await _transition(
        execution,
        WorkerExecutionStatus
            .agentExecuting, // reuse status for "running commands"
        epoch: epoch,
      );

      // 2. Run baseline build
      await _event(execution, WorkerEventType.executionStarted);
      try {
        await _runCommand(
          execution,
          'build',
          _extractBuildCommand(request),
          buildTimeout,
          descriptor.worktreePath,
          epoch: epoch,
        );
      } on Object catch (e) {
        if (_isStale(epoch)) {
          // Abandoned while wedged in this await: the cleanup record and
          // the terminal write below belong to the abandon path. A
          // detached drive running them would CAS-overwrite the honest
          // timedOut it already wrote.
          return _detachedResult(execution);
        }
        failureCode = WorkerFailureCode.agentFailed;
        failureDetail = 'build failed: $e';
        finalStatus = WorkerExecutionStatus.executedFail;
        cleanupStatus = await _cleanupAfterFailure(
          execution,
          request,
          descriptor,
          epoch: epoch,
        );
        return _finish(
          execution,
          epoch: epoch,
          finalStatus: finalStatus,
          cleanupStatus: cleanupStatus,
          failureCode: failureCode,
          failureDetail: failureDetail,
        );
      }
      if (_isStale(epoch)) {
        // Abandoned while wedged in the command await or its event write:
        // the test command and everything below are work nobody is
        // waiting for, on a slot a successor may already hold.
        return _detachedResult(execution);
      }

      // 3. Run baseline tests
      try {
        await _runCommand(
          execution,
          'test',
          _extractTestCommand(request),
          testTimeout,
          descriptor.worktreePath,
          epoch: epoch,
        );
      } on Object catch (e) {
        if (_isStale(epoch)) {
          return _detachedResult(execution);
        }
        failureCode = WorkerFailureCode.agentFailed;
        failureDetail = 'test failed: $e';
        finalStatus = WorkerExecutionStatus.executedFail;
        cleanupStatus = await _cleanupAfterFailure(
          execution,
          request,
          descriptor,
          epoch: epoch,
        );
        return _finish(
          execution,
          epoch: epoch,
          finalStatus: finalStatus,
          cleanupStatus: cleanupStatus,
          failureCode: failureCode,
          failureDetail: failureDetail,
        );
      }
      if (_isStale(epoch)) {
        return _detachedResult(execution);
      }

      // 4. Inspect git state (platform's own evidence)
      final inspection = await inspector.inspect(
        descriptor.worktreePath,
        startingRevision: descriptor.startingRevision,
      );
      endingRevision = inspection.revision;
      changedFiles = inspection.changedFiles;
      diffSummary = inspection.diffSummary;
      if (_isStale(epoch)) {
        // Abandoned while wedged in the inspection: the workspaceReady
        // event, the cleanup record and the terminal write below are
        // fresh writes on a run that already settled.
        return _detachedResult(execution);
      }

      // 5. Success — the workspace is ready and verified
      finalStatus = WorkerExecutionStatus.executedPass;
      await _event(execution, WorkerEventType.workspaceReady);
    } on Object catch (e) {
      if (_isStale(epoch)) {
        // Abandoned while wedged in an await that then threw — commonly
        // the worktree disappearing under an in-flight command or inspect
        // because the abandon cleanup raced it (see _abandonDrive).
        // Emitting an executionFailed event or a cleanup record now would
        // decorate a run that already settled honestly as timedOut.
        return _detachedResult(execution);
      }
      failureCode = failureCode == WorkerFailureCode.none
          ? WorkerFailureCode.agentFailed
          : failureCode;
      failureDetail ??= e.toString();
      finalStatus = WorkerExecutionStatus.executedFail;
      await _event(
        execution,
        WorkerEventType.executionFailed,
        payload: {'detail': e.toString()},
      );
    }

    // Last checkpoint before the writes a detached drive must never reach:
    // the cleanup RECORD (_setCleanup inside _finalCleanup) and the terminal
    // write. A drive abandoned while it was wedged in an event write above
    // resumes here; the abandon path already owns this run's ending,
    // including its workspace cleanup.
    if (_isStale(epoch)) {
      return _detachedResult(execution);
    }
    cleanupStatus = await _finalCleanup(
      execution,
      request,
      descriptor,
      finalStatus: finalStatus,
      epoch: epoch,
    );
    return _finish(
      execution,
      epoch: epoch,
      finalStatus: finalStatus,
      cleanupStatus: cleanupStatus,
      failureCode: failureCode,
      failureDetail: failureDetail,
      endingRevision: endingRevision,
      changedFiles: changedFiles,
      diffSummary: diffSummary,
    );
  }

  List<String> _extractBuildCommand(WorkerExecutionRequest request) {
    final config = request.runtimeConfig;
    if (config != null) {
      final buildCmd = config['buildCommand'];
      if (buildCmd != null) {
        // Try to parse as JSON list, fall back to space-split string
        try {
          final decoded = json.decode(buildCmd);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
        return buildCmd.split(' ');
      }
    }
    // Default: assume Dart/Flutter project
    return ['dart', 'pub', 'get'];
  }

  List<String> _extractTestCommand(WorkerExecutionRequest request) {
    final config = request.runtimeConfig;
    if (config != null) {
      final testCmd = config['testCommand'];
      if (testCmd != null) {
        try {
          final decoded = json.decode(testCmd);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
        return testCmd.split(' ');
      }
    }
    // Default: assume Dart/Flutter project
    return ['dart', 'test'];
  }

  Future<void> _runCommand(
    WorkerExecution execution,
    String phase,
    List<String> command,
    Duration timeout,
    String workingDirectory, {
    int? epoch,
  }) async {
    await _event(
      execution,
      WorkerEventType.executionStarted,
      payload: {'phase': phase, 'command': command.join(' ')},
    );
    if (epoch != null && _isStale(epoch)) {
      // Abandoned while wedged in the event write: spawning the command
      // now would run real work nobody is waiting for, on a slot a
      // successor may already hold. The caller's post-await fence turns
      // this early return into the detached result.
      return;
    }

    final result =
        await Process.run(
          command.first,
          command.skip(1).toList(),
          workingDirectory: workingDirectory,
          environment: environmentPolicy.resolve(
            WorkerExecutionRequest(
              workerExecutionId: execution.workerExecutionId,
              workItemId: execution.workItemId,
              repositoryPath: execution.repositoryPath,
              startingRevision: execution.requestedStartingRevision,
              requiredCapabilities: execution.requiredCapabilities,
              role: AgentRole.implementer,
              instruction: '',
              timeoutSeconds: timeout.inSeconds,
              runtimeTypeId: 'onboarding',
              cleanupPolicy: WorkerCleanupPolicy.removeAlways,
            ),
            hostEnv: Platform.environment,
          ),
        ).timeout(
          timeout,
          onTimeout: () {
            throw OnboardingPrepareException(
              '$phase command timed out after $timeout',
            );
          },
        );

    if (result.exitCode != 0) {
      throw OnboardingPrepareException(
        '$phase exited ${result.exitCode}: ${result.stderr}',
      );
    }
  }

  Future<WorkerCleanupStatus> _finalCleanup(
    WorkerExecution execution,
    WorkerExecutionRequest request,
    WorkspaceDescriptor? descriptor, {
    WorkerExecutionStatus finalStatus = WorkerExecutionStatus.executedFail,
    int? epoch,
  }) async {
    if (descriptor == null) return WorkerCleanupStatus.notApplicable;
    if (request.cleanupPolicy.preservesOnFailure &&
        finalStatus != WorkerExecutionStatus.executedPass) {
      await _setCleanup(
        execution,
        WorkerCleanupStatus.preservedPerPolicy,
        epoch: epoch,
      );
      return WorkerCleanupStatus.preservedPerPolicy;
    }
    final status = await workspaceManager.cleanup(descriptor);
    // A drive abandoned while it was wedged inside the cleanup await
    // resumes here; the epoch-fenced record write is what keeps its
    // blind upsert from resurrecting the abandon path's terminal row.
    await _setCleanup(execution, status, epoch: epoch);
    return status;
  }

  Future<WorkerCleanupStatus> _cleanupAfterFailure(
    WorkerExecution execution,
    WorkerExecutionRequest request,
    WorkspaceDescriptor descriptor, {
    int? epoch,
  }) async {
    if (request.cleanupPolicy.preservesOnFailure) {
      await _setCleanup(
        execution,
        WorkerCleanupStatus.preservedPerPolicy,
        epoch: epoch,
      );
      return WorkerCleanupStatus.preservedPerPolicy;
    }
    final status = await workspaceManager.cleanup(descriptor);
    await _setCleanup(execution, status, epoch: epoch);
    return status;
  }

  Future<WorkerExecutionResult> _finish(
    WorkerExecution execution, {
    int? epoch,
    required WorkerExecutionStatus finalStatus,
    required WorkerCleanupStatus cleanupStatus,
    required WorkerFailureCode failureCode,
    String? failureDetail,
    String? endingRevision,
    List<ChangedFile> changedFiles = const [],
    String? diffSummary,
  }) async {
    // Epoch fence: a drive that outlived the whole-run bound keeps running
    // detached, and a wedged await can resume all the way down here. The
    // abandon path already wrote this run's honest terminal, so a stale
    // drive writing now would CAS-overwrite timedOut with a competing
    // status, overwrite the saved result, and append terminal events. The
    // abandon path itself passes no epoch — it IS the legitimate writer.
    if (epoch != null && _isStale(epoch)) {
      return _detachedResult(execution);
    }
    // Re-read the canonical record so the terminal write's CAS compares
    // against the last persisted intermediate version.
    final current =
        await workerStore.readWorkerExecution(execution.workerExecutionId) ??
        execution;
    // Second fence, between the re-read and the transaction: a drive
    // abandoned while it was wedged in the read resumes here, and a CAS
    // built on the pre-abandon version would land terminal + result +
    // event over the abandon path's row.
    if (epoch != null && _isStale(epoch)) {
      return _detachedResult(execution);
    }
    final terminal = current.copyWith(
      status: finalStatus,
      workspaceId: current.workspaceId ?? '',
      endingRevision: endingRevision,
      cleanupStatus: cleanupStatus,
      failureCode: failureCode,
      reason: failureDetail,
      endedAt: DateTime.now().toUtc(),
      version: current.version + 1,
    );
    late final WorkerExecutionResult result;

    final committed = await workerStore.inTransaction<bool>((tx) async {
      // Last fence INSIDE the transaction machinery: a drive abandoned
      // while it was wedged waiting on the transaction resumes at the
      // top of this body, before any write. The residual window —
      // abandonment between the individual writes below — is what
      // [WorkerStore.saveWorkerExecution]'s expectedVersion CAS covers
      // where the store enforces it; it cannot shrink further from here.
      if (epoch != null && _isStale(epoch)) return false;
      await tx.saveWorkerExecution(terminal, expectedVersion: current.version);

      result = WorkerExecutionResult(
        workerExecutionId: terminal.workerExecutionId,
        workItemId: terminal.workItemId,
        status: finalStatus,
        startingRevision: terminal.requestedStartingRevision,
        endingRevision: endingRevision,
        workerId: workerId,
        workspaceId: terminal.workspaceId ?? '',
        agentExecutionId: null,
        agentResultStatus: null,
        verificationId: null,
        verificationPassed: finalStatus == WorkerExecutionStatus.executedPass,
        changedFiles: changedFiles,
        diffSummary: diffSummary,
        cleanupStatus: cleanupStatus,
        failureCode: failureCode,
        failureDetail: failureDetail,
        startedAt: terminal.startedAt ?? DateTime.now().toUtc(),
        endedAt: terminal.endedAt ?? DateTime.now().toUtc(),
      );
      await tx.saveResult(result);

      await _event(
        terminal,
        cleanupStatus == WorkerCleanupStatus.cleanupFailed
            ? WorkerEventType.cleanupFailed
            : finalStatus == WorkerExecutionStatus.executedPass
            ? WorkerEventType.workspaceCleaned
            : WorkerEventType.workerReleased,
        payload: {'status': finalStatus.name},
        via: tx,
      );
      return true;
    });
    if (!committed) {
      return _detachedResult(execution);
    }
    // The lease is deliberately NOT cleared here. `_leased` belongs to the
    // run, and `run`'s finally is the only place that releases it: a drive
    // that was abandoned at the whole-run bound is turned back by the epoch
    // fence above, but even without it, letting a late continuation clear
    // the slot would free a lease a successor run already holds — the same
    // starvation bug, one level down.
    return result;
  }

  Future<WorkerExecution> _transition(
    WorkerExecution execution,
    WorkerExecutionStatus status, {
    int? epoch,
  }) async {
    // Epoch fence, same contract as [_finish]: callers pass the drive's
    // epoch, and a detached drive resumed from a wedge must not
    // blind-upsert a stale status over the abandon path's terminal row.
    // Null epoch means the caller IS the legitimate writer.
    if (epoch != null && _isStale(epoch)) return execution;
    final next = execution.copyWith(
      status: status,
      version: execution.version + 1,
    );
    await workerStore.saveWorkerExecution(next);
    return next;
  }

  Future<void> _setCleanup(
    WorkerExecution execution,
    WorkerCleanupStatus status, {
    int? epoch,
  }) async {
    // Epoch fence, same contract as [_transition]: without it a detached
    // drive resumed from a wedge inside workspaceManager.cleanup would
    // blind-upsert this record over the abandon path's terminal row —
    // resurrecting timedOut back to a live status with endedAt cleared.
    if (epoch != null && _isStale(epoch)) return;
    final next = execution.copyWith(
      cleanupStatus: status,
      version: execution.version + 1,
    );
    await workerStore.saveWorkerExecution(next);
  }

  Future<void> _event(
    WorkerExecution execution,
    WorkerEventType type, {
    Map<String, dynamic>? payload,
    WorkerStore? via,
  }) async {
    final store = via ?? workerStore;
    final record = WorkerEventRecord(
      eventId: 'we-${execution.workerExecutionId}-${_sequence++}',
      workerExecutionId: execution.workerExecutionId,
      workItemId: execution.workItemId,
      sequence: _sequence,
      type: type,
      occurredAt: DateTime.now().toUtc(),
      payload: payload,
    );
    await store.appendEvent(record);
    eventSink?.call(record);
  }
}

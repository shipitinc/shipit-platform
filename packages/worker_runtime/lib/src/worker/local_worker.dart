import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';

import '../env/environment_policy.dart';
import '../execution/agent_execution_driver.dart';
import '../execution/provider_failure.dart';
import '../store/store_contention.dart';
import '../store/worker_store.dart';
import '../store/worker_registration_store.dart';
import '../workspace/artifact_committer.dart';
import '../workspace/git_workspace_inspector.dart';
import '../workspace/workspace_manager.dart';
import 'worker.dart';

/// Thrown when an execution tries to claim a slot that is already held.
class WorkerBusyException implements Exception {
  const WorkerBusyException(this.workerId);

  final String workerId;

  @override
  String toString() => 'Worker is busy: $workerId';
}

/// How often a worker refreshes its durable registration row.
///
/// Deliberately much shorter than [kDefaultWorkerRegistrationStaleAfter]: the
/// cadence is a LIVENESS signal, and the staleness bound is how long a reader
/// waits before concluding something has gone wrong. A bound that is close to
/// the cadence would report a healthy fleet as stale every time the database
/// hiccuped for one period.
const Duration kDefaultWorkerHeartbeatInterval = Duration(seconds: 15);

/// The age past which a durable registration row stops being a live statement
/// about a worker.
///
/// A worker that dies cannot mark itself gone — the process that would do the
/// writing died with it — so "is this row still true?" is a question only a
/// reader with a clock can answer, and it is answered here, once, for the whole
/// table. This is deliberately NOT exported as a getter on `WorkerRegistration`
/// in `worker_protocol`: that package defines the vocabulary this reuses, and
/// the reader that would consult such a getter is not in it.
const Duration kDefaultWorkerRegistrationStaleAfter = Duration(minutes: 2);

/// The ceiling on one registration write.
///
/// A registration row is a liveness signal, not a transaction anyone waits on.
/// Without a bound, one wedged database write would leave the heartbeat's
/// single-flight guard latched forever — no further heartbeat, and a `stop()`
/// that could never return.
const Duration kDefaultWorkerRegistrationWriteTimeout = Duration(seconds: 10);

/// The bound on everything one run does OUTSIDE the agent session's own
/// budget: workspace prepare, event writes, inspection, verification reads,
/// the artifact commit, cleanup and the terminal write. Each of those is
/// already bounded where the platform controls it — every git invocation
/// carries its own timeout — so this is the ceiling on their SUM, sized
/// above the worst case the inner bounds permit. A drive that outlives it is
/// wedged rather than slow, and the lease must not be held for it.
const Duration kDefaultWorkerDriveOverheadBound = Duration(minutes: 15);

/// The bound on each best-effort step of the abandon path — the agent
/// cancel, the workspace cleanup and the terminal write. The abandon path
/// exists to escape a wedge; a step that may itself BE the wedged component
/// is never awaited past this.
const Duration kDefaultWorkerAbandonStepBound = Duration(seconds: 30);

DateTime _utcNow() => DateTime.now().toUtc();

/// Default [Worker]: one durable execution per acquisition, isolated in a
/// platform-owned git worktree, driven through a provider-neutral
/// [AgentExecutionDriver], with the [EnvironmentPolicy] applied to the runtime
/// process. The worker captures the git-observed diff + ending revision before
/// applying the request's cleanup policy.
///
/// ## THE DURABLE REGISTRATION IS OPTIONAL HERE, AND THAT IS A DELIBERATE GAP
///
/// [registrationStore] is nullable, so a worker constructed without one behaves
/// exactly as it always did: it runs executions and registers nothing anywhere.
/// That is the honest default for a unit test and a mis-wiring hazard in
/// production, which is why [WorkerRegistrationHeartbeat.start] REFUSES a fleet
/// containing such a worker instead of quietly skipping it — a skipped worker
/// is the exact defect this class exists to close, and a silent skip would
/// reintroduce it wearing a green build.
///
/// ## THE LEASE HAS A WHOLE-RUN BOUND (F-226)
///
/// The `execute` await inside the drive has always been bounded at
/// `timeoutSeconds + workerLeaseGrace`, but every OTHER await in the drive
/// was not — event writes, inspection, verification reads, cleanup and the
/// terminal write — so a wedge in any of them held `_leased` forever: the
/// scheduler's zombie sweep can orphan the durable execution row but has no
/// path back to the in-process slot, and the worker reports `busy 1/1`
/// permanently. [run] therefore bounds the drive as a whole at
/// `timeoutSeconds + workerLeaseGrace + driveOverheadBound` and, on expiry,
/// abandons the drive through [_abandonDrive]: the hung agent session is
/// cancelled, the workspace cleanup is attempted, an honest `timedOut`
/// outcome is written where the store still answers, and the lease is
/// released by `run`'s finally regardless.
///
/// A bounded wait does not cancel the future it was waiting on, so the
/// abandoned drive keeps running detached. The drive's epoch tells it apart
/// from a later run: a stale drive cannot set the slot's active session or
/// workspace, cannot start a session nobody is waiting for, cannot inspect,
/// commit, clean up after or finish a run nobody is waiting for, and cannot
/// clear the lease — those are all owned by the run that holds the slot.
/// Without the post-checkpoint fences a resumed drive would CAS-overwrite
/// the abandon path's `timedOut` terminal with a competing status and
/// `checkout -B` force-move the artifact branch onto an abandoned run's
/// output.
class LocalWorker implements Worker {
  LocalWorker({
    required this.workerId,
    required this.poolId,
    required Set<WorkerCapability> capabilities,
    required this.workspaceManager,
    required this.executionDriver,
    required this.workerStore,
    this.registrationStore,
    this.heartbeatWriteTimeout = kDefaultWorkerRegistrationWriteTimeout,
    this.platform,
    this.environmentPolicy = const EnvironmentPolicy(),
    this.inspector = const GitWorkspaceInspector(),
    this.artifactCommitter = const ArtifactCommitter(),
    this.workerLeaseGrace = const Duration(seconds: 60),
    this.driveOverheadBound = kDefaultWorkerDriveOverheadBound,
    this.abandonStepBound = kDefaultWorkerAbandonStepBound,
    this.eventSink,
    DateTime Function()? clock,
  }) : _capabilities = capabilities,
       clock = clock ?? _utcNow;

  final String workerId;
  final String poolId;
  final Set<WorkerCapability> _capabilities;
  final String? platform;
  final WorkspaceManager workspaceManager;
  final AgentExecutionDriver executionDriver;
  final WorkerStore workerStore;
  final EnvironmentPolicy environmentPolicy;
  final GitWorkspaceInspector inspector;

  /// Where this worker's registration row is written, so an operator surface
  /// reading the durable table sees this worker rather than an empty fleet.
  /// Null means "this worker is not registered anywhere", which is what every
  /// pre-existing construction site means.
  final WorkerRegistrationStore? registrationStore;

  /// The ceiling on one registration write. See
  /// [kDefaultWorkerRegistrationWriteTimeout].
  final Duration heartbeatWriteTimeout;

  /// This worker's clock. Defaults to the system clock in UTC; a test injects
  /// one so that heartbeat ages are exact rather than raced.
  final DateTime Function() clock;

  /// Makes a non-reviewer execution's produced artifact durable (a branch + a
  /// commit) before cleanup removes the worktree. Injecting it keeps the
  /// worker's handoff testable without shelling out.
  final ArtifactCommitter artifactCommitter;
  final Duration workerLeaseGrace;

  /// The bound on the parts of a run that are not the agent session itself:
  /// prepare, event writes, inspection, verification reads, the artifact
  /// commit, cleanup and the terminal write. See
  /// [kDefaultWorkerDriveOverheadBound].
  final Duration driveOverheadBound;

  /// The bound applied to each step of [_abandonDrive]. See
  /// [kDefaultWorkerAbandonStepBound].
  final Duration abandonStepBound;

  /// Optional observer for normalized worker events (used by tests/audit).
  final void Function(WorkerEventRecord event)? eventSink;

  bool _leased = false;
  int _sequence = 0;
  String? _activeAgentExecutionId;

  /// The workspace the CURRENT run prepared, tracked so [_abandonDrive] can
  /// attempt its cleanup after the drive that owned it was given up on.
  /// Epoch-guarded like [_activeAgentExecutionId]: a drive that outlived its
  /// run must never overwrite a successor's.
  WorkspaceDescriptor? _activeDescriptor;

  /// The generation of the current [run]. A drive abandoned at the
  /// whole-run bound keeps running detached; the epoch is how it is told
  /// apart from a later run now holding the slot it used to own.
  int _driveEpoch = 0;

  /// The epoch of a drive that was explicitly abandoned. A drive is stale
  /// the moment its run is given up on — not only when a successor starts —
  /// so an abandoned drive that unwedges in the gap before the next [run]
  /// still cannot start a session nobody is waiting for.
  int? _abandonedEpoch;

  bool _isStale(int epoch) => epoch != _driveEpoch || epoch == _abandonedEpoch;

  @override
  Set<WorkerCapability> get capabilities => _capabilities;

  @override
  bool get isAcquirable => !_leased;

  @override
  Future<void> acquire() async {
    if (_leased) throw const WorkerBusyException('');
    _leased = true;
  }

  @override
  Future<void> release() async {
    _leased = false;
    _activeAgentExecutionId = null;
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
      lastHeartbeat: clock().toUtc(),
      platform: platform,
      currentExecutionId: _activeAgentExecutionId,
    );
  }

  /// The status this worker is actually in right now, from its own lease.
  ///
  /// `toRegistration`'s DEFAULT is still [WorkerStatus.idle] and is left alone:
  /// [WorkerRegistry] calls it to build dispatch snapshots, and dispatch
  /// deliberately asks the live worker for availability rather than reading the
  /// snapshot's status (see `WorkerDispatcher.run`). This accessor is the one
  /// that writes the durable row, where "busy" is a fact an operator can see.
  WorkerStatus get liveStatus =>
      _leased ? WorkerStatus.busy : WorkerStatus.idle;

  /// Writes this worker's registration row, bounded by [heartbeatWriteTimeout].
  ///
  /// Throws [StateError] when no [registrationStore] was supplied: a caller that
  /// asked for a durable write and cannot perform one must be told, not
  /// silently reported as a success.
  Future<void> writeRegistration({
    WorkerStatus? status,
    Duration? timeout,
  }) async {
    final store = registrationStore;
    if (store == null) {
      throw StateError(
        'Worker $workerId has no registrationStore, so its registration row '
        'cannot be written. A worker that is never registered reads as a fleet '
        'of zero on the operator surface, which is a fabricated machine '
        'shortage rather than a true one.',
      );
    }
    await store
        .registerWorker(toRegistration(status: status ?? liveStatus))
        .timeout(timeout ?? heartbeatWriteTimeout);
  }

  /// The ceiling on the WHOLE run: the agent session's own budget plus the
  /// grace the `execute` await already carries, plus the bound on everything
  /// else the drive does. Without it the lease is held by every unbounded
  /// await in the drive — an event write, a verification read, a cleanup —
  /// which is the F-226 starvation: the zombie sweep can orphan the durable
  /// row but has no path back to the in-process slot, so the worker reports
  /// `busy 1/1` for ever and every queued job defers `workerBusy`.
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
  /// dead so its detached continuation cannot start a session or touch the
  /// slot, cancels the hung agent session, attempts the workspace cleanup,
  /// and writes an honest terminal outcome. Every step is bounded by
  /// [abandonStepBound] and best-effort — the abandon path exists to escape
  /// a wedge and must never wait on one, so a component that may itself be
  /// the wedge (the store, the driver) is given [abandonStepBound] and no
  /// more. The lease itself is freed by [run]'s finally.
  Future<WorkerExecutionResult> _abandonDrive(
    WorkerExecutionRequest request,
    int epoch,
  ) async {
    _abandonedEpoch = epoch;
    final bound = _runBound(request);
    final failureDetail =
        'worker drive exceeded its whole-run bound of $bound and was '
        'abandoned; the wedged await continues detached but holds no lease';
    final agentExecutionId = _activeAgentExecutionId;
    final descriptor = _activeDescriptor;

    // Stop the hung agent session where one was started. The timeout arm in
    // _drive uses this same path for the same reason.
    if (agentExecutionId != null) {
      try {
        await executionDriver
            .cancel(agentExecutionId, 'worker drive bound exceeded')
            .timeout(abandonStepBound);
      } on Object {
        // The driver may be the wedged component; the cancel is best-effort.
      }
    }

    var cleanupStatus = WorkerCleanupStatus.notApplicable;
    if (descriptor != null) {
      if (request.cleanupPolicy.preservesOnFailure) {
        cleanupStatus = WorkerCleanupStatus.preservedPerPolicy;
      } else {
        // KNOWN RACE, documented rather than solved: this cleanup runs while
        // the detached drive may still be inside an in-flight worktree
        // operation — the wedged await it was abandoned on (an inspect, an
        // artifact commit) resumes to find its worktree being removed, or
        // already gone. Both directions are tolerated: the detached side's
        // operation fails or completes pointlessly and every write it could
        // make afterwards is epoch-fenced, and a removal that fails because
        // a git process still holds the directory reports the honest
        // cleanupFailed rather than wedging. What the race must never do is
        // block — the step bound is what keeps a stuck git from re-taking
        // the lease.
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
          agentExecutionId: agentExecutionId,
          createdAt: DateTime.now().toUtc(),
          startedAt: DateTime.now().toUtc(),
        ),
        finalStatus: WorkerExecutionStatus.timedOut,
        cleanupStatus: cleanupStatus,
        failureCode: WorkerFailureCode.timedOut,
        failureDetail: failureDetail,
        agentExecutionId: agentExecutionId,
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
        agentExecutionId: agentExecutionId,
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
  /// where the drive stops: no session start, no inspection or artifact
  /// commit, no cleanup record, no terminal write.
  ///
  /// "Writes nothing" is a claim about the durable record and the artifact
  /// branch only. A wedged await can still be holding an in-flight operation
  /// when the run is abandoned — a git invocation, a worktree touch — and
  /// that operation may complete when the await resumes (see the race note
  /// in [_abandonDrive]). What the fences guarantee is that nothing the
  /// detached drive does afterwards reaches the store or the artifact
  /// branch a retry resolves.
  WorkerExecutionResult _detachedResult(
    WorkerExecution execution,
    String? agentExecutionId,
  ) {
    return WorkerExecutionResult(
      workerExecutionId: execution.workerExecutionId,
      workItemId: execution.workItemId,
      status: WorkerExecutionStatus.timedOut,
      startingRevision: execution.requestedStartingRevision,
      workerId: workerId,
      workspaceId: '',
      agentExecutionId: agentExecutionId,
      cleanupStatus: WorkerCleanupStatus.notApplicable,
      failureCode: WorkerFailureCode.timedOut,
      failureDetail:
          'the worker drive outlived its whole-run bound and was abandoned',
      startedAt: execution.startedAt ?? DateTime.now().toUtc(),
      endedAt: DateTime.now().toUtc(),
    );
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
      return _detachedResult(execution, null);
    }

    WorkspaceDescriptor? descriptor;
    var cleanupStatus = WorkerCleanupStatus.notApplicable;
    var failureCode = WorkerFailureCode.none;
    String? failureDetail;
    WorkerExecutionStatus finalStatus = WorkerExecutionStatus.executedFail;
    AgentResultStatus? agentResultStatus;
    bool? verificationPassed;
    String? verificationId;
    String? endingRevision;
    List<ChangedFile> changedFiles = const [];
    String? diffSummary;
    String? agentExecutionId;

    try {
      execution = await _transition(
        execution,
        WorkerExecutionStatus.workspacePreparing,
        epoch: epoch,
      );
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
          return _detachedResult(execution, agentExecutionId);
        }
        failureCode = WorkerFailureCode.prepareFailed;
        failureDetail = e.toString();
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
        return _detachedResult(execution, agentExecutionId);
      }
      await _event(execution, WorkerEventType.workspaceReady);
      execution = await _transition(
        execution,
        WorkerExecutionStatus.agentExecuting,
        epoch: epoch,
      );
      final agentRequest = _agentRequest(execution, request, descriptor);
      agentExecutionId = agentRequest.executionId;
      if (_isStale(epoch)) {
        // This drive outlived the whole-run bound and was abandoned while it
        // was wedged. Starting the session now would run real work on a slot
        // a later run may already own, so the drive unwinds the workspace it
        // just prepared and stops instead. Its lease was already freed by
        // [run]'s finally — never by this drive.
        try {
          await workspaceManager.cleanup(descriptor);
        } on Object {
          // Best-effort: a stale drive's leftover is platform-owned metadata
          // under the workspace root and is reclaimed by the sweeps.
        }
        return _detachedResult(execution, agentExecutionId);
      }
      _activeAgentExecutionId = agentRequest.executionId;

      AgentExecution settled;
      try {
        await _event(execution, WorkerEventType.executionStarted);
        if (_isStale(epoch)) {
          // Abandoned while wedged in the event write: starting the
          // session now would run real agent work nobody is waiting
          // for, on a slot a successor may already hold.
          return _detachedResult(execution, agentExecutionId);
        }
        settled = await executionDriver
            .execute(agentRequest)
            .timeout(
              Duration(
                seconds: request.timeoutSeconds + workerLeaseGrace.inSeconds,
              ),
            );
      } on TimeoutException catch (e) {
        if (_isStale(epoch)) {
          // Abandoned while wedged in this await: the cleanup record and the
          // terminal write below belong to the abandon path. A detached
          // drive running them would CAS-overwrite the honest timedOut it
          // already wrote.
          return _detachedResult(execution, agentExecutionId);
        }
        failureCode = WorkerFailureCode.timedOut;
        failureDetail = e.toString();
        await _cancelAgent(execution, agentRequest.executionId);
        finalStatus = WorkerExecutionStatus.timedOut;
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
          agentResultStatus: agentResultStatus,
          endingRevision: endingRevision,
          changedFiles: changedFiles,
          diffSummary: diffSummary,
        );
      }

      // Re-check staleness AFTER the session settles: a drive abandoned
      // while it was wedged in the event write or the execute await above
      // resumes here, and the abandon path already wrote this run's honest
      // terminal. Everything below — inspection, the artifact commit, the
      // cleanup record, _finish — is a write nobody is waiting for, and the
      // commit would `checkout -B` force-move the artifact branch a retry
      // resolves.
      if (_isStale(epoch)) {
        return _detachedResult(execution, agentExecutionId);
      }

      // Inspect git BEFORE cleanup: this is the platform's own evidence.
      final inspection = await inspector.inspect(
        descriptor.worktreePath,
        startingRevision: descriptor.startingRevision,
      );
      endingRevision = inspection.revision;
      changedFiles = inspection.changedFiles;
      diffSummary = inspection.diffSummary;

      agentResultStatus = _fromSessionStatus(settled.status);

      final verifications = await executionDriver.verificationsFor(
        agentRequest.executionId,
      );
      if (_isStale(epoch)) {
        // Abandoned while wedged in this read (or in the inspection
        // above): the verificationStarted event and everything below
        // are fresh writes on a run that already settled.
        return _detachedResult(execution, agentExecutionId);
      }
      if (verifications.isNotEmpty) {
        await _event(execution, WorkerEventType.verificationStarted);
        verificationId = verifications.first.verificationId;
        verificationPassed = verifications.every(
          (v) => v.status == AgentClaimStatus.passed,
        );
      }

      switch (settled.status) {
        case AgentSessionStatus.completed:
          final passed =
              agentResultStatus == AgentResultStatus.completed &&
              (verificationPassed ?? true);
          finalStatus = passed
              ? WorkerExecutionStatus.executedPass
              : WorkerExecutionStatus.executedFail;
          if (!passed) {
            failureCode = WorkerFailureCode.agentFailed;
            failureDetail = verificationPassed == false
                ? 'verification ${verificationId ?? ''} failed'
                : 'agent completed without platform verification';
          }
        case AgentSessionStatus.failed:
          finalStatus = WorkerExecutionStatus.executedFail;
          failureCode = WorkerFailureCode.agentFailed;
          failureDetail = 'agent session failed';
        case AgentSessionStatus.interrupted:
          finalStatus = WorkerExecutionStatus.timedOut;
          failureCode = WorkerFailureCode.timedOut;
          failureDetail = await _timeoutDetailFor(agentRequest.executionId);
        case AgentSessionStatus.cancelled:
          finalStatus = WorkerExecutionStatus.cancelled;
          failureCode = WorkerFailureCode.cancelled;
          failureDetail = 'agent session cancelled';
        case AgentSessionStatus.orphaned:
          finalStatus = WorkerExecutionStatus.orphaned;
          failureCode = WorkerFailureCode.agentFailed;
          failureDetail = 'agent session orphaned';
        case AgentSessionStatus.starting:
        case AgentSessionStatus.running:
          finalStatus = WorkerExecutionStatus.executedFail;
          failureCode = WorkerFailureCode.agentFailed;
          failureDetail = 'execution never reached a terminal state';
      }

      // Commit the produced artifact onto a durable branch BEFORE cleanup
      // removes the worktree. The worktree is detached and is destroyed on
      // completion, so an uncommitted edit is not evidence anything downstream
      // can inspect: the produced revision is the commit. A reviewer must NEVER
      // commit — it inspects what the producer produced — so this is skipped
      // for BOTH reviewer roles.
      //
      // The DESIGN reviewer is excluded for the same reason, and the step-8
      // mount is what makes that reachable: its subject is the Penpot revision
      // the producer recorded, not a commit of the review worktree.
      //
      // The stale guard comes FIRST: a drive abandoned while it was wedged in
      // the inspection or verification reads above resumes here, and running
      // the commit now would force-move `shipit/impl/<workItemId>` — the
      // shared branch a retry's commit and a downstream reviewer resolve —
      // onto an abandoned run's artifact.
      if (!_isStale(epoch) &&
          request.role != AgentRole.engineeringReviewer &&
          request.role != AgentRole.designReviewer) {
        final committed = await artifactCommitter.commit(
          worktreePath: descriptor.worktreePath,
          workItemId: request.workItemId,
          startingRevision: descriptor.startingRevision,
          message:
              'shipit artifact: ${request.workItemId} '
              '(${request.role.wire}) ${request.workerExecutionId}',
        );
        if (_isStale(epoch)) {
          // Abandoned while wedged inside the commit itself: the branch
          // move may already have happened (the documented race), but
          // the artifactCommitFailed event below must not land on a run
          // that already settled.
          return _detachedResult(execution, agentExecutionId);
        }
        if (committed.revision != null) {
          endingRevision = committed.revision;
        } else if (committed.failureDetail != null) {
          // A commit failure must not abort an otherwise-successful run, but it
          // MUST be visible: the run recorded an inspected revision that no
          // downstream reviewer can resolve. Emit it rather than swallowing it.
          await _event(
            execution,
            WorkerEventType.finalizing,
            payload: {
              'artifactCommitFailed': true,
              'detail': committed.failureDetail,
            },
          );
        }
      }
    } on ConcurrentWorkerModificationException {
      if (_isStale(epoch)) {
        return _detachedResult(execution, agentExecutionId);
      }
      // The WORKER-EXECUTION row itself was advanced by a concurrent writer —
      // a scheduler zombie reclaim or the worker reconciler — so it already
      // carries a verdict this drive lost to. Every write below would
      // contradict it: `_setCleanup`'s blind upsert would resurrect this
      // stale copy's status over the terminal row, and `_finish`'s terminal
      // compare-and-swap would replace the winning verdict with a second,
      // false one. The drive therefore writes nothing and rethrows: the run
      // fails out to `_settleDetachedRun`, which drops the claim so the
      // next tick's reconcile adopts the row that already won — the verdict
      // that is actually durable.
      rethrow;
    } on Object catch (e) {
      if (_isStale(epoch)) {
        // Abandoned while wedged in an await that then threw — commonly the
        // worktree disappearing under an in-flight inspect or commit because
        // the abandon cleanup raced it (see _abandonDrive). Emitting an
        // executionFailed event or a cleanup record now would decorate a run
        // that already settled honestly as timedOut.
        return _detachedResult(execution, agentExecutionId);
      }
      if (isStoreContentionError(e)) {
        // A compare-and-swap loss on the WORK ITEM or AGENT EXECUTION rows:
        // a concurrent writer already advanced the durable record, so this
        // run's outcome was decided by somebody else. A lost race is
        // TRANSIENT — retrying it belongs to whoever settles the job — but
        // the worker-execution row is still this drive's to settle, and the
        // honest terminal for it is `executedFail` carrying the contention
        // marker: `RetryPolicy.classify` reads the marker and requeues the
        // job instead of terminal-failing it. Unmarked, this same detail
        // classified PERMANENT and jobs died on races they had already lost
        // correctly (F-241). `agentFailed` stays the generic carrier code —
        // the marker, not the code, carries the classification.
        failureCode = failureCode == WorkerFailureCode.none
            ? WorkerFailureCode.agentFailed
            : failureCode;
        failureDetail = '$storeContentionMarker $e';
        finalStatus = WorkerExecutionStatus.executedFail;
        await _event(
          execution,
          WorkerEventType.executionFailed,
          payload: {'detail': failureDetail, 'storeContention': true},
        );
      } else {
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
    }

    // Last checkpoint before the writes a detached drive must never reach:
    // the cleanup RECORD (_setCleanup inside _finalCleanup) and the terminal
    // write. A drive abandoned while it was wedged in the artifact commit or
    // an event write above resumes here; the abandon path already owns this
    // run's ending, including its workspace cleanup.
    if (_isStale(epoch)) {
      return _detachedResult(execution, agentExecutionId);
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
      agentResultStatus: agentResultStatus,
      verificationId: verificationId,
      verificationPassed: verificationPassed,
      agentExecutionId: agentExecutionId,
      endingRevision: endingRevision,
      changedFiles: changedFiles,
      diffSummary: diffSummary,
    );
  }

  AgentExecutionRequest _agentRequest(
    WorkerExecution execution,
    WorkerExecutionRequest request,
    WorkspaceDescriptor descriptor,
  ) {
    final agentExecutionId = 'agx-${request.workerExecutionId}';
    return AgentExecutionRequest(
      executionId: agentExecutionId,
      workItemId: request.workItemId,
      role: request.role,
      workspace: AgentWorkspace(
        workspaceId: descriptor.workspaceId,
        path: descriptor.worktreePath,
        startingRevision: descriptor.startingRevision,
        allowedPaths: [descriptor.worktreePath],
      ),
      instruction: request.instruction,
      timeoutSeconds: request.timeoutSeconds,
      runtimeTypeId: request.runtimeTypeId,
      expectedArtifacts: request.expectedArtifacts,
      // The lane's path-ownership GRANT, carried verbatim from the dispatch
      // request. This is the worker's own production write path: the
      // declaration reaches the durable execution record through this copy and
      // through the coordinator's capture, and a copy that dropped it would
      // leave every lane's declaration unreadable — which reads as "declared
      // nothing", the fail-closed direction, so the defect would be invisible
      // except as a gate that refuses everything.
      declaredOwnedPaths: request.declaredOwnedPaths,
      runtimeConfig: request.runtimeConfig,
      environment: environmentPolicy.resolve(
        request,
        hostEnv: Platform.environment,
      ),
    );
  }

  /// The failure detail for an interrupted agent session: the honest
  /// timeout, enriched with [providerFailureMarker] when the durable agent
  /// result shows the provider produced nothing — or said so itself.
  ///
  /// The enrichment is what lets `Scheduler._adopt` tell "the model quota
  /// was exhausted" apart from "the work hung": both settle `timedOut` and
  /// both are transient, but only the first earns a bump up the role's
  /// model chain. A driver that cannot read the result, or a read that
  /// fails, degrades to the plain detail — never a guessed marker, because
  /// a false marker spends the paid tier.
  Future<String> _timeoutDetailFor(String agentExecutionId) async {
    const base = 'agent session timed out';
    final driver = executionDriver;
    if (driver is! AgentResultReader) return base;
    final AgentResult? result;
    try {
      result = await (driver as AgentResultReader).resultFor(agentExecutionId);
    } on Object {
      return base;
    }
    final evidence = providerFailureEvidence(result);
    if (evidence == null) return base;
    return '$base; $providerFailureMarker$evidence';
  }

  Future<void> _cancelAgent(
    WorkerExecution execution,
    String agentExecutionId,
  ) async {
    try {
      await executionDriver.cancel(agentExecutionId, 'worker-level timeout');
    } on Object {
      // The coordinator may have already settled; never mask the timeout.
    }
  }

  AgentResultStatus? _fromSessionStatus(AgentSessionStatus status) {
    return switch (status) {
      AgentSessionStatus.completed => AgentResultStatus.completed,
      AgentSessionStatus.failed => AgentResultStatus.failed,
      AgentSessionStatus.cancelled => AgentResultStatus.cancelled,
      AgentSessionStatus.interrupted => AgentResultStatus.partial,
      _ => null,
    };
  }

  /// Cleanup on the happy path: agent passed and the platform verified.
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

  /// Cleanup on a failed/cancelled/timed-out execution, honoring the request's
  /// cleanup policy.
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
    AgentResultStatus? agentResultStatus,
    bool? verificationPassed,
    String? verificationId,
    String? agentExecutionId,
    List<ChangedFile> changedFiles = const [],
    String? diffSummary,
    String? endingRevision,
  }) async {
    // Epoch fence: a drive that outlived the whole-run bound keeps running
    // detached, and a wedged await can resume all the way down here. The
    // abandon path already wrote this run's honest terminal, so a stale
    // drive writing now would CAS-overwrite timedOut with a competing
    // status, overwrite the saved result, and append terminal events. The
    // abandon path itself passes no epoch — it IS the legitimate writer.
    if (epoch != null && _isStale(epoch)) {
      return _detachedResult(execution, agentExecutionId);
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
      return _detachedResult(execution, agentExecutionId);
    }
    final terminal = current.copyWith(
      status: finalStatus,
      workspaceId: current.workspaceId ?? '',
      agentExecutionId: agentExecutionId ?? current.agentExecutionId,
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
        agentExecutionId: agentExecutionId,
        agentResultStatus: agentResultStatus,
        verificationId: verificationId,
        verificationPassed: verificationPassed,
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
        // `workspaceCleaned` is a CLAIM ABOUT THE FILESYSTEM: it says the
        // workspace is gone. The retention makes that claim false in exactly
        // one new case — a removal that was DEFERRED
        // ([WorkerCleanupStatus.pending]), where the workspace is still on
        // disk because the evaluation that reads it has not finished. So
        // `pending` must not produce it.
        //
        // EVERY OTHER COMBINATION IS UNCHANGED, and that is deliberate. The
        // failure path keeps saying `workerReleased` for a workspace that WAS
        // removed. A run that never got a workspace at all reports
        // `notApplicable`, and that combination never reaches `executedPass`
        // — a run without a workspace either failed to prepare or was
        // interrupted, and neither is a pass. This event is not the place to
        // change any of those: doing it here would make a retention change
        // look like a semantics change it is not, and the audit trail would
        // move under lanes that did not sign up for it.
        cleanupStatus == WorkerCleanupStatus.cleanupFailed
            ? WorkerEventType.cleanupFailed
            : cleanupStatus == WorkerCleanupStatus.pending
            ? WorkerEventType.workerReleased
            : finalStatus == WorkerExecutionStatus.executedPass
            ? WorkerEventType.workspaceCleaned
            : WorkerEventType.workerReleased,
        payload: {'status': finalStatus.name},
        via: tx,
      );
      return true;
    });
    if (!committed) {
      return _detachedResult(execution, agentExecutionId);
    }
    // The lease is deliberately NOT cleared here. `_leased` belongs to the
    // run, and `run`'s finally is the only place that releases it: a drive
    // that was abandoned at the whole-run bound is turned back by the epoch
    // fence above, but even without it, letting a late continuation clear
    // the slot would free a lease a successor run already holds — the same
    // starvation bug, one level down. The same reasoning keeps
    // `_activeAgentExecutionId` teardown in `release()`.
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

  @override
  Future<void> cancel(String reason) async {
    final active = _activeAgentExecutionId;
    if (active == null) return;
    await executionDriver.cancel(active, reason);
  }
}

/// What one [WorkerRegistrationHeartbeat.start] actually wrote.
///
/// Returned rather than logged-and-dropped because the startup banner in
/// `apps/server/lib/server.dart` prints the outcome in BOTH directions: a
/// process that registered three workers and one that registered none must not
/// look the same, and "the field is absent" is precisely the ambiguity this
/// exists to remove.
@immutable
class WorkerRegistrationReport {
  const WorkerRegistrationReport({
    required this.registeredWorkerIds,
    required this.failures,
    this.staleWorkerIds = const [],
  });

  /// Workers whose row was written by this start, in fleet order.
  final List<String> registeredWorkerIds;

  /// Worker id -> why its row was not written. Non-empty means the operator
  /// surface is understating the fleet, and an operator needs to see that.
  final Map<String, String> failures;

  /// Worker ids this start found already stale. Normally empty on a fresh boot;
  /// non-empty means the table outlived a previous process.
  final List<String> staleWorkerIds;

  bool get isComplete => failures.isEmpty;

  Map<String, dynamic> describe() => {
    'registered': registeredWorkerIds,
    'registeredCount': registeredWorkerIds.length,
    'failed': failures,
    'previouslyStale': staleWorkerIds,
    'state': isComplete
        ? 'every worker in this process has a durable registration row'
        : 'AT LEAST ONE WORKER IS NOT REGISTERED: the operator surface will '
              'understate this fleet until a later heartbeat writes the row',
  };
}

/// Drives the durable worker-registration lifecycle for a fleet of [LocalWorker]s.
///
/// ## WHAT THIS IS FOR
///
/// A control plane dispatched work correctly while its operator surface reported
/// `0 of 0 machines busy` and labelled every queued job "waiting for a free
/// machine". The fleet existed and was busy; the durable registration table was
/// empty because nothing in the process ever wrote to it. An operator debugging
/// a stall was therefore sent to a machine shortage that did not exist, by
/// construction and on every run.
///
/// Dispatch did not notice, because dispatch selects from the live in-memory
/// [WorkerRegistry] and never reads the durable table. The two views of the same
/// fleet had nothing connecting them.
///
/// ## WHAT IT DOES, IN ORDER, ON EVERY PASS
///
///   1. refresh each worker in this process, then
///   2. sweep the whole table and mark aged rows [WorkerStatus.offline].
///
/// The order matters: a worker this process owns is fresh before the sweep runs,
/// so the sweep can never mark a live worker stale because of a race with its
/// own refresh.
///
/// ## WHY STALENESS IS DECIDED HERE AND NOT IN THE DOMAIN TYPE
///
/// `worker_protocol` owns the vocabulary and it is REUSED, not extended: an aged
/// row becomes [WorkerStatus.offline], the member whose `isAvailable` and
/// `isAcquirable` already mean "not available". No parallel `stale` status is
/// introduced, because a second way to say "not available" is one more thing a
/// reader has to know about and one more that can disagree with the first.
///
/// The decision itself lives here for a specific reason: a worker that dies
/// cannot mark itself gone — the process that would have written the row died
/// with it — so only a live process reading the whole table can notice. A
/// predicate on the row could only be consulted by a reader, and the readers are
/// projections that copy `status` verbatim.
///
/// ## THE BOUNDS, AND WHY EACH ONE EXISTS
///
/// * ONE timer, cancelled by [stop]. It is the only periodic thing this class
///   creates, so there is exactly one thing to cancel and exactly one thing that
///   could keep a Dart VM alive.
/// * Single-flight. `Timer.periodic` does not await its callback, so a pass that
///   outlives the interval would otherwise overlap itself and pile up against a
///   slow database. An overlapping pass is SKIPPED, never queued: queueing it
///   would rebuild the pile-up one level down.
/// * Every write is bounded by [writeTimeout], so a wedged database cannot latch
///   the single-flight guard permanently.
/// * [stop] is bounded by the same timeout and writes its final rows through
///   [Future.wait], so it returns within roughly one timeout regardless of fleet
///   size, and no write is still in flight when it returns.
class WorkerRegistrationHeartbeat {
  WorkerRegistrationHeartbeat({
    required this.workers,
    required this.store,
    this.interval = kDefaultWorkerHeartbeatInterval,
    this.staleAfter = kDefaultWorkerRegistrationStaleAfter,
    this.writeTimeout = kDefaultWorkerRegistrationWriteTimeout,
    DateTime Function()? clock,
    this.log,
  }) : clock = clock ?? _utcNow {
    if (workers.isEmpty) {
      throw StateError(
        'A WorkerRegistrationHeartbeat over zero workers registers nothing and '
        'would report an empty fleet as accurate. Refusing here is the point: '
        'an empty fleet is the defect, not a configuration.',
      );
    }
    for (final worker in workers) {
      if (worker.registrationStore == null) {
        throw StateError(
          'Worker ${worker.workerId} has no registrationStore, so it cannot '
          'be registered. Refusing to start beats starting a heartbeat that '
          'silently leaves that worker invisible.',
        );
      }
    }
  }

  final List<LocalWorker> workers;
  final WorkerRegistrationStore store;
  final Duration interval;
  final Duration staleAfter;
  final Duration writeTimeout;
  final DateTime Function() clock;
  final void Function(String event, Map<String, dynamic> fields)? log;

  Timer? _timer;
  Future<void>? _inFlight;
  WorkerRegistrationReport? _report;

  /// What the most recent [start] wrote. Null until one has run.
  ///
  /// Held rather than returned-and-forgotten because the caller needs BOTH
  /// halves: the outcome to print at startup, and the running lifecycle it
  /// would stop at shutdown. Returning only the report would leave the timer
  /// with no handle on it, which is the handle that matters.
  WorkerRegistrationReport get report =>
      _report ??
      (throw StateError(
        'No WorkerRegistrationReport yet: start() has not completed.',
      ));

  /// True while the periodic timer exists. Asserted by tests, and the property
  /// a shutdown path has to be able to observe.
  bool get isRunning => _timer != null;

  /// Registers every worker, then starts the bounded periodic refresh.
  ///
  /// A registration failure does NOT abort the start and does NOT stop the
  /// timer: a transient database error at boot must not take the control plane
  /// down, and the next pass retries. It is logged, and returned in
  /// [WorkerRegistrationReport.failures], so it cannot pass unnoticed.
  Future<WorkerRegistrationReport> start() async {
    if (_timer != null) {
      throw StateError('WorkerRegistrationHeartbeat is already running.');
    }
    final registered = <String>[];
    final failures = <String, String>{};
    for (final worker in workers) {
      try {
        await worker.writeRegistration(timeout: writeTimeout);
        registered.add(worker.workerId);
      } on Object catch (error) {
        failures[worker.workerId] = error.toString();
        _emit('worker.registration.failed', {
          'workerId': worker.workerId,
          'error': error.toString(),
          'action':
              'this worker is missing from the operator surface until a later '
              'heartbeat writes its row; every other lane is unaffected',
        });
      }
    }
    final stale = await _safeSweep();
    // NOT `unawaited(...)`: [_fire] is itself void and already contains the one
    // `unawaited` this closure needs, around the only asynchronous part. A
    // second wrapper here would be asserting a value the callee never returns.
    _timer = Timer.periodic(interval, (_) => _fire());
    _emit('worker.registration.started', {
      'intervalSeconds': interval.inSeconds,
      'staleAfterSeconds': staleAfter.inSeconds,
      'registered': registered,
      'failed': failures,
      'previouslyStale': stale,
    });
    return _report = WorkerRegistrationReport(
      registeredWorkerIds: registered,
      failures: failures,
      staleWorkerIds: stale,
    );
  }

  /// Cancels the timer, lets an in-flight pass finish (bounded), and marks every
  /// worker [WorkerStatus.offline] so a cleanly stopped worker reads as gone
  /// rather than as permanently available.
  ///
  /// It marks rows `offline` rather than deleting them, on purpose. Deleting
  /// would make the fleet size fall to zero on shutdown and reproduce the very
  /// defect this class exists to fix, in the opposite direction: an operator
  /// would again be shown a shortage that is an artefact of bookkeeping.
  ///
  /// ## THE ONE WINDOW, STATED RATHER THAN GLOSSED
  ///
  /// If the pass that [stop] abandoned is still running when the `offline`
  /// rows are written, it can rewrite one of them back to `idle` with a fresh
  /// `lastHeartbeat`. That is the pathological branch — the pass did not finish
  /// within [writeTimeout] — and it is the ONLY branch in which it can happen:
  /// in every other case the pass is awaited to completion first, so the
  /// `offline` write is unambiguously last.
  ///
  /// It is not papered over with a read-back-and-retry, because that closes the
  /// window by one bounded round trip rather than removing it, and buys a second
  /// network dependency in a shutdown path. It self-heals instead: the rewritten
  /// row carries a fresh heartbeat that nothing will refresh, so the next
  /// process's sweep condemns it. The failure mode is therefore "a stopped
  /// worker looks available until a surviving registrar notices", which is
  /// bounded by [kDefaultWorkerRegistrationStaleAfter], and not "a stopped
  /// worker looks available for ever", which is the defect this closes.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;

    final inFlight = _inFlight;
    if (inFlight != null) {
      try {
        await inFlight.timeout(writeTimeout);
      } on Object catch (error) {
        // Two causes land here and both are reported rather than swallowed: a
        // pass that overran its bound and will never finish, and a pass that
        // threw. Neither may hold the shutdown open.
        _emit('worker.registration.stop.inflight_abandoned', {
          'error': error.toString(),
          'timeoutSeconds': writeTimeout.inSeconds,
        });
      }
    }

    // One round trip's worth of time, not one per worker: the bound on `stop`
    // is the write timeout regardless of how large the fleet is.
    await Future.wait(
      workers.map(
        (worker) => worker
            .writeRegistration(
              status: WorkerStatus.offline,
              timeout: writeTimeout,
            )
            .catchError((Object error) {
              _emit('worker.registration.stop.failed', {
                'workerId': worker.workerId,
                'error': error.toString(),
              });
            }),
      ),
    );
    log?.call('worker.registration.stopped', {
      'workerIds': workers.map((w) => w.workerId).toList(),
    });
  }

  /// One pass: refresh this fleet, then sweep the table for stale rows.
  ///
  /// Public and idempotent so the properties it holds can be asserted without
  /// racing a timer.
  Future<void> tick() async {
    final pass = _runPass();
    _inFlight = pass;
    try {
      await pass;
    } finally {
      if (identical(_inFlight, pass)) _inFlight = null;
    }
  }

  /// Marks every registration row whose last heartbeat is older than
  /// [staleAfter] as [WorkerStatus.offline]. Returns the worker ids it changed.
  ///
  /// The rewritten row KEEPS ITS ORIGINAL `lastHeartbeat`. That is not an
  /// oversight and it is the whole point: writing `now` would refresh the very
  /// timestamp the sweep is reasoning about and make a silent worker look
  /// healthy again on the next pass. The age on screen stays the age that
  /// actually happened.
  Future<List<String>> sweep() async {
    final now = clock().toUtc();
    final stale = <String>[];
    for (final row in await store.listWorkers()) {
      // A row stamped in the future is clock skew between hosts, not evidence
      // of death, and is deliberately not treated as stale.
      if (now.difference(row.lastHeartbeat.toUtc()) <= staleAfter) continue;
      await store.registerWorker(_asOffline(row)).timeout(writeTimeout);
      stale.add(row.workerId);
    }
    if (stale.isNotEmpty) {
      _emit('worker.registration.stale', {
        'workerIds': stale,
        'staleAfterSeconds': staleAfter.inSeconds,
        'status': WorkerStatus.offline.name,
        'action':
            'these workers stopped heartbeating and are now reported as '
            'offline rather than available. They are not deleted: a machine '
            'that is unreachable should be visible, not absent',
      });
    }
    return stale;
  }

  Future<void> _runPass() async {
    for (final worker in workers) {
      try {
        await worker.writeRegistration(timeout: writeTimeout);
      } on Object catch (error) {
        _emit('worker.registration.refresh.failed', {
          'workerId': worker.workerId,
          'error': error.toString(),
        });
      }
    }
    await _safeSweep();
  }

  Future<List<String>> _safeSweep() async {
    try {
      return await sweep();
    } on Object catch (error) {
      _emit('worker.registration.sweep.failed', {'error': error.toString()});
      return const [];
    }
  }

  /// `Timer.periodic` does not await its callback and an error escaping into the
  /// timer zone is an unhandled asynchronous error, so both are contained here.
  ///
  /// Note that the guard checks [_inFlight] and returns, and [tick] re-checks
  /// nothing: the window between the two is synchronous, so no second pass can
  /// enter in it.
  void _fire() {
    if (_inFlight != null) {
      _emit('worker.registration.tick.skipped', {
        'reason':
            'the previous pass has not finished; skipping rather than '
            'queueing so a slow store cannot build a backlog of heartbeats',
      });
      return;
    }
    unawaited(
      tick().catchError((Object error) {
        _emit('worker.registration.tick.failed', {'error': error.toString()});
      }),
    );
  }

  /// [WorkerRegistration] has no `copyWith`, and the two fields this changes are
  /// named explicitly rather than spread-copied: `currentExecutionId` is absent
  /// from the codec and must stay absent, and `lastHeartbeat` must survive.
  WorkerRegistration _asOffline(WorkerRegistration row) => WorkerRegistration(
    workerId: row.workerId,
    poolId: row.poolId,
    capabilities: row.capabilities,
    status: WorkerStatus.offline,
    // An offline worker holds nothing. Leaving the load it had when it died
    // would report capacity that does not exist.
    currentLoad: 0,
    maxConcurrency: row.maxConcurrency,
    lastHeartbeat: row.lastHeartbeat,
    artifactCache: row.artifactCache,
    platform: row.platform,
    currentExecutionId: null,
  );

  void _emit(String event, Map<String, dynamic> fields) =>
      log?.call(event, fields);
}

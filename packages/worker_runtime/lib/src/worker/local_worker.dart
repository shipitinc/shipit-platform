import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';

import '../env/environment_policy.dart';
import '../execution/agent_execution_driver.dart';
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

  /// Optional observer for normalized worker events (used by tests/audit).
  final void Function(WorkerEventRecord event)? eventSink;

  bool _leased = false;
  int _sequence = 0;
  String? _activeAgentExecutionId;

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

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    if (!_leased) await acquire();
    try {
      return await _drive(request);
    } finally {
      await release();
    }
  }

  Future<WorkerExecutionResult> _drive(WorkerExecutionRequest request) async {
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
    await workerStore.inTransaction((tx) async {
      await tx.saveWorkerExecution(execution);
      await _event(execution, WorkerEventType.workerAcquired, via: tx);
    });

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
      );
      try {
        descriptor = await workspaceManager.prepare(
          request,
          workerId: workerId,
        );
      } on Object catch (e) {
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
          finalStatus: finalStatus,
          cleanupStatus: cleanupStatus,
          failureCode: failureCode,
          failureDetail: failureDetail,
        );
      }

      await _event(execution, WorkerEventType.workspaceReady);
      execution = await _transition(
        execution,
        WorkerExecutionStatus.agentExecuting,
      );
      final agentRequest = _agentRequest(execution, request, descriptor);
      agentExecutionId = agentRequest.executionId;
      _activeAgentExecutionId = agentRequest.executionId;

      AgentExecution settled;
      try {
        await _event(execution, WorkerEventType.executionStarted);
        settled = await executionDriver
            .execute(agentRequest)
            .timeout(
              Duration(
                seconds: request.timeoutSeconds + workerLeaseGrace.inSeconds,
              ),
            );
      } on TimeoutException catch (e) {
        failureCode = WorkerFailureCode.timedOut;
        failureDetail = e.toString();
        await _cancelAgent(execution, agentRequest.executionId);
        finalStatus = WorkerExecutionStatus.timedOut;
        cleanupStatus = await _cleanupAfterFailure(
          execution,
          request,
          descriptor,
        );
        return _finish(
          execution,
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
          failureDetail = 'agent session timed out';
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
      // commit — it inspects what the implementer produced — so this is skipped
      // for the engineering-reviewer role.
      if (request.role != AgentRole.engineeringReviewer) {
        final committed = await artifactCommitter.commit(
          worktreePath: descriptor.worktreePath,
          workItemId: request.workItemId,
          startingRevision: descriptor.startingRevision,
          message:
              'shipit artifact: ${request.workItemId} '
              '(${request.role.wire}) ${request.workerExecutionId}',
        );
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
    } on Object catch (e) {
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

    cleanupStatus = await _finalCleanup(
      execution,
      request,
      descriptor,
      finalStatus: finalStatus,
    );
    return _finish(
      execution,
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
      runtimeConfig: request.runtimeConfig,
      environment: environmentPolicy.resolve(
        request,
        hostEnv: Platform.environment,
      ),
    );
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
  }) async {
    if (descriptor == null) return WorkerCleanupStatus.notApplicable;
    if (request.cleanupPolicy.preservesOnFailure &&
        finalStatus != WorkerExecutionStatus.executedPass) {
      await _setCleanup(execution, WorkerCleanupStatus.preservedPerPolicy);
      return WorkerCleanupStatus.preservedPerPolicy;
    }
    final status = await workspaceManager.cleanup(descriptor);
    await _setCleanup(execution, status);
    return status;
  }

  /// Cleanup on a failed/cancelled/timed-out execution, honoring the request's
  /// cleanup policy.
  Future<WorkerCleanupStatus> _cleanupAfterFailure(
    WorkerExecution execution,
    WorkerExecutionRequest request,
    WorkspaceDescriptor descriptor,
  ) async {
    if (request.cleanupPolicy.preservesOnFailure) {
      await _setCleanup(execution, WorkerCleanupStatus.preservedPerPolicy);
      return WorkerCleanupStatus.preservedPerPolicy;
    }
    final status = await workspaceManager.cleanup(descriptor);
    await _setCleanup(execution, status);
    return status;
  }

  Future<WorkerExecutionResult> _finish(
    WorkerExecution execution, {
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
    // Re-read the canonical record so the terminal write's CAS compares
    // against the last persisted intermediate version.
    final current =
        await workerStore.readWorkerExecution(execution.workerExecutionId) ??
        execution;
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

    await workerStore.inTransaction((tx) async {
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
        cleanupStatus == WorkerCleanupStatus.cleanupFailed
            ? WorkerEventType.cleanupFailed
            : finalStatus == WorkerExecutionStatus.executedPass
            ? WorkerEventType.workspaceCleaned
            : WorkerEventType.workerReleased,
        payload: {'status': finalStatus.name},
        via: tx,
      );
    });
    _leased = false;
    _activeAgentExecutionId = null;
    return result;
  }

  Future<WorkerExecution> _transition(
    WorkerExecution execution,
    WorkerExecutionStatus status,
  ) async {
    final next = execution.copyWith(
      status: status,
      version: execution.version + 1,
    );
    await workerStore.saveWorkerExecution(next);
    return next;
  }

  Future<void> _setCleanup(
    WorkerExecution execution,
    WorkerCleanupStatus status,
  ) async {
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

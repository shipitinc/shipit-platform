import 'dart:async';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:scheduler/src/capacity/capacity_lockable_store.dart';
import 'package:scheduler/src/capacity/execution_capacity.dart';
import 'package:scheduler/src/capacity/job_capacity_guard.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// A [JobStore] that behaves like a durable one under the capacity guard.
///
/// Two properties matter, and both are deliberately reproduced rather than
/// wished for:
///
///  1. **Every store call is an await point.** A real store round-trips to
///     another process. If the in-memory map answered synchronously, "count the
///     in-flight jobs" and "claim one" would run without an interleaving point
///     and the overshoot race could not happen even with the lock removed — the
///     test would pass for the wrong reason. [roundTrip] yields to the event
///     loop, so the window the budget lock exists to close is really open.
///  2. **The budget lock really excludes.** [_locks] serialises
///     [inCapacityLockedTransaction] per key exactly the way
///     `pg_advisory_xact_lock` serialises across connections, and releases on
///     every exit path including failure.
///
/// The data itself lives in [inner], so a "restart" is a brand-new instance of
/// this store over the same [inner] — which is exactly what T5 needs to show
/// the cap is not held in process memory.
class SerializedJobStore implements JobStore, CapacityLockingJobStore {
  SerializedJobStore(this.inner);

  final JobStore inner;

  /// Set to false ONLY to demonstrate, in a throwaway copy, that removing the
  /// budget lock reintroduces the overshoot this store normally prevents.
  /// Never set false in a committed test.
  bool honourBudgetLock = true;

  /// Budget locks, scoped to the DURABLE store rather than to this wrapper.
  ///
  /// `pg_advisory_xact_lock` is scoped to the database and shared by every
  /// connection, so two schedulers over one database contend for one lock. A
  /// per-wrapper registry would model something else entirely — and would model
  /// it wrongly in the dangerous direction: two "replicas" would each take a
  /// private lock and both admit, which is precisely the overshoot.
  static final Expando<Map<int, Completer<void>>> _locksByDatabase =
      Expando<Map<int, Completer<void>>>('capacity-budget-locks');

  Map<int, Completer<void>> get _locks =>
      _locksByDatabase[inner] ??= <int, Completer<void>>{};

  /// Simulates one durable round trip.
  static Future<void> roundTrip() => Future<void>.delayed(Duration.zero);

  Future<T> _roundTrip<T>(Future<T> Function() body) async {
    await roundTrip();
    final result = await body();
    await roundTrip();
    return result;
  }

  @override
  Future<T> inCapacityLockedTransaction<T>(
    int lockKey,
    Future<T> Function(JobStore store) body,
  ) async {
    if (!honourBudgetLock) {
      // Mutant: no exclusion at all. Count and claim interleave freely.
      return inner.inTransaction(body);
    }
    final locks = _locks;
    final previous = locks[lockKey];
    final mine = Completer<void>();
    locks[lockKey] = mine;
    if (previous != null) {
      await previous.future;
    }
    try {
      return await inner.inTransaction((tx) => body(this));
    } finally {
      // Released on success AND on failure, exactly as a transaction-scoped
      // advisory lock is released by COMMIT, ROLLBACK or connection loss.
      if (identical(locks[lockKey], mine)) locks.remove(lockKey);
      if (!mine.isCompleted) mine.complete();
    }
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) =>
      _roundTrip(() => inner.inTransaction((tx) => body(this)));

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) =>
      _roundTrip(() => inner.saveJob(job, expectedVersion: expectedVersion));

  @override
  Future<Job?> readJob(String jobId) => _roundTrip(() => inner.readJob(jobId));

  @override
  Future<List<Job>> listJobs() => _roundTrip(inner.listJobs);

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) =>
      _roundTrip(() => inner.listJobsForWorkItem(workItemId));

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) =>
      _roundTrip(() => inner.findLatestByDedupeKey(dedupeKey));

  @override
  Future<void> saveClaim(JobClaim claim) =>
      _roundTrip(() => inner.saveClaim(claim));

  @override
  Future<JobClaim?> readClaimForJob(String jobId) =>
      _roundTrip(() => inner.readClaimForJob(jobId));

  @override
  Future<List<JobClaim>> listClaims() => _roundTrip(inner.listClaims);

  @override
  Future<void> deleteClaim(String jobId) =>
      _roundTrip(() => inner.deleteClaim(jobId));

  @override
  Future<void> appendEvent(SchedulerEventRecord event) =>
      _roundTrip(() => inner.appendEvent(event));

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) =>
      _roundTrip(() => inner.readEvents(jobId));
}

/// A dispatch surface that counts how many agent executions are running at the
/// same instant and remembers the HIGHEST number it ever saw.
///
/// The assertion target is [observedMaxConcurrency], never a final count. A
/// cap that is briefly exceeded and then re-converges looks perfect to any
/// end-state assertion, and a brief overshoot is precisely what exhausts a
/// host: the peak is the number that matters.
class InstrumentedDispatcher implements WorkerDispatch {
  InstrumentedDispatcher({this.maxConcurrency = 8});

  /// Advertised worker parallelism. Deliberately generous: the WORKER does not
  /// enforce this cap, so anything the test observes above `C` is the capacity
  /// guard failing, not the worker pool doing its job.
  final int maxConcurrency;

  var _active = 0;
  var observedMaxConcurrency = 0;
  final List<String> started = [];
  final List<String> _parked = [];
  final List<Completer<void>> _releases = [];

  /// When true, each run parks until [releaseAll] is called, so several
  /// executions can be in flight simultaneously and the peak is observable.
  bool parkRuns = false;

  bool get hasParkedRuns => _parked.isNotEmpty;

  int get active => _active;

  /// Runs currently parked, waiting to be released.
  int get parked => _parked.length;

  /// Lets every parked run finish, and stops parking future ones.
  ///
  /// Stopping the parking matters: a tick that is midway through its dispatch
  /// loop will carry on to the next job once this one returns, and a test that
  /// meant to release exactly one slot would otherwise park again on the next
  /// one and hang.
  void releaseAll() {
    parkRuns = false;
    final pending = List<Completer<void>>.from(_releases);
    _releases.clear();
    _parked.clear();
    for (final release in pending) {
      if (!release.isCompleted) release.complete();
    }
  }

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    return WorkerSelection.dispatched(
      WorkerRegistration(
        workerId: 'w-instrumented',
        poolId: 'instrumented-pool',
        capabilities: {
          for (final c in request.requiredCapabilities)
            c: CapabilitySpec(capability: c, version: '1'),
        },
        status: WorkerStatus.busy,
        currentLoad: _active,
        maxConcurrency: maxConcurrency,
        lastHeartbeat: DateTime.now(),
      ),
    );
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    _active++;
    if (_active > observedMaxConcurrency) observedMaxConcurrency = _active;
    started.add(request.workItemId);
    final release = Completer<void>();
    if (parkRuns) {
      _parked.add(request.workItemId);
      _releases.add(release);
    }
    try {
      if (parkRuns) await release.future;
      // One more round trip so the peak is genuinely observed while the
      // execution is held, not merely at its instant of entry.
      await SerializedJobStore.roundTrip();
      final now = DateTime.now().toUtc();
      return WorkerExecutionResult(
        workerExecutionId: request.workerExecutionId,
        workItemId: request.workItemId,
        status: WorkerExecutionStatus.executedPass,
        workerId: 'w-instrumented',
        workspaceId: 'ws-${request.workerExecutionId}',
        startingRevision: request.startingRevision,
        startedAt: now,
        endedAt: now,
        cleanupStatus: WorkerCleanupStatus.removed,
        failureCode: WorkerFailureCode.none,
      );
    } finally {
      _active--;
    }
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

/// One capacity-test world: shared durable state plus however many scheduler
/// replicas the test needs (two replicas is the shape that actually
/// exercised the bug — a cap that only holds for one process holds for no
/// reason at all).
class CapacityHost {
  CapacityHost({required DateTime Function() clock, int replicas = 1})
    : _clock = clock,
      innerStore = InMemoryJobStore(),
      workflowStore = InMemoryWorkflowStore(),
      workerStore = InMemoryWorkerStore() {
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    store = SerializedJobStore(innerStore);
    dispatch = InstrumentedDispatcher();
    schedulers = [
      for (var i = 0; i < replicas; i++) _newScheduler('sched-${i + 1}'),
    ];
  }

  /// The durable truth a "restart" would find on disk.
  final InMemoryJobStore innerStore;
  final WorkflowStore workflowStore;
  final WorkerStore workerStore;
  final DateTime Function() _clock;

  late final DurableWorkflowEngine workflowEngine;
  late final SerializedJobStore store;
  late final InstrumentedDispatcher dispatch;

  /// Rebuilt by [applyCap]; not final because a cap is injected by constructing
  /// a new Scheduler, never by mutating an existing one.
  late List<Scheduler> schedulers;

  static const SchedulerWorkload _workload = SchedulerWorkload(
    repositoryPath: '/tmp/capacity',
    startingRevision: 'deadbeef',
    timeoutSeconds: 60,
    runtimeTypeId: 'instrumented-runtime',
  );

  Scheduler _newScheduler(
    String id, {
    WorkerDispatch? dispatch,
    JobStore? store,
    JobCapacityGuard? capacityGuard,
  }) {
    return Scheduler(
      schedulerId: id,
      workflowStore: workflowStore,
      jobStore: store ?? this.store,
      workerStore: workerStore,
      dispatch: dispatch ?? this.dispatch,
      definition: defaultImplementFeatureDefinition,
      workload: _workload,
      clock: _clock,
      capacityGuard: capacityGuard,
      // Matches `capacityDedupeKey` used by [enqueueAll]. Left explicit so the
      // harness can never pre-enqueue a job under one key and have a tick mint
      // a second job for the same work item under another.
      dedupeKeyBuilder: (item, definition) => capacityDedupeKey(item),
    );
  }

  Scheduler get scheduler => schedulers.first;

  /// A "restart": a brand-new store wrapper and a brand-new scheduler over the
  /// same durable [innerStore]. Nothing in-process carries over — in
  /// particular, no capacity counter could survive this.
  ({
    SerializedJobStore store,
    Scheduler scheduler,
    InstrumentedDispatcher dispatch,
  })
  restart({int cap = 2}) {
    final freshStore = SerializedJobStore(innerStore);
    final freshDispatch = InstrumentedDispatcher();
    final fresh = _newScheduler(
      'sched-restarted',
      dispatch: freshDispatch,
      store: freshStore,
      capacityGuard: guardFor(cap, store: freshStore),
    );
    return (store: freshStore, scheduler: fresh, dispatch: freshDispatch);
  }

  /// Creates a work item parked at a RUNNABLE entry state.
  Future<void> itemRunnable(String workItemId) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Item $workItemId',
      description: 'Capacity-cap test item $workItemId',
      qaContractId: 'qa-$workItemId',
      featureRef: 'feature/$workItemId',
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: {'featureRef': 'feature/$workItemId'},
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  /// Builds a guard over [store] with the given cap, resolved the same way
  /// production resolves it — through the environment, not a constructor that
  /// could be handed a hand-picked number.
  JobCapacityGuard guardFor(int cap, {JobStore? store}) => JobCapacityGuard(
    store: store ?? this.store,
    capacity: ExecutionCapacityResolution.fromEnvironment({
      executionCapacityEnvVar: '$cap',
    }).capacity!,
  );

  /// Attaches a cap to every replica, rebuilding each scheduler against the
  /// same shared durable store.
  void applyCap(int cap) {
    schedulers = [
      for (final existing in schedulers)
        _newScheduler(
          existing.schedulerId,
          capacityGuard: guardFor(cap, store: store),
        ),
    ];
  }

  /// The one dedupe key every job in these tests uses. Deliberately simpler than
  /// the scheduler's production default so a test can name the key it enqueued
  /// under and be certain it is the same one a tick will look for.
  String capacityDedupeKey(WorkItem item) => '${item.workItemId}:capacity';

  /// Creates work items AND enqueues their jobs, sequentially.
  ///
  /// Enqueue is done here, once and non-concurrently, for the same reason
  /// [InMemoryJobStore] cannot arbitrate it: it has no active-dedupe unique
  /// constraint (PostgreSQL has `job_active_dedupe_unique`), so two replicas
  /// enqueueing the same work item at the same instant both find nothing and
  /// both insert. That is a property of this in-memory double, not of the
  /// capacity cap, and letting it into a capacity test would measure the
  /// wrong thing. These tests are about claim-time admission, so the queue
  /// starts out already full and deterministic.
  Future<List<Job>> enqueueAll(List<String> workItemIds) async {
    final queue = JobQueue(store: store, clock: _clock);
    final jobs = <Job>[];
    for (final id in workItemIds) {
      await itemRunnable(id);
      final result = await queue.enqueueIfAbsent(
        workItemId: id,
        definition: defaultImplementFeatureDefinition,
        dedupeKey: capacityDedupeKey(await workflowEngine.loadWorkItem(id)),
        instruction: 'work on $id',
        now: _clock().toUtc(),
      );
      jobs.add(result.job);
    }
    return jobs;
  }

  Future<List<Job>> jobs() => innerStore.listJobs();

  Future<List<String>> statesOf(String prefix) async {
    final all = (await jobs())
        .where((j) => j.workItemId.startsWith(prefix))
        .toList();
    return all.map((j) => '${j.workItemId}=${j.state.wire}').toList()..sort();
  }
}

/// Awaits every one of [futures], failing with a named diagnostic instead of
/// hanging until the framework's blanket 30 s timeout.
///
/// The concurrency tests deliberately hold executions open, so a bare
/// `Future.wait` that never resolves would report "test timed out" and say
/// nothing about which step stalled.
Future<void> settleAll(
  List<Future<Object?>> futures, {
  required String because,
  Duration timeout = const Duration(seconds: 10),
}) async {
  var pending = futures.length;
  if (pending == 0) return;
  for (final f in futures) {
    f.then((_) => pending--, onError: (_) => pending--);
  }
  final deadline = DateTime.now().add(timeout);
  while (pending > 0) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('timed out waiting for: $because');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// Counts capacity-denial records across the whole store.
///
/// The precise signal that a scheduler REFUSED work rather than merely having
/// not reached a job yet, which is what a test needs before it can claim the
/// cap did the work.
Future<int> capacityDenials(JobStore store) async {
  var count = 0;
  for (final job in await store.listJobs()) {
    for (final event in await store.readEvents(job.jobId)) {
      if (event.payload?['outcome'] == 'capacityDenied') count++;
    }
  }
  return count;
}

/// Resolves a cap exactly the way production does — through the environment
/// variable, never by constructing an [ExecutionCapacity] directly. Its
/// constructor is private precisely so that no test, and no caller, can hand
/// the guard a number that was not read from configuration.
ExecutionCapacity capacityOf(int cap) =>
    ExecutionCapacityResolution.fromEnvironment({
      executionCapacityEnvVar: '$cap',
    }).capacity!;

/// Lets pending event-loop work (parked ticks, store round trips) run until
/// [condition] holds, so a test never has to guess a fixed sleep.
///
/// Accepts a Future-valued condition so a test can wait on durable evidence —
/// an audit record, a persisted state — rather than on an in-memory counter.
Future<void> waitUntil(
  FutureOr<bool> Function() condition, {
  String? because,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('timed out waiting for: ${because ?? 'condition'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'settle.dart' show waitUntil;

/// The wait half of the reconcile-adoption settle, sized for the integration
/// tier.
///
/// Detached dispatch (F-237) moves completion work off the tick: a run
/// resolves and its continuation releases the job's claim on the event loop,
/// not inside any `tick()` a test can await. Observing that release needs a
/// poll, never a fixed sleep — and here that poll is a real Postgres
/// round-trip against a claim a real run releases only after a git worktree,
/// a coordinator drive and a platform-runner verification have finished,
/// while every other integration file competes for the same machine and the
/// same database. The spacing is therefore gentler than the unit tier's one
/// millisecond — the poll must not become a query storm — and the bound is
/// measured against the real cost of the work. A claim that never releases
/// is still a hard failure, not a skipped assertion.
///
/// Pass a store that narrows [JobStore.listJobs] the way the scheduler's own
/// store does: suites that share the database scope their listings to their
/// own rows, and handing the wait the unscoped store would make one suite
/// block on another suite's in-flight job.
///
/// For session-scoped Postgres stores the poll must ALSO run on an
/// INDEPENDENT `PersistenceDatabase` wrapper over the same `session.db` —
/// `PersistenceDatabase(db.db)`, never the harness's own `db`. The detached
/// run commits its durable tail inside `workerStore.inTransaction`, and a
/// `PersistenceDatabase` routes every query through its single active
/// transaction slot: a poll issued on the shared wrapper while the worker's
/// commit is open attaches to THAT transaction and dies with
/// `Session or transaction has already finished` the moment the commit
/// lands mid-poll. A second wrapper has a slot of its own, so the poll
/// always goes straight to the pool.
Future<void> waitForClaimRelease(
  JobStore jobStore, {
  Duration timeout = const Duration(minutes: 2),
  Duration spacing = const Duration(milliseconds: 25),
}) => waitUntil(
  () async {
    for (final job in await jobStore.listJobs()) {
      final held =
          job.state == JobState.claimed || job.state == JobState.running;
      if (held && await jobStore.readClaimForJob(job.jobId) != null) {
        return false;
      }
    }
    return true;
  },
  because: 'every in-flight job to release its claim for reconcile-adoption',
  timeout: timeout,
  spacing: spacing,
);

/// `settleHeldJobs` for the integration tier: waits for every currently-held
/// job's detached run to release its claim, then runs the tick that settles
/// it through reconcile-adoption — the two halves a production tick interval
/// provides between "the run ended" and "the job was adopted".
///
/// Dispatch is detached (F-237): a tick STARTS the execution and returns,
/// and the run's continuation drops the claim so the NEXT tick's
/// `_reconcileClaim` adopts the terminal worker execution. The claim going
/// absent is the durable signal the continuation ran — never a sleep.
///
/// The returned result is the ADOPTING tick's: a caller asserting
/// `dispatched` should use the result of the dispatching tick instead, kept
/// before this call. A caller that needs the state the run left behind
/// BEFORE the adopting tick's own passes move it (e.g. `agentFailed` before
/// the retry-return) should use [waitForClaimRelease], observe, then tick —
/// adopt and return are one pass inside a tick now.
Future<SchedulerTickResult> settleHeldJobs(
  JobStore jobStore,
  Scheduler scheduler, {
  Duration timeout = const Duration(minutes: 2),
  Duration spacing = const Duration(milliseconds: 25),
}) async {
  await waitForClaimRelease(jobStore, timeout: timeout, spacing: spacing);
  return scheduler.tick();
}

/// The durable tail a real worker commits before `run` resolves: the
/// terminal [WorkerExecution] row plus the stored [WorkerExecutionResult].
///
/// Mirrors `persistWorkerOutcome` in
/// `packages/scheduler/test/support/controlled_dispatcher.dart`, which the
/// package's own test suites consume but a test in `apps/server` cannot
/// import — only `lib/` is reachable across package boundaries.
///
/// Any [WorkerDispatch] test double that plays a completed run must persist
/// this pair. Under detached dispatch the returned future is never adopted
/// directly: the continuation only releases the claim, and the next tick's
/// `_reconcileClaim` -> `_adoptFromExecution` settles the job from the
/// durable worker record. A finished run that leaves no record can only be
/// requeued for want of a referenced execution — and re-dispatched on every
/// later tick.
Future<void> persistWorkerOutcome(
  WorkerStore store,
  WorkerExecutionRequest request,
  WorkerExecutionResult result,
) async {
  await store.saveWorkerExecution(
    WorkerExecution(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      repositoryPath: request.repositoryPath,
      requestedStartingRevision: request.startingRevision,
      requiredCapabilities: request.requiredCapabilities,
      status: result.status,
      cleanupPolicy: request.cleanupPolicy,
      workerId: result.workerId,
      workspaceId: result.workspaceId,
      agentExecutionId: result.agentExecutionId,
      cleanupStatus: result.cleanupStatus,
      failureCode: result.failureCode,
      reason: result.failureDetail,
      createdAt: result.startedAt,
      startedAt: result.startedAt,
      endedAt: result.endedAt,
    ),
  );
  // The scheduler's JobExecutionReference names the REQUEST's execution id,
  // so the stored result is keyed under it even when the dispatcher reports
  // a different one — `readResult(ref)` must hit for adoption to see the
  // reported agentExecutionId. The reported id stays on the record itself.
  final stored = result.workerExecutionId == request.workerExecutionId
      ? result
      : WorkerExecutionResult(
          workerExecutionId: request.workerExecutionId,
          workItemId: result.workItemId,
          status: result.status,
          workerId: result.workerId,
          workspaceId: result.workspaceId,
          startingRevision: result.startingRevision,
          startedAt: result.startedAt,
          endedAt: result.endedAt,
          cleanupStatus: result.cleanupStatus,
          failureCode: result.failureCode,
          failureDetail: result.failureDetail,
          agentExecutionId: result.agentExecutionId,
        );
  await store.saveResult(stored);
}

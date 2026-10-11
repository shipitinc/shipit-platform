import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/faulty_workflow_store.dart';
import 'support/file_host.dart';

/// A zombie reclaim that fails the JOB but leaves the WORK ITEM at
/// `agentExecuting` converts a recoverable reclaim into permanent, silent loss
/// of the work.
///
/// `triageDefectDefinition.entryStates` is `{designNotRequired, designApproved}`,
/// so a stranded item is never dispatched again no matter how long an operator
/// waits. QA showed exactly that: the job failed, capacity was released, and the
/// work item sat at `agent_executing` forever.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);
  final t1 = t0.add(const Duration(minutes: 11));
  final zombieStart = t0.subtract(const Duration(hours: 4, minutes: 47));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scheduler_reclaim_unstrand_');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// A work item parked in `agentExecuting` — the state QA observed stranded —
  /// behind a held job whose worker execution has been stuck since [startedAt]
  /// with nothing behind it.
  Future<({FileRestartHarness host, String executionId})> strandedHost({
    required DateTime startedAt,
    ExecutionLivenessProbe? probe,
  }) async {
    final first = FileRestartHarness(dir, clock: () => t0);
    await first.itemRunnable();
    await first.itemExecuting();
    final running = await first.plantRunningJob(t0);
    final executionId = running.executionReference!.workerExecutionId;
    await first.workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: executionId,
        workItemId: 'wi-1',
        repositoryPath: '${dir.path}/repo',
        requestedStartingRevision: 'deadbeef',
        requiredCapabilities: running.requiredCapabilities,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        workerId: 'w-1',
        startedAt: startedAt,
      ),
    );
    return (
      host: FileRestartHarness(dir, clock: () => t1, executionLiveness: probe),
      executionId: executionId,
    );
  }

  group('a reclaim moves the work item OUT of agentExecuting', () {
    test('the item lands on agentFailed — the only non-terminal exit the real '
        'transition table allows from agentExecuting', () async {
      final planted = await strandedHost(startedAt: zombieStart);

      final before = await planted.host.workflowEngine.loadWorkItem('wi-1');
      expect(
        before.state,
        WorkItemState.agentExecuting,
        reason: 'the state QA observed stranded',
      );

      await planted.host.scheduler.tick();

      final after = await planted.host.workflowEngine.loadWorkItem('wi-1');
      expect(
        after.state,
        WorkItemState.agentFailed,
        reason:
            'a zombie must not leave the work in a state no entry set '
            'contains, or it is undispatchable forever',
      );
      expect(
        after.isTerminal,
        isFalse,
        reason:
            'agentFailed is a correction gate, NOT a terminal state — '
            'this is a recoverable landing, not a cancellation',
      );
    });

    test(
      'the transition went through the real engine: it is recorded as an '
      'ACCEPTED agentExecuting -> agentFailed under the reclaim key',
      () async {
        final planted = await strandedHost(startedAt: zombieStart);

        await planted.host.scheduler.tick();

        final record = await planted.host.workflowStore
            .findTransitionByIdempotencyKey(
              'wi-1',
              'zombie-reclaim:${planted.executionId}',
            );
        expect(
          record,
          isNotNull,
          reason:
              'the reclaim must be attributable to '
              'the execution it reclaimed, not be an unexplained state change',
        );
        expect(record!.outcome, TransitionOutcome.accepted);
        expect(record.fromState, WorkItemState.agentExecuting);
        expect(record.toState, WorkItemState.agentFailed);
      },
    );

    test('the landing state is recoverable: agentFailed -> agentExecuting is a '
        'legal edge, so the work can be resumed rather than lost', () async {
      final planted = await strandedHost(startedAt: zombieStart);
      await planted.host.scheduler.tick();

      expect(
        (await planted.host.workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
      );

      // Resumed through the REAL engine and the REAL transition table. If
      // this edge did not exist, the landing state would be a dead end and
      // the reclaim would be permanent loss wearing a recoverable label.
      final resumed = await planted.host.workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
      );
      expect(resumed.state, WorkItemState.agentExecuting);
    });

    test('the cancelled/terminated escapes are deliberately NOT used: both are '
        'terminal, and either would make the loss permanent', () async {
      final planted = await strandedHost(startedAt: zombieStart);
      await planted.host.scheduler.tick();

      final after = await planted.host.workflowEngine.loadWorkItem('wi-1');
      expect(after.state, isNot(WorkItemState.cancelled));
      expect(after.state, isNot(WorkItemState.terminated));
      expect(
        after.isTerminal,
        isFalse,
        reason: 'a zombie is recoverable; a cancelled item is gone',
      );
    });
  });

  group('the reclaim is idempotent', () {
    test('replaying the whole reconciliation does not double-transition or '
        'resurrect the item', () async {
      final planted = await strandedHost(startedAt: zombieStart);

      await planted.host.scheduler.tick();
      final afterFirst = await planted.host.workflowEngine.loadWorkItem('wi-1');

      for (var i = 0; i < 3; i++) {
        await planted.host.scheduler.tick();
      }

      final after = await planted.host.workflowEngine.loadWorkItem('wi-1');
      expect(after.state, WorkItemState.agentFailed);
      expect(
        after.version,
        afterFirst.version,
        reason: 'a replay must not bump the item version again',
      );

      final job = (await planted.host.jobStore.listJobs()).single;
      expect(job.state, JobState.failed);
      expect((planted.host.dispatch as ControlledDispatcher).runs, isEmpty);
    });

    test(
      'the idempotency key collapses a retry that re-sends the same reclaim',
      () async {
        final planted = await strandedHost(startedAt: zombieStart);
        await planted.host.scheduler.tick();
        final afterFirst = await planted.host.workflowEngine.loadWorkItem(
          'wi-1',
        );

        // A retry after a partial write re-sends the identical request. The
        // durable engine must return the accepted outcome, not transition again.
        final retried = await planted.host.workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
          actor: const WorkflowActor(
            actorId: 'scheduler',
            actorType: ActorType.orchestrator,
          ),
          idempotencyKey: 'zombie-reclaim:${planted.executionId}',
        );

        expect(retried.state, WorkItemState.agentFailed);
        expect(retried.version, afterFirst.version);
      },
    );
  });

  group('the reclaim is safe against a concurrent writer', () {
    // NOTE on the `agentExecuting` pre-check in `_releaseWorkItem`.
    //
    // That pre-check (`if (item.state != agentExecuting) return;` before
    // attempting the transition) has NO failing mutation — removing it does not
    // break any test in this file. It is kept deliberately and its absence from
    // the mutation table is recorded here so a future reader does not "simplify"
    // it away on the grounds that no test covers it.
    //
    // WHY it exists even though the engine would reject the transition anyway:
    //  * it is the guard that makes the method's loop correct on RE-entry. When
    //    a concurrent writer has already taken the item out of `agentExecuting`,
    //    the first line of each attempt short-circuits BEFORE an idempotency-key
    //    lookup or a transition attempt. Removing it would push every concurrent
    //    case through the exception path instead, which is correct but noisy and
    //    slower under contention.
    //  * it keeps a replay from even constructing a transition request for an
    //    item that is no longer executing, which is the case a reclaim hits most
    //    often (the second and later ticks).
    //  * Its absence would be silently absorbed by the `WorkflowTransition-
    //    RejectedException` / `ConcurrentModificationException` handlers rather
    //    than failing loudly, so removing it looks free in the test suite while
    //    changing real behaviour.
    //
    // The low-severity N2 finding from review acknowledges this explicitly: the
    // disclosure was honest and no test is required. This comment is the record.
    test('an item another writer already moved is not fought over: no '
        'double-transition, the winner keeps its state', () async {
      final planted = await strandedHost(startedAt: zombieStart);

      // A real result arriving from the wedged path moves the item first.
      await planted.host.workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.agentResult,
      );
      final before = await planted.host.workflowEngine.loadWorkItem('wi-1');

      await planted.host.scheduler.tick();

      final after = await planted.host.workflowEngine.loadWorkItem('wi-1');
      expect(after.state, before.state);
      expect(after.version, before.version);
    });

    test(
      'the job still reaches terminal when the work item was already settled',
      () async {
        final planted = await strandedHost(startedAt: zombieStart);
        await planted.host.workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.agentResult,
        );

        await planted.host.scheduler.tick();

        final job = (await planted.host.jobStore.listJobs()).single;
        expect(
          job.state,
          JobState.failed,
          reason:
              'losing the race on the work '
              'item must not leave the job held',
        );
        expect(await planted.host.jobStore.readClaimForJob(job.jobId), isNull);
      },
    );
  });

  group('the write order is crash-safe', () {
    test(
      'the job is NEVER terminal before the work item is released: a fault at '
      'the work-item step must leave the job held so a later tick converges',
      () async {
        // This is the property the ORDER in `_reclaimZombie` exists for, and
        // it is asserted rather than left as a comment. Failing the job first
        // would be safe only if the process never died between the two writes;
        // a terminal job is never re-reconciled, so the item would be stranded
        // with no path back.
        final seeded = FileRestartHarness(dir, clock: () => t0);
        await seeded.itemRunnable();
        await seeded.itemExecuting();
        final running = await seeded.plantRunningJob(t0);
        await seeded.workerStore.saveWorkerExecution(
          WorkerExecution(
            workerExecutionId: running.executionReference!.workerExecutionId,
            workItemId: 'wi-1',
            repositoryPath: '${dir.path}/repo',
            requestedStartingRevision: 'deadbeef',
            requiredCapabilities: running.requiredCapabilities,
            status: WorkerExecutionStatus.agentExecuting,
            cleanupPolicy: WorkerCleanupPolicy.removeAlways,
            workerId: 'w-1',
            startedAt: zombieStart,
          ),
        );

        final faulty = FaultyTransitionStore(
          FileRestartHarness(dir, clock: () => t0).workflowStore,
        );
        final host = FileRestartHarness(
          dir,
          clock: () => t1,
          workflowStoreOverride: faulty,
        );

        await host.scheduler.tick().then((_) {}, onError: (_) {});

        expect(
          faulty.attempted,
          greaterThan(0),
          reason:
              'the fault must actually have been reached, or this test '
              'would pass for the wrong reason',
        );
        final job = (await host.jobStore.listJobs()).single;
        expect(
          job.isTerminal,
          isFalse,
          reason:
              'a terminal job is never reconciled again, so failing it '
              'before the work item is released would strand the work forever',
        );
      },
    );
  });

  group('the worker execution row is retired too', () {
    test('the stranded worker_execution reaches a terminal state instead of '
        'staying at agentExecuting forever', () async {
      final planted = await strandedHost(startedAt: zombieStart);
      expect(
        (await planted.host.workerStore.readWorkerExecution(
          planted.executionId,
        ))!.status,
        WorkerExecutionStatus.agentExecuting,
      );

      await planted.host.scheduler.tick();

      final after = await planted.host.workerStore.readWorkerExecution(
        planted.executionId,
      );
      expect(after, isNotNull);
      expect(
        after!.isTerminal,
        isTrue,
        reason:
            'the row kept asserting agentExecuting after the reclaim '
            'decided nothing was running — QA saw this directly',
      );
      expect(after.status, WorkerExecutionStatus.orphaned);
      expect(after.endedAt, isNotNull);
      expect(after.reason, contains('orphaned by scheduler zombie reclaim'));
      expect(
        after.reason,
        contains(planted.executionId),
        reason: 'the row must say WHICH execution it was stopped for',
      );
    });

    test(
      'cleanup is NOT claimed: the row stays honest about what is outstanding',
      () async {
        final planted = await strandedHost(startedAt: zombieStart);

        await planted.host.scheduler.tick();

        final after = await planted.host.workerStore.readWorkerExecution(
          planted.executionId,
        );
        // The reclaim ran no workspace cleanup, so it must not say it did.
        // Nothing in this repository consumes `cleanupMissing`, so leaving the
        // recorded value alone invents nothing and loses nothing.
        expect(after!.cleanupStatus, isNot(WorkerCleanupStatus.removed));
      },
    );

    test(
      'a worker execution another writer already terminated is left alone',
      () async {
        final planted = await strandedHost(startedAt: zombieStart);
        final open = (await planted.host.workerStore.readWorkerExecution(
          planted.executionId,
        ))!;
        await planted.host.workerStore.saveWorkerExecution(
          open.copyWith(
            status: WorkerExecutionStatus.executedPass,
            endedAt: t1,
            version: open.version + 1,
          ),
          expectedVersion: open.version,
        );

        await planted.host.scheduler.tick();

        final after = await planted.host.workerStore.readWorkerExecution(
          planted.executionId,
        );
        expect(
          after!.status,
          WorkerExecutionStatus.executedPass,
          reason:
              'the reclaim must not overwrite a verdict another writer '
              'already recorded',
        );
      },
    );
  });

  group('the job still reaches terminal, and nothing is dispatched', () {
    test(
      'the job is failed, the claim is released, and nothing re-dispatches',
      () async {
        final planted = await strandedHost(startedAt: zombieStart);

        await planted.host.scheduler.tick();

        final job = (await planted.host.jobStore.listJobs()).single;
        expect(job.state, JobState.failed);
        expect(job.isTerminal, isTrue);
        expect(await planted.host.jobStore.readClaimForJob(job.jobId), isNull);
        expect((planted.host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );
  });
}

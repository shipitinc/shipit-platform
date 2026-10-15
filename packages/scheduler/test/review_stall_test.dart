import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

/// A work item this lane can never complete an execution for must stop being
/// LAUNCHED, not merely stop being dispatched.
///
/// ## THE DEFECT, AS MEASURED
///
/// Live QA on 2026-10-15: two work items at 214 jobs each, four jobs a minute,
/// steady. Every cycle was `jobQueued → jobClaimed → jobDispatched →
/// jobCancelled`, and the cancellation carried the right conclusion verbatim —
/// "Stopping rather than spinning — a human should check why this item cannot
/// complete an execution" — into `scheduler_event.payloadJson`, where no
/// operator surface reads it.
///
/// The breaker's own count was already correct and already immune to re-minting.
/// It was stopping the JOB. `JobQueue.enqueueIfAbsent` yields a dedupe key the
/// moment its holder is `cancelled`, so with the key free the next tick minted a
/// fresh job, dispatched it, was superseded again, and the count — read across
/// every job the item has ever held — was still over the cap, so the fresh job
/// was cancelled on its FIRST supersession. Four ticks per cycle, one cycle per
/// job, forever.
///
/// ## WHY THESE TESTS ASSERT A COUNT
///
/// A test that asserts the item's final state passes either way: the item reads
/// `agent_completed` while the lane spins AND while it does not. The only thing
/// that distinguishes "stopped" from "still spinning" is how many jobs exist.
/// Every assertion below that matters is on a count.
///
/// ## WHY THE FIXTURE NEVER MOVES THE ITEM
///
/// The entry state is incidental and deliberately left at the harness default.
/// What makes the stall necessary is that the item does not progress while this
/// lane keeps trying, and a fixture that moved the item between attempts would
/// be testing the requeue path instead — which is covered, and must keep
/// working, by `supersession_requeue_test.dart`.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() => dir = Directory.systemTemp.createTempSync('review_stall'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// Every dispatch reports a supersession. The item is never touched, so this
  /// is indistinguishable from QA's "the coordinator refused the entry edge and
  /// nothing ran".
  WorkerExecutionResult superseded(WorkerExecutionRequest request) {
    final t = DateTime.utc(2026, 1, 1, 12);
    return WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: WorkerExecutionStatus.executedFail,
      workerId: 'w-scripted-1',
      workspaceId: 'ws-1',
      startingRevision: 'deadbeef',
      startedAt: t,
      endedAt: t,
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: WorkerFailureCode.agentFailed,
      failureDetail:
          '$supersededExecutionMarker Superseded execution: work item '
          '${request.workItemId} is not in a state this lane can begin from, so '
          'nothing ran and nothing was produced.',
      agentResultStatus: null,
      verificationPassed: null,
      changedFiles: const [],
      endingRevision: null,
    );
  }

  /// Drives [ticks] ticks against a fresh harness whose every dispatch is a
  /// supersession. Returns the harness AND the dispatcher, because the number of
  /// worker executions spent is half of what is being asserted.
  Future<({FileRestartHarness host, ControlledDispatcher dispatch})> spin({
    required int ticks,
  }) async {
    final dispatch = ControlledDispatcher()
      ..resultBuilder = (r) async => superseded(r);
    final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);
    await host.itemRunnable();
    for (var i = 0; i < ticks; i++) {
      await host.scheduler.tick();
    }
    return (host: host, dispatch: dispatch);
  }

  group('the producer stops, not just the job', () {
    test(
      'after N ticks exactly ONE job exists for the item, and no further tick '
      'mints a second',
      () async {
        final run = await spin(ticks: 12);
        final host = run.host;

        final jobs = await host.jobStore.listJobsForWorkItem('wi-1');
        expect(
          jobs,
          hasLength(1),
          reason:
              'this is the property that stops the bleeding. The item sits at '
              '${(await host.workflowStore.readWorkItem('wi-1')).state.wire} '
              'either way, so a state assertion cannot tell a stopped lane '
              'from a spinning one — only the number of jobs can. At the base '
              'revision this count grows by one every tick from the fourth '
              'onward, which is the 214-jobs-each QA measured.',
        );

        // And it is STABLE: three more ticks add nothing.
        for (var i = 0; i < 3; i++) {
          await host.scheduler.tick();
        }
        expect(
          await host.jobStore.listJobsForWorkItem('wi-1'),
          hasLength(1),
          reason: 'the count must be stable, not merely small at one instant',
        );
      },
    );

    test('no worker execution is spent once the stall has landed', () async {
      final run = await spin(ticks: 12);
      final before = run.dispatch.runs.length;
      for (var i = 0; i < 5; i++) {
        await run.host.scheduler.tick();
      }
      expect(
        run.dispatch.runs.length,
        before,
        reason:
            'a refused enqueue must not cost a dispatch. Each one is a real '
            'worker execution and a real capacity slot, which is the part of '
            'the churn that was never free',
      );
    });

    test(
      'the single surviving job records the break, and no attempt on it',
      () async {
        final run = await spin(ticks: 12);
        final job = (await run.host.jobStore.listJobsForWorkItem(
          'wi-1',
        )).single;
        expect(
          job.state,
          JobState.cancelled,
          reason: 'the one job the cap retired is the one that stays retired',
        );
        expect(job.cancelReason, contains('Stopping rather than spinning'));
        expect(
          job.attempt,
          1,
          reason: 'no attempt was consumed and none may be charged',
        );
      },
    );
  });

  group('the stall is reported where an operator surface can read it', () {
    test(
      'the tick names the item, its state and the deferrals it burned',
      () async {
        final dispatch = ControlledDispatcher()
          ..resultBuilder = (r) async => superseded(r);
        final host = FileRestartHarness(
          dir,
          clock: () => t0,
          dispatch: dispatch,
        );
        await host.itemRunnable();

        for (var i = 0; i < 4; i++) {
          await host.scheduler.tick();
        }
        final result = await host.scheduler.tick();

        expect(
          result.stalled,
          hasLength(1),
          reason:
              'the conclusion the breaker cancel reason already states has to '
              'arrive on a channel the composition root can act on. Before this '
              'existed it existed only in scheduler_event.payloadJson',
        );
        final stall = result.stalled.single;
        expect(stall.workItemId, 'wi-1');
        expect(stall.state, WorkItemState.designNotRequired);
        expect(stall.jobType, JobType.implementFeature);
        expect(stall.deferrals, 3);
        expect(
          stall.reason,
          contains('a human'),
          reason:
              'the reason is what an operator acts on, and the one fact this '
              'whole change exists to deliver is that a human is needed',
        );
      },
    );

    test(
      'the stall is reported on EVERY tick it holds, not only the first',
      () async {
        final run = await spin(ticks: 6);
        for (var i = 0; i < 3; i++) {
          final result = await run.host.scheduler.tick();
          expect(
            result.stalled,
            hasLength(1),
            reason:
                'an item that keeps refusing re-reports every tick, which is the '
                'intended signal: it is not going to fix itself, and a one-shot '
                'report is a report that gets read once and forgotten',
          );
        }
      },
    );
  });

  group('the stall is NOT a dead end', () {
    test('it lifts by itself the moment the work item actually MOVES, and this '
        'lane mints a fresh job for it', () async {
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => superseded(r);
      final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);
      await host.itemRunnable();
      for (var i = 0; i < 5; i++) {
        await host.scheduler.tick();
      }
      expect(
        await host.jobStore.listJobsForWorkItem('wi-1'),
        hasLength(1),
        reason: 'precondition: the stall is holding',
      );

      // A real move: out to execution and back again, which is the shortest
      // legal round trip between two states this definition dispatches from.
      // `agentFailed -> designNotRequired` is the edge B4's retry return
      // exists to honour, so this path is itself under test by
      // `retry_return_to_entry_state_test.dart`.
      const hop = {'agentAvailable': true, 'capabilitiesMatch': true};
      await host.workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        context: hop,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
      );
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.designNotRequired,
        reason: 'precondition: the item really is back where it can run',
      );

      final after = await host.scheduler.tick();
      expect(
        after.stalled,
        isEmpty,
        reason:
            'the recorded diagnosis described an item that had not moved. It '
            'has now moved, so the diagnosis is stale and this lane owes it '
            'a job — refusing here is how a stall becomes a permanent dead '
            'end, and a permanently-stranded item is worse than a churn',
      );
      expect(
        await host.jobStore.listJobsForWorkItem('wi-1'),
        hasLength(2),
        reason: 'the cancelled job released the key; a real one took its place',
      );
    });

    test('a genuinely MOVING item is never stalled at all — the legitimate '
        'requeue keeps working', () async {
      // This is `supersession_requeue_test.dart`'s scenario, re-asserted
      // here because the stall condition is "the cap fired AND the item has
      // not moved", and a regression that dropped the second half would
      // strand every legitimately-deferred item. The requeue must survive.
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => superseded(r);
      final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);
      await host.itemRunnable();
      final job = await host.enqueueJob();

      for (var i = 0; i < 3; i++) {
        await host.scheduler.tick();
        expect(
          (await host.jobStore.readJob(job.jobId))!.state,
          JobState.queued,
          reason: 'deferral ${i + 1} of 3 must still defer, not stop',
        );
      }
      final result = await host.scheduler.tick();
      expect(
        result.stalled,
        isEmpty,
        reason:
            'the cap fired on this job, but the deferral count alone is not '
            'the stall condition — an item that never moved and an item that '
            'is genuinely being re-queued look identical on that number '
            'alone, and only the first may be stopped',
      );
    });
  });

  group('the stall cannot re-derive itself', () {
    test(
      'withdrawing the queued job behind a stall does not record another cap '
      'firing, so the stall cannot feed on its own withdrawal',
      () async {
        final run = await spin(ticks: 12);
        final host = run.host;

        // Re-enqueue by hand, exactly as another scheduler sharing this
        // JobStore would. The stall must refuse to dispatch it AND must not
        // write a second `supersessionCapFired`, or each refusal would be
        // evidence for the next one and the loop would be immortal.
        final before = (await host.jobStore.listJobsForWorkItem('wi-1')).length;
        await host.scheduler.queue.enqueueIfAbsent(
          workItemId: 'wi-1',
          definition: defaultImplementFeatureDefinition,
          dedupeKey: host.dedupeKey,
          instruction: 'Implement the feature.',
          now: t0,
        );
        expect(
          await host.jobStore.listJobsForWorkItem('wi-1'),
          hasLength(before + 1),
          reason: 'precondition: an outside writer did mint one',
        );

        await host.scheduler.tick();
        final rows = await host.jobStore.listJobsForWorkItem('wi-1');
        expect(rows.last.state, JobState.cancelled);
        expect(
          rows.last.cancelReason,
          startsWith('stalled:'),
          reason:
              'withdrawn under its own vocabulary. A job withdrawn by a stall '
              'is NOT superseded — the item is exactly where the work is',
        );
        expect(
          run.dispatch.runs.length,
          lessThanOrEqualTo(4),
          reason: 'an outside-minted job is refused, never dispatched',
        );

        // Still exactly the one original job plus the withdrawn outsider, and
        // no further growth on more ticks.
        for (var i = 0; i < 3; i++) {
          await host.scheduler.tick();
        }
        expect(
          await host.jobStore.listJobsForWorkItem('wi-1'),
          hasLength(before + 1),
        );
      },
    );
  });
}

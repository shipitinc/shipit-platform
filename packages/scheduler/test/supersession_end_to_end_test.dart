import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/git_repo_fixture.dart';
import 'support/scheduler_host.dart';

/// End-to-end proof that a supersession survives the crossing and is acted on.
///
/// Everything below the scheduler is REAL here: the real `ExecutionCoordinator`
/// raises the real `WorkItemSupersededException`, the real `LocalWorker` catches
/// it as a plain `Object` and flattens it into a generic `executedFail` /
/// `agentFailed` detail, and the real scheduler adopts it. That flattening is
/// the reason this suite exists at all — the classifier reaches the scheduler
/// ONLY as a string, so the thing worth testing is that the string survives
/// and is still recognised after every layer it passes through.
///
/// The scripted-dispatcher suite (`supersession_requeue_test.dart`) covers the
/// (a)/(b) judgement exhaustively. It cannot prove the crossing, because it
/// injects the failure detail directly and so assumes the very thing at risk.
void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late SchedulerHost host;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('supersession_e2e_test');
    repo = GitRepoFixture.create('${temp.path}/repo');
    host = SchedulerHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      jobStore: InMemoryJobStore(),
      // `designRejected` is an entry state for a design revision job and is NOT
      // an entry state for an execution: the coordinator's
      // `designRejected -> agentExecuting` is not an edge in the transition
      // table, so it refuses — deterministically, with no race and no timing.
      definition: designRevisionDefinition,
      workerCapabilities: const {
        WorkerCapability.linux,
        WorkerCapability.penpotWrite,
        WorkerCapability.visualDesign,
      },
    );
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  /// Parks the item at `designRejected` the way a human rejecting a design does.
  Future<void> itemRejectedByHuman() async {
    await host.itemBlocked(workItemId: 'wi-1');
    await host.workflowEngine.resolveHumanDecision(
      decisionId: (await host.workflowStore.readWorkItem(
        'wi-1',
      )).blockingHumanDecisionId!,
      choice: HumanDecisionChoice.reject,
      decider: 'hum@shipit.platform',
      rationale: 'design rejected: revisit the layout',
      signature: DecisionSignature(
        algorithm: 'ed25519',
        publicKey: 'test-public-key',
        signature: 'sig-reject-wi-1',
        signedAt: DateTime.now().toUtc(),
      ),
    );
  }

  test('a superseded design-revision execution is REQUEUED, consumes no '
      'attempt, and moved no work item', () async {
    await itemRejectedByHuman();
    expect(
      (await host.workflowStore.readWorkItem('wi-1')).state,
      WorkItemState.designRejected,
    );

    final tick = await host.scheduler.tick();

    expect(tick.enqueued, hasLength(1), reason: 'the item is probeable');
    final job = (await host.jobStore.listJobs()).single;
    expect(tick.dispatched, [job.jobId]);

    // The verdict.
    final requeued = (await host.jobStore.readJob(job.jobId))!;
    expect(
      requeued.state,
      JobState.queued,
      reason:
          'designRejected still accepts a design revision job, so this job is '
          'wanted — it lost a race it should be allowed to run again, and a '
          'terminal `failed` would assert an execution that never happened',
    );
    expect(requeued.failure, isNull);
    expect(requeued.attempt, 1, reason: 'no execution started, so no budget');
    expect(requeued.maxAttempts, designRevisionDefinition.maxAttempts);

    // The reason is readable and is about the MOVE, not about an agent.
    final events = await host.jobStore.readEvents(job.jobId);
    final deferral = events.singleWhere(
      (e) => e.payload?['supersessionDeferred'] == true,
    );
    final reason = deferral.payload!['reason']! as String;
    expect(reason, contains('design_rejected'));
    expect(reason, contains('Nothing ran and nothing was produced'));
    expect(
      events.map((e) => e.type),
      isNot(contains(SchedulerEventType.jobFailed)),
      reason: 'nothing about this run says the agent failed',
    );
  });

  test(
    'nothing ran: the worker execution record shows the supersession and '
    'there is no agent execution row, no session, and no live session',
    () async {
      await itemRejectedByHuman();
      await host.scheduler.tick();
      final job = (await host.jobStore.listJobs()).single;

      // The worker row is durable evidence that the marker really crossed.
      final execution = await host.workerStore.readWorkerExecution(
        'wx-${job.jobId}',
      );
      expect(execution!.status, WorkerExecutionStatus.executedFail);
      expect(
        execution.reason,
        startsWith(supersededExecutionMarker),
        reason:
            'this is the string the coordinator threw, flattened by the worker. '
            'If it stopped matching here, the scheduler would be back to failing '
            'these terminally and nothing would say so',
      );
      expect(execution.reason, contains('design_rejected'));
      expect(
        execution.agentExecutionId,
        isNotNull,
        reason:
            'the worker mints this id BEFORE it calls the coordinator, so '
            'its presence proves nothing and must not be read as a run',
      );

      // And the thing that actually ran: nothing.
      expect(
        await host.executionStore.readExecutionOrNull('agx-wx-${job.jobId}'),
        isNull,
        reason:
            'no execution row — the refusal happened before one was written',
      );
      expect(
        await host.executionStore.readEvents('agx-wx-${job.jobId}'),
        isEmpty,
      );
      expect(host.coordinator.liveSessionCount, 0);
      expect(host.session.status, AgentSessionStatus.starting);
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.designRejected,
        reason:
            'this change never moves a work item — it belongs to whoever moved '
            'it, which here is the human who rejected the design',
      );
    },
  );

  test(
    'and a later tick really does retry it against the same state',
    () async {
      await itemRejectedByHuman();
      await host.scheduler.tick();
      final job = (await host.jobStore.listJobs()).single;

      // The same row is dispatched again — no second job, no second key.
      final second = await host.scheduler.tick();
      expect(second.enqueued, isEmpty);
      expect(second.dispatched, [job.jobId]);
      expect(await host.jobStore.listJobs(), hasLength(1));
    },
  );
}

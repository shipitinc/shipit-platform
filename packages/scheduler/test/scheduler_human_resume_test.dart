import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/git_repo_fixture.dart';
import 'support/scheduler_host.dart';

void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late SchedulerHost host;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('scheduler_resume_test');
    repo = GitRepoFixture.create('${temp.path}/repo');
    host = SchedulerHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      jobStore: InMemoryJobStore(),
    );
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  test('a blocked item parks with zero job pressure and, once the human '
      'resolves the gate, continues from its PERSISTED lifecycle without '
      'replaying history', () async {
    final a = await host.itemBlocked(workItemId: 'wi-a');
    final blockedId = a.blockingHumanDecisionId!;

    // While blocked the scheduler takes no action at all.
    final firstTick = await host.scheduler.tick();
    expect(firstTick.enqueued, isEmpty);
    expect(await host.jobStore.listJobsForWorkItem('wi-a'), isEmpty);
    expect(firstTick.deferred, isEmpty);

    // The human resolves the design gate -> designApproved (runnable).
    final resumed = await host.humanApproves(workItemId: 'wi-a');
    expect(resumed.state, WorkItemState.designApproved);
    expect(resumed.workItemId, 'wi-a');

    // The next tick schedules a NEW job (new workflow-state based dedupe
    // key) and executes it.
    final tick = host.scheduler.tick();
    await host.session.awaitingGate;
    host.session.release();
    await tick;

    final jobs = await host.jobStore.listJobsForWorkItem('wi-a');
    expect(jobs, hasLength(1));
    final job = jobs.single;
    expect(job.state, JobState.succeeded);
    expect(job.dedupeKey, contains('design_approved'));

    // History was preserved, never replayed: exactly one record per state,
    // flowing through the human-approved design gate and then the execution
    // that the scheduler drove to completion.
    final history = await host.workflowEngine.transitionHistory('wi-a');
    expect(history.map((r) => r.toState), [
      WorkItemState.planning,
      WorkItemState.planned,
      WorkItemState.designRequired,
      WorkItemState.designInReview,
      WorkItemState.waitingForHumanDecision,
      WorkItemState.designApproved,
      WorkItemState.agentExecuting,
      WorkItemState.agentCompleted,
    ]);

    // The blocking decision itself is durably resolved.
    final decisions = await host.workflowStore.readHumanDecisionsForWorkItem(
      'wi-a',
    );
    expect(decisions, hasLength(1));
    expect(decisions.single.decisionId, blockedId);
    expect(decisions.single.status, HumanDecisionStatus.resolved);
    expect(decisions.single.choice, HumanDecisionChoice.approve);
  });
}

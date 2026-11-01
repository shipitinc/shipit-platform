import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/controlled_dispatcher.dart';
import 'support/settle.dart';

/// Automatic paid-model escalation on provider failure.
///
/// The chain under test: a `timedOut` worker result carrying
/// [providerFailureMarker] -> `RetryPolicy` transient -> `_adopt` bumps
/// `WorkItem.metadata['escalationIndex']` BEFORE the retry is scheduled ->
/// the retry's dispatch selects `chain[1]` via [modelRuntimeConfig].
/// Ordinary failures — work that ran and hung — must NEVER take this path.
void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  ModelPolicy twoStepChain() => ModelPolicy(
    role: AgentRole.implementer,
    chain: const [
      ModelStep(modelId: 'opencode/free-tier', provider: 'opencode'),
      ModelStep(modelId: 'opencode/paid-tier', provider: 'opencode'),
    ],
    version: 1,
    updatedAt: DateTime.utc(2026, 1, 1),
    updatedByDecisionId: 'test',
  );

  WorkerExecutionResult outcome(
    WorkerExecutionRequest request, {
    required WorkerExecutionStatus status,
    String? detail,
  }) {
    final t = DateTime.now().toUtc();
    return WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: status,
      workerId: 'w-scripted-1',
      workspaceId: 'ws',
      startingRevision: request.startingRevision,
      startedAt: t,
      endedAt: t,
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: status == WorkerExecutionStatus.executedPass
          ? WorkerFailureCode.none
          : WorkerFailureCode.timedOut,
      failureDetail: detail,
    );
  }

  const providerDead =
      'agent session timed out; '
      '${providerFailureMarker}the runtime emitted no output at all — '
      '0 message chunks, 0 tool calls, 0 tokens';

  test('provider failure -> escalationIndex+1 -> retry dispatch picks '
      'chain[1]', () async {
    var now = t0;
    final host = _Host(policy: twoStepChain(), clock: () => now);
    var call = 0;
    host.dispatch.resultBuilder = (request) {
      call++;
      return outcome(
        request,
        status: call == 1
            ? WorkerExecutionStatus.timedOut
            : WorkerExecutionStatus.executedPass,
        detail: call == 1 ? providerDead : null,
      );
    };

    await host.itemRunnable();
    await host.scheduler.tick();
    expect(
      host.dispatch.runs.single.runtimeConfig?['model'],
      'opencode/free-tier',
      reason: 'first dispatch selects chain[0]',
    );
    await settleHeldJobs(host.jobStore, host.scheduler);

    var job = (await host.jobStore.listJobs()).single;
    expect(job.state, JobState.retryWaiting);
    expect(await host.escalationIndex(), 1);

    // Past the retry delay the job is claimed again — against the paid step.
    now = t0.add(const Duration(minutes: 2));
    await host.scheduler.tick();
    expect(host.dispatch.runs, hasLength(2));
    expect(
      host.dispatch.runs.last.runtimeConfig?['model'],
      'opencode/paid-tier',
    );
    expect(host.dispatch.runs.last.runtimeConfig?['escalationIndex'], '1');
    await settleHeldJobs(host.jobStore, host.scheduler);
    job = (await host.jobStore.listJobs()).single;
    expect(job.state, JobState.succeeded);
  });

  test(
    'an ordinary timeout — work that ran and hung — does NOT escalate',
    () async {
      var now = t0;
      final host = _Host(policy: twoStepChain(), clock: () => now);
      var call = 0;
      host.dispatch.resultBuilder = (request) {
        call++;
        return outcome(
          request,
          status: call == 1
              ? WorkerExecutionStatus.timedOut
              : WorkerExecutionStatus.executedPass,
          detail: 'agent session timed out',
        );
      };

      await host.itemRunnable();
      await host.scheduler.tick();
      await settleHeldJobs(host.jobStore, host.scheduler);

      expect(
        (await host.jobStore.listJobs()).single.state,
        JobState.retryWaiting,
      );
      expect(
        await host.escalationIndex(),
        0,
        reason:
            'a plain timeout carries no marker: the work failed, not the '
            'provider, and the paid tier must not be spent on it.',
      );

      now = t0.add(const Duration(minutes: 2));
      await host.scheduler.tick();
      expect(
        host.dispatch.runs.last.runtimeConfig?['model'],
        'opencode/free-tier',
      );
    },
  );

  test(
    'the chain bound is respected: a single-step policy never escalates',
    () async {
      var now = t0;
      final host = _Host(
        policy: ModelPolicy(
          role: AgentRole.implementer,
          chain: const [
            ModelStep(modelId: 'opencode/free-tier', provider: 'opencode'),
          ],
          version: 1,
          updatedAt: DateTime.utc(2026, 1, 1),
          updatedByDecisionId: 'test',
        ),
        clock: () => now,
      );
      host.dispatch.resultBuilder = (request) => outcome(
        request,
        status: WorkerExecutionStatus.timedOut,
        detail: providerDead,
      );

      await host.itemRunnable();
      await host.scheduler.tick();
      await settleHeldJobs(host.jobStore, host.scheduler);

      expect(await host.escalationIndex(), 0);
    },
  );

  test('escalation stops at the top of the chain: a second provider failure '
      'leaves the index at the ceiling', () async {
    var now = t0;
    final host = _Host(policy: twoStepChain(), clock: () => now);
    host.dispatch.resultBuilder = (request) => outcome(
      request,
      status: WorkerExecutionStatus.timedOut,
      detail: providerDead,
    );

    await host.itemRunnable();
    await host.scheduler.tick();
    await settleHeldJobs(host.jobStore, host.scheduler);
    expect(await host.escalationIndex(), 1);

    // Retry also dies on the provider — index stays at the ceiling of 1.
    now = t0.add(const Duration(minutes: 2));
    await host.scheduler.tick();
    await settleHeldJobs(host.jobStore, host.scheduler);

    expect(await host.escalationIndex(), 1);
    expect((await host.jobStore.listJobs()).single.state, JobState.failed);
  });
}

class _Host {
  _Host({required ModelPolicy policy, DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    workflowStore = InMemoryWorkflowStore();
    engine = DurableWorkflowEngine(store: workflowStore);
    jobStore = InMemoryJobStore();
    workerStore = InMemoryWorkerStore();
    dispatch = ControlledDispatcher(workerStore: workerStore);
    policyStore = InMemoryModelPolicyStore()..addPolicy(policy);
    modelSelection = ModelSelectionService(policyStore);
    scheduler = Scheduler(
      schedulerId: 'sched-1',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: defaultImplementFeatureDefinition,
      workload: _workload,
      clock: this.clock,
      modelSelection: modelSelection,
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine engine;
  late InMemoryJobStore jobStore;
  late InMemoryWorkerStore workerStore;
  late ControlledDispatcher dispatch;
  late InMemoryModelPolicyStore policyStore;
  late ModelSelectionService modelSelection;
  late Scheduler scheduler;
  final DateTime Function() clock;

  Future<WorkItem> itemRunnable() async {
    await engine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'runnable item',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    await engine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await engine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/calc'},
    );
    return engine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  Future<int> escalationIndex() async {
    final item = await workflowStore.readWorkItem('wi-1');
    return item.metadata?['escalationIndex'] as int? ?? 0;
  }
}

const _workload = SchedulerWorkload(
  repositoryPath: '/repo',
  startingRevision: 'deadbeef',
  timeoutSeconds: 60,
  runtimeTypeId: 'fake-runtime',
);

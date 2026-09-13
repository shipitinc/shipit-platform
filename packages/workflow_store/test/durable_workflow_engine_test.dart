import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

const _workItemId = '123e4567-e89b-12d3-a456-426614174001';
const _orch = WorkflowActor(
  actorId: 'orch-1',
  actorType: ActorType.orchestrator,
);
const _reviewer = WorkflowActor(
  actorId: 'reviewer-2',
  actorType: ActorType.engineeringReviewer,
);
const _qaExecutor = WorkflowActor(
  actorId: 'qa-1',
  actorType: ActorType.qaExecutor,
);

AgentResult _completedResult() => AgentResult(
  resultId: 'res-1',
  sessionId: 'ses-1',
  workItemId: _workItemId,
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: AgentDiagnostics(
    exitCode: 0,
    durationMs: 100,
    toolCalls: 1,
    errors: const [],
    warnings: const [],
  ),
  structuredResult: const {},
  completedAt: DateTime.now(),
);

QAContract _qaContract() => QAContract(
  contractId: 'qa-1',
  workItemCategory: WorkItemCategory.feature,
  gates: [
    QAGateDefinition(
      gateId: 'static-analysis',
      type: 'static-analysis',
      required: true,
      config: const {},
      evidenceTypes: const ['test-report'],
    ),
    QAGateDefinition(
      gateId: 'unit-tests',
      type: 'unit-tests',
      required: true,
      config: const {},
      evidenceTypes: const ['test-report'],
    ),
  ],
  version: '1.0.0',
  createdAt: DateTime.parse('2024-03-01T00:00:00Z'),
  updatedAt: DateTime.parse('2024-03-01T00:00:00Z'),
);

List<QAGateResult> _passingGateResults() => [
  QAGateResult(
    gateId: 'static-analysis',
    workItemId: _workItemId,
    status: QAGateStatus.passed,
    evidence: const [],
    evaluatedAt: DateTime.parse('2024-03-02T13:00:00Z'),
  ),
  QAGateResult(
    gateId: 'unit-tests',
    workItemId: _workItemId,
    status: QAGateStatus.passed,
    evidence: const [],
    evaluatedAt: DateTime.parse('2024-03-02T13:00:00Z'),
  ),
];

DecisionSignature _sig() => DecisionSignature(
  algorithm: 'Ed25519',
  publicKey: 'key-1',
  signature: 'sig-1',
  signedAt: DateTime.now(),
);

Future<void> pushToDesignInReview(DurableWorkflowEngine engine) async {
  final result = await engine.transition(
    workItemId: _workItemId,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
  );
  expect(result.state, WorkItemState.planning);

  await engine.transition(
    workItemId: _workItemId,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
    context: {'featureRef': 'FEAT-001'},
  );
  await engine.transition(
    workItemId: _workItemId,
    to: WorkItemState.designRequired,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
    context: {'designContractId': 'dc-1'},
  );
  await engine.transition(
    workItemId: _workItemId,
    to: WorkItemState.designInReview,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
    context: {'designContractStatus': DesignContractStatus.underReview},
  );
  expect(
    (await engine.loadWorkItem(_workItemId)).state,
    WorkItemState.designInReview,
  );
}

void main() {
  group('DurableWorkflowEngine (InMemory)', () {
    late WorkflowStore store;
    late DurableWorkflowEngine engine;

    setUp(() {
      store = InMemoryWorkflowStore();
      engine = DurableWorkflowEngine(store: store);
    });

    test('golden path draft -> completed through all gates', () async {
      await engine.createWorkItem(
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Golden path',
        workItemId: _workItemId,
        featureRef: 'FEAT-001',
      );

      await pushToDesignInReview(engine);

      final pending = await engine.requestHumanDecision(
        workItemId: _workItemId,
        decisionType: HumanDecisionType.designApproval,
        question: 'Approve the design?',
        actor: _orch,
      );
      expect(pending.status, HumanDecisionStatus.pending);
      expect(
        (await engine.loadWorkItem(_workItemId)).blockingHumanDecisionId,
        pending.decisionId,
      );
      expect(await engine.isWaitingForHumanDecision(_workItemId), isTrue);

      final approved = await engine.resolveHumanDecision(
        decisionId: pending.decisionId,
        choice: HumanDecisionChoice.approve,
        decider: 'alice@example.com',
        rationale: 'Looks good',
        signature: _sig(),
      );
      expect(approved.state, WorkItemState.designApproved);
      expect(approved.blockingHumanDecisionId, isNull);

      final result = await engine.transition(
        workItemId: _workItemId,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: {'agentAvailable': true, 'capabilitiesMatch': true},
      );
      expect(result.state, WorkItemState.agentExecuting);

      await engine.transition(
        workItemId: _workItemId,
        to: WorkItemState.agentCompleted,
        trigger: TransitionTrigger.agentResult,
        actor: _orch,
        context: {'qaContractId': 'qa-1', 'agentResult': _completedResult()},
      );
      await engine.transition(
        workItemId: _workItemId,
        to: WorkItemState.reviewInProgress,
        trigger: TransitionTrigger.agentResult,
        actor: _orch,
        context: {'agentResult': _completedResult()},
      );

      final review = await engine.requestHumanDecision(
        workItemId: _workItemId,
        decisionType: HumanDecisionType.engineeringReview,
        question: 'Approve the implementation?',
        actor: _reviewer,
        extraContext: {'producerActorId': 'agent-1'},
      );
      final reviewed = await engine.resolveHumanDecision(
        decisionId: review.decisionId,
        choice: HumanDecisionChoice.approve,
        decider: 'bob@example.com',
        rationale: 'Implementation approved',
        signature: _sig(),
      );
      expect(reviewed.state, WorkItemState.reviewApproved);

      await engine.transition(
        workItemId: _workItemId,
        to: WorkItemState.qaInProgress,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: {'qaContractId': 'qa-1'},
      );
      await engine.transition(
        workItemId: _workItemId,
        to: WorkItemState.qaPassed,
        trigger: TransitionTrigger.agentResult,
        actor: _qaExecutor,
        context: {
          'gateResults': _passingGateResults(),
          'qaContract': _qaContract(),
        },
      );

      final qaApproval = await engine.requestHumanDecision(
        workItemId: _workItemId,
        decisionType: HumanDecisionType.humanQaApproval,
        question: 'Confirm QA sign-off?',
        actor: _orch,
      );
      final completed = await engine.resolveHumanDecision(
        decisionId: qaApproval.decisionId,
        choice: HumanDecisionChoice.approve,
        decider: 'carol@example.com',
        rationale: 'QA sign-off confirmed',
        signature: _sig(),
      );
      expect(completed.state, WorkItemState.completed);
      expect(completed.completedAt, isNotNull);

      final history = await engine.transitionHistory(_workItemId);
      expect(history, isNotEmpty);
      expect(
        history.any((r) => r.outcome == TransitionOutcome.rejected),
        isFalse,
      );
      expect(
        history.any((r) => r.toState == WorkItemState.completed),
        isTrue,
        reason: 'the final human approval must produce a completed record',
      );
    });

    test(
      'rejected human approvals recover without deadlocking the gate',
      () async {
        await engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Reject route',
          workItemId: _workItemId,
        );
        await pushToDesignInReview(engine);
        await engine.resolveHumanDecision(
          decisionId: (await engine.requestHumanDecision(
            workItemId: _workItemId,
            decisionType: HumanDecisionType.designApproval,
            actor: _orch,
          )).decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'alice@example.com',
          rationale: 'Approved',
          signature: _sig(),
        );
        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.agentCompleted,
          trigger: TransitionTrigger.agentResult,
          actor: _orch,
          context: {'qaContractId': 'qa-1', 'agentResult': _completedResult()},
        );
        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.reviewInProgress,
          trigger: TransitionTrigger.agentResult,
          actor: _orch,
          context: {'agentResult': _completedResult()},
        );
        await engine.resolveHumanDecision(
          decisionId: (await engine.requestHumanDecision(
            workItemId: _workItemId,
            decisionType: HumanDecisionType.engineeringReview,
            actor: _reviewer,
            extraContext: {'producerActorId': 'agent-1'},
          )).decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'bob@example.com',
          rationale: 'Approved',
          signature: _sig(),
        );
        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.qaInProgress,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: {'qaContractId': 'qa-1'},
        );
        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.qaPassed,
          trigger: TransitionTrigger.agentResult,
          actor: _qaExecutor,
          context: {
            'gateResults': _passingGateResults(),
            'qaContract': _qaContract(),
          },
        );

        final approval = await engine.requestHumanDecision(
          workItemId: _workItemId,
          decisionType: HumanDecisionType.humanQaApproval,
          question: 'Confirm QA sign-off?',
          actor: _orch,
        );
        final reworked = await engine.resolveHumanDecision(
          decisionId: approval.decisionId,
          choice: HumanDecisionChoice.reject,
          decider: 'dave@example.com',
          rationale: 'A follow-up defect was found',
          signature: _sig(),
        );
        expect(reworked.state, WorkItemState.agentExecuting);
        expect(reworked.blockingHumanDecisionId, isNull);
        expect(await engine.isWaitingForHumanDecision(_workItemId), isFalse);

        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.agentCompleted,
          trigger: TransitionTrigger.agentResult,
          actor: _orch,
          context: {'qaContractId': 'qa-1', 'agentResult': _completedResult()},
        );
        expect(
          (await engine.loadWorkItem(_workItemId)).state,
          WorkItemState.agentCompleted,
        );
      },
    );

    test(
      'rejected transition records a rejected attempt and does not move state',
      () async {
        await engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Rejected',
          workItemId: _workItemId,
        );

        await expectLater(
          engine.transition(
            workItemId: _workItemId,
            to: WorkItemState.agentCompleted,
            trigger: TransitionTrigger.systemEvent,
            actor: _orch,
          ),
          throwsA(isA<WorkflowTransitionRejectedException>()),
        );

        final history = await engine.transitionHistory(_workItemId);
        expect(history, hasLength(1));
        expect(history.single.outcome, TransitionOutcome.rejected);
        expect(
          (await engine.loadWorkItem(_workItemId)).state,
          WorkItemState.draft,
        );
      },
    );

    test('same-state transition is rejected and recorded', () async {
      await engine.createWorkItem(
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Same state',
        workItemId: _workItemId,
      );
      await expectLater(
        engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.draft,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
        ),
        throwsA(isA<WorkflowTransitionRejectedException>()),
      );
    });

    test(
      'idempotent transitions replay the prior outcome under the same key',
      () async {
        await engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Idempotent',
          workItemId: _workItemId,
        );

        final first = await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          idempotencyKey: 'k1',
        );
        expect(first.state, WorkItemState.planning);

        final second = await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          idempotencyKey: 'k1',
        );
        expect(second.state, WorkItemState.planning);

        final history = await engine.transitionHistory(_workItemId);
        expect(history.where((r) => r.idempotencyKey == 'k1').length, 1);
        expect(
          (await engine.loadWorkItem(_workItemId)).state,
          WorkItemState.planning,
        );
      },
    );

    test(
      'resolving a decision is idempotent after the gate advances',
      () async {
        await engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Resume resolve',
          workItemId: _workItemId,
        );
        await pushToDesignInReview(engine);
        final pending = await engine.requestHumanDecision(
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          actor: _orch,
        );

        final first = await engine.resolveHumanDecision(
          decisionId: pending.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'alice@example.com',
          rationale: 'Approved on first attempt',
          signature: _sig(),
        );
        expect(first.state, WorkItemState.designApproved);

        final replay = await engine.resolveHumanDecision(
          decisionId: pending.decisionId,
          choice: HumanDecisionChoice.reject,
          decider: 'other@example.com',
          rationale: 'Should be ignored',
          signature: _sig(),
        );
        expect(replay.state, WorkItemState.designApproved);
        final decision = await store.readHumanDecision(pending.decisionId);
        expect(decision.choice, HumanDecisionChoice.approve);
        expect(decision.decider, 'alice@example.com');
      },
    );

    test(
      'concurrent writers are rejected by compare-and-swap on version',
      () async {
        await engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'CAS',
          workItemId: _workItemId,
        );
        final stale = await store.readWorkItem(_workItemId);
        expect(stale.version, 1);

        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
        );

        await expectLater(
          store.saveWorkItem(stale, expectedVersion: stale.version),
          throwsA(isA<ConcurrentModificationException>()),
        );
      },
    );
  });

  group('DurableWorkflowEngine (FileJson) process-exit resume', () {
    late Directory tempDir;
    late File storeFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('shipit-store-');
      storeFile = File('${tempDir.path}/store.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'a fresh engine on the same file resumes execution after the gate',
      () async {
        final engineA = DurableWorkflowEngine(
          store: FileJsonWorkflowStore(storeFile),
        );
        await engineA.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Process exit resume',
          workItemId: _workItemId,
        );
        await pushToDesignInReview(engineA);

        final pending = await engineA.requestHumanDecision(
          workItemId: _workItemId,
          decisionType: HumanDecisionType.designApproval,
          question: 'Approve the design?',
          actor: _orch,
        );
        expect(await engineA.isWaitingForHumanDecision(_workItemId), isTrue);

        // Simulated process exit: drop every engine/store instance and build a
        // brand new one over the same file.
        expect(
          await File('${storeFile.path}.tmp').exists(),
          isFalse,
          reason: 'no leftover temp file after atomic writes',
        );

        final storeB = FileJsonWorkflowStore(storeFile);
        final engineB = DurableWorkflowEngine(store: storeB);

        final reloaded = await engineB.loadWorkItem(_workItemId);
        expect(reloaded.state, WorkItemState.waitingForHumanDecision);
        expect(reloaded.blockingHumanDecisionId, pending.decisionId);

        final persistedDecision = await storeB.readHumanDecision(
          pending.decisionId,
        );
        expect(persistedDecision.status, HumanDecisionStatus.pending);
        expect(persistedDecision.workItemId, _workItemId);

        final historyBefore = await engineB.transitionHistory(_workItemId);
        expect(historyBefore, isNotEmpty);

        final resumed = await engineB.resolveHumanDecision(
          decisionId: pending.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'alice@example.com',
          rationale: 'resumed after restart',
          signature: _sig(),
        );
        expect(resumed.state, WorkItemState.designApproved);

        // Continue the full golden path in the new process instance.
        await engineB.transition(
          workItemId: _workItemId,
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        await engineB.transition(
          workItemId: _workItemId,
          to: WorkItemState.agentCompleted,
          trigger: TransitionTrigger.agentResult,
          actor: _orch,
          context: {'qaContractId': 'qa-1', 'agentResult': _completedResult()},
        );
        await engineB.transition(
          workItemId: _workItemId,
          to: WorkItemState.reviewInProgress,
          trigger: TransitionTrigger.agentResult,
          actor: _orch,
          context: {'agentResult': _completedResult()},
        );

        final review = await engineB.requestHumanDecision(
          workItemId: _workItemId,
          decisionType: HumanDecisionType.engineeringReview,
          question: 'Approve the implementation?',
          actor: _reviewer,
          extraContext: {'producerActorId': 'agent-1'},
        );
        await engineB.resolveHumanDecision(
          decisionId: review.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'bob@example.com',
          rationale: 'Implementation approved after restart',
          signature: _sig(),
        );
        await engineB.transition(
          workItemId: _workItemId,
          to: WorkItemState.qaInProgress,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: {'qaContractId': 'qa-1'},
        );
        await engineB.transition(
          workItemId: _workItemId,
          to: WorkItemState.qaPassed,
          trigger: TransitionTrigger.agentResult,
          actor: _qaExecutor,
          context: {
            'gateResults': _passingGateResults(),
            'qaContract': _qaContract(),
          },
        );
        final qaApproval = await engineB.requestHumanDecision(
          workItemId: _workItemId,
          decisionType: HumanDecisionType.humanQaApproval,
          question: 'Confirm QA sign-off?',
          actor: _orch,
        );
        final completed = await engineB.resolveHumanDecision(
          decisionId: qaApproval.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'carol@example.com',
          rationale: 'QA sign-off after restart',
          signature: _sig(),
        );
        expect(completed.state, WorkItemState.completed);

        final historyAfter = await engineB.transitionHistory(_workItemId);
        expect(historyAfter.length, greaterThan(historyBefore.length));
      },
    );

    test('persisted rejected attempts survive a restart', () async {
      final engineA = DurableWorkflowEngine(
        store: FileJsonWorkflowStore(storeFile),
      );
      await engineA.createWorkItem(
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Rejected attempt',
        workItemId: _workItemId,
      );
      await expectLater(
        engineA.transition(
          workItemId: _workItemId,
          to: WorkItemState.agentCompleted,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
        ),
        throwsA(isA<WorkflowTransitionRejectedException>()),
      );

      final engineB = DurableWorkflowEngine(
        store: FileJsonWorkflowStore(storeFile),
      );
      final history = await engineB.transitionHistory(_workItemId);
      expect(history, hasLength(1));
      expect(history.single.outcome, TransitionOutcome.rejected);
      expect(
        (await engineB.loadWorkItem(_workItemId)).state,
        WorkItemState.draft,
      );
    });
  });
}

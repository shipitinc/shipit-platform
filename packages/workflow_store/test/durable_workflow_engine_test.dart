import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart'
    show designContractResolutionContextKey, DesignContractResolution;
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

/// The design contract governing [_workItemId], provisioned through the real
/// [DesignContractProvisioner] and read back — so the `designContractId` these
/// tests put on the work item is an id they have SEEN RESOLVE, which is the
/// only kind `designContractExists()` accepts.
Future<String> provisionContractForTest(
  DesignContractStore contractStore,
) async =>
    (await DesignContractProvisioner(
          contractStore: contractStore,
        ).provisionForWorkItem(workItemId: _workItemId, productId: 'prod-1'))
        .contractId;

/// The `designContractId` a work item for [_workItemId] must carry to enter
/// `designRequired` now that the guard reads the COLUMN.
String contractIdForTest() => designContractIdForWorkItem(_workItemId);

/// Walks `draft -> planning -> planned -> designRequired -> designInReview`.
///
/// ## THE `designContractId` IS DELIBERATELY ABSENT FROM THE CONTEXT
///
/// Every other guard this walk satisfies is satisfied by context, because it
/// describes something happening *now*. This one cannot: the guard reads the
/// work item's persisted `designContractId` column and confirms it against the
/// store, so the item has to be CREATED carrying the id. A test that kept
/// passing `context: {'designContractId': …}` here would be asserting the defect
/// — it would go on passing while the guard grew stricter, which is precisely
/// how a guard gets closed without anyone noticing.
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
    late DesignContractStore contractStore;
    late DurableWorkflowEngine engine;

    setUp(() async {
      store = InMemoryWorkflowStore();
      contractStore = InMemoryDesignContractStore();
      engine = DurableWorkflowEngine(
        store: store,
        designContractStore: contractStore,
      );
      await provisionContractForTest(contractStore);
    });

    test('golden path draft -> completed through all gates', () async {
      await engine.createWorkItem(
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Golden path',
        description: 'Golden path item through all workflow gates',
        workItemId: _workItemId,
        featureRef: 'FEAT-001',
        designContractId: contractIdForTest(),
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
          description: 'Reject route through the engineering review gate',
          workItemId: _workItemId,
          designContractId: contractIdForTest(),
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
        // A rejected human QA approval lands on `implementationReady`, NOT on
        // `agentExecuting`. See the note below — do not "restore" the old
        // expectation here.
        expect(reworked.state, WorkItemState.implementationReady);
        expect(reworked.blockingHumanDecisionId, isNull);
        expect(await engine.isWaitingForHumanDecision(_workItemId), isFalse);

        // WHY A DISPATCHABLE STATE AND NOT `agentExecuting`
        //
        // This test used to assert `agentExecuting` here, which pinned the
        // stranding state as correct behaviour. `agentExecuting` is in the
        // `entryStates` of NO wired JobDefinition, so an item parked there is
        // never enqueued and nothing can ever dispatch it: the gate is
        // resolved, the item is unrecoverable. It also asserts something
        // untrue — that an execution is ALREADY RUNNING — when resolving a
        // decision does not start one. Observed live on work item
        // `defect-DEF-1791684804452198` on 2026-10-12, stuck at
        // agent_executing since 16:43:11 with no job enqueued.
        //
        // It then asserted `designNotRequired`, which `OD-3` has since
        // superseded: a human QA rejection judges the delivered RESULT, so it
        // means "re-do the work" and routes to
        // `implementFeatureDefinition.entryStates`. The routing table
        // (`HumanDecisionRouting.targetFor`) is the sole determinant of where
        // a resolved decision lands, so this expectation tracks production
        // behaviour rather than restating a superseded routing.
        //
        // The remainder of the test proves what its NAME claims — that
        // resolving the gate UNBLOCKS it — by driving the item forward from
        // the state it actually landed in. There is no direct
        // `implementationReady -> agentCompleted` edge; the only legal path is
        // through `agentExecuting`, which is reached here by an explicit
        // orchestrator transition carrying `agentAvailable` — i.e. the
        // dispatch that the stranding state made impossible. Reaching
        // `agentCompleted` from the real landing state is a stronger proof of
        // recovery than the old `agentExecuting -> agentCompleted` hop, which
        // could only succeed precisely because the gate had left the item
        // nowhere to go.

        // Step 1: the scheduler/orchestrator dispatches the reworked item.
        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        expect(
          (await engine.loadWorkItem(_workItemId)).state,
          WorkItemState.agentExecuting,
        );

        // Step 2: the dispatched run completes, proving the item is live and
        // not stranded behind its own resolved gate.
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
          description: 'Work item that the policy rejects',
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
        description: 'Same-state transition rejection probe',
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
          description: 'Idempotent transition replay probe',
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
          description: 'Resume resolve of a blocking human decision',
          workItemId: _workItemId,
          designContractId: contractIdForTest(),
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
          description: 'Concurrent compare-and-swap probe',
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

  // `design-revision.md` §8.1, row D-5. The finding was specified as "the
  // failing test to write", not as prose, precisely because a finding nobody can
  // run rots. These are that test, and they are the ones that make this file's
  // other `designContractId` handling mean something: without them, a guard that
  // went back to reading `context['designContractId']` would leave every other
  // test in this file green, because they all supply a real row.
  group('designContractExists is confirmed against the store, not a string', () {
    /// Creates an item at `planned`, carrying whatever [designContractId] the
    /// caller asks for — including none, and including an id nothing holds.
    Future<DurableWorkflowEngine> atPlanned(
      WorkflowStore store,
      DesignContractStore? contractStore, {
      String? designContractId,
    }) async {
      final engine = DurableWorkflowEngine(
        store: store,
        designContractStore: contractStore,
      );
      await engine.createWorkItem(
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Design contract probe',
        description: 'The falsifier for a guard satisfied by any string',
        workItemId: _workItemId,
        featureRef: 'FEAT-001',
        designContractId: designContractId,
      );
      await engine.transition(
        workItemId: _workItemId,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );
      await engine.transition(
        workItemId: _workItemId,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: const {'featureRef': 'FEAT-001'},
      );
      return engine;
    }

    Future<WorkflowTransitionRecord> attempt(
      DurableWorkflowEngine engine,
    ) async {
      try {
        await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.designRequired,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: const {'designContractId': 'anything'},
        );
        fail(
          'planned -> designRequired was ACCEPTED with no contract behind it',
        );
      } on WorkflowTransitionRejectedException catch (e) {
        return e.record;
      }
    }

    test(
      "a caller's fabricated id on an item whose COLUMN is null is refused",
      () async {
        // THE FALSIFIER, verbatim: `context: {'designContractId': 'anything'}`
        // on an item whose column is NULL. Before the guard change this was
        // ACCEPTED and persisted an item at `designRequired` with nothing
        // behind it — the fabrication lane E refused rather than perform.
        final contractStore = InMemoryDesignContractStore();
        await provisionContractForTest(contractStore);
        final engine = await atPlanned(
          InMemoryWorkflowStore(),
          contractStore,
          designContractId: null,
        );

        final record = await attempt(engine);
        expect(record.outcome, TransitionOutcome.rejected);
        expect(
          (await engine.loadWorkItem(_workItemId)).state,
          WorkItemState.planned,
          reason: 'a refused transition must not move the item',
        );
      },
    );

    test('a COLUMN naming an id the store does not hold is refused', () async {
      // The other half. A non-null column is a NAME; only the store lookup
      // turns it into a contract.
      final engine = await atPlanned(
        InMemoryWorkflowStore(),
        InMemoryDesignContractStore(),
        designContractId: contractIdForTest(),
      );

      final record = await attempt(engine);
      expect(record.outcome, TransitionOutcome.rejected);
      expect(
        record.reason,
        contains('resolves to no row'),
        reason: 'the refusal must name WHICH fact was missing',
      );
    });

    test(
      'an engine with NO contract store mounted refuses a real column too',
      () async {
        // Fail-closed by construction. A missing mount must not degrade to the
        // pre-step-2 behaviour, because the pre-step-2 behaviour IS the defect.
        final engine = await atPlanned(
          InMemoryWorkflowStore(),
          null,
          designContractId: contractIdForTest(),
        );

        final record = await attempt(engine);
        expect(record.outcome, TransitionOutcome.rejected);
      },
    );

    test(
      'a COLUMN the store confirms is accepted, with NO context id',
      () async {
        final contractStore = InMemoryDesignContractStore();
        final contractId = await provisionContractForTest(contractStore);
        final engine = await atPlanned(
          InMemoryWorkflowStore(),
          contractStore,
          designContractId: contractId,
        );

        final moved = await engine.transition(
          workItemId: _workItemId,
          to: WorkItemState.designRequired,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
        );

        expect(
          moved.state,
          WorkItemState.designRequired,
          reason:
              'the positive case: the COLUMN and the ROW are the whole of the '
              'evidence, and the transition needs nothing from the caller',
        );
      },
    );

    test(
      'a caller that PLANTS a confirmed resolution for a different id is refused',
      () async {
        // The ordering is the whole of the fix's second half. The resolution key
        // is a public constant, so planting it is possible; it is inert only
        // because `transition` writes its own value AFTER spreading the caller's
        // map. A store holds a real contract for THIS item — so the planted value
        // is not merely "true", it is true about the WRONG contract — and the
        // item's own column is null, so the honest answer is a refusal.
        final contractStore = InMemoryDesignContractStore();
        await provisionContractForTest(contractStore);
        final engine = await atPlanned(
          InMemoryWorkflowStore(),
          contractStore,
          designContractId: null,
        );

        await expectLater(
          engine.transition(
            workItemId: _workItemId,
            to: WorkItemState.designRequired,
            trigger: TransitionTrigger.systemEvent,
            actor: _orch,
            context: {
              designContractResolutionContextKey: DesignContractResolution(
                contractId: designContractIdForWorkItem('some-other-item'),
                storeConfirmed: true,
              ),
            },
          ),
          throwsA(isA<WorkflowTransitionRejectedException>()),
          reason:
              'a planted resolution must be OVERWRITTEN by the engine\'s own '
              'reading, not honoured',
        );
      },
    );
  });

  group('DurableWorkflowEngine (FileJson) process-exit resume', () {
    late Directory tempDir;
    late File storeFile;
    late DesignContractStore contractStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('shipit-store-');
      storeFile = File('${tempDir.path}/store.json');
      // The SAME instance across the simulated process exit, which is what a
      // mounted `PostgresDesignContractStore` over one database gives: the
      // engine is rebuilt, the durable row behind it is not.
      contractStore = InMemoryDesignContractStore();
      await provisionContractForTest(contractStore);
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
          designContractStore: contractStore,
        );
        await engineA.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Process exit resume',
          description: 'Process exit resume after a durable decision',
          workItemId: _workItemId,
          designContractId: contractIdForTest(),
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
        final engineB = DurableWorkflowEngine(
          store: storeB,
          designContractStore: contractStore,
        );

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
        description: 'Work item whose retried attempt is rejected',
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

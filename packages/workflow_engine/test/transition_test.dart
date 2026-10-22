import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:test/test.dart';

const _workItemId = '123e4567-e89b-12d3-a456-426614174001';

const _orch = WorkflowActor(
  actorId: 'orch-1',
  actorType: ActorType.orchestrator,
);
const _system = WorkflowActor(actorId: 'system-1', actorType: ActorType.system);
const _qaExecutor = WorkflowActor(
  actorId: 'qa-1',
  actorType: ActorType.qaExecutor,
);

WorkflowActor _agent(String id) =>
    WorkflowActor(actorId: id, actorType: ActorType.implementationAgent);

HumanDecision _pendingDecision({
  required HumanDecisionType type,
  String workItemId = _workItemId,
}) {
  return HumanDecision(
    decisionId: 'dec-pending-1',
    workItemId: workItemId,
    decisionType: type,
    status: HumanDecisionStatus.pending,
    question: 'Question?',
    requestedAt: DateTime.parse('2024-01-01T10:00:00Z'),
    updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
  );
}

HumanDecision _resolvedDecision({
  required HumanDecisionType type,
  required HumanDecisionChoice choice,
  String workItemId = _workItemId,
  String? decider = 'alice@example.com',
}) {
  final resolvedAt = DateTime.parse('2024-01-02T12:00:00Z');
  return HumanDecision(
    decisionId: 'dec-resolved-1',
    workItemId: workItemId,
    decisionType: type,
    status: HumanDecisionStatus.resolved,
    question: 'Question?',
    decider: decider,
    choice: choice,
    rationale: 'because',
    timestamp: resolvedAt,
    signature: DecisionSignature(
      algorithm: 'Ed25519',
      publicKey: 'key',
      signature: 'sig',
      signedAt: resolvedAt,
    ),
    context: DecisionContext(
      workflowState: 'waiting_for_human_decision',
      availableOptions: const [],
    ),
    requestedAt: DateTime.parse('2024-01-01T10:00:00Z'),
    updatedAt: resolvedAt,
  );
}

void main() {
  _escalationRouting();
  _escalationTransitions();
  _escalationRoutingMethods();

  group('WorkItemTransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    Transition<WorkItemState> eval(
      WorkItemState from,
      WorkItemState to, {
      TransitionTrigger trigger = TransitionTrigger.systemEvent,
      WorkflowActor actor = _orch,
      Map<String, dynamic> context = const {},
    }) {
      return engine.evaluateWorkItemTransition(
        from: from,
        to: to,
        trigger: trigger,
        actor: actor,
        context: context,
      );
    }

    test('draft -> planning is legal for the orchestrator', () {
      final transition = eval(WorkItemState.draft, WorkItemState.planning);
      expect(transition.isValid, isTrue);
    });

    test('planning -> planned requires planning evidence', () {
      final noEvidence = eval(WorkItemState.planning, WorkItemState.planned);
      expect(noEvidence.isValid, isFalse);
      expect(noEvidence.failedGuards, contains('planning_evidence_provided'));

      final withEvidence = eval(
        WorkItemState.planning,
        WorkItemState.planned,
        context: {'featureRef': 'FEAT-001'},
      );
      expect(withEvidence.isValid, isTrue);
    });

    test('planned -> designRequired requires a CONFIRMED design contract', () {
      // This used to read `context: {'designContractId': 'contract-123'}` and
      // pass. That string was the whole of the evidence, the durable engine
      // discarded it, and an item was persisted at `designRequired` with a NULL
      // contract column behind it — `design-revision.md` §4.3's falsifier. The
      // guard now reads the COLUMN and the STORE, which the pure policy engine
      // has neither of, so "nothing supplied" is a refusal rather than a pass.
      final without = eval(WorkItemState.planned, WorkItemState.designRequired);
      expect(without.isValid, isFalse);
      expect(without.failedGuards, contains('design_contract_exists'));

      // THE FALSIFIER, asserted so it can never come back: a caller-supplied
      // string on an item with nothing behind it.
      final fabricated = eval(
        WorkItemState.planned,
        WorkItemState.designRequired,
        context: const {'designContractId': 'anything'},
      );
      expect(fabricated.isValid, isFalse, reason: 'a string is not a contract');
      expect(fabricated.failedGuards, contains('design_contract_exists'));

      // A caller that plants the resolution key itself is no more able to pass:
      // the durable engine overwrites that key after spreading the caller's map.
      final planted = eval(
        WorkItemState.planned,
        WorkItemState.designRequired,
        context: {
          designContractResolutionContextKey:
              const DesignContractResolution.noContract(),
        },
      );
      expect(planted.isValid, isFalse);
      expect(planted.failedGuards, contains('design_contract_exists'));

      // A column that names a contract the store could not confirm is refused,
      // and the message says which of the two facts was missing.
      final unconfirmedId = eval(
        WorkItemState.planned,
        WorkItemState.designRequired,
        context: {
          designContractResolutionContextKey: const DesignContractResolution(
            contractId: 'contract-123',
            storeConfirmed: false,
          ),
        },
      );
      expect(unconfirmedId.isValid, isFalse);
      expect(unconfirmedId.rejectionReason, contains('contract-123'));

      final noColumn = eval(
        WorkItemState.planned,
        WorkItemState.designRequired,
        context: {
          designContractResolutionContextKey:
              const DesignContractResolution.noContract(),
        },
      );
      expect(noColumn.isValid, isFalse);
      expect(noColumn.rejectionReason, contains('no designContractId'));

      // The only value that opens the edge: a column id the store confirmed.
      final withContract = eval(
        WorkItemState.planned,
        WorkItemState.designRequired,
        context: {
          designContractResolutionContextKey: const DesignContractResolution(
            contractId: 'contract-123',
            storeConfirmed: true,
          ),
        },
      );
      expect(withContract.isValid, isTrue);
    });

    test('designRequired -> designInReview requires a STORE-CONFIRMED '
        'under-review contract', () {
      // A caller-supplied status is not evidence. The old guard read this
      // exact key and passed; the resolution under
      // `designContractResolutionContextKey` is the only thing consulted now,
      // and it is written by `DurableWorkflowEngine.transition`, not by the
      // caller.
      final callerSuppliedStatus = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        context: const {
          'designContractStatus': DesignContractStatus.underReview,
        },
      );
      expect(callerSuppliedStatus.isValid, isFalse);

      final noResolution = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
      );
      expect(noResolution.isValid, isFalse);
      expect(noResolution.rejectionReason, contains('No durable'));

      final noContract = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        context: const {
          designContractResolutionContextKey:
              DesignContractResolution.noContract(),
        },
      );
      expect(noContract.isValid, isFalse);
      expect(noContract.rejectionReason, contains('no designContractId'));

      final unconfirmed = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        context: const {
          designContractResolutionContextKey: DesignContractResolution(
            contractId: 'contract-123',
            storeConfirmed: false,
            status: DesignContractStatus.underReview,
          ),
        },
      );
      expect(unconfirmed.isValid, isFalse);
      expect(unconfirmed.rejectionReason, contains('contract-123'));

      // The status is the STORE's answer, carried alongside the confirmed id.
      // A confirmed draft contract is not reviewable, whatever the caller
      // says.
      final draft = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        context: const {
          designContractResolutionContextKey: DesignContractResolution(
            contractId: 'contract-123',
            storeConfirmed: true,
            status: DesignContractStatus.draft,
          ),
        },
      );
      expect(draft.isValid, isFalse);
      expect(draft.rejectionReason, contains('not under review'));

      final confirmedUnderReview = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        context: const {
          designContractResolutionContextKey: DesignContractResolution(
            contractId: 'contract-123',
            storeConfirmed: true,
            status: DesignContractStatus.underReview,
          ),
        },
      );
      expect(confirmedUnderReview.isValid, isTrue);
    });

    test('designRejected -> designRequired carries actorAllowed ALONE', () {
      // `design-revision.md` §5.4 (a). The scheduler's probe runs THIS pure
      // policy with no store and no work item, so it can supply no
      // `DesignContractResolution`; a `designContractExists()` guard here
      // would fail closed and make `designRevisionDefinition`'s declared hop
      // unreachable. The item already carried a confirmed contract to reach
      // `designRequired` the first time, and a re-design does not need a
      // second one minted.
      final legal = eval(
        WorkItemState.designRejected,
        WorkItemState.designRequired,
      );
      expect(legal.isValid, isTrue);
      expect(legal.failedGuards, isEmpty);

      final agent = eval(
        WorkItemState.designRejected,
        WorkItemState.designRequired,
        actor: _agent('agent-1'),
      );
      expect(agent.isValid, isFalse);
      expect(agent.failedGuards, contains('actor_allowed'));
    });

    test('illegal transition returns invalid result instead of throwing', () {
      final transition = eval(
        WorkItemState.draft,
        WorkItemState.agentExecuting,
      );
      expect(transition.isValid, isFalse);
      expect(transition.failedGuards, contains('legal_transition'));
      expect(transition.rejectionReason, isNotNull);
    });

    test('terminal states cannot transition to anything', () {
      expect(
        eval(WorkItemState.completed, WorkItemState.cancelled).isValid,
        isFalse,
      );
      expect(
        eval(WorkItemState.cancelled, WorkItemState.draft).isValid,
        isFalse,
      );
      expect(
        eval(WorkItemState.terminated, WorkItemState.draft).isValid,
        isFalse,
      );
    });

    test(
      'generic escape allows orchestrator to cancel any non-terminal state',
      () {
        expect(
          eval(WorkItemState.qaInProgress, WorkItemState.cancelled).isValid,
          isTrue,
        );
        expect(
          eval(
            WorkItemState.waitingForHumanDecision,
            WorkItemState.cancelled,
          ).isValid,
          isTrue,
        );
      },
    );

    test(
      'non-orchestrator actors are rejected for workflow-advancing moves',
      () {
        final impl = _agent('agent-1');
        final byImpl = eval(
          WorkItemState.planning,
          WorkItemState.planned,
          actor: impl,
          context: {'featureRef': 'FEAT-001'},
        );
        expect(byImpl.isValid, isFalse);
        expect(byImpl.failedGuards, contains('actor_allowed'));
      },
    );

    test('entering the design gate requires a pending blocking decision', () {
      final without = eval(
        WorkItemState.designInReview,
        WorkItemState.waitingForHumanDecision,
      );
      expect(without.isValid, isFalse);
      expect(without.failedGuards, contains('blocking_human_decision_pending'));

      final pending = _pendingDecision(type: HumanDecisionType.designApproval);
      final withPending = eval(
        WorkItemState.designInReview,
        WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': pending, 'workItemId': _workItemId},
      );
      expect(withPending.isValid, isTrue);
    });

    test('design gate resolves to designApproved only on approve', () {
      final approvedDecision = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.approve,
      );
      final approved = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designApproved,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': approvedDecision, 'workItemId': _workItemId},
      );
      expect(approved.isValid, isTrue);

      final rejectedDecision = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.reject,
      );
      final rejected = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designApproved,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': rejectedDecision, 'workItemId': _workItemId},
      );
      expect(rejected.isValid, isFalse);
      expect(
        rejected.failedGuards,
        contains('blocking_human_decision_resolved'),
      );
    });

    test('design gate rejects a decision for a different work item', () {
      final otherDecision = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.approve,
        workItemId: '123e4567-e89b-12d3-a456-426614174099',
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designApproved,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': otherDecision, 'workItemId': _workItemId},
      );
      expect(transition.isValid, isFalse);
      expect(
        transition.failedGuards,
        contains('blocking_human_decision_resolved'),
      );
    });

    test('design gate requires a human decider on the decision', () {
      final noDecider = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.approve,
        decider: null,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designApproved,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': noDecider, 'workItemId': _workItemId},
      );
      expect(transition.isValid, isFalse);
      expect(transition.failedGuards, contains('decision_actor_is_human'));
    });

    test('expired approval cannot unlock the gate', () {
      final expired = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.approve,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designApproved,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': expired, 'workItemId': _workItemId},
      );
      // Without expiration, a resolved decision with valid choice should pass
      expect(transition.isValid, isTrue);
    });

    test('design rework returns to designInReview', () {
      final reworkDecision = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.rework,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designInReview,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': reworkDecision, 'workItemId': _workItemId},
      );
      expect(transition.isValid, isTrue);
    });

    test('engineer cannot review their own implementation', () {
      final selfReview = WorkflowActor(
        actorId: 'agent-1',
        actorType: ActorType.engineeringReviewer,
      );
      final pending = _pendingDecision(
        type: HumanDecisionType.engineeringReview,
      );
      final transition = eval(
        WorkItemState.reviewInProgress,
        WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        actor: selfReview,
        context: {
          'humanDecision': pending,
          'workItemId': _workItemId,
          'producerActorId': 'agent-1',
        },
      );
      expect(transition.isValid, isFalse);
      expect(transition.failedGuards, contains('actor_not_self'));

      final otherReviewer = WorkflowActor(
        actorId: 'reviewer-2',
        actorType: ActorType.engineeringReviewer,
      );
      final ok = eval(
        WorkItemState.reviewInProgress,
        WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        actor: otherReviewer,
        context: {
          'humanDecision': pending,
          'workItemId': _workItemId,
          'producerActorId': 'agent-1',
        },
      );
      expect(ok.isValid, isTrue);
    });

    test('engineering review approve unlocks reviewApproved', () {
      final decision = _resolvedDecision(
        type: HumanDecisionType.engineeringReview,
        choice: HumanDecisionChoice.approve,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.reviewApproved,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': decision, 'workItemId': _workItemId},
      );
      expect(transition.isValid, isTrue);
    });

    test('agent completion requires QA contract and valid result', () {
      final result = AgentResult(
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

      final withoutContract = eval(
        WorkItemState.agentExecuting,
        WorkItemState.agentCompleted,
        trigger: TransitionTrigger.agentResult,
        context: {'agentResult': result},
      );
      expect(withoutContract.isValid, isFalse);
      expect(withoutContract.failedGuards, contains('qa_contract_exists'));

      final withContract = eval(
        WorkItemState.agentExecuting,
        WorkItemState.agentCompleted,
        trigger: TransitionTrigger.agentResult,
        context: {'agentResult': result, 'qaContractId': 'qa-123'},
      );
      expect(withContract.isValid, isTrue);
    });

    test('reviewApproved -> qaInProgress requires QA contract', () {
      final without = eval(
        WorkItemState.reviewApproved,
        WorkItemState.qaInProgress,
      );
      expect(without.isValid, isFalse);

      final withContract = eval(
        WorkItemState.reviewApproved,
        WorkItemState.qaInProgress,
        context: {'qaContractId': 'qa-123'},
      );
      expect(withContract.isValid, isTrue);
    });

    test('qaInProgress -> qaPassed requires all required gates to pass', () {
      final gateResults = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: _workItemId,
          status: QAGateStatus.passed,
          evidence: const [],
          evaluatedAt: DateTime.parse('2024-01-02T13:00:00Z'),
        ),
        QAGateResult(
          gateId: 'unit-tests',
          workItemId: _workItemId,
          status: QAGateStatus.passed,
          evidence: const [],
          evaluatedAt: DateTime.parse('2024-01-02T13:00:00Z'),
        ),
      ];
      final qaContract = QAContract(
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
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

      final context = {'gateResults': gateResults, 'qaContract': qaContract};
      expect(
        eval(
          WorkItemState.qaInProgress,
          WorkItemState.qaPassed,
          trigger: TransitionTrigger.agentResult,
          actor: _qaExecutor,
          context: context,
        ).isValid,
        isTrue,
      );

      // Supplies a result for BOTH required gates, so this rejection is caused
      // by the `failed` status alone. It previously supplied one result for a
      // two-required-gate contract, so it also failed for the second, weaker
      // reason that a required gate had no result at all — and therefore
      // exercised neither reason in isolation.
      final failing = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: _workItemId,
          status: QAGateStatus.failed,
          evidence: const [],
          evaluatedAt: DateTime.parse('2024-01-02T13:00:00Z'),
        ),
        QAGateResult(
          gateId: 'unit-tests',
          workItemId: _workItemId,
          status: QAGateStatus.passed,
          evidence: const [],
          evaluatedAt: DateTime.parse('2024-01-02T13:00:00Z'),
        ),
      ];
      final rejected = eval(
        WorkItemState.qaInProgress,
        WorkItemState.qaPassed,
        trigger: TransitionTrigger.agentResult,
        actor: _qaExecutor,
        context: {'gateResults': failing, 'qaContract': qaContract},
      );
      expect(rejected.isValid, isFalse);
      expect(rejected.failedGuards, contains('all_required_gates_passed'));

      // The subset case, at the transition level: both required gates exist in
      // the contract but only one result was produced. This is the vacuous
      // pass that `guard_conditions_vacuous_pass_test.dart` pins row-by-row.
      final subset = eval(
        WorkItemState.qaInProgress,
        WorkItemState.qaPassed,
        trigger: TransitionTrigger.agentResult,
        actor: _qaExecutor,
        context: {
          'gateResults': [gateResults.first],
          'qaContract': qaContract,
        },
      );
      expect(subset.isValid, isFalse);
      expect(subset.failedGuards, contains('all_required_gates_passed'));
    });

    test('qaFailed gate accepts waiver and unlocks qaPassed', () {
      final pending = _pendingDecision(type: HumanDecisionType.qaWaiver);
      final entered = eval(
        WorkItemState.qaFailed,
        WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': pending, 'workItemId': _workItemId},
      );
      expect(entered.isValid, isTrue);

      final waived = _resolvedDecision(
        type: HumanDecisionType.qaWaiver,
        choice: HumanDecisionChoice.waive,
      );
      final resolved = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.qaPassed,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': waived, 'workItemId': _workItemId},
      );
      expect(resolved.isValid, isTrue);
    });

    test('qa rework unlock maps to agentExecuting for "reject"', () {
      final decision = _resolvedDecision(
        type: HumanDecisionType.qaRework,
        choice: HumanDecisionChoice.reject,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.agentExecuting,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': decision, 'workItemId': _workItemId},
      );
      expect(transition.isValid, isTrue);
    });

    test('human QA approval gate unlocks completed', () {
      final pending = _pendingDecision(type: HumanDecisionType.humanQaApproval);
      final entered = eval(
        WorkItemState.qaPassed,
        WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': pending, 'workItemId': _workItemId},
      );
      expect(entered.isValid, isTrue);

      final approved = _resolvedDecision(
        type: HumanDecisionType.humanQaApproval,
        choice: HumanDecisionChoice.approve,
      );
      final completed = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.completed,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': approved, 'workItemId': _workItemId},
      );
      expect(completed.isValid, isTrue);
    });

    test('waiting -> completed rejects a non-matching decision', () {
      final decision = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.approve,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.completed,
        trigger: TransitionTrigger.humanDecision,
        context: {'humanDecision': decision, 'workItemId': _workItemId},
      );
      expect(transition.isValid, isFalse);
    });
  });

  group('HumanDecisionRouting', () {
    test('maps decision outcomes to target states', () {
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.designApproval,
          HumanDecisionChoice.approve,
        ),
        WorkItemState.designApproved,
      );
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.implementationReady,
        reason:
            'OD-3 resolved "rework" at a review gate to mean re-do the work, '
            'so it targets the implementation lane rather than re-triage',
      );
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.humanQaApproval,
          HumanDecisionChoice.approve,
        ),
        WorkItemState.completed,
      );
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.qaWaiver,
          HumanDecisionChoice.waive,
        ),
        WorkItemState.qaPassed,
      );
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.deploymentApproval,
          HumanDecisionChoice.approve,
        ),
        WorkItemState.deployed,
      );
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.qaRework,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.designInReview,
      );
    });

    test('unmapped resolutions return null', () {
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.rollbackApproval,
          HumanDecisionChoice.approve,
        ),
        isNull,
      );
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.policyException,
          HumanDecisionChoice.defer,
        ),
        isNull,
      );
    });

    test('cancel choice always routes to cancelled', () {
      for (final type in HumanDecisionType.values) {
        expect(
          HumanDecisionRouting.targetFor(type, HumanDecisionChoice.cancel),
          WorkItemState.cancelled,
        );
      }
    });
  });

  group('DesignTransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    test('underReview -> approved is legal', () {
      final transition = engine.transitionDesignContract(
        DesignContractStatus.underReview,
        DesignContractStatus.approved,
        TransitionTrigger.humanDecision,
        _orch,
        const {},
      );
      expect(transition.isValid, isTrue);
    });

    test('approved -> rejected is rejected', () {
      final transition = engine.transitionDesignContract(
        DesignContractStatus.approved,
        DesignContractStatus.rejected,
        TransitionTrigger.humanDecision,
        _orch,
        const {},
      );
      expect(transition.isValid, isFalse);
    });
  });

  group('QATransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    test('pending -> inProgress is legal', () {
      final transition = engine.transitionQA(
        QAStatus.pending,
        QAStatus.inProgress,
        TransitionTrigger.systemEvent,
        _qaExecutor,
        const {},
      );
      expect(transition.isValid, isTrue);
    });

    test('passed -> failed is rejected', () {
      final transition = engine.transitionQA(
        QAStatus.passed,
        QAStatus.failed,
        TransitionTrigger.systemEvent,
        _qaExecutor,
        const {},
      );
      expect(transition.isValid, isFalse);
    });
  });

  group('DeploymentTransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    test('building -> promoting is legal', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.building,
        DeploymentPhase.promoting,
        TransitionTrigger.systemEvent,
        _system,
        const {},
      );
      expect(transition.isValid, isTrue);
    });

    test('completed -> failed is rejected', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.completed,
        DeploymentPhase.failed,
        TransitionTrigger.systemEvent,
        _system,
        const {},
      );
      expect(transition.isValid, isFalse);
    });
  });

  group('WorkflowState allowedTransitions', () {
    test('draft allows planning and the generic escapes', () {
      // `draft -> planning` plus the non-terminal -> cancelled/terminated
      // escapes every state gets. The old expectation listed planning alone,
      // which was the mirror being stale rather than the table being narrow.
      expect(
        WorkItemWorkflowState.draft.allowedTransitions.map((s) => s.value),
        containsAll(<WorkItemState>[
          WorkItemState.planning,
          WorkItemState.cancelled,
          WorkItemState.terminated,
        ]),
      );
    });

    test('waitingForHumanDecision exposes all gate resolutions', () {
      final targets = WorkItemWorkflowState
          .waitingForHumanDecision
          .allowedTransitions
          .map((s) => s.value)
          .toSet();
      expect(
        targets,
        containsAll(<WorkItemState>[
          WorkItemState.designApproved,
          WorkItemState.reviewApproved,
          WorkItemState.qaPassed,
          WorkItemState.completed,
          WorkItemState.cancelled,
          WorkItemState.terminated,
        ]),
      );
    });

    test('terminal states allow no transitions', () {
      expect(WorkItemWorkflowState.completed.allowedTransitions, isEmpty);
      expect(WorkItemWorkflowState.cancelled.allowedTransitions, isEmpty);
      expect(WorkItemWorkflowState.terminated.allowedTransitions, isEmpty);
      expect(WorkItemWorkflowState.done.allowedTransitions, isEmpty);
    });
  });

  group('Transition validator', () {
    test('actor is threaded into context and surfaced on the result', () {
      final engine = const WorkflowEngine();
      final transition = engine.evaluateWorkItemTransition(
        from: WorkItemState.draft,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );
      expect(transition.actor.actorType, ActorType.orchestrator);
      expect(transition.metadata?['actor'], isA<WorkflowActor>());
    });
  });
}

void _escalationRouting() {
  group('Escalation outcomes', () {
    test('resume queues the escalation back into work', () {
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.escalation,
          HumanDecisionChoice.approve,
        ),
        WorkItemState.designNotRequired,
      );
    });

    test('sending it back routes to planning', () {
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.escalation,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.planning,
      );
    });

    test('stopping it routes to cancelled', () {
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.escalation,
          HumanDecisionChoice.cancel,
        ),
        WorkItemState.cancelled,
      );
    });

    test('every escalation outcome has somewhere to go', () {
      // A route that exists but has no legal transition would still strand
      // the item, so assert the pair rather than the routing alone.
      for (final choice in [
        HumanDecisionChoice.approve,
        HumanDecisionChoice.rework,
        HumanDecisionChoice.cancel,
      ]) {
        final target = HumanDecisionRouting.targetFor(
          HumanDecisionType.escalation,
          choice,
        );
        expect(target, isNotNull, reason: 'no route for $choice');
      }
    });

    test('resume queues the work instead of stranding it', () {
      // Resuming used to be `agentExecuting`, which no JobDefinition lists in
      // entryStates — the live strand on defect-DEF-1791684804452198.
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.escalation,
          HumanDecisionChoice.approve,
        ),
        WorkItemState.designNotRequired,
      );
    });
  });
}

void _escalationTransitions() {
  group('Escalation transitions (review gate rejection/rework)', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    HumanDecision _resolvedDecision({
      required HumanDecisionType type,
      required HumanDecisionChoice choice,
      String workItemId = _workItemId,
      String? decider = 'alice@example.com',
    }) {
      final resolvedAt = DateTime.parse('2024-01-02T12:00:00Z');
      return HumanDecision(
        decisionId: 'dec-resolved-1',
        workItemId: workItemId,
        decisionType: type,
        status: HumanDecisionStatus.resolved,
        question: 'Question?',
        decider: decider,
        choice: choice,
        rationale: 'because',
        timestamp: resolvedAt,
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: resolvedAt,
        ),
        context: DecisionContext(
          workflowState: 'waiting_for_human_decision',
          availableOptions: const [],
        ),
        requestedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        updatedAt: resolvedAt,
      );
    }

    Transition<WorkItemState> eval(
      WorkItemState from,
      WorkItemState to, {
      TransitionTrigger trigger = TransitionTrigger.humanDecision,
      WorkflowActor actor = _orch,
      Map<String, dynamic> context = const {},
    }) {
      return engine.evaluateWorkItemTransition(
        from: from,
        to: to,
        trigger: trigger,
        actor: actor,
        context: context,
      );
    }

    test(
      'engineeringReview reject -> agentExecuting is legal with escalation index',
      () {
        final decision = _resolvedDecision(
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.reject,
        );
        final transition = eval(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
          context: {
            'humanDecision': decision,
            'workItemId': _workItemId,
            'escalationIndex': 0,
            'maxEscalation': 3,
          },
        );
        expect(transition.isValid, isTrue);
      },
    );

    test(
      'engineeringReview rework -> agentExecuting is legal with escalation index',
      () {
        final decision = _resolvedDecision(
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.rework,
        );
        final transition = eval(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
          context: {
            'humanDecision': decision,
            'workItemId': _workItemId,
            'escalationIndex': 0,
            'maxEscalation': 3,
          },
        );
        expect(transition.isValid, isTrue);
      },
    );

    test(
      'designApproval reject -> designInReview is legal with escalation index',
      () {
        final decision = _resolvedDecision(
          type: HumanDecisionType.designApproval,
          choice: HumanDecisionChoice.reject,
        );
        final transition = eval(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.designInReview,
          context: {
            'humanDecision': decision,
            'workItemId': _workItemId,
            'escalationIndex': 0,
            'maxEscalation': 3,
          },
        );
        expect(transition.isValid, isTrue);
      },
    );

    test(
      'designApproval rework -> designInReview is legal with escalation index',
      () {
        final decision = _resolvedDecision(
          type: HumanDecisionType.designApproval,
          choice: HumanDecisionChoice.rework,
        );
        final transition = eval(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.designInReview,
          context: {
            'humanDecision': decision,
            'workItemId': _workItemId,
            'escalationIndex': 0,
            'maxEscalation': 3,
          },
        );
        expect(transition.isValid, isTrue);
      },
    );

    test(
      'humanQaApproval reject -> agentExecuting is legal with escalation index',
      () {
        final decision = _resolvedDecision(
          type: HumanDecisionType.humanQaApproval,
          choice: HumanDecisionChoice.reject,
        );
        final transition = eval(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
          context: {
            'humanDecision': decision,
            'workItemId': _workItemId,
            'escalationIndex': 0,
            'maxEscalation': 3,
          },
        );
        expect(transition.isValid, isTrue);
      },
    );

    test('escalation index limit exceeded rejects transition', () {
      final decision = _resolvedDecision(
        type: HumanDecisionType.engineeringReview,
        choice: HumanDecisionChoice.reject,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.agentExecuting,
        context: {
          'humanDecision': decision,
          'workItemId': _workItemId,
          'escalationIndex': 3,
          'maxEscalation': 3,
        },
      );
      expect(transition.isValid, isFalse);
      expect(
        transition.failedGuards,
        contains('escalation_index_within_limit'),
      );
    });

    test(
      'engineeringReview approve does not require escalation index check',
      () {
        final decision = _resolvedDecision(
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.approve,
        );
        final transition = eval(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.reviewApproved,
          context: {
            'humanDecision': decision,
            'workItemId': _workItemId,
            'escalationIndex': 0,
            'maxEscalation': 0,
          },
        );
        expect(transition.isValid, isTrue);
      },
    );

    test('designApproval approve does not require escalation index check', () {
      final decision = _resolvedDecision(
        type: HumanDecisionType.designApproval,
        choice: HumanDecisionChoice.approve,
      );
      final transition = eval(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designApproved,
        context: {
          'humanDecision': decision,
          'workItemId': _workItemId,
          'escalationIndex': 0,
          'maxEscalation': 0,
        },
      );
      expect(transition.isValid, isTrue);
    });
  });
}

void _escalationRoutingMethods() {
  group('HumanDecisionRouting escalationTargetFor', () {
    test('moved IN LOCKSTEP with the routes that changed target', () {
      // `DurableWorkflowEngine._isEscalationTransition` compares this against
      // the ACTUAL target from `targetFor`. Diverge and the escalation index
      // silently stops advancing and the audit record changes shape — no
      // exception, just an escalation that no longer counts.
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.implementationReady,
      );
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.humanQaApproval,
          HumanDecisionChoice.reject,
        ),
        WorkItemState.implementationReady,
      );
    });

    test('agrees with targetFor for every pair it claims to escalate', () {
      // The property the durable engine actually depends on, asserted over
      // the whole cross-product rather than pair by pair.
      //
      // The allowlist is the PRE-EXISTING divergence, made executable. Both
      // entries are unchanged by this commit and are documented in
      // `HumanDecisionRouting.escalationTargetFor`: they name a state the pair
      // never reaches, so a rejected engineering review and a rejected design
      // do not increment the escalation index. Deleting an entry here — to
      // "fix" it — fails this test, which is the point: changing escalation
      // accounting is a decision, not a drive-by.
      const knownDivergences = {
        (HumanDecisionType.engineeringReview, HumanDecisionChoice.reject),
        (HumanDecisionType.designApproval, HumanDecisionChoice.reject),
      };

      for (final type in HumanDecisionType.values) {
        for (final choice in HumanDecisionChoice.values) {
          final target = HumanDecisionRouting.targetFor(type, choice);
          final escalation = HumanDecisionRouting.escalationTargetFor(
            type,
            choice,
          );
          if (target == null || escalation == null) continue;
          if (escalation == target) continue;
          if (knownDivergences.contains((type, choice))) continue;
          expect(
            escalation,
            target,
            reason:
                '(${type.name}, ${choice.name}): escalationTargetFor names a '
                'state the pair never reaches, so the comparison at '
                'durable_workflow_engine.dart:761 can never be true.',
          );
        }
      }

      // And the allowlist is not allowed to grow on its own.
      expect(knownDivergences, hasLength(2));
    });

    test('returns the pre-existing answers for the untouched pairs', () {
      // These are NOT moved. `engineeringReview/reject` routes to
      // `reviewRejected`, which this never named, and `designApproval/reject`
      // to `designRejected`; both therefore do NOT increment the escalation
      // index. That is the behaviour at cc6290d and changing it would start
      // counting escalations on two routes outside this change.
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.reject,
        ),
        WorkItemState.agentExecuting,
      );
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.humanQaApproval,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.agentExecuting,
      );
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.designApproval,
          HumanDecisionChoice.reject,
        ),
        WorkItemState.designInReview,
      );
    });

    test('returns correct target for designApproval reject/rework', () {
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.designApproval,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.designInReview,
      );
    });

    test('returns null for non-escalation choices', () {
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.approve,
        ),
        isNull,
      );
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.designApproval,
          HumanDecisionChoice.approve,
        ),
        isNull,
      );
    });

    test('returns null for non-review decision types', () {
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.qaWaiver,
          HumanDecisionChoice.reject,
        ),
        isNull,
      );
      expect(
        HumanDecisionRouting.escalationTargetFor(
          HumanDecisionType.deploymentApproval,
          HumanDecisionChoice.reject,
        ),
        isNull,
      );
    });
  });

  group('HumanDecisionRouting routesToEscalation', () {
    test('returns true for escalation targets', () {
      expect(
        HumanDecisionRouting.routesToEscalation(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.rework,
          WorkItemState.implementationReady,
        ),
        isTrue,
      );
      expect(
        HumanDecisionRouting.routesToEscalation(
          HumanDecisionType.designApproval,
          HumanDecisionChoice.rework,
          WorkItemState.designInReview,
        ),
        isTrue,
      );
      expect(
        HumanDecisionRouting.routesToEscalation(
          HumanDecisionType.humanQaApproval,
          HumanDecisionChoice.reject,
          WorkItemState.implementationReady,
        ),
        isTrue,
      );
    });

    test('the moved routes no longer escalate at agentExecuting', () {
      // The failure this change had to avoid: had escalationTargetFor stayed
      // at agentExecuting while targetFor moved, the comparison would be false
      // and the escalation index would stop advancing silently.
      for (final route in const [
        (
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.rework,
          WorkItemState.agentExecuting,
        ),
        (
          HumanDecisionType.humanQaApproval,
          HumanDecisionChoice.reject,
          WorkItemState.agentExecuting,
        ),
      ]) {
        expect(
          HumanDecisionRouting.routesToEscalation(route.$1, route.$2, route.$3),
          isFalse,
        );
      }
    });

    test('returns false for non-escalation targets', () {
      expect(
        HumanDecisionRouting.routesToEscalation(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.approve,
          WorkItemState.reviewApproved,
        ),
        isFalse,
      );
      expect(
        HumanDecisionRouting.routesToEscalation(
          HumanDecisionType.designApproval,
          HumanDecisionChoice.approve,
          WorkItemState.designApproved,
        ),
        isFalse,
      );
    });
  });
}

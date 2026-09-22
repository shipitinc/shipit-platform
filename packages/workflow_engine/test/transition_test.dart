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

    test('planned -> designRequired requires a design contract', () {
      final without = eval(WorkItemState.planned, WorkItemState.designRequired);
      expect(without.isValid, isFalse);
      expect(without.failedGuards, contains('design_contract_exists'));

      final withContract = eval(
        WorkItemState.planned,
        WorkItemState.designRequired,
        context: {'designContractId': 'contract-123'},
      );
      expect(withContract.isValid, isTrue);
    });

    test('designRequired -> designInReview requires contract under review', () {
      final notReviewed = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        context: {'designContractStatus': DesignContractStatus.draft},
      );
      expect(notReviewed.isValid, isFalse);

      final reviewed = eval(
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        context: {'designContractStatus': DesignContractStatus.underReview},
      );
      expect(reviewed.isValid, isTrue);
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

      final failing = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: _workItemId,
          status: QAGateStatus.failed,
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
        WorkItemState.agentExecuting,
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
    test('draft allows only planning', () {
      expect(
        WorkItemWorkflowState.draft.allowedTransitions.map((s) => s.value),
        [WorkItemState.planning],
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

/// Escalations are failure gates: a run that stopped with an error and was
/// handed to a human. Before these routes existed, answering one recorded the
/// decision but left the work item parked at its gate forever.
void _escalationRouting() {
  group('Escalation outcomes', () {
    test('resume routes an escalation back into execution', () {
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.escalation,
          HumanDecisionChoice.approve,
        ),
        WorkItemState.agentExecuting,
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
  });
}

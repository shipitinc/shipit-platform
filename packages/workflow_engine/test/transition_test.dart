import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:test/test.dart';

void main() {
  group('WorkItemTransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    test(
      'allows legal transition: draft -> designInReview with design contract',
      () {
        final context = {'designContractId': 'contract-123'};

        final transition = engine.transitionWorkItem(
          WorkItemState.draft,
          WorkItemState.designInReview,
          TransitionTrigger.systemEvent,
          context,
        );

        expect(transition.isValid, isTrue);
        expect(transition.from.value, equals(WorkItemState.draft));
        expect(transition.to.value, equals(WorkItemState.designInReview));
      },
    );

    test('rejects illegal transition: draft -> agentExecuting', () {
      final context = <String, dynamic>{};

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.draft,
          WorkItemState.agentExecuting,
          TransitionTrigger.systemEvent,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('rejects draft -> designInReview without design contract', () {
      final context = <String, dynamic>{};

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.draft,
          WorkItemState.designInReview,
          TransitionTrigger.systemEvent,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('allows designInReview -> designApproved with approve decision', () {
      final decision = HumanDecision(
        decisionId: 'dec-1',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.designApproval,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.approve,
        rationale: 'LGTM',
        timestamp: DateTime.now(),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.now(),
        ),
      );

      final context = {'humanDecision': decision};

      final transition = engine.transitionWorkItem(
        WorkItemState.designInReview,
        WorkItemState.designApproved,
        TransitionTrigger.humanDecision,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('decision survives serialization and still drives transition', () {
      final decision = HumanDecision(
        decisionId: 'dec-1',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.designApproval,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.approve,
        rationale: 'Approved after persistence roundtrip',
        timestamp: DateTime.parse('2024-01-02T12:00:00Z'),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.parse('2024-01-02T12:00:01Z'),
        ),
        context: DecisionContext(
          workflowState: 'design_in_review',
          availableOptions: ['approve', 'reject'],
        ),
      );

      final restored = HumanDecision.fromJson(decision.toJson());

      final transition = engine.transitionWorkItem(
        WorkItemState.designInReview,
        WorkItemState.designApproved,
        TransitionTrigger.humanDecision,
        {'humanDecision': restored},
      );

      expect(transition.isValid, isTrue);
      expect(restored.signature.algorithm, equals('Ed25519'));
      expect(restored.context?.workflowState, equals('design_in_review'));
    });

    test('rejects designInReview -> designApproved with reject decision', () {
      final decision = HumanDecision(
        decisionId: 'dec-1',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.designApproval,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.reject,
        rationale: 'Needs changes',
        timestamp: DateTime.now(),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.now(),
        ),
      );

      final context = {'humanDecision': decision};

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.designInReview,
          WorkItemState.designApproved,
          TransitionTrigger.humanDecision,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('allows designApproved -> agentExecuting with agent available', () {
      final context = {'agentAvailable': true, 'capabilitiesMatch': true};

      final transition = engine.transitionWorkItem(
        WorkItemState.designApproved,
        WorkItemState.agentExecuting,
        TransitionTrigger.systemEvent,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('rejects designApproved -> agentExecuting without agent', () {
      final context = {'agentAvailable': false, 'capabilitiesMatch': true};

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.designApproved,
          WorkItemState.agentExecuting,
          TransitionTrigger.systemEvent,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('allows agentCompleted -> qaInProgress with QA contract', () {
      final context = {'qaContractId': 'qa-123'};

      final transition = engine.transitionWorkItem(
        WorkItemState.agentCompleted,
        WorkItemState.qaInProgress,
        TransitionTrigger.systemEvent,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('allows qaInProgress -> qaPassed when all required gates pass', () {
      final gateResults = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: 'wi-1',
          status: QAGateStatus.passed,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
        QAGateResult(
          gateId: 'unit-tests',
          workItemId: 'wi-1',
          status: QAGateStatus.passed,
          evidence: [],
          evaluatedAt: DateTime.now(),
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
            config: {},
            evidenceTypes: ['test-report'],
          ),
          QAGateDefinition(
            gateId: 'unit-tests',
            type: 'unit-tests',
            required: true,
            config: {},
            evidenceTypes: ['test-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = {'gateResults': gateResults, 'qaContract': qaContract};

      final transition = engine.transitionWorkItem(
        WorkItemState.qaInProgress,
        WorkItemState.qaPassed,
        TransitionTrigger.systemEvent,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('rejects qaInProgress -> qaPassed when required gate fails', () {
      final gateResults = [
        QAGateResult(
          gateId: 'static-analysis',
          workItemId: 'wi-1',
          status: QAGateStatus.failed,
          evidence: [],
          evaluatedAt: DateTime.now(),
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
            config: {},
            evidenceTypes: ['test-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = {'gateResults': gateResults, 'qaContract': qaContract};

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.qaInProgress,
          WorkItemState.qaPassed,
          TransitionTrigger.systemEvent,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test(
      'rejects qaInProgress -> qaPassed when required gate is not_executed',
      () {
        final gateResults = [
          QAGateResult(
            gateId: 'e2e',
            workItemId: 'wi-1',
            status: QAGateStatus.notExecuted,
            evidence: [],
            evaluatedAt: DateTime.now(),
            evidenceDeterminations: [
              QAEvidenceDetermination(
                evidenceId: 'E-01',
                determination: EvidenceDetermination.readyNotExecuted,
                reasons: 'Headless iOS device job not yet provisioned',
              ),
            ],
          ),
        ];

        final qaContract = QAContract(
          contractId: 'qa-1',
          workItemCategory: WorkItemCategory.feature,
          gates: [
            QAGateDefinition(
              gateId: 'e2e',
              type: 'integration-tests',
              required: true,
              config: {},
              evidenceTypes: ['test-report'],
            ),
          ],
          version: '1.0.0',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final context = {'gateResults': gateResults, 'qaContract': qaContract};

        expect(
          () => engine.transitionWorkItem(
            WorkItemState.qaInProgress,
            WorkItemState.qaPassed,
            TransitionTrigger.systemEvent,
            context,
          ),
          throwsA(isA<InvalidTransitionException>()),
        );
      },
    );

    test('allows qaInProgress -> qaPassed when required gate is N/A', () {
      final gateResults = [
        QAGateResult(
          gateId: 'visual',
          workItemId: 'wi-1',
          status: QAGateStatus.notApplicable,
          evidence: [],
          evaluatedAt: DateTime.now(),
        ),
      ];

      final qaContract = QAContract(
        contractId: 'qa-1',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'visual',
            type: 'static-analysis',
            required: true,
            config: {},
            evidenceTypes: ['accessibility-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = {'gateResults': gateResults, 'qaContract': qaContract};

      final transition = engine.transitionWorkItem(
        WorkItemState.qaInProgress,
        WorkItemState.qaPassed,
        TransitionTrigger.systemEvent,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('allows qaInProgress -> qaPassed when required gate is skipped with '
        'an authority ref', () {
      final gateResults = [
        QAGateResult(
          gateId: 'e2e',
          workItemId: 'wi-1',
          status: QAGateStatus.skipped,
          evidence: [],
          evaluatedAt: DateTime.now(),
          evidenceDeterminations: [
            QAEvidenceDetermination(
              evidenceId: 'E-01',
              determination: EvidenceDetermination.skipped,
              reasons: 'Manual e2e charter covers this journey',
              authorityRef: 'decision-123',
            ),
          ],
        ),
      ];

      final qaContract = QAContract(
        contractId: 'qa-1',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'e2e',
            type: 'integration-tests',
            required: true,
            config: {},
            evidenceTypes: ['test-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final context = {'gateResults': gateResults, 'qaContract': qaContract};

      final transition = engine.transitionWorkItem(
        WorkItemState.qaInProgress,
        WorkItemState.qaPassed,
        TransitionTrigger.systemEvent,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('allows qaFailed -> qaPassed with waiver decision', () {
      final decision = HumanDecision(
        decisionId: 'dec-2',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.qaWaiver,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.waive,
        rationale: 'Known issue, accepting risk',
        timestamp: DateTime.now(),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.now(),
        ),
      );

      final context = {'humanDecision': decision};

      final transition = engine.transitionWorkItem(
        WorkItemState.qaFailed,
        WorkItemState.qaPassed,
        TransitionTrigger.humanDecision,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('allows qaFailed -> designInReview with rework decision', () {
      final decision = HumanDecision(
        decisionId: 'dec-3',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.qaRework,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.rework,
        rationale: 'Revisit design before retry',
        timestamp: DateTime.now(),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.now(),
        ),
      );

      final context = {'humanDecision': decision};

      final transition = engine.transitionWorkItem(
        WorkItemState.qaFailed,
        WorkItemState.designInReview,
        TransitionTrigger.humanDecision,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('allows qaFailed -> agentExecuting with reject decision', () {
      final decision = HumanDecision(
        decisionId: 'dec-4',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.qaRework,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.reject,
        rationale: 'Redo implementation with feedback',
        timestamp: DateTime.now(),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.now(),
        ),
      );

      final context = {'humanDecision': decision};

      final transition = engine.transitionWorkItem(
        WorkItemState.qaFailed,
        WorkItemState.agentExecuting,
        TransitionTrigger.humanDecision,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('rejects qaFailed -> designInReview with wrong decision', () {
      final decision = HumanDecision(
        decisionId: 'dec-5',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.qaWaiver,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.waive,
        rationale: 'Accepting risk',
        timestamp: DateTime.now(),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.now(),
        ),
      );

      final context = {'humanDecision': decision};

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.qaFailed,
          WorkItemState.designInReview,
          TransitionTrigger.humanDecision,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('allows qaPassed -> deploying with artifact built', () {
      final artifact = DeploymentArtifact(
        artifactId: 'art-1',
        contentHash: 'hash',
        manifest: ArtifactManifest(
          name: 'app',
          version: '1.0.0',
          gitCommit: 'commit',
          files: [],
          sbom: SoftwareBillOfMaterials(
            format: 'CycloneDX',
            version: '1.5',
            components: [],
          ),
        ),
        builtAt: DateTime.now(),
        builtBy: 'session-1',
      );

      final context = {'deploymentArtifact': artifact};

      final transition = engine.transitionWorkItem(
        WorkItemState.qaPassed,
        WorkItemState.deploying,
        TransitionTrigger.systemEvent,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('rejects qaPassed -> deploying without artifact', () {
      final context = <String, dynamic>{};

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.qaPassed,
          WorkItemState.deploying,
          TransitionTrigger.systemEvent,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('allows deploying -> deployed for staging without human approval', () {
      final artifact = DeploymentArtifact(
        artifactId: 'art-1',
        contentHash: 'hash',
        manifest: ArtifactManifest(
          name: 'app',
          version: '1.0.0',
          gitCommit: 'commit',
          files: [],
          sbom: SoftwareBillOfMaterials(
            format: 'CycloneDX',
            version: '1.5',
            components: [],
          ),
        ),
        builtAt: DateTime.now(),
        builtBy: 'session-1',
      );

      final context = {
        'deploymentArtifact': artifact,
        'targetEnvironment': 'staging',
      };

      final transition = engine.transitionWorkItem(
        WorkItemState.deploying,
        WorkItemState.deployed,
        TransitionTrigger.systemEvent,
        context,
      );

      expect(transition.isValid, isTrue);
    });

    test('requires human approval for production deployment', () {
      final artifact = DeploymentArtifact(
        artifactId: 'art-1',
        contentHash: 'hash',
        manifest: ArtifactManifest(
          name: 'app',
          version: '1.0.0',
          gitCommit: 'commit',
          files: [],
          sbom: SoftwareBillOfMaterials(
            format: 'CycloneDX',
            version: '1.5',
            components: [],
          ),
        ),
        builtAt: DateTime.now(),
        builtBy: 'session-1',
      );

      final context = {
        'deploymentArtifact': artifact,
        'targetEnvironment': 'production',
      };

      expect(
        () => engine.transitionWorkItem(
          WorkItemState.deploying,
          WorkItemState.deployed,
          TransitionTrigger.systemEvent,
          context,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('allows deploying -> deployed for production with approval', () {
      final artifact = DeploymentArtifact(
        artifactId: 'art-1',
        contentHash: 'hash',
        manifest: ArtifactManifest(
          name: 'app',
          version: '1.0.0',
          gitCommit: 'commit',
          files: [],
          sbom: SoftwareBillOfMaterials(
            format: 'CycloneDX',
            version: '1.5',
            components: [],
          ),
        ),
        builtAt: DateTime.now(),
        builtBy: 'session-1',
      );

      final decision = HumanDecision(
        decisionId: 'dec-3',
        workflowId: 'wi-1',
        decisionType: HumanDecisionType.deploymentApproval,
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.approve,
        rationale: 'Staging verified',
        timestamp: DateTime.now(),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'key',
          signature: 'sig',
          signedAt: DateTime.now(),
        ),
      );

      final context = {
        'deploymentArtifact': artifact,
        'targetEnvironment': 'production',
        'humanDecision': decision,
      };

      final transition = engine.transitionWorkItem(
        WorkItemState.deploying,
        WorkItemState.deployed,
        TransitionTrigger.humanDecision,
        context,
      );

      expect(transition.isValid, isTrue);
    });
  });

  group('DesignTransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    test('allows draft -> underReview', () {
      final transition = engine.transitionDesignContract(
        DesignContractStatus.draft,
        DesignContractStatus.underReview,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows underReview -> approved', () {
      final transition = engine.transitionDesignContract(
        DesignContractStatus.underReview,
        DesignContractStatus.approved,
        TransitionTrigger.humanDecision,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows underReview -> rejected', () {
      final transition = engine.transitionDesignContract(
        DesignContractStatus.underReview,
        DesignContractStatus.rejected,
        TransitionTrigger.humanDecision,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows rejected -> draft', () {
      final transition = engine.transitionDesignContract(
        DesignContractStatus.rejected,
        DesignContractStatus.draft,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('rejects approved -> rejected', () {
      expect(
        () => engine.transitionDesignContract(
          DesignContractStatus.approved,
          DesignContractStatus.rejected,
          TransitionTrigger.systemEvent,
          {},
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });
  });

  group('QATransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    test('allows pending -> inProgress', () {
      final transition = engine.transitionQA(
        QAStatus.pending,
        QAStatus.inProgress,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows inProgress -> passed', () {
      final transition = engine.transitionQA(
        QAStatus.inProgress,
        QAStatus.passed,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows inProgress -> failed', () {
      final transition = engine.transitionQA(
        QAStatus.inProgress,
        QAStatus.failed,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows failed -> inProgress (rework)', () {
      final transition = engine.transitionQA(
        QAStatus.failed,
        QAStatus.inProgress,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows failed -> waived', () {
      final transition = engine.transitionQA(
        QAStatus.failed,
        QAStatus.waived,
        TransitionTrigger.humanDecision,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('rejects passed -> failed', () {
      expect(
        () => engine.transitionQA(
          QAStatus.passed,
          QAStatus.failed,
          TransitionTrigger.systemEvent,
          {},
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });
  });

  group('DeploymentTransitions', () {
    late WorkflowEngine engine;

    setUp(() {
      engine = const WorkflowEngine();
    });

    test('allows building -> promoting', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.building,
        DeploymentPhase.promoting,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows promoting -> deploying', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.promoting,
        DeploymentPhase.deploying,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows deploying -> validating', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.deploying,
        DeploymentPhase.validating,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows validating -> completed', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.validating,
        DeploymentPhase.completed,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows validating -> failed', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.validating,
        DeploymentPhase.failed,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows failed -> rolledBack', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.failed,
        DeploymentPhase.rolledBack,
        TransitionTrigger.systemEvent,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('allows failed -> deploying (retry)', () {
      final transition = engine.transitionDeployment(
        DeploymentPhase.failed,
        DeploymentPhase.deploying,
        TransitionTrigger.manual,
        {},
      );
      expect(transition.isValid, isTrue);
    });

    test('rejects completed -> failed', () {
      expect(
        () => engine.transitionDeployment(
          DeploymentPhase.completed,
          DeploymentPhase.failed,
          TransitionTrigger.systemEvent,
          {},
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
    });
  });

  group('WorkflowState allowedTransitions', () {
    test('WorkItemWorkflowState.draft allows only designInReview', () {
      final state = WorkItemWorkflowState.draft;
      expect(state.allowedTransitions.length, equals(1));
      expect(
        state.allowedTransitions.first.value,
        equals(WorkItemState.designInReview),
      );
    });

    test(
      'WorkItemWorkflowState.designInReview allows approved and rejected',
      () {
        final state = WorkItemWorkflowState.designInReview;
        expect(state.allowedTransitions.length, equals(2));
        expect(
          state.allowedTransitions.map((s) => s.value).toSet(),
          equals({WorkItemState.designApproved, WorkItemState.designRejected}),
        );
      },
    );

    test('WorkItemWorkflowState.done allows no transitions', () {
      final state = WorkItemWorkflowState.done;
      expect(state.allowedTransitions, isEmpty);
    });
  });
}

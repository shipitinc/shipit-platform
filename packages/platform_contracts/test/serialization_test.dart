import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('ProductManifest serialization', () {
    test('serializes to JSON and back', () {
      final manifest = ProductManifest(
        productId: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Product',
        version: '1.0.0',
        capabilities: ['flutter', 'web'],
        environments: [
          EnvironmentConfig(
            name: 'staging',
            type: 'cloud-run',
            config: {'region': 'us-central1'},
          ),
        ],
        contracts: ProductContracts(
          workItemCategories: ['feature', 'bugfix'],
          designContract: DesignContractSpec(
            requiredArtifacts: ['architecture-decision-record', 'api-spec'],
            reviewers: ['alice@example.com', 'bob@example.com'],
            approvalThreshold: 2,
          ),
          qaContract: QAContractSpec(
            gates: [
              QAGateSpec(
                gateId: 'static-analysis',
                type: 'static-analysis',
                required: true,
                config: {'tool': 'dart analyze'},
              ),
            ],
          ),
          deploymentContract: DeploymentContractSpec(
            promotionPath: ['staging', 'production'],
            approvalGates: [
              ApprovalGateSpec(
                environment: 'production',
                approvers: ['alice@example.com'],
                threshold: 1,
              ),
            ],
          ),
        ),
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

      final json = manifest.toJson();
      final decoded = ProductManifest.fromJson(json);

      expect(decoded.productId, equals(manifest.productId));
      expect(decoded.name, equals(manifest.name));
      expect(decoded.version, equals(manifest.version));
      expect(decoded.capabilities, equals(manifest.capabilities));
      expect(decoded.environments.length, equals(1));
      expect(
        decoded.contracts.workItemCategories,
        equals(manifest.contracts.workItemCategories),
      );
    });
  });

  group('WorkItem serialization', () {
    test('serializes to JSON and back', () {
      final workItem = WorkItem(
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        productId: '123e4567-e89b-12d3-a456-426614174000',
        category: WorkItemCategory.feature,
        title: 'Add login feature',
        state: WorkItemState.draft,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

      final json = workItem.toJson();
      final decoded = WorkItem.fromJson(json);

      expect(decoded.workItemId, equals(workItem.workItemId));
      expect(decoded.category, equals(WorkItemCategory.feature));
      expect(decoded.state, equals(WorkItemState.draft));
    });

    test('copyWith updates fields correctly', () {
      final workItem = WorkItem(
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        productId: '123e4567-e89b-12d3-a456-426614174000',
        category: WorkItemCategory.feature,
        title: 'Add login feature',
        state: WorkItemState.draft,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

      final updated = workItem.copyWith(state: WorkItemState.designInReview);

      expect(updated.state, equals(WorkItemState.designInReview));
      expect(updated.workItemId, equals(workItem.workItemId));
    });
  });

  group('DesignContract serialization', () {
    test('maps under_review status to and from JSON', () {
      final contract = DesignContract(
        contractId: '123e4567-e89b-12d3-a456-4266141740aa',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        requiredArtifacts: [
          RequiredArtifact(
            artifactType: 'architecture-decision-record',
            description: 'ADR for this feature',
            required: true,
          ),
        ],
        reviewers: ['alice@example.com'],
        approvalThreshold: 1,
        status: DesignContractStatus.underReview,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

      final json = contract.toJson();
      expect(json['status'], equals('under_review'));

      final decoded = DesignContract.fromJson(json);
      expect(decoded.status, equals(DesignContractStatus.underReview));
    });
  });

  group('HumanDecision serialization', () {
    test('serializes a resolved decision to JSON and back', () {
      final decision = HumanDecision(
        decisionId: '123e4567-e89b-12d3-a456-426614174002',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        decisionType: HumanDecisionType.designApproval,
        status: HumanDecisionStatus.resolved,
        question: 'Approve the design revision for the login feature?',
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.approve,
        rationale: 'Design looks good',
        timestamp: DateTime.parse('2024-01-01T12:00:00Z'),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'base64key',
          signature: 'base64sig',
          signedAt: DateTime.parse('2024-01-01T12:00:00Z'),
        ),
        context: DecisionContext(
          workflowState: 'waiting_for_human_decision',
          availableOptions: ['approve', 'reject'],
        ),
        requestedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );

      final json = decision.toJson();
      final decoded = HumanDecision.fromJson(json);

      expect(decoded.decisionId, equals(decision.decisionId));
      expect(decoded.workItemId, equals(decision.workItemId));
      expect(decoded.status, equals(HumanDecisionStatus.resolved));
      expect(decoded.choice, equals(HumanDecisionChoice.approve));
      expect(decoded.signature!.algorithm, equals('Ed25519'));
      expect(json['status'], equals('resolved'));
      expect(json['workItemId'], isNotNull);
      expect(json.containsKey('workflowId'), isFalse);
    });

    test('pending decision omits resolution fields', () {
      final decision = HumanDecision(
        decisionId: '123e4567-e89b-12d3-a456-426614174002',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        decisionType: HumanDecisionType.engineeringReview,
        status: HumanDecisionStatus.pending,
        question: 'Does this implementation satisfy the design contract?',
        options: [
          HumanDecisionOption(
            optionId: 'approve',
            label: 'Approve',
            recommended: true,
          ),
          const HumanDecisionOption(optionId: 'reject', label: 'Reject'),
          const HumanDecisionOption(optionId: 'rework', label: 'Rework'),
        ],
        recommendation: 'approve',
        requestedAt: DateTime.parse('2024-01-01T10:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
      );

      final json = decision.toJson();
      final decoded = HumanDecision.fromJson(json);

      expect(decoded.status, equals(HumanDecisionStatus.pending));
      expect(decoded.choice, isNull);
      expect(decoded.decider, isNull);
      expect(decoded.signature, isNull);
      expect(json.containsKey('choice'), isFalse);
      expect(json.containsKey('decider'), isFalse);
    });
  });

  group('AgentResult serialization', () {
    test('serializes to JSON and back', () {
      final result = AgentResult(
        resultId: '123e4567-e89b-12d3-a456-426614174003',
        sessionId: '123e4567-e89b-12d3-a456-426614174004',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        status: AgentResultStatus.completed,
        artifacts: [
          AgentArtifact(
            artifactId: '123e4567-e89b-12d3-a456-426614174005',
            type: 'source-code',
            path: 'lib/main.dart',
            sha256: 'a' * 64,
            sizeBytes: 1024,
            mediaType: 'text/plain',
          ),
        ],
        diagnostics: AgentDiagnostics(
          exitCode: 0,
          durationMs: 30000,
          toolCalls: 15,
          errors: [],
          warnings: [],
        ),
        structuredResult: {'testsPassed': 42, 'coverage': 0.85},
        completedAt: DateTime.parse('2024-01-01T13:00:00Z'),
      );

      final json = result.toJson();
      final decoded = AgentResult.fromJson(json);

      expect(decoded.resultId, equals(result.resultId));
      expect(decoded.status, equals(AgentResultStatus.completed));
      expect(decoded.artifacts.length, equals(1));
      expect(decoded.diagnostics.exitCode, equals(0));
    });
  });

  group('AgentExecution records serialization', () {
    test('AgentExecutionRequest round-trips role, workspace, config', () {
      final request = AgentExecutionRequest(
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        role: AgentRole.implementer,
        runtimeTypeId: 'opencode',
        workspace: const AgentWorkspace(
          workspaceId: 'ws-001',
          path: '/tmp/ws',
          startingRevision: 'HEAD',
        ),
        instruction: 'Implement add so the test passes.',
        timeoutSeconds: 300,
        expectedArtifacts: const [
          ExpectedArtifact(
            description: 'Modified calculator',
            pathPattern: 'lib/calculator.dart',
            required: true,
          ),
        ],
        runtimeConfig: const {'model': 'opencode/big-pickle'},
        createdAt: DateTime.parse('2024-01-02T12:30:00Z'),
      );

      final decoded = AgentExecutionRequest.fromJson(request.toJson());
      expect(decoded.role, equals(AgentRole.implementer));
      expect(decoded.runtimeTypeId, equals('opencode'));
      expect(decoded.workspace.path, equals('/tmp/ws'));
      expect(decoded.runtimeConfig, equals({'model': 'opencode/big-pickle'}));
      expect(decoded.expectedArtifacts[0].required, isTrue);
    });

    test('AgentExecution round-trips status and session linkage', () {
      final execution = AgentExecution(
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        requestId: '123e4567-e89b-12d3-a456-426614174011',
        runtimeTypeId: 'opencode',
        role: AgentRole.implementer,
        status: AgentSessionStatus.orphaned,
        workspace: const AgentWorkspace(workspaceId: 'ws-001', path: '/tmp/ws'),
        sessionId: 'ses_ab01',
        startedAt: DateTime.parse('2024-01-02T12:30:01Z'),
        reason: 'child process exited before result capture',
      );

      final decoded = AgentExecution.fromJson(execution.toJson());
      expect(decoded.status, equals(AgentSessionStatus.orphaned));
      expect(decoded.sessionId, equals('ses_ab01'));
      expect(decoded.isTerminal, isTrue);
    });

    test('AgentExecution copyWith preserves terminal status fields', () {
      final execution = AgentExecution(
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        requestId: '123e4567-e89b-12d3-a456-426614174011',
        runtimeTypeId: 'opencode',
        role: AgentRole.implementer,
        status: AgentSessionStatus.running,
        workspace: const AgentWorkspace(workspaceId: 'ws-001', path: '/tmp/ws'),
      );
      final updated = execution.copyWith(
        status: AgentSessionStatus.completed,
        sessionId: null,
      );
      expect(updated.status, equals(AgentSessionStatus.completed));
      expect(updated.sessionId, isNull);
    });

    test('AgentEventRecord round-trips wire event type', () {
      final event = AgentEventRecord(
        eventId: '123e4567-e89b-12d3-a456-426614174020',
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        sequence: 1,
        type: AgentEventType.toolCompleted,
        occurredAt: DateTime.parse('2024-01-02T12:30:05Z'),
        payload: const {'tool': 'write'},
      );

      final json = event.toJson();
      expect(json['type'], equals('tool_completed'));
      final decoded = AgentEventRecord.fromJson(json);
      expect(decoded.type, equals(AgentEventType.toolCompleted));
    });

    test('PlatformVerification round-trips evidence kind', () {
      final verification = PlatformVerification(
        verificationId: '123e4567-e89b-12d3-a456-426614174030',
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        checkName: 'dart test (independent)',
        status: AgentClaimStatus.passed,
        mechanism: 'process_dart_test',
        command: 'dart test',
        capturedAt: DateTime.parse('2024-01-02T12:34:00Z'),
      );

      final json = verification.toJson();
      expect(json['evidenceKind'], equals('platform_verified_evidence'));
      final decoded = PlatformVerification.fromJson(json);
      expect(
        decoded.evidenceKind,
        equals(EvidenceKind.platformVerifiedEvidence),
      );
      expect(decoded.status, equals(AgentClaimStatus.passed));
    });
  });

  group('DeploymentArtifact serialization', () {
    test('serializes to JSON and back', () {
      final artifact = DeploymentArtifact(
        artifactId: '123e4567-e89b-12d3-a456-426614174006',
        contentHash: 'b' * 64,
        manifest: ArtifactManifest(
          name: 'my-app',
          version: '1.0.0',
          gitCommit: 'c' * 40,
          files: [
            ArtifactFile(
              path: 'build/app.apk',
              sha256: 'd' * 64,
              sizeBytes: 10485760,
              mediaType: 'application/vnd.android.package-archive',
            ),
          ],
          sbom: SoftwareBillOfMaterials(
            format: 'CycloneDX',
            version: '1.5',
            components: [
              SBOMComponent(
                name: 'flutter',
                version: '3.22.0',
                type: 'framework',
                purl: 'pkg:pub/flutter@3.22.0',
              ),
            ],
          ),
        ),
        builtAt: DateTime.parse('2024-01-01T14:00:00Z'),
        builtBy: '123e4567-e89b-12d3-a456-426614174004',
      );

      final json = artifact.toJson();
      final decoded = DeploymentArtifact.fromJson(json);

      expect(decoded.artifactId, equals(artifact.artifactId));
      expect(decoded.contentHash, equals(artifact.contentHash));
      expect(decoded.manifest.name, equals('my-app'));
      expect(decoded.manifest.files.length, equals(1));
    });
  });

  group('Enums', () {
    test('WorkerCapability has expected values', () {
      expect(WorkerCapability.values.length, equals(7));
      expect(WorkerCapability.linux.name, equals('linux'));
      expect(WorkerCapability.docker.name, equals('docker'));
      expect(WorkerCapability.flutter.name, equals('flutter'));
      expect(WorkerCapability.android.name, equals('android'));
      expect(WorkerCapability.macos.name, equals('macos'));
      expect(WorkerCapability.ios.name, equals('ios'));
      expect(WorkerCapability.xcode.name, equals('xcode'));
    });

    test('WorkItemState has expected values', () {
      expect(WorkItemState.values.length, equals(25));
      expect(WorkItemState.draft.name, equals('draft'));
      expect(WorkItemState.completed.isTerminal, isTrue);
      expect(WorkItemState.cancelled.isTerminal, isTrue);
      expect(WorkItemState.terminated.isTerminal, isTrue);
      expect(WorkItemState.done.isTerminal, isTrue);
      expect(WorkItemState.designApproved.isTerminal, isFalse);
      expect(
        WorkItemState.waitingForHumanDecision.isWaitingForHumanDecision,
        isTrue,
      );
    });

    test('QAGateStatus has AEF-aligned non-executed values', () {
      expect(QAGateStatus.notExecuted.name, equals('notExecuted'));
      expect(QAGateStatus.notApplicable.name, equals('notApplicable'));
      expect(QAGateStatus.skipped, isNot(equals(QAGateStatus.notExecuted)));
    });
  });

  group('QAContract serialization', () {
    test('round-trips evidence rows with AEF wire enums', () {
      final contract = QAContract(
        contractId: '123e4567-e89b-12d3-a456-42661417400a',
        workItemCategory: WorkItemCategory.feature,
        gates: [
          QAGateDefinition(
            gateId: 'e2e',
            type: 'integration-tests',
            required: true,
            config: {'device': 'headless'},
            evidenceTypes: ['test-report'],
          ),
        ],
        version: '1.0.0',
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-01T00:00:00Z'),
        evidenceRows: [
          QAEvidenceRow(
            evidenceId: 'E-01',
            title: 'App journey e2e',
            requirement: EvidenceRowRequirement.required,
            testMethod: TestMethod.automated,
            artifactRef: 'apps/app/integration_test/app_journey_test.dart',
            params: '--dart-define=E2E_VERIFICATION_CODE',
            prerequisites: 'headless-device-job:ios',
            traceabilityRefs: ['REQ-01'],
            contractDetermination: ContractDetermination.expectedToExecute,
          ),
          QAEvidenceRow(
            evidenceId: 'E-02',
            requirement: EvidenceRowRequirement.optional,
            testMethod: TestMethod.visual,
            contractDetermination: ContractDetermination.skippedByContract,
            determinationReasons: 'No visual baseline for this feature yet',
          ),
        ],
      );

      final json = contract.toJson();
      expect(json['evidenceRows'], hasLength(2));
      expect(json['evidenceRows'][0]['requirement'], equals('required'));
      expect(
        json['evidenceRows'][0]['contractDetermination'],
        equals('expected_to_execute'),
      );
      expect(
        json['evidenceRows'][1]['contractDetermination'],
        equals('skipped_by_contract'),
      );

      final decoded = QAContract.fromJson(json);
      expect(decoded.evidenceRows, hasLength(2));
      expect(
        decoded.evidenceRows![0].contractDetermination,
        equals(ContractDetermination.expectedToExecute),
      );
      expect(decoded.evidenceRows![0].traceabilityRefs, equals(['REQ-01']));
      expect(
        decoded.evidenceRows![1].contractDetermination,
        equals(ContractDetermination.skippedByContract),
      );
      expect(decoded.evidenceRows![1].determinationReasons, isNotNull);
    });
  });

  group('QAGateResult serialization', () {
    test('round-trips not_executed status and evidence determinations', () {
      final result = QAGateResult(
        gateId: 'e2e',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        status: QAGateStatus.notExecuted,
        evidence: const [],
        evaluatedAt: DateTime.parse('2024-01-02T10:00:00Z'),
        evidenceDeterminations: [
          QAEvidenceDetermination(
            evidenceId: 'E-01',
            determination: EvidenceDetermination.readyNotExecuted,
            artifactRef: 'apps/app/integration_test/app_journey_test.dart',
            params: '--dart-define=E2E_VERIFICATION_CODE',
            prerequisites: 'headless-device-job:ios',
            reasons: 'Headless iOS device job not yet provisioned',
          ),
          QAEvidenceDetermination(
            evidenceId: 'E-02',
            determination: EvidenceDetermination.skipped,
            reasons: 'No visual baseline',
            authorityRef: '123e4567-e89b-12d3-a456-42661417400b',
          ),
        ],
      );

      final json = result.toJson();
      expect(json['status'], equals('not_executed'));
      expect(json['evidenceDeterminations'], hasLength(2));
      expect(
        json['evidenceDeterminations'][0]['determination'],
        equals('ready_not_executed'),
      );
      expect(
        json['evidenceDeterminations'][1]['determination'],
        equals('skipped'),
      );
      expect(json['evidenceDeterminations'][1]['authorityRef'], isNotNull);

      final decoded = QAGateResult.fromJson(json);
      expect(decoded.status, equals(QAGateStatus.notExecuted));
      expect(decoded.evidenceDeterminations, hasLength(2));
      expect(
        decoded.evidenceDeterminations![0].determination,
        equals(EvidenceDetermination.readyNotExecuted),
      );
      expect(
        decoded.evidenceDeterminations![1].determination,
        equals(EvidenceDetermination.skipped),
      );
      expect(decoded.evidenceDeterminations![1].authorityRef, isNotNull);
    });

    test('maps not_applicable to and from JSON', () {
      final result = QAGateResult(
        gateId: 'visual',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        status: QAGateStatus.notApplicable,
        evidence: const [],
        evaluatedAt: DateTime.parse('2024-01-02T10:00:00Z'),
      );

      final json = result.toJson();
      expect(json['status'], equals('not_applicable'));
      expect(
        QAGateResult.fromJson(json).status,
        equals(QAGateStatus.notApplicable),
      );
    });
  });

  group('ArtifactReference serialization', () {
    test('round-trips with wire artifact type', () {
      final ref = ArtifactReference(
        artifactId: '123e4567-e89b-12d3-a456-426614174030',
        artifactType: ArtifactType.qaEvidence,
        uri: 'artifacts/static-analysis.json',
        provider: 'ci',
        contentHash: 'c' * 64,
        createdAt: DateTime.parse('2024-01-02T10:00:00Z'),
      );

      final json = ref.toJson();
      expect(json['artifactType'], equals('qa_evidence'));
      final decoded = ArtifactReference.fromJson(json);
      expect(decoded.artifactType, equals(ArtifactType.qaEvidence));
      expect(decoded.uri, equals(ref.uri));
    });
  });

  group('WorkflowActor serialization', () {
    test('round-trips with wire actor type', () {
      const actor = WorkflowActor(
        actorId: 'orch-1',
        actorType: ActorType.orchestrator,
        displayName: 'ShipIt Orchestrator',
      );

      final json = actor.toJson();
      expect(json['actorType'], equals('orchestrator'));
      final decoded = WorkflowActor.fromJson(json);
      expect(decoded.actorType, equals(ActorType.orchestrator));
      expect(decoded.displayName, equals('ShipIt Orchestrator'));
    });
  });

  group('WorkflowTransitionRecord serialization', () {
    test('round-trips accepted transition with guard evaluations', () {
      final record = WorkflowTransitionRecord(
        transitionId: '123e4567-e89b-12d3-a456-426614174040',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        fromState: WorkItemState.planned,
        toState: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        actorType: ActorType.orchestrator,
        actorId: 'orch-1',
        outcome: TransitionOutcome.accepted,
        occurredAt: DateTime.parse('2024-01-02T12:00:00Z'),
        guardEvaluations: [
          TransitionGuardEvaluation(
            guardName: 'design_contract_exists',
            passed: true,
          ),
        ],
        idempotencyKey: 'tx-001',
      );

      final json = record.toJson();
      expect(json['outcome'], equals('accepted'));
      expect(json['fromState'], equals('planned'));
      expect(json['actorType'], equals('orchestrator'));
      expect(json['trigger'], equals('system_event'));

      final decoded = WorkflowTransitionRecord.fromJson(json);
      expect(decoded.outcome, equals(TransitionOutcome.accepted));
      expect(decoded.fromState, equals(WorkItemState.planned));
      expect(decoded.toState, equals(WorkItemState.designRequired));
      expect(decoded.trigger, equals(TransitionTrigger.systemEvent));
      expect(decoded.guardEvaluations.single.passed, isTrue);
    });

    test('round-trips rejected transition', () {
      final record = WorkflowTransitionRecord(
        transitionId: '123e4567-e89b-12d3-a456-426614174041',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        fromState: WorkItemState.draft,
        toState: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actorType: ActorType.orchestrator,
        actorId: 'orch-1',
        outcome: TransitionOutcome.rejected,
        reason: 'Transition from draft to agent_executing is not allowed',
        occurredAt: DateTime.parse('2024-01-02T12:00:00Z'),
      );

      final decoded = WorkflowTransitionRecord.fromJson(record.toJson());
      expect(decoded.outcome, equals(TransitionOutcome.rejected));
      expect(decoded.reason, isNotNull);
    });
  });
}

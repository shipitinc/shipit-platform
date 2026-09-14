import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

const _schemasRoot = '../../schemas';

Map<String, dynamic> _readJsonFile(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

JsonSchema _loadSchema(String name) =>
    JsonSchema.create(_readJsonFile('$_schemasRoot/$name.schema.json'));

void _expectValid(JsonSchema schema, Map<String, dynamic> instance) {
  final results = schema.validate(instance, validateFormats: true);
  expect(
    results.isValid,
    isTrue,
    reason: 'errors: ${results.errors}\nwarnings: ${results.warnings}',
  );
}

void main() {
  group('JSON Schema examples conform to their schema', () {
    const schemas = [
      'agent_result',
      'agent_execution_request',
      'agent_execution',
      'agent_event_record',
      'platform_verification',
      'worker_execution_request',
      'worker_execution',
      'worker_execution_result',
      'workspace_descriptor',
      'worker_event_record',
      'work_item',
      'qa_evidence',
      'human_decision',
      'deployment_artifact',
      'qa_pass_criteria',
      'workflow_transition_record',
      'artifact_reference',
      'job',
      'job_claim',
      'job_execution_reference',
      'scheduler_event_record',
      'retry_policy',
    ];

    for (final name in schemas) {
      test('$name.example.json conforms to $name.schema.json', () {
        final schema = _loadSchema(name);
        final instance = _readJsonFile(
          '$_schemasRoot/examples/$name.example.json',
        );
        _expectValid(schema, instance);
      });
    }
  });

  group('Dart serialization conforms to JSON Schema', () {
    test('WorkItem.toJson() conforms to work_item.schema.json', () {
      final workItem = WorkItem(
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        productId: '123e4567-e89b-12d3-a456-426614174000',
        category: WorkItemCategory.feature,
        title: 'Add login feature',
        state: WorkItemState.designInReview,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2024-01-02T00:00:00Z'),
      );

      _expectValid(_loadSchema('work_item'), workItem.toJson());
    });

    test('AgentResult.toJson() conforms to agent_result.schema.json', () {
      final result = AgentResult(
        resultId: '123e4567-e89b-12d3-a456-426614174003',
        sessionId: '123e4567-e89b-12d3-a456-426614174004',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        status: AgentResultStatus.completed,
        artifacts: [],
        diagnostics: AgentDiagnostics(
          exitCode: 0,
          durationMs: 30000,
          toolCalls: 15,
          errors: [],
          warnings: [],
        ),
        structuredResult: {'testsPassed': 42},
        completedAt: DateTime.parse('2024-01-02T13:00:00Z'),
      );

      _expectValid(_loadSchema('agent_result'), result.toJson());
    });

    test('AgentResult.toJson() with execution fields conforms to '
        'agent_result.schema.json', () {
      final result = AgentResult(
        resultId: '123e4567-e89b-12d3-a456-426614174003',
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        role: AgentRole.implementer,
        sessionId: '123e4567-e89b-12d3-a456-426614174004',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        status: AgentResultStatus.completed,
        artifacts: [],
        changedFiles: const [
          ChangedFile(
            path: 'lib/calculator.dart',
            operation: ChangedFileOperation.modified,
          ),
        ],
        claimedChecks: const [
          AgentClaimedCheck(
            checkName: 'dart test',
            status: AgentClaimStatus.passed,
          ),
        ],
        diagnostics: AgentDiagnostics(
          exitCode: 0,
          durationMs: 30000,
          toolCalls: 15,
          errors: [],
          warnings: [],
        ),
        structuredResult: {'testsPassed': 42},
        completedAt: DateTime.parse('2024-01-02T13:00:00Z'),
      );

      _expectValid(_loadSchema('agent_result'), result.toJson());
    });

    test('AgentExecutionRequest.toJson() conforms to '
        'agent_execution_request.schema.json', () {
      final request = AgentExecutionRequest(
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        role: AgentRole.implementer,
        runtimeTypeId: 'opencode',
        workspace: const AgentWorkspace(
          workspaceId: 'ws-001',
          path: '/tmp/shipit-fixture-work-2026',
          startingRevision: 'HEAD',
        ),
        instruction: 'Implement add so the test passes.',
        timeoutSeconds: 300,
        expectedArtifacts: const [
          ExpectedArtifact(
            description: 'Modified lib/calculator.dart',
            pathPattern: 'lib/calculator.dart',
            required: true,
          ),
        ],
        runtimeConfig: const {'model': 'opencode/big-pickle'},
        createdAt: DateTime.parse('2024-01-02T12:30:00Z'),
      );

      _expectValid(_loadSchema('agent_execution_request'), request.toJson());
    });

    test('AgentExecution.toJson() conforms to agent_execution.schema.json', () {
      final execution = AgentExecution(
        executionId: '123e4567-e89b-12d3-a456-426614174010',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        requestId: '123e4567-e89b-12d3-a456-426614174011',
        runtimeTypeId: 'opencode',
        role: AgentRole.implementer,
        status: AgentSessionStatus.running,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-001',
          path: '/tmp/shipit-fixture-work-2026',
        ),
        sessionId: 'ses_ab01cdef2345',
        startedAt: DateTime.parse('2024-01-02T12:30:01Z'),
      );

      _expectValid(_loadSchema('agent_execution'), execution.toJson());
    });

    test(
      'AgentEventRecord.toJson() conforms to agent_event_record.schema.json',
      () {
        final event = AgentEventRecord(
          eventId: '123e4567-e89b-12d3-a456-426614174020',
          executionId: '123e4567-e89b-12d3-a456-426614174010',
          workItemId: '123e4567-e89b-12d3-a456-426614174001',
          sequence: 1,
          type: AgentEventType.message,
          occurredAt: DateTime.parse('2024-01-02T12:30:05Z'),
          payload: const {'text': 'Starting implementation'},
        );

        _expectValid(_loadSchema('agent_event_record'), event.toJson());
      },
    );

    test('WorkerExecutionRequest.toJson() conforms to '
        'worker_execution_request.schema.json', () {
      final request = WorkerExecutionRequest(
        workerExecutionId: '123e4567-e89b-12d3-a456-426614174020',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        repositoryPath: '/home/ci/checkouts/shipit-platform',
        startingRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.flutter,
        },
        role: AgentRole.implementer,
        instruction: 'Implement add(2,3) == 5.',
        timeoutSeconds: 300,
        runtimeTypeId: 'opencode',
      );

      _expectValid(_loadSchema('worker_execution_request'), request.toJson());
    });

    test(
      'WorkerExecution.toJson() conforms to worker_execution.schema.json',
      () {
        final execution = WorkerExecution(
          workerExecutionId: '123e4567-e89b-12d3-a456-426614174020',
          workItemId: '123e4567-e89b-12d3-a456-426614174001',
          repositoryPath: '/home/ci/checkouts/shipit-platform',
          requestedStartingRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
          requiredCapabilities: const {WorkerCapability.linux},
          status: WorkerExecutionStatus.executedPass,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          workerId: 'worker-local-1',
          workspaceId: 'ws-001',
          agentExecutionId: 'agx-wx-1',
          cleanupStatus: WorkerCleanupStatus.removed,
          failureCode: WorkerFailureCode.none,
          createdAt: DateTime.parse('2024-01-02T12:00:00Z'),
          startedAt: DateTime.parse('2024-01-02T12:00:01Z'),
          endedAt: DateTime.parse('2024-01-02T12:03:45Z'),
          version: 3,
        );

        _expectValid(_loadSchema('worker_execution'), execution.toJson());
      },
    );

    test('WorkerExecutionResult.toJson() conforms to '
        'worker_execution_result.schema.json', () {
      final result = WorkerExecutionResult(
        workerExecutionId: '123e4567-e89b-12d3-a456-426614174020',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        status: WorkerExecutionStatus.executedPass,
        workerId: 'worker-local-1',
        workspaceId: 'ws-001',
        startingRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
        endingRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
        agentExecutionId: 'agx-wx-1',
        agentResultStatus: AgentResultStatus.completed,
        verificationId: 'ver-1',
        verificationPassed: true,
        changedFiles: const [
          ChangedFile(
            path: 'lib/calculator.dart',
            operation: ChangedFileOperation.modified,
          ),
        ],
        diffSummary: 'lib/calculator.dart | 2 +-',
        cleanupStatus: WorkerCleanupStatus.removed,
        failureCode: WorkerFailureCode.none,
        startedAt: DateTime.parse('2024-01-02T12:00:01Z'),
        endedAt: DateTime.parse('2024-01-02T12:03:45Z'),
      );

      _expectValid(_loadSchema('worker_execution_result'), result.toJson());
    });

    test(
      'WorkerEventRecord.toJson() conforms to worker_event_record.schema.json',
      () {
        final event = WorkerEventRecord(
          eventId: 'evt-1',
          workerExecutionId: '123e4567-e89b-12d3-a456-426614174020',
          workItemId: '123e4567-e89b-12d3-a456-426614174001',
          sequence: 2,
          type: WorkerEventType.verificationStarted,
          occurredAt: DateTime.parse('2024-01-02T12:31:05Z'),
          payload: const {'verificationId': 'ver-1'},
        );

        _expectValid(_loadSchema('worker_event_record'), event.toJson());
      },
    );

    test('WorkspaceDescriptor.toJson() conforms to '
        'workspace_descriptor.schema.json', () {
      final descriptor = WorkspaceDescriptor(
        workspaceId: 'ws-001',
        workerExecutionId: '123e4567-e89b-12d3-a456-426614174020',
        workerId: 'worker-local-1',
        repositoryPath: '/home/ci/checkouts/shipit-platform',
        startingRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
        worktreePath: '/workspaces/ws-001',
        detached: true,
        createdAt: DateTime.parse('2024-01-02T12:00:01Z'),
      );

      _expectValid(_loadSchema('workspace_descriptor'), descriptor.toJson());
    });

    test('PlatformVerification.toJson() conforms to '
        'platform_verification.schema.json', () {
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

      _expectValid(_loadSchema('platform_verification'), verification.toJson());
    });

    test('HumanDecision.toJson() conforms to human_decision.schema.json', () {
      final decision = HumanDecision(
        decisionId: '123e4567-e89b-12d3-a456-426614174002',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        decisionType: HumanDecisionType.qaWaiver,
        status: HumanDecisionStatus.resolved,
        question: 'Accept the known issue and waive the failing gate?',
        decider: 'alice@example.com',
        choice: HumanDecisionChoice.waive,
        rationale: 'Known issue, accepting risk',
        timestamp: DateTime.parse('2024-01-02T12:00:00Z'),
        signature: DecisionSignature(
          algorithm: 'Ed25519',
          publicKey: 'base64key',
          signature: 'base64sig',
          signedAt: DateTime.parse('2024-01-02T12:00:01Z'),
        ),
        requestedAt: DateTime.parse('2024-01-02T11:00:00Z'),
        updatedAt: DateTime.parse('2024-01-02T12:00:00Z'),
      );

      _expectValid(_loadSchema('human_decision'), decision.toJson());
    });

    test(
      'pending HumanDecision.toJson() conforms to human_decision.schema.json',
      () {
        final decision = HumanDecision(
          decisionId: '123e4567-e89b-12d3-a456-426614174002',
          workItemId: '123e4567-e89b-12d3-a456-426614174001',
          decisionType: HumanDecisionType.engineeringReview,
          status: HumanDecisionStatus.pending,
          question: 'Approve the implementation?',
          options: [
            HumanDecisionOption(
              optionId: 'approve',
              label: 'Approve',
              recommended: true,
            ),
            const HumanDecisionOption(optionId: 'rework', label: 'Rework'),
          ],
          recommendation: 'approve',
          requestedAt: DateTime.parse('2024-01-02T11:00:00Z'),
          updatedAt: DateTime.parse('2024-01-02T11:00:00Z'),
        );

        final json = decision.toJson();
        expect(json.containsKey('choice'), isFalse);
        expect(json.containsKey('signature'), isFalse);
        _expectValid(_loadSchema('human_decision'), json);
      },
    );

    test(
      'DeploymentArtifact.toJson() conforms to deployment_artifact.schema.json',
      () {
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
              components: [],
            ),
          ),
          builtAt: DateTime.parse('2024-01-02T14:00:00Z'),
          builtBy: '123e4567-e89b-12d3-a456-426614174004',
        );

        _expectValid(_loadSchema('deployment_artifact'), artifact.toJson());
      },
    );

    test('QAEvidence.toJson() conforms to qa_evidence.schema.json', () {
      final evidence = QAEvidence(
        evidenceId: '123e4567-e89b-12d3-a456-426614174020',
        gateId: 'static-analysis',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        evidenceType: 'analysis-report',
        artifactRef: 'artifacts/static-analysis.json',
        content: {'errorCount': 0},
        collectedAt: DateTime.parse('2024-01-02T10:00:00Z'),
      );

      _expectValid(_loadSchema('qa_evidence'), evidence.toJson());
    });

    test(
      'QAPassCriteria.toJson() conforms to qa_pass_criteria.schema.json',
      () {
        final criteria = const QAPassCriteria(
          allRequiredGatesMustPass: true,
          optionalGateFailuresAllowed: 1,
          waiverRequiresHumanDecision: true,
        );

        _expectValid(_loadSchema('qa_pass_criteria'), criteria.toJson());
      },
    );

    test('QAContract.toJson() conforms to qa_contract.schema.json', () {
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
        ],
      );

      _expectValid(_loadSchema('qa_contract'), contract.toJson());
    });

    test('QAGateResult.toJson() conforms to qa_evidence.schema.json across '
        'AEF-aligned statuses and determinations', () {
      final result = QAGateResult(
        gateId: 'static-analysis',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        status: QAGateStatus.notExecuted,
        evidence: const [],
        evaluatedAt: DateTime.parse('2024-01-02T10:00:00Z'),
        evidenceDeterminations: [
          QAEvidenceDetermination(
            evidenceId: 'E-01',
            determination: EvidenceDetermination.readyNotExecuted,
            artifactRef: 'artifacts/static-analysis.json',
            reasons: 'Analyzer lane not yet run',
          ),
          QAEvidenceDetermination(
            evidenceId: 'E-02',
            determination: EvidenceDetermination.skipped,
            reasons: 'No DEX scan baseline in CI',
            authorityRef: '123e4567-e89b-12d3-a456-42661417400b',
          ),
        ],
        metadata: {'note': 'conformance smoke test'},
      );

      final gateResultSchema = _loadSchema(
        'qa_evidence',
      ).definitions['QAGateResult'];
      expect(gateResultSchema, isNotNull);
      _expectValid(gateResultSchema!, result.toJson());
    });

    test('WorkflowTransitionRecord.toJson() conforms to '
        'workflow_transition_record.schema.json', () {
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
          const TransitionGuardEvaluation(
            guardName: 'design_contract_exists',
            passed: true,
          ),
        ],
      );

      _expectValid(_loadSchema('workflow_transition_record'), record.toJson());
    });

    test(
      'ArtifactReference.toJson() conforms to artifact_reference.schema.json',
      () {
        final ref = ArtifactReference(
          artifactId: '123e4567-e89b-12d3-a456-426614174030',
          artifactType: ArtifactType.qaEvidence,
          uri: 'artifacts/static-analysis.json',
          createdAt: DateTime.parse('2024-01-02T10:00:00Z'),
        );

        _expectValid(_loadSchema('artifact_reference'), ref.toJson());
      },
    );
  });

  group('Invalid enum values are rejected', () {
    test('WorkItem.fromJson rejects an unknown state', () {
      final json = {
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'productId': '123e4567-e89b-12d3-a456-426614174000',
        'category': 'feature',
        'title': 't',
        'state': 'not_a_real_state',
        'createdAt': '2024-01-01T00:00:00Z',
        'updatedAt': '2024-01-01T00:00:00Z',
      };

      expect(() => WorkItem.fromJson(json), throwsFormatException);
    });

    test('AgentResult.fromJson rejects an unknown status', () {
      final json = {
        'resultId': '123e4567-e89b-12d3-a456-426614174003',
        'sessionId': '123e4567-e89b-12d3-a456-426614174004',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'status': 'unknown',
        'artifacts': <Object>[],
        'diagnostics': {
          'exitCode': 0,
          'durationMs': 0,
          'toolCalls': 0,
          'errors': <Object>[],
          'warnings': <Object>[],
        },
        'structuredResult': <Object, Object>{},
        'completedAt': '2024-01-02T13:00:00Z',
      };

      expect(() => AgentResult.fromJson(json), throwsFormatException);
    });

    test(
      'HumanDecision.fromJson rejects an unknown decisionType or choice',
      () {
        final base = {
          'decisionId': '123e4567-e89b-12d3-a456-426614174002',
          'workItemId': '123e4567-e89b-12d3-a456-426614174001',
          'status': 'pending',
          'updatedAt': '2024-01-02T12:00:00Z',
        };

        expect(
          () => HumanDecision.fromJson({...base, 'decisionType': 'not_a_type'}),
          throwsFormatException,
        );
        expect(
          () => HumanDecision.fromJson({
            ...base,
            'decisionType': 'qa_waiver',
            'status': 'resolved',
            'choice': 'maybe',
            'decider': 'alice@example.com',
            'rationale': 'why',
            'timestamp': '2024-01-02T12:00:00Z',
            'signature': {
              'algorithm': 'Ed25519',
              'publicKey': 'key',
              'signature': 'sig',
              'signedAt': '2024-01-02T12:00:01Z',
            },
          }),
          throwsFormatException,
        );
        expect(
          () => HumanDecision.fromJson({
            ...base,
            'decisionType': 'qa_waiver',
            'status': 'not_a_status',
          }),
          throwsFormatException,
        );
      },
    );

    test('QAGateResult.fromJson rejects an unknown gate status', () {
      final json = {
        'gateId': 'static-analysis',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'status': 'not_a_status',
        'evidence': <Object>[],
        'evaluatedAt': '2024-01-02T10:00:00Z',
      };

      expect(() => QAGateResult.fromJson(json), throwsFormatException);
    });

    test(
      'QAEvidenceDetermination.fromJson rejects an unknown determination',
      () {
        final json = {'evidenceId': 'E-01', 'determination': 'unknown'};

        expect(
          () => QAEvidenceDetermination.fromJson(json),
          throwsFormatException,
        );
      },
    );

    test('AgentExecutionRequest.fromJson rejects an unknown role and an '
        'orphaned-free status is not relevant here', () {
      final base = {
        'executionId': '123e4567-e89b-12d3-a456-426614174010',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'role': 'NOT_A_ROLE',
        'runtimeTypeId': 'opencode',
        'workspace': {'workspaceId': 'ws-001', 'path': '/tmp/ws'},
        'instruction': 'instr',
        'timeoutSeconds': 60,
        'expectedArtifacts': <Object>[],
      };

      expect(() => AgentExecutionRequest.fromJson(base), throwsFormatException);
    });

    test('AgentExecution.fromJson rejects an unknown status', () {
      final base = {
        'executionId': '123e4567-e89b-12d3-a456-426614174010',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'requestId': '123e4567-e89b-12d3-a456-426614174011',
        'runtimeTypeId': 'opencode',
        'role': 'IMPLEMENTER',
        'status': 'not_a_status',
        'workspace': {'workspaceId': 'ws-001', 'path': '/tmp/ws'},
        'version': 1,
      };

      expect(() => AgentExecution.fromJson(base), throwsA(anything));
    });

    test('AgentEventRecord.fromJson rejects an unknown type', () {
      final json = {
        'eventId': '123e4567-e89b-12d3-a456-426614174020',
        'executionId': '123e4567-e89b-12d3-a456-426614174010',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'sequence': 1,
        'type': 'not_a_type',
        'occurredAt': '2024-01-02T12:30:05Z',
      };

      expect(() => AgentEventRecord.fromJson(json), throwsFormatException);
    });

    test('PlatformVerification.fromJson rejects an unknown status', () {
      final json = {
        'verificationId': '123e4567-e89b-12d3-a456-426614174030',
        'executionId': '123e4567-e89b-12d3-a456-426614174010',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'checkName': 'check',
        'status': 'unknown',
        'mechanism': 'm',
        'command': 'c',
        'capturedAt': '2024-01-02T12:34:00Z',
        'evidenceKind': 'platform_verified_evidence',
      };

      expect(() => PlatformVerification.fromJson(json), throwsFormatException);
    });

    test('WorkerEventRecord.fromJson rejects an unknown type', () {
      final json = {
        'eventId': 'evt-x',
        'workerExecutionId': '123e4567-e89b-12d3-a456-426614174020',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'sequence': 1,
        'type': 'not_a_worker_type',
        'occurredAt': '2024-01-02T12:30:05Z',
      };

      expect(() => WorkerEventRecord.fromJson(json), throwsFormatException);
    });

    test('WorkerExecutionRequest round-trips required capability tokens', () {
      final request = WorkerExecutionRequest.fromJson({
        'workerExecutionId': '123e4567-e89b-12d3-a456-426614174020',
        'workItemId': '123e4567-e89b-12d3-a456-426614174001',
        'repositoryPath': '/checkouts/repo',
        'startingRevision': 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
        'requiredCapabilities': ['macos', 'xcode'],
        'role': 'IMPLEMENTER',
        'instruction': 'do the thing',
        'timeoutSeconds': 300,
        'runtimeTypeId': 'opencode',
        'cleanupPolicy': 'preserveOnFailure',
      });

      expect(
        request.requiredCapabilities,
        containsAll(const {WorkerCapability.macos, WorkerCapability.xcode}),
      );
      expect(request.cleanupPolicy, WorkerCleanupPolicy.preserveOnFailure);

      final decoded = WorkerExecutionRequest.fromJson(request.toJson());
      expect(decoded.requiredCapabilities, request.requiredCapabilities);
      expect(decoded.startingRevision, request.startingRevision);
    });

    test('Job.toJson() conforms to job.schema.json', () {
      final job = Job(
        jobId: 'job-001',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        jobType: JobType.implementFeature,
        requiredRole: AgentRole.implementer,
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.flutter,
        },
        priority: JobPriority.normal,
        state: JobState.running,
        dedupeKey:
            '123e4567-e89b-12d3-a456-426614174001:design_not_required:'
            'implement_feature:IMPLEMENTER',
        createdAt: DateTime.parse('2024-01-02T12:00:00Z'),
        instruction: 'Implement the feature described in the work item.',
        attempt: 1,
        maxAttempts: 2,
        startedAt: DateTime.parse('2024-01-02T12:00:02Z'),
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-job-001',
          agentExecutionId: 'agx-wx-job-001',
          resultId: '123e4567-e89b-12d3-a456-426614174003',
          createdAt: DateTime.parse('2024-01-02T12:00:02Z'),
        ),
        workerId: 'worker-local-1',
        version: 3,
      );

      _expectValid(_loadSchema('job'), job.toJson());
    });

    test('JobClaim.toJson() conforms to job_claim.schema.json', () {
      final claim = JobClaim(
        claimId: 'claim-001',
        jobId: 'job-001',
        ownerId: 'scheduler-1',
        leasedUntil: DateTime.parse('2024-01-02T12:10:00Z'),
        createdAt: DateTime.parse('2024-01-02T12:00:01Z'),
      );

      _expectValid(_loadSchema('job_claim'), claim.toJson());
    });

    test('JobExecutionReference.toJson() conforms to '
        'job_execution_reference.schema.json', () {
      final reference = JobExecutionReference(
        workerExecutionId: 'wx-job-001',
        agentExecutionId: 'agx-wx-job-001',
        resultId: '123e4567-e89b-12d3-a456-426614174003',
        createdAt: DateTime.parse('2024-01-02T12:00:02Z'),
      );

      _expectValid(_loadSchema('job_execution_reference'), reference.toJson());
    });

    test('SchedulerEventRecord.toJson() conforms to '
        'scheduler_event_record.schema.json', () {
      final event = SchedulerEventRecord(
        eventId: 'se-job-001-1',
        jobId: 'job-001',
        workItemId: '123e4567-e89b-12d3-a456-426614174001',
        sequence: 1,
        type: SchedulerEventType.jobQueued,
        occurredAt: DateTime.parse('2024-01-02T12:00:00Z'),
        payload: const {'priority': 'normal'},
      );

      _expectValid(_loadSchema('scheduler_event_record'), event.toJson());
    });

    test('Job round-trips enums exactly (Dart <-> JSON)', () {
      final job = Job(
        jobId: 'job-rt',
        workItemId: 'wi-rt',
        jobType: JobType.implementFeature,
        requiredRole: AgentRole.implementer,
        requiredCapabilities: const {WorkerCapability.linux},
        priority: JobPriority.critical,
        state: JobState.retryWaiting,
        dedupeKey: 'wi-rt:design_approved:implement_feature:IMPLEMENTER',
        createdAt: DateTime.parse('2024-01-02T12:00:00Z'),
        instruction: 'go',
        attempt: 2,
        maxAttempts: 2,
        availableAt: DateTime.parse('2024-01-02T12:01:00Z'),
        failure: const JobFailure(
          code: JobFailureCode.executionInterrupted,
          kind: JobFailureKind.transient,
          reason: 'session interrupted',
        ),
        version: 4,
      );

      final decoded = Job.fromJson(job.toJson());
      expect(decoded.jobType, JobType.implementFeature);
      expect(decoded.priority, JobPriority.critical);
      expect(decoded.state, JobState.retryWaiting);
      expect(decoded.failure!.code, JobFailureCode.executionInterrupted);
      expect(decoded.failure!.kind, JobFailureKind.transient);
      expect(decoded.dedupeKey, job.dedupeKey);
    });
  });
}

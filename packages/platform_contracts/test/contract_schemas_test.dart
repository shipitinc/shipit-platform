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
      'work_item',
      'qa_evidence',
      'human_decision',
      'deployment_artifact',
      'qa_pass_criteria',
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

    test('HumanDecision.toJson() conforms to human_decision.schema.json', () {
      final decision = HumanDecision(
        decisionId: '123e4567-e89b-12d3-a456-426614174002',
        workflowId: '123e4567-e89b-12d3-a456-426614174001',
        decisionType: HumanDecisionType.qaWaiver,
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
      );

      _expectValid(_loadSchema('human_decision'), decision.toJson());
    });

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
          'workflowId': '123e4567-e89b-12d3-a456-426614174001',
          'decider': 'alice@example.com',
          'rationale': 'why',
          'timestamp': '2024-01-02T12:00:00Z',
          'signature': {
            'algorithm': 'Ed25519',
            'publicKey': 'key',
            'signature': 'sig',
            'signedAt': '2024-01-02T12:00:01Z',
          },
        };

        expect(
          () => HumanDecision.fromJson({
            ...base,
            'decisionType': 'not_a_type',
            'choice': 'approve',
          }),
          throwsFormatException,
        );
        expect(
          () => HumanDecision.fromJson({
            ...base,
            'decisionType': 'qa_waiver',
            'choice': 'maybe',
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
  });
}

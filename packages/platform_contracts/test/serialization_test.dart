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
    test('serializes to JSON and back', () {
      final decision = HumanDecision(
        decisionId: '123e4567-e89b-12d3-a456-426614174002',
        workflowId: '123e4567-e89b-12d3-a456-426614174001',
        decisionType: HumanDecisionType.designApproval,
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
          workflowState: 'design_in_review',
          availableOptions: ['approve', 'reject'],
        ),
      );

      final json = decision.toJson();
      final decoded = HumanDecision.fromJson(json);

      expect(decoded.decisionId, equals(decision.decisionId));
      expect(decoded.choice, equals(HumanDecisionChoice.approve));
      expect(decoded.signature.algorithm, equals('Ed25519'));
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
      expect(WorkItemState.values.length, equals(14));
      expect(WorkItemState.draft.name, equals('draft'));
      expect(WorkItemState.done.name, equals('done'));
    });
  });
}

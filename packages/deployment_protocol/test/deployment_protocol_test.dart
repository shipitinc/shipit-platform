import 'package:deployment_protocol/deployment_protocol.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show AgentArtifact, AgentDiagnostics, AgentResult, AgentResultStatus;
import 'package:test/test.dart';

void main() {
  group('PromotionEngine', () {
    late PromotionEngine engine;

    setUp(() {
      engine = const PromotionEngine();
    });

    test('returns canPromote false when no rules apply', () {
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

      final rules = [
        PromotionRule(
          fromEnvironment: 'staging',
          toEnvironment: 'production',
          gate: PromotionGate.human,
        ),
      ];

      final currentDeployments = <String, DeploymentRecord>{};

      final result = engine.evaluate(artifact, rules, currentDeployments);

      expect(result.canPromote, isFalse);
      expect(result.reason, contains('No applicable'));
    });

    test('returns promotion when staging is healthy', () {
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

      final rules = [
        PromotionRule(
          fromEnvironment: 'staging',
          toEnvironment: 'production',
          gate: PromotionGate.human,
        ),
      ];

      final currentDeployments = {
        'staging': DeploymentRecord(
          recordId: 'rec-1',
          artifactId: 'art-1',
          targetId: 'cloud-run-staging',
          environment: 'staging',
          status: DeploymentStatus.healthy,
          deployedAt: DateTime.now(),
          completedAt: DateTime.now(),
        ),
      };

      final result = engine.evaluate(artifact, rules, currentDeployments);

      expect(result.canPromote, isTrue);
      expect(result.nextEnvironment, equals('production'));
      expect(result.requiredGate, equals(PromotionGate.human));
    });

    test('skips promotion when staging is not healthy', () {
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

      final rules = [
        PromotionRule(
          fromEnvironment: 'staging',
          toEnvironment: 'production',
          gate: PromotionGate.human,
        ),
      ];

      final currentDeployments = {
        'staging': DeploymentRecord(
          recordId: 'rec-1',
          artifactId: 'art-1',
          targetId: 'cloud-run-staging',
          environment: 'staging',
          status: DeploymentStatus.failed,
          deployedAt: DateTime.now(),
          completedAt: DateTime.now(),
        ),
      };

      final result = engine.evaluate(artifact, rules, currentDeployments);

      expect(result.canPromote, isFalse);
    });
  });

  group('DeploymentArtifact', () {
    test('creates artifact with manifest', () {
      final manifest = ArtifactManifest(
        name: 'my-app',
        version: '1.0.0',
        gitCommit: 'abc123',
        files: [
          ArtifactFile(
            path: 'build/app.apk',
            sha256: 'hash',
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
      );

      final artifact = DeploymentArtifact(
        artifactId: 'art-1',
        contentHash: 'content-hash',
        manifest: manifest,
        builtAt: DateTime.now(),
        builtBy: 'session-1',
      );

      expect(artifact.manifest.name, equals('my-app'));
      expect(artifact.manifest.version, equals('1.0.0'));
      expect(artifact.manifest.files.length, equals(1));
      expect(artifact.manifest.sbom.components.length, equals(1));
    });
  });

  group('DeploymentProtocol.buildArtifact content hash', () {
    test('produces a deterministic 64-char hex sha256', () async {
      final protocol = DeploymentProtocol();
      final agentResult = AgentResult(
        resultId: 'result-1',
        sessionId: 'session-1',
        workItemId: 'work-1',
        status: AgentResultStatus.completed,
        artifacts: [
          AgentArtifact(
            artifactId: 'art-1',
            type: 'apk',
            path: 'build/app.apk',
            sha256: 'hash',
            sizeBytes: 10485760,
            mediaType: 'application/vnd.android.package-archive',
          ),
        ],
        diagnostics: AgentDiagnostics(
          exitCode: 0,
          durationMs: 1000,
          toolCalls: 0,
          errors: [],
          warnings: [],
        ),
        structuredResult: {'summary': 'Built apk'},
        completedAt: DateTime.now(),
      );

      final first = await protocol.buildArtifact(
        'work-1',
        agentResult,
        'my-app',
        '1.0.0',
        'abc123',
      );
      final second = await protocol.buildArtifact(
        'work-1',
        agentResult,
        'my-app',
        '1.0.0',
        'abc123',
      );

      expect(first.contentHash, hasLength(64));
      expect(first.contentHash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(first.contentHash, equals(second.contentHash));
      expect(first.contentHash, isNot(equals('a' * 64)));
    });
  });
}

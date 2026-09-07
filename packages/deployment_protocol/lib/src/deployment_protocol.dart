import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:platform_contracts/platform_contracts.dart';

import 'artifacts/artifact_store.dart';
import 'promotion/promotion_rule.dart';

class DeploymentProtocol {
  DeploymentProtocol({ArtifactStore? store, PromotionEngine? promotionEngine})
    : _store = store,
      _promotionEngine = promotionEngine ?? const PromotionEngine();

  final ArtifactStore? _store;
  final PromotionEngine _promotionEngine;

  Future<DeploymentArtifact> buildArtifact(
    String workItemId,
    AgentResult agentResult,
    String name,
    String version,
    String gitCommit,
  ) async {
    final files = <ArtifactFile>[];

    for (final artifact in agentResult.artifacts) {
      files.add(
        ArtifactFile(
          path: artifact.path,
          sha256: artifact.sha256,
          sizeBytes: artifact.sizeBytes,
          mediaType: artifact.mediaType,
        ),
      );
    }

    final manifest = ArtifactManifest(
      name: name,
      version: version,
      gitCommit: gitCommit,
      files: files,
      sbom: SoftwareBillOfMaterials(
        format: 'CycloneDX',
        version: '1.5',
        components: [],
      ),
    );

    final contentHash = _computeHash(manifest);

    final artifact = DeploymentArtifact(
      artifactId: 'artifact-${DateTime.now().millisecondsSinceEpoch}',
      contentHash: contentHash,
      manifest: manifest,
      builtAt: DateTime.now(),
      builtBy: agentResult.sessionId,
    );

    if (_store != null) {
      await _store.store(ArtifactBundle(files: {}, manifest: manifest));
    }

    return artifact;
  }

  String _computeHash(ArtifactManifest manifest) => crypto.sha256
      .convert(utf8.encode(jsonEncode(manifest.toJson())))
      .toString();

  PromotionResult evaluatePromotion(
    DeploymentArtifact artifact,
    List<PromotionRule> rules,
    Map<String, DeploymentRecord> currentDeployments,
  ) {
    return _promotionEngine.evaluate(artifact, rules, currentDeployments);
  }
}

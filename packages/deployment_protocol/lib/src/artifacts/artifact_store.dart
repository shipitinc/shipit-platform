import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

abstract class ArtifactStore {
  Future<DeploymentArtifact> store(ArtifactBundle bundle);
  Future<DeploymentArtifact?> getByHash(String contentHash);
  Future<DeploymentArtifact?> getById(String artifactId);
  Future<List<DeploymentArtifact>> list({
    String? name,
    String? versionPrefix,
    DateTime? since,
  });
  Future<void> delete(String artifactId);
}

@immutable
class ArtifactBundle {
  const ArtifactBundle({required this.files, required this.manifest});

  final Map<String, List<int>> files;
  final ArtifactManifest manifest;
}

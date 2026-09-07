import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

abstract interface class DeploymentTarget {
  String get targetId;
  String get environment;
  List<WorkerCapability> get requiredCapabilities;

  Future<DeploymentResult> deploy(
    DeploymentArtifact artifact,
    DeploymentConfig config,
  );
  Future<DeploymentStatus> getStatus(String deploymentId);
  Future<void> rollback(String deploymentId, String previousArtifactId);
  Future<HealthCheckResult> healthCheck(String deploymentId);
}

@immutable
class DeploymentConfig {
  const DeploymentConfig({
    this.replicas,
    this.resources,
    this.environmentVariables,
    this.labels,
  });

  final int? replicas;
  final Map<String, String>? resources;
  final Map<String, String>? environmentVariables;
  final Map<String, String>? labels;
}

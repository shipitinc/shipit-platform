import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

@immutable
class TaskRequirements {
  const TaskRequirements({
    required this.requiredCapabilities,
    this.minVersions,
    this.estimatedDuration,
    this.maxRetries = 3,
    this.environment,
  });

  final Set<WorkerCapability> requiredCapabilities;
  final Map<WorkerCapability, String>? minVersions;
  final Duration? estimatedDuration;
  final int maxRetries;
  final Map<String, String>? environment;
}

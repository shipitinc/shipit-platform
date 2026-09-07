import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import '../capabilities/capability_spec.dart';
import 'worker_status.dart';

@immutable
class WorkerRegistration {
  const WorkerRegistration({
    required this.workerId,
    required this.poolId,
    required this.capabilities,
    required this.status,
    required this.currentLoad,
    required this.maxConcurrency,
    required this.lastHeartbeat,
    this.artifactCache,
  });

  final String workerId;
  final String poolId;
  final Map<WorkerCapability, CapabilitySpec> capabilities;
  final WorkerStatus status;
  final int currentLoad;
  final int maxConcurrency;
  final DateTime lastHeartbeat;
  final Map<String, ArtifactCacheEntry>? artifactCache;

  bool get isAvailable =>
      status == WorkerStatus.idle ||
      (status == WorkerStatus.busy && currentLoad < maxConcurrency);
}

@immutable
class ArtifactCacheEntry {
  const ArtifactCacheEntry({
    required this.artifactHash,
    required this.localPath,
    required this.cachedAt,
    this.sizeBytes,
  });

  final String artifactHash;
  final String localPath;
  final DateTime cachedAt;
  final int? sizeBytes;
}

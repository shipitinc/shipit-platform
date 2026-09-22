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
    this.platform,
    this.currentExecutionId,
  });

  final String workerId;
  final String poolId;
  final Map<WorkerCapability, CapabilitySpec> capabilities;
  final WorkerStatus status;
  final int currentLoad;
  final int maxConcurrency;
  final DateTime lastHeartbeat;
  final Map<String, ArtifactCacheEntry>? artifactCache;

  /// Host platform descriptor (provider-neutral, e.g. `macos-14`, `linux-x64`).
  /// Optional: capability matching never depends on this string; it is carried
  /// for observability and future pinning policy.
  final String? platform;

  /// The worker execution ID currently running on this worker, if any.
  /// Used for independence at dispatch (e.g. design review must not go to
  /// the same execution that produced the design).
  final String? currentExecutionId;

  bool get isAvailable =>
      status == WorkerStatus.idle ||
      (status == WorkerStatus.busy && currentLoad < maxConcurrency);

  /// Capacity-1 lease: can this worker take one more execution right now?
  bool get isAcquirable =>
      status != WorkerStatus.offline &&
      status != WorkerStatus.draining &&
      currentLoad < maxConcurrency;
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

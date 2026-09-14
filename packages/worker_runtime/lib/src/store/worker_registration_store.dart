import 'package:worker_protocol/worker_protocol.dart';

/// Snapshot of a worker bid, persisted durably so the control plane can list
/// known workers across restarts. Scheduling authority stays in the live
/// in-memory [WorkerRegistry]; this store is the durable view for observability
/// and (future) pinning policy.
abstract interface class WorkerRegistrationStore {
  Future<void> registerWorker(WorkerRegistration registration);

  Future<WorkerRegistration?> readWorker(String workerId);

  Future<List<WorkerRegistration>> listWorkers();

  Future<void> unregisterWorker(String workerId);

  /// Runs [body] within a single store transaction. Implementations that back a
  /// transaction-capable database must make every store call inside [body]
  /// atomic and rollback together on error. The default implementation has no
  /// transaction and simply forwards.
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) async => body(this);
}

class WorkerRegistrationNotFoundException implements Exception {
  WorkerRegistrationNotFoundException(this.workerId);

  final String workerId;

  @override
  String toString() => 'Worker registration not found: $workerId';
}

/// Provider-neutral JSON codec for [WorkerRegistration] and its nested value
/// types, shared by the file/in-memory/Postgres implementations.
abstract final class WorkerRegistrationCodec {
  static Map<String, dynamic> toJson(WorkerRegistration registration) {
    return {
      'workerId': registration.workerId,
      'poolId': registration.poolId,
      'capabilities': registration.capabilities.map(
        (capability, spec) => MapEntry(capability.name, _specToJson(spec)),
      ),
      'status': registration.status.name,
      'currentLoad': registration.currentLoad,
      'maxConcurrency': registration.maxConcurrency,
      'lastHeartbeat': registration.lastHeartbeat.toIso8601String(),
      'artifactCache': registration.artifactCache?.map(
        (key, entry) => MapEntry(key, _cacheEntryToJson(entry)),
      ),
      'platform': registration.platform,
    };
  }

  static WorkerRegistration fromJson(Map<String, dynamic> json) {
    final capabilitiesJson =
        (json['capabilities'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final artifactCacheJson =
        (json['artifactCache'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return WorkerRegistration(
      workerId: json['workerId'] as String,
      poolId: json['poolId'] as String,
      capabilities: capabilitiesJson.map(
        (name, specJson) => MapEntry(
          WorkerCapability.values.byName(name),
          _specFromJson(specJson as Map<String, dynamic>),
        ),
      ),
      status: WorkerStatus.values.byName(json['status'] as String),
      currentLoad: json['currentLoad'] as int,
      maxConcurrency: json['maxConcurrency'] as int,
      lastHeartbeat: DateTime.parse(json['lastHeartbeat'] as String),
      artifactCache: artifactCacheJson.isEmpty
          ? null
          : artifactCacheJson.map(
              (key, entryJson) => MapEntry(
                key,
                _cacheEntryFromJson(entryJson as Map<String, dynamic>),
              ),
            ),
      platform: json['platform'] as String?,
    );
  }

  static Map<String, dynamic> _specToJson(CapabilitySpec spec) => {
    'capability': spec.capability.name,
    'version': spec.version,
    'metadata': spec.metadata,
    'providedTools': spec.providedTools,
  };

  static CapabilitySpec _specFromJson(Map<String, dynamic> json) =>
      CapabilitySpec(
        capability: WorkerCapability.values.byName(
          json['capability'] as String,
        ),
        version: json['version'] as String,
        metadata: (json['metadata'] as Map<String, dynamic>?)
            ?.cast<String, String>(),
        providedTools: (json['providedTools'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );

  static Map<String, dynamic> _cacheEntryToJson(ArtifactCacheEntry entry) => {
    'artifactHash': entry.artifactHash,
    'localPath': entry.localPath,
    'cachedAt': entry.cachedAt.toIso8601String(),
    'sizeBytes': entry.sizeBytes,
  };

  static ArtifactCacheEntry _cacheEntryFromJson(Map<String, dynamic> json) =>
      ArtifactCacheEntry(
        artifactHash: json['artifactHash'] as String,
        localPath: json['localPath'] as String,
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        sizeBytes: json['sizeBytes'] as int?,
      );
}

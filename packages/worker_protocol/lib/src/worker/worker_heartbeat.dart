import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import '../capabilities/capability_spec.dart';
import 'worker_registration.dart';
import 'worker_status.dart';

@immutable
class WorkerHeartbeat {
  const WorkerHeartbeat({
    required this.workerId,
    required this.status,
    required this.currentLoad,
    required this.capabilities,
    this.artifactCache,
    required this.timestamp,
  });

  final String workerId;
  final WorkerStatus status;
  final int currentLoad;
  final Map<WorkerCapability, CapabilitySpec> capabilities;
  final Map<String, ArtifactCacheEntry>? artifactCache;
  final DateTime timestamp;
}

import 'package:meta/meta.dart';

import '../capabilities/capability_requirements.dart';

@immutable
class TaskDispatch {
  const TaskDispatch({
    required this.taskId,
    required this.workItemId,
    required this.requirements,
    required this.payload,
    this.timeout,
    this.priority = 0,
  });

  final String taskId;
  final String workItemId;
  final TaskRequirements requirements;
  final Map<String, dynamic> payload;
  final Duration? timeout;
  final int priority;
}

enum DispatchStrategy { leastLoaded, affinity }

@immutable
class TaskResult {
  const TaskResult({
    required this.taskId,
    required this.status,
    this.output,
    this.artifacts,
    this.error,
    required this.durationMs,
    required this.workerId,
  });

  final String taskId;
  final TaskStatus status;
  final Map<String, dynamic>? output;
  final List<WorkerArtifact>? artifacts;
  final String? error;
  final int durationMs;
  final String workerId;
}

enum TaskStatus { success, failed, timeout, cancelled }

@immutable
class WorkerArtifact {
  const WorkerArtifact({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
    required this.mediaType,
  });

  final String path;
  final String sha256;
  final int sizeBytes;
  final String mediaType;
}

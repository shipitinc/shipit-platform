/// Worker-level lifecycle events. These exist only where there is a worker
/// concern not already owned by the agent layer; `AgentEventRecord` stays the
/// source of truth for agent-side states.
enum WorkerEventType {
  workerAcquired('worker_acquired'),
  workspacePreparing('workspace_preparing'),
  workspaceReady('workspace_ready'),
  executionStarted('execution_started'),
  verificationStarted('verification_started'),
  finalizing('finalizing'),
  workspaceCleaned('workspace_cleaned'),
  workerReleased('worker_released'),
  prepareFailed('prepare_failed'),
  executionFailed('execution_failed'),
  cleanupFailed('cleanup_failed');

  const WorkerEventType(this.wire);

  final String wire;

  static WorkerEventType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown worker event type: $value'),
  );
}

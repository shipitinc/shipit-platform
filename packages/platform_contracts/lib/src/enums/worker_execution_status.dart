enum WorkerExecutionStatus {
  acquiring,
  workspacePreparing,
  agentExecuting,
  finalizing,
  executedPass,
  executedFail,
  prepareFailed,
  cancelled,
  timedOut,
  orphaned;

  const WorkerExecutionStatus();

  bool get isTerminal =>
      this == executedPass ||
      this == executedFail ||
      this == prepareFailed ||
      this == cancelled ||
      this == timedOut ||
      this == orphaned;
}

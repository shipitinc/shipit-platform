/// Bounded failure classification for a worker execution. Normal lifecycle
/// outcomes (cancellation, timeout, miss) are never encoded as prose.
enum WorkerFailureCode {
  none,
  noCompatibleWorker,
  prepareFailed,
  agentFailed,
  timedOut,
  cancelled,
  cleanupFailed;

  const WorkerFailureCode();

  bool get isFailure => this != none;
}

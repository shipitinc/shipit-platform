/// Durable outcome of workspace cleanup/finalization. Mistakes here are
/// reparable by reconciliation, but the worker layer must be explicit about
/// what it did with platform-owned files.
enum WorkerCleanupStatus {
  notApplicable,
  pending,
  removed,
  preservedPerPolicy,
  cleanupFailed;

  const WorkerCleanupStatus();
}

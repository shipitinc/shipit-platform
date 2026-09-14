/// The durable lifecycle of one scheduler [Job].
///
/// The JOB state machine is distinct from the WORKFLOW state machine (a job
/// can succeed operationally while its work item enters review) and from the
/// WORKER / AGENT execution state machines (a job can be claimed before the
/// worker has started the underlying execution). States are strongly typed;
/// a scheduling outcome is never encoded as prose.
enum JobState {
  /// Enqueued, eligible to be claimed once a worker is available.
  queued,

  /// A scheduler owns a lease on this job; the worker dispatch is committed.
  claimed,

  /// The job has been handed to a worker; an execution is (or was) running.
  running,

  /// The job failed transiently; it can be retried after [availableAt].
  retryWaiting,

  /// The underlying worker execution passed the platform's verification.
  succeeded,

  /// The underlying execution failed permanently (or exhausts retries).
  failed,

  /// The job was cancelled before or during execution.
  cancelled;

  bool get isTerminal =>
      this == succeeded || this == failed || this == cancelled;

  bool get isActive => !isTerminal;
}

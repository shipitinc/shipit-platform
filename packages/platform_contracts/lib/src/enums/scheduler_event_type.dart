/// Normalized scheduler lifecycle events, meaningful transitions only. There
/// are no verbose polling records: a tick that finds nothing to do emits
/// nothing, and `jobDeferred` is only emitted when a runnable job was
/// ATTEMPTED but no worker could be acquired.
enum SchedulerEventType {
  jobQueued('job_queued'),
  jobClaimed('job_claimed'),
  jobDispatched('job_dispatched'),
  jobDeferred('job_deferred'),
  jobRetryScheduled('job_retry_scheduled'),
  jobCompleted('job_completed'),
  jobFailed('job_failed'),
  jobCancelled('job_cancelled');

  const SchedulerEventType(this.wire);

  final String wire;

  static SchedulerEventType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown scheduler event type: $value'),
  );
}

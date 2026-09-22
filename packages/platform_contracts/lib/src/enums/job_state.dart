/// The durable lifecycle of one scheduler [Job].
///
/// The JOB state machine is distinct from the WORKFLOW state machine (a job
/// can succeed operationally while its work item enters review) and from the
/// WORKER / AGENT execution state machines (a job can be claimed before the
/// worker has started the underlying execution). States are strongly typed;
/// a scheduling outcome is never encoded as prose.
///
/// ## Wire values are pinned, and `retryWaiting` is deliberately not snake_case
///
/// These values were persisted via `.name` before wire strings existed, so
/// they are pinned to exactly what is already in the database. `retryWaiting`
/// stays camelCase because changing it is not cosmetic:
///
/// - every persisted `job.state` row holds the current spelling, and
/// - the `job_active_dedupe_unique` partial index predicate matches
///   `state = 'retryWaiting'` literally. Renaming the wire value without
///   rebuilding that index would silently disable the DB-level job dedupe
///   guarantee.
///
/// Declaring them explicitly still buys the thing that matters: renaming a
/// Dart identifier can no longer change what is written to the database, and
/// an unknown value now fails loudly instead of throwing an opaque
/// `byName` error.
enum JobState {
  /// Enqueued, eligible to be claimed once a worker is available.
  queued('queued'),

  /// A scheduler owns a lease on this job; the worker dispatch is committed.
  claimed('claimed'),

  /// The job has been handed to a worker; an execution is (or was) running.
  running('running'),

  /// The job failed transiently; it can be retried after [availableAt].
  retryWaiting('retryWaiting'),

  /// The underlying worker execution passed the platform's verification.
  succeeded('succeeded'),

  /// The underlying execution failed permanently (or exhausts retries).
  failed('failed'),

  /// The job was cancelled before or during execution.
  cancelled('cancelled');

  const JobState(this.wire);

  final String wire;

  bool get isTerminal =>
      this == succeeded || this == failed || this == cancelled;

  bool get isActive => !isTerminal;

  static JobState fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw FormatException('Unknown job state: $value'),
  );
}

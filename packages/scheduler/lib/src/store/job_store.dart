import 'package:platform_contracts/platform_contracts.dart';

/// Durable container for everything the scheduler persists for resume,
/// reconciliation and audit: the [Job] state record, the active [JobClaim]
/// leases, and normalized [SchedulerEventRecord]s. The store owns the
/// durability of the queue; it never makes scheduling decisions.
abstract interface class JobStore {
  /// Persists [job]. When [expectedVersion] is provided the write is a
  /// compare-and-swap against the currently stored version and fails with
  /// [ConcurrentJobModificationException] on mismatch, so two scheduler
  /// instances cannot both win the same job.
  Future<void> saveJob(Job job, {int? expectedVersion});

  Future<Job?> readJob(String jobId);

  Future<List<Job>> listJobs();

  Future<List<Job>> listJobsForWorkItem(String workItemId);

  /// The most recent job for [dedupeKey], if any. Used for idempotent
  /// enqueue: re-evaluating unchanged workflow state must not create a second
  /// job.
  Future<Job?> findLatestByDedupeKey(String dedupeKey);

  Future<void> saveClaim(JobClaim claim);

  Future<JobClaim?> readClaimForJob(String jobId);

  Future<List<JobClaim>> listClaims();

  Future<void> deleteClaim(String jobId);

  Future<void> appendEvent(SchedulerEventRecord event);

  Future<List<SchedulerEventRecord>> readEvents(String jobId);

  /// Runs [body] within a single store transaction. Implementations that back a
  /// transaction-capable database must make every store call inside [body]
  /// atomic and rollback together on error. The default implementation has no
  /// transaction and simply forwards.
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) async =>
      body(this);
}

class JobNotFoundException implements Exception {
  JobNotFoundException(this.jobId);

  final String jobId;

  @override
  String toString() => 'Job not found: $jobId';
}

class ConcurrentJobModificationException implements Exception {
  ConcurrentJobModificationException({
    required this.jobId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String jobId;
  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'Concurrent modification of job $jobId '
      '(expected version $expectedVersion, actual $actualVersion)';
}

/// Raised by a store when a job insert violates the active-state deduplication
/// constraint: an active job (queued/claimed/running/retryWaiting) with the
/// same [dedupeKey] already exists. Callers re-read the existing job and treat
/// the enqueue as a no-op.
class DuplicateActiveJobException implements Exception {
  DuplicateActiveJobException({required this.jobId, required this.dedupeKey});

  final String jobId;
  final String dedupeKey;

  @override
  String toString() =>
      'An active job already exists for dedupe key $dedupeKey (job $jobId)';
}

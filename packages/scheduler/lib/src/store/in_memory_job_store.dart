import 'package:platform_contracts/platform_contracts.dart';

import 'job_store.dart';

/// An in-memory [JobStore]. Fast and deterministic; not durable across
/// process exits (use [FileJsonJobStore] for durability tests and hosts).
class InMemoryJobStore implements JobStore {
  final Map<String, Job> _jobs = {};
  final Map<String, JobClaim> _claims = {};
  final Map<String, List<SchedulerEventRecord>> _events = {};

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) async {
    if (expectedVersion != null) {
      final current = _jobs[job.jobId];
      final actual = current?.version ?? 0;
      if (actual != expectedVersion) {
        throw ConcurrentJobModificationException(
          jobId: job.jobId,
          expectedVersion: expectedVersion,
          actualVersion: actual,
        );
      }
    }
    _jobs[job.jobId] = job;
  }

  @override
  Future<Job?> readJob(String jobId) async => _jobs[jobId];

  @override
  Future<List<Job>> listJobs() async => _jobs.values.toList();

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) async =>
      _jobs.values.where((job) => job.workItemId == workItemId).toList();

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) async {
    Job? latest;
    for (final job in _jobs.values) {
      // Most recently CREATED wins; equal timestamps resolve by the most
      // recently STORED (map iteration is insertion-ordered), because an
      // idempotent enqueue must never resurrect an earlier attempt.
      if (job.dedupeKey == dedupeKey &&
          (latest == null || !job.createdAt.isBefore(latest.createdAt))) {
        latest = job;
      }
    }
    return latest;
  }

  @override
  Future<void> saveClaim(JobClaim claim) async {
    _claims[claim.jobId] = claim;
  }

  @override
  Future<JobClaim?> readClaimForJob(String jobId) async => _claims[jobId];

  @override
  Future<List<JobClaim>> listClaims() async => _claims.values.toList();

  @override
  Future<void> deleteClaim(String jobId) async {
    _claims.remove(jobId);
  }

  @override
  Future<void> appendEvent(SchedulerEventRecord event) async {
    final events = _events.putIfAbsent(event.jobId, () => []);
    events.add(event);
  }

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) async =>
      List.unmodifiable(_events[jobId] ?? const []);
}

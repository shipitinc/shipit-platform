import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

import 'job_store.dart';

/// A durable [JobStore] backed by a single JSON document on disk.
///
/// Every mutation is written to a temp file and atomically renamed over the
/// target so a crash never leaves a truncated document; concurrent mutations
/// are serialized through a write chain so the rename never races itself. A
/// brand new instance backed by the same [File] observes everything the
/// previous instance persisted, which is what makes scheduler process-restart
/// and crash tests meaningful.
///
/// Guarantees: single-host durability with atomic-rename documents. The
/// compare-and-swap that arbitrates claim/lease conflicts is enforced within
/// one store instance; multiple scheduler replicas must therefore share one
/// store connection (the control-plane PostgreSQL store, ADR 0023) rather
/// than each holding an unsynchronized copy of the same file. Cross-host
/// fencing, database-level transactions and multi-node store semantics are
/// intentionally deferred to that store.
class FileJsonJobStore implements JobStore {
  FileJsonJobStore(this._file) {
    _load();
  }

  final File _file;

  final Map<String, Job> _jobs = {};
  final Map<String, JobClaim> _claims = {};
  final Map<String, List<SchedulerEventRecord>> _events = {};

  /// Chains every atomic write so concurrent mutations cannot race the same
  /// temp file and break the rename with ENOENT.
  Future<void> _pendingWrite = Future<void>.value();

  Future<void> _persist() {
    final write = _pendingWrite.then((_) => _writeDocument());
    _pendingWrite = write.then((_) {}, onError: (_) {});
    return write;
  }

  Future<void> _writeDocument() async {
    final document = <String, dynamic>{
      'jobs': _jobs.map((id, job) => MapEntry(id, job.toJson())),
      'claims': _claims.map((id, claim) => MapEntry(id, claim.toJson())),
      'events': _events.map(
        (id, events) => MapEntry(id, events.map((e) => e.toJson()).toList()),
      ),
    };

    await _file.parent.create(recursive: true);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(document),
    );
    await temp.rename(_file.path);
  }

  void _load() {
    if (!_file.existsSync()) return;
    final document =
        jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    final jobs = (document['jobs'] as Map<String, dynamic>? ?? {});
    for (final entry in jobs.entries) {
      _jobs[entry.key] = Job.fromJson(
        (entry.value as Map<String, dynamic>).cast(),
      );
    }
    final claims = (document['claims'] as Map<String, dynamic>? ?? {});
    for (final entry in claims.entries) {
      _claims[entry.key] = JobClaim.fromJson(
        (entry.value as Map<String, dynamic>).cast(),
      );
    }
    final events = (document['events'] as Map<String, dynamic>? ?? {});
    for (final entry in events.entries) {
      final list = (entry.value as List<dynamic>).cast<Map<String, dynamic>>();
      _events[entry.key] = list.map(SchedulerEventRecord.fromJson).toList();
    }
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) async =>
      body(this);

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
    await _persist();
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
    await _persist();
  }

  @override
  Future<JobClaim?> readClaimForJob(String jobId) async => _claims[jobId];

  @override
  Future<List<JobClaim>> listClaims() async => _claims.values.toList();

  @override
  Future<void> deleteClaim(String jobId) async {
    _claims.remove(jobId);
    await _persist();
  }

  @override
  Future<void> appendEvent(SchedulerEventRecord event) async {
    final events = _events.putIfAbsent(event.jobId, () => []);
    events.add(event);
    await _persist();
  }

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) async =>
      List.unmodifiable(_events[jobId] ?? const []);
}

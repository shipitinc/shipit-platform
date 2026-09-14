import 'dart:math';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';

import '../policy/runnable_work.dart';
import '../store/job_store.dart';

/// Outcome of [JobQueue.enqueueIfAbsent].
class JobEnqueueResult {
  const JobEnqueueResult({required this.job, required this.created});

  final Job job;
  final bool created;
}

/// The queue's durable operations: idempotent enqueue, deterministic
/// selection, claim/lease with compare-and-swap, dispatch bookkeeping, and
/// terminal/retry/cancel transitions. The queue never decides WHAT to enqueue
/// (workflow policy does) and never interprets execution results as workflow
/// approval (the workflow engine does that); it only keeps jobs moving.
class JobQueue {
  JobQueue({required JobStore store, DateTime Function()? clock})
    : _store = store,
      _clock = clock ?? DateTime.now;

  final JobStore _store;
  final DateTime Function() _clock;

  static String newJobId() => _newId('jb');
  static String newClaimId() => _newId('cl');

  /// Creates the job if no job exists for [dedupeKey], otherwise returns the
  /// existing job untouched. Re-evaluating UNCHANGED workflow state (same
  /// dedupe key) never creates a second job and never emits a second
  /// `jobQueued` event.
  Future<JobEnqueueResult> enqueueIfAbsent({
    required String workItemId,
    required JobDefinition definition,
    required String dedupeKey,
    required String instruction,
    DateTime? now,
  }) async {
    final at = now ?? _clock().toUtc();
    final existing = await _store.findLatestByDedupeKey(dedupeKey);
    if (existing != null) {
      return JobEnqueueResult(job: existing, created: false);
    }
    final job = Job(
      jobId: newJobId(),
      workItemId: workItemId,
      jobType: definition.jobType,
      requiredRole: definition.requiredRole,
      requiredCapabilities: definition.requiredCapabilities,
      priority: definition.priority,
      state: JobState.queued,
      dedupeKey: dedupeKey,
      createdAt: at,
      instruction: instruction,
      attempt: 1,
      maxAttempts: definition.maxAttempts,
      version: 1,
    );
    await _store.saveJob(job);
    await _event(
      job,
      SchedulerEventType.jobQueued,
      payload: {'jobType': job.jobType.wire, 'priority': job.priority.name},
    );
    return JobEnqueueResult(job: job, created: true);
  }

  /// Since claims are the concurrency gate across scheduler instances, the
  /// check-then-write enqueue above is safe under the scheduler's serialized
  /// tick; a racing second tick at most creates a duplicate job with a unique
  /// id, and only ONE can ever pass the claim CAS.
  /// Deterministic ordering used by [nextEligible] and the scheduler's
  /// dispatch pass: priority (highest first), then availableAt, then
  /// createdAt, then stable job id. Never host-dependent.
  static int orderEligible(Job a, Job b) {
    var cmp = b.priority.order.compareTo(a.priority.order);
    if (cmp != 0) return cmp;
    cmp = _compareNullable(a.availableAt, b.availableAt);
    if (cmp != 0) return cmp;
    cmp = a.createdAt.compareTo(b.createdAt);
    if (cmp != 0) return cmp;
    return a.jobId.compareTo(b.jobId);
  }

  static int _compareNullable(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  /// Whether [job] may start an execution now (queued or retryWaiting, and
  /// past its availableAt window).
  bool isEligibleAt(Job job, DateTime now) {
    if (job.state != JobState.queued && job.state != JobState.retryWaiting) {
      return false;
    }
    if (job.availableAt == null || !job.availableAt!.isAfter(now)) {
      return true;
    }
    return false;
  }

  /// Claims [job] for [ownerId] via a version CAS, then persists the lease.
  /// Returns `null` when the claim lost the CAS (another scheduler won), when
  /// the job is no longer eligible, or when it was cancelled in between.
  /// A `retryWaiting` job is promoted back through `queued` and claimed in
  /// the same operation, so a bounded retry resumes within a single pass.
  Future<JobClaim?> claim({
    required Job job,
    required String ownerId,
    required DateTime now,
    required Duration lease,
  }) async {
    final current = await _store.readJob(job.jobId);
    if (current == null || !isEligibleAt(current, now)) return null;
    var candidate = current;
    if (candidate.state == JobState.retryWaiting) {
      candidate = await _promote(candidate);
      if (candidate.state != JobState.queued) return null;
    }
    final updated = candidate.copyWith(
      state: JobState.claimed,
      version: candidate.version + 1,
    );
    try {
      await _store.saveJob(updated, expectedVersion: candidate.version);
    } on ConcurrentJobModificationException {
      return null;
    }
    final claim = JobClaim(
      claimId: newClaimId(),
      jobId: candidate.jobId,
      ownerId: ownerId,
      leasedUntil: now.add(lease),
      createdAt: now,
    );
    await _store.saveClaim(claim);
    await _event(
      candidate,
      SchedulerEventType.jobClaimed,
      payload: {
        'ownerId': ownerId,
        'leasedUntil': claim.leasedUntil.toIso8601String(),
      },
    );
    return claim;
  }

  Future<Job> _promote(Job job) async {
    final current = (await _store.readJob(job.jobId))!;
    final updated = current.copyWith(
      state: JobState.queued,
      version: current.version + 1,
    );
    try {
      await _store.saveJob(updated, expectedVersion: current.version);
    } on ConcurrentJobModificationException {
      // Lost the promotion race; someone else will handle it.
    }
    return updated;
  }

  /// Marks the claimed job as dispatched to a worker, recording the reference
  /// to the underlying worker execution BEFORE the worker starts so a crash
  /// during dispatch is distinguishable from "never dispatched".
  Future<Job> markRunning({
    required Job job,
    required DateTime now,
    required String workerId,
    required String workerExecutionId,
  }) async {
    final current = await _store.readJob(job.jobId);
    if (current == null || current.state != JobState.claimed) {
      return current ?? job;
    }
    final updated = current.copyWith(
      state: JobState.running,
      startedAt: current.startedAt ?? now,
      executionReference: JobExecutionReference(
        workerExecutionId: workerExecutionId,
        createdAt: now,
      ),
      workerId: workerId,
      version: current.version + 1,
    );
    try {
      await _store.saveJob(updated, expectedVersion: current.version);
    } on ConcurrentJobModificationException {
      return current;
    }
    await _event(
      current,
      SchedulerEventType.jobDispatched,
      payload: {'workerId': workerId, 'workerExecutionId': workerExecutionId},
    );
    return updated;
  }

  /// Returns a claimed/running job whose dispatch failed BEFORE any worker
  /// execution was created back to the queue. Safe by construction: the job
  /// either has no execution reference or its referenced execution does not
  /// exist, so nothing can double-run.
  Future<Job> revertToQueued({
    required Job job,
    required String reason,
    WorkerDispatchOutcome? outcome,
  }) async {
    final current = await _store.readJob(job.jobId);
    if (current == null) return job;
    final updated = current.copyWith(
      state: JobState.queued,
      executionReference: null,
      version: current.version + 1,
    );
    try {
      await _store.saveJob(updated, expectedVersion: current.version);
    } on ConcurrentJobModificationException {
      return current;
    }
    await _store.deleteClaim(job.jobId);
    await _event(
      current,
      SchedulerEventType.jobDeferred,
      payload: {'reason': reason, if (outcome != null) 'outcome': outcome.name},
    );
    return updated;
  }

  /// Records that a runnable job could not be placed on any worker this tick
  /// (job STAYS queued; no failure is recorded - "no worker" is not an error).
  /// Emitted at most once per consecutive deferred window to avoid polluting
  /// the audit log with per-tick noise.
  Future<void> recordDeferred({
    required Job job,
    required WorkerDispatchOutcome outcome,
    DateTime? now,
  }) async {
    final prior = await _store.readEvents(job.jobId);
    if (prior.isNotEmpty && prior.last.type == SchedulerEventType.jobDeferred) {
      return;
    }
    await _event(
      job,
      SchedulerEventType.jobDeferred,
      payload: {'outcome': outcome.name},
    );
  }

  /// Persistently requeues a job recovered from a stale/expired claim.
  Future<Job> requeueFromStaleClaim({
    required Job job,
    required String reason,
    DateTime? now,
  }) async {
    final current = await _store.readJob(job.jobId);
    if (current == null || current.isTerminal) return current ?? job;
    final updated = current.copyWith(
      state: JobState.queued,
      executionReference: null,
      workerId: null,
      version: current.version + 1,
    );
    try {
      await _store.saveJob(updated, expectedVersion: current.version);
    } on ConcurrentJobModificationException {
      return current;
    }
    await _store.deleteClaim(job.jobId);
    await _event(
      current,
      SchedulerEventType.jobQueued,
      payload: {'reason': reason, 'reclaimed': true},
    );
    return updated;
  }

  /// Terminal transition. [terminal] must be succeeded/failed/cancelled.
  Future<Job> complete({
    required Job job,
    required JobState terminal,
    JobFailure? failure,
    String? cancelReason,
    DateTime? now,
  }) async {
    assert(
      terminal == JobState.succeeded ||
          terminal == JobState.failed ||
          terminal == JobState.cancelled,
      'complete() only accepts terminal states',
    );
    final at = now ?? _clock().toUtc();
    final current = await _store.readJob(job.jobId);
    if (current == null || current.isTerminal) return current ?? job;
    final updated = current.copyWith(
      state: terminal,
      completedAt: at,
      failure: failure,
      cancelReason: cancelReason,
      version: current.version + 1,
    );
    try {
      await _store.saveJob(updated, expectedVersion: current.version);
    } on ConcurrentJobModificationException {
      return current;
    }
    await _store.deleteClaim(job.jobId);
    final type = switch (terminal) {
      JobState.succeeded => SchedulerEventType.jobCompleted,
      JobState.failed => SchedulerEventType.jobFailed,
      JobState.cancelled => SchedulerEventType.jobCancelled,
      _ => SchedulerEventType.jobFailed,
    };
    await _event(
      current,
      type,
      payload: {
        if (failure != null) 'failureCode': failure.code.name,
        if (cancelReason != null) 'reason': cancelReason,
      },
    );
    return updated;
  }

  /// Schedules a bounded retry: job moves to retryWaiting until
  /// `now + retryDelay`, attempt is incremented, and the stale claim is
  /// released.
  Future<Job> scheduleRetry({
    required Job job,
    required JobFailure failure,
    DateTime? now,
    Duration? retryDelay,
  }) async {
    final at = now ?? _clock().toUtc();
    final current = await _store.readJob(job.jobId);
    if (current == null || current.isTerminal) return current ?? job;
    final updated = current.copyWith(
      state: JobState.retryWaiting,
      failure: failure,
      availableAt: at.add(retryDelay ?? const Duration(minutes: 1)),
      attempt: current.attempt + 1,
      version: current.version + 1,
    );
    try {
      await _store.saveJob(updated, expectedVersion: current.version);
    } on ConcurrentJobModificationException {
      return current;
    }
    await _store.deleteClaim(job.jobId);
    await _event(
      current,
      SchedulerEventType.jobRetryScheduled,
      payload: {
        'attempt': updated.attempt,
        'availableAt': updated.availableAt!.toIso8601String(),
        'reason': failure.reason,
      },
    );
    return updated;
  }

  /// Cancels a job that has NOT started executing (queued/retryWaiting).
  /// Running jobs are cancelled through the worker/coordinator path and
  /// reach this terminal transition via outcome adoption.
  Future<Job> cancelQueued({
    required Job job,
    required String reason,
    DateTime? now,
  }) {
    return complete(
      job: job,
      terminal: JobState.cancelled,
      cancelReason: reason,
      now: now,
    );
  }

  JobStore get store => _store;

  Future<void> _event(
    Job job,
    SchedulerEventType type, {
    Map<String, dynamic>? payload,
  }) async {
    final events = await _store.readEvents(job.jobId);
    await _store.appendEvent(
      SchedulerEventRecord(
        eventId: 'se-${job.jobId}-${events.length + 1}',
        jobId: job.jobId,
        workItemId: job.workItemId,
        sequence: events.length + 1,
        type: type,
        occurredAt: _clock().toUtc(),
        payload: payload,
      ),
    );
  }

  static String _newId(String prefix) {
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
        '${Random().nextInt(1 << 32).toRadixString(36)}';
    return '$prefix-$suffix';
  }
}

import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import 'package:platform_contracts/platform_contracts.dart'
    show Job, JobClaim, SchedulerEventRecord;

import '../generated/job_claim_view.dart';
import '../generated/job_inspection_view.dart';
import '../generated/job_list_view.dart';
import '../generated/job_record_view.dart';
import '../generated/scheduler_event_view.dart';
import '../services/control_plane_service.dart';

/// Read endpoints for scheduler durable state (jobs + their lifecycle events).
class SchedulerEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Lists all jobs, newest first. Reads only.
  ///
  /// Was `Future<Map<String, dynamic>>`, so the generated client could not read
  /// it at all.
  Future<JobListView> listJobs(
    Session session, {
    String? workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final jobs = workItemId == null
          ? await service.listJobs()
          : await service.listJobsForWorkItem(workItemId);
      return JobListView(
        jobs: jobs.map(_jobView).toList(growable: false),
      );
    } catch (error, stackTrace) {
      service.logger.error('scheduler.list.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns one job, its claim, and its full event history. Reads only.
  Future<JobInspectionView> inspect(
    Session session, {
    required String jobId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final job = await service.readJob(jobId);
      if (job == null) {
        throw StateError('Unknown job $jobId');
      }
      final events = await service.readJobEvents(jobId);
      final claim = await service.readClaimForJob(jobId);
      return JobInspectionView(
        job: _jobView(job),
        events: events.map(_eventView).toList(growable: false),
        claim: claim == null ? null : _claimView(claim),
      );
    } catch (error, stackTrace) {
      service.logger.error('scheduler.inspect.failed', {
        'jobId': jobId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // ---------------------------------------------------------------------
  // Projections
  //
  // Named copies, not `toJson()`: a field added to a domain type breaks this
  // build rather than silently widening a wire contract. Enums travel as wire
  // text and `requiredCapabilities` (a `Set` on the domain type) travels as a
  // `List`, which is the only shape JSON has for it.
  //
  // `SchedulerEventRecord.payload` is the one open-ended value, and it travels
  // as JSON TEXT because Serverpod 3.4.13 refuses `dynamic` in a model schema,
  // so no field type can hold parsed JSON. See
  // `defect_endpoints.dart` for the same convention on a client-reachable path.
  // ---------------------------------------------------------------------

  JobRecordView _jobView(Job j) => JobRecordView(
    jobId: j.jobId,
    workItemId: j.workItemId,
    jobType: j.jobType.wire,
    requiredRole: j.requiredRole.wire,
    requiredCapabilities: j.requiredCapabilities
        .map((c) => c.name)
        .toList(growable: false),
    priority: j.priority.name,
    state: j.state.wire,
    dedupeKey: j.dedupeKey,
    createdAt: j.createdAt,
    availableAt: j.availableAt,
    instruction: j.instruction,
  );

  SchedulerEventView _eventView(SchedulerEventRecord e) => SchedulerEventView(
    eventId: e.eventId,
    jobId: e.jobId,
    workItemId: e.workItemId,
    sequence: e.sequence,
    type: e.type.wire,
    occurredAt: e.occurredAt,
    payloadJson: e.payload == null ? null : jsonEncode(e.payload),
  );

  JobClaimView _claimView(JobClaim c) => JobClaimView(
    claimId: c.claimId,
    jobId: c.jobId,
    ownerId: c.ownerId,
    leasedUntil: c.leasedUntil,
    createdAt: c.createdAt,
  );
}

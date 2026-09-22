import 'package:serverpod/serverpod.dart';

import '../services/control_plane_service.dart';
import '../services/structured_logger.dart';

/// Read endpoints for scheduler durable state (jobs + their lifecycle events).
class SchedulerEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Lists all jobs, newest first. Reads only.
  Future<Map<String, dynamic>> listJobs(
    Session session, {
    String? workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final jobs = workItemId == null
          ? await service.listJobs()
          : await service.listJobsForWorkItem(workItemId);
      return {'jobs': toJsonList(jobs.map((e) => e.toJson()))};
    } catch (error, stackTrace) {
      service.logger.error('scheduler.list.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns one job, its claim, and its full event history. Reads only.
  Future<Map<String, dynamic>> inspect(
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
      return {
        'job': toJsonObject(job.toJson()),
        'events': toJsonList(events.map((e) => e.toJson())),
        'claim': claim == null ? null : toJsonObject(claim.toJson()),
      };
    } catch (error, stackTrace) {
      service.logger.error('scheduler.inspect.failed', {
        'jobId': jobId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

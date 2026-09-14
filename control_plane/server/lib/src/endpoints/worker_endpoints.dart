import 'package:serverpod/serverpod.dart';

import '../services/control_plane_service.dart';
import '../services/structured_logger.dart';
import 'package:worker_runtime/worker_runtime.dart'
    show WorkerRegistrationCodec;

/// Read endpoints for worker_runtime durable state (registrations +
/// executions + results).
class WorkerEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Lists registered workers. Reads only.
  Future<Map<String, dynamic>> listWorkers(
    Session session,
  ) async {
    final service = ControlPlaneService(session);
    try {
      final workers = await service.listWorkers();
      return {
        'workers': workers
            .map((w) => toJsonObject(WorkerRegistrationCodec.toJson(w)))
            .toList(),
      };
    } catch (error, stackTrace) {
      service.logger.error('worker.list.failed', {'error': error.toString()});
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists worker executions, newest first. Reads only.
  Future<Map<String, dynamic>> listExecutions(
    Session session, {
    String? workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final executions = await service.listWorkerExecutions();
      final filtered = workItemId == null
          ? executions
          : executions.where((e) => e.workItemId == workItemId).toList();
      return {'executions': toJsonList(filtered.map((e) => e.toJson()))};
    } catch (error, stackTrace) {
      service.logger.error('worker.executions.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns one execution, its events and (if present) its result. Reads only.
  Future<Map<String, dynamic>> inspect(
    Session session, {
    required String workerExecutionId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final executions = await service.listWorkerExecutions();
      final execution = executions
          .where((e) => e.workerExecutionId == workerExecutionId)
          .firstOrNull;
      if (execution == null) {
        throw StateError('Unknown worker execution $workerExecutionId');
      }
      final result = await service.readWorkerResult(workerExecutionId);
      final events = await service.readWorkerEvents(workerExecutionId);
      return {
        'execution': toJsonObject(execution.toJson()),
        'events': toJsonList(events.map((e) => e.toJson())),
        'result': result == null ? null : toJsonObject(result.toJson()),
      };
    } catch (error, stackTrace) {
      service.logger.error('worker.inspect.failed', {
        'workerExecutionId': workerExecutionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

import 'package:serverpod/serverpod.dart';

import '../services/control_plane_service.dart';
import '../services/structured_logger.dart';

/// Read endpoints for execution_coordinator durable state (agent executions,
/// events, results, verifications).
class ExecutionEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Lists agent executions, optionally filtered by work item. Reads only.
  Future<Map<String, dynamic>> list(
    Session session, {
    String? workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final executions = await service.listAgentExecutions(
        workItemId: workItemId,
      );
      return {'executions': toJsonList(executions.map((e) => e.toJson()))};
    } catch (error, stackTrace) {
      service.logger.error('execution.list.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns one execution, its events, result and verifications. Reads only.
  Future<Map<String, dynamic>> inspect(
    Session session, {
    required String executionId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final execution = await service.readAgentExecution(executionId);
      final events = await service.readAgentEvents(executionId);
      final result = await service.readAgentResult(executionId);
      final verifications = await service.readVerifications(executionId);
      return {
        'execution': toJsonObject(execution.toJson()),
        'events': toJsonList(events.map((e) => e.toJson())),
        'result': result == null ? null : toJsonObject(result.toJson()),
        'verifications': toJsonList(verifications.map((e) => e.toJson())),
      };
    } catch (error, stackTrace) {
      service.logger.error('execution.inspect.failed', {
        'executionId': executionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

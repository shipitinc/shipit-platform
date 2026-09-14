import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';

import '../services/control_plane_service.dart';
import '../services/structured_logger.dart';

/// Read endpoints for durable workflow state (work items + their transitions).
class WorkflowEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Returns the current work item and its transition history. Never mutates
  /// state; `WorkItem.state` on the wire is always reported, never written.
  Future<Map<String, dynamic>> inspect(
    Session session, {
    required String workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final item = await service.readWorkItem(workItemId);
      final history = await service.readTransitionHistory(workItemId);
      return {
        'workItem': toJsonObject(item.toJson()),
        'transitionHistory': toJsonList(history.map((e) => e.toJson())),
      };
    } catch (error, stackTrace) {
      service.logger.error('workflow.inspect.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists every decision attached to a work item, most recent first.
  Future<Map<String, dynamic>> listDecisions(
    Session session, {
    required String workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final decisions = await service.readDecisionsForWorkItem(workItemId);
      return {'decisions': toJsonList(decisions.map((e) => e.toJson()))};
    } catch (error, stackTrace) {
      service.logger.error('workflow.decisions.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Resolves a human decision through the durable engine.
  ///
  /// This is the only legal request-side state transition. The decision,
  /// its resolution, and the resulting work item move are persisted
  /// transactionally; a repeated call is an idempotent replay, so retries
  /// after a network failure never double-apply the transition.
  Future<Map<String, dynamic>> resolveDecision(
    Session session, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String algorithm,
    required String publicKey,
    required String signature,
    required DateTime signedAt,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final workItem = await service.resolveHumanDecision(
        decisionId: decisionId,
        choice: HumanDecisionChoice.fromWire(choice),
        decider: decider,
        rationale: rationale,
        signature: DecisionSignature(
          algorithm: algorithm,
          publicKey: publicKey,
          signature: signature,
          signedAt: signedAt,
        ),
      );
      final decision = await service.readDecisionsForWorkItem(
        workItem.workItemId,
      );
      return {
        'workItem': toJsonObject(workItem.toJson()),
        'decision': decision.isEmpty
            ? null
            : toJsonObject(
                decision.firstWhere((d) => d.decisionId == decisionId).toJson(),
              ),
      };
    } catch (error, stackTrace) {
      service.logger.error('workflow.resolve.failed', {
        'decisionId': decisionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

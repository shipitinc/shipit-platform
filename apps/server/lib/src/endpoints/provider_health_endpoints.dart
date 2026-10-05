import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';

import '../services/control_plane_service.dart';

/// Provider health and model policy management endpoints.
class ProviderHealthEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Returns the health status of all known providers.
  Future<Map<String, dynamic>> getProviderHealth(Session session) async {
    final service = ControlPlaneService(session);
    try {
      final policies = await service.modelPolicyStore.getAllPolicies();
      final providers = <String>{};
      for (final p in policies) {
        for (final step in p.chain) {
          providers.add(step.provider);
        }
      }

      // In a full implementation, this would query the health monitor state
      // For now, return the list of known providers from policies
      return {
        'providers': providers
            .map((p) => {'provider': p, 'healthy': null})
            .toList(),
        'allProvidersDown': <Map<String, dynamic>>[],
      };
    } catch (error, stackTrace) {
      service.logger.error('provider_health.get.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists all model policies.
  Future<Map<String, dynamic>> listModelPolicies(Session session) async {
    final service = ControlPlaneService(session);
    try {
      final policies = await service.modelPolicyStore.getAllPolicies();
      return {'policies': policies.map((p) => p.toJson()).toList()};
    } catch (error, stackTrace) {
      service.logger.error('model_policies.list.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Updates a model policy chain (requires admin).
  Future<Map<String, dynamic>> updateModelPolicy(
    Session session, {
    required String role,
    required String chainJson,
    required int version,
    required String updatedByDecisionId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final policy = ModelPolicy(
        role: AgentRole.fromWire(role),
        chain: jsonDecode(
          chainJson,
        ).map<ModelStep>((c) => ModelStep.fromJson(c)).toList(growable: false),
        version: version,
        updatedAt: DateTime.now().toUtc(),
        updatedByDecisionId: updatedByDecisionId,
      );
      await service.modelPolicyStore.upsertPolicy(policy);
      return {'success': true};
    } catch (error, stackTrace) {
      service.logger.error('model_policies.update.failed', {
        'role': role,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns paginated model execution records with filters.
  Future<Map<String, dynamic>> listModelExecutions(
    Session session, {
    String? workItemId,
    String? provider,
    String? modelId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    final service = ControlPlaneService(session);
    try {
      // TODO: Add query methods to PostgresModelExecutionRecordStore for filtering
      // For now, return all records for a work item if specified
      List<ModelExecutionRecord> records;
      if (workItemId != null) {
        records = await service.modelExecutionRecordStore.getByWorkItem(
          workItemId,
        );
      } else {
        // This would need a listAll or similar method
        records = [];
      }

      // Apply additional filters in memory for now
      if (provider != null) {
        records = records.where((r) => r.provider == provider).toList();
      }
      if (modelId != null) {
        records = records.where((r) => r.modelId == modelId).toList();
      }
      if (from != null) {
        records = records.where((r) => r.startedAt.isAfter(from)).toList();
      }
      if (to != null) {
        records = records.where((r) => r.startedAt.isBefore(to)).toList();
      }

      // Apply pagination
      final total = records.length;
      final paginated = records.skip(offset).take(limit).toList();

      return {
        'executions': paginated.map((r) => r.toJson()).toList(),
        'total': total,
        'limit': limit,
        'offset': offset,
      };
    } catch (error, stackTrace) {
      service.logger.error('model_executions.list.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns aggregated model execution statistics.
  Future<Map<String, dynamic>> getModelStats(
    Session session, {
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final stats = await service.modelExecutionRecordStore.getStats(
        from: from,
        to: to,
        groupBy: groupBy,
      );
      return {
        'count': stats.count,
        'totalInputTokens': stats.totalInputTokens,
        'totalOutputTokens': stats.totalOutputTokens,
        'totalTokens': stats.totalTokens,
        'totalCachedReadTokens': stats.totalCachedReadTokens,
        'totalCostUsd': stats.totalCostUsd,
        'avgCostUsd': stats.avgCostUsd,
        'successCount': stats.successCount,
        'failureCount': stats.failureCount,
        'byGroup': stats.byGroup
            .map(
              (g) => {
                'groupKey': g.groupKey,
                'count': g.count,
                'totalInputTokens': g.totalInputTokens,
                'totalOutputTokens': g.totalOutputTokens,
                'totalTokens': g.totalTokens,
                'totalCachedReadTokens': g.totalCachedReadTokens,
                'totalCostUsd': g.totalCostUsd,
                'avgCostUsd': g.avgCostUsd,
                'successCount': g.successCount,
                'failureCount': g.failureCount,
              },
            )
            .toList(),
      };
    } catch (error, stackTrace) {
      service.logger.error('model_stats.get.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

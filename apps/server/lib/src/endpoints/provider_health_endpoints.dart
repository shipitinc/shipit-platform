import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/model_execution_list_view.dart';
import '../generated/model_execution_record_view.dart';
import '../generated/model_policy_list_view.dart';
import '../generated/model_policy_view.dart';
import '../generated/model_stats_group_view.dart';
import '../generated/model_stats_view.dart';
import '../generated/model_step_view.dart';
import '../generated/provider_health_view.dart';
import '../generated/provider_status_view.dart';
import '../services/control_plane_service.dart';

/// Provider health and model policy management endpoints.
class ProviderHealthEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Returns the health status of all known providers.
  ///
  /// Was `Future<Map<String, dynamic>>`. Every method on this endpoint class was
  /// reachable from the live Flutter client and every one of them threw
  /// `No deserialization found for type dynamic` on first use.
  Future<ProviderHealthView> getProviderHealth(Session session) async {
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
      return ProviderHealthView(
        providers: providers
            .map((p) => ProviderStatusView(provider: p, healthy: null))
            .toList(growable: false),
        allProvidersDown: const [],
      );
    } catch (error, stackTrace) {
      service.logger.error('provider_health.get.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists all model policies.
  Future<ModelPolicyListView> listModelPolicies(Session session) async {
    final service = ControlPlaneService(session);
    try {
      final policies = await service.modelPolicyStore.getAllPolicies();
      return ModelPolicyListView(
        policies: policies.map(_modelPolicyView).toList(growable: false),
      );
    } catch (error, stackTrace) {
      service.logger.error('model_policies.list.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Updates a model policy chain (requires admin).
  ///
  /// Returns the policy as written, not `{'success': true}`. The old
  /// acknowledgement could not satisfy this client method's declared return
  /// type — `ModelPolicyResponse.fromJson` read a `role` that was never sent —
  /// so the pair only worked because the one caller discarded the result. The
  /// endpoint now publishes the thing it just persisted.
  Future<ModelPolicyView> updateModelPolicy(
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
      return _modelPolicyView(policy);
    } catch (error, stackTrace) {
      service.logger.error('model_policies.update.failed', {
        'role': role,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns paginated model execution records with filters.
  Future<ModelExecutionListView> listModelExecutions(
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

      return ModelExecutionListView(
        executions: paginated.map(_modelExecutionView).toList(growable: false),
        total: total,
        limit: limit,
        offset: offset,
      );
    } catch (error, stackTrace) {
      service.logger.error('model_executions.list.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns aggregated model execution statistics.
  Future<ModelStatsView> getModelStats(
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
      return ModelStatsView(
        count: stats.count,
        totalInputTokens: stats.totalInputTokens,
        totalOutputTokens: stats.totalOutputTokens,
        totalTokens: stats.totalTokens,
        totalCachedReadTokens: stats.totalCachedReadTokens,
        totalCostUsd: stats.totalCostUsd,
        avgCostUsd: stats.avgCostUsd,
        successCount: stats.successCount,
        failureCount: stats.failureCount,
        byGroup: stats.byGroup
            .map(
              (g) => ModelStatsGroupView(
                groupKey: g.groupKey,
                count: g.count,
                totalInputTokens: g.totalInputTokens,
                totalOutputTokens: g.totalOutputTokens,
                totalTokens: g.totalTokens,
                totalCachedReadTokens: g.totalCachedReadTokens,
                totalCostUsd: g.totalCostUsd,
                avgCostUsd: g.avgCostUsd,
                successCount: g.successCount,
                failureCount: g.failureCount,
              ),
            )
            .toList(growable: false),
      );
    } catch (error, stackTrace) {
      service.logger.error('model_stats.get.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // ---------------------------------------------------------------------
  // Projections
  //
  // Named copies rather than `ModelPolicy.toJson()` / `ModelExecutionRecord
  // .toJson()`, so a field added to a domain type breaks this build instead of
  // silently widening a wire contract. Enums travel as their wire text, as
  // everywhere else in `lib/src/models/`.
  // ---------------------------------------------------------------------

  ModelPolicyView _modelPolicyView(ModelPolicy p) => ModelPolicyView(
    role: p.role.wire,
    chain: p.chain
        .map(
          (s) => ModelStepView(modelId: s.modelId, provider: s.provider),
        )
        .toList(growable: false),
    version: p.version,
    updatedAt: p.updatedAt,
    updatedByDecisionId: p.updatedByDecisionId,
  );

  ModelExecutionRecordView _modelExecutionView(ModelExecutionRecord r) =>
      ModelExecutionRecordView(
        workItemId: r.workItemId,
        jobId: r.jobId,
        agentExecutionId: r.agentExecutionId,
        role: r.role.wire,
        modelId: r.modelId,
        provider: r.provider,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
        totalTokens: r.totalTokens,
        cachedReadTokens: r.cachedReadTokens,
        costUsd: r.costUsd,
        currency: r.currency,
        startedAt: r.startedAt,
        finishedAt: r.finishedAt,
        success: r.success,
        error: r.error,
        escalationIndex: r.escalationIndex,
        taskType: r.taskType,
      );
}

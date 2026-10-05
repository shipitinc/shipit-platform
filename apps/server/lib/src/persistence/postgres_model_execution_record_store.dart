import 'package:execution_coordinator/execution_coordinator.dart'
    show ModelExecutionRecordStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// Statistics for model execution records.
class ModelExecutionStats {
  const ModelExecutionStats({
    required this.count,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalTokens,
    required this.totalCachedReadTokens,
    required this.totalCostUsd,
    required this.avgCostUsd,
    required this.successCount,
    required this.failureCount,
    this.byGroup = const [],
  });

  final int count;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalTokens;
  final int totalCachedReadTokens;
  final double totalCostUsd;
  final double avgCostUsd;
  final int successCount;
  final int failureCount;
  final List<GroupedModelExecutionStats> byGroup;

  factory ModelExecutionStats.empty() => const ModelExecutionStats(
    count: 0,
    totalInputTokens: 0,
    totalOutputTokens: 0,
    totalTokens: 0,
    totalCachedReadTokens: 0,
    totalCostUsd: 0.0,
    avgCostUsd: 0.0,
    successCount: 0,
    failureCount: 0,
  );

  factory ModelExecutionStats.byGroup(List<GroupedModelExecutionStats> groups) {
    return ModelExecutionStats(
      count: groups.fold(0, (sum, g) => sum + g.count),
      totalInputTokens: groups.fold(0, (sum, g) => sum + g.totalInputTokens),
      totalOutputTokens: groups.fold(0, (sum, g) => sum + g.totalOutputTokens),
      totalTokens: groups.fold(0, (sum, g) => sum + g.totalTokens),
      totalCachedReadTokens: groups.fold(
        0,
        (sum, g) => sum + g.totalCachedReadTokens,
      ),
      totalCostUsd: groups.fold(0.0, (sum, g) => sum + g.totalCostUsd),
      avgCostUsd: groups.isEmpty
          ? 0.0
          : groups.fold(0.0, (sum, g) => sum + g.avgCostUsd) / groups.length,
      successCount: groups.fold(0, (sum, g) => sum + g.successCount),
      failureCount: groups.fold(0, (sum, g) => sum + g.failureCount),
      byGroup: groups,
    );
  }
}

/// Grouped statistics for model execution records.
class GroupedModelExecutionStats {
  const GroupedModelExecutionStats({
    required this.groupKey,
    required this.count,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalTokens,
    required this.totalCachedReadTokens,
    required this.totalCostUsd,
    required this.avgCostUsd,
    required this.successCount,
    required this.failureCount,
  });

  final String groupKey;
  final int count;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalTokens;
  final int totalCachedReadTokens;
  final double totalCostUsd;
  final double avgCostUsd;
  final int successCount;
  final int failureCount;
}

/// PostgreSQL implementation of [ModelExecutionRecordStore].
class PostgresModelExecutionRecordStore implements ModelExecutionRecordStore {
  PostgresModelExecutionRecordStore(this._db);

  final PersistenceDatabase _db;

  Future<T> inTransaction<T>(
    Future<T> Function(PostgresModelExecutionRecordStore store) body,
  ) {
    return _db.inTransaction<T>(() => body(this));
  }

  @override
  Future<void> insert(ModelExecutionRecord record) async {
    await _db.execute(
      '''INSERT INTO "model_execution_record"
           ("workItemId", "jobId", "agentExecutionId", "role", "modelId",
            "provider", "inputTokens", "outputTokens", "totalTokens",
            "cachedReadTokens", "costUsd", "currency", "startedAt",
            "finishedAt", "success", "error", "escalationIndex", "taskType")
         VALUES
           (@workItemId, @jobId, @agentExecutionId, @role, @modelId,
            @provider, @inputTokens, @outputTokens, @totalTokens,
            @cachedReadTokens, @costUsd, @currency, @startedAt,
            @finishedAt, @success, @error, @escalationIndex, @taskType)''',
      parameters: QueryParameters.named(_toParams(record)),
    );
  }

  @override
  Future<void> insertAll(List<ModelExecutionRecord> records) async {
    if (records.isEmpty) return;
    await _db.inTransaction(() async {
      for (final record in records) {
        await _db.execute(
          '''INSERT INTO "model_execution_record"
               ("workItemId", "jobId", "agentExecutionId", "role", "modelId",
                "provider", "inputTokens", "outputTokens", "totalTokens",
                "cachedReadTokens", "costUsd", "currency", "startedAt",
                "finishedAt", "success", "error", "escalationIndex", "taskType")
           VALUES
             (@workItemId, @jobId, @agentExecutionId, @role, @modelId,
              @provider, @inputTokens, @outputTokens, @totalTokens,
              @cachedReadTokens, @costUsd, @currency, @startedAt,
              @finishedAt, @success, @error, @escalationIndex, @taskType)''',
          parameters: QueryParameters.named(_toParams(record)),
        );
      }
    });
  }

  @override
  Future<List<ModelExecutionRecord>> getByWorkItem(String workItemId) async {
    final rows = await _db.query(
      'SELECT * FROM "model_execution_record" WHERE "workItemId" = @workItemId ORDER BY "startedAt" ASC',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<ModelExecutionRecord>> getByJob(String jobId) async {
    final rows = await _db.query(
      'SELECT * FROM "model_execution_record" WHERE "jobId" = @jobId ORDER BY "startedAt" ASC',
      parameters: QueryParameters.named({'jobId': jobId}),
    );
    return rows.map(_fromRow).toList();
  }

  Future<ModelExecutionStats> getStats({
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) async {
    final where = <String>[];
    final params = <String, dynamic>{};

    if (from != null) {
      where.add('"startedAt" >= @from');
      params['from'] = from.toUtc();
    }
    if (to != null) {
      where.add('"startedAt" <= @to');
      params['to'] = to.toUtc();
    }

    String groupByColumn;
    switch (groupBy) {
      case 'modelId':
        groupByColumn = '"modelId"';
        break;
      case 'provider':
        groupByColumn = '"provider"';
        break;
      case 'taskType':
        groupByColumn = '"taskType"';
        break;
      case 'role':
        groupByColumn = '"role"';
        break;
      default:
        groupByColumn = '1'; // No grouping, single aggregate
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final groupByClause = groupBy != null ? 'GROUP BY $groupByColumn' : '';

    final selectColumns = groupBy != null ? '$groupByColumn, ' : '';

    final rows = await _db.query(
      '''SELECT $selectColumns
            COUNT(*) as "count",
            SUM("inputTokens") as "totalInputTokens",
            SUM("outputTokens") as "totalOutputTokens",
            SUM("totalTokens") as "totalTokens",
            SUM("cachedReadTokens") as "totalCachedReadTokens",
            SUM("costUsd") as "totalCostUsd",
            AVG("costUsd") as "avgCostUsd",
            COUNT(*) FILTER (WHERE "success") as "successCount",
            COUNT(*) FILTER (WHERE NOT "success") as "failureCount"
         FROM "model_execution_record"
         $whereClause
         $groupByClause
         ORDER BY "totalCostUsd" DESC''',
      parameters: QueryParameters.named(params),
    );

    if (groupBy != null) {
      return ModelExecutionStats.byGroup(
        rows.map((r) {
          final m = r.toColumnMap();
          return GroupedModelExecutionStats(
            groupKey: m[groupByColumn] as String,
            count: m['count'] as int,
            totalInputTokens: m['totalInputTokens'] as int? ?? 0,
            totalOutputTokens: m['totalOutputTokens'] as int? ?? 0,
            totalTokens: m['totalTokens'] as int? ?? 0,
            totalCachedReadTokens: m['totalCachedReadTokens'] as int? ?? 0,
            totalCostUsd: (m['totalCostUsd'] as num?)?.toDouble() ?? 0.0,
            avgCostUsd: (m['avgCostUsd'] as num?)?.toDouble() ?? 0.0,
            successCount: m['successCount'] as int? ?? 0,
            failureCount: m['failureCount'] as int? ?? 0,
          );
        }).toList(),
      );
    }

    if (rows.isEmpty) {
      return ModelExecutionStats.empty();
    }

    final m = rows.first.toColumnMap();
    return ModelExecutionStats(
      count: m['count'] as int,
      totalInputTokens: m['totalInputTokens'] as int? ?? 0,
      totalOutputTokens: m['totalOutputTokens'] as int? ?? 0,
      totalTokens: m['totalTokens'] as int? ?? 0,
      totalCachedReadTokens: m['totalCachedReadTokens'] as int? ?? 0,
      totalCostUsd: (m['totalCostUsd'] as num?)?.toDouble() ?? 0.0,
      avgCostUsd: (m['avgCostUsd'] as num?)?.toDouble() ?? 0.0,
      successCount: m['successCount'] as int? ?? 0,
      failureCount: m['failureCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _toParams(ModelExecutionRecord r) => {
    'workItemId': r.workItemId,
    'jobId': r.jobId,
    'agentExecutionId': r.agentExecutionId,
    'role': r.role.wire,
    'modelId': r.modelId,
    'provider': r.provider,
    'inputTokens': r.inputTokens,
    'outputTokens': r.outputTokens,
    'totalTokens': r.totalTokens,
    'cachedReadTokens': r.cachedReadTokens,
    'costUsd': r.costUsd,
    'currency': r.currency,
    'startedAt': r.startedAt.toUtc(),
    'finishedAt': r.finishedAt.toUtc(),
    'success': r.success,
    'error': r.error,
    'escalationIndex': r.escalationIndex,
    'taskType': r.taskType,
  };

  ModelExecutionRecord _fromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return ModelExecutionRecord(
      workItemId: m['workItemId'] as String,
      jobId: m['jobId'] as String,
      agentExecutionId: m['agentExecutionId'] as String,
      role: AgentRole.fromWire(m['role'] as String),
      modelId: m['modelId'] as String,
      provider: m['provider'] as String,
      inputTokens: m['inputTokens'] as int,
      outputTokens: m['outputTokens'] as int,
      totalTokens: m['totalTokens'] as int,
      cachedReadTokens: m['cachedReadTokens'] as int,
      costUsd: (m['costUsd'] as num).toDouble(),
      currency: m['currency'] as String,
      startedAt: decodeUtc(m['startedAt'])!,
      finishedAt: decodeUtc(m['finishedAt'])!,
      success: m['success'] as bool,
      error: m['error'] as String?,
      escalationIndex: m['escalationIndex'] as int,
      taskType: m['taskType'] as String,
    );
  }
}

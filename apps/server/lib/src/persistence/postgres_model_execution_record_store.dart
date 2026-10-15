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
    final count = groups.fold(0, (sum, g) => sum + g.count);
    final totalCostUsd = groups.fold(0.0, (sum, g) => sum + g.totalCostUsd);
    return ModelExecutionStats(
      count: count,
      totalInputTokens: groups.fold(0, (sum, g) => sum + g.totalInputTokens),
      totalOutputTokens: groups.fold(0, (sum, g) => sum + g.totalOutputTokens),
      totalTokens: groups.fold(0, (sum, g) => sum + g.totalTokens),
      totalCachedReadTokens: groups.fold(
        0,
        (sum, g) => sum + g.totalCachedReadTokens,
      ),
      totalCostUsd: totalCostUsd,
      // total/count, NOT the mean of the per-group means. The groups are a
      // partition of the same rows, so averaging their means silently weights a
      // 3-run model the same as a 300-run one and reports a number no
      // execution cost.
      avgCostUsd: count > 0 ? totalCostUsd / count : 0.0,
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

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    // The group column as `toColumnMap()` keys it: BARE.
    //
    // `Row.toColumnMap()` keys are column NAMES. `SELECT "role", ...` names the
    // column `role` — the quotes are SQL identifier delimiters and are never
    // part of the name. This method used to hold `'"role"'` and then look up
    // `m['"role"']`, which is null, so `null as String` threw and EVERY grouped
    // call 500'd. The SQL fragment quotes at build time; the Dart map lookup
    // must not.
    //
    // Null means "no grouping". A non-null groupBy that is not a real column is
    // now an explicit ArgumentError naming the supported set, rather than the
    // accidental TypeError it used to be — there was no working behaviour to
    // preserve here, because every such call threw.
    final groupColumn = switch (groupBy) {
      'modelId' => 'modelId',
      'provider' => 'provider',
      'taskType' => 'taskType',
      'role' => 'role',
      null => null,
      _ => throw ArgumentError.value(
        groupBy,
        'groupBy',
        'unsupported grouping; supported: modelId, provider, taskType, role',
      ),
    };

    final groupByClause = groupColumn == null ? '' : 'GROUP BY "$groupColumn"';

    final selectColumns = groupColumn == null ? '' : '"$groupColumn", ';

    final rows = await _db.query(
      // WHY THE FOUR `::bigint` CASTS ON THE TOKEN SUMS
      //
      // `inputTokens`/`outputTokens`/`totalTokens`/`cachedReadTokens` are
      // `bigint`, and PostgreSQL's `SUM(bigint)` returns `numeric` — never
      // `bigint` again. Verified against the QA database:
      //     SELECT pg_typeof(SUM("inputTokens")) FROM "model_execution_record"
      //     -> numeric
      // The postgres driver decodes `numeric` as a String (text codec
      // `asText()`, binary codec `_decodeNumeric`), so `as int?` threw a
      // TypeError on every one of these four columns and `getModelStats`
      // 500'd on every call. Verified: SUM("costUsd") is `double precision` and
      // COUNT(*) is `bigint`, so those two never needed this.
      //
      // The cast is in the SQL rather than a defensive `?? 0` in Dart because
      // `?? 0` cannot see a type error — it would have turned this exception
      // into a confident 0-token report, which is the exact bug class this
      // screen exists to stop.
      //
      // `COALESCE(..., 0)` is not a mask: the ONLY way SUM over these columns is
      // NULL is that no rows matched, and the sum over no rows IS zero. An
      // overflow of int64 raises rather than wrapping, so this cannot silently
      // report a wrong total.
      '''SELECT $selectColumns
            COUNT(*) as "count",
            COALESCE(SUM("inputTokens"), 0)::bigint as "totalInputTokens",
            COALESCE(SUM("outputTokens"), 0)::bigint as "totalOutputTokens",
            COALESCE(SUM("totalTokens"), 0)::bigint as "totalTokens",
            COALESCE(SUM("cachedReadTokens"), 0)::bigint as "totalCachedReadTokens",
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

    if (groupColumn != null) {
      return ModelExecutionStats.byGroup(
        rows.map((r) {
          final m = r.toColumnMap();
          return GroupedModelExecutionStats(
            groupKey: m[groupColumn] as String,
            count: m['count'] as int,
            totalInputTokens: m['totalInputTokens'] as int,
            totalOutputTokens: m['totalOutputTokens'] as int,
            totalTokens: m['totalTokens'] as int,
            totalCachedReadTokens: m['totalCachedReadTokens'] as int,
            totalCostUsd: (m['totalCostUsd'] as num?)?.toDouble() ?? 0.0,
            avgCostUsd: (m['avgCostUsd'] as num?)?.toDouble() ?? 0.0,
            successCount: m['successCount'] as int,
            failureCount: m['failureCount'] as int,
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
      totalInputTokens: m['totalInputTokens'] as int,
      totalOutputTokens: m['totalOutputTokens'] as int,
      totalTokens: m['totalTokens'] as int,
      totalCachedReadTokens: m['totalCachedReadTokens'] as int,
      // `costUsd` is `double precision`, so `SUM`/`AVG` over it are
      // `double precision` too and these arrive as `num` — the `numeric` trap
      // above does not apply to them. NULL here means the row set was empty.
      // For `totalCostUsd` that is a TRUE zero (the sum of no costs is zero).
      // For `avgCostUsd` it is NOT a measurement at all, and the field is
      // non-nullable because `ModelStatsView.avgCostUsd` is; the client is the
      // layer that refuses to display a mean over zero executions
      // (`ModelStatsResponse.avgCostPerExecution`).
      totalCostUsd: (m['totalCostUsd'] as num?)?.toDouble() ?? 0.0,
      avgCostUsd: (m['avgCostUsd'] as num?)?.toDouble() ?? 0.0,
      successCount: m['successCount'] as int,
      failureCount: m['failureCount'] as int,
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

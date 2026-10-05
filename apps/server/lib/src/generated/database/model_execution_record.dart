/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;

abstract class ModelExecutionRecordRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ModelExecutionRecordRow._({
    this.id,
    required this.workItemId,
    required this.jobId,
    required this.agentExecutionId,
    required this.role,
    required this.modelId,
    required this.provider,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.cachedReadTokens,
    required this.costUsd,
    required this.currency,
    required this.startedAt,
    required this.finishedAt,
    required this.success,
    this.error,
    required this.escalationIndex,
    required this.taskType,
  });

  factory ModelExecutionRecordRow({
    int? id,
    required String workItemId,
    required String jobId,
    required String agentExecutionId,
    required String role,
    required String modelId,
    required String provider,
    required int inputTokens,
    required int outputTokens,
    required int totalTokens,
    required int cachedReadTokens,
    required double costUsd,
    required String currency,
    required DateTime startedAt,
    required DateTime finishedAt,
    required bool success,
    String? error,
    required int escalationIndex,
    required String taskType,
  }) = _ModelExecutionRecordRowImpl;

  factory ModelExecutionRecordRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ModelExecutionRecordRow(
      id: jsonSerialization['id'] as int?,
      workItemId: jsonSerialization['workItemId'] as String,
      jobId: jsonSerialization['jobId'] as String,
      agentExecutionId: jsonSerialization['agentExecutionId'] as String,
      role: jsonSerialization['role'] as String,
      modelId: jsonSerialization['modelId'] as String,
      provider: jsonSerialization['provider'] as String,
      inputTokens: jsonSerialization['inputTokens'] as int,
      outputTokens: jsonSerialization['outputTokens'] as int,
      totalTokens: jsonSerialization['totalTokens'] as int,
      cachedReadTokens: jsonSerialization['cachedReadTokens'] as int,
      costUsd: (jsonSerialization['costUsd'] as num).toDouble(),
      currency: jsonSerialization['currency'] as String,
      startedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startedAt'],
      ),
      finishedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['finishedAt'],
      ),
      success: _i1.BoolJsonExtension.fromJson(jsonSerialization['success']),
      error: jsonSerialization['error'] as String?,
      escalationIndex: jsonSerialization['escalationIndex'] as int,
      taskType: jsonSerialization['taskType'] as String,
    );
  }

  static final t = ModelExecutionRecordRowTable();

  static const db = ModelExecutionRecordRowRepository._();

  @override
  int? id;

  String workItemId;

  String jobId;

  String agentExecutionId;

  String role;

  String modelId;

  String provider;

  int inputTokens;

  int outputTokens;

  int totalTokens;

  int cachedReadTokens;

  double costUsd;

  String currency;

  DateTime startedAt;

  DateTime finishedAt;

  bool success;

  String? error;

  int escalationIndex;

  String taskType;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ModelExecutionRecordRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelExecutionRecordRow copyWith({
    int? id,
    String? workItemId,
    String? jobId,
    String? agentExecutionId,
    String? role,
    String? modelId,
    String? provider,
    int? inputTokens,
    int? outputTokens,
    int? totalTokens,
    int? cachedReadTokens,
    double? costUsd,
    String? currency,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? success,
    String? error,
    int? escalationIndex,
    String? taskType,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelExecutionRecordRow',
      if (id != null) 'id': id,
      'workItemId': workItemId,
      'jobId': jobId,
      'agentExecutionId': agentExecutionId,
      'role': role,
      'modelId': modelId,
      'provider': provider,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'totalTokens': totalTokens,
      'cachedReadTokens': cachedReadTokens,
      'costUsd': costUsd,
      'currency': currency,
      'startedAt': startedAt.toJson(),
      'finishedAt': finishedAt.toJson(),
      'success': success,
      if (error != null) 'error': error,
      'escalationIndex': escalationIndex,
      'taskType': taskType,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ModelExecutionRecordRowInclude include() {
    return ModelExecutionRecordRowInclude._();
  }

  static ModelExecutionRecordRowIncludeList includeList({
    _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ModelExecutionRecordRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ModelExecutionRecordRowTable>? orderByList,
    ModelExecutionRecordRowInclude? include,
  }) {
    return ModelExecutionRecordRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ModelExecutionRecordRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ModelExecutionRecordRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ModelExecutionRecordRowImpl extends ModelExecutionRecordRow {
  _ModelExecutionRecordRowImpl({
    int? id,
    required String workItemId,
    required String jobId,
    required String agentExecutionId,
    required String role,
    required String modelId,
    required String provider,
    required int inputTokens,
    required int outputTokens,
    required int totalTokens,
    required int cachedReadTokens,
    required double costUsd,
    required String currency,
    required DateTime startedAt,
    required DateTime finishedAt,
    required bool success,
    String? error,
    required int escalationIndex,
    required String taskType,
  }) : super._(
         id: id,
         workItemId: workItemId,
         jobId: jobId,
         agentExecutionId: agentExecutionId,
         role: role,
         modelId: modelId,
         provider: provider,
         inputTokens: inputTokens,
         outputTokens: outputTokens,
         totalTokens: totalTokens,
         cachedReadTokens: cachedReadTokens,
         costUsd: costUsd,
         currency: currency,
         startedAt: startedAt,
         finishedAt: finishedAt,
         success: success,
         error: error,
         escalationIndex: escalationIndex,
         taskType: taskType,
       );

  /// Returns a shallow copy of this [ModelExecutionRecordRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelExecutionRecordRow copyWith({
    Object? id = _Undefined,
    String? workItemId,
    String? jobId,
    String? agentExecutionId,
    String? role,
    String? modelId,
    String? provider,
    int? inputTokens,
    int? outputTokens,
    int? totalTokens,
    int? cachedReadTokens,
    double? costUsd,
    String? currency,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? success,
    Object? error = _Undefined,
    int? escalationIndex,
    String? taskType,
  }) {
    return ModelExecutionRecordRow(
      id: id is int? ? id : this.id,
      workItemId: workItemId ?? this.workItemId,
      jobId: jobId ?? this.jobId,
      agentExecutionId: agentExecutionId ?? this.agentExecutionId,
      role: role ?? this.role,
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      cachedReadTokens: cachedReadTokens ?? this.cachedReadTokens,
      costUsd: costUsd ?? this.costUsd,
      currency: currency ?? this.currency,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      success: success ?? this.success,
      error: error is String? ? error : this.error,
      escalationIndex: escalationIndex ?? this.escalationIndex,
      taskType: taskType ?? this.taskType,
    );
  }
}

class ModelExecutionRecordRowUpdateTable
    extends _i1.UpdateTable<ModelExecutionRecordRowTable> {
  ModelExecutionRecordRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> jobId(String value) => _i1.ColumnValue(
    table.jobId,
    value,
  );

  _i1.ColumnValue<String, String> agentExecutionId(String value) =>
      _i1.ColumnValue(
        table.agentExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> role(String value) => _i1.ColumnValue(
    table.role,
    value,
  );

  _i1.ColumnValue<String, String> modelId(String value) => _i1.ColumnValue(
    table.modelId,
    value,
  );

  _i1.ColumnValue<String, String> provider(String value) => _i1.ColumnValue(
    table.provider,
    value,
  );

  _i1.ColumnValue<int, int> inputTokens(int value) => _i1.ColumnValue(
    table.inputTokens,
    value,
  );

  _i1.ColumnValue<int, int> outputTokens(int value) => _i1.ColumnValue(
    table.outputTokens,
    value,
  );

  _i1.ColumnValue<int, int> totalTokens(int value) => _i1.ColumnValue(
    table.totalTokens,
    value,
  );

  _i1.ColumnValue<int, int> cachedReadTokens(int value) => _i1.ColumnValue(
    table.cachedReadTokens,
    value,
  );

  _i1.ColumnValue<double, double> costUsd(double value) => _i1.ColumnValue(
    table.costUsd,
    value,
  );

  _i1.ColumnValue<String, String> currency(String value) => _i1.ColumnValue(
    table.currency,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> startedAt(DateTime value) =>
      _i1.ColumnValue(
        table.startedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> finishedAt(DateTime value) =>
      _i1.ColumnValue(
        table.finishedAt,
        value,
      );

  _i1.ColumnValue<bool, bool> success(bool value) => _i1.ColumnValue(
    table.success,
    value,
  );

  _i1.ColumnValue<String, String> error(String? value) => _i1.ColumnValue(
    table.error,
    value,
  );

  _i1.ColumnValue<int, int> escalationIndex(int value) => _i1.ColumnValue(
    table.escalationIndex,
    value,
  );

  _i1.ColumnValue<String, String> taskType(String value) => _i1.ColumnValue(
    table.taskType,
    value,
  );
}

class ModelExecutionRecordRowTable extends _i1.Table<int?> {
  ModelExecutionRecordRowTable({super.tableRelation})
    : super(tableName: 'model_execution_record') {
    updateTable = ModelExecutionRecordRowUpdateTable(this);
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    jobId = _i1.ColumnString(
      'jobId',
      this,
    );
    agentExecutionId = _i1.ColumnString(
      'agentExecutionId',
      this,
    );
    role = _i1.ColumnString(
      'role',
      this,
    );
    modelId = _i1.ColumnString(
      'modelId',
      this,
    );
    provider = _i1.ColumnString(
      'provider',
      this,
    );
    inputTokens = _i1.ColumnInt(
      'inputTokens',
      this,
    );
    outputTokens = _i1.ColumnInt(
      'outputTokens',
      this,
    );
    totalTokens = _i1.ColumnInt(
      'totalTokens',
      this,
    );
    cachedReadTokens = _i1.ColumnInt(
      'cachedReadTokens',
      this,
    );
    costUsd = _i1.ColumnDouble(
      'costUsd',
      this,
    );
    currency = _i1.ColumnString(
      'currency',
      this,
    );
    startedAt = _i1.ColumnDateTime(
      'startedAt',
      this,
    );
    finishedAt = _i1.ColumnDateTime(
      'finishedAt',
      this,
    );
    success = _i1.ColumnBool(
      'success',
      this,
    );
    error = _i1.ColumnString(
      'error',
      this,
    );
    escalationIndex = _i1.ColumnInt(
      'escalationIndex',
      this,
    );
    taskType = _i1.ColumnString(
      'taskType',
      this,
    );
  }

  late final ModelExecutionRecordRowUpdateTable updateTable;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString jobId;

  late final _i1.ColumnString agentExecutionId;

  late final _i1.ColumnString role;

  late final _i1.ColumnString modelId;

  late final _i1.ColumnString provider;

  late final _i1.ColumnInt inputTokens;

  late final _i1.ColumnInt outputTokens;

  late final _i1.ColumnInt totalTokens;

  late final _i1.ColumnInt cachedReadTokens;

  late final _i1.ColumnDouble costUsd;

  late final _i1.ColumnString currency;

  late final _i1.ColumnDateTime startedAt;

  late final _i1.ColumnDateTime finishedAt;

  late final _i1.ColumnBool success;

  late final _i1.ColumnString error;

  late final _i1.ColumnInt escalationIndex;

  late final _i1.ColumnString taskType;

  @override
  List<_i1.Column> get columns => [
    id,
    workItemId,
    jobId,
    agentExecutionId,
    role,
    modelId,
    provider,
    inputTokens,
    outputTokens,
    totalTokens,
    cachedReadTokens,
    costUsd,
    currency,
    startedAt,
    finishedAt,
    success,
    error,
    escalationIndex,
    taskType,
  ];
}

class ModelExecutionRecordRowInclude extends _i1.IncludeObject {
  ModelExecutionRecordRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ModelExecutionRecordRow.t;
}

class ModelExecutionRecordRowIncludeList extends _i1.IncludeList {
  ModelExecutionRecordRowIncludeList._({
    _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ModelExecutionRecordRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ModelExecutionRecordRow.t;
}

class ModelExecutionRecordRowRepository {
  const ModelExecutionRecordRowRepository._();

  /// Returns a list of [ModelExecutionRecordRow]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<ModelExecutionRecordRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ModelExecutionRecordRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ModelExecutionRecordRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ModelExecutionRecordRow>(
      where: where?.call(ModelExecutionRecordRow.t),
      orderBy: orderBy?.call(ModelExecutionRecordRow.t),
      orderByList: orderByList?.call(ModelExecutionRecordRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ModelExecutionRecordRow] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<ModelExecutionRecordRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<ModelExecutionRecordRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ModelExecutionRecordRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ModelExecutionRecordRow>(
      where: where?.call(ModelExecutionRecordRow.t),
      orderBy: orderBy?.call(ModelExecutionRecordRow.t),
      orderByList: orderByList?.call(ModelExecutionRecordRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ModelExecutionRecordRow] by its [id] or null if no such row exists.
  Future<ModelExecutionRecordRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ModelExecutionRecordRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ModelExecutionRecordRow]s in the list and returns the inserted rows.
  ///
  /// The returned [ModelExecutionRecordRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ModelExecutionRecordRow>> insert(
    _i1.DatabaseSession session,
    List<ModelExecutionRecordRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ModelExecutionRecordRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ModelExecutionRecordRow] and returns the inserted row.
  ///
  /// The returned [ModelExecutionRecordRow] will have its `id` field set.
  Future<ModelExecutionRecordRow> insertRow(
    _i1.DatabaseSession session,
    ModelExecutionRecordRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ModelExecutionRecordRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ModelExecutionRecordRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ModelExecutionRecordRow>> update(
    _i1.DatabaseSession session,
    List<ModelExecutionRecordRow> rows, {
    _i1.ColumnSelections<ModelExecutionRecordRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ModelExecutionRecordRow>(
      rows,
      columns: columns?.call(ModelExecutionRecordRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ModelExecutionRecordRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ModelExecutionRecordRow> updateRow(
    _i1.DatabaseSession session,
    ModelExecutionRecordRow row, {
    _i1.ColumnSelections<ModelExecutionRecordRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ModelExecutionRecordRow>(
      row,
      columns: columns?.call(ModelExecutionRecordRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ModelExecutionRecordRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ModelExecutionRecordRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ModelExecutionRecordRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ModelExecutionRecordRow>(
      id,
      columnValues: columnValues(ModelExecutionRecordRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ModelExecutionRecordRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ModelExecutionRecordRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ModelExecutionRecordRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ModelExecutionRecordRowTable>? orderBy,
    _i1.OrderByListBuilder<ModelExecutionRecordRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ModelExecutionRecordRow>(
      columnValues: columnValues(ModelExecutionRecordRow.t.updateTable),
      where: where(ModelExecutionRecordRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ModelExecutionRecordRow.t),
      orderByList: orderByList?.call(ModelExecutionRecordRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ModelExecutionRecordRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ModelExecutionRecordRow>> delete(
    _i1.DatabaseSession session,
    List<ModelExecutionRecordRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ModelExecutionRecordRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ModelExecutionRecordRow].
  Future<ModelExecutionRecordRow> deleteRow(
    _i1.DatabaseSession session,
    ModelExecutionRecordRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ModelExecutionRecordRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ModelExecutionRecordRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ModelExecutionRecordRow>(
      where: where(ModelExecutionRecordRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ModelExecutionRecordRow>(
      where: where?.call(ModelExecutionRecordRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ModelExecutionRecordRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ModelExecutionRecordRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ModelExecutionRecordRow>(
      where: where(ModelExecutionRecordRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

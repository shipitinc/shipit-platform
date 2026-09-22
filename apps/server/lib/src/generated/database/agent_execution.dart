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

abstract class AgentExecutionRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  AgentExecutionRow._({
    this.id,
    required this.executionId,
    required this.workItemId,
    required this.requestId,
    required this.runtimeTypeId,
    required this.role,
    required this.status,
    required this.workspaceJson,
    this.sessionId,
    this.resultId,
    this.startedAt,
    this.completedAt,
    this.reason,
    this.metadataJson,
    required this.version,
  });

  factory AgentExecutionRow({
    int? id,
    required String executionId,
    required String workItemId,
    required String requestId,
    required String runtimeTypeId,
    required String role,
    required String status,
    required String workspaceJson,
    String? sessionId,
    String? resultId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? reason,
    String? metadataJson,
    required int version,
  }) = _AgentExecutionRowImpl;

  factory AgentExecutionRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentExecutionRow(
      id: jsonSerialization['id'] as int?,
      executionId: jsonSerialization['executionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      requestId: jsonSerialization['requestId'] as String,
      runtimeTypeId: jsonSerialization['runtimeTypeId'] as String,
      role: jsonSerialization['role'] as String,
      status: jsonSerialization['status'] as String,
      workspaceJson: jsonSerialization['workspaceJson'] as String,
      sessionId: jsonSerialization['sessionId'] as String?,
      resultId: jsonSerialization['resultId'] as String?,
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      reason: jsonSerialization['reason'] as String?,
      metadataJson: jsonSerialization['metadataJson'] as String?,
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = AgentExecutionRowTable();

  static const db = AgentExecutionRowRepository._();

  @override
  int? id;

  String executionId;

  String workItemId;

  String requestId;

  String runtimeTypeId;

  String role;

  String status;

  String workspaceJson;

  String? sessionId;

  String? resultId;

  DateTime? startedAt;

  DateTime? completedAt;

  String? reason;

  String? metadataJson;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [AgentExecutionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentExecutionRow copyWith({
    int? id,
    String? executionId,
    String? workItemId,
    String? requestId,
    String? runtimeTypeId,
    String? role,
    String? status,
    String? workspaceJson,
    String? sessionId,
    String? resultId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? reason,
    String? metadataJson,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentExecutionRow',
      if (id != null) 'id': id,
      'executionId': executionId,
      'workItemId': workItemId,
      'requestId': requestId,
      'runtimeTypeId': runtimeTypeId,
      'role': role,
      'status': status,
      'workspaceJson': workspaceJson,
      if (sessionId != null) 'sessionId': sessionId,
      if (resultId != null) 'resultId': resultId,
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (reason != null) 'reason': reason,
      if (metadataJson != null) 'metadataJson': metadataJson,
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AgentExecutionRowInclude include() {
    return AgentExecutionRowInclude._();
  }

  static AgentExecutionRowIncludeList includeList({
    _i1.WhereExpressionBuilder<AgentExecutionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentExecutionRowTable>? orderByList,
    AgentExecutionRowInclude? include,
  }) {
    return AgentExecutionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentExecutionRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(AgentExecutionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentExecutionRowImpl extends AgentExecutionRow {
  _AgentExecutionRowImpl({
    int? id,
    required String executionId,
    required String workItemId,
    required String requestId,
    required String runtimeTypeId,
    required String role,
    required String status,
    required String workspaceJson,
    String? sessionId,
    String? resultId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? reason,
    String? metadataJson,
    required int version,
  }) : super._(
         id: id,
         executionId: executionId,
         workItemId: workItemId,
         requestId: requestId,
         runtimeTypeId: runtimeTypeId,
         role: role,
         status: status,
         workspaceJson: workspaceJson,
         sessionId: sessionId,
         resultId: resultId,
         startedAt: startedAt,
         completedAt: completedAt,
         reason: reason,
         metadataJson: metadataJson,
         version: version,
       );

  /// Returns a shallow copy of this [AgentExecutionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentExecutionRow copyWith({
    Object? id = _Undefined,
    String? executionId,
    String? workItemId,
    String? requestId,
    String? runtimeTypeId,
    String? role,
    String? status,
    String? workspaceJson,
    Object? sessionId = _Undefined,
    Object? resultId = _Undefined,
    Object? startedAt = _Undefined,
    Object? completedAt = _Undefined,
    Object? reason = _Undefined,
    Object? metadataJson = _Undefined,
    int? version,
  }) {
    return AgentExecutionRow(
      id: id is int? ? id : this.id,
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      requestId: requestId ?? this.requestId,
      runtimeTypeId: runtimeTypeId ?? this.runtimeTypeId,
      role: role ?? this.role,
      status: status ?? this.status,
      workspaceJson: workspaceJson ?? this.workspaceJson,
      sessionId: sessionId is String? ? sessionId : this.sessionId,
      resultId: resultId is String? ? resultId : this.resultId,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      reason: reason is String? ? reason : this.reason,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
      version: version ?? this.version,
    );
  }
}

class AgentExecutionRowUpdateTable
    extends _i1.UpdateTable<AgentExecutionRowTable> {
  AgentExecutionRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> executionId(String value) => _i1.ColumnValue(
    table.executionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> requestId(String value) => _i1.ColumnValue(
    table.requestId,
    value,
  );

  _i1.ColumnValue<String, String> runtimeTypeId(String value) =>
      _i1.ColumnValue(
        table.runtimeTypeId,
        value,
      );

  _i1.ColumnValue<String, String> role(String value) => _i1.ColumnValue(
    table.role,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> workspaceJson(String value) =>
      _i1.ColumnValue(
        table.workspaceJson,
        value,
      );

  _i1.ColumnValue<String, String> sessionId(String? value) => _i1.ColumnValue(
    table.sessionId,
    value,
  );

  _i1.ColumnValue<String, String> resultId(String? value) => _i1.ColumnValue(
    table.resultId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> startedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.startedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.completedAt,
        value,
      );

  _i1.ColumnValue<String, String> reason(String? value) => _i1.ColumnValue(
    table.reason,
    value,
  );

  _i1.ColumnValue<String, String> metadataJson(String? value) =>
      _i1.ColumnValue(
        table.metadataJson,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class AgentExecutionRowTable extends _i1.Table<int?> {
  AgentExecutionRowTable({super.tableRelation})
    : super(tableName: 'agent_execution') {
    updateTable = AgentExecutionRowUpdateTable(this);
    executionId = _i1.ColumnString(
      'executionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    requestId = _i1.ColumnString(
      'requestId',
      this,
    );
    runtimeTypeId = _i1.ColumnString(
      'runtimeTypeId',
      this,
    );
    role = _i1.ColumnString(
      'role',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    workspaceJson = _i1.ColumnString(
      'workspaceJson',
      this,
    );
    sessionId = _i1.ColumnString(
      'sessionId',
      this,
    );
    resultId = _i1.ColumnString(
      'resultId',
      this,
    );
    startedAt = _i1.ColumnDateTime(
      'startedAt',
      this,
    );
    completedAt = _i1.ColumnDateTime(
      'completedAt',
      this,
    );
    reason = _i1.ColumnString(
      'reason',
      this,
    );
    metadataJson = _i1.ColumnString(
      'metadataJson',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final AgentExecutionRowUpdateTable updateTable;

  late final _i1.ColumnString executionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString requestId;

  late final _i1.ColumnString runtimeTypeId;

  late final _i1.ColumnString role;

  late final _i1.ColumnString status;

  late final _i1.ColumnString workspaceJson;

  late final _i1.ColumnString sessionId;

  late final _i1.ColumnString resultId;

  late final _i1.ColumnDateTime startedAt;

  late final _i1.ColumnDateTime completedAt;

  late final _i1.ColumnString reason;

  late final _i1.ColumnString metadataJson;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    executionId,
    workItemId,
    requestId,
    runtimeTypeId,
    role,
    status,
    workspaceJson,
    sessionId,
    resultId,
    startedAt,
    completedAt,
    reason,
    metadataJson,
    version,
  ];
}

class AgentExecutionRowInclude extends _i1.IncludeObject {
  AgentExecutionRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => AgentExecutionRow.t;
}

class AgentExecutionRowIncludeList extends _i1.IncludeList {
  AgentExecutionRowIncludeList._({
    _i1.WhereExpressionBuilder<AgentExecutionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AgentExecutionRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => AgentExecutionRow.t;
}

class AgentExecutionRowRepository {
  const AgentExecutionRowRepository._();

  /// Returns a list of [AgentExecutionRow]s matching the given query parameters.
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
  Future<List<AgentExecutionRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentExecutionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentExecutionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AgentExecutionRow>(
      where: where?.call(AgentExecutionRow.t),
      orderBy: orderBy?.call(AgentExecutionRow.t),
      orderByList: orderByList?.call(AgentExecutionRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AgentExecutionRow] matching the given query parameters.
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
  Future<AgentExecutionRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentExecutionRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentExecutionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AgentExecutionRow>(
      where: where?.call(AgentExecutionRow.t),
      orderBy: orderBy?.call(AgentExecutionRow.t),
      orderByList: orderByList?.call(AgentExecutionRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AgentExecutionRow] by its [id] or null if no such row exists.
  Future<AgentExecutionRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AgentExecutionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AgentExecutionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [AgentExecutionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<AgentExecutionRow>> insert(
    _i1.DatabaseSession session,
    List<AgentExecutionRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<AgentExecutionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [AgentExecutionRow] and returns the inserted row.
  ///
  /// The returned [AgentExecutionRow] will have its `id` field set.
  Future<AgentExecutionRow> insertRow(
    _i1.DatabaseSession session,
    AgentExecutionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<AgentExecutionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [AgentExecutionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<AgentExecutionRow>> update(
    _i1.DatabaseSession session,
    List<AgentExecutionRow> rows, {
    _i1.ColumnSelections<AgentExecutionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<AgentExecutionRow>(
      rows,
      columns: columns?.call(AgentExecutionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentExecutionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AgentExecutionRow> updateRow(
    _i1.DatabaseSession session,
    AgentExecutionRow row, {
    _i1.ColumnSelections<AgentExecutionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<AgentExecutionRow>(
      row,
      columns: columns?.call(AgentExecutionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentExecutionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AgentExecutionRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<AgentExecutionRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<AgentExecutionRow>(
      id,
      columnValues: columnValues(AgentExecutionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AgentExecutionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<AgentExecutionRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<AgentExecutionRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<AgentExecutionRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRowTable>? orderBy,
    _i1.OrderByListBuilder<AgentExecutionRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<AgentExecutionRow>(
      columnValues: columnValues(AgentExecutionRow.t.updateTable),
      where: where(AgentExecutionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentExecutionRow.t),
      orderByList: orderByList?.call(AgentExecutionRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [AgentExecutionRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<AgentExecutionRow>> delete(
    _i1.DatabaseSession session,
    List<AgentExecutionRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<AgentExecutionRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [AgentExecutionRow].
  Future<AgentExecutionRow> deleteRow(
    _i1.DatabaseSession session,
    AgentExecutionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AgentExecutionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<AgentExecutionRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentExecutionRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<AgentExecutionRow>(
      where: where(AgentExecutionRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentExecutionRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<AgentExecutionRow>(
      where: where?.call(AgentExecutionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AgentExecutionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentExecutionRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AgentExecutionRow>(
      where: where(AgentExecutionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

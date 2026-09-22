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

abstract class AgentResultRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  AgentResultRow._({
    this.id,
    required this.resultId,
    required this.sessionId,
    required this.workItemId,
    required this.status,
    required this.artifactsJson,
    required this.diagnosticsJson,
    required this.structuredResultJson,
    this.executionId,
    this.role,
    this.changedFilesJson,
    this.claimedChecksJson,
    this.summary,
    required this.completedAt,
    this.metadataJson,
  });

  factory AgentResultRow({
    int? id,
    required String resultId,
    required String sessionId,
    required String workItemId,
    required String status,
    required String artifactsJson,
    required String diagnosticsJson,
    required String structuredResultJson,
    String? executionId,
    String? role,
    String? changedFilesJson,
    String? claimedChecksJson,
    String? summary,
    required DateTime completedAt,
    String? metadataJson,
  }) = _AgentResultRowImpl;

  factory AgentResultRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentResultRow(
      id: jsonSerialization['id'] as int?,
      resultId: jsonSerialization['resultId'] as String,
      sessionId: jsonSerialization['sessionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      status: jsonSerialization['status'] as String,
      artifactsJson: jsonSerialization['artifactsJson'] as String,
      diagnosticsJson: jsonSerialization['diagnosticsJson'] as String,
      structuredResultJson: jsonSerialization['structuredResultJson'] as String,
      executionId: jsonSerialization['executionId'] as String?,
      role: jsonSerialization['role'] as String?,
      changedFilesJson: jsonSerialization['changedFilesJson'] as String?,
      claimedChecksJson: jsonSerialization['claimedChecksJson'] as String?,
      summary: jsonSerialization['summary'] as String?,
      completedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['completedAt'],
      ),
      metadataJson: jsonSerialization['metadataJson'] as String?,
    );
  }

  static final t = AgentResultRowTable();

  static const db = AgentResultRowRepository._();

  @override
  int? id;

  String resultId;

  String sessionId;

  String workItemId;

  String status;

  String artifactsJson;

  String diagnosticsJson;

  String structuredResultJson;

  String? executionId;

  String? role;

  String? changedFilesJson;

  String? claimedChecksJson;

  String? summary;

  DateTime completedAt;

  String? metadataJson;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [AgentResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentResultRow copyWith({
    int? id,
    String? resultId,
    String? sessionId,
    String? workItemId,
    String? status,
    String? artifactsJson,
    String? diagnosticsJson,
    String? structuredResultJson,
    String? executionId,
    String? role,
    String? changedFilesJson,
    String? claimedChecksJson,
    String? summary,
    DateTime? completedAt,
    String? metadataJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentResultRow',
      if (id != null) 'id': id,
      'resultId': resultId,
      'sessionId': sessionId,
      'workItemId': workItemId,
      'status': status,
      'artifactsJson': artifactsJson,
      'diagnosticsJson': diagnosticsJson,
      'structuredResultJson': structuredResultJson,
      if (executionId != null) 'executionId': executionId,
      if (role != null) 'role': role,
      if (changedFilesJson != null) 'changedFilesJson': changedFilesJson,
      if (claimedChecksJson != null) 'claimedChecksJson': claimedChecksJson,
      if (summary != null) 'summary': summary,
      'completedAt': completedAt.toJson(),
      if (metadataJson != null) 'metadataJson': metadataJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AgentResultRowInclude include() {
    return AgentResultRowInclude._();
  }

  static AgentResultRowIncludeList includeList({
    _i1.WhereExpressionBuilder<AgentResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentResultRowTable>? orderByList,
    AgentResultRowInclude? include,
  }) {
    return AgentResultRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentResultRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(AgentResultRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentResultRowImpl extends AgentResultRow {
  _AgentResultRowImpl({
    int? id,
    required String resultId,
    required String sessionId,
    required String workItemId,
    required String status,
    required String artifactsJson,
    required String diagnosticsJson,
    required String structuredResultJson,
    String? executionId,
    String? role,
    String? changedFilesJson,
    String? claimedChecksJson,
    String? summary,
    required DateTime completedAt,
    String? metadataJson,
  }) : super._(
         id: id,
         resultId: resultId,
         sessionId: sessionId,
         workItemId: workItemId,
         status: status,
         artifactsJson: artifactsJson,
         diagnosticsJson: diagnosticsJson,
         structuredResultJson: structuredResultJson,
         executionId: executionId,
         role: role,
         changedFilesJson: changedFilesJson,
         claimedChecksJson: claimedChecksJson,
         summary: summary,
         completedAt: completedAt,
         metadataJson: metadataJson,
       );

  /// Returns a shallow copy of this [AgentResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentResultRow copyWith({
    Object? id = _Undefined,
    String? resultId,
    String? sessionId,
    String? workItemId,
    String? status,
    String? artifactsJson,
    String? diagnosticsJson,
    String? structuredResultJson,
    Object? executionId = _Undefined,
    Object? role = _Undefined,
    Object? changedFilesJson = _Undefined,
    Object? claimedChecksJson = _Undefined,
    Object? summary = _Undefined,
    DateTime? completedAt,
    Object? metadataJson = _Undefined,
  }) {
    return AgentResultRow(
      id: id is int? ? id : this.id,
      resultId: resultId ?? this.resultId,
      sessionId: sessionId ?? this.sessionId,
      workItemId: workItemId ?? this.workItemId,
      status: status ?? this.status,
      artifactsJson: artifactsJson ?? this.artifactsJson,
      diagnosticsJson: diagnosticsJson ?? this.diagnosticsJson,
      structuredResultJson: structuredResultJson ?? this.structuredResultJson,
      executionId: executionId is String? ? executionId : this.executionId,
      role: role is String? ? role : this.role,
      changedFilesJson: changedFilesJson is String?
          ? changedFilesJson
          : this.changedFilesJson,
      claimedChecksJson: claimedChecksJson is String?
          ? claimedChecksJson
          : this.claimedChecksJson,
      summary: summary is String? ? summary : this.summary,
      completedAt: completedAt ?? this.completedAt,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
    );
  }
}

class AgentResultRowUpdateTable extends _i1.UpdateTable<AgentResultRowTable> {
  AgentResultRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> resultId(String value) => _i1.ColumnValue(
    table.resultId,
    value,
  );

  _i1.ColumnValue<String, String> sessionId(String value) => _i1.ColumnValue(
    table.sessionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> artifactsJson(String value) =>
      _i1.ColumnValue(
        table.artifactsJson,
        value,
      );

  _i1.ColumnValue<String, String> diagnosticsJson(String value) =>
      _i1.ColumnValue(
        table.diagnosticsJson,
        value,
      );

  _i1.ColumnValue<String, String> structuredResultJson(String value) =>
      _i1.ColumnValue(
        table.structuredResultJson,
        value,
      );

  _i1.ColumnValue<String, String> executionId(String? value) => _i1.ColumnValue(
    table.executionId,
    value,
  );

  _i1.ColumnValue<String, String> role(String? value) => _i1.ColumnValue(
    table.role,
    value,
  );

  _i1.ColumnValue<String, String> changedFilesJson(String? value) =>
      _i1.ColumnValue(
        table.changedFilesJson,
        value,
      );

  _i1.ColumnValue<String, String> claimedChecksJson(String? value) =>
      _i1.ColumnValue(
        table.claimedChecksJson,
        value,
      );

  _i1.ColumnValue<String, String> summary(String? value) => _i1.ColumnValue(
    table.summary,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> completedAt(DateTime value) =>
      _i1.ColumnValue(
        table.completedAt,
        value,
      );

  _i1.ColumnValue<String, String> metadataJson(String? value) =>
      _i1.ColumnValue(
        table.metadataJson,
        value,
      );
}

class AgentResultRowTable extends _i1.Table<int?> {
  AgentResultRowTable({super.tableRelation})
    : super(tableName: 'agent_result') {
    updateTable = AgentResultRowUpdateTable(this);
    resultId = _i1.ColumnString(
      'resultId',
      this,
    );
    sessionId = _i1.ColumnString(
      'sessionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    artifactsJson = _i1.ColumnString(
      'artifactsJson',
      this,
    );
    diagnosticsJson = _i1.ColumnString(
      'diagnosticsJson',
      this,
    );
    structuredResultJson = _i1.ColumnString(
      'structuredResultJson',
      this,
    );
    executionId = _i1.ColumnString(
      'executionId',
      this,
    );
    role = _i1.ColumnString(
      'role',
      this,
    );
    changedFilesJson = _i1.ColumnString(
      'changedFilesJson',
      this,
    );
    claimedChecksJson = _i1.ColumnString(
      'claimedChecksJson',
      this,
    );
    summary = _i1.ColumnString(
      'summary',
      this,
    );
    completedAt = _i1.ColumnDateTime(
      'completedAt',
      this,
    );
    metadataJson = _i1.ColumnString(
      'metadataJson',
      this,
    );
  }

  late final AgentResultRowUpdateTable updateTable;

  late final _i1.ColumnString resultId;

  late final _i1.ColumnString sessionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString status;

  late final _i1.ColumnString artifactsJson;

  late final _i1.ColumnString diagnosticsJson;

  late final _i1.ColumnString structuredResultJson;

  late final _i1.ColumnString executionId;

  late final _i1.ColumnString role;

  late final _i1.ColumnString changedFilesJson;

  late final _i1.ColumnString claimedChecksJson;

  late final _i1.ColumnString summary;

  late final _i1.ColumnDateTime completedAt;

  late final _i1.ColumnString metadataJson;

  @override
  List<_i1.Column> get columns => [
    id,
    resultId,
    sessionId,
    workItemId,
    status,
    artifactsJson,
    diagnosticsJson,
    structuredResultJson,
    executionId,
    role,
    changedFilesJson,
    claimedChecksJson,
    summary,
    completedAt,
    metadataJson,
  ];
}

class AgentResultRowInclude extends _i1.IncludeObject {
  AgentResultRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => AgentResultRow.t;
}

class AgentResultRowIncludeList extends _i1.IncludeList {
  AgentResultRowIncludeList._({
    _i1.WhereExpressionBuilder<AgentResultRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AgentResultRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => AgentResultRow.t;
}

class AgentResultRowRepository {
  const AgentResultRowRepository._();

  /// Returns a list of [AgentResultRow]s matching the given query parameters.
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
  Future<List<AgentResultRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AgentResultRow>(
      where: where?.call(AgentResultRow.t),
      orderBy: orderBy?.call(AgentResultRow.t),
      orderByList: orderByList?.call(AgentResultRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AgentResultRow] matching the given query parameters.
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
  Future<AgentResultRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentResultRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<AgentResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AgentResultRow>(
      where: where?.call(AgentResultRow.t),
      orderBy: orderBy?.call(AgentResultRow.t),
      orderByList: orderByList?.call(AgentResultRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AgentResultRow] by its [id] or null if no such row exists.
  Future<AgentResultRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AgentResultRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AgentResultRow]s in the list and returns the inserted rows.
  ///
  /// The returned [AgentResultRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<AgentResultRow>> insert(
    _i1.DatabaseSession session,
    List<AgentResultRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<AgentResultRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [AgentResultRow] and returns the inserted row.
  ///
  /// The returned [AgentResultRow] will have its `id` field set.
  Future<AgentResultRow> insertRow(
    _i1.DatabaseSession session,
    AgentResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<AgentResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [AgentResultRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<AgentResultRow>> update(
    _i1.DatabaseSession session,
    List<AgentResultRow> rows, {
    _i1.ColumnSelections<AgentResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<AgentResultRow>(
      rows,
      columns: columns?.call(AgentResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentResultRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AgentResultRow> updateRow(
    _i1.DatabaseSession session,
    AgentResultRow row, {
    _i1.ColumnSelections<AgentResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<AgentResultRow>(
      row,
      columns: columns?.call(AgentResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentResultRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AgentResultRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<AgentResultRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<AgentResultRow>(
      id,
      columnValues: columnValues(AgentResultRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AgentResultRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<AgentResultRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<AgentResultRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<AgentResultRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentResultRowTable>? orderBy,
    _i1.OrderByListBuilder<AgentResultRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<AgentResultRow>(
      columnValues: columnValues(AgentResultRow.t.updateTable),
      where: where(AgentResultRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentResultRow.t),
      orderByList: orderByList?.call(AgentResultRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [AgentResultRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<AgentResultRow>> delete(
    _i1.DatabaseSession session,
    List<AgentResultRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<AgentResultRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [AgentResultRow].
  Future<AgentResultRow> deleteRow(
    _i1.DatabaseSession session,
    AgentResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AgentResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<AgentResultRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentResultRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<AgentResultRow>(
      where: where(AgentResultRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentResultRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<AgentResultRow>(
      where: where?.call(AgentResultRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AgentResultRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentResultRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AgentResultRow>(
      where: where(AgentResultRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

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

abstract class AgentExecutionRequestRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  AgentExecutionRequestRow._({
    this.id,
    required this.executionId,
    required this.workItemId,
    required this.role,
    required this.runtimeTypeId,
    required this.workspaceJson,
    required this.instruction,
    required this.timeoutSeconds,
    this.permittedScope,
    this.expectedResultJson,
    required this.expectedArtifactsJson,
    this.runtimeConfigJson,
    this.environmentJson,
    required this.createdAt,
  });

  factory AgentExecutionRequestRow({
    int? id,
    required String executionId,
    required String workItemId,
    required String role,
    required String runtimeTypeId,
    required String workspaceJson,
    required String instruction,
    required int timeoutSeconds,
    String? permittedScope,
    String? expectedResultJson,
    required String expectedArtifactsJson,
    String? runtimeConfigJson,
    String? environmentJson,
    required DateTime createdAt,
  }) = _AgentExecutionRequestRowImpl;

  factory AgentExecutionRequestRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AgentExecutionRequestRow(
      id: jsonSerialization['id'] as int?,
      executionId: jsonSerialization['executionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      role: jsonSerialization['role'] as String,
      runtimeTypeId: jsonSerialization['runtimeTypeId'] as String,
      workspaceJson: jsonSerialization['workspaceJson'] as String,
      instruction: jsonSerialization['instruction'] as String,
      timeoutSeconds: jsonSerialization['timeoutSeconds'] as int,
      permittedScope: jsonSerialization['permittedScope'] as String?,
      expectedResultJson: jsonSerialization['expectedResultJson'] as String?,
      expectedArtifactsJson:
          jsonSerialization['expectedArtifactsJson'] as String,
      runtimeConfigJson: jsonSerialization['runtimeConfigJson'] as String?,
      environmentJson: jsonSerialization['environmentJson'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = AgentExecutionRequestRowTable();

  static const db = AgentExecutionRequestRowRepository._();

  @override
  int? id;

  String executionId;

  String workItemId;

  String role;

  String runtimeTypeId;

  String workspaceJson;

  String instruction;

  int timeoutSeconds;

  String? permittedScope;

  String? expectedResultJson;

  String expectedArtifactsJson;

  String? runtimeConfigJson;

  String? environmentJson;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [AgentExecutionRequestRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentExecutionRequestRow copyWith({
    int? id,
    String? executionId,
    String? workItemId,
    String? role,
    String? runtimeTypeId,
    String? workspaceJson,
    String? instruction,
    int? timeoutSeconds,
    String? permittedScope,
    String? expectedResultJson,
    String? expectedArtifactsJson,
    String? runtimeConfigJson,
    String? environmentJson,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentExecutionRequestRow',
      if (id != null) 'id': id,
      'executionId': executionId,
      'workItemId': workItemId,
      'role': role,
      'runtimeTypeId': runtimeTypeId,
      'workspaceJson': workspaceJson,
      'instruction': instruction,
      'timeoutSeconds': timeoutSeconds,
      if (permittedScope != null) 'permittedScope': permittedScope,
      if (expectedResultJson != null) 'expectedResultJson': expectedResultJson,
      'expectedArtifactsJson': expectedArtifactsJson,
      if (runtimeConfigJson != null) 'runtimeConfigJson': runtimeConfigJson,
      if (environmentJson != null) 'environmentJson': environmentJson,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AgentExecutionRequestRowInclude include() {
    return AgentExecutionRequestRowInclude._();
  }

  static AgentExecutionRequestRowIncludeList includeList({
    _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRequestRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentExecutionRequestRowTable>? orderByList,
    AgentExecutionRequestRowInclude? include,
  }) {
    return AgentExecutionRequestRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentExecutionRequestRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(AgentExecutionRequestRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentExecutionRequestRowImpl extends AgentExecutionRequestRow {
  _AgentExecutionRequestRowImpl({
    int? id,
    required String executionId,
    required String workItemId,
    required String role,
    required String runtimeTypeId,
    required String workspaceJson,
    required String instruction,
    required int timeoutSeconds,
    String? permittedScope,
    String? expectedResultJson,
    required String expectedArtifactsJson,
    String? runtimeConfigJson,
    String? environmentJson,
    required DateTime createdAt,
  }) : super._(
         id: id,
         executionId: executionId,
         workItemId: workItemId,
         role: role,
         runtimeTypeId: runtimeTypeId,
         workspaceJson: workspaceJson,
         instruction: instruction,
         timeoutSeconds: timeoutSeconds,
         permittedScope: permittedScope,
         expectedResultJson: expectedResultJson,
         expectedArtifactsJson: expectedArtifactsJson,
         runtimeConfigJson: runtimeConfigJson,
         environmentJson: environmentJson,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [AgentExecutionRequestRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentExecutionRequestRow copyWith({
    Object? id = _Undefined,
    String? executionId,
    String? workItemId,
    String? role,
    String? runtimeTypeId,
    String? workspaceJson,
    String? instruction,
    int? timeoutSeconds,
    Object? permittedScope = _Undefined,
    Object? expectedResultJson = _Undefined,
    String? expectedArtifactsJson,
    Object? runtimeConfigJson = _Undefined,
    Object? environmentJson = _Undefined,
    DateTime? createdAt,
  }) {
    return AgentExecutionRequestRow(
      id: id is int? ? id : this.id,
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      role: role ?? this.role,
      runtimeTypeId: runtimeTypeId ?? this.runtimeTypeId,
      workspaceJson: workspaceJson ?? this.workspaceJson,
      instruction: instruction ?? this.instruction,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      permittedScope: permittedScope is String?
          ? permittedScope
          : this.permittedScope,
      expectedResultJson: expectedResultJson is String?
          ? expectedResultJson
          : this.expectedResultJson,
      expectedArtifactsJson:
          expectedArtifactsJson ?? this.expectedArtifactsJson,
      runtimeConfigJson: runtimeConfigJson is String?
          ? runtimeConfigJson
          : this.runtimeConfigJson,
      environmentJson: environmentJson is String?
          ? environmentJson
          : this.environmentJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AgentExecutionRequestRowUpdateTable
    extends _i1.UpdateTable<AgentExecutionRequestRowTable> {
  AgentExecutionRequestRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> executionId(String value) => _i1.ColumnValue(
    table.executionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> role(String value) => _i1.ColumnValue(
    table.role,
    value,
  );

  _i1.ColumnValue<String, String> runtimeTypeId(String value) =>
      _i1.ColumnValue(
        table.runtimeTypeId,
        value,
      );

  _i1.ColumnValue<String, String> workspaceJson(String value) =>
      _i1.ColumnValue(
        table.workspaceJson,
        value,
      );

  _i1.ColumnValue<String, String> instruction(String value) => _i1.ColumnValue(
    table.instruction,
    value,
  );

  _i1.ColumnValue<int, int> timeoutSeconds(int value) => _i1.ColumnValue(
    table.timeoutSeconds,
    value,
  );

  _i1.ColumnValue<String, String> permittedScope(String? value) =>
      _i1.ColumnValue(
        table.permittedScope,
        value,
      );

  _i1.ColumnValue<String, String> expectedResultJson(String? value) =>
      _i1.ColumnValue(
        table.expectedResultJson,
        value,
      );

  _i1.ColumnValue<String, String> expectedArtifactsJson(String value) =>
      _i1.ColumnValue(
        table.expectedArtifactsJson,
        value,
      );

  _i1.ColumnValue<String, String> runtimeConfigJson(String? value) =>
      _i1.ColumnValue(
        table.runtimeConfigJson,
        value,
      );

  _i1.ColumnValue<String, String> environmentJson(String? value) =>
      _i1.ColumnValue(
        table.environmentJson,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class AgentExecutionRequestRowTable extends _i1.Table<int?> {
  AgentExecutionRequestRowTable({super.tableRelation})
    : super(tableName: 'agent_execution_request') {
    updateTable = AgentExecutionRequestRowUpdateTable(this);
    executionId = _i1.ColumnString(
      'executionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    role = _i1.ColumnString(
      'role',
      this,
    );
    runtimeTypeId = _i1.ColumnString(
      'runtimeTypeId',
      this,
    );
    workspaceJson = _i1.ColumnString(
      'workspaceJson',
      this,
    );
    instruction = _i1.ColumnString(
      'instruction',
      this,
    );
    timeoutSeconds = _i1.ColumnInt(
      'timeoutSeconds',
      this,
    );
    permittedScope = _i1.ColumnString(
      'permittedScope',
      this,
    );
    expectedResultJson = _i1.ColumnString(
      'expectedResultJson',
      this,
    );
    expectedArtifactsJson = _i1.ColumnString(
      'expectedArtifactsJson',
      this,
    );
    runtimeConfigJson = _i1.ColumnString(
      'runtimeConfigJson',
      this,
    );
    environmentJson = _i1.ColumnString(
      'environmentJson',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final AgentExecutionRequestRowUpdateTable updateTable;

  late final _i1.ColumnString executionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString role;

  late final _i1.ColumnString runtimeTypeId;

  late final _i1.ColumnString workspaceJson;

  late final _i1.ColumnString instruction;

  late final _i1.ColumnInt timeoutSeconds;

  late final _i1.ColumnString permittedScope;

  late final _i1.ColumnString expectedResultJson;

  late final _i1.ColumnString expectedArtifactsJson;

  late final _i1.ColumnString runtimeConfigJson;

  late final _i1.ColumnString environmentJson;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    executionId,
    workItemId,
    role,
    runtimeTypeId,
    workspaceJson,
    instruction,
    timeoutSeconds,
    permittedScope,
    expectedResultJson,
    expectedArtifactsJson,
    runtimeConfigJson,
    environmentJson,
    createdAt,
  ];
}

class AgentExecutionRequestRowInclude extends _i1.IncludeObject {
  AgentExecutionRequestRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => AgentExecutionRequestRow.t;
}

class AgentExecutionRequestRowIncludeList extends _i1.IncludeList {
  AgentExecutionRequestRowIncludeList._({
    _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AgentExecutionRequestRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => AgentExecutionRequestRow.t;
}

class AgentExecutionRequestRowRepository {
  const AgentExecutionRequestRowRepository._();

  /// Returns a list of [AgentExecutionRequestRow]s matching the given query parameters.
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
  Future<List<AgentExecutionRequestRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRequestRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentExecutionRequestRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AgentExecutionRequestRow>(
      where: where?.call(AgentExecutionRequestRow.t),
      orderBy: orderBy?.call(AgentExecutionRequestRow.t),
      orderByList: orderByList?.call(AgentExecutionRequestRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AgentExecutionRequestRow] matching the given query parameters.
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
  Future<AgentExecutionRequestRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRequestRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentExecutionRequestRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AgentExecutionRequestRow>(
      where: where?.call(AgentExecutionRequestRow.t),
      orderBy: orderBy?.call(AgentExecutionRequestRow.t),
      orderByList: orderByList?.call(AgentExecutionRequestRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AgentExecutionRequestRow] by its [id] or null if no such row exists.
  Future<AgentExecutionRequestRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AgentExecutionRequestRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AgentExecutionRequestRow]s in the list and returns the inserted rows.
  ///
  /// The returned [AgentExecutionRequestRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<AgentExecutionRequestRow>> insert(
    _i1.DatabaseSession session,
    List<AgentExecutionRequestRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<AgentExecutionRequestRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [AgentExecutionRequestRow] and returns the inserted row.
  ///
  /// The returned [AgentExecutionRequestRow] will have its `id` field set.
  Future<AgentExecutionRequestRow> insertRow(
    _i1.DatabaseSession session,
    AgentExecutionRequestRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<AgentExecutionRequestRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [AgentExecutionRequestRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<AgentExecutionRequestRow>> update(
    _i1.DatabaseSession session,
    List<AgentExecutionRequestRow> rows, {
    _i1.ColumnSelections<AgentExecutionRequestRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<AgentExecutionRequestRow>(
      rows,
      columns: columns?.call(AgentExecutionRequestRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentExecutionRequestRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AgentExecutionRequestRow> updateRow(
    _i1.DatabaseSession session,
    AgentExecutionRequestRow row, {
    _i1.ColumnSelections<AgentExecutionRequestRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<AgentExecutionRequestRow>(
      row,
      columns: columns?.call(AgentExecutionRequestRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentExecutionRequestRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AgentExecutionRequestRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<AgentExecutionRequestRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<AgentExecutionRequestRow>(
      id,
      columnValues: columnValues(AgentExecutionRequestRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AgentExecutionRequestRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<AgentExecutionRequestRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<AgentExecutionRequestRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentExecutionRequestRowTable>? orderBy,
    _i1.OrderByListBuilder<AgentExecutionRequestRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<AgentExecutionRequestRow>(
      columnValues: columnValues(AgentExecutionRequestRow.t.updateTable),
      where: where(AgentExecutionRequestRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentExecutionRequestRow.t),
      orderByList: orderByList?.call(AgentExecutionRequestRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [AgentExecutionRequestRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<AgentExecutionRequestRow>> delete(
    _i1.DatabaseSession session,
    List<AgentExecutionRequestRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<AgentExecutionRequestRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [AgentExecutionRequestRow].
  Future<AgentExecutionRequestRow> deleteRow(
    _i1.DatabaseSession session,
    AgentExecutionRequestRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AgentExecutionRequestRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<AgentExecutionRequestRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<AgentExecutionRequestRow>(
      where: where(AgentExecutionRequestRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<AgentExecutionRequestRow>(
      where: where?.call(AgentExecutionRequestRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AgentExecutionRequestRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentExecutionRequestRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AgentExecutionRequestRow>(
      where: where(AgentExecutionRequestRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

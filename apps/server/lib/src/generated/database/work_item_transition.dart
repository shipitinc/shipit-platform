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

abstract class WorkItemTransitionRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  WorkItemTransitionRow._({
    this.id,
    required this.transitionId,
    required this.workItemId,
    required this.fromState,
    required this.toState,
    required this.trigger,
    required this.actorType,
    this.actorId,
    this.decisionId,
    required this.outcome,
    this.reason,
    this.guardEvaluationsJson,
    this.idempotencyKey,
    required this.occurredAt,
  });

  factory WorkItemTransitionRow({
    int? id,
    required String transitionId,
    required String workItemId,
    required String fromState,
    required String toState,
    required String trigger,
    required String actorType,
    String? actorId,
    String? decisionId,
    required String outcome,
    String? reason,
    String? guardEvaluationsJson,
    String? idempotencyKey,
    required DateTime occurredAt,
  }) = _WorkItemTransitionRowImpl;

  factory WorkItemTransitionRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkItemTransitionRow(
      id: jsonSerialization['id'] as int?,
      transitionId: jsonSerialization['transitionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      fromState: jsonSerialization['fromState'] as String,
      toState: jsonSerialization['toState'] as String,
      trigger: jsonSerialization['trigger'] as String,
      actorType: jsonSerialization['actorType'] as String,
      actorId: jsonSerialization['actorId'] as String?,
      decisionId: jsonSerialization['decisionId'] as String?,
      outcome: jsonSerialization['outcome'] as String,
      reason: jsonSerialization['reason'] as String?,
      guardEvaluationsJson:
          jsonSerialization['guardEvaluationsJson'] as String?,
      idempotencyKey: jsonSerialization['idempotencyKey'] as String?,
      occurredAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
    );
  }

  static final t = WorkItemTransitionRowTable();

  static const db = WorkItemTransitionRowRepository._();

  @override
  int? id;

  String transitionId;

  String workItemId;

  String fromState;

  String toState;

  String trigger;

  String actorType;

  String? actorId;

  String? decisionId;

  String outcome;

  String? reason;

  String? guardEvaluationsJson;

  String? idempotencyKey;

  DateTime occurredAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [WorkItemTransitionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemTransitionRow copyWith({
    int? id,
    String? transitionId,
    String? workItemId,
    String? fromState,
    String? toState,
    String? trigger,
    String? actorType,
    String? actorId,
    String? decisionId,
    String? outcome,
    String? reason,
    String? guardEvaluationsJson,
    String? idempotencyKey,
    DateTime? occurredAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemTransitionRow',
      if (id != null) 'id': id,
      'transitionId': transitionId,
      'workItemId': workItemId,
      'fromState': fromState,
      'toState': toState,
      'trigger': trigger,
      'actorType': actorType,
      if (actorId != null) 'actorId': actorId,
      if (decisionId != null) 'decisionId': decisionId,
      'outcome': outcome,
      if (reason != null) 'reason': reason,
      if (guardEvaluationsJson != null)
        'guardEvaluationsJson': guardEvaluationsJson,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      'occurredAt': occurredAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WorkItemTransitionRowInclude include() {
    return WorkItemTransitionRowInclude._();
  }

  static WorkItemTransitionRowIncludeList includeList({
    _i1.WhereExpressionBuilder<WorkItemTransitionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkItemTransitionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkItemTransitionRowTable>? orderByList,
    WorkItemTransitionRowInclude? include,
  }) {
    return WorkItemTransitionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkItemTransitionRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(WorkItemTransitionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkItemTransitionRowImpl extends WorkItemTransitionRow {
  _WorkItemTransitionRowImpl({
    int? id,
    required String transitionId,
    required String workItemId,
    required String fromState,
    required String toState,
    required String trigger,
    required String actorType,
    String? actorId,
    String? decisionId,
    required String outcome,
    String? reason,
    String? guardEvaluationsJson,
    String? idempotencyKey,
    required DateTime occurredAt,
  }) : super._(
         id: id,
         transitionId: transitionId,
         workItemId: workItemId,
         fromState: fromState,
         toState: toState,
         trigger: trigger,
         actorType: actorType,
         actorId: actorId,
         decisionId: decisionId,
         outcome: outcome,
         reason: reason,
         guardEvaluationsJson: guardEvaluationsJson,
         idempotencyKey: idempotencyKey,
         occurredAt: occurredAt,
       );

  /// Returns a shallow copy of this [WorkItemTransitionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemTransitionRow copyWith({
    Object? id = _Undefined,
    String? transitionId,
    String? workItemId,
    String? fromState,
    String? toState,
    String? trigger,
    String? actorType,
    Object? actorId = _Undefined,
    Object? decisionId = _Undefined,
    String? outcome,
    Object? reason = _Undefined,
    Object? guardEvaluationsJson = _Undefined,
    Object? idempotencyKey = _Undefined,
    DateTime? occurredAt,
  }) {
    return WorkItemTransitionRow(
      id: id is int? ? id : this.id,
      transitionId: transitionId ?? this.transitionId,
      workItemId: workItemId ?? this.workItemId,
      fromState: fromState ?? this.fromState,
      toState: toState ?? this.toState,
      trigger: trigger ?? this.trigger,
      actorType: actorType ?? this.actorType,
      actorId: actorId is String? ? actorId : this.actorId,
      decisionId: decisionId is String? ? decisionId : this.decisionId,
      outcome: outcome ?? this.outcome,
      reason: reason is String? ? reason : this.reason,
      guardEvaluationsJson: guardEvaluationsJson is String?
          ? guardEvaluationsJson
          : this.guardEvaluationsJson,
      idempotencyKey: idempotencyKey is String?
          ? idempotencyKey
          : this.idempotencyKey,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }
}

class WorkItemTransitionRowUpdateTable
    extends _i1.UpdateTable<WorkItemTransitionRowTable> {
  WorkItemTransitionRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> transitionId(String value) => _i1.ColumnValue(
    table.transitionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> fromState(String value) => _i1.ColumnValue(
    table.fromState,
    value,
  );

  _i1.ColumnValue<String, String> toState(String value) => _i1.ColumnValue(
    table.toState,
    value,
  );

  _i1.ColumnValue<String, String> trigger(String value) => _i1.ColumnValue(
    table.trigger,
    value,
  );

  _i1.ColumnValue<String, String> actorType(String value) => _i1.ColumnValue(
    table.actorType,
    value,
  );

  _i1.ColumnValue<String, String> actorId(String? value) => _i1.ColumnValue(
    table.actorId,
    value,
  );

  _i1.ColumnValue<String, String> decisionId(String? value) => _i1.ColumnValue(
    table.decisionId,
    value,
  );

  _i1.ColumnValue<String, String> outcome(String value) => _i1.ColumnValue(
    table.outcome,
    value,
  );

  _i1.ColumnValue<String, String> reason(String? value) => _i1.ColumnValue(
    table.reason,
    value,
  );

  _i1.ColumnValue<String, String> guardEvaluationsJson(String? value) =>
      _i1.ColumnValue(
        table.guardEvaluationsJson,
        value,
      );

  _i1.ColumnValue<String, String> idempotencyKey(String? value) =>
      _i1.ColumnValue(
        table.idempotencyKey,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> occurredAt(DateTime value) =>
      _i1.ColumnValue(
        table.occurredAt,
        value,
      );
}

class WorkItemTransitionRowTable extends _i1.Table<int?> {
  WorkItemTransitionRowTable({super.tableRelation})
    : super(tableName: 'work_item_transition') {
    updateTable = WorkItemTransitionRowUpdateTable(this);
    transitionId = _i1.ColumnString(
      'transitionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    fromState = _i1.ColumnString(
      'fromState',
      this,
    );
    toState = _i1.ColumnString(
      'toState',
      this,
    );
    trigger = _i1.ColumnString(
      'trigger',
      this,
    );
    actorType = _i1.ColumnString(
      'actorType',
      this,
    );
    actorId = _i1.ColumnString(
      'actorId',
      this,
    );
    decisionId = _i1.ColumnString(
      'decisionId',
      this,
    );
    outcome = _i1.ColumnString(
      'outcome',
      this,
    );
    reason = _i1.ColumnString(
      'reason',
      this,
    );
    guardEvaluationsJson = _i1.ColumnString(
      'guardEvaluationsJson',
      this,
    );
    idempotencyKey = _i1.ColumnString(
      'idempotencyKey',
      this,
    );
    occurredAt = _i1.ColumnDateTime(
      'occurredAt',
      this,
    );
  }

  late final WorkItemTransitionRowUpdateTable updateTable;

  late final _i1.ColumnString transitionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString fromState;

  late final _i1.ColumnString toState;

  late final _i1.ColumnString trigger;

  late final _i1.ColumnString actorType;

  late final _i1.ColumnString actorId;

  late final _i1.ColumnString decisionId;

  late final _i1.ColumnString outcome;

  late final _i1.ColumnString reason;

  late final _i1.ColumnString guardEvaluationsJson;

  late final _i1.ColumnString idempotencyKey;

  late final _i1.ColumnDateTime occurredAt;

  @override
  List<_i1.Column> get columns => [
    id,
    transitionId,
    workItemId,
    fromState,
    toState,
    trigger,
    actorType,
    actorId,
    decisionId,
    outcome,
    reason,
    guardEvaluationsJson,
    idempotencyKey,
    occurredAt,
  ];
}

class WorkItemTransitionRowInclude extends _i1.IncludeObject {
  WorkItemTransitionRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => WorkItemTransitionRow.t;
}

class WorkItemTransitionRowIncludeList extends _i1.IncludeList {
  WorkItemTransitionRowIncludeList._({
    _i1.WhereExpressionBuilder<WorkItemTransitionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WorkItemTransitionRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => WorkItemTransitionRow.t;
}

class WorkItemTransitionRowRepository {
  const WorkItemTransitionRowRepository._();

  /// Returns a list of [WorkItemTransitionRow]s matching the given query parameters.
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
  Future<List<WorkItemTransitionRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkItemTransitionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkItemTransitionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkItemTransitionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WorkItemTransitionRow>(
      where: where?.call(WorkItemTransitionRow.t),
      orderBy: orderBy?.call(WorkItemTransitionRow.t),
      orderByList: orderByList?.call(WorkItemTransitionRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WorkItemTransitionRow] matching the given query parameters.
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
  Future<WorkItemTransitionRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkItemTransitionRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<WorkItemTransitionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkItemTransitionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WorkItemTransitionRow>(
      where: where?.call(WorkItemTransitionRow.t),
      orderBy: orderBy?.call(WorkItemTransitionRow.t),
      orderByList: orderByList?.call(WorkItemTransitionRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WorkItemTransitionRow] by its [id] or null if no such row exists.
  Future<WorkItemTransitionRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WorkItemTransitionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WorkItemTransitionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [WorkItemTransitionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<WorkItemTransitionRow>> insert(
    _i1.DatabaseSession session,
    List<WorkItemTransitionRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<WorkItemTransitionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [WorkItemTransitionRow] and returns the inserted row.
  ///
  /// The returned [WorkItemTransitionRow] will have its `id` field set.
  Future<WorkItemTransitionRow> insertRow(
    _i1.DatabaseSession session,
    WorkItemTransitionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<WorkItemTransitionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [WorkItemTransitionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<WorkItemTransitionRow>> update(
    _i1.DatabaseSession session,
    List<WorkItemTransitionRow> rows, {
    _i1.ColumnSelections<WorkItemTransitionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<WorkItemTransitionRow>(
      rows,
      columns: columns?.call(WorkItemTransitionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkItemTransitionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WorkItemTransitionRow> updateRow(
    _i1.DatabaseSession session,
    WorkItemTransitionRow row, {
    _i1.ColumnSelections<WorkItemTransitionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<WorkItemTransitionRow>(
      row,
      columns: columns?.call(WorkItemTransitionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkItemTransitionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WorkItemTransitionRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<WorkItemTransitionRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<WorkItemTransitionRow>(
      id,
      columnValues: columnValues(WorkItemTransitionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WorkItemTransitionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<WorkItemTransitionRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<WorkItemTransitionRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<WorkItemTransitionRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkItemTransitionRowTable>? orderBy,
    _i1.OrderByListBuilder<WorkItemTransitionRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<WorkItemTransitionRow>(
      columnValues: columnValues(WorkItemTransitionRow.t.updateTable),
      where: where(WorkItemTransitionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkItemTransitionRow.t),
      orderByList: orderByList?.call(WorkItemTransitionRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [WorkItemTransitionRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<WorkItemTransitionRow>> delete(
    _i1.DatabaseSession session,
    List<WorkItemTransitionRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<WorkItemTransitionRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [WorkItemTransitionRow].
  Future<WorkItemTransitionRow> deleteRow(
    _i1.DatabaseSession session,
    WorkItemTransitionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WorkItemTransitionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<WorkItemTransitionRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkItemTransitionRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<WorkItemTransitionRow>(
      where: where(WorkItemTransitionRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkItemTransitionRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<WorkItemTransitionRow>(
      where: where?.call(WorkItemTransitionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WorkItemTransitionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkItemTransitionRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WorkItemTransitionRow>(
      where: where(WorkItemTransitionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

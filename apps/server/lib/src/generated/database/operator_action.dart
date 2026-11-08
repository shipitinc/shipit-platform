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

abstract class OperatorActionRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  OperatorActionRow._({
    this.id,
    required this.actionId,
    required this.workItemId,
    required this.action,
    required this.fromState,
    required this.toState,
    required this.requestedBy,
    required this.reason,
    required this.requestId,
    this.jobId,
    this.transitionId,
    this.attemptNumber,
    required this.createdAt,
  });

  factory OperatorActionRow({
    int? id,
    required String actionId,
    required String workItemId,
    required String action,
    required String fromState,
    required String toState,
    required String requestedBy,
    required String reason,
    required String requestId,
    String? jobId,
    String? transitionId,
    int? attemptNumber,
    required DateTime createdAt,
  }) = _OperatorActionRowImpl;

  factory OperatorActionRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return OperatorActionRow(
      id: jsonSerialization['id'] as int?,
      actionId: jsonSerialization['actionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      action: jsonSerialization['action'] as String,
      fromState: jsonSerialization['fromState'] as String,
      toState: jsonSerialization['toState'] as String,
      requestedBy: jsonSerialization['requestedBy'] as String,
      reason: jsonSerialization['reason'] as String,
      requestId: jsonSerialization['requestId'] as String,
      jobId: jsonSerialization['jobId'] as String?,
      transitionId: jsonSerialization['transitionId'] as String?,
      attemptNumber: jsonSerialization['attemptNumber'] as int?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = OperatorActionRowTable();

  static const db = OperatorActionRowRepository._();

  @override
  int? id;

  String actionId;

  String workItemId;

  /// 'retry' | 'stop' | 'deploy' | 'reclaim' | 'reland' | 'reroute'. The
  /// first two are the closed set of OperatorActionKind; the other four are
  /// the endpoint's own wire tokens (operatorDeployActionWire /
  /// operatorReclaimActionWire / operatorRelandActionWire /
  /// operatorRerouteActionWire in work_item_action_endpoints.dart), stored
  /// here as plain strings — the column carries no enum.
  String action;

  String fromState;

  String toState;

  /// THE HUMAN, unlike work_item_transition.actorId, which names the path the
  /// engine acted by. First class on purpose: a string parsed back out of an
  /// idempotency key is a convention, not an audit.
  String requestedBy;

  String reason;

  /// Client-minted, stable per operator intent. Unique per work item — this is
  /// what makes a network replay of one press spend nothing twice.
  String requestId;

  /// Set for 'retry'; null for 'stop', which arms nothing.
  String? jobId;

  /// The work_item_transition row this action authorised. The engine mints the
  /// transition id before it opens its transaction, so both rows commit
  /// together and name each other.
  String? transitionId;

  /// 1 for the first retry of this item, 2 for the second, and so on, counted
  /// from this table and never from memory.
  int? attemptNumber;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [OperatorActionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  OperatorActionRow copyWith({
    int? id,
    String? actionId,
    String? workItemId,
    String? action,
    String? fromState,
    String? toState,
    String? requestedBy,
    String? reason,
    String? requestId,
    String? jobId,
    String? transitionId,
    int? attemptNumber,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OperatorActionRow',
      if (id != null) 'id': id,
      'actionId': actionId,
      'workItemId': workItemId,
      'action': action,
      'fromState': fromState,
      'toState': toState,
      'requestedBy': requestedBy,
      'reason': reason,
      'requestId': requestId,
      if (jobId != null) 'jobId': jobId,
      if (transitionId != null) 'transitionId': transitionId,
      if (attemptNumber != null) 'attemptNumber': attemptNumber,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static OperatorActionRowInclude include() {
    return OperatorActionRowInclude._();
  }

  static OperatorActionRowIncludeList includeList({
    _i1.WhereExpressionBuilder<OperatorActionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<OperatorActionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<OperatorActionRowTable>? orderByList,
    OperatorActionRowInclude? include,
  }) {
    return OperatorActionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OperatorActionRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(OperatorActionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OperatorActionRowImpl extends OperatorActionRow {
  _OperatorActionRowImpl({
    int? id,
    required String actionId,
    required String workItemId,
    required String action,
    required String fromState,
    required String toState,
    required String requestedBy,
    required String reason,
    required String requestId,
    String? jobId,
    String? transitionId,
    int? attemptNumber,
    required DateTime createdAt,
  }) : super._(
         id: id,
         actionId: actionId,
         workItemId: workItemId,
         action: action,
         fromState: fromState,
         toState: toState,
         requestedBy: requestedBy,
         reason: reason,
         requestId: requestId,
         jobId: jobId,
         transitionId: transitionId,
         attemptNumber: attemptNumber,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [OperatorActionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  OperatorActionRow copyWith({
    Object? id = _Undefined,
    String? actionId,
    String? workItemId,
    String? action,
    String? fromState,
    String? toState,
    String? requestedBy,
    String? reason,
    String? requestId,
    Object? jobId = _Undefined,
    Object? transitionId = _Undefined,
    Object? attemptNumber = _Undefined,
    DateTime? createdAt,
  }) {
    return OperatorActionRow(
      id: id is int? ? id : this.id,
      actionId: actionId ?? this.actionId,
      workItemId: workItemId ?? this.workItemId,
      action: action ?? this.action,
      fromState: fromState ?? this.fromState,
      toState: toState ?? this.toState,
      requestedBy: requestedBy ?? this.requestedBy,
      reason: reason ?? this.reason,
      requestId: requestId ?? this.requestId,
      jobId: jobId is String? ? jobId : this.jobId,
      transitionId: transitionId is String? ? transitionId : this.transitionId,
      attemptNumber: attemptNumber is int? ? attemptNumber : this.attemptNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class OperatorActionRowUpdateTable
    extends _i1.UpdateTable<OperatorActionRowTable> {
  OperatorActionRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> actionId(String value) => _i1.ColumnValue(
    table.actionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> action(String value) => _i1.ColumnValue(
    table.action,
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

  _i1.ColumnValue<String, String> requestedBy(String value) => _i1.ColumnValue(
    table.requestedBy,
    value,
  );

  _i1.ColumnValue<String, String> reason(String value) => _i1.ColumnValue(
    table.reason,
    value,
  );

  _i1.ColumnValue<String, String> requestId(String value) => _i1.ColumnValue(
    table.requestId,
    value,
  );

  _i1.ColumnValue<String, String> jobId(String? value) => _i1.ColumnValue(
    table.jobId,
    value,
  );

  _i1.ColumnValue<String, String> transitionId(String? value) =>
      _i1.ColumnValue(
        table.transitionId,
        value,
      );

  _i1.ColumnValue<int, int> attemptNumber(int? value) => _i1.ColumnValue(
    table.attemptNumber,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class OperatorActionRowTable extends _i1.Table<int?> {
  OperatorActionRowTable({super.tableRelation})
    : super(tableName: 'operator_action') {
    updateTable = OperatorActionRowUpdateTable(this);
    actionId = _i1.ColumnString(
      'actionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    action = _i1.ColumnString(
      'action',
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
    requestedBy = _i1.ColumnString(
      'requestedBy',
      this,
    );
    reason = _i1.ColumnString(
      'reason',
      this,
    );
    requestId = _i1.ColumnString(
      'requestId',
      this,
    );
    jobId = _i1.ColumnString(
      'jobId',
      this,
    );
    transitionId = _i1.ColumnString(
      'transitionId',
      this,
    );
    attemptNumber = _i1.ColumnInt(
      'attemptNumber',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final OperatorActionRowUpdateTable updateTable;

  late final _i1.ColumnString actionId;

  late final _i1.ColumnString workItemId;

  /// 'retry' | 'stop' | 'deploy' | 'reclaim' | 'reland' | 'reroute'. The
  /// first two are the closed set of OperatorActionKind; the other four are
  /// the endpoint's own wire tokens (operatorDeployActionWire /
  /// operatorReclaimActionWire / operatorRelandActionWire /
  /// operatorRerouteActionWire in work_item_action_endpoints.dart), stored
  /// here as plain strings — the column carries no enum.
  late final _i1.ColumnString action;

  late final _i1.ColumnString fromState;

  late final _i1.ColumnString toState;

  /// THE HUMAN, unlike work_item_transition.actorId, which names the path the
  /// engine acted by. First class on purpose: a string parsed back out of an
  /// idempotency key is a convention, not an audit.
  late final _i1.ColumnString requestedBy;

  late final _i1.ColumnString reason;

  /// Client-minted, stable per operator intent. Unique per work item — this is
  /// what makes a network replay of one press spend nothing twice.
  late final _i1.ColumnString requestId;

  /// Set for 'retry'; null for 'stop', which arms nothing.
  late final _i1.ColumnString jobId;

  /// The work_item_transition row this action authorised. The engine mints the
  /// transition id before it opens its transaction, so both rows commit
  /// together and name each other.
  late final _i1.ColumnString transitionId;

  /// 1 for the first retry of this item, 2 for the second, and so on, counted
  /// from this table and never from memory.
  late final _i1.ColumnInt attemptNumber;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    actionId,
    workItemId,
    action,
    fromState,
    toState,
    requestedBy,
    reason,
    requestId,
    jobId,
    transitionId,
    attemptNumber,
    createdAt,
  ];
}

class OperatorActionRowInclude extends _i1.IncludeObject {
  OperatorActionRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => OperatorActionRow.t;
}

class OperatorActionRowIncludeList extends _i1.IncludeList {
  OperatorActionRowIncludeList._({
    _i1.WhereExpressionBuilder<OperatorActionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OperatorActionRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => OperatorActionRow.t;
}

class OperatorActionRowRepository {
  const OperatorActionRowRepository._();

  /// Returns a list of [OperatorActionRow]s matching the given query parameters.
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
  Future<List<OperatorActionRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<OperatorActionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<OperatorActionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<OperatorActionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OperatorActionRow>(
      where: where?.call(OperatorActionRow.t),
      orderBy: orderBy?.call(OperatorActionRow.t),
      orderByList: orderByList?.call(OperatorActionRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [OperatorActionRow] matching the given query parameters.
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
  Future<OperatorActionRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<OperatorActionRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<OperatorActionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<OperatorActionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OperatorActionRow>(
      where: where?.call(OperatorActionRow.t),
      orderBy: orderBy?.call(OperatorActionRow.t),
      orderByList: orderByList?.call(OperatorActionRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OperatorActionRow] by its [id] or null if no such row exists.
  Future<OperatorActionRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OperatorActionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OperatorActionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [OperatorActionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<OperatorActionRow>> insert(
    _i1.DatabaseSession session,
    List<OperatorActionRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<OperatorActionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [OperatorActionRow] and returns the inserted row.
  ///
  /// The returned [OperatorActionRow] will have its `id` field set.
  Future<OperatorActionRow> insertRow(
    _i1.DatabaseSession session,
    OperatorActionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<OperatorActionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [OperatorActionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<OperatorActionRow>> update(
    _i1.DatabaseSession session,
    List<OperatorActionRow> rows, {
    _i1.ColumnSelections<OperatorActionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<OperatorActionRow>(
      rows,
      columns: columns?.call(OperatorActionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OperatorActionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OperatorActionRow> updateRow(
    _i1.DatabaseSession session,
    OperatorActionRow row, {
    _i1.ColumnSelections<OperatorActionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<OperatorActionRow>(
      row,
      columns: columns?.call(OperatorActionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OperatorActionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OperatorActionRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<OperatorActionRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<OperatorActionRow>(
      id,
      columnValues: columnValues(OperatorActionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OperatorActionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<OperatorActionRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<OperatorActionRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<OperatorActionRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<OperatorActionRowTable>? orderBy,
    _i1.OrderByListBuilder<OperatorActionRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<OperatorActionRow>(
      columnValues: columnValues(OperatorActionRow.t.updateTable),
      where: where(OperatorActionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OperatorActionRow.t),
      orderByList: orderByList?.call(OperatorActionRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [OperatorActionRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<OperatorActionRow>> delete(
    _i1.DatabaseSession session,
    List<OperatorActionRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<OperatorActionRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [OperatorActionRow].
  Future<OperatorActionRow> deleteRow(
    _i1.DatabaseSession session,
    OperatorActionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OperatorActionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<OperatorActionRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<OperatorActionRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<OperatorActionRow>(
      where: where(OperatorActionRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<OperatorActionRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<OperatorActionRow>(
      where: where?.call(OperatorActionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OperatorActionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<OperatorActionRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OperatorActionRow>(
      where: where(OperatorActionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

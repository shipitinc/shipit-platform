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

abstract class WorkerEventRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  WorkerEventRow._({
    this.id,
    required this.eventId,
    required this.workerExecutionId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payloadJson,
  });

  factory WorkerEventRow({
    int? id,
    required String eventId,
    required String workerExecutionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) = _WorkerEventRowImpl;

  factory WorkerEventRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkerEventRow(
      id: jsonSerialization['id'] as int?,
      eventId: jsonSerialization['eventId'] as String,
      workerExecutionId: jsonSerialization['workerExecutionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      sequence: jsonSerialization['sequence'] as int,
      type: jsonSerialization['type'] as String,
      occurredAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
      payloadJson: jsonSerialization['payloadJson'] as String?,
    );
  }

  static final t = WorkerEventRowTable();

  static const db = WorkerEventRowRepository._();

  @override
  int? id;

  String eventId;

  String workerExecutionId;

  String workItemId;

  int sequence;

  String type;

  DateTime occurredAt;

  String? payloadJson;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [WorkerEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerEventRow copyWith({
    int? id,
    String? eventId,
    String? workerExecutionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    String? payloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerEventRow',
      if (id != null) 'id': id,
      'eventId': eventId,
      'workerExecutionId': workerExecutionId,
      'workItemId': workItemId,
      'sequence': sequence,
      'type': type,
      'occurredAt': occurredAt.toJson(),
      if (payloadJson != null) 'payloadJson': payloadJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WorkerEventRowInclude include() {
    return WorkerEventRowInclude._();
  }

  static WorkerEventRowIncludeList includeList({
    _i1.WhereExpressionBuilder<WorkerEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerEventRowTable>? orderByList,
    WorkerEventRowInclude? include,
  }) {
    return WorkerEventRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerEventRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(WorkerEventRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerEventRowImpl extends WorkerEventRow {
  _WorkerEventRowImpl({
    int? id,
    required String eventId,
    required String workerExecutionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) : super._(
         id: id,
         eventId: eventId,
         workerExecutionId: workerExecutionId,
         workItemId: workItemId,
         sequence: sequence,
         type: type,
         occurredAt: occurredAt,
         payloadJson: payloadJson,
       );

  /// Returns a shallow copy of this [WorkerEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerEventRow copyWith({
    Object? id = _Undefined,
    String? eventId,
    String? workerExecutionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    Object? payloadJson = _Undefined,
  }) {
    return WorkerEventRow(
      id: id is int? ? id : this.id,
      eventId: eventId ?? this.eventId,
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
    );
  }
}

class WorkerEventRowUpdateTable extends _i1.UpdateTable<WorkerEventRowTable> {
  WorkerEventRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> eventId(String value) => _i1.ColumnValue(
    table.eventId,
    value,
  );

  _i1.ColumnValue<String, String> workerExecutionId(String value) =>
      _i1.ColumnValue(
        table.workerExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<int, int> sequence(int value) => _i1.ColumnValue(
    table.sequence,
    value,
  );

  _i1.ColumnValue<String, String> type(String value) => _i1.ColumnValue(
    table.type,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> occurredAt(DateTime value) =>
      _i1.ColumnValue(
        table.occurredAt,
        value,
      );

  _i1.ColumnValue<String, String> payloadJson(String? value) => _i1.ColumnValue(
    table.payloadJson,
    value,
  );
}

class WorkerEventRowTable extends _i1.Table<int?> {
  WorkerEventRowTable({super.tableRelation})
    : super(tableName: 'worker_event') {
    updateTable = WorkerEventRowUpdateTable(this);
    eventId = _i1.ColumnString(
      'eventId',
      this,
    );
    workerExecutionId = _i1.ColumnString(
      'workerExecutionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    sequence = _i1.ColumnInt(
      'sequence',
      this,
    );
    type = _i1.ColumnString(
      'type',
      this,
    );
    occurredAt = _i1.ColumnDateTime(
      'occurredAt',
      this,
    );
    payloadJson = _i1.ColumnString(
      'payloadJson',
      this,
    );
  }

  late final WorkerEventRowUpdateTable updateTable;

  late final _i1.ColumnString eventId;

  late final _i1.ColumnString workerExecutionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnInt sequence;

  late final _i1.ColumnString type;

  late final _i1.ColumnDateTime occurredAt;

  late final _i1.ColumnString payloadJson;

  @override
  List<_i1.Column> get columns => [
    id,
    eventId,
    workerExecutionId,
    workItemId,
    sequence,
    type,
    occurredAt,
    payloadJson,
  ];
}

class WorkerEventRowInclude extends _i1.IncludeObject {
  WorkerEventRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => WorkerEventRow.t;
}

class WorkerEventRowIncludeList extends _i1.IncludeList {
  WorkerEventRowIncludeList._({
    _i1.WhereExpressionBuilder<WorkerEventRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WorkerEventRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => WorkerEventRow.t;
}

class WorkerEventRowRepository {
  const WorkerEventRowRepository._();

  /// Returns a list of [WorkerEventRow]s matching the given query parameters.
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
  Future<List<WorkerEventRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WorkerEventRow>(
      where: where?.call(WorkerEventRow.t),
      orderBy: orderBy?.call(WorkerEventRow.t),
      orderByList: orderByList?.call(WorkerEventRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WorkerEventRow] matching the given query parameters.
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
  Future<WorkerEventRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerEventRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<WorkerEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WorkerEventRow>(
      where: where?.call(WorkerEventRow.t),
      orderBy: orderBy?.call(WorkerEventRow.t),
      orderByList: orderByList?.call(WorkerEventRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WorkerEventRow] by its [id] or null if no such row exists.
  Future<WorkerEventRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WorkerEventRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WorkerEventRow]s in the list and returns the inserted rows.
  ///
  /// The returned [WorkerEventRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<WorkerEventRow>> insert(
    _i1.DatabaseSession session,
    List<WorkerEventRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<WorkerEventRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [WorkerEventRow] and returns the inserted row.
  ///
  /// The returned [WorkerEventRow] will have its `id` field set.
  Future<WorkerEventRow> insertRow(
    _i1.DatabaseSession session,
    WorkerEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<WorkerEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [WorkerEventRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<WorkerEventRow>> update(
    _i1.DatabaseSession session,
    List<WorkerEventRow> rows, {
    _i1.ColumnSelections<WorkerEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<WorkerEventRow>(
      rows,
      columns: columns?.call(WorkerEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerEventRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WorkerEventRow> updateRow(
    _i1.DatabaseSession session,
    WorkerEventRow row, {
    _i1.ColumnSelections<WorkerEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<WorkerEventRow>(
      row,
      columns: columns?.call(WorkerEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerEventRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WorkerEventRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<WorkerEventRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<WorkerEventRow>(
      id,
      columnValues: columnValues(WorkerEventRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WorkerEventRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<WorkerEventRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<WorkerEventRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<WorkerEventRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerEventRowTable>? orderBy,
    _i1.OrderByListBuilder<WorkerEventRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<WorkerEventRow>(
      columnValues: columnValues(WorkerEventRow.t.updateTable),
      where: where(WorkerEventRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerEventRow.t),
      orderByList: orderByList?.call(WorkerEventRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [WorkerEventRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<WorkerEventRow>> delete(
    _i1.DatabaseSession session,
    List<WorkerEventRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<WorkerEventRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [WorkerEventRow].
  Future<WorkerEventRow> deleteRow(
    _i1.DatabaseSession session,
    WorkerEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WorkerEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<WorkerEventRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerEventRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<WorkerEventRow>(
      where: where(WorkerEventRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerEventRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<WorkerEventRow>(
      where: where?.call(WorkerEventRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WorkerEventRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerEventRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WorkerEventRow>(
      where: where(WorkerEventRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

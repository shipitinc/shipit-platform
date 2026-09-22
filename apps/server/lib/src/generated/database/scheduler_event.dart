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

abstract class SchedulerEventRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  SchedulerEventRow._({
    this.id,
    required this.eventId,
    required this.jobId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payloadJson,
  });

  factory SchedulerEventRow({
    int? id,
    required String eventId,
    required String jobId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) = _SchedulerEventRowImpl;

  factory SchedulerEventRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return SchedulerEventRow(
      id: jsonSerialization['id'] as int?,
      eventId: jsonSerialization['eventId'] as String,
      jobId: jsonSerialization['jobId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      sequence: jsonSerialization['sequence'] as int,
      type: jsonSerialization['type'] as String,
      occurredAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
      payloadJson: jsonSerialization['payloadJson'] as String?,
    );
  }

  static final t = SchedulerEventRowTable();

  static const db = SchedulerEventRowRepository._();

  @override
  int? id;

  String eventId;

  String jobId;

  String workItemId;

  int sequence;

  String type;

  DateTime occurredAt;

  String? payloadJson;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [SchedulerEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SchedulerEventRow copyWith({
    int? id,
    String? eventId,
    String? jobId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    String? payloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SchedulerEventRow',
      if (id != null) 'id': id,
      'eventId': eventId,
      'jobId': jobId,
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

  static SchedulerEventRowInclude include() {
    return SchedulerEventRowInclude._();
  }

  static SchedulerEventRowIncludeList includeList({
    _i1.WhereExpressionBuilder<SchedulerEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SchedulerEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SchedulerEventRowTable>? orderByList,
    SchedulerEventRowInclude? include,
  }) {
    return SchedulerEventRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SchedulerEventRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(SchedulerEventRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SchedulerEventRowImpl extends SchedulerEventRow {
  _SchedulerEventRowImpl({
    int? id,
    required String eventId,
    required String jobId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) : super._(
         id: id,
         eventId: eventId,
         jobId: jobId,
         workItemId: workItemId,
         sequence: sequence,
         type: type,
         occurredAt: occurredAt,
         payloadJson: payloadJson,
       );

  /// Returns a shallow copy of this [SchedulerEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SchedulerEventRow copyWith({
    Object? id = _Undefined,
    String? eventId,
    String? jobId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    Object? payloadJson = _Undefined,
  }) {
    return SchedulerEventRow(
      id: id is int? ? id : this.id,
      eventId: eventId ?? this.eventId,
      jobId: jobId ?? this.jobId,
      workItemId: workItemId ?? this.workItemId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
    );
  }
}

class SchedulerEventRowUpdateTable
    extends _i1.UpdateTable<SchedulerEventRowTable> {
  SchedulerEventRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> eventId(String value) => _i1.ColumnValue(
    table.eventId,
    value,
  );

  _i1.ColumnValue<String, String> jobId(String value) => _i1.ColumnValue(
    table.jobId,
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

class SchedulerEventRowTable extends _i1.Table<int?> {
  SchedulerEventRowTable({super.tableRelation})
    : super(tableName: 'scheduler_event') {
    updateTable = SchedulerEventRowUpdateTable(this);
    eventId = _i1.ColumnString(
      'eventId',
      this,
    );
    jobId = _i1.ColumnString(
      'jobId',
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

  late final SchedulerEventRowUpdateTable updateTable;

  late final _i1.ColumnString eventId;

  late final _i1.ColumnString jobId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnInt sequence;

  late final _i1.ColumnString type;

  late final _i1.ColumnDateTime occurredAt;

  late final _i1.ColumnString payloadJson;

  @override
  List<_i1.Column> get columns => [
    id,
    eventId,
    jobId,
    workItemId,
    sequence,
    type,
    occurredAt,
    payloadJson,
  ];
}

class SchedulerEventRowInclude extends _i1.IncludeObject {
  SchedulerEventRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => SchedulerEventRow.t;
}

class SchedulerEventRowIncludeList extends _i1.IncludeList {
  SchedulerEventRowIncludeList._({
    _i1.WhereExpressionBuilder<SchedulerEventRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SchedulerEventRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => SchedulerEventRow.t;
}

class SchedulerEventRowRepository {
  const SchedulerEventRowRepository._();

  /// Returns a list of [SchedulerEventRow]s matching the given query parameters.
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
  Future<List<SchedulerEventRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SchedulerEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SchedulerEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SchedulerEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SchedulerEventRow>(
      where: where?.call(SchedulerEventRow.t),
      orderBy: orderBy?.call(SchedulerEventRow.t),
      orderByList: orderByList?.call(SchedulerEventRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [SchedulerEventRow] matching the given query parameters.
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
  Future<SchedulerEventRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SchedulerEventRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<SchedulerEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<SchedulerEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SchedulerEventRow>(
      where: where?.call(SchedulerEventRow.t),
      orderBy: orderBy?.call(SchedulerEventRow.t),
      orderByList: orderByList?.call(SchedulerEventRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SchedulerEventRow] by its [id] or null if no such row exists.
  Future<SchedulerEventRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SchedulerEventRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SchedulerEventRow]s in the list and returns the inserted rows.
  ///
  /// The returned [SchedulerEventRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<SchedulerEventRow>> insert(
    _i1.DatabaseSession session,
    List<SchedulerEventRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<SchedulerEventRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [SchedulerEventRow] and returns the inserted row.
  ///
  /// The returned [SchedulerEventRow] will have its `id` field set.
  Future<SchedulerEventRow> insertRow(
    _i1.DatabaseSession session,
    SchedulerEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<SchedulerEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [SchedulerEventRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<SchedulerEventRow>> update(
    _i1.DatabaseSession session,
    List<SchedulerEventRow> rows, {
    _i1.ColumnSelections<SchedulerEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<SchedulerEventRow>(
      rows,
      columns: columns?.call(SchedulerEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SchedulerEventRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SchedulerEventRow> updateRow(
    _i1.DatabaseSession session,
    SchedulerEventRow row, {
    _i1.ColumnSelections<SchedulerEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<SchedulerEventRow>(
      row,
      columns: columns?.call(SchedulerEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SchedulerEventRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SchedulerEventRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<SchedulerEventRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<SchedulerEventRow>(
      id,
      columnValues: columnValues(SchedulerEventRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SchedulerEventRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<SchedulerEventRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<SchedulerEventRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<SchedulerEventRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<SchedulerEventRowTable>? orderBy,
    _i1.OrderByListBuilder<SchedulerEventRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<SchedulerEventRow>(
      columnValues: columnValues(SchedulerEventRow.t.updateTable),
      where: where(SchedulerEventRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SchedulerEventRow.t),
      orderByList: orderByList?.call(SchedulerEventRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [SchedulerEventRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<SchedulerEventRow>> delete(
    _i1.DatabaseSession session,
    List<SchedulerEventRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<SchedulerEventRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [SchedulerEventRow].
  Future<SchedulerEventRow> deleteRow(
    _i1.DatabaseSession session,
    SchedulerEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SchedulerEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<SchedulerEventRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<SchedulerEventRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<SchedulerEventRow>(
      where: where(SchedulerEventRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<SchedulerEventRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<SchedulerEventRow>(
      where: where?.call(SchedulerEventRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SchedulerEventRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<SchedulerEventRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SchedulerEventRow>(
      where: where(SchedulerEventRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

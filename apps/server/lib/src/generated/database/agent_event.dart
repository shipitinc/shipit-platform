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

abstract class AgentEventRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  AgentEventRow._({
    this.id,
    required this.eventId,
    required this.executionId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payloadJson,
  });

  factory AgentEventRow({
    int? id,
    required String eventId,
    required String executionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) = _AgentEventRowImpl;

  factory AgentEventRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentEventRow(
      id: jsonSerialization['id'] as int?,
      eventId: jsonSerialization['eventId'] as String,
      executionId: jsonSerialization['executionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      sequence: jsonSerialization['sequence'] as int,
      type: jsonSerialization['type'] as String,
      occurredAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
      payloadJson: jsonSerialization['payloadJson'] as String?,
    );
  }

  static final t = AgentEventRowTable();

  static const db = AgentEventRowRepository._();

  @override
  int? id;

  String eventId;

  String executionId;

  String workItemId;

  int sequence;

  String type;

  DateTime occurredAt;

  String? payloadJson;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [AgentEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentEventRow copyWith({
    int? id,
    String? eventId,
    String? executionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    String? payloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentEventRow',
      if (id != null) 'id': id,
      'eventId': eventId,
      'executionId': executionId,
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

  static AgentEventRowInclude include() {
    return AgentEventRowInclude._();
  }

  static AgentEventRowIncludeList includeList({
    _i1.WhereExpressionBuilder<AgentEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentEventRowTable>? orderByList,
    AgentEventRowInclude? include,
  }) {
    return AgentEventRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentEventRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(AgentEventRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentEventRowImpl extends AgentEventRow {
  _AgentEventRowImpl({
    int? id,
    required String eventId,
    required String executionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) : super._(
         id: id,
         eventId: eventId,
         executionId: executionId,
         workItemId: workItemId,
         sequence: sequence,
         type: type,
         occurredAt: occurredAt,
         payloadJson: payloadJson,
       );

  /// Returns a shallow copy of this [AgentEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentEventRow copyWith({
    Object? id = _Undefined,
    String? eventId,
    String? executionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    Object? payloadJson = _Undefined,
  }) {
    return AgentEventRow(
      id: id is int? ? id : this.id,
      eventId: eventId ?? this.eventId,
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
    );
  }
}

class AgentEventRowUpdateTable extends _i1.UpdateTable<AgentEventRowTable> {
  AgentEventRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> eventId(String value) => _i1.ColumnValue(
    table.eventId,
    value,
  );

  _i1.ColumnValue<String, String> executionId(String value) => _i1.ColumnValue(
    table.executionId,
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

class AgentEventRowTable extends _i1.Table<int?> {
  AgentEventRowTable({super.tableRelation}) : super(tableName: 'agent_event') {
    updateTable = AgentEventRowUpdateTable(this);
    eventId = _i1.ColumnString(
      'eventId',
      this,
    );
    executionId = _i1.ColumnString(
      'executionId',
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

  late final AgentEventRowUpdateTable updateTable;

  late final _i1.ColumnString eventId;

  late final _i1.ColumnString executionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnInt sequence;

  late final _i1.ColumnString type;

  late final _i1.ColumnDateTime occurredAt;

  late final _i1.ColumnString payloadJson;

  @override
  List<_i1.Column> get columns => [
    id,
    eventId,
    executionId,
    workItemId,
    sequence,
    type,
    occurredAt,
    payloadJson,
  ];
}

class AgentEventRowInclude extends _i1.IncludeObject {
  AgentEventRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => AgentEventRow.t;
}

class AgentEventRowIncludeList extends _i1.IncludeList {
  AgentEventRowIncludeList._({
    _i1.WhereExpressionBuilder<AgentEventRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AgentEventRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => AgentEventRow.t;
}

class AgentEventRowRepository {
  const AgentEventRowRepository._();

  /// Returns a list of [AgentEventRow]s matching the given query parameters.
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
  Future<List<AgentEventRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AgentEventRow>(
      where: where?.call(AgentEventRow.t),
      orderBy: orderBy?.call(AgentEventRow.t),
      orderByList: orderByList?.call(AgentEventRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AgentEventRow] matching the given query parameters.
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
  Future<AgentEventRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentEventRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<AgentEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<AgentEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AgentEventRow>(
      where: where?.call(AgentEventRow.t),
      orderBy: orderBy?.call(AgentEventRow.t),
      orderByList: orderByList?.call(AgentEventRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AgentEventRow] by its [id] or null if no such row exists.
  Future<AgentEventRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AgentEventRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AgentEventRow]s in the list and returns the inserted rows.
  ///
  /// The returned [AgentEventRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<AgentEventRow>> insert(
    _i1.DatabaseSession session,
    List<AgentEventRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<AgentEventRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [AgentEventRow] and returns the inserted row.
  ///
  /// The returned [AgentEventRow] will have its `id` field set.
  Future<AgentEventRow> insertRow(
    _i1.DatabaseSession session,
    AgentEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<AgentEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [AgentEventRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<AgentEventRow>> update(
    _i1.DatabaseSession session,
    List<AgentEventRow> rows, {
    _i1.ColumnSelections<AgentEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<AgentEventRow>(
      rows,
      columns: columns?.call(AgentEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentEventRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AgentEventRow> updateRow(
    _i1.DatabaseSession session,
    AgentEventRow row, {
    _i1.ColumnSelections<AgentEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<AgentEventRow>(
      row,
      columns: columns?.call(AgentEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentEventRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AgentEventRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<AgentEventRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<AgentEventRow>(
      id,
      columnValues: columnValues(AgentEventRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AgentEventRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<AgentEventRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<AgentEventRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<AgentEventRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<AgentEventRowTable>? orderBy,
    _i1.OrderByListBuilder<AgentEventRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<AgentEventRow>(
      columnValues: columnValues(AgentEventRow.t.updateTable),
      where: where(AgentEventRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentEventRow.t),
      orderByList: orderByList?.call(AgentEventRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [AgentEventRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<AgentEventRow>> delete(
    _i1.DatabaseSession session,
    List<AgentEventRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<AgentEventRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [AgentEventRow].
  Future<AgentEventRow> deleteRow(
    _i1.DatabaseSession session,
    AgentEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AgentEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<AgentEventRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentEventRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<AgentEventRow>(
      where: where(AgentEventRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<AgentEventRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<AgentEventRow>(
      where: where?.call(AgentEventRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AgentEventRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<AgentEventRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AgentEventRow>(
      where: where(AgentEventRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

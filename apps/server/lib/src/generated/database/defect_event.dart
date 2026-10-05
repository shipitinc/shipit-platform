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

abstract class DefectEventRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DefectEventRow._({
    this.id,
    required this.eventId,
    required this.defectId,
    required this.sequence,
    required this.type,
    this.fromStatus,
    this.toStatus,
    required this.actorType,
    this.actorId,
    this.payloadJson,
    required this.occurredAt,
  });

  factory DefectEventRow({
    int? id,
    required String eventId,
    required String defectId,
    required int sequence,
    required String type,
    String? fromStatus,
    String? toStatus,
    required String actorType,
    String? actorId,
    String? payloadJson,
    required DateTime occurredAt,
  }) = _DefectEventRowImpl;

  factory DefectEventRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectEventRow(
      id: jsonSerialization['id'] as int?,
      eventId: jsonSerialization['eventId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      sequence: jsonSerialization['sequence'] as int,
      type: jsonSerialization['type'] as String,
      fromStatus: jsonSerialization['fromStatus'] as String?,
      toStatus: jsonSerialization['toStatus'] as String?,
      actorType: jsonSerialization['actorType'] as String,
      actorId: jsonSerialization['actorId'] as String?,
      payloadJson: jsonSerialization['payloadJson'] as String?,
      occurredAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
    );
  }

  static final t = DefectEventRowTable();

  static const db = DefectEventRowRepository._();

  @override
  int? id;

  String eventId;

  String defectId;

  int sequence;

  String type;

  String? fromStatus;

  String? toStatus;

  String actorType;

  String? actorId;

  String? payloadJson;

  DateTime occurredAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DefectEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectEventRow copyWith({
    int? id,
    String? eventId,
    String? defectId,
    int? sequence,
    String? type,
    String? fromStatus,
    String? toStatus,
    String? actorType,
    String? actorId,
    String? payloadJson,
    DateTime? occurredAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectEventRow',
      if (id != null) 'id': id,
      'eventId': eventId,
      'defectId': defectId,
      'sequence': sequence,
      'type': type,
      if (fromStatus != null) 'fromStatus': fromStatus,
      if (toStatus != null) 'toStatus': toStatus,
      'actorType': actorType,
      if (actorId != null) 'actorId': actorId,
      if (payloadJson != null) 'payloadJson': payloadJson,
      'occurredAt': occurredAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DefectEventRowInclude include() {
    return DefectEventRowInclude._();
  }

  static DefectEventRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DefectEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectEventRowTable>? orderByList,
    DefectEventRowInclude? include,
  }) {
    return DefectEventRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectEventRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DefectEventRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectEventRowImpl extends DefectEventRow {
  _DefectEventRowImpl({
    int? id,
    required String eventId,
    required String defectId,
    required int sequence,
    required String type,
    String? fromStatus,
    String? toStatus,
    required String actorType,
    String? actorId,
    String? payloadJson,
    required DateTime occurredAt,
  }) : super._(
         id: id,
         eventId: eventId,
         defectId: defectId,
         sequence: sequence,
         type: type,
         fromStatus: fromStatus,
         toStatus: toStatus,
         actorType: actorType,
         actorId: actorId,
         payloadJson: payloadJson,
         occurredAt: occurredAt,
       );

  /// Returns a shallow copy of this [DefectEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectEventRow copyWith({
    Object? id = _Undefined,
    String? eventId,
    String? defectId,
    int? sequence,
    String? type,
    Object? fromStatus = _Undefined,
    Object? toStatus = _Undefined,
    String? actorType,
    Object? actorId = _Undefined,
    Object? payloadJson = _Undefined,
    DateTime? occurredAt,
  }) {
    return DefectEventRow(
      id: id is int? ? id : this.id,
      eventId: eventId ?? this.eventId,
      defectId: defectId ?? this.defectId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      fromStatus: fromStatus is String? ? fromStatus : this.fromStatus,
      toStatus: toStatus is String? ? toStatus : this.toStatus,
      actorType: actorType ?? this.actorType,
      actorId: actorId is String? ? actorId : this.actorId,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }
}

class DefectEventRowUpdateTable extends _i1.UpdateTable<DefectEventRowTable> {
  DefectEventRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> eventId(String value) => _i1.ColumnValue(
    table.eventId,
    value,
  );

  _i1.ColumnValue<String, String> defectId(String value) => _i1.ColumnValue(
    table.defectId,
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

  _i1.ColumnValue<String, String> fromStatus(String? value) => _i1.ColumnValue(
    table.fromStatus,
    value,
  );

  _i1.ColumnValue<String, String> toStatus(String? value) => _i1.ColumnValue(
    table.toStatus,
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

  _i1.ColumnValue<String, String> payloadJson(String? value) => _i1.ColumnValue(
    table.payloadJson,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> occurredAt(DateTime value) =>
      _i1.ColumnValue(
        table.occurredAt,
        value,
      );
}

class DefectEventRowTable extends _i1.Table<int?> {
  DefectEventRowTable({super.tableRelation})
    : super(tableName: 'defect_event') {
    updateTable = DefectEventRowUpdateTable(this);
    eventId = _i1.ColumnString(
      'eventId',
      this,
    );
    defectId = _i1.ColumnString(
      'defectId',
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
    fromStatus = _i1.ColumnString(
      'fromStatus',
      this,
    );
    toStatus = _i1.ColumnString(
      'toStatus',
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
    payloadJson = _i1.ColumnString(
      'payloadJson',
      this,
    );
    occurredAt = _i1.ColumnDateTime(
      'occurredAt',
      this,
    );
  }

  late final DefectEventRowUpdateTable updateTable;

  late final _i1.ColumnString eventId;

  late final _i1.ColumnString defectId;

  late final _i1.ColumnInt sequence;

  late final _i1.ColumnString type;

  late final _i1.ColumnString fromStatus;

  late final _i1.ColumnString toStatus;

  late final _i1.ColumnString actorType;

  late final _i1.ColumnString actorId;

  late final _i1.ColumnString payloadJson;

  late final _i1.ColumnDateTime occurredAt;

  @override
  List<_i1.Column> get columns => [
    id,
    eventId,
    defectId,
    sequence,
    type,
    fromStatus,
    toStatus,
    actorType,
    actorId,
    payloadJson,
    occurredAt,
  ];
}

class DefectEventRowInclude extends _i1.IncludeObject {
  DefectEventRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DefectEventRow.t;
}

class DefectEventRowIncludeList extends _i1.IncludeList {
  DefectEventRowIncludeList._({
    _i1.WhereExpressionBuilder<DefectEventRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DefectEventRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DefectEventRow.t;
}

class DefectEventRowRepository {
  const DefectEventRowRepository._();

  /// Returns a list of [DefectEventRow]s matching the given query parameters.
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
  Future<List<DefectEventRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DefectEventRow>(
      where: where?.call(DefectEventRow.t),
      orderBy: orderBy?.call(DefectEventRow.t),
      orderByList: orderByList?.call(DefectEventRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DefectEventRow] matching the given query parameters.
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
  Future<DefectEventRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectEventRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DefectEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DefectEventRow>(
      where: where?.call(DefectEventRow.t),
      orderBy: orderBy?.call(DefectEventRow.t),
      orderByList: orderByList?.call(DefectEventRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DefectEventRow] by its [id] or null if no such row exists.
  Future<DefectEventRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DefectEventRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DefectEventRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DefectEventRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DefectEventRow>> insert(
    _i1.DatabaseSession session,
    List<DefectEventRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DefectEventRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DefectEventRow] and returns the inserted row.
  ///
  /// The returned [DefectEventRow] will have its `id` field set.
  Future<DefectEventRow> insertRow(
    _i1.DatabaseSession session,
    DefectEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DefectEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DefectEventRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DefectEventRow>> update(
    _i1.DatabaseSession session,
    List<DefectEventRow> rows, {
    _i1.ColumnSelections<DefectEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DefectEventRow>(
      rows,
      columns: columns?.call(DefectEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectEventRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DefectEventRow> updateRow(
    _i1.DatabaseSession session,
    DefectEventRow row, {
    _i1.ColumnSelections<DefectEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DefectEventRow>(
      row,
      columns: columns?.call(DefectEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectEventRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DefectEventRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DefectEventRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DefectEventRow>(
      id,
      columnValues: columnValues(DefectEventRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DefectEventRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DefectEventRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DefectEventRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<DefectEventRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectEventRowTable>? orderBy,
    _i1.OrderByListBuilder<DefectEventRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DefectEventRow>(
      columnValues: columnValues(DefectEventRow.t.updateTable),
      where: where(DefectEventRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectEventRow.t),
      orderByList: orderByList?.call(DefectEventRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DefectEventRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DefectEventRow>> delete(
    _i1.DatabaseSession session,
    List<DefectEventRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DefectEventRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DefectEventRow].
  Future<DefectEventRow> deleteRow(
    _i1.DatabaseSession session,
    DefectEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DefectEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DefectEventRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectEventRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DefectEventRow>(
      where: where(DefectEventRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectEventRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DefectEventRow>(
      where: where?.call(DefectEventRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DefectEventRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectEventRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DefectEventRow>(
      where: where(DefectEventRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

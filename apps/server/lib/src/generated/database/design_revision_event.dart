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

abstract class DesignRevisionEventRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DesignRevisionEventRow._({
    this.id,
    required this.eventId,
    required this.designRevisionId,
    required this.eventType,
    required this.payloadJson,
    required this.sequence,
    required this.createdAt,
  });

  factory DesignRevisionEventRow({
    int? id,
    required String eventId,
    required String designRevisionId,
    required String eventType,
    required String payloadJson,
    required int sequence,
    required DateTime createdAt,
  }) = _DesignRevisionEventRowImpl;

  factory DesignRevisionEventRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DesignRevisionEventRow(
      id: jsonSerialization['id'] as int?,
      eventId: jsonSerialization['eventId'] as String,
      designRevisionId: jsonSerialization['designRevisionId'] as String,
      eventType: jsonSerialization['eventType'] as String,
      payloadJson: jsonSerialization['payloadJson'] as String,
      sequence: jsonSerialization['sequence'] as int,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = DesignRevisionEventRowTable();

  static const db = DesignRevisionEventRowRepository._();

  @override
  int? id;

  String eventId;

  String designRevisionId;

  String eventType;

  String payloadJson;

  int sequence;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DesignRevisionEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DesignRevisionEventRow copyWith({
    int? id,
    String? eventId,
    String? designRevisionId,
    String? eventType,
    String? payloadJson,
    int? sequence,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DesignRevisionEventRow',
      if (id != null) 'id': id,
      'eventId': eventId,
      'designRevisionId': designRevisionId,
      'eventType': eventType,
      'payloadJson': payloadJson,
      'sequence': sequence,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DesignRevisionEventRowInclude include() {
    return DesignRevisionEventRowInclude._();
  }

  static DesignRevisionEventRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DesignRevisionEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignRevisionEventRowTable>? orderByList,
    DesignRevisionEventRowInclude? include,
  }) {
    return DesignRevisionEventRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignRevisionEventRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DesignRevisionEventRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DesignRevisionEventRowImpl extends DesignRevisionEventRow {
  _DesignRevisionEventRowImpl({
    int? id,
    required String eventId,
    required String designRevisionId,
    required String eventType,
    required String payloadJson,
    required int sequence,
    required DateTime createdAt,
  }) : super._(
         id: id,
         eventId: eventId,
         designRevisionId: designRevisionId,
         eventType: eventType,
         payloadJson: payloadJson,
         sequence: sequence,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DesignRevisionEventRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DesignRevisionEventRow copyWith({
    Object? id = _Undefined,
    String? eventId,
    String? designRevisionId,
    String? eventType,
    String? payloadJson,
    int? sequence,
    DateTime? createdAt,
  }) {
    return DesignRevisionEventRow(
      id: id is int? ? id : this.id,
      eventId: eventId ?? this.eventId,
      designRevisionId: designRevisionId ?? this.designRevisionId,
      eventType: eventType ?? this.eventType,
      payloadJson: payloadJson ?? this.payloadJson,
      sequence: sequence ?? this.sequence,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DesignRevisionEventRowUpdateTable
    extends _i1.UpdateTable<DesignRevisionEventRowTable> {
  DesignRevisionEventRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> eventId(String value) => _i1.ColumnValue(
    table.eventId,
    value,
  );

  _i1.ColumnValue<String, String> designRevisionId(String value) =>
      _i1.ColumnValue(
        table.designRevisionId,
        value,
      );

  _i1.ColumnValue<String, String> eventType(String value) => _i1.ColumnValue(
    table.eventType,
    value,
  );

  _i1.ColumnValue<String, String> payloadJson(String value) => _i1.ColumnValue(
    table.payloadJson,
    value,
  );

  _i1.ColumnValue<int, int> sequence(int value) => _i1.ColumnValue(
    table.sequence,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class DesignRevisionEventRowTable extends _i1.Table<int?> {
  DesignRevisionEventRowTable({super.tableRelation})
    : super(tableName: 'design_revision_event') {
    updateTable = DesignRevisionEventRowUpdateTable(this);
    eventId = _i1.ColumnString(
      'eventId',
      this,
    );
    designRevisionId = _i1.ColumnString(
      'designRevisionId',
      this,
    );
    eventType = _i1.ColumnString(
      'eventType',
      this,
    );
    payloadJson = _i1.ColumnString(
      'payloadJson',
      this,
    );
    sequence = _i1.ColumnInt(
      'sequence',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final DesignRevisionEventRowUpdateTable updateTable;

  late final _i1.ColumnString eventId;

  late final _i1.ColumnString designRevisionId;

  late final _i1.ColumnString eventType;

  late final _i1.ColumnString payloadJson;

  late final _i1.ColumnInt sequence;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    eventId,
    designRevisionId,
    eventType,
    payloadJson,
    sequence,
    createdAt,
  ];
}

class DesignRevisionEventRowInclude extends _i1.IncludeObject {
  DesignRevisionEventRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DesignRevisionEventRow.t;
}

class DesignRevisionEventRowIncludeList extends _i1.IncludeList {
  DesignRevisionEventRowIncludeList._({
    _i1.WhereExpressionBuilder<DesignRevisionEventRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DesignRevisionEventRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DesignRevisionEventRow.t;
}

class DesignRevisionEventRowRepository {
  const DesignRevisionEventRowRepository._();

  /// Returns a list of [DesignRevisionEventRow]s matching the given query parameters.
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
  Future<List<DesignRevisionEventRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignRevisionEventRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignRevisionEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DesignRevisionEventRow>(
      where: where?.call(DesignRevisionEventRow.t),
      orderBy: orderBy?.call(DesignRevisionEventRow.t),
      orderByList: orderByList?.call(DesignRevisionEventRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DesignRevisionEventRow] matching the given query parameters.
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
  Future<DesignRevisionEventRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignRevisionEventRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionEventRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignRevisionEventRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DesignRevisionEventRow>(
      where: where?.call(DesignRevisionEventRow.t),
      orderBy: orderBy?.call(DesignRevisionEventRow.t),
      orderByList: orderByList?.call(DesignRevisionEventRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DesignRevisionEventRow] by its [id] or null if no such row exists.
  Future<DesignRevisionEventRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DesignRevisionEventRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DesignRevisionEventRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DesignRevisionEventRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DesignRevisionEventRow>> insert(
    _i1.DatabaseSession session,
    List<DesignRevisionEventRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DesignRevisionEventRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DesignRevisionEventRow] and returns the inserted row.
  ///
  /// The returned [DesignRevisionEventRow] will have its `id` field set.
  Future<DesignRevisionEventRow> insertRow(
    _i1.DatabaseSession session,
    DesignRevisionEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DesignRevisionEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DesignRevisionEventRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DesignRevisionEventRow>> update(
    _i1.DatabaseSession session,
    List<DesignRevisionEventRow> rows, {
    _i1.ColumnSelections<DesignRevisionEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DesignRevisionEventRow>(
      rows,
      columns: columns?.call(DesignRevisionEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignRevisionEventRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DesignRevisionEventRow> updateRow(
    _i1.DatabaseSession session,
    DesignRevisionEventRow row, {
    _i1.ColumnSelections<DesignRevisionEventRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DesignRevisionEventRow>(
      row,
      columns: columns?.call(DesignRevisionEventRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignRevisionEventRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DesignRevisionEventRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DesignRevisionEventRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DesignRevisionEventRow>(
      id,
      columnValues: columnValues(DesignRevisionEventRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DesignRevisionEventRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DesignRevisionEventRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DesignRevisionEventRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DesignRevisionEventRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionEventRowTable>? orderBy,
    _i1.OrderByListBuilder<DesignRevisionEventRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DesignRevisionEventRow>(
      columnValues: columnValues(DesignRevisionEventRow.t.updateTable),
      where: where(DesignRevisionEventRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignRevisionEventRow.t),
      orderByList: orderByList?.call(DesignRevisionEventRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DesignRevisionEventRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DesignRevisionEventRow>> delete(
    _i1.DatabaseSession session,
    List<DesignRevisionEventRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DesignRevisionEventRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DesignRevisionEventRow].
  Future<DesignRevisionEventRow> deleteRow(
    _i1.DatabaseSession session,
    DesignRevisionEventRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DesignRevisionEventRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DesignRevisionEventRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignRevisionEventRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DesignRevisionEventRow>(
      where: where(DesignRevisionEventRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignRevisionEventRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DesignRevisionEventRow>(
      where: where?.call(DesignRevisionEventRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DesignRevisionEventRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignRevisionEventRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DesignRevisionEventRow>(
      where: where(DesignRevisionEventRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

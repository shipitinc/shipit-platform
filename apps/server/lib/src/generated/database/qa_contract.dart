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

abstract class QAContractRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  QAContractRow._({
    this.id,
    required this.contractId,
    required this.workItemCategory,
    required this.gatesJson,
    required this.version,
    this.passCriteriaJson,
    required this.createdAt,
    required this.updatedAt,
    this.evidenceRowsJson,
    this.metadataJson,
  });

  factory QAContractRow({
    int? id,
    required String contractId,
    required String workItemCategory,
    required String gatesJson,
    required String version,
    String? passCriteriaJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? evidenceRowsJson,
    String? metadataJson,
  }) = _QAContractRowImpl;

  factory QAContractRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return QAContractRow(
      id: jsonSerialization['id'] as int?,
      contractId: jsonSerialization['contractId'] as String,
      workItemCategory: jsonSerialization['workItemCategory'] as String,
      gatesJson: jsonSerialization['gatesJson'] as String,
      version: jsonSerialization['version'] as String,
      passCriteriaJson: jsonSerialization['passCriteriaJson'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      evidenceRowsJson: jsonSerialization['evidenceRowsJson'] as String?,
      metadataJson: jsonSerialization['metadataJson'] as String?,
    );
  }

  static final t = QAContractRowTable();

  static const db = QAContractRowRepository._();

  @override
  int? id;

  String contractId;

  String workItemCategory;

  String gatesJson;

  String version;

  String? passCriteriaJson;

  DateTime createdAt;

  DateTime updatedAt;

  String? evidenceRowsJson;

  String? metadataJson;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [QAContractRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  QAContractRow copyWith({
    int? id,
    String? contractId,
    String? workItemCategory,
    String? gatesJson,
    String? version,
    String? passCriteriaJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? evidenceRowsJson,
    String? metadataJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'QAContractRow',
      if (id != null) 'id': id,
      'contractId': contractId,
      'workItemCategory': workItemCategory,
      'gatesJson': gatesJson,
      'version': version,
      if (passCriteriaJson != null) 'passCriteriaJson': passCriteriaJson,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (evidenceRowsJson != null) 'evidenceRowsJson': evidenceRowsJson,
      if (metadataJson != null) 'metadataJson': metadataJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static QAContractRowInclude include() {
    return QAContractRowInclude._();
  }

  static QAContractRowIncludeList includeList({
    _i1.WhereExpressionBuilder<QAContractRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<QAContractRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<QAContractRowTable>? orderByList,
    QAContractRowInclude? include,
  }) {
    return QAContractRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(QAContractRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(QAContractRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _QAContractRowImpl extends QAContractRow {
  _QAContractRowImpl({
    int? id,
    required String contractId,
    required String workItemCategory,
    required String gatesJson,
    required String version,
    String? passCriteriaJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? evidenceRowsJson,
    String? metadataJson,
  }) : super._(
         id: id,
         contractId: contractId,
         workItemCategory: workItemCategory,
         gatesJson: gatesJson,
         version: version,
         passCriteriaJson: passCriteriaJson,
         createdAt: createdAt,
         updatedAt: updatedAt,
         evidenceRowsJson: evidenceRowsJson,
         metadataJson: metadataJson,
       );

  /// Returns a shallow copy of this [QAContractRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  QAContractRow copyWith({
    Object? id = _Undefined,
    String? contractId,
    String? workItemCategory,
    String? gatesJson,
    String? version,
    Object? passCriteriaJson = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? evidenceRowsJson = _Undefined,
    Object? metadataJson = _Undefined,
  }) {
    return QAContractRow(
      id: id is int? ? id : this.id,
      contractId: contractId ?? this.contractId,
      workItemCategory: workItemCategory ?? this.workItemCategory,
      gatesJson: gatesJson ?? this.gatesJson,
      version: version ?? this.version,
      passCriteriaJson: passCriteriaJson is String?
          ? passCriteriaJson
          : this.passCriteriaJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      evidenceRowsJson: evidenceRowsJson is String?
          ? evidenceRowsJson
          : this.evidenceRowsJson,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
    );
  }
}

class QAContractRowUpdateTable extends _i1.UpdateTable<QAContractRowTable> {
  QAContractRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> contractId(String value) => _i1.ColumnValue(
    table.contractId,
    value,
  );

  _i1.ColumnValue<String, String> workItemCategory(String value) =>
      _i1.ColumnValue(
        table.workItemCategory,
        value,
      );

  _i1.ColumnValue<String, String> gatesJson(String value) => _i1.ColumnValue(
    table.gatesJson,
    value,
  );

  _i1.ColumnValue<String, String> version(String value) => _i1.ColumnValue(
    table.version,
    value,
  );

  _i1.ColumnValue<String, String> passCriteriaJson(String? value) =>
      _i1.ColumnValue(
        table.passCriteriaJson,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );

  _i1.ColumnValue<String, String> evidenceRowsJson(String? value) =>
      _i1.ColumnValue(
        table.evidenceRowsJson,
        value,
      );

  _i1.ColumnValue<String, String> metadataJson(String? value) =>
      _i1.ColumnValue(
        table.metadataJson,
        value,
      );
}

class QAContractRowTable extends _i1.Table<int?> {
  QAContractRowTable({super.tableRelation}) : super(tableName: 'qa_contract') {
    updateTable = QAContractRowUpdateTable(this);
    contractId = _i1.ColumnString(
      'contractId',
      this,
    );
    workItemCategory = _i1.ColumnString(
      'workItemCategory',
      this,
    );
    gatesJson = _i1.ColumnString(
      'gatesJson',
      this,
    );
    version = _i1.ColumnString(
      'version',
      this,
    );
    passCriteriaJson = _i1.ColumnString(
      'passCriteriaJson',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
    evidenceRowsJson = _i1.ColumnString(
      'evidenceRowsJson',
      this,
    );
    metadataJson = _i1.ColumnString(
      'metadataJson',
      this,
    );
  }

  late final QAContractRowUpdateTable updateTable;

  late final _i1.ColumnString contractId;

  late final _i1.ColumnString workItemCategory;

  late final _i1.ColumnString gatesJson;

  late final _i1.ColumnString version;

  late final _i1.ColumnString passCriteriaJson;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnString evidenceRowsJson;

  late final _i1.ColumnString metadataJson;

  @override
  List<_i1.Column> get columns => [
    id,
    contractId,
    workItemCategory,
    gatesJson,
    version,
    passCriteriaJson,
    createdAt,
    updatedAt,
    evidenceRowsJson,
    metadataJson,
  ];
}

class QAContractRowInclude extends _i1.IncludeObject {
  QAContractRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => QAContractRow.t;
}

class QAContractRowIncludeList extends _i1.IncludeList {
  QAContractRowIncludeList._({
    _i1.WhereExpressionBuilder<QAContractRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(QAContractRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => QAContractRow.t;
}

class QAContractRowRepository {
  const QAContractRowRepository._();

  /// Returns a list of [QAContractRow]s matching the given query parameters.
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
  Future<List<QAContractRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<QAContractRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<QAContractRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<QAContractRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<QAContractRow>(
      where: where?.call(QAContractRow.t),
      orderBy: orderBy?.call(QAContractRow.t),
      orderByList: orderByList?.call(QAContractRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [QAContractRow] matching the given query parameters.
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
  Future<QAContractRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<QAContractRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<QAContractRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<QAContractRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<QAContractRow>(
      where: where?.call(QAContractRow.t),
      orderBy: orderBy?.call(QAContractRow.t),
      orderByList: orderByList?.call(QAContractRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [QAContractRow] by its [id] or null if no such row exists.
  Future<QAContractRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<QAContractRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [QAContractRow]s in the list and returns the inserted rows.
  ///
  /// The returned [QAContractRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<QAContractRow>> insert(
    _i1.DatabaseSession session,
    List<QAContractRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<QAContractRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [QAContractRow] and returns the inserted row.
  ///
  /// The returned [QAContractRow] will have its `id` field set.
  Future<QAContractRow> insertRow(
    _i1.DatabaseSession session,
    QAContractRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<QAContractRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [QAContractRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<QAContractRow>> update(
    _i1.DatabaseSession session,
    List<QAContractRow> rows, {
    _i1.ColumnSelections<QAContractRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<QAContractRow>(
      rows,
      columns: columns?.call(QAContractRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [QAContractRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<QAContractRow> updateRow(
    _i1.DatabaseSession session,
    QAContractRow row, {
    _i1.ColumnSelections<QAContractRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<QAContractRow>(
      row,
      columns: columns?.call(QAContractRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [QAContractRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<QAContractRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<QAContractRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<QAContractRow>(
      id,
      columnValues: columnValues(QAContractRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [QAContractRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<QAContractRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<QAContractRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<QAContractRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<QAContractRowTable>? orderBy,
    _i1.OrderByListBuilder<QAContractRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<QAContractRow>(
      columnValues: columnValues(QAContractRow.t.updateTable),
      where: where(QAContractRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(QAContractRow.t),
      orderByList: orderByList?.call(QAContractRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [QAContractRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<QAContractRow>> delete(
    _i1.DatabaseSession session,
    List<QAContractRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<QAContractRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [QAContractRow].
  Future<QAContractRow> deleteRow(
    _i1.DatabaseSession session,
    QAContractRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<QAContractRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<QAContractRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<QAContractRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<QAContractRow>(
      where: where(QAContractRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<QAContractRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<QAContractRow>(
      where: where?.call(QAContractRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [QAContractRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<QAContractRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<QAContractRow>(
      where: where(QAContractRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

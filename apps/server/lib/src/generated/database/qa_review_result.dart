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

abstract class QaReviewResultRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  QaReviewResultRow._({
    this.id,
    required this.reviewExecutionId,
    required this.revisionId,
    required this.verdict,
    required this.findingsJson,
    required this.assessedDimensionsJson,
    this.reviewScopeJson,
    required this.createdAt,
    required this.version,
  });

  factory QaReviewResultRow({
    int? id,
    required String reviewExecutionId,
    required String revisionId,
    required String verdict,
    required String findingsJson,
    required String assessedDimensionsJson,
    String? reviewScopeJson,
    required DateTime createdAt,
    required int version,
  }) = _QaReviewResultRowImpl;

  factory QaReviewResultRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return QaReviewResultRow(
      id: jsonSerialization['id'] as int?,
      reviewExecutionId: jsonSerialization['reviewExecutionId'] as String,
      revisionId: jsonSerialization['revisionId'] as String,
      verdict: jsonSerialization['verdict'] as String,
      findingsJson: jsonSerialization['findingsJson'] as String,
      assessedDimensionsJson:
          jsonSerialization['assessedDimensionsJson'] as String,
      reviewScopeJson: jsonSerialization['reviewScopeJson'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = QaReviewResultRowTable();

  static const db = QaReviewResultRowRepository._();

  @override
  int? id;

  String reviewExecutionId;

  String revisionId;

  String verdict;

  String findingsJson;

  String assessedDimensionsJson;

  String? reviewScopeJson;

  DateTime createdAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [QaReviewResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  QaReviewResultRow copyWith({
    int? id,
    String? reviewExecutionId,
    String? revisionId,
    String? verdict,
    String? findingsJson,
    String? assessedDimensionsJson,
    String? reviewScopeJson,
    DateTime? createdAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'QaReviewResultRow',
      if (id != null) 'id': id,
      'reviewExecutionId': reviewExecutionId,
      'revisionId': revisionId,
      'verdict': verdict,
      'findingsJson': findingsJson,
      'assessedDimensionsJson': assessedDimensionsJson,
      if (reviewScopeJson != null) 'reviewScopeJson': reviewScopeJson,
      'createdAt': createdAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static QaReviewResultRowInclude include() {
    return QaReviewResultRowInclude._();
  }

  static QaReviewResultRowIncludeList includeList({
    _i1.WhereExpressionBuilder<QaReviewResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<QaReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<QaReviewResultRowTable>? orderByList,
    QaReviewResultRowInclude? include,
  }) {
    return QaReviewResultRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(QaReviewResultRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(QaReviewResultRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _QaReviewResultRowImpl extends QaReviewResultRow {
  _QaReviewResultRowImpl({
    int? id,
    required String reviewExecutionId,
    required String revisionId,
    required String verdict,
    required String findingsJson,
    required String assessedDimensionsJson,
    String? reviewScopeJson,
    required DateTime createdAt,
    required int version,
  }) : super._(
         id: id,
         reviewExecutionId: reviewExecutionId,
         revisionId: revisionId,
         verdict: verdict,
         findingsJson: findingsJson,
         assessedDimensionsJson: assessedDimensionsJson,
         reviewScopeJson: reviewScopeJson,
         createdAt: createdAt,
         version: version,
       );

  /// Returns a shallow copy of this [QaReviewResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  QaReviewResultRow copyWith({
    Object? id = _Undefined,
    String? reviewExecutionId,
    String? revisionId,
    String? verdict,
    String? findingsJson,
    String? assessedDimensionsJson,
    Object? reviewScopeJson = _Undefined,
    DateTime? createdAt,
    int? version,
  }) {
    return QaReviewResultRow(
      id: id is int? ? id : this.id,
      reviewExecutionId: reviewExecutionId ?? this.reviewExecutionId,
      revisionId: revisionId ?? this.revisionId,
      verdict: verdict ?? this.verdict,
      findingsJson: findingsJson ?? this.findingsJson,
      assessedDimensionsJson:
          assessedDimensionsJson ?? this.assessedDimensionsJson,
      reviewScopeJson: reviewScopeJson is String?
          ? reviewScopeJson
          : this.reviewScopeJson,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
    );
  }
}

class QaReviewResultRowUpdateTable
    extends _i1.UpdateTable<QaReviewResultRowTable> {
  QaReviewResultRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> reviewExecutionId(String value) =>
      _i1.ColumnValue(
        table.reviewExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> revisionId(String value) => _i1.ColumnValue(
    table.revisionId,
    value,
  );

  _i1.ColumnValue<String, String> verdict(String value) => _i1.ColumnValue(
    table.verdict,
    value,
  );

  _i1.ColumnValue<String, String> findingsJson(String value) => _i1.ColumnValue(
    table.findingsJson,
    value,
  );

  _i1.ColumnValue<String, String> assessedDimensionsJson(String value) =>
      _i1.ColumnValue(
        table.assessedDimensionsJson,
        value,
      );

  _i1.ColumnValue<String, String> reviewScopeJson(String? value) =>
      _i1.ColumnValue(
        table.reviewScopeJson,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class QaReviewResultRowTable extends _i1.Table<int?> {
  QaReviewResultRowTable({super.tableRelation})
    : super(tableName: 'qa_review_result') {
    updateTable = QaReviewResultRowUpdateTable(this);
    reviewExecutionId = _i1.ColumnString(
      'reviewExecutionId',
      this,
    );
    revisionId = _i1.ColumnString(
      'revisionId',
      this,
    );
    verdict = _i1.ColumnString(
      'verdict',
      this,
    );
    findingsJson = _i1.ColumnString(
      'findingsJson',
      this,
    );
    assessedDimensionsJson = _i1.ColumnString(
      'assessedDimensionsJson',
      this,
    );
    reviewScopeJson = _i1.ColumnString(
      'reviewScopeJson',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final QaReviewResultRowUpdateTable updateTable;

  late final _i1.ColumnString reviewExecutionId;

  late final _i1.ColumnString revisionId;

  late final _i1.ColumnString verdict;

  late final _i1.ColumnString findingsJson;

  late final _i1.ColumnString assessedDimensionsJson;

  late final _i1.ColumnString reviewScopeJson;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    reviewExecutionId,
    revisionId,
    verdict,
    findingsJson,
    assessedDimensionsJson,
    reviewScopeJson,
    createdAt,
    version,
  ];
}

class QaReviewResultRowInclude extends _i1.IncludeObject {
  QaReviewResultRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => QaReviewResultRow.t;
}

class QaReviewResultRowIncludeList extends _i1.IncludeList {
  QaReviewResultRowIncludeList._({
    _i1.WhereExpressionBuilder<QaReviewResultRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(QaReviewResultRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => QaReviewResultRow.t;
}

class QaReviewResultRowRepository {
  const QaReviewResultRowRepository._();

  /// Returns a list of [QaReviewResultRow]s matching the given query parameters.
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
  Future<List<QaReviewResultRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<QaReviewResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<QaReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<QaReviewResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<QaReviewResultRow>(
      where: where?.call(QaReviewResultRow.t),
      orderBy: orderBy?.call(QaReviewResultRow.t),
      orderByList: orderByList?.call(QaReviewResultRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [QaReviewResultRow] matching the given query parameters.
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
  Future<QaReviewResultRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<QaReviewResultRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<QaReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<QaReviewResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<QaReviewResultRow>(
      where: where?.call(QaReviewResultRow.t),
      orderBy: orderBy?.call(QaReviewResultRow.t),
      orderByList: orderByList?.call(QaReviewResultRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [QaReviewResultRow] by its [id] or null if no such row exists.
  Future<QaReviewResultRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<QaReviewResultRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [QaReviewResultRow]s in the list and returns the inserted rows.
  ///
  /// The returned [QaReviewResultRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<QaReviewResultRow>> insert(
    _i1.DatabaseSession session,
    List<QaReviewResultRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<QaReviewResultRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [QaReviewResultRow] and returns the inserted row.
  ///
  /// The returned [QaReviewResultRow] will have its `id` field set.
  Future<QaReviewResultRow> insertRow(
    _i1.DatabaseSession session,
    QaReviewResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<QaReviewResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [QaReviewResultRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<QaReviewResultRow>> update(
    _i1.DatabaseSession session,
    List<QaReviewResultRow> rows, {
    _i1.ColumnSelections<QaReviewResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<QaReviewResultRow>(
      rows,
      columns: columns?.call(QaReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [QaReviewResultRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<QaReviewResultRow> updateRow(
    _i1.DatabaseSession session,
    QaReviewResultRow row, {
    _i1.ColumnSelections<QaReviewResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<QaReviewResultRow>(
      row,
      columns: columns?.call(QaReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [QaReviewResultRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<QaReviewResultRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<QaReviewResultRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<QaReviewResultRow>(
      id,
      columnValues: columnValues(QaReviewResultRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [QaReviewResultRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<QaReviewResultRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<QaReviewResultRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<QaReviewResultRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<QaReviewResultRowTable>? orderBy,
    _i1.OrderByListBuilder<QaReviewResultRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<QaReviewResultRow>(
      columnValues: columnValues(QaReviewResultRow.t.updateTable),
      where: where(QaReviewResultRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(QaReviewResultRow.t),
      orderByList: orderByList?.call(QaReviewResultRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [QaReviewResultRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<QaReviewResultRow>> delete(
    _i1.DatabaseSession session,
    List<QaReviewResultRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<QaReviewResultRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [QaReviewResultRow].
  Future<QaReviewResultRow> deleteRow(
    _i1.DatabaseSession session,
    QaReviewResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<QaReviewResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<QaReviewResultRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<QaReviewResultRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<QaReviewResultRow>(
      where: where(QaReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<QaReviewResultRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<QaReviewResultRow>(
      where: where?.call(QaReviewResultRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [QaReviewResultRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<QaReviewResultRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<QaReviewResultRow>(
      where: where(QaReviewResultRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

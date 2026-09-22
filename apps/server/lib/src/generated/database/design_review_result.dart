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

abstract class DesignReviewResultRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DesignReviewResultRow._({
    this.id,
    required this.reviewResultId,
    required this.revisionId,
    required this.reviewExecutionId,
    required this.verdict,
    required this.findingsJson,
    required this.assessedDimensionsJson,
    this.reviewScopeJson,
    required this.createdAt,
    required this.version,
  });

  factory DesignReviewResultRow({
    int? id,
    required String reviewResultId,
    required String revisionId,
    required String reviewExecutionId,
    required String verdict,
    required String findingsJson,
    required String assessedDimensionsJson,
    String? reviewScopeJson,
    required DateTime createdAt,
    required int version,
  }) = _DesignReviewResultRowImpl;

  factory DesignReviewResultRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DesignReviewResultRow(
      id: jsonSerialization['id'] as int?,
      reviewResultId: jsonSerialization['reviewResultId'] as String,
      revisionId: jsonSerialization['revisionId'] as String,
      reviewExecutionId: jsonSerialization['reviewExecutionId'] as String,
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

  static final t = DesignReviewResultRowTable();

  static const db = DesignReviewResultRowRepository._();

  @override
  int? id;

  String reviewResultId;

  String revisionId;

  String reviewExecutionId;

  String verdict;

  String findingsJson;

  String assessedDimensionsJson;

  String? reviewScopeJson;

  DateTime createdAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DesignReviewResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DesignReviewResultRow copyWith({
    int? id,
    String? reviewResultId,
    String? revisionId,
    String? reviewExecutionId,
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
      '__className__': 'DesignReviewResultRow',
      if (id != null) 'id': id,
      'reviewResultId': reviewResultId,
      'revisionId': revisionId,
      'reviewExecutionId': reviewExecutionId,
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

  static DesignReviewResultRowInclude include() {
    return DesignReviewResultRowInclude._();
  }

  static DesignReviewResultRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DesignReviewResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignReviewResultRowTable>? orderByList,
    DesignReviewResultRowInclude? include,
  }) {
    return DesignReviewResultRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignReviewResultRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DesignReviewResultRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DesignReviewResultRowImpl extends DesignReviewResultRow {
  _DesignReviewResultRowImpl({
    int? id,
    required String reviewResultId,
    required String revisionId,
    required String reviewExecutionId,
    required String verdict,
    required String findingsJson,
    required String assessedDimensionsJson,
    String? reviewScopeJson,
    required DateTime createdAt,
    required int version,
  }) : super._(
         id: id,
         reviewResultId: reviewResultId,
         revisionId: revisionId,
         reviewExecutionId: reviewExecutionId,
         verdict: verdict,
         findingsJson: findingsJson,
         assessedDimensionsJson: assessedDimensionsJson,
         reviewScopeJson: reviewScopeJson,
         createdAt: createdAt,
         version: version,
       );

  /// Returns a shallow copy of this [DesignReviewResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DesignReviewResultRow copyWith({
    Object? id = _Undefined,
    String? reviewResultId,
    String? revisionId,
    String? reviewExecutionId,
    String? verdict,
    String? findingsJson,
    String? assessedDimensionsJson,
    Object? reviewScopeJson = _Undefined,
    DateTime? createdAt,
    int? version,
  }) {
    return DesignReviewResultRow(
      id: id is int? ? id : this.id,
      reviewResultId: reviewResultId ?? this.reviewResultId,
      revisionId: revisionId ?? this.revisionId,
      reviewExecutionId: reviewExecutionId ?? this.reviewExecutionId,
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

class DesignReviewResultRowUpdateTable
    extends _i1.UpdateTable<DesignReviewResultRowTable> {
  DesignReviewResultRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> reviewResultId(String value) =>
      _i1.ColumnValue(
        table.reviewResultId,
        value,
      );

  _i1.ColumnValue<String, String> revisionId(String value) => _i1.ColumnValue(
    table.revisionId,
    value,
  );

  _i1.ColumnValue<String, String> reviewExecutionId(String value) =>
      _i1.ColumnValue(
        table.reviewExecutionId,
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

class DesignReviewResultRowTable extends _i1.Table<int?> {
  DesignReviewResultRowTable({super.tableRelation})
    : super(tableName: 'design_review_result') {
    updateTable = DesignReviewResultRowUpdateTable(this);
    reviewResultId = _i1.ColumnString(
      'reviewResultId',
      this,
    );
    revisionId = _i1.ColumnString(
      'revisionId',
      this,
    );
    reviewExecutionId = _i1.ColumnString(
      'reviewExecutionId',
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

  late final DesignReviewResultRowUpdateTable updateTable;

  late final _i1.ColumnString reviewResultId;

  late final _i1.ColumnString revisionId;

  late final _i1.ColumnString reviewExecutionId;

  late final _i1.ColumnString verdict;

  late final _i1.ColumnString findingsJson;

  late final _i1.ColumnString assessedDimensionsJson;

  late final _i1.ColumnString reviewScopeJson;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    reviewResultId,
    revisionId,
    reviewExecutionId,
    verdict,
    findingsJson,
    assessedDimensionsJson,
    reviewScopeJson,
    createdAt,
    version,
  ];
}

class DesignReviewResultRowInclude extends _i1.IncludeObject {
  DesignReviewResultRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DesignReviewResultRow.t;
}

class DesignReviewResultRowIncludeList extends _i1.IncludeList {
  DesignReviewResultRowIncludeList._({
    _i1.WhereExpressionBuilder<DesignReviewResultRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DesignReviewResultRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DesignReviewResultRow.t;
}

class DesignReviewResultRowRepository {
  const DesignReviewResultRowRepository._();

  /// Returns a list of [DesignReviewResultRow]s matching the given query parameters.
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
  Future<List<DesignReviewResultRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignReviewResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignReviewResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DesignReviewResultRow>(
      where: where?.call(DesignReviewResultRow.t),
      orderBy: orderBy?.call(DesignReviewResultRow.t),
      orderByList: orderByList?.call(DesignReviewResultRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DesignReviewResultRow] matching the given query parameters.
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
  Future<DesignReviewResultRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignReviewResultRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DesignReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignReviewResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DesignReviewResultRow>(
      where: where?.call(DesignReviewResultRow.t),
      orderBy: orderBy?.call(DesignReviewResultRow.t),
      orderByList: orderByList?.call(DesignReviewResultRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DesignReviewResultRow] by its [id] or null if no such row exists.
  Future<DesignReviewResultRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DesignReviewResultRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DesignReviewResultRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DesignReviewResultRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DesignReviewResultRow>> insert(
    _i1.DatabaseSession session,
    List<DesignReviewResultRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DesignReviewResultRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DesignReviewResultRow] and returns the inserted row.
  ///
  /// The returned [DesignReviewResultRow] will have its `id` field set.
  Future<DesignReviewResultRow> insertRow(
    _i1.DatabaseSession session,
    DesignReviewResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DesignReviewResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DesignReviewResultRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DesignReviewResultRow>> update(
    _i1.DatabaseSession session,
    List<DesignReviewResultRow> rows, {
    _i1.ColumnSelections<DesignReviewResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DesignReviewResultRow>(
      rows,
      columns: columns?.call(DesignReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignReviewResultRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DesignReviewResultRow> updateRow(
    _i1.DatabaseSession session,
    DesignReviewResultRow row, {
    _i1.ColumnSelections<DesignReviewResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DesignReviewResultRow>(
      row,
      columns: columns?.call(DesignReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignReviewResultRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DesignReviewResultRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DesignReviewResultRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DesignReviewResultRow>(
      id,
      columnValues: columnValues(DesignReviewResultRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DesignReviewResultRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DesignReviewResultRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DesignReviewResultRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DesignReviewResultRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignReviewResultRowTable>? orderBy,
    _i1.OrderByListBuilder<DesignReviewResultRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DesignReviewResultRow>(
      columnValues: columnValues(DesignReviewResultRow.t.updateTable),
      where: where(DesignReviewResultRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignReviewResultRow.t),
      orderByList: orderByList?.call(DesignReviewResultRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DesignReviewResultRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DesignReviewResultRow>> delete(
    _i1.DatabaseSession session,
    List<DesignReviewResultRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DesignReviewResultRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DesignReviewResultRow].
  Future<DesignReviewResultRow> deleteRow(
    _i1.DatabaseSession session,
    DesignReviewResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DesignReviewResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DesignReviewResultRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignReviewResultRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DesignReviewResultRow>(
      where: where(DesignReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignReviewResultRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DesignReviewResultRow>(
      where: where?.call(DesignReviewResultRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DesignReviewResultRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignReviewResultRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DesignReviewResultRow>(
      where: where(DesignReviewResultRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

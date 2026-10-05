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

abstract class EngineeringReviewResultRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  EngineeringReviewResultRow._({
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

  factory EngineeringReviewResultRow({
    int? id,
    required String reviewExecutionId,
    required String revisionId,
    required String verdict,
    required String findingsJson,
    required String assessedDimensionsJson,
    String? reviewScopeJson,
    required DateTime createdAt,
    required int version,
  }) = _EngineeringReviewResultRowImpl;

  factory EngineeringReviewResultRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return EngineeringReviewResultRow(
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

  static final t = EngineeringReviewResultRowTable();

  static const db = EngineeringReviewResultRowRepository._();

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

  /// Returns a shallow copy of this [EngineeringReviewResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  EngineeringReviewResultRow copyWith({
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
      '__className__': 'EngineeringReviewResultRow',
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

  static EngineeringReviewResultRowInclude include() {
    return EngineeringReviewResultRowInclude._();
  }

  static EngineeringReviewResultRowIncludeList includeList({
    _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EngineeringReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EngineeringReviewResultRowTable>? orderByList,
    EngineeringReviewResultRowInclude? include,
  }) {
    return EngineeringReviewResultRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EngineeringReviewResultRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(EngineeringReviewResultRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EngineeringReviewResultRowImpl extends EngineeringReviewResultRow {
  _EngineeringReviewResultRowImpl({
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

  /// Returns a shallow copy of this [EngineeringReviewResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  EngineeringReviewResultRow copyWith({
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
    return EngineeringReviewResultRow(
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

class EngineeringReviewResultRowUpdateTable
    extends _i1.UpdateTable<EngineeringReviewResultRowTable> {
  EngineeringReviewResultRowUpdateTable(super.table);

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

class EngineeringReviewResultRowTable extends _i1.Table<int?> {
  EngineeringReviewResultRowTable({super.tableRelation})
    : super(tableName: 'engineering_review_result') {
    updateTable = EngineeringReviewResultRowUpdateTable(this);
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

  late final EngineeringReviewResultRowUpdateTable updateTable;

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

class EngineeringReviewResultRowInclude extends _i1.IncludeObject {
  EngineeringReviewResultRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => EngineeringReviewResultRow.t;
}

class EngineeringReviewResultRowIncludeList extends _i1.IncludeList {
  EngineeringReviewResultRowIncludeList._({
    _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EngineeringReviewResultRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => EngineeringReviewResultRow.t;
}

class EngineeringReviewResultRowRepository {
  const EngineeringReviewResultRowRepository._();

  /// Returns a list of [EngineeringReviewResultRow]s matching the given query parameters.
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
  Future<List<EngineeringReviewResultRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EngineeringReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EngineeringReviewResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<EngineeringReviewResultRow>(
      where: where?.call(EngineeringReviewResultRow.t),
      orderBy: orderBy?.call(EngineeringReviewResultRow.t),
      orderByList: orderByList?.call(EngineeringReviewResultRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [EngineeringReviewResultRow] matching the given query parameters.
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
  Future<EngineeringReviewResultRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<EngineeringReviewResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EngineeringReviewResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<EngineeringReviewResultRow>(
      where: where?.call(EngineeringReviewResultRow.t),
      orderBy: orderBy?.call(EngineeringReviewResultRow.t),
      orderByList: orderByList?.call(EngineeringReviewResultRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [EngineeringReviewResultRow] by its [id] or null if no such row exists.
  Future<EngineeringReviewResultRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<EngineeringReviewResultRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [EngineeringReviewResultRow]s in the list and returns the inserted rows.
  ///
  /// The returned [EngineeringReviewResultRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<EngineeringReviewResultRow>> insert(
    _i1.DatabaseSession session,
    List<EngineeringReviewResultRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<EngineeringReviewResultRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [EngineeringReviewResultRow] and returns the inserted row.
  ///
  /// The returned [EngineeringReviewResultRow] will have its `id` field set.
  Future<EngineeringReviewResultRow> insertRow(
    _i1.DatabaseSession session,
    EngineeringReviewResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<EngineeringReviewResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [EngineeringReviewResultRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<EngineeringReviewResultRow>> update(
    _i1.DatabaseSession session,
    List<EngineeringReviewResultRow> rows, {
    _i1.ColumnSelections<EngineeringReviewResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<EngineeringReviewResultRow>(
      rows,
      columns: columns?.call(EngineeringReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EngineeringReviewResultRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EngineeringReviewResultRow> updateRow(
    _i1.DatabaseSession session,
    EngineeringReviewResultRow row, {
    _i1.ColumnSelections<EngineeringReviewResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<EngineeringReviewResultRow>(
      row,
      columns: columns?.call(EngineeringReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EngineeringReviewResultRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<EngineeringReviewResultRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<EngineeringReviewResultRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<EngineeringReviewResultRow>(
      id,
      columnValues: columnValues(EngineeringReviewResultRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EngineeringReviewResultRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<EngineeringReviewResultRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<EngineeringReviewResultRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EngineeringReviewResultRowTable>? orderBy,
    _i1.OrderByListBuilder<EngineeringReviewResultRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<EngineeringReviewResultRow>(
      columnValues: columnValues(EngineeringReviewResultRow.t.updateTable),
      where: where(EngineeringReviewResultRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EngineeringReviewResultRow.t),
      orderByList: orderByList?.call(EngineeringReviewResultRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [EngineeringReviewResultRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<EngineeringReviewResultRow>> delete(
    _i1.DatabaseSession session,
    List<EngineeringReviewResultRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<EngineeringReviewResultRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [EngineeringReviewResultRow].
  Future<EngineeringReviewResultRow> deleteRow(
    _i1.DatabaseSession session,
    EngineeringReviewResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EngineeringReviewResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<EngineeringReviewResultRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<EngineeringReviewResultRow>(
      where: where(EngineeringReviewResultRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<EngineeringReviewResultRow>(
      where: where?.call(EngineeringReviewResultRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [EngineeringReviewResultRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<EngineeringReviewResultRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<EngineeringReviewResultRow>(
      where: where(EngineeringReviewResultRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

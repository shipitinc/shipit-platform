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

abstract class DesignFindingRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DesignFindingRow._({
    this.id,
    required this.findingId,
    required this.revisionId,
    required this.reviewExecutionId,
    required this.category,
    required this.severity,
    required this.dimension,
    required this.evidence,
    required this.requiredCorrection,
    required this.affectedSurface,
    this.resolvedByRevisionId,
    required this.createdAt,
    required this.version,
  });

  factory DesignFindingRow({
    int? id,
    required String findingId,
    required String revisionId,
    required String reviewExecutionId,
    required String category,
    required String severity,
    required String dimension,
    required String evidence,
    required String requiredCorrection,
    required String affectedSurface,
    String? resolvedByRevisionId,
    required DateTime createdAt,
    required int version,
  }) = _DesignFindingRowImpl;

  factory DesignFindingRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return DesignFindingRow(
      id: jsonSerialization['id'] as int?,
      findingId: jsonSerialization['findingId'] as String,
      revisionId: jsonSerialization['revisionId'] as String,
      reviewExecutionId: jsonSerialization['reviewExecutionId'] as String,
      category: jsonSerialization['category'] as String,
      severity: jsonSerialization['severity'] as String,
      dimension: jsonSerialization['dimension'] as String,
      evidence: jsonSerialization['evidence'] as String,
      requiredCorrection: jsonSerialization['requiredCorrection'] as String,
      affectedSurface: jsonSerialization['affectedSurface'] as String,
      resolvedByRevisionId:
          jsonSerialization['resolvedByRevisionId'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = DesignFindingRowTable();

  static const db = DesignFindingRowRepository._();

  @override
  int? id;

  String findingId;

  String revisionId;

  String reviewExecutionId;

  String category;

  String severity;

  String dimension;

  String evidence;

  String requiredCorrection;

  String affectedSurface;

  String? resolvedByRevisionId;

  DateTime createdAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DesignFindingRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DesignFindingRow copyWith({
    int? id,
    String? findingId,
    String? revisionId,
    String? reviewExecutionId,
    String? category,
    String? severity,
    String? dimension,
    String? evidence,
    String? requiredCorrection,
    String? affectedSurface,
    String? resolvedByRevisionId,
    DateTime? createdAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DesignFindingRow',
      if (id != null) 'id': id,
      'findingId': findingId,
      'revisionId': revisionId,
      'reviewExecutionId': reviewExecutionId,
      'category': category,
      'severity': severity,
      'dimension': dimension,
      'evidence': evidence,
      'requiredCorrection': requiredCorrection,
      'affectedSurface': affectedSurface,
      if (resolvedByRevisionId != null)
        'resolvedByRevisionId': resolvedByRevisionId,
      'createdAt': createdAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DesignFindingRowInclude include() {
    return DesignFindingRowInclude._();
  }

  static DesignFindingRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DesignFindingRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignFindingRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignFindingRowTable>? orderByList,
    DesignFindingRowInclude? include,
  }) {
    return DesignFindingRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignFindingRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DesignFindingRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DesignFindingRowImpl extends DesignFindingRow {
  _DesignFindingRowImpl({
    int? id,
    required String findingId,
    required String revisionId,
    required String reviewExecutionId,
    required String category,
    required String severity,
    required String dimension,
    required String evidence,
    required String requiredCorrection,
    required String affectedSurface,
    String? resolvedByRevisionId,
    required DateTime createdAt,
    required int version,
  }) : super._(
         id: id,
         findingId: findingId,
         revisionId: revisionId,
         reviewExecutionId: reviewExecutionId,
         category: category,
         severity: severity,
         dimension: dimension,
         evidence: evidence,
         requiredCorrection: requiredCorrection,
         affectedSurface: affectedSurface,
         resolvedByRevisionId: resolvedByRevisionId,
         createdAt: createdAt,
         version: version,
       );

  /// Returns a shallow copy of this [DesignFindingRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DesignFindingRow copyWith({
    Object? id = _Undefined,
    String? findingId,
    String? revisionId,
    String? reviewExecutionId,
    String? category,
    String? severity,
    String? dimension,
    String? evidence,
    String? requiredCorrection,
    String? affectedSurface,
    Object? resolvedByRevisionId = _Undefined,
    DateTime? createdAt,
    int? version,
  }) {
    return DesignFindingRow(
      id: id is int? ? id : this.id,
      findingId: findingId ?? this.findingId,
      revisionId: revisionId ?? this.revisionId,
      reviewExecutionId: reviewExecutionId ?? this.reviewExecutionId,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      dimension: dimension ?? this.dimension,
      evidence: evidence ?? this.evidence,
      requiredCorrection: requiredCorrection ?? this.requiredCorrection,
      affectedSurface: affectedSurface ?? this.affectedSurface,
      resolvedByRevisionId: resolvedByRevisionId is String?
          ? resolvedByRevisionId
          : this.resolvedByRevisionId,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
    );
  }
}

class DesignFindingRowUpdateTable
    extends _i1.UpdateTable<DesignFindingRowTable> {
  DesignFindingRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> findingId(String value) => _i1.ColumnValue(
    table.findingId,
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

  _i1.ColumnValue<String, String> category(String value) => _i1.ColumnValue(
    table.category,
    value,
  );

  _i1.ColumnValue<String, String> severity(String value) => _i1.ColumnValue(
    table.severity,
    value,
  );

  _i1.ColumnValue<String, String> dimension(String value) => _i1.ColumnValue(
    table.dimension,
    value,
  );

  _i1.ColumnValue<String, String> evidence(String value) => _i1.ColumnValue(
    table.evidence,
    value,
  );

  _i1.ColumnValue<String, String> requiredCorrection(String value) =>
      _i1.ColumnValue(
        table.requiredCorrection,
        value,
      );

  _i1.ColumnValue<String, String> affectedSurface(String value) =>
      _i1.ColumnValue(
        table.affectedSurface,
        value,
      );

  _i1.ColumnValue<String, String> resolvedByRevisionId(String? value) =>
      _i1.ColumnValue(
        table.resolvedByRevisionId,
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

class DesignFindingRowTable extends _i1.Table<int?> {
  DesignFindingRowTable({super.tableRelation})
    : super(tableName: 'design_finding') {
    updateTable = DesignFindingRowUpdateTable(this);
    findingId = _i1.ColumnString(
      'findingId',
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
    category = _i1.ColumnString(
      'category',
      this,
    );
    severity = _i1.ColumnString(
      'severity',
      this,
    );
    dimension = _i1.ColumnString(
      'dimension',
      this,
    );
    evidence = _i1.ColumnString(
      'evidence',
      this,
    );
    requiredCorrection = _i1.ColumnString(
      'requiredCorrection',
      this,
    );
    affectedSurface = _i1.ColumnString(
      'affectedSurface',
      this,
    );
    resolvedByRevisionId = _i1.ColumnString(
      'resolvedByRevisionId',
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

  late final DesignFindingRowUpdateTable updateTable;

  late final _i1.ColumnString findingId;

  late final _i1.ColumnString revisionId;

  late final _i1.ColumnString reviewExecutionId;

  late final _i1.ColumnString category;

  late final _i1.ColumnString severity;

  late final _i1.ColumnString dimension;

  late final _i1.ColumnString evidence;

  late final _i1.ColumnString requiredCorrection;

  late final _i1.ColumnString affectedSurface;

  late final _i1.ColumnString resolvedByRevisionId;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    findingId,
    revisionId,
    reviewExecutionId,
    category,
    severity,
    dimension,
    evidence,
    requiredCorrection,
    affectedSurface,
    resolvedByRevisionId,
    createdAt,
    version,
  ];
}

class DesignFindingRowInclude extends _i1.IncludeObject {
  DesignFindingRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DesignFindingRow.t;
}

class DesignFindingRowIncludeList extends _i1.IncludeList {
  DesignFindingRowIncludeList._({
    _i1.WhereExpressionBuilder<DesignFindingRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DesignFindingRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DesignFindingRow.t;
}

class DesignFindingRowRepository {
  const DesignFindingRowRepository._();

  /// Returns a list of [DesignFindingRow]s matching the given query parameters.
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
  Future<List<DesignFindingRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignFindingRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignFindingRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignFindingRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DesignFindingRow>(
      where: where?.call(DesignFindingRow.t),
      orderBy: orderBy?.call(DesignFindingRow.t),
      orderByList: orderByList?.call(DesignFindingRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DesignFindingRow] matching the given query parameters.
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
  Future<DesignFindingRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignFindingRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DesignFindingRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignFindingRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DesignFindingRow>(
      where: where?.call(DesignFindingRow.t),
      orderBy: orderBy?.call(DesignFindingRow.t),
      orderByList: orderByList?.call(DesignFindingRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DesignFindingRow] by its [id] or null if no such row exists.
  Future<DesignFindingRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DesignFindingRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DesignFindingRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DesignFindingRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DesignFindingRow>> insert(
    _i1.DatabaseSession session,
    List<DesignFindingRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DesignFindingRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DesignFindingRow] and returns the inserted row.
  ///
  /// The returned [DesignFindingRow] will have its `id` field set.
  Future<DesignFindingRow> insertRow(
    _i1.DatabaseSession session,
    DesignFindingRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DesignFindingRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DesignFindingRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DesignFindingRow>> update(
    _i1.DatabaseSession session,
    List<DesignFindingRow> rows, {
    _i1.ColumnSelections<DesignFindingRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DesignFindingRow>(
      rows,
      columns: columns?.call(DesignFindingRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignFindingRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DesignFindingRow> updateRow(
    _i1.DatabaseSession session,
    DesignFindingRow row, {
    _i1.ColumnSelections<DesignFindingRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DesignFindingRow>(
      row,
      columns: columns?.call(DesignFindingRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignFindingRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DesignFindingRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DesignFindingRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DesignFindingRow>(
      id,
      columnValues: columnValues(DesignFindingRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DesignFindingRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DesignFindingRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DesignFindingRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DesignFindingRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignFindingRowTable>? orderBy,
    _i1.OrderByListBuilder<DesignFindingRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DesignFindingRow>(
      columnValues: columnValues(DesignFindingRow.t.updateTable),
      where: where(DesignFindingRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignFindingRow.t),
      orderByList: orderByList?.call(DesignFindingRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DesignFindingRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DesignFindingRow>> delete(
    _i1.DatabaseSession session,
    List<DesignFindingRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DesignFindingRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DesignFindingRow].
  Future<DesignFindingRow> deleteRow(
    _i1.DatabaseSession session,
    DesignFindingRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DesignFindingRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DesignFindingRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignFindingRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DesignFindingRow>(
      where: where(DesignFindingRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignFindingRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DesignFindingRow>(
      where: where?.call(DesignFindingRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DesignFindingRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignFindingRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DesignFindingRow>(
      where: where(DesignFindingRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

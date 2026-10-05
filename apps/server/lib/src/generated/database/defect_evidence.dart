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

abstract class DefectEvidenceRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DefectEvidenceRow._({
    this.id,
    required this.evidenceId,
    required this.defectId,
    required this.kind,
    this.artifactId,
    this.contentHash,
    this.description,
    this.sourceRef,
    required this.capturedAt,
    required this.createdAt,
    required this.version,
  });

  factory DefectEvidenceRow({
    int? id,
    required String evidenceId,
    required String defectId,
    required String kind,
    String? artifactId,
    String? contentHash,
    String? description,
    String? sourceRef,
    required DateTime capturedAt,
    required DateTime createdAt,
    required int version,
  }) = _DefectEvidenceRowImpl;

  factory DefectEvidenceRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectEvidenceRow(
      id: jsonSerialization['id'] as int?,
      evidenceId: jsonSerialization['evidenceId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      kind: jsonSerialization['kind'] as String,
      artifactId: jsonSerialization['artifactId'] as String?,
      contentHash: jsonSerialization['contentHash'] as String?,
      description: jsonSerialization['description'] as String?,
      sourceRef: jsonSerialization['sourceRef'] as String?,
      capturedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['capturedAt'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = DefectEvidenceRowTable();

  static const db = DefectEvidenceRowRepository._();

  @override
  int? id;

  String evidenceId;

  String defectId;

  String kind;

  String? artifactId;

  String? contentHash;

  String? description;

  String? sourceRef;

  DateTime capturedAt;

  DateTime createdAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DefectEvidenceRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectEvidenceRow copyWith({
    int? id,
    String? evidenceId,
    String? defectId,
    String? kind,
    String? artifactId,
    String? contentHash,
    String? description,
    String? sourceRef,
    DateTime? capturedAt,
    DateTime? createdAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectEvidenceRow',
      if (id != null) 'id': id,
      'evidenceId': evidenceId,
      'defectId': defectId,
      'kind': kind,
      if (artifactId != null) 'artifactId': artifactId,
      if (contentHash != null) 'contentHash': contentHash,
      if (description != null) 'description': description,
      if (sourceRef != null) 'sourceRef': sourceRef,
      'capturedAt': capturedAt.toJson(),
      'createdAt': createdAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DefectEvidenceRowInclude include() {
    return DefectEvidenceRowInclude._();
  }

  static DefectEvidenceRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DefectEvidenceRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectEvidenceRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectEvidenceRowTable>? orderByList,
    DefectEvidenceRowInclude? include,
  }) {
    return DefectEvidenceRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectEvidenceRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DefectEvidenceRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectEvidenceRowImpl extends DefectEvidenceRow {
  _DefectEvidenceRowImpl({
    int? id,
    required String evidenceId,
    required String defectId,
    required String kind,
    String? artifactId,
    String? contentHash,
    String? description,
    String? sourceRef,
    required DateTime capturedAt,
    required DateTime createdAt,
    required int version,
  }) : super._(
         id: id,
         evidenceId: evidenceId,
         defectId: defectId,
         kind: kind,
         artifactId: artifactId,
         contentHash: contentHash,
         description: description,
         sourceRef: sourceRef,
         capturedAt: capturedAt,
         createdAt: createdAt,
         version: version,
       );

  /// Returns a shallow copy of this [DefectEvidenceRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectEvidenceRow copyWith({
    Object? id = _Undefined,
    String? evidenceId,
    String? defectId,
    String? kind,
    Object? artifactId = _Undefined,
    Object? contentHash = _Undefined,
    Object? description = _Undefined,
    Object? sourceRef = _Undefined,
    DateTime? capturedAt,
    DateTime? createdAt,
    int? version,
  }) {
    return DefectEvidenceRow(
      id: id is int? ? id : this.id,
      evidenceId: evidenceId ?? this.evidenceId,
      defectId: defectId ?? this.defectId,
      kind: kind ?? this.kind,
      artifactId: artifactId is String? ? artifactId : this.artifactId,
      contentHash: contentHash is String? ? contentHash : this.contentHash,
      description: description is String? ? description : this.description,
      sourceRef: sourceRef is String? ? sourceRef : this.sourceRef,
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
    );
  }
}

class DefectEvidenceRowUpdateTable
    extends _i1.UpdateTable<DefectEvidenceRowTable> {
  DefectEvidenceRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> evidenceId(String value) => _i1.ColumnValue(
    table.evidenceId,
    value,
  );

  _i1.ColumnValue<String, String> defectId(String value) => _i1.ColumnValue(
    table.defectId,
    value,
  );

  _i1.ColumnValue<String, String> kind(String value) => _i1.ColumnValue(
    table.kind,
    value,
  );

  _i1.ColumnValue<String, String> artifactId(String? value) => _i1.ColumnValue(
    table.artifactId,
    value,
  );

  _i1.ColumnValue<String, String> contentHash(String? value) => _i1.ColumnValue(
    table.contentHash,
    value,
  );

  _i1.ColumnValue<String, String> description(String? value) => _i1.ColumnValue(
    table.description,
    value,
  );

  _i1.ColumnValue<String, String> sourceRef(String? value) => _i1.ColumnValue(
    table.sourceRef,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> capturedAt(DateTime value) =>
      _i1.ColumnValue(
        table.capturedAt,
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

class DefectEvidenceRowTable extends _i1.Table<int?> {
  DefectEvidenceRowTable({super.tableRelation})
    : super(tableName: 'defect_evidence') {
    updateTable = DefectEvidenceRowUpdateTable(this);
    evidenceId = _i1.ColumnString(
      'evidenceId',
      this,
    );
    defectId = _i1.ColumnString(
      'defectId',
      this,
    );
    kind = _i1.ColumnString(
      'kind',
      this,
    );
    artifactId = _i1.ColumnString(
      'artifactId',
      this,
    );
    contentHash = _i1.ColumnString(
      'contentHash',
      this,
    );
    description = _i1.ColumnString(
      'description',
      this,
    );
    sourceRef = _i1.ColumnString(
      'sourceRef',
      this,
    );
    capturedAt = _i1.ColumnDateTime(
      'capturedAt',
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

  late final DefectEvidenceRowUpdateTable updateTable;

  late final _i1.ColumnString evidenceId;

  late final _i1.ColumnString defectId;

  late final _i1.ColumnString kind;

  late final _i1.ColumnString artifactId;

  late final _i1.ColumnString contentHash;

  late final _i1.ColumnString description;

  late final _i1.ColumnString sourceRef;

  late final _i1.ColumnDateTime capturedAt;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    evidenceId,
    defectId,
    kind,
    artifactId,
    contentHash,
    description,
    sourceRef,
    capturedAt,
    createdAt,
    version,
  ];
}

class DefectEvidenceRowInclude extends _i1.IncludeObject {
  DefectEvidenceRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DefectEvidenceRow.t;
}

class DefectEvidenceRowIncludeList extends _i1.IncludeList {
  DefectEvidenceRowIncludeList._({
    _i1.WhereExpressionBuilder<DefectEvidenceRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DefectEvidenceRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DefectEvidenceRow.t;
}

class DefectEvidenceRowRepository {
  const DefectEvidenceRowRepository._();

  /// Returns a list of [DefectEvidenceRow]s matching the given query parameters.
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
  Future<List<DefectEvidenceRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectEvidenceRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectEvidenceRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectEvidenceRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DefectEvidenceRow>(
      where: where?.call(DefectEvidenceRow.t),
      orderBy: orderBy?.call(DefectEvidenceRow.t),
      orderByList: orderByList?.call(DefectEvidenceRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DefectEvidenceRow] matching the given query parameters.
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
  Future<DefectEvidenceRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectEvidenceRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DefectEvidenceRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectEvidenceRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DefectEvidenceRow>(
      where: where?.call(DefectEvidenceRow.t),
      orderBy: orderBy?.call(DefectEvidenceRow.t),
      orderByList: orderByList?.call(DefectEvidenceRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DefectEvidenceRow] by its [id] or null if no such row exists.
  Future<DefectEvidenceRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DefectEvidenceRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DefectEvidenceRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DefectEvidenceRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DefectEvidenceRow>> insert(
    _i1.DatabaseSession session,
    List<DefectEvidenceRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DefectEvidenceRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DefectEvidenceRow] and returns the inserted row.
  ///
  /// The returned [DefectEvidenceRow] will have its `id` field set.
  Future<DefectEvidenceRow> insertRow(
    _i1.DatabaseSession session,
    DefectEvidenceRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DefectEvidenceRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DefectEvidenceRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DefectEvidenceRow>> update(
    _i1.DatabaseSession session,
    List<DefectEvidenceRow> rows, {
    _i1.ColumnSelections<DefectEvidenceRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DefectEvidenceRow>(
      rows,
      columns: columns?.call(DefectEvidenceRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectEvidenceRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DefectEvidenceRow> updateRow(
    _i1.DatabaseSession session,
    DefectEvidenceRow row, {
    _i1.ColumnSelections<DefectEvidenceRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DefectEvidenceRow>(
      row,
      columns: columns?.call(DefectEvidenceRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectEvidenceRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DefectEvidenceRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DefectEvidenceRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DefectEvidenceRow>(
      id,
      columnValues: columnValues(DefectEvidenceRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DefectEvidenceRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DefectEvidenceRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DefectEvidenceRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DefectEvidenceRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectEvidenceRowTable>? orderBy,
    _i1.OrderByListBuilder<DefectEvidenceRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DefectEvidenceRow>(
      columnValues: columnValues(DefectEvidenceRow.t.updateTable),
      where: where(DefectEvidenceRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectEvidenceRow.t),
      orderByList: orderByList?.call(DefectEvidenceRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DefectEvidenceRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DefectEvidenceRow>> delete(
    _i1.DatabaseSession session,
    List<DefectEvidenceRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DefectEvidenceRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DefectEvidenceRow].
  Future<DefectEvidenceRow> deleteRow(
    _i1.DatabaseSession session,
    DefectEvidenceRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DefectEvidenceRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DefectEvidenceRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectEvidenceRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DefectEvidenceRow>(
      where: where(DefectEvidenceRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectEvidenceRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DefectEvidenceRow>(
      where: where?.call(DefectEvidenceRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DefectEvidenceRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectEvidenceRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DefectEvidenceRow>(
      where: where(DefectEvidenceRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

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

abstract class BaselineFactRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  BaselineFactRow._({
    this.id,
    required this.factId,
    required this.baselineId,
    required this.section,
    required this.claim,
    required this.provenance,
    required this.maturity,
    this.evidenceRefsJson,
    this.assumptionNote,
    required this.redacted,
    required this.version,
  });

  factory BaselineFactRow({
    int? id,
    required String factId,
    required String baselineId,
    required String section,
    required String claim,
    required String provenance,
    required String maturity,
    String? evidenceRefsJson,
    String? assumptionNote,
    required bool redacted,
    required int version,
  }) = _BaselineFactRowImpl;

  factory BaselineFactRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return BaselineFactRow(
      id: jsonSerialization['id'] as int?,
      factId: jsonSerialization['factId'] as String,
      baselineId: jsonSerialization['baselineId'] as String,
      section: jsonSerialization['section'] as String,
      claim: jsonSerialization['claim'] as String,
      provenance: jsonSerialization['provenance'] as String,
      maturity: jsonSerialization['maturity'] as String,
      evidenceRefsJson: jsonSerialization['evidenceRefsJson'] as String?,
      assumptionNote: jsonSerialization['assumptionNote'] as String?,
      redacted: _i1.BoolJsonExtension.fromJson(jsonSerialization['redacted']),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = BaselineFactRowTable();

  static const db = BaselineFactRowRepository._();

  @override
  int? id;

  String factId;

  String baselineId;

  String section;

  String claim;

  String provenance;

  String maturity;

  String? evidenceRefsJson;

  String? assumptionNote;

  bool redacted;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [BaselineFactRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  BaselineFactRow copyWith({
    int? id,
    String? factId,
    String? baselineId,
    String? section,
    String? claim,
    String? provenance,
    String? maturity,
    String? evidenceRefsJson,
    String? assumptionNote,
    bool? redacted,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BaselineFactRow',
      if (id != null) 'id': id,
      'factId': factId,
      'baselineId': baselineId,
      'section': section,
      'claim': claim,
      'provenance': provenance,
      'maturity': maturity,
      if (evidenceRefsJson != null) 'evidenceRefsJson': evidenceRefsJson,
      if (assumptionNote != null) 'assumptionNote': assumptionNote,
      'redacted': redacted,
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BaselineFactRowInclude include() {
    return BaselineFactRowInclude._();
  }

  static BaselineFactRowIncludeList includeList({
    _i1.WhereExpressionBuilder<BaselineFactRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<BaselineFactRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<BaselineFactRowTable>? orderByList,
    BaselineFactRowInclude? include,
  }) {
    return BaselineFactRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BaselineFactRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(BaselineFactRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BaselineFactRowImpl extends BaselineFactRow {
  _BaselineFactRowImpl({
    int? id,
    required String factId,
    required String baselineId,
    required String section,
    required String claim,
    required String provenance,
    required String maturity,
    String? evidenceRefsJson,
    String? assumptionNote,
    required bool redacted,
    required int version,
  }) : super._(
         id: id,
         factId: factId,
         baselineId: baselineId,
         section: section,
         claim: claim,
         provenance: provenance,
         maturity: maturity,
         evidenceRefsJson: evidenceRefsJson,
         assumptionNote: assumptionNote,
         redacted: redacted,
         version: version,
       );

  /// Returns a shallow copy of this [BaselineFactRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  BaselineFactRow copyWith({
    Object? id = _Undefined,
    String? factId,
    String? baselineId,
    String? section,
    String? claim,
    String? provenance,
    String? maturity,
    Object? evidenceRefsJson = _Undefined,
    Object? assumptionNote = _Undefined,
    bool? redacted,
    int? version,
  }) {
    return BaselineFactRow(
      id: id is int? ? id : this.id,
      factId: factId ?? this.factId,
      baselineId: baselineId ?? this.baselineId,
      section: section ?? this.section,
      claim: claim ?? this.claim,
      provenance: provenance ?? this.provenance,
      maturity: maturity ?? this.maturity,
      evidenceRefsJson: evidenceRefsJson is String?
          ? evidenceRefsJson
          : this.evidenceRefsJson,
      assumptionNote: assumptionNote is String?
          ? assumptionNote
          : this.assumptionNote,
      redacted: redacted ?? this.redacted,
      version: version ?? this.version,
    );
  }
}

class BaselineFactRowUpdateTable extends _i1.UpdateTable<BaselineFactRowTable> {
  BaselineFactRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> factId(String value) => _i1.ColumnValue(
    table.factId,
    value,
  );

  _i1.ColumnValue<String, String> baselineId(String value) => _i1.ColumnValue(
    table.baselineId,
    value,
  );

  _i1.ColumnValue<String, String> section(String value) => _i1.ColumnValue(
    table.section,
    value,
  );

  _i1.ColumnValue<String, String> claim(String value) => _i1.ColumnValue(
    table.claim,
    value,
  );

  _i1.ColumnValue<String, String> provenance(String value) => _i1.ColumnValue(
    table.provenance,
    value,
  );

  _i1.ColumnValue<String, String> maturity(String value) => _i1.ColumnValue(
    table.maturity,
    value,
  );

  _i1.ColumnValue<String, String> evidenceRefsJson(String? value) =>
      _i1.ColumnValue(
        table.evidenceRefsJson,
        value,
      );

  _i1.ColumnValue<String, String> assumptionNote(String? value) =>
      _i1.ColumnValue(
        table.assumptionNote,
        value,
      );

  _i1.ColumnValue<bool, bool> redacted(bool value) => _i1.ColumnValue(
    table.redacted,
    value,
  );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class BaselineFactRowTable extends _i1.Table<int?> {
  BaselineFactRowTable({super.tableRelation})
    : super(tableName: 'baseline_fact') {
    updateTable = BaselineFactRowUpdateTable(this);
    factId = _i1.ColumnString(
      'factId',
      this,
    );
    baselineId = _i1.ColumnString(
      'baselineId',
      this,
    );
    section = _i1.ColumnString(
      'section',
      this,
    );
    claim = _i1.ColumnString(
      'claim',
      this,
    );
    provenance = _i1.ColumnString(
      'provenance',
      this,
    );
    maturity = _i1.ColumnString(
      'maturity',
      this,
    );
    evidenceRefsJson = _i1.ColumnString(
      'evidenceRefsJson',
      this,
    );
    assumptionNote = _i1.ColumnString(
      'assumptionNote',
      this,
    );
    redacted = _i1.ColumnBool(
      'redacted',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final BaselineFactRowUpdateTable updateTable;

  late final _i1.ColumnString factId;

  late final _i1.ColumnString baselineId;

  late final _i1.ColumnString section;

  late final _i1.ColumnString claim;

  late final _i1.ColumnString provenance;

  late final _i1.ColumnString maturity;

  late final _i1.ColumnString evidenceRefsJson;

  late final _i1.ColumnString assumptionNote;

  late final _i1.ColumnBool redacted;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    factId,
    baselineId,
    section,
    claim,
    provenance,
    maturity,
    evidenceRefsJson,
    assumptionNote,
    redacted,
    version,
  ];
}

class BaselineFactRowInclude extends _i1.IncludeObject {
  BaselineFactRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => BaselineFactRow.t;
}

class BaselineFactRowIncludeList extends _i1.IncludeList {
  BaselineFactRowIncludeList._({
    _i1.WhereExpressionBuilder<BaselineFactRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BaselineFactRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => BaselineFactRow.t;
}

class BaselineFactRowRepository {
  const BaselineFactRowRepository._();

  /// Returns a list of [BaselineFactRow]s matching the given query parameters.
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
  Future<List<BaselineFactRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<BaselineFactRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<BaselineFactRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<BaselineFactRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BaselineFactRow>(
      where: where?.call(BaselineFactRow.t),
      orderBy: orderBy?.call(BaselineFactRow.t),
      orderByList: orderByList?.call(BaselineFactRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [BaselineFactRow] matching the given query parameters.
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
  Future<BaselineFactRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<BaselineFactRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<BaselineFactRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<BaselineFactRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BaselineFactRow>(
      where: where?.call(BaselineFactRow.t),
      orderBy: orderBy?.call(BaselineFactRow.t),
      orderByList: orderByList?.call(BaselineFactRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BaselineFactRow] by its [id] or null if no such row exists.
  Future<BaselineFactRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BaselineFactRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BaselineFactRow]s in the list and returns the inserted rows.
  ///
  /// The returned [BaselineFactRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<BaselineFactRow>> insert(
    _i1.DatabaseSession session,
    List<BaselineFactRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<BaselineFactRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [BaselineFactRow] and returns the inserted row.
  ///
  /// The returned [BaselineFactRow] will have its `id` field set.
  Future<BaselineFactRow> insertRow(
    _i1.DatabaseSession session,
    BaselineFactRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<BaselineFactRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [BaselineFactRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<BaselineFactRow>> update(
    _i1.DatabaseSession session,
    List<BaselineFactRow> rows, {
    _i1.ColumnSelections<BaselineFactRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<BaselineFactRow>(
      rows,
      columns: columns?.call(BaselineFactRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BaselineFactRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BaselineFactRow> updateRow(
    _i1.DatabaseSession session,
    BaselineFactRow row, {
    _i1.ColumnSelections<BaselineFactRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<BaselineFactRow>(
      row,
      columns: columns?.call(BaselineFactRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BaselineFactRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BaselineFactRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<BaselineFactRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<BaselineFactRow>(
      id,
      columnValues: columnValues(BaselineFactRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BaselineFactRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<BaselineFactRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<BaselineFactRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<BaselineFactRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<BaselineFactRowTable>? orderBy,
    _i1.OrderByListBuilder<BaselineFactRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<BaselineFactRow>(
      columnValues: columnValues(BaselineFactRow.t.updateTable),
      where: where(BaselineFactRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BaselineFactRow.t),
      orderByList: orderByList?.call(BaselineFactRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [BaselineFactRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<BaselineFactRow>> delete(
    _i1.DatabaseSession session,
    List<BaselineFactRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<BaselineFactRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [BaselineFactRow].
  Future<BaselineFactRow> deleteRow(
    _i1.DatabaseSession session,
    BaselineFactRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BaselineFactRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<BaselineFactRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<BaselineFactRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<BaselineFactRow>(
      where: where(BaselineFactRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<BaselineFactRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<BaselineFactRow>(
      where: where?.call(BaselineFactRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BaselineFactRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<BaselineFactRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BaselineFactRow>(
      where: where(BaselineFactRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

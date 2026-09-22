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

abstract class RepositoryReferenceRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  RepositoryReferenceRow._({
    this.id,
    required this.repositoryId,
    required this.productId,
    required this.kind,
    required this.uri,
    required this.provider,
    required this.addedAt,
    required this.version,
  });

  factory RepositoryReferenceRow({
    int? id,
    required String repositoryId,
    required String productId,
    required String kind,
    required String uri,
    required String provider,
    required DateTime addedAt,
    required int version,
  }) = _RepositoryReferenceRowImpl;

  factory RepositoryReferenceRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RepositoryReferenceRow(
      id: jsonSerialization['id'] as int?,
      repositoryId: jsonSerialization['repositoryId'] as String,
      productId: jsonSerialization['productId'] as String,
      kind: jsonSerialization['kind'] as String,
      uri: jsonSerialization['uri'] as String,
      provider: jsonSerialization['provider'] as String,
      addedAt: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['addedAt']),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = RepositoryReferenceRowTable();

  static const db = RepositoryReferenceRowRepository._();

  @override
  int? id;

  String repositoryId;

  String productId;

  String kind;

  String uri;

  String provider;

  DateTime addedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [RepositoryReferenceRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RepositoryReferenceRow copyWith({
    int? id,
    String? repositoryId,
    String? productId,
    String? kind,
    String? uri,
    String? provider,
    DateTime? addedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RepositoryReferenceRow',
      if (id != null) 'id': id,
      'repositoryId': repositoryId,
      'productId': productId,
      'kind': kind,
      'uri': uri,
      'provider': provider,
      'addedAt': addedAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static RepositoryReferenceRowInclude include() {
    return RepositoryReferenceRowInclude._();
  }

  static RepositoryReferenceRowIncludeList includeList({
    _i1.WhereExpressionBuilder<RepositoryReferenceRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RepositoryReferenceRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RepositoryReferenceRowTable>? orderByList,
    RepositoryReferenceRowInclude? include,
  }) {
    return RepositoryReferenceRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RepositoryReferenceRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(RepositoryReferenceRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RepositoryReferenceRowImpl extends RepositoryReferenceRow {
  _RepositoryReferenceRowImpl({
    int? id,
    required String repositoryId,
    required String productId,
    required String kind,
    required String uri,
    required String provider,
    required DateTime addedAt,
    required int version,
  }) : super._(
         id: id,
         repositoryId: repositoryId,
         productId: productId,
         kind: kind,
         uri: uri,
         provider: provider,
         addedAt: addedAt,
         version: version,
       );

  /// Returns a shallow copy of this [RepositoryReferenceRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RepositoryReferenceRow copyWith({
    Object? id = _Undefined,
    String? repositoryId,
    String? productId,
    String? kind,
    String? uri,
    String? provider,
    DateTime? addedAt,
    int? version,
  }) {
    return RepositoryReferenceRow(
      id: id is int? ? id : this.id,
      repositoryId: repositoryId ?? this.repositoryId,
      productId: productId ?? this.productId,
      kind: kind ?? this.kind,
      uri: uri ?? this.uri,
      provider: provider ?? this.provider,
      addedAt: addedAt ?? this.addedAt,
      version: version ?? this.version,
    );
  }
}

class RepositoryReferenceRowUpdateTable
    extends _i1.UpdateTable<RepositoryReferenceRowTable> {
  RepositoryReferenceRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> repositoryId(String value) => _i1.ColumnValue(
    table.repositoryId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> kind(String value) => _i1.ColumnValue(
    table.kind,
    value,
  );

  _i1.ColumnValue<String, String> uri(String value) => _i1.ColumnValue(
    table.uri,
    value,
  );

  _i1.ColumnValue<String, String> provider(String value) => _i1.ColumnValue(
    table.provider,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> addedAt(DateTime value) =>
      _i1.ColumnValue(
        table.addedAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class RepositoryReferenceRowTable extends _i1.Table<int?> {
  RepositoryReferenceRowTable({super.tableRelation})
    : super(tableName: 'repository_reference') {
    updateTable = RepositoryReferenceRowUpdateTable(this);
    repositoryId = _i1.ColumnString(
      'repositoryId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    kind = _i1.ColumnString(
      'kind',
      this,
    );
    uri = _i1.ColumnString(
      'uri',
      this,
    );
    provider = _i1.ColumnString(
      'provider',
      this,
    );
    addedAt = _i1.ColumnDateTime(
      'addedAt',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final RepositoryReferenceRowUpdateTable updateTable;

  late final _i1.ColumnString repositoryId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString kind;

  late final _i1.ColumnString uri;

  late final _i1.ColumnString provider;

  late final _i1.ColumnDateTime addedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    repositoryId,
    productId,
    kind,
    uri,
    provider,
    addedAt,
    version,
  ];
}

class RepositoryReferenceRowInclude extends _i1.IncludeObject {
  RepositoryReferenceRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => RepositoryReferenceRow.t;
}

class RepositoryReferenceRowIncludeList extends _i1.IncludeList {
  RepositoryReferenceRowIncludeList._({
    _i1.WhereExpressionBuilder<RepositoryReferenceRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RepositoryReferenceRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => RepositoryReferenceRow.t;
}

class RepositoryReferenceRowRepository {
  const RepositoryReferenceRowRepository._();

  /// Returns a list of [RepositoryReferenceRow]s matching the given query parameters.
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
  Future<List<RepositoryReferenceRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RepositoryReferenceRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RepositoryReferenceRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RepositoryReferenceRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<RepositoryReferenceRow>(
      where: where?.call(RepositoryReferenceRow.t),
      orderBy: orderBy?.call(RepositoryReferenceRow.t),
      orderByList: orderByList?.call(RepositoryReferenceRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [RepositoryReferenceRow] matching the given query parameters.
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
  Future<RepositoryReferenceRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RepositoryReferenceRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<RepositoryReferenceRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RepositoryReferenceRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<RepositoryReferenceRow>(
      where: where?.call(RepositoryReferenceRow.t),
      orderBy: orderBy?.call(RepositoryReferenceRow.t),
      orderByList: orderByList?.call(RepositoryReferenceRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [RepositoryReferenceRow] by its [id] or null if no such row exists.
  Future<RepositoryReferenceRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<RepositoryReferenceRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [RepositoryReferenceRow]s in the list and returns the inserted rows.
  ///
  /// The returned [RepositoryReferenceRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<RepositoryReferenceRow>> insert(
    _i1.DatabaseSession session,
    List<RepositoryReferenceRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<RepositoryReferenceRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [RepositoryReferenceRow] and returns the inserted row.
  ///
  /// The returned [RepositoryReferenceRow] will have its `id` field set.
  Future<RepositoryReferenceRow> insertRow(
    _i1.DatabaseSession session,
    RepositoryReferenceRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<RepositoryReferenceRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [RepositoryReferenceRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<RepositoryReferenceRow>> update(
    _i1.DatabaseSession session,
    List<RepositoryReferenceRow> rows, {
    _i1.ColumnSelections<RepositoryReferenceRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<RepositoryReferenceRow>(
      rows,
      columns: columns?.call(RepositoryReferenceRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RepositoryReferenceRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<RepositoryReferenceRow> updateRow(
    _i1.DatabaseSession session,
    RepositoryReferenceRow row, {
    _i1.ColumnSelections<RepositoryReferenceRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<RepositoryReferenceRow>(
      row,
      columns: columns?.call(RepositoryReferenceRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RepositoryReferenceRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<RepositoryReferenceRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<RepositoryReferenceRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<RepositoryReferenceRow>(
      id,
      columnValues: columnValues(RepositoryReferenceRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [RepositoryReferenceRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<RepositoryReferenceRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<RepositoryReferenceRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<RepositoryReferenceRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RepositoryReferenceRowTable>? orderBy,
    _i1.OrderByListBuilder<RepositoryReferenceRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<RepositoryReferenceRow>(
      columnValues: columnValues(RepositoryReferenceRow.t.updateTable),
      where: where(RepositoryReferenceRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RepositoryReferenceRow.t),
      orderByList: orderByList?.call(RepositoryReferenceRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [RepositoryReferenceRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<RepositoryReferenceRow>> delete(
    _i1.DatabaseSession session,
    List<RepositoryReferenceRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<RepositoryReferenceRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [RepositoryReferenceRow].
  Future<RepositoryReferenceRow> deleteRow(
    _i1.DatabaseSession session,
    RepositoryReferenceRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<RepositoryReferenceRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<RepositoryReferenceRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RepositoryReferenceRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<RepositoryReferenceRow>(
      where: where(RepositoryReferenceRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RepositoryReferenceRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<RepositoryReferenceRow>(
      where: where?.call(RepositoryReferenceRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RepositoryReferenceRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RepositoryReferenceRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<RepositoryReferenceRow>(
      where: where(RepositoryReferenceRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

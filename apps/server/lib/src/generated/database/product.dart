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

abstract class ProductRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ProductRow._({
    this.id,
    required this.productId,
    required this.name,
    this.description,
    this.manifestVersion,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory ProductRow({
    int? id,
    required String productId,
    required String name,
    String? description,
    String? manifestVersion,
    required String state,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
  }) = _ProductRowImpl;

  factory ProductRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProductRow(
      id: jsonSerialization['id'] as int?,
      productId: jsonSerialization['productId'] as String,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String?,
      manifestVersion: jsonSerialization['manifestVersion'] as String?,
      state: jsonSerialization['state'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = ProductRowTable();

  static const db = ProductRowRepository._();

  @override
  int? id;

  String productId;

  String name;

  String? description;

  String? manifestVersion;

  String state;

  DateTime createdAt;

  DateTime updatedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ProductRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductRow copyWith({
    int? id,
    String? productId,
    String? name,
    String? description,
    String? manifestVersion,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductRow',
      if (id != null) 'id': id,
      'productId': productId,
      'name': name,
      if (description != null) 'description': description,
      if (manifestVersion != null) 'manifestVersion': manifestVersion,
      'state': state,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ProductRowInclude include() {
    return ProductRowInclude._();
  }

  static ProductRowIncludeList includeList({
    _i1.WhereExpressionBuilder<ProductRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductRowTable>? orderByList,
    ProductRowInclude? include,
  }) {
    return ProductRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProductRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ProductRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductRowImpl extends ProductRow {
  _ProductRowImpl({
    int? id,
    required String productId,
    required String name,
    String? description,
    String? manifestVersion,
    required String state,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
  }) : super._(
         id: id,
         productId: productId,
         name: name,
         description: description,
         manifestVersion: manifestVersion,
         state: state,
         createdAt: createdAt,
         updatedAt: updatedAt,
         version: version,
       );

  /// Returns a shallow copy of this [ProductRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductRow copyWith({
    Object? id = _Undefined,
    String? productId,
    String? name,
    Object? description = _Undefined,
    Object? manifestVersion = _Undefined,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return ProductRow(
      id: id is int? ? id : this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description is String? ? description : this.description,
      manifestVersion: manifestVersion is String?
          ? manifestVersion
          : this.manifestVersion,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}

class ProductRowUpdateTable extends _i1.UpdateTable<ProductRowTable> {
  ProductRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<String, String> description(String? value) => _i1.ColumnValue(
    table.description,
    value,
  );

  _i1.ColumnValue<String, String> manifestVersion(String? value) =>
      _i1.ColumnValue(
        table.manifestVersion,
        value,
      );

  _i1.ColumnValue<String, String> state(String value) => _i1.ColumnValue(
    table.state,
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

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class ProductRowTable extends _i1.Table<int?> {
  ProductRowTable({super.tableRelation}) : super(tableName: 'product') {
    updateTable = ProductRowUpdateTable(this);
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    description = _i1.ColumnString(
      'description',
      this,
    );
    manifestVersion = _i1.ColumnString(
      'manifestVersion',
      this,
    );
    state = _i1.ColumnString(
      'state',
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
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final ProductRowUpdateTable updateTable;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString name;

  late final _i1.ColumnString description;

  late final _i1.ColumnString manifestVersion;

  late final _i1.ColumnString state;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    productId,
    name,
    description,
    manifestVersion,
    state,
    createdAt,
    updatedAt,
    version,
  ];
}

class ProductRowInclude extends _i1.IncludeObject {
  ProductRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ProductRow.t;
}

class ProductRowIncludeList extends _i1.IncludeList {
  ProductRowIncludeList._({
    _i1.WhereExpressionBuilder<ProductRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ProductRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ProductRow.t;
}

class ProductRowRepository {
  const ProductRowRepository._();

  /// Returns a list of [ProductRow]s matching the given query parameters.
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
  Future<List<ProductRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ProductRow>(
      where: where?.call(ProductRow.t),
      orderBy: orderBy?.call(ProductRow.t),
      orderByList: orderByList?.call(ProductRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ProductRow] matching the given query parameters.
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
  Future<ProductRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<ProductRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ProductRow>(
      where: where?.call(ProductRow.t),
      orderBy: orderBy?.call(ProductRow.t),
      orderByList: orderByList?.call(ProductRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ProductRow] by its [id] or null if no such row exists.
  Future<ProductRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ProductRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ProductRow]s in the list and returns the inserted rows.
  ///
  /// The returned [ProductRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ProductRow>> insert(
    _i1.DatabaseSession session,
    List<ProductRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ProductRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ProductRow] and returns the inserted row.
  ///
  /// The returned [ProductRow] will have its `id` field set.
  Future<ProductRow> insertRow(
    _i1.DatabaseSession session,
    ProductRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ProductRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ProductRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ProductRow>> update(
    _i1.DatabaseSession session,
    List<ProductRow> rows, {
    _i1.ColumnSelections<ProductRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ProductRow>(
      rows,
      columns: columns?.call(ProductRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ProductRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ProductRow> updateRow(
    _i1.DatabaseSession session,
    ProductRow row, {
    _i1.ColumnSelections<ProductRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ProductRow>(
      row,
      columns: columns?.call(ProductRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ProductRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ProductRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ProductRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ProductRow>(
      id,
      columnValues: columnValues(ProductRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ProductRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ProductRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ProductRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ProductRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductRowTable>? orderBy,
    _i1.OrderByListBuilder<ProductRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ProductRow>(
      columnValues: columnValues(ProductRow.t.updateTable),
      where: where(ProductRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProductRow.t),
      orderByList: orderByList?.call(ProductRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ProductRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ProductRow>> delete(
    _i1.DatabaseSession session,
    List<ProductRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ProductRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ProductRow].
  Future<ProductRow> deleteRow(
    _i1.DatabaseSession session,
    ProductRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ProductRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ProductRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ProductRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ProductRow>(
      where: where(ProductRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ProductRow>(
      where: where?.call(ProductRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ProductRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ProductRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ProductRow>(
      where: where(ProductRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

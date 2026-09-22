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

abstract class ProductRegistryAuditRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ProductRegistryAuditRow._({
    this.id,
    required this.auditId,
    required this.productId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.beforeJson,
    this.afterJson,
    this.actor,
    required this.timestamp,
  });

  factory ProductRegistryAuditRow({
    int? id,
    required String auditId,
    required String productId,
    required String entityType,
    required String entityId,
    required String action,
    String? beforeJson,
    String? afterJson,
    String? actor,
    required DateTime timestamp,
  }) = _ProductRegistryAuditRowImpl;

  factory ProductRegistryAuditRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ProductRegistryAuditRow(
      id: jsonSerialization['id'] as int?,
      auditId: jsonSerialization['auditId'] as String,
      productId: jsonSerialization['productId'] as String,
      entityType: jsonSerialization['entityType'] as String,
      entityId: jsonSerialization['entityId'] as String,
      action: jsonSerialization['action'] as String,
      beforeJson: jsonSerialization['beforeJson'] as String?,
      afterJson: jsonSerialization['afterJson'] as String?,
      actor: jsonSerialization['actor'] as String?,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
    );
  }

  static final t = ProductRegistryAuditRowTable();

  static const db = ProductRegistryAuditRowRepository._();

  @override
  int? id;

  String auditId;

  String productId;

  String entityType;

  String entityId;

  String action;

  String? beforeJson;

  String? afterJson;

  String? actor;

  DateTime timestamp;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ProductRegistryAuditRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductRegistryAuditRow copyWith({
    int? id,
    String? auditId,
    String? productId,
    String? entityType,
    String? entityId,
    String? action,
    String? beforeJson,
    String? afterJson,
    String? actor,
    DateTime? timestamp,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductRegistryAuditRow',
      if (id != null) 'id': id,
      'auditId': auditId,
      'productId': productId,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      if (beforeJson != null) 'beforeJson': beforeJson,
      if (afterJson != null) 'afterJson': afterJson,
      if (actor != null) 'actor': actor,
      'timestamp': timestamp.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ProductRegistryAuditRowInclude include() {
    return ProductRegistryAuditRowInclude._();
  }

  static ProductRegistryAuditRowIncludeList includeList({
    _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductRegistryAuditRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductRegistryAuditRowTable>? orderByList,
    ProductRegistryAuditRowInclude? include,
  }) {
    return ProductRegistryAuditRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProductRegistryAuditRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ProductRegistryAuditRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductRegistryAuditRowImpl extends ProductRegistryAuditRow {
  _ProductRegistryAuditRowImpl({
    int? id,
    required String auditId,
    required String productId,
    required String entityType,
    required String entityId,
    required String action,
    String? beforeJson,
    String? afterJson,
    String? actor,
    required DateTime timestamp,
  }) : super._(
         id: id,
         auditId: auditId,
         productId: productId,
         entityType: entityType,
         entityId: entityId,
         action: action,
         beforeJson: beforeJson,
         afterJson: afterJson,
         actor: actor,
         timestamp: timestamp,
       );

  /// Returns a shallow copy of this [ProductRegistryAuditRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductRegistryAuditRow copyWith({
    Object? id = _Undefined,
    String? auditId,
    String? productId,
    String? entityType,
    String? entityId,
    String? action,
    Object? beforeJson = _Undefined,
    Object? afterJson = _Undefined,
    Object? actor = _Undefined,
    DateTime? timestamp,
  }) {
    return ProductRegistryAuditRow(
      id: id is int? ? id : this.id,
      auditId: auditId ?? this.auditId,
      productId: productId ?? this.productId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      beforeJson: beforeJson is String? ? beforeJson : this.beforeJson,
      afterJson: afterJson is String? ? afterJson : this.afterJson,
      actor: actor is String? ? actor : this.actor,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ProductRegistryAuditRowUpdateTable
    extends _i1.UpdateTable<ProductRegistryAuditRowTable> {
  ProductRegistryAuditRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> auditId(String value) => _i1.ColumnValue(
    table.auditId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> entityType(String value) => _i1.ColumnValue(
    table.entityType,
    value,
  );

  _i1.ColumnValue<String, String> entityId(String value) => _i1.ColumnValue(
    table.entityId,
    value,
  );

  _i1.ColumnValue<String, String> action(String value) => _i1.ColumnValue(
    table.action,
    value,
  );

  _i1.ColumnValue<String, String> beforeJson(String? value) => _i1.ColumnValue(
    table.beforeJson,
    value,
  );

  _i1.ColumnValue<String, String> afterJson(String? value) => _i1.ColumnValue(
    table.afterJson,
    value,
  );

  _i1.ColumnValue<String, String> actor(String? value) => _i1.ColumnValue(
    table.actor,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> timestamp(DateTime value) =>
      _i1.ColumnValue(
        table.timestamp,
        value,
      );
}

class ProductRegistryAuditRowTable extends _i1.Table<int?> {
  ProductRegistryAuditRowTable({super.tableRelation})
    : super(tableName: 'product_registry_audit') {
    updateTable = ProductRegistryAuditRowUpdateTable(this);
    auditId = _i1.ColumnString(
      'auditId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    entityType = _i1.ColumnString(
      'entityType',
      this,
    );
    entityId = _i1.ColumnString(
      'entityId',
      this,
    );
    action = _i1.ColumnString(
      'action',
      this,
    );
    beforeJson = _i1.ColumnString(
      'beforeJson',
      this,
    );
    afterJson = _i1.ColumnString(
      'afterJson',
      this,
    );
    actor = _i1.ColumnString(
      'actor',
      this,
    );
    timestamp = _i1.ColumnDateTime(
      'timestamp',
      this,
    );
  }

  late final ProductRegistryAuditRowUpdateTable updateTable;

  late final _i1.ColumnString auditId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString entityType;

  late final _i1.ColumnString entityId;

  late final _i1.ColumnString action;

  late final _i1.ColumnString beforeJson;

  late final _i1.ColumnString afterJson;

  late final _i1.ColumnString actor;

  late final _i1.ColumnDateTime timestamp;

  @override
  List<_i1.Column> get columns => [
    id,
    auditId,
    productId,
    entityType,
    entityId,
    action,
    beforeJson,
    afterJson,
    actor,
    timestamp,
  ];
}

class ProductRegistryAuditRowInclude extends _i1.IncludeObject {
  ProductRegistryAuditRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ProductRegistryAuditRow.t;
}

class ProductRegistryAuditRowIncludeList extends _i1.IncludeList {
  ProductRegistryAuditRowIncludeList._({
    _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ProductRegistryAuditRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ProductRegistryAuditRow.t;
}

class ProductRegistryAuditRowRepository {
  const ProductRegistryAuditRowRepository._();

  /// Returns a list of [ProductRegistryAuditRow]s matching the given query parameters.
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
  Future<List<ProductRegistryAuditRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductRegistryAuditRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductRegistryAuditRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ProductRegistryAuditRow>(
      where: where?.call(ProductRegistryAuditRow.t),
      orderBy: orderBy?.call(ProductRegistryAuditRow.t),
      orderByList: orderByList?.call(ProductRegistryAuditRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ProductRegistryAuditRow] matching the given query parameters.
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
  Future<ProductRegistryAuditRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<ProductRegistryAuditRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductRegistryAuditRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ProductRegistryAuditRow>(
      where: where?.call(ProductRegistryAuditRow.t),
      orderBy: orderBy?.call(ProductRegistryAuditRow.t),
      orderByList: orderByList?.call(ProductRegistryAuditRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ProductRegistryAuditRow] by its [id] or null if no such row exists.
  Future<ProductRegistryAuditRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ProductRegistryAuditRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ProductRegistryAuditRow]s in the list and returns the inserted rows.
  ///
  /// The returned [ProductRegistryAuditRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ProductRegistryAuditRow>> insert(
    _i1.DatabaseSession session,
    List<ProductRegistryAuditRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ProductRegistryAuditRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ProductRegistryAuditRow] and returns the inserted row.
  ///
  /// The returned [ProductRegistryAuditRow] will have its `id` field set.
  Future<ProductRegistryAuditRow> insertRow(
    _i1.DatabaseSession session,
    ProductRegistryAuditRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ProductRegistryAuditRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ProductRegistryAuditRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ProductRegistryAuditRow>> update(
    _i1.DatabaseSession session,
    List<ProductRegistryAuditRow> rows, {
    _i1.ColumnSelections<ProductRegistryAuditRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ProductRegistryAuditRow>(
      rows,
      columns: columns?.call(ProductRegistryAuditRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ProductRegistryAuditRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ProductRegistryAuditRow> updateRow(
    _i1.DatabaseSession session,
    ProductRegistryAuditRow row, {
    _i1.ColumnSelections<ProductRegistryAuditRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ProductRegistryAuditRow>(
      row,
      columns: columns?.call(ProductRegistryAuditRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ProductRegistryAuditRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ProductRegistryAuditRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ProductRegistryAuditRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ProductRegistryAuditRow>(
      id,
      columnValues: columnValues(ProductRegistryAuditRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ProductRegistryAuditRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ProductRegistryAuditRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ProductRegistryAuditRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductRegistryAuditRowTable>? orderBy,
    _i1.OrderByListBuilder<ProductRegistryAuditRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ProductRegistryAuditRow>(
      columnValues: columnValues(ProductRegistryAuditRow.t.updateTable),
      where: where(ProductRegistryAuditRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProductRegistryAuditRow.t),
      orderByList: orderByList?.call(ProductRegistryAuditRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ProductRegistryAuditRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ProductRegistryAuditRow>> delete(
    _i1.DatabaseSession session,
    List<ProductRegistryAuditRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ProductRegistryAuditRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ProductRegistryAuditRow].
  Future<ProductRegistryAuditRow> deleteRow(
    _i1.DatabaseSession session,
    ProductRegistryAuditRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ProductRegistryAuditRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ProductRegistryAuditRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ProductRegistryAuditRow>(
      where: where(ProductRegistryAuditRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ProductRegistryAuditRow>(
      where: where?.call(ProductRegistryAuditRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ProductRegistryAuditRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ProductRegistryAuditRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ProductRegistryAuditRow>(
      where: where(ProductRegistryAuditRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

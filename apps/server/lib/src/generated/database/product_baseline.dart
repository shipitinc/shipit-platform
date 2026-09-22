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

abstract class ProductBaselineRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ProductBaselineRow._({
    this.id,
    required this.baselineId,
    required this.productId,
    required this.revision,
    required this.status,
    required this.factsJson,
    required this.contentHash,
    required this.contentHashVersion,
    this.supersedesBaselineId,
    this.proposedAt,
    this.reviewedAt,
    this.acceptedAt,
    this.acceptedBy,
    this.acceptedDecisionId,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationKind,
    this.createdAt,
    this.updatedAt,
    required this.version,
  });

  factory ProductBaselineRow({
    int? id,
    required String baselineId,
    required String productId,
    required int revision,
    required String status,
    required String factsJson,
    required String contentHash,
    required int contentHashVersion,
    String? supersedesBaselineId,
    DateTime? proposedAt,
    DateTime? reviewedAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedDecisionId,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? verificationKind,
    DateTime? createdAt,
    DateTime? updatedAt,
    required int version,
  }) = _ProductBaselineRowImpl;

  factory ProductBaselineRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProductBaselineRow(
      id: jsonSerialization['id'] as int?,
      baselineId: jsonSerialization['baselineId'] as String,
      productId: jsonSerialization['productId'] as String,
      revision: jsonSerialization['revision'] as int,
      status: jsonSerialization['status'] as String,
      factsJson: jsonSerialization['factsJson'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      contentHashVersion: jsonSerialization['contentHashVersion'] as int,
      supersedesBaselineId:
          jsonSerialization['supersedesBaselineId'] as String?,
      proposedAt: jsonSerialization['proposedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['proposedAt']),
      reviewedAt: jsonSerialization['reviewedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['reviewedAt']),
      acceptedAt: jsonSerialization['acceptedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['acceptedAt']),
      acceptedBy: jsonSerialization['acceptedBy'] as String?,
      acceptedDecisionId: jsonSerialization['acceptedDecisionId'] as String?,
      verifiedAt: jsonSerialization['verifiedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['verifiedAt']),
      verifiedBy: jsonSerialization['verifiedBy'] as String?,
      verificationKind: jsonSerialization['verificationKind'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = ProductBaselineRowTable();

  static const db = ProductBaselineRowRepository._();

  @override
  int? id;

  String baselineId;

  String productId;

  int revision;

  String status;

  String factsJson;

  String contentHash;

  int contentHashVersion;

  String? supersedesBaselineId;

  DateTime? proposedAt;

  DateTime? reviewedAt;

  DateTime? acceptedAt;

  String? acceptedBy;

  String? acceptedDecisionId;

  DateTime? verifiedAt;

  String? verifiedBy;

  String? verificationKind;

  DateTime? createdAt;

  DateTime? updatedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ProductBaselineRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductBaselineRow copyWith({
    int? id,
    String? baselineId,
    String? productId,
    int? revision,
    String? status,
    String? factsJson,
    String? contentHash,
    int? contentHashVersion,
    String? supersedesBaselineId,
    DateTime? proposedAt,
    DateTime? reviewedAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedDecisionId,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? verificationKind,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductBaselineRow',
      if (id != null) 'id': id,
      'baselineId': baselineId,
      'productId': productId,
      'revision': revision,
      'status': status,
      'factsJson': factsJson,
      'contentHash': contentHash,
      'contentHashVersion': contentHashVersion,
      if (supersedesBaselineId != null)
        'supersedesBaselineId': supersedesBaselineId,
      if (proposedAt != null) 'proposedAt': proposedAt?.toJson(),
      if (reviewedAt != null) 'reviewedAt': reviewedAt?.toJson(),
      if (acceptedAt != null) 'acceptedAt': acceptedAt?.toJson(),
      if (acceptedBy != null) 'acceptedBy': acceptedBy,
      if (acceptedDecisionId != null) 'acceptedDecisionId': acceptedDecisionId,
      if (verifiedAt != null) 'verifiedAt': verifiedAt?.toJson(),
      if (verifiedBy != null) 'verifiedBy': verifiedBy,
      if (verificationKind != null) 'verificationKind': verificationKind,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ProductBaselineRowInclude include() {
    return ProductBaselineRowInclude._();
  }

  static ProductBaselineRowIncludeList includeList({
    _i1.WhereExpressionBuilder<ProductBaselineRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductBaselineRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductBaselineRowTable>? orderByList,
    ProductBaselineRowInclude? include,
  }) {
    return ProductBaselineRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProductBaselineRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ProductBaselineRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductBaselineRowImpl extends ProductBaselineRow {
  _ProductBaselineRowImpl({
    int? id,
    required String baselineId,
    required String productId,
    required int revision,
    required String status,
    required String factsJson,
    required String contentHash,
    required int contentHashVersion,
    String? supersedesBaselineId,
    DateTime? proposedAt,
    DateTime? reviewedAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedDecisionId,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? verificationKind,
    DateTime? createdAt,
    DateTime? updatedAt,
    required int version,
  }) : super._(
         id: id,
         baselineId: baselineId,
         productId: productId,
         revision: revision,
         status: status,
         factsJson: factsJson,
         contentHash: contentHash,
         contentHashVersion: contentHashVersion,
         supersedesBaselineId: supersedesBaselineId,
         proposedAt: proposedAt,
         reviewedAt: reviewedAt,
         acceptedAt: acceptedAt,
         acceptedBy: acceptedBy,
         acceptedDecisionId: acceptedDecisionId,
         verifiedAt: verifiedAt,
         verifiedBy: verifiedBy,
         verificationKind: verificationKind,
         createdAt: createdAt,
         updatedAt: updatedAt,
         version: version,
       );

  /// Returns a shallow copy of this [ProductBaselineRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductBaselineRow copyWith({
    Object? id = _Undefined,
    String? baselineId,
    String? productId,
    int? revision,
    String? status,
    String? factsJson,
    String? contentHash,
    int? contentHashVersion,
    Object? supersedesBaselineId = _Undefined,
    Object? proposedAt = _Undefined,
    Object? reviewedAt = _Undefined,
    Object? acceptedAt = _Undefined,
    Object? acceptedBy = _Undefined,
    Object? acceptedDecisionId = _Undefined,
    Object? verifiedAt = _Undefined,
    Object? verifiedBy = _Undefined,
    Object? verificationKind = _Undefined,
    Object? createdAt = _Undefined,
    Object? updatedAt = _Undefined,
    int? version,
  }) {
    return ProductBaselineRow(
      id: id is int? ? id : this.id,
      baselineId: baselineId ?? this.baselineId,
      productId: productId ?? this.productId,
      revision: revision ?? this.revision,
      status: status ?? this.status,
      factsJson: factsJson ?? this.factsJson,
      contentHash: contentHash ?? this.contentHash,
      contentHashVersion: contentHashVersion ?? this.contentHashVersion,
      supersedesBaselineId: supersedesBaselineId is String?
          ? supersedesBaselineId
          : this.supersedesBaselineId,
      proposedAt: proposedAt is DateTime? ? proposedAt : this.proposedAt,
      reviewedAt: reviewedAt is DateTime? ? reviewedAt : this.reviewedAt,
      acceptedAt: acceptedAt is DateTime? ? acceptedAt : this.acceptedAt,
      acceptedBy: acceptedBy is String? ? acceptedBy : this.acceptedBy,
      acceptedDecisionId: acceptedDecisionId is String?
          ? acceptedDecisionId
          : this.acceptedDecisionId,
      verifiedAt: verifiedAt is DateTime? ? verifiedAt : this.verifiedAt,
      verifiedBy: verifiedBy is String? ? verifiedBy : this.verifiedBy,
      verificationKind: verificationKind is String?
          ? verificationKind
          : this.verificationKind,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      version: version ?? this.version,
    );
  }
}

class ProductBaselineRowUpdateTable
    extends _i1.UpdateTable<ProductBaselineRowTable> {
  ProductBaselineRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> baselineId(String value) => _i1.ColumnValue(
    table.baselineId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<int, int> revision(int value) => _i1.ColumnValue(
    table.revision,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> factsJson(String value) => _i1.ColumnValue(
    table.factsJson,
    value,
  );

  _i1.ColumnValue<String, String> contentHash(String value) => _i1.ColumnValue(
    table.contentHash,
    value,
  );

  _i1.ColumnValue<int, int> contentHashVersion(int value) => _i1.ColumnValue(
    table.contentHashVersion,
    value,
  );

  _i1.ColumnValue<String, String> supersedesBaselineId(String? value) =>
      _i1.ColumnValue(
        table.supersedesBaselineId,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> proposedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.proposedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> reviewedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.reviewedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> acceptedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.acceptedAt,
        value,
      );

  _i1.ColumnValue<String, String> acceptedBy(String? value) => _i1.ColumnValue(
    table.acceptedBy,
    value,
  );

  _i1.ColumnValue<String, String> acceptedDecisionId(String? value) =>
      _i1.ColumnValue(
        table.acceptedDecisionId,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> verifiedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.verifiedAt,
        value,
      );

  _i1.ColumnValue<String, String> verifiedBy(String? value) => _i1.ColumnValue(
    table.verifiedBy,
    value,
  );

  _i1.ColumnValue<String, String> verificationKind(String? value) =>
      _i1.ColumnValue(
        table.verificationKind,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime? value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class ProductBaselineRowTable extends _i1.Table<int?> {
  ProductBaselineRowTable({super.tableRelation})
    : super(tableName: 'product_baseline') {
    updateTable = ProductBaselineRowUpdateTable(this);
    baselineId = _i1.ColumnString(
      'baselineId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    revision = _i1.ColumnInt(
      'revision',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    factsJson = _i1.ColumnString(
      'factsJson',
      this,
    );
    contentHash = _i1.ColumnString(
      'contentHash',
      this,
    );
    contentHashVersion = _i1.ColumnInt(
      'contentHashVersion',
      this,
    );
    supersedesBaselineId = _i1.ColumnString(
      'supersedesBaselineId',
      this,
    );
    proposedAt = _i1.ColumnDateTime(
      'proposedAt',
      this,
    );
    reviewedAt = _i1.ColumnDateTime(
      'reviewedAt',
      this,
    );
    acceptedAt = _i1.ColumnDateTime(
      'acceptedAt',
      this,
    );
    acceptedBy = _i1.ColumnString(
      'acceptedBy',
      this,
    );
    acceptedDecisionId = _i1.ColumnString(
      'acceptedDecisionId',
      this,
    );
    verifiedAt = _i1.ColumnDateTime(
      'verifiedAt',
      this,
    );
    verifiedBy = _i1.ColumnString(
      'verifiedBy',
      this,
    );
    verificationKind = _i1.ColumnString(
      'verificationKind',
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

  late final ProductBaselineRowUpdateTable updateTable;

  late final _i1.ColumnString baselineId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnInt revision;

  late final _i1.ColumnString status;

  late final _i1.ColumnString factsJson;

  late final _i1.ColumnString contentHash;

  late final _i1.ColumnInt contentHashVersion;

  late final _i1.ColumnString supersedesBaselineId;

  late final _i1.ColumnDateTime proposedAt;

  late final _i1.ColumnDateTime reviewedAt;

  late final _i1.ColumnDateTime acceptedAt;

  late final _i1.ColumnString acceptedBy;

  late final _i1.ColumnString acceptedDecisionId;

  late final _i1.ColumnDateTime verifiedAt;

  late final _i1.ColumnString verifiedBy;

  late final _i1.ColumnString verificationKind;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    baselineId,
    productId,
    revision,
    status,
    factsJson,
    contentHash,
    contentHashVersion,
    supersedesBaselineId,
    proposedAt,
    reviewedAt,
    acceptedAt,
    acceptedBy,
    acceptedDecisionId,
    verifiedAt,
    verifiedBy,
    verificationKind,
    createdAt,
    updatedAt,
    version,
  ];
}

class ProductBaselineRowInclude extends _i1.IncludeObject {
  ProductBaselineRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ProductBaselineRow.t;
}

class ProductBaselineRowIncludeList extends _i1.IncludeList {
  ProductBaselineRowIncludeList._({
    _i1.WhereExpressionBuilder<ProductBaselineRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ProductBaselineRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ProductBaselineRow.t;
}

class ProductBaselineRowRepository {
  const ProductBaselineRowRepository._();

  /// Returns a list of [ProductBaselineRow]s matching the given query parameters.
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
  Future<List<ProductBaselineRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductBaselineRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductBaselineRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductBaselineRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ProductBaselineRow>(
      where: where?.call(ProductBaselineRow.t),
      orderBy: orderBy?.call(ProductBaselineRow.t),
      orderByList: orderByList?.call(ProductBaselineRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ProductBaselineRow] matching the given query parameters.
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
  Future<ProductBaselineRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductBaselineRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<ProductBaselineRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ProductBaselineRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ProductBaselineRow>(
      where: where?.call(ProductBaselineRow.t),
      orderBy: orderBy?.call(ProductBaselineRow.t),
      orderByList: orderByList?.call(ProductBaselineRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ProductBaselineRow] by its [id] or null if no such row exists.
  Future<ProductBaselineRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ProductBaselineRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ProductBaselineRow]s in the list and returns the inserted rows.
  ///
  /// The returned [ProductBaselineRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ProductBaselineRow>> insert(
    _i1.DatabaseSession session,
    List<ProductBaselineRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ProductBaselineRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ProductBaselineRow] and returns the inserted row.
  ///
  /// The returned [ProductBaselineRow] will have its `id` field set.
  Future<ProductBaselineRow> insertRow(
    _i1.DatabaseSession session,
    ProductBaselineRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ProductBaselineRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ProductBaselineRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ProductBaselineRow>> update(
    _i1.DatabaseSession session,
    List<ProductBaselineRow> rows, {
    _i1.ColumnSelections<ProductBaselineRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ProductBaselineRow>(
      rows,
      columns: columns?.call(ProductBaselineRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ProductBaselineRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ProductBaselineRow> updateRow(
    _i1.DatabaseSession session,
    ProductBaselineRow row, {
    _i1.ColumnSelections<ProductBaselineRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ProductBaselineRow>(
      row,
      columns: columns?.call(ProductBaselineRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ProductBaselineRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ProductBaselineRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ProductBaselineRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ProductBaselineRow>(
      id,
      columnValues: columnValues(ProductBaselineRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ProductBaselineRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ProductBaselineRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ProductBaselineRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<ProductBaselineRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ProductBaselineRowTable>? orderBy,
    _i1.OrderByListBuilder<ProductBaselineRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ProductBaselineRow>(
      columnValues: columnValues(ProductBaselineRow.t.updateTable),
      where: where(ProductBaselineRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ProductBaselineRow.t),
      orderByList: orderByList?.call(ProductBaselineRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ProductBaselineRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ProductBaselineRow>> delete(
    _i1.DatabaseSession session,
    List<ProductBaselineRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ProductBaselineRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ProductBaselineRow].
  Future<ProductBaselineRow> deleteRow(
    _i1.DatabaseSession session,
    ProductBaselineRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ProductBaselineRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ProductBaselineRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ProductBaselineRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ProductBaselineRow>(
      where: where(ProductBaselineRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ProductBaselineRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ProductBaselineRow>(
      where: where?.call(ProductBaselineRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ProductBaselineRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ProductBaselineRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ProductBaselineRow>(
      where: where(ProductBaselineRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

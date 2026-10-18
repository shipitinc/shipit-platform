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

abstract class DesignContractRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DesignContractRow._({
    this.id,
    required this.contractId,
    required this.workItemId,
    required this.requiredArtifactsJson,
    required this.reviewersJson,
    required this.approvalThreshold,
    required this.status,
    this.submittedArtifactsJson,
    this.decisionsJson,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.metadataJson,
  });

  factory DesignContractRow({
    int? id,
    required String contractId,
    required String workItemId,
    required String requiredArtifactsJson,
    required String reviewersJson,
    required int approvalThreshold,
    required String status,
    String? submittedArtifactsJson,
    String? decisionsJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? expiresAt,
    String? metadataJson,
  }) = _DesignContractRowImpl;

  factory DesignContractRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return DesignContractRow(
      id: jsonSerialization['id'] as int?,
      contractId: jsonSerialization['contractId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      requiredArtifactsJson:
          jsonSerialization['requiredArtifactsJson'] as String,
      reviewersJson: jsonSerialization['reviewersJson'] as String,
      approvalThreshold: jsonSerialization['approvalThreshold'] as int,
      status: jsonSerialization['status'] as String,
      submittedArtifactsJson:
          jsonSerialization['submittedArtifactsJson'] as String?,
      decisionsJson: jsonSerialization['decisionsJson'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      metadataJson: jsonSerialization['metadataJson'] as String?,
    );
  }

  static final t = DesignContractRowTable();

  static const db = DesignContractRowRepository._();

  @override
  int? id;

  String contractId;

  String workItemId;

  String requiredArtifactsJson;

  String reviewersJson;

  int approvalThreshold;

  String status;

  String? submittedArtifactsJson;

  String? decisionsJson;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? expiresAt;

  String? metadataJson;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DesignContractRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DesignContractRow copyWith({
    int? id,
    String? contractId,
    String? workItemId,
    String? requiredArtifactsJson,
    String? reviewersJson,
    int? approvalThreshold,
    String? status,
    String? submittedArtifactsJson,
    String? decisionsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? metadataJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DesignContractRow',
      if (id != null) 'id': id,
      'contractId': contractId,
      'workItemId': workItemId,
      'requiredArtifactsJson': requiredArtifactsJson,
      'reviewersJson': reviewersJson,
      'approvalThreshold': approvalThreshold,
      'status': status,
      if (submittedArtifactsJson != null)
        'submittedArtifactsJson': submittedArtifactsJson,
      if (decisionsJson != null) 'decisionsJson': decisionsJson,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      if (metadataJson != null) 'metadataJson': metadataJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DesignContractRowInclude include() {
    return DesignContractRowInclude._();
  }

  static DesignContractRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DesignContractRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignContractRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignContractRowTable>? orderByList,
    DesignContractRowInclude? include,
  }) {
    return DesignContractRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignContractRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DesignContractRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DesignContractRowImpl extends DesignContractRow {
  _DesignContractRowImpl({
    int? id,
    required String contractId,
    required String workItemId,
    required String requiredArtifactsJson,
    required String reviewersJson,
    required int approvalThreshold,
    required String status,
    String? submittedArtifactsJson,
    String? decisionsJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? expiresAt,
    String? metadataJson,
  }) : super._(
         id: id,
         contractId: contractId,
         workItemId: workItemId,
         requiredArtifactsJson: requiredArtifactsJson,
         reviewersJson: reviewersJson,
         approvalThreshold: approvalThreshold,
         status: status,
         submittedArtifactsJson: submittedArtifactsJson,
         decisionsJson: decisionsJson,
         createdAt: createdAt,
         updatedAt: updatedAt,
         expiresAt: expiresAt,
         metadataJson: metadataJson,
       );

  /// Returns a shallow copy of this [DesignContractRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DesignContractRow copyWith({
    Object? id = _Undefined,
    String? contractId,
    String? workItemId,
    String? requiredArtifactsJson,
    String? reviewersJson,
    int? approvalThreshold,
    String? status,
    Object? submittedArtifactsJson = _Undefined,
    Object? decisionsJson = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? expiresAt = _Undefined,
    Object? metadataJson = _Undefined,
  }) {
    return DesignContractRow(
      id: id is int? ? id : this.id,
      contractId: contractId ?? this.contractId,
      workItemId: workItemId ?? this.workItemId,
      requiredArtifactsJson:
          requiredArtifactsJson ?? this.requiredArtifactsJson,
      reviewersJson: reviewersJson ?? this.reviewersJson,
      approvalThreshold: approvalThreshold ?? this.approvalThreshold,
      status: status ?? this.status,
      submittedArtifactsJson: submittedArtifactsJson is String?
          ? submittedArtifactsJson
          : this.submittedArtifactsJson,
      decisionsJson: decisionsJson is String?
          ? decisionsJson
          : this.decisionsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt is DateTime? ? expiresAt : this.expiresAt,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
    );
  }
}

class DesignContractRowUpdateTable
    extends _i1.UpdateTable<DesignContractRowTable> {
  DesignContractRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> contractId(String value) => _i1.ColumnValue(
    table.contractId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> requiredArtifactsJson(String value) =>
      _i1.ColumnValue(
        table.requiredArtifactsJson,
        value,
      );

  _i1.ColumnValue<String, String> reviewersJson(String value) =>
      _i1.ColumnValue(
        table.reviewersJson,
        value,
      );

  _i1.ColumnValue<int, int> approvalThreshold(int value) => _i1.ColumnValue(
    table.approvalThreshold,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> submittedArtifactsJson(String? value) =>
      _i1.ColumnValue(
        table.submittedArtifactsJson,
        value,
      );

  _i1.ColumnValue<String, String> decisionsJson(String? value) =>
      _i1.ColumnValue(
        table.decisionsJson,
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

  _i1.ColumnValue<DateTime, DateTime> expiresAt(DateTime? value) =>
      _i1.ColumnValue(
        table.expiresAt,
        value,
      );

  _i1.ColumnValue<String, String> metadataJson(String? value) =>
      _i1.ColumnValue(
        table.metadataJson,
        value,
      );
}

class DesignContractRowTable extends _i1.Table<int?> {
  DesignContractRowTable({super.tableRelation})
    : super(tableName: 'design_contract') {
    updateTable = DesignContractRowUpdateTable(this);
    contractId = _i1.ColumnString(
      'contractId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    requiredArtifactsJson = _i1.ColumnString(
      'requiredArtifactsJson',
      this,
    );
    reviewersJson = _i1.ColumnString(
      'reviewersJson',
      this,
    );
    approvalThreshold = _i1.ColumnInt(
      'approvalThreshold',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    submittedArtifactsJson = _i1.ColumnString(
      'submittedArtifactsJson',
      this,
    );
    decisionsJson = _i1.ColumnString(
      'decisionsJson',
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
    expiresAt = _i1.ColumnDateTime(
      'expiresAt',
      this,
    );
    metadataJson = _i1.ColumnString(
      'metadataJson',
      this,
    );
  }

  late final DesignContractRowUpdateTable updateTable;

  late final _i1.ColumnString contractId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString requiredArtifactsJson;

  late final _i1.ColumnString reviewersJson;

  late final _i1.ColumnInt approvalThreshold;

  late final _i1.ColumnString status;

  late final _i1.ColumnString submittedArtifactsJson;

  late final _i1.ColumnString decisionsJson;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnDateTime expiresAt;

  late final _i1.ColumnString metadataJson;

  @override
  List<_i1.Column> get columns => [
    id,
    contractId,
    workItemId,
    requiredArtifactsJson,
    reviewersJson,
    approvalThreshold,
    status,
    submittedArtifactsJson,
    decisionsJson,
    createdAt,
    updatedAt,
    expiresAt,
    metadataJson,
  ];
}

class DesignContractRowInclude extends _i1.IncludeObject {
  DesignContractRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DesignContractRow.t;
}

class DesignContractRowIncludeList extends _i1.IncludeList {
  DesignContractRowIncludeList._({
    _i1.WhereExpressionBuilder<DesignContractRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DesignContractRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DesignContractRow.t;
}

class DesignContractRowRepository {
  const DesignContractRowRepository._();

  /// Returns a list of [DesignContractRow]s matching the given query parameters.
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
  Future<List<DesignContractRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignContractRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignContractRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignContractRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DesignContractRow>(
      where: where?.call(DesignContractRow.t),
      orderBy: orderBy?.call(DesignContractRow.t),
      orderByList: orderByList?.call(DesignContractRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DesignContractRow] matching the given query parameters.
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
  Future<DesignContractRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignContractRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DesignContractRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignContractRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DesignContractRow>(
      where: where?.call(DesignContractRow.t),
      orderBy: orderBy?.call(DesignContractRow.t),
      orderByList: orderByList?.call(DesignContractRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DesignContractRow] by its [id] or null if no such row exists.
  Future<DesignContractRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DesignContractRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DesignContractRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DesignContractRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DesignContractRow>> insert(
    _i1.DatabaseSession session,
    List<DesignContractRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DesignContractRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DesignContractRow] and returns the inserted row.
  ///
  /// The returned [DesignContractRow] will have its `id` field set.
  Future<DesignContractRow> insertRow(
    _i1.DatabaseSession session,
    DesignContractRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DesignContractRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DesignContractRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DesignContractRow>> update(
    _i1.DatabaseSession session,
    List<DesignContractRow> rows, {
    _i1.ColumnSelections<DesignContractRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DesignContractRow>(
      rows,
      columns: columns?.call(DesignContractRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignContractRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DesignContractRow> updateRow(
    _i1.DatabaseSession session,
    DesignContractRow row, {
    _i1.ColumnSelections<DesignContractRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DesignContractRow>(
      row,
      columns: columns?.call(DesignContractRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignContractRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DesignContractRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DesignContractRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DesignContractRow>(
      id,
      columnValues: columnValues(DesignContractRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DesignContractRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DesignContractRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DesignContractRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DesignContractRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignContractRowTable>? orderBy,
    _i1.OrderByListBuilder<DesignContractRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DesignContractRow>(
      columnValues: columnValues(DesignContractRow.t.updateTable),
      where: where(DesignContractRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignContractRow.t),
      orderByList: orderByList?.call(DesignContractRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DesignContractRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DesignContractRow>> delete(
    _i1.DatabaseSession session,
    List<DesignContractRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DesignContractRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DesignContractRow].
  Future<DesignContractRow> deleteRow(
    _i1.DatabaseSession session,
    DesignContractRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DesignContractRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DesignContractRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignContractRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DesignContractRow>(
      where: where(DesignContractRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignContractRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DesignContractRow>(
      where: where?.call(DesignContractRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DesignContractRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignContractRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DesignContractRow>(
      where: where(DesignContractRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

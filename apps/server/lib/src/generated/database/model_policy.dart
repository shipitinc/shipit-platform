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

abstract class ModelPolicyRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ModelPolicyRow._({
    this.id,
    required this.role,
    required this.chainJson,
    required this.version,
    required this.updatedAt,
    required this.updatedByDecisionId,
  });

  factory ModelPolicyRow({
    int? id,
    required String role,
    required String chainJson,
    required int version,
    required DateTime updatedAt,
    required String updatedByDecisionId,
  }) = _ModelPolicyRowImpl;

  factory ModelPolicyRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return ModelPolicyRow(
      id: jsonSerialization['id'] as int?,
      role: jsonSerialization['role'] as String,
      chainJson: jsonSerialization['chainJson'] as String,
      version: jsonSerialization['version'] as int,
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      updatedByDecisionId: jsonSerialization['updatedByDecisionId'] as String,
    );
  }

  static final t = ModelPolicyRowTable();

  static const db = ModelPolicyRowRepository._();

  @override
  int? id;

  String role;

  String chainJson;

  int version;

  DateTime updatedAt;

  String updatedByDecisionId;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ModelPolicyRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelPolicyRow copyWith({
    int? id,
    String? role,
    String? chainJson,
    int? version,
    DateTime? updatedAt,
    String? updatedByDecisionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelPolicyRow',
      if (id != null) 'id': id,
      'role': role,
      'chainJson': chainJson,
      'version': version,
      'updatedAt': updatedAt.toJson(),
      'updatedByDecisionId': updatedByDecisionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ModelPolicyRowInclude include() {
    return ModelPolicyRowInclude._();
  }

  static ModelPolicyRowIncludeList includeList({
    _i1.WhereExpressionBuilder<ModelPolicyRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ModelPolicyRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ModelPolicyRowTable>? orderByList,
    ModelPolicyRowInclude? include,
  }) {
    return ModelPolicyRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ModelPolicyRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ModelPolicyRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ModelPolicyRowImpl extends ModelPolicyRow {
  _ModelPolicyRowImpl({
    int? id,
    required String role,
    required String chainJson,
    required int version,
    required DateTime updatedAt,
    required String updatedByDecisionId,
  }) : super._(
         id: id,
         role: role,
         chainJson: chainJson,
         version: version,
         updatedAt: updatedAt,
         updatedByDecisionId: updatedByDecisionId,
       );

  /// Returns a shallow copy of this [ModelPolicyRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelPolicyRow copyWith({
    Object? id = _Undefined,
    String? role,
    String? chainJson,
    int? version,
    DateTime? updatedAt,
    String? updatedByDecisionId,
  }) {
    return ModelPolicyRow(
      id: id is int? ? id : this.id,
      role: role ?? this.role,
      chainJson: chainJson ?? this.chainJson,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByDecisionId: updatedByDecisionId ?? this.updatedByDecisionId,
    );
  }
}

class ModelPolicyRowUpdateTable extends _i1.UpdateTable<ModelPolicyRowTable> {
  ModelPolicyRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> role(String value) => _i1.ColumnValue(
    table.role,
    value,
  );

  _i1.ColumnValue<String, String> chainJson(String value) => _i1.ColumnValue(
    table.chainJson,
    value,
  );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );

  _i1.ColumnValue<String, String> updatedByDecisionId(String value) =>
      _i1.ColumnValue(
        table.updatedByDecisionId,
        value,
      );
}

class ModelPolicyRowTable extends _i1.Table<int?> {
  ModelPolicyRowTable({super.tableRelation})
    : super(tableName: 'model_policy') {
    updateTable = ModelPolicyRowUpdateTable(this);
    role = _i1.ColumnString(
      'role',
      this,
    );
    chainJson = _i1.ColumnString(
      'chainJson',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
    updatedByDecisionId = _i1.ColumnString(
      'updatedByDecisionId',
      this,
    );
  }

  late final ModelPolicyRowUpdateTable updateTable;

  late final _i1.ColumnString role;

  late final _i1.ColumnString chainJson;

  late final _i1.ColumnInt version;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnString updatedByDecisionId;

  @override
  List<_i1.Column> get columns => [
    id,
    role,
    chainJson,
    version,
    updatedAt,
    updatedByDecisionId,
  ];
}

class ModelPolicyRowInclude extends _i1.IncludeObject {
  ModelPolicyRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ModelPolicyRow.t;
}

class ModelPolicyRowIncludeList extends _i1.IncludeList {
  ModelPolicyRowIncludeList._({
    _i1.WhereExpressionBuilder<ModelPolicyRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ModelPolicyRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ModelPolicyRow.t;
}

class ModelPolicyRowRepository {
  const ModelPolicyRowRepository._();

  /// Returns a list of [ModelPolicyRow]s matching the given query parameters.
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
  Future<List<ModelPolicyRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ModelPolicyRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ModelPolicyRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ModelPolicyRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ModelPolicyRow>(
      where: where?.call(ModelPolicyRow.t),
      orderBy: orderBy?.call(ModelPolicyRow.t),
      orderByList: orderByList?.call(ModelPolicyRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ModelPolicyRow] matching the given query parameters.
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
  Future<ModelPolicyRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ModelPolicyRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<ModelPolicyRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ModelPolicyRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ModelPolicyRow>(
      where: where?.call(ModelPolicyRow.t),
      orderBy: orderBy?.call(ModelPolicyRow.t),
      orderByList: orderByList?.call(ModelPolicyRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ModelPolicyRow] by its [id] or null if no such row exists.
  Future<ModelPolicyRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ModelPolicyRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ModelPolicyRow]s in the list and returns the inserted rows.
  ///
  /// The returned [ModelPolicyRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ModelPolicyRow>> insert(
    _i1.DatabaseSession session,
    List<ModelPolicyRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ModelPolicyRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ModelPolicyRow] and returns the inserted row.
  ///
  /// The returned [ModelPolicyRow] will have its `id` field set.
  Future<ModelPolicyRow> insertRow(
    _i1.DatabaseSession session,
    ModelPolicyRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ModelPolicyRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ModelPolicyRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ModelPolicyRow>> update(
    _i1.DatabaseSession session,
    List<ModelPolicyRow> rows, {
    _i1.ColumnSelections<ModelPolicyRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ModelPolicyRow>(
      rows,
      columns: columns?.call(ModelPolicyRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ModelPolicyRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ModelPolicyRow> updateRow(
    _i1.DatabaseSession session,
    ModelPolicyRow row, {
    _i1.ColumnSelections<ModelPolicyRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ModelPolicyRow>(
      row,
      columns: columns?.call(ModelPolicyRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ModelPolicyRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ModelPolicyRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ModelPolicyRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ModelPolicyRow>(
      id,
      columnValues: columnValues(ModelPolicyRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ModelPolicyRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ModelPolicyRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ModelPolicyRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ModelPolicyRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ModelPolicyRowTable>? orderBy,
    _i1.OrderByListBuilder<ModelPolicyRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ModelPolicyRow>(
      columnValues: columnValues(ModelPolicyRow.t.updateTable),
      where: where(ModelPolicyRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ModelPolicyRow.t),
      orderByList: orderByList?.call(ModelPolicyRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ModelPolicyRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ModelPolicyRow>> delete(
    _i1.DatabaseSession session,
    List<ModelPolicyRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ModelPolicyRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ModelPolicyRow].
  Future<ModelPolicyRow> deleteRow(
    _i1.DatabaseSession session,
    ModelPolicyRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ModelPolicyRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ModelPolicyRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ModelPolicyRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ModelPolicyRow>(
      where: where(ModelPolicyRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ModelPolicyRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ModelPolicyRow>(
      where: where?.call(ModelPolicyRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ModelPolicyRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ModelPolicyRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ModelPolicyRow>(
      where: where(ModelPolicyRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

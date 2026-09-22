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

abstract class OnboardingRecordRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  OnboardingRecordRow._({
    this.id,
    required this.onboardingId,
    required this.productId,
    required this.currentBaselineRevision,
    required this.pendingClarifications,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory OnboardingRecordRow({
    int? id,
    required String onboardingId,
    required String productId,
    required int currentBaselineRevision,
    required int pendingClarifications,
    required bool completed,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
  }) = _OnboardingRecordRowImpl;

  factory OnboardingRecordRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return OnboardingRecordRow(
      id: jsonSerialization['id'] as int?,
      onboardingId: jsonSerialization['onboardingId'] as String,
      productId: jsonSerialization['productId'] as String,
      currentBaselineRevision:
          jsonSerialization['currentBaselineRevision'] as int,
      pendingClarifications: jsonSerialization['pendingClarifications'] as int,
      completed: _i1.BoolJsonExtension.fromJson(jsonSerialization['completed']),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = OnboardingRecordRowTable();

  static const db = OnboardingRecordRowRepository._();

  @override
  int? id;

  String onboardingId;

  String productId;

  int currentBaselineRevision;

  int pendingClarifications;

  bool completed;

  DateTime createdAt;

  DateTime updatedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [OnboardingRecordRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  OnboardingRecordRow copyWith({
    int? id,
    String? onboardingId,
    String? productId,
    int? currentBaselineRevision,
    int? pendingClarifications,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OnboardingRecordRow',
      if (id != null) 'id': id,
      'onboardingId': onboardingId,
      'productId': productId,
      'currentBaselineRevision': currentBaselineRevision,
      'pendingClarifications': pendingClarifications,
      'completed': completed,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static OnboardingRecordRowInclude include() {
    return OnboardingRecordRowInclude._();
  }

  static OnboardingRecordRowIncludeList includeList({
    _i1.WhereExpressionBuilder<OnboardingRecordRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<OnboardingRecordRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<OnboardingRecordRowTable>? orderByList,
    OnboardingRecordRowInclude? include,
  }) {
    return OnboardingRecordRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OnboardingRecordRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(OnboardingRecordRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OnboardingRecordRowImpl extends OnboardingRecordRow {
  _OnboardingRecordRowImpl({
    int? id,
    required String onboardingId,
    required String productId,
    required int currentBaselineRevision,
    required int pendingClarifications,
    required bool completed,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
  }) : super._(
         id: id,
         onboardingId: onboardingId,
         productId: productId,
         currentBaselineRevision: currentBaselineRevision,
         pendingClarifications: pendingClarifications,
         completed: completed,
         createdAt: createdAt,
         updatedAt: updatedAt,
         version: version,
       );

  /// Returns a shallow copy of this [OnboardingRecordRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  OnboardingRecordRow copyWith({
    Object? id = _Undefined,
    String? onboardingId,
    String? productId,
    int? currentBaselineRevision,
    int? pendingClarifications,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return OnboardingRecordRow(
      id: id is int? ? id : this.id,
      onboardingId: onboardingId ?? this.onboardingId,
      productId: productId ?? this.productId,
      currentBaselineRevision:
          currentBaselineRevision ?? this.currentBaselineRevision,
      pendingClarifications:
          pendingClarifications ?? this.pendingClarifications,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}

class OnboardingRecordRowUpdateTable
    extends _i1.UpdateTable<OnboardingRecordRowTable> {
  OnboardingRecordRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> onboardingId(String value) => _i1.ColumnValue(
    table.onboardingId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<int, int> currentBaselineRevision(int value) =>
      _i1.ColumnValue(
        table.currentBaselineRevision,
        value,
      );

  _i1.ColumnValue<int, int> pendingClarifications(int value) => _i1.ColumnValue(
    table.pendingClarifications,
    value,
  );

  _i1.ColumnValue<bool, bool> completed(bool value) => _i1.ColumnValue(
    table.completed,
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

class OnboardingRecordRowTable extends _i1.Table<int?> {
  OnboardingRecordRowTable({super.tableRelation})
    : super(tableName: 'onboarding_record') {
    updateTable = OnboardingRecordRowUpdateTable(this);
    onboardingId = _i1.ColumnString(
      'onboardingId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    currentBaselineRevision = _i1.ColumnInt(
      'currentBaselineRevision',
      this,
    );
    pendingClarifications = _i1.ColumnInt(
      'pendingClarifications',
      this,
    );
    completed = _i1.ColumnBool(
      'completed',
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

  late final OnboardingRecordRowUpdateTable updateTable;

  late final _i1.ColumnString onboardingId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnInt currentBaselineRevision;

  late final _i1.ColumnInt pendingClarifications;

  late final _i1.ColumnBool completed;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    onboardingId,
    productId,
    currentBaselineRevision,
    pendingClarifications,
    completed,
    createdAt,
    updatedAt,
    version,
  ];
}

class OnboardingRecordRowInclude extends _i1.IncludeObject {
  OnboardingRecordRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => OnboardingRecordRow.t;
}

class OnboardingRecordRowIncludeList extends _i1.IncludeList {
  OnboardingRecordRowIncludeList._({
    _i1.WhereExpressionBuilder<OnboardingRecordRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OnboardingRecordRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => OnboardingRecordRow.t;
}

class OnboardingRecordRowRepository {
  const OnboardingRecordRowRepository._();

  /// Returns a list of [OnboardingRecordRow]s matching the given query parameters.
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
  Future<List<OnboardingRecordRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<OnboardingRecordRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<OnboardingRecordRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<OnboardingRecordRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OnboardingRecordRow>(
      where: where?.call(OnboardingRecordRow.t),
      orderBy: orderBy?.call(OnboardingRecordRow.t),
      orderByList: orderByList?.call(OnboardingRecordRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [OnboardingRecordRow] matching the given query parameters.
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
  Future<OnboardingRecordRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<OnboardingRecordRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<OnboardingRecordRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<OnboardingRecordRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OnboardingRecordRow>(
      where: where?.call(OnboardingRecordRow.t),
      orderBy: orderBy?.call(OnboardingRecordRow.t),
      orderByList: orderByList?.call(OnboardingRecordRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OnboardingRecordRow] by its [id] or null if no such row exists.
  Future<OnboardingRecordRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OnboardingRecordRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OnboardingRecordRow]s in the list and returns the inserted rows.
  ///
  /// The returned [OnboardingRecordRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<OnboardingRecordRow>> insert(
    _i1.DatabaseSession session,
    List<OnboardingRecordRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<OnboardingRecordRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [OnboardingRecordRow] and returns the inserted row.
  ///
  /// The returned [OnboardingRecordRow] will have its `id` field set.
  Future<OnboardingRecordRow> insertRow(
    _i1.DatabaseSession session,
    OnboardingRecordRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<OnboardingRecordRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [OnboardingRecordRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<OnboardingRecordRow>> update(
    _i1.DatabaseSession session,
    List<OnboardingRecordRow> rows, {
    _i1.ColumnSelections<OnboardingRecordRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<OnboardingRecordRow>(
      rows,
      columns: columns?.call(OnboardingRecordRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OnboardingRecordRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OnboardingRecordRow> updateRow(
    _i1.DatabaseSession session,
    OnboardingRecordRow row, {
    _i1.ColumnSelections<OnboardingRecordRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<OnboardingRecordRow>(
      row,
      columns: columns?.call(OnboardingRecordRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OnboardingRecordRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OnboardingRecordRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<OnboardingRecordRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<OnboardingRecordRow>(
      id,
      columnValues: columnValues(OnboardingRecordRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OnboardingRecordRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<OnboardingRecordRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<OnboardingRecordRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<OnboardingRecordRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<OnboardingRecordRowTable>? orderBy,
    _i1.OrderByListBuilder<OnboardingRecordRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<OnboardingRecordRow>(
      columnValues: columnValues(OnboardingRecordRow.t.updateTable),
      where: where(OnboardingRecordRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OnboardingRecordRow.t),
      orderByList: orderByList?.call(OnboardingRecordRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [OnboardingRecordRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<OnboardingRecordRow>> delete(
    _i1.DatabaseSession session,
    List<OnboardingRecordRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<OnboardingRecordRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [OnboardingRecordRow].
  Future<OnboardingRecordRow> deleteRow(
    _i1.DatabaseSession session,
    OnboardingRecordRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OnboardingRecordRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<OnboardingRecordRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<OnboardingRecordRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<OnboardingRecordRow>(
      where: where(OnboardingRecordRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<OnboardingRecordRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<OnboardingRecordRow>(
      where: where?.call(OnboardingRecordRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OnboardingRecordRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<OnboardingRecordRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OnboardingRecordRow>(
      where: where(OnboardingRecordRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

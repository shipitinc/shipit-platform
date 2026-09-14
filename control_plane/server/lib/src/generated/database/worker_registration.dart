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

abstract class WorkerRegistrationRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  WorkerRegistrationRow._({
    this.id,
    required this.workerId,
    required this.poolId,
    required this.capabilitiesJson,
    required this.status,
    required this.currentLoad,
    required this.maxConcurrency,
    required this.lastHeartbeat,
    this.artifactCacheJson,
    this.platform,
  });

  factory WorkerRegistrationRow({
    int? id,
    required String workerId,
    required String poolId,
    required String capabilitiesJson,
    required String status,
    required int currentLoad,
    required int maxConcurrency,
    required DateTime lastHeartbeat,
    String? artifactCacheJson,
    String? platform,
  }) = _WorkerRegistrationRowImpl;

  factory WorkerRegistrationRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkerRegistrationRow(
      id: jsonSerialization['id'] as int?,
      workerId: jsonSerialization['workerId'] as String,
      poolId: jsonSerialization['poolId'] as String,
      capabilitiesJson: jsonSerialization['capabilitiesJson'] as String,
      status: jsonSerialization['status'] as String,
      currentLoad: jsonSerialization['currentLoad'] as int,
      maxConcurrency: jsonSerialization['maxConcurrency'] as int,
      lastHeartbeat: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastHeartbeat'],
      ),
      artifactCacheJson: jsonSerialization['artifactCacheJson'] as String?,
      platform: jsonSerialization['platform'] as String?,
    );
  }

  static final t = WorkerRegistrationRowTable();

  static const db = WorkerRegistrationRowRepository._();

  @override
  int? id;

  String workerId;

  String poolId;

  String capabilitiesJson;

  String status;

  int currentLoad;

  int maxConcurrency;

  DateTime lastHeartbeat;

  String? artifactCacheJson;

  String? platform;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [WorkerRegistrationRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerRegistrationRow copyWith({
    int? id,
    String? workerId,
    String? poolId,
    String? capabilitiesJson,
    String? status,
    int? currentLoad,
    int? maxConcurrency,
    DateTime? lastHeartbeat,
    String? artifactCacheJson,
    String? platform,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerRegistrationRow',
      if (id != null) 'id': id,
      'workerId': workerId,
      'poolId': poolId,
      'capabilitiesJson': capabilitiesJson,
      'status': status,
      'currentLoad': currentLoad,
      'maxConcurrency': maxConcurrency,
      'lastHeartbeat': lastHeartbeat.toJson(),
      if (artifactCacheJson != null) 'artifactCacheJson': artifactCacheJson,
      if (platform != null) 'platform': platform,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WorkerRegistrationRowInclude include() {
    return WorkerRegistrationRowInclude._();
  }

  static WorkerRegistrationRowIncludeList includeList({
    _i1.WhereExpressionBuilder<WorkerRegistrationRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerRegistrationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerRegistrationRowTable>? orderByList,
    WorkerRegistrationRowInclude? include,
  }) {
    return WorkerRegistrationRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerRegistrationRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(WorkerRegistrationRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerRegistrationRowImpl extends WorkerRegistrationRow {
  _WorkerRegistrationRowImpl({
    int? id,
    required String workerId,
    required String poolId,
    required String capabilitiesJson,
    required String status,
    required int currentLoad,
    required int maxConcurrency,
    required DateTime lastHeartbeat,
    String? artifactCacheJson,
    String? platform,
  }) : super._(
         id: id,
         workerId: workerId,
         poolId: poolId,
         capabilitiesJson: capabilitiesJson,
         status: status,
         currentLoad: currentLoad,
         maxConcurrency: maxConcurrency,
         lastHeartbeat: lastHeartbeat,
         artifactCacheJson: artifactCacheJson,
         platform: platform,
       );

  /// Returns a shallow copy of this [WorkerRegistrationRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerRegistrationRow copyWith({
    Object? id = _Undefined,
    String? workerId,
    String? poolId,
    String? capabilitiesJson,
    String? status,
    int? currentLoad,
    int? maxConcurrency,
    DateTime? lastHeartbeat,
    Object? artifactCacheJson = _Undefined,
    Object? platform = _Undefined,
  }) {
    return WorkerRegistrationRow(
      id: id is int? ? id : this.id,
      workerId: workerId ?? this.workerId,
      poolId: poolId ?? this.poolId,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      status: status ?? this.status,
      currentLoad: currentLoad ?? this.currentLoad,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      artifactCacheJson: artifactCacheJson is String?
          ? artifactCacheJson
          : this.artifactCacheJson,
      platform: platform is String? ? platform : this.platform,
    );
  }
}

class WorkerRegistrationRowUpdateTable
    extends _i1.UpdateTable<WorkerRegistrationRowTable> {
  WorkerRegistrationRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> workerId(String value) => _i1.ColumnValue(
    table.workerId,
    value,
  );

  _i1.ColumnValue<String, String> poolId(String value) => _i1.ColumnValue(
    table.poolId,
    value,
  );

  _i1.ColumnValue<String, String> capabilitiesJson(String value) =>
      _i1.ColumnValue(
        table.capabilitiesJson,
        value,
      );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<int, int> currentLoad(int value) => _i1.ColumnValue(
    table.currentLoad,
    value,
  );

  _i1.ColumnValue<int, int> maxConcurrency(int value) => _i1.ColumnValue(
    table.maxConcurrency,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> lastHeartbeat(DateTime value) =>
      _i1.ColumnValue(
        table.lastHeartbeat,
        value,
      );

  _i1.ColumnValue<String, String> artifactCacheJson(String? value) =>
      _i1.ColumnValue(
        table.artifactCacheJson,
        value,
      );

  _i1.ColumnValue<String, String> platform(String? value) => _i1.ColumnValue(
    table.platform,
    value,
  );
}

class WorkerRegistrationRowTable extends _i1.Table<int?> {
  WorkerRegistrationRowTable({super.tableRelation})
    : super(tableName: 'worker_registration') {
    updateTable = WorkerRegistrationRowUpdateTable(this);
    workerId = _i1.ColumnString(
      'workerId',
      this,
    );
    poolId = _i1.ColumnString(
      'poolId',
      this,
    );
    capabilitiesJson = _i1.ColumnString(
      'capabilitiesJson',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    currentLoad = _i1.ColumnInt(
      'currentLoad',
      this,
    );
    maxConcurrency = _i1.ColumnInt(
      'maxConcurrency',
      this,
    );
    lastHeartbeat = _i1.ColumnDateTime(
      'lastHeartbeat',
      this,
    );
    artifactCacheJson = _i1.ColumnString(
      'artifactCacheJson',
      this,
    );
    platform = _i1.ColumnString(
      'platform',
      this,
    );
  }

  late final WorkerRegistrationRowUpdateTable updateTable;

  late final _i1.ColumnString workerId;

  late final _i1.ColumnString poolId;

  late final _i1.ColumnString capabilitiesJson;

  late final _i1.ColumnString status;

  late final _i1.ColumnInt currentLoad;

  late final _i1.ColumnInt maxConcurrency;

  late final _i1.ColumnDateTime lastHeartbeat;

  late final _i1.ColumnString artifactCacheJson;

  late final _i1.ColumnString platform;

  @override
  List<_i1.Column> get columns => [
    id,
    workerId,
    poolId,
    capabilitiesJson,
    status,
    currentLoad,
    maxConcurrency,
    lastHeartbeat,
    artifactCacheJson,
    platform,
  ];
}

class WorkerRegistrationRowInclude extends _i1.IncludeObject {
  WorkerRegistrationRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => WorkerRegistrationRow.t;
}

class WorkerRegistrationRowIncludeList extends _i1.IncludeList {
  WorkerRegistrationRowIncludeList._({
    _i1.WhereExpressionBuilder<WorkerRegistrationRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WorkerRegistrationRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => WorkerRegistrationRow.t;
}

class WorkerRegistrationRowRepository {
  const WorkerRegistrationRowRepository._();

  /// Returns a list of [WorkerRegistrationRow]s matching the given query parameters.
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
  Future<List<WorkerRegistrationRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerRegistrationRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerRegistrationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerRegistrationRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WorkerRegistrationRow>(
      where: where?.call(WorkerRegistrationRow.t),
      orderBy: orderBy?.call(WorkerRegistrationRow.t),
      orderByList: orderByList?.call(WorkerRegistrationRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WorkerRegistrationRow] matching the given query parameters.
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
  Future<WorkerRegistrationRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerRegistrationRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<WorkerRegistrationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerRegistrationRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WorkerRegistrationRow>(
      where: where?.call(WorkerRegistrationRow.t),
      orderBy: orderBy?.call(WorkerRegistrationRow.t),
      orderByList: orderByList?.call(WorkerRegistrationRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WorkerRegistrationRow] by its [id] or null if no such row exists.
  Future<WorkerRegistrationRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WorkerRegistrationRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WorkerRegistrationRow]s in the list and returns the inserted rows.
  ///
  /// The returned [WorkerRegistrationRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<WorkerRegistrationRow>> insert(
    _i1.DatabaseSession session,
    List<WorkerRegistrationRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<WorkerRegistrationRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [WorkerRegistrationRow] and returns the inserted row.
  ///
  /// The returned [WorkerRegistrationRow] will have its `id` field set.
  Future<WorkerRegistrationRow> insertRow(
    _i1.DatabaseSession session,
    WorkerRegistrationRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<WorkerRegistrationRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [WorkerRegistrationRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<WorkerRegistrationRow>> update(
    _i1.DatabaseSession session,
    List<WorkerRegistrationRow> rows, {
    _i1.ColumnSelections<WorkerRegistrationRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<WorkerRegistrationRow>(
      rows,
      columns: columns?.call(WorkerRegistrationRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerRegistrationRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WorkerRegistrationRow> updateRow(
    _i1.DatabaseSession session,
    WorkerRegistrationRow row, {
    _i1.ColumnSelections<WorkerRegistrationRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<WorkerRegistrationRow>(
      row,
      columns: columns?.call(WorkerRegistrationRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerRegistrationRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WorkerRegistrationRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<WorkerRegistrationRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<WorkerRegistrationRow>(
      id,
      columnValues: columnValues(WorkerRegistrationRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WorkerRegistrationRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<WorkerRegistrationRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<WorkerRegistrationRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<WorkerRegistrationRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerRegistrationRowTable>? orderBy,
    _i1.OrderByListBuilder<WorkerRegistrationRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<WorkerRegistrationRow>(
      columnValues: columnValues(WorkerRegistrationRow.t.updateTable),
      where: where(WorkerRegistrationRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerRegistrationRow.t),
      orderByList: orderByList?.call(WorkerRegistrationRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [WorkerRegistrationRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<WorkerRegistrationRow>> delete(
    _i1.DatabaseSession session,
    List<WorkerRegistrationRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<WorkerRegistrationRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [WorkerRegistrationRow].
  Future<WorkerRegistrationRow> deleteRow(
    _i1.DatabaseSession session,
    WorkerRegistrationRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WorkerRegistrationRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<WorkerRegistrationRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerRegistrationRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<WorkerRegistrationRow>(
      where: where(WorkerRegistrationRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerRegistrationRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<WorkerRegistrationRow>(
      where: where?.call(WorkerRegistrationRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WorkerRegistrationRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerRegistrationRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WorkerRegistrationRow>(
      where: where(WorkerRegistrationRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

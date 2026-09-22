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

abstract class WorkerExecutionRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  WorkerExecutionRow._({
    this.id,
    required this.workerExecutionId,
    required this.workItemId,
    required this.repositoryPath,
    required this.requestedStartingRevision,
    this.requiredCapabilitiesJson,
    required this.status,
    required this.cleanupPolicy,
    this.workerId,
    this.workspaceId,
    this.agentExecutionId,
    this.resultId,
    this.endingRevision,
    this.cleanupStatus,
    this.failureCode,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.reason,
    required this.version,
  });

  factory WorkerExecutionRow({
    int? id,
    required String workerExecutionId,
    required String workItemId,
    required String repositoryPath,
    required String requestedStartingRevision,
    String? requiredCapabilitiesJson,
    required String status,
    required String cleanupPolicy,
    String? workerId,
    String? workspaceId,
    String? agentExecutionId,
    String? resultId,
    String? endingRevision,
    String? cleanupStatus,
    String? failureCode,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? reason,
    required int version,
  }) = _WorkerExecutionRowImpl;

  factory WorkerExecutionRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkerExecutionRow(
      id: jsonSerialization['id'] as int?,
      workerExecutionId: jsonSerialization['workerExecutionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      repositoryPath: jsonSerialization['repositoryPath'] as String,
      requestedStartingRevision:
          jsonSerialization['requestedStartingRevision'] as String,
      requiredCapabilitiesJson:
          jsonSerialization['requiredCapabilitiesJson'] as String?,
      status: jsonSerialization['status'] as String,
      cleanupPolicy: jsonSerialization['cleanupPolicy'] as String,
      workerId: jsonSerialization['workerId'] as String?,
      workspaceId: jsonSerialization['workspaceId'] as String?,
      agentExecutionId: jsonSerialization['agentExecutionId'] as String?,
      resultId: jsonSerialization['resultId'] as String?,
      endingRevision: jsonSerialization['endingRevision'] as String?,
      cleanupStatus: jsonSerialization['cleanupStatus'] as String?,
      failureCode: jsonSerialization['failureCode'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      endedAt: jsonSerialization['endedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['endedAt']),
      reason: jsonSerialization['reason'] as String?,
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = WorkerExecutionRowTable();

  static const db = WorkerExecutionRowRepository._();

  @override
  int? id;

  String workerExecutionId;

  String workItemId;

  String repositoryPath;

  String requestedStartingRevision;

  String? requiredCapabilitiesJson;

  String status;

  String cleanupPolicy;

  String? workerId;

  String? workspaceId;

  String? agentExecutionId;

  String? resultId;

  String? endingRevision;

  String? cleanupStatus;

  String? failureCode;

  DateTime? createdAt;

  DateTime? startedAt;

  DateTime? endedAt;

  String? reason;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [WorkerExecutionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerExecutionRow copyWith({
    int? id,
    String? workerExecutionId,
    String? workItemId,
    String? repositoryPath,
    String? requestedStartingRevision,
    String? requiredCapabilitiesJson,
    String? status,
    String? cleanupPolicy,
    String? workerId,
    String? workspaceId,
    String? agentExecutionId,
    String? resultId,
    String? endingRevision,
    String? cleanupStatus,
    String? failureCode,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? reason,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerExecutionRow',
      if (id != null) 'id': id,
      'workerExecutionId': workerExecutionId,
      'workItemId': workItemId,
      'repositoryPath': repositoryPath,
      'requestedStartingRevision': requestedStartingRevision,
      if (requiredCapabilitiesJson != null)
        'requiredCapabilitiesJson': requiredCapabilitiesJson,
      'status': status,
      'cleanupPolicy': cleanupPolicy,
      if (workerId != null) 'workerId': workerId,
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (agentExecutionId != null) 'agentExecutionId': agentExecutionId,
      if (resultId != null) 'resultId': resultId,
      if (endingRevision != null) 'endingRevision': endingRevision,
      if (cleanupStatus != null) 'cleanupStatus': cleanupStatus,
      if (failureCode != null) 'failureCode': failureCode,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (endedAt != null) 'endedAt': endedAt?.toJson(),
      if (reason != null) 'reason': reason,
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WorkerExecutionRowInclude include() {
    return WorkerExecutionRowInclude._();
  }

  static WorkerExecutionRowIncludeList includeList({
    _i1.WhereExpressionBuilder<WorkerExecutionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerExecutionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerExecutionRowTable>? orderByList,
    WorkerExecutionRowInclude? include,
  }) {
    return WorkerExecutionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerExecutionRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(WorkerExecutionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerExecutionRowImpl extends WorkerExecutionRow {
  _WorkerExecutionRowImpl({
    int? id,
    required String workerExecutionId,
    required String workItemId,
    required String repositoryPath,
    required String requestedStartingRevision,
    String? requiredCapabilitiesJson,
    required String status,
    required String cleanupPolicy,
    String? workerId,
    String? workspaceId,
    String? agentExecutionId,
    String? resultId,
    String? endingRevision,
    String? cleanupStatus,
    String? failureCode,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? reason,
    required int version,
  }) : super._(
         id: id,
         workerExecutionId: workerExecutionId,
         workItemId: workItemId,
         repositoryPath: repositoryPath,
         requestedStartingRevision: requestedStartingRevision,
         requiredCapabilitiesJson: requiredCapabilitiesJson,
         status: status,
         cleanupPolicy: cleanupPolicy,
         workerId: workerId,
         workspaceId: workspaceId,
         agentExecutionId: agentExecutionId,
         resultId: resultId,
         endingRevision: endingRevision,
         cleanupStatus: cleanupStatus,
         failureCode: failureCode,
         createdAt: createdAt,
         startedAt: startedAt,
         endedAt: endedAt,
         reason: reason,
         version: version,
       );

  /// Returns a shallow copy of this [WorkerExecutionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerExecutionRow copyWith({
    Object? id = _Undefined,
    String? workerExecutionId,
    String? workItemId,
    String? repositoryPath,
    String? requestedStartingRevision,
    Object? requiredCapabilitiesJson = _Undefined,
    String? status,
    String? cleanupPolicy,
    Object? workerId = _Undefined,
    Object? workspaceId = _Undefined,
    Object? agentExecutionId = _Undefined,
    Object? resultId = _Undefined,
    Object? endingRevision = _Undefined,
    Object? cleanupStatus = _Undefined,
    Object? failureCode = _Undefined,
    Object? createdAt = _Undefined,
    Object? startedAt = _Undefined,
    Object? endedAt = _Undefined,
    Object? reason = _Undefined,
    int? version,
  }) {
    return WorkerExecutionRow(
      id: id is int? ? id : this.id,
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      repositoryPath: repositoryPath ?? this.repositoryPath,
      requestedStartingRevision:
          requestedStartingRevision ?? this.requestedStartingRevision,
      requiredCapabilitiesJson: requiredCapabilitiesJson is String?
          ? requiredCapabilitiesJson
          : this.requiredCapabilitiesJson,
      status: status ?? this.status,
      cleanupPolicy: cleanupPolicy ?? this.cleanupPolicy,
      workerId: workerId is String? ? workerId : this.workerId,
      workspaceId: workspaceId is String? ? workspaceId : this.workspaceId,
      agentExecutionId: agentExecutionId is String?
          ? agentExecutionId
          : this.agentExecutionId,
      resultId: resultId is String? ? resultId : this.resultId,
      endingRevision: endingRevision is String?
          ? endingRevision
          : this.endingRevision,
      cleanupStatus: cleanupStatus is String?
          ? cleanupStatus
          : this.cleanupStatus,
      failureCode: failureCode is String? ? failureCode : this.failureCode,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      endedAt: endedAt is DateTime? ? endedAt : this.endedAt,
      reason: reason is String? ? reason : this.reason,
      version: version ?? this.version,
    );
  }
}

class WorkerExecutionRowUpdateTable
    extends _i1.UpdateTable<WorkerExecutionRowTable> {
  WorkerExecutionRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> workerExecutionId(String value) =>
      _i1.ColumnValue(
        table.workerExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> repositoryPath(String value) =>
      _i1.ColumnValue(
        table.repositoryPath,
        value,
      );

  _i1.ColumnValue<String, String> requestedStartingRevision(String value) =>
      _i1.ColumnValue(
        table.requestedStartingRevision,
        value,
      );

  _i1.ColumnValue<String, String> requiredCapabilitiesJson(String? value) =>
      _i1.ColumnValue(
        table.requiredCapabilitiesJson,
        value,
      );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> cleanupPolicy(String value) =>
      _i1.ColumnValue(
        table.cleanupPolicy,
        value,
      );

  _i1.ColumnValue<String, String> workerId(String? value) => _i1.ColumnValue(
    table.workerId,
    value,
  );

  _i1.ColumnValue<String, String> workspaceId(String? value) => _i1.ColumnValue(
    table.workspaceId,
    value,
  );

  _i1.ColumnValue<String, String> agentExecutionId(String? value) =>
      _i1.ColumnValue(
        table.agentExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> resultId(String? value) => _i1.ColumnValue(
    table.resultId,
    value,
  );

  _i1.ColumnValue<String, String> endingRevision(String? value) =>
      _i1.ColumnValue(
        table.endingRevision,
        value,
      );

  _i1.ColumnValue<String, String> cleanupStatus(String? value) =>
      _i1.ColumnValue(
        table.cleanupStatus,
        value,
      );

  _i1.ColumnValue<String, String> failureCode(String? value) => _i1.ColumnValue(
    table.failureCode,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime? value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> startedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.startedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> endedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.endedAt,
        value,
      );

  _i1.ColumnValue<String, String> reason(String? value) => _i1.ColumnValue(
    table.reason,
    value,
  );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class WorkerExecutionRowTable extends _i1.Table<int?> {
  WorkerExecutionRowTable({super.tableRelation})
    : super(tableName: 'worker_execution') {
    updateTable = WorkerExecutionRowUpdateTable(this);
    workerExecutionId = _i1.ColumnString(
      'workerExecutionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    repositoryPath = _i1.ColumnString(
      'repositoryPath',
      this,
    );
    requestedStartingRevision = _i1.ColumnString(
      'requestedStartingRevision',
      this,
    );
    requiredCapabilitiesJson = _i1.ColumnString(
      'requiredCapabilitiesJson',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    cleanupPolicy = _i1.ColumnString(
      'cleanupPolicy',
      this,
    );
    workerId = _i1.ColumnString(
      'workerId',
      this,
    );
    workspaceId = _i1.ColumnString(
      'workspaceId',
      this,
    );
    agentExecutionId = _i1.ColumnString(
      'agentExecutionId',
      this,
    );
    resultId = _i1.ColumnString(
      'resultId',
      this,
    );
    endingRevision = _i1.ColumnString(
      'endingRevision',
      this,
    );
    cleanupStatus = _i1.ColumnString(
      'cleanupStatus',
      this,
    );
    failureCode = _i1.ColumnString(
      'failureCode',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    startedAt = _i1.ColumnDateTime(
      'startedAt',
      this,
    );
    endedAt = _i1.ColumnDateTime(
      'endedAt',
      this,
    );
    reason = _i1.ColumnString(
      'reason',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final WorkerExecutionRowUpdateTable updateTable;

  late final _i1.ColumnString workerExecutionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString repositoryPath;

  late final _i1.ColumnString requestedStartingRevision;

  late final _i1.ColumnString requiredCapabilitiesJson;

  late final _i1.ColumnString status;

  late final _i1.ColumnString cleanupPolicy;

  late final _i1.ColumnString workerId;

  late final _i1.ColumnString workspaceId;

  late final _i1.ColumnString agentExecutionId;

  late final _i1.ColumnString resultId;

  late final _i1.ColumnString endingRevision;

  late final _i1.ColumnString cleanupStatus;

  late final _i1.ColumnString failureCode;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime startedAt;

  late final _i1.ColumnDateTime endedAt;

  late final _i1.ColumnString reason;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    workerExecutionId,
    workItemId,
    repositoryPath,
    requestedStartingRevision,
    requiredCapabilitiesJson,
    status,
    cleanupPolicy,
    workerId,
    workspaceId,
    agentExecutionId,
    resultId,
    endingRevision,
    cleanupStatus,
    failureCode,
    createdAt,
    startedAt,
    endedAt,
    reason,
    version,
  ];
}

class WorkerExecutionRowInclude extends _i1.IncludeObject {
  WorkerExecutionRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => WorkerExecutionRow.t;
}

class WorkerExecutionRowIncludeList extends _i1.IncludeList {
  WorkerExecutionRowIncludeList._({
    _i1.WhereExpressionBuilder<WorkerExecutionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WorkerExecutionRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => WorkerExecutionRow.t;
}

class WorkerExecutionRowRepository {
  const WorkerExecutionRowRepository._();

  /// Returns a list of [WorkerExecutionRow]s matching the given query parameters.
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
  Future<List<WorkerExecutionRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerExecutionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerExecutionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerExecutionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WorkerExecutionRow>(
      where: where?.call(WorkerExecutionRow.t),
      orderBy: orderBy?.call(WorkerExecutionRow.t),
      orderByList: orderByList?.call(WorkerExecutionRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WorkerExecutionRow] matching the given query parameters.
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
  Future<WorkerExecutionRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerExecutionRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<WorkerExecutionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerExecutionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WorkerExecutionRow>(
      where: where?.call(WorkerExecutionRow.t),
      orderBy: orderBy?.call(WorkerExecutionRow.t),
      orderByList: orderByList?.call(WorkerExecutionRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WorkerExecutionRow] by its [id] or null if no such row exists.
  Future<WorkerExecutionRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WorkerExecutionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WorkerExecutionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [WorkerExecutionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<WorkerExecutionRow>> insert(
    _i1.DatabaseSession session,
    List<WorkerExecutionRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<WorkerExecutionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [WorkerExecutionRow] and returns the inserted row.
  ///
  /// The returned [WorkerExecutionRow] will have its `id` field set.
  Future<WorkerExecutionRow> insertRow(
    _i1.DatabaseSession session,
    WorkerExecutionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<WorkerExecutionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [WorkerExecutionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<WorkerExecutionRow>> update(
    _i1.DatabaseSession session,
    List<WorkerExecutionRow> rows, {
    _i1.ColumnSelections<WorkerExecutionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<WorkerExecutionRow>(
      rows,
      columns: columns?.call(WorkerExecutionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerExecutionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WorkerExecutionRow> updateRow(
    _i1.DatabaseSession session,
    WorkerExecutionRow row, {
    _i1.ColumnSelections<WorkerExecutionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<WorkerExecutionRow>(
      row,
      columns: columns?.call(WorkerExecutionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerExecutionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WorkerExecutionRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<WorkerExecutionRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<WorkerExecutionRow>(
      id,
      columnValues: columnValues(WorkerExecutionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WorkerExecutionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<WorkerExecutionRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<WorkerExecutionRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<WorkerExecutionRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerExecutionRowTable>? orderBy,
    _i1.OrderByListBuilder<WorkerExecutionRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<WorkerExecutionRow>(
      columnValues: columnValues(WorkerExecutionRow.t.updateTable),
      where: where(WorkerExecutionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerExecutionRow.t),
      orderByList: orderByList?.call(WorkerExecutionRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [WorkerExecutionRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<WorkerExecutionRow>> delete(
    _i1.DatabaseSession session,
    List<WorkerExecutionRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<WorkerExecutionRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [WorkerExecutionRow].
  Future<WorkerExecutionRow> deleteRow(
    _i1.DatabaseSession session,
    WorkerExecutionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WorkerExecutionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<WorkerExecutionRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerExecutionRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<WorkerExecutionRow>(
      where: where(WorkerExecutionRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerExecutionRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<WorkerExecutionRow>(
      where: where?.call(WorkerExecutionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WorkerExecutionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerExecutionRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WorkerExecutionRow>(
      where: where(WorkerExecutionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

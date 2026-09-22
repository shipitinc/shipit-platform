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

abstract class WorkerResultRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  WorkerResultRow._({
    this.id,
    required this.workerExecutionId,
    required this.workItemId,
    required this.status,
    required this.workerId,
    required this.workspaceId,
    required this.startingRevision,
    this.endingRevision,
    this.agentExecutionId,
    this.agentResultStatus,
    this.verificationId,
    this.verificationPassed,
    this.changedFilesJson,
    this.diffSummary,
    this.diffRef,
    required this.cleanupStatus,
    required this.failureCode,
    this.failureDetail,
    required this.startedAt,
    required this.endedAt,
  });

  factory WorkerResultRow({
    int? id,
    required String workerExecutionId,
    required String workItemId,
    required String status,
    required String workerId,
    required String workspaceId,
    required String startingRevision,
    String? endingRevision,
    String? agentExecutionId,
    String? agentResultStatus,
    String? verificationId,
    bool? verificationPassed,
    String? changedFilesJson,
    String? diffSummary,
    String? diffRef,
    required String cleanupStatus,
    required String failureCode,
    String? failureDetail,
    required DateTime startedAt,
    required DateTime endedAt,
  }) = _WorkerResultRowImpl;

  factory WorkerResultRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkerResultRow(
      id: jsonSerialization['id'] as int?,
      workerExecutionId: jsonSerialization['workerExecutionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      status: jsonSerialization['status'] as String,
      workerId: jsonSerialization['workerId'] as String,
      workspaceId: jsonSerialization['workspaceId'] as String,
      startingRevision: jsonSerialization['startingRevision'] as String,
      endingRevision: jsonSerialization['endingRevision'] as String?,
      agentExecutionId: jsonSerialization['agentExecutionId'] as String?,
      agentResultStatus: jsonSerialization['agentResultStatus'] as String?,
      verificationId: jsonSerialization['verificationId'] as String?,
      verificationPassed: jsonSerialization['verificationPassed'] == null
          ? null
          : _i1.BoolJsonExtension.fromJson(
              jsonSerialization['verificationPassed'],
            ),
      changedFilesJson: jsonSerialization['changedFilesJson'] as String?,
      diffSummary: jsonSerialization['diffSummary'] as String?,
      diffRef: jsonSerialization['diffRef'] as String?,
      cleanupStatus: jsonSerialization['cleanupStatus'] as String,
      failureCode: jsonSerialization['failureCode'] as String,
      failureDetail: jsonSerialization['failureDetail'] as String?,
      startedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startedAt'],
      ),
      endedAt: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['endedAt']),
    );
  }

  static final t = WorkerResultRowTable();

  static const db = WorkerResultRowRepository._();

  @override
  int? id;

  String workerExecutionId;

  String workItemId;

  String status;

  String workerId;

  String workspaceId;

  String startingRevision;

  String? endingRevision;

  String? agentExecutionId;

  String? agentResultStatus;

  String? verificationId;

  bool? verificationPassed;

  String? changedFilesJson;

  String? diffSummary;

  String? diffRef;

  String cleanupStatus;

  String failureCode;

  String? failureDetail;

  DateTime startedAt;

  DateTime endedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [WorkerResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerResultRow copyWith({
    int? id,
    String? workerExecutionId,
    String? workItemId,
    String? status,
    String? workerId,
    String? workspaceId,
    String? startingRevision,
    String? endingRevision,
    String? agentExecutionId,
    String? agentResultStatus,
    String? verificationId,
    bool? verificationPassed,
    String? changedFilesJson,
    String? diffSummary,
    String? diffRef,
    String? cleanupStatus,
    String? failureCode,
    String? failureDetail,
    DateTime? startedAt,
    DateTime? endedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerResultRow',
      if (id != null) 'id': id,
      'workerExecutionId': workerExecutionId,
      'workItemId': workItemId,
      'status': status,
      'workerId': workerId,
      'workspaceId': workspaceId,
      'startingRevision': startingRevision,
      if (endingRevision != null) 'endingRevision': endingRevision,
      if (agentExecutionId != null) 'agentExecutionId': agentExecutionId,
      if (agentResultStatus != null) 'agentResultStatus': agentResultStatus,
      if (verificationId != null) 'verificationId': verificationId,
      if (verificationPassed != null) 'verificationPassed': verificationPassed,
      if (changedFilesJson != null) 'changedFilesJson': changedFilesJson,
      if (diffSummary != null) 'diffSummary': diffSummary,
      if (diffRef != null) 'diffRef': diffRef,
      'cleanupStatus': cleanupStatus,
      'failureCode': failureCode,
      if (failureDetail != null) 'failureDetail': failureDetail,
      'startedAt': startedAt.toJson(),
      'endedAt': endedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WorkerResultRowInclude include() {
    return WorkerResultRowInclude._();
  }

  static WorkerResultRowIncludeList includeList({
    _i1.WhereExpressionBuilder<WorkerResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerResultRowTable>? orderByList,
    WorkerResultRowInclude? include,
  }) {
    return WorkerResultRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerResultRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(WorkerResultRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerResultRowImpl extends WorkerResultRow {
  _WorkerResultRowImpl({
    int? id,
    required String workerExecutionId,
    required String workItemId,
    required String status,
    required String workerId,
    required String workspaceId,
    required String startingRevision,
    String? endingRevision,
    String? agentExecutionId,
    String? agentResultStatus,
    String? verificationId,
    bool? verificationPassed,
    String? changedFilesJson,
    String? diffSummary,
    String? diffRef,
    required String cleanupStatus,
    required String failureCode,
    String? failureDetail,
    required DateTime startedAt,
    required DateTime endedAt,
  }) : super._(
         id: id,
         workerExecutionId: workerExecutionId,
         workItemId: workItemId,
         status: status,
         workerId: workerId,
         workspaceId: workspaceId,
         startingRevision: startingRevision,
         endingRevision: endingRevision,
         agentExecutionId: agentExecutionId,
         agentResultStatus: agentResultStatus,
         verificationId: verificationId,
         verificationPassed: verificationPassed,
         changedFilesJson: changedFilesJson,
         diffSummary: diffSummary,
         diffRef: diffRef,
         cleanupStatus: cleanupStatus,
         failureCode: failureCode,
         failureDetail: failureDetail,
         startedAt: startedAt,
         endedAt: endedAt,
       );

  /// Returns a shallow copy of this [WorkerResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerResultRow copyWith({
    Object? id = _Undefined,
    String? workerExecutionId,
    String? workItemId,
    String? status,
    String? workerId,
    String? workspaceId,
    String? startingRevision,
    Object? endingRevision = _Undefined,
    Object? agentExecutionId = _Undefined,
    Object? agentResultStatus = _Undefined,
    Object? verificationId = _Undefined,
    Object? verificationPassed = _Undefined,
    Object? changedFilesJson = _Undefined,
    Object? diffSummary = _Undefined,
    Object? diffRef = _Undefined,
    String? cleanupStatus,
    String? failureCode,
    Object? failureDetail = _Undefined,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return WorkerResultRow(
      id: id is int? ? id : this.id,
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      status: status ?? this.status,
      workerId: workerId ?? this.workerId,
      workspaceId: workspaceId ?? this.workspaceId,
      startingRevision: startingRevision ?? this.startingRevision,
      endingRevision: endingRevision is String?
          ? endingRevision
          : this.endingRevision,
      agentExecutionId: agentExecutionId is String?
          ? agentExecutionId
          : this.agentExecutionId,
      agentResultStatus: agentResultStatus is String?
          ? agentResultStatus
          : this.agentResultStatus,
      verificationId: verificationId is String?
          ? verificationId
          : this.verificationId,
      verificationPassed: verificationPassed is bool?
          ? verificationPassed
          : this.verificationPassed,
      changedFilesJson: changedFilesJson is String?
          ? changedFilesJson
          : this.changedFilesJson,
      diffSummary: diffSummary is String? ? diffSummary : this.diffSummary,
      diffRef: diffRef is String? ? diffRef : this.diffRef,
      cleanupStatus: cleanupStatus ?? this.cleanupStatus,
      failureCode: failureCode ?? this.failureCode,
      failureDetail: failureDetail is String?
          ? failureDetail
          : this.failureDetail,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}

class WorkerResultRowUpdateTable extends _i1.UpdateTable<WorkerResultRowTable> {
  WorkerResultRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> workerExecutionId(String value) =>
      _i1.ColumnValue(
        table.workerExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> workerId(String value) => _i1.ColumnValue(
    table.workerId,
    value,
  );

  _i1.ColumnValue<String, String> workspaceId(String value) => _i1.ColumnValue(
    table.workspaceId,
    value,
  );

  _i1.ColumnValue<String, String> startingRevision(String value) =>
      _i1.ColumnValue(
        table.startingRevision,
        value,
      );

  _i1.ColumnValue<String, String> endingRevision(String? value) =>
      _i1.ColumnValue(
        table.endingRevision,
        value,
      );

  _i1.ColumnValue<String, String> agentExecutionId(String? value) =>
      _i1.ColumnValue(
        table.agentExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> agentResultStatus(String? value) =>
      _i1.ColumnValue(
        table.agentResultStatus,
        value,
      );

  _i1.ColumnValue<String, String> verificationId(String? value) =>
      _i1.ColumnValue(
        table.verificationId,
        value,
      );

  _i1.ColumnValue<bool, bool> verificationPassed(bool? value) =>
      _i1.ColumnValue(
        table.verificationPassed,
        value,
      );

  _i1.ColumnValue<String, String> changedFilesJson(String? value) =>
      _i1.ColumnValue(
        table.changedFilesJson,
        value,
      );

  _i1.ColumnValue<String, String> diffSummary(String? value) => _i1.ColumnValue(
    table.diffSummary,
    value,
  );

  _i1.ColumnValue<String, String> diffRef(String? value) => _i1.ColumnValue(
    table.diffRef,
    value,
  );

  _i1.ColumnValue<String, String> cleanupStatus(String value) =>
      _i1.ColumnValue(
        table.cleanupStatus,
        value,
      );

  _i1.ColumnValue<String, String> failureCode(String value) => _i1.ColumnValue(
    table.failureCode,
    value,
  );

  _i1.ColumnValue<String, String> failureDetail(String? value) =>
      _i1.ColumnValue(
        table.failureDetail,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> startedAt(DateTime value) =>
      _i1.ColumnValue(
        table.startedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> endedAt(DateTime value) =>
      _i1.ColumnValue(
        table.endedAt,
        value,
      );
}

class WorkerResultRowTable extends _i1.Table<int?> {
  WorkerResultRowTable({super.tableRelation})
    : super(tableName: 'worker_result') {
    updateTable = WorkerResultRowUpdateTable(this);
    workerExecutionId = _i1.ColumnString(
      'workerExecutionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    status = _i1.ColumnString(
      'status',
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
    startingRevision = _i1.ColumnString(
      'startingRevision',
      this,
    );
    endingRevision = _i1.ColumnString(
      'endingRevision',
      this,
    );
    agentExecutionId = _i1.ColumnString(
      'agentExecutionId',
      this,
    );
    agentResultStatus = _i1.ColumnString(
      'agentResultStatus',
      this,
    );
    verificationId = _i1.ColumnString(
      'verificationId',
      this,
    );
    verificationPassed = _i1.ColumnBool(
      'verificationPassed',
      this,
    );
    changedFilesJson = _i1.ColumnString(
      'changedFilesJson',
      this,
    );
    diffSummary = _i1.ColumnString(
      'diffSummary',
      this,
    );
    diffRef = _i1.ColumnString(
      'diffRef',
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
    failureDetail = _i1.ColumnString(
      'failureDetail',
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
  }

  late final WorkerResultRowUpdateTable updateTable;

  late final _i1.ColumnString workerExecutionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString status;

  late final _i1.ColumnString workerId;

  late final _i1.ColumnString workspaceId;

  late final _i1.ColumnString startingRevision;

  late final _i1.ColumnString endingRevision;

  late final _i1.ColumnString agentExecutionId;

  late final _i1.ColumnString agentResultStatus;

  late final _i1.ColumnString verificationId;

  late final _i1.ColumnBool verificationPassed;

  late final _i1.ColumnString changedFilesJson;

  late final _i1.ColumnString diffSummary;

  late final _i1.ColumnString diffRef;

  late final _i1.ColumnString cleanupStatus;

  late final _i1.ColumnString failureCode;

  late final _i1.ColumnString failureDetail;

  late final _i1.ColumnDateTime startedAt;

  late final _i1.ColumnDateTime endedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    workerExecutionId,
    workItemId,
    status,
    workerId,
    workspaceId,
    startingRevision,
    endingRevision,
    agentExecutionId,
    agentResultStatus,
    verificationId,
    verificationPassed,
    changedFilesJson,
    diffSummary,
    diffRef,
    cleanupStatus,
    failureCode,
    failureDetail,
    startedAt,
    endedAt,
  ];
}

class WorkerResultRowInclude extends _i1.IncludeObject {
  WorkerResultRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => WorkerResultRow.t;
}

class WorkerResultRowIncludeList extends _i1.IncludeList {
  WorkerResultRowIncludeList._({
    _i1.WhereExpressionBuilder<WorkerResultRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WorkerResultRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => WorkerResultRow.t;
}

class WorkerResultRowRepository {
  const WorkerResultRowRepository._();

  /// Returns a list of [WorkerResultRow]s matching the given query parameters.
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
  Future<List<WorkerResultRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WorkerResultRow>(
      where: where?.call(WorkerResultRow.t),
      orderBy: orderBy?.call(WorkerResultRow.t),
      orderByList: orderByList?.call(WorkerResultRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WorkerResultRow] matching the given query parameters.
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
  Future<WorkerResultRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerResultRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<WorkerResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkerResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WorkerResultRow>(
      where: where?.call(WorkerResultRow.t),
      orderBy: orderBy?.call(WorkerResultRow.t),
      orderByList: orderByList?.call(WorkerResultRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WorkerResultRow] by its [id] or null if no such row exists.
  Future<WorkerResultRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WorkerResultRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WorkerResultRow]s in the list and returns the inserted rows.
  ///
  /// The returned [WorkerResultRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<WorkerResultRow>> insert(
    _i1.DatabaseSession session,
    List<WorkerResultRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<WorkerResultRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [WorkerResultRow] and returns the inserted row.
  ///
  /// The returned [WorkerResultRow] will have its `id` field set.
  Future<WorkerResultRow> insertRow(
    _i1.DatabaseSession session,
    WorkerResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<WorkerResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [WorkerResultRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<WorkerResultRow>> update(
    _i1.DatabaseSession session,
    List<WorkerResultRow> rows, {
    _i1.ColumnSelections<WorkerResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<WorkerResultRow>(
      rows,
      columns: columns?.call(WorkerResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerResultRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WorkerResultRow> updateRow(
    _i1.DatabaseSession session,
    WorkerResultRow row, {
    _i1.ColumnSelections<WorkerResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<WorkerResultRow>(
      row,
      columns: columns?.call(WorkerResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkerResultRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WorkerResultRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<WorkerResultRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<WorkerResultRow>(
      id,
      columnValues: columnValues(WorkerResultRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WorkerResultRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<WorkerResultRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<WorkerResultRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<WorkerResultRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkerResultRowTable>? orderBy,
    _i1.OrderByListBuilder<WorkerResultRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<WorkerResultRow>(
      columnValues: columnValues(WorkerResultRow.t.updateTable),
      where: where(WorkerResultRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkerResultRow.t),
      orderByList: orderByList?.call(WorkerResultRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [WorkerResultRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<WorkerResultRow>> delete(
    _i1.DatabaseSession session,
    List<WorkerResultRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<WorkerResultRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [WorkerResultRow].
  Future<WorkerResultRow> deleteRow(
    _i1.DatabaseSession session,
    WorkerResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WorkerResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<WorkerResultRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerResultRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<WorkerResultRow>(
      where: where(WorkerResultRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkerResultRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<WorkerResultRow>(
      where: where?.call(WorkerResultRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WorkerResultRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkerResultRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WorkerResultRow>(
      where: where(WorkerResultRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

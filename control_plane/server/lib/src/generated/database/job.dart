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

abstract class JobRow implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  JobRow._({
    this.id,
    required this.jobId,
    required this.workItemId,
    required this.jobType,
    required this.requiredRole,
    required this.requiredCapabilitiesJson,
    required this.priority,
    required this.state,
    required this.dedupeKey,
    required this.createdAt,
    this.availableAt,
    required this.instruction,
    required this.attempt,
    required this.maxAttempts,
    this.startedAt,
    this.completedAt,
    this.executionReferenceJson,
    this.workerId,
    this.failureJson,
    this.cancelReason,
    required this.version,
  });

  factory JobRow({
    int? id,
    required String jobId,
    required String workItemId,
    required String jobType,
    required String requiredRole,
    required String requiredCapabilitiesJson,
    required String priority,
    required String state,
    required String dedupeKey,
    required DateTime createdAt,
    DateTime? availableAt,
    required String instruction,
    required int attempt,
    required int maxAttempts,
    DateTime? startedAt,
    DateTime? completedAt,
    String? executionReferenceJson,
    String? workerId,
    String? failureJson,
    String? cancelReason,
    required int version,
  }) = _JobRowImpl;

  factory JobRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return JobRow(
      id: jsonSerialization['id'] as int?,
      jobId: jsonSerialization['jobId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      jobType: jsonSerialization['jobType'] as String,
      requiredRole: jsonSerialization['requiredRole'] as String,
      requiredCapabilitiesJson:
          jsonSerialization['requiredCapabilitiesJson'] as String,
      priority: jsonSerialization['priority'] as String,
      state: jsonSerialization['state'] as String,
      dedupeKey: jsonSerialization['dedupeKey'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      availableAt: jsonSerialization['availableAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['availableAt'],
            ),
      instruction: jsonSerialization['instruction'] as String,
      attempt: jsonSerialization['attempt'] as int,
      maxAttempts: jsonSerialization['maxAttempts'] as int,
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      executionReferenceJson:
          jsonSerialization['executionReferenceJson'] as String?,
      workerId: jsonSerialization['workerId'] as String?,
      failureJson: jsonSerialization['failureJson'] as String?,
      cancelReason: jsonSerialization['cancelReason'] as String?,
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = JobRowTable();

  static const db = JobRowRepository._();

  @override
  int? id;

  String jobId;

  String workItemId;

  String jobType;

  String requiredRole;

  String requiredCapabilitiesJson;

  String priority;

  String state;

  String dedupeKey;

  DateTime createdAt;

  DateTime? availableAt;

  String instruction;

  int attempt;

  int maxAttempts;

  DateTime? startedAt;

  DateTime? completedAt;

  String? executionReferenceJson;

  String? workerId;

  String? failureJson;

  String? cancelReason;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [JobRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JobRow copyWith({
    int? id,
    String? jobId,
    String? workItemId,
    String? jobType,
    String? requiredRole,
    String? requiredCapabilitiesJson,
    String? priority,
    String? state,
    String? dedupeKey,
    DateTime? createdAt,
    DateTime? availableAt,
    String? instruction,
    int? attempt,
    int? maxAttempts,
    DateTime? startedAt,
    DateTime? completedAt,
    String? executionReferenceJson,
    String? workerId,
    String? failureJson,
    String? cancelReason,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JobRow',
      if (id != null) 'id': id,
      'jobId': jobId,
      'workItemId': workItemId,
      'jobType': jobType,
      'requiredRole': requiredRole,
      'requiredCapabilitiesJson': requiredCapabilitiesJson,
      'priority': priority,
      'state': state,
      'dedupeKey': dedupeKey,
      'createdAt': createdAt.toJson(),
      if (availableAt != null) 'availableAt': availableAt?.toJson(),
      'instruction': instruction,
      'attempt': attempt,
      'maxAttempts': maxAttempts,
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (executionReferenceJson != null)
        'executionReferenceJson': executionReferenceJson,
      if (workerId != null) 'workerId': workerId,
      if (failureJson != null) 'failureJson': failureJson,
      if (cancelReason != null) 'cancelReason': cancelReason,
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static JobRowInclude include() {
    return JobRowInclude._();
  }

  static JobRowIncludeList includeList({
    _i1.WhereExpressionBuilder<JobRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<JobRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<JobRowTable>? orderByList,
    JobRowInclude? include,
  }) {
    return JobRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(JobRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(JobRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _JobRowImpl extends JobRow {
  _JobRowImpl({
    int? id,
    required String jobId,
    required String workItemId,
    required String jobType,
    required String requiredRole,
    required String requiredCapabilitiesJson,
    required String priority,
    required String state,
    required String dedupeKey,
    required DateTime createdAt,
    DateTime? availableAt,
    required String instruction,
    required int attempt,
    required int maxAttempts,
    DateTime? startedAt,
    DateTime? completedAt,
    String? executionReferenceJson,
    String? workerId,
    String? failureJson,
    String? cancelReason,
    required int version,
  }) : super._(
         id: id,
         jobId: jobId,
         workItemId: workItemId,
         jobType: jobType,
         requiredRole: requiredRole,
         requiredCapabilitiesJson: requiredCapabilitiesJson,
         priority: priority,
         state: state,
         dedupeKey: dedupeKey,
         createdAt: createdAt,
         availableAt: availableAt,
         instruction: instruction,
         attempt: attempt,
         maxAttempts: maxAttempts,
         startedAt: startedAt,
         completedAt: completedAt,
         executionReferenceJson: executionReferenceJson,
         workerId: workerId,
         failureJson: failureJson,
         cancelReason: cancelReason,
         version: version,
       );

  /// Returns a shallow copy of this [JobRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JobRow copyWith({
    Object? id = _Undefined,
    String? jobId,
    String? workItemId,
    String? jobType,
    String? requiredRole,
    String? requiredCapabilitiesJson,
    String? priority,
    String? state,
    String? dedupeKey,
    DateTime? createdAt,
    Object? availableAt = _Undefined,
    String? instruction,
    int? attempt,
    int? maxAttempts,
    Object? startedAt = _Undefined,
    Object? completedAt = _Undefined,
    Object? executionReferenceJson = _Undefined,
    Object? workerId = _Undefined,
    Object? failureJson = _Undefined,
    Object? cancelReason = _Undefined,
    int? version,
  }) {
    return JobRow(
      id: id is int? ? id : this.id,
      jobId: jobId ?? this.jobId,
      workItemId: workItemId ?? this.workItemId,
      jobType: jobType ?? this.jobType,
      requiredRole: requiredRole ?? this.requiredRole,
      requiredCapabilitiesJson:
          requiredCapabilitiesJson ?? this.requiredCapabilitiesJson,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
      availableAt: availableAt is DateTime? ? availableAt : this.availableAt,
      instruction: instruction ?? this.instruction,
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      executionReferenceJson: executionReferenceJson is String?
          ? executionReferenceJson
          : this.executionReferenceJson,
      workerId: workerId is String? ? workerId : this.workerId,
      failureJson: failureJson is String? ? failureJson : this.failureJson,
      cancelReason: cancelReason is String? ? cancelReason : this.cancelReason,
      version: version ?? this.version,
    );
  }
}

class JobRowUpdateTable extends _i1.UpdateTable<JobRowTable> {
  JobRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> jobId(String value) => _i1.ColumnValue(
    table.jobId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> jobType(String value) => _i1.ColumnValue(
    table.jobType,
    value,
  );

  _i1.ColumnValue<String, String> requiredRole(String value) => _i1.ColumnValue(
    table.requiredRole,
    value,
  );

  _i1.ColumnValue<String, String> requiredCapabilitiesJson(String value) =>
      _i1.ColumnValue(
        table.requiredCapabilitiesJson,
        value,
      );

  _i1.ColumnValue<String, String> priority(String value) => _i1.ColumnValue(
    table.priority,
    value,
  );

  _i1.ColumnValue<String, String> state(String value) => _i1.ColumnValue(
    table.state,
    value,
  );

  _i1.ColumnValue<String, String> dedupeKey(String value) => _i1.ColumnValue(
    table.dedupeKey,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> availableAt(DateTime? value) =>
      _i1.ColumnValue(
        table.availableAt,
        value,
      );

  _i1.ColumnValue<String, String> instruction(String value) => _i1.ColumnValue(
    table.instruction,
    value,
  );

  _i1.ColumnValue<int, int> attempt(int value) => _i1.ColumnValue(
    table.attempt,
    value,
  );

  _i1.ColumnValue<int, int> maxAttempts(int value) => _i1.ColumnValue(
    table.maxAttempts,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> startedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.startedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.completedAt,
        value,
      );

  _i1.ColumnValue<String, String> executionReferenceJson(String? value) =>
      _i1.ColumnValue(
        table.executionReferenceJson,
        value,
      );

  _i1.ColumnValue<String, String> workerId(String? value) => _i1.ColumnValue(
    table.workerId,
    value,
  );

  _i1.ColumnValue<String, String> failureJson(String? value) => _i1.ColumnValue(
    table.failureJson,
    value,
  );

  _i1.ColumnValue<String, String> cancelReason(String? value) =>
      _i1.ColumnValue(
        table.cancelReason,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class JobRowTable extends _i1.Table<int?> {
  JobRowTable({super.tableRelation}) : super(tableName: 'job') {
    updateTable = JobRowUpdateTable(this);
    jobId = _i1.ColumnString(
      'jobId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    jobType = _i1.ColumnString(
      'jobType',
      this,
    );
    requiredRole = _i1.ColumnString(
      'requiredRole',
      this,
    );
    requiredCapabilitiesJson = _i1.ColumnString(
      'requiredCapabilitiesJson',
      this,
    );
    priority = _i1.ColumnString(
      'priority',
      this,
    );
    state = _i1.ColumnString(
      'state',
      this,
    );
    dedupeKey = _i1.ColumnString(
      'dedupeKey',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    availableAt = _i1.ColumnDateTime(
      'availableAt',
      this,
    );
    instruction = _i1.ColumnString(
      'instruction',
      this,
    );
    attempt = _i1.ColumnInt(
      'attempt',
      this,
    );
    maxAttempts = _i1.ColumnInt(
      'maxAttempts',
      this,
    );
    startedAt = _i1.ColumnDateTime(
      'startedAt',
      this,
    );
    completedAt = _i1.ColumnDateTime(
      'completedAt',
      this,
    );
    executionReferenceJson = _i1.ColumnString(
      'executionReferenceJson',
      this,
    );
    workerId = _i1.ColumnString(
      'workerId',
      this,
    );
    failureJson = _i1.ColumnString(
      'failureJson',
      this,
    );
    cancelReason = _i1.ColumnString(
      'cancelReason',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final JobRowUpdateTable updateTable;

  late final _i1.ColumnString jobId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString jobType;

  late final _i1.ColumnString requiredRole;

  late final _i1.ColumnString requiredCapabilitiesJson;

  late final _i1.ColumnString priority;

  late final _i1.ColumnString state;

  late final _i1.ColumnString dedupeKey;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime availableAt;

  late final _i1.ColumnString instruction;

  late final _i1.ColumnInt attempt;

  late final _i1.ColumnInt maxAttempts;

  late final _i1.ColumnDateTime startedAt;

  late final _i1.ColumnDateTime completedAt;

  late final _i1.ColumnString executionReferenceJson;

  late final _i1.ColumnString workerId;

  late final _i1.ColumnString failureJson;

  late final _i1.ColumnString cancelReason;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    jobId,
    workItemId,
    jobType,
    requiredRole,
    requiredCapabilitiesJson,
    priority,
    state,
    dedupeKey,
    createdAt,
    availableAt,
    instruction,
    attempt,
    maxAttempts,
    startedAt,
    completedAt,
    executionReferenceJson,
    workerId,
    failureJson,
    cancelReason,
    version,
  ];
}

class JobRowInclude extends _i1.IncludeObject {
  JobRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => JobRow.t;
}

class JobRowIncludeList extends _i1.IncludeList {
  JobRowIncludeList._({
    _i1.WhereExpressionBuilder<JobRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(JobRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => JobRow.t;
}

class JobRowRepository {
  const JobRowRepository._();

  /// Returns a list of [JobRow]s matching the given query parameters.
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
  Future<List<JobRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<JobRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<JobRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<JobRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<JobRow>(
      where: where?.call(JobRow.t),
      orderBy: orderBy?.call(JobRow.t),
      orderByList: orderByList?.call(JobRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [JobRow] matching the given query parameters.
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
  Future<JobRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<JobRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<JobRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<JobRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<JobRow>(
      where: where?.call(JobRow.t),
      orderBy: orderBy?.call(JobRow.t),
      orderByList: orderByList?.call(JobRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [JobRow] by its [id] or null if no such row exists.
  Future<JobRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<JobRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [JobRow]s in the list and returns the inserted rows.
  ///
  /// The returned [JobRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<JobRow>> insert(
    _i1.DatabaseSession session,
    List<JobRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<JobRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [JobRow] and returns the inserted row.
  ///
  /// The returned [JobRow] will have its `id` field set.
  Future<JobRow> insertRow(
    _i1.DatabaseSession session,
    JobRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<JobRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [JobRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<JobRow>> update(
    _i1.DatabaseSession session,
    List<JobRow> rows, {
    _i1.ColumnSelections<JobRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<JobRow>(
      rows,
      columns: columns?.call(JobRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [JobRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<JobRow> updateRow(
    _i1.DatabaseSession session,
    JobRow row, {
    _i1.ColumnSelections<JobRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<JobRow>(
      row,
      columns: columns?.call(JobRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [JobRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<JobRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<JobRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<JobRow>(
      id,
      columnValues: columnValues(JobRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [JobRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<JobRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<JobRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<JobRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<JobRowTable>? orderBy,
    _i1.OrderByListBuilder<JobRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<JobRow>(
      columnValues: columnValues(JobRow.t.updateTable),
      where: where(JobRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(JobRow.t),
      orderByList: orderByList?.call(JobRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [JobRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<JobRow>> delete(
    _i1.DatabaseSession session,
    List<JobRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<JobRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [JobRow].
  Future<JobRow> deleteRow(
    _i1.DatabaseSession session,
    JobRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<JobRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<JobRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<JobRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<JobRow>(
      where: where(JobRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<JobRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<JobRow>(
      where: where?.call(JobRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [JobRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<JobRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<JobRow>(
      where: where(JobRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

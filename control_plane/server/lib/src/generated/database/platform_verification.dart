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

abstract class PlatformVerificationRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  PlatformVerificationRow._({
    this.id,
    required this.verificationId,
    required this.executionId,
    required this.workItemId,
    required this.checkName,
    required this.status,
    required this.mechanism,
    required this.command,
    required this.capturedAt,
    required this.evidenceKind,
    this.outputRef,
    this.detail,
    this.resultPath,
  });

  factory PlatformVerificationRow({
    int? id,
    required String verificationId,
    required String executionId,
    required String workItemId,
    required String checkName,
    required String status,
    required String mechanism,
    required String command,
    required DateTime capturedAt,
    required String evidenceKind,
    String? outputRef,
    String? detail,
    String? resultPath,
  }) = _PlatformVerificationRowImpl;

  factory PlatformVerificationRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PlatformVerificationRow(
      id: jsonSerialization['id'] as int?,
      verificationId: jsonSerialization['verificationId'] as String,
      executionId: jsonSerialization['executionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      checkName: jsonSerialization['checkName'] as String,
      status: jsonSerialization['status'] as String,
      mechanism: jsonSerialization['mechanism'] as String,
      command: jsonSerialization['command'] as String,
      capturedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['capturedAt'],
      ),
      evidenceKind: jsonSerialization['evidenceKind'] as String,
      outputRef: jsonSerialization['outputRef'] as String?,
      detail: jsonSerialization['detail'] as String?,
      resultPath: jsonSerialization['resultPath'] as String?,
    );
  }

  static final t = PlatformVerificationRowTable();

  static const db = PlatformVerificationRowRepository._();

  @override
  int? id;

  String verificationId;

  String executionId;

  String workItemId;

  String checkName;

  String status;

  String mechanism;

  String command;

  DateTime capturedAt;

  String evidenceKind;

  String? outputRef;

  String? detail;

  String? resultPath;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [PlatformVerificationRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  PlatformVerificationRow copyWith({
    int? id,
    String? verificationId,
    String? executionId,
    String? workItemId,
    String? checkName,
    String? status,
    String? mechanism,
    String? command,
    DateTime? capturedAt,
    String? evidenceKind,
    String? outputRef,
    String? detail,
    String? resultPath,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PlatformVerificationRow',
      if (id != null) 'id': id,
      'verificationId': verificationId,
      'executionId': executionId,
      'workItemId': workItemId,
      'checkName': checkName,
      'status': status,
      'mechanism': mechanism,
      'command': command,
      'capturedAt': capturedAt.toJson(),
      'evidenceKind': evidenceKind,
      if (outputRef != null) 'outputRef': outputRef,
      if (detail != null) 'detail': detail,
      if (resultPath != null) 'resultPath': resultPath,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static PlatformVerificationRowInclude include() {
    return PlatformVerificationRowInclude._();
  }

  static PlatformVerificationRowIncludeList includeList({
    _i1.WhereExpressionBuilder<PlatformVerificationRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<PlatformVerificationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<PlatformVerificationRowTable>? orderByList,
    PlatformVerificationRowInclude? include,
  }) {
    return PlatformVerificationRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PlatformVerificationRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(PlatformVerificationRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PlatformVerificationRowImpl extends PlatformVerificationRow {
  _PlatformVerificationRowImpl({
    int? id,
    required String verificationId,
    required String executionId,
    required String workItemId,
    required String checkName,
    required String status,
    required String mechanism,
    required String command,
    required DateTime capturedAt,
    required String evidenceKind,
    String? outputRef,
    String? detail,
    String? resultPath,
  }) : super._(
         id: id,
         verificationId: verificationId,
         executionId: executionId,
         workItemId: workItemId,
         checkName: checkName,
         status: status,
         mechanism: mechanism,
         command: command,
         capturedAt: capturedAt,
         evidenceKind: evidenceKind,
         outputRef: outputRef,
         detail: detail,
         resultPath: resultPath,
       );

  /// Returns a shallow copy of this [PlatformVerificationRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  PlatformVerificationRow copyWith({
    Object? id = _Undefined,
    String? verificationId,
    String? executionId,
    String? workItemId,
    String? checkName,
    String? status,
    String? mechanism,
    String? command,
    DateTime? capturedAt,
    String? evidenceKind,
    Object? outputRef = _Undefined,
    Object? detail = _Undefined,
    Object? resultPath = _Undefined,
  }) {
    return PlatformVerificationRow(
      id: id is int? ? id : this.id,
      verificationId: verificationId ?? this.verificationId,
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      checkName: checkName ?? this.checkName,
      status: status ?? this.status,
      mechanism: mechanism ?? this.mechanism,
      command: command ?? this.command,
      capturedAt: capturedAt ?? this.capturedAt,
      evidenceKind: evidenceKind ?? this.evidenceKind,
      outputRef: outputRef is String? ? outputRef : this.outputRef,
      detail: detail is String? ? detail : this.detail,
      resultPath: resultPath is String? ? resultPath : this.resultPath,
    );
  }
}

class PlatformVerificationRowUpdateTable
    extends _i1.UpdateTable<PlatformVerificationRowTable> {
  PlatformVerificationRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> verificationId(String value) =>
      _i1.ColumnValue(
        table.verificationId,
        value,
      );

  _i1.ColumnValue<String, String> executionId(String value) => _i1.ColumnValue(
    table.executionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> checkName(String value) => _i1.ColumnValue(
    table.checkName,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> mechanism(String value) => _i1.ColumnValue(
    table.mechanism,
    value,
  );

  _i1.ColumnValue<String, String> command(String value) => _i1.ColumnValue(
    table.command,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> capturedAt(DateTime value) =>
      _i1.ColumnValue(
        table.capturedAt,
        value,
      );

  _i1.ColumnValue<String, String> evidenceKind(String value) => _i1.ColumnValue(
    table.evidenceKind,
    value,
  );

  _i1.ColumnValue<String, String> outputRef(String? value) => _i1.ColumnValue(
    table.outputRef,
    value,
  );

  _i1.ColumnValue<String, String> detail(String? value) => _i1.ColumnValue(
    table.detail,
    value,
  );

  _i1.ColumnValue<String, String> resultPath(String? value) => _i1.ColumnValue(
    table.resultPath,
    value,
  );
}

class PlatformVerificationRowTable extends _i1.Table<int?> {
  PlatformVerificationRowTable({super.tableRelation})
    : super(tableName: 'platform_verification') {
    updateTable = PlatformVerificationRowUpdateTable(this);
    verificationId = _i1.ColumnString(
      'verificationId',
      this,
    );
    executionId = _i1.ColumnString(
      'executionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    checkName = _i1.ColumnString(
      'checkName',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    mechanism = _i1.ColumnString(
      'mechanism',
      this,
    );
    command = _i1.ColumnString(
      'command',
      this,
    );
    capturedAt = _i1.ColumnDateTime(
      'capturedAt',
      this,
    );
    evidenceKind = _i1.ColumnString(
      'evidenceKind',
      this,
    );
    outputRef = _i1.ColumnString(
      'outputRef',
      this,
    );
    detail = _i1.ColumnString(
      'detail',
      this,
    );
    resultPath = _i1.ColumnString(
      'resultPath',
      this,
    );
  }

  late final PlatformVerificationRowUpdateTable updateTable;

  late final _i1.ColumnString verificationId;

  late final _i1.ColumnString executionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString checkName;

  late final _i1.ColumnString status;

  late final _i1.ColumnString mechanism;

  late final _i1.ColumnString command;

  late final _i1.ColumnDateTime capturedAt;

  late final _i1.ColumnString evidenceKind;

  late final _i1.ColumnString outputRef;

  late final _i1.ColumnString detail;

  late final _i1.ColumnString resultPath;

  @override
  List<_i1.Column> get columns => [
    id,
    verificationId,
    executionId,
    workItemId,
    checkName,
    status,
    mechanism,
    command,
    capturedAt,
    evidenceKind,
    outputRef,
    detail,
    resultPath,
  ];
}

class PlatformVerificationRowInclude extends _i1.IncludeObject {
  PlatformVerificationRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => PlatformVerificationRow.t;
}

class PlatformVerificationRowIncludeList extends _i1.IncludeList {
  PlatformVerificationRowIncludeList._({
    _i1.WhereExpressionBuilder<PlatformVerificationRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(PlatformVerificationRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => PlatformVerificationRow.t;
}

class PlatformVerificationRowRepository {
  const PlatformVerificationRowRepository._();

  /// Returns a list of [PlatformVerificationRow]s matching the given query parameters.
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
  Future<List<PlatformVerificationRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<PlatformVerificationRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<PlatformVerificationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<PlatformVerificationRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<PlatformVerificationRow>(
      where: where?.call(PlatformVerificationRow.t),
      orderBy: orderBy?.call(PlatformVerificationRow.t),
      orderByList: orderByList?.call(PlatformVerificationRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [PlatformVerificationRow] matching the given query parameters.
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
  Future<PlatformVerificationRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<PlatformVerificationRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<PlatformVerificationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<PlatformVerificationRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<PlatformVerificationRow>(
      where: where?.call(PlatformVerificationRow.t),
      orderBy: orderBy?.call(PlatformVerificationRow.t),
      orderByList: orderByList?.call(PlatformVerificationRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [PlatformVerificationRow] by its [id] or null if no such row exists.
  Future<PlatformVerificationRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<PlatformVerificationRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [PlatformVerificationRow]s in the list and returns the inserted rows.
  ///
  /// The returned [PlatformVerificationRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<PlatformVerificationRow>> insert(
    _i1.DatabaseSession session,
    List<PlatformVerificationRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<PlatformVerificationRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [PlatformVerificationRow] and returns the inserted row.
  ///
  /// The returned [PlatformVerificationRow] will have its `id` field set.
  Future<PlatformVerificationRow> insertRow(
    _i1.DatabaseSession session,
    PlatformVerificationRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<PlatformVerificationRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [PlatformVerificationRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<PlatformVerificationRow>> update(
    _i1.DatabaseSession session,
    List<PlatformVerificationRow> rows, {
    _i1.ColumnSelections<PlatformVerificationRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<PlatformVerificationRow>(
      rows,
      columns: columns?.call(PlatformVerificationRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [PlatformVerificationRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<PlatformVerificationRow> updateRow(
    _i1.DatabaseSession session,
    PlatformVerificationRow row, {
    _i1.ColumnSelections<PlatformVerificationRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<PlatformVerificationRow>(
      row,
      columns: columns?.call(PlatformVerificationRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [PlatformVerificationRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<PlatformVerificationRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<PlatformVerificationRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<PlatformVerificationRow>(
      id,
      columnValues: columnValues(PlatformVerificationRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [PlatformVerificationRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<PlatformVerificationRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<PlatformVerificationRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<PlatformVerificationRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<PlatformVerificationRowTable>? orderBy,
    _i1.OrderByListBuilder<PlatformVerificationRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<PlatformVerificationRow>(
      columnValues: columnValues(PlatformVerificationRow.t.updateTable),
      where: where(PlatformVerificationRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PlatformVerificationRow.t),
      orderByList: orderByList?.call(PlatformVerificationRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [PlatformVerificationRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<PlatformVerificationRow>> delete(
    _i1.DatabaseSession session,
    List<PlatformVerificationRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<PlatformVerificationRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [PlatformVerificationRow].
  Future<PlatformVerificationRow> deleteRow(
    _i1.DatabaseSession session,
    PlatformVerificationRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<PlatformVerificationRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<PlatformVerificationRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<PlatformVerificationRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<PlatformVerificationRow>(
      where: where(PlatformVerificationRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<PlatformVerificationRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<PlatformVerificationRow>(
      where: where?.call(PlatformVerificationRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [PlatformVerificationRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<PlatformVerificationRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<PlatformVerificationRow>(
      where: where(PlatformVerificationRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

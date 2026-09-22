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

abstract class JobClaimRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  JobClaimRow._({
    this.id,
    required this.claimId,
    required this.jobId,
    required this.ownerId,
    required this.leasedUntil,
    required this.createdAt,
  });

  factory JobClaimRow({
    int? id,
    required String claimId,
    required String jobId,
    required String ownerId,
    required DateTime leasedUntil,
    required DateTime createdAt,
  }) = _JobClaimRowImpl;

  factory JobClaimRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return JobClaimRow(
      id: jsonSerialization['id'] as int?,
      claimId: jsonSerialization['claimId'] as String,
      jobId: jsonSerialization['jobId'] as String,
      ownerId: jsonSerialization['ownerId'] as String,
      leasedUntil: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['leasedUntil'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = JobClaimRowTable();

  static const db = JobClaimRowRepository._();

  @override
  int? id;

  String claimId;

  String jobId;

  String ownerId;

  DateTime leasedUntil;

  DateTime createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [JobClaimRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JobClaimRow copyWith({
    int? id,
    String? claimId,
    String? jobId,
    String? ownerId,
    DateTime? leasedUntil,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JobClaimRow',
      if (id != null) 'id': id,
      'claimId': claimId,
      'jobId': jobId,
      'ownerId': ownerId,
      'leasedUntil': leasedUntil.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static JobClaimRowInclude include() {
    return JobClaimRowInclude._();
  }

  static JobClaimRowIncludeList includeList({
    _i1.WhereExpressionBuilder<JobClaimRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<JobClaimRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<JobClaimRowTable>? orderByList,
    JobClaimRowInclude? include,
  }) {
    return JobClaimRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(JobClaimRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(JobClaimRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _JobClaimRowImpl extends JobClaimRow {
  _JobClaimRowImpl({
    int? id,
    required String claimId,
    required String jobId,
    required String ownerId,
    required DateTime leasedUntil,
    required DateTime createdAt,
  }) : super._(
         id: id,
         claimId: claimId,
         jobId: jobId,
         ownerId: ownerId,
         leasedUntil: leasedUntil,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [JobClaimRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JobClaimRow copyWith({
    Object? id = _Undefined,
    String? claimId,
    String? jobId,
    String? ownerId,
    DateTime? leasedUntil,
    DateTime? createdAt,
  }) {
    return JobClaimRow(
      id: id is int? ? id : this.id,
      claimId: claimId ?? this.claimId,
      jobId: jobId ?? this.jobId,
      ownerId: ownerId ?? this.ownerId,
      leasedUntil: leasedUntil ?? this.leasedUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class JobClaimRowUpdateTable extends _i1.UpdateTable<JobClaimRowTable> {
  JobClaimRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> claimId(String value) => _i1.ColumnValue(
    table.claimId,
    value,
  );

  _i1.ColumnValue<String, String> jobId(String value) => _i1.ColumnValue(
    table.jobId,
    value,
  );

  _i1.ColumnValue<String, String> ownerId(String value) => _i1.ColumnValue(
    table.ownerId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> leasedUntil(DateTime value) =>
      _i1.ColumnValue(
        table.leasedUntil,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class JobClaimRowTable extends _i1.Table<int?> {
  JobClaimRowTable({super.tableRelation}) : super(tableName: 'job_claim') {
    updateTable = JobClaimRowUpdateTable(this);
    claimId = _i1.ColumnString(
      'claimId',
      this,
    );
    jobId = _i1.ColumnString(
      'jobId',
      this,
    );
    ownerId = _i1.ColumnString(
      'ownerId',
      this,
    );
    leasedUntil = _i1.ColumnDateTime(
      'leasedUntil',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final JobClaimRowUpdateTable updateTable;

  late final _i1.ColumnString claimId;

  late final _i1.ColumnString jobId;

  late final _i1.ColumnString ownerId;

  late final _i1.ColumnDateTime leasedUntil;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    claimId,
    jobId,
    ownerId,
    leasedUntil,
    createdAt,
  ];
}

class JobClaimRowInclude extends _i1.IncludeObject {
  JobClaimRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => JobClaimRow.t;
}

class JobClaimRowIncludeList extends _i1.IncludeList {
  JobClaimRowIncludeList._({
    _i1.WhereExpressionBuilder<JobClaimRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(JobClaimRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => JobClaimRow.t;
}

class JobClaimRowRepository {
  const JobClaimRowRepository._();

  /// Returns a list of [JobClaimRow]s matching the given query parameters.
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
  Future<List<JobClaimRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<JobClaimRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<JobClaimRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<JobClaimRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<JobClaimRow>(
      where: where?.call(JobClaimRow.t),
      orderBy: orderBy?.call(JobClaimRow.t),
      orderByList: orderByList?.call(JobClaimRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [JobClaimRow] matching the given query parameters.
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
  Future<JobClaimRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<JobClaimRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<JobClaimRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<JobClaimRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<JobClaimRow>(
      where: where?.call(JobClaimRow.t),
      orderBy: orderBy?.call(JobClaimRow.t),
      orderByList: orderByList?.call(JobClaimRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [JobClaimRow] by its [id] or null if no such row exists.
  Future<JobClaimRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<JobClaimRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [JobClaimRow]s in the list and returns the inserted rows.
  ///
  /// The returned [JobClaimRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<JobClaimRow>> insert(
    _i1.DatabaseSession session,
    List<JobClaimRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<JobClaimRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [JobClaimRow] and returns the inserted row.
  ///
  /// The returned [JobClaimRow] will have its `id` field set.
  Future<JobClaimRow> insertRow(
    _i1.DatabaseSession session,
    JobClaimRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<JobClaimRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [JobClaimRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<JobClaimRow>> update(
    _i1.DatabaseSession session,
    List<JobClaimRow> rows, {
    _i1.ColumnSelections<JobClaimRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<JobClaimRow>(
      rows,
      columns: columns?.call(JobClaimRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [JobClaimRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<JobClaimRow> updateRow(
    _i1.DatabaseSession session,
    JobClaimRow row, {
    _i1.ColumnSelections<JobClaimRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<JobClaimRow>(
      row,
      columns: columns?.call(JobClaimRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [JobClaimRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<JobClaimRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<JobClaimRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<JobClaimRow>(
      id,
      columnValues: columnValues(JobClaimRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [JobClaimRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<JobClaimRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<JobClaimRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<JobClaimRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<JobClaimRowTable>? orderBy,
    _i1.OrderByListBuilder<JobClaimRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<JobClaimRow>(
      columnValues: columnValues(JobClaimRow.t.updateTable),
      where: where(JobClaimRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(JobClaimRow.t),
      orderByList: orderByList?.call(JobClaimRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [JobClaimRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<JobClaimRow>> delete(
    _i1.DatabaseSession session,
    List<JobClaimRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<JobClaimRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [JobClaimRow].
  Future<JobClaimRow> deleteRow(
    _i1.DatabaseSession session,
    JobClaimRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<JobClaimRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<JobClaimRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<JobClaimRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<JobClaimRow>(
      where: where(JobClaimRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<JobClaimRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<JobClaimRow>(
      where: where?.call(JobClaimRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [JobClaimRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<JobClaimRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<JobClaimRow>(
      where: where(JobClaimRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

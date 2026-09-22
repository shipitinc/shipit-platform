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

abstract class StandingPolicyRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  StandingPolicyRow._({
    this.id,
    required this.policyId,
    required this.productId,
    required this.actionsJson,
    required this.authorisingDecisionId,
    required this.authorisedBy,
    required this.rationale,
    required this.authorisedAt,
    this.revokedAt,
    this.revokedBy,
    this.revocationDecisionId,
    this.revocationReason,
    required this.version,
  });

  factory StandingPolicyRow({
    int? id,
    required String policyId,
    required String productId,
    required String actionsJson,
    required String authorisingDecisionId,
    required String authorisedBy,
    required String rationale,
    required DateTime authorisedAt,
    DateTime? revokedAt,
    String? revokedBy,
    String? revocationDecisionId,
    String? revocationReason,
    required int version,
  }) = _StandingPolicyRowImpl;

  factory StandingPolicyRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return StandingPolicyRow(
      id: jsonSerialization['id'] as int?,
      policyId: jsonSerialization['policyId'] as String,
      productId: jsonSerialization['productId'] as String,
      actionsJson: jsonSerialization['actionsJson'] as String,
      authorisingDecisionId:
          jsonSerialization['authorisingDecisionId'] as String,
      authorisedBy: jsonSerialization['authorisedBy'] as String,
      rationale: jsonSerialization['rationale'] as String,
      authorisedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['authorisedAt'],
      ),
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
      revokedBy: jsonSerialization['revokedBy'] as String?,
      revocationDecisionId:
          jsonSerialization['revocationDecisionId'] as String?,
      revocationReason: jsonSerialization['revocationReason'] as String?,
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = StandingPolicyRowTable();

  static const db = StandingPolicyRowRepository._();

  @override
  int? id;

  String policyId;

  String productId;

  String actionsJson;

  String authorisingDecisionId;

  String authorisedBy;

  String rationale;

  DateTime authorisedAt;

  DateTime? revokedAt;

  String? revokedBy;

  String? revocationDecisionId;

  String? revocationReason;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [StandingPolicyRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  StandingPolicyRow copyWith({
    int? id,
    String? policyId,
    String? productId,
    String? actionsJson,
    String? authorisingDecisionId,
    String? authorisedBy,
    String? rationale,
    DateTime? authorisedAt,
    DateTime? revokedAt,
    String? revokedBy,
    String? revocationDecisionId,
    String? revocationReason,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StandingPolicyRow',
      if (id != null) 'id': id,
      'policyId': policyId,
      'productId': productId,
      'actionsJson': actionsJson,
      'authorisingDecisionId': authorisingDecisionId,
      'authorisedBy': authorisedBy,
      'rationale': rationale,
      'authorisedAt': authorisedAt.toJson(),
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
      if (revokedBy != null) 'revokedBy': revokedBy,
      if (revocationDecisionId != null)
        'revocationDecisionId': revocationDecisionId,
      if (revocationReason != null) 'revocationReason': revocationReason,
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static StandingPolicyRowInclude include() {
    return StandingPolicyRowInclude._();
  }

  static StandingPolicyRowIncludeList includeList({
    _i1.WhereExpressionBuilder<StandingPolicyRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StandingPolicyRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StandingPolicyRowTable>? orderByList,
    StandingPolicyRowInclude? include,
  }) {
    return StandingPolicyRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StandingPolicyRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(StandingPolicyRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StandingPolicyRowImpl extends StandingPolicyRow {
  _StandingPolicyRowImpl({
    int? id,
    required String policyId,
    required String productId,
    required String actionsJson,
    required String authorisingDecisionId,
    required String authorisedBy,
    required String rationale,
    required DateTime authorisedAt,
    DateTime? revokedAt,
    String? revokedBy,
    String? revocationDecisionId,
    String? revocationReason,
    required int version,
  }) : super._(
         id: id,
         policyId: policyId,
         productId: productId,
         actionsJson: actionsJson,
         authorisingDecisionId: authorisingDecisionId,
         authorisedBy: authorisedBy,
         rationale: rationale,
         authorisedAt: authorisedAt,
         revokedAt: revokedAt,
         revokedBy: revokedBy,
         revocationDecisionId: revocationDecisionId,
         revocationReason: revocationReason,
         version: version,
       );

  /// Returns a shallow copy of this [StandingPolicyRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  StandingPolicyRow copyWith({
    Object? id = _Undefined,
    String? policyId,
    String? productId,
    String? actionsJson,
    String? authorisingDecisionId,
    String? authorisedBy,
    String? rationale,
    DateTime? authorisedAt,
    Object? revokedAt = _Undefined,
    Object? revokedBy = _Undefined,
    Object? revocationDecisionId = _Undefined,
    Object? revocationReason = _Undefined,
    int? version,
  }) {
    return StandingPolicyRow(
      id: id is int? ? id : this.id,
      policyId: policyId ?? this.policyId,
      productId: productId ?? this.productId,
      actionsJson: actionsJson ?? this.actionsJson,
      authorisingDecisionId:
          authorisingDecisionId ?? this.authorisingDecisionId,
      authorisedBy: authorisedBy ?? this.authorisedBy,
      rationale: rationale ?? this.rationale,
      authorisedAt: authorisedAt ?? this.authorisedAt,
      revokedAt: revokedAt is DateTime? ? revokedAt : this.revokedAt,
      revokedBy: revokedBy is String? ? revokedBy : this.revokedBy,
      revocationDecisionId: revocationDecisionId is String?
          ? revocationDecisionId
          : this.revocationDecisionId,
      revocationReason: revocationReason is String?
          ? revocationReason
          : this.revocationReason,
      version: version ?? this.version,
    );
  }
}

class StandingPolicyRowUpdateTable
    extends _i1.UpdateTable<StandingPolicyRowTable> {
  StandingPolicyRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> policyId(String value) => _i1.ColumnValue(
    table.policyId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> actionsJson(String value) => _i1.ColumnValue(
    table.actionsJson,
    value,
  );

  _i1.ColumnValue<String, String> authorisingDecisionId(String value) =>
      _i1.ColumnValue(
        table.authorisingDecisionId,
        value,
      );

  _i1.ColumnValue<String, String> authorisedBy(String value) => _i1.ColumnValue(
    table.authorisedBy,
    value,
  );

  _i1.ColumnValue<String, String> rationale(String value) => _i1.ColumnValue(
    table.rationale,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> authorisedAt(DateTime value) =>
      _i1.ColumnValue(
        table.authorisedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> revokedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.revokedAt,
        value,
      );

  _i1.ColumnValue<String, String> revokedBy(String? value) => _i1.ColumnValue(
    table.revokedBy,
    value,
  );

  _i1.ColumnValue<String, String> revocationDecisionId(String? value) =>
      _i1.ColumnValue(
        table.revocationDecisionId,
        value,
      );

  _i1.ColumnValue<String, String> revocationReason(String? value) =>
      _i1.ColumnValue(
        table.revocationReason,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class StandingPolicyRowTable extends _i1.Table<int?> {
  StandingPolicyRowTable({super.tableRelation})
    : super(tableName: 'standing_policy') {
    updateTable = StandingPolicyRowUpdateTable(this);
    policyId = _i1.ColumnString(
      'policyId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    actionsJson = _i1.ColumnString(
      'actionsJson',
      this,
    );
    authorisingDecisionId = _i1.ColumnString(
      'authorisingDecisionId',
      this,
    );
    authorisedBy = _i1.ColumnString(
      'authorisedBy',
      this,
    );
    rationale = _i1.ColumnString(
      'rationale',
      this,
    );
    authorisedAt = _i1.ColumnDateTime(
      'authorisedAt',
      this,
    );
    revokedAt = _i1.ColumnDateTime(
      'revokedAt',
      this,
    );
    revokedBy = _i1.ColumnString(
      'revokedBy',
      this,
    );
    revocationDecisionId = _i1.ColumnString(
      'revocationDecisionId',
      this,
    );
    revocationReason = _i1.ColumnString(
      'revocationReason',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final StandingPolicyRowUpdateTable updateTable;

  late final _i1.ColumnString policyId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString actionsJson;

  late final _i1.ColumnString authorisingDecisionId;

  late final _i1.ColumnString authorisedBy;

  late final _i1.ColumnString rationale;

  late final _i1.ColumnDateTime authorisedAt;

  late final _i1.ColumnDateTime revokedAt;

  late final _i1.ColumnString revokedBy;

  late final _i1.ColumnString revocationDecisionId;

  late final _i1.ColumnString revocationReason;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    policyId,
    productId,
    actionsJson,
    authorisingDecisionId,
    authorisedBy,
    rationale,
    authorisedAt,
    revokedAt,
    revokedBy,
    revocationDecisionId,
    revocationReason,
    version,
  ];
}

class StandingPolicyRowInclude extends _i1.IncludeObject {
  StandingPolicyRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => StandingPolicyRow.t;
}

class StandingPolicyRowIncludeList extends _i1.IncludeList {
  StandingPolicyRowIncludeList._({
    _i1.WhereExpressionBuilder<StandingPolicyRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(StandingPolicyRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => StandingPolicyRow.t;
}

class StandingPolicyRowRepository {
  const StandingPolicyRowRepository._();

  /// Returns a list of [StandingPolicyRow]s matching the given query parameters.
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
  Future<List<StandingPolicyRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<StandingPolicyRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StandingPolicyRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StandingPolicyRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<StandingPolicyRow>(
      where: where?.call(StandingPolicyRow.t),
      orderBy: orderBy?.call(StandingPolicyRow.t),
      orderByList: orderByList?.call(StandingPolicyRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [StandingPolicyRow] matching the given query parameters.
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
  Future<StandingPolicyRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<StandingPolicyRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<StandingPolicyRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StandingPolicyRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<StandingPolicyRow>(
      where: where?.call(StandingPolicyRow.t),
      orderBy: orderBy?.call(StandingPolicyRow.t),
      orderByList: orderByList?.call(StandingPolicyRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [StandingPolicyRow] by its [id] or null if no such row exists.
  Future<StandingPolicyRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<StandingPolicyRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [StandingPolicyRow]s in the list and returns the inserted rows.
  ///
  /// The returned [StandingPolicyRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<StandingPolicyRow>> insert(
    _i1.DatabaseSession session,
    List<StandingPolicyRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<StandingPolicyRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [StandingPolicyRow] and returns the inserted row.
  ///
  /// The returned [StandingPolicyRow] will have its `id` field set.
  Future<StandingPolicyRow> insertRow(
    _i1.DatabaseSession session,
    StandingPolicyRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<StandingPolicyRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [StandingPolicyRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<StandingPolicyRow>> update(
    _i1.DatabaseSession session,
    List<StandingPolicyRow> rows, {
    _i1.ColumnSelections<StandingPolicyRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<StandingPolicyRow>(
      rows,
      columns: columns?.call(StandingPolicyRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StandingPolicyRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<StandingPolicyRow> updateRow(
    _i1.DatabaseSession session,
    StandingPolicyRow row, {
    _i1.ColumnSelections<StandingPolicyRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<StandingPolicyRow>(
      row,
      columns: columns?.call(StandingPolicyRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StandingPolicyRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<StandingPolicyRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<StandingPolicyRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<StandingPolicyRow>(
      id,
      columnValues: columnValues(StandingPolicyRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [StandingPolicyRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<StandingPolicyRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<StandingPolicyRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<StandingPolicyRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StandingPolicyRowTable>? orderBy,
    _i1.OrderByListBuilder<StandingPolicyRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<StandingPolicyRow>(
      columnValues: columnValues(StandingPolicyRow.t.updateTable),
      where: where(StandingPolicyRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StandingPolicyRow.t),
      orderByList: orderByList?.call(StandingPolicyRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [StandingPolicyRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<StandingPolicyRow>> delete(
    _i1.DatabaseSession session,
    List<StandingPolicyRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<StandingPolicyRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [StandingPolicyRow].
  Future<StandingPolicyRow> deleteRow(
    _i1.DatabaseSession session,
    StandingPolicyRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<StandingPolicyRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<StandingPolicyRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<StandingPolicyRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<StandingPolicyRow>(
      where: where(StandingPolicyRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<StandingPolicyRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<StandingPolicyRow>(
      where: where?.call(StandingPolicyRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [StandingPolicyRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<StandingPolicyRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<StandingPolicyRow>(
      where: where(StandingPolicyRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

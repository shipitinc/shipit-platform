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

abstract class HumanDecisionRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  HumanDecisionRow._({
    this.id,
    required this.decisionId,
    required this.workItemId,
    required this.decisionType,
    required this.status,
    this.question,
    this.contextJson,
    this.optionsJson,
    this.recommendation,
    this.blocking,
    this.requestedAt,
    this.expiration,
    this.decider,
    this.choice,
    this.rationale,
    this.timestamp,
    this.signatureJson,
    this.resolvedOptionId,
    this.metadataJson,
    required this.updatedAt,
  });

  factory HumanDecisionRow({
    int? id,
    required String decisionId,
    required String workItemId,
    required String decisionType,
    required String status,
    String? question,
    String? contextJson,
    String? optionsJson,
    String? recommendation,
    bool? blocking,
    DateTime? requestedAt,
    DateTime? expiration,
    String? decider,
    String? choice,
    String? rationale,
    DateTime? timestamp,
    String? signatureJson,
    String? resolvedOptionId,
    String? metadataJson,
    required DateTime updatedAt,
  }) = _HumanDecisionRowImpl;

  factory HumanDecisionRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return HumanDecisionRow(
      id: jsonSerialization['id'] as int?,
      decisionId: jsonSerialization['decisionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      decisionType: jsonSerialization['decisionType'] as String,
      status: jsonSerialization['status'] as String,
      question: jsonSerialization['question'] as String?,
      contextJson: jsonSerialization['contextJson'] as String?,
      optionsJson: jsonSerialization['optionsJson'] as String?,
      recommendation: jsonSerialization['recommendation'] as String?,
      blocking: jsonSerialization['blocking'] == null
          ? null
          : _i1.BoolJsonExtension.fromJson(jsonSerialization['blocking']),
      requestedAt: jsonSerialization['requestedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['requestedAt'],
            ),
      expiration: jsonSerialization['expiration'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['expiration']),
      decider: jsonSerialization['decider'] as String?,
      choice: jsonSerialization['choice'] as String?,
      rationale: jsonSerialization['rationale'] as String?,
      timestamp: jsonSerialization['timestamp'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['timestamp']),
      signatureJson: jsonSerialization['signatureJson'] as String?,
      resolvedOptionId: jsonSerialization['resolvedOptionId'] as String?,
      metadataJson: jsonSerialization['metadataJson'] as String?,
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = HumanDecisionRowTable();

  static const db = HumanDecisionRowRepository._();

  @override
  int? id;

  String decisionId;

  String workItemId;

  String decisionType;

  String status;

  String? question;

  String? contextJson;

  String? optionsJson;

  String? recommendation;

  bool? blocking;

  DateTime? requestedAt;

  DateTime? expiration;

  String? decider;

  String? choice;

  String? rationale;

  DateTime? timestamp;

  String? signatureJson;

  String? resolvedOptionId;

  String? metadataJson;

  DateTime updatedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [HumanDecisionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  HumanDecisionRow copyWith({
    int? id,
    String? decisionId,
    String? workItemId,
    String? decisionType,
    String? status,
    String? question,
    String? contextJson,
    String? optionsJson,
    String? recommendation,
    bool? blocking,
    DateTime? requestedAt,
    DateTime? expiration,
    String? decider,
    String? choice,
    String? rationale,
    DateTime? timestamp,
    String? signatureJson,
    String? resolvedOptionId,
    String? metadataJson,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HumanDecisionRow',
      if (id != null) 'id': id,
      'decisionId': decisionId,
      'workItemId': workItemId,
      'decisionType': decisionType,
      'status': status,
      if (question != null) 'question': question,
      if (contextJson != null) 'contextJson': contextJson,
      if (optionsJson != null) 'optionsJson': optionsJson,
      if (recommendation != null) 'recommendation': recommendation,
      if (blocking != null) 'blocking': blocking,
      if (requestedAt != null) 'requestedAt': requestedAt?.toJson(),
      if (expiration != null) 'expiration': expiration?.toJson(),
      if (decider != null) 'decider': decider,
      if (choice != null) 'choice': choice,
      if (rationale != null) 'rationale': rationale,
      if (timestamp != null) 'timestamp': timestamp?.toJson(),
      if (signatureJson != null) 'signatureJson': signatureJson,
      if (resolvedOptionId != null) 'resolvedOptionId': resolvedOptionId,
      if (metadataJson != null) 'metadataJson': metadataJson,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static HumanDecisionRowInclude include() {
    return HumanDecisionRowInclude._();
  }

  static HumanDecisionRowIncludeList includeList({
    _i1.WhereExpressionBuilder<HumanDecisionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HumanDecisionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HumanDecisionRowTable>? orderByList,
    HumanDecisionRowInclude? include,
  }) {
    return HumanDecisionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HumanDecisionRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(HumanDecisionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HumanDecisionRowImpl extends HumanDecisionRow {
  _HumanDecisionRowImpl({
    int? id,
    required String decisionId,
    required String workItemId,
    required String decisionType,
    required String status,
    String? question,
    String? contextJson,
    String? optionsJson,
    String? recommendation,
    bool? blocking,
    DateTime? requestedAt,
    DateTime? expiration,
    String? decider,
    String? choice,
    String? rationale,
    DateTime? timestamp,
    String? signatureJson,
    String? resolvedOptionId,
    String? metadataJson,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         decisionId: decisionId,
         workItemId: workItemId,
         decisionType: decisionType,
         status: status,
         question: question,
         contextJson: contextJson,
         optionsJson: optionsJson,
         recommendation: recommendation,
         blocking: blocking,
         requestedAt: requestedAt,
         expiration: expiration,
         decider: decider,
         choice: choice,
         rationale: rationale,
         timestamp: timestamp,
         signatureJson: signatureJson,
         resolvedOptionId: resolvedOptionId,
         metadataJson: metadataJson,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [HumanDecisionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  HumanDecisionRow copyWith({
    Object? id = _Undefined,
    String? decisionId,
    String? workItemId,
    String? decisionType,
    String? status,
    Object? question = _Undefined,
    Object? contextJson = _Undefined,
    Object? optionsJson = _Undefined,
    Object? recommendation = _Undefined,
    Object? blocking = _Undefined,
    Object? requestedAt = _Undefined,
    Object? expiration = _Undefined,
    Object? decider = _Undefined,
    Object? choice = _Undefined,
    Object? rationale = _Undefined,
    Object? timestamp = _Undefined,
    Object? signatureJson = _Undefined,
    Object? resolvedOptionId = _Undefined,
    Object? metadataJson = _Undefined,
    DateTime? updatedAt,
  }) {
    return HumanDecisionRow(
      id: id is int? ? id : this.id,
      decisionId: decisionId ?? this.decisionId,
      workItemId: workItemId ?? this.workItemId,
      decisionType: decisionType ?? this.decisionType,
      status: status ?? this.status,
      question: question is String? ? question : this.question,
      contextJson: contextJson is String? ? contextJson : this.contextJson,
      optionsJson: optionsJson is String? ? optionsJson : this.optionsJson,
      recommendation: recommendation is String?
          ? recommendation
          : this.recommendation,
      blocking: blocking is bool? ? blocking : this.blocking,
      requestedAt: requestedAt is DateTime? ? requestedAt : this.requestedAt,
      expiration: expiration is DateTime? ? expiration : this.expiration,
      decider: decider is String? ? decider : this.decider,
      choice: choice is String? ? choice : this.choice,
      rationale: rationale is String? ? rationale : this.rationale,
      timestamp: timestamp is DateTime? ? timestamp : this.timestamp,
      signatureJson: signatureJson is String?
          ? signatureJson
          : this.signatureJson,
      resolvedOptionId: resolvedOptionId is String?
          ? resolvedOptionId
          : this.resolvedOptionId,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class HumanDecisionRowUpdateTable
    extends _i1.UpdateTable<HumanDecisionRowTable> {
  HumanDecisionRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> decisionId(String value) => _i1.ColumnValue(
    table.decisionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> decisionType(String value) => _i1.ColumnValue(
    table.decisionType,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> question(String? value) => _i1.ColumnValue(
    table.question,
    value,
  );

  _i1.ColumnValue<String, String> contextJson(String? value) => _i1.ColumnValue(
    table.contextJson,
    value,
  );

  _i1.ColumnValue<String, String> optionsJson(String? value) => _i1.ColumnValue(
    table.optionsJson,
    value,
  );

  _i1.ColumnValue<String, String> recommendation(String? value) =>
      _i1.ColumnValue(
        table.recommendation,
        value,
      );

  _i1.ColumnValue<bool, bool> blocking(bool? value) => _i1.ColumnValue(
    table.blocking,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> requestedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.requestedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> expiration(DateTime? value) =>
      _i1.ColumnValue(
        table.expiration,
        value,
      );

  _i1.ColumnValue<String, String> decider(String? value) => _i1.ColumnValue(
    table.decider,
    value,
  );

  _i1.ColumnValue<String, String> choice(String? value) => _i1.ColumnValue(
    table.choice,
    value,
  );

  _i1.ColumnValue<String, String> rationale(String? value) => _i1.ColumnValue(
    table.rationale,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> timestamp(DateTime? value) =>
      _i1.ColumnValue(
        table.timestamp,
        value,
      );

  _i1.ColumnValue<String, String> signatureJson(String? value) =>
      _i1.ColumnValue(
        table.signatureJson,
        value,
      );

  _i1.ColumnValue<String, String> resolvedOptionId(String? value) =>
      _i1.ColumnValue(
        table.resolvedOptionId,
        value,
      );

  _i1.ColumnValue<String, String> metadataJson(String? value) =>
      _i1.ColumnValue(
        table.metadataJson,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );
}

class HumanDecisionRowTable extends _i1.Table<int?> {
  HumanDecisionRowTable({super.tableRelation})
    : super(tableName: 'human_decision') {
    updateTable = HumanDecisionRowUpdateTable(this);
    decisionId = _i1.ColumnString(
      'decisionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    decisionType = _i1.ColumnString(
      'decisionType',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    question = _i1.ColumnString(
      'question',
      this,
    );
    contextJson = _i1.ColumnString(
      'contextJson',
      this,
    );
    optionsJson = _i1.ColumnString(
      'optionsJson',
      this,
    );
    recommendation = _i1.ColumnString(
      'recommendation',
      this,
    );
    blocking = _i1.ColumnBool(
      'blocking',
      this,
    );
    requestedAt = _i1.ColumnDateTime(
      'requestedAt',
      this,
    );
    expiration = _i1.ColumnDateTime(
      'expiration',
      this,
    );
    decider = _i1.ColumnString(
      'decider',
      this,
    );
    choice = _i1.ColumnString(
      'choice',
      this,
    );
    rationale = _i1.ColumnString(
      'rationale',
      this,
    );
    timestamp = _i1.ColumnDateTime(
      'timestamp',
      this,
    );
    signatureJson = _i1.ColumnString(
      'signatureJson',
      this,
    );
    resolvedOptionId = _i1.ColumnString(
      'resolvedOptionId',
      this,
    );
    metadataJson = _i1.ColumnString(
      'metadataJson',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final HumanDecisionRowUpdateTable updateTable;

  late final _i1.ColumnString decisionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString decisionType;

  late final _i1.ColumnString status;

  late final _i1.ColumnString question;

  late final _i1.ColumnString contextJson;

  late final _i1.ColumnString optionsJson;

  late final _i1.ColumnString recommendation;

  late final _i1.ColumnBool blocking;

  late final _i1.ColumnDateTime requestedAt;

  late final _i1.ColumnDateTime expiration;

  late final _i1.ColumnString decider;

  late final _i1.ColumnString choice;

  late final _i1.ColumnString rationale;

  late final _i1.ColumnDateTime timestamp;

  late final _i1.ColumnString signatureJson;

  late final _i1.ColumnString resolvedOptionId;

  late final _i1.ColumnString metadataJson;

  late final _i1.ColumnDateTime updatedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    decisionId,
    workItemId,
    decisionType,
    status,
    question,
    contextJson,
    optionsJson,
    recommendation,
    blocking,
    requestedAt,
    expiration,
    decider,
    choice,
    rationale,
    timestamp,
    signatureJson,
    resolvedOptionId,
    metadataJson,
    updatedAt,
  ];
}

class HumanDecisionRowInclude extends _i1.IncludeObject {
  HumanDecisionRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => HumanDecisionRow.t;
}

class HumanDecisionRowIncludeList extends _i1.IncludeList {
  HumanDecisionRowIncludeList._({
    _i1.WhereExpressionBuilder<HumanDecisionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HumanDecisionRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => HumanDecisionRow.t;
}

class HumanDecisionRowRepository {
  const HumanDecisionRowRepository._();

  /// Returns a list of [HumanDecisionRow]s matching the given query parameters.
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
  Future<List<HumanDecisionRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HumanDecisionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HumanDecisionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HumanDecisionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HumanDecisionRow>(
      where: where?.call(HumanDecisionRow.t),
      orderBy: orderBy?.call(HumanDecisionRow.t),
      orderByList: orderByList?.call(HumanDecisionRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [HumanDecisionRow] matching the given query parameters.
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
  Future<HumanDecisionRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HumanDecisionRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<HumanDecisionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HumanDecisionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HumanDecisionRow>(
      where: where?.call(HumanDecisionRow.t),
      orderBy: orderBy?.call(HumanDecisionRow.t),
      orderByList: orderByList?.call(HumanDecisionRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HumanDecisionRow] by its [id] or null if no such row exists.
  Future<HumanDecisionRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<HumanDecisionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [HumanDecisionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [HumanDecisionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<HumanDecisionRow>> insert(
    _i1.DatabaseSession session,
    List<HumanDecisionRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<HumanDecisionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [HumanDecisionRow] and returns the inserted row.
  ///
  /// The returned [HumanDecisionRow] will have its `id` field set.
  Future<HumanDecisionRow> insertRow(
    _i1.DatabaseSession session,
    HumanDecisionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<HumanDecisionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [HumanDecisionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<HumanDecisionRow>> update(
    _i1.DatabaseSession session,
    List<HumanDecisionRow> rows, {
    _i1.ColumnSelections<HumanDecisionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<HumanDecisionRow>(
      rows,
      columns: columns?.call(HumanDecisionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HumanDecisionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HumanDecisionRow> updateRow(
    _i1.DatabaseSession session,
    HumanDecisionRow row, {
    _i1.ColumnSelections<HumanDecisionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<HumanDecisionRow>(
      row,
      columns: columns?.call(HumanDecisionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HumanDecisionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<HumanDecisionRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<HumanDecisionRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<HumanDecisionRow>(
      id,
      columnValues: columnValues(HumanDecisionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HumanDecisionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<HumanDecisionRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<HumanDecisionRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<HumanDecisionRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HumanDecisionRowTable>? orderBy,
    _i1.OrderByListBuilder<HumanDecisionRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<HumanDecisionRow>(
      columnValues: columnValues(HumanDecisionRow.t.updateTable),
      where: where(HumanDecisionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HumanDecisionRow.t),
      orderByList: orderByList?.call(HumanDecisionRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [HumanDecisionRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<HumanDecisionRow>> delete(
    _i1.DatabaseSession session,
    List<HumanDecisionRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<HumanDecisionRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [HumanDecisionRow].
  Future<HumanDecisionRow> deleteRow(
    _i1.DatabaseSession session,
    HumanDecisionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HumanDecisionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<HumanDecisionRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HumanDecisionRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<HumanDecisionRow>(
      where: where(HumanDecisionRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HumanDecisionRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<HumanDecisionRow>(
      where: where?.call(HumanDecisionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HumanDecisionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HumanDecisionRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HumanDecisionRow>(
      where: where(HumanDecisionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

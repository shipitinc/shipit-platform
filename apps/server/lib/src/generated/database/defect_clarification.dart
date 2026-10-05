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

abstract class DefectClarificationRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DefectClarificationRow._({
    this.id,
    required this.clarificationId,
    required this.defectId,
    required this.question,
    required this.reason,
    required this.status,
    this.answer,
    this.humanDecisionId,
    this.requestedByTriageJobId,
    required this.requestedAt,
    this.answeredAt,
    required this.createdAt,
    required this.version,
  });

  factory DefectClarificationRow({
    int? id,
    required String clarificationId,
    required String defectId,
    required String question,
    required String reason,
    required String status,
    String? answer,
    String? humanDecisionId,
    String? requestedByTriageJobId,
    required DateTime requestedAt,
    DateTime? answeredAt,
    required DateTime createdAt,
    required int version,
  }) = _DefectClarificationRowImpl;

  factory DefectClarificationRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DefectClarificationRow(
      id: jsonSerialization['id'] as int?,
      clarificationId: jsonSerialization['clarificationId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      question: jsonSerialization['question'] as String,
      reason: jsonSerialization['reason'] as String,
      status: jsonSerialization['status'] as String,
      answer: jsonSerialization['answer'] as String?,
      humanDecisionId: jsonSerialization['humanDecisionId'] as String?,
      requestedByTriageJobId:
          jsonSerialization['requestedByTriageJobId'] as String?,
      requestedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['requestedAt'],
      ),
      answeredAt: jsonSerialization['answeredAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['answeredAt']),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = DefectClarificationRowTable();

  static const db = DefectClarificationRowRepository._();

  @override
  int? id;

  String clarificationId;

  String defectId;

  String question;

  String reason;

  String status;

  String? answer;

  String? humanDecisionId;

  String? requestedByTriageJobId;

  DateTime requestedAt;

  DateTime? answeredAt;

  DateTime createdAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DefectClarificationRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectClarificationRow copyWith({
    int? id,
    String? clarificationId,
    String? defectId,
    String? question,
    String? reason,
    String? status,
    String? answer,
    String? humanDecisionId,
    String? requestedByTriageJobId,
    DateTime? requestedAt,
    DateTime? answeredAt,
    DateTime? createdAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectClarificationRow',
      if (id != null) 'id': id,
      'clarificationId': clarificationId,
      'defectId': defectId,
      'question': question,
      'reason': reason,
      'status': status,
      if (answer != null) 'answer': answer,
      if (humanDecisionId != null) 'humanDecisionId': humanDecisionId,
      if (requestedByTriageJobId != null)
        'requestedByTriageJobId': requestedByTriageJobId,
      'requestedAt': requestedAt.toJson(),
      if (answeredAt != null) 'answeredAt': answeredAt?.toJson(),
      'createdAt': createdAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DefectClarificationRowInclude include() {
    return DefectClarificationRowInclude._();
  }

  static DefectClarificationRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DefectClarificationRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectClarificationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectClarificationRowTable>? orderByList,
    DefectClarificationRowInclude? include,
  }) {
    return DefectClarificationRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectClarificationRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DefectClarificationRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectClarificationRowImpl extends DefectClarificationRow {
  _DefectClarificationRowImpl({
    int? id,
    required String clarificationId,
    required String defectId,
    required String question,
    required String reason,
    required String status,
    String? answer,
    String? humanDecisionId,
    String? requestedByTriageJobId,
    required DateTime requestedAt,
    DateTime? answeredAt,
    required DateTime createdAt,
    required int version,
  }) : super._(
         id: id,
         clarificationId: clarificationId,
         defectId: defectId,
         question: question,
         reason: reason,
         status: status,
         answer: answer,
         humanDecisionId: humanDecisionId,
         requestedByTriageJobId: requestedByTriageJobId,
         requestedAt: requestedAt,
         answeredAt: answeredAt,
         createdAt: createdAt,
         version: version,
       );

  /// Returns a shallow copy of this [DefectClarificationRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectClarificationRow copyWith({
    Object? id = _Undefined,
    String? clarificationId,
    String? defectId,
    String? question,
    String? reason,
    String? status,
    Object? answer = _Undefined,
    Object? humanDecisionId = _Undefined,
    Object? requestedByTriageJobId = _Undefined,
    DateTime? requestedAt,
    Object? answeredAt = _Undefined,
    DateTime? createdAt,
    int? version,
  }) {
    return DefectClarificationRow(
      id: id is int? ? id : this.id,
      clarificationId: clarificationId ?? this.clarificationId,
      defectId: defectId ?? this.defectId,
      question: question ?? this.question,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      answer: answer is String? ? answer : this.answer,
      humanDecisionId: humanDecisionId is String?
          ? humanDecisionId
          : this.humanDecisionId,
      requestedByTriageJobId: requestedByTriageJobId is String?
          ? requestedByTriageJobId
          : this.requestedByTriageJobId,
      requestedAt: requestedAt ?? this.requestedAt,
      answeredAt: answeredAt is DateTime? ? answeredAt : this.answeredAt,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
    );
  }
}

class DefectClarificationRowUpdateTable
    extends _i1.UpdateTable<DefectClarificationRowTable> {
  DefectClarificationRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> clarificationId(String value) =>
      _i1.ColumnValue(
        table.clarificationId,
        value,
      );

  _i1.ColumnValue<String, String> defectId(String value) => _i1.ColumnValue(
    table.defectId,
    value,
  );

  _i1.ColumnValue<String, String> question(String value) => _i1.ColumnValue(
    table.question,
    value,
  );

  _i1.ColumnValue<String, String> reason(String value) => _i1.ColumnValue(
    table.reason,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> answer(String? value) => _i1.ColumnValue(
    table.answer,
    value,
  );

  _i1.ColumnValue<String, String> humanDecisionId(String? value) =>
      _i1.ColumnValue(
        table.humanDecisionId,
        value,
      );

  _i1.ColumnValue<String, String> requestedByTriageJobId(String? value) =>
      _i1.ColumnValue(
        table.requestedByTriageJobId,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> requestedAt(DateTime value) =>
      _i1.ColumnValue(
        table.requestedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> answeredAt(DateTime? value) =>
      _i1.ColumnValue(
        table.answeredAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class DefectClarificationRowTable extends _i1.Table<int?> {
  DefectClarificationRowTable({super.tableRelation})
    : super(tableName: 'defect_clarification') {
    updateTable = DefectClarificationRowUpdateTable(this);
    clarificationId = _i1.ColumnString(
      'clarificationId',
      this,
    );
    defectId = _i1.ColumnString(
      'defectId',
      this,
    );
    question = _i1.ColumnString(
      'question',
      this,
    );
    reason = _i1.ColumnString(
      'reason',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    answer = _i1.ColumnString(
      'answer',
      this,
    );
    humanDecisionId = _i1.ColumnString(
      'humanDecisionId',
      this,
    );
    requestedByTriageJobId = _i1.ColumnString(
      'requestedByTriageJobId',
      this,
    );
    requestedAt = _i1.ColumnDateTime(
      'requestedAt',
      this,
    );
    answeredAt = _i1.ColumnDateTime(
      'answeredAt',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final DefectClarificationRowUpdateTable updateTable;

  late final _i1.ColumnString clarificationId;

  late final _i1.ColumnString defectId;

  late final _i1.ColumnString question;

  late final _i1.ColumnString reason;

  late final _i1.ColumnString status;

  late final _i1.ColumnString answer;

  late final _i1.ColumnString humanDecisionId;

  late final _i1.ColumnString requestedByTriageJobId;

  late final _i1.ColumnDateTime requestedAt;

  late final _i1.ColumnDateTime answeredAt;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    clarificationId,
    defectId,
    question,
    reason,
    status,
    answer,
    humanDecisionId,
    requestedByTriageJobId,
    requestedAt,
    answeredAt,
    createdAt,
    version,
  ];
}

class DefectClarificationRowInclude extends _i1.IncludeObject {
  DefectClarificationRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DefectClarificationRow.t;
}

class DefectClarificationRowIncludeList extends _i1.IncludeList {
  DefectClarificationRowIncludeList._({
    _i1.WhereExpressionBuilder<DefectClarificationRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DefectClarificationRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DefectClarificationRow.t;
}

class DefectClarificationRowRepository {
  const DefectClarificationRowRepository._();

  /// Returns a list of [DefectClarificationRow]s matching the given query parameters.
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
  Future<List<DefectClarificationRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectClarificationRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectClarificationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectClarificationRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DefectClarificationRow>(
      where: where?.call(DefectClarificationRow.t),
      orderBy: orderBy?.call(DefectClarificationRow.t),
      orderByList: orderByList?.call(DefectClarificationRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DefectClarificationRow] matching the given query parameters.
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
  Future<DefectClarificationRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectClarificationRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DefectClarificationRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectClarificationRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DefectClarificationRow>(
      where: where?.call(DefectClarificationRow.t),
      orderBy: orderBy?.call(DefectClarificationRow.t),
      orderByList: orderByList?.call(DefectClarificationRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DefectClarificationRow] by its [id] or null if no such row exists.
  Future<DefectClarificationRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DefectClarificationRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DefectClarificationRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DefectClarificationRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DefectClarificationRow>> insert(
    _i1.DatabaseSession session,
    List<DefectClarificationRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DefectClarificationRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DefectClarificationRow] and returns the inserted row.
  ///
  /// The returned [DefectClarificationRow] will have its `id` field set.
  Future<DefectClarificationRow> insertRow(
    _i1.DatabaseSession session,
    DefectClarificationRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DefectClarificationRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DefectClarificationRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DefectClarificationRow>> update(
    _i1.DatabaseSession session,
    List<DefectClarificationRow> rows, {
    _i1.ColumnSelections<DefectClarificationRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DefectClarificationRow>(
      rows,
      columns: columns?.call(DefectClarificationRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectClarificationRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DefectClarificationRow> updateRow(
    _i1.DatabaseSession session,
    DefectClarificationRow row, {
    _i1.ColumnSelections<DefectClarificationRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DefectClarificationRow>(
      row,
      columns: columns?.call(DefectClarificationRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectClarificationRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DefectClarificationRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DefectClarificationRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DefectClarificationRow>(
      id,
      columnValues: columnValues(DefectClarificationRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DefectClarificationRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DefectClarificationRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DefectClarificationRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DefectClarificationRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectClarificationRowTable>? orderBy,
    _i1.OrderByListBuilder<DefectClarificationRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DefectClarificationRow>(
      columnValues: columnValues(DefectClarificationRow.t.updateTable),
      where: where(DefectClarificationRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectClarificationRow.t),
      orderByList: orderByList?.call(DefectClarificationRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DefectClarificationRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DefectClarificationRow>> delete(
    _i1.DatabaseSession session,
    List<DefectClarificationRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DefectClarificationRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DefectClarificationRow].
  Future<DefectClarificationRow> deleteRow(
    _i1.DatabaseSession session,
    DefectClarificationRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DefectClarificationRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DefectClarificationRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectClarificationRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DefectClarificationRow>(
      where: where(DefectClarificationRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectClarificationRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DefectClarificationRow>(
      where: where?.call(DefectClarificationRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DefectClarificationRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectClarificationRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DefectClarificationRow>(
      where: where(DefectClarificationRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

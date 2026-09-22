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

abstract class ClarificationRequestRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ClarificationRequestRow._({
    this.id,
    required this.clarificationId,
    required this.productId,
    required this.onboardingId,
    required this.section,
    required this.question,
    required this.status,
    this.answer,
    required this.createdAt,
    this.answeredAt,
    this.answeredBy,
  });

  factory ClarificationRequestRow({
    int? id,
    required String clarificationId,
    required String productId,
    required String onboardingId,
    required String section,
    required String question,
    required String status,
    String? answer,
    required DateTime createdAt,
    DateTime? answeredAt,
    String? answeredBy,
  }) = _ClarificationRequestRowImpl;

  factory ClarificationRequestRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ClarificationRequestRow(
      id: jsonSerialization['id'] as int?,
      clarificationId: jsonSerialization['clarificationId'] as String,
      productId: jsonSerialization['productId'] as String,
      onboardingId: jsonSerialization['onboardingId'] as String,
      section: jsonSerialization['section'] as String,
      question: jsonSerialization['question'] as String,
      status: jsonSerialization['status'] as String,
      answer: jsonSerialization['answer'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      answeredAt: jsonSerialization['answeredAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['answeredAt']),
      answeredBy: jsonSerialization['answeredBy'] as String?,
    );
  }

  static final t = ClarificationRequestRowTable();

  static const db = ClarificationRequestRowRepository._();

  @override
  int? id;

  String clarificationId;

  String productId;

  String onboardingId;

  String section;

  String question;

  String status;

  String? answer;

  DateTime createdAt;

  DateTime? answeredAt;

  String? answeredBy;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ClarificationRequestRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClarificationRequestRow copyWith({
    int? id,
    String? clarificationId,
    String? productId,
    String? onboardingId,
    String? section,
    String? question,
    String? status,
    String? answer,
    DateTime? createdAt,
    DateTime? answeredAt,
    String? answeredBy,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClarificationRequestRow',
      if (id != null) 'id': id,
      'clarificationId': clarificationId,
      'productId': productId,
      'onboardingId': onboardingId,
      'section': section,
      'question': question,
      'status': status,
      if (answer != null) 'answer': answer,
      'createdAt': createdAt.toJson(),
      if (answeredAt != null) 'answeredAt': answeredAt?.toJson(),
      if (answeredBy != null) 'answeredBy': answeredBy,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static ClarificationRequestRowInclude include() {
    return ClarificationRequestRowInclude._();
  }

  static ClarificationRequestRowIncludeList includeList({
    _i1.WhereExpressionBuilder<ClarificationRequestRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClarificationRequestRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClarificationRequestRowTable>? orderByList,
    ClarificationRequestRowInclude? include,
  }) {
    return ClarificationRequestRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClarificationRequestRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ClarificationRequestRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClarificationRequestRowImpl extends ClarificationRequestRow {
  _ClarificationRequestRowImpl({
    int? id,
    required String clarificationId,
    required String productId,
    required String onboardingId,
    required String section,
    required String question,
    required String status,
    String? answer,
    required DateTime createdAt,
    DateTime? answeredAt,
    String? answeredBy,
  }) : super._(
         id: id,
         clarificationId: clarificationId,
         productId: productId,
         onboardingId: onboardingId,
         section: section,
         question: question,
         status: status,
         answer: answer,
         createdAt: createdAt,
         answeredAt: answeredAt,
         answeredBy: answeredBy,
       );

  /// Returns a shallow copy of this [ClarificationRequestRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClarificationRequestRow copyWith({
    Object? id = _Undefined,
    String? clarificationId,
    String? productId,
    String? onboardingId,
    String? section,
    String? question,
    String? status,
    Object? answer = _Undefined,
    DateTime? createdAt,
    Object? answeredAt = _Undefined,
    Object? answeredBy = _Undefined,
  }) {
    return ClarificationRequestRow(
      id: id is int? ? id : this.id,
      clarificationId: clarificationId ?? this.clarificationId,
      productId: productId ?? this.productId,
      onboardingId: onboardingId ?? this.onboardingId,
      section: section ?? this.section,
      question: question ?? this.question,
      status: status ?? this.status,
      answer: answer is String? ? answer : this.answer,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt is DateTime? ? answeredAt : this.answeredAt,
      answeredBy: answeredBy is String? ? answeredBy : this.answeredBy,
    );
  }
}

class ClarificationRequestRowUpdateTable
    extends _i1.UpdateTable<ClarificationRequestRowTable> {
  ClarificationRequestRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> clarificationId(String value) =>
      _i1.ColumnValue(
        table.clarificationId,
        value,
      );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> onboardingId(String value) => _i1.ColumnValue(
    table.onboardingId,
    value,
  );

  _i1.ColumnValue<String, String> section(String value) => _i1.ColumnValue(
    table.section,
    value,
  );

  _i1.ColumnValue<String, String> question(String value) => _i1.ColumnValue(
    table.question,
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

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> answeredAt(DateTime? value) =>
      _i1.ColumnValue(
        table.answeredAt,
        value,
      );

  _i1.ColumnValue<String, String> answeredBy(String? value) => _i1.ColumnValue(
    table.answeredBy,
    value,
  );
}

class ClarificationRequestRowTable extends _i1.Table<int?> {
  ClarificationRequestRowTable({super.tableRelation})
    : super(tableName: 'clarification_request') {
    updateTable = ClarificationRequestRowUpdateTable(this);
    clarificationId = _i1.ColumnString(
      'clarificationId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    onboardingId = _i1.ColumnString(
      'onboardingId',
      this,
    );
    section = _i1.ColumnString(
      'section',
      this,
    );
    question = _i1.ColumnString(
      'question',
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
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    answeredAt = _i1.ColumnDateTime(
      'answeredAt',
      this,
    );
    answeredBy = _i1.ColumnString(
      'answeredBy',
      this,
    );
  }

  late final ClarificationRequestRowUpdateTable updateTable;

  late final _i1.ColumnString clarificationId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString onboardingId;

  late final _i1.ColumnString section;

  late final _i1.ColumnString question;

  late final _i1.ColumnString status;

  late final _i1.ColumnString answer;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime answeredAt;

  late final _i1.ColumnString answeredBy;

  @override
  List<_i1.Column> get columns => [
    id,
    clarificationId,
    productId,
    onboardingId,
    section,
    question,
    status,
    answer,
    createdAt,
    answeredAt,
    answeredBy,
  ];
}

class ClarificationRequestRowInclude extends _i1.IncludeObject {
  ClarificationRequestRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ClarificationRequestRow.t;
}

class ClarificationRequestRowIncludeList extends _i1.IncludeList {
  ClarificationRequestRowIncludeList._({
    _i1.WhereExpressionBuilder<ClarificationRequestRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ClarificationRequestRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ClarificationRequestRow.t;
}

class ClarificationRequestRowRepository {
  const ClarificationRequestRowRepository._();

  /// Returns a list of [ClarificationRequestRow]s matching the given query parameters.
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
  Future<List<ClarificationRequestRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClarificationRequestRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClarificationRequestRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClarificationRequestRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ClarificationRequestRow>(
      where: where?.call(ClarificationRequestRow.t),
      orderBy: orderBy?.call(ClarificationRequestRow.t),
      orderByList: orderByList?.call(ClarificationRequestRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ClarificationRequestRow] matching the given query parameters.
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
  Future<ClarificationRequestRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClarificationRequestRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<ClarificationRequestRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ClarificationRequestRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ClarificationRequestRow>(
      where: where?.call(ClarificationRequestRow.t),
      orderBy: orderBy?.call(ClarificationRequestRow.t),
      orderByList: orderByList?.call(ClarificationRequestRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ClarificationRequestRow] by its [id] or null if no such row exists.
  Future<ClarificationRequestRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ClarificationRequestRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ClarificationRequestRow]s in the list and returns the inserted rows.
  ///
  /// The returned [ClarificationRequestRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ClarificationRequestRow>> insert(
    _i1.DatabaseSession session,
    List<ClarificationRequestRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ClarificationRequestRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ClarificationRequestRow] and returns the inserted row.
  ///
  /// The returned [ClarificationRequestRow] will have its `id` field set.
  Future<ClarificationRequestRow> insertRow(
    _i1.DatabaseSession session,
    ClarificationRequestRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ClarificationRequestRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ClarificationRequestRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ClarificationRequestRow>> update(
    _i1.DatabaseSession session,
    List<ClarificationRequestRow> rows, {
    _i1.ColumnSelections<ClarificationRequestRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ClarificationRequestRow>(
      rows,
      columns: columns?.call(ClarificationRequestRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClarificationRequestRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ClarificationRequestRow> updateRow(
    _i1.DatabaseSession session,
    ClarificationRequestRow row, {
    _i1.ColumnSelections<ClarificationRequestRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ClarificationRequestRow>(
      row,
      columns: columns?.call(ClarificationRequestRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ClarificationRequestRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ClarificationRequestRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ClarificationRequestRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ClarificationRequestRow>(
      id,
      columnValues: columnValues(ClarificationRequestRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ClarificationRequestRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ClarificationRequestRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ClarificationRequestRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<ClarificationRequestRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ClarificationRequestRowTable>? orderBy,
    _i1.OrderByListBuilder<ClarificationRequestRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ClarificationRequestRow>(
      columnValues: columnValues(ClarificationRequestRow.t.updateTable),
      where: where(ClarificationRequestRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ClarificationRequestRow.t),
      orderByList: orderByList?.call(ClarificationRequestRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ClarificationRequestRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ClarificationRequestRow>> delete(
    _i1.DatabaseSession session,
    List<ClarificationRequestRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ClarificationRequestRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ClarificationRequestRow].
  Future<ClarificationRequestRow> deleteRow(
    _i1.DatabaseSession session,
    ClarificationRequestRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ClarificationRequestRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ClarificationRequestRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClarificationRequestRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ClarificationRequestRow>(
      where: where(ClarificationRequestRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ClarificationRequestRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ClarificationRequestRow>(
      where: where?.call(ClarificationRequestRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ClarificationRequestRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ClarificationRequestRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ClarificationRequestRow>(
      where: where(ClarificationRequestRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

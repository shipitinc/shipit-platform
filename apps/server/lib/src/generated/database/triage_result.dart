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
import 'package:control_plane_server/src/generated/protocol.dart' as _i2;

abstract class TriageResultRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  TriageResultRow._({
    this.id,
    required this.resultId,
    required this.defectId,
    required this.recommendedStatus,
    this.recommendedClassification,
    required this.confidence,
    required this.suspectedCategory,
    required this.suspectedComponents,
    required this.reproductionSupported,
    required this.evidenceUsed,
    this.clarificationRequired,
    required this.recommendedNextAction,
    this.possibleDuplicateDefectId,
    this.recommendedWorkItemCategory,
    required this.summary,
    required this.jobId,
    this.executionId,
    required this.createdAt,
    this.completedAt,
    required this.version,
  });

  factory TriageResultRow({
    int? id,
    required String resultId,
    required String defectId,
    required String recommendedStatus,
    String? recommendedClassification,
    required double confidence,
    required String suspectedCategory,
    required List<String> suspectedComponents,
    required bool reproductionSupported,
    required List<String> evidenceUsed,
    String? clarificationRequired,
    required String recommendedNextAction,
    String? possibleDuplicateDefectId,
    String? recommendedWorkItemCategory,
    required String summary,
    required String jobId,
    String? executionId,
    required DateTime createdAt,
    DateTime? completedAt,
    required int version,
  }) = _TriageResultRowImpl;

  factory TriageResultRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return TriageResultRow(
      id: jsonSerialization['id'] as int?,
      resultId: jsonSerialization['resultId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      recommendedStatus: jsonSerialization['recommendedStatus'] as String,
      recommendedClassification:
          jsonSerialization['recommendedClassification'] as String?,
      confidence: (jsonSerialization['confidence'] as num).toDouble(),
      suspectedCategory: jsonSerialization['suspectedCategory'] as String,
      suspectedComponents: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['suspectedComponents'],
      ),
      reproductionSupported: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['reproductionSupported'],
      ),
      evidenceUsed: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['evidenceUsed'],
      ),
      clarificationRequired:
          jsonSerialization['clarificationRequired'] as String?,
      recommendedNextAction:
          jsonSerialization['recommendedNextAction'] as String,
      possibleDuplicateDefectId:
          jsonSerialization['possibleDuplicateDefectId'] as String?,
      recommendedWorkItemCategory:
          jsonSerialization['recommendedWorkItemCategory'] as String?,
      summary: jsonSerialization['summary'] as String,
      jobId: jsonSerialization['jobId'] as String,
      executionId: jsonSerialization['executionId'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = TriageResultRowTable();

  static const db = TriageResultRowRepository._();

  @override
  int? id;

  String resultId;

  String defectId;

  String recommendedStatus;

  String? recommendedClassification;

  double confidence;

  String suspectedCategory;

  List<String> suspectedComponents;

  bool reproductionSupported;

  List<String> evidenceUsed;

  String? clarificationRequired;

  String recommendedNextAction;

  String? possibleDuplicateDefectId;

  String? recommendedWorkItemCategory;

  String summary;

  String jobId;

  String? executionId;

  DateTime createdAt;

  DateTime? completedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [TriageResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  TriageResultRow copyWith({
    int? id,
    String? resultId,
    String? defectId,
    String? recommendedStatus,
    String? recommendedClassification,
    double? confidence,
    String? suspectedCategory,
    List<String>? suspectedComponents,
    bool? reproductionSupported,
    List<String>? evidenceUsed,
    String? clarificationRequired,
    String? recommendedNextAction,
    String? possibleDuplicateDefectId,
    String? recommendedWorkItemCategory,
    String? summary,
    String? jobId,
    String? executionId,
    DateTime? createdAt,
    DateTime? completedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TriageResultRow',
      if (id != null) 'id': id,
      'resultId': resultId,
      'defectId': defectId,
      'recommendedStatus': recommendedStatus,
      if (recommendedClassification != null)
        'recommendedClassification': recommendedClassification,
      'confidence': confidence,
      'suspectedCategory': suspectedCategory,
      'suspectedComponents': suspectedComponents.toJson(),
      'reproductionSupported': reproductionSupported,
      'evidenceUsed': evidenceUsed.toJson(),
      if (clarificationRequired != null)
        'clarificationRequired': clarificationRequired,
      'recommendedNextAction': recommendedNextAction,
      if (possibleDuplicateDefectId != null)
        'possibleDuplicateDefectId': possibleDuplicateDefectId,
      if (recommendedWorkItemCategory != null)
        'recommendedWorkItemCategory': recommendedWorkItemCategory,
      'summary': summary,
      'jobId': jobId,
      if (executionId != null) 'executionId': executionId,
      'createdAt': createdAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static TriageResultRowInclude include() {
    return TriageResultRowInclude._();
  }

  static TriageResultRowIncludeList includeList({
    _i1.WhereExpressionBuilder<TriageResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TriageResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<TriageResultRowTable>? orderByList,
    TriageResultRowInclude? include,
  }) {
    return TriageResultRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(TriageResultRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(TriageResultRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TriageResultRowImpl extends TriageResultRow {
  _TriageResultRowImpl({
    int? id,
    required String resultId,
    required String defectId,
    required String recommendedStatus,
    String? recommendedClassification,
    required double confidence,
    required String suspectedCategory,
    required List<String> suspectedComponents,
    required bool reproductionSupported,
    required List<String> evidenceUsed,
    String? clarificationRequired,
    required String recommendedNextAction,
    String? possibleDuplicateDefectId,
    String? recommendedWorkItemCategory,
    required String summary,
    required String jobId,
    String? executionId,
    required DateTime createdAt,
    DateTime? completedAt,
    required int version,
  }) : super._(
         id: id,
         resultId: resultId,
         defectId: defectId,
         recommendedStatus: recommendedStatus,
         recommendedClassification: recommendedClassification,
         confidence: confidence,
         suspectedCategory: suspectedCategory,
         suspectedComponents: suspectedComponents,
         reproductionSupported: reproductionSupported,
         evidenceUsed: evidenceUsed,
         clarificationRequired: clarificationRequired,
         recommendedNextAction: recommendedNextAction,
         possibleDuplicateDefectId: possibleDuplicateDefectId,
         recommendedWorkItemCategory: recommendedWorkItemCategory,
         summary: summary,
         jobId: jobId,
         executionId: executionId,
         createdAt: createdAt,
         completedAt: completedAt,
         version: version,
       );

  /// Returns a shallow copy of this [TriageResultRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  TriageResultRow copyWith({
    Object? id = _Undefined,
    String? resultId,
    String? defectId,
    String? recommendedStatus,
    Object? recommendedClassification = _Undefined,
    double? confidence,
    String? suspectedCategory,
    List<String>? suspectedComponents,
    bool? reproductionSupported,
    List<String>? evidenceUsed,
    Object? clarificationRequired = _Undefined,
    String? recommendedNextAction,
    Object? possibleDuplicateDefectId = _Undefined,
    Object? recommendedWorkItemCategory = _Undefined,
    String? summary,
    String? jobId,
    Object? executionId = _Undefined,
    DateTime? createdAt,
    Object? completedAt = _Undefined,
    int? version,
  }) {
    return TriageResultRow(
      id: id is int? ? id : this.id,
      resultId: resultId ?? this.resultId,
      defectId: defectId ?? this.defectId,
      recommendedStatus: recommendedStatus ?? this.recommendedStatus,
      recommendedClassification: recommendedClassification is String?
          ? recommendedClassification
          : this.recommendedClassification,
      confidence: confidence ?? this.confidence,
      suspectedCategory: suspectedCategory ?? this.suspectedCategory,
      suspectedComponents:
          suspectedComponents ??
          this.suspectedComponents.map((e0) => e0).toList(),
      reproductionSupported:
          reproductionSupported ?? this.reproductionSupported,
      evidenceUsed: evidenceUsed ?? this.evidenceUsed.map((e0) => e0).toList(),
      clarificationRequired: clarificationRequired is String?
          ? clarificationRequired
          : this.clarificationRequired,
      recommendedNextAction:
          recommendedNextAction ?? this.recommendedNextAction,
      possibleDuplicateDefectId: possibleDuplicateDefectId is String?
          ? possibleDuplicateDefectId
          : this.possibleDuplicateDefectId,
      recommendedWorkItemCategory: recommendedWorkItemCategory is String?
          ? recommendedWorkItemCategory
          : this.recommendedWorkItemCategory,
      summary: summary ?? this.summary,
      jobId: jobId ?? this.jobId,
      executionId: executionId is String? ? executionId : this.executionId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      version: version ?? this.version,
    );
  }
}

class TriageResultRowUpdateTable extends _i1.UpdateTable<TriageResultRowTable> {
  TriageResultRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> resultId(String value) => _i1.ColumnValue(
    table.resultId,
    value,
  );

  _i1.ColumnValue<String, String> defectId(String value) => _i1.ColumnValue(
    table.defectId,
    value,
  );

  _i1.ColumnValue<String, String> recommendedStatus(String value) =>
      _i1.ColumnValue(
        table.recommendedStatus,
        value,
      );

  _i1.ColumnValue<String, String> recommendedClassification(String? value) =>
      _i1.ColumnValue(
        table.recommendedClassification,
        value,
      );

  _i1.ColumnValue<double, double> confidence(double value) => _i1.ColumnValue(
    table.confidence,
    value,
  );

  _i1.ColumnValue<String, String> suspectedCategory(String value) =>
      _i1.ColumnValue(
        table.suspectedCategory,
        value,
      );

  _i1.ColumnValue<List<String>, List<String>> suspectedComponents(
    List<String> value,
  ) => _i1.ColumnValue(
    table.suspectedComponents,
    value,
  );

  _i1.ColumnValue<bool, bool> reproductionSupported(bool value) =>
      _i1.ColumnValue(
        table.reproductionSupported,
        value,
      );

  _i1.ColumnValue<List<String>, List<String>> evidenceUsed(
    List<String> value,
  ) => _i1.ColumnValue(
    table.evidenceUsed,
    value,
  );

  _i1.ColumnValue<String, String> clarificationRequired(String? value) =>
      _i1.ColumnValue(
        table.clarificationRequired,
        value,
      );

  _i1.ColumnValue<String, String> recommendedNextAction(String value) =>
      _i1.ColumnValue(
        table.recommendedNextAction,
        value,
      );

  _i1.ColumnValue<String, String> possibleDuplicateDefectId(String? value) =>
      _i1.ColumnValue(
        table.possibleDuplicateDefectId,
        value,
      );

  _i1.ColumnValue<String, String> recommendedWorkItemCategory(String? value) =>
      _i1.ColumnValue(
        table.recommendedWorkItemCategory,
        value,
      );

  _i1.ColumnValue<String, String> summary(String value) => _i1.ColumnValue(
    table.summary,
    value,
  );

  _i1.ColumnValue<String, String> jobId(String value) => _i1.ColumnValue(
    table.jobId,
    value,
  );

  _i1.ColumnValue<String, String> executionId(String? value) => _i1.ColumnValue(
    table.executionId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.completedAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class TriageResultRowTable extends _i1.Table<int?> {
  TriageResultRowTable({super.tableRelation})
    : super(tableName: 'triage_result') {
    updateTable = TriageResultRowUpdateTable(this);
    resultId = _i1.ColumnString(
      'resultId',
      this,
    );
    defectId = _i1.ColumnString(
      'defectId',
      this,
    );
    recommendedStatus = _i1.ColumnString(
      'recommendedStatus',
      this,
    );
    recommendedClassification = _i1.ColumnString(
      'recommendedClassification',
      this,
    );
    confidence = _i1.ColumnDouble(
      'confidence',
      this,
    );
    suspectedCategory = _i1.ColumnString(
      'suspectedCategory',
      this,
    );
    suspectedComponents = _i1.ColumnSerializable<List<String>>(
      'suspectedComponents',
      this,
    );
    reproductionSupported = _i1.ColumnBool(
      'reproductionSupported',
      this,
    );
    evidenceUsed = _i1.ColumnSerializable<List<String>>(
      'evidenceUsed',
      this,
    );
    clarificationRequired = _i1.ColumnString(
      'clarificationRequired',
      this,
    );
    recommendedNextAction = _i1.ColumnString(
      'recommendedNextAction',
      this,
    );
    possibleDuplicateDefectId = _i1.ColumnString(
      'possibleDuplicateDefectId',
      this,
    );
    recommendedWorkItemCategory = _i1.ColumnString(
      'recommendedWorkItemCategory',
      this,
    );
    summary = _i1.ColumnString(
      'summary',
      this,
    );
    jobId = _i1.ColumnString(
      'jobId',
      this,
    );
    executionId = _i1.ColumnString(
      'executionId',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    completedAt = _i1.ColumnDateTime(
      'completedAt',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final TriageResultRowUpdateTable updateTable;

  late final _i1.ColumnString resultId;

  late final _i1.ColumnString defectId;

  late final _i1.ColumnString recommendedStatus;

  late final _i1.ColumnString recommendedClassification;

  late final _i1.ColumnDouble confidence;

  late final _i1.ColumnString suspectedCategory;

  late final _i1.ColumnSerializable<List<String>> suspectedComponents;

  late final _i1.ColumnBool reproductionSupported;

  late final _i1.ColumnSerializable<List<String>> evidenceUsed;

  late final _i1.ColumnString clarificationRequired;

  late final _i1.ColumnString recommendedNextAction;

  late final _i1.ColumnString possibleDuplicateDefectId;

  late final _i1.ColumnString recommendedWorkItemCategory;

  late final _i1.ColumnString summary;

  late final _i1.ColumnString jobId;

  late final _i1.ColumnString executionId;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime completedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    resultId,
    defectId,
    recommendedStatus,
    recommendedClassification,
    confidence,
    suspectedCategory,
    suspectedComponents,
    reproductionSupported,
    evidenceUsed,
    clarificationRequired,
    recommendedNextAction,
    possibleDuplicateDefectId,
    recommendedWorkItemCategory,
    summary,
    jobId,
    executionId,
    createdAt,
    completedAt,
    version,
  ];
}

class TriageResultRowInclude extends _i1.IncludeObject {
  TriageResultRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => TriageResultRow.t;
}

class TriageResultRowIncludeList extends _i1.IncludeList {
  TriageResultRowIncludeList._({
    _i1.WhereExpressionBuilder<TriageResultRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(TriageResultRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => TriageResultRow.t;
}

class TriageResultRowRepository {
  const TriageResultRowRepository._();

  /// Returns a list of [TriageResultRow]s matching the given query parameters.
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
  Future<List<TriageResultRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TriageResultRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TriageResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<TriageResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<TriageResultRow>(
      where: where?.call(TriageResultRow.t),
      orderBy: orderBy?.call(TriageResultRow.t),
      orderByList: orderByList?.call(TriageResultRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [TriageResultRow] matching the given query parameters.
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
  Future<TriageResultRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TriageResultRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<TriageResultRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<TriageResultRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<TriageResultRow>(
      where: where?.call(TriageResultRow.t),
      orderBy: orderBy?.call(TriageResultRow.t),
      orderByList: orderByList?.call(TriageResultRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [TriageResultRow] by its [id] or null if no such row exists.
  Future<TriageResultRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<TriageResultRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [TriageResultRow]s in the list and returns the inserted rows.
  ///
  /// The returned [TriageResultRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<TriageResultRow>> insert(
    _i1.DatabaseSession session,
    List<TriageResultRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<TriageResultRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [TriageResultRow] and returns the inserted row.
  ///
  /// The returned [TriageResultRow] will have its `id` field set.
  Future<TriageResultRow> insertRow(
    _i1.DatabaseSession session,
    TriageResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<TriageResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [TriageResultRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<TriageResultRow>> update(
    _i1.DatabaseSession session,
    List<TriageResultRow> rows, {
    _i1.ColumnSelections<TriageResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<TriageResultRow>(
      rows,
      columns: columns?.call(TriageResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [TriageResultRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<TriageResultRow> updateRow(
    _i1.DatabaseSession session,
    TriageResultRow row, {
    _i1.ColumnSelections<TriageResultRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<TriageResultRow>(
      row,
      columns: columns?.call(TriageResultRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [TriageResultRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<TriageResultRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<TriageResultRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<TriageResultRow>(
      id,
      columnValues: columnValues(TriageResultRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [TriageResultRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<TriageResultRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<TriageResultRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<TriageResultRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TriageResultRowTable>? orderBy,
    _i1.OrderByListBuilder<TriageResultRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<TriageResultRow>(
      columnValues: columnValues(TriageResultRow.t.updateTable),
      where: where(TriageResultRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(TriageResultRow.t),
      orderByList: orderByList?.call(TriageResultRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [TriageResultRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<TriageResultRow>> delete(
    _i1.DatabaseSession session,
    List<TriageResultRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<TriageResultRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [TriageResultRow].
  Future<TriageResultRow> deleteRow(
    _i1.DatabaseSession session,
    TriageResultRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<TriageResultRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<TriageResultRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<TriageResultRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<TriageResultRow>(
      where: where(TriageResultRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TriageResultRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<TriageResultRow>(
      where: where?.call(TriageResultRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [TriageResultRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<TriageResultRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<TriageResultRow>(
      where: where(TriageResultRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

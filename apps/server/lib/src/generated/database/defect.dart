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

abstract class DefectRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DefectRow._({
    this.id,
    required this.defectId,
    required this.title,
    required this.description,
    this.expectedBehavior,
    this.reproductionSteps,
    required this.severity,
    required this.status,
    this.classification,
    required this.reporter,
    this.productId,
    this.affectedWorkItemId,
    this.affectedRunId,
    this.remediationWorkItemId,
    this.duplicateOfDefectId,
    this.currentTriageJobId,
    this.clientContextJson,
    this.metadataJson,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
    required this.version,
  });

  factory DefectRow({
    int? id,
    required String defectId,
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    required String status,
    String? classification,
    required String reporter,
    String? productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? remediationWorkItemId,
    String? duplicateOfDefectId,
    String? currentTriageJobId,
    String? clientContextJson,
    String? metadataJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    required int version,
  }) = _DefectRowImpl;

  factory DefectRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectRow(
      id: jsonSerialization['id'] as int?,
      defectId: jsonSerialization['defectId'] as String,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String,
      expectedBehavior: jsonSerialization['expectedBehavior'] as String?,
      reproductionSteps: jsonSerialization['reproductionSteps'] as String?,
      severity: jsonSerialization['severity'] as String,
      status: jsonSerialization['status'] as String,
      classification: jsonSerialization['classification'] as String?,
      reporter: jsonSerialization['reporter'] as String,
      productId: jsonSerialization['productId'] as String?,
      affectedWorkItemId: jsonSerialization['affectedWorkItemId'] as String?,
      affectedRunId: jsonSerialization['affectedRunId'] as String?,
      remediationWorkItemId:
          jsonSerialization['remediationWorkItemId'] as String?,
      duplicateOfDefectId: jsonSerialization['duplicateOfDefectId'] as String?,
      currentTriageJobId: jsonSerialization['currentTriageJobId'] as String?,
      clientContextJson: jsonSerialization['clientContextJson'] as String?,
      metadataJson: jsonSerialization['metadataJson'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      resolvedAt: jsonSerialization['resolvedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['resolvedAt']),
      closedAt: jsonSerialization['closedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['closedAt']),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = DefectRowTable();

  static const db = DefectRowRepository._();

  @override
  int? id;

  String defectId;

  String title;

  String description;

  String? expectedBehavior;

  String? reproductionSteps;

  String severity;

  String status;

  String? classification;

  String reporter;

  String? productId;

  String? affectedWorkItemId;

  String? affectedRunId;

  String? remediationWorkItemId;

  String? duplicateOfDefectId;

  String? currentTriageJobId;

  String? clientContextJson;

  String? metadataJson;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? resolvedAt;

  DateTime? closedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DefectRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectRow copyWith({
    int? id,
    String? defectId,
    String? title,
    String? description,
    String? expectedBehavior,
    String? reproductionSteps,
    String? severity,
    String? status,
    String? classification,
    String? reporter,
    String? productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? remediationWorkItemId,
    String? duplicateOfDefectId,
    String? currentTriageJobId,
    String? clientContextJson,
    String? metadataJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectRow',
      if (id != null) 'id': id,
      'defectId': defectId,
      'title': title,
      'description': description,
      if (expectedBehavior != null) 'expectedBehavior': expectedBehavior,
      if (reproductionSteps != null) 'reproductionSteps': reproductionSteps,
      'severity': severity,
      'status': status,
      if (classification != null) 'classification': classification,
      'reporter': reporter,
      if (productId != null) 'productId': productId,
      if (affectedWorkItemId != null) 'affectedWorkItemId': affectedWorkItemId,
      if (affectedRunId != null) 'affectedRunId': affectedRunId,
      if (remediationWorkItemId != null)
        'remediationWorkItemId': remediationWorkItemId,
      if (duplicateOfDefectId != null)
        'duplicateOfDefectId': duplicateOfDefectId,
      if (currentTriageJobId != null) 'currentTriageJobId': currentTriageJobId,
      if (clientContextJson != null) 'clientContextJson': clientContextJson,
      if (metadataJson != null) 'metadataJson': metadataJson,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (closedAt != null) 'closedAt': closedAt?.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DefectRowInclude include() {
    return DefectRowInclude._();
  }

  static DefectRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DefectRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectRowTable>? orderByList,
    DefectRowInclude? include,
  }) {
    return DefectRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DefectRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectRowImpl extends DefectRow {
  _DefectRowImpl({
    int? id,
    required String defectId,
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    required String status,
    String? classification,
    required String reporter,
    String? productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? remediationWorkItemId,
    String? duplicateOfDefectId,
    String? currentTriageJobId,
    String? clientContextJson,
    String? metadataJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
    required int version,
  }) : super._(
         id: id,
         defectId: defectId,
         title: title,
         description: description,
         expectedBehavior: expectedBehavior,
         reproductionSteps: reproductionSteps,
         severity: severity,
         status: status,
         classification: classification,
         reporter: reporter,
         productId: productId,
         affectedWorkItemId: affectedWorkItemId,
         affectedRunId: affectedRunId,
         remediationWorkItemId: remediationWorkItemId,
         duplicateOfDefectId: duplicateOfDefectId,
         currentTriageJobId: currentTriageJobId,
         clientContextJson: clientContextJson,
         metadataJson: metadataJson,
         createdAt: createdAt,
         updatedAt: updatedAt,
         resolvedAt: resolvedAt,
         closedAt: closedAt,
         version: version,
       );

  /// Returns a shallow copy of this [DefectRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectRow copyWith({
    Object? id = _Undefined,
    String? defectId,
    String? title,
    String? description,
    Object? expectedBehavior = _Undefined,
    Object? reproductionSteps = _Undefined,
    String? severity,
    String? status,
    Object? classification = _Undefined,
    String? reporter,
    Object? productId = _Undefined,
    Object? affectedWorkItemId = _Undefined,
    Object? affectedRunId = _Undefined,
    Object? remediationWorkItemId = _Undefined,
    Object? duplicateOfDefectId = _Undefined,
    Object? currentTriageJobId = _Undefined,
    Object? clientContextJson = _Undefined,
    Object? metadataJson = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? resolvedAt = _Undefined,
    Object? closedAt = _Undefined,
    int? version,
  }) {
    return DefectRow(
      id: id is int? ? id : this.id,
      defectId: defectId ?? this.defectId,
      title: title ?? this.title,
      description: description ?? this.description,
      expectedBehavior: expectedBehavior is String?
          ? expectedBehavior
          : this.expectedBehavior,
      reproductionSteps: reproductionSteps is String?
          ? reproductionSteps
          : this.reproductionSteps,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      classification: classification is String?
          ? classification
          : this.classification,
      reporter: reporter ?? this.reporter,
      productId: productId is String? ? productId : this.productId,
      affectedWorkItemId: affectedWorkItemId is String?
          ? affectedWorkItemId
          : this.affectedWorkItemId,
      affectedRunId: affectedRunId is String?
          ? affectedRunId
          : this.affectedRunId,
      remediationWorkItemId: remediationWorkItemId is String?
          ? remediationWorkItemId
          : this.remediationWorkItemId,
      duplicateOfDefectId: duplicateOfDefectId is String?
          ? duplicateOfDefectId
          : this.duplicateOfDefectId,
      currentTriageJobId: currentTriageJobId is String?
          ? currentTriageJobId
          : this.currentTriageJobId,
      clientContextJson: clientContextJson is String?
          ? clientContextJson
          : this.clientContextJson,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt is DateTime? ? resolvedAt : this.resolvedAt,
      closedAt: closedAt is DateTime? ? closedAt : this.closedAt,
      version: version ?? this.version,
    );
  }
}

class DefectRowUpdateTable extends _i1.UpdateTable<DefectRowTable> {
  DefectRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> defectId(String value) => _i1.ColumnValue(
    table.defectId,
    value,
  );

  _i1.ColumnValue<String, String> title(String value) => _i1.ColumnValue(
    table.title,
    value,
  );

  _i1.ColumnValue<String, String> description(String value) => _i1.ColumnValue(
    table.description,
    value,
  );

  _i1.ColumnValue<String, String> expectedBehavior(String? value) =>
      _i1.ColumnValue(
        table.expectedBehavior,
        value,
      );

  _i1.ColumnValue<String, String> reproductionSteps(String? value) =>
      _i1.ColumnValue(
        table.reproductionSteps,
        value,
      );

  _i1.ColumnValue<String, String> severity(String value) => _i1.ColumnValue(
    table.severity,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> classification(String? value) =>
      _i1.ColumnValue(
        table.classification,
        value,
      );

  _i1.ColumnValue<String, String> reporter(String value) => _i1.ColumnValue(
    table.reporter,
    value,
  );

  _i1.ColumnValue<String, String> productId(String? value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> affectedWorkItemId(String? value) =>
      _i1.ColumnValue(
        table.affectedWorkItemId,
        value,
      );

  _i1.ColumnValue<String, String> affectedRunId(String? value) =>
      _i1.ColumnValue(
        table.affectedRunId,
        value,
      );

  _i1.ColumnValue<String, String> remediationWorkItemId(String? value) =>
      _i1.ColumnValue(
        table.remediationWorkItemId,
        value,
      );

  _i1.ColumnValue<String, String> duplicateOfDefectId(String? value) =>
      _i1.ColumnValue(
        table.duplicateOfDefectId,
        value,
      );

  _i1.ColumnValue<String, String> currentTriageJobId(String? value) =>
      _i1.ColumnValue(
        table.currentTriageJobId,
        value,
      );

  _i1.ColumnValue<String, String> clientContextJson(String? value) =>
      _i1.ColumnValue(
        table.clientContextJson,
        value,
      );

  _i1.ColumnValue<String, String> metadataJson(String? value) =>
      _i1.ColumnValue(
        table.metadataJson,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> resolvedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.resolvedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> closedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.closedAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class DefectRowTable extends _i1.Table<int?> {
  DefectRowTable({super.tableRelation}) : super(tableName: 'defect') {
    updateTable = DefectRowUpdateTable(this);
    defectId = _i1.ColumnString(
      'defectId',
      this,
    );
    title = _i1.ColumnString(
      'title',
      this,
    );
    description = _i1.ColumnString(
      'description',
      this,
    );
    expectedBehavior = _i1.ColumnString(
      'expectedBehavior',
      this,
    );
    reproductionSteps = _i1.ColumnString(
      'reproductionSteps',
      this,
    );
    severity = _i1.ColumnString(
      'severity',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    classification = _i1.ColumnString(
      'classification',
      this,
    );
    reporter = _i1.ColumnString(
      'reporter',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    affectedWorkItemId = _i1.ColumnString(
      'affectedWorkItemId',
      this,
    );
    affectedRunId = _i1.ColumnString(
      'affectedRunId',
      this,
    );
    remediationWorkItemId = _i1.ColumnString(
      'remediationWorkItemId',
      this,
    );
    duplicateOfDefectId = _i1.ColumnString(
      'duplicateOfDefectId',
      this,
    );
    currentTriageJobId = _i1.ColumnString(
      'currentTriageJobId',
      this,
    );
    clientContextJson = _i1.ColumnString(
      'clientContextJson',
      this,
    );
    metadataJson = _i1.ColumnString(
      'metadataJson',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
    resolvedAt = _i1.ColumnDateTime(
      'resolvedAt',
      this,
    );
    closedAt = _i1.ColumnDateTime(
      'closedAt',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final DefectRowUpdateTable updateTable;

  late final _i1.ColumnString defectId;

  late final _i1.ColumnString title;

  late final _i1.ColumnString description;

  late final _i1.ColumnString expectedBehavior;

  late final _i1.ColumnString reproductionSteps;

  late final _i1.ColumnString severity;

  late final _i1.ColumnString status;

  late final _i1.ColumnString classification;

  late final _i1.ColumnString reporter;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString affectedWorkItemId;

  late final _i1.ColumnString affectedRunId;

  late final _i1.ColumnString remediationWorkItemId;

  late final _i1.ColumnString duplicateOfDefectId;

  late final _i1.ColumnString currentTriageJobId;

  late final _i1.ColumnString clientContextJson;

  late final _i1.ColumnString metadataJson;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnDateTime resolvedAt;

  late final _i1.ColumnDateTime closedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    defectId,
    title,
    description,
    expectedBehavior,
    reproductionSteps,
    severity,
    status,
    classification,
    reporter,
    productId,
    affectedWorkItemId,
    affectedRunId,
    remediationWorkItemId,
    duplicateOfDefectId,
    currentTriageJobId,
    clientContextJson,
    metadataJson,
    createdAt,
    updatedAt,
    resolvedAt,
    closedAt,
    version,
  ];
}

class DefectRowInclude extends _i1.IncludeObject {
  DefectRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DefectRow.t;
}

class DefectRowIncludeList extends _i1.IncludeList {
  DefectRowIncludeList._({
    _i1.WhereExpressionBuilder<DefectRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DefectRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DefectRow.t;
}

class DefectRowRepository {
  const DefectRowRepository._();

  /// Returns a list of [DefectRow]s matching the given query parameters.
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
  Future<List<DefectRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DefectRow>(
      where: where?.call(DefectRow.t),
      orderBy: orderBy?.call(DefectRow.t),
      orderByList: orderByList?.call(DefectRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DefectRow] matching the given query parameters.
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
  Future<DefectRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DefectRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DefectRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DefectRow>(
      where: where?.call(DefectRow.t),
      orderBy: orderBy?.call(DefectRow.t),
      orderByList: orderByList?.call(DefectRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DefectRow] by its [id] or null if no such row exists.
  Future<DefectRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DefectRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DefectRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DefectRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DefectRow>> insert(
    _i1.DatabaseSession session,
    List<DefectRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DefectRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DefectRow] and returns the inserted row.
  ///
  /// The returned [DefectRow] will have its `id` field set.
  Future<DefectRow> insertRow(
    _i1.DatabaseSession session,
    DefectRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DefectRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DefectRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DefectRow>> update(
    _i1.DatabaseSession session,
    List<DefectRow> rows, {
    _i1.ColumnSelections<DefectRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DefectRow>(
      rows,
      columns: columns?.call(DefectRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DefectRow> updateRow(
    _i1.DatabaseSession session,
    DefectRow row, {
    _i1.ColumnSelections<DefectRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DefectRow>(
      row,
      columns: columns?.call(DefectRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DefectRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DefectRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DefectRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DefectRow>(
      id,
      columnValues: columnValues(DefectRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DefectRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DefectRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DefectRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<DefectRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DefectRowTable>? orderBy,
    _i1.OrderByListBuilder<DefectRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DefectRow>(
      columnValues: columnValues(DefectRow.t.updateTable),
      where: where(DefectRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DefectRow.t),
      orderByList: orderByList?.call(DefectRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DefectRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DefectRow>> delete(
    _i1.DatabaseSession session,
    List<DefectRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DefectRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DefectRow].
  Future<DefectRow> deleteRow(
    _i1.DatabaseSession session,
    DefectRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DefectRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DefectRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DefectRow>(
      where: where(DefectRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DefectRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DefectRow>(
      where: where?.call(DefectRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DefectRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DefectRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DefectRow>(
      where: where(DefectRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

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

abstract class WorkItemRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  WorkItemRow._({
    this.id,
    required this.workItemId,
    required this.productId,
    required this.category,
    required this.title,
    this.description,
    required this.state,
    this.designContractId,
    this.agentSessionId,
    this.qaContractId,
    this.featureRef,
    this.requirementRef,
    this.blockingHumanDecisionId,
    this.blockingReason,
    this.artifactRefsJson,
    this.metadataJson,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.terminatedAt,
    required this.version,
  });

  factory WorkItemRow({
    int? id,
    required String workItemId,
    required String productId,
    required String category,
    required String title,
    String? description,
    required String state,
    String? designContractId,
    String? agentSessionId,
    String? qaContractId,
    String? featureRef,
    String? requirementRef,
    String? blockingHumanDecisionId,
    String? blockingReason,
    String? artifactRefsJson,
    String? metadataJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
    DateTime? terminatedAt,
    required int version,
  }) = _WorkItemRowImpl;

  factory WorkItemRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkItemRow(
      id: jsonSerialization['id'] as int?,
      workItemId: jsonSerialization['workItemId'] as String,
      productId: jsonSerialization['productId'] as String,
      category: jsonSerialization['category'] as String,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String?,
      state: jsonSerialization['state'] as String,
      designContractId: jsonSerialization['designContractId'] as String?,
      agentSessionId: jsonSerialization['agentSessionId'] as String?,
      qaContractId: jsonSerialization['qaContractId'] as String?,
      featureRef: jsonSerialization['featureRef'] as String?,
      requirementRef: jsonSerialization['requirementRef'] as String?,
      blockingHumanDecisionId:
          jsonSerialization['blockingHumanDecisionId'] as String?,
      blockingReason: jsonSerialization['blockingReason'] as String?,
      artifactRefsJson: jsonSerialization['artifactRefsJson'] as String?,
      metadataJson: jsonSerialization['metadataJson'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      terminatedAt: jsonSerialization['terminatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['terminatedAt'],
            ),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = WorkItemRowTable();

  static const db = WorkItemRowRepository._();

  @override
  int? id;

  String workItemId;

  String productId;

  String category;

  String title;

  String? description;

  String state;

  String? designContractId;

  String? agentSessionId;

  String? qaContractId;

  String? featureRef;

  String? requirementRef;

  String? blockingHumanDecisionId;

  String? blockingReason;

  String? artifactRefsJson;

  String? metadataJson;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? completedAt;

  DateTime? terminatedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [WorkItemRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemRow copyWith({
    int? id,
    String? workItemId,
    String? productId,
    String? category,
    String? title,
    String? description,
    String? state,
    String? designContractId,
    String? agentSessionId,
    String? qaContractId,
    String? featureRef,
    String? requirementRef,
    String? blockingHumanDecisionId,
    String? blockingReason,
    String? artifactRefsJson,
    String? metadataJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? terminatedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemRow',
      if (id != null) 'id': id,
      'workItemId': workItemId,
      'productId': productId,
      'category': category,
      'title': title,
      if (description != null) 'description': description,
      'state': state,
      if (designContractId != null) 'designContractId': designContractId,
      if (agentSessionId != null) 'agentSessionId': agentSessionId,
      if (qaContractId != null) 'qaContractId': qaContractId,
      if (featureRef != null) 'featureRef': featureRef,
      if (requirementRef != null) 'requirementRef': requirementRef,
      if (blockingHumanDecisionId != null)
        'blockingHumanDecisionId': blockingHumanDecisionId,
      if (blockingReason != null) 'blockingReason': blockingReason,
      if (artifactRefsJson != null) 'artifactRefsJson': artifactRefsJson,
      if (metadataJson != null) 'metadataJson': metadataJson,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (terminatedAt != null) 'terminatedAt': terminatedAt?.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WorkItemRowInclude include() {
    return WorkItemRowInclude._();
  }

  static WorkItemRowIncludeList includeList({
    _i1.WhereExpressionBuilder<WorkItemRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkItemRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkItemRowTable>? orderByList,
    WorkItemRowInclude? include,
  }) {
    return WorkItemRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkItemRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(WorkItemRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkItemRowImpl extends WorkItemRow {
  _WorkItemRowImpl({
    int? id,
    required String workItemId,
    required String productId,
    required String category,
    required String title,
    String? description,
    required String state,
    String? designContractId,
    String? agentSessionId,
    String? qaContractId,
    String? featureRef,
    String? requirementRef,
    String? blockingHumanDecisionId,
    String? blockingReason,
    String? artifactRefsJson,
    String? metadataJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
    DateTime? terminatedAt,
    required int version,
  }) : super._(
         id: id,
         workItemId: workItemId,
         productId: productId,
         category: category,
         title: title,
         description: description,
         state: state,
         designContractId: designContractId,
         agentSessionId: agentSessionId,
         qaContractId: qaContractId,
         featureRef: featureRef,
         requirementRef: requirementRef,
         blockingHumanDecisionId: blockingHumanDecisionId,
         blockingReason: blockingReason,
         artifactRefsJson: artifactRefsJson,
         metadataJson: metadataJson,
         createdAt: createdAt,
         updatedAt: updatedAt,
         completedAt: completedAt,
         terminatedAt: terminatedAt,
         version: version,
       );

  /// Returns a shallow copy of this [WorkItemRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemRow copyWith({
    Object? id = _Undefined,
    String? workItemId,
    String? productId,
    String? category,
    String? title,
    Object? description = _Undefined,
    String? state,
    Object? designContractId = _Undefined,
    Object? agentSessionId = _Undefined,
    Object? qaContractId = _Undefined,
    Object? featureRef = _Undefined,
    Object? requirementRef = _Undefined,
    Object? blockingHumanDecisionId = _Undefined,
    Object? blockingReason = _Undefined,
    Object? artifactRefsJson = _Undefined,
    Object? metadataJson = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _Undefined,
    Object? terminatedAt = _Undefined,
    int? version,
  }) {
    return WorkItemRow(
      id: id is int? ? id : this.id,
      workItemId: workItemId ?? this.workItemId,
      productId: productId ?? this.productId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description is String? ? description : this.description,
      state: state ?? this.state,
      designContractId: designContractId is String?
          ? designContractId
          : this.designContractId,
      agentSessionId: agentSessionId is String?
          ? agentSessionId
          : this.agentSessionId,
      qaContractId: qaContractId is String? ? qaContractId : this.qaContractId,
      featureRef: featureRef is String? ? featureRef : this.featureRef,
      requirementRef: requirementRef is String?
          ? requirementRef
          : this.requirementRef,
      blockingHumanDecisionId: blockingHumanDecisionId is String?
          ? blockingHumanDecisionId
          : this.blockingHumanDecisionId,
      blockingReason: blockingReason is String?
          ? blockingReason
          : this.blockingReason,
      artifactRefsJson: artifactRefsJson is String?
          ? artifactRefsJson
          : this.artifactRefsJson,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      terminatedAt: terminatedAt is DateTime?
          ? terminatedAt
          : this.terminatedAt,
      version: version ?? this.version,
    );
  }
}

class WorkItemRowUpdateTable extends _i1.UpdateTable<WorkItemRowTable> {
  WorkItemRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> category(String value) => _i1.ColumnValue(
    table.category,
    value,
  );

  _i1.ColumnValue<String, String> title(String value) => _i1.ColumnValue(
    table.title,
    value,
  );

  _i1.ColumnValue<String, String> description(String? value) => _i1.ColumnValue(
    table.description,
    value,
  );

  _i1.ColumnValue<String, String> state(String value) => _i1.ColumnValue(
    table.state,
    value,
  );

  _i1.ColumnValue<String, String> designContractId(String? value) =>
      _i1.ColumnValue(
        table.designContractId,
        value,
      );

  _i1.ColumnValue<String, String> agentSessionId(String? value) =>
      _i1.ColumnValue(
        table.agentSessionId,
        value,
      );

  _i1.ColumnValue<String, String> qaContractId(String? value) =>
      _i1.ColumnValue(
        table.qaContractId,
        value,
      );

  _i1.ColumnValue<String, String> featureRef(String? value) => _i1.ColumnValue(
    table.featureRef,
    value,
  );

  _i1.ColumnValue<String, String> requirementRef(String? value) =>
      _i1.ColumnValue(
        table.requirementRef,
        value,
      );

  _i1.ColumnValue<String, String> blockingHumanDecisionId(String? value) =>
      _i1.ColumnValue(
        table.blockingHumanDecisionId,
        value,
      );

  _i1.ColumnValue<String, String> blockingReason(String? value) =>
      _i1.ColumnValue(
        table.blockingReason,
        value,
      );

  _i1.ColumnValue<String, String> artifactRefsJson(String? value) =>
      _i1.ColumnValue(
        table.artifactRefsJson,
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

  _i1.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.completedAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> terminatedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.terminatedAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class WorkItemRowTable extends _i1.Table<int?> {
  WorkItemRowTable({super.tableRelation}) : super(tableName: 'work_item') {
    updateTable = WorkItemRowUpdateTable(this);
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    category = _i1.ColumnString(
      'category',
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
    state = _i1.ColumnString(
      'state',
      this,
    );
    designContractId = _i1.ColumnString(
      'designContractId',
      this,
    );
    agentSessionId = _i1.ColumnString(
      'agentSessionId',
      this,
    );
    qaContractId = _i1.ColumnString(
      'qaContractId',
      this,
    );
    featureRef = _i1.ColumnString(
      'featureRef',
      this,
    );
    requirementRef = _i1.ColumnString(
      'requirementRef',
      this,
    );
    blockingHumanDecisionId = _i1.ColumnString(
      'blockingHumanDecisionId',
      this,
    );
    blockingReason = _i1.ColumnString(
      'blockingReason',
      this,
    );
    artifactRefsJson = _i1.ColumnString(
      'artifactRefsJson',
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
    completedAt = _i1.ColumnDateTime(
      'completedAt',
      this,
    );
    terminatedAt = _i1.ColumnDateTime(
      'terminatedAt',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final WorkItemRowUpdateTable updateTable;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString category;

  late final _i1.ColumnString title;

  late final _i1.ColumnString description;

  late final _i1.ColumnString state;

  late final _i1.ColumnString designContractId;

  late final _i1.ColumnString agentSessionId;

  late final _i1.ColumnString qaContractId;

  late final _i1.ColumnString featureRef;

  late final _i1.ColumnString requirementRef;

  late final _i1.ColumnString blockingHumanDecisionId;

  late final _i1.ColumnString blockingReason;

  late final _i1.ColumnString artifactRefsJson;

  late final _i1.ColumnString metadataJson;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnDateTime completedAt;

  late final _i1.ColumnDateTime terminatedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    workItemId,
    productId,
    category,
    title,
    description,
    state,
    designContractId,
    agentSessionId,
    qaContractId,
    featureRef,
    requirementRef,
    blockingHumanDecisionId,
    blockingReason,
    artifactRefsJson,
    metadataJson,
    createdAt,
    updatedAt,
    completedAt,
    terminatedAt,
    version,
  ];
}

class WorkItemRowInclude extends _i1.IncludeObject {
  WorkItemRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => WorkItemRow.t;
}

class WorkItemRowIncludeList extends _i1.IncludeList {
  WorkItemRowIncludeList._({
    _i1.WhereExpressionBuilder<WorkItemRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WorkItemRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => WorkItemRow.t;
}

class WorkItemRowRepository {
  const WorkItemRowRepository._();

  /// Returns a list of [WorkItemRow]s matching the given query parameters.
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
  Future<List<WorkItemRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkItemRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkItemRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkItemRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WorkItemRow>(
      where: where?.call(WorkItemRow.t),
      orderBy: orderBy?.call(WorkItemRow.t),
      orderByList: orderByList?.call(WorkItemRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WorkItemRow] matching the given query parameters.
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
  Future<WorkItemRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkItemRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<WorkItemRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<WorkItemRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WorkItemRow>(
      where: where?.call(WorkItemRow.t),
      orderBy: orderBy?.call(WorkItemRow.t),
      orderByList: orderByList?.call(WorkItemRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WorkItemRow] by its [id] or null if no such row exists.
  Future<WorkItemRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WorkItemRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WorkItemRow]s in the list and returns the inserted rows.
  ///
  /// The returned [WorkItemRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<WorkItemRow>> insert(
    _i1.DatabaseSession session,
    List<WorkItemRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<WorkItemRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [WorkItemRow] and returns the inserted row.
  ///
  /// The returned [WorkItemRow] will have its `id` field set.
  Future<WorkItemRow> insertRow(
    _i1.DatabaseSession session,
    WorkItemRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<WorkItemRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [WorkItemRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<WorkItemRow>> update(
    _i1.DatabaseSession session,
    List<WorkItemRow> rows, {
    _i1.ColumnSelections<WorkItemRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<WorkItemRow>(
      rows,
      columns: columns?.call(WorkItemRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkItemRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WorkItemRow> updateRow(
    _i1.DatabaseSession session,
    WorkItemRow row, {
    _i1.ColumnSelections<WorkItemRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<WorkItemRow>(
      row,
      columns: columns?.call(WorkItemRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WorkItemRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WorkItemRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<WorkItemRowUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<WorkItemRow>(
      id,
      columnValues: columnValues(WorkItemRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WorkItemRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<WorkItemRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<WorkItemRowUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<WorkItemRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<WorkItemRowTable>? orderBy,
    _i1.OrderByListBuilder<WorkItemRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<WorkItemRow>(
      columnValues: columnValues(WorkItemRow.t.updateTable),
      where: where(WorkItemRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WorkItemRow.t),
      orderByList: orderByList?.call(WorkItemRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [WorkItemRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<WorkItemRow>> delete(
    _i1.DatabaseSession session,
    List<WorkItemRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<WorkItemRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [WorkItemRow].
  Future<WorkItemRow> deleteRow(
    _i1.DatabaseSession session,
    WorkItemRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WorkItemRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<WorkItemRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkItemRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<WorkItemRow>(
      where: where(WorkItemRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<WorkItemRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<WorkItemRow>(
      where: where?.call(WorkItemRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WorkItemRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<WorkItemRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WorkItemRow>(
      where: where(WorkItemRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

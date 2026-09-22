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

abstract class DesignRevisionRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  DesignRevisionRow._({
    this.id,
    required this.revisionId,
    required this.workItemId,
    required this.productId,
    this.parentRevisionId,
    required this.designSystemRevision,
    required this.providerType,
    this.penpotFileId,
    this.penpotPageId,
    required this.boardIdsJson,
    required this.responsiveTargetsJson,
    required this.statesRepresentedJson,
    required this.artifactRefsJson,
    required this.designerExecutionId,
    required this.reviewExecutionIdsJson,
    required this.status,
    required this.riskTier,
    this.reviewScopeJson,
    this.carriedForwardFromRevisionId,
    this.supersededByRevisionId,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    required this.version,
  });

  factory DesignRevisionRow({
    int? id,
    required String revisionId,
    required String workItemId,
    required String productId,
    String? parentRevisionId,
    required String designSystemRevision,
    required String providerType,
    String? penpotFileId,
    String? penpotPageId,
    required String boardIdsJson,
    required String responsiveTargetsJson,
    required String statesRepresentedJson,
    required String artifactRefsJson,
    required String designerExecutionId,
    required String reviewExecutionIdsJson,
    required String status,
    required String riskTier,
    String? reviewScopeJson,
    String? carriedForwardFromRevisionId,
    String? supersededByRevisionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? approvedAt,
    required int version,
  }) = _DesignRevisionRowImpl;

  factory DesignRevisionRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return DesignRevisionRow(
      id: jsonSerialization['id'] as int?,
      revisionId: jsonSerialization['revisionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      productId: jsonSerialization['productId'] as String,
      parentRevisionId: jsonSerialization['parentRevisionId'] as String?,
      designSystemRevision: jsonSerialization['designSystemRevision'] as String,
      providerType: jsonSerialization['providerType'] as String,
      penpotFileId: jsonSerialization['penpotFileId'] as String?,
      penpotPageId: jsonSerialization['penpotPageId'] as String?,
      boardIdsJson: jsonSerialization['boardIdsJson'] as String,
      responsiveTargetsJson:
          jsonSerialization['responsiveTargetsJson'] as String,
      statesRepresentedJson:
          jsonSerialization['statesRepresentedJson'] as String,
      artifactRefsJson: jsonSerialization['artifactRefsJson'] as String,
      designerExecutionId: jsonSerialization['designerExecutionId'] as String,
      reviewExecutionIdsJson:
          jsonSerialization['reviewExecutionIdsJson'] as String,
      status: jsonSerialization['status'] as String,
      riskTier: jsonSerialization['riskTier'] as String,
      reviewScopeJson: jsonSerialization['reviewScopeJson'] as String?,
      carriedForwardFromRevisionId:
          jsonSerialization['carriedForwardFromRevisionId'] as String?,
      supersededByRevisionId:
          jsonSerialization['supersededByRevisionId'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      approvedAt: jsonSerialization['approvedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['approvedAt']),
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = DesignRevisionRowTable();

  static const db = DesignRevisionRowRepository._();

  @override
  int? id;

  String revisionId;

  String workItemId;

  String productId;

  String? parentRevisionId;

  String designSystemRevision;

  String providerType;

  String? penpotFileId;

  String? penpotPageId;

  String boardIdsJson;

  String responsiveTargetsJson;

  String statesRepresentedJson;

  String artifactRefsJson;

  String designerExecutionId;

  String reviewExecutionIdsJson;

  String status;

  String riskTier;

  String? reviewScopeJson;

  String? carriedForwardFromRevisionId;

  String? supersededByRevisionId;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? approvedAt;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [DesignRevisionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DesignRevisionRow copyWith({
    int? id,
    String? revisionId,
    String? workItemId,
    String? productId,
    String? parentRevisionId,
    String? designSystemRevision,
    String? providerType,
    String? penpotFileId,
    String? penpotPageId,
    String? boardIdsJson,
    String? responsiveTargetsJson,
    String? statesRepresentedJson,
    String? artifactRefsJson,
    String? designerExecutionId,
    String? reviewExecutionIdsJson,
    String? status,
    String? riskTier,
    String? reviewScopeJson,
    String? carriedForwardFromRevisionId,
    String? supersededByRevisionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DesignRevisionRow',
      if (id != null) 'id': id,
      'revisionId': revisionId,
      'workItemId': workItemId,
      'productId': productId,
      if (parentRevisionId != null) 'parentRevisionId': parentRevisionId,
      'designSystemRevision': designSystemRevision,
      'providerType': providerType,
      if (penpotFileId != null) 'penpotFileId': penpotFileId,
      if (penpotPageId != null) 'penpotPageId': penpotPageId,
      'boardIdsJson': boardIdsJson,
      'responsiveTargetsJson': responsiveTargetsJson,
      'statesRepresentedJson': statesRepresentedJson,
      'artifactRefsJson': artifactRefsJson,
      'designerExecutionId': designerExecutionId,
      'reviewExecutionIdsJson': reviewExecutionIdsJson,
      'status': status,
      'riskTier': riskTier,
      if (reviewScopeJson != null) 'reviewScopeJson': reviewScopeJson,
      if (carriedForwardFromRevisionId != null)
        'carriedForwardFromRevisionId': carriedForwardFromRevisionId,
      if (supersededByRevisionId != null)
        'supersededByRevisionId': supersededByRevisionId,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (approvedAt != null) 'approvedAt': approvedAt?.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static DesignRevisionRowInclude include() {
    return DesignRevisionRowInclude._();
  }

  static DesignRevisionRowIncludeList includeList({
    _i1.WhereExpressionBuilder<DesignRevisionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignRevisionRowTable>? orderByList,
    DesignRevisionRowInclude? include,
  }) {
    return DesignRevisionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignRevisionRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(DesignRevisionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DesignRevisionRowImpl extends DesignRevisionRow {
  _DesignRevisionRowImpl({
    int? id,
    required String revisionId,
    required String workItemId,
    required String productId,
    String? parentRevisionId,
    required String designSystemRevision,
    required String providerType,
    String? penpotFileId,
    String? penpotPageId,
    required String boardIdsJson,
    required String responsiveTargetsJson,
    required String statesRepresentedJson,
    required String artifactRefsJson,
    required String designerExecutionId,
    required String reviewExecutionIdsJson,
    required String status,
    required String riskTier,
    String? reviewScopeJson,
    String? carriedForwardFromRevisionId,
    String? supersededByRevisionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? approvedAt,
    required int version,
  }) : super._(
         id: id,
         revisionId: revisionId,
         workItemId: workItemId,
         productId: productId,
         parentRevisionId: parentRevisionId,
         designSystemRevision: designSystemRevision,
         providerType: providerType,
         penpotFileId: penpotFileId,
         penpotPageId: penpotPageId,
         boardIdsJson: boardIdsJson,
         responsiveTargetsJson: responsiveTargetsJson,
         statesRepresentedJson: statesRepresentedJson,
         artifactRefsJson: artifactRefsJson,
         designerExecutionId: designerExecutionId,
         reviewExecutionIdsJson: reviewExecutionIdsJson,
         status: status,
         riskTier: riskTier,
         reviewScopeJson: reviewScopeJson,
         carriedForwardFromRevisionId: carriedForwardFromRevisionId,
         supersededByRevisionId: supersededByRevisionId,
         createdAt: createdAt,
         updatedAt: updatedAt,
         approvedAt: approvedAt,
         version: version,
       );

  /// Returns a shallow copy of this [DesignRevisionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DesignRevisionRow copyWith({
    Object? id = _Undefined,
    String? revisionId,
    String? workItemId,
    String? productId,
    Object? parentRevisionId = _Undefined,
    String? designSystemRevision,
    String? providerType,
    Object? penpotFileId = _Undefined,
    Object? penpotPageId = _Undefined,
    String? boardIdsJson,
    String? responsiveTargetsJson,
    String? statesRepresentedJson,
    String? artifactRefsJson,
    String? designerExecutionId,
    String? reviewExecutionIdsJson,
    String? status,
    String? riskTier,
    Object? reviewScopeJson = _Undefined,
    Object? carriedForwardFromRevisionId = _Undefined,
    Object? supersededByRevisionId = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? approvedAt = _Undefined,
    int? version,
  }) {
    return DesignRevisionRow(
      id: id is int? ? id : this.id,
      revisionId: revisionId ?? this.revisionId,
      workItemId: workItemId ?? this.workItemId,
      productId: productId ?? this.productId,
      parentRevisionId: parentRevisionId is String?
          ? parentRevisionId
          : this.parentRevisionId,
      designSystemRevision: designSystemRevision ?? this.designSystemRevision,
      providerType: providerType ?? this.providerType,
      penpotFileId: penpotFileId is String? ? penpotFileId : this.penpotFileId,
      penpotPageId: penpotPageId is String? ? penpotPageId : this.penpotPageId,
      boardIdsJson: boardIdsJson ?? this.boardIdsJson,
      responsiveTargetsJson:
          responsiveTargetsJson ?? this.responsiveTargetsJson,
      statesRepresentedJson:
          statesRepresentedJson ?? this.statesRepresentedJson,
      artifactRefsJson: artifactRefsJson ?? this.artifactRefsJson,
      designerExecutionId: designerExecutionId ?? this.designerExecutionId,
      reviewExecutionIdsJson:
          reviewExecutionIdsJson ?? this.reviewExecutionIdsJson,
      status: status ?? this.status,
      riskTier: riskTier ?? this.riskTier,
      reviewScopeJson: reviewScopeJson is String?
          ? reviewScopeJson
          : this.reviewScopeJson,
      carriedForwardFromRevisionId: carriedForwardFromRevisionId is String?
          ? carriedForwardFromRevisionId
          : this.carriedForwardFromRevisionId,
      supersededByRevisionId: supersededByRevisionId is String?
          ? supersededByRevisionId
          : this.supersededByRevisionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt is DateTime? ? approvedAt : this.approvedAt,
      version: version ?? this.version,
    );
  }
}

class DesignRevisionRowUpdateTable
    extends _i1.UpdateTable<DesignRevisionRowTable> {
  DesignRevisionRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> revisionId(String value) => _i1.ColumnValue(
    table.revisionId,
    value,
  );

  _i1.ColumnValue<String, String> workItemId(String value) => _i1.ColumnValue(
    table.workItemId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> parentRevisionId(String? value) =>
      _i1.ColumnValue(
        table.parentRevisionId,
        value,
      );

  _i1.ColumnValue<String, String> designSystemRevision(String value) =>
      _i1.ColumnValue(
        table.designSystemRevision,
        value,
      );

  _i1.ColumnValue<String, String> providerType(String value) => _i1.ColumnValue(
    table.providerType,
    value,
  );

  _i1.ColumnValue<String, String> penpotFileId(String? value) =>
      _i1.ColumnValue(
        table.penpotFileId,
        value,
      );

  _i1.ColumnValue<String, String> penpotPageId(String? value) =>
      _i1.ColumnValue(
        table.penpotPageId,
        value,
      );

  _i1.ColumnValue<String, String> boardIdsJson(String value) => _i1.ColumnValue(
    table.boardIdsJson,
    value,
  );

  _i1.ColumnValue<String, String> responsiveTargetsJson(String value) =>
      _i1.ColumnValue(
        table.responsiveTargetsJson,
        value,
      );

  _i1.ColumnValue<String, String> statesRepresentedJson(String value) =>
      _i1.ColumnValue(
        table.statesRepresentedJson,
        value,
      );

  _i1.ColumnValue<String, String> artifactRefsJson(String value) =>
      _i1.ColumnValue(
        table.artifactRefsJson,
        value,
      );

  _i1.ColumnValue<String, String> designerExecutionId(String value) =>
      _i1.ColumnValue(
        table.designerExecutionId,
        value,
      );

  _i1.ColumnValue<String, String> reviewExecutionIdsJson(String value) =>
      _i1.ColumnValue(
        table.reviewExecutionIdsJson,
        value,
      );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> riskTier(String value) => _i1.ColumnValue(
    table.riskTier,
    value,
  );

  _i1.ColumnValue<String, String> reviewScopeJson(String? value) =>
      _i1.ColumnValue(
        table.reviewScopeJson,
        value,
      );

  _i1.ColumnValue<String, String> carriedForwardFromRevisionId(String? value) =>
      _i1.ColumnValue(
        table.carriedForwardFromRevisionId,
        value,
      );

  _i1.ColumnValue<String, String> supersededByRevisionId(String? value) =>
      _i1.ColumnValue(
        table.supersededByRevisionId,
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

  _i1.ColumnValue<DateTime, DateTime> approvedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.approvedAt,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class DesignRevisionRowTable extends _i1.Table<int?> {
  DesignRevisionRowTable({super.tableRelation})
    : super(tableName: 'design_revision') {
    updateTable = DesignRevisionRowUpdateTable(this);
    revisionId = _i1.ColumnString(
      'revisionId',
      this,
    );
    workItemId = _i1.ColumnString(
      'workItemId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    parentRevisionId = _i1.ColumnString(
      'parentRevisionId',
      this,
    );
    designSystemRevision = _i1.ColumnString(
      'designSystemRevision',
      this,
    );
    providerType = _i1.ColumnString(
      'providerType',
      this,
    );
    penpotFileId = _i1.ColumnString(
      'penpotFileId',
      this,
    );
    penpotPageId = _i1.ColumnString(
      'penpotPageId',
      this,
    );
    boardIdsJson = _i1.ColumnString(
      'boardIdsJson',
      this,
    );
    responsiveTargetsJson = _i1.ColumnString(
      'responsiveTargetsJson',
      this,
    );
    statesRepresentedJson = _i1.ColumnString(
      'statesRepresentedJson',
      this,
    );
    artifactRefsJson = _i1.ColumnString(
      'artifactRefsJson',
      this,
    );
    designerExecutionId = _i1.ColumnString(
      'designerExecutionId',
      this,
    );
    reviewExecutionIdsJson = _i1.ColumnString(
      'reviewExecutionIdsJson',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    riskTier = _i1.ColumnString(
      'riskTier',
      this,
    );
    reviewScopeJson = _i1.ColumnString(
      'reviewScopeJson',
      this,
    );
    carriedForwardFromRevisionId = _i1.ColumnString(
      'carriedForwardFromRevisionId',
      this,
    );
    supersededByRevisionId = _i1.ColumnString(
      'supersededByRevisionId',
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
    approvedAt = _i1.ColumnDateTime(
      'approvedAt',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final DesignRevisionRowUpdateTable updateTable;

  late final _i1.ColumnString revisionId;

  late final _i1.ColumnString workItemId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString parentRevisionId;

  late final _i1.ColumnString designSystemRevision;

  late final _i1.ColumnString providerType;

  late final _i1.ColumnString penpotFileId;

  late final _i1.ColumnString penpotPageId;

  late final _i1.ColumnString boardIdsJson;

  late final _i1.ColumnString responsiveTargetsJson;

  late final _i1.ColumnString statesRepresentedJson;

  late final _i1.ColumnString artifactRefsJson;

  late final _i1.ColumnString designerExecutionId;

  late final _i1.ColumnString reviewExecutionIdsJson;

  late final _i1.ColumnString status;

  late final _i1.ColumnString riskTier;

  late final _i1.ColumnString reviewScopeJson;

  late final _i1.ColumnString carriedForwardFromRevisionId;

  late final _i1.ColumnString supersededByRevisionId;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnDateTime approvedAt;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    revisionId,
    workItemId,
    productId,
    parentRevisionId,
    designSystemRevision,
    providerType,
    penpotFileId,
    penpotPageId,
    boardIdsJson,
    responsiveTargetsJson,
    statesRepresentedJson,
    artifactRefsJson,
    designerExecutionId,
    reviewExecutionIdsJson,
    status,
    riskTier,
    reviewScopeJson,
    carriedForwardFromRevisionId,
    supersededByRevisionId,
    createdAt,
    updatedAt,
    approvedAt,
    version,
  ];
}

class DesignRevisionRowInclude extends _i1.IncludeObject {
  DesignRevisionRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => DesignRevisionRow.t;
}

class DesignRevisionRowIncludeList extends _i1.IncludeList {
  DesignRevisionRowIncludeList._({
    _i1.WhereExpressionBuilder<DesignRevisionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DesignRevisionRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => DesignRevisionRow.t;
}

class DesignRevisionRowRepository {
  const DesignRevisionRowRepository._();

  /// Returns a list of [DesignRevisionRow]s matching the given query parameters.
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
  Future<List<DesignRevisionRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignRevisionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignRevisionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DesignRevisionRow>(
      where: where?.call(DesignRevisionRow.t),
      orderBy: orderBy?.call(DesignRevisionRow.t),
      orderByList: orderByList?.call(DesignRevisionRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DesignRevisionRow] matching the given query parameters.
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
  Future<DesignRevisionRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignRevisionRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<DesignRevisionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DesignRevisionRow>(
      where: where?.call(DesignRevisionRow.t),
      orderBy: orderBy?.call(DesignRevisionRow.t),
      orderByList: orderByList?.call(DesignRevisionRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DesignRevisionRow] by its [id] or null if no such row exists.
  Future<DesignRevisionRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DesignRevisionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DesignRevisionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [DesignRevisionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<DesignRevisionRow>> insert(
    _i1.DatabaseSession session,
    List<DesignRevisionRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<DesignRevisionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [DesignRevisionRow] and returns the inserted row.
  ///
  /// The returned [DesignRevisionRow] will have its `id` field set.
  Future<DesignRevisionRow> insertRow(
    _i1.DatabaseSession session,
    DesignRevisionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<DesignRevisionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [DesignRevisionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<DesignRevisionRow>> update(
    _i1.DatabaseSession session,
    List<DesignRevisionRow> rows, {
    _i1.ColumnSelections<DesignRevisionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<DesignRevisionRow>(
      rows,
      columns: columns?.call(DesignRevisionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignRevisionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DesignRevisionRow> updateRow(
    _i1.DatabaseSession session,
    DesignRevisionRow row, {
    _i1.ColumnSelections<DesignRevisionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<DesignRevisionRow>(
      row,
      columns: columns?.call(DesignRevisionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DesignRevisionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DesignRevisionRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<DesignRevisionRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<DesignRevisionRow>(
      id,
      columnValues: columnValues(DesignRevisionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DesignRevisionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<DesignRevisionRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<DesignRevisionRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<DesignRevisionRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<DesignRevisionRowTable>? orderBy,
    _i1.OrderByListBuilder<DesignRevisionRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<DesignRevisionRow>(
      columnValues: columnValues(DesignRevisionRow.t.updateTable),
      where: where(DesignRevisionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DesignRevisionRow.t),
      orderByList: orderByList?.call(DesignRevisionRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [DesignRevisionRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<DesignRevisionRow>> delete(
    _i1.DatabaseSession session,
    List<DesignRevisionRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<DesignRevisionRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [DesignRevisionRow].
  Future<DesignRevisionRow> deleteRow(
    _i1.DatabaseSession session,
    DesignRevisionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DesignRevisionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<DesignRevisionRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignRevisionRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<DesignRevisionRow>(
      where: where(DesignRevisionRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<DesignRevisionRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<DesignRevisionRow>(
      where: where?.call(DesignRevisionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DesignRevisionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<DesignRevisionRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DesignRevisionRow>(
      where: where(DesignRevisionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

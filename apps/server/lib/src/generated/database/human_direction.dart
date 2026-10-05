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

abstract class HumanDirectionRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  HumanDirectionRow._({
    this.id,
    required this.directionId,
    required this.directionType,
    required this.targetType,
    this.targetId,
    required this.status,
    required this.payloadJson,
    this.createdBy,
    this.assignedTo,
    this.ackedAt,
    this.ackedBy,
    this.startedAt,
    this.startedBy,
    this.completedAt,
    this.completedBy,
    this.completionSummary,
    this.rejectedAt,
    this.rejectedBy,
    this.rejectionReason,
    this.supersededAt,
    this.supersededByDirectionId,
    required this.createdAt,
    required this.updatedAt,
    this.metadataJson,
  });

  factory HumanDirectionRow({
    int? id,
    required String directionId,
    required String directionType,
    required String targetType,
    String? targetId,
    required String status,
    required String payloadJson,
    String? createdBy,
    String? assignedTo,
    DateTime? ackedAt,
    String? ackedBy,
    DateTime? startedAt,
    String? startedBy,
    DateTime? completedAt,
    String? completedBy,
    String? completionSummary,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? supersededAt,
    String? supersededByDirectionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? metadataJson,
  }) = _HumanDirectionRowImpl;

  factory HumanDirectionRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return HumanDirectionRow(
      id: jsonSerialization['id'] as int?,
      directionId: jsonSerialization['directionId'] as String,
      directionType: jsonSerialization['directionType'] as String,
      targetType: jsonSerialization['targetType'] as String,
      targetId: jsonSerialization['targetId'] as String?,
      status: jsonSerialization['status'] as String,
      payloadJson: jsonSerialization['payloadJson'] as String,
      createdBy: jsonSerialization['createdBy'] as String?,
      assignedTo: jsonSerialization['assignedTo'] as String?,
      ackedAt: jsonSerialization['ackedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['ackedAt']),
      ackedBy: jsonSerialization['ackedBy'] as String?,
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      startedBy: jsonSerialization['startedBy'] as String?,
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      completedBy: jsonSerialization['completedBy'] as String?,
      completionSummary: jsonSerialization['completionSummary'] as String?,
      rejectedAt: jsonSerialization['rejectedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['rejectedAt']),
      rejectedBy: jsonSerialization['rejectedBy'] as String?,
      rejectionReason: jsonSerialization['rejectionReason'] as String?,
      supersededAt: jsonSerialization['supersededAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['supersededAt'],
            ),
      supersededByDirectionId:
          jsonSerialization['supersededByDirectionId'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      metadataJson: jsonSerialization['metadataJson'] as String?,
    );
  }

  static final t = HumanDirectionRowTable();

  static const db = HumanDirectionRowRepository._();

  @override
  int? id;

  String directionId;

  String directionType;

  String targetType;

  String? targetId;

  String status;

  String payloadJson;

  String? createdBy;

  String? assignedTo;

  DateTime? ackedAt;

  String? ackedBy;

  DateTime? startedAt;

  String? startedBy;

  DateTime? completedAt;

  String? completedBy;

  String? completionSummary;

  DateTime? rejectedAt;

  String? rejectedBy;

  String? rejectionReason;

  DateTime? supersededAt;

  String? supersededByDirectionId;

  DateTime createdAt;

  DateTime updatedAt;

  String? metadataJson;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [HumanDirectionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  HumanDirectionRow copyWith({
    int? id,
    String? directionId,
    String? directionType,
    String? targetType,
    String? targetId,
    String? status,
    String? payloadJson,
    String? createdBy,
    String? assignedTo,
    DateTime? ackedAt,
    String? ackedBy,
    DateTime? startedAt,
    String? startedBy,
    DateTime? completedAt,
    String? completedBy,
    String? completionSummary,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? supersededAt,
    String? supersededByDirectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? metadataJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HumanDirectionRow',
      if (id != null) 'id': id,
      'directionId': directionId,
      'directionType': directionType,
      'targetType': targetType,
      if (targetId != null) 'targetId': targetId,
      'status': status,
      'payloadJson': payloadJson,
      if (createdBy != null) 'createdBy': createdBy,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (ackedAt != null) 'ackedAt': ackedAt?.toJson(),
      if (ackedBy != null) 'ackedBy': ackedBy,
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (startedBy != null) 'startedBy': startedBy,
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (completedBy != null) 'completedBy': completedBy,
      if (completionSummary != null) 'completionSummary': completionSummary,
      if (rejectedAt != null) 'rejectedAt': rejectedAt?.toJson(),
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (supersededAt != null) 'supersededAt': supersededAt?.toJson(),
      if (supersededByDirectionId != null)
        'supersededByDirectionId': supersededByDirectionId,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (metadataJson != null) 'metadataJson': metadataJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static HumanDirectionRowInclude include() {
    return HumanDirectionRowInclude._();
  }

  static HumanDirectionRowIncludeList includeList({
    _i1.WhereExpressionBuilder<HumanDirectionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HumanDirectionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HumanDirectionRowTable>? orderByList,
    HumanDirectionRowInclude? include,
  }) {
    return HumanDirectionRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HumanDirectionRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(HumanDirectionRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HumanDirectionRowImpl extends HumanDirectionRow {
  _HumanDirectionRowImpl({
    int? id,
    required String directionId,
    required String directionType,
    required String targetType,
    String? targetId,
    required String status,
    required String payloadJson,
    String? createdBy,
    String? assignedTo,
    DateTime? ackedAt,
    String? ackedBy,
    DateTime? startedAt,
    String? startedBy,
    DateTime? completedAt,
    String? completedBy,
    String? completionSummary,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? supersededAt,
    String? supersededByDirectionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? metadataJson,
  }) : super._(
         id: id,
         directionId: directionId,
         directionType: directionType,
         targetType: targetType,
         targetId: targetId,
         status: status,
         payloadJson: payloadJson,
         createdBy: createdBy,
         assignedTo: assignedTo,
         ackedAt: ackedAt,
         ackedBy: ackedBy,
         startedAt: startedAt,
         startedBy: startedBy,
         completedAt: completedAt,
         completedBy: completedBy,
         completionSummary: completionSummary,
         rejectedAt: rejectedAt,
         rejectedBy: rejectedBy,
         rejectionReason: rejectionReason,
         supersededAt: supersededAt,
         supersededByDirectionId: supersededByDirectionId,
         createdAt: createdAt,
         updatedAt: updatedAt,
         metadataJson: metadataJson,
       );

  /// Returns a shallow copy of this [HumanDirectionRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  HumanDirectionRow copyWith({
    Object? id = _Undefined,
    String? directionId,
    String? directionType,
    String? targetType,
    Object? targetId = _Undefined,
    String? status,
    String? payloadJson,
    Object? createdBy = _Undefined,
    Object? assignedTo = _Undefined,
    Object? ackedAt = _Undefined,
    Object? ackedBy = _Undefined,
    Object? startedAt = _Undefined,
    Object? startedBy = _Undefined,
    Object? completedAt = _Undefined,
    Object? completedBy = _Undefined,
    Object? completionSummary = _Undefined,
    Object? rejectedAt = _Undefined,
    Object? rejectedBy = _Undefined,
    Object? rejectionReason = _Undefined,
    Object? supersededAt = _Undefined,
    Object? supersededByDirectionId = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? metadataJson = _Undefined,
  }) {
    return HumanDirectionRow(
      id: id is int? ? id : this.id,
      directionId: directionId ?? this.directionId,
      directionType: directionType ?? this.directionType,
      targetType: targetType ?? this.targetType,
      targetId: targetId is String? ? targetId : this.targetId,
      status: status ?? this.status,
      payloadJson: payloadJson ?? this.payloadJson,
      createdBy: createdBy is String? ? createdBy : this.createdBy,
      assignedTo: assignedTo is String? ? assignedTo : this.assignedTo,
      ackedAt: ackedAt is DateTime? ? ackedAt : this.ackedAt,
      ackedBy: ackedBy is String? ? ackedBy : this.ackedBy,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      startedBy: startedBy is String? ? startedBy : this.startedBy,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      completedBy: completedBy is String? ? completedBy : this.completedBy,
      completionSummary: completionSummary is String?
          ? completionSummary
          : this.completionSummary,
      rejectedAt: rejectedAt is DateTime? ? rejectedAt : this.rejectedAt,
      rejectedBy: rejectedBy is String? ? rejectedBy : this.rejectedBy,
      rejectionReason: rejectionReason is String?
          ? rejectionReason
          : this.rejectionReason,
      supersededAt: supersededAt is DateTime?
          ? supersededAt
          : this.supersededAt,
      supersededByDirectionId: supersededByDirectionId is String?
          ? supersededByDirectionId
          : this.supersededByDirectionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
    );
  }
}

class HumanDirectionRowUpdateTable
    extends _i1.UpdateTable<HumanDirectionRowTable> {
  HumanDirectionRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> directionId(String value) => _i1.ColumnValue(
    table.directionId,
    value,
  );

  _i1.ColumnValue<String, String> directionType(String value) =>
      _i1.ColumnValue(
        table.directionType,
        value,
      );

  _i1.ColumnValue<String, String> targetType(String value) => _i1.ColumnValue(
    table.targetType,
    value,
  );

  _i1.ColumnValue<String, String> targetId(String? value) => _i1.ColumnValue(
    table.targetId,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<String, String> payloadJson(String value) => _i1.ColumnValue(
    table.payloadJson,
    value,
  );

  _i1.ColumnValue<String, String> createdBy(String? value) => _i1.ColumnValue(
    table.createdBy,
    value,
  );

  _i1.ColumnValue<String, String> assignedTo(String? value) => _i1.ColumnValue(
    table.assignedTo,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> ackedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.ackedAt,
        value,
      );

  _i1.ColumnValue<String, String> ackedBy(String? value) => _i1.ColumnValue(
    table.ackedBy,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> startedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.startedAt,
        value,
      );

  _i1.ColumnValue<String, String> startedBy(String? value) => _i1.ColumnValue(
    table.startedBy,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> completedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.completedAt,
        value,
      );

  _i1.ColumnValue<String, String> completedBy(String? value) => _i1.ColumnValue(
    table.completedBy,
    value,
  );

  _i1.ColumnValue<String, String> completionSummary(String? value) =>
      _i1.ColumnValue(
        table.completionSummary,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> rejectedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.rejectedAt,
        value,
      );

  _i1.ColumnValue<String, String> rejectedBy(String? value) => _i1.ColumnValue(
    table.rejectedBy,
    value,
  );

  _i1.ColumnValue<String, String> rejectionReason(String? value) =>
      _i1.ColumnValue(
        table.rejectionReason,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> supersededAt(DateTime? value) =>
      _i1.ColumnValue(
        table.supersededAt,
        value,
      );

  _i1.ColumnValue<String, String> supersededByDirectionId(String? value) =>
      _i1.ColumnValue(
        table.supersededByDirectionId,
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

  _i1.ColumnValue<String, String> metadataJson(String? value) =>
      _i1.ColumnValue(
        table.metadataJson,
        value,
      );
}

class HumanDirectionRowTable extends _i1.Table<int?> {
  HumanDirectionRowTable({super.tableRelation})
    : super(tableName: 'human_direction') {
    updateTable = HumanDirectionRowUpdateTable(this);
    directionId = _i1.ColumnString(
      'directionId',
      this,
    );
    directionType = _i1.ColumnString(
      'directionType',
      this,
    );
    targetType = _i1.ColumnString(
      'targetType',
      this,
    );
    targetId = _i1.ColumnString(
      'targetId',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    payloadJson = _i1.ColumnString(
      'payloadJson',
      this,
    );
    createdBy = _i1.ColumnString(
      'createdBy',
      this,
    );
    assignedTo = _i1.ColumnString(
      'assignedTo',
      this,
    );
    ackedAt = _i1.ColumnDateTime(
      'ackedAt',
      this,
    );
    ackedBy = _i1.ColumnString(
      'ackedBy',
      this,
    );
    startedAt = _i1.ColumnDateTime(
      'startedAt',
      this,
    );
    startedBy = _i1.ColumnString(
      'startedBy',
      this,
    );
    completedAt = _i1.ColumnDateTime(
      'completedAt',
      this,
    );
    completedBy = _i1.ColumnString(
      'completedBy',
      this,
    );
    completionSummary = _i1.ColumnString(
      'completionSummary',
      this,
    );
    rejectedAt = _i1.ColumnDateTime(
      'rejectedAt',
      this,
    );
    rejectedBy = _i1.ColumnString(
      'rejectedBy',
      this,
    );
    rejectionReason = _i1.ColumnString(
      'rejectionReason',
      this,
    );
    supersededAt = _i1.ColumnDateTime(
      'supersededAt',
      this,
    );
    supersededByDirectionId = _i1.ColumnString(
      'supersededByDirectionId',
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
    metadataJson = _i1.ColumnString(
      'metadataJson',
      this,
    );
  }

  late final HumanDirectionRowUpdateTable updateTable;

  late final _i1.ColumnString directionId;

  late final _i1.ColumnString directionType;

  late final _i1.ColumnString targetType;

  late final _i1.ColumnString targetId;

  late final _i1.ColumnString status;

  late final _i1.ColumnString payloadJson;

  late final _i1.ColumnString createdBy;

  late final _i1.ColumnString assignedTo;

  late final _i1.ColumnDateTime ackedAt;

  late final _i1.ColumnString ackedBy;

  late final _i1.ColumnDateTime startedAt;

  late final _i1.ColumnString startedBy;

  late final _i1.ColumnDateTime completedAt;

  late final _i1.ColumnString completedBy;

  late final _i1.ColumnString completionSummary;

  late final _i1.ColumnDateTime rejectedAt;

  late final _i1.ColumnString rejectedBy;

  late final _i1.ColumnString rejectionReason;

  late final _i1.ColumnDateTime supersededAt;

  late final _i1.ColumnString supersededByDirectionId;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime updatedAt;

  late final _i1.ColumnString metadataJson;

  @override
  List<_i1.Column> get columns => [
    id,
    directionId,
    directionType,
    targetType,
    targetId,
    status,
    payloadJson,
    createdBy,
    assignedTo,
    ackedAt,
    ackedBy,
    startedAt,
    startedBy,
    completedAt,
    completedBy,
    completionSummary,
    rejectedAt,
    rejectedBy,
    rejectionReason,
    supersededAt,
    supersededByDirectionId,
    createdAt,
    updatedAt,
    metadataJson,
  ];
}

class HumanDirectionRowInclude extends _i1.IncludeObject {
  HumanDirectionRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => HumanDirectionRow.t;
}

class HumanDirectionRowIncludeList extends _i1.IncludeList {
  HumanDirectionRowIncludeList._({
    _i1.WhereExpressionBuilder<HumanDirectionRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HumanDirectionRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => HumanDirectionRow.t;
}

class HumanDirectionRowRepository {
  const HumanDirectionRowRepository._();

  /// Returns a list of [HumanDirectionRow]s matching the given query parameters.
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
  Future<List<HumanDirectionRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HumanDirectionRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HumanDirectionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HumanDirectionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HumanDirectionRow>(
      where: where?.call(HumanDirectionRow.t),
      orderBy: orderBy?.call(HumanDirectionRow.t),
      orderByList: orderByList?.call(HumanDirectionRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [HumanDirectionRow] matching the given query parameters.
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
  Future<HumanDirectionRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HumanDirectionRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<HumanDirectionRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HumanDirectionRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HumanDirectionRow>(
      where: where?.call(HumanDirectionRow.t),
      orderBy: orderBy?.call(HumanDirectionRow.t),
      orderByList: orderByList?.call(HumanDirectionRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HumanDirectionRow] by its [id] or null if no such row exists.
  Future<HumanDirectionRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<HumanDirectionRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [HumanDirectionRow]s in the list and returns the inserted rows.
  ///
  /// The returned [HumanDirectionRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<HumanDirectionRow>> insert(
    _i1.DatabaseSession session,
    List<HumanDirectionRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<HumanDirectionRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [HumanDirectionRow] and returns the inserted row.
  ///
  /// The returned [HumanDirectionRow] will have its `id` field set.
  Future<HumanDirectionRow> insertRow(
    _i1.DatabaseSession session,
    HumanDirectionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<HumanDirectionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [HumanDirectionRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<HumanDirectionRow>> update(
    _i1.DatabaseSession session,
    List<HumanDirectionRow> rows, {
    _i1.ColumnSelections<HumanDirectionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<HumanDirectionRow>(
      rows,
      columns: columns?.call(HumanDirectionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HumanDirectionRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HumanDirectionRow> updateRow(
    _i1.DatabaseSession session,
    HumanDirectionRow row, {
    _i1.ColumnSelections<HumanDirectionRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<HumanDirectionRow>(
      row,
      columns: columns?.call(HumanDirectionRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HumanDirectionRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<HumanDirectionRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<HumanDirectionRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<HumanDirectionRow>(
      id,
      columnValues: columnValues(HumanDirectionRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HumanDirectionRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<HumanDirectionRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<HumanDirectionRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<HumanDirectionRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HumanDirectionRowTable>? orderBy,
    _i1.OrderByListBuilder<HumanDirectionRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<HumanDirectionRow>(
      columnValues: columnValues(HumanDirectionRow.t.updateTable),
      where: where(HumanDirectionRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HumanDirectionRow.t),
      orderByList: orderByList?.call(HumanDirectionRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [HumanDirectionRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<HumanDirectionRow>> delete(
    _i1.DatabaseSession session,
    List<HumanDirectionRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<HumanDirectionRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [HumanDirectionRow].
  Future<HumanDirectionRow> deleteRow(
    _i1.DatabaseSession session,
    HumanDirectionRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HumanDirectionRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<HumanDirectionRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HumanDirectionRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<HumanDirectionRow>(
      where: where(HumanDirectionRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HumanDirectionRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<HumanDirectionRow>(
      where: where?.call(HumanDirectionRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HumanDirectionRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HumanDirectionRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HumanDirectionRow>(
      where: where(HumanDirectionRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

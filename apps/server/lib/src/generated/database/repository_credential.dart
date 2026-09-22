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

abstract class RepositoryCredentialRow
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  RepositoryCredentialRow._({
    this.id,
    required this.credentialId,
    required this.productId,
    required this.repositoryId,
    required this.referenceName,
    required this.publicKey,
    required this.fingerprint,
    required this.algorithm,
    required this.status,
    required this.createdAt,
    this.lastVerifiedAt,
    this.lastVerifiedBy,
    this.lastFailureReason,
    required this.hostKeyStatus,
    this.host,
    this.hostKeyFingerprint,
    this.hostConfirmedAt,
    this.hostConfirmedBy,
    this.revokedAt,
    this.revokedReason,
    this.supersedesCredentialId,
    required this.version,
  });

  factory RepositoryCredentialRow({
    int? id,
    required String credentialId,
    required String productId,
    required String repositoryId,
    required String referenceName,
    required String publicKey,
    required String fingerprint,
    required String algorithm,
    required String status,
    required DateTime createdAt,
    DateTime? lastVerifiedAt,
    String? lastVerifiedBy,
    String? lastFailureReason,
    required String hostKeyStatus,
    String? host,
    String? hostKeyFingerprint,
    DateTime? hostConfirmedAt,
    String? hostConfirmedBy,
    DateTime? revokedAt,
    String? revokedReason,
    String? supersedesCredentialId,
    required int version,
  }) = _RepositoryCredentialRowImpl;

  factory RepositoryCredentialRow.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RepositoryCredentialRow(
      id: jsonSerialization['id'] as int?,
      credentialId: jsonSerialization['credentialId'] as String,
      productId: jsonSerialization['productId'] as String,
      repositoryId: jsonSerialization['repositoryId'] as String,
      referenceName: jsonSerialization['referenceName'] as String,
      publicKey: jsonSerialization['publicKey'] as String,
      fingerprint: jsonSerialization['fingerprint'] as String,
      algorithm: jsonSerialization['algorithm'] as String,
      status: jsonSerialization['status'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      lastVerifiedAt: jsonSerialization['lastVerifiedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastVerifiedAt'],
            ),
      lastVerifiedBy: jsonSerialization['lastVerifiedBy'] as String?,
      lastFailureReason: jsonSerialization['lastFailureReason'] as String?,
      hostKeyStatus: jsonSerialization['hostKeyStatus'] as String,
      host: jsonSerialization['host'] as String?,
      hostKeyFingerprint: jsonSerialization['hostKeyFingerprint'] as String?,
      hostConfirmedAt: jsonSerialization['hostConfirmedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['hostConfirmedAt'],
            ),
      hostConfirmedBy: jsonSerialization['hostConfirmedBy'] as String?,
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
      revokedReason: jsonSerialization['revokedReason'] as String?,
      supersedesCredentialId:
          jsonSerialization['supersedesCredentialId'] as String?,
      version: jsonSerialization['version'] as int,
    );
  }

  static final t = RepositoryCredentialRowTable();

  static const db = RepositoryCredentialRowRepository._();

  @override
  int? id;

  String credentialId;

  String productId;

  String repositoryId;

  String referenceName;

  String publicKey;

  String fingerprint;

  String algorithm;

  String status;

  DateTime createdAt;

  DateTime? lastVerifiedAt;

  String? lastVerifiedBy;

  String? lastFailureReason;

  String hostKeyStatus;

  String? host;

  String? hostKeyFingerprint;

  DateTime? hostConfirmedAt;

  String? hostConfirmedBy;

  DateTime? revokedAt;

  String? revokedReason;

  String? supersedesCredentialId;

  int version;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [RepositoryCredentialRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RepositoryCredentialRow copyWith({
    int? id,
    String? credentialId,
    String? productId,
    String? repositoryId,
    String? referenceName,
    String? publicKey,
    String? fingerprint,
    String? algorithm,
    String? status,
    DateTime? createdAt,
    DateTime? lastVerifiedAt,
    String? lastVerifiedBy,
    String? lastFailureReason,
    String? hostKeyStatus,
    String? host,
    String? hostKeyFingerprint,
    DateTime? hostConfirmedAt,
    String? hostConfirmedBy,
    DateTime? revokedAt,
    String? revokedReason,
    String? supersedesCredentialId,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RepositoryCredentialRow',
      if (id != null) 'id': id,
      'credentialId': credentialId,
      'productId': productId,
      'repositoryId': repositoryId,
      'referenceName': referenceName,
      'publicKey': publicKey,
      'fingerprint': fingerprint,
      'algorithm': algorithm,
      'status': status,
      'createdAt': createdAt.toJson(),
      if (lastVerifiedAt != null) 'lastVerifiedAt': lastVerifiedAt?.toJson(),
      if (lastVerifiedBy != null) 'lastVerifiedBy': lastVerifiedBy,
      if (lastFailureReason != null) 'lastFailureReason': lastFailureReason,
      'hostKeyStatus': hostKeyStatus,
      if (host != null) 'host': host,
      if (hostKeyFingerprint != null) 'hostKeyFingerprint': hostKeyFingerprint,
      if (hostConfirmedAt != null) 'hostConfirmedAt': hostConfirmedAt?.toJson(),
      if (hostConfirmedBy != null) 'hostConfirmedBy': hostConfirmedBy,
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
      if (revokedReason != null) 'revokedReason': revokedReason,
      if (supersedesCredentialId != null)
        'supersedesCredentialId': supersedesCredentialId,
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static RepositoryCredentialRowInclude include() {
    return RepositoryCredentialRowInclude._();
  }

  static RepositoryCredentialRowIncludeList includeList({
    _i1.WhereExpressionBuilder<RepositoryCredentialRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RepositoryCredentialRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RepositoryCredentialRowTable>? orderByList,
    RepositoryCredentialRowInclude? include,
  }) {
    return RepositoryCredentialRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RepositoryCredentialRow.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(RepositoryCredentialRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RepositoryCredentialRowImpl extends RepositoryCredentialRow {
  _RepositoryCredentialRowImpl({
    int? id,
    required String credentialId,
    required String productId,
    required String repositoryId,
    required String referenceName,
    required String publicKey,
    required String fingerprint,
    required String algorithm,
    required String status,
    required DateTime createdAt,
    DateTime? lastVerifiedAt,
    String? lastVerifiedBy,
    String? lastFailureReason,
    required String hostKeyStatus,
    String? host,
    String? hostKeyFingerprint,
    DateTime? hostConfirmedAt,
    String? hostConfirmedBy,
    DateTime? revokedAt,
    String? revokedReason,
    String? supersedesCredentialId,
    required int version,
  }) : super._(
         id: id,
         credentialId: credentialId,
         productId: productId,
         repositoryId: repositoryId,
         referenceName: referenceName,
         publicKey: publicKey,
         fingerprint: fingerprint,
         algorithm: algorithm,
         status: status,
         createdAt: createdAt,
         lastVerifiedAt: lastVerifiedAt,
         lastVerifiedBy: lastVerifiedBy,
         lastFailureReason: lastFailureReason,
         hostKeyStatus: hostKeyStatus,
         host: host,
         hostKeyFingerprint: hostKeyFingerprint,
         hostConfirmedAt: hostConfirmedAt,
         hostConfirmedBy: hostConfirmedBy,
         revokedAt: revokedAt,
         revokedReason: revokedReason,
         supersedesCredentialId: supersedesCredentialId,
         version: version,
       );

  /// Returns a shallow copy of this [RepositoryCredentialRow]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RepositoryCredentialRow copyWith({
    Object? id = _Undefined,
    String? credentialId,
    String? productId,
    String? repositoryId,
    String? referenceName,
    String? publicKey,
    String? fingerprint,
    String? algorithm,
    String? status,
    DateTime? createdAt,
    Object? lastVerifiedAt = _Undefined,
    Object? lastVerifiedBy = _Undefined,
    Object? lastFailureReason = _Undefined,
    String? hostKeyStatus,
    Object? host = _Undefined,
    Object? hostKeyFingerprint = _Undefined,
    Object? hostConfirmedAt = _Undefined,
    Object? hostConfirmedBy = _Undefined,
    Object? revokedAt = _Undefined,
    Object? revokedReason = _Undefined,
    Object? supersedesCredentialId = _Undefined,
    int? version,
  }) {
    return RepositoryCredentialRow(
      id: id is int? ? id : this.id,
      credentialId: credentialId ?? this.credentialId,
      productId: productId ?? this.productId,
      repositoryId: repositoryId ?? this.repositoryId,
      referenceName: referenceName ?? this.referenceName,
      publicKey: publicKey ?? this.publicKey,
      fingerprint: fingerprint ?? this.fingerprint,
      algorithm: algorithm ?? this.algorithm,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastVerifiedAt: lastVerifiedAt is DateTime?
          ? lastVerifiedAt
          : this.lastVerifiedAt,
      lastVerifiedBy: lastVerifiedBy is String?
          ? lastVerifiedBy
          : this.lastVerifiedBy,
      lastFailureReason: lastFailureReason is String?
          ? lastFailureReason
          : this.lastFailureReason,
      hostKeyStatus: hostKeyStatus ?? this.hostKeyStatus,
      host: host is String? ? host : this.host,
      hostKeyFingerprint: hostKeyFingerprint is String?
          ? hostKeyFingerprint
          : this.hostKeyFingerprint,
      hostConfirmedAt: hostConfirmedAt is DateTime?
          ? hostConfirmedAt
          : this.hostConfirmedAt,
      hostConfirmedBy: hostConfirmedBy is String?
          ? hostConfirmedBy
          : this.hostConfirmedBy,
      revokedAt: revokedAt is DateTime? ? revokedAt : this.revokedAt,
      revokedReason: revokedReason is String?
          ? revokedReason
          : this.revokedReason,
      supersedesCredentialId: supersedesCredentialId is String?
          ? supersedesCredentialId
          : this.supersedesCredentialId,
      version: version ?? this.version,
    );
  }
}

class RepositoryCredentialRowUpdateTable
    extends _i1.UpdateTable<RepositoryCredentialRowTable> {
  RepositoryCredentialRowUpdateTable(super.table);

  _i1.ColumnValue<String, String> credentialId(String value) => _i1.ColumnValue(
    table.credentialId,
    value,
  );

  _i1.ColumnValue<String, String> productId(String value) => _i1.ColumnValue(
    table.productId,
    value,
  );

  _i1.ColumnValue<String, String> repositoryId(String value) => _i1.ColumnValue(
    table.repositoryId,
    value,
  );

  _i1.ColumnValue<String, String> referenceName(String value) =>
      _i1.ColumnValue(
        table.referenceName,
        value,
      );

  _i1.ColumnValue<String, String> publicKey(String value) => _i1.ColumnValue(
    table.publicKey,
    value,
  );

  _i1.ColumnValue<String, String> fingerprint(String value) => _i1.ColumnValue(
    table.fingerprint,
    value,
  );

  _i1.ColumnValue<String, String> algorithm(String value) => _i1.ColumnValue(
    table.algorithm,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> lastVerifiedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.lastVerifiedAt,
        value,
      );

  _i1.ColumnValue<String, String> lastVerifiedBy(String? value) =>
      _i1.ColumnValue(
        table.lastVerifiedBy,
        value,
      );

  _i1.ColumnValue<String, String> lastFailureReason(String? value) =>
      _i1.ColumnValue(
        table.lastFailureReason,
        value,
      );

  _i1.ColumnValue<String, String> hostKeyStatus(String value) =>
      _i1.ColumnValue(
        table.hostKeyStatus,
        value,
      );

  _i1.ColumnValue<String, String> host(String? value) => _i1.ColumnValue(
    table.host,
    value,
  );

  _i1.ColumnValue<String, String> hostKeyFingerprint(String? value) =>
      _i1.ColumnValue(
        table.hostKeyFingerprint,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> hostConfirmedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.hostConfirmedAt,
        value,
      );

  _i1.ColumnValue<String, String> hostConfirmedBy(String? value) =>
      _i1.ColumnValue(
        table.hostConfirmedBy,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> revokedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.revokedAt,
        value,
      );

  _i1.ColumnValue<String, String> revokedReason(String? value) =>
      _i1.ColumnValue(
        table.revokedReason,
        value,
      );

  _i1.ColumnValue<String, String> supersedesCredentialId(String? value) =>
      _i1.ColumnValue(
        table.supersedesCredentialId,
        value,
      );

  _i1.ColumnValue<int, int> version(int value) => _i1.ColumnValue(
    table.version,
    value,
  );
}

class RepositoryCredentialRowTable extends _i1.Table<int?> {
  RepositoryCredentialRowTable({super.tableRelation})
    : super(tableName: 'product_credential') {
    updateTable = RepositoryCredentialRowUpdateTable(this);
    credentialId = _i1.ColumnString(
      'credentialId',
      this,
    );
    productId = _i1.ColumnString(
      'productId',
      this,
    );
    repositoryId = _i1.ColumnString(
      'repositoryId',
      this,
    );
    referenceName = _i1.ColumnString(
      'referenceName',
      this,
    );
    publicKey = _i1.ColumnString(
      'publicKey',
      this,
    );
    fingerprint = _i1.ColumnString(
      'fingerprint',
      this,
    );
    algorithm = _i1.ColumnString(
      'algorithm',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    lastVerifiedAt = _i1.ColumnDateTime(
      'lastVerifiedAt',
      this,
    );
    lastVerifiedBy = _i1.ColumnString(
      'lastVerifiedBy',
      this,
    );
    lastFailureReason = _i1.ColumnString(
      'lastFailureReason',
      this,
    );
    hostKeyStatus = _i1.ColumnString(
      'hostKeyStatus',
      this,
    );
    host = _i1.ColumnString(
      'host',
      this,
    );
    hostKeyFingerprint = _i1.ColumnString(
      'hostKeyFingerprint',
      this,
    );
    hostConfirmedAt = _i1.ColumnDateTime(
      'hostConfirmedAt',
      this,
    );
    hostConfirmedBy = _i1.ColumnString(
      'hostConfirmedBy',
      this,
    );
    revokedAt = _i1.ColumnDateTime(
      'revokedAt',
      this,
    );
    revokedReason = _i1.ColumnString(
      'revokedReason',
      this,
    );
    supersedesCredentialId = _i1.ColumnString(
      'supersedesCredentialId',
      this,
    );
    version = _i1.ColumnInt(
      'version',
      this,
    );
  }

  late final RepositoryCredentialRowUpdateTable updateTable;

  late final _i1.ColumnString credentialId;

  late final _i1.ColumnString productId;

  late final _i1.ColumnString repositoryId;

  late final _i1.ColumnString referenceName;

  late final _i1.ColumnString publicKey;

  late final _i1.ColumnString fingerprint;

  late final _i1.ColumnString algorithm;

  late final _i1.ColumnString status;

  late final _i1.ColumnDateTime createdAt;

  late final _i1.ColumnDateTime lastVerifiedAt;

  late final _i1.ColumnString lastVerifiedBy;

  late final _i1.ColumnString lastFailureReason;

  late final _i1.ColumnString hostKeyStatus;

  late final _i1.ColumnString host;

  late final _i1.ColumnString hostKeyFingerprint;

  late final _i1.ColumnDateTime hostConfirmedAt;

  late final _i1.ColumnString hostConfirmedBy;

  late final _i1.ColumnDateTime revokedAt;

  late final _i1.ColumnString revokedReason;

  late final _i1.ColumnString supersedesCredentialId;

  late final _i1.ColumnInt version;

  @override
  List<_i1.Column> get columns => [
    id,
    credentialId,
    productId,
    repositoryId,
    referenceName,
    publicKey,
    fingerprint,
    algorithm,
    status,
    createdAt,
    lastVerifiedAt,
    lastVerifiedBy,
    lastFailureReason,
    hostKeyStatus,
    host,
    hostKeyFingerprint,
    hostConfirmedAt,
    hostConfirmedBy,
    revokedAt,
    revokedReason,
    supersedesCredentialId,
    version,
  ];
}

class RepositoryCredentialRowInclude extends _i1.IncludeObject {
  RepositoryCredentialRowInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => RepositoryCredentialRow.t;
}

class RepositoryCredentialRowIncludeList extends _i1.IncludeList {
  RepositoryCredentialRowIncludeList._({
    _i1.WhereExpressionBuilder<RepositoryCredentialRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RepositoryCredentialRow.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => RepositoryCredentialRow.t;
}

class RepositoryCredentialRowRepository {
  const RepositoryCredentialRowRepository._();

  /// Returns a list of [RepositoryCredentialRow]s matching the given query parameters.
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
  Future<List<RepositoryCredentialRow>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RepositoryCredentialRowTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RepositoryCredentialRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RepositoryCredentialRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<RepositoryCredentialRow>(
      where: where?.call(RepositoryCredentialRow.t),
      orderBy: orderBy?.call(RepositoryCredentialRow.t),
      orderByList: orderByList?.call(RepositoryCredentialRow.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [RepositoryCredentialRow] matching the given query parameters.
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
  Future<RepositoryCredentialRow?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RepositoryCredentialRowTable>? where,
    int? offset,
    _i1.OrderByBuilder<RepositoryCredentialRowTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RepositoryCredentialRowTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<RepositoryCredentialRow>(
      where: where?.call(RepositoryCredentialRow.t),
      orderBy: orderBy?.call(RepositoryCredentialRow.t),
      orderByList: orderByList?.call(RepositoryCredentialRow.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [RepositoryCredentialRow] by its [id] or null if no such row exists.
  Future<RepositoryCredentialRow?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<RepositoryCredentialRow>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [RepositoryCredentialRow]s in the list and returns the inserted rows.
  ///
  /// The returned [RepositoryCredentialRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<RepositoryCredentialRow>> insert(
    _i1.DatabaseSession session,
    List<RepositoryCredentialRow> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<RepositoryCredentialRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [RepositoryCredentialRow] and returns the inserted row.
  ///
  /// The returned [RepositoryCredentialRow] will have its `id` field set.
  Future<RepositoryCredentialRow> insertRow(
    _i1.DatabaseSession session,
    RepositoryCredentialRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<RepositoryCredentialRow>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [RepositoryCredentialRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<RepositoryCredentialRow>> update(
    _i1.DatabaseSession session,
    List<RepositoryCredentialRow> rows, {
    _i1.ColumnSelections<RepositoryCredentialRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<RepositoryCredentialRow>(
      rows,
      columns: columns?.call(RepositoryCredentialRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RepositoryCredentialRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<RepositoryCredentialRow> updateRow(
    _i1.DatabaseSession session,
    RepositoryCredentialRow row, {
    _i1.ColumnSelections<RepositoryCredentialRowTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<RepositoryCredentialRow>(
      row,
      columns: columns?.call(RepositoryCredentialRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RepositoryCredentialRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<RepositoryCredentialRow?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<RepositoryCredentialRowUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<RepositoryCredentialRow>(
      id,
      columnValues: columnValues(RepositoryCredentialRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [RepositoryCredentialRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<RepositoryCredentialRow>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<RepositoryCredentialRowUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<RepositoryCredentialRowTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RepositoryCredentialRowTable>? orderBy,
    _i1.OrderByListBuilder<RepositoryCredentialRowTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<RepositoryCredentialRow>(
      columnValues: columnValues(RepositoryCredentialRow.t.updateTable),
      where: where(RepositoryCredentialRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RepositoryCredentialRow.t),
      orderByList: orderByList?.call(RepositoryCredentialRow.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [RepositoryCredentialRow]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<RepositoryCredentialRow>> delete(
    _i1.DatabaseSession session,
    List<RepositoryCredentialRow> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<RepositoryCredentialRow>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [RepositoryCredentialRow].
  Future<RepositoryCredentialRow> deleteRow(
    _i1.DatabaseSession session,
    RepositoryCredentialRow row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<RepositoryCredentialRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<RepositoryCredentialRow>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RepositoryCredentialRowTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<RepositoryCredentialRow>(
      where: where(RepositoryCredentialRow.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RepositoryCredentialRowTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<RepositoryCredentialRow>(
      where: where?.call(RepositoryCredentialRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RepositoryCredentialRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RepositoryCredentialRowTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<RepositoryCredentialRow>(
      where: where(RepositoryCredentialRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

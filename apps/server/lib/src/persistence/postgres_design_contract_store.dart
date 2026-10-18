import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';
import 'package:workflow_store/workflow_store.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// The durable [DesignContractStore] — the single owner of every read and write
/// against the `"design_contract"` table.
///
/// ## Why this file is the step-1 merge condition and not an optimisation
///
/// `design-revision.md` §4.2(a) is headed "**A durable** design contract", and
/// §9's own justification for step 2 is *"Without it, step 1's row and a
/// fabricated string are indistinguishable."* A table plus an interface plus an
/// in-memory implementation satisfies none of that: nothing survives a
/// restart, so `GuardConditions.designContractExists()` confirming "the id
/// resolves" against a `Map` would confirm it about process state that a
/// redeploy erases. Step 2 cannot honestly move `designContractExists()` onto
/// the durable column until this class exists and is mounted.
///
/// ## Which sibling this mirrors, and why
///
/// [PostgresQAContractStore], in preference to the two other plausible models:
///
///   * It is the same SHAPE of problem. `"qa_contract"` is likewise a
///     `text`-keyed, `text`-columned, JSON-in-`text` contract table whose
///     interface also carries a `provision*` that writes and then READS BACK.
///     Every decision that shaped that store — `ON CONFLICT` upsert on the
///     string primary key, the tolerant `_asJson` cell normaliser, the
///     per-column `FormatException` that keeps a decode failure attributable —
///     applies here unchanged, and adopting them is what makes the two stores
///     reviewable as one family rather than two.
///   * [PostgresDesignGovernanceStore] is the same DOMAIN but a different
///     problem: its rows are generated from typed Serverpod models, it carries
///     CAS versioning, append-only event tables and `inTransaction`, none of
///     which [DesignContractStore] has or wants. Copying its idioms would
///     import machinery this store has no use for.
///   * [PostgresWorkflowStore] owns work items, not contracts, and reaches the
///     design contract only through the `designContractId` column it does not
///     write.
///
/// The one idiom borrowed from [PostgresDesignGovernanceStore] is its
/// `WHERE "workItemId" = @… ORDER BY "createdAt" ASC` listing query, which is
/// the same indexed column read this store needs
/// (`design_contract_work_item_idx`).
///
/// ## Why the JSON columns are decoded here and not by `DesignContractRow`
///
/// The generated `DesignContractRow` models every JSON column as opaque `text`,
/// so it cannot reconstruct a typed `DesignContract` on its own — the same
/// reason [PostgresQAContractStore] writes raw SQL rather than using
/// `QAContractRow`. So this store binds named parameters and decodes explicitly.
///
/// ## The status column goes through the type's OWN codec, and there is no
/// second vocabulary
///
/// `DesignContractStatus.underReview` is spelled `under_review` on the wire, and
/// that mapping is PRIVATE to `platform_contracts/src/types/design_contract.dart`
/// — the enum carries no public `.wire` the way `DesignRevisionStatus` does.
/// So the only public reader AND writer of the vocabulary is
/// `DesignContract.toJson()` / `DesignContract.fromJson()` themselves.
///
/// This store therefore routes `status` through those, in both directions, and
/// nowhere else. That is what `design_contract.spy.yaml` asks for ("stored
/// through the type's OWN `toJson` codec … so the column and
/// `DesignContract.toJson()` can never disagree about what the word means"), and
/// it is strictly stronger than the alternative: a hand-written
/// `_statusToWire`/`_statusFromWire` pair here would be a SECOND vocabulary for
/// a status whose authority is `platform_contracts` — the exact failure the
/// column comment names — and it could drift from the private codec with no
/// failing test, because nothing in this repository may assert against a private
/// function.
class PostgresDesignContractStore implements DesignContractStore {
  PostgresDesignContractStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<void> saveDesignContract(DesignContract contract) async {
    await _db.execute(
      '''INSERT INTO "design_contract" (
           "contractId", "workItemId", "requiredArtifactsJson",
           "reviewersJson", "approvalThreshold", "status",
           "submittedArtifactsJson", "decisionsJson", "createdAt", "updatedAt",
           "expiresAt", "metadataJson"
         ) VALUES (
           @contractId, @workItemId, @requiredArtifacts,
           @reviewers, @approvalThreshold, @status,
           @submittedArtifacts, @decisions, @createdAt, @updatedAt,
           @expiresAt, @metadata
         )
         ON CONFLICT ("contractId") DO UPDATE SET
           "workItemId" = EXCLUDED."workItemId",
           "requiredArtifactsJson" = EXCLUDED."requiredArtifactsJson",
           "reviewersJson" = EXCLUDED."reviewersJson",
           "approvalThreshold" = EXCLUDED."approvalThreshold",
           "status" = EXCLUDED."status",
           "submittedArtifactsJson" = EXCLUDED."submittedArtifactsJson",
           "decisionsJson" = EXCLUDED."decisionsJson",
           "createdAt" = EXCLUDED."createdAt",
           "updatedAt" = EXCLUDED."updatedAt",
           "expiresAt" = EXCLUDED."expiresAt",
           "metadataJson" = EXCLUDED."metadataJson"''',
      parameters: QueryParameters.named(_contractParams(contract)),
    );
  }

  @override
  Future<DesignContract> provisionDesignContract(
    DesignContract contract,
  ) async {
    await saveDesignContract(contract);
    final stored = await readDesignContract(contract.contractId);
    if (stored == null) {
      // Unreachable unless the table was dropped between the write and the
      // read. Surfaced rather than swallowed for the reason the interface gives:
      // the caller is about to stamp `stored.contractId` onto a work item, and
      // the whole point of this method is that the id provably resolves.
      throw StateError(
        'DesignContract ${contract.contractId} was written but cannot be read '
        'back; refusing to hand out a designContractId that resolves to nothing',
      );
    }
    return stored;
  }

  @override
  Future<DesignContract?> readDesignContract(String contractId) async {
    final rows = await _db.query(
      'SELECT * FROM "design_contract" WHERE "contractId" = @contractId',
      parameters: QueryParameters.named({'contractId': contractId}),
    );
    if (rows.isEmpty) return null;
    return _contractFromRow(rows.first);
  }

  @override
  Future<bool> hasDesignContract(String contractId) async {
    final rows = await _db.query(
      'SELECT 1 AS "present" FROM "design_contract" WHERE "contractId" = '
      '@contractId',
      parameters: QueryParameters.named({'contractId': contractId}),
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<DesignContract>> listDesignContractsForWorkItem(
    String workItemId,
  ) async {
    // The `workItemId` column is indexed (`design_contract_work_item_idx`)
    // precisely so this is an indexed lookup rather than a scan; see
    // `design_contract.spy.yaml`.
    //
    // The `ORDER BY` is the interface's ORDER, not a display preference. It is
    // spelled out in `DesignContractStore.listDesignContractsForWorkItem`, and
    // `InMemoryDesignContractStore` sorts to the same total order; `"contractId"`
    // is the tie-break because `createdAt` is caller-asserted and two contracts
    // sharing an instant is a normal state, not a malformed row. An `ORDER BY`
    // that leaves ties to the planner would let this store and the in-memory
    // one disagree about which of two equally-old contracts comes first.
    final rows = await _db.query(
      'SELECT * FROM "design_contract" WHERE "workItemId" = @workItemId '
      'ORDER BY "createdAt" ASC, "contractId" ASC',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return rows.map(_contractFromRow).toList(growable: false);
  }

  /// The one writer of the row shape.
  ///
  /// Every JSON column is written as a JSON document string and stored verbatim
  /// in its `text` column. `status` is the single non-document JSON column and
  /// it is a bare wire token taken from `DesignContract.toJson()` — never from a
  /// mapping declared here, for the reason this class's doc gives.
  Map<String, Object?> _contractParams(DesignContract contract) {
    final json = contract.toJson();
    return <String, Object?>{
      'contractId': json['contractId'],
      'workItemId': json['workItemId'],
      'requiredArtifacts': jsonEncode(json['requiredArtifacts']),
      'reviewers': jsonEncode(json['reviewers']),
      'approvalThreshold': json['approvalThreshold'],
      'status': json['status'],
      'submittedArtifacts': _encodeNullable(json['submittedArtifacts']),
      'decisions': _encodeNullable(json['decisions']),
      'createdAt': contract.createdAt,
      'updatedAt': contract.updatedAt,
      'expiresAt': contract.expiresAt,
      'metadata': _encodeNullable(json['metadata']),
    };
  }

  /// The one decoder of the row shape. Mirrors [_contractParams] column for
  /// column; a column added to one and not the other is a bug in this file, not
  /// a runtime surprise.
  ///
  /// Each JSON column is normalised and shape-checked HERE, under its own name,
  /// so a defective column raises a `FormatException` that says which column is
  /// defective — the reason `PostgresQAContractStore` decodes column by column
  /// rather than handing a whole row to `QAContract.fromJson`.
  ///
  /// What is then handed to `DesignContract.fromJson` is a document shaped like
  /// `DesignContract.toJson()`, which is what makes `status` decode through the
  /// type's own codec. The `Map<String, dynamic>` is transport for the duration
  /// of this one call and never becomes the domain object: the return type is
  /// `DesignContract`, and its typed constructor is what validates the rest.
  DesignContract _contractFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DesignContract.fromJson(<String, dynamic>{
      'contractId': m['contractId'] as String,
      'workItemId': m['workItemId'] as String,
      'requiredArtifacts': _requiredJsonArray(
        m['requiredArtifactsJson'],
        'requiredArtifactsJson',
      ),
      'reviewers': _requiredJsonArray(m['reviewersJson'], 'reviewersJson'),
      'approvalThreshold': (m['approvalThreshold'] as num).toInt(),
      // Straight into the document, decoded by `_designContractStatusFromJson`.
      // A column holding an unknown token raises `NoSuchMethodError` from the
      // enum lookup rather than a `FormatException` — which is the right
      // failure, because an unknown status word is a vocabulary fault and
      // naming it here would name a vocabulary this file does not own.
      'status': m['status'] as String,
      'submittedArtifacts': _jsonArray(
        m['submittedArtifactsJson'],
        'submittedArtifactsJson',
      ),
      'decisions': _jsonArray(m['decisionsJson'], 'decisionsJson'),
      // ISO-8601 TEXT rather than the `DateTime` itself: the generated decoder
      // reads a timestamp from a string, and `decodeUtc` is the one place that
      // knows the column is a naive UTC wall clock. Handing it the raw driver
      // value would produce a local-vs-UTC mismatch on every read.
      'createdAt': decodeUtc(m['createdAt'])!.toIso8601String(),
      'updatedAt': decodeUtc(m['updatedAt'])!.toIso8601String(),
      'expiresAt': decodeUtc(m['expiresAt'])?.toIso8601String(),
      'metadata': _jsonObject(m['metadataJson'], 'metadataJson'),
    });
  }

  /// `null` means "no such document"; an EMPTY `text` cell means the same thing,
  /// so both collapse here rather than in each caller.
  String? _encodeNullable(Object? value) =>
      value == null ? null : jsonEncode(value);

  /// A JSON-array column that the DDL declares `NOT NULL`.
  ///
  /// Separate from [_jsonArray] because a null here is NOT an absent value — the
  /// column cannot be null — and letting it through would surface as a cast
  /// failure several frames deeper, naming a Dart type instead of the column
  /// that is actually empty.
  List<dynamic> _requiredJsonArray(Object? value, String column) {
    final decoded = _jsonArray(value, column);
    if (decoded == null) {
      throw FormatException(
        'design_contract.$column is NOT NULL but held no JSON array',
      );
    }
    return decoded;
  }

  List<dynamic>? _jsonArray(Object? value, String column) {
    final decoded = _asJson(value, column);
    if (decoded == null) return null;
    if (decoded is! List) {
      throw FormatException(
        'design_contract.$column must be a JSON array, got '
        '${decoded.runtimeType}',
      );
    }
    return decoded;
  }

  Map<String, dynamic>? _jsonObject(Object? value, String column) {
    final decoded = _asJson(value, column);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'design_contract.$column must be a JSON object, got '
        '${decoded.runtimeType}',
      );
    }
    return decoded;
  }

  /// Normalises a JSON cell, which the driver may hand back already decoded
  /// (`List`/`Map`) or as the raw JSON text. Same defensive posture as
  /// `PostgresQAContractStore._asJson` and
  /// `PostgresTriageStore._stringList`: both shapes are accepted, neither is
  /// assumed, and anything else is a `FormatException` naming the column.
  Object? _asJson(Object? value, String column) {
    if (value == null) return null;
    if (value is String) {
      if (value.trim().isEmpty) return null;
      return jsonDecode(value);
    }
    if (value is List || value is Map) return value;
    throw FormatException(
      'design_contract.$column must be a JSON document, got '
      '${value.runtimeType}',
    );
  }
}

import 'dart:convert';

import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// The single owner of every read and write against the `"qa_contract"`
/// table.
///
/// Column naming and types are the ones declared by
/// `lib/src/database/qa_contract.spy.yaml`, so there is one schema and one
/// mapping: the row model exists (`QAContractRow`) but it models the JSON
/// payloads as opaque `text`, so it cannot reconstruct the typed domain
/// objects on its own. This store therefore writes raw SQL with named
/// `@param` bindings and decodes rows explicitly, exactly as
/// `PostgresTriageStore` does for `"triage_result"`.
///
/// ## Why the mapping is hand-written rather than `QAContract.fromJson`
///
/// `gatesJson`, `passCriteriaJson`, `evidenceRowsJson` and `metadataJson` are
/// `text` columns holding a JSON document. Each of them carries a *typed*
/// value on the Dart side
/// (`List<QAGateDefinition>`, `QAPassCriteria?`, `List<QAEvidenceRow>?`,
/// `Map<String, dynamic>?`) and each of those types has its own generated
/// `fromJson` that fails loudly on an unknown enum name. Decoding them one
/// column at a time — rather than `jsonDecode`ing a whole row into
/// `QAContract.fromJson` — keeps the failure attributable to a single column
/// and keeps AGENTS.md §8's "no `Map<String, dynamic>` for domain objects"
/// honest: the map is only ever the transport, never the domain object.
class PostgresQAContractStore implements QAContractStore {
  PostgresQAContractStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<void> saveQAContract(QAContract contract) async {
    await _db.execute(
      '''INSERT INTO "qa_contract" (
           "contractId", "workItemCategory", "gatesJson", "version",
           "passCriteriaJson", "createdAt", "updatedAt", "evidenceRowsJson",
           "metadataJson"
         ) VALUES (
           @contractId, @workItemCategory, @gates, @version,
           @passCriteria, @createdAt, @updatedAt, @evidenceRows,
           @metadata
         )
         ON CONFLICT ("contractId") DO UPDATE SET
           "workItemCategory" = EXCLUDED."workItemCategory",
           "gatesJson" = EXCLUDED."gatesJson",
           "version" = EXCLUDED."version",
           "passCriteriaJson" = EXCLUDED."passCriteriaJson",
           "createdAt" = EXCLUDED."createdAt",
           "updatedAt" = EXCLUDED."updatedAt",
           "evidenceRowsJson" = EXCLUDED."evidenceRowsJson",
           "metadataJson" = EXCLUDED."metadataJson"''',
      parameters: QueryParameters.named(_contractParams(contract)),
    );
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    await saveQAContract(contract);
    final stored = await readQAContract(contract.contractId);
    if (stored == null) {
      // Unreachable unless the table was dropped between the write and the
      // read. Surfaced rather than swallowed: the caller is about to stamp
      // `stored.contractId` onto a work item, and the whole point of this
      // method is that the id provably resolves.
      throw StateError(
        'QAContract ${contract.contractId} was written but cannot be read '
        'back; refusing to hand out a qaContractId that resolves to nothing',
      );
    }
    return stored;
  }

  @override
  Future<QAContract?> readQAContract(String contractId) async {
    final rows = await _db.query(
      'SELECT * FROM "qa_contract" WHERE "contractId" = @contractId',
      parameters: QueryParameters.named({'contractId': contractId}),
    );
    if (rows.isEmpty) return null;
    return _contractFromRow(rows.first);
  }

  @override
  Future<bool> hasQAContract(String contractId) async {
    final rows = await _db.query(
      'SELECT 1 AS "present" FROM "qa_contract" WHERE "contractId" = '
      '@contractId',
      parameters: QueryParameters.named({'contractId': contractId}),
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<QAContract>> listQAContractsForWorkItem(String workItemId) async {
    // `qa_contract."metadataJson"` holds a JSON document in a `text` column,
    // so the containment operator is applied through a cast back to `jsonb`
    // rather than to a text pattern match. `workItemId` is the metadata key the
    // provisioner records; see `QAContractStore`.
    final rows = await _db.query(
      'SELECT * FROM "qa_contract" WHERE "metadataJson"::jsonb @> @probe '
      'ORDER BY "createdAt" ASC',
      parameters: QueryParameters.named({
        'probe': jsonEncode(<String, dynamic>{
          qaContractWorkItemIdMetadataKey: workItemId,
        }),
      }),
    );
    return rows.map(_contractFromRow).toList(growable: false);
  }

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async {
    final rows = await _db.query(
      'SELECT * FROM "qa_contract" WHERE "workItemCategory" = @category '
      'ORDER BY "createdAt" ASC',
      parameters: QueryParameters.named({'category': category.name}),
    );
    return rows.map(_contractFromRow).toList(growable: false);
  }

  /// The one writer of the row shape. Every JSON column is written as a JSON
  /// document string, stored verbatim in its `text` column.
  Map<String, Object?> _contractParams(QAContract c) => {
    'contractId': c.contractId,
    'workItemCategory': c.workItemCategory.name,
    'gates': jsonEncode(c.gates.map((gate) => gate.toJson()).toList()),
    'version': c.version,
    'passCriteria': c.passCriteria == null
        ? null
        : jsonEncode(c.passCriteria!.toJson()),
    'createdAt': c.createdAt,
    'updatedAt': c.updatedAt,
    'evidenceRows': c.evidenceRows == null
        ? null
        : jsonEncode(c.evidenceRows!.map((row) => row.toJson()).toList()),
    'metadata': c.metadata == null ? null : jsonEncode(c.metadata),
  };

  /// The one decoder of the row shape. Mirrors [_contractParams] column for
  /// column; a column added to one and not the other is a bug in this file,
  /// not a runtime surprise.
  QAContract _contractFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return QAContract(
      contractId: m['contractId'] as String,
      workItemCategory: WorkItemCategory.values.byName(
        m['workItemCategory'] as String,
      ),
      gates: _gates(m['gatesJson']),
      version: m['version'] as String,
      passCriteria: _passCriteria(m['passCriteriaJson']),
      createdAt: decodeUtc(m['createdAt'])!,
      updatedAt: decodeUtc(m['updatedAt'])!,
      evidenceRows: _evidenceRows(m['evidenceRowsJson']),
      metadata: _metadata(m['metadataJson']),
    );
  }

  List<QAGateDefinition> _gates(Object? value) {
    final decoded = _asJson(value, 'gatesJson');
    if (decoded is! List) {
      throw FormatException(
        'qa_contract.gatesJson must be a JSON array, got '
        '${decoded.runtimeType}',
      );
    }
    return decoded
        .map((e) => QAGateDefinition.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  QAPassCriteria? _passCriteria(Object? value) {
    final decoded = _asJson(value, 'passCriteriaJson');
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'qa_contract.passCriteriaJson must be a JSON object, got '
        '${decoded.runtimeType}',
      );
    }
    return QAPassCriteria.fromJson(decoded);
  }

  List<QAEvidenceRow>? _evidenceRows(Object? value) {
    final decoded = _asJson(value, 'evidenceRowsJson');
    if (decoded == null) return null;
    if (decoded is! List) {
      throw FormatException(
        'qa_contract.evidenceRowsJson must be a JSON array, got '
        '${decoded.runtimeType}',
      );
    }
    return decoded
        .map((e) => QAEvidenceRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Map<String, dynamic>? _metadata(Object? value) {
    final decoded = _asJson(value, 'metadataJson');
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'qa_contract.metadataJson must be a JSON object, got '
        '${decoded.runtimeType}',
      );
    }
    return decoded;
  }

  /// Normalises a JSON cell, which the driver may hand back already
  /// decoded (`List`/`Map`) or as the raw JSON text. Same defensive posture as
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
      'qa_contract.$column must be a JSON document, got '
      '${value.runtimeType}',
    );
  }
}

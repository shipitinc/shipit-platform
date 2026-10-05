import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';
import 'package:product_registry/product_registry.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// The single owner of every read and write against the `"triage_result"`
/// table.
///
/// `PostgresDefectStore` also satisfies `DefectStore`'s four `TriageResult`
/// methods, but it *delegates* to this class rather than owning a second copy
/// of the SQL. There is deliberately exactly one `_triageResultParams` writer
/// and exactly one `_triageResultFromRow` decoder in the codebase, because the
/// `"triage_result"` table has no per-column type contract on the Dart side:
/// `suspectedComponents` / `evidenceUsed` are `json` columns whose values the
/// driver may hand back already decoded, while `clarificationRequired` is a
/// `text` column carrying a JSON document. Two divergent copies of this mapping
/// previously meant a row written through one store was unreadable through the
/// other. Do not re-inline this logic anywhere else.
class PostgresTriageStore {
  PostgresTriageStore(this._db);

  final PersistenceDatabase _db;

  Future<void> saveTriageResult(
    TriageResult result, {
    int? expectedVersion,
  }) async {
    const bareInsert = '''INSERT INTO "triage_result" (
           "resultId", "defectId", "recommendedStatus", "recommendedClassification",
           "confidence", "suspectedCategory", "suspectedComponents",
           "reproductionSupported", "evidenceUsed", "clarificationRequired",
           "recommendedNextAction", "possibleDuplicateDefectId",
           "recommendedWorkItemCategory", "summary", "jobId", "executionId",
           "createdAt", "completedAt", "version"
         ) VALUES (
           @resultId, @defectId, @recommendedStatus, @recommendedClassification,
           @confidence, @suspectedCategory, @suspectedComponents,
           @reproductionSupported, @evidenceUsed, @clarificationRequired,
           @recommendedNextAction, @possibleDuplicateDefectId,
           @recommendedWorkItemCategory, @summary, @jobId, @executionId,
           @createdAt, @completedAt, @version
         )''';

    final params = QueryParameters.named(_triageResultParams(result));

    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "triage_result" SET
             "defectId" = @defectId,
             "recommendedStatus" = @recommendedStatus,
             "recommendedClassification" = @recommendedClassification,
             "confidence" = @confidence,
             "suspectedCategory" = @suspectedCategory,
             "suspectedComponents" = @suspectedComponents,
             "reproductionSupported" = @reproductionSupported,
             "evidenceUsed" = @evidenceUsed,
             "clarificationRequired" = @clarificationRequired,
             "recommendedNextAction" = @recommendedNextAction,
             "possibleDuplicateDefectId" = @possibleDuplicateDefectId,
             "recommendedWorkItemCategory" = @recommendedWorkItemCategory,
             "summary" = @summary,
             "jobId" = @jobId,
             "executionId" = @executionId,
             "createdAt" = @createdAt,
             "completedAt" = @completedAt,
             "version" = @version
           WHERE "resultId" = @resultId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ...(params.parameters as Map<String, Object?>),
          'version': result.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;
      throw ConcurrentModificationException(
        entityId: result.resultId,
        expectedVersion: expectedVersion,
        actualVersion: 0,
      );
    }

    await _db.execute(
      '''$bareInsert ON CONFLICT ("resultId") DO UPDATE SET
             "defectId" = EXCLUDED."defectId",
             "recommendedStatus" = EXCLUDED."recommendedStatus",
             "recommendedClassification" = EXCLUDED."recommendedClassification",
             "confidence" = EXCLUDED."confidence",
             "suspectedCategory" = EXCLUDED."suspectedCategory",
             "suspectedComponents" = EXCLUDED."suspectedComponents",
             "reproductionSupported" = EXCLUDED."reproductionSupported",
             "evidenceUsed" = EXCLUDED."evidenceUsed",
             "clarificationRequired" = EXCLUDED."clarificationRequired",
             "recommendedNextAction" = EXCLUDED."recommendedNextAction",
             "possibleDuplicateDefectId" = EXCLUDED."possibleDuplicateDefectId",
             "recommendedWorkItemCategory" = EXCLUDED."recommendedWorkItemCategory",
             "summary" = EXCLUDED."summary",
             "jobId" = EXCLUDED."jobId",
             "executionId" = EXCLUDED."executionId",
             "createdAt" = EXCLUDED."createdAt",
             "completedAt" = EXCLUDED."completedAt",
             "version" = EXCLUDED."version"''',
      parameters: params,
    );
  }

  Future<TriageResult?> readTriageResult(String resultId) async {
    final rows = await _db.query(
      'SELECT * FROM "triage_result" WHERE "resultId" = @resultId',
      parameters: QueryParameters.named({'resultId': resultId}),
    );
    if (rows.isEmpty) return null;
    return _triageResultFromRow(rows.first);
  }

  Future<List<TriageResult>> readTriageResultsForDefect(String defectId) async {
    final rows = await _db.query(
      'SELECT * FROM "triage_result" WHERE "defectId" = @defectId ORDER BY "createdAt" DESC',
      parameters: QueryParameters.named({'defectId': defectId}),
    );
    return rows.map(_triageResultFromRow).toList();
  }

  Future<TriageResult?> readTriageResultForJob(String jobId) async {
    final rows = await _db.query(
      'SELECT * FROM "triage_result" WHERE "jobId" = @jobId',
      parameters: QueryParameters.named({'jobId': jobId}),
    );
    if (rows.isEmpty) return null;
    return _triageResultFromRow(rows.first);
  }

  Map<String, dynamic> _triageResultParams(TriageResult r) => {
    'resultId': r.resultId,
    'defectId': r.defectId,
    'recommendedStatus': r.recommendedStatus.wire,
    'recommendedClassification': r.recommendedClassification.wire,
    'confidence': r.confidence,
    'suspectedCategory': r.suspectedCategory,
    'suspectedComponents': PersistenceDatabase.encodeJson(
      r.suspectedComponents,
    ),
    'reproductionSupported': r.reproductionSupported,
    'evidenceUsed': PersistenceDatabase.encodeJson(r.evidenceUsed),
    'clarificationRequired': PersistenceDatabase.encodeJson(
      r.clarificationRequired.map((c) => c.toJson()).toList(),
    ),
    'recommendedNextAction': r.recommendedNextAction,
    'possibleDuplicateDefectId': r.possibleDuplicateDefectId,
    'recommendedWorkItemCategory': r.recommendedWorkItemCategory,
    'summary': r.summary,
    'jobId': r.jobId,
    'executionId': r.executionId,
    'createdAt': r.createdAt,
    'completedAt': r.completedAt,
    'version': r.version,
  };

  TriageResult _triageResultFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return TriageResult(
      resultId: m['resultId'] as String,
      defectId: m['defectId'] as String,
      recommendedStatus: DefectStatus.fromWire(
        m['recommendedStatus'] as String,
      ),
      recommendedClassification: m['recommendedClassification'] == null
          ? DefectClassification.implementationDefect
          : DefectClassification.fromWire(
              m['recommendedClassification'] as String,
            ),
      confidence: (m['confidence'] as num).toDouble(),
      suspectedCategory: m['suspectedCategory'] as String,
      // `suspectedComponents` / `evidenceUsed` are `json` columns, so the
      // driver already hands back a decoded List. `clarificationRequired` is
      // `text` written with PersistenceDatabase.encodeJson, so it comes back
      // as a JSON String and must be decoded here.
      suspectedComponents: _stringList(m['suspectedComponents']),
      reproductionSupported: m['reproductionSupported'] as bool,
      evidenceUsed: _stringList(m['evidenceUsed']),
      clarificationRequired:
          decodeJsonList(
            m['clarificationRequired'] as String?,
            DefectClarificationRequest.fromJson,
          ) ??
          const [],
      recommendedNextAction: m['recommendedNextAction'] as String,
      possibleDuplicateDefectId: m['possibleDuplicateDefectId'] as String?,
      recommendedWorkItemCategory: m['recommendedWorkItemCategory'] as String?,
      summary: m['summary'] as String,
      jobId: m['jobId'] as String,
      executionId: m['executionId'] as String?,
      createdAt: decodeUtc(m['createdAt'])!,
      completedAt: decodeUtc(m['completedAt']),
      version: m['version'] as int,
    );
  }

  /// Normalizes a JSON-array column that may arrive already decoded (driver
  /// behaviour for `json` columns) or still encoded (defensive, e.g. if the
  /// driver is configured to return raw text).
  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.cast<String>();
    if (value is String) {
      if (value.trim().isEmpty) return const [];
      return (jsonDecode(value) as List).cast<String>();
    }
    throw FormatException('Expected a JSON array, got ${value.runtimeType}');
  }
}

/// Exception thrown when a triage result is not found.
///
/// This is the canonical `TriageResultNotFoundException` for the
/// `"triage_result"` table; the duplicate that used to live in
/// `postgres_defect_store.dart` was removed when that store stopped owning a
/// second copy of the mapping.
class TriageResultNotFoundException implements Exception {
  TriageResultNotFoundException(this.resultId);

  final String resultId;

  @override
  String toString() => 'Triage result not found: $resultId';
}

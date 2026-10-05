import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'postgres_triage_store.dart' show PostgresTriageStore;
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [DefectStore].
///
/// Optimistic concurrency uses the same `version` + CAS pattern as other stores.
class PostgresDefectStore implements DefectStore {
  PostgresDefectStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(DefectStore store) body,
  ) {
    return _db.inTransaction<T>(() => body(this));
  }

  // ---------------------------------------------------------------------
  // Defect
  // ---------------------------------------------------------------------

  @override
  Future<void> saveDefect(Defect defect, {int? expectedVersion}) async {
    const bareInsert = '''INSERT INTO "defect" (
           "defectId", "title", "description", "expectedBehavior",
           "reproductionSteps", "severity", "status", "classification",
           "reporter", "productId", "affectedWorkItemId", "affectedRunId",
           "remediationWorkItemId", "duplicateOfDefectId",
           "currentTriageJobId", "clientContextJson", "metadataJson",
           "createdAt", "updatedAt", "resolvedAt", "closedAt", "version"
         ) VALUES (
           @defectId, @title, @description, @expectedBehavior,
           @reproductionSteps, @severity, @status, @classification,
           @reporter, @productId, @affectedWorkItemId, @affectedRunId,
           @remediationWorkItemId, @duplicateOfDefectId,
           @currentTriageJobId, @clientContextJson, @metadataJson,
           @createdAt, @updatedAt, @resolvedAt, @closedAt, @version
         )''';

    final params = QueryParameters.named(_defectParams(defect));

    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "defect" SET
             "title" = @title,
             "description" = @description,
             "expectedBehavior" = @expectedBehavior,
             "reproductionSteps" = @reproductionSteps,
             "severity" = @severity,
             "status" = @status,
             "classification" = @classification,
             "reporter" = @reporter,
             "productId" = @productId,
             "affectedWorkItemId" = @affectedWorkItemId,
             "affectedRunId" = @affectedRunId,
             "remediationWorkItemId" = @remediationWorkItemId,
             "duplicateOfDefectId" = @duplicateOfDefectId,
             "currentTriageJobId" = @currentTriageJobId,
             "clientContextJson" = @clientContextJson,
             "metadataJson" = @metadataJson,
             "createdAt" = @createdAt,
             "updatedAt" = @updatedAt,
             "resolvedAt" = @resolvedAt,
             "closedAt" = @closedAt,
             "version" = @version
           WHERE "defectId" = @defectId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ...(params.parameters as Map<String, Object?>),
          'version': defect.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;

      final rows = await _db.query(
        'SELECT "version" FROM "defect" WHERE "defectId" = @defectId',
        parameters: QueryParameters.named({'defectId': defect.defectId}),
      );
      final actual = rows.isEmpty ? 0 : rows[0].toColumnMap()['version'] as int;
      if (rows.isEmpty && expectedVersion == 0) {
        final inserted = await _db.execute(
          '$bareInsert ON CONFLICT ("defectId") DO NOTHING',
          parameters: params,
        );
        if (inserted == 1) return;
        final current = await _db.query(
          'SELECT "version" FROM "defect" WHERE "defectId" = @defectId',
          parameters: QueryParameters.named({'defectId': defect.defectId}),
        );
        throw ConcurrentModificationException(
          entityId: defect.defectId,
          expectedVersion: 0,
          actualVersion: current.isEmpty
              ? 0
              : (current[0].toColumnMap()['version'] as int),
        );
      }
      throw ConcurrentModificationException(
        entityId: defect.defectId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }

    await _db.execute(
      '''$bareInsert ON CONFLICT ("defectId") DO UPDATE SET
             "title" = EXCLUDED."title",
             "description" = EXCLUDED."description",
             "expectedBehavior" = EXCLUDED."expectedBehavior",
             "reproductionSteps" = EXCLUDED."reproductionSteps",
             "severity" = EXCLUDED."severity",
             "status" = EXCLUDED."status",
             "classification" = EXCLUDED."classification",
             "reporter" = EXCLUDED."reporter",
             "productId" = EXCLUDED."productId",
             "affectedWorkItemId" = EXCLUDED."affectedWorkItemId",
             "affectedRunId" = EXCLUDED."affectedRunId",
             "remediationWorkItemId" = EXCLUDED."remediationWorkItemId",
             "duplicateOfDefectId" = EXCLUDED."duplicateOfDefectId",
             "currentTriageJobId" = EXCLUDED."currentTriageJobId",
             "clientContextJson" = EXCLUDED."clientContextJson",
             "metadataJson" = EXCLUDED."metadataJson",
             "createdAt" = EXCLUDED."createdAt",
             "updatedAt" = EXCLUDED."updatedAt",
             "resolvedAt" = EXCLUDED."resolvedAt",
             "closedAt" = EXCLUDED."closedAt",
             "version" = EXCLUDED."version"''',
      parameters: params,
    );
  }

  @override
  Future<Defect> readDefect(String defectId) async {
    final rows = await _db.query(
      'SELECT * FROM "defect" WHERE "defectId" = @defectId',
      parameters: QueryParameters.named({'defectId': defectId}),
    );
    if (rows.isEmpty) {
      throw DefectNotFoundException(defectId);
    }
    return _defectFromRow(rows.first);
  }

  @override
  Future<List<Defect>> listDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
    int? limit,
    int? offset,
  }) async {
    final where = <String>[];
    final params = <String, dynamic>{};

    if (productId != null) {
      where.add(
        '"affectedWorkItemId" IN (SELECT "workItemId" FROM "work_item" WHERE "productId" = @productId)',
      );
      params['productId'] = productId;
    }
    if (status != null) {
      where.add('"status" = @status');
      params['status'] = status.wire;
    }
    if (classification != null) {
      where.add('"classification" = @classification');
      params['classification'] = classification.wire;
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';

    final rows = await _db.query(
      'SELECT * FROM "defect" $whereClause ORDER BY "updatedAt" DESC $limitClause $offsetClause',
      parameters: QueryParameters.named(params),
    );

    return rows.map<Defect>(_defectFromRow).toList();
  }

  @override
  Future<int> countDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
  }) async {
    final where = <String>[];
    final params = <String, dynamic>{};

    if (productId != null) {
      where.add(
        '"affectedWorkItemId" IN (SELECT "workItemId" FROM "work_item" WHERE "productId" = @productId)',
      );
      params['productId'] = productId;
    }
    if (status != null) {
      where.add('"status" = @status');
      params['status'] = status.wire;
    }
    if (classification != null) {
      where.add('"classification" = @classification');
      params['classification'] = classification.wire;
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await _db.query(
      'SELECT COUNT(*) as count FROM "defect" $whereClause',
      parameters: QueryParameters.named(params),
    );
    return rows.first.toColumnMap()['count'] as int;
  }

  // ---------------------------------------------------------------------
  // DefectEvidence
  // ---------------------------------------------------------------------

  @override
  Future<void> saveDefectEvidence(
    DefectEvidence evidence, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "defect_evidence" SET
             "defectId" = @defectId,
             "kind" = @kind,
             "artifactId" = @artifactId,
             "contentHash" = @contentHash,
             "description" = @description,
             "sourceRef" = @sourceRef,
             "capturedAt" = @capturedAt,
             "createdAt" = @createdAt,
             "version" = @version
           WHERE "evidenceId" = @evidenceId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._evidenceParams(evidence),
          'version': evidence.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;
      throw ConcurrentModificationException(
        entityId: evidence.evidenceId,
        expectedVersion: expectedVersion,
        actualVersion: 0,
      );
    }
    await _db.execute(
      '''INSERT INTO "defect_evidence" (
           "evidenceId", "defectId", "kind", "artifactId",
           "contentHash", "description", "sourceRef",
           "capturedAt", "createdAt", "version"
         ) VALUES (
           @evidenceId, @defectId, @kind, @artifactId,
           @contentHash, @description, @sourceRef,
           @capturedAt, @createdAt, @version
         )
         ON CONFLICT ("evidenceId") DO UPDATE SET
           "defectId" = EXCLUDED."defectId",
           "kind" = EXCLUDED."kind",
           "artifactId" = EXCLUDED."artifactId",
           "contentHash" = EXCLUDED."contentHash",
           "description" = EXCLUDED."description",
           "sourceRef" = EXCLUDED."sourceRef",
           "capturedAt" = EXCLUDED."capturedAt",
           "createdAt" = EXCLUDED."createdAt",
           "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_evidenceParams(evidence)),
    );
  }

  @override
  Future<List<DefectEvidence>> readEvidenceForDefect(String defectId) async {
    final rows = await _db.query(
      'SELECT * FROM "defect_evidence" WHERE "defectId" = @defectId ORDER BY "createdAt" ASC',
      parameters: QueryParameters.named({'defectId': defectId}),
    );
    return rows.map<DefectEvidence>(_evidenceFromRow).toList();
  }

  // ---------------------------------------------------------------------
  // DefectEvent
  // ---------------------------------------------------------------------

  @override
  Future<void> appendDefectEvent(DefectEvent event) async {
    await _db.execute(
      '''INSERT INTO "defect_event" (
           "eventId", "defectId", "sequence", "type",
           "fromStatus", "toStatus", "actorType", "actorId",
           "payloadJson", "occurredAt"
         ) VALUES (
           @eventId, @defectId, @sequence, @type,
           @fromStatus, @toStatus, @actorType, @actorId,
           @payloadJson, @occurredAt
         )''',
      parameters: QueryParameters.named(_eventParams(event)),
    );
  }

  @override
  Future<List<DefectEvent>> readEventsForDefect(String defectId) async {
    final rows = await _db.query(
      'SELECT * FROM "defect_event" WHERE "defectId" = @defectId ORDER BY "sequence" ASC',
      parameters: QueryParameters.named({'defectId': defectId}),
    );
    return rows.map<DefectEvent>(_eventFromRow).toList();
  }

  // ---------------------------------------------------------------------
  // DefectClarification
  // ---------------------------------------------------------------------

  @override
  Future<void> saveClarification(
    DefectClarification clarification, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "defect_clarification" SET
             "defectId" = @defectId,
             "question" = @question,
             "reason" = @reason,
             "status" = @status,
             "answer" = @answer,
             "humanDecisionId" = @humanDecisionId,
             "requestedByTriageJobId" = @requestedByTriageJobId,
             "requestedAt" = @requestedAt,
             "answeredAt" = @answeredAt,
             "createdAt" = @createdAt,
             "version" = @version
           WHERE "clarificationId" = @clarificationId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._clarificationParams(clarification),
          'version': clarification.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;
      throw ConcurrentModificationException(
        entityId: clarification.clarificationId,
        expectedVersion: expectedVersion,
        actualVersion: 0,
      );
    }
    await _db.execute(
      '''INSERT INTO "defect_clarification" (
           "clarificationId", "defectId", "question", "reason",
           "status", "answer", "humanDecisionId",
           "requestedByTriageJobId", "requestedAt", "answeredAt", "createdAt", "version"
         ) VALUES (
           @clarificationId, @defectId, @question, @reason,
           @status, @answer, @humanDecisionId,
           @requestedByTriageJobId, @requestedAt, @answeredAt, @createdAt, @version
         )
         ON CONFLICT ("clarificationId") DO UPDATE SET
           "defectId" = EXCLUDED."defectId",
           "question" = EXCLUDED."question",
           "reason" = EXCLUDED."reason",
           "status" = EXCLUDED."status",
           "answer" = EXCLUDED."answer",
           "humanDecisionId" = EXCLUDED."humanDecisionId",
           "requestedByTriageJobId" = EXCLUDED."requestedByTriageJobId",
           "requestedAt" = EXCLUDED."requestedAt",
           "answeredAt" = EXCLUDED."answeredAt",
           "createdAt" = EXCLUDED."createdAt",
           "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_clarificationParams(clarification)),
    );
  }

  @override
  Future<DefectClarification?> readClarification(String clarificationId) async {
    final rows = await _db.query(
      'SELECT * FROM "defect_clarification" WHERE "clarificationId" = @clarificationId',
      parameters: QueryParameters.named({'clarificationId': clarificationId}),
    );
    if (rows.isEmpty) return null;
    return _clarificationFromRow(rows.first);
  }

  @override
  Future<List<DefectClarification>> readClarificationsForDefect(
    String defectId,
  ) async {
    final rows = await _db.query(
      'SELECT * FROM "defect_clarification" WHERE "defectId" = @defectId ORDER BY "createdAt" ASC',
      parameters: QueryParameters.named({'defectId': defectId}),
    );
    return rows.map<DefectClarification>(_clarificationFromRow).toList();
  }

  // ---------------------------------------------------------------------
  // Triage linkage
  // ---------------------------------------------------------------------

  @override
  Future<void> setTriageJob(String defectId, String? jobId) async {
    await _db.execute(
      '''UPDATE "defect" SET
           "currentTriageJobId" = @jobId,
           "updatedAt" = @updatedAt,
           "version" = "version" + 1
         WHERE "defectId" = @defectId''',
      parameters: QueryParameters.named({
        'defectId': defectId,
        'jobId': jobId,
        'updatedAt': DateTime.now().toUtc(),
      }),
    );
  }

  // ---------------------------------------------------------------------
  // TriageResult
  // ---------------------------------------------------------------------
  //
  // `DefectStore` declares these four methods, so `PostgresDefectStore` has to
  // implement them. It does not *own* them: every call is forwarded to
  // [PostgresTriageStore], which holds the only `triage_result` writer and the
  // only `triage_result` decoder in the codebase. Both stores are constructed
  // over the same [PersistenceDatabase] instance, so delegation preserves the
  // single active transaction slot — a `defectStore.inTransaction(...)` body
  // that writes a `Defect` and a `TriageResult` still commits atomically.
  //
  // A previous revision of this class carried its own copy of the SQL, the
  // parameter binding and the row decoder. That copy bound raw Dart `List`
  // values to the `json` columns and read `clarificationRequired` as a `List`
  // from a `text` column, so a row written by one store could not be read by
  // the other. It was dead code with no callers.

  /// The single owner of the `"triage_result"` table.
  PostgresTriageStore get _triageStore => PostgresTriageStore(_db);

  @override
  Future<void> saveTriageResult(TriageResult result, {int? expectedVersion}) {
    return _triageStore.saveTriageResult(
      result,
      expectedVersion: expectedVersion,
    );
  }

  @override
  Future<TriageResult?> readTriageResult(String resultId) {
    return _triageStore.readTriageResult(resultId);
  }

  @override
  Future<List<TriageResult>> readTriageResultsForDefect(String defectId) {
    return _triageStore.readTriageResultsForDefect(defectId);
  }

  @override
  Future<TriageResult?> readTriageResultForJob(String jobId) {
    return _triageStore.readTriageResultForJob(jobId);
  }

  // ---------------------------------------------------------------------
  // Row mapping
  // ---------------------------------------------------------------------

  Map<String, dynamic> _defectParams(Defect d) => {
    'defectId': d.defectId,
    'title': d.title,
    'description': d.description,
    'expectedBehavior': d.expectedBehavior,
    'reproductionSteps': d.reproductionSteps,
    'severity': d.severity,
    'status': d.status.wire,
    'classification': d.classification?.wire,
    'reporter': d.reporter,
    'productId': d.productId,
    'affectedWorkItemId': d.affectedWorkItemId,
    'affectedRunId': d.affectedRunId,
    'remediationWorkItemId': d.remediationWorkItemId,
    'duplicateOfDefectId': d.duplicateOfDefectId,
    'currentTriageJobId': d.currentTriageJobId,
    'clientContextJson': d.clientContextJson,
    'metadataJson': d.metadataJson,
    'createdAt': d.createdAt,
    'updatedAt': d.updatedAt,
    'resolvedAt': d.resolvedAt,
    'closedAt': d.closedAt,
    'version': d.version,
  };

  Defect _defectFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return Defect(
      defectId: m['defectId'] as String,
      title: m['title'] as String,
      description: m['description'] as String,
      expectedBehavior: m['expectedBehavior'] as String?,
      reproductionSteps: m['reproductionSteps'] as String?,
      severity: m['severity'] as String,
      status: DefectStatus.fromWire(m['status'] as String),
      classification: m['classification'] == null
          ? null
          : DefectClassification.fromWire(m['classification'] as String),
      reporter: m['reporter'] as String,
      productId: m['productId'] as String?,
      affectedWorkItemId: m['affectedWorkItemId'] as String?,
      affectedRunId: m['affectedRunId'] as String?,
      remediationWorkItemId: m['remediationWorkItemId'] as String?,
      duplicateOfDefectId: m['duplicateOfDefectId'] as String?,
      currentTriageJobId: m['currentTriageJobId'] as String?,
      clientContextJson: m['clientContextJson'] as String?,
      metadataJson: m['metadataJson'] as String?,

      createdAt: decodeUtc(m['createdAt'])!,
      updatedAt: decodeUtc(m['updatedAt'])!,
      resolvedAt: decodeUtc(m['resolvedAt']),
      closedAt: decodeUtc(m['closedAt']),
      version: m['version'] as int,
    );
  }

  Map<String, dynamic> _evidenceParams(DefectEvidence e) => {
    'evidenceId': e.evidenceId,
    'defectId': e.defectId,
    'kind': e.kind.wire,
    'artifactId': e.artifactId,
    'contentHash': e.contentHash,
    'description': e.description,
    'sourceRef': e.sourceRef,
    'capturedAt': e.capturedAt,
    'createdAt': e.createdAt,
    'version': e.version,
  };

  DefectEvidence _evidenceFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DefectEvidence(
      evidenceId: m['evidenceId'] as String,
      defectId: m['defectId'] as String,
      kind: EvidenceIntakeKind.fromWire(m['kind'] as String),
      artifactId: m['artifactId'] as String?,
      contentHash: m['contentHash'] as String?,
      description: m['description'] as String?,
      sourceRef: m['sourceRef'] as String?,
      capturedAt: decodeUtc(m['capturedAt'])!,

      createdAt: decodeUtc(m['createdAt'])!,
      version: m['version'] as int,
    );
  }

  Map<String, dynamic> _eventParams(DefectEvent e) => {
    'eventId': e.eventId,
    'defectId': e.defectId,
    'sequence': e.sequence,
    'type': e.type.wire,
    'fromStatus': e.fromStatus?.wire,
    'toStatus': e.toStatus?.wire,
    'actorType': e.actorType.wire,
    'actorId': e.actorId,
    'payloadJson': e.payloadJson,
    'occurredAt': e.occurredAt,
  };

  DefectEvent _eventFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DefectEvent(
      eventId: m['eventId'] as String,
      defectId: m['defectId'] as String,
      sequence: m['sequence'] as int,
      type: DefectEventType.fromWire(m['type'] as String),
      fromStatus: m['fromStatus'] == null
          ? null
          : DefectStatus.fromWire(m['fromStatus'] as String),
      toStatus: m['toStatus'] == null
          ? null
          : DefectStatus.fromWire(m['toStatus'] as String),
      actorType: ActorType.fromWire(m['actorType'] as String),
      actorId: m['actorId'] as String?,
      payloadJson: m['payloadJson'] as String?,
      occurredAt: decodeUtc(m['occurredAt'])!,
    );
  }

  Map<String, dynamic> _clarificationParams(DefectClarification c) => {
    'clarificationId': c.clarificationId,
    'defectId': c.defectId,
    'question': c.question,
    'reason': c.reason,
    'status': c.status.wire,
    'answer': c.answer,
    'humanDecisionId': c.humanDecisionId,
    'requestedByTriageJobId': c.requestedByTriageJobId,
    'requestedAt': c.requestedAt,
    'answeredAt': c.answeredAt,
    'createdAt': c.createdAt,
    'version': c.version,
  };

  DefectClarification _clarificationFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DefectClarification(
      clarificationId: m['clarificationId'] as String,
      defectId: m['defectId'] as String,
      question: m['question'] as String,
      reason: m['reason'] as String,
      status: ClarificationStatus.fromWire(m['status'] as String),
      answer: m['answer'] as String?,
      humanDecisionId: m['humanDecisionId'] as String?,
      requestedByTriageJobId: m['requestedByTriageJobId'] as String?,
      requestedAt: decodeUtc(m['requestedAt'])!,
      answeredAt: decodeUtc(m['answeredAt']),
      createdAt: decodeUtc(m['createdAt'])!,
      version: m['version'] as int,
    );
  }
}

/// Exception thrown when a defect is not found.
class DefectNotFoundException implements Exception {
  final String defectId;
  DefectNotFoundException(this.defectId);
  @override
  String toString() => 'Defect not found: $defectId';
}

/// Exception thrown when a concurrent modification is detected.
class ConcurrentModificationException implements Exception {
  final String entityId;
  final int expectedVersion;
  final int actualVersion;
  ConcurrentModificationException({
    required this.entityId,
    required this.expectedVersion,
    required this.actualVersion,
  });
  @override
  String toString() =>
      'Concurrent modification of $entityId: expected version $expectedVersion, actual $actualVersion';
}

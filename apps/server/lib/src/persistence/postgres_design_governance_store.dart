import 'package:design_governance/design_governance.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of all design governance store interfaces.
class PostgresDesignGovernanceStore implements DesignGovernanceStore {
  PostgresDesignGovernanceStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(Future<T> Function(DesignGovernanceStore store) body) {
    return _db.inTransaction<T>(() => body(this));
  }

  // DesignRevisionStore

  @override
  Future<DesignRevision> readDesignRevision(String revisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_revision" WHERE "revisionId" = @revisionId''',
      parameters: QueryParameters.named({'revisionId': revisionId}),
    );
    if (result.isEmpty) {
      throw DesignRevisionNotFoundException(revisionId);
    }
    return _designRevisionFromRow(result[0]);
  }

  @override
  Future<List<DesignRevision>> readDesignRevisionsForWorkItem(String workItemId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_revision" WHERE "workItemId" = @workItemId ORDER BY "createdAt" ASC''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return result.map(_designRevisionFromRow).toList();
  }

  @override
  Future<DesignRevision?> readApprovedDesignRevisionForWorkItem(String workItemId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_revision"
         WHERE "workItemId" = @workItemId AND "status" = @status''',
      parameters: QueryParameters.named({
        'workItemId': workItemId,
        'status': DesignRevisionStatus.approved.wire,
      }),
    );
    if (result.isEmpty) return null;
    return _designRevisionFromRow(result[0]);
  }

  @override
  Future<DesignRevision?> readLatestDesignRevisionForWorkItem(String workItemId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_revision"
         WHERE "workItemId" = @workItemId
         ORDER BY "createdAt" DESC LIMIT 1''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    if (result.isEmpty) return null;
    return _designRevisionFromRow(result[0]);
  }

  @override
  Future<void> saveDesignRevision(DesignRevision revision, {int? expectedVersion}) async {
    const bareInsert = '''INSERT INTO "design_revision" (
           "revisionId", "workItemId", "productId", "parentRevisionId",
           "designSystemRevision", "providerType", "penpotFileId", "penpotPageId",
           "boardIdsJson", "responsiveTargetsJson", "statesRepresentedJson",
           "artifactRefsJson", "designerExecutionId", "reviewExecutionIdsJson",
           "status", "riskTier", "reviewScopeJson", "carriedForwardFromRevisionId",
           "supersededByRevisionId", "createdAt", "updatedAt", "approvedAt", "version"
         ) VALUES (
           @revisionId, @workItemId, @productId, @parentRevisionId,
           @designSystemRevision, @providerType, @penpotFileId, @penpotPageId,
           @boardIdsJson, @responsiveTargetsJson, @statesRepresentedJson,
           @artifactRefsJson, @designerExecutionId, @reviewExecutionIdsJson,
           @status, @riskTier, @reviewScopeJson, @carriedForwardFromRevisionId,
           @supersededByRevisionId, @createdAt, @updatedAt, @approvedAt, @version
         )''';

    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "design_revision" SET
             "workItemId" = @workItemId,
             "productId" = @productId,
             "parentRevisionId" = @parentRevisionId,
             "designSystemRevision" = @designSystemRevision,
             "providerType" = @providerType,
             "penpotFileId" = @penpotFileId,
             "penpotPageId" = @penpotPageId,
             "boardIdsJson" = @boardIdsJson,
             "responsiveTargetsJson" = @responsiveTargetsJson,
             "statesRepresentedJson" = @statesRepresentedJson,
             "artifactRefsJson" = @artifactRefsJson,
             "designerExecutionId" = @designerExecutionId,
             "reviewExecutionIdsJson" = @reviewExecutionIdsJson,
             "status" = @status,
             "riskTier" = @riskTier,
             "reviewScopeJson" = @reviewScopeJson,
             "carriedForwardFromRevisionId" = @carriedForwardFromRevisionId,
             "supersededByRevisionId" = @supersededByRevisionId,
             "createdAt" = @createdAt,
             "updatedAt" = @updatedAt,
             "approvedAt" = @approvedAt,
             "version" = @version
           WHERE "revisionId" = @revisionId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._designRevisionToParams(revision),
          'version': revision.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) {
        return;
      }

      final rows = await _db.query(
        'SELECT "version" FROM "design_revision" WHERE "revisionId" = @revisionId',
        parameters: QueryParameters.named({'revisionId': revision.revisionId}),
      );
      final actual = rows.isEmpty ? 0 : rows[0].toColumnMap()['version'] as int;
      if (rows.isEmpty && expectedVersion == 0) {
        final inserted = await _db.execute(
          '$bareInsert ON CONFLICT ("revisionId") DO NOTHING',
          parameters: QueryParameters.named(_designRevisionToParams(revision)),
        );
        if (inserted == 1) {
          return;
        }
        final current = await _db.query(
          'SELECT "version" FROM "design_revision" WHERE "revisionId" = @revisionId',
          parameters: QueryParameters.named({'revisionId': revision.revisionId}),
        );
        throw DesignGovernanceConcurrentModificationException(
          entityId: revision.revisionId,
          expectedVersion: 0,
          actualVersion: current.isEmpty ? 0 : (current[0].toColumnMap()['version'] as int),
        );
      }
      throw DesignGovernanceConcurrentModificationException(
        entityId: revision.revisionId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }

    await _db.execute(
      '''$bareInsert ON CONFLICT ("revisionId") DO UPDATE SET
             "workItemId" = EXCLUDED."workItemId",
             "productId" = EXCLUDED."productId",
             "parentRevisionId" = EXCLUDED."parentRevisionId",
             "designSystemRevision" = EXCLUDED."designSystemRevision",
             "providerType" = EXCLUDED."providerType",
             "penpotFileId" = EXCLUDED."penpotFileId",
             "penpotPageId" = EXCLUDED."penpotPageId",
             "boardIdsJson" = EXCLUDED."boardIdsJson",
             "responsiveTargetsJson" = EXCLUDED."responsiveTargetsJson",
             "statesRepresentedJson" = EXCLUDED."statesRepresentedJson",
             "artifactRefsJson" = EXCLUDED."artifactRefsJson",
             "designerExecutionId" = EXCLUDED."designerExecutionId",
             "reviewExecutionIdsJson" = EXCLUDED."reviewExecutionIdsJson",
             "status" = EXCLUDED."status",
             "riskTier" = EXCLUDED."riskTier",
             "reviewScopeJson" = EXCLUDED."reviewScopeJson",
             "carriedForwardFromRevisionId" = EXCLUDED."carriedForwardFromRevisionId",
             "supersededByRevisionId" = EXCLUDED."supersededByRevisionId",
             "createdAt" = EXCLUDED."createdAt",
             "updatedAt" = EXCLUDED."updatedAt",
             "approvedAt" = EXCLUDED."approvedAt",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_designRevisionToParams(revision)),
    );
  }

  @override
  Future<List<DesignRevision>> getLineage(String revisionId) async {
    final lineage = <DesignRevision>[];
    var currentId = revisionId;

    while (currentId.isNotEmpty) {
      final result = await _db.query(
        'SELECT * FROM "design_revision" WHERE "revisionId" = @revisionId',
        parameters: QueryParameters.named({'revisionId': currentId}),
      );
      if (result.isEmpty) break;
      final revision = _designRevisionFromRow(result[0]);
      lineage.add(revision);
      currentId = revision.parentRevisionId ?? '';
    }

    return lineage.reversed.toList();
  }

  @override
  Future<DesignRevision?> findDesignRevisionByIdempotencyKey(String workItemId, String idempotencyKey) async {
    // Idempotency key would be stored in reviewScopeJson or a separate tracking column
    // Placeholder - returns null for now
    return null;
  }

  // DesignReviewResultStore

  @override
  Future<DesignReviewResult> readDesignReviewResult(String reviewResultId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_review_result" WHERE "reviewExecutionId" = @reviewExecutionId''',
      parameters: QueryParameters.named({'reviewExecutionId': reviewResultId}),
    );
    if (result.isEmpty) {
      throw DesignReviewResultNotFoundException(reviewResultId);
    }
    return _designReviewResultFromRow(result[0]);
  }

  @override
  Future<List<DesignReviewResult>> readDesignReviewResultsForRevision(String revisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_review_result" WHERE "revisionId" = @revisionId''',
      parameters: QueryParameters.named({'revisionId': revisionId}),
    );
    return result.map(_designReviewResultFromRow).toList();
  }

  @override
  Future<DesignReviewResult?> readDesignReviewResultForExecution(
    String revisionId,
    String reviewExecutionId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "design_review_result"
         WHERE "revisionId" = @revisionId AND "reviewExecutionId" = @reviewExecutionId''',
      parameters: QueryParameters.named({
        'revisionId': revisionId,
        'reviewExecutionId': reviewExecutionId,
      }),
    );
    if (result.isEmpty) return null;
    return _designReviewResultFromRow(result[0]);
  }

  @override
  Future<void> saveDesignReviewResult(DesignReviewResult result, {int? expectedVersion}) async {
    const bareInsert = '''INSERT INTO "design_review_result" (
           "reviewResultId", "revisionId", "reviewExecutionId", "verdict",
           "findingsJson", "assessedDimensionsJson", "reviewScopeJson", "createdAt", "version"
         ) VALUES (
           @reviewResultId, @revisionId, @reviewExecutionId, @verdict,
           @findingsJson, @assessedDimensionsJson, @reviewScopeJson, @createdAt, @version
         )''';

    if (expectedVersion != null) {
      await _db.inTransaction(() async {
        final existing = await _db.query(
          'SELECT * FROM "design_review_result" WHERE "reviewExecutionId" = @reviewExecutionId',
          parameters: QueryParameters.named({'reviewExecutionId': result.reviewExecutionId}),
        );
        if (existing.isNotEmpty && (existing[0].toColumnMap()['version'] as int) != expectedVersion) {
          throw DesignGovernanceConcurrentModificationException(
            entityId: result.reviewExecutionId,
            expectedVersion: expectedVersion,
            actualVersion: existing[0].toColumnMap()['version'] as int,
          );
        }
        await _db.execute(
          '''$bareInsert ON CONFLICT ("reviewExecutionId") DO UPDATE SET
                 "revisionId" = EXCLUDED."revisionId",
                 "verdict" = EXCLUDED."verdict",
                 "findingsJson" = EXCLUDED."findingsJson",
                 "assessedDimensionsJson" = EXCLUDED."assessedDimensionsJson",
                 "reviewScopeJson" = EXCLUDED."reviewScopeJson",
                 "createdAt" = EXCLUDED."createdAt",
                 "version" = EXCLUDED."version"''',
          parameters: QueryParameters.named(_designReviewResultToParams(result)),
        );
      });
    } else {
      await _db.execute(
        '''$bareInsert ON CONFLICT ("reviewExecutionId") DO UPDATE SET
               "revisionId" = EXCLUDED."revisionId",
               "verdict" = EXCLUDED."verdict",
               "findingsJson" = EXCLUDED."findingsJson",
               "assessedDimensionsJson" = EXCLUDED."assessedDimensionsJson",
               "reviewScopeJson" = EXCLUDED."reviewScopeJson",
               "createdAt" = EXCLUDED."createdAt",
               "version" = EXCLUDED."version"''',
        parameters: QueryParameters.named(_designReviewResultToParams(result)),
      );
    }
  }

  @override
  Future<DesignReviewResult?> findDesignReviewResultByIdempotencyKey(String revisionId, String idempotencyKey) async {
    // Placeholder
    return null;
  }

  // DesignFindingStore

  @override
  Future<DesignFinding> readDesignFinding(String findingId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_finding" WHERE "findingId" = @findingId''',
      parameters: QueryParameters.named({'findingId': findingId}),
    );
    if (result.isEmpty) {
      throw DesignFindingNotFoundException(findingId);
    }
    return _designFindingFromRow(result[0]);
  }

  @override
  Future<List<DesignFinding>> readDesignFindingsForRevision(String revisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_finding" WHERE "revisionId" = @revisionId''',
      parameters: QueryParameters.named({'revisionId': revisionId}),
    );
    return result.map(_designFindingFromRow).toList();
  }

  @override
  Future<List<DesignFinding>> readDesignFindingsForReviewExecution(String reviewExecutionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_finding" WHERE "reviewExecutionId" = @reviewExecutionId''',
      parameters: QueryParameters.named({'reviewExecutionId': reviewExecutionId}),
    );
    return result.map(_designFindingFromRow).toList();
  }

  @override
  Future<List<DesignFinding>> readUnresolvedFindingsForRevision(String revisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_finding"
         WHERE "revisionId" = @revisionId AND "resolvedByRevisionId" IS NULL''',
      parameters: QueryParameters.named({'revisionId': revisionId}),
    );
    return result.map(_designFindingFromRow).toList();
  }

  @override
  Future<List<DesignFinding>> readFindingsResolvedByRevision(String revisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_finding" WHERE "resolvedByRevisionId" = @revisionId''',
      parameters: QueryParameters.named({'revisionId': revisionId}),
    );
    return result.map(_designFindingFromRow).toList();
  }

  @override
  Future<void> saveDesignFinding(DesignFinding finding, {int? expectedVersion}) async {
    const bareInsert = '''INSERT INTO "design_finding" (
           "findingId", "revisionId", "reviewExecutionId", "category", "severity",
           "dimension", "evidence", "requiredCorrection", "affectedSurface",
           "resolvedByRevisionId", "createdAt", "version"
         ) VALUES (
           @findingId, @revisionId, @reviewExecutionId, @category, @severity,
           @dimension, @evidence, @requiredCorrection, @affectedSurface,
           @resolvedByRevisionId, @createdAt, @version
         )''';

    if (expectedVersion != null) {
      await _db.inTransaction(() async {
        final existing = await _db.query(
          'SELECT * FROM "design_finding" WHERE "findingId" = @findingId',
          parameters: QueryParameters.named({'findingId': finding.findingId}),
        );
        if (existing.isNotEmpty && (existing[0].toColumnMap()['version'] as int) != expectedVersion) {
          throw DesignGovernanceConcurrentModificationException(
            entityId: finding.findingId,
            expectedVersion: expectedVersion,
            actualVersion: existing[0].toColumnMap()['version'] as int,
          );
        }
        await _db.execute(
          '''$bareInsert ON CONFLICT ("findingId") DO UPDATE SET
                 "revisionId" = EXCLUDED."revisionId",
                 "reviewExecutionId" = EXCLUDED."reviewExecutionId",
                 "category" = EXCLUDED."category",
                 "severity" = EXCLUDED."severity",
                 "dimension" = EXCLUDED."dimension",
                 "evidence" = EXCLUDED."evidence",
                 "requiredCorrection" = EXCLUDED."requiredCorrection",
                 "affectedSurface" = EXCLUDED."affectedSurface",
                 "resolvedByRevisionId" = EXCLUDED."resolvedByRevisionId",
                 "createdAt" = EXCLUDED."createdAt",
                 "version" = EXCLUDED."version"''',
          parameters: QueryParameters.named(_designFindingToParams(finding)),
        );
      });
    } else {
      await _db.execute(
        '''$bareInsert ON CONFLICT ("findingId") DO UPDATE SET
               "revisionId" = EXCLUDED."revisionId",
               "reviewExecutionId" = EXCLUDED."reviewExecutionId",
               "category" = EXCLUDED."category",
               "severity" = EXCLUDED."severity",
               "dimension" = EXCLUDED."dimension",
               "evidence" = EXCLUDED."evidence",
               "requiredCorrection" = EXCLUDED."requiredCorrection",
               "affectedSurface" = EXCLUDED."affectedSurface",
               "resolvedByRevisionId" = EXCLUDED."resolvedByRevisionId",
               "createdAt" = EXCLUDED."createdAt",
               "version" = EXCLUDED."version"''',
        parameters: QueryParameters.named(_designFindingToParams(finding)),
      );
    }
  }

  @override
  Future<DesignFinding?> findDesignFindingByIdempotencyKey(String revisionId, String idempotencyKey) async {
    // Placeholder
    return null;
  }

  // DesignRevisionEventStore

  @override
  Future<void> appendEvent(DesignRevisionEvent event) async {
    await _db.execute(
      '''INSERT INTO "design_revision_event" (
             "eventId", "designRevisionId", "eventType", "payloadJson", "sequence", "createdAt"
           ) VALUES (
             @eventId, @designRevisionId, @eventType, @payloadJson, @sequence, @createdAt
           )''',
      parameters: QueryParameters.named(_designRevisionEventToParams(event)),
    );
  }

  @override
  Future<List<DesignRevisionEvent>> readEventsForRevision(String designRevisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_revision_event"
         WHERE "designRevisionId" = @designRevisionId
         ORDER BY "sequence" ASC''',
      parameters: QueryParameters.named({'designRevisionId': designRevisionId}),
    );
    return result.map(_designRevisionEventFromRow).toList();
  }

  @override
  Future<List<DesignRevisionEvent>> readEventsAfterSequence(
    String designRevisionId,
    int sequence,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "design_revision_event"
         WHERE "designRevisionId" = @designRevisionId AND "sequence" > @sequence
         ORDER BY "sequence" ASC''',
      parameters: QueryParameters.named({
        'designRevisionId': designRevisionId,
        'sequence': sequence,
      }),
    );
    return result.map(_designRevisionEventFromRow).toList();
  }

  @override
  Future<DesignRevisionEvent?> readLastEventForRevision(String designRevisionId) async {
    final result = await _db.query(
      '''SELECT * FROM "design_revision_event"
         WHERE "designRevisionId" = @designRevisionId
         ORDER BY "sequence" DESC LIMIT 1''',
      parameters: QueryParameters.named({'designRevisionId': designRevisionId}),
    );
    if (result.isEmpty) return null;
    return _designRevisionEventFromRow(result[0]);
  }

  // Row mappers

  DesignRevision _designRevisionFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DesignRevision(
      revisionId: m['revisionId'] as String,
      workItemId: m['workItemId'] as String,
      productId: m['productId'] as String,
      parentRevisionId: m['parentRevisionId'] as String?,
      designSystemRevision: m['designSystemRevision'] as String,
      provider: DesignProviderType.fromWire(m['providerType'] as String),
      penpotFileId: m['penpotFileId'] as String?,
      penpotPageId: m['penpotPageId'] as String?,
      boardIdsJson: m['boardIdsJson'] as String,
      responsiveTargetsJson: m['responsiveTargetsJson'] as String,
      statesRepresentedJson: m['statesRepresentedJson'] as String,
      artifactRefsJson: m['artifactRefsJson'] as String,
      designerExecutionId: m['designerExecutionId'] as String,
      reviewExecutionIdsJson: m['reviewExecutionIdsJson'] as String,
      status: DesignRevisionStatus.fromWire(m['status'] as String),
      riskTier: DesignRiskTier.fromWire(m['riskTier'] as String),
      reviewScopeJson: decodeJsonMap(m['reviewScopeJson'] as String?),
      carriedForwardFromRevisionId: m['carriedForwardFromRevisionId'] as String?,
      supersededByRevisionId: m['supersededByRevisionId'] as String?,
      createdAt: decodeUtc(m['createdAt'])!,
      updatedAt: decodeUtc(m['updatedAt'])!,
      approvedAt: decodeUtc(m['approvedAt']),
      version: m['version'] as int,
    );
  }

  Map<String, Object?> _designRevisionToParams(DesignRevision revision) {
    final json = revision.toJson();
    return {
      'revisionId': json['revisionId'],
      'workItemId': json['workItemId'],
      'productId': json['productId'],
      'parentRevisionId': json['parentRevisionId'],
      'designSystemRevision': json['designSystemRevision'],
      'providerType': json['provider'],
      'penpotFileId': json['penpotFileId'],
      'penpotPageId': json['penpotPageId'],
      'boardIdsJson': json['boardIdsJson'],
      'responsiveTargetsJson': json['responsiveTargetsJson'],
      'statesRepresentedJson': json['statesRepresentedJson'],
      'artifactRefsJson': json['artifactRefsJson'],
      'designerExecutionId': json['designerExecutionId'],
      'reviewExecutionIdsJson': json['reviewExecutionIdsJson'],
      'status': json['status'],
      'riskTier': json['riskTier'],
      'reviewScopeJson': PersistenceDatabase.encodeJson(json['reviewScopeJson']),
      'carriedForwardFromRevisionId': json['carriedForwardFromRevisionId'],
      'supersededByRevisionId': json['supersededByRevisionId'],
      'createdAt': PersistenceDatabase.toUtc(revision.createdAt),
      'updatedAt': PersistenceDatabase.toUtc(revision.updatedAt),
      'approvedAt': PersistenceDatabase.toUtc(revision.approvedAt),
      'version': revision.version,
    };
  }

  DesignReviewResult _designReviewResultFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DesignReviewResult(
      reviewExecutionId: m['reviewExecutionId'] as String,
      revisionId: m['revisionId'] as String,
      verdict: DesignReviewVerdict.fromWire(m['verdict'] as String),
      findings: decodeJsonArray(m['findingsJson'] as String?)
          ?.map((e) => DesignFinding.fromJson(e as Map<String, dynamic>))
          .toList(growable: false) ??
          const <DesignFinding>[],
      assessedDimensions: (decodeJsonArray(m['assessedDimensionsJson'] as String?)
              ?.map((e) => e as String)
              .toList(growable: false) ??
              const <String>[]),
      reviewScopeJson: decodeJsonMap(m['reviewScopeJson'] as String?),
      createdAt: decodeUtc(m['createdAt'])!,
      version: m['version'] as int,
    );
  }

  Map<String, Object?> _designReviewResultToParams(DesignReviewResult result) {
    final json = result.toJson();
    return {
      'reviewResultId': json['reviewExecutionId'], // Using reviewExecutionId as primary key
      'revisionId': json['revisionId'],
      'reviewExecutionId': json['reviewExecutionId'],
      'verdict': json['verdict'],
      'findingsJson': PersistenceDatabase.encodeJson(
        result.findings.map((f) => f.toJson()).toList(),
      ),
      'assessedDimensionsJson': PersistenceDatabase.encodeJson(result.assessedDimensions),
      'reviewScopeJson': PersistenceDatabase.encodeJson(json['reviewScopeJson']),
      'createdAt': PersistenceDatabase.toUtc(result.createdAt),
      'version': result.version,
    };
  }

  DesignFinding _designFindingFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DesignFinding(
      findingId: m['findingId'] as String,
      revisionId: m['revisionId'] as String,
      reviewExecutionId: m['reviewExecutionId'] as String,
      category: DesignFindingCategory.fromWire(m['category'] as String),
      severity: DesignFindingSeverity.fromWire(m['severity'] as String),
      dimension: m['dimension'] as String,
      evidence: m['evidence'] as String,
      requiredCorrection: m['requiredCorrection'] as String,
      affectedSurface: m['affectedSurface'] as String,
      resolvedByRevisionId: m['resolvedByRevisionId'] as String?,
      createdAt: decodeUtc(m['createdAt'])!,
      version: m['version'] as int,
    );
  }

  Map<String, Object?> _designFindingToParams(DesignFinding finding) {
    final json = finding.toJson();
    return {
      'findingId': json['findingId'],
      'revisionId': json['revisionId'],
      'reviewExecutionId': json['reviewExecutionId'],
      'category': json['category'],
      'severity': json['severity'],
      'dimension': json['dimension'],
      'evidence': json['evidence'],
      'requiredCorrection': json['requiredCorrection'],
      'affectedSurface': json['affectedSurface'],
      'resolvedByRevisionId': json['resolvedByRevisionId'],
      'createdAt': PersistenceDatabase.toUtc(finding.createdAt),
      'version': finding.version,
    };
  }

  DesignRevisionEvent _designRevisionEventFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return DesignRevisionEvent(
      eventId: m['eventId'] as String,
      designRevisionId: m['designRevisionId'] as String,
      eventType: m['eventType'] as String,
      payloadJson: m['payloadJson'] as String,
      sequence: m['sequence'] as int,
      createdAt: decodeUtc(m['createdAt'])!,
    );
  }

  Map<String, Object?> _designRevisionEventToParams(DesignRevisionEvent event) {
    final json = event.toJson();
    return {
      'eventId': json['eventId'],
      'designRevisionId': json['designRevisionId'],
      'eventType': json['eventType'],
      'payloadJson': json['payloadJson'],
      'sequence': json['sequence'],
      'createdAt': PersistenceDatabase.toUtc(event.createdAt),
    };
  }
}
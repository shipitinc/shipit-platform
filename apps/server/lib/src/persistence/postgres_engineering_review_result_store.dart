import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [EngineeringReviewResultStore].
class PostgresEngineeringReviewResultStore {
  PostgresEngineeringReviewResultStore(this._db);

  final PersistenceDatabase _db;

  Future<T> inTransaction<T>(
    Future<T> Function(PostgresEngineeringReviewResultStore store) body,
  ) {
    return _db.inTransaction<T>(() => body(this));
  }

  Future<EngineeringReviewResult> readEngineeringReviewResult(
    String reviewExecutionId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "engineering_review_result"
         WHERE "reviewExecutionId" = @reviewExecutionId''',
      parameters: QueryParameters.named({
        'reviewExecutionId': reviewExecutionId,
      }),
    );
    if (result.isEmpty) {
      throw EngineeringReviewResultNotFoundException(reviewExecutionId);
    }
    return _fromRow(result[0]);
  }

  Future<List<EngineeringReviewResult>> readEngineeringReviewResultsForWorkItem(
    String workItemId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "engineering_review_result"
         WHERE "workItemId" = @workItemId''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return result.map(_fromRow).toList();
  }

  Future<void> saveEngineeringReviewResult(
    EngineeringReviewResult result, {
    int? expectedVersion,
  }) async {
    const bareInsert = '''INSERT INTO "engineering_review_result"
           ("reviewExecutionId", "workItemId", "verdict", "findingsJson",
            "assessedDimensionsJson", "reviewScopeJson", "createdAt", "version",
            "reviewerRole")
         VALUES
           (@reviewExecutionId, @workItemId, @verdict, @findingsJson,
            @assessedDimensionsJson, @reviewScopeJson, @createdAt, @version,
            @reviewerRole)''';

    if (expectedVersion != null) {
      await _db.inTransaction(() async {
        final existing = await _db.query(
          'SELECT * FROM "engineering_review_result" WHERE "reviewExecutionId" = @reviewExecutionId',
          parameters: QueryParameters.named({
            'reviewExecutionId': result.reviewExecutionId,
          }),
        );
        if (existing.isNotEmpty &&
            (existing[0].toColumnMap()['version'] as int) != expectedVersion) {
          throw PostgresConcurrentModificationException(
            entityId: result.reviewExecutionId,
            expectedVersion: expectedVersion,
            actualVersion: existing[0].toColumnMap()['version'] as int,
          );
        }
        await _db.execute(
          '''$bareInsert ON CONFLICT ("reviewExecutionId") DO UPDATE SET
                 "workItemId" = EXCLUDED."workItemId",
                 "verdict" = EXCLUDED."verdict",
                 "findingsJson" = EXCLUDED."findingsJson",
                 "assessedDimensionsJson" = EXCLUDED."assessedDimensionsJson",
                 "reviewScopeJson" = EXCLUDED."reviewScopeJson",
                 "createdAt" = EXCLUDED."createdAt",
                 "version" = EXCLUDED."version",
                 "reviewerRole" = EXCLUDED."reviewerRole"''',
          parameters: QueryParameters.named(_toParams(result)),
        );
      });
    } else {
      await _db.execute(
        '''$bareInsert ON CONFLICT ("reviewExecutionId") DO UPDATE SET
               "workItemId" = EXCLUDED."workItemId",
               "verdict" = EXCLUDED."verdict",
               "findingsJson" = EXCLUDED."findingsJson",
               "assessedDimensionsJson" = EXCLUDED."assessedDimensionsJson",
               "reviewScopeJson" = EXCLUDED."reviewScopeJson",
               "createdAt" = EXCLUDED."createdAt",
               "version" = EXCLUDED."version",
               "reviewerRole" = EXCLUDED."reviewerRole"''',
        parameters: QueryParameters.named(_toParams(result)),
      );
    }
  }

  Future<EngineeringReviewResult?> findEngineeringReviewResultByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) async {
    // Placeholder - not implemented
    return null;
  }

  EngineeringReviewResult _fromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return EngineeringReviewResult(
      reviewExecutionId: m['reviewExecutionId'] as String,
      workItemId: m['workItemId'] as String,
      verdict: ReviewVerdict.fromWire(m['verdict'] as String),
      findings: (jsonDecode(m['findingsJson'] as String) as List)
          .map((e) => DesignFinding.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      assessedDimensions:
          (jsonDecode(m['assessedDimensionsJson'] as String) as List)
              .map((e) => e as String)
              .toList(growable: false),
      reviewScopeJson: m['reviewScopeJson'] == null
          ? null
          : jsonDecode(m['reviewScopeJson'] as String) as Map<String, dynamic>,
      createdAt: decodeUtc(m['createdAt'])!,
      version: m['version'] as int,
      reviewerRole: AgentRole.fromWire(m['reviewerRole'] as String),
    );
  }

  Map<String, Object?> _toParams(EngineeringReviewResult result) {
    return {
      'reviewExecutionId': result.reviewExecutionId,
      'workItemId': result.workItemId,
      'verdict': result.verdict.wire,
      'findingsJson': jsonEncode(
        result.findings.map((f) => f.toJson()).toList(),
      ),
      'assessedDimensionsJson': jsonEncode(result.assessedDimensions),
      'reviewScopeJson': result.reviewScopeJson == null
          ? null
          : jsonEncode(result.reviewScopeJson),
      'createdAt': PersistenceDatabase.toUtc(result.createdAt),
      'version': result.version,
      'reviewerRole': result.reviewerRole.wire,
    };
  }
}

class EngineeringReviewResultNotFoundException implements Exception {
  EngineeringReviewResultNotFoundException(this.reviewExecutionId);

  final String reviewExecutionId;

  @override
  String toString() =>
      'Engineering review result not found: $reviewExecutionId';
}

class PostgresConcurrentModificationException implements Exception {
  PostgresConcurrentModificationException({
    required this.entityId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String entityId;
  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'Concurrent modification of $entityId (expected version '
      '$expectedVersion, actual $actualVersion)';
}

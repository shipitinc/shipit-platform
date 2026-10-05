import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';

/// PostgreSQL implementation of HumanDirection store.
class PostgresHumanDirectionStore {
  PostgresHumanDirectionStore(this._db);

  final PersistenceDatabase _db;

  /// Creates a new direction.
  Future<HumanDirection> createDirection({
    required String directionType,
    required HumanDirectionTarget target,
    required HumanDirectionPayload payload,
    String? createdBy,
    String? assignedTo,
  }) async {
    final now = DateTime.now().toUtc();
    final direction = HumanDirection(
      directionId: 'hd-${now.millisecondsSinceEpoch}',
      directionType: HumanDirectionType.fromWire(directionType),
      target: target,
      status: HumanDirectionStatus.created,
      payload: payload,
      createdBy: createdBy,
      assignedTo: assignedTo,
      createdAt: now,
      updatedAt: now,
    );

    await _db.execute(
      '''INSERT INTO "human_direction" (
            "directionId", "directionType", "targetType", "targetId", "status",
            "payloadJson", "createdBy", "assignedTo",
            "ackedAt", "ackedBy", "startedAt", "startedBy",
            "completedAt", "completedBy", "completionSummary",
            "rejectedAt", "rejectedBy", "rejectionReason",
            "supersededAt", "supersededByDirectionId",
            "createdAt", "updatedAt", "metadataJson"
          ) VALUES (
            @directionId, @directionType, @targetType, @targetId, @status,
            @payloadJson, @createdBy, @assignedTo,
            @ackedAt, @ackedBy, @startedAt, @startedBy,
            @completedAt, @completedBy, @completionSummary,
            @rejectedAt, @rejectedBy, @rejectionReason,
            @supersededAt, @supersededByDirectionId,
            @createdAt, @updatedAt, @metadataJson
          )''',
      parameters: QueryParameters.named(_directionToParams(direction)),
    );

    return direction;
  }

  /// Reads a direction by ID.
  Future<HumanDirection?> readDirection({required String directionId}) async {
    final result = await _db.query(
      '''SELECT * FROM "human_direction" WHERE "directionId" = @directionId''',
      parameters: QueryParameters.named({'directionId': directionId}),
    );
    if (result.isEmpty) return null;
    return _directionFromRow(result[0]);
  }

  /// Lists directions for a specific target.
  Future<List<HumanDirection>> listDirectionsForTarget({
    required String targetType,
    required String targetId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    var sql = '''SELECT * FROM "human_direction"
          WHERE "targetType" = @targetType AND "targetId" = @targetId''';
    final params = <String, Object?>{
      'targetType': targetType,
      'targetId': targetId,
    };

    if (status != null) {
      sql += ' AND "status" = @status';
      params['status'] = status;
    }

    sql += ' ORDER BY "createdAt" DESC';

    if (limit != null) {
      sql += ' LIMIT @limit';
      params['limit'] = limit;
    }

    if (offset != null) {
      sql += ' OFFSET @offset';
      params['offset'] = offset;
    }

    final result = await _db.query(
      sql,
      parameters: QueryParameters.named(params),
    );
    return result.map(_directionFromRow).toList();
  }

  /// Lists directions by status.
  Future<List<HumanDirection>> listDirectionsByStatus({
    required String status,
    String? directionType,
    String? targetType,
    int? limit,
    int? offset,
  }) async {
    var sql = '''SELECT * FROM "human_direction" WHERE "status" = @status''';
    final params = <String, Object?>{'status': status};

    if (directionType != null) {
      sql += ' AND "directionType" = @directionType';
      params['directionType'] = directionType;
    }

    if (targetType != null) {
      sql += ' AND "targetType" = @targetType';
      params['targetType'] = targetType;
    }

    sql += ' ORDER BY "createdAt" DESC';

    if (limit != null) {
      sql += ' LIMIT @limit';
      params['limit'] = limit;
    }

    if (offset != null) {
      sql += ' OFFSET @offset';
      params['offset'] = offset;
    }

    final result = await _db.query(
      sql,
      parameters: QueryParameters.named(params),
    );
    return result.map(_directionFromRow).toList();
  }

  /// Acknowledges a direction (created → acked).
  Future<HumanDirection> acknowledgeDirection({
    required String directionId,
    required String acknowledgedBy,
  }) async {
    return _updateDirection(directionId, (direction) {
      if (direction.status != HumanDirectionStatus.created) {
        throw StateError(
          'Cannot acknowledge direction in status ${direction.status.wire}',
        );
      }
      final now = DateTime.now().toUtc();
      return HumanDirection(
        directionId: direction.directionId,
        directionType: direction.directionType,
        target: direction.target,
        status: HumanDirectionStatus.acked,
        payload: direction.payload,
        createdBy: direction.createdBy,
        assignedTo: direction.assignedTo,
        ackedAt: now,
        ackedBy: acknowledgedBy,
        startedAt: direction.startedAt,
        startedBy: direction.startedBy,
        completedAt: direction.completedAt,
        completedBy: direction.completedBy,
        completionSummary: direction.completionSummary,
        rejectedAt: direction.rejectedAt,
        rejectedBy: direction.rejectedBy,
        rejectionReason: direction.rejectionReason,
        supersededAt: direction.supersededAt,
        supersededByDirectionId: direction.supersededByDirectionId,
        createdAt: direction.createdAt,
        updatedAt: now,
        metadata: direction.metadata,
      );
    });
  }

  /// Starts working on a direction (acked → working).
  Future<HumanDirection> startWorkingDirection({
    required String directionId,
    required String startedBy,
  }) async {
    return _updateDirection(directionId, (direction) {
      if (direction.status != HumanDirectionStatus.acked) {
        throw StateError(
          'Cannot start working on direction in status ${direction.status.wire}',
        );
      }
      final now = DateTime.now().toUtc();
      return HumanDirection(
        directionId: direction.directionId,
        directionType: direction.directionType,
        target: direction.target,
        status: HumanDirectionStatus.working,
        payload: direction.payload,
        createdBy: direction.createdBy,
        assignedTo: direction.assignedTo,
        ackedAt: direction.ackedAt,
        ackedBy: direction.ackedBy,
        startedAt: now,
        startedBy: startedBy,
        completedAt: direction.completedAt,
        completedBy: direction.completedBy,
        completionSummary: direction.completionSummary,
        rejectedAt: direction.rejectedAt,
        rejectedBy: direction.rejectedBy,
        rejectionReason: direction.rejectionReason,
        supersededAt: direction.supersededAt,
        supersededByDirectionId: direction.supersededByDirectionId,
        createdAt: direction.createdAt,
        updatedAt: now,
        metadata: direction.metadata,
      );
    });
  }

  /// Completes a direction (working → completed).
  Future<HumanDirection> completeDirection({
    required String directionId,
    required String completedBy,
    required String completionSummary,
  }) async {
    return _updateDirection(directionId, (direction) {
      if (direction.status != HumanDirectionStatus.working) {
        throw StateError(
          'Cannot complete direction in status ${direction.status.wire}',
        );
      }
      final now = DateTime.now().toUtc();
      return HumanDirection(
        directionId: direction.directionId,
        directionType: direction.directionType,
        target: direction.target,
        status: HumanDirectionStatus.completed,
        payload: direction.payload,
        createdBy: direction.createdBy,
        assignedTo: direction.assignedTo,
        ackedAt: direction.ackedAt,
        ackedBy: direction.ackedBy,
        startedAt: direction.startedAt,
        startedBy: direction.startedBy,
        completedAt: now,
        completedBy: completedBy,
        completionSummary: completionSummary,
        rejectedAt: direction.rejectedAt,
        rejectedBy: direction.rejectedBy,
        rejectionReason: direction.rejectionReason,
        supersededAt: direction.supersededAt,
        supersededByDirectionId: direction.supersededByDirectionId,
        createdAt: direction.createdAt,
        updatedAt: now,
        metadata: direction.metadata,
      );
    });
  }

  /// Rejects a direction (working → rejected).
  Future<HumanDirection> rejectDirection({
    required String directionId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    return _updateDirection(directionId, (direction) {
      if (direction.status != HumanDirectionStatus.working) {
        throw StateError(
          'Cannot reject direction in status ${direction.status.wire}',
        );
      }
      final now = DateTime.now().toUtc();
      return HumanDirection(
        directionId: direction.directionId,
        directionType: direction.directionType,
        target: direction.target,
        status: HumanDirectionStatus.rejected,
        payload: direction.payload,
        createdBy: direction.createdBy,
        assignedTo: direction.assignedTo,
        ackedAt: direction.ackedAt,
        ackedBy: direction.ackedBy,
        startedAt: direction.startedAt,
        startedBy: direction.startedBy,
        completedAt: direction.completedAt,
        completedBy: direction.completedBy,
        completionSummary: direction.completionSummary,
        rejectedAt: now,
        rejectedBy: rejectedBy,
        rejectionReason: rejectionReason,
        supersededAt: direction.supersededAt,
        supersededByDirectionId: direction.supersededByDirectionId,
        createdAt: direction.createdAt,
        updatedAt: now,
        metadata: direction.metadata,
      );
    });
  }

  /// Supersedes a direction (any active → superseded).
  Future<HumanDirection> supersedeDirection({
    required String directionId,
    required String supersededByDirectionId,
    required String supersededBy,
  }) async {
    return _updateDirection(directionId, (direction) {
      if (direction.status.isTerminal) {
        throw StateError(
          'Cannot supersede direction in terminal status ${direction.status.wire}',
        );
      }
      final now = DateTime.now().toUtc();
      return HumanDirection(
        directionId: direction.directionId,
        directionType: direction.directionType,
        target: direction.target,
        status: HumanDirectionStatus.superseded,
        payload: direction.payload,
        createdBy: direction.createdBy,
        assignedTo: direction.assignedTo,
        ackedAt: direction.ackedAt,
        ackedBy: direction.ackedBy,
        startedAt: direction.startedAt,
        startedBy: direction.startedBy,
        completedAt: direction.completedAt,
        completedBy: direction.completedBy,
        completionSummary: direction.completionSummary,
        rejectedAt: direction.rejectedAt,
        rejectedBy: direction.rejectedBy,
        rejectionReason: direction.rejectionReason,
        supersededAt: now,
        supersededByDirectionId: supersededByDirectionId,
        createdAt: direction.createdAt,
        updatedAt: now,
        metadata: direction.metadata,
      );
    });
  }

  Future<HumanDirection> _updateDirection(
    String directionId,
    HumanDirection Function(HumanDirection) updateFn,
  ) async {
    final current = await readDirection(directionId: directionId);
    if (current == null) {
      throw StateError('Direction not found: $directionId');
    }

    final updated = updateFn(current);

    await _db.execute(
      '''UPDATE "human_direction" SET
            "directionType" = @directionType,
            "targetType" = @targetType,
            "targetId" = @targetId,
            "status" = @status,
            "payloadJson" = @payloadJson,
            "createdBy" = @createdBy,
            "assignedTo" = @assignedTo,
            "ackedAt" = @ackedAt,
            "ackedBy" = @ackedBy,
            "startedAt" = @startedAt,
            "startedBy" = @startedBy,
            "completedAt" = @completedAt,
            "completedBy" = @completedBy,
            "completionSummary" = @completionSummary,
            "rejectedAt" = @rejectedAt,
            "rejectedBy" = @rejectedBy,
            "rejectionReason" = @rejectionReason,
            "supersededAt" = @supersededAt,
            "supersededByDirectionId" = @supersededByDirectionId,
            "createdAt" = @createdAt,
            "updatedAt" = @updatedAt,
            "metadataJson" = @metadataJson
          WHERE "directionId" = @directionId''',
      parameters: QueryParameters.named(_directionToParams(updated)),
    );

    return updated;
  }

  Map<String, Object?> _directionToParams(HumanDirection direction) {
    return {
      'directionId': direction.directionId,
      'directionType': direction.directionType.wire,
      'targetType': direction.target.targetType.wire,
      'targetId': direction.target.targetId,
      'status': direction.status.wire,
      'payloadJson': _payloadToJson(direction.payload),
      'createdBy': direction.createdBy,
      'assignedTo': direction.assignedTo,
      'ackedAt': PersistenceDatabase.toUtc(direction.ackedAt),
      'ackedBy': direction.ackedBy,
      'startedAt': PersistenceDatabase.toUtc(direction.startedAt),
      'startedBy': direction.startedBy,
      'completedAt': PersistenceDatabase.toUtc(direction.completedAt),
      'completedBy': direction.completedBy,
      'completionSummary': direction.completionSummary,
      'rejectedAt': PersistenceDatabase.toUtc(direction.rejectedAt),
      'rejectedBy': direction.rejectedBy,
      'rejectionReason': direction.rejectionReason,
      'supersededAt': PersistenceDatabase.toUtc(direction.supersededAt),
      'supersededByDirectionId': direction.supersededByDirectionId,
      'createdAt': PersistenceDatabase.toUtc(direction.createdAt),
      'updatedAt': PersistenceDatabase.toUtc(direction.updatedAt),
      'metadataJson': direction.metadata != null
          ? PersistenceDatabase.encodeJson(direction.metadata!)
          : null,
    };
  }

  HumanDirection _directionFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return HumanDirection(
      directionId: m['directionId'] as String,
      directionType: HumanDirectionType.fromWire(m['directionType'] as String),
      target: HumanDirectionTarget(
        targetType: HumanDirectionTargetType.fromWire(
          m['targetType'] as String,
        ),
        targetId: m['targetId'] as String?,
      ),
      status: HumanDirectionStatus.fromWire(m['status'] as String),
      payload: _payloadFromJson(m['payloadJson'] as String),
      createdBy: m['createdBy'] as String?,
      assignedTo: m['assignedTo'] as String?,
      ackedAt: (m['ackedAt'] as DateTime?)?.toUtc(),
      ackedBy: m['ackedBy'] as String?,
      startedAt: (m['startedAt'] as DateTime?)?.toUtc(),
      startedBy: m['startedBy'] as String?,
      completedAt: (m['completedAt'] as DateTime?)?.toUtc(),
      completedBy: m['completedBy'] as String?,
      completionSummary: m['completionSummary'] as String?,
      rejectedAt: (m['rejectedAt'] as DateTime?)?.toUtc(),
      rejectedBy: m['rejectedBy'] as String?,
      rejectionReason: m['rejectionReason'] as String?,
      supersededAt: (m['supersededAt'] as DateTime?)?.toUtc(),
      supersededByDirectionId: m['supersededByDirectionId'] as String?,
      createdAt: (m['createdAt'] as DateTime).toUtc(),
      updatedAt: (m['updatedAt'] as DateTime).toUtc(),
      metadata: m['metadataJson'] != null
          ? jsonDecode(m['metadataJson'] as String) as Map<String, dynamic>
          : null,
    );
  }

  String _payloadToJson(HumanDirectionPayload payload) {
    final map = <String, dynamic>{
      'title': payload.title,
      'description': payload.description,
    };
    if (payload.contextJson != null) {
      map['contextJson'] = payload.contextJson;
    }
    if (payload.attachments != null) {
      map['attachments'] = payload.attachments!
          .map(
            (a) => {
              'artifactId': a.artifactId,
              'artifactType': a.artifactType,
              'description': a.description,
            },
          )
          .toList();
    }
    return jsonEncode(map);
  }

  HumanDirectionPayload _payloadFromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return HumanDirectionPayload(
      title: map['title'] as String,
      description: map['description'] as String,
      contextJson: map['contextJson'] as String?,
      attachments:
          (map['attachments'] as List<dynamic>?)
              ?.map(
                (a) => HumanDirectionAttachment(
                  artifactId: a['artifactId'] as String,
                  artifactType: a['artifactType'] as String,
                  description: a['description'] as String?,
                ),
              )
              .toList() ??
          [],
    );
  }
}

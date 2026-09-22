import 'package:serverpod/database.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [WorkerRegistrationStore].
class PostgresWorkerRegistrationStore implements WorkerRegistrationStore {
  PostgresWorkerRegistrationStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) {
    return _db.inTransaction<T>(() => body(this));
  }

  @override
  Future<void> registerWorker(WorkerRegistration registration) async {
    final json = WorkerRegistrationCodec.toJson(registration);
    await _db.execute(
      '''INSERT INTO "worker_registration" (
             "workerId", "poolId", "capabilitiesJson", "status", "currentLoad",
             "maxConcurrency", "lastHeartbeat", "artifactCacheJson", "platform"
           ) VALUES (
             @workerId, @poolId, @capabilitiesJson, @status, @currentLoad,
             @maxConcurrency, @lastHeartbeat, @artifactCacheJson, @platform
           )
           ON CONFLICT ("workerId") DO UPDATE SET
             "poolId" = EXCLUDED."poolId",
             "capabilitiesJson" = EXCLUDED."capabilitiesJson",
             "status" = EXCLUDED."status",
             "currentLoad" = EXCLUDED."currentLoad",
             "maxConcurrency" = EXCLUDED."maxConcurrency",
             "lastHeartbeat" = EXCLUDED."lastHeartbeat",
             "artifactCacheJson" = EXCLUDED."artifactCacheJson",
             "platform" = EXCLUDED."platform"''',
      parameters: QueryParameters.named({
        'workerId': json['workerId'],
        'poolId': json['poolId'],
        'capabilitiesJson': PersistenceDatabase.encodeJson(
          json['capabilities'],
        ),
        'status': json['status'],
        'currentLoad': json['currentLoad'],
        'maxConcurrency': json['maxConcurrency'],
        'lastHeartbeat': decodeUtc(json['lastHeartbeat']),
        'artifactCacheJson': PersistenceDatabase.encodeJson(
          json['artifactCache'],
        ),
        'platform': json['platform'],
      }),
    );
  }

  @override
  Future<WorkerRegistration?> readWorker(String workerId) async {
    final result = await _db.query(
      '''SELECT * FROM "worker_registration" WHERE "workerId" = @workerId''',
      parameters: QueryParameters.named({'workerId': workerId}),
    );
    if (result.isEmpty) return null;
    return _registrationFromRow(result[0]);
  }

  @override
  Future<List<WorkerRegistration>> listWorkers() async {
    final result = await _db.query(
      '''SELECT * FROM "worker_registration" ORDER BY "lastHeartbeat" DESC''',
    );
    return result.map(_registrationFromRow).toList();
  }

  @override
  Future<void> unregisterWorker(String workerId) async {
    await _db.execute(
      '''DELETE FROM "worker_registration" WHERE "workerId" = @workerId''',
      parameters: QueryParameters.named({'workerId': workerId}),
    );
  }

  WorkerRegistration _registrationFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return WorkerRegistrationCodec.fromJson({
      'workerId': m['workerId'],
      'poolId': m['poolId'],
      'capabilities': decodeJsonMap(
        m['capabilitiesJson'] as String?,
      ),
      'status': m['status'],
      'currentLoad': m['currentLoad'],
      'maxConcurrency': m['maxConcurrency'],
      'lastHeartbeat': decodeUtc(m['lastHeartbeat'])!.toIso8601String(),
      'artifactCache': decodeJsonMap(m['artifactCacheJson'] as String?),
      'platform': m['platform'],
    });
  }
}

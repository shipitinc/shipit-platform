import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Opens an unmodified, unregistered session so this group does not fight with
/// sibling groups' cleanup.
late PersistenceDatabase _db;

Future<void> _truncateJobTables() async {
  await _db.queryNoTransaction('''
    TRUNCATE TABLE "job", "job_claim", "scheduler_event" RESTART IDENTITY CASCADE
  ''');
}

void main() {
  withServerpod(
    'Postgres enforces the scheduler dedupe index',
    (sessionBuilder, endpoints) {
      setUpAll(() async {
        final session = await Serverpod.instance.createSession(
          enableLogging: false,
        );
        _db = PersistenceDatabase(session.db);
      });
      setUp(_truncateJobTables);

      test(
        'job_active_dedupe_unique exists as a partial unique index',
        () async {
          final rows = await _db.queryNoTransaction('''
          SELECT indexdef FROM pg_indexes
          WHERE schemaname = 'public'
            AND tablename = 'job'
            AND indexname = 'job_active_dedupe_unique'
        ''');
          expect(rows.length, 1, reason: 'the dedupe index must be installed');
          final definition = rows[0].toColumnMap()['indexdef'] as String;
          expect(definition, contains('job_active_dedupe_unique'));
          expect(definition, contains('unique'));
          expect(definition, contains('queued'));
          expect(definition, contains('claimed'));
          expect(definition, contains('running'));
          expect(definition, contains('retryWaiting'));
        },
      );

      test('two active jobs with the same dedupe key cannot coexist', () async {
        await _db.execute(
          '''INSERT INTO "job" (
               "jobId", "workItemId", "jobType", "requiredRole",
               "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
               "createdAt", "instruction", "attempt", "maxAttempts", "version"
             ) VALUES (
               @a, 'wi-a', 'implementFeature', 'implementer',
               '{"linux":true}', 'normal', 'queued', 'shared-key',
               @now, 'x', 1, 2, 1
             )''',
          parameters: QueryParameters.named({
            'a': 'job-dup-a',
            'now': DateTime.utc(2026, 1, 1),
          }),
        );
        expect(
          _db.execute(
            '''INSERT INTO "job" (
                 "jobId", "workItemId", "jobType", "requiredRole",
                 "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
                 "createdAt", "instruction", "attempt", "maxAttempts", "version"
               ) VALUES (
                 @b, 'wi-b', 'implementFeature', 'implementer',
                 '{"linux":true}', 'normal', 'queued', 'shared-key',
                 @now, 'y', 1, 2, 1
               )''',
            parameters: QueryParameters.named({
              'b': 'job-dup-b',
              'now': DateTime.utc(2026, 1, 1),
            }),
          ),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('duplicate key'),
                contains('job_active_dedupe_unique'),
              ),
            ),
          ),
        );
        final rows = await _db.queryNoTransaction(
          'SELECT count(*) AS n FROM "job"',
        );
        expect(rows[0].toColumnMap()['n'], 1);
      });

      test(
        'a terminal job does not block re-enqueuing the same dedupe key',
        () async {
          await _db.execute(
            '''INSERT INTO "job" (
               "jobId", "workItemId", "jobType", "requiredRole",
               "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
               "createdAt", "instruction", "attempt", "maxAttempts", "version"
             ) VALUES (
               @id, 'wi-a', 'implementFeature', 'implementer',
               '{"linux":true}', 'normal', 'completed', 'shared-key',
               @now, 'x', 1, 2, 1
             )''',
            parameters: QueryParameters.named({
              'id': 'job-term',
              'now': DateTime.utc(2026, 1, 1),
            }),
          );
          await _db.execute(
            '''INSERT INTO "job" (
               "jobId", "workItemId", "jobType", "requiredRole",
               "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
               "createdAt", "instruction", "attempt", "maxAttempts", "version"
             ) VALUES (
               @id, 'wi-b', 'implementFeature', 'implementer',
               '{"linux":true}', 'normal', 'queued', 'shared-key',
               @now, 'y', 1, 2, 1
             )''',
            parameters: QueryParameters.named({
              'id': 'job-new',
              'now': DateTime.utc(2026, 1, 1),
            }),
          );
          final rows = await _db.queryNoTransaction(
            'SELECT count(*) AS n FROM "job"',
          );
          expect(
            rows[0].toColumnMap()['n'],
            2,
            reason: 'a completed job releases the active dedupe key',
          );
        },
      );

      test('distinct dedupe keys coexist freely', () async {
        await _db.execute(
          '''INSERT INTO "job" (
               "jobId", "workItemId", "jobType", "requiredRole",
               "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
               "createdAt", "instruction", "attempt", "maxAttempts", "version"
             ) VALUES (
               @a, 'wi-a', 'implementFeature', 'implementer',
               '{"linux":true}', 'normal', 'queued', 'key-a',
               @now, 'x', 1, 2, 1
             ), (
               @b, 'wi-b', 'implementFeature', 'implementer',
               '{"linux":true}', 'normal', 'queued', 'key-b',
               @now, 'y', 1, 2, 1
             )''',
          parameters: QueryParameters.named({
            'a': 'job-null-a',
            'b': 'job-null-b',
            'now': DateTime.utc(2026, 1, 1),
          }),
        );
        final rows = await _db.queryNoTransaction(
          'SELECT count(*) AS n FROM "job"',
        );
        expect(
          rows[0].toColumnMap()['n'],
          2,
          reason: 'the partial unique index only scopes equal dedupe keys',
        );
      });
    },
  );
}

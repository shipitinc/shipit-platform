import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Opens an unmodified, unregistered session so this group does not fight with
/// sibling groups' cleanup.
late PersistenceDatabase _db;

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// A targeted DELETE, never a TRUNCATE: `test/integration` shares one
/// PostgreSQL database with other test files that run concurrently, and
/// truncating `job` out from under them breaks their assertions. Every marker
/// below is namespaced `mig-*`, so no other file's row can match. The same
/// purge runs in tearDown because the rows are only interesting while a test is
/// running, and in setUp because a previous run that aborted mid-test leaves
/// rows behind that would then violate a unique constraint.
Future<void> _purgeSuiteRows() async {
  const workItem = 'mig-%';
  // One statement per call: the driver sends a parameterised command as a
  // prepared statement, which accepts exactly one command at a time.
  const statements = <String>[
    'DELETE FROM "job_claim" WHERE "jobId" IN '
        '(SELECT "jobId" FROM "job" WHERE "workItemId" LIKE \'$workItem\')',
    'DELETE FROM "scheduler_event" WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "job"          WHERE "workItemId" LIKE \'$workItem\'',
  ];
  for (final statement in statements) {
    await _db.query(statement);
  }
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
      setUp(_purgeSuiteRows);
      tearDown(_purgeSuiteRows);

      test(
        'job_active_dedupe_unique is a plain unique index on activeDedupeKey',
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
          expect(
            definition,
            contains('("activeDedupeKey")'),
            reason:
                'the constraint lives on the derived column, not on '
                'dedupeKey itself',
          );
          expect(
            definition.toUpperCase(),
            isNot(contains('WHERE')),
            reason:
                'a partial (WHERE-clause) index cannot be expressed in a '
                'Serverpod model, so serverpod create-migration erases it; '
                'the whole point of activeDedupeKey is that this index needs '
                'no predicate',
          );
        },
      );

      test('two active jobs with the same dedupe key cannot coexist', () async {
        await _db.execute(
          '''INSERT INTO "job" (
               "jobId", "workItemId", "jobType", "requiredRole",
               "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
               "activeDedupeKey", "createdAt", "instruction", "attempt",
               "maxAttempts", "version"
             ) VALUES (
               @a, 'mig-a', 'implement_feature', 'IMPLEMENTER',
               '["linux"]', 'normal', 'queued', 'mig-shared-key',
               'mig-shared-key', @now, 'x', 1, 2, 1
             )''',
          parameters: QueryParameters.named({
            'a': 'mig-job-dup-a',
            'now': DateTime.utc(2026, 1, 1),
          }),
        );
        expect(
          _db.execute(
            '''INSERT INTO "job" (
                 "jobId", "workItemId", "jobType", "requiredRole",
                 "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
                 "activeDedupeKey", "createdAt", "instruction", "attempt",
                 "maxAttempts", "version"
               ) VALUES (
                 @b, 'mig-b', 'implement_feature', 'IMPLEMENTER',
                 '["linux"]', 'normal', 'queued', 'mig-shared-key',
                 'mig-shared-key', @now, 'y', 1, 2, 1
               )''',
            parameters: QueryParameters.named({
              'b': 'mig-job-dup-b',
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
          'SELECT count(*) AS n FROM "job" WHERE "workItemId" LIKE \'mig-%\'',
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
               "activeDedupeKey", "createdAt", "instruction", "attempt",
               "maxAttempts", "version"
             ) VALUES (
               @id, 'mig-a', 'implement_feature', 'IMPLEMENTER',
               '["linux"]', 'normal', 'succeeded', 'mig-shared-key',
               NULL, @now, 'x', 1, 2, 1
             )''',
            parameters: QueryParameters.named({
              'id': 'mig-job-term',
              'now': DateTime.utc(2026, 1, 1),
            }),
          );
          await _db.execute(
            '''INSERT INTO "job" (
               "jobId", "workItemId", "jobType", "requiredRole",
               "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
               "activeDedupeKey", "createdAt", "instruction", "attempt",
               "maxAttempts", "version"
             ) VALUES (
               @id, 'mig-b', 'implement_feature', 'IMPLEMENTER',
               '["linux"]', 'normal', 'queued', 'mig-shared-key',
               'mig-shared-key', @now, 'y', 1, 2, 1
             )''',
            parameters: QueryParameters.named({
              'id': 'mig-job-new',
              'now': DateTime.utc(2026, 1, 1),
            }),
          );
          final rows = await _db.queryNoTransaction(
            'SELECT count(*) AS n FROM "job" WHERE "workItemId" LIKE \'mig-%\'',
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
               "activeDedupeKey", "createdAt", "instruction", "attempt",
               "maxAttempts", "version"
             ) VALUES (
               @a, 'mig-a', 'implement_feature', 'IMPLEMENTER',
               '["linux"]', 'normal', 'queued', 'mig-key-a',
               'mig-key-a', @now, 'x', 1, 2, 1
             ), (
               @b, 'mig-b', 'implement_feature', 'IMPLEMENTER',
               '["linux"]', 'normal', 'queued', 'mig-key-b',
               'mig-key-b', @now, 'y', 1, 2, 1
             )''',
          parameters: QueryParameters.named({
            'a': 'mig-job-null-a',
            'b': 'mig-job-null-b',
            'now': DateTime.utc(2026, 1, 1),
          }),
        );
        final rows = await _db.queryNoTransaction(
          'SELECT count(*) AS n FROM "job" WHERE "workItemId" LIKE \'mig-%\'',
        );
        expect(
          rows[0].toColumnMap()['n'],
          2,
          reason: 'the unique index only scopes equal active dedupe keys',
        );
      });

      test(
        'PostgresJobStore keeps activeDedupeKey in step with the state',
        () async {
          final store = PostgresJobStore(_db);
          await _db.execute(
            '''INSERT INTO "job" (
                 "jobId", "workItemId", "jobType", "requiredRole",
                 "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
                 "activeDedupeKey", "createdAt", "instruction", "attempt",
                 "maxAttempts", "version"
               ) VALUES (
                 'mig-job-derive', 'mig-wi', 'implement_feature', 'IMPLEMENTER',
                 '[]', 'normal', 'queued', 'mig-k',
                 'mig-k', @now, 'x', 1, 2, 1
               )''',
            parameters: QueryParameters.named({
              'now': DateTime.utc(2026, 1, 1),
            }),
          );

          Future<Object?> storedKey() async {
            final rows = await _db.queryNoTransaction(
              '''SELECT "activeDedupeKey" FROM "job"
                 WHERE "jobId" = 'mig-job-derive\'''',
            );
            return rows.first.toColumnMap()['activeDedupeKey'];
          }

          expect(await storedKey(), 'mig-k');

          final running = (await store.readJob('mig-job-derive'))!;
          await store.saveJob(
            running.copyWith(state: JobState.succeeded, version: 2),
            expectedVersion: 1,
          );
          expect(
            await storedKey(),
            isNull,
            reason: 'a terminal job must release the active dedupe key',
          );

          final resumed = (await store.readJob('mig-job-derive'))!;
          await store.saveJob(
            resumed.copyWith(state: JobState.running, version: 3),
            expectedVersion: 2,
          );
          expect(
            await storedKey(),
            'mig-k',
            reason: 'returning to an active state must re-take the key',
          );
        },
      );
    },
  );
}

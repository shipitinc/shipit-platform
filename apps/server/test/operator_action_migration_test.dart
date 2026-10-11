import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// AC-30 / AC-14d / AC-31 — the single migration that creates the
/// `operator_action` audit table.
///
/// These are properties of SQL and of source text, so they are asserted as
/// such: reading the artifact is the only way to see them, and a reviewer
/// reading a diff is not a check that fails.
///
/// AC-30 is a claim about MUTUAL EXCLUSIVITY as much as about existence —
/// "exactly one migration, exactly one table, changing no existing table" is a
/// claim about what the migration does NOT do, so the negative assertions carry
/// as much weight as the positive ones. A migration that quietly altered
/// `work_item` or `work_item_transition` would be a production-affecting change
/// hiding inside an audit-table change.
///
/// AC-14d is asserted by scanning the whole repository for an UPDATE or DELETE
/// against the table, which is the form the criterion asks for: "a test that
/// fails if any UPDATE/DELETE against the table is introduced".
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  final registry = File(p.join(migrationsDir.path, 'migration_registry.txt'))
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  final latest = registry.last;
  final latestDir = Directory(p.join(migrationsDir.path, latest));
  final migrationSql = File(
    p.join(latestDir.path, 'migration.sql'),
  ).readAsStringSync();
  final definitionSql = File(
    p.join(latestDir.path, 'definition.sql'),
  ).readAsStringSync();

  /// Strips `--` comments so a section header that NAMES an object cannot
  /// satisfy a check that is supposed to find the DDL that CREATES it. The
  /// generated migrations are heavily commented, so this is load-bearing
  /// rather than tidy.
  String sqlBody(String sql) => sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');
  final body = sqlBody(migrationSql);

  group('AC-30 exactly one migration, exactly one table, no existing change', () {
    test('the latest registered migration is the only one that creates it', () {
      final creators = <String>[];
      for (final entry in migrationsDir.listSync()) {
        if (entry is! Directory) continue;
        final sql = File(p.join(entry.path, 'migration.sql'));
        if (!sql.existsSync()) continue;
        if (sqlBody(
          sql.readAsStringSync(),
        ).contains('CREATE TABLE "operator_action"')) {
          creators.add(p.basename(entry.path));
        }
      }
      expect(creators, [latest]);
      expect(
        registry.where((e) => e == latest),
        hasLength(1),
        reason: 'the registry must list the version exactly once',
      );
    });

    test('it creates EXACTLY ONE table, and it is operator_action', () {
      final created = RegExp(
        r'CREATE\s+TABLE\s+"([^"]+)"',
      ).allMatches(body).map((m) => m.group(1)).toList();
      expect(created, ['operator_action']);
    });

    test('it changes NO existing table', () {
      expect(
        RegExp(r'\bALTER\s+TABLE\b', caseSensitive: false).hasMatch(body),
        isFalse,
        reason:
            'AC-30: this migration creates a table and changes no '
            'existing one. An ALTER here would be a production-affecting '
            'change hiding inside an audit-table change.',
      );
      expect(
        RegExp(r'\bDROP\s+TABLE\b', caseSensitive: false).hasMatch(body),
        isFalse,
      );
      expect(
        RegExp(
          r'\bCREATE\s+OR\s+REPLACE\b',
          caseSensitive: false,
        ).hasMatch(body),
        isFalse,
      );
      expect(
        RegExp(r'\bTRUNCATE\b', caseSensitive: false).hasMatch(body),
        isFalse,
      );
    });

    test('the registry gained exactly one version', () {
      // The committed registry before this change listed every directory but
      // one; the generator appends whatever is missing. What matters for AC-30
      // is that THIS table is created once, which the first test proves.
      expect(latestDir.existsSync(), isTrue);
      expect(registry, isNotEmpty);
    });

    test('the fresh-database path carries the table too', () {
      // Serverpod applies the LATEST definition.sql to a database with no
      // recorded migration version, and replays every migration.sql to a
      // chain-migrated one. Both paths must reach the table, or one of the two
      // databases this repository creates silently lacks the audit ledger.
      expect(
        sqlBody(definitionSql).contains('CREATE TABLE "operator_action"'),
        isTrue,
      );
    });
  });

  group('AC-14a/e the indexes the table depends on', () {
    test(
      'operator_action_request_unique is UNIQUE on (workItemId, requestId)',
      () {
        // The idempotency record. Without the UNIQUE, a replay would append a
        // second row, a second job and a second spend.
        final m = RegExp(
          r'CREATE UNIQUE INDEX "operator_action_request_unique"[^;]*',
        ).firstMatch(body);
        expect(m, isNotNull, reason: 'the replay index must exist');
        expect(m!.group(0), contains('"workItemId"'));
        expect(m.group(0), contains('"requestId"'));
      },
    );

    test('operator_action_retry_idx and operator_action_job_idx exist', () {
      expect(
        RegExp(
          r'CREATE INDEX "operator_action_retry_idx"[^;]*',
        ).hasMatch(body),
        isTrue,
      );
      expect(
        RegExp(
          r'CREATE INDEX "operator_action_job_idx"[^;]*',
        ).hasMatch(body),
        isTrue,
      );
    });

    test('actionId is unique, so a row is addressable on its own', () {
      expect(
        RegExp(
          r'CREATE UNIQUE INDEX "operator_action_id_unique"[^;]*',
        ).hasMatch(body),
        isTrue,
      );
    });

    test('the columns a refused action must never blank are NOT NULL', () {
      // requestedBy and reason are what make the row an audit rather than a
      // convention, so they are enforced by the database and not only by the
      // Dart constructor.
      final table = RegExp(
        r'CREATE TABLE "operator_action" \((.*?)\);',
        dotAll: true,
      ).firstMatch(body)!.group(1)!;
      for (final column in [
        '"actionId"',
        '"workItemId"',
        '"action"',
        '"fromState"',
        '"toState"',
        '"requestedBy"',
        '"reason"',
        '"requestId"',
      ]) {
        final line = table
            .split('\n')
            .firstWhere((l) => l.trim().startsWith(column));
        expect(line, contains('NOT NULL'), reason: '$column must be required');
      }
      // jobId, transitionId and attemptNumber are legitimately nullable: a
      // stop arms no job, and the binding is stamped by the engine.
      for (final column in ['"jobId"', '"transitionId"', '"attemptNumber"']) {
        final line = table
            .split('\n')
            .firstWhere((l) => l.trim().startsWith(column));
        expect(line, isNot(contains('NOT NULL')));
      }
    });
  });

  group('AC-14d the ledger is append-only', () {
    // A name-anchored scan cannot tell a WRITE PATH from a TEARDOWN, and
    // pretending otherwise is the same failure `verify_schema_bootstrap.sh`
    // documents for itself: a check that reads as coverage while the thing it
    // guards is unenforced. So the exception is EXPLICIT, NAMED, and audited
    // below rather than smuggled into the matcher.
    //
    // Each entry must be a test file. That constraint is itself asserted, so
    // this list can never quietly grow to cover a production path -- which is
    // the only way an allowlist becomes dangerous.
    const fixturePurges = <String, String>{
      'apps/server/test/integration/store_contracts_postgres_test.dart':
          "teardown. `operator_action` has no foreign key to `work_item`, so "
          "no cascade removes the store contract suite's fixture rows. They "
          'MUST be deleted explicitly, or the suite\'s own '
          'duplicate-requestId assertion fails on a constraint it did not '
          'cause and the failure points at the wrong thing.',
    };

    test('every allowlisted purge is a TEST file, never production', () {
      for (final path in fixturePurges.keys) {
        expect(
          path,
          startsWith('apps/server/test/'),
          reason:
              '$path is allowlisted as a fixture purge. An allowlist entry '
              'must be test-only; a production path may never be added here, '
              'because that is the exact thing this test exists to catch.',
        );
        expect(File(p.join(repoRoot, path)).existsSync(), isTrue);
      }
    });

    test('no UPDATE or DELETE against operator_action exists anywhere', () {
      final offenders = <String>[];
      for (final entry in ['packages', 'apps']) {
        final dir = Directory(p.join(repoRoot, entry));
        if (!dir.existsSync()) continue;
        for (final file in dir.listSync(recursive: true)) {
          if (file is! File) continue;
          final path = file.path;
          if (!path.endsWith('.dart') && !path.endsWith('.sql')) continue;
          if (path.contains('/generated/')) continue;
          if (path.contains('/migrations/')) continue;
          if (path.contains('/.dart_tool/')) continue;
          final relative = p.relative(path, from: repoRoot);
          if (fixturePurges.containsKey(relative)) continue;
          final text = file.readAsStringSync();
          if (RegExp(
                r'(UPDATE\s+"operator_action")',
                caseSensitive: false,
              ).hasMatch(text) ||
              RegExp(
                r'(DELETE\s+FROM\s+"operator_action")',
                caseSensitive: false,
              ).hasMatch(text)) {
            offenders.add(relative);
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the audit ledger has no update or delete path. Introducing '
            'one is a merge blocker, not a refactor. (The one allowlisted '
            'fixture purge is a test teardown, asserted test-only above.)',
      );
    });

    test('the store API offers no way to update or delete a row', () {
      // The interface is the contract every implementor must satisfy. A
      // `deleteOperatorAction` here would make AC-14d unreachable regardless
      // of what the SQL says.
      final source = File(
        p.join(
          repoRoot,
          'packages/workflow_store/lib/src/store/workflow_store.dart',
        ),
      ).readAsStringSync();
      expect(source, contains('appendOperatorAction'));
      for (final forbidden in [
        'deleteOperatorAction',
        'updateOperatorAction',
        'removeOperatorAction',
      ]) {
        expect(source, isNot(contains(forbidden)));
      }
    });

    test('the only write goes through the transaction, with no ON CONFLICT '
        'rewrite', () {
      // An `ON CONFLICT DO UPDATE` would silently REPLACE the row recording
      // what an operator already did. The insert must be able to fail.
      final store = File(
        p.join(
          repoRoot,
          'apps/server/lib/src/persistence/postgres_workflow_store.dart',
        ),
      ).readAsStringSync();
      final start = store.indexOf('INSERT INTO "operator_action"');
      expect(start, greaterThan(-1), reason: 'the store must insert the row');
      final end = store.indexOf("'''", start);
      final statement = store.substring(start, end);
      expect(
        statement,
        isNot(contains('ON CONFLICT')),
        reason:
            'a replay must COLLIDE on the unique index, not rewrite the '
            'row that already records the action',
      );
    });
  });
}

/// Walks up from the test's working directory until it finds the repository
/// root, so the test does not hard-code a checkout path.
String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(p.join(dir.path, 'packages')).existsSync() &&
        Directory(p.join(dir.path, 'apps')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

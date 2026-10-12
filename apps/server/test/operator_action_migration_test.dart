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
///
/// The creator is identified by CONTENT — the migration whose SQL contains
/// `CREATE TABLE "operator_action"` — not by its position in the registry. See
/// the resolution note in `main` for why that distinction is load-bearing.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  final registry = File(p.join(migrationsDir.path, 'migration_registry.txt'))
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();

  /// Strips `--` comments so a section header that NAMES an object cannot
  /// satisfy a check that is supposed to find the DDL that CREATES it. The
  /// generated migrations are heavily commented, so this is load-bearing
  /// rather than tidy.
  String sqlBody(String sql) => sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  /// Every migration that contains `CREATE TABLE "operator_action"`, found by
  /// scanning the migration directories.
  ///
  /// This scan used to live inside the exclusivity test and pick
  /// `registry.last` as its answer. That made the creator's identity a claim
  /// about the registry's TAIL: true only while this migration was newest, and
  /// broken by the registration of ANY later migration. When a data-repair
  /// migration was added, six assertions here failed — the index checks, the
  /// NOT NULL check, the fresh-database check — all of them reading a repair
  /// migration's SQL and reporting it as damage to the audit ledger. The
  /// breakage was pre-existing fragility rather than a property of the repair,
  /// and the failure pointed at the wrong file entirely.
  ///
  /// Resolving the creator once, by content, makes every assertion below a
  /// property of the migration that owns the table. It also costs nothing: the
  /// scan was already being performed, once per run, by the test that enforces
  /// exclusivity — so hoisting it proves the SAME property and stops the other
  /// assertions from re-deriving an identity that registry position cannot
  /// support.
  final creators = <String>[
    for (final entry in migrationsDir.listSync())
      if (entry is Directory)
        if (File(p.join(entry.path, 'migration.sql')).existsSync())
          if (sqlBody(
            File(p.join(entry.path, 'migration.sql')).readAsStringSync(),
          ).contains('CREATE TABLE "operator_action"'))
            p.basename(entry.path),
  ]..sort();
  if (creators.isEmpty) {
    // Failing here is deliberate. With no creator, every assertion below would
    // read nothing and pass for the wrong reason, so the whole file would go
    // green while proving nothing about the table.
    throw StateError(
      'no migration under ${migrationsDir.path} creates '
      'CREATE TABLE "operator_action". The assertions in this file resolve the '
      'table by scanning migrations for the DDL that creates it; with no such '
      'migration they cannot read anything and would pass vacuously.',
    );
  }
  // Multiplicity is asserted by its own test, so a second creator is reported
  // there — against the list of both offenders — rather than as an opaque
  // `No element`/`Too many elements` crash before any test runs.
  //
  // Sorting is what keeps that report to a single failure. `listSync()` returns
  // filesystem order, which is not alphabetical and is not stable across
  // machines, so an unsorted `first` could hand the index and NOT NULL checks
  // the WRONG creator and bury the one test that names the real defect under
  // four failures that all read as "the audit ledger is broken".
  final creator = creators.first;
  final creatorDir = Directory(p.join(migrationsDir.path, creator));
  final migrationSql = File(
    p.join(creatorDir.path, 'migration.sql'),
  ).readAsStringSync();
  final definitionSql = File(
    p.join(creatorDir.path, 'definition.sql'),
  ).readAsStringSync();
  final body = sqlBody(migrationSql);

  /// The definition the FRESH-database path is actually served by.
  ///
  /// This one subject is positional BY NATURE, and that is the opposite of the
  /// creator: a fresh database is created from whatever definition.sql is
  /// newest, so `registry.last` is not a fragile proxy for it, it is the
  /// mechanism. It is resolved separately so the fresh-database assertions
  /// keep proving that mechanism after the creator stopped being the newest
  /// entry.
  final freshDatabaseVersion = registry.last;
  final freshDatabaseDefinition = File(
    p.join(migrationsDir.path, freshDatabaseVersion, 'definition.sql'),
  );

  group('AC-30 exactly one migration, exactly one table, no existing change', () {
    test(
      'exactly one migration creates it, and the registry lists it once',
      () {
        expect(
          creators,
          hasLength(1),
          reason:
              'AC-30 is a mutual-exclusivity claim, so the count is the '
              'assertion: every entry listed here contains '
              'CREATE TABLE "operator_action". A second origin for the table '
              'means the ledger has two creation paths and no single migration '
              'whose SQL can be held to the checks below.',
        );
        expect(
          registry.where((e) => e == creator),
          hasLength(1),
          reason: 'the registry must list the version exactly once',
        );
      },
    );

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

    test('the creating migration exists on disk and is registered', () {
      // The committed registry lists every directory but one; the generator
      // appends whatever is missing. That gap is not what AC-30 is about — what
      // matters is that THIS table is created once, which the first test
      // proves. What this test pins is that the creator the scan resolved is a
      // real directory carrying the files the other assertions read.
      expect(creatorDir.existsSync(), isTrue);
      expect(registry, isNotEmpty);
    });

    test('the fresh-database path carries the table too', () {
      // Serverpod applies the LATEST definition.sql to a database with no
      // recorded migration version, and replays every migration.sql to a
      // chain-migrated one. Both paths must reach the table, or one of the two
      // databases this repository creates silently lacks the audit ledger.
      //
      // BOTH definitions are asserted, and neither substitutes for the other.
      // The creator's proves the migration is self-consistent — the table is in
      // the schema that the migration itself declares. The newest registered
      // one's proves the path a fresh database actually takes. Asserting only
      // the first would be a WEAKENING introduced by this refactor: it stays
      // green if a later migration ships a definition.sql that omits the
      // table, which is the exact defect this test exists to catch, and it
      // would stay green precisely when that defect appears.
      expect(
        sqlBody(definitionSql).contains('CREATE TABLE "operator_action"'),
        isTrue,
        reason:
            'the creating migration must declare the table in its own '
            'definition.sql, so the chain-migrated path reaches it too',
      );
      expect(
        freshDatabaseDefinition.existsSync(),
        isTrue,
        reason:
            '$freshDatabaseVersion is the newest registered version and the '
            'fresh-database path applies its definition.sql',
      );
      expect(
        sqlBody(freshDatabaseDefinition.readAsStringSync()).contains(
          'CREATE TABLE "operator_action"',
        ),
        isTrue,
        reason:
            'a fresh database is built from the NEWEST registered '
            'definition.sql, not from the creator\'s. A later migration '
            'shipping a definition.sql without operator_action would leave '
            'every freshly created database without an audit ledger while the '
            'creator-scoped assertion above still passed.',
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

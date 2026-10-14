import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Migration `20261012213045000` — the columns that let `onboarding_record`
/// carry a Product's pinned git revision and its workspace.
///
/// These are properties of SQL and of JSON artefacts on disk, so they are
/// asserted as such: reading the artefacts is the only way to see them, and a
/// reviewer reading a diff is not a check that fails.
///
/// The creator is resolved BY CONTENT — the migration whose SQL adds these
/// columns to `onboarding_record` — never by registry position. See
/// `operator_action_migration_test.dart` for why that distinction is
/// load-bearing: a data-repair migration added after the fact broke six
/// assertions in that file, all of them reading the wrong migration's SQL.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  final registry = File(p.join(migrationsDir.path, 'migration_registry.txt'))
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();

  /// Strips `--` comments so a section header that NAMES an object cannot
  /// satisfy a check that is supposed to find the DDL that creates it. This
  /// migration's banner names `onboarding_record` and all three columns, so
  /// without this every assertion here would pass vacuously.
  String sqlBody(String sql) => sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  final creators = <String>[
    for (final entry in migrationsDir.listSync())
      if (entry is Directory)
        if (File(p.join(entry.path, 'migration.sql')).existsSync())
          if (sqlBody(
            File(p.join(entry.path, 'migration.sql')).readAsStringSync(),
          ).contains('ALTER TABLE "onboarding_record" ADD COLUMN'))
            p.basename(entry.path),
  ]..sort();

  if (creators.isEmpty) {
    // Failing here is deliberate: with no creator every assertion below would
    // read nothing and pass for the wrong reason.
    throw StateError(
      'no migration under ${migrationsDir.path} adds a column to '
      '"onboarding_record". The assertions in this file resolve the change by '
      'scanning migrations for its DDL; with none they would pass vacuously.',
    );
  }
  final creator = creators.first;
  final creatorDir = Directory(p.join(migrationsDir.path, creator));
  final migrationSql = File(
    p.join(creatorDir.path, 'migration.sql'),
  ).readAsStringSync();
  final body = sqlBody(migrationSql);

  const columns = ['pinnedRevision', 'workspace', 'completedBaselineId'];

  group('exactly one migration, exactly three columns', () {
    test('exactly one migration adds a column to onboarding_record', () {
      expect(
        creators,
        hasLength(1),
        reason:
            'a second origin for these columns means two migration paths and '
            'no single migration the checks below can be held to. Every entry '
            'listed here contains ALTER TABLE "onboarding_record" ADD COLUMN.',
      );
      expect(
        registry.where((e) => e == creator),
        hasLength(1),
        reason: 'the registry must list the version exactly once',
      );
    });

    test('it adds EXACTLY the three new columns, to ONE table', () {
      final added = RegExp(
        r'ALTER\s+TABLE\s+"([^"]+)"\s+ADD\s+COLUMN\s+"([^"]+)"',
        caseSensitive: false,
      );
      final matches = added
          .allMatches(body)
          .map((m) => (table: m.group(1)!, column: m.group(2)!))
          .toList();
      expect(matches.map((m) => m.table).toSet(), {'onboarding_record'});
      expect(matches.map((m) => m.column).toSet(), columns.toSet());
      expect(
        matches,
        hasLength(3),
        reason: 'no column may be added beyond the three this lane needs',
      );
    });

    test('it changes no other table, and drops nothing', () {
      // A migration that quietly altered a second table would be a
      // production-affecting change hiding inside an additive column change.
      final tables = RegExp(
        r'ALTER\s+TABLE\s+"([^"]+)"',
        caseSensitive: false,
      ).allMatches(body).map((m) => m.group(1)).toSet();
      expect(tables, {'onboarding_record'});
      for (final forbidden in [
        r'\bDROP\s+TABLE\b',
        r'\bDROP\s+COLUMN\b',
        r'\bDROP\s+INDEX\b',
        r'\bTRUNCATE\b',
        r'\bCREATE\s+TABLE\b',
        r'\bDELETE\s+FROM\b',
      ]) {
        expect(
          RegExp(forbidden, caseSensitive: false).hasMatch(body),
          isFalse,
          reason:
              '$forbidden must not appear outside the commented-down '
              'rollback section of a purely additive migration',
        );
      }
      // The down-migration section is documentation, not executable SQL: its
      // statements are all `--`-commented, which `sqlBody` removed above. If a
      // future edit uncomments them, this test is the thing that fails.
      expect(body, isNot(contains('DROP COLUMN')));
    });

    test('every added column is NULLABLE with no DEFAULT', () {
      // NULLABLE is the backward-compatibility mechanism: an existing row is
      // readable after this migration with all three fields NULL and no
      // backfill. A `NOT NULL` or a `DEFAULT` would either fail the ALTER on a
      // populated table or invent an answer for a product nobody pinned.
      for (final column in columns) {
        final m = RegExp(
          'ALTER\\s+TABLE\\s+"onboarding_record"\\s+ADD\\s+COLUMN\\s+'
          '"$column"[^;]*;',
          caseSensitive: false,
        ).firstMatch(body);
        expect(m, isNotNull, reason: '$column must be added');
        expect(m!.group(0), isNot(contains('NOT NULL')));
        expect(m.group(0)!.toUpperCase(), isNot(contains('DEFAULT')));
        // Serverpod renders a Dart `String?` field as nullable `text`.
        expect(m.group(0), contains('text'));
      }
    });

    test('it is wrapped in one transaction and stamps its version LAST', () {
      expect(body.trimLeft().startsWith('BEGIN;'), isTrue);
      expect(body.trimRight().endsWith('COMMIT;'), isTrue);
      // Both `serverpod_migrations` rows come after every DDL statement, which
      // is what makes a failure roll the DDL back with the version stamp
      // instead of leaving a database that claims a version it does not have.
      final lastDdl = body.lastIndexOf('ADD COLUMN');
      for (final module in ['control_plane', 'serverpod']) {
        final stamp = body.indexOf("VALUES ('$module'");
        expect(
          stamp,
          greaterThan(lastDdl),
          reason: 'the $module version row must be the LAST thing written',
        );
      }
      expect(body, contains("VALUES ('control_plane', '$creator'"));
    });

    test('the registry lists it, and the fresh-database path still has it', () {
      // `registry.last` and `creator` are DIFFERENT SUBJECTS, and asserting
      // they are the same value conflates them. `creator` is resolved by
      // CONTENT — it is the migration whose SQL ADDS the columns. `registry.last`
      // is whatever definition.sql is newest, and it is positional BY NATURE,
      // because a fresh database is built from it.
      //
      // Those two coincide only while the creator is ALSO the newest. They
      // stopped coinciding when a later DATA-ONLY migration was registered
      // (20261014093000000, the stranded-key repair, whose migration.json is
      // `actions: []` and whose definition.json is the creator's byte for
      // byte). So `expect(registry.last, creator)` does not protect the
      // fresh-database path at all; it only forbids any migration from ever
      // being registered after the one that added the columns, which is not a
      // property anybody wants — and the same fragility
      // `operator_action_migration_test.dart` already documents and corrected
      // for when a data-repair migration landed on top of ITS creator.
      //
      // What the fresh-database path actually needs is that the NEWEST
      // definition still declares the three columns. A later migration that
      // shipped a definition.sql WITHOUT them would leave every freshly created
      // database without them, while every creator-scoped assertion in this
      // file stayed green — which is the exact defect this test exists to
      // catch, and the one the positional form would have missed.
      final newest = registry.last;
      expect(
        int.parse(newest),
        greaterThanOrEqualTo(int.parse(creator)),
        reason:
            '$newest is the newest registered version and a chain-migrated '
            'database replays it last; a stamp earlier than $creator could '
            'never be reached',
      );

      final newestDefinition = File(
        p.join(migrationsDir.path, newest, 'definition.sql'),
      );
      expect(
        newestDefinition.existsSync(),
        isTrue,
        reason:
            '$newest is the newest registered version and its definition.sql '
            'is the artifact a fresh database is actually built from',
      );
      final newestSql = newestDefinition.readAsStringSync();
      for (final column in columns) {
        expect(
          newestSql,
          contains('"$column" text'),
          reason:
              'a fresh database is built from $newest/definition.sql, NOT from '
              "the creator's, so $column must be declared there too or every "
              'newly created database silently lacks it',
        );
      }
    });
  });

  group('the generated artefacts describe the change', () {
    Map<String, dynamic> readJson(String name) =>
        jsonDecode(File(p.join(creatorDir.path, name)).readAsStringSync())
            as Map<String, dynamic>;

    Map<String, dynamic> onboardingColumnsFrom(String name) {
      final tables = (readJson(name)['tables'] as List)
          .cast<Map<String, dynamic>>();
      final table = tables.singleWhere((t) => t['name'] == 'onboarding_record');
      return {
        for (final c in (table['columns'] as List).cast<Map<String, dynamic>>())
          c['name'] as String: c,
      };
    }

    test('migration.json is an alterTable, not `actions: []`', () {
      // A DDL migration whose migration.json has no actions would replay as a
      // no-op on a chain-migrated database while its definition.sql says
      // otherwise: the two paths would disagree, and only one of them would
      // have the columns.
      final actions = (readJson('migration.json')['actions'] as List)
          .cast<Map<String, dynamic>>();
      expect(actions, hasLength(1));
      expect(actions.single['type'], 'alterTable');
      final alter = (actions.single['alterTable'] as Map)
          .cast<String, dynamic>();
      expect(alter['name'], 'onboarding_record');
      expect(alter['schema'], 'public');
      final added = (alter['addColumns'] as List)
          .map((c) => (c as Map)['name'])
          .toList();
      expect(added.toSet(), columns.toSet());
      // And nothing else is changed by this migration.
      for (final untouched in [
        'deleteColumns',
        'modifyColumns',
        'addIndexes',
        'deleteIndexes',
        'addForeignKeys',
        'deleteForeignKeys',
      ]) {
        expect(alter[untouched], isEmpty, reason: '$untouched must be empty');
      }
    });

    test('the added columns are nullable Strings in migration.json', () {
      final alter =
          ((readJson('migration.json')['actions'] as List).single
                  as Map)['alterTable']
              as Map;
      for (final c
          in (alter['addColumns'] as List).cast<Map<String, dynamic>>()) {
        expect(
          c['isNullable'],
          isTrue,
          reason: '${c['name']} must be nullable',
        );
        expect(c['dartType'], 'String?');
        expect(c['columnType'], 0, reason: 'Serverpod text == columnType 0');
      }
    });

    test('definition.sql declares the columns on a fresh database', () {
      // Serverpod applies exactly ONE artefact to a database with no recorded
      // version: the LATEST definition.sql. A chain-migrated database replays
      // migration.sql instead. BOTH must carry the columns, or one of the two
      // kinds of database this repository creates silently lacks them.
      final definitionSql = sqlBody(
        File(p.join(creatorDir.path, 'definition.sql')).readAsStringSync(),
      );
      final table = RegExp(
        r'CREATE TABLE "onboarding_record" \((.*?)\);',
        dotAll: true,
      ).firstMatch(definitionSql)!.group(1)!;
      for (final column in columns) {
        final line = table
            .split('\n')
            .firstWhere((l) => l.trim().startsWith('"$column"'));
        expect(line, isNot(contains('NOT NULL')));
        expect(line, contains('text'));
      }
      // The pre-existing columns are untouched.
      for (final column in [
        '"onboardingId"',
        '"productId"',
        '"currentBaselineRevision"',
        '"completed"',
      ]) {
        final line = table
            .split('\n')
            .firstWhere((l) => l.trim().startsWith(column));
        expect(
          line,
          contains('NOT NULL'),
          reason: '$column was already NOT NULL and must stay so',
        );
      }
    });

    test('definition.json and definition_project.json both declare them', () {
      // definition_project.json is the same schema without the serverpod
      // module's own tables; a column added to one and not the other is a
      // generator-diff defect that only a fresh database would surface.
      for (final name in ['definition.json', 'definition_project.json']) {
        final cols = onboardingColumnsFrom(name);
        for (final column in columns) {
          expect(
            cols.containsKey(column),
            isTrue,
            reason: '$name must declare $column',
          );
          expect(cols[column]!['isNullable'], isTrue);
          expect(cols[column]!['dartType'], 'String?');
        }
        // And nothing pre-existing was dropped.
        for (final column in [
          'onboardingId',
          'productId',
          'currentBaselineRevision',
          'pendingClarifications',
          'completed',
          'createdAt',
          'updatedAt',
          'version',
        ]) {
          expect(
            cols.containsKey(column),
            isTrue,
            reason: '$name must still declare $column',
          );
        }
      }
    });

    test('the artefacts differ from the predecessor ONLY in this change', () {
      // A derived artefact that drifts anywhere else — a re-serialised file, a
      // re-ordered table, a bumped serverpod version — is a migration that
      // claims to add three columns and also changes something nobody
      // reviewed. The predecessor is resolved as the previous registry entry.
      final predecessor = registry[registry.indexOf(creator) - 1];
      final prevDir = Directory(p.join(migrationsDir.path, predecessor));

      /// Removes exactly what this migration is allowed to have added, so what
      /// remains can be compared against the predecessor.
      ///
      /// Removing the `control_plane` entry from `installedModules` is part of
      /// the same removal: the version stamp is this migration's own, and the
      /// predecessor's stamp is not the new one's.
      Map<String, dynamic> stripThisMigration(Map<String, dynamic> doc) {
        final tables = (doc['tables'] as List).cast<Map<String, dynamic>>();
        final table = tables.singleWhere(
          (t) => t['name'] == 'onboarding_record',
        );
        table['columns'] = [
          for (final c
              in (table['columns'] as List).cast<Map<String, dynamic>>())
            if (!columns.contains(c['name'])) c,
        ];
        (doc['installedModules'] as List).removeWhere(
          (m) => (m as Map)['module'] == 'control_plane',
        );
        return doc;
      }

      Map<String, dynamic> load(String dir, String name) => stripThisMigration(
        jsonDecode(
              File(p.join(dir, name)).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );

      // `equals(...)`, not `==`: Dart's List does not override `==`, so a bare
      // comparison here is IDENTITY and fails for two documents that are
      // byte-identical — an assertion that looks real and proves nothing.
      expect(
        load(creatorDir.path, 'definition.json')['tables'],
        equals(load(prevDir.path, 'definition.json')['tables']),
        reason:
            'no table other than onboarding_record\'s three columns may '
            'differ from the predecessor',
      );
      expect(
        load(creatorDir.path, 'definition_project.json')['tables'],
        equals(load(prevDir.path, 'definition_project.json')['tables']),
        reason:
            'definition_project.json must carry the same three columns and '
            'nothing else',
      );

      // definition.sql: the same comparison in SQL. This migration's own
      // additions are the three column lines and the version stamp, so both
      // are removed from BOTH sides and what is left must be identical.
      String normaliseSql(String sql) => sql
          .replaceAll("'$predecessor'", "'<version>'")
          .replaceAll("'$creator'", "'<version>'");
      String removeThisMigrationsColumns(String sql) {
        var out = sql;
        for (final column in columns) {
          out = out.replaceAll('    "$column" text,\n', '');
        }
        return out;
      }

      expect(
        removeThisMigrationsColumns(
          normaliseSql(
            File(p.join(creatorDir.path, 'definition.sql')).readAsStringSync(),
          ),
        ),
        normaliseSql(
          File(p.join(prevDir.path, 'definition.sql')).readAsStringSync(),
        ),
        reason:
            'definition.sql must differ from the predecessor only by this '
            "migration's columns and its own version stamp",
      );
    });
  });

  group('the store reads and writes exactly these columns', () {
    test('saveOnboarding names all three, in the INSERT and the SET', () {
      // A column added to the INSERT but not to the ON CONFLICT clause is
      // write-once: the first write lands and every later one silently keeps
      // the original value. That is the exact defect a round-trip test misses
      // and a source assertion catches.
      final store = File(
        p.join(
          repoRoot,
          'apps/server/lib/src/persistence/postgres_product_registry_store.dart',
        ),
      ).readAsStringSync();
      final start = store.indexOf('INSERT INTO "onboarding_record"');
      expect(start, greaterThan(-1));
      final statement = store.substring(start, store.indexOf("'''", start));
      for (final column in columns) {
        expect(
          statement,
          contains('"$column"'),
          reason: '$column must appear in the statement',
        );
        expect(
          statement,
          contains('@$column'),
          reason: '$column must be bound as a named parameter',
        );
      }
      final setClause = statement.substring(statement.indexOf('DO UPDATE SET'));
      for (final column in columns) {
        expect(
          setClause,
          contains('"$column" = EXCLUDED."$column"'),
          reason: '$column must be updated on conflict, not only inserted',
        );
      }
    });

    test('the row mapper reads all three back', () {
      final store = File(
        p.join(
          repoRoot,
          'apps/server/lib/src/persistence/postgres_product_registry_store.dart',
        ),
      ).readAsStringSync();
      final start = store.indexOf('OnboardingRecord _onboardingFromRow(');
      expect(start, greaterThan(-1));
      final body = store.substring(start, store.indexOf('\n  }', start));
      for (final column in columns) {
        expect(
          body,
          contains("'$column'"),
          reason: '$column must be read into the record',
        );
      }
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

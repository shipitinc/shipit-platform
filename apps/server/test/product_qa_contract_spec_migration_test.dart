import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Migration `20261017102506000` — `product_qa_contract_spec`, the table that
/// makes a PRODUCT's declared QA contract reachable.
///
/// ## WHY THIS FILE EXISTS AT ALL
///
/// `AGENTS.md` records that a review lane destroyed the QA database with an
/// unscoped `docker compose down -v`, and that it was unrecoverable. So the
/// properties that matter here are not "the table exists" but "nothing else
/// changed" and "re-running it is a no-op": a migration that quietly altered an
/// existing table, or that is not idempotent, is a migration that cannot be
/// re-applied after a partial failure without taking more with it.
///
/// These are properties of SQL and of files on disk, so they are asserted as
/// such. Reading the artefacts is the only way to see them, and a reviewer
/// reading a diff is not a check that fails.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  const table = 'product_qa_contract_spec';
  const version = '20261017102506000';

  final registry = File(p.join(migrationsDir.path, 'migration_registry.txt'))
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();

  /// Strips `--` comments so a banner that NAMES an object or a forbidden verb
  /// cannot satisfy a check that is supposed to find the statement that does it.
  ///
  /// Load-bearing here, not tidy: this migration's banner discusses `DROP`,
  /// `ALTER`, `TRUNCATE`, `DELETE` and `UPDATE` by name while explaining that
  /// none of them appear. Without the strip, every negative assertion below
  /// would pass for the wrong reason — and then fail the moment someone edited
  /// the prose.
  String sqlBody(String sql) => sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  /// Every migration whose `migration.sql` CREATES the table, found by
  /// scanning, never by registry position. See
  /// `operator_action_migration_test.dart` for why position is the wrong
  /// identity: it is true only while the creator happens to be newest, and any
  /// later migration breaks every assertion that reads it.
  final creators = <String>[
    for (final entry in migrationsDir.listSync())
      if (entry is Directory)
        if (File(p.join(entry.path, 'migration.sql')).existsSync())
          if (sqlBody(
                File(p.join(entry.path, 'migration.sql')).readAsStringSync(),
                // The `IF NOT EXISTS ` sits between CREATE TABLE and the quoted
                // name, so the bare form is matched in the stripped body.
              ).contains('CREATE TABLE IF NOT EXISTS "$table"') ||
              sqlBody(
                File(p.join(entry.path, 'migration.sql')).readAsStringSync(),
              ).contains('CREATE TABLE "$table"'))
            p.basename(entry.path),
  ]..sort();

  if (creators.isEmpty) {
    // Deliberate: with no creator every assertion below would read nothing and
    // pass for the wrong reason.
    throw StateError(
      'no migration under ${migrationsDir.path} creates "$table". The '
      'assertions in this file resolve the table by scanning migrations for its '
      'DDL; with none they would pass vacuously.',
    );
  }

  final creator = creators.first;
  final creatorDir = Directory(p.join(migrationsDir.path, creator));
  final migrationSql = File(
    p.join(creatorDir.path, 'migration.sql'),
  ).readAsStringSync();
  final definitionSql = File(
    p.join(creatorDir.path, 'definition.sql'),
  ).readAsStringSync();
  final body = sqlBody(migrationSql);

  /// [body] with Serverpod's own `serverpod_migrations` bookkeeping removed.
  ///
  /// The version stamp is an `INSERT ... ON CONFLICT DO UPDATE` against
  /// `serverpod_migrations`, which every migration in this repository carries
  /// and which the applier needs in order to record that the DDL above
  /// happened. Leaving it in the body makes a blanket "no UPDATE" check
  /// unsatisfiable — or, worse, satisfiable only by someone deleting the stamp,
  /// which is the one thing that must never be deleted. The data DML checks
  /// below are about EXISTING DATA, so the bookkeeping is excluded from them
  /// explicitly rather than the checks being weakened until they pass.
  final dataBody = body.replaceAll(
    RegExp(
      r'INSERT INTO "serverpod_migrations"[\s\S]*?;',
      caseSensitive: false,
    ),
    '',
  );

  /// The definition a FRESH database is actually built from. Positional by
  /// nature, and that is the mechanism rather than a proxy for it: Serverpod
  /// applies exactly one artefact to a database with no recorded migration
  /// version, and it is the newest `definition.sql`.
  final freshVersion = registry.last;
  final freshDefinition = File(
    p.join(migrationsDir.path, freshVersion, 'definition.sql'),
  );

  group('additive: it creates one table and changes nothing else', () {
    test(
      'exactly one migration creates it, and the registry lists it once',
      () {
        expect(
          creators,
          hasLength(1),
          reason:
              'a second origin for the table means two creation paths and no '
              'single migration whose SQL can be held to the checks below',
        );
        expect(registry.where((e) => e == creator), hasLength(1));
        expect(creator, version, reason: 'this file pins ONE migration, named');
      },
    );

    test('it creates EXACTLY ONE table, and it is this one', () {
      final created = RegExp(
        r'CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?\"([^\"]+)\"',
      ).allMatches(body).map((m) => m.group(2)!).toList();
      expect(created, [table]);
    });

    test('it changes NO existing table', () {
      // The backward-compatibility property that makes this safe to run against
      // a database the repository cannot recreate. An `ALTER` here would be a
      // production-affecting change hiding inside a new-table migration.
      for (final forbidden in [
        r'\bALTER\s+TABLE\b',
        r'\bDROP\s+TABLE\b',
        r'\bDROP\s+COLUMN\b',
        r'\bDROP\s+INDEX\b',
        r'\bTRUNCATE\b',
        r'\bDELETE\s+FROM\b',
        r'\bUPDATE\s+(?!set\b)',
        r'\bCREATE\s+OR\s+REPLACE\b',
      ]) {
        expect(
          RegExp(forbidden, caseSensitive: false).hasMatch(dataBody),
          isFalse,
          reason:
              '$forbidden must not appear in the executable body. Every existing '
              'row of every existing table must read back exactly as it did '
              'before, which is the only property that makes re-running this '
              'migration after a partial failure safe.',
        );
      }
    });

    test('the down section stays COMMENTED, so nothing rolls back by accident', () {
      expect(
        RegExp(
          r'^\s*DROP\s+TABLE',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(migrationSql),
        isFalse,
        reason:
            'the rollback is documented as prose plus `-- `-commented SQL. An '
            'uncommented DROP TABLE would run at the end of every migration and '
            'delete every declared QA contract in the database.',
      );
      // ...and the commented form IS present, so a reviewer can see the rollback
      // exists rather than inferring its absence from an absence.
      expect(migrationSql, contains('-- DROP TABLE IF EXISTS "$table";'));
    });
  });

  group('idempotent: re-running it is a no-op', () {
    test('every CREATE carries IF NOT EXISTS', () {
      // Serverpod replays `migration.sql` onto databases that were bootstrapped
      // by another path and onto databases where an operator applied the DDL by
      // hand. Without the guard the second run aborts the transaction and takes
      // the `serverpod_migrations` version stamp down with it, leaving a
      // database that believes it is at this version and is not.
      final creates = RegExp(
        r'CREATE\s+(UNIQUE\s+)?(TABLE|INDEX)\s+(IF\s+NOT\s+EXISTS\s+)?"',
        caseSensitive: false,
      ).allMatches(body);
      expect(
        creates,
        isNotEmpty,
        reason: 'nothing to check if there is no DDL',
      );
      for (final m in creates) {
        expect(
          m.group(3),
          isNotNull,
          reason:
              'CREATE ${m.group(1) ?? ''}${m.group(2)} "${m.group(0)}" is '
              'missing its IF NOT EXISTS guard',
        );
      }
    });

    test(
      'the column shape is ASSERTED after the guarded CREATE, so a table of '
      'the same NAME but a different shape is refused rather than accepted',
      () {
        expect(
          body,
          contains('information_schema."columns"'),
          reason:
              'IF NOT EXISTS makes the CREATE a no-op against a pre-existing '
              'table that says something else, and then the migration would '
              'stamp its version onto a database whose table is not this one. '
              'Reading the columns back and refusing is what makes the guard '
              'safe rather than merely quiet.',
        );
        for (final column in const [
          'productId',
          'gatesJson',
          'manifestVersion',
          'createdAt',
          'updatedAt',
          'version',
        ]) {
          expect(
            body,
            contains(column),
            reason:
                '$column is bound by the Dart store, so the migration must '
                'have created it',
          );
        }
      },
    );
  });

  group('it is stamped last, in one transaction', () {
    test('BEGIN, then DDL, then both version rows, then COMMIT', () {
      expect(body.trimLeft().startsWith('BEGIN;'), isTrue);
      expect(body.trimRight().endsWith('COMMIT;'), isTrue);

      // The version rows come after every DDL statement, which is what makes a
      // failure roll the DDL back WITH the stamp instead of leaving a database
      // that claims a version it does not have.
      final lastDdl = body.lastIndexOf('RAISE EXCEPTION');
      expect(lastDdl, greaterThan(0));
      for (final module in ['control_plane', 'serverpod']) {
        final stamp = body.indexOf("VALUES ('$module'");
        expect(
          stamp,
          greaterThan(lastDdl),
          reason: 'the $module version row must be the LAST thing written',
        );
      }
      expect(body, contains("VALUES ('control_plane', '$version'"));
    });
  });

  group('both database-creation paths reach the table', () {
    // Serverpod applies the LATEST definition.sql to a fresh database and
    // replays every migration.sql to a chain-migrated one. Both must reach the
    // table or one of the two databases this repository creates lacks it.
    test(
      'the creating migration declares the table in its own definition.sql',
      () {
        expect(
          sqlBody(definitionSql).contains('CREATE TABLE "$table"'),
          isTrue,
        );
      },
    );

    test('the FRESH-database path carries the table too', () {
      expect(
        freshDefinition.existsSync(),
        isTrue,
        reason:
            'the newest registered version is the artefact a fresh database is '
            'actually built from, and it has to exist for the check below to '
            'read anything rather than passing vacuously',
      );
      final freshBody = sqlBody(freshDefinition.readAsStringSync());
      expect(
        freshBody.contains('CREATE TABLE "$table"'),
        isTrue,
        reason:
            '$freshVersion is the newest registered version and a fresh '
            'database is built from its definition.sql, NOT from the creator\'s. '
            'A definition.sql without this table leaves every newly created '
            'database — CI included — without it while the chain-migrated path '
            'works, and the creator-scoped assertions above all stay green.',
      );
    });

    test('the fresh definition is the previous schema PLUS this table', () {
      // Not merely "contains it": the definition is a full snapshot, so a fresh
      // database built from it must still carry every table the chain-migrated
      // one has. Two tables that both satisfied "contains the table" while
      // differing everywhere else is exactly the divergence these tests exist
      // to catch.
      // The baseline is the schema as of BEFORE THIS MIGRATION, not the entry
      // before `freshVersion`. The two coincide only while this migration is the
      // newest; once a later migration exists, `registry.last - 1` IS this
      // migration, and the delta being computed would be the later one's alone.
      // With the creator's own predecessor as the baseline, the delta is
      // "everything later migrations added", and this table is covered by the
      // `contains` assertion below rather than by the delta.
      final previous = registry[registry.indexOf(creator) - 1];
      final previousBody = sqlBody(
        File(
          p.join(migrationsDir.path, previous, 'definition.sql'),
        ).readAsStringSync(),
      );
      final freshBody = sqlBody(freshDefinition.readAsStringSync());
      final previousTables = RegExp(
        r'CREATE TABLE \"([^\"]+)\"',
      ).allMatches(previousBody);
      expect(previousTables, isNotEmpty);
      for (final m in previousTables) {
        expect(
          freshBody.contains('CREATE TABLE "${m.group(1)}"'),
          isTrue,
          reason:
              '"${m.group(1)}" was in $previous and must still be in '
              '$freshVersion, or a fresh database loses it',
        );
      }
      final freshTables = RegExp(
        r'CREATE TABLE \"([^\"]+)\"',
      ).allMatches(freshBody).map((m) => m.group(1)!).toSet();
      final previousSet = previousTables.map((m) => m.group(1)).toSet();
      final added = freshTables.difference(previousSet);
      expect(
        added,
        contains(table),
        reason:
            'the snapshot must add this table. A table missing from the fresh '
            'path is a table a new database silently does not have.',
      );
      // ...and every OTHER table it adds must be one a LATER migration created.
      //
      // This used to be `{table}` exactly, which was true only while this
      // migration was the newest — a property of the registry's TAIL, not of
      // this migration, so it went false the moment a later table was added
      // and the assertion could only be satisfied by editing it. It is stated
      // the same strength without the version: the snapshot may add tables, and
      // each added table must be traceable to a migration registered at or
      // after this one. A table appearing in the fresh path with NO creating
      // migration is the shape this guards against — the divergence
      // `verify_schema_bootstrap.sh` exists for, where a fresh database and a
      // chain-migrated one enforce different things.
      final creatorIndex = registry.indexOf(creator);
      final unexplained = added.where((name) {
        final declaring = registry
            .sublist(creatorIndex)
            .where(
              (version) => _createsTable(migrationsDir, version, name),
            );
        return declaring.isEmpty;
      }).toSet();
      expect(
        unexplained,
        isEmpty,
        reason:
            '${unexplained.join(', ')} appear(s) in $freshVersion but no '
            'migration registered at or after $creator creates it. A table with '
            'no migration is a table a chain-migrated database does not have.',
      );
    });
  });

  group('registration', () {
    // F-09: `20261006150645000` is a directory the committed registry does not
    // list, and no guard compares the two sets. So "the generator appends
    // whatever is missing" is a claim about the generator, not about this
    // repository, and a migration that is correct but unregistered is a
    // migration whose freshness is a matter of chance. These assertions are
    // what makes the registration a checked fact.
    test('the migration is listed in migration_registry.txt', () {
      expect(
        registry,
        contains(version),
        reason:
            'Serverpod 3.4.13 `listVersions()` ignores the registry and '
            'enumerates migration DIRECTORIES, so an unregistered migration '
            'still runs — which means the registry is not what makes this '
            'migration reach a database. Registering it is still required: the '
            'registry is what the two migration guard tests read to resolve '
            '`registry.last`, and that is the artefact a fresh database is '
            'built from.',
      );
    });

    test('it is registered AFTER every earlier migration, and the fresh path is '
        'at or after it', () {
      final numeric = registry.map(int.parse).toList(growable: false);
      expect(
        numeric,
        orderedEquals(
          [...numeric]..sort(),
        ),
        reason:
            'the registry is applied in order; an out-of-order entry is a '
            'migration that can never be reached',
      );
      // The creator sits after its own PREDECESSOR, not at the end of the
      // registry. This used to assert it was the LAST entry, which is a
      // statement about the registry's tail rather than about this migration,
      // and it went false the moment any later migration was added. What the
      // fresh-database assertions above need is that the artefact they read is
      // at least as new as the creator, and that is what is asserted here.
      final creatorIndex = registry.indexOf(creator);
      expect(creatorIndex, greaterThan(0));
      expect(
        int.parse(creator),
        greaterThan(int.parse(registry[creatorIndex - 1])),
      );
      expect(
        int.parse(freshVersion),
        greaterThanOrEqualTo(int.parse(creator)),
        reason:
            '$freshVersion is the artefact a fresh database is built from, so '
            'it cannot predate the migration that creates $table',
      );
    });

    test(
      'the migration directory carries every artefact the applier reads',
      () {
        for (final artefact in const [
          'migration.sql',
          'migration.json',
          'definition.sql',
          'definition.json',
          'definition_project.json',
        ]) {
          expect(
            File(p.join(creatorDir.path, artefact)).existsSync(),
            isTrue,
            reason:
                '$artefact is read by Serverpod or by a guard; a missing one '
                'is a migration that is half-applied',
          );
        }
      },
    );

    test(
      'the generated JSON definition describes the table, so a later '
      'regeneration does not quietly disagree with the SQL',
      () {
        final definition = File(
          p.join(creatorDir.path, 'definition.json'),
        ).readAsStringSync();
        expect(definition, contains('"$table"'));
        for (final column in const [
          'productId',
          'gatesJson',
          'manifestVersion',
          'createdAt',
          'updatedAt',
          'version',
        ]) {
          expect(definition, contains('"$column"'));
        }
      },
    );
  });

  group('what this migration deliberately does NOT do', () {
    // Each of these is a decision a reviewer would otherwise have to infer from
    // the absence of code, and each is a change that would be a DIFFERENT lane.
    test('it declares no QA contract for any product', () {
      expect(
        RegExp(
          r'\bINSERT\s+INTO\s+"?product_qa_contract_spec"?\s*\(?\s*"?productId',
          caseSensitive: false,
        ).hasMatch(body),
        isFalse,
        reason:
            'the table is EMPTY after this migration. Declaring a contract for a '
            'product is a human act taken through `createProduct` with a '
            'manifest; a migration that invented one would be the platform '
            'asserting a QA policy nobody wrote.',
      );
    });

    test('it moves no work item and repairs no row', () {
      for (final table in const ['work_item', 'work_item_transition', 'job']) {
        expect(
          body.contains('"$table"'),
          isFalse,
          reason:
              '$table is not mentioned in the executable body. The three items '
              'stranded in agentExecuting need a human operator transition '
              'after their contracts exist — agentExecuting has no edge to '
              'anything but agentCompleted and agentFailed — and this change '
              'makes that recovery POSSIBLE without performing it.',
        );
      }
    });

    test('it does not touch the completion guard', () {
      expect(
        body.toLowerCase().contains('guard_condition'),
        isFalse,
        reason:
            'the guard stays exactly as strict as it is. This change makes a '
            'real contract reachable; narrowing or removing the guard would be '
            'the other route and it is not this one.',
      );
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    // `packages/` AND `apps/` at the same level is the workspace root.
    // `apps/server` also has a `pubspec.yaml` and an `apps/` directory of its
    // own, so anchoring on the pubspec finds the wrong root — which then makes
    // every path below it unresolvable and this whole file fails to load.
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

/// Whether the migration in `migrationsDir/version` CREATEs [name].
///
/// Scans the migration's executable SQL rather than trusting its position or
/// its `definition.sql`: the fresh-database snapshot is rendered from the
/// models, so a table can be in it without any migration having created it, and
/// that is precisely the divergence this predicate exists to detect.
///
/// `--` comments are stripped first so a banner that names the table cannot
/// answer the question.
bool _createsTable(Directory migrationsDir, String version, String name) {
  final sql = File(p.join(migrationsDir.path, version, 'migration.sql'));
  if (!sql.existsSync()) return false;
  return RegExp(
    'CREATE\\s+TABLE\\s+(IF\\s+NOT\\s+EXISTS\\s+)?"$name"',
    caseSensitive: false,
  ).hasMatch(
    sql
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n'),
  );
}

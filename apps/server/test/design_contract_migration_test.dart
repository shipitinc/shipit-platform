import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Migration `20261018180816929` — `design_contract`, the durable design contract
/// the design governance runtime needs so that `designRequired` stops being a
/// state with nothing behind it.
///
/// ## WHY THIS FILE EXISTS AT ALL
///
/// Two of the properties that matter here are not "the table exists" but "this
/// was not hand-written" and "nothing else changed".
///
/// * **It was not hand-written.** Serverpod rebuilds `definition.sql` from the
///   `.spy.yaml` models on every `create-migration`. A hand-appended
///   `CREATE TABLE "design_contract"` would survive until the next regeneration
///   and then collide with the generator's own `CREATE TABLE` of the same name
///   — on a database this repository cannot recreate (AGENTS.md, "Shared Docker
///   state"). So the three declarations of the column list — the model, the
///   migration, and the definition — are asserted to be the SAME list, which is
///   only possible if the generator produced the latter two from the former.
/// * **Nothing else changed.** A migration that quietly altered an existing table
///   is a migration that cannot be re-applied after a partial failure without
///   taking more with it. The properties are properties of SQL and of files on
///   disk, so they are asserted as such; a reviewer reading a diff is not a
///   check that fails.
///
/// ## WHAT IT DELIBERATELY DOES NOT DO
///
/// It creates no contract, provisions no work item, and touches no state. Every
/// value below is a `null` or an empty table, and the assertions that hold them
/// there are what make "this is a foundation, not a switch" checkable rather than
/// a claim. In particular it does not widen `planned -> designRequired`: that
/// guard still reads caller-supplied context, and §9 step 2 is what changes it.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  const table = 'design_contract';
  const version = '20261018180816929';

  /// The unmanaged table this migration's generator run would otherwise have
  /// erased. See the group below; it is named here because it is a subject of
  /// this file, not an aside.
  const unmanagedSibling = 'product_qa_contract_spec';

  final registry = File(p.join(migrationsDir.path, 'migration_registry.txt'))
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();

  /// Strips `--` comments so a banner that NAMES an object or a forbidden verb
  /// cannot satisfy a check that is supposed to find the statement that does it.
  String sqlBody(String sql) => sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  /// Every migration whose `migration.sql` CREATES the table, found by scanning,
  /// never by registry position — see
  /// `operator_action_migration_test.dart` for why position is the wrong
  /// identity.
  final creators = <String>[
    for (final entry in migrationsDir.listSync())
      if (entry is Directory)
        if (File(p.join(entry.path, 'migration.sql')).existsSync())
          if (RegExp(
            'CREATE\\s+TABLE\\s+(IF\\s+NOT\\s+EXISTS\\s+)?"$table"',
            caseSensitive: false,
          ).hasMatch(
            sqlBody(
              File(p.join(entry.path, 'migration.sql')).readAsStringSync(),
            ),
          ))
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

  /// [body] with Serverpod's own `serverpod_migrations` bookkeeping removed —
  /// that stamp is an `INSERT … ON CONFLICT DO UPDATE` every migration in this
  /// repository carries, so leaving it in makes a blanket "no UPDATE" check
  /// unsatisfiable.
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

  /// The columns of [table] in declaration order, read out of a `CREATE TABLE`
  /// body. Returns `[]` when the statement is absent, so a caller asserting
  /// `orderedEquals` on an empty list fails rather than reading nothing.
  List<String> columnsOf(String sql) {
    final match = RegExp(
      'CREATE\\s+TABLE\\s+"$table"\\s*\\(([^;]*?)\\);',
      dotAll: true,
    ).firstMatch(sql);
    if (match == null) return const [];
    return RegExp(
      r'"([A-Za-z][A-Za-z0-9]*)"\s',
    ).allMatches(match.group(1)!).map((m) => m.group(1)!).toList();
  }

  group('it is MANAGED, not hand-written DDL', () {
    // The property the whole approach rests on. A table with no `.spy.yaml`
    // model cannot be regenerated, and a hand-written `CREATE TABLE` in a
    // generated file is erased by the next `serverpod create-migration` — after
    // which the generator emits its own `CREATE TABLE` of the same name against a
    // database that already has one.
    final model = File(
      p.join(repoRoot, 'apps/server/lib/src/database/$table.spy.yaml'),
    );

    test('a model exists for it', () {
      expect(
        model.existsSync(),
        isTrue,
        reason:
            '$table is declared as a Serverpod model in '
            'apps/server/lib/src/database/$table.spy.yaml. Without one the '
            'generator knows nothing about it and no DDL for it can be '
            'regenerated.',
      );
    });

    test('the model declares the table and is NOT unmanaged', () {
      final yaml = model.readAsStringSync();
      expect(yaml, contains('table: $table'));
      expect(
        RegExp(r'^\s*managed:\s*false', multiLine: true).hasMatch(yaml),
        isFalse,
        reason:
            '`managed: false` tells the generator to know the table without ever '
            'rendering its DDL. That is the shape this migration exists to '
            'avoid: it is how an unregeneratable table gets into the tree.',
      );
    });

    test(
      'the MODEL, the MIGRATION and the DEFINITION declare the SAME columns, in '
      'the same order',
      () {
        // This is the falsifier for "the DDL was generated, not typed". Three
        // lists that agree can only come from one declaration; a hand-written
        // table and a model that disagrees fails here, in whichever direction it
        // disagrees.
        final modelFields = RegExp(r'^  ([A-Za-z][A-Za-z0-9]*):', multiLine: true)
            .allMatches(model.readAsStringSync())
            .map((m) => m.group(1)!)
            // `indexes:` entries are nested two spaces deeper and so cannot
            // appear here; the only two-space keys are `class:`, `table:` and
            // `serverOnly:`, none of which is a column.
            .where((k) => !const ['class', 'table', 'serverOnly'].contains(k))
            .toList();
        expect(
          modelFields,
          isNotEmpty,
          reason:
              'the model declares no fields, so there is nothing to compare',
        );

        final fromMigration = columnsOf(body);
        final fromDefinition = columnsOf(sqlBody(definitionSql));
        expect(
          fromMigration,
          orderedEquals(['id', ...modelFields]),
          reason:
              'the migration binds the columns the model declares. A migration '
              'carrying a different list is a table the model does not describe.',
        );
        expect(
          fromDefinition,
          orderedEquals(fromMigration),
          reason:
              'the fresh-database definition and the chain-migrated migration '
              'must create the same table, or the two database-creation paths '
              'disagree about what "$table" is.',
        );
      },
    );

    test('the generated JSON describes the table as managed', () {
      // Parsed rather than pattern-matched: the assertion is about the CONTENT
      // of one entry, and a regex over pretty-printed JSON would fail on a
      // reformat while passing on an entry that said the wrong thing.
      final definition =
          jsonDecode(
                File(
                  p.join(creatorDir.path, 'definition.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final tables = (definition['tables'] as List)
          .cast<Map<String, dynamic>>();
      final entries = tables
          .where((t) => t['name'] == table)
          .toList(growable: false);
      expect(
        entries,
        hasLength(1),
        reason:
            'definition.json must describe $table exactly once for the next '
            'regeneration to reproduce it',
      );
      expect(
        entries.single['managed'],
        isNot(false),
        reason:
            'a `managed: false` entry is known to the generator but never '
            'rendered, so the DDL would exist only as long as nobody '
            'regenerated — which is exactly the property this migration '
            'exists to avoid.',
      );
      expect(
        (entries.single['columns'] as List)
            .cast<Map<String, dynamic>>()
            .map((c) => c['name'])
            .toList(),
        orderedEquals(columnsOf(sqlBody(definitionSql))),
        reason:
            'the JSON the next regeneration reads and the SQL a fresh database '
            'is built from must describe the same table',
      );
    });

    test('a generated Dart row class exists for it', () {
      final generated = File(
        p.join(
          repoRoot,
          'apps/server/lib/src/generated/database/$table.dart',
        ),
      );
      expect(
        generated.existsSync(),
        isTrue,
        reason:
            '`serverpod generate` writes one Dart row class per model. Its '
            'absence means the model was added without being generated, and the '
            'migration above would then describe a table nothing reads.',
      );
      expect(generated.readAsStringSync(), contains("tableName: '$table'"));
    });
  });

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
        r'CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?"([^"]+)"',
      ).allMatches(body).map((m) => m.group(2)!).toList();
      expect(created, [table]);
    });

    test('it drops NOTHING', () {
      // The catastrophic shape for a table this repository cannot recreate: a
      // `DROP TABLE` here runs against the live stack on the next apply. It is
      // asserted separately from the other verbs because it is the one whose
      // consequence is unrecoverable rather than merely noisy.
      expect(
        RegExp(r'\bDROP\s+TABLE\b', caseSensitive: false).hasMatch(dataBody),
        isFalse,
      );
    });

    test('it changes NO existing table', () {
      for (final forbidden in [
        r'\bALTER\s+TABLE\b',
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
      // The generator emits no down section at all for this migration, which is
      // why there is nothing to uncomment. Asserting the absence is what keeps
      // it true: a down script added later would have to be deliberately
      // uncommented, and a reviewer reading that diff sees the choice.
      expect(
        RegExp(
          r'^\s*DROP\s+TABLE',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(migrationSql),
        isFalse,
        reason:
            'an uncommented DROP TABLE would run at the end of every migration '
            'and delete every design contract in the database.',
      );
    });
  });

  group('both database-creation paths reach the table', () {
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
      expect(
        sqlBody(
          freshDefinition.readAsStringSync(),
        ).contains('CREATE TABLE "$table"'),
        isTrue,
      );
    });

    test('the fresh definition is the previous schema PLUS this table', () {
      // Not merely "contains it": the definition is a full snapshot, so a fresh
      // database built from it must still carry every table the chain-migrated
      // one has.
      final previous = registry[registry.indexOf(freshVersion) - 1];
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
      ).allMatches(freshBody).map((m) => m.group(1)).toSet();
      final previousSet = previousTables.map((m) => m.group(1)).toSet();
      expect(
        freshTables.difference(previousSet),
        {table},
        reason:
            'the snapshot must add exactly this table and drop nothing. A table '
            'missing from the fresh path is a table a new database silently '
            'does not have.',
      );
    });

    test(
      'the fresh path still carries the UNMANAGED table, which the generator '
      'run for this migration would otherwise have erased',
      () {
        // MEASURED, NOT ASSUMED. Running `serverpod create-migration` for this
        // table rebuilt every `definition.sql` from the models, and
        // `$unmanagedSibling` — declared in no model, present only as a
        // `managed: false` entry in the previous `definition.json` — vanished
        // from the output. The chain-migrated path was unaffected (its DDL is
        // in `20261017102506000/migration.sql`), so the divergence was silent:
        // `verify:schema-deviations` does not list this table and
        // `verify_schema_bootstrap.sh` does not either. A fresh database built
        // after that run would have had no `$unmanagedSibling`, and
        // `PostgresProductQAContractSpecStore` binds parameters to it.
        //
        // So the entry was restored, byte for byte, and this assertion is what
        // stops the next regeneration from doing it again unnoticed.
        expect(
          sqlBody(
            freshDefinition.readAsStringSync(),
          ).contains('CREATE TABLE "$unmanagedSibling"'),
          isTrue,
          reason:
              '$freshVersion is the artefact a fresh database is built from. '
              'A definition.sql without $unmanagedSibling leaves every newly '
              'created database — CI included — without a table the '
              'product-QA-contract store writes to, while the chain-migrated '
              'path works and every other assertion stays green.',
        );
      },
    );
  });

  group('registration', () {
    test('the migration is listed in migration_registry.txt', () {
      expect(
        registry,
        contains(version),
        reason:
            'Serverpod 3.4.13 `listVersions()` ignores the registry and '
            'enumerates migration DIRECTORIES, so an unregistered migration '
            'still runs. Registering it is still required: the registry is what '
            'the migration guard tests read to resolve `registry.last`, and that '
            'is the artefact a fresh database is built from.',
      );
    });

    test('the registry is in ascending version order', () {
      final numeric = registry.map(int.parse).toList(growable: false);
      expect(
        numeric,
        orderedEquals([...numeric]..sort()),
        reason:
            'the registry is applied in order; an out-of-order entry is a '
            'migration that can never be reached',
      );
      expect(
        int.parse(version),
        greaterThan(int.parse(registry[registry.indexOf(version) - 1])),
        reason:
            'a migration registered before its own predecessor can never be '
            'applied after it, so the chain stops one version short',
      );
    });

    test('the migration directory carries every artefact the applier reads', () {
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
              '$artefact is read by Serverpod or by a guard; a missing one is a '
              'migration that is half-applied',
        );
      }
    });
  });

  group('what this migration deliberately does NOT do', () {
    test('it provisions no design contract', () {
      expect(
        RegExp(
          // NOT a raw string: `$table` is the interpolated table name, and in a
          // raw string it would be the four literal characters `$table` — which
          // matches no DDL, so the assertion below would pass for the wrong
          // reason. MEASURED: inserting a real `INSERT INTO "design_contract"`
          // left this test green until the raw string was replaced.
          '\\bINSERT\\s+INTO\\s+"?$table"?',
          caseSensitive: false,
        ).hasMatch(body),
        isFalse,
        reason:
            'the table is EMPTY after this migration. A design contract is '
            'written by the builder when a remediation work item is created, '
            'and no work item is created by a migration — a migration that '
            'inserted one would be the platform asserting a design requirement '
            'nobody filed.',
      );
    });

    test('it creates no work item and moves no workflow state', () {
      for (final table in const [
        'work_item',
        'work_item_transition',
        'job',
      ]) {
        expect(
          body.contains('"$table"'),
          isFalse,
          reason:
              '$table is not mentioned in the executable body. §9 step 1 is a '
              'foundation; the state walk that consumes it is step 3, and a '
              'migration that moved a work item would be doing step 3\'s work '
              'in a place nobody reviews it.',
        );
      }
    });

    test('it does not touch the guard that step 2 owns', () {
      expect(
        body.toLowerCase().contains('guard_condition'),
        isFalse,
        reason:
            'designContractExists() still reads caller-supplied context. This '
            'migration makes a real contract WRITABLE; changing what the guard '
            'accepts is step 2, and doing it here would close '
            'planned -> designRequired before anything can satisfy it.',
      );
    });

    test('it mounts nothing', () {
      // Switching the runtime ON is §9 step 8 and depends on step 6. A
      // migration cannot mount a scheduler, but it CAN leave a `sched-design-*`
      // scheduler row behind, which is the same mistake in a place migrations
      // are not reviewed for it.
      expect(
        RegExp(r'sched-design', caseSensitive: false).hasMatch(body),
        isFalse,
      );
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    // `packages/` AND `apps/` at the same level is the workspace root.
    // `apps/server` also has a `pubspec.yaml` and an `apps/` directory of its
    // own, so anchoring on the pubspec finds the wrong root.
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

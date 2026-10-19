import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `20261019010044759` — the destructive route that adds
/// `fidelityAnchorSchemaVersion` to `design_revision`, and the guard that keeps
/// it from silently deleting the two invariants it cascades away.
///
/// ## WHAT WENT WRONG
///
/// `serverpod create-migration` cannot add a `NOT NULL` column to an existing
/// table without a default, so it emitted the authorised destructive route:
///
/// ```sql
/// DROP TABLE "design_revision" CASCADE;
/// CREATE TABLE "design_revision" ( ... "fidelityAnchorSchemaVersion" text NOT NULL ... );
/// ```
///
/// The generated `CREATE TABLE` carries ONLY the four `.spy.yaml` indexes, because
/// those four are the only ones the generator can express. Two objects on that
/// table have no model and exist only as hand-maintained DDL:
///
///   * `design_revision_approved_unique_per_work_item` — the PARTIAL unique index
///     making "at most one approved revision per work item" exclusive under
///     concurrency rather than a read-modify-write race;
///   * `trigger_design_revision_immutability` — the BEFORE UPDATE trigger making
///     an approved design revision an audit record that cannot be edited in place.
///
/// `CASCADE` removed both. On a FRESH database nothing is lost, because the
/// newest `definition.sql` builds the table and `tool/schema_bootstrap.sql` then
/// re-creates both objects by hand. On a CHAIN-MIGRATED database — every
/// developer machine, QA and production — no `migration.sql` after this one ever
/// runs again, and nothing recreates them.
///
/// ## WHY NO EXISTING GATE SAW IT, AND WHY THIS FILE IS STATIC
///
/// `make test-integration` and CI both build FRESH (`definition.sql` then
/// `tool/schema_bootstrap.sql`), so they restore the two objects by a different
/// route and cannot observe this loss. `tool/verify_schema_bootstrap.sh` builds
/// its `chain_ddl` by CONCATENATING every `migration.sql` and grepping the
/// concatenation for the DDL; a `DROP` does not remove `20260920232118956`'s
/// text from that concatenation, so all of its checks pass with the restores
/// deleted. A destructive migration is invisible to a textual-presence check by
/// construction.
///
/// Replaying the chain against a real database is the only runtime proof, and no
/// gate in this repository does it — `test/integration` shares one freshly
/// bootstrapped database, and replaying `DROP TABLE ... CASCADE` into it would
/// destroy the rows every other file in that directory asserts on. So the property
/// asserted here is the property of the FILE, which is what was wrong: this
/// migration must own every object the CASCADE removed. That is deterministic,
/// needs no database, and fails closed when the file is regenerated.
///
/// `product_qa_contract_spec_migration_test.dart` is the precedent: the same
/// hand-maintained-DDL-inside-a-generated-migration shape, guarded by reading the
/// artefacts rather than by convention.
///
/// ## NON-VACUITY
///
/// The coverage check below DERIVES the set of objects that lived on
/// `design_revision` before this migration, by scanning every EARLIER
/// `migration.sql` for index and trigger DDL naming that table — it does not
/// read the set from this file, which would make a missing restore simply drop
/// out of the set and pass. The derivation is additionally asserted to have found
/// the two named objects, so a scan that stopped matching is a failure rather
/// than a smaller, greener set.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  const table = 'design_revision';
  const originVersion = '20260920232118956';
  const destructiveVersion = '20261019010044759';
  const indexName = 'design_revision_approved_unique_per_work_item';
  const triggerName = 'trigger_design_revision_immutability';
  const functionName = 'enforce_design_revision_immutability';

  final destructiveSql = _readMigration(migrationsDir, destructiveVersion);
  final destructiveBody = _stripCommentLines(destructiveSql);
  final originSql = _readMigration(migrationsDir, originVersion);
  final originBody = _stripCommentLines(originSql);

  /// Every earlier migration, in registry order, as `(version, comment-stripped
  /// SQL)`. The set of objects this file must restore is read from these and
  /// from nowhere else.
  final earlier = <(String, String)>[
    for (final version in _registryVersions(migrationsDir))
      if (int.parse(version) < int.parse(destructiveVersion))
        (version, _stripCommentLines(_readMigration(migrationsDir, version))),
  ];

  group('premises: the file really is the destructive route', () {
    test('it drops the table CASCADE and recreates it with the new column', () {
      expect(
        RegExp(
          'DROP\\s+TABLE\\s+"$table"\\s+CASCADE\\s*;',
          caseSensitive: false,
        ).hasMatch(destructiveBody),
        isTrue,
        reason:
            'this file asserts things about a migration that destroys and '
            'recreates "$table". If that is no longer what it does, the guards '
            'below are guarding nothing.',
      );
      final create = RegExp(
        'CREATE\\s+TABLE\\s+"$table"\\s*\\(([\\s\\S]*?)\\n\\);',
      ).firstMatch(destructiveBody);
      expect(
        create,
        isNotNull,
        reason: 'the recreated table declaration could not be read',
      );
      expect(
        create!.group(1),
        contains('"fidelityAnchorSchemaVersion" text NOT NULL'),
        reason: 'the column this migration exists to add',
      );
      expect(
        earlier,
        isNotEmpty,
        reason:
            'no migration earlier than $destructiveVersion could be read, so '
            '"what the CASCADE removed" would be an empty set and every '
            'coverage check below would pass without reading anything.',
      );
    });
  });

  group('coverage: it recreates every object the CASCADE removed', () {
    // DERIVED, not listed. The set is whatever earlier migrations created on
    // `design_revision`; this file never names it as the expectation.
    final cascadedIndexes = <String>{};
    final cascadedTriggers = <String>{};
    for (final (_, sql) in earlier) {
      cascadedIndexes.addAll(_indexesOn(sql, table));
      cascadedTriggers.addAll(_triggersOn(sql, table));
    }
    // A trigger is only usable if the function it executes exists, and a
    // function is not a recorded dependency of the tables its plpgsql body
    // names — so whether one outlives a CASCADE is a property of the server's
    // dependency tracking that a migration should not bet on.
    final cascadedFunctions = <String>{
      for (final (_, sql) in earlier)
        ..._functionsExecutedBy(sql, cascadedTriggers),
    };

    test('the derivation found the objects this lane is about', () {
      expect(
        cascadedIndexes,
        contains(indexName),
        reason:
            'no migration earlier than $destructiveVersion creates a '
            '$indexName on $table. Either the object moved or the scan stopped '
            'matching, and in both cases the coverage checks below are '
            'meaningless.',
      );
      expect(
        cascadedTriggers,
        contains(triggerName),
        reason:
            'no migration earlier than $destructiveVersion creates a '
            '$triggerName on $table. Same consequence.',
      );
      expect(cascadedFunctions, contains(functionName));
    });

    test('every cascaded INDEX is re-created after the CREATE TABLE', () {
      final createAt = destructiveBody.indexOf('CREATE TABLE "$table"');
      expect(
        createAt,
        greaterThan(-1),
        reason: 'the CREATE TABLE could not be located',
      );
      for (final name in cascadedIndexes) {
        final restored = _restoreStatementIndex(destructiveBody, name);
        expect(
          restored,
          isNotNull,
          reason:
              '$name existed on $table before $destructiveVersion ran, and its '
              'DROP TABLE ... CASCADE removed it. Nothing in this migration '
              'recreates it, so every chain-migrated database ends this '
              'migration without it while every fresh database keeps it.',
        );
        expect(
          restored,
          greaterThan(createAt),
          reason:
              'the $name restore sits at $restored, before the CREATE TABLE at '
              '$createAt. It attaches to a table the CASCADE removed, so '
              'executed in this order it is refused against a table that does '
              'not exist and rolls the whole migration back — taking the new '
              'column with it.',
        );
      }
    });

    test('every cascaded TRIGGER is re-created after the CREATE TABLE', () {
      final createAt = destructiveBody.indexOf('CREATE TABLE "$table"');
      for (final name in cascadedTriggers) {
        final restored = _restoreStatementIndex(destructiveBody, name);
        expect(
          restored,
          isNotNull,
          reason:
              '$name existed on $table before $destructiveVersion ran. Its '
              'CASCADE removed it and nothing here recreates it.',
        );
        expect(
          restored,
          greaterThan(createAt),
          reason: 'a BEFORE UPDATE trigger cannot attach to a dropped table',
        );
        expect(
          destructiveBody.substring(0, restored).trimRight(),
          endsWith('DROP TRIGGER IF EXISTS "$name" ON "$table";'),
          reason:
              'the $name restore must drop before it creates. Re-running this '
              'migration — after a partial failure, or onto a database another '
              'path already equipped — has to be a no-op rather than a 42710. '
              'The DROP must be the statement immediately preceding the CREATE, '
              'not merely present somewhere earlier in the file.',
        );
      }
    });

    test('every function those triggers EXECUTE is re-declared', () {
      for (final name in cascadedFunctions) {
        final redeclared = RegExp(
          'CREATE\\s+OR\\s+REPLACE\\s+FUNCTION\\s+"$name"\\s*\\(\\s*\\)',
          caseSensitive: false,
        ).hasMatch(destructiveBody);
        expect(
          redeclared,
          isTrue,
          reason:
              '$name is the function $triggerName EXECUTE FUNCTIONs. A '
              'plpgsql body is not a recorded dependency of the tables it '
              'names, so the trigger must not bet on the function having '
              'survived the CASCADE. CREATE OR REPLACE is correct either way.',
        );
      }
    });

    test('every restore lands BEFORE the version stamp, in one transaction', () {
      final stamp = destructiveBody.indexOf(
        'INSERT INTO "serverpod_migrations"',
      );
      expect(
        stamp,
        greaterThan(-1),
        reason: 'the version stamp could not be located',
      );
      for (final name in <String>[...cascadedIndexes, ...cascadedTriggers]) {
        final restored = _restoreStatementIndex(destructiveBody, name)!;
        expect(
          restored,
          lessThan(stamp),
          reason:
              'the $name restore is stamped as though it had run when it had '
              'not: it comes after the serverpod_migrations row. A failure from '
              'there on would roll the DDL back and leave the stamp behind.',
        );
      }
      expect(destructiveBody.trimLeft().startsWith('BEGIN;'), isTrue);
      expect(destructiveBody.trimRight().endsWith('COMMIT;'), isTrue);
    });
  });

  group('reproduction: byte-identical to $originVersion', () {
    test(
      'the partial unique index is the same statement, predicate included',
      () {
        // A paraphrase here would be invisible: a `WHERE` that read
        // `"status" = 'approved'` less strictly, or indexed the wrong column,
        // would still match on the index NAME, and name-anchored parity is not
        // parity — the defect `tool/verify_schema_bootstrap.sh` documents.
        expect(
          _normalise(_statementFor(destructiveBody, indexName)),
          _normalise(_statementFor(originBody, indexName)),
          reason:
              'the $indexName in $destructiveVersion must be the statement '
              '$originVersion already ships — same table, same key column, same '
              'partial predicate.',
        );
        expect(
          _statementFor(destructiveBody, indexName),
          contains('WHERE ("status" = \'approved\')'),
        );
        expect(_statementFor(destructiveBody, indexName), contains(table));
        expect(
          _statementFor(destructiveBody, indexName),
          contains('"workItemId"'),
        );
      },
    );

    test(
      'the immutability trigger is the same trigger, over the same columns',
      () {
        expect(
          _normalise(_triggerDdl(destructiveBody)),
          _normalise(_triggerDdl(originBody)),
          reason:
              'the $triggerName in $destructiveVersion must be the trigger '
              '$originVersion already ships — same event, same timing, same '
              'function, and every guarded column identical. A dropped column is '
              'a column an approved revision can then be edited in.',
        );
        expect(_triggerDdl(destructiveBody), contains('BEFORE UPDATE'));
        expect(
          _triggerDdl(destructiveBody),
          contains('FOR EACH ROW'),
        );
        expect(
          _triggerDdl(destructiveBody),
          contains('EXECUTE FUNCTION "$functionName"()'),
        );
        // The function body itself, compared as text. [_triggerDdl] spans the
        // DROP/CREATE pair only — the function is declared ABOVE that pair — so
        // without this the trigger and the rule it runs would be checked
        // separately from each other, and a paraphrase of the body would pass.
        expect(
          _normalise(_functionDdl(destructiveBody)),
          _normalise(_functionDdl(originBody)),
          reason:
              'the $functionName body must be the one $originVersion ships, '
              'verbatim. Same exception text, same OLD/NEW comparisons, same '
              'order — a paraphrase here is a different rule wearing the same '
              'name.',
        );
        expect(_functionDdl(destructiveBody), contains('RETURNS trigger'));
        expect(
          _functionDdl(destructiveBody),
          contains(
            r"RAISE EXCEPTION 'Cannot modify approved design revision %', "
            r'OLD."revisionId"',
          ),
        );
        final destructiveColumns = _guardedColumns(destructiveBody);
        final originColumns = _guardedColumns(originBody);

        // Non-vacuity, stated as data. Two empty lists compare equal, so
        // without these the comparison below is satisfiable by the scanner
        // reading nothing at all — which is precisely what it did before the
        // body delimiter was fixed.
        expect(
          originColumns,
          isNotEmpty,
          reason:
              'no guarded column could be read out of $originVersion. Two '
              'empty lists are equal, so the comparison below would pass '
              'having read nothing.',
        );
        expect(
          destructiveColumns,
          isNotEmpty,
          reason:
              'no guarded column could be read out of $destructiveVersion. '
              'Either the function is gone or the scanner stopped matching, and '
              'in both cases the comparison below is vacuous.',
        );
        expect(
          destructiveColumns,
          originColumns,
          reason:
              'the set of guarded columns must be identical, in both homes. A '
              'column guarded in one and not the other is a column an approved '
              'revision can be edited in.',
        );
      },
    );

    test('the two files are two ORIGINS, not a move', () {
      expect(
        _statementFor(originBody, indexName),
        isNotEmpty,
        reason:
            '$originVersion has shipped and is replayed by every database that '
            'started before it. Copying from it must not empty it.',
      );
      expect(_triggerDdl(originBody), isNotEmpty);
      expect(
        _statementFor(destructiveBody, indexName),
        isNotEmpty,
        reason:
            'this file is a SECOND origin, not a move. The chain replays both '
            'migrations in order, so an object missing from either one is '
            'missing from every database that reached the other.',
      );
      expect(_triggerDdl(destructiveBody), isNotEmpty);
    });
  });

  group('parity: both homes still declare what they own', () {
    final asset = File(
      p.join(repoRoot, 'apps/server/tool/schema_bootstrap.sql'),
    ).readAsStringSync();
    final assetBody = _stripCommentLines(asset);
    final freshVersion = _registryVersions(migrationsDir).last;
    final freshDefinition = _stripCommentLines(
      File(
        p.join(migrationsDir.path, freshVersion, 'definition.sql'),
      ).readAsStringSync(),
    );

    test('the FRESH path still comes from the bootstrap asset', () {
      expect(
        freshDefinition,
        isNot(contains(indexName)),
        reason:
            'the newest definition.sql declares $indexName. These objects are '
            'hand-maintained and a generated definition.sql erases them on '
            'regeneration; tool/verify_schema_bootstrap.sh check 4 fails on '
            'exactly this.',
      );
      expect(freshDefinition, isNot(contains(triggerName)));
      expect(
        assetBody,
        contains('CREATE UNIQUE INDEX IF NOT EXISTS "$indexName"'),
      );
      expect(assetBody, contains('CREATE TRIGGER "$triggerName"'));
    });

    test('the CHAIN path is now owned by the destructive migration', () {
      // The check above is what makes THIS one meaningful rather than
      // redundant: the fresh path has not been touched, so the only thing that
      // can have changed for a chain-migrated database is this file.
      expect(
        _statementFor(destructiveBody, indexName),
        isNotEmpty,
        reason:
            'with the fresh path unchanged, a chain-migrated database reaches '
            '$indexName only through this migration.',
      );
      expect(_triggerDdl(destructiveBody), isNotEmpty);
      // Both this file and the asset declare the same predicate, so a fresh and
      // a chain-migrated database enforce the same thing.
      //
      // The `IF NOT EXISTS` clause is excluded, and ONLY it — it is a declared
      // asymmetry in this repository, not an accident: the bootstrap asset must
      // be re-runnable and this migration's own index is dropped by the CASCADE
      // immediately above it, so it does not need the clause. Normalising
      // anything else — the table, the key column, the predicate — would
      // forgive a real divergence, which is the defect the full-DDL comparison
      // in `tool/verify_schema_bootstrap.sh` was added to close.
      expect(
        _withoutIdempotenceClause(
          _normalise(_statementFor(destructiveBody, indexName)),
        ),
        _withoutIdempotenceClause(
          _normalise(_statementFor(assetBody, indexName)),
        ),
      );
    });
  });
}

/// The index/trigger statement creating [name] in [body], or `''`.
///
/// Anchored on the statement that CREATES the object rather than on its name
/// appearing anywhere, for the reason `sql_without_comments` in
/// `tool/verify_schema_bootstrap.sh` gives: a banner that NAMES an object is
/// not that object.
String _statementFor(String body, String name) {
  final pattern = RegExp(
    'CREATE\\s+(?:UNIQUE\\s+)?INDEX\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?"$name"'
    '[\\s\\S]*?;',
    caseSensitive: false,
  );
  return pattern.firstMatch(body)?.group(0) ?? '';
}

/// The `DROP TRIGGER IF EXISTS` + `CREATE TRIGGER` pair for the immutability
/// trigger, as one string. Both halves are required: a `CREATE` alone leaves the
/// statement unre-runnable, and a `DROP` alone enforces nothing.
String _triggerDdl(String body) {
  final pattern = RegExp(
    r'DROP\s+TRIGGER\s+IF\s+EXISTS\s+"trigger_design_revision_immutability"'
    r'\s+ON\s+"design_revision"\s*;[\s\S]*?'
    r'EXECUTE\s+FUNCTION\s+"enforce_design_revision_immutability"\s*\(\s*\)\s*;',
    caseSensitive: false,
  );
  return pattern.firstMatch(body)?.group(0) ?? '';
}

/// The `CREATE OR REPLACE FUNCTION "enforce_design_revision_immutability"`
/// declaration in [body], up to and including its closing `$$;`.
///
/// The body is taken as what lies BETWEEN the two `$$` delimiters. Matching to
/// the first `$$` instead would stop at the `AS $$` opener and return a
/// fragment containing no rule at all — which compares equal to the same
/// fragment in another file, so the check would be green while reading nothing.
String _functionDdl(String body) {
  final pattern = RegExp(
    r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+"enforce_design_revision_immutability"'
    r'\s*\(\s*\)[\s\S]*?AS\s*\$\$[\s\S]*?\$\$\s*;',
    caseSensitive: false,
  );
  return pattern.firstMatch(body)?.group(0) ?? '';
}

/// Column names read as `NEW."<col>"` inside the immutability function, sorted
/// so the comparison is order-independent.
///
/// THE BODY DELIMITER, NOT THE FIRST `$$`. This function's SQL is
/// `AS $$ … $$;`, so a lazy match that simply runs to the first `$$` stops at
/// the OPENER and captures `CREATE OR REPLACE FUNCTION … AS $$` — which contains
/// no `NEW."…"` reference at all. That yields an empty list from BOTH homes,
/// two empty lists compare equal, and the guarded-column assertion goes green
/// while guarding nothing. Measured, not assumed: a mutation that deleted
/// `NEW."designerExecutionId"` from the trigger function left the suite at 11/11
/// because of exactly this. The opener is therefore matched explicitly and the
/// body is taken as what lies between the two delimiters.
List<String> _guardedColumns(String body) {
  final fn = RegExp(
    r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+"enforce_design_revision_immutability"'
    r'\s*\(\s*\)\s*RETURNS\s+trigger[\s\S]*?AS\s*\$\$([\s\S]*?)\$\$\s*;',
    caseSensitive: false,
  ).firstMatch(body)?.group(1);
  if (fn == null) return const [];
  return RegExp(
    r'NEW\."([A-Za-z_]+)"',
  ).allMatches(fn).map((m) => m.group(1)!).toSet().toList()..sort();
}

/// Where the statement re-creating index or trigger [name] begins in [body].
int? _restoreStatementIndex(String body, String name) {
  final pattern = RegExp(
    'CREATE\\s+(?:(?:UNIQUE\\s+)?INDEX|TRIGGER)\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?"$name"',
    caseSensitive: false,
  );
  return pattern.firstMatch(body)?.start;
}

/// Every index [table] carries, read from [sql].
Set<String> _indexesOn(String sql, String table) {
  final names = <String>{};
  for (final m in RegExp(
    r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?"([^"]+)"'
    r'\s+ON\s+(?:ONLY\s+)?"([^"]+)"',
    caseSensitive: false,
  ).allMatches(sql)) {
    if (m.group(2) == table) names.add(m.group(1)!);
  }
  return names;
}

/// Every trigger attached to [table], read from [sql].
///
/// `DROP TRIGGER IF EXISTS` and `CREATE TRIGGER` are one statement — they are
/// separated by `;` at the end of the DROP — so both halves are matched from
/// the same scan.
Set<String> _triggersOn(String sql, String table) {
  final names = <String>{};
  for (final statement in sql.split(';')) {
    if (!statement.contains('ON "$table"')) continue;
    final m = RegExp(
      r'CREATE\s+TRIGGER\s+"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(statement);
    if (m != null) names.add(m.group(1)!);
  }
  return names;
}

/// The functions the named triggers [triggersOnTable] `EXECUTE FUNCTION`.
Set<String> _functionsExecutedBy(String sql, Set<String> triggersOnTable) {
  final names = <String>{};
  for (final statement in sql.split(';')) {
    if (!triggersOnTable.any(
      (t) => RegExp(
        'CREATE\\s+TRIGGER\\s+"$t"',
        caseSensitive: false,
      ).hasMatch(statement),
    )) {
      continue;
    }
    for (final m in RegExp(
      r'EXECUTE\s+(?:PROCEDURE|FUNCTION)\s+"([^"]+)"',
      caseSensitive: false,
    ).allMatches(statement)) {
      names.add(m.group(1)!);
    }
  }
  return names;
}

/// Replaces `--` comment lines with empty ones, so a banner that NAMES an object
/// can neither satisfy nor break a check about the statement that creates it.
///
/// Whole lines only, so a `--` inside a string literal does not eat the
/// statement after it — the same boundary
/// `migration_primary_key_index_collision_test.dart` draws, for the same reason.
String _stripCommentLines(String sql) {
  final out = StringBuffer();
  for (final line in const LineSplitter().convert(sql)) {
    if (line.trimLeft().startsWith('--')) {
      out.write('\n');
    } else {
      out.write(line);
      out.write('\n');
    }
  }
  return out.toString();
}

/// Whitespace collapsed to single spaces and trimmed, so line wrapping is not a
/// difference and nothing else is.
String _normalise(String ddl) => ddl.replaceAll(RegExp(r'\s+'), ' ').trim();

/// [_normalise]'d with the `IF NOT EXISTS` idempotence clause removed.
///
/// One clause, one direction, and nothing else — see the call site.
String _withoutIdempotenceClause(String normalised) => normalised.replaceAll(
  RegExp(r'\bIF\s+NOT\s+EXISTS\s+'),
  '',
);

String _readMigration(Directory migrationsDir, String version) {
  final file = File(p.join(migrationsDir.path, version, 'migration.sql'));
  if (!file.existsSync()) {
    throw StateError(
      'missing or unreadable: ${file.path}. These guards read the migration '
      'artefacts directly; with none they would pass having read nothing.',
    );
  }
  return file.readAsStringSync();
}

/// Versions from `migration_registry.txt`, ascending.
List<String> _registryVersions(Directory migrationsDir) {
  final registry = File(p.join(migrationsDir.path, 'migration_registry.txt'));
  if (!registry.existsSync()) {
    throw StateError('missing or unreadable: ${registry.path}');
  }
  final versions = registry
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  if (versions.isEmpty) {
    throw StateError('${registry.path} lists no migrations');
  }
  return versions;
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    // `packages/` AND `apps/` at the same level is the workspace root;
    // `apps/server` has both an `apps/` directory and a `pubspec.yaml` of its
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

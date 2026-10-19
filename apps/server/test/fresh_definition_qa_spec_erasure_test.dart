import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `product_qa_contract_spec` must survive every `serverpod create-migration`.
///
/// ## WHAT ERASES IT, AND WHY IT IS NOT CONDITIONAL
///
/// The table is declared in **no** Dart model. It exists only as a
/// `"managed": false` entry hand-appended into a migration's `definition.json`,
/// `definition_project.json` and `definition.sql`.
///
/// The generator cannot render an unmanaged table. Serverpod renders the
/// fresh-database snapshot with
///
/// ```dart
/// for (var table in tables.where((table) => table.managed != false))
/// ```
///
/// (`serverpod_cli-3.4.13/lib/src/database/dialects/postgres.dart:58`), so
/// `create-migration` reads the previous `definition.json`, drops every
/// unmanaged table on the floor, and writes a new snapshot without it. The
/// erasure is therefore **certain on every single regeneration**, not a
/// possibility that a careful run might avoid.
///
/// Measured, not assumed: three `create-migration` runs on this repository at
/// revision `abedea0` produced fresh `definition.sql` files containing **zero**
/// occurrences of `product_qa_contract_spec`, with `definition.json` dropping
/// from 55 to 54 tables and `definition_project.json` from 42 to 41.
///
/// ## WHAT IT COSTS WHEN IT HAPPENS
///
/// Serverpod applies exactly one artefact to a database with no recorded
/// migration version — the newest `definition.sql`. A snapshot without this
/// table means every newly created database is born without it: local
/// `make test-integration` databases and CI databases alike. The
/// chain-migrated path still replays the creating migration's `migration.sql`
/// and still has the table, so the failure is invisible on any developer
/// machine that already had a database and appears only where nothing existed
/// before.
///
/// ## WHY THIS IS A TEST AND NOT A PROSE INSTRUCTION
///
/// `migration_primary_key_index_collision_test.dart` exists because exactly
/// this class of instruction — remember to re-append the table — is what
/// carried a 42P07 collision into every fresh database once already. A prose
/// instruction is not a check that fails. This is.
///
/// ## THE HONEST LIMIT OF THIS GUARD
///
/// **This test DETECTS the erasure. It does not PREVENT it.** Between a
/// regeneration and this test running, the artefact on disk is already wrong;
/// the failure surfaces at test time rather than at generation time.
///
/// Only two changes actually prevent it, and both are outside the scope of
/// the change that introduced this guard:
///
///  1. Make the table a managed model, so the generator renders it like any
///     other.
///  2. Move its DDL into `apps/server/tool/schema_bootstrap.sql` and register
///     it with `verify:schema-deviations`.
///
/// Until one of those happens, `create-migration` will keep erasing it and
/// somebody will keep re-appending it. This guard makes that failure loud and
/// attributable; it does not make it stop.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  const table = 'product_qa_contract_spec';

  /// Every migration DIRECTORY, newest last.
  ///
  /// Enumerated from the filesystem rather than read from
  /// `migration_registry.txt`, because that is the artefact Serverpod actually
  /// applies. Serverpod 3.4.13's `listVersions()` ignores the registry and
  /// enumerates directories, so an unregistered migration still reaches a
  /// database — which means the registry can name a DIFFERENT newest version
  /// than the one a fresh database is built from. Trusting the registry here
  /// would let the guard pass while the applied artefact is the un-erased one.
  final versions = <String>[
    for (final entry in migrationsDir.listSync())
      if (entry is Directory &&
          RegExp(r'^\d+$').hasMatch(p.basename(entry.path)))
        p.basename(entry.path),
  ]..sort(compareVersions);

  if (versions.isEmpty) {
    throw StateError(
      'no migration directories found under ${migrationsDir.path}. This guard '
      'reads the newest definition.sql; with none it would report success '
      'having read nothing.',
    );
  }

  final newest = versions.last;
  final newestDir = Directory(p.join(migrationsDir.path, newest));

  /// The artefact a fresh database is actually built from.
  final definitionSqlFile = File(p.join(newestDir.path, 'definition.sql'));

  test('the newest definition.sql is the one this guard reads', () {
    expect(
      definitionSqlFile.existsSync(),
      isTrue,
      reason:
          '$newest is the newest migration directory, so its definition.sql is '
          'the artefact a fresh database is built from, and it has to exist '
          'for every assertion below to read anything rather than passing '
          'vacuously',
    );
  });

  group('the erasure is detected', () {
    test('the newest definition.sql still CREATEs the table', () {
      final body = _stripComments(definitionSqlFile.readAsStringSync());

      expect(
        RegExp(
          'CREATE\\s+TABLE\\s+"$table"',
          caseSensitive: false,
        ).hasMatch(body),
        isTrue,
        reason:
            '$table is MISSING from $newest/definition.sql. It is declared in no '
            'Dart model, so `serverpod create-migration` erased it: postgres.dart '
            'renders `tables.where((table) => table.managed != false)` and this '
            'table survives only as a hand-appended unmanaged entry. Every '
            'database created from this snapshot — CI and `make '
            'test-integration` included — is born without it. Re-append the '
            'table, its indexes, and its `"managed": false` entry in '
            'definition.json and definition_project.json.',
      );
    });

    // The JSON is checked, not just the SQL, because the JSON is where the
    // erasure ORIGINATES: the SQL block is hand-appended FROM the unmanaged
    // entry. A snapshot whose JSON has lost the entry cannot be repaired by
    // re-appending SQL alone, because the next regeneration reads the JSON.
    for (final artefact in const [
      'definition.json',
      'definition_project.json',
    ]) {
      test('$artefact still carries the unmanaged entry', () {
        final file = File(p.join(newestDir.path, artefact));
        expect(
          file.existsSync(),
          isTrue,
          reason: '$artefact is read by Serverpod and by this guard',
        );

        final decoded = jsonDecode(file.readAsStringSync());
        final tables = decoded is Map<String, dynamic>
            ? decoded['tables']
            : null;
        expect(
          tables,
          isA<List<Object?>>(),
          reason: '$artefact has no `tables` array to read the entry from',
        );

        final entries = <Map<String, dynamic>>[
          for (final t in (tables! as List<Object?>))
            if (t is Map<String, dynamic>) t,
        ];

        final entry = entries.where((t) => t['name'] == table).toList();
        expect(
          entry,
          hasLength(1),
          reason:
              '$artefact declares $table ${entry.length} time(s). It must '
              'appear exactly once as an unmanaged entry. Zero occurrences is '
              'the erasure, and it is unrecoverable by re-appending SQL: the '
              'next regeneration reads this file.',
        );
        expect(
          entry.single['managed'],
          isFalse,
          reason:
              'the entry must keep `"managed": false`. `managed` anything else '
              'changes what postgres.dart renders — `managed != false` is the '
              'predicate, so this value decides whether the generator emits the '
              'table at all.',
        );

        // Non-vacuity, asserted as data. A parse that silently produced zero
        // entries would satisfy the check above for the wrong reason, so the
        // surrounding array is proved to have been read.
        expect(
          entries.length,
          greaterThan(1),
          reason:
              '$artefact yielded ${entries.length} table entries. The scan read '
              'nothing, so the presence assertion above proves nothing.',
        );
      });
    }
  });

  group('the guard cannot be satisfied by deleting things', () {
    test('the per-product uniqueness constraint is still declared', () {
      // The check above forbids an ABSENCE. It must not be satisfiable by
      // stripping indexes wholesale: the genuinely independent constraint on
      // this table — one declared QA contract per product — is what makes the
      // table correct, and the store relies on it.
      final body = _stripComments(definitionSqlFile.readAsStringSync());
      expect(
        body,
        contains(
          'CREATE UNIQUE INDEX "${table}_product_unique" '
          'ON "$table" USING btree ("productId")',
        ),
        reason:
            'one QA contract per product is enforced by this index. Removing it '
            'would satisfy the erasure check while silently dropping a '
            'constraint the store relies on.',
      );
    });

    test('the scan reads the snapshot, not an empty file', () {
      final body = _stripComments(definitionSqlFile.readAsStringSync());
      final created = RegExp(
        r'CREATE\s+TABLE\s+"([^"]+)"',
        caseSensitive: false,
      ).allMatches(body).map((m) => m.group(1)!).toList();

      expect(
        created,
        isNotEmpty,
        reason:
            '$newest/definition.sql yielded no CREATE TABLE statements, so the '
            'presence assertion above is reading an empty or unreadable '
            'artefact rather than a schema.',
      );
      expect(
        created.length,
        greaterThan(10),
        reason:
            'only ${created.length} CREATE TABLE statements were parsed from a '
            'snapshot that should carry the whole schema; a partial parse would '
            'report the table absent when it is present.',
      );
    });
  });
}

/// Blanks out whole-line `--` comments while preserving every byte offset.
///
/// Preserving length is what lets a banner that NAMES `product_qa_contract_spec`
/// fail to satisfy a check about the statement that CREATEs it.
String _stripComments(String sql) => sql
    .split('\n')
    .map((line) => line.trimLeft().startsWith('--') ? '' : line)
    .join('\n');

/// Orders migration version directory names numerically.
///
/// Lexicographic would work only while every version has the same digit count.
int compareVersions(String a, String b) => int.parse(a).compareTo(int.parse(b));

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

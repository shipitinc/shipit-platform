import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// No migration artifact may CREATE an index under a name Postgres has already
/// taken.
///
/// ## WHAT BROKE, AND WHY ONLY A FRESH DATABASE SAW IT
///
/// `20261017102506000` shipped this alongside every other table in the file:
///
/// ```sql
/// CREATE TABLE "product_qa_contract_spec" (
///     "id" bigserial PRIMARY KEY,          -- Postgres names the PK index
///     ...                                    -- "product_qa_contract_spec_pkey"
/// );
/// CREATE UNIQUE INDEX "product_qa_contract_spec_pkey"
///   ON "product_qa_contract_spec" USING btree ("id");
/// ```
///
/// `PRIMARY KEY` already materialises an index called `<table>_pkey`, so the
/// second statement asks for a relation name that exists and is refused with
/// **42P07 `relation "product_qa_contract_spec_pkey" already exists`**.
///
/// The database this was found on already had the migration recorded, so it
/// never replayed it. Every database built FROM SCRATCH died at that statement.
/// Serverpod applies exactly one artefact to a database with no recorded
/// migration version — the newest `definition.sql`
/// (`serverpod-3.4.13/lib/src/database/migrations/migration_manager.dart`
/// `_loadMigrationSQL`) — so the whole fresh-database path, `make
/// test-integration` and CI included, was dead.
///
/// ## WHY THE STATEMENT WAS REDUNDANT, NOT A SECOND CONSTRAINT
///
/// It indexes the same single column, with the same uniqueness and the same
/// access method, as the primary key it collides with — and the repository's own
/// generated `definition.json` says so, marking that index `"isPrimary": true`
/// rather than `"isPrimary": false` the way a genuinely separate constraint is
/// marked. Deleting the statement removes no uniqueness: `id` is still unique,
/// and the index still exists, under the name Postgres gave it. A genuinely
/// independent constraint on this table — `product_qa_contract_spec_product_unique`
/// on `("productId")` — has its own name and is untouched by this.
///
/// ## WHY `IF NOT EXISTS` IS NOT A FIX
///
/// The `migration.sql` copy of this statement DOES carry `IF NOT EXISTS`, and
/// that is exactly why it never failed: with the clause, a name collision is a
/// NOTICE and the statement is skipped. The `definition.sql` copies carry no
/// clause, which is what turns the collision into an error. This guard
/// therefore distinguishes the two rather than pattern-matching the name alone:
/// a clause-bearing statement is tolerated (it is a no-op), a bare one is not.
/// Flagging the `migration.sql` copy as well would be reporting a statement
/// that Postgres accepts.
///
/// ## WHY THIS IS A TEST AND NOT A REVIEW CONVENTION
///
/// `product_qa_contract_spec` is declared in no Dart model — it survives only
/// as a `"managed": false` entry in `definition.json`, and `postgres.dart`
/// renders `tables.where((table) => table.managed != false)`, so the generator
/// can never emit it. The file is hand-appended after every regeneration, and
/// the hand-append is what carried the collision. A convention does not fail;
/// this does.
///
/// It is deliberately a REPOSITORY-WIDE invariant rather than an assertion
/// about one known line, because the defect is a property of how these files
/// are assembled, not of the table that happened to hit it first.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  /// Every SQL file the applier can read, paired with the migration it belongs
  /// to. `definition.sql` is what a fresh database is built from; `migration.sql`
  /// is what a chain-migrated one replays. Both are scanned because both carry
  /// index DDL, and they carry it with different idempotence clauses.
  final artifacts = <(String, File)>[];
  for (final entry in migrationsDir.listSync()) {
    if (entry is! Directory) continue;
    for (final name in const ['definition.sql', 'migration.sql']) {
      final file = File(p.join(entry.path, name));
      if (file.existsSync()) artifacts.add((p.basename(entry.path), file));
    }
  }

  group('no index may claim a name Postgres has already taken', () {
    test('every migration SQL artefact is readable', () {
      expect(
        artifacts,
        isNotEmpty,
        reason:
            'the guard scans ${migrationsDir.path} for SQL the applier reads. '
            'With nothing found it would report success having read nothing.',
      );
    });

    test('no bare CREATE INDEX reuses a primary key\'s automatic name', () {
      final offenders = <String>[];

      // Accumulated across files so the scan is known to have read something.
      var tablesSeen = 0;
      var indexesSeen = 0;

      for (final (version, file) in artifacts) {
        final sql = _maskCommentLines(file.readAsStringSync());

        final pkNamesByTable = <String, String>{};
        for (final m in RegExp(
          r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"([^"]+)"\s*'
          r'\(([\s\S]*?)\n\);',
          caseSensitive: false,
        ).allMatches(sql)) {
          final table = m.group(1)!;
          final body = m.group(2)!;
          if (!RegExp(
            r'\bPRIMARY\s+KEY\b',
            caseSensitive: false,
          ).hasMatch(body)) {
            continue;
          }
          tablesSeen++;
          // An explicitly named PRIMARY KEY constraint takes its OWN name, so
          // `<table>_pkey` would be free in that case and flagging it would be a
          // false positive rather than a finding.
          final named = RegExp(
            r'CONSTRAINT\s+"([^"]+)"\s+PRIMARY\s+KEY',
            caseSensitive: false,
          ).firstMatch(body);
          pkNamesByTable[table] = named?.group(1) ?? '${table}_pkey';
        }

        for (final m in RegExp(
          r'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(IF\s+NOT\s+EXISTS\s+)?'
          r'"([^"]+)"\s+ON\s+(?:ONLY\s+)?"([^"]+)"',
          caseSensitive: false,
        ).allMatches(sql)) {
          final guarded = m.group(1) != null;
          final indexName = m.group(2)!;
          final table = m.group(3)!;
          indexesSeen++;

          // Tolerated: with the clause, an existing name is a NOTICE and the
          // statement is skipped. That is why the `migration.sql` copy of the
          // colliding statement never failed and must not be reported.
          if (guarded) continue;

          final taken = pkNamesByTable[table];
          if (taken != null && taken == indexName) {
            offenders.add(
              '$version/${p.basename(file.path)}:${_lineOf(sql, m.start)} '
              'CREATE INDEX "$indexName" ON "$table" — "$table" declares a '
              'PRIMARY KEY in this same file, and Postgres has already created '
              'an index called "$taken" for it. A fresh database refuses this '
              'with 42P07 "relation \\"$indexName\\" already exists".',
            );
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these statements collide with a primary key index Postgres creates '
            'automatically, so every database built from the chain fails:\n'
            '  ${offenders.join('\n  ')}',
      );

      // Non-vacuity, asserted as data rather than assumed. A regex that stopped
      // matching would report success having read nothing.
      expect(
        tablesSeen,
        greaterThan(0),
        reason: 'no PRIMARY KEY was parsed out of any artefact',
      );
      expect(
        indexesSeen,
        greaterThan(0),
        reason: 'no CREATE INDEX was parsed out of any artefact',
      );
    });

    test('the real unique constraint on this table is still declared', () {
      // The guard above forbids a COLLIDING name. It must not be satisfiable by
      // deleting indexes wholesale: the genuinely independent constraint on
      // `product_qa_contract_spec` — one declared QA contract per product — is
      // what makes that table correct, and it has a name of its own.
      final sql = _maskCommentLines(
        File(
          p.join(migrationsDir.path, '20261017102506000', 'definition.sql'),
        ).readAsStringSync(),
      );
      expect(
        sql,
        contains(
          'CREATE UNIQUE INDEX "product_qa_contract_spec_product_unique" '
          'ON "product_qa_contract_spec" USING btree ("productId")',
        ),
        reason:
            'the per-product uniqueness constraint is not the one that '
            'collided, and removing it would satisfy the guard above while '
            'silently dropping a constraint the store relies on',
      );
    });
  });
}

/// Blanks out whole-line `--` comments while preserving every byte offset and
/// line break.
///
/// Preserving length is what lets [_lineOf] report a real line number, and
/// restricting the mask to comments that occupy a line on their own is what
/// keeps a `--` inside a string literal from eating the statement after it.
/// Both matter: a banner that NAMES a colliding index must not be able to
/// satisfy — or to break — a check about the statement that creates one.
String _maskCommentLines(String sql) {
  final out = StringBuffer();
  for (final line in const LineSplitter().convert(sql)) {
    if (line.trimLeft().startsWith('--')) {
      out.write(' ' * line.length);
    } else {
      out.write(line);
    }
    out.write('\n');
  }
  return out.toString();
}

/// 1-based line number of [offset] within [text].
int _lineOf(String text, int offset) =>
    '\n'
        .allMatches(
          text.substring(0, offset),
        )
        .length +
    1;

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

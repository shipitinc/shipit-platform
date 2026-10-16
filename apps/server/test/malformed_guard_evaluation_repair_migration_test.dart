import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The behaviour of migration `20261015120000000` — the repair that rewrites
/// `work_item_transition.guardEvaluationsJson` from a bare JSON OBJECT back to
/// the JSON ARRAY the column is declared to hold, without destroying the repair
/// metadata that object carries.
///
/// ## WHY THIS FILE READS THE ARTIFACT AS TEXT
///
/// These are properties of SQL, and no static check can establish what a
/// statement WRITES. The assertions below are therefore assertions about the
/// statements themselves, which is also the only thing this lane can do: `AGENTS.md`
/// read-only-over-Docker binds every lane without infrastructure authority and
/// this dispatch forbids every docker command outright, so no real PostgreSQL is
/// reachable from here and `make test-integration` is not available either.
///
/// `test/integration/unreviewed_review_repair_migration_test.dart` DOES run
/// `20261014210000000`'s SQL against a real database. That file's banner
/// explains why the BOOTSTRAP path never executes a `migration.sql` against
/// `public` — the integration suite builds its schema through
/// `tool/schema_bootstrap.dart`, which on a fresh database applies the LATEST
/// `definition.sql` ALONE, and a data repair is a no-op on an empty schema.
///
/// SO: THIS FILE IS NOT WEAKER THAN IT LOOKS, AND IT IS NOT STRONGER. Read it as
/// the gate on the migration's SHAPE, and read the gap honestly: the claims
/// below are that the repair is aimed at the right rows, keeps the payload, and
/// is exactly reversible. They are NOT a demonstration that the SQL executes
/// against PostgreSQL. A green run here means the migration says what it must;
/// it does not mean the SQL parses. Running this file's repair against a real
/// database belongs in `test/integration/`, in a lane that holds infrastructure
/// authority — reported to the Manager rather than faked here.
///
/// ## THE WRITER IS IDENTIFIED BY CONTENT, NOT BY POSITION
///
/// The creator is found by scanning the migration directories for the statement
/// that does the wrapping, never by taking `registry.last`. Picking the tail
/// would make every assertion below true only while this migration is newest,
/// and they would all break the day another migration lands — which is how
/// `operator_action_migration_test.dart` lost six assertions the last time a
/// data repair was added. The scan costs nothing and the distinction is
/// load-bearing.
void main() {
  final repoRoot = _findRepoRoot();
  final migrationsDir = Directory(p.join(repoRoot, 'apps/server/migrations'));

  final repairVersion = _findRepairMigration(migrationsDir);

  final repairSql = File(
    p.join(migrationsDir.path, repairVersion, 'migration.sql'),
  ).readAsStringSync();

  /// The DOWN region, extracted the way the repository's convention defines it:
  /// everything between the two markers, with exactly one leading `-- ` stripped
  /// from each line so the block goes from inert prose to runnable SQL.
  final downSql = _extractDownRegion(repairSql);

  /// Strips `--` comments so a section header that NAMES an object cannot
  /// satisfy a check that is supposed to find the statement that changes it.
  String body(String sql) => sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  final repairBody = body(repairSql);
  final downBody = body(downSql);

  /// Every table named by a statement-LEADING DML verb in [sql], uppercased and
  /// unquoted.
  ///
  /// Anchored to the start of a line, because `ON CONFLICT … DO UPDATE SET` is
  /// also an `UPDATE` followed by a word, and an unanchored scan reports that
  /// word as a table. The failure direction matters: it would have named a table
  /// called `SET`, and the assertion below is specifically about which tables
  /// this migration writes.
  Set<String> writtenTables(String sql) => {
    for (final match in RegExp(
      r'^\s*(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+"?(\w+)"?',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(sql))
      match.group(1)!.toUpperCase(),
  };

  group('the repair is registered exactly once', () {
    test('exactly one migration directory performs the wrapping', () {
      expect(
        repairVersion,
        '20261015120000000',
        reason:
            'the repair is identified by content; if this fails, more '
            'than one migration claims the same repair',
      );
    });

    test('migration_registry.txt lists it exactly once, last', () {
      final registry =
          File(
                p.join(migrationsDir.path, 'migration_registry.txt'),
              )
              .readAsLinesSync()
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && !l.startsWith('#'))
              .toList();

      expect(
        registry.where((l) => l == repairVersion),
        hasLength(1),
        reason: 'registered exactly once',
      );
      expect(
        registry.last,
        repairVersion,
        reason: 'it must sort AFTER 20261014210000000, whose rows it repairs',
      );
      // The ordering claim, read off the numbers rather than off the tail: a
      // tail assertion alone would pass for a version that sorts earlier if the
      // registry were unsorted.
      expect(
        repairVersion.compareTo('20261014210000000'),
        greaterThan(0),
        reason: 'lexicographic order is timestamp order for these ids',
      );
    });

    test('the migration directory carries the five Serverpod artifacts', () {
      for (final artifact in const [
        'migration.json',
        'migration.sql',
        'definition.sql',
        'definition.json',
        'definition_project.json',
      ]) {
        expect(
          File(
            p.join(migrationsDir.path, repairVersion, artifact),
          ).existsSync(),
          isTrue,
          reason: '$artifact is part of a Serverpod migration directory',
        );
      }
    });

    test('the definition artifacts name THIS version', () {
      final definition = File(
        p.join(migrationsDir.path, repairVersion, 'definition.json'),
      ).readAsStringSync();
      expect(definition, contains('"version": "$repairVersion"'));

      final definitionSql = File(
        p.join(migrationsDir.path, repairVersion, 'definition.sql'),
      ).readAsStringSync();
      expect(definitionSql, contains("'$repairVersion'"));
    });

    test('the migration declares no schema actions — it is a data repair', () {
      expect(
        File(
          p.join(migrationsDir.path, repairVersion, 'migration.json'),
        ).readAsStringSync(),
        contains('"actions": []'),
        reason: 'a schema change here would be an undeclared side effect',
      );
    });
  });

  group('the UP repairs the right rows', () {
    test('it targets work_item_transition and nothing else', () {
      // `serverpod_migrations` is bookkeeping every migration writes; excluding
      // it is the difference between "touches one table" and "touches one
      // table, plus the version row".
      expect(
        writtenTables(repairBody).difference({'SERVERPOD_MIGRATIONS'}),
        {'WORK_ITEM_TRANSITION'},
      );
    });

    test('it SELECTs for eligibility and UPDATEs, never DELETEs', () {
      expect(repairBody.toUpperCase(), isNot(contains('DELETE')));
      expect(repairBody, contains('UPDATE "work_item_transition"'));
    });

    test('it wraps rather than replaces: the SET is a function of the WHOLE '
        'old document', () {
      // The property that makes "without destroying the repair metadata"
      // checkable rather than asserted. The new value is built from the parsed
      // document itself, so a key this migration has never heard of survives. A
      // projection — `jsonb_build_object('decisionId', d->>'decisionId', …)` —
      // would silently drop every key the author failed to list, and this
      // assertion is what makes that shape a failure instead of a review note.
      expect(
        repairBody,
        contains('jsonb_build_array(doc)::text'),
      );
      expect(repairBody, isNot(contains('jsonb_build_object(')));
    });

    test('the eligibility test admits non-arrays and excludes arrays', () {
      expect(repairBody, contains("jsonb_typeof(doc) <> 'array'"));
    });

    test('the eligibility test EXCLUDES NULL and blank columns', () {
      // Twelve work items carry NULL there and all read fine; NULL is data, not
      // a defect. A repair that admitted NULL would "fix" twelve healthy rows.
      expect(
        repairBody,
        contains('x."guardEvaluationsJson" IS NOT NULL'),
      );
      expect(repairBody, contains("btrim(x.\"guardEvaluationsJson\") <> ''"));
    });

    test('it does NOT narrow the repair to the five known rows', () {
      // A predicate naming `tr-unreviewed-review-repair-%` would repair the five
      // QA is broken on and leave the sixth identically-shaped row bricked, so
      // the fix would be one migration behind forever.
      expect(repairBody, isNot(contains('tr-unreviewed-review-repair')));
    });

    test('it parses per row, in a subtransaction, and skips unparseable ones', () {
      // PostgreSQL does not evaluate a WHERE clause before the expressions it
      // selects, so a single `UPDATE … WHERE jsonb_typeof(x::jsonb) <> 'array'`
      // raises on the first unparseable column in the table and the repair dies
      // with it. The per-row BEGIN/EXCEPTION is what stops one bad row from
      // abandoning every row after it.
      expect(repairBody, contains('EXCEPTION WHEN others THEN'));
      expect(repairBody, contains('CONTINUE;'));
      expect(repairBody, contains("candidate.\"guardEvaluationsJson\"::jsonb"));
    });

    test('a skipped row is reported, never silently passed over', () {
      expect(repairBody, contains('RAISE WARNING'));
      expect(repairBody, contains('RAISE NOTICE'));
      expect(repairBody, contains('skipped_ids'));
    });

    test('the write re-asserts eligibility next to the UPDATE', () {
      // The candidate list is read before the UPDATE runs; without re-asserting
      // the predicate on the row itself, a concurrent writer that fixed the
      // column in that window would have its fix overwritten by this repair.
      expect(
        repairBody,
        contains(
          'jsonb_typeof(t."guardEvaluationsJson"::jsonb) <> \'array\'',
        ),
      );
      expect(
        repairBody,
        contains('t."transitionId" = candidate."transitionId"'),
      );
    });
  });

  group('the DOWN is exact, and says so', () {
    test('the DOWN region is present between the repository markers', () {
      expect(repairSql, contains('-- -- DOWN SCRIPT START'));
      expect(repairSql, contains('-- -- DOWN SCRIPT END'));
      expect(downSql.trim(), isNotEmpty);
      // The strip really happened: what came out is SQL, not prose.
      expect(downBody, contains('UPDATE "work_item_transition"'));
    });

    test('the DOWN unwraps element 0 back to the bare object', () {
      expect(
        downBody,
        contains(
          'SET "guardEvaluationsJson" = (t."guardEvaluationsJson"::jsonb -> 0)::text',
        ),
      );
    });

    test('the DOWN is scoped to the shape the UP created', () {
      // Without the length arm the rollback would discard an element that is not
      // a repair payload — a real guard evaluation, say — on any array it found.
      expect(
        downBody,
        contains("jsonb_typeof(t.\"guardEvaluationsJson\"::jsonb) = 'array'"),
      );
      expect(
        downBody,
        contains('jsonb_array_length(t."guardEvaluationsJson"::jsonb) = 1'),
      );
      expect(
        downBody,
        contains(
          "jsonb_typeof(t.\"guardEvaluationsJson\"::jsonb -> 0) = 'object'",
        ),
      );
    });

    test('the DOWN does not narrow itself to the five known rows either', () {
      expect(downBody, isNot(contains('tr-unreviewed-review-repair')));
    });

    test('the DOWN rolls this migration version back', () {
      expect(downBody, contains('DELETE FROM "serverpod_migrations"'));
      expect(downBody, contains('"version" = \'$repairVersion\''));
    });
  });

  group(
    'the cross-migration consequence is documented, not left to be found',
    () {
      // `20261014210000000`'s `down` reads its before-image with a top-level
      // `jsonb ->> 'key'` lookup. On a JSON ARRAY that yields NULL — no error, no
      // warning — so once this repair has run, that rollback restores nothing
      // while reporting success. The failure direction is the dangerous one: a
      // rollback that silently did nothing is indistinguishable from a rollback
      // that correctly had nothing to do. Asserted as prose because the
      // consequence is only dangerous if it is KNOWN.
      test('the banner names the interaction with 20261014210000000', () {
        expect(
          repairSql,
          contains('20261014210000000'),
          reason: 'the migration that wrote the malformed rows must be named',
        );
        expect(
          repairSql,
          contains('restore payload'),
          reason: 'why the payload must survive the wrap',
        );
        expect(
          repairSql,
          contains('jsonb ->> text'),
          reason:
              'the exact PostgreSQL behaviour that makes the older '
              "rollback's before-image unreadable",
        );
      });

      test('the banner states the required rollback order', () {
        expect(repairSql, contains('THIS migration'));
        expect(repairSql.toLowerCase(), contains('first'));
      });
    },
  );
}

/// Finds the one migration that wraps `guardEvaluationsJson` into an array.
///
/// By CONTENT, scanning every migration directory — see the banner on why.
String _findRepairMigration(Directory migrationsDir) {
  final matches = <String>[];
  for (final entity in migrationsDir.listSync()) {
    if (entity is! Directory) continue;
    final version = p.basename(entity.path);
    if (int.tryParse(version) == null) continue;
    final sqlFile = File(p.join(entity.path, 'migration.sql'));
    if (!sqlFile.existsSync()) continue;
    final sql = sqlFile
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n');
    if (sql.contains('UPDATE "work_item_transition"') &&
        sql.contains('jsonb_build_array')) {
      matches.add(version);
    }
  }
  if (matches.length != 1) {
    throw StateError(
      'expected exactly one migration wrapping guardEvaluationsJson, '
      'found ${matches.length}: $matches',
    );
  }
  return matches.single;
}

/// Extracts the executable DOWN region and strips its one leading `-- `.
///
/// A line inside the region is written `-- -- text`; stripping exactly one
/// prefix leaves `-- text`, which is still a comment. Stripping two would leave
/// bare prose and execute it.
String _extractDownRegion(String sql) {
  const start = '-- -- DOWN SCRIPT START';
  const end = '-- -- DOWN SCRIPT END';
  final from = sql.indexOf(start);
  final to = sql.indexOf(end);
  if (from < 0 || to < 0 || to <= from) {
    throw StateError('no DOWN region between the two markers');
  }
  return sql
      .substring(from + start.length, to)
      .split('\n')
      .map((line) => line.startsWith('-- ') ? line.substring(3) : line)
      .join('\n');
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

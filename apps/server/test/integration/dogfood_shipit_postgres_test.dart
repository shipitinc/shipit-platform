import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// S-1 dogfood (checkpoint 006 §14.1): onboard `Product: ShipIt` against the
/// real repository, but ONLY as far as S-1 allows.
///
/// This test deliberately does **not** accept the baseline. Human acceptance is
/// bound to an exact revision + contentHash and is a human gate
/// (`PRODUCT_BASELINE_APPROVAL_REQUIRED`); an agent must not self-approve
/// ShipIt's own baseline. The test proves the durable registration, read-only
/// pinned-HEAD discovery, proposed baseline, restart survival, and that the
/// repository working tree was not mutated.
Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `product` out from under
/// them breaks their assertions. Every statement is scoped to the
/// `shipit-platform` Product this suite registers, so no other file's row can
/// match. Runs in `setUp` as well as `tearDown`, because a previous run that
/// aborted mid-test leaves rows behind and re-registering the Product would
/// then violate a unique constraint (`proposed.revision == 1` also depends on
/// no baseline surviving from an earlier run).
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  const product = 'shipit-platform';
  const statements = <String>[
    'DELETE FROM "baseline_fact" WHERE "baselineId" IN '
        '(SELECT "baselineId" FROM "product_baseline" '
        'WHERE "productId" = \'$product\')',
    'DELETE FROM "standing_policy"          WHERE "productId" = \'$product\'',
    'DELETE FROM "clarification_request"    WHERE "productId" = \'$product\'',
    'DELETE FROM "onboarding_record"        WHERE "productId" = \'$product\'',
    'DELETE FROM "product_registry_audit"   WHERE "productId" = \'$product\'',
    'DELETE FROM "product_credential"       WHERE "productId" = \'$product\'',
    'DELETE FROM "product_baseline"         WHERE "productId" = \'$product\'',
    'DELETE FROM "repository_reference"     WHERE "productId" = \'$product\'',
    'DELETE FROM "product"                  WHERE "productId" = \'$product\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

Future<Directory> _repoRoot() async {
  final entry = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  // apps/server/lib/server.dart -> apps/server -> apps -> repo root
  return File(entry!.toFilePath()).parent.parent.parent.parent;
}

Future<String> _git(List<String> args, Directory cwd) async {
  final result = await Process.run('git', args, workingDirectory: cwd.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout.toString().trim();
}

void main() {
  withServerpod(
    'S-1 DOGFOOD — Product: ShipIt (Postgres, read-only)',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(_purgeSuiteRows);

      test(
        'register ShipIt, discover pinned HEAD read-only, propose baseline, survive restart',
        () async {
          final repoRoot = await _repoRoot();
          expect(
            Directory('${repoRoot.path}/.git').existsSync(),
            isTrue,
            reason: 'dogfood expects a git working tree at ${repoRoot.path}',
          );

          final head = await _git(['rev-parse', 'HEAD'], repoRoot);
          final porcelainBefore = await _git([
            'status',
            '--porcelain',
          ], repoRoot);

          // Pinned, read-only snapshot at HEAD (tracked tree only, so untracked
          // local secrets/build output can never be ingested).
          final snapshot = await Directory.systemTemp.createTemp(
            'shipit-head-',
          );
          addTearDown(() async {
            if (snapshot.existsSync()) await snapshot.delete(recursive: true);
          });
          final archive = await Process.run(
            'sh',
            [
              '-c',
              'git archive --format=tar HEAD | tar -x -C "\$1"',
              'sh',
              snapshot.path,
            ],
            workingDirectory: repoRoot.path,
          );
          expect(archive.exitCode, 0, reason: archive.stderr.toString());

          final store = PostgresProductRegistryStore(await _newDb());
          final decisions = PostgresHumanDecisionStore(
            PostgresWorkflowStore(await _newDb()),
          );
          final engine = ProductRegistryEngine(
            store: store,
            humanDecisionStore: decisions,
          );

          // 1. Durable Product identity (never cwd/repo URL/process-global).
          await engine.createProduct(
            productId: 'shipit-platform',
            name: 'ShipIt',
            description: 'The platform itself (S-1 dogfood).',
          );

          // 2. Repository attribution: durable, product-scoped.
          await engine.addRepositoryReference(
            repositoryId: 'repo-shipit-platform',
            productId: 'shipit-platform',
            uri: repoRoot.path,
            kind: RepositoryKind.monorepo,
            provider: RepositoryProvider.local,
          );

          // 3. Read-only discovery over the pinned snapshot.
          final observations = await ReadOnlyRepositoryReader(
            snapshotRoot: snapshot,
          ).inspect();
          expect(observations, isNotEmpty);
          expect(
            observations.any((o) => o.claim.contains('Dart pub workspace')),
            isTrue,
            reason: 'root pubspec declares a Dart workspace',
          );

          BaselineMaturity maturityFromProvenance(Provenance p) => switch (p) {
            Provenance.observed => BaselineMaturity.implemented,
            Provenance.derived => BaselineMaturity.implemented,
            Provenance.humanProvided => BaselineMaturity.implemented,
            Provenance.assumed => BaselineMaturity.unknown,
            Provenance.unknown => BaselineMaturity.unknown,
          };

          final facts = <BaselineFact>[
            for (var i = 0; i < observations.length; i++)
              BaselineFact(
                factId: 'dogfood-$i',
                section: observations[i].section,
                claim: observations[i].claim,
                provenance: observations[i].provenance,
                maturity: maturityFromProvenance(observations[i].provenance),
                evidenceRefs: observations[i].evidencePaths,
                assumptionNote: observations[i].assumptionNote,
                redacted: observations[i].redacted,
              ),
          ];

          // 4. Propose (NOT accept) the baseline. The human gate stays open.
          final proposed = await engine.proposeBaseline(
            productId: 'shipit-platform',
            facts: facts,
          );
          expect(proposed.revision, 1);
          expect(proposed.status, ProductBaselineStatus.proposed);
          expect(proposed.acceptedBy, isNull);
          expect(proposed.contentHash, isNotEmpty);
          expect(
            proposed.facts.any((f) => f.provenance == Provenance.observed),
            isTrue,
          );

          // 5. Read-only proof: the real working tree is byte-for-byte unchanged.
          final porcelainAfter = await _git([
            'status',
            '--porcelain',
          ], repoRoot);
          expect(
            porcelainAfter,
            porcelainBefore,
            reason: 'discovery must not mutate the repository',
          );

          // 6. Restart durability: a brand-new store+engine over the same DB.
          final freshDecisions = PostgresHumanDecisionStore(
            PostgresWorkflowStore(await _newDb()),
          );
          final fresh = ProductRegistryEngine(
            store: PostgresProductRegistryStore(await _newDb()),
            humanDecisionStore: freshDecisions,
          );
          final ctx = await fresh.loadProductContext('shipit-platform');
          expect(ctx.product.name, 'ShipIt');
          // Proposing a baseline moves the product into baselinePending. It
          // is NOT governed, because no human has approved anything — which is
          // exactly what the activeBaseline assertion below asserts.
          expect(ctx.product.state, ProductState.baselinePending);
          expect(ctx.product.state.allowsDispatch, isFalse);
          expect(ctx.repositories.single.uri, repoRoot.path);
          // Nothing accepted by an agent — the human gate is still pending.
          expect(ctx.activeBaseline, isNull);
          expect(
            ctx.allBaselines.single.status,
            ProductBaselineStatus.proposed,
          );
          expect(ctx.allBaselines.single.contentHash, proposed.contentHash);
          expect(ctx.allBaselines.single.facts.length, facts.length);
          expect(fresh.readBaselineRevision('shipit-platform', 1), completes);

          // Sanity: record the exact pinned revision discovery ran against.
          expect(head, matches(RegExp(r'^[0-9a-f]{40}$|^[0-9a-f]{7,}$')));
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

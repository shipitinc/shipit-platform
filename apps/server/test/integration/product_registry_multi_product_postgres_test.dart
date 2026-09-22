import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Deterministic multi-product proof (checkpoint 006 §14.1 n°1–9, §15
/// MP-AC-1..8, §16 DATABASE + SECURITY). Two fixture Products exercise the
/// real PostgreSQL store so the isolation claims are demonstrated against
/// durable rows, not in-memory maps.
Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

Future<void> _truncateProductTables() async {
  final db = await _newDb();
  await db.queryNoTransaction('''
    TRUNCATE TABLE
      "product",
      "repository_reference",
      "product_baseline",
      "clarification_request",
      "onboarding_record",
      "human_decision"
    RESTART IDENTITY CASCADE
  ''');
}

const productA = 'multi-a-fixture';
const productB = 'multi-b-fixture';

List<BaselineFact> _facts(String claim) => [
  BaselineFact(
    factId: 'fact-$claim',
    section: BaselineSectionKey.techStack,
    claim: claim,
    provenance: Provenance.observed,
    maturity: BaselineMaturity.implemented,
    evidenceRefs: const ['repo:README.md'],
  ),
];

DecisionSignature _testSignature() => DecisionSignature(
  algorithm: 'ed25519',
  publicKey: 'pk-test',
  signature: 'sig-test',
  signedAt: DateTime.utc(2026, 1, 1),
);

Future<ProductRegistryEngine> _engine() async {
  final db = await _newDb();
  final workflowStore = PostgresWorkflowStore(db);
  final decisions = PostgresHumanDecisionStore(workflowStore);
  return ProductRegistryEngine(
    store: PostgresProductRegistryStore(db),
    humanDecisionStore: decisions,
  );
}

Future<void> _approveBaseline(
  ProductRegistryEngine engine,
  String productId,
  ProductBaseline baseline, {
  String decider = 'reviewer',
}) async {
  // A worker attests to the baseline before any human is asked (AGENTS.md
  // §12); the gate fails closed without it.
  await engine.verifyBaseline(
    productId: productId,
    baselineId: baseline.baselineId,
    verifiedBy: 'worker-multi-verifier',
  );
  final request = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: baseline.baselineId,
  );
  await engine.resolveBaselineApproval(
    decisionId: request.decisionId,
    choice: HumanDecisionChoice.approve,
    decider: decider,
    rationale: 'approved',
    signature: _testSignature(),
  );
}

void main() {
  withServerpod(
    'S-1 multi-product registry isolation (Postgres)',
    (sessionBuilder, endpoints) {
      setUp(_truncateProductTables);

      late ProductRegistryEngine engine;

      setUp(() async {
        engine = await _engine();
      });

      // A brand-new store + engine over the SAME database models a process
      // restart: no in-memory carry-over, only durable rows remain.
      Future<ProductRegistryEngine> restart() async => _engine();

      Future<void> seedBoth() async {
        await engine.createProduct(productId: productA, name: 'Product A');
        await engine.createProduct(productId: productB, name: 'Product B');
        await engine.addRepositoryReference(
          repositoryId: 'repo-a',
          productId: productA,
          uri: 'file:///srv/a',
          kind: RepositoryKind.monorepo,
        );
        await engine.addRepositoryReference(
          repositoryId: 'repo-b',
          productId: productB,
          uri: 'file:///srv/b',
          kind: RepositoryKind.frontend,
        );
      }

      test(
        'MP-AC-1/2: two Products persist concurrently as distinct rows',
        () async {
          await seedBoth();
          final products = await engine.readAllProducts();
          expect(
            products.map((p) => p.productId),
            containsAll([productA, productB]),
          );
          expect(productA, isNot(productB));
          expect((await engine.readProduct(productA)).name, 'Product A');
          expect((await engine.readProduct(productB)).name, 'Product B');
        },
      );

      test(
        'MP-AC-4: repository references belong to the correct Product',
        () async {
          await seedBoth();
          final aRepos = await engine.readRepositories(productA);
          final bRepos = await engine.readRepositories(productB);
          expect(aRepos.map((r) => r.repositoryId), ['repo-a']);
          expect(bRepos.map((r) => r.repositoryId), ['repo-b']);
          expect(aRepos.every((r) => r.productId == productA), isTrue);
          expect(bRepos.every((r) => r.productId == productB), isTrue);

          expect(
            () => engine.resolveRepository(productA, 'repo-b'),
            throwsA(isA<CrossProductAccessException>()),
          );
        },
      );

      test('MP-AC-5: ProductContext(productId) is unambiguous', () async {
        await seedBoth();
        final a = await engine.proposeBaseline(
          productId: productA,
          facts: _facts('A stack'),
        );
        await _approveBaseline(engine, productA, a);

        final ctxA = await engine.loadProductContext(productA);
        final ctxB = await engine.loadProductContext(productB);

        expect(ctxA.product.productId, productA);
        expect(ctxA.activeBaseline?.productId, productA);
        expect(ctxA.allBaselines.every((b) => b.productId == productA), isTrue);
        expect(ctxA.repositories.every((r) => r.productId == productA), isTrue);

        expect(ctxB.product.productId, productB);
        expect(ctxB.activeBaseline, isNull);
        expect(ctxB.allBaselines, isEmpty);
        expect(ctxB.repositories.every((r) => r.productId == productB), isTrue);
      });

      test(
        'MP-AC-6/SECURITY: cross-Product baseline access is refused',
        () async {
          await seedBoth();
          final b = await engine.proposeBaseline(
            productId: productB,
            facts: _facts('B stack'),
          );

          // Knowing B's baseline id does not authorize A to accept it.
          expect(
            () => _approveBaseline(engine, productA, b),
            throwsA(isA<CrossProductAccessException>()),
          );
          // A's read path never surfaces B's revision.
          expect(await engine.readBaselines(productA), isEmpty);
        },
      );

      test(
        'DATABASE: baseline revisions are independent per Product',
        () async {
          await seedBoth();
          final a1 = await engine.proposeBaseline(
            productId: productA,
            facts: _facts('A v1'),
          );
          final b1 = await engine.proposeBaseline(
            productId: productB,
            facts: _facts('B v1'),
          );
          expect(a1.revision, 1);
          expect(b1.revision, 1);
          final storeA = PostgresProductRegistryStore(await _newDb());
          final storeB = PostgresProductRegistryStore(await _newDb());
          expect(await storeA.nextBaselineRevision(productA), 2);
          expect(await storeB.nextBaselineRevision(productB), 2);

          final a2 = await engine.proposeBaseline(
            productId: productA,
            facts: _facts('A v2'),
          );
          expect(a2.revision, 2);
          // B is untouched by A's new revision.
          expect(await storeB.nextBaselineRevision(productB), 2);
          final bOnly = await engine.readBaselines(productB);
          expect(bOnly.map((b) => b.revision), [1]);
        },
      );

      test('MP-AC-8: operations on A do not mutate B', () async {
        await seedBoth();
        final before = await engine.readProduct(productB);

        final a1 = await engine.proposeBaseline(
          productId: productA,
          facts: _facts('A v1'),
        );
        await _approveBaseline(engine, productA, a1);
        await engine.requireClarification(
          productId: productA,
          section: BaselineSectionKey.qa,
          question: 'A QA question?',
        );

        final after = await engine.readProduct(productB);
        expect(after.state, before.state);
        expect(after.version, before.version);
        expect(after.updatedAt, before.updatedAt);
        expect(await engine.readBaselines(productB), isEmpty);
        expect(await engine.readOpenClarifications(productB), isEmpty);
      });

      test(
        'MP-AC-7: both Products and their baselines survive restart',
        () async {
          await seedBoth();
          final a1 = await engine.proposeBaseline(
            productId: productA,
            facts: _facts('A v1'),
          );
          await _approveBaseline(engine, productA, a1);
          final aContentHash = a1.contentHash;
          await engine.requireClarification(
            productId: productB,
            section: BaselineSectionKey.governance,
            question: 'B governance question?',
          );

          final fresh = await restart();
          final ctxA = await fresh.loadProductContext(productA);
          final ctxB = await fresh.loadProductContext(productB);

          expect(ctxA.product.productId, productA);
          expect(ctxA.activeBaseline?.contentHash, aContentHash);
          expect(ctxA.activeBaseline?.status, ProductBaselineStatus.accepted);
          expect(
            ctxB.openClarifications.single.question,
            'B governance question?',
          );
          expect((await fresh.readAllProducts()).length, 2);
        },
      );

      test(
        'SECURITY: baselines carry references only, never secret values',
        () async {
          await engine.createProduct(productId: productA, name: 'Product A');
          final baseline = await engine.proposeBaseline(
            productId: productA,
            facts: [
              BaselineFact(
                factId: 'fact-cred',
                section: BaselineSectionKey.environments,
                claim: 'PENPOT_SHIPIT_PLATFORM_TOKEN (referenced by name only)',
                provenance: Provenance.humanProvided,
                maturity: BaselineMaturity.implemented,
                redacted: true,
              ),
            ],
          );

          final secretLike = RegExp(r'[A-Za-z0-9]{32,}');
          for (final fact in baseline.facts) {
            expect(fact.redacted, isTrue);
            expect(
              secretLike.hasMatch(fact.claim),
              isFalse,
              reason: 'baseline fact must not embed a secret value',
            );
          }
          // And it round-trips through Postgres without gaining a value.
          final reloaded = await restart();
          final stored = await reloaded.readBaselineRevision(productA, 1);
          expect(stored.facts.single.redacted, isTrue);
          expect(secretLike.hasMatch(stored.facts.single.claim), isFalse);
        },
      );

      test('durable clarification answers resume the same lineage', () async {
        await engine.createProduct(productId: productA, name: 'Product A');
        final clar = await engine.requireClarification(
          productId: productA,
          section: BaselineSectionKey.deployment,
          question: 'Where does A deploy?',
        );

        final fresh = await restart();
        expect(
          (await fresh.readOpenClarifications(productA)).single.clarificationId,
          clar.clarificationId,
        );

        final answered = await fresh.answerClarification(
          clarificationId: clar.clarificationId,
          answer: 'to the staging cluster',
          answeredBy: 'operator',
        );
        expect(answered.status, ClarificationStatus.answered);

        // Idempotent replay after another restart.
        final again = await restart();
        final replay = await again.answerClarification(
          clarificationId: clar.clarificationId,
          answer: 'ignored duplicate',
          answeredBy: 'operator',
        );
        expect(replay.answer, 'to the staging cluster');
        expect(await again.readOpenClarifications(productA), isEmpty);
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

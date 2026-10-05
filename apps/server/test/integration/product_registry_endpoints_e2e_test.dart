import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// E2E proof that the S-1 registry is served through the *typed* Serverpod
/// protocol: the generated client endpoints return protocol models (field
/// access, not `Map<String,dynamic>`), and the two human-gate writes delegate
/// to the durable engine.
Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `product` out from under
/// them breaks their assertions. Every statement is scoped to this file's two
/// fixture Products (`endpoint-*-fixture`) and their synthetic decision
/// scopes, so no other file's row can match. Runs in `setUp` as well as
/// `tearDown`, because a previous run that aborted mid-test leaves rows behind
/// and re-registering a Product would then violate a unique constraint — and
/// because two of these tests deliberately leave a blocking approval decision
/// pending, which must not outlive the file.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  const statements = <String>[
    'DELETE FROM "baseline_fact" WHERE "baselineId" IN '
        '(SELECT "baselineId" FROM "product_baseline" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\'))',
    'DELETE FROM "human_decision" WHERE "workItemId" LIKE \'%endpoint-%-fixture\'',
    'DELETE FROM "standing_policy" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
    'DELETE FROM "clarification_request" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
    'DELETE FROM "onboarding_record" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
    'DELETE FROM "product_registry_audit" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
    'DELETE FROM "product_credential" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
    'DELETE FROM "product_baseline" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
    'DELETE FROM "repository_reference" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
    'DELETE FROM "product" WHERE "productId" IN '
        '(\'endpoint-a-fixture\', \'endpoint-b-fixture\')',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

const a = 'endpoint-a-fixture';
const b = 'endpoint-b-fixture';

List<BaselineFact> _facts(String claim) => [
  BaselineFact(
    factId: 'fact-$claim',
    section: BaselineSectionKey.techStack,
    claim: claim,
    provenance: Provenance.humanProvided,
    maturity: BaselineMaturity.implemented,
    evidenceRefs: const ['repo:pubspec.yaml'],
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

void main() {
  withServerpod(
    'S-1 registry typed Serverpod endpoints (Postgres)',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(_purgeSuiteRows);

      test(
        'listProducts and productContext round-trip typed models',
        () async {
          final e = await _engine();
          await e.createProduct(productId: a, name: 'Endpoint A');
          await e.addRepositoryReference(
            repositoryId: 'repo-endpoint-a',
            productId: a,
            uri: 'file:///srv/a',
          );
          final proposed = await e.proposeBaseline(
            productId: a,
            facts: _facts('A'),
          );
          await e.verifyBaseline(
            productId: a,
            baselineId: proposed.baselineId,
            verifiedBy: 'worker-e2e-verifier',
          );

          final products = await endpoints.productRegistryEndpoints
              .listProducts(
                sessionBuilder,
              );
          expect(products.map((p) => p.productId), contains(a));
          expect(
            products.firstWhere((p) => p.productId == a).state,
            'baseline_pending',
          );

          final ctx = await endpoints.productRegistryEndpoints.productContext(
            sessionBuilder,
            productId: a,
          );
          expect(ctx.product.productId, a);
          expect(ctx.repositories.single.repositoryId, 'repo-endpoint-a');
          expect(ctx.activeBaseline, isNull);
          expect(ctx.allBaselines.single.status, 'proposed');
          expect(ctx.allBaselines.single.contentHash, proposed.contentHash);
          expect(
            ctx.allBaselines.single.facts.single.provenance,
            'human_provided',
          );
        },
      );

      test(
        'baseline approval gate: request, resolve (approve), accepts exact revision',
        () async {
          final e = await _engine();
          await e.createProduct(productId: a, name: 'Endpoint A');
          final proposed = await e.proposeBaseline(
            productId: a,
            facts: _facts('A'),
          );
          await e.verifyBaseline(
            productId: a,
            baselineId: proposed.baselineId,
            verifiedBy: 'worker-e2e-verifier',
          );

          // Request approval — returns a durable pending decision
          final request = await endpoints.productRegistryEndpoints
              .requestBaselineApproval(
                sessionBuilder,
                productId: a,
                baselineId: proposed.baselineId,
              );
          expect(request.status, 'pending');
          expect(request.decisionType, 'product_decision');
          expect(request.workItemId, 'product-baseline:$a');

          // Resolve with approval — accepts the bound baseline
          final resolved = await endpoints.productRegistryEndpoints
              .resolveBaselineApproval(
                sessionBuilder,
                decisionId: request.decisionId,
                choice: 'approve',
                decider: 'human-gate',
                rationale: 'Baseline reviewed and approved',
                signature: _testSignature().signature,
                publicKey: _testSignature().publicKey,
                algorithm: _testSignature().algorithm,
                signedAt: _testSignature().signedAt,
              );
          expect(resolved.status, 'resolved');
          expect(resolved.choice, 'approve');
          expect(resolved.decider, 'human-gate');

          // The baseline is now accepted with the decision as authority
          final ctx = await endpoints.productRegistryEndpoints.productContext(
            sessionBuilder,
            productId: a,
          );
          expect(ctx.activeBaseline!.status, 'accepted');
          expect(ctx.activeBaseline!.acceptedBy, 'human-gate');
          expect(ctx.activeBaseline!.acceptedDecisionId, request.decisionId);
          expect(ctx.activeBaseline!.contentHash, proposed.contentHash);

          // Requesting approval for an already-accepted revision is refused
          // (immutability).
          expect(
            () => endpoints.productRegistryEndpoints.requestBaselineApproval(
              sessionBuilder,
              productId: a,
              baselineId: proposed.baselineId,
            ),
            throwsA(isA<ImmutableBaselineException>()),
          );
        },
      );

      test(
        'cross-product acceptance through the endpoint is refused',
        () async {
          final e = await _engine();
          await e.createProduct(productId: a, name: 'Endpoint A');
          await e.createProduct(productId: b, name: 'Endpoint B');
          final bBaseline = await e.proposeBaseline(
            productId: b,
            facts: _facts('B'),
          );
          await e.verifyBaseline(
            productId: b,
            baselineId: bBaseline.baselineId,
            verifiedBy: 'worker-e2e-verifier',
          );

          // Requesting approval for B's baseline with productId: A is refused
          // at the request stage (cross-product scope check).
          expect(
            () => endpoints.productRegistryEndpoints.requestBaselineApproval(
              sessionBuilder,
              productId: a,
              baselineId: bBaseline.baselineId,
            ),
            throwsA(isA<CrossProductAccessException>()),
          );

          // Requesting approval for B's baseline with correct productId works
          final request = await endpoints.productRegistryEndpoints
              .requestBaselineApproval(
                sessionBuilder,
                productId: b,
                baselineId: bBaseline.baselineId,
              );
          expect(request.status, 'pending');

          // Resolving that decision (for B) works - it's not cross-product
          await endpoints.productRegistryEndpoints.resolveBaselineApproval(
            sessionBuilder,
            decisionId: request.decisionId,
            choice: 'approve',
            decider: 'human-gate',
            rationale: 'legitimate approval for B',
            signature: _testSignature().signature,
            publicKey: _testSignature().publicKey,
            algorithm: _testSignature().algorithm,
            signedAt: _testSignature().signedAt,
          );

          // Verify A has no baselines
          final ctxA = await endpoints.productRegistryEndpoints.productContext(
            sessionBuilder,
            productId: a,
          );
          expect(ctxA.allBaselines, isEmpty);
        },
      );

      test('answerClarification resumes the same lineage', () async {
        final e = await _engine();
        await e.createProduct(productId: a, name: 'Endpoint A');
        final clar = await e.requireClarification(
          productId: a,
          section: BaselineSectionKey.deployment,
          question: 'Deploy where?',
        );

        final answered = await endpoints.productRegistryEndpoints
            .answerClarification(
              sessionBuilder,
              clarificationId: clar.clarificationId,
              answer: 'staging',
              answeredBy: 'operator',
            );
        expect(answered.status, 'answered');
        expect(answered.answer, 'staging');
        expect(answered.productId, a);
      });

      test('stale approval protection (TOCTOU)', () async {
        final e = await _engine();
        await e.createProduct(productId: a, name: 'Endpoint A');
        final v1 = await e.proposeBaseline(productId: a, facts: _facts('v1'));
        await e.verifyBaseline(
          productId: a,
          baselineId: v1.baselineId,
          verifiedBy: 'worker-e2e-verifier',
        );

        // Request approval for v1 (decision D1)
        final request = await endpoints.productRegistryEndpoints
            .requestBaselineApproval(
              sessionBuilder,
              productId: a,
              baselineId: v1.baselineId,
            );

        // Before resolving D1, propose and accept v2 (decision D2)
        final v2 = await e.proposeBaseline(productId: a, facts: _facts('v2'));
        await e.verifyBaseline(
          productId: a,
          baselineId: v2.baselineId,
          verifiedBy: 'worker-e2e-verifier',
        );
        final request2 = await endpoints.productRegistryEndpoints
            .requestBaselineApproval(
              sessionBuilder,
              productId: a,
              baselineId: v2.baselineId,
            );
        await endpoints.productRegistryEndpoints.resolveBaselineApproval(
          sessionBuilder,
          decisionId: request2.decisionId,
          choice: 'approve',
          decider: 'human-gate',
          rationale: 'approve v2',
          signature: _testSignature().signature,
          publicKey: _testSignature().publicKey,
          algorithm: _testSignature().algorithm,
          signedAt: _testSignature().signedAt,
        );

        // v1 is now superseded. Attempt to resolve D1 with approve — must fail
        expect(
          () => endpoints.productRegistryEndpoints.resolveBaselineApproval(
            sessionBuilder,
            decisionId: request.decisionId,
            choice: 'approve',
            decider: 'human-gate',
            rationale: 'stale approval attempt',
            signature: _testSignature().signature,
            publicKey: _testSignature().publicKey,
            algorithm: _testSignature().algorithm,
            signedAt: _testSignature().signedAt,
          ),
          throwsA(isA<StaleBaselineApprovalException>()),
        );

        // v2 is the active baseline, v1 is superseded
        final ctx = await endpoints.productRegistryEndpoints.productContext(
          sessionBuilder,
          productId: a,
        );
        expect(ctx.activeBaseline!.revision, 2);
        expect(ctx.activeBaseline!.baselineId, v2.baselineId);
        expect(ctx.allBaselines.length, 2);
      });

      test('idempotent replay of approval resolution', () async {
        final e = await _engine();
        await e.createProduct(productId: a, name: 'Endpoint A');
        final proposed = await e.proposeBaseline(
          productId: a,
          facts: _facts('A'),
        );
        await e.verifyBaseline(
          productId: a,
          baselineId: proposed.baselineId,
          verifiedBy: 'worker-e2e-verifier',
        );

        final request = await endpoints.productRegistryEndpoints
            .requestBaselineApproval(
              sessionBuilder,
              productId: a,
              baselineId: proposed.baselineId,
            );

        // First resolution
        await endpoints.productRegistryEndpoints.resolveBaselineApproval(
          sessionBuilder,
          decisionId: request.decisionId,
          choice: 'approve',
          decider: 'human-gate',
          rationale: 'first approval',
          signature: _testSignature().signature,
          publicKey: _testSignature().publicKey,
          algorithm: _testSignature().algorithm,
          signedAt: _testSignature().signedAt,
        );

        // Second resolution with same decisionId is idempotent replay
        final replay = await endpoints.productRegistryEndpoints
            .resolveBaselineApproval(
              sessionBuilder,
              decisionId: request.decisionId,
              choice: 'approve',
              decider: 'human-gate',
              rationale: 'replay',
              signature: _testSignature().signature,
              publicKey: _testSignature().publicKey,
              algorithm: _testSignature().algorithm,
              signedAt: _testSignature().signedAt,
            );
        expect(replay.decisionId, request.decisionId);
        expect(replay.status, 'resolved');

        // Baseline accepted once, acceptedDecisionId preserved
        final ctx = await endpoints.productRegistryEndpoints.productContext(
          sessionBuilder,
          productId: a,
        );
        expect(ctx.activeBaseline!.acceptedDecisionId, request.decisionId);
      });

      test('readBaselineApproval returns the governing decision', () async {
        final e = await _engine();
        await e.createProduct(productId: a, name: 'Endpoint A');
        final proposed = await e.proposeBaseline(
          productId: a,
          facts: _facts('A'),
        );
        await e.verifyBaseline(
          productId: a,
          baselineId: proposed.baselineId,
          verifiedBy: 'worker-e2e-verifier',
        );

        // Before any request - throws 404 (StateError)
        expect(
          () => endpoints.productRegistryEndpoints.baselineApproval(
            sessionBuilder,
            productId: a,
            baselineId: proposed.baselineId,
          ),
          throwsA(isA<StateError>()),
        );

        // After requesting approval
        final request = await endpoints.productRegistryEndpoints
            .requestBaselineApproval(
              sessionBuilder,
              productId: a,
              baselineId: proposed.baselineId,
            );

        final found = await endpoints.productRegistryEndpoints.baselineApproval(
          sessionBuilder,
          productId: a,
          baselineId: proposed.baselineId,
        );
        expect(found.decisionId, request.decisionId);
        expect(found.status, 'pending');
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

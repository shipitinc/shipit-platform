import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const governanceA = 'governance-ep-a';

Future<PersistenceDatabase> _db() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `product` out from under
/// them breaks their assertions. Every statement is scoped to this file's two
/// fixture Products (`governance-ep-*`), so no other file's row can match —
/// `governance_wire_e2e_test.dart` names its fixtures `governance-a` /
/// `governance-b` and the two files would otherwise collide on the unique
/// Product id. Runs in `setUp` as well as `tearDown`, because a previous run
/// that aborted mid-test leaves rows behind and re-registering a Product would
/// then violate a unique constraint.
Future<void> _purgeSuiteRows() async {
  final db = await _db();
  // `HumanDecision.workItemId` carries the engine's synthetic scope
  // (`product-baseline:<productId>` and friends); those rows live in
  // `human_decision`, and the engine never writes a `work_item` row for them.
  // The `work_item` sweep below is a namespaced no-op kept for defence in
  // depth.
  const statements = <String>[
    'DELETE FROM "baseline_fact" WHERE "baselineId" IN '
        '(SELECT "baselineId" FROM "product_baseline" '
        'WHERE "productId" LIKE \'governance-ep-%\')',
    'DELETE FROM "human_decision" WHERE "workItemId" LIKE '
        '\'%governance-ep-%\'',
    'DELETE FROM "work_item" WHERE "workItemId" LIKE \'%governance-ep-%\'',
    'DELETE FROM "standing_policy" WHERE "productId" LIKE \'governance-ep-%\'',
    'DELETE FROM "clarification_request" WHERE "productId" LIKE '
        '\'governance-ep-%\'',
    'DELETE FROM "onboarding_record" WHERE "productId" LIKE \'governance-ep-%\'',
    'DELETE FROM "product_registry_audit" WHERE "productId" LIKE '
        '\'governance-ep-%\'',
    'DELETE FROM "product_credential" WHERE "productId" LIKE '
        '\'governance-ep-%\'',
    'DELETE FROM "product_baseline" WHERE "productId" LIKE \'governance-ep-%\'',
    'DELETE FROM "repository_reference" WHERE "productId" LIKE '
        '\'governance-ep-%\'',
    'DELETE FROM "product" WHERE "productId" LIKE \'governance-ep-%\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

List<BaselineFact> _facts(String seed) => [
  BaselineFact(
    factId: 'fact-$seed',
    section: BaselineSectionKey.techStack,
    claim: 'Governance durable wire for $seed',
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

Future<ProductRegistryEngine> _governedEngine({
  required String productId,
  required String name,
}) async {
  final db = await _db();
  final workflowStore = PostgresWorkflowStore(db);
  final decisions = PostgresHumanDecisionStore(workflowStore);
  final engine = ProductRegistryEngine(
    store: PostgresProductRegistryStore(db),
    humanDecisionStore: decisions,
  );
  await engine.createProduct(productId: productId, name: name);
  await engine.addRepositoryReference(
    repositoryId: 'repo-$productId',
    productId: productId,
    uri: 'file:///srv/$productId',
  );
  final proposed = await engine.proposeBaseline(
    productId: productId,
    facts: _facts('$productId-baseline'),
  );
  await engine.verifyBaseline(
    productId: productId,
    baselineId: proposed.baselineId,
    verifiedBy: 'worker-governance-verifier',
  );

  final request = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: proposed.baselineId,
  );
  await engine.resolveBaselineApproval(
    decisionId: request.decisionId,
    choice: HumanDecisionChoice.approve,
    decider: 'human-gate',
    rationale: 'durable baseline acceptance for $productId',
    signature: _testSignature(),
  );
  return engine;
}

void main() {
  withServerpod(
    'Governance durable wire round-trip (Postgres)',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(_purgeSuiteRows);

      test(
        'lifecycle decision raised and resolved durably with a real decisionId',
        () async {
          await _governedEngine(productId: governanceA, name: 'A');
          final request = await endpoints.productRegistryEndpoints
              .requestLifecycleDecision(
                sessionBuilder,
                productId: governanceA,
                action: 'pause',
                drainInFlight: true,
              );
          expect(request.decisionId, isNotEmpty);
          expect(request.status, 'pending');
          expect(request.decisionType, 'product_decision');

          final resolved = await endpoints.productRegistryEndpoints
              .resolveLifecycleDecision(
                sessionBuilder,
                decisionId: request.decisionId,
                choice: 'approve',
                decider: 'human-gate',
                rationale: 'durable pause approval',
                signature: _testSignature().signature,
                publicKey: _testSignature().publicKey,
                algorithm: _testSignature().algorithm,
                signedAt: _testSignature().signedAt,
                noWorkInFlight: true,
              );
          expect(resolved.status, 'resolved');
          expect(resolved.choice, 'approve');
          expect(resolved.decisionId, request.decisionId);
        },
      );

      test(
        'policy authorisation round-trips durably and revokes by decision',
        () async {
          await _governedEngine(productId: 'governance-ep-b', name: 'B');
          final request = await endpoints.productRegistryEndpoints
              .requestPolicyAuthorisation(
                sessionBuilder,
                productId: 'governance-ep-b',
                actions: ['push'],
              );
          expect(request.decisionId, isNotEmpty);
          expect(request.status, 'pending');

          final resolved = await endpoints.productRegistryEndpoints
              .resolvePolicyAuthorisation(
                sessionBuilder,
                decisionId: request.decisionId,
                choice: 'approve',
                decider: 'human-gate',
                rationale: 'standing push policy accepted',
                signature: _testSignature().signature,
                publicKey: _testSignature().publicKey,
                algorithm: _testSignature().algorithm,
                signedAt: _testSignature().signedAt,
              );
          expect(resolved, isNotNull);
          expect(resolved!.authorisingDecisionId, request.decisionId);

          final revoked = await endpoints.productRegistryEndpoints
              .revokeStandingPolicy(
                sessionBuilder,
                productId: 'governance-ep-b',
                policyId: resolved.policyId,
                revokedBy: 'human-gate',
              );
          expect(revoked.isRevoked, isTrue);
          expect(revoked.policyId, resolved.policyId);
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

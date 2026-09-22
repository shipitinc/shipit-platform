import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const governanceA = 'governance-a';

Future<PersistenceDatabase> _db() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

Future<void> _truncateDurableTables() async {
  final db = await _db();
  await db.queryNoTransaction('''
    TRUNCATE TABLE
      "human_decision",
      "work_item",
      "standing_policy",
      "product",
      "product_baseline",
      "repository_reference",
      "baseline_fact",
      "clarification_request",
      "product_credential",
      "product_registry_audit"
    RESTART IDENTITY CASCADE
  ''');
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
      setUp(_truncateDurableTables);

      test(
        'lifecycle decision raised and resolved durably with a real decisionId',
        () async {
          await _governedEngine(productId: governanceA, name: 'A');
          final request =
              await endpoints.productRegistryEndpoints
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

      test('policy authorisation round-trips durably and revokes by decision',
          () async {
        await _governedEngine(productId: 'governance-b', name: 'B');
        final request = await endpoints.productRegistryEndpoints
            .requestPolicyAuthorisation(
              sessionBuilder,
              productId: 'governance-b',
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
              productId: 'governance-b',
              policyId: resolved.policyId,
              revokedBy: 'human-gate',
            );
        expect(revoked.isRevoked, isTrue);
        expect(revoked.policyId, resolved.policyId);
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

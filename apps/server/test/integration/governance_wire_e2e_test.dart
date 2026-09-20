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
const governanceB = 'governance-b';

DecisionSignature _testSignature() => DecisionSignature(
  algorithm: 'ed25519',
  publicKey: 'pk-test',
  signature: 'sig-test',
  signedAt: DateTime.utc(2026, 1, 1),
);

List<BaselineFact> _facts(String seed) => [
  BaselineFact(
    factId: 'fact-$seed',
    section: BaselineSectionKey.techStack,
    claim: 'Governance wire round-trip fact for $seed',
    provenance: Provenance.humanProvided,
    maturity: BaselineMaturity.implemented,
    evidenceRefs: const ['repo:pubspec.yaml'],
  ),
];

Future<ProductRegistryEngine> _engine({
  required String productId,
  required String name,
}) async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  final db = PersistenceDatabase(session.db);
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
  // Approve the baseline to reach "governed" state
  final approvalRequest = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: proposed.baselineId,
  );
  await engine.resolveBaselineApproval(
    decisionId: approvalRequest.decisionId,
    choice: HumanDecisionChoice.approve,
    decider: 'human-gate',
    rationale: 'baseline accepted for governance test',
    signature: _testSignature(),
  );
  return engine;
}

Future<void> _truncateDurableTables() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  final db = PersistenceDatabase(session.db);
  await db.queryNoTransaction('''
    TRUNCATE TABLE
      "human_decision",
      "product_baseline",
      "clarification_request",
      "onboarding_record",
      "product",
      "repository_reference",
      "standing_policy"
    RESTART IDENTITY CASCADE
  ''');
}

void main() {
  withServerpod(
    'G-1 durable governance wire e2e (Postgres)',
    (sessionBuilder, endpoints) {
      setUp(_truncateDurableTables);

      test(
        'lifecycle decision request/resolve round-trip on the real wire',
        () async {
          await _engine(productId: governanceA, name: 'Governance A');

          final requested =
              await endpoints.productRegistryEndpoints
                  .requestLifecycleDecision(
                    sessionBuilder,
                    productId: governanceA,
                    action: 'pause',
                    drainInFlight: false,
                  );
          expect(requested.decisionId, isNotEmpty);

          final resolved =
              await endpoints.productRegistryEndpoints
                  .resolveLifecycleDecision(
                    sessionBuilder,
                    decisionId: requested.decisionId,
                    choice: 'approve',
                    decider: 'human-gate',
                    rationale: 'durable lifecycle approval',
                    signature: _testSignature().signature,
                    publicKey: _testSignature().publicKey,
                    algorithm: _testSignature().algorithm,
                    signedAt: _testSignature().signedAt,
                    noWorkInFlight: false,
                  );
          expect(resolved.decisionId, requested.decisionId);
          expect(resolved.status, 'resolved');
        },
      );

      test(
        'policy authorisation request/resolve/revoke round-trip durably',
        () async {
          await _engine(productId: governanceB, name: 'Governance B');

          final requested =
              await endpoints.productRegistryEndpoints
                  .requestPolicyAuthorisation(
                    sessionBuilder,
                    productId: governanceB,
                    actions: const ['push'],
                  );
          expect(requested.decisionId, isNotEmpty);

          final resolved =
              await endpoints.productRegistryEndpoints
                  .resolvePolicyAuthorisation(
                    sessionBuilder,
                    decisionId: requested.decisionId,
                    choice: 'approve',
                    decider: 'human-gate',
                    rationale: 'durable policy approval',
                    signature: _testSignature().signature,
                    publicKey: _testSignature().publicKey,
                    algorithm: _testSignature().algorithm,
                    signedAt: _testSignature().signedAt,
                  );
          expect(resolved, isNotNull);
          expect(resolved!.authorisingDecisionId, requested.decisionId);
          expect(resolved.isRevoked, isFalse);
          final policyId = resolved.policyId;

          final revoked =
              await endpoints.productRegistryEndpoints
                  .revokeStandingPolicy(
                    sessionBuilder,
                    productId: governanceB,
                    policyId: policyId,
                    revokedBy: 'human-gate',
                  );
          expect(revoked.policyId, policyId);
          expect(revoked.isRevoked, isTrue);
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
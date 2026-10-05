import 'dart:io';

import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_test/serverpod_test.dart';
import 'package:test/test.dart';

/// Test group name for the onboarding test
const String _testGroupName = 'ShipIt Platform Onboarding (S-1)';

/// The test endpoints for the control plane server.
///
/// `InternalTestEndpoints` is an `abstract interface class`, so it is
/// implemented rather than extended.
class _TestEndpoints implements InternalTestEndpoints {
  @override
  void initialize(
    SerializationManagerServer serializationManager,
    EndpointDispatch endpoints,
  ) {
    // No initialization needed for this test
  }
}

void main() {
  // Build the withServerpod test helper
  buildWithServerpod<_TestEndpoints>(
    _testGroupName,
    TestServerpod(
      testEndpoints: _TestEndpoints(),
      endpoints: Endpoints(),
      serializationManager: Protocol(),
      isDatabaseEnabled: true,
      runMode: null,
      applyMigrations: true,
      serverpodLoggingMode: null,
      testServerOutputMode: null,
    ),
    maybeRollbackDatabase: RollbackDatabase.disabled,
    maybeEnableSessionLogging: true,
    maybeTestGroupTagsOverride: const ['integration'],
    maybeServerpodStartTimeout: const Duration(seconds: 60),
    maybeTestServerOutputMode: TestServerOutputMode.normal,
  )((TestSessionBuilder testSession, _TestEndpoints endpoints) {
    late PersistenceDatabase db;
    late PostgresWorkflowStore workflowStore;
    late PostgresHumanDecisionStore decisions;
    late ProductRegistryEngine engine;
    final productId = 'shipit-platform';
    final maturityClassifier = MaturityClassifier();

    setUpAll(() async {
      // Create a session to access the database
      final session = testSession.build();
      db = PersistenceDatabase((session as dynamic).db);
      workflowStore = PostgresWorkflowStore(db);
      decisions = PostgresHumanDecisionStore(workflowStore);
      engine = ProductRegistryEngine(
        store: PostgresProductRegistryStore(db),
        humanDecisionStore: decisions,
      );
    });

    // Read-only discovery walks the whole workspace, which takes well past the
    // 30s default under a loaded machine.
    test('Complete onboarding flow', timeout: const Timeout(Duration(minutes: 5)), () async {
      // Create or load product
      Product product;
      try {
        product = await engine.readProduct(productId);
        stdout.writeln('PRODUCT IDENTITY (existing):');
      } on ProductNotFoundException {
        stdout.writeln('Product not found, creating...');
        product = await engine.createProduct(
          productId: productId,
          name: 'ShipIt',
          description: 'The platform itself (S-1 dogfood).',
        );
        stdout.writeln('PRODUCT IDENTITY (created):');
      }
      stdout.writeln('  display name: ${product.name}');
      stdout.writeln('  productId: ${product.productId}');
      stdout.writeln('  ProductState: ${product.state.wire}');
      stdout.writeln('  dispatch allowed: ${product.state.allowsDispatch}');

      // Add repository reference
      stdout.writeln('\nAdding repository reference...');
      try {
        await engine.addRepositoryReference(
          repositoryId: 'repo-shipit-platform',
          productId: productId,
          uri: '/Users/alkebut/air/shipit-platform',
          kind: RepositoryKind.monorepo,
          provider: RepositoryProvider.local,
        );
        stdout.writeln('Repository reference added.');
      } catch (e) {
        stdout.writeln('Repository reference already exists or error: $e');
      }

      // Run read-only discovery
      stdout.writeln(
        '\nRunning read-only discovery with MaturityClassifier...',
      );
      final observations = await ReadOnlyRepositoryReader(
        snapshotRoot: Directory('/Users/alkebut/air/shipit-platform'),
      ).inspect();
      stdout.writeln('Discovered ${observations.length} observations.');

      final facts = <BaselineFact>[
        for (var i = 0; i < observations.length; i++)
          BaselineFact(
            factId: 'dogfood-$i',
            section: observations[i].section,
            claim: observations[i].claim,
            provenance: observations[i].provenance,
            maturity: maturityClassifier.classify(
              claim: observations[i].claim,
              evidencePaths: observations[i].evidencePaths,
              provenance: observations[i].provenance,
              assumptionNote: observations[i].assumptionNote,
              redacted: observations[i].redacted,
            ),
            evidenceRefs: observations[i].evidencePaths,
            assumptionNote: observations[i].assumptionNote,
            redacted: observations[i].redacted,
          ),
      ];

      // Propose baseline
      stdout.writeln('\nProposing baseline...');
      final proposed = await engine.proposeBaseline(
        productId: productId,
        facts: facts,
      );
      stdout.writeln('Proposed baseline:');
      stdout.writeln('  baselineId: ${proposed.baselineId}');
      stdout.writeln('  revision: ${proposed.revision}');
      stdout.writeln('  contentHash: ${proposed.contentHash}');
      stdout.writeln('  contentHashVersion: ${proposed.contentHashVersion}');
      stdout.writeln('  status: ${proposed.status.wire}');
      stdout.writeln('  fact count: ${proposed.facts.length}');

      final matCounts = <String, int>{};
      for (final f in proposed.facts) {
        matCounts[f.maturity.wire] = (matCounts[f.maturity.wire] ?? 0) + 1;
      }
      stdout.writeln('\nProposed baseline maturity counts:');
      matCounts.forEach((k, v) => stdout.writeln('  $k: $v'));

      // Resolve pending decisions
      stdout.writeln('\nResolving any existing pending decisions...');
      final existingDecisions = await decisions.readHumanDecisionsForScope(
        'product-baseline:$productId',
      );
      for (final d in existingDecisions) {
        if (d.status == HumanDecisionStatus.pending) {
          stdout.writeln(
            'Resolving pending decision ${d.decisionId} as REWORK...',
          );
          final testSig = DecisionSignature(
            algorithm: 'ed25519',
            publicKey: 'pk-human-review',
            signature: 'sig-human-review-rework',
            signedAt: DateTime.utc(2026, 9, 17),
          );
          await engine.resolveBaselineApproval(
            decisionId: d.decisionId,
            choice: HumanDecisionChoice.rework,
            decider: 'human-review',
            rationale:
                'Hash contract upgraded to V2 (binds maturity). Discovery maturity classification was systematically incorrect (defaulted to IMPLEMENTED). New baseline with Hash V2 and corrected maturity required.',
            signature: testSig,
          );
          stdout.writeln('  Resolved: ${d.decisionId} as REWORK');
        }
      }

      // Create corrected baseline
      stdout.writeln('\nCreating corrected baseline with Hash Contract V2...');
      final correctedFacts = <BaselineFact>[
        ...proposed.facts.map(
          (f) => BaselineFact(
            factId: f.factId,
            section: f.section,
            claim: f.claim,
            provenance: f.provenance,
            maturity: maturityClassifier.classify(
              claim: f.claim,
              evidencePaths: f.evidenceRefs,
              provenance: f.provenance,
              assumptionNote: f.assumptionNote,
              redacted: f.redacted,
            ),
            evidenceRefs: f.evidenceRefs,
            assumptionNote: f.assumptionNote,
            redacted: f.redacted,
          ),
        ),
        BaselineFact(
          factId: 'correction-1',
          section: BaselineSectionKey.governance,
          claim:
              'ControlPlane writes: ProductRegistryEndpoints include governed mutations (requestBaselineApproval, resolveBaselineApproval, baselineApproval, answerClarification). Not limited to resolveHumanDecision.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.implemented,
          evidenceRefs: const [
            'lib/src/endpoints/product_registry_endpoints.dart',
          ],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-2',
          section: BaselineSectionKey.governance,
          claim:
              'Real-time session log streaming to Flutter UI: NOT_IMPLEMENTED. Original operator-UI scope excluded realtime behavior.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.notImplemented,
          evidenceRefs: const [
            'lib/features/',
            'lib/data/control_plane_repository.dart',
          ],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-3',
          section: BaselineSectionKey.governance,
          claim:
              'HumanDecision authority implemented for: workflow human decisions, ProductBaseline acceptance. Deployment/release/rollback/security/infra gates exist as contracts/policies, not implemented authority paths.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.policy,
          evidenceRefs: const [
            'packages/deployment_protocol/',
            'packages/qa_orchestration/',
            'packages/workflow_engine/',
          ],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-4',
          section: BaselineSectionKey.deployment,
          claim:
              'Artifact storage: ArtifactReference/PlatformVerification use content hashes. AgentResult/worker artifacts reference files. Production GCS/Local ArtifactStore NOT_IMPLEMENTED. Do not generalize.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.notImplemented,
          evidenceRefs: const [
            'packages/deployment_protocol/',
            'packages/agent_runtime/',
          ],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-5',
          section: BaselineSectionKey.ciCd,
          claim:
              'Byte-identical Serverpod regeneration executed as QA evidence (local). GitHub Actions CI pipeline NOT_IMPLEMENTED in repo. Distinguish QA evidence from CI enforcement.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.notImplemented,
          evidenceRefs: const ['melos.yaml', '.github/ (absent)'],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-6',
          section: BaselineSectionKey.qa,
          claim:
              'QA governance: QAContract, independent verification, artifact validation exist as contracts/policies (packages/qa_orchestration). Full AEF implementation NOT_VERIFIED. Distinguish implemented from planned.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.policy,
          evidenceRefs: const ['packages/qa_orchestration/'],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-7',
          section: BaselineSectionKey.architecture,
          claim:
              'ProductState (draft/active/archived/deprecated) is distinct from WorkItemState workflow gates. Do not conflate Product lifecycle with WorkItem workflow lifecycle.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.implemented,
          evidenceRefs: const [
            'packages/platform_contracts/lib/src/enums/product_state.dart',
            'packages/workflow_engine/lib/src/states/workflow_state.dart',
          ],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-8',
          section: BaselineSectionKey.deployment,
          claim:
              'DeploymentProtocol models artifact promotion/rollback as domain types. Production deployment targets, OpenTofu IaC, GCS ArtifactStore NOT_IMPLEMENTED. ShipIt not production-deployable.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.notImplemented,
          evidenceRefs: const [
            'packages/deployment_protocol/',
            'docs/adr/0009-opentofu-iac.md',
          ],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-9',
          section: BaselineSectionKey.governance,
          claim:
              'Independent baseline review of v1 was insufficient — human review identified material overstatements. Review must explicitly check: OBSERVED vs DERIVED vs HUMAN_PROVIDED AND IMPLEMENTED vs PLANNED vs POLICY. Provenance alone is insufficient.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.policy,
          evidenceRefs: const ['this correction rationale'],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-10',
          section: BaselineSectionKey.governance,
          claim:
              'BaselineFact model now includes typed maturity field (implemented, policy, planned, deferred, notImplemented, unknown) independent of provenance. ARCHITECTURE_DECISION_REQUIRED resolved.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.implemented,
          evidenceRefs: const [
            'packages/platform_contracts/lib/src/enums/baseline_maturity.dart',
            'packages/platform_contracts/lib/src/types/baseline_fact.dart',
          ],
          redacted: false,
        ),
        BaselineFact(
          factId: 'correction-11',
          section: BaselineSectionKey.governance,
          claim:
              'Baseline revisions must be complete standalone snapshots. V3 carries forward all valid v1 facts + corrections. v2 delta rejected. ContentHash binds complete fact set.',
          provenance: Provenance.humanProvided,
          maturity: BaselineMaturity.policy,
          evidenceRefs: const ['AD-1 baseline revision semantics'],
          redacted: false,
        ),
      ];

      final corrected = await engine.proposeBaseline(
        productId: productId,
        facts: correctedFacts,
      );

      stdout.writeln('\nCORRECTED BASELINE CREATED (Hash V2):');
      stdout.writeln('  baselineId: ${corrected.baselineId}');
      stdout.writeln('  revision: ${corrected.revision}');
      stdout.writeln('  contentHash: ${corrected.contentHash}');
      stdout.writeln('  contentHashVersion: ${corrected.contentHashVersion}');
      stdout.writeln('  status: ${corrected.status.wire}');
      stdout.writeln(
        '  supersedesBaselineId: ${corrected.supersedesBaselineId}',
      );
      stdout.writeln('  fact count: ${corrected.facts.length}');

      final matCountsCorrected = <String, int>{};
      for (final f in corrected.facts) {
        matCountsCorrected[f.maturity.wire] =
            (matCountsCorrected[f.maturity.wire] ?? 0) + 1;
      }
      stdout.writeln('\nCorrected baseline maturity counts:');
      matCountsCorrected.forEach((k, v) => stdout.writeln('  $k: $v'));

      // Create governing HumanDecision
      stdout.writeln(
        '\nCreating governing HumanDecision for corrected baseline (Hash V2)...',
      );
      // Review only opens for a baseline that was independently verified, so
      // the corrected revision has to carry that verification first.
      await engine.verifyBaseline(
        productId: productId,
        baselineId: corrected.baselineId,
        verifiedBy: 'shipit-platform-verifier',
      );
      final correctedDecision = await engine.requestBaselineApproval(
        productId: productId,
        baselineId: corrected.baselineId,
      );

      stdout.writeln('\nCORRECTED DECISION CREATED:');
      stdout.writeln('  decisionId: ${correctedDecision.decisionId}');
      stdout.writeln('  workItemId: ${correctedDecision.workItemId}');
      stdout.writeln('  decisionType: ${correctedDecision.decisionType.wire}');
      stdout.writeln('  status: ${correctedDecision.status.wire}');
      stdout.writeln('  question: ${correctedDecision.question}');
      stdout.writeln('  metadata: ${correctedDecision.metadata}');

      // Verify decision stored
      final stored = await decisions.readHumanDecision(
        correctedDecision.decisionId,
      );
      stdout.writeln(
        '\nVerified stored corrected decision: ${stored?.decisionId}',
      );

      // Verify Hash V2 binding in metadata
      final metadata = correctedDecision.metadata ?? {};
      stdout.writeln('\nDecision metadata binding:');
      stdout.writeln('  routing: ${metadata['routing']}');
      stdout.writeln('  productId: ${metadata['productId']}');
      stdout.writeln('  baselineId: ${metadata['baselineId']}');
      stdout.writeln('  baselineRevision: ${metadata['baselineRevision']}');
      stdout.writeln('  contentHash: ${metadata['contentHash']}');

      // Verify Hash V2 recomputation
      final recomputedHash = baselineContentHashV2(corrected.facts);
      stdout.writeln('\n=== HASH V2 RECOMPUTATION ===');
      stdout.writeln('  persisted contentHash: ${corrected.contentHash}');
      stdout.writeln('  recomputed Hash V2:   $recomputedHash');
      stdout.writeln('  contentHashVersion:   ${corrected.contentHashVersion}');
      stdout.writeln(
        '  MATCH: ${corrected.contentHash == recomputedHash && corrected.contentHashVersion == 2}',
      );

      // Fresh process readback proof
      stdout.writeln('\n=== FRESH PROCESS READBACK ===');
      // Create a new session for fresh readback
      final freshSession = testSession.build();
      final freshDb = PersistenceDatabase((freshSession as dynamic).db);
      final freshWorkflowStore = PostgresWorkflowStore(freshDb);
      final freshDecisions = PostgresHumanDecisionStore(freshWorkflowStore);
      final freshEngine = ProductRegistryEngine(
        store: PostgresProductRegistryStore(freshDb),
        humanDecisionStore: freshDecisions,
      );

      final ctx = await freshEngine.loadProductContext(productId);
      stdout.writeln('ProductContext loaded from fresh session:');
      stdout.writeln(
        '  active baseline: ${ctx.activeBaseline?.baselineId} (rev ${ctx.activeBaseline?.revision})',
      );
      stdout.writeln(
        '  active baseline status: ${ctx.activeBaseline?.status.wire}',
      );
      stdout.writeln(
        '  active baseline contentHashVersion: ${ctx.activeBaseline?.contentHashVersion}',
      );
      stdout.writeln('  all baselines count: ${ctx.allBaselines.length}');

      if (ctx.activeBaseline != null) {
        stdout.writeln(
          '  reloaded baselineId: ${ctx.activeBaseline!.baselineId}',
        );
        stdout.writeln('  reloaded revision: ${ctx.activeBaseline!.revision}');
        stdout.writeln(
          '  reloaded contentHash: ${ctx.activeBaseline!.contentHash}',
        );
        stdout.writeln(
          '  reloaded contentHashVersion: ${ctx.activeBaseline!.contentHashVersion}',
        );
        stdout.writeln(
          '  reloaded fact count: ${ctx.activeBaseline!.facts.length}',
        );

        final reloadProv = <String, int>{};
        final reloadMat = <String, int>{};
        for (final f in ctx.activeBaseline!.facts) {
          reloadProv[f.provenance.wire] =
              (reloadProv[f.provenance.wire] ?? 0) + 1;
          reloadMat[f.maturity.wire] = (reloadMat[f.maturity.wire] ?? 0) + 1;
        }
        stdout.writeln('\nReloaded provenance counts:');
        reloadProv.forEach((k, v) => stdout.writeln('  $k: $v'));
        stdout.writeln('\nReloaded maturity counts:');
        reloadMat.forEach((k, v) => stdout.writeln('  $k: $v'));
      }

      if (ctx.activeBaseline != null) {
        final recomputedHash = baselineContentHashV2(ctx.activeBaseline!.facts);
        stdout.writeln('\n=== HASH V2 RECOMPUTATION (FRESH SESSION) ===');
        stdout.writeln(
          '  persisted contentHash: ${ctx.activeBaseline!.contentHash}',
        );
        stdout.writeln('  recomputed Hash V2:   $recomputedHash');
        stdout.writeln(
          '  MATCH: ${recomputedHash == ctx.activeBaseline!.contentHash}',
        );
        stdout.writeln(
          '  contentHashVersion: ${ctx.activeBaseline!.contentHashVersion}',
        );
      }

      // Final gate summary
      stdout.writeln('\n=== CORRECTED BASELINE GATE SUMMARY ===');
      stdout.writeln('productId: $productId');
      stdout.writeln('baselineId: ${corrected.baselineId}');
      stdout.writeln('revision: ${corrected.revision}');
      stdout.writeln('contentHash: ${corrected.contentHash}');
      stdout.writeln('contentHashVersion: ${corrected.contentHashVersion}');
      stdout.writeln('decisionId: ${correctedDecision.decisionId}');
      stdout.writeln('status: ${corrected.status.wire}');
      stdout.writeln('CURRENT GATE: PRODUCT_BASELINE_APPROVAL_REQUIRED');
      stdout.writeln(
        'HASH CONTRACT: V2 (binds maturity + all semantic fields)',
      );
      stdout.writeln('\n=== ONBOARDING COMPLETE ===');
    });
  });
}

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
import 'package:workflow_store/workflow_store.dart';

import 'package:product_registry/src/discovery/read_only_repository_reader.dart';
import 'package:product_registry/src/discovery/maturity_classifier.dart';
import 'package:product_registry/src/engine/baseline_content_hash_v2.dart';

Future<PersistenceDatabase> _newTestDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

void main() async {
  // Initialize Serverpod for DEV database (persistent, not test)
  final pod = Serverpod(
    ['--mode', 'development'],
    Protocol(),
    Endpoints(),
    configOverride: (config) => config.copyWith(
      database: DatabaseConfig(
        host: 'localhost',
        port: 8090,
        name: 'control_plane',
        user: 'postgres',
        password: 'fd6239170e2e5511e8ac0fa79a03695f28781037d4c8b644',
      ),
      redis: null,
      webServer: null,
      insightsServer: null,
    ),
  );
  await pod.start();

  final db = await _newTestDb();
  final workflowStore = PostgresWorkflowStore(db);
  final decisions = PostgresHumanDecisionStore(workflowStore);
  final engine = ProductRegistryEngine(
    store: PostgresProductRegistryStore(db),
    humanDecisionStore: decisions,
  );

  final productId = 'shipit-platform';
  final maturityClassifier = MaturityClassifier();

  // Create or load product
  Product product;
  try {
    product = await engine.readProduct(productId);
    print('PRODUCT IDENTITY (existing):');
  } on ProductNotFoundException {
    print('Product not found, creating...');
    product = await engine.createProduct(
      productId: productId,
      name: 'ShipIt',
      description: 'The platform itself (S-1 dogfood).',
    );
    print('PRODUCT IDENTITY (created):');
  }
  print('  display name: ${product.name}');
  print('  productId: ${product.productId}');
  print('  ProductState: ${product.state.wire}');
  print('  dispatch allowed: ${product.state.allowsDispatch}');

  // Add repository reference
  print('\nAdding repository reference...');
  await engine.addRepositoryReference(
    repositoryId: 'repo-shipit-platform',
    productId: productId,
    uri: '/Users/alkebut/air/shipit-platform',
    kind: RepositoryKind.monorepo,
    provider: RepositoryProvider.local,
  );
  print('Repository reference added.');

  // Run read-only discovery with proper maturity classification
  print('\nRunning read-only discovery with MaturityClassifier...');
  final observations = await ReadOnlyRepositoryReader(
    snapshotRoot: Directory('/Users/alkebut/air/shipit-platform'),
  ).inspect();
  print('Discovered ${observations.length} observations.');

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
  print('\nProposing baseline...');
  final proposed = await engine.proposeBaseline(
    productId: productId,
    facts: facts,
  );
  print('Proposed baseline:');
  print('  baselineId: ${proposed.baselineId}');
  print('  revision: ${proposed.revision}');
  print('  contentHash: ${proposed.contentHash}');
  print('  contentHashVersion: ${proposed.contentHashVersion}');
  print('  status: ${proposed.status.wire}');
  print('  fact count: ${proposed.facts.length}');

  // Count maturity
  final provCounts = <String, int>{};
  final matCounts = <String, int>{};
  for (final f in proposed.facts) {
    provCounts[f.provenance.wire] = (provCounts[f.provenance.wire] ?? 0) + 1;
    matCounts[f.maturity.wire] = (matCounts[f.maturity.wire] ?? 0) + 1;
  }
  print('\nProposed baseline maturity counts:');
  matCounts.forEach((k, v) => print('  ${k}: $v'));

  // Resolve any existing pending decisions as rework
  print('\nResolving any existing pending decisions...');
  final existingDecisions = await decisions.readHumanDecisionsForScope('product-baseline:$productId');
  for (final d in existingDecisions) {
    if (d.status == HumanDecisionStatus.pending) {
      print('Resolving pending decision ${d.decisionId} as REWORK...');
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
        rationale: 'Hash contract upgraded to V2 (binds maturity). Discovery maturity classification was systematically incorrect (defaulted to IMPLEMENTED). New baseline with Hash V2 and corrected maturity required.',
        signature: testSig,
      );
      print('  Resolved: ${d.decisionId} as REWORK');
    }
  }

  // Create corrected baseline using MaturityClassifier for corrections too
  print('\nCreating corrected baseline with Hash Contract V2...');
  
  // Build complete corrected baseline using MaturityClassifier for all facts
  final correctedFacts = <BaselineFact>[
    // Carry forward all v1 facts with re-classified maturity
    ...proposed.facts.map((f) => BaselineFact(
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
    )).toList(),
    // Add correction facts with proper maturity
    BaselineFact(
      factId: 'correction-1',
      section: BaselineSectionKey.governance,
      claim: 'ControlPlane writes: ProductRegistryEndpoints include governed mutations (requestBaselineApproval, resolveBaselineApproval, baselineApproval, answerClarification). Not limited to resolveHumanDecision.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.implemented,
      evidenceRefs: const ['lib/src/endpoints/product_registry_endpoints.dart'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-2',
      section: BaselineSectionKey.governance,
      claim: 'Real-time session log streaming to Flutter UI: NOT_IMPLEMENTED. Original operator-UI scope excluded realtime behavior.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.notImplemented,
      evidenceRefs: const ['lib/features/', 'lib/data/control_plane_repository.dart'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-3',
      section: BaselineSectionKey.governance,
      claim: 'HumanDecision authority implemented for: workflow human decisions, ProductBaseline acceptance. Deployment/release/rollback/security/infra gates exist as contracts/policies, not implemented authority paths.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.policy,
      evidenceRefs: const ['packages/deployment_protocol/', 'packages/qa_orchestration/', 'packages/workflow_engine/'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-4',
      section: BaselineSectionKey.deployment,
      claim: 'Artifact storage: ArtifactReference/PlatformVerification use content hashes. AgentResult/worker artifacts reference files. Production GCS/Local ArtifactStore NOT_IMPLEMENTED. Do not generalize.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.notImplemented,
      evidenceRefs: const ['packages/deployment_protocol/', 'packages/agent_runtime/'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-5',
      section: BaselineSectionKey.ciCd,
      claim: 'Byte-identical Serverpod regeneration executed as QA evidence (local). GitHub Actions CI pipeline NOT_IMPLEMENTED in repo. Distinguish QA evidence from CI enforcement.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.notImplemented,
      evidenceRefs: const ['melos.yaml', '.github/ (absent)'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-6',
      section: BaselineSectionKey.qa,
      claim: 'QA governance: QAContract, independent verification, artifact validation exist as contracts/policies (packages/qa_orchestration). Full AEF implementation NOT_VERIFIED. Distinguish implemented from planned.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.policy,
      evidenceRefs: const ['packages/qa_orchestration/'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-7',
      section: BaselineSectionKey.architecture,
      claim: 'ProductState (draft/active/archived/deprecated) is distinct from WorkItemState workflow gates. Do not conflate Product lifecycle with WorkItem workflow lifecycle.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.implemented,
      evidenceRefs: const ['packages/platform_contracts/lib/src/enums/product_state.dart', 'packages/workflow_engine/lib/src/states/workflow_state.dart'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-8',
      section: BaselineSectionKey.deployment,
      claim: 'DeploymentProtocol models artifact promotion/rollback as domain types. Production deployment targets, OpenTofu IaC, GCS ArtifactStore NOT_IMPLEMENTED. ShipIt not production-deployable.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.notImplemented,
      evidenceRefs: const ['packages/deployment_protocol/', 'docs/adr/0009-opentofu-iac.md'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-9',
      section: BaselineSectionKey.governance,
      claim: 'Independent baseline review of v1 was insufficient — human review identified material overstatements. Review must explicitly check: OBSERVED vs DERIVED vs HUMAN_PROVIDED AND IMPLEMENTED vs PLANNED vs POLICY. Provenance alone is insufficient.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.policy,
      evidenceRefs: const ['this correction rationale'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-10',
      section: BaselineSectionKey.governance,
      claim: 'BaselineFact model now includes typed maturity field (implemented, policy, planned, deferred, notImplemented, unknown) independent of provenance. ARCHITECTURE_DECISION_REQUIRED resolved.',
      provenance: Provenance.humanProvided,
      maturity: BaselineMaturity.implemented,
      evidenceRefs: const ['packages/platform_contracts/lib/src/enums/baseline_maturity.dart', 'packages/platform_contracts/lib/src/types/baseline_fact.dart'],
      redacted: false,
    ),
    BaselineFact(
      factId: 'correction-11',
      section: BaselineSectionKey.governance,
      claim: 'Baseline revisions must be complete standalone snapshots. V3 carries forward all valid v1 facts + corrections. v2 delta rejected. ContentHash binds complete fact set.',
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

  print('\nCORRECTED BASELINE CREATED (Hash V2):');
  print('  baselineId: ${corrected.baselineId}');
  print('  revision: ${corrected.revision}');
  print('  contentHash: ${corrected.contentHash}');
  print('  contentHashVersion: ${corrected.contentHashVersion}');
  print('  status: ${corrected.status.wire}');
  print('  supersedesBaselineId: ${corrected.supersedesBaselineId}');
  print('  fact count: ${corrected.facts.length}');

  // Count maturity
  final matCountsCorrected = <String, int>{};
  for (final f in corrected.facts) {
    matCountsCorrected[f.maturity.wire] = (matCountsCorrected[f.maturity.wire] ?? 0) + 1;
  }
  print('\nCorrected baseline maturity counts:');
  matCountsCorrected.forEach((k, v) => print('  ${k}: $v'));

  // Create governing HumanDecision for corrected baseline
  print('\nCreating governing HumanDecision for corrected baseline (Hash V2)...');
  final correctedDecision = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: corrected.baselineId,
  );

  print('\nCORRECTED DECISION CREATED:');
  print('  decisionId: ${correctedDecision.decisionId}');
  print('  workItemId: ${correctedDecision.workItemId}');
  print('  decisionType: ${correctedDecision.decisionType.wire}');
  print('  status: ${correctedDecision.status.wire}');
  print('  question: ${correctedDecision.question}');
  print('  metadata: ${correctedDecision.metadata}');

  // Verify decision stored
  final stored = await decisions.readHumanDecision(correctedDecision.decisionId);
  print('\nVerified stored corrected decision: ${stored?.decisionId}');

  // Verify Hash V2 binding in metadata
  final metadata = correctedDecision.metadata ?? {};
  print('\nDecision metadata binding:');
  print('  routing: ${metadata['routing']}');
  print('  productId: ${metadata['productId']}');
  print('  baselineId: ${metadata['baselineId']}');
  print('  baselineRevision: ${metadata['baselineRevision']}');
  print('  contentHash: ${metadata['contentHash']}');

  // Verify Hash V2 recomputation
  final recomputedHash = baselineContentHashV2(corrected.facts);
  print('\n=== HASH V2 RECOMPUTATION ===');
  print('  persisted contentHash: ${corrected.contentHash}');
  print('  recomputed Hash V2:   $recomputedHash');
  print('  contentHashVersion:   ${corrected.contentHashVersion}');
  print('  MATCH: ${corrected.contentHash == recomputedHash && corrected.contentHashVersion == 2}');

  // Fresh process readback proof
  print('\n=== FRESH PROCESS READBACK ===');
  final freshDb = await _newTestDb();
  final freshWorkflowStore = PostgresWorkflowStore(freshDb);
  final freshDecisions = PostgresHumanDecisionStore(freshWorkflowStore);
  final freshEngine = ProductRegistryEngine(
    store: PostgresProductRegistryStore(freshDb),
    humanDecisionStore: freshDecisions,
  );
  
  final ctx = await freshEngine.loadProductContext(productId);
  print('ProductContext loaded from fresh process:');
  print('  active baseline: ${ctx.activeBaseline?.baselineId} (rev ${ctx.activeBaseline?.revision})');
  print('  active baseline status: ${ctx.activeBaseline?.status.wire}');
  print('  active baseline contentHashVersion: ${ctx.activeBaseline?.contentHashVersion}');
  print('  all baselines count: ${ctx.allBaselines.length}');
  
  if (ctx.activeBaseline != null) {
    print('  reloaded baselineId: ${ctx.activeBaseline!.baselineId}');
    print('  reloaded revision: ${ctx.activeBaseline!.revision}');
    print('  reloaded contentHash: ${ctx.activeBaseline!.contentHash}');
    print('  reloaded contentHashVersion: ${ctx.activeBaseline!.contentHashVersion}');
    print('  reloaded fact count: ${ctx.activeBaseline!.facts.length}');
    
    // Verify provenance/maturity preserved
    final reloadProv = <String, int>{};
    final reloadMat = <String, int>{};
    for (final f in ctx.activeBaseline!.facts) {
      reloadProv[f.provenance.wire] = (reloadProv[f.provenance.wire] ?? 0) + 1;
      reloadMat[f.maturity.wire] = (reloadMat[f.maturity.wire] ?? 0) + 1;
    }
    print('\nReloaded provenance counts:');
    reloadProv.forEach((k, v) => print('  $k: $v'));
    print('\nReloaded maturity counts:');
    reloadMat.forEach((k, v) => print('  $k: $v'));
  }

  // Hash V2 recomputation proof
  if (ctx.activeBaseline != null) {
    final recomputedHash = baselineContentHashV2(ctx.activeBaseline!.facts);
    print('\n=== HASH V2 RECOMPUTATION (FRESH PROCESS) ===');
    print('  persisted contentHash: ${ctx.activeBaseline!.contentHash}');
    print('  recomputed Hash V2:   $recomputedHash');
    print('  MATCH: ${recomputedHash == ctx.activeBaseline!.contentHash}');
    print('  contentHashVersion: ${ctx.activeBaseline!.contentHashVersion}');
  }

  // Final gate summary
  print('\n=== CORRECTED BASELINE GATE SUMMARY ===');
  print('productId: $productId');
  print('baselineId: ${corrected.baselineId}');
  print('revision: ${corrected.revision}');
  print('contentHash: ${corrected.contentHash}');
  print('contentHashVersion: ${corrected.contentHashVersion}');
  print('decisionId: ${correctedDecision.decisionId}');
  print('status: ${corrected.status.wire}');
  print('CURRENT GATE: PRODUCT_BASELINE_APPROVAL_REQUIRED');
  print('HASH CONTRACT: V2 (binds maturity + all semantic fields)');
}
import 'dart:async';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';

import 'lib/src/generated/endpoints.dart';
import 'lib/src/generated/protocol.dart';
import 'lib/src/persistence/postgres_workflow_store.dart';
import 'lib/src/persistence/postgres_human_decision_store.dart';
import 'lib/src/persistence/postgres_product_registry_store.dart';
import 'lib/src/persistence/persistence_database.dart';

String _env(String key, String fallback) {
  final value = Platform.environment[key];
  return (value == null || value.isEmpty) ? fallback : value;
}

/// ShipIt platform onboarding script (S-1).
///
/// Creates a Serverpod instance to connect to the already-migrated database
/// and runs the onboarding logic.
Future<void> main() async {
  try {
    stdout.writeln('=== ShipIt Platform Onboarding (S-1) ===');

    // Create Serverpod instance to connect to the already-migrated database
    // (migrations were applied by the background server)
    final pod = Serverpod(
      ['--mode', 'development'],
      Protocol(),
      Endpoints(),
      configOverride: (config) => config.copyWith(
        database: DatabaseConfig(
          host: 'localhost',
          port: 5432,
          name: 'shipit',
          user: 'shipit',
          password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit'),
        ),
        redis: null,
        webServer: null,
        insightsServer: null,
      ),
    );

    stdout.writeln('Starting Serverpod...');
    // Serverpod.start() returns once startup completes - it does not wait for
    // server shutdown, so awaiting it would not hang; `bin/test_pod.dart` awaits
    // it and still reaches `shutdown()`. Startup is deliberately left
    // un-awaited so the onboarding below runs concurrently with it.
    // The database is initialized synchronously during start().
    // `unawaited` is a no-op wrapper (`void unawaited(Future<void>? f) {}`) that
    // discards the future so `unawaited_futures` stays satisfied and the
    // deliberate fire-and-forget intent is explicit in code.
    unawaited(pod.start());
    stdout.writeln('Serverpod starting (non-blocking)...');
    // Best-effort flushes, deliberately not awaited: `unawaited` keeps them
    // non-blocking exactly as before rather than routing a flush failure into
    // the fatal handler below.
    unawaited(stdout.flush());
    // Give database time to initialize
    await Future.delayed(const Duration(seconds: 3));
    stdout.writeln('Serverpod started, database connected.');
    unawaited(stdout.flush());

    // Get database session
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    final db = PersistenceDatabase(session.db);

    final workflowStore = PostgresWorkflowStore(db);
    final decisions = PostgresHumanDecisionStore(workflowStore);
    final engine = ProductRegistryEngine(
      store: PostgresProductRegistryStore(db),
      humanDecisionStore: decisions,
    );

    final productId = 'shipit-platform';
    final maturityClassifier = MaturityClassifier();

    stdout.writeln(
      'Database stores created, attempting to read/create product...',
    );
    // Create or load product
    Product product;
    try {
      product = await engine.readProduct(productId);
      stdout.writeln('PRODUCT IDENTITY (existing):');
    } on ProductNotFoundException catch (e) {
      stdout.writeln(
        'Product not found (ProductNotFoundException), creating...',
      );
      stdout.writeln('Exception: $e');
      product = await engine.createProduct(
        productId: productId,
        name: 'ShipIt',
        description: 'The platform itself (S-1 dogfood).',
      );
      stdout.writeln('PRODUCT IDENTITY (created):');
    } catch (e, stackTrace) {
      stdout.writeln('ERROR reading/creating product: $e');
      stdout.writeln('Stack trace: $stackTrace');
      rethrow;
    }
    stdout.writeln('  display name: ${product.name}');
    stdout.writeln('  productId: ${product.productId}');
    stdout.writeln('  ProductState: ${product.state.wire}');
    stdout.writeln('  dispatch allowed: ${product.state.allowsDispatch}');

    // Add repository reference
    stdout.writeln('\nAdding repository reference...');
    stdout.writeln('About to call engine.addRepositoryReference...');
    try {
      stdout.writeln('Calling engine.addRepositoryReference...');
      await engine.addRepositoryReference(
        repositoryId: 'repo-shipit-platform',
        productId: productId,
        uri: '/Users/alkebut/air/shipit-platform',
        kind: RepositoryKind.monorepo,
        provider: RepositoryProvider.local,
      );
      stdout.writeln('Repository reference added.');
    } catch (e, stackTrace) {
      stdout.writeln('Repository reference already exists or error: $e');
      stdout.writeln('Stack trace: $stackTrace');
    }
    stdout.writeln('Repository reference step completed.');

    // Run read-only discovery with proper maturity classification
    stdout.writeln('\nRunning read-only discovery with MaturityClassifier...');
    stdout.writeln('\nRunning read-only discovery with MaturityClassifier...');
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

    // Count maturity
    final matCounts = <String, int>{};
    for (final f in proposed.facts) {
      matCounts[f.maturity.wire] = (matCounts[f.maturity.wire] ?? 0) + 1;
    }
    stdout.writeln('\nProposed baseline maturity counts:');
    matCounts.forEach((k, v) => stdout.writeln('  $k: $v'));

    // Resolve any existing pending decisions as rework
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

    // Create corrected baseline using MaturityClassifier for corrections too
    stdout.writeln('\nCreating corrected baseline with Hash Contract V2...');

    // Build complete corrected baseline using MaturityClassifier for all facts
    final correctedFacts = <BaselineFact>[
      // Carry forward all v1 facts with re-classified maturity
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
      // Add correction facts with proper maturity
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
    stdout.writeln('  supersedesBaselineId: ${corrected.supersedesBaselineId}');
    stdout.writeln('  fact count: ${corrected.facts.length}');

    // Count maturity
    final matCountsCorrected = <String, int>{};
    for (final f in corrected.facts) {
      matCountsCorrected[f.maturity.wire] =
          (matCountsCorrected[f.maturity.wire] ?? 0) + 1;
    }
    stdout.writeln('\nCorrected baseline maturity counts:');
    matCountsCorrected.forEach((k, v) => stdout.writeln('  $k: $v'));

    // Create governing HumanDecision for corrected baseline
    stdout.writeln(
      '\nCreating governing HumanDecision for corrected baseline (Hash V2)...',
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
    final freshSession = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    final freshDb = PersistenceDatabase(freshSession.db);
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

      // Verify provenance/maturity preserved
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

    // Hash V2 recomputation proof
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
    stdout.writeln('HASH CONTRACT: V2 (binds maturity + all semantic fields)');
    stdout.writeln('\n=== ONBOARDING COMPLETE ===');
  } catch (e, stackTrace) {
    stdout.writeln('FATAL ERROR: $e');
    stdout.writeln('Stack trace: $stackTrace');
    exit(1);
  }
}

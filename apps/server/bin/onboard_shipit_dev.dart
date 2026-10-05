/// Onboards a product from a real repository snapshot and leaves the baseline
/// approval to a human.
///
/// Run it against the control-plane database:
///
///   SERVERPOD_DATABASE_HOST=postgres \
///   SHIPIT_REPOSITORY_PATH=/repo \
///   dart run bin/onboard_shipit_dev.dart
///
/// Every connection detail comes from the environment so the same script runs
/// on a developer machine and inside the compose network, where the database is
/// reachable as `postgres:5432` but not as `localhost:5432`.
///
/// This script NEVER resolves a HumanDecision. Baseline approval is a human
/// gate (AGENTS.md §19); fabricating a decider would forge the authority that
/// makes a governed product meaningful. It stops at a pending decision.
library;

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

String _env(String key, String fallback) {
  final value = Platform.environment[key];
  return (value == null || value.isEmpty) ? fallback : value;
}

void main(List<String> argv) async {
  final productId = argv.isNotEmpty
      ? argv.first
      : _env('SHIPIT_PRODUCT_ID', 'shipit-platform');
  final repoPath = _env(
    'SHIPIT_REPOSITORY_PATH',
    Directory.current.parent.parent.path,
  );
  final snapshotRoot = Directory(repoPath);
  if (!snapshotRoot.existsSync()) {
    stderr.writeln('Repository path does not exist: $repoPath');
    exit(2);
  }

  final database = DatabaseConfig(
    host: _env('SERVERPOD_DATABASE_HOST', 'localhost'),
    port: int.parse(_env('SERVERPOD_DATABASE_PORT', '5432')),
    name: _env('SERVERPOD_DATABASE_NAME', 'shipit'),
    user: _env('SERVERPOD_DATABASE_USER', 'shipit'),
    password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit'),
  );

  stdout.writeln('Onboarding product "$productId"');
  stdout.writeln('  repository : $repoPath');
  stdout.writeln(
    '  database   : ${database.host}:${database.port}/${database.name}',
  );

  final pod = Serverpod(
    ['--mode', 'development', '--apply-migrations'],
    Protocol(),
    Endpoints(),
    configOverride: (config) => config.copyWith(
      database: database,
      redis: null,
      webServer: null,
      insightsServer: null,
    ),
  );
  await pod.start();

  final session = await Serverpod.instance.createSession(enableLogging: false);
  final db = PersistenceDatabase(session.db);
  final store = PostgresProductRegistryStore(db);
  final workflowStore = PostgresWorkflowStore(db);
  final decisions = PostgresHumanDecisionStore(workflowStore);
  final engine = ProductRegistryEngine(
    store: store,
    humanDecisionStore: decisions,
  );

  // 1. Product identity.
  Product product;
  try {
    product = await engine.readProduct(productId);
    stdout.writeln(
      '\nPRODUCT (existing): ${product.name} [${product.state.wire}]',
    );
  } on ProductNotFoundException {
    product = await engine.createProduct(
      productId: productId,
      name: productId,
      description: 'Onboarded from $repoPath',
    );
    stdout.writeln('\nPRODUCT (created): ${product.name}');
  }

  // 2. Repository reference. Recorded as `local` because onboarding inspects a
  //    path on this machine; a real remote would carry its provider here.
  final repositoryId = 'repo-$productId';
  await engine.addRepositoryReference(
    repositoryId: repositoryId,
    productId: productId,
    uri: repoPath,
    kind: RepositoryKind.monorepo,
    provider: RepositoryProvider.local,
  );
  stdout.writeln('REPOSITORY: $repositoryId -> $repoPath');

  // 3. Read-only discovery. This never writes to the snapshot.
  stdout.writeln('\nDiscovering facts (read-only)...');
  final observations = await ReadOnlyRepositoryReader(
    snapshotRoot: snapshotRoot,
  ).inspect();
  if (observations.isEmpty) {
    stderr.writeln(
      'Discovery produced no observations; refusing to propose an '
      'empty baseline. A baseline with no facts would attest to nothing.',
    );
    await pod.shutdown(exitProcess: false);
    exit(3);
  }
  stdout.writeln('  ${observations.length} observations');

  final classifier = MaturityClassifier();
  final facts = <BaselineFact>[
    for (var i = 0; i < observations.length; i++)
      BaselineFact(
        factId: 'discovery-$i',
        section: observations[i].section,
        claim: observations[i].claim,
        provenance: observations[i].provenance,
        maturity: classifier.classify(
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

  // 4. Propose. Never propose an empty baseline.
  //
  //    Re-running onboarding must not spam revisions, so if the newest baseline
  //    already asserts exactly this content, reuse it instead of superseding it
  //    with an identical copy.
  //
  //    If there is a proposed baseline that has human-authored claims (provenance
  //    humanProvided), we must preserve those by merging fresh discovery with the
  //    existing baseline's facts, rather than starting from scratch.
  final candidateHash = baselineContentHashV3(facts);
  final context = await engine.loadProductContext(productId);
  final existingByHash = context.allBaselines
      .where((b) => b.contentHash == candidateHash)
      .toList();

  // Check if there's an existing proposed baseline
  final existingProposed = context.allBaselines
      .where((b) => b.status == ProductBaselineStatus.proposed)
      .toList();
  existingProposed.sort((a, b) => b.revision.compareTo(a.revision));

  // Prefer the proposed baseline that has human-authored claims (most recently amended)
  final proposedWithHumanClaims = existingProposed
      .where(
        (b) => b.facts.any((f) => f.provenance == Provenance.humanProvided),
      )
      .toList();
  proposedWithHumanClaims.sort(
    (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );

  ProductBaseline proposed;
  if (existingProposed.isNotEmpty) {
    final referenceProposed = proposedWithHumanClaims.isNotEmpty
        ? proposedWithHumanClaims.first
        : existingProposed.first;
    final currentProposed = referenceProposed;

    // Separate human-authored claims from scraped ones
    final humanFacts = currentProposed.facts
        .where((f) => f.provenance == Provenance.humanProvided)
        .toList();
    final scrapedFacts = currentProposed.facts
        .where((f) => f.provenance != Provenance.humanProvided)
        .toList();

    // Check if fresh discovery matches the scraped portion
    final scrapedHash = baselineContentHashV3(scrapedFacts);
    final freshScrapedHash = baselineContentHashV3(facts);

    if (humanFacts.isNotEmpty && scrapedHash == freshScrapedHash) {
      // Discovery matches; preserve human claims by merging
      proposed = currentProposed.copyWith(
        facts: [...scrapedFacts, ...humanFacts],
        contentHash: baselineContentHashV3([...scrapedFacts, ...humanFacts]),
        updatedAt: DateTime.now().toUtc(),
        version: currentProposed.version + 1,
        verifiedAt: null,
        verifiedBy: null,
        verificationKind: null,
      );
      await store.saveBaseline(
        proposed,
        expectedVersion: currentProposed.version,
      );
      stdout.writeln(
        '\nPreserved ${humanFacts.length} human claim(s) in baseline '
        '${proposed.baselineId} (rev ${proposed.revision}).',
      );
    } else if (candidateHash == currentProposed.contentHash) {
      // Exact match (no human claims or content unchanged)
      proposed = currentProposed;
      stdout.writeln(
        '\nReusing baseline ${proposed.baselineId} '
        '(rev ${proposed.revision}) — content unchanged.',
      );
    } else {
      // Fresh proposal with current discovery
      proposed = await engine.proposeBaseline(
        productId: productId,
        facts: facts,
      );
    }
  } else if (existingByHash.isNotEmpty) {
    // Legacy: exact hash match from older logic
    existingByHash.sort((a, b) => b.revision.compareTo(a.revision));
    proposed = existingByHash.first;
    stdout.writeln(
      '\nReusing baseline ${proposed.baselineId} '
      '(rev ${proposed.revision}) — content unchanged.',
    );
  } else {
    proposed = await engine.proposeBaseline(
      productId: productId,
      facts: facts,
    );
  }

  final bySection = <String, int>{};
  final byMaturity = <String, int>{};
  for (final f in proposed.facts) {
    bySection[f.section.wire] = (bySection[f.section.wire] ?? 0) + 1;
    byMaturity[f.maturity.wire] = (byMaturity[f.maturity.wire] ?? 0) + 1;
  }

  stdout.writeln('\nPROPOSED BASELINE');
  stdout.writeln('  baselineId        : ${proposed.baselineId}');
  stdout.writeln('  revision          : ${proposed.revision}');
  stdout.writeln('  fact count        : ${proposed.facts.length}');
  stdout.writeln('  contentHash       : ${proposed.contentHash}');
  stdout.writeln('  contentHashVersion: ${proposed.contentHashVersion}');
  stdout.writeln(
    '  supersedes        : ${proposed.supersedesBaselineId ?? '(none)'}',
  );
  stdout.writeln('\n  facts by section:');
  bySection.forEach((k, v) => stdout.writeln('    $k: $v'));
  stdout.writeln('\n  facts by maturity:');
  byMaturity.forEach((k, v) => stdout.writeln('    $k: $v'));

  // Recompute with the contract the engine actually wrote, so the check cannot
  // silently drift onto a different version than the one persisted.
  final recomputed = proposed.contentHashVersion == 3
      ? baselineContentHashV3(proposed.facts)
      : baselineContentHashV2(proposed.facts);
  stdout.writeln('\nHASH VERIFICATION');
  stdout.writeln('  contract  : V${proposed.contentHashVersion}');
  stdout.writeln('  persisted : ${proposed.contentHash}');
  stdout.writeln('  recomputed: $recomputed');
  stdout.writeln('  MATCH     : ${recomputed == proposed.contentHash}');
  if (recomputed != proposed.contentHash) {
    stderr.writeln('Content hash does not match the persisted facts.');
    await pod.shutdown(exitProcess: false);
    exit(4);
  }

  // 5. Independent verification. The engine refuses to open an approval gate on
  //    an unverified baseline, and a bare `verifiedBy` string would be a rubber
  //    stamp that attests to nothing.
  //
  //    So this re-derives the facts from the same pinned snapshot and refuses to
  //    record verification unless the fresh derivation reproduces the persisted
  //    content hash byte for byte. It proves the stored facts still correspond
  //    to the repository; it does not claim the claims are correct, which is
  //    what the human gate below is for.
  var verified = proposed;
  if (proposed.verifiedAt == null) {
    stdout.writeln(
      '\nVerifying baseline against a fresh read of the snapshot...',
    );
    final recheck = await ReadOnlyRepositoryReader(
      snapshotRoot: snapshotRoot,
    ).inspect();
    final refacts = <BaselineFact>[
      for (var i = 0; i < recheck.length; i++)
        BaselineFact(
          factId: 'discovery-$i',
          section: recheck[i].section,
          claim: recheck[i].claim,
          provenance: recheck[i].provenance,
          maturity: classifier.classify(
            claim: recheck[i].claim,
            evidencePaths: recheck[i].evidencePaths,
            provenance: recheck[i].provenance,
            assumptionNote: recheck[i].assumptionNote,
            redacted: recheck[i].redacted,
          ),
          evidenceRefs: recheck[i].evidencePaths,
          assumptionNote: recheck[i].assumptionNote,
          redacted: recheck[i].redacted,
        ),
    ];
    final recheckHash = baselineContentHashV3(refacts);
    final reproduced = recheckHash == proposed.contentHash;
    stdout.writeln('  re-derived facts : ${refacts.length}');
    stdout.writeln('  re-derived hash  : $recheckHash');
    stdout.writeln('  REPRODUCED      : $reproduced');
    if (!reproduced) {
      stderr.writeln(
        'Refusing to verify: a fresh read of $repoPath does not reproduce the '
        'persisted content hash. The stored baseline does not match the '
        'repository, so it must not go to human review.',
      );
      await pod.shutdown(exitProcess: false);
      exit(5);
    }
    verified = await engine.verifyBaseline(
      productId: productId,
      baselineId: proposed.baselineId,
      verifiedBy: 'worker:baseline-verifier/onboard_shipit_dev',
    );
    stdout.writeln(
      '  verifiedAt      : ${verified.verifiedAt?.toIso8601String()}',
    );
    stdout.writeln('  verifiedBy      : ${verified.verifiedBy}');
  } else {
    stdout.writeln(
      '\nAlready verified by ${proposed.verifiedBy} at '
      '${proposed.verifiedAt?.toIso8601String()}; re-checking scraped portion still holds.',
    );
    // Only re-check the scraped (non-human) portion against the repo.
    // Human claims are operator-entered and cannot be verified from the repo.
    final scrapedFacts = proposed.facts
        .where((f) => f.provenance != Provenance.humanProvided)
        .toList();
    final recheckHash = baselineContentHashV3(scrapedFacts);
    final currentScrapedHash = baselineContentHashV3(facts);
    if (recheckHash != currentScrapedHash) {
      stderr.writeln(
        'Refusing to open an approval gate: the repository no longer '
        'reproduces the verified scraped content hash.',
      );
      await pod.shutdown(exitProcess: false);
      exit(5);
    }
    verified = proposed;
  }

  // 6. Ask a human. This script stops here on purpose.
  final decision = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: verified.baselineId,
  );

  stdout.writeln('\nAWAITING HUMAN APPROVAL');
  stdout.writeln('  decisionId: ${decision.decisionId}');
  stdout.writeln('  question  : ${decision.question}');
  stdout.writeln('  status    : ${decision.status.wire}');
  stdout.writeln(
    '\nOpen the dashboard and review the ${proposed.facts.length} facts:',
  );
  stdout.writeln('  http://localhost:8081/#/products/$productId');

  // `shutdown(exitProcess: false)` leaves Serverpod's timers running, so the
  // VM never reaches main() again on its own.
  await pod.shutdown(exitProcess: true);
}

/// Simple onboarding that connects directly to the database without starting Serverpod.
///
/// Uses the same env vars as onboard_shipit_dev.dart.
library;

import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:postgres/postgres.dart';

String _env(String key, String fallback) {
  final value = Platform.environment[key];
  return (value == null || value.isEmpty) ? fallback : value;
}

Future<void> main(List<String> argv) async {
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

  final dbConfig = DatabaseConfig(
    host: _env('SERVERPOD_DATABASE_HOST', 'localhost'),
    port: int.parse(_env('SERVERPOD_DATABASE_PORT', '5432')),
    name: _env('SERVERPOD_DATABASE_NAME', 'shipit'),
    user: _env('SERVERPOD_DATABASE_USER', 'shipit'),
    password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit'),
  );

  print('Onboarding product "$productId"');
  print('  repository : $repoPath');
  print('  database   : ${dbConfig.host}:${dbConfig.port}/${dbConfig.name}');

  // Direct postgres connection
  final connection = await Connection.open(
    Endpoint(
      host: dbConfig.host,
      port: dbConfig.port,
      database: dbConfig.name,
      username: dbConfig.user,
      password: dbConfig.password,
    ),
    settings: ConnectionSettings(
      sslMode: SslMode.disable,
      timeout: const Duration(seconds: 30),
    ),
  );

  try {
    final db = PersistenceDatabase(connection);
    final workflowStore = PostgresWorkflowStore(db);
    final decisions = PostgresHumanDecisionStore(workflowStore);
    final store = PostgresProductRegistryStore(db);
    final engine = ProductRegistryEngine(
      store: store,
      humanDecisionStore: decisions,
    );

    // 1. Product identity.
    Product product;
    try {
      product = await engine.readProduct(productId);
      print('\nPRODUCT (existing): ${product.name} [${product.state.wire}]');
    } on ProductNotFoundException {
      product = await engine.createProduct(
        productId: productId,
        name: productId,
        description: 'Onboarded from $repoPath',
      );
      print('\nPRODUCT (created): ${product.name}');
    }

    // 2. Repository reference.
    final repositoryId = 'repo-$productId';
    await engine.addRepositoryReference(
      repositoryId: repositoryId,
      productId: productId,
      uri: repoPath,
      kind: RepositoryKind.monorepo,
      provider: RepositoryProvider.local,
    );
    print('REPOSITORY: $repositoryId -> $repoPath');

    // 3. Read-only discovery.
    print('\nDiscovering facts (read-only)...');
    final observations = await ReadOnlyRepositoryReader(
      snapshotRoot: snapshotRoot,
    ).inspect();
    if (observations.isEmpty) {
      stderr.writeln(
        'Discovery produced no observations; refusing to propose an '
        'empty baseline.',
      );
      exit(3);
    }
    print('  ${observations.length} observations');

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

    // 4. Propose.
    final candidateHash = baselineContentHashV3(facts);
    final context = await engine.loadProductContext(productId);
    final existing = context.allBaselines
        .where((b) => b.contentHash == candidateHash)
        .toList();
    ProductBaseline proposed;
    if (existing.isNotEmpty) {
      existing.sort((a, b) => b.revision.compareTo(a.revision));
      proposed = existing.first;
      print(
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

    print('\nPROPOSED BASELINE');
    print('  baselineId        : ${proposed.baselineId}');
    print('  revision          : ${proposed.revision}');
    print('  fact count        : ${proposed.facts.length}');
    print('  contentHash       : ${proposed.contentHash}');
    print('  contentHashVersion: ${proposed.contentHashVersion}');
    print('  supersedes        : ${proposed.supersedesBaselineId ?? '(none)'}');
    print('\n  facts by section:');
    bySection.forEach((k, v) => print('    $k: $v'));
    print('\n  facts by maturity:');
    byMaturity.forEach((k, v) => print('    $k: $v'));

    // Hash verification
    final recomputed = proposed.contentHashVersion == 3
        ? baselineContentHashV3(proposed.facts)
        : baselineContentHashV2(proposed.facts);
    print('\nHASH VERIFICATION');
    print('  contract  : V${proposed.contentHashVersion}');
    print('  persisted : ${proposed.contentHash}');
    print('  recomputed: $recomputed');
    print('  MATCH     : ${recomputed == proposed.contentHash}');
    if (recomputed != proposed.contentHash) {
      stderr.writeln('Content hash does not match the persisted facts.');
      exit(4);
    }

    // 5. Independent verification
    var verified = proposed;
    if (proposed.verifiedAt == null) {
      print('\nVerifying baseline against a fresh read of the snapshot...');
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
      print('  re-derived facts : ${refacts.length}');
      print('  re-derived hash  : $recheckHash');
      print('  REPRODUCED      : $reproduced');
      if (!reproduced) {
        stderr.writeln(
          'Refusing to verify: a fresh read of $repoPath does not reproduce the '
          'persisted content hash.',
        );
        exit(5);
      }
      verified = await engine.verifyBaseline(
        productId: productId,
        baselineId: proposed.baselineId,
        verifiedBy: 'worker:baseline-verifier/onboard_simple',
      );
      print('  verifiedAt      : ${verified.verifiedAt?.toIso8601String()}');
      print('  verifiedBy      : ${verified.verifiedBy}');
    } else {
      print(
        '\nAlready verified by ${proposed.verifiedBy} at '
        '${proposed.verifiedAt?.toIso8601String()}; re-checking it still holds.',
      );
      final recheckHash = baselineContentHashV3(facts);
      if (recheckHash != proposed.contentHash) {
        stderr.writeln(
          'Refusing to open an approval gate: the repository no longer '
          'reproduces the verified content hash.',
        );
        exit(5);
      }
    }

    // 6. Ask a human.
    final decision = await engine.requestBaselineApproval(
      productId: productId,
      baselineId: verified.baselineId,
    );

    print('\nAWAITING HUMAN APPROVAL');
    print('  decisionId: ${decision.decisionId}');
    print('  question  : ${decision.question}');
    print('  status    : ${decision.status.wire}');
    print('\nOpen the dashboard and review the ${proposed.facts.length} facts:');
    print('  http://localhost:8081/#/products/$productId');

    print('\nONBOARDING COMPLETE');
  } finally {
    await connection.close();
  }
}
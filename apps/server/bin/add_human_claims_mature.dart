import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:postgres/postgres.dart';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';

String _env(String key, String fallback) {
  final value = Platform.environment[key];
  return (value == null || value.isEmpty) ? fallback : value;
}

Future<void> main(List<String> argv) async {
  final productId = argv.isNotEmpty
      ? argv.first
      : _env('SHIPIT_PRODUCT_ID', 'shipit-platform');
  final baselineId = _env('SHIPIT_BASELINE_ID', 'bl-shipit-platform-1');

  final connection = await Connection.open(
    Endpoint(
      host: _env('SERVERPOD_DATABASE_HOST', 'localhost'),
      port: int.parse(_env('SERVERPOD_DATABASE_PORT', '5432')),
      database: _env('SERVERPOD_DATABASE_NAME', 'control_plane_test'),
      username: _env('SERVERPOD_DATABASE_USER', 'postgres'),
      password: _env('SERVERPOD_DATABASE_PASSWORD', 'control_plane_test_pw'),
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
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

    // Add human claims with explicit maturity
    final claims = [
      (section: BaselineSectionKey.architecture, claim: 'ShipIt Platform is a self-hosted developer automation platform that lets one operator run many products by orchestrating agents, workers, and durable workflows.', maturity: BaselineMaturity.implemented),
      (section: BaselineSectionKey.governance, claim: 'All agent executions are durable, auditable, and require human gates for production promotion — no autonomous production changes.', maturity: BaselineMaturity.policy),
      (section: BaselineSectionKey.environments, claim: 'Local development uses Docker Compose with a seeded triage repository; production targets Kubernetes via OpenTofu.', maturity: BaselineMaturity.implemented),
      (section: BaselineSectionKey.techStack, claim: 'Core platform is Dart/Flutter; workers run on Linux/macOS with OpenCode ACP; scheduler uses PostgreSQL CAS job queue.', maturity: BaselineMaturity.implemented),
      (section: BaselineSectionKey.knownGaps, claim: 'Real OpenCode execution requires Google auth which is not yet configured; Anthropic fallback has insufficient credit.', maturity: BaselineMaturity.notImplemented),
      (section: BaselineSectionKey.deployment, claim: 'Artifacts are promoted via immutable artifact references bound to a verified baseline; no direct container push bypass.', maturity: BaselineMaturity.implemented),
    ];

    for (final c in claims) {
      await engine.addHumanBaselineClaim(
        productId: productId,
        baselineId: baselineId,
        section: c.section,
        claim: c.claim,
        author: 'operator',
        maturity: c.maturity,
        evidenceRefs: ['authored by operator on ${DateTime.now().toIso8601String().split('T').first}'],
      );
      print('Added claim: ${c.section.wire} (${c.maturity.wire})');
    }

    // Check new baseline
    final context = await engine.loadProductContext(productId);
    final proposed = context.allBaselines
        .where((b) => b.status == ProductBaselineStatus.proposed)
        .reduce((a, b) => a.revision > b.revision ? a : b);

    print('\nNew proposed baseline:');
    print('  baselineId: ${proposed.baselineId}');
    print('  revision: ${proposed.revision}');
    print('  fact count: ${proposed.facts.length}');
    
    final byMaturity = <String, int>{};
    for (final f in proposed.facts) {
      byMaturity[f.maturity.wire] = (byMaturity[f.maturity.wire] ?? 0) + 1;
    }
    print('\n  facts by maturity:');
    byMaturity.forEach((k, v) => print('    $k: $v'));
    
    // Request approval for the new revision
    final decision = await engine.requestBaselineApproval(
      productId: productId,
      baselineId: proposed.baselineId,
    );
    print('\nAWAITING HUMAN APPROVAL');
    print('  decisionId: ${decision.decisionId}');
    print('  question  : ${decision.question}');
  } finally {
    await connection.close();
  }
}
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

Future<void> main(List<String> argv) async {
  final productId = argv.isNotEmpty
      ? argv.first
      : _env('SHIPIT_PRODUCT_ID', 'shipit-platform');
  final baselineId = _env('SHIPIT_BASELINE_ID', 'bl-shipit-platform-1');

  final database = DatabaseConfig(
    host: _env('SERVERPOD_DATABASE_HOST', 'localhost'),
    port: int.parse(_env('SERVERPOD_DATABASE_PORT', '5432')),
    name: _env('SERVERPOD_DATABASE_NAME', 'shipit'),
    user: _env('SERVERPOD_DATABASE_USER', 'shipit'),
    password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit'),
  );

  stdout.writeln('Adding human claims to $productId / $baselineId');
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

  try {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    final db = PersistenceDatabase(session.db);
    final workflowStore = PostgresWorkflowStore(db);
    final decisions = PostgresHumanDecisionStore(workflowStore);
    final store = PostgresProductRegistryStore(db);
    final engine = ProductRegistryEngine(
      store: store,
      humanDecisionStore: decisions,
    );

    // Add human domain claims
    final claims = [
      (
        section: BaselineSectionKey.architecture,
        claim:
            'ShipIt Platform is a self-hosted developer automation platform that lets one operator run many products by orchestrating agents, workers, and durable workflows.',
      ),
      (
        section: BaselineSectionKey.governance,
        claim:
            'All agent executions are durable, auditable, and require human gates for production promotion — no autonomous production changes.',
      ),
      (
        section: BaselineSectionKey.environments,
        claim:
            'Local development uses Docker Compose with a seeded triage repository; production targets Kubernetes via OpenTofu.',
      ),
      (
        section: BaselineSectionKey.techStack,
        claim:
            'Core platform is Dart/Flutter; workers run on Linux/macOS with OpenCode ACP; scheduler uses PostgreSQL CAS job queue.',
      ),
      (
        section: BaselineSectionKey.knownGaps,
        claim:
            'Real OpenCode execution requires Google auth which is not yet configured; Anthropic fallback has insufficient credit.',
      ),
      (
        section: BaselineSectionKey.deployment,
        claim:
            'Artifacts are promoted via immutable artifact references bound to a verified baseline; no direct container push bypass.',
      ),
    ];

    for (final c in claims) {
      await engine.addHumanBaselineClaim(
        productId: productId,
        baselineId: baselineId,
        section: c.section,
        claim: c.claim,
        author: 'operator',
        evidenceRefs: [
          'authored by operator on ${DateTime.now().toIso8601String().split('T').first}',
        ],
      );
      stdout.writeln('Added claim: ${c.section.wire}');
    }

    // Check new baseline
    final context = await engine.loadProductContext(productId);
    final proposed = context.allBaselines
        .where((b) => b.status == ProductBaselineStatus.proposed)
        .reduce((a, b) => a.revision > b.revision ? a : b);

    stdout.writeln('\nNew proposed baseline:');
    stdout.writeln('  baselineId: ${proposed.baselineId}');
    stdout.writeln('  revision: ${proposed.revision}');
    stdout.writeln('  fact count: ${proposed.facts.length}');
    stdout.writeln('  contentHash: ${proposed.contentHash}');

    // Request approval for the new revision
    final decision = await engine.requestBaselineApproval(
      productId: productId,
      baselineId: proposed.baselineId,
    );
    stdout.writeln('\nAWAITING HUMAN APPROVAL');
    stdout.writeln('  decisionId: ${decision.decisionId}');
    stdout.writeln('  question  : ${decision.question}');
  } finally {
    await pod.shutdown(exitProcess: true);
  }
}

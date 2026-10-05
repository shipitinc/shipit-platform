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

Future<PersistenceDatabase> _newTestDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

void main() async {
  // Initialize Serverpod for test database
  final pod = Serverpod(
    ['--mode', 'test', '--apply-migrations'],
    Protocol(),
    Endpoints(),
    configOverride: (config) => config.copyWith(
      database: DatabaseConfig(
        host: 'localhost',
        port: 9090,
        name: 'control_plane_test',
        user: 'postgres',
        password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit'),
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

  // Load existing product
  final product = await engine.readProduct(productId);
  stdout.writeln('PRODUCT IDENTITY:');
  stdout.writeln('  display name: ${product.name}');
  stdout.writeln('  productId: ${product.productId}');
  stdout.writeln('  ProductState: ${product.state.name}');

  // Load repositories
  final repos = await engine.readRepositories(productId);
  stdout.writeln('\nREPOSITORIES:');
  for (final repo in repos) {
    stdout.writeln('  repositoryId: ${repo.repositoryId}');
    stdout.writeln('  provider/kind: ${repo.provider.name}/${repo.kind.name}');
    stdout.writeln('  role: ${repo.kind.name}');
    stdout.writeln('  canonical identity: ${repo.uri}');
    stdout.writeln('  observed revision: (to be determined from git)');
  }

  // Get the proposed baseline
  final baselines = await engine.readBaselines(productId);
  final proposed = baselines.firstWhere(
    (b) => b.status == ProductBaselineStatus.proposed,
  );

  stdout.writeln('\nBASELINE IDENTITY:');
  stdout.writeln('  baselineId: ${proposed.baselineId}');
  stdout.writeln('  revision: ${proposed.revision}');
  stdout.writeln('  contentHash: ${proposed.contentHash}');
  stdout.writeln('  status: ${proposed.status.wire}');

  // Create the governing HumanDecision
  stdout.writeln('\nCreating governing HumanDecision...');
  final decision = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: proposed.baselineId,
  );

  stdout.writeln('  decisionId: ${decision.decisionId}');
  stdout.writeln('  workItemId: ${decision.workItemId}');
  stdout.writeln('  decisionType: ${decision.decisionType.wire}');
  stdout.writeln('  status: ${decision.status.wire}');
  stdout.writeln('  question: ${decision.question}');
  stdout.writeln('  metadata: ${decision.metadata}');

  // Verify decision stored
  final stored = await decisions.readHumanDecision(decision.decisionId);
  stdout.writeln('\nVerified stored decision: ${stored?.decisionId}');

  // Present baseline package summary
  stdout.writeln('\n=== GATE SUMMARY ===');
  stdout.writeln('productId: $productId');
  stdout.writeln('baselineId: ${proposed.baselineId}');
  stdout.writeln('revision: ${proposed.revision}');
  stdout.writeln('contentHash: ${proposed.contentHash}');
  stdout.writeln('decisionId: ${decision.decisionId}');
  stdout.writeln('CURRENT GATE: PRODUCT_BASELINE_APPROVAL_REQUIRED');
}

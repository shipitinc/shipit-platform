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
        password: 'control_plane_test_pw',
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
  print('PRODUCT IDENTITY:');
  print('  display name: ${product.name}');
  print('  productId: ${product.productId}');
  print('  ProductState: ${product.state.name}');

  // Load repositories
  final repos = await engine.readRepositories(productId);
  print('\nREPOSITORIES:');
  for (final repo in repos) {
    print('  repositoryId: ${repo.repositoryId}');
    print('  provider/kind: ${repo.provider.name}/${repo.kind.name}');
    print('  role: ${repo.kind.name}');
    print('  canonical identity: ${repo.uri}');
    print('  observed revision: (to be determined from git)');
  }

  // Get the proposed baseline
  final baselines = await engine.readBaselines(productId);
  final proposed = baselines.firstWhere((b) => b.status == ProductBaselineStatus.proposed);
  
  print('\nBASELINE IDENTITY:');
  print('  baselineId: ${proposed.baselineId}');
  print('  revision: ${proposed.revision}');
  print('  contentHash: ${proposed.contentHash}');
  print('  status: ${proposed.status.wire}');

  // Create the governing HumanDecision
  print('\nCreating governing HumanDecision...');
  final decision = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: proposed.baselineId,
  );
  
  print('  decisionId: ${decision.decisionId}');
  print('  workItemId: ${decision.workItemId}');
  print('  decisionType: ${decision.decisionType.wire}');
  print('  status: ${decision.status.wire}');
  print('  question: ${decision.question}');
  print('  metadata: ${decision.metadata}');

  // Verify decision stored
  final stored = await decisions.readHumanDecision(decision.decisionId);
  print('\nVerified stored decision: ${stored?.decisionId}');

  // Present baseline package summary
  print('\n=== GATE SUMMARY ===');
  print('productId: $productId');
  print('baselineId: ${proposed.baselineId}');
  print('revision: ${proposed.revision}');
  print('contentHash: ${proposed.contentHash}');
  print('decisionId: ${decision.decisionId}');
  print('CURRENT GATE: PRODUCT_BASELINE_APPROVAL_REQUIRED');
}
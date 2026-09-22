import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_execution_store.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_registration_store.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:serverpod/serverpod.dart';
import 'package:store_contract_tests/store_contract_tests.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

Future<void> _truncateDomainTables() async {
  final db = await _newDb();
  await db.queryNoTransaction('''
    TRUNCATE TABLE
      "design_revision_event",
      "design_finding",
      "design_review_result",
      "design_revision",
      "work_item",
      "human_decision",
      "work_item_transition",
      "job",
      "job_claim",
      "scheduler_event",
      "worker_execution",
      "worker_result",
      "worker_event",
      "worker_registration",
      "agent_execution_request",
      "agent_execution",
      "agent_event",
      "agent_result",
      "platform_verification",
      "product",
      "repository_reference",
      "product_baseline",
      "clarification_request",
      "onboarding_record"
    RESTART IDENTITY CASCADE
  ''');
}

void main() {
  withServerpod(
    'Postgres stores satisfy the store contracts',
    (sessionBuilder, endpoints) {
      setUp(_truncateDomainTables);

      runWorkflowStoreSuite(
        groupName: 'WorkflowStore (Postgres)',
        createStore: () async => PostgresWorkflowStore(await _newDb()),
      );

      runJobStoreSuite(
        groupName: 'JobStore (Postgres)',
        createStore: () async => PostgresJobStore(await _newDb()),
      );

      runWorkerStoreSuite(
        groupName: 'WorkerStore (Postgres)',
        createStore: () async => PostgresWorkerStore(await _newDb()),
      );

      runExecutionStoreSuite(
        groupName: 'ExecutionStore (Postgres)',
        createStore: () async => PostgresExecutionStore(await _newDb()),
      );

      runWorkerRegistrationSuite(
        groupName: 'WorkerRegistrationStore (Postgres)',
        createStore: () async =>
            PostgresWorkerRegistrationStore(await _newDb()),
      );

      runProductRegistryStoreSuite(
        groupName: 'ProductRegistryStore (Postgres)',
        createStore: () async => PostgresProductRegistryStore(await _newDb()),
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

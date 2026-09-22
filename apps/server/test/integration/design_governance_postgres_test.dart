import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_design_governance_store.dart';
import 'package:serverpod/serverpod.dart';
import 'package:store_contract_tests/store_contract_tests.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  return PersistenceDatabase(session.db);
}

Future<void> _truncateDesignGovernanceTables() async {
  final db = await _newDb();
  await db.queryNoTransaction('''
    TRUNCATE TABLE
      "design_revision_event",
      "design_finding",
      "design_review_result",
      "design_revision"
    RESTART IDENTITY CASCADE
  ''');
}

void main() {
  withServerpod(
    'Postgres design governance stores satisfy the store contracts',
    (sessionBuilder, endpoints) {
      setUp(_truncateDesignGovernanceTables);

      runDesignGovernanceStoreSuite(
        groupName: 'DesignGovernanceStore (Postgres)',
        createStore: () async => PostgresDesignGovernanceStore(await _newDb()),
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
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

Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  // Removes only this suite's rows, in an order that satisfies foreign keys.
  //
  // Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
  // with files that run concurrently, and truncating these tables out from
  // under them breaks their assertions. Every marker is a fixture id from
  // `store_contract_tests`' design-governance suite, and this file is the only
  // one that writes design-governance rows to PostgreSQL. Runs in `setUp` as
  // well as `tearDown`, because a previous run that aborted mid-test leaves
  // rows behind and re-creating the fixture would then violate a unique
  // constraint.
  const revision = 'DES-R00%';
  const statements = <String>[
    'DELETE FROM "design_finding"        WHERE "findingId" LIKE \'FD-00%\'',
    'DELETE FROM "design_review_result"  WHERE "reviewExecutionId" LIKE '
        '\'rev-exec-%\'',
    'DELETE FROM "design_revision_event" WHERE "designRevisionId" LIKE '
        '\'$revision\'',
    'DELETE FROM "design_revision"       WHERE "revisionId" LIKE \'$revision\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

void main() {
  withServerpod(
    'Postgres design governance stores satisfy the store contracts',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(_purgeSuiteRows);

      runDesignGovernanceStoreSuite(
        groupName: 'DesignGovernanceStore (Postgres)',
        createStore: () async => PostgresDesignGovernanceStore(await _newDb()),
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_design_contract_store.dart';
import 'package:serverpod/serverpod.dart';
import 'package:store_contract_tests/store_contract_tests.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Every session opened here is closed in [tearDown].
///
/// `runDesignContractStoreSuite` opens a FRESH store — and therefore a fresh
/// session — per test, which is twelve of them. The test host's pool is finite
/// and shared with every other file in `test/integration`, so a leaked session
/// starves a concurrent sibling rather than failing here. `design_governance_postgres_test.dart`
/// does not close its sessions; this file does, and the reason is the store
/// suite's per-test construction rather than anything about the design contract.
final List<Session> _openSessions = <Session>[];

Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  _openSessions.add(session);
  return PersistenceDatabase(session.db);
}

Future<void> _closeSessions() async {
  for (final session in List.of(_openSessions)) {
    await session.close();
  }
  _openSessions.clear();
}

/// Removes only this suite's rows.
///
/// Targeted DELETE, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `design_contract` out from
/// under them breaks their assertions.
///
/// The predicate is `design-contract-wi-000%`, which covers every fixture id
/// `runDesignContractStoreSuite` writes — `design-contract-wi-0001`,
/// `-wi-0001a`, `-wi-0001b` and `-wi-0002` — and matches nothing else the
/// platform writes, because production contract ids come from
/// `designContractIdForWorkItem`, which prefixes them with a full work item id
/// such as `design-contract-defect-DEF-1791684804452198`.
///
/// Runs in `setUp` as well as `tearDown`: a previous run that aborted
/// mid-test leaves rows behind, and re-creating a fixture would then collide
/// with `design_contract_contract_id_unique`.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  await db.query(
    'DELETE FROM "design_contract" WHERE "contractId" LIKE '
    "'design-contract-wi-000%'",
  );
}

void main() {
  withServerpod(
    'Postgres design contract store satisfies the store contract',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(_purgeSuiteRows);
      tearDown(_closeSessions);

      runDesignContractStoreSuite(
        groupName: 'DesignContractStore (Postgres)',
        createStore: () async => PostgresDesignContractStore(await _newDb()),
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

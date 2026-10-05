import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_execution_store.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_registration_store.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:store_contract_tests/store_contract_tests.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Every session opened during a test is registered so it can be closed in
/// [tearDown]; the test host's connection pool is finite and leaked sessions
/// starve concurrent sibling test groups.
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

/// The fixture id space `store_contract_tests` writes in this file: work items
/// `wi-0001` / `wi-0002`, jobs `jb-*` on `wi-0001`, workers `wk-1` / `wk-2`,
/// products `shipit` / `txn`. These constants live in the contract package and
/// are shared by every suite here.
const Set<String> _ownedWorkItems = {'wi-0001', 'wi-0002'};
const Set<String> _ownedWorkerIds = {'wk-1', 'wk-2'};

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `work_item`/`job`/`product`
/// out from under them breaks their assertions. Every statement is scoped to
/// the fixture ids in [_ownedWorkItems], [_ownedWorkerIds], `jb-*`, `shipit`
/// and `txn`, so no other file's row can match. Runs in `setUp` as well as
/// `tearDown`, because a previous run that aborted mid-test leaves rows behind
/// and re-creating the fixture would then violate a unique constraint.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  // One statement per call: the driver sends a parameterised command as a
  // prepared statement, which accepts exactly one command at a time.
  // NO `design_*` statements: none of the suites run in this file writes a
  // `design_revision`/`design_finding`/`design_review_result` row. Those tables
  // are written only through `PostgresDesignGovernanceStore`, which
  // `design_governance_postgres_test.dart` drives with `DES-R00*` revisions
  // hanging off `wi-0001`/`wi-0002` — the same work-item ids this file's
  // workflow suite owns. Sweeping them from here would delete ANOTHER file's
  // rows mid-test, which is the interference this purge exists to end.
  const statements = <String>[
    // Queue: claims and events before `job`.
    'DELETE FROM "job_claim" WHERE "jobId" IN '
        '(SELECT "jobId" FROM "job" WHERE "workItemId" = \'wi-0001\')',
    'DELETE FROM "scheduler_event" WHERE "workItemId" = \'wi-0001\'',
    'DELETE FROM "job" WHERE "workItemId" = \'wi-0001\'',
    // Workflow.
    'DELETE FROM "human_decision" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "work_item_transition" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "work_item" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    // Worker executions before their registration row.
    'DELETE FROM "worker_result" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "worker_event" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "worker_execution" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "worker_registration" WHERE "workerId" IN '
        '(\'wk-1\', \'wk-2\')',
    // Agent executions.
    'DELETE FROM "platform_verification" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "agent_result" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "agent_event" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "agent_execution" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    'DELETE FROM "agent_execution_request" WHERE "workItemId" IN '
        '(\'wi-0001\', \'wi-0002\')',
    // Products.
    'DELETE FROM "baseline_fact" WHERE "baselineId" IN '
        '(SELECT "baselineId" FROM "product_baseline" WHERE "productId" IN '
        '(\'shipit\', \'txn\'))',
    'DELETE FROM "standing_policy" WHERE "productId" IN '
        '(\'shipit\', \'txn\')',
    'DELETE FROM "clarification_request" WHERE "productId" IN '
        '(\'shipit\', \'txn\')',
    'DELETE FROM "onboarding_record" WHERE "productId" IN '
        '(\'shipit\', \'txn\')',
    'DELETE FROM "product_registry_audit" WHERE "productId" IN '
        '(\'shipit\', \'txn\')',
    'DELETE FROM "product_credential" WHERE "productId" IN '
        '(\'shipit\', \'txn\')',
    'DELETE FROM "product_baseline" WHERE "productId" IN '
        '(\'shipit\', \'txn\')',
    'DELETE FROM "repository_reference" WHERE "productId" IN '
        '(\'shipit\', \'txn\')',
    'DELETE FROM "product" WHERE "productId" IN (\'shipit\', \'txn\')',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

/// Narrows a [JobStore]'s global listings to the contract suite's fixtures.
///
/// TEST ISOLATION, not production: `listJobs()` and `listClaims()` are global
/// reads with exact-count assertions, and `test/integration` shares one
/// database with files that run concurrently (a sibling may hold queued jobs
/// or claims while these tests assert `hasLength(2)` / `length, 1`). Only the
/// two listings are narrowed — writes, CAS, per-work-item lookups and events
/// still go to the real [PostgresJobStore].
class _ScopedJobStore implements JobStore {
  _ScopedJobStore(this._delegate, this._owned);

  final JobStore _delegate;
  final Set<String> _owned;

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) =>
      _delegate.saveJob(job, expectedVersion: expectedVersion);

  @override
  Future<Job?> readJob(String jobId) => _delegate.readJob(jobId);

  @override
  Future<List<Job>> listJobs() async => (await _delegate.listJobs())
      .where((job) => _owned.contains(job.workItemId))
      .toList();

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) =>
      _delegate.listJobsForWorkItem(workItemId);

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) =>
      _delegate.findLatestByDedupeKey(dedupeKey);

  @override
  Future<void> saveClaim(JobClaim claim) => _delegate.saveClaim(claim);

  @override
  Future<JobClaim?> readClaimForJob(String jobId) =>
      _delegate.readClaimForJob(jobId);

  @override
  Future<List<JobClaim>> listClaims() async {
    final ownedJobIds = (await _delegate.listJobs())
        .where((job) => _owned.contains(job.workItemId))
        .map((job) => job.jobId)
        .toSet();
    return (await _delegate.listClaims())
        .where((claim) => ownedJobIds.contains(claim.jobId))
        .toList();
  }

  @override
  Future<void> deleteClaim(String jobId) => _delegate.deleteClaim(jobId);

  @override
  Future<void> appendEvent(SchedulerEventRecord event) =>
      _delegate.appendEvent(event);

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) =>
      _delegate.readEvents(jobId);

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) =>
      _delegate.inTransaction<T>((_) => body(this));
}

/// Narrows a [WorkerRegistrationStore]'s worker listing to the contract
/// suite's fixtures.
///
/// TEST ISOLATION, not production: `listWorkers()` is a global read with an
/// `isEmpty` assertion, and `test/integration` shares one database with files
/// that run concurrently. Only the listing is narrowed — register, read,
/// unregister and transactions still go to the real
/// [PostgresWorkerRegistrationStore].
class _ScopedWorkerRegistrationStore implements WorkerRegistrationStore {
  _ScopedWorkerRegistrationStore(this._delegate, this._owned);

  final WorkerRegistrationStore _delegate;
  final Set<String> _owned;

  @override
  Future<void> registerWorker(WorkerRegistration registration) =>
      _delegate.registerWorker(registration);

  @override
  Future<WorkerRegistration?> readWorker(String workerId) =>
      _delegate.readWorker(workerId);

  @override
  Future<List<WorkerRegistration>> listWorkers() async =>
      (await _delegate.listWorkers())
          .where((worker) => _owned.contains(worker.workerId))
          .toList();

  @override
  Future<void> unregisterWorker(String workerId) =>
      _delegate.unregisterWorker(workerId);

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) => _delegate.inTransaction<T>((_) => body(this));
}

void main() {
  withServerpod(
    'Postgres stores satisfy the store contracts',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(() async {
        await _purgeSuiteRows();
        await _closeSessions();
      });

      runWorkflowStoreSuite(
        groupName: 'WorkflowStore (Postgres)',
        createStore: () async => PostgresWorkflowStore(await _newDb()),
      );

      runJobStoreSuite(
        groupName: 'JobStore (Postgres)',
        createStore: () async =>
            _ScopedJobStore(PostgresJobStore(await _newDb()), _ownedWorkItems),
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
        createStore: () async => _ScopedWorkerRegistrationStore(
          PostgresWorkerRegistrationStore(await _newDb()),
          _ownedWorkerIds,
        ),
      );

      runProductRegistryStoreSuite(
        groupName: 'ProductRegistryStore (Postgres)',
        createStore: () async => PostgresProductRegistryStore(await _newDb()),
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

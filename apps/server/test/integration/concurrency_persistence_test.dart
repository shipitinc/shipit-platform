import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:store_contract_tests/store_contract_tests.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

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

/// The work-item id space this file owns. Fixture ids are namespaced `conc-*`
/// so no other file's row can match the purge below, and so the fixed
/// `wi-0001` used by `store_contract_tests` stays exclusive to that suite.
const Set<String> _ownedWorkItems = {
  'conc-wi-0001',
  'conc-dedupe',
  'conc-claim',
  'conc-resolve',
};

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `work_item`/`job` out from
/// under them breaks their assertions. Every marker is namespaced `conc-*` to
/// this file. Runs in `setUp` as well as `tearDown`, because a previous run
/// that aborted mid-test leaves rows behind and re-creating the fixture would
/// then violate a unique constraint.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  const workItem = 'conc-%';
  // One statement per call: the driver sends a parameterised command as a
  // prepared statement, which accepts exactly one command at a time.
  const statements = <String>[
    'DELETE FROM "job_claim" WHERE "jobId" IN '
        '(SELECT "jobId" FROM "job" WHERE "workItemId" LIKE \'$workItem\')',
    'DELETE FROM "scheduler_event"      WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "job"                  WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "human_decision"       WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "work_item_transition" WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "work_item"            WHERE "workItemId" LIKE \'$workItem\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

/// Narrows a [JobStore]'s work-item listing to ids this file owns.
///
/// TEST ISOLATION, not production: one of these tests asserts an exact job
/// count on `listJobs()`, a global read, and `test/integration` shares one
/// database with files that run concurrently. Only the listing is narrowed —
/// writes, claims, events and CAS all still go to the real
/// [PostgresJobStore].
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
  Future<List<JobClaim>> listClaims() => _delegate.listClaims();

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

/// Runs [futures] concurrently and collapses every outcome into a value so one
/// failing sibling cannot short-circuit the others.
Future<List<Object?>> _settle(List<Future<Object?>> futures) => Future.wait(
  futures.map(
    (f) => f.then<Object?>((ok) => ok, onError: (Object e, _) => e),
  ),
);

void main() {
  withServerpod(
    'Postgres persistence races settle to exactly one winner',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(() async {
        await _purgeSuiteRows();
        await _closeSessions();
      });

      test(
        'stale work item CAS is rejected under a concurrent write race',
        () async {
          // Two independent processes, each with its own store/session, race the
          // compare-and-swap; the database guard decides the single winner.
          final storeA = PostgresWorkflowStore(await _newDb());
          final storeB = PostgresWorkflowStore(await _newDb());
          final seeder = PostgresWorkflowStore(await _newDb());

          final item = buildWorkItem(workItemId: 'conc-wi-0001');
          await seeder.saveWorkItem(item);

          final snapshot = (await seeder.readWorkItem(item.workItemId))
              .copyWith(
                state: WorkItemState.planning,
                version: 2,
              );
          final outcomes = await _settle([
            storeA
                .saveWorkItem(snapshot, expectedVersion: 1)
                .then<Object?>((_) => true),
            storeB
                .saveWorkItem(snapshot, expectedVersion: 1)
                .then<Object?>((_) => true),
          ]);

          final winners = outcomes.whereType<bool>().length;
          expect(winners, 1, reason: 'exactly one writer must win the CAS');
          final lost = outcomes.whereType<ConcurrentModificationException>();
          expect(lost.length, 1);
          expect(lost.single.actualVersion, 2);

          final finalItem = await seeder.readWorkItem(item.workItemId);
          expect(finalItem.version, 2);
          expect(finalItem.state, WorkItemState.planning);
        },
      );

      test(
        'concurrent dedupe enqueues create exactly one job and one event',
        () async {
          final stores = [
            for (var i = 0; i < 6; i++)
              _ScopedJobStore(
                PostgresJobStore(await _newDb()),
                _ownedWorkItems,
              ),
          ];
          const workItemId = 'conc-dedupe';

          final outcomes = await _settle([
            for (var i = 0; i < stores.length; i++)
              JobQueue(store: stores[i])
                  .enqueueIfAbsent(
                    workItemId: workItemId,
                    definition: defaultImplementFeatureDefinition,
                    dedupeKey: 'conc-dedupe-race',
                    instruction: 'race',
                    now: DateTime.utc(2026, 3, 1, 9),
                  )
                  .then<Object?>((r) => r),
          ]);
          final results = outcomes.whereType<JobEnqueueResult>();
          expect(
            results.length,
            6,
            reason: 'every racer must resolve to a job',
          );
          expect(results.where((r) => r.created).length, 1);

          final jobs = await stores.first.listJobs();
          expect(jobs.length, 1, reason: 'only one job may survive the race');
          expect(jobs.single.state, JobState.queued);

          final events = await stores.first.readEvents(jobs.single.jobId);
          expect(events.length, 1);
          expect(events.single.type, SchedulerEventType.jobQueued);
        },
      );

      test('concurrent claims on one job produce exactly one owner', () async {
        final seeder = _ScopedJobStore(
          PostgresJobStore(await _newDb()),
          _ownedWorkItems,
        );
        final job = (await JobQueue(store: seeder).enqueueIfAbsent(
          workItemId: 'conc-claim',
          definition: defaultImplementFeatureDefinition,
          dedupeKey: 'conc-claim-race',
          instruction: 'race',
          now: DateTime.utc(2026, 3, 1, 9),
        )).job;
        final at = DateTime.utc(2026, 3, 1, 9, 1);

        final stores = [
          for (var i = 0; i < 6; i++)
            _ScopedJobStore(PostgresJobStore(await _newDb()), _ownedWorkItems),
        ];
        final claims = await _settle([
          for (var i = 0; i < stores.length; i++)
            JobQueue(store: stores[i])
                .claim(
                  job: job,
                  ownerId: 'owner-$i',
                  now: at,
                  lease: const Duration(minutes: 5),
                )
                .then<Object?>((c) => c),
        ]);
        final won = claims.whereType<JobClaim>();
        expect(won.length, 1, reason: 'exactly one claim may win the CAS');

        final stored = await seeder.readClaimForJob(job.jobId);
        expect(stored, isNotNull);
        expect(stored!.claimId, won.single.claimId);

        final finalJob = (await seeder.readJob(job.jobId))!;
        expect(finalJob.state, JobState.claimed);
        expect(finalJob.version, 2);
      });

      test(
        'concurrent human decision resolution drives exactly one unlock',
        () async {
          final seeder = PostgresWorkflowStore(await _newDb());
          final seeded = buildWorkItem(
            workItemId: 'conc-resolve',
            state: WorkItemState.designInReview,
          );
          await seeder.saveWorkItem(seeded);

          final decision = await DurableWorkflowEngine(store: seeder)
              .requestHumanDecision(
                workItemId: seeded.workItemId,
                decisionType: HumanDecisionType.designApproval,
                decisionId: 'conc-dec-resolve',
                blocking: true,
                question: 'Approve the design?',
              );
          expect(decision.status, HumanDecisionStatus.pending);

          final at = DateTime.utc(2026, 3, 1, 10);
          final signed = DecisionSignature(
            algorithm: 'ed25519',
            publicKey: 'pk-reviewer',
            signature: 'sig-reviewer',
            signedAt: at,
          );
          final stores = [
            for (var i = 0; i < 6; i++) PostgresWorkflowStore(await _newDb()),
          ];
          final outcomes = await _settle([
            for (var i = 0; i < stores.length; i++)
              DurableWorkflowEngine(store: stores[i])
                  .resolveHumanDecision(
                    decisionId: decision.decisionId,
                    choice: HumanDecisionChoice.approve,
                    decider: 'reviewer-$i',
                    rationale: 'reviewer-$i approves',
                    signature: signed,
                  )
                  .then<Object?>((item) => item),
          ]);

          final unlocked = outcomes.whereType<WorkItem>().length;
          expect(unlocked, 1, reason: 'exactly one resolution may unlock');
          final rejected = outcomes
              .whereType<ConcurrentModificationException>();
          expect(rejected.length, 5);
          expect(rejected.every((e) => e.actualVersion > 1), isTrue);

          final finalItem = await seeder.readWorkItem(seeded.workItemId);
          expect(finalItem.state, WorkItemState.designApproved);
          expect(finalItem.blockingHumanDecisionId, isNull);
          expect(finalItem.version, 3, reason: 'gate entry + one unlock');

          final history = await DurableWorkflowEngine(
            store: seeder,
          ).transitionHistory(seeded.workItemId);
          final unlocks = history
              .where((r) => r.toState == WorkItemState.designApproved)
              .where((r) => r.outcome == TransitionOutcome.accepted);
          expect(
            unlocks.length,
            1,
            reason: 'the losing resolutions must have rolled back',
          );
        },
      );
    },
  );
}

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

Future<void> _truncateDomainTables() async {
  final db = await _newDb();
  await db.queryNoTransaction('''
    TRUNCATE TABLE
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
      "platform_verification"
    RESTART IDENTITY CASCADE
  ''');
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
      setUp(_truncateDomainTables);
      tearDown(_closeSessions);

      test(
        'stale work item CAS is rejected under a concurrent write race',
        () async {
          // Two independent processes, each with its own store/session, race the
          // compare-and-swap; the database guard decides the single winner.
          final storeA = PostgresWorkflowStore(await _newDb());
          final storeB = PostgresWorkflowStore(await _newDb());
          final seeder = PostgresWorkflowStore(await _newDb());

          final item = buildWorkItem();
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
            for (var i = 0; i < 6; i++) PostgresJobStore(await _newDb()),
          ];
          const workItemId = 'wi-dedupe';

          final outcomes = await _settle([
            for (var i = 0; i < stores.length; i++)
              JobQueue(store: stores[i])
                  .enqueueIfAbsent(
                    workItemId: workItemId,
                    definition: defaultImplementFeatureDefinition,
                    dedupeKey: 'dedupe-race',
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
        final seeder = PostgresJobStore(await _newDb());
        final job = (await JobQueue(store: seeder).enqueueIfAbsent(
          workItemId: 'wi-claim',
          definition: defaultImplementFeatureDefinition,
          dedupeKey: 'claim-race',
          instruction: 'race',
          now: DateTime.utc(2026, 3, 1, 9),
        )).job;
        final at = DateTime.utc(2026, 3, 1, 9, 1);

        final stores = [
          for (var i = 0; i < 6; i++) PostgresJobStore(await _newDb()),
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
            workItemId: 'wi-resolve',
            state: WorkItemState.designInReview,
          );
          await seeder.saveWorkItem(seeded);

          final decision = await DurableWorkflowEngine(store: seeder)
              .requestHumanDecision(
                workItemId: seeded.workItemId,
                decisionType: HumanDecisionType.designApproval,
                decisionId: 'dec-resolve',
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

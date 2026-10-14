import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:control_plane_server/server.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

import '../support/design_gate_agents.dart';
import '../support/git_repo_fixture.dart';
import 'test_tools/serverpod_test_tools.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// The composition root handed the execution coordinator a
/// `FileJsonExecutionStore` in container temp while every reader of an agent
/// execution read PostgreSQL. Measured on the QA database after 35 worker
/// executions:
///
///     agent_execution = 0,  worker_execution = 35,  model_execution_record = 29
///
/// so no agent execution had ever been written to the table the engineering
/// review gate reads. This file runs the REAL path — the production store
/// seam [agentExecutionStore], the production coordinator construction
/// [buildTriageExecutionCoordinator], a real `LocalWorker` through a real
/// `CoordinatorAgentExecutionDriver`, over the real PostgreSQL stores — and
/// asserts the rows and the verdicts that the split made unreachable.
///
/// ## WHY EVERY ID IN HERE IS MINTED BY PRODUCTION CODE
///
/// The anchor `producedCommitFor` resolves is `agx-<workerExecutionId>`. That
/// is not a convention this file adopts; `LocalWorker._agentRequest` derives
/// it, `LocalWorker` records it on the worker execution, and the coordinator
/// stamps it back onto the work item as `producerActorId`.
///
/// The assertions below therefore read the ids BACK OUT of the database rather
/// than writing them in, and the discriminator is asked about a work item that
/// a real producer run left behind. A test that inserted a matching
/// `producerActorId` by hand would pass against a broken chain: it would only
/// be proving that the test wrote the same value twice.
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
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `work_item` out from under
/// them breaks their assertions. Every marker here is a fixture id this file
/// mints, so no other file's row can match. Runs in `setUp` as well as
/// `tearDown`, because a previous run that aborted mid-test leaves rows behind.
///
/// NO `operator_action` statement, and deliberately so. `AC-14d` scans the whole
/// repository for any UPDATE or DELETE against that table and is a merge
/// blocker; `store_contracts_postgres_test.dart` is the one allowlisted
/// fixture purge, and it is allowlisted because it cannot avoid one. This suite
/// can — it never records an operator action, because it never performs one — so
/// adding itself to that allowlist would buy nothing and would weaken a check
/// that exists to catch exactly the kind of drift it is watching for.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  const statements = <String>[
    'DELETE FROM "human_decision" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "work_item_transition" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "work_item" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "worker_result" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "worker_event" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "worker_execution" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "platform_verification" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "agent_result" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "agent_event" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "agent_execution" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "agent_execution_request" WHERE "workItemId" LIKE \'wi-store-%\'',
    'DELETE FROM "job" WHERE "workItemId" LIKE \'wi-store-%\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

/// The number of agent executions this suite has recorded for [workItemId],
/// read straight out of the table the review gate reads.
Future<int> _agentExecutionCount(
  PersistenceDatabase db,
  String workItemId,
) async {
  final result = await db.query(
    'SELECT count(*) AS n FROM "agent_execution" WHERE "workItemId" = @id',
    parameters: QueryParameters.named({'id': workItemId}),
  );
  return result.first.toColumnMap()['n'] as int;
}

/// A producer run driven through every real component, on real PostgreSQL.
class _ProducerRun {
  _ProducerRun._({
    required this.db,
    required this.workItemId,
    required this.workflowEngine,
    required this.executionStore,
    required this.workerStore,
  });

  /// Runs one real implementation execution and returns the host.
  ///
  /// [writeArtifact] selects which side of the artifact boundary this run lands
  /// on, and it selects it the way production does: the agent writes into its
  /// isolated worktree or it does not, and `ArtifactCommitter` reads the result
  /// off git. Nothing here sets an `endingRevision`.
  static Future<_ProducerRun> execute({
    required PersistenceDatabase db,
    required String workItemId,
    required GitRepoFixture repo,
    required String workspaceRoot,
    required bool writeArtifact,
  }) async {
    final workflowStore = PostgresWorkflowStore(db);
    final workflowEngine = DurableWorkflowEngine(store: workflowStore);
    final workerStore = PostgresWorkerStore(db);
    // BOTH production seams. `agentExecutionStore` is the wiring under test:
    // if it regressed to the file store, nothing below would reach the
    // database and every assertion about `agent_execution` would fail.
    final executionStore = agentExecutionStore(db);

    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Route the federated feed',
      description: 'A producer fixture that leaves exactly what it leaves.',
      // Required by the `agentExecuting -> agentCompleted` edge's
      // `qaContractExists()` guard. Without it the run settles at `agentFailed`,
      // the success branch's `metadataMerge` never runs, and no `producerActorId`
      // is stamped — which would make every assertion below vacuous rather than
      // failing loudly.
      qaContractId: 'qa-1',
      featureRef: 'feature/federated-feed',
    );
    // `draft` has no edge to `agentExecuting`, so the coordinator would refuse
    // the run before a session ever started. This is the production arrival
    // path, taken verbatim from the design-gate lane.
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/federated-feed'},
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );

    final session = DesignGateAgentSession(
      executionId: 'agx-producer',
      writeArtifact: writeArtifact,
    );
    final runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(
          DesignGateAgentAdapter(session, providerId: 'impl-runtime'),
        ),
    );
    final coordinator = buildTriageExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
    );
    final worker = LocalWorker(
      workerId: 'w-impl-store',
      poolId: 'impl-store-pool',
      capabilities: defaultImplementFeatureDefinition.requiredCapabilities,
      workspaceManager: GitWorktreeWorkspaceManager(
        workspaceRoot: workspaceRoot,
      ),
      executionDriver: CoordinatorAgentExecutionDriver(coordinator),
      workerStore: workerStore,
      platform: Platform.operatingSystem,
    );

    final run = worker.run(
      WorkerExecutionRequest(
        workerExecutionId: 'wx-$workItemId',
        workItemId: workItemId,
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        requiredCapabilities:
            defaultImplementFeatureDefinition.requiredCapabilities,
        role: AgentRole.implementer,
        instruction: 'Implement the calculator.',
        timeoutSeconds: 120,
        runtimeTypeId: 'impl-runtime',
      ),
    );

    // The session parks until released, so this is what makes the run
    // deterministic. It is bounded rather than bare: if the coordinator never
    // reaches the agent — a refused transition, an unknown runtime id — a bare
    // `await` hangs until the suite's own timeout with nothing to point at,
    // whereas releasing here surfaces the real failure from `worker.run`.
    await session.awaitingGate.timeout(
      const Duration(seconds: 20),
      onTimeout: () => session.release(),
    );
    session.release();
    final result = await run.timeout(const Duration(seconds: 20));
    if (result.status != WorkerExecutionStatus.executedPass) {
      throw StateError(
        'the producer run for $workItemId did not succeed, so nothing this '
        'file asserts about producerActorId, endingRevision or the review '
        'gate would mean anything. status=${result.status} '
        'failureCode=${result.failureCode} detail=${result.failureDetail}',
      );
    }

    return _ProducerRun._(
      db: db,
      workItemId: workItemId,
      workflowEngine: workflowEngine,
      executionStore: executionStore,
      workerStore: workerStore,
    );
  }

  final PersistenceDatabase db;
  final String workItemId;
  final DurableWorkflowEngine workflowEngine;
  final ExecutionStore executionStore;
  final WorkerStore workerStore;

  Future<WorkItem> item() => workflowEngine.loadWorkItem(workItemId);

  /// Every worker execution the real `LocalWorker` recorded, read back.
  Future<List<WorkerExecution>> workerExecutions() async {
    final all = await workerStore.listWorkerExecutions();
    return all.where((e) => e.workItemId == workItemId).toList();
  }
}

void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('store_rootcause_');
    repo = GitRepoFixture.create(temp.path);
  });

  tearDown(() async {
    await _closeSessions();
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  withServerpod(
    'the execution store the composition attaches is the one readers read',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(_purgeSuiteRows);

      test(
        'a producer run writes agent executions to PostgreSQL, where the '
        'review gate looks for them',
        () async {
          // THE REGRESSION. Before the wiring fix this count stayed at zero no
          // matter how many producer runs happened, because the coordinator was
          // writing to a JSON file in container temp.
          final db = await _newDb();
          final workspaceRoot = '${temp.path}/workspaces';
          Directory(workspaceRoot).createSync(recursive: true);

          expect(
            await _agentExecutionCount(db, 'wi-store-committed'),
            0,
            reason: 'precondition: the work item has never run.',
          );

          final run = await _ProducerRun.execute(
            db: db,
            workItemId: 'wi-store-committed',
            repo: repo,
            workspaceRoot: workspaceRoot,
            writeArtifact: true,
          );

          expect(
            await _agentExecutionCount(db, 'wi-store-committed'),
            greaterThan(0),
            reason:
                'a real producer run through a real coordinator must leave an '
                '`agent_execution` row in the table every reader uses. This is '
                'the assertion that fails if `agentExecutionStore` is ever '
                'wired back to a store the readers cannot see.',
          );

          // And the row must be the one the gate looks up by id, not merely a
          // row that happens to exist.
          final executions = await run.executionStore.listExecutions(
            workItemId: 'wi-store-committed',
          );
          expect(executions, isNotEmpty);
          final producer = executions.first;
          expect(
            await run.executionStore.readResult(producer.executionId),
            isNotNull,
            reason:
                'the gate reads the producer\'s result by execution id to '
                'satisfy `agentResultValid()`. A row without a readable result '
                'leaves the park unreachable in exactly the way the file store '
                'did.',
          );
          expect(
            producer.role,
            AgentRole.implementer,
            reason:
                'the coordinator stamps the REQUESTED role onto the result — an '
                'agent can never assert its own role.',
          );
        },
      );

      test(
        'the anchor the discriminator resolves is minted by production code, '
        'not by this test',
        () async {
          final db = await _newDb();
          final workspaceRoot = '${temp.path}/workspaces';
          Directory(workspaceRoot).createSync(recursive: true);

          final run = await _ProducerRun.execute(
            db: db,
            workItemId: 'wi-store-anchor',
            repo: repo,
            workspaceRoot: workspaceRoot,
            writeArtifact: true,
          );

          final item = await run.item();
          final stampedProducer = item.metadata?['producerActorId'];
          expect(
            stampedProducer,
            isA<String>(),
            reason:
                'the coordinator stamps `producerActorId` on its SUCCESS branch. '
                'Its failure branch deliberately omits the merge, so a producer '
                'that failed leaves no anchor — and this run must have '
                'succeeded for the rest of this test to mean anything.',
          );

          final workerExecutions = await run.workerExecutions();
          final matching = workerExecutions.where(
            (e) => e.agentExecutionId == stampedProducer,
          );
          expect(
            matching,
            hasLength(1),
            reason:
                'this is the join `producedCommitFor` performs, asserted over '
                'rows production wrote. `LocalWorker` derives the anchor as '
                '`agx-<workerExecutionId>` and records it on the execution; '
                'the coordinator stamps the same id onto the work item. If '
                'either derivation changes, the discriminator stops resolving '
                'and this fails here rather than silently routing everything.',
          );
          expect(
            (matching.single.agentExecutionId as String),
            startsWith('agx-'),
            reason: 'the anchor is an agent execution id, by derivation.',
          );
        },
      );

      test(
        'a producer that COMMITTED is discriminated as a commit produced, and '
        'the review gate can act on it',
        () async {
          final db = await _newDb();
          final workspaceRoot = '${temp.path}/workspaces';
          Directory(workspaceRoot).createSync(recursive: true);

          final run = await _ProducerRun.execute(
            db: db,
            workItemId: 'wi-store-committed-2',
            repo: repo,
            workspaceRoot: workspaceRoot,
            writeArtifact: true,
          );
          final item = await run.item();
          expect(
            item.state,
            WorkItemState.agentCompleted,
            reason: 'precondition: the producer succeeded.',
          );

          final resolver = engineeringReviewWorkloadResolver(
            workerStore: run.workerStore,
            runtimeTypeId: 'review-runtime',
          );
          final workload = await resolver(
            Job(
              jobId: 'jb-store-committed-2',
              workItemId: run.workItemId,
              jobType: JobType.engineeringReview,
              requiredRole: AgentRole.engineeringReviewer,
              requiredCapabilities: const {
                WorkerCapability.engineeringReview,
              },
              priority: JobPriority.normal,
              state: JobState.queued,
              dedupeKey: 'engineering-review:${run.workItemId}',
              instruction: 'Review the produced artifact.',
              attempt: 0,
              maxAttempts: 1,
              version: 1,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
            item,
          );

          expect(
            workload,
            isNotNull,
            reason:
                'the producer committed, so there is a reviewable artifact and '
                'the resolver must say so. It resolves entirely from '
                '`worker_execution` and the work item metadata — note that the '
                'store under test is NOT consulted here, which is precisely '
                'why this chain was never what broke.',
          );
          expect(workload!.startingRevision, isNot(repo.startingRevision));
        },
      );

      test(
        'a producer that committed NOTHING is discriminated as no commit, and '
        'the review gate stands down',
        () async {
          final db = await _newDb();
          final workspaceRoot = '${temp.path}/workspaces';
          Directory(workspaceRoot).createSync(recursive: true);

          final run = await _ProducerRun.execute(
            db: db,
            workItemId: 'wi-store-nocommit',
            repo: repo,
            workspaceRoot: workspaceRoot,
            writeArtifact: false,
          );
          final item = await run.item();
          expect(item.state, WorkItemState.agentCompleted);

          // The triage shape, and the measured shape of every real producer in
          // the QA database: HEAD is recorded either way, so an untouched
          // worktree leaves `endingRevision` equal to `requestedStartingRevision`.
          final executions = await run.workerExecutions();
          expect(
            executions.single.endingRevision,
            executions.single.requestedStartingRevision,
            reason: 'precondition: nothing was committed.',
          );

          final resolver = engineeringReviewWorkloadResolver(
            workerStore: run.workerStore,
            runtimeTypeId: 'review-runtime',
          );
          final workload = await resolver(
            Job(
              jobId: 'jb-store-nocommit',
              workItemId: run.workItemId,
              jobType: JobType.engineeringReview,
              requiredRole: AgentRole.engineeringReviewer,
              requiredCapabilities: const {
                WorkerCapability.engineeringReview,
              },
              priority: JobPriority.normal,
              state: JobState.queued,
              dedupeKey: 'engineering-review:${run.workItemId}',
              instruction: 'Review the produced artifact.',
              attempt: 0,
              maxAttempts: 1,
              version: 1,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
            item,
          );
          expect(workload, isNull);

          // The other half: the gate must NOT park this one. The stand-down is
          // decided from `worker_execution` and the work item metadata — never
          // from the store under test — so this holds no matter what
          // `agentExecutionStore` returns.
          await engineeringReviewMissingArtifact(
            workflowEngine: run.workflowEngine,
            executionStore: run.executionStore,
            workerStore: run.workerStore,
            job: Job(
              jobId: 'jb-store-nocommit',
              workItemId: run.workItemId,
              jobType: JobType.engineeringReview,
              requiredRole: AgentRole.engineeringReviewer,
              requiredCapabilities: const {
                WorkerCapability.engineeringReview,
              },
              priority: JobPriority.normal,
              state: JobState.queued,
              dedupeKey: 'engineering-review:${run.workItemId}',
              instruction: 'Review the produced artifact.',
              attempt: 0,
              maxAttempts: 1,
              version: 1,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
            logger: (_, __) {},
          );

          final after = await run.item();
          expect(
            after.state,
            WorkItemState.agentCompleted,
            reason:
                'the implementation inflow owns this item — it produced a '
                'report, not an artifact. Parking it would pre-empt the lane '
                'that can do the work and hand a human a rework/reject choice '
                'that is the wrong question.',
          );
          expect(after.blockingHumanDecisionId, isNull);
        },
      );

      test(
        'the fail-closed park now REACHES a producer that committed — the '
        'thing the file store made impossible',
        () async {
          final db = await _newDb();
          final workspaceRoot = '${temp.path}/workspaces';
          Directory(workspaceRoot).createSync(recursive: true);

          final run = await _ProducerRun.execute(
            db: db,
            workItemId: 'wi-store-park',
            repo: repo,
            workspaceRoot: workspaceRoot,
            writeArtifact: true,
          );

          // Before the wiring fix this handler read `agent_execution`, found
          // nothing, logged `engineering-review-missing-artifact-no-implementer-
          // result` and returned without transitioning or raising anything —
          // on every tick, for ever, for exactly the items that exist to be
          // parked. The two reads below are the reads that used to fail.
          final latest = await run.executionStore.latestExecutionForWorkItem(
            run.workItemId,
          );
          expect(latest, isNotNull);
          expect(
            await run.executionStore.readResult(latest!.executionId),
            isNotNull,
          );

          await engineeringReviewMissingArtifact(
            workflowEngine: run.workflowEngine,
            executionStore: run.executionStore,
            workerStore: run.workerStore,
            job: Job(
              jobId: 'jb-store-park',
              workItemId: run.workItemId,
              jobType: JobType.engineeringReview,
              requiredRole: AgentRole.engineeringReviewer,
              requiredCapabilities: const {
                WorkerCapability.engineeringReview,
              },
              priority: JobPriority.normal,
              state: JobState.queued,
              dedupeKey: 'engineering-review:${run.workItemId}',
              instruction: 'Review the produced artifact.',
              attempt: 0,
              maxAttempts: 1,
              version: 1,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
            logger: (_, __) {},
          );

          final after = await run.item();
          expect(
            after.state,
            WorkItemState.waitingForHumanDecision,
            reason:
                'a commit exists and the producer\'s completed result is '
                'readable, so `agentResultValid()` passes and the gate hands '
                'the item to a human. This is the park the wiring restores.',
          );
          expect(after.blockingHumanDecisionId, isNotNull);
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

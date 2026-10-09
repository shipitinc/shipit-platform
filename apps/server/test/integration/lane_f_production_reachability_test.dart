import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_defect_store.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:control_plane_server/src/persistence/postgres_qa_contract_store.dart';
import 'package:control_plane_server/src/persistence/postgres_triage_store.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:control_plane_server/src/triage/lane_a_defect_triage_work_item.dart';
import 'package:control_plane_server/src/triage/lane_i_tick_hook.dart';
import 'package:control_plane_server/src/triage/triage_processor.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Lane F: does the triage pipeline actually REACH a durable `TriageResult`
/// through the production composition, or only through a test harness?
///
/// `triage_execution_test.dart` proves the processor and everything under it,
/// but it calls `TriageProcessor.processCompletedTriageJob` itself. Nothing in
/// the repository ever proves the wiring that has to happen *before* that
/// call: that a tick dispatches, that the job durably succeeds, and that the
/// post-tick hook notices and hands the job over. That wiring lives only in
/// `apps/server/lib/server.dart`, inside a 30-second timer, and it is the
/// exact place the file's own long comment says a previous version silently
/// dropped every job on the floor.
///
/// So this suite never calls the processor. It rebuilds the shipping
/// composition and then does only two things: `Scheduler.tick()`, and the
/// post-tick hook transcribed from `server.dart`:
///
///     coordinator <- ExecutionCoordinator(AgentRuntime(<adapter>))
///     scheduler   <- Scheduler(dispatch: WorkerDispatcherAdapter(WorkerDispatcher))
///     processor   <- TriageProcessor(...)
///     hook        <- for id in dispatched ∪ terminal ∪ reconciled: ...
///
/// Real PostgreSQL, real work item provisioning, real `JobQueue`, real
/// `LocalWorker` on a real git worktree, real verification, real structured
/// result, real `TriageProcessor`, real typed reads. The only fake is an
/// `AgentAdapter` — bound through the real `AgentAdapterRegistry` at the same
/// seam `server.dart` binds OpenCode.
///
/// WHAT IT FOUND, AND WHAT WAS THEN FIXED. This suite originally reported
/// three defects. Two have since been repaired in production code; the third
/// is still live and is characterised here.
///
///   1. FIXED (B8) — a triage work item was refused at its last transition.
///      `_QAContractExistsGuard` on `agentExecuting -> agentCompleted` requires
///      a `qaContractId`, and no production path ever set one, so the
///      coordinator caught the rejection, recorded the job as PERMANENTLY
///      FAILED and stranded the work item in `agentExecuting`.
///      `DefectTriageWorkItemProvisioner` now provisions a real `QAContract`
///      via `buildAdvisoryTriageQAContract` — three triage gates, advisory
///      only, per ADR 0021 — persists it through `QAContractStore`, and stamps
///      only the id of the row it READ BACK.
///      `ControlPlaneService` supplies `PostgresQAContractStore(_db)`
///      (line 81, getter at line 97); that wiring was the part that made the
///      earlier attempt inert. The first test proves the chain now reaches
///      `agentCompleted` and `triage.processed`, and proves the stamped id
///      resolves to a real `qa_contract` row with the expected category and
///      gate ids — because a non-null string that satisfies the guard is
///      precisely the bug that was fixed, and `!= null` would reproduce it.
///
///   2. FIXED (B9) — a refused execution still produced a classification.
///      The coordinator persists the `AgentResult` BEFORE attempting the
///      transition (deliberately kept), so the post-tick hook found a
///      terminal job plus a saved result and the processor wrote a confident
///      `TriageResult` from a run the platform had just declared failed.
///      `TriageProcessor` now requires BOTH `execution.status == completed`
///      AND `result.status == completed`, logs
///      `triage.execution_not_successful` and returns null. The third test
///      induces exactly the signature Lane G observed —
///      `executionStatus: failed, resultStatus: completed` — and proves that
///      no `TriageResult`, no defect update and no clarification is written.
///
///   3. STILL OPEN — nothing is ever dispatched. `server.dart` line 78 still
///      composes `WorkerDispatcher(registry: WorkerRegistry())` and line 68
///      still composes `AgentRuntime()` with no adapter registered, against
///      `runtimeTypeId: 'opencode'` at line 94. A reported defect is durably
///      enqueued and then deferred forever, so NEITHER fix above is reachable
///      in a shipped server until a worker and an adapter are registered. The
///      second test characterises this; it is unchanged by B8/B9.
///
/// Test isolation (and the only two deviations from `server.dart`):
///
///  1. Work-item/job *listings* are narrowed to this suite's ids. Production
///     reads the whole table; `test/integration` shares one database with files
///     that run concurrently, so an unscoped tick here could enqueue and claim
///     a foreign file's job. Reads by id are not narrowed, so the scheduler can
///     never be told a foreign work item is missing.
///  2. The defect id is namespaced `DEF-lane-f-*` instead of the
///     `DEF-${now.microsecondsSinceEpoch}` that `PostgresDefectStore` mints,
///     because `defect_backend_postgres_test.dart` purges `^DEF-[0-9]+$` and
///     would race a real intake. Nothing else about the fixture is
///     hand-rolled: the defect, its evidence, its event, the work item, the
///     enqueue and the tick are all the production components.
///
/// SHARED-DATABASE INTERFERENCE, NOT A FLAKE. `dart test` runs test FILES
/// concurrently against one shared PostgreSQL database, so a suite's cleanup
/// is a statement about every other suite. This file used to list thirteen
/// siblings in `test/integration/` that issued `TRUNCATE ...` in their setup —
/// `e2e_restart_persistence_test.dart` truncated `work_item` outright — and a
/// concurrent truncate could delete this suite's rows mid-test, with the
/// symptom `Work item not found: defect-DEF-lane-f-reachability` or a null
/// `executionReference` on a job that was succeeded moments earlier. Those
/// were not flaky assertions and this file does not retry around them: the
/// rows really were destroyed.
///
/// The interference is now gone at the source. Every file in
/// `test/integration/` cleans up with namespace-scoped, FK-ordered targeted
/// DELETEs that can only reach rows carrying its own fixture marker — in
/// `setUp` as well as `tearDown`, so an aborted prior run cannot poison the
/// next one — and no file issues a `TRUNCATE` any more. Two invariants follow
/// and are worth keeping: a row missing here is still a real defect, never
/// something to retry around, and no suite may widen its sweep into another
/// suite's id space to make itself pass.
///
/// A SECOND POISONER, now removed at the source. The production bug it exposed
/// is still open and is recorded here because it is a real robustness defect,
/// not a test artefact.
///
/// `test/integration/migration_persistence_test.dart` inserted raw `job` rows
/// with `'{"linux":true}'` in `requiredCapabilitiesJson` — a JSON OBJECT in a
/// column the domain defines as a list of capability names. Those rows were not
/// namespaced and not cleaned up on abort. The fixtures now write
/// `'["linux"]'`, so the immediate poisoner is gone, but the blast radius it
/// demonstrated is unchanged. A column with an unexpected shape still does
/// this:
///
///   postgres_job_store.dart     decodeJsonArray(m['requiredCapabilitiesJson'])
///                               -> jsonDecode('{"linux":true}') as List  💥
///   postgres_job_store.dart     listJobs()
///   scheduler.dart              Scheduler._eligibleRunnableJobs()
///   scheduler.dart              Scheduler.tick()
///
/// `listJobs()` is on the scheduler's hot path and decodes every row without
/// per-row isolation, so ONE malformed row throws the tick for EVERY scheduler
/// in the process. Observed under `dart test test/integration/` as
/// `type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>'` in
/// this file, in `triage_execution_test.dart`, and in others, all from rows
/// this suite never wrote.
///
/// A JSON column with an unexpected shape should not be able to halt the
/// platform. This suite does not reproduce it — doing so would mean writing a
/// malformed row into the database every other suite is reading, which is the
/// exact damage being complained about here.
///
/// The suite passes deterministically in isolation, including a real git
/// worktree per test, and both fixes belong in files that are read-only to
/// this lane.
const String _runtimeTypeId = 'lane-f-fake-triage';

/// The default case: the happy path (B8) and the B9 refusal. Later tests
/// build further cases with the same helpers so every one of them lands inside
/// this suite's `DEF-lane-f-%` / `w-lane-f-%` purge patterns.
const String _defectId = 'DEF-lane-f-reachability';

/// `defectTriageWorkItemId(defectId)` is `defect-<defectId>`, and the triage
/// job is enqueued against that work item.
String _workItemIdFor(String defectId) => 'defect-$defectId';

/// Derived so a case cannot reference another case's intake evidence: the
/// processor persists `evidenceUsed` verbatim and B9 does not validate it, so
/// a shared constant would let a case pass on another's evidence.
String _evidenceIdFor(String defectId) =>
    'ev-${defectId.replaceFirst('DEF-', '')}';

/// One worker per case: `worker_registration` is keyed by worker id and two
/// cases sharing one id would collide in the shared database.
String _workerIdFor(String defectId) =>
    'w-${defectId.replaceFirst('DEF-', '')}';

const String _workItemId = 'defect-$_defectId';
const String _evidenceId = 'ev-lane-f-reachability';

/// The real repository, created per test because [LocalWorker] pins each
/// execution to an exact commit of it.
class _GitRepo {
  _GitRepo._(this.root);

  final Directory root;
  late final String startingRevision;

  static _GitRepo create(String path) {
    final repo = _GitRepo._(Directory(path)..createSync(recursive: true));
    String git(String args) {
      final result = Process.runSync(
        'git',
        args.split(' '),
        workingDirectory: repo.root.path,
      );
      if (result.exitCode != 0) {
        throw StateError(
          'git $args failed: ${result.stdout}\n${result.stderr}',
        );
      }
      return (result.stdout as String).trim();
    }

    git('init --initial-branch=main');
    git('config user.email lane-f@example.com');
    git('config user.name Lane F');
    File('${repo.root.path}/README.md').writeAsStringSync('# lane f\n');
    git('add -A');
    git('commit -m initial');
    repo.startingRevision = git('rev-parse HEAD');
    return repo;
  }

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

/// A fake at the **agent runtime boundary**: production binds a provider here
/// (`runtimeTypeId: 'opencode'` in `server.dart`) and this suite binds a
/// scripted one. Everything above the adapter — coordinator, worker, worktree,
/// verification, scheduler, processor — is the real thing.
///
/// The session is a genuine `AgentSession`: it emits `SessionStarted` on
/// `start`, then asynchronously emits a terminal `SessionCompleted` carrying a
/// real `AgentResult` with a real `structuredResult`. The coordinator therefore
/// has to wait for the terminal contract rather than assume one, exactly as it
/// does for a live provider.
class _FakeRuntimeSession implements AgentSession {
  _FakeRuntimeSession({required this.config, required this.structuredResult});

  final AgentSessionConfig config;
  final Map<String, dynamic> structuredResult;

  final StreamController<AgentEvent> _events =
      StreamController<AgentEvent>.broadcast(sync: true);
  final Completer<void> _terminal = Completer<void>();

  var _status = AgentSessionStatus.starting;
  var _sequence = 0;

  @override
  String get sessionId => config.sessionId ?? 'ses-lane-f';

  @override
  String get executionId => config.executionId;

  @override
  String get workItemId => config.workItemId;

  @override
  AgentSessionStatus get status => _status;

  @override
  Stream<AgentEvent> get eventStream => _events.stream;

  String _nextEventId() => 'evt-lane-f-${_sequence++}';

  void _emit(AgentEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  @override
  Future<void> start(AgentSessionConfig config) async {
    _status = AgentSessionStatus.running;
    _emit(
      SessionStarted(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        sessionId: sessionId,
        workItemId: workItemId,
      ),
    );
  }

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {
    _status = AgentSessionStatus.running;
    _emit(
      InstructionSent(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        instructionId: instruction.instructionId,
        content: instruction.content,
      ),
    );
    // A real provider reports the outcome asynchronously; the coordinator must
    // wait for the terminal contract rather than assume one.
    unawaited(Future<void>.delayed(Duration.zero, _emitTerminal));
  }

  void _emitTerminal() {
    if (_terminal.isCompleted) return;
    _status = AgentSessionStatus.completed;
    _emit(
      SessionCompleted(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        result: _buildResult(),
      ),
    );
    _terminal.complete();
  }

  AgentResult _buildResult() => AgentResult(
    resultId: 'res-$executionId',
    sessionId: sessionId,
    workItemId: workItemId,
    status: AgentResultStatus.completed,
    artifacts: const [],
    diagnostics: const AgentDiagnostics(
      exitCode: 0,
      durationMs: 1,
      toolCalls: 1,
      errors: [],
      warnings: [],
    ),
    structuredResult: structuredResult,
    summary: 'Triage completed by the lane F fake runtime',
    completedAt: DateTime.now().toUtc(),
  );

  @override
  Future<AgentResult> getResult() async {
    // The result is only observable after the terminal event was delivered.
    if (!_terminal.isCompleted) await _terminal.future;
    return _buildResult();
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> cancel(String reason) async {
    if (_status == AgentSessionStatus.completed) return;
    _status = AgentSessionStatus.cancelled;
    _emit(
      SessionCancelled(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );
    if (!_terminal.isCompleted) _terminal.complete();
  }

  @override
  Future<void> close() async {
    // A real provider tears its process down here. This session owns no
    // external resources; the event controller is collected with it.
  }
}

/// The scripted provider registered under [_runtimeTypeId].
class _FakeRuntimeAdapter implements AgentAdapter {
  _FakeRuntimeAdapter(this.structuredResult);

  final Map<String, dynamic> structuredResult;

  @override
  String get providerId => _runtimeTypeId;

  @override
  String get displayName => 'Lane F Fake Runtime';

  @override
  RuntimeCapabilities get capabilities => const RuntimeCapabilities(
    supported: {
      RuntimeCapability.readFiles,
      RuntimeCapability.runShell,
      RuntimeCapability.cancellable,
    },
  );

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    final session = _FakeRuntimeSession(
      config: config,
      structuredResult: structuredResult,
    );
    await session.start(config);
    return session;
  }

  @override
  Future<AgentSession> resumeSession(AgentSessionConfig config) =>
      createSession(config);

  @override
  Future<bool> canResume(String sessionId) async => false;

  @override
  Future<AdapterHealth> checkHealth() async =>
      const AdapterHealth(healthy: true, version: 'lane-f-fake');

  @override
  Future<void> shutdown() async {}
}

/// Narrows a [WorkflowStore]'s work-item listing to ids this suite owns.
///
/// TEST ISOLATION, not production. Production's `Scheduler.tick` reads every
/// work item in the database; `test/integration` shares one PostgreSQL
/// database with files that run concurrently, so an unscoped tick here could
/// enqueue and claim a foreign file's job. Only the listing is narrowed — a
/// read of a specific id still goes to the real store, so the scheduler can
/// never be fooled into thinking a foreign work item is missing.
class _ScopedWorkflowStore implements WorkflowStore {
  _ScopedWorkflowStore(this._delegate, this._owned);

  final WorkflowStore _delegate;
  final Set<String> _owned;

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _delegate.readWorkItem(workItemId);

  @override
  Future<List<WorkItem>> readAllWorkItems() async =>
      (await _delegate.readAllWorkItems())
          .where((item) => _owned.contains(item.workItemId))
          .toList();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) =>
      _delegate.saveWorkItem(item, expectedVersion: expectedVersion);

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _delegate.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _delegate.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _delegate.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _delegate.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _delegate.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _delegate.appendTransitionRecord(record);

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      _delegate.inTransaction<T>((_) => body(this));
}

/// Narrows a [JobStore]'s listing the same way. Writes, claims, events and CAS
/// all still go to the real [PostgresJobStore].
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

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `work_item`/`job` out from
/// under them breaks their assertions. Every marker is namespaced to this
/// file. Runs in `setUp` as well as `tearDown`, because a previous run that
/// aborted mid-test leaves rows behind and re-creating the defect would then
/// violate a unique constraint.
Future<void> purgeSuiteRows(PersistenceDatabase db) async {
  const defect = 'DEF-lane-f-%';
  const workItem = '%DEF-lane-f-%';
  const worker = 'w-lane-f-%';
  const statements = <String>[
    'DELETE FROM "defect_clarification" WHERE "defectId" LIKE \'$defect\'',
    'DELETE FROM "defect_event"         WHERE "defectId" LIKE \'$defect\'',
    'DELETE FROM "defect_evidence"      WHERE "defectId" LIKE \'$defect\'',
    'DELETE FROM "triage_result"        WHERE "defectId" LIKE \'$defect\'',
    'DELETE FROM "defect"               WHERE "defectId" LIKE \'$defect\'',
    'DELETE FROM "worker_event"         WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "worker_result"        WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "worker_execution"     WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "scheduler_event"      WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "job_claim" WHERE "jobId" IN '
        '(SELECT "jobId" FROM "job" WHERE "workItemId" LIKE \'$workItem\')',
    'DELETE FROM "job"                  WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "work_item_transition" WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "work_item"            WHERE "workItemId" LIKE \'$workItem\'',
    'DELETE FROM "worker_registration"  WHERE "workerId" LIKE \'$worker\'',
    // `qa_contract` is keyed by CONTRACT id (`qa-triage-<defectId>`), not by
    // work item id, and carries no FK to `work_item`, so the `%DEF-lane-f-%`
    // sweep above does not reach it. Left behind it would accumulate one
    // orphaned advisory declaration per run.
    'DELETE FROM "qa_contract" WHERE "contractId" LIKE '
        '\'qa-triage-$defect%\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

/// A real, empty [SchedulerTickResult].
///
/// The drain's input is a plain value with a production constructor, so the
/// union legs are covered by handing it real jobs through one leg at a time
/// rather than by inventing a stand-in. The other four lists are empty because
/// a real `Scheduler.tick` result has them empty too whenever the leg under
/// test is the one that fired.
SchedulerTickResult _emptyTick() => const SchedulerTickResult(
  reconciled: [],
  enqueued: [],
  dispatched: [],
  cancelledQueued: [],
  deferred: [],
  terminal: [],
);

/// The `SchedulerWorkload` from `server.dart` lines 89-95, with this suite's
/// real repository and the fake runtime's type id.
SchedulerWorkload _triageWorkload(_GitRepo repo) => SchedulerWorkload(
  repositoryPath: repo.root.path,
  startingRevision: repo.startingRevision,
  timeoutSeconds: 300,
  runtimeTypeId: _runtimeTypeId,
);

/// Production defect intake, reproduced from
/// `ControlPlaneService.createDefect` lines 589-709.
///
/// Reproduced rather than called because `ControlPlaneService` is a `Session`
/// endpoint that mints its own defect id, and this suite needs a fixed,
/// purgeable one. Every *component* is the production one: the defect is saved
/// through `PostgresDefectStore`, the work item is provisioned by
/// `DefectTriageWorkItemProvisioner`, and the job is enqueued by the real
/// `JobQueue` with the canonical builders — plus the
/// `currentTriageJobId` stamp that lets the endpoint find the result later.
Future<Job> _productionIntake({
  required PersistenceDatabase db,
  required WorkflowStore workflowStore,
  required DurableWorkflowEngine workflowEngine,
  required PostgresDefectStore defectStore,
  required String title,
  String defectId = _defectId,
  String evidenceId = _evidenceId,
  QAContractStore? qaContractStore,
  void Function(String event, Map<String, Object?> fields)? log,
}) async {
  final jobStore = PostgresJobStore(db);
  final now = DateTime.now().toUtc();
  final defect = Defect(
    defectId: defectId,
    title: title,
    description: 'Checkout shows 47.00 where the invoice shows 42.00.',
    expectedBehavior: 'Checkout total equals the invoice total.',
    reproductionSteps: '1. Add two items\n2. Open checkout',
    severity: 'high',
    status: DefectStatus.reported,
    reporter: 'reporter@example.com',
    createdAt: now,
    updatedAt: now,
    version: 1,
  );
  await defectStore.saveDefect(defect);
  await defectStore.saveDefectEvidence(
    DefectEvidence(
      evidenceId: evidenceId,
      defectId: defectId,
      kind: EvidenceIntakeKind.textDescription,
      description: 'Invoice 42.00 vs checkout 47.00',
      sourceRef: 'intake-form',
      capturedAt: now,
      createdAt: now,
    ),
  );
  await defectStore.appendDefectEvent(
    DefectEvent(
      eventId: 'evt-lane-f-created-$defectId',
      defectId: defectId,
      sequence: 1,
      type: DefectEventType.created,
      toStatus: DefectStatus.reported,
      actorType: ActorType.human,
      actorId: 'reporter@example.com',
      occurredAt: now,
    ),
  );

  // The production provisioner call, including the `qaContractStore` that
  // `ControlPlaneService._triageWorkItemProvisioner` supplies at line 81.
  final item =
      await DefectTriageWorkItemProvisioner(
        workflowStore: workflowStore,
        workflowEngine: workflowEngine,
        qaContractStore: qaContractStore,
        log: log,
      ).ensurePersisted(
        defect: defect,
        evidenceJson: jsonEncode([
          {
            'evidenceId': evidenceId,
            'description': 'Invoice 42.00 vs checkout 47.00',
          },
        ]),
      );
  final enqueue = await JobQueue(store: jobStore).enqueueIfAbsent(
    workItemId: item.workItemId,
    definition: triageDefectDefinition,
    dedupeKey: triageDefectDedupeKey(item, triageDefectDefinition),
    instruction: triageDefectInstruction(item, triageDefectDefinition),
  );
  if (enqueue.created) {
    await defectStore.saveDefect(
      defect.copyWith(
        currentTriageJobId: enqueue.job.jobId,
        updatedAt: now,
        version: defect.version + 1,
      ),
    );
  }
  return enqueue.job;
}

/// Runs [body] in a guarded zone and returns its value together with every
/// error that reached the zone as an *unhandled* async error.
///
/// This exists because of a real production defect, not to make a flaky test
/// green. `ExecutionCoordinator._releaseExecution`
/// (`packages/execution_coordinator/lib/src/coordinator/
/// execution_coordinator.dart` line 618-637) settles its per-execution
/// `Completer` with `completeError(error)` when finalization throws. That
/// `Completer` exists so `cancelExecution` cannot block forever on a dead
/// execution, and the ordinary `execute()` path never listens to it — so the
/// error is handed to the ambient zone as an unhandled async error. The
/// scheduler's own failure handling is unaffected (the same error is rethrown
/// and `LocalWorker._drive` catches it with `on Object catch`), but the
/// unhandled copy is real and it races the test runner.
///
/// Capturing it here turns a race with teardown into a deterministic
/// assertion about a specific, nameable defect.
Future<(T, List<Object>)> capturingUnhandled<T>(
  Future<T> Function() body,
) async {
  final unhandled = <Object>[];
  final value = await runZonedGuarded<Future<T>>(() async {
    final result = await body();
    // Unhandled-error delivery is scheduled on the zone rather than raised
    // synchronously, and how long that takes depends on what else the isolate
    // is doing. Poll for a bounded window instead of yielding once, so the
    // assertion below is about the error existing -- not about winning a race
    // with the event loop. Still inside the zone, so the error cannot escape
    // into the test runner.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (unhandled.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return result;
  }, (error, stack) => unhandled.add(error));
  return (value as T, unhandled);
}

/// The shipping composition from `apps/server/lib/server.dart` lines 55-109,
/// assembled once so each test can drive the identical object graph.
///
/// Deliberately the production wiring, in production order: the stores, then
/// the coordinator (over the same real execution store), then the worker and
/// its dispatcher, then the scheduler, then the processor. Only two things are
/// parameterised, and neither is production behaviour:
///
///  * [registerWorker] — `server.dart` line 78 passes a bare
///    `WorkerRegistry()`. `false` reproduces that exactly; `true` registers a
///    real `LocalWorker` so a dispatch can actually happen.
///  * [wireQAContractStore] — `true` is what `ControlPlaneService` does
///    (line 81 passes `PostgresQAContractStore(_db)`), and is what every test
///    except the B9 negative one uses. `false` omits it, which is a reachable
///    production configuration rather than a contrivance:
///    `DefectTriageWorkItemProvisioner.qaContractStore` is nullable and
///    documents exactly this case, logging
///    `triage.qa_contract.store_unavailable` and creating the work item with
///    no `qaContractId`. It is the only remaining way to reach a refused
///    completion transition now that B8 is fixed, which is what the B9 test
///    needs.
class _ProductionPipeline {
  _ProductionPipeline._({
    required this.db,
    required this.workflowStore,
    required this.jobStore,
    required this.workerStore,
    required this.defectStore,
    required this.triageStore,
    required this.qaContractStore,
    required this.engine,
    required this.coordinator,
    required this.scheduler,
    required this.processor,
    required this.logs,
    required this.intakeLogs,
    required this.queuedJobId,
    required this.defectId,
    required this.workItemId,
  });

  final PersistenceDatabase db;
  final WorkflowStore workflowStore;
  final JobStore jobStore;
  final PostgresWorkerStore workerStore;
  final PostgresDefectStore defectStore;
  final PostgresTriageStore triageStore;
  final QAContractStore qaContractStore;
  final DurableWorkflowEngine engine;
  final ExecutionCoordinator coordinator;
  final Scheduler scheduler;
  final TriageProcessor processor;

  /// Events emitted by [TriageProcessor] ONLY. Kept separate from
  /// [intakeLogs] so that `expect(logs, isEmpty)` in the never-dispatched test
  /// means what it says — "the processor was never reached" — rather than
  /// "nothing at all happened", which stopped being true once the provisioner
  /// started logging `triage.qa_contract.*` into the same list.
  final List<String> logs;

  /// Events emitted by `DefectTriageWorkItemProvisioner` during intake.
  final List<String> intakeLogs;
  final String queuedJobId;
  final String defectId;
  final String workItemId;

  /// THE production boundary, and the same call `server.dart:207` makes.
  ///
  /// This is deliberately a CALL into `drainTriageOutcomesFromTick` and not a
  /// transcription of it. An earlier version of this file copied the loop out
  /// of `server.dart` and asserted against the copy; a reviewer reverted the
  /// production set to `{...tickResult.terminal}` — the original bug — and the
  /// whole suite still passed, because a copy of a loop is only ever consistent
  /// with itself. `lib/src/triage/lane_i_tick_hook.dart` is now the single
  /// owner of the union, the guards and the per-job isolation, and this suite
  /// runs that same function.
  Future<TriageTickDrainResult> drain(SchedulerTickResult tickResult) {
    return drainTriageOutcomesFromTick(
      tickResult: tickResult,
      jobStore: jobStore,
      triageProcessor: processor,
      // Production passes one operator log to everything; the drain's
      // `triage.tick.job_failed` lands beside the processor's events so a
      // refused job and a failed job are both visible in one place.
      logger: (event, data) => logs.add('$event $data'),
    );
  }

  Future<SchedulerTickResult> tick() => scheduler.tick();

  static Future<_ProductionPipeline> build({
    required PersistenceDatabase db,
    required Directory caseRoot,
    required _GitRepo repo,
    required bool registerWorker,
    required String title,
    bool wireQAContractStore = true,
    String defectId = _defectId,
    String caseSuffix = 'reachability',
    List<String> extraDefectIds = const [],
  }) async {
    // Every case gets its own defect, work item, evidence, worker and execution
    // store, so several can be built inside one test without colliding in the
    // shared database. `_evidenceId` is threaded into the fake runtime's
    // structured result below for the same reason.
    final workItemId = _workItemIdFor(defectId);
    final evidenceId = _evidenceIdFor(defectId);
    final workerId = _workerIdFor(defectId);

    // --- the real stores, over the real database ------------------------
    final workflowStore = PostgresWorkflowStore(db);
    final jobStore = PostgresJobStore(db);
    final workerStore = PostgresWorkerStore(db);
    final defectStore = PostgresDefectStore(db);
    final triageStore = PostgresTriageStore(db);
    // The real store, constructed exactly as `ControlPlaneService.qaContractStore`
    // constructs it (line 97: `PostgresQAContractStore(_db)`).
    final qaContractStore = PostgresQAContractStore(db);
    final engine = DurableWorkflowEngine(store: workflowStore);
    // `extraDefectIds` lets one pipeline carry several triage work items, so a
    // test can exercise a MULTI-JOB tick batch. It matters that they share one
    // pipeline rather than being two pipelines: the drain runs one processor
    // over one execution store, and a second pipeline's executions would be
    // invisible to the first — the batch would then fail for the wrong
    // reason.
    final owned = <String>{
      workItemId,
      for (final extra in extraDefectIds) _workItemIdFor(extra),
    };
    // Captured before intake: the provisioner logs `triage.qa_contract.*` from
    // inside `ensurePersisted`, and those events are evidence about whether a
    // real contract was provisioned. Kept apart from the processor's log.
    final intakeLogs = <String>[];
    final logs = <String>[];

    // --- the agent runtime, faked at the adapter seam --------------------
    // `runtimeTypeId` below selects this adapter through the real
    // `AgentAdapterRegistry`; the coordinator, worker and scheduler are
    // untouched. `server.dart` binds OpenCode at exactly this point (and
    // currently binds nothing at all — the second test).
    final runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(
          _FakeRuntimeAdapter({
            'classification': DefectClassification.implementationDefect.wire,
            'status': DefectStatus.triaging.wire,
            'confidence': 0.82,
            'suspectedCategory': 'backend',
            'suspectedComponents': ['checkout', 'invoice-render'],
            'reproductionSupported': true,
            'evidenceUsed': [evidenceId],
            'clarificationRequired': const <Map<String, String>>[],
            'recommendedNextAction': 'fix',
            'summary': 'Checkout total is computed before tax rounding.',
          }),
        ),
    );

    // --- the real coordinator, on a real on-disk execution store ---------
    // A real platform-runner verification executes inside the isolated
    // worktree, so a green job is itself proof the verifier really ran.
    final coordinator = ExecutionCoordinator(
      store: FileJsonExecutionStore(
        File('${caseRoot.path}/$caseSuffix/execution/store.json'),
      ),
      workflowEngine: engine,
      runtime: runtime,
      verificationPlan: const VerificationPlan(
        command: ['git', 'rev-parse', '--verify', 'HEAD^{commit}'],
        checkName: 'git_worktree_head',
      ),
    );

    // --- the real worker, on a real git worktree ------------------------
    final worker = LocalWorker(
      workerId: workerId,
      poolId: 'triage-pool',
      capabilities: const {
        WorkerCapability.linux,
        WorkerCapability.git,
      },
      workspaceManager: GitWorktreeWorkspaceManager(
        workspaceRoot: '${caseRoot.path}/$caseSuffix/workspaces',
      ),
      executionDriver: CoordinatorAgentExecutionDriver(coordinator),
      workerStore: workerStore,
      platform: 'local-test',
    );
    final registry = WorkerRegistry();
    if (registerWorker) registry.register(worker);

    // --- the real scheduler, as `server.dart` composes it ----------------
    // Only the two listings are scoped; see `_ScopedWorkflowStore`.
    final scheduler = Scheduler(
      schedulerId: 'sched-lane-f-$caseSuffix',
      workflowStore: _ScopedWorkflowStore(workflowStore, owned),
      jobStore: _ScopedJobStore(jobStore, owned),
      workerStore: workerStore,
      dispatch: WorkerDispatcherAdapter(WorkerDispatcher(registry: registry)),
      definition: triageDefectDefinition,
      dedupeKeyBuilder: triageDefectDedupeKey,
      instructionBuilder: triageDefectInstruction,
      requestBuilder: triageDefectRequest,
      workload: _triageWorkload(repo),
      clock: () => DateTime.now().toUtc(),
    );

    // --- production intake -----------------------------------------------
    final queued = await _productionIntake(
      db: db,
      workflowStore: workflowStore,
      workflowEngine: engine,
      defectStore: defectStore,
      defectId: defectId,
      evidenceId: evidenceId,
      title: title,
      qaContractStore: wireQAContractStore ? qaContractStore : null,
      log: (event, fields) => intakeLogs.add('$event $fields'),
    );

    for (final extra in extraDefectIds) {
      await _productionIntake(
        db: db,
        workflowStore: workflowStore,
        workflowEngine: engine,
        defectStore: defectStore,
        defectId: extra,
        evidenceId: _evidenceIdFor(extra),
        title: 'Second defect in the same batch',
        qaContractStore: wireQAContractStore ? qaContractStore : null,
        log: (event, fields) => intakeLogs.add('$event $fields'),
      );
    }

    return _ProductionPipeline._(
      db: db,
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      defectStore: defectStore,
      triageStore: triageStore,
      qaContractStore: qaContractStore,
      engine: engine,
      coordinator: coordinator,
      scheduler: scheduler,
      // Production logs to stdout; here the logger is captured so a test can
      // assert whether the hook actually drove the processor.
      processor: TriageProcessor(
        db: db,
        workflowStore: workflowStore,
        workflowEngine: engine,
        executionCoordinator: coordinator,
        defectStore: defectStore,
        triageStore: triageStore,
        logger: (event, data) => logs.add('$event $data'),
      ),
      logs: logs,
      intakeLogs: intakeLogs,
      queuedJobId: queued.jobId,
      defectId: defectId,
      workItemId: workItemId,
    );
  }
}

void main() {
  final openSessions = <Session>[];

  Future<Session> newSession() async {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    openSessions.add(session);
    return session;
  }

  Future<PersistenceDatabase> newDb() async =>
      PersistenceDatabase((await newSession()).db);

  withServerpod(
    'lane F: the production triage composition reaches a durable TriageResult',
    (sessionBuilder, endpoints) {
      late Directory caseRoot;
      late _GitRepo repo;

      setUp(() async {
        await purgeSuiteRows(await newDb());
        caseRoot = Directory(
          '${Directory.systemTemp.path}/shipit_lane_f_reachability',
        )..createSync(recursive: true);
        repo = _GitRepo.create('${caseRoot.path}/source_repo');
      });

      tearDown(() async {
        repo.dispose();
        if (caseRoot.existsSync()) caseRoot.deleteSync(recursive: true);
        for (final session in List.of(openSessions)) {
          unawaited(session.close());
        }
        openSessions.clear();
        // Purge after each test, not only before it. A suite that cleans up in
        // `setUp` alone leaves the last test's rows in the shared database,
        // which is the same damage this suite's own `setUp` exists to undo on
        // someone else's behalf.
        await purgeSuiteRows(await newDb());
      });

      test(
        'the chain reaches agentCompleted and triage.processed through the '
        'production composition, and the stamped qaContractId resolves to a '
        'real qa_contract row',
        () async {
          // THE happy path, and the reason the other two tests exist.
          //
          // Nothing here is hand-wired. `DefectTriageWorkItemProvisioner`
          // provisions a real `QAContract` (`qa_orchestration/lib/src/
          // lane_g_triage_qa_contract.dart`), `PostgresQAContractStore` writes
          // it and reads it back, and only the read-back id is stamped on the
          // work item — `ControlPlaneService` supplies that store at line 81.
          // Then the real scheduler ticks, the real `LocalWorker` executes in a
          // real git worktree, the real coordinator verifies, the real
          // work-item transition passes `qaContractExists()`, and the real
          // `TriageProcessor` is driven only by the transcribed post-tick hook.
          final db = await newDb();
          final pipeline = await _ProductionPipeline.build(
            db: db,
            caseRoot: caseRoot,
            repo: repo,
            registerWorker: true,
            title: 'Checkout totals disagree with the invoice screen',
          );

          // --- 1. the qaContractId is a REAL row, not a string ------------
          //
          // This is asserted BEFORE the pipeline runs, and it is deliberately
          // more than `!= null`. The defect that B8 fixed was a work item
          // whose `qaContractId` was absent entirely, and the natural way to
          // "fix" that in a test is to attach an opaque string — which
          // satisfies `qaContractExists()` and nothing else, reproducing the
          // original defect with extra steps. So: the row must exist, its
          // category must equal the work item's own category, its gate ids
          // must be the three the triage contract declares, and it must be
          // reachable through the store's own query methods rather than only
          // by primary key.
          final item = await pipeline.workflowStore.readWorkItem(_workItemId);
          final contractId = item.qaContractId;
          expect(
            contractId,
            isNotNull,
            reason:
                'the provisioner stamps the id of the contract it read back, '
                'never a placeholder',
          );
          expect(
            contractId,
            triageQAContractIdForDefect(_defectId),
            reason:
                'the contract id is derived from the defect, so one defect '
                'gets one contract and re-provisioning converges',
          );
          expect(
            await pipeline.qaContractStore.hasQAContract(contractId!),
            isTrue,
          );
          final contract = await pipeline.qaContractStore.readQAContract(
            contractId,
          );
          expect(
            contract,
            isNotNull,
            reason: 'the stamped id must resolve to an actual row',
          );
          expect(
            contract!.workItemCategory,
            item.category,
            reason:
                'a contract that claims a category the work item does not '
                'have is a contract nobody can check; this compares against '
                'the PERSISTED work item, not a shared constant, so drift is '
                'caught rather than assumed away',
          );
          expect(contract.version, advisoryTriageQAContractVersion);
          expect(
            contract.gates.map((g) => g.gateId).toList(),
            const [
              'triage-classification-admitted',
              'triage-evidence-grounded',
              'triage-clarification-routing',
            ],
            reason: 'the advisory triage gate set, per ADR 0021',
          );
          expect(
            contract.gates.map((g) => g.required).toList(),
            [true, true, false],
            reason:
                'classification and evidence grounding are required; '
                'clarification routing is conditional on ambiguity and is '
                'deliberately NOT required',
          );
          expect(
            contract.metadata?[qaContractWorkItemIdMetadataKey],
            _workItemId,
            reason: 'the contract records the work item it was provisioned for',
          );
          expect(contract.metadata?[qaContractDefectIdMetadataKey], _defectId);
          expect(contract.passCriteria?.allRequiredGatesMustPass, isTrue);
          expect(contract.metadata?['advisory'], isTrue);
          expect(
            await pipeline.qaContractStore.listQAContractsForWorkItem(
              _workItemId,
            ),
            hasLength(1),
            reason: 'the contract is findable by work item, not only by id',
          );
          expect(
            await pipeline.qaContractStore.listQAContractsByCategory(
              item.category,
            ),
            contains(contract),
          );
          expect(
            pipeline.intakeLogs,
            contains(startsWith('triage.qa_contract.provisioned ')),
            reason: 'and the provisioner said so, with the read-back id',
          );

          // A stale schema must not silently pass. `qa_contract` arrives with
          // migration 20260928140116000; anything older cannot provision the
          // contract above at all, and would otherwise surface much later as
          // an opaque SQL error inside the scheduler.
          const qaContractMigration = '20260928140116000';
          final applied =
              (await db.query(
                    'SELECT version FROM serverpod_migrations '
                    'ORDER BY version DESC LIMIT 1',
                  )).single.toColumnMap()['version']!
                  as String;
          expect(
            int.parse(applied),
            greaterThanOrEqualTo(int.parse(qaContractMigration)),
            reason:
                'the applied schema must be at least migration '
                '$qaContractMigration (found $applied), which is what creates '
                '"qa_contract"; an older schema cannot provision the contract '
                'above at all',
          );

          // --- 2. the chain now reaches agentCompleted -------------------
          final tick = await pipeline.tick();
          expect(tick.enqueued, isEmpty, reason: 'intake already enqueued it');
          expect(tick.dispatched, hasLength(1));
          expect(
            tick.terminal,
            isEmpty,
            reason:
                'a job dispatched AND completed inside one tick is reported '
                'only in `dispatched`; `server.dart` unions the three lists '
                'precisely because of this, and the hook only drains because '
                'of it',
          );
          expect(tick.reconciled, isEmpty);

          // THE production boundary, and the real one. This calls
          // `drainTriageOutcomesFromTick` — `server.dart:207` calls that same
          // function on the same arguments — so the union, the guards and the
          // per-job isolation exercised here are production's, not a copy.
          final drain = await pipeline.drain(tick);
          expect(drain.considered, 1);
          expect(drain.skipped, 0);
          expect(drain.handedOff, 1);
          expect(drain.failedJobIds, isEmpty);

          final job = await pipeline.jobStore.readJob(tick.dispatched.single);
          expect(job!.state, JobState.succeeded);
          expect(job.attempt, 1);
          expect(job.failure, isNull, reason: 'no permanent failure any more');
          expect(job.jobType, JobType.triageDefect);
          expect(job.workItemId, _workItemId);
          expect(job.requiredRole, AgentRole.triageDefect);
          expect(
            job.requiredCapabilities,
            triageDefectDefinition.requiredCapabilities,
          );
          expect(
            job.instruction,
            contains('Checkout totals disagree'),
            reason:
                'the canonical instruction builder sends the triage '
                'instruction, not the default implement-feature instruction',
          );
          expect(
            job.instruction,
            contains(_evidenceId),
            reason: 'and renders the real intake evidence',
          );
          expect(
            pipeline.logs,
            contains(startsWith('triage.processed ')),
            reason: 'B9 allows this because BOTH signals say completed',
          );
          expect(
            pipeline.logs,
            isNot(contains(startsWith('triage.execution_not_successful'))),
          );

          // The refused-transition failure mode is gone. This is the exact
          // assertion that could not be made before B8: the completion
          // transition now passes `qaContractExists()` and the job is not
          // recorded as a permanent failure.
          expect(
            job.failure?.kind,
            isNot(JobFailureKind.permanent),
            reason: 'the QA guard no longer rejects the completion',
          );

          // The coordinator really drove a worktree and really verified.
          final executionId = job.executionReference!.agentExecutionId!;
          final execution = await pipeline.coordinator.store.readExecution(
            executionId,
          );
          expect(
            execution.status,
            AgentSessionStatus.completed,
            reason:
                'B9 reads this; if it were `failed` the processor would have '
                'refused the result, so the durable TriageResult below is '
                'itself evidence that this is `completed`',
          );
          final verifications = await pipeline.coordinator.store
              .readVerifications(executionId);
          expect(verifications, hasLength(1));
          expect(verifications.single.status, AgentClaimStatus.passed);
          expect(verifications.single.resultPath, contains('workspaces'));
          expect(
            (await pipeline.coordinator.store.readResult(
              executionId,
            ))?.structuredResult['classification'],
            DefectClassification.implementationDefect.wire,
          );

          // The work item advanced out of execution through the real engine.
          expect(
            (await pipeline.workflowStore.readWorkItem(_workItemId)).state,
            WorkItemState.agentCompleted,
            reason: 'agentExecuting -> agentCompleted, past qaContractExists()',
          );

          // --- 3. the durable TriageResult ------------------------------
          final viaJob = await pipeline.triageStore.readTriageResultForJob(
            job.jobId,
          );
          expect(viaJob, isNotNull);
          expect(viaJob!.defectId, _defectId);
          expect(viaJob.jobId, job.jobId);
          expect(viaJob.executionId, executionId);
          expect(
            viaJob.recommendedClassification,
            DefectClassification.implementationDefect,
          );
          expect(viaJob.recommendedStatus, DefectStatus.triaging);
          expect(viaJob.confidence, 0.82);
          expect(viaJob.suspectedCategory, 'backend');
          expect(viaJob.suspectedComponents, ['checkout', 'invoice-render']);
          expect(viaJob.evidenceUsed, [_evidenceId]);
          expect(viaJob.recommendedNextAction, 'fix');
          expect(viaJob.clarificationRequired, isEmpty);
          expect(
            await pipeline.triageStore.readTriageResultsForDefect(_defectId),
            hasLength(1),
          );
          expect(
            (await pipeline.triageStore.readTriageResult(
              viaJob.resultId,
            ))?.resultId,
            viaJob.resultId,
          );

          // The human-reported defect keeps its status and gains a reference.
          final reread = await pipeline.defectStore.readDefect(_defectId);
          expect(reread.status, DefectStatus.reported);
          expect(reread.classification, isNull);
          expect(reread.currentTriageJobId, job.jobId);
          final metadata =
              jsonDecode(reread.metadataJson!) as Map<String, dynamic>;
          expect(metadata['triageResultId'], viaJob.resultId);

          // And the same durable state is visible over the typed endpoint.
          final inspected = await endpoints.defectEndpoints.inspect(
            sessionBuilder,
            defectId: _defectId,
          );
          expect(inspected.defect.status, DefectStatus.reported.wire);
          expect(inspected.triageResult!.resultId, viaJob.resultId);
          expect(inspected.evidence, hasLength(1));
        },
        // The default 30s is not enough for a real git worktree plus a real
        // platform-runner verification when every other integration file is
        // competing for the same machine and the same database.
        timeout: const Timeout(Duration(minutes: 10)),
      );

      test(
        'STILL OPEN - PRODUCTION BLOCKER: the shipped composition enqueues a '
        'triage job and never dispatches it, so no TriageResult is ever '
        'produced',
        () async {
          // Characterisation of `apps/server/lib/server.dart` as written
          // today, built from the production components with the values the
          // shipping server actually passes:
          //
          //   server.dart:68  runtime: AgentRuntime(),   // no adapter at all
          //   server.dart:78  WorkerDispatcher(registry: WorkerRegistry())
          //   server.dart:94  runtimeTypeId: 'opencode'
          //
          // An empty `WorkerRegistry` means `WorkerDispatcher.select` never
          // yields a worker, so `Scheduler.tick` cannot dispatch. That is a
          // structural fact, so it is demonstrated by running the real
          // scheduler rather than asserted about a list.
          //
          // B8 and B9 did not touch this. They made the far end of the
          // pipeline correct; nothing here ever reaches it, so neither fix is
          // observable in a shipped server. This is now the only blocker left
          // from the original three.
          //
          // Expected to FAIL once production registers a worker and an
          // OpenCode adapter — at which point the assertions below invert and
          // this becomes the regression guard for the shipped composition.
          final db = await newDb();
          final pipeline = await _ProductionPipeline.build(
            db: db,
            caseRoot: caseRoot,
            repo: repo,
            registerWorker: false,
            title: 'Shipped composition probe',
          );

          final first = await pipeline.tick();
          expect(
            first.enqueued,
            isEmpty,
            reason: 'production intake already enqueued it',
          );
          expect(
            first.dispatched,
            isEmpty,
            reason:
                'PRODUCTION BLOCKER: no worker is registered, so '
                '`WorkerDispatcher.select` yields nothing',
          );
          expect(
            first.deferred,
            [pipeline.queuedJobId],
            reason:
                'the job is deferred for want of a capable worker, not '
                'dropped and not failed',
          );

          // Further ticks change nothing: the job is durable and stuck.
          final second = await pipeline.tick();
          expect(second.dispatched, isEmpty);
          expect(second.terminal, isEmpty);
          expect(second.reconciled, isEmpty);

          // The real drain runs, sees a non-terminal job, and correctly
          // SKIPS it. The processor is never reached.
          final drain = await pipeline.drain(second);
          expect(
            drain.considered,
            0,
            reason:
                'a job the scheduler DEFERRED is not in the union, and must '
                'not be: the union is `dispatched ∪ terminal ∪ reconciled`, '
                'and a deferred job has reached no terminal state, so handing '
                'it to the processor would be handing it a job that cannot be '
                'consumed. `deferred` is deliberately not a leg of the union',
          );
          expect(drain.skipped, 0);
          expect(drain.handedOff, 0);
          expect(drain.succeededJobIds, isEmpty);
          expect(drain.failedJobIds, isEmpty);
          expect(
            pipeline.logs,
            isEmpty,
            reason:
                'no triage event of any kind was emitted. `intakeLogs` is not '
                'empty: the provisioner did run and did provision a contract, '
                'which is the point of the assertions below',
          );

          // The observable production symptom: a reported defect durably
          // queued for triage for as long as the server runs, and never
          // classified, never clarified, never surfaced.
          final job = await pipeline.jobStore.readJob(pipeline.queuedJobId);
          expect(job!.state, JobState.queued);
          expect(job.attempt, 1, reason: '1-based, set at enqueue');
          expect(job.startedAt, isNull);
          expect(job.executionReference, isNull);
          expect(
            await pipeline.triageStore.readTriageResultForJob(job.jobId),
            isNull,
          );
          expect(
            (await pipeline.workflowStore.readWorkItem(_workItemId)).state,
            WorkItemState.designNotRequired,
            reason: 'the work item never left its entry state',
          );
          final reread = await pipeline.defectStore.readDefect(_defectId);
          expect(reread.status, DefectStatus.reported);
          expect(reread.currentTriageJobId, job.jobId);

          // The QA contract IS provisioned here — the work item is not the
          // problem. It reaches exactly as far as the empty registry allows
          // and then stops, which is what makes the diagnosis precise.
          final item = await pipeline.workflowStore.readWorkItem(_workItemId);
          expect(
            item.qaContractId,
            triageQAContractIdForDefect(_defectId),
            reason: 'B8 is fixed: the work item carries a real contract id',
          );
          expect(
            await pipeline.qaContractStore.hasQAContract(item.qaContractId!),
            isTrue,
          );
        },
        // The default 30s is not enough for a real git worktree plus a real
        // platform-runner verification when every other integration file is
        // competing for the same machine and the same database.
        timeout: const Timeout(Duration(minutes: 10)),
      );

      test(
        'a genuinely FAILED execution whose result says completed writes NO '
        'TriageResult, no defect update and no clarifications',
        () async {
          // B9. The valuable one.
          //
          // B8 fixed the cause, but the EFFECT B9 defends against is still
          // reachable, and it is the one that produced the incoherent record
          // this suite originally reported: an execution the platform declared
          // FAILED, whose saved `AgentResult` nonetheless says `completed`,
          // being read by the processor as an authoritative classification.
          // The coordinator's save-before-transition ordering is deliberately
          // KEPT (`execution_coordinator.dart:362` persists the result, then
          // `:405` attempts `agentExecuting -> agentCompleted`), so this
          // signature is the normal consequence of ANY refusal at the last
          // transition — a guard rejection, a store error, a concurrent state
          // change — not a contrived combination.
          //
          // HOW IT IS INDUCED, honestly: the work item is provisioned with
          // `qaContractStore: null`. That is a reachable production
          // configuration, not a test invention —
          // `DefectTriageWorkItemProvisioner.qaContractStore` is declared
          // nullable precisely for it and documents the behaviour, logging
          // `triage.qa_contract.store_unavailable` and creating the work item
          // with no `qaContractId` rather than minting a placeholder. With no
          // contract, `qaContractExists()` refuses the completion transition,
          // the coordinator's catch records `AgentSessionStatus.failed`, and
          // the durable result keeps `AgentResultStatus.completed`.
          //
          // The result-status-only check this guards against would CONSUME
          // this job. Both halves are asserted below, so the test fails if
          // either the execution check or the result check is dropped.
          final db = await newDb();
          final pipeline = await _ProductionPipeline.build(
            db: db,
            caseRoot: caseRoot,
            repo: repo,
            registerWorker: true,
            title: 'Checkout totals disagree with the invoice screen',
            wireQAContractStore: false,
          );

          // Precondition: the work item really has no contract, and the
          // provisioner said so rather than inventing one.
          final item = await pipeline.workflowStore.readWorkItem(_workItemId);
          expect(
            item.qaContractId,
            isNull,
            reason: 'this is the precondition being induced, not a hope',
          );
          expect(
            pipeline.intakeLogs,
            contains(startsWith('triage.qa_contract.store_unavailable ')),
            reason:
                'the store-less path is explicit and logged, which is what '
                'makes it a reachable configuration rather than a contrivance',
          );
          expect(
            await pipeline.qaContractStore.readQAContract(
              triageQAContractIdForDefect(_defectId),
            ),
            isNull,
            reason: 'and genuinely no contract row was written',
          );

          final (tick, unhandled) = await capturingUnhandled(pipeline.tick);
          expect(
            tick.dispatched,
            hasLength(1),
            reason: 'the worker and adapter are registered, so it dispatches',
          );

          // --- the exact signature B9 exists to catch --------------------
          final dispatched = await pipeline.jobStore.readJob(
            tick.dispatched.single,
          );
          final executionId = dispatched!.executionReference!.agentExecutionId!;

          // The result is real, durable, role-stamped and says COMPLETED. This
          // is the half a result-status-only check would have accepted.
          final result = await pipeline.coordinator.store.readResult(
            executionId,
          );
          expect(result, isNotNull, reason: 'the coordinator saved it first');
          expect(
            result!.status,
            AgentResultStatus.completed,
            reason: 'the agent did its job and reported success',
          );
          expect(
            result.structuredResult['classification'],
            DefectClassification.implementationDefect.wire,
          );

          // The execution is FAILED. This is the half a result-only check
          // would have missed.
          expect(
            (await pipeline.coordinator.store.readExecution(
              executionId,
            )).status,
            AgentSessionStatus.failed,
            reason:
                'the completion transition was refused, the catch at '
                'execution_coordinator.dart:319 stamped a finalize error',
          );
          expect(
            (await pipeline.workflowStore.readWorkItem(_workItemId)).state,
            WorkItemState.agentExecuting,
          );

          // The unhandled copy of the finalize error is a separate production
          // wart (`_releaseExecution` settles a `Completer` nobody listens to,
          // execution_coordinator.dart:618-637). It is recorded rather than
          // asserted away, because `server.dart`'s timer swallows it and
          // nobody is looking at it.
          expect(
            unhandled,
            hasLength(1),
            reason:
                'one unhandled async error from the settled contract nobody is '
                'waiting on \u2014 still present, still invisible in production',
          );

          // --- the drain runs, REFUSES this job, and RETURNS --------------
          // `drainTriageOutcomesFromTick` guards each job individually, so a
          // refused job is a normal outcome reported in `succeededJobIds`, not
          // a throw. Awaiting it without a try/catch IS the assertion:
          // reaching the next line proves it returned, and the accounting below
          // proves the refusal was counted rather than swallowed.
          final drain = await pipeline.drain(tick);
          expect(drain.considered, 1);
          expect(drain.skipped, 0);
          expect(
            drain.handedOff,
            1,
            reason:
                'the processor RAN; it returned null because the execution was '
                'not successful. A refusal is not a skipped job and not a '
                'failed one',
          );
          expect(drain.failedJobIds, isEmpty, reason: 'nothing threw');
          expect(
            drain.succeededJobIds,
            [dispatched.jobId],
            reason:
                'a job the processor declined is still a job the processor '
                'handled; reporting it as a failure would make a refusal look '
                'like a throw',
          );

          // --- 1. the log event ------------------------------------------
          final notSuccessful = pipeline.logs
              .where((l) => l.startsWith('triage.execution_not_successful '))
              .toList();
          expect(notSuccessful, hasLength(1), reason: 'the refusal is logged');
          expect(
            notSuccessful.single,
            contains('executionStatus: failed'),
            reason: 'and names the execution status that caused it',
          );
          expect(
            notSuccessful.single,
            contains('resultStatus: completed'),
            reason:
                'the signature Lane G observed: the result says completed and '
                'the execution says failed, in one durable job',
          );
          expect(
            pipeline.logs,
            isNot(contains(startsWith('triage.processed '))),
            reason: 'nothing may be processed from a failed execution',
          );

          // --- 2. no TriageResult, by job or by defect -------------------
          final job = await pipeline.jobStore.readJob(dispatched.jobId);
          expect(job!.state, JobState.failed);
          expect(
            job.failure!.kind,
            JobFailureKind.permanent,
            reason: 'a guard rejection is not a retryable agent failure',
          );
          expect(
            await pipeline.triageStore.readTriageResultForJob(job.jobId),
            isNull,
            reason:
                'the direct ask: this job produced no classification, even '
                'though a completed one was sitting in the execution store',
          );
          expect(
            await pipeline.triageStore.readTriageResultsForDefect(_defectId),
            isEmpty,
          );
          // Belt and braces: ask the table directly, so the assertion cannot
          // be satisfied by a store method that filters on job state.
          final rows = await db.query(
            'SELECT count(*) AS "n" FROM "triage_result" '
            'WHERE "defectId" = @defectId',
            parameters: QueryParameters.named({'defectId': _defectId}),
          );
          expect(
            (rows.single.toColumnMap()['n']! as num).toInt(),
            0,
            reason: 'no triage_result row exists for this defect, at all',
          );

          // --- 3. the defect is NOT updated ------------------------------
          final reread = await pipeline.defectStore.readDefect(_defectId);
          expect(reread.status, DefectStatus.reported);
          expect(reread.classification, isNull);
          expect(
            reread.currentTriageJobId,
            job.jobId,
            reason: 'still the enqueued job, with no result attached',
          );
          // The triage metadata merge is what writes `triageResultId` into
          // `metadataJson`. With no merge the column is either untouched —
          // null, as the defect was saved at intake, with no metadata at all —
          // or present without that key. Treating null as an empty document
          // makes the assertion about the merge rather than about the column
          // being non-null.
          final metadata = reread.metadataJson == null
              ? const <String, dynamic>{}
              : jsonDecode(reread.metadataJson!) as Map<String, dynamic>;
          expect(
            metadata.containsKey('triageResultId'),
            isFalse,
            reason: 'the triage metadata merge must not have happened',
          );

          // --- 4. no clarifications --------------------------------------
          expect(
            await pipeline.defectStore.readClarificationsForDefect(_defectId),
            isEmpty,
            reason: 'a failed run raises nothing for a human to answer',
          );
          final clarifications = await db.query(
            'SELECT count(*) AS "n" FROM "defect_clarification" '
            'WHERE "defectId" = @defectId',
            parameters: QueryParameters.named({'defectId': _defectId}),
          );
          expect(
            (clarifications.single.toColumnMap()['n']! as num).toInt(),
            0,
          );

          // --- 5. the processor is still usable ---------------------------
          // B9 refuses one job; it must not poison the batch. The hook
          // returned normally above, and the processor is a shared instance
          // over the same stores, so a subsequent successful job must still be
          // consumable. This is asserted by re-running the processor against
          // the same job and observing the same refusal rather than a crash or
          // a duplicate write.
          final again = await pipeline.processor.processCompletedTriageJob(
            job,
          );
          expect(again, isNull, reason: 'B9 is idempotent in its refusal');
          expect(
            await pipeline.triageStore.readTriageResultsForDefect(_defectId),
            isEmpty,
            reason: 'processing the same job twice still writes nothing',
          );
        },
        // The default 30s is not enough for a real git worktree plus a real
        // platform-runner verification when every other integration file is
        // competing for the same machine and the same database.
        timeout: const Timeout(Duration(minutes: 10)),
      );

      // ------------------------------------------------------------------
      // B2. The regression guard for the union of
      // `dispatched \u222a terminal \u222a reconciled`.
      //
      // `SchedulerTickResult.terminal` alone is NOT the set of jobs that
      // reached a terminal state: in `Scheduler.tick` a job dispatched AND
      // completed inside one tick takes the `if (outcome.dispatched)` branch
      // first, so its id never reaches `terminal`. The original server
      // consumed `{...tickResult.terminal}` and therefore never ran the
      // processor at all. Each leg below is drained through the REAL
      // `drainTriageOutcomesFromTick`, so narrowing the union in
      // `lane_i_tick_hook.dart:118` fails this test.
      // ------------------------------------------------------------------
      test(
        'the real drain hands off the job for EACH of dispatched, terminal '
        'and reconciled \u2014 the case `terminal` alone dropped',
        () async {
          const dispatchedCase = 'DEF-lane-f-dispatched';
          const terminalCase = 'DEF-lane-f-terminal';
          const reconciledCase = 'DEF-lane-f-reconciled';

          Future<_ProductionPipeline> buildCase(
            String defectId,
            String suffix,
          ) async {
            return _ProductionPipeline.build(
              db: await newDb(),
              caseRoot: caseRoot,
              repo: repo,
              registerWorker: true,
              title: 'Checkout totals disagree with the invoice screen',
              defectId: defectId,
              caseSuffix: suffix,
            );
          }

          // Three real pipelines, each with a real git worktree, a real
          // dispatch and a real verification. Only the shape of the tick
          // result handed to the drain differs.
          final dispatchedPipeline = await buildCase(dispatchedCase, 'disp');
          final terminalPipeline = await buildCase(terminalCase, 'term');
          final reconciledPipeline = await buildCase(
            reconciledCase,
            'recon',
          );

          // A real tick, so the job really is terminal and really carries a
          // real execution. This is the `dispatched`-only case the original
          // bug lost: `terminal` is EMPTY on this tick, by production design.
          final dispatchedTick = await dispatchedPipeline.tick();
          expect(dispatchedTick.dispatched, hasLength(1));
          expect(
            dispatchedTick.terminal,
            isEmpty,
            reason:
                'production under-reports here, and that is the whole reason '
                'the union exists',
          );
          expect(dispatchedTick.reconciled, isEmpty);

          final terminalTick = await terminalPipeline.tick();
          final terminalJobId = terminalTick.dispatched.single;
          final reconciledTick = await reconciledPipeline.tick();
          final reconciledJobId = reconciledTick.dispatched.single;

          // Hand each job to the real drain through exactly ONE leg of the
          // union. `SchedulerTickResult` is a plain value, so this is the
          // honest way to cover `terminal` and `reconciled` too: those legs
          // are filled by the scheduler only in narrow races that a
          // single-threaded test cannot provoke, and the drain is the code
          // under test either way.
          final onlyDispatched = SchedulerTickResult(
            reconciled: const [],
            enqueued: const [],
            dispatched: [terminalJobId],
            cancelledQueued: const [],
            deferred: const [],
            terminal: const [],
          );

          // -- leg 1: `dispatched` -----------------------------------------
          // THE B2 GUARD. With the production set narrowed to
          // `{...tickResult.terminal}` this call sees nothing, reports
          // `considered: 0`, and no TriageResult is ever written.
          final drainDispatched = await terminalPipeline.drain(onlyDispatched);
          expect(
            drainDispatched.considered,
            1,
            reason:
                'the id is in `dispatched` only; a drain that reads `terminal` '
                'alone would consider nothing and silently drop the job',
          );
          expect(drainDispatched.skipped, 0);
          expect(drainDispatched.handedOff, 1);
          expect(drainDispatched.failedJobIds, isEmpty);
          expect(
            await terminalPipeline.triageStore.readTriageResultForJob(
              terminalJobId,
            ),
            isNotNull,
            reason: 'the dropped-on-the-floor outcome this test exists for',
          );

          // -- leg 2: `terminal` -------------------------------------------
          final onlyTerminal = SchedulerTickResult(
            reconciled: const [],
            enqueued: const [],
            dispatched: const [],
            cancelledQueued: const [],
            deferred: const [],
            terminal: [terminalJobId],
          );
          final drainTerminal = await terminalPipeline.drain(onlyTerminal);
          expect(drainTerminal.considered, 1);
          expect(drainTerminal.handedOff, 1);
          expect(drainTerminal.failedJobIds, isEmpty);

          // -- leg 3: `reconciled` -----------------------------------------
          final onlyReconciled = SchedulerTickResult(
            reconciled: [reconciledJobId],
            enqueued: const [],
            dispatched: const [],
            cancelledQueued: const [],
            deferred: const [],
            terminal: const [],
          );
          final drainReconciled = await reconciledPipeline.drain(
            onlyReconciled,
          );
          expect(
            drainReconciled.considered,
            1,
            reason:
                'a claim recovered from an expired lease is adopted into a '
                'terminal state by `_adoptFromExecution` without ever being '
                'added to `terminal`, so this leg is not redundant either',
          );
          expect(drainReconciled.handedOff, 1);
          expect(drainReconciled.failedJobIds, isEmpty);
          expect(
            await reconciledPipeline.triageStore.readTriageResultForJob(
              reconciledJobId,
            ),
            isNotNull,
          );

          // And a completely empty tick does nothing, rather than treating
          // the empty union as a batch.
          final drainEmpty = await terminalPipeline.drain(
            _emptyTick(),
          );
          expect(drainEmpty.considered, 0);
          expect(drainEmpty.handedOff, 0);
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );

      // ------------------------------------------------------------------
      // Per-job isolation, which is now production behaviour at
      // `lane_i_tick_hook.dart:145` and was the reviewer's requirement 5.
      //
      // The throw is GENUINE and comes from real production code, not from a
      // stubbed processor: the job's `executionReference.agentExecutionId` is
      // repointed at an execution that does not exist, and
      // `TriageProcessor.processCompletedTriageJob` calls
      // `ExecutionStore.readExecution` uncaught, which throws
      // `ExecutionNotFoundException`. That is a realistic corruption (a
      // half-deleted execution store, a bad migration) and it is the one
      // shape of failure the drain's per-job guard exists for.
      // ------------------------------------------------------------------
      test(
        'a job that THROWS mid-batch does not stop the rest, and the throw is '
        'logged as triage.tick.job_failed',
        () async {
          const brokenCase = 'DEF-lane-f-throwing';
          const healthyCase = 'DEF-lane-f-healthy';

          // ONE pipeline carrying two triage work items, so one real tick
          // produces a two-job batch through a single processor, a single job
          // store and a single execution store. Two separate pipelines would
          // each hold their own `FileJsonExecutionStore`, and the healthy
          // job's execution would be invisible to the pipeline that drained
          // it \u2014 the batch would then fail for the wrong reason and the
          // isolation claim would be worthless.
          final pipeline = await _ProductionPipeline.build(
            db: await newDb(),
            caseRoot: caseRoot,
            repo: repo,
            registerWorker: true,
            title: 'Broken execution reference',
            defectId: brokenCase,
            caseSuffix: 'batch',
            extraDefectIds: const [healthyCase],
          );

          final tick = await pipeline.tick();
          expect(
            tick.dispatched,
            hasLength(2),
            reason: 'one real tick dispatched both work items',
          );

          // Map each job back to its work item so the batch can be ordered.
          final jobByWorkItem = <String, Job>{};
          for (final jobId in tick.dispatched) {
            final job = await pipeline.jobStore.readJob(jobId);
            expect(job!.state, JobState.succeeded, reason: 'really succeeded');
            expect(job.jobType, JobType.triageDefect);
            expect(
              job.executionReference!.agentExecutionId,
              isNotNull,
              reason: 'and really carries an execution reference',
            );
            jobByWorkItem[job.workItemId] = job;
          }
          final brokenJob = jobByWorkItem[_workItemIdFor(brokenCase)]!;
          final healthyJob = jobByWorkItem[_workItemIdFor(healthyCase)]!;

          // Repoint ONLY the broken job's execution reference at an execution
          // that does not exist. Every other field of the row is untouched, so
          // the job is still a terminal triage job and all three of the drain's
          // guards pass; the failure happens inside the processor, where the
          // production `try`/`catch` lives. This is a genuine corruption \u2014 the
          // shape a half-deleted execution store or a bad migration leaves
          // behind \u2014 not a stubbed processor.
          final db = await newDb();
          await db.execute(
            'UPDATE "job" SET "executionReferenceJson" = '
            'replace("executionReferenceJson", @from, @to) WHERE "jobId" = @jobId',
            parameters: QueryParameters.named({
              'from': brokenJob.executionReference!.agentExecutionId!,
              'to': 'agx-lane-f-does-not-exist',
              'jobId': brokenJob.jobId,
            }),
          );
          expect(
            (await pipeline.jobStore.readJob(
              brokenJob.jobId,
            ))!.executionReference!.agentExecutionId,
            'agx-lane-f-does-not-exist',
            reason: 'the corruption is in place and the job is still terminal',
          );
          expect(
            (await pipeline.jobStore.readJob(
              healthyJob.jobId,
            ))!.executionReference!.agentExecutionId,
            healthyJob.executionReference!.agentExecutionId,
            reason: 'the healthy job was not touched',
          );

          // The THROWING job first, so a regression to a bare unguarded loop
          // would abandon the healthy job and this test would fail.
          final batch = SchedulerTickResult(
            reconciled: const [],
            enqueued: const [],
            dispatched: [brokenJob.jobId, healthyJob.jobId],
            cancelledQueued: const [],
            deferred: const [],
            terminal: const [],
          );

          // If the throw escaped, this line would throw. Reaching the
          // assertions below is the isolation proof.
          final drain = await pipeline.drain(batch);
          expect(drain.considered, 2, reason: 'both ids were in the union');
          expect(drain.skipped, 0);
          expect(
            drain.handedOff,
            2,
            reason:
                'a job that threw still REACHED the processor; the drain counts '
                'it as handed off, because excluding it would make a drained '
                'job look as though it had never been reached',
          );
          expect(
            drain.failedJobIds,
            [brokenJob.jobId],
            reason: 'exactly the job whose execution was missing',
          );
          expect(drain.succeededJobIds, [healthyJob.jobId]);

          // --- the throw is logged, never silent -------------------------
          final failures = pipeline.logs
              .where((l) => l.startsWith('triage.tick.job_failed '))
              .toList();
          expect(failures, hasLength(1), reason: 'logged exactly once');
          expect(
            failures.single,
            contains('jobId: ${brokenJob.jobId}'),
            reason: 'naming the job whose outcome was dropped',
          );
          expect(
            failures.single,
            contains('error: Execution not found: agx-lane-f-does-not-exist'),
            reason:
                'carrying the real message from the real '
                'ExecutionStore.readExecution, so the log is evidence rather '
                'than a count. Production logs `e.toString()` here, which is '
                'the exception message, not its type name \u2014 so the type is '
                'asserted through the stack instead',
          );
          expect(
            failures.single,
            contains('triage_processor.dart'),
            reason:
                'the stack proves the throw came from the real '
                'TriageProcessor, not from this suite',
          );
          expect(
            failures.single,
            contains('lane_i_tick_hook.dart'),
            reason:
                'and that the production `try`/`catch` at line 143 is what '
                'caught it, so this suite did not wrap the call itself',
          );
          expect(
            failures.single,
            contains('action: job left terminal and unclassified'),
            reason: 'the log states the consequence, not just the cause',
          );

          // --- and the healthy job in the SAME batch was classified -------
          expect(
            await pipeline.triageStore.readTriageResultForJob(
              healthyJob.jobId,
            ),
            isNotNull,
            reason:
                'this is the assertion that matters: the throw did not abort '
                'the batch. A guardless loop would have dropped this result '
                'forever \u2014 the job is terminal, so nothing would retry it',
          );
          expect(
            await pipeline.triageStore.readTriageResultForJob(brokenJob.jobId),
            isNull,
            reason: 'and the broken job is honestly left unclassified',
          );
          expect(
            pipeline.logs,
            contains(startsWith('triage.processed ')),
            reason: 'the healthy job really went through the processor',
          );
        },
        timeout: const Timeout(Duration(minutes: 10)),
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

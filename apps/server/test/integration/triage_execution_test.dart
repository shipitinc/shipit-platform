import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_defect_store.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:control_plane_server/src/persistence/postgres_triage_store.dart';
import 'package:control_plane_server/src/persistence/postgres_worker_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:control_plane_server/src/triage/lane_a_defect_triage_work_item.dart';
import 'package:control_plane_server/src/triage/lane_e_design_remediation_work_item.dart';
import 'package:control_plane_server/src/triage/triage_processor.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Human-reported defect text, shared by the fixture and the assertions so a
/// change to either one shows up as a test failure rather than a silent drift.
const String _defectTitle = 'Checkout totals disagree with the invoice screen';

/// The runtime id the scheduler stamps into every triage execution request. It
/// is a *runtime selection*, not a workflow decision: the coordinator resolves
/// it through the [AgentAdapterRegistry], so tests may point it at a scripted
/// adapter without touching workflow policy.
const String _triageRuntimeTypeId = 'fake-triage';

/// A disposable, real git repository. The worker prepares a real worktree
/// pinned to an exact commit, so a fake path would prove nothing.
class _GitRepo {
  _GitRepo._(this.root);

  final Directory root;
  late final String startingRevision;

  static _GitRepo create(String path) {
    // A disposable fixture must start from nothing: a directory left behind by
    // an aborted run would make `git commit` a no-op ("nothing to commit") and
    // fail the whole scenario for the wrong reason.
    final directory = Directory(path);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    final repo = _GitRepo._(directory..createSync(recursive: true));
    repo._initialise();
    return repo;
  }

  ProcessResult _run(List<String> args) {
    final result = Process.runSync(
      'git',
      args,
      workingDirectory: root.path,
      environment: {
        ...Platform.environment,
        'GIT_AUTHOR_NAME': 'triage-test',
        'GIT_AUTHOR_EMAIL': 'triage-test@example.com',
        'GIT_COMMITTER_NAME': 'triage-test',
        'GIT_COMMITTER_EMAIL': 'triage-test@example.com',
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
      },
    );
    if (result.exitCode != 0) {
      throw StateError(
        'git ${args.join(' ')} failed (${result.exitCode}): ${result.stderr}',
      );
    }
    return result;
  }

  void _initialise() {
    _run(['init', '-b', 'main']);
    File('${root.path}/README.md').writeAsStringSync(
      '# triage execution fixture\n\nA committed baseline the worker can fork.\n',
    );
    _run(['add', '.']);
    _run(['commit', '-m', 'baseline']);
    startingRevision = _run(['rev-parse', 'HEAD']).stdout.toString().trim();
  }

  void dispose() {
    Process.runSync(
      'git',
      ['worktree', 'prune'],
      workingDirectory: root.path,
    );
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

/// A scripted [AgentSession] standing in for a provider runtime.
///
/// It behaves like a real adapter: the session is created from the durable
/// request, the terminal event is delivered on a later microtask rather than
/// synchronously, and [getResult] only settles once that terminal event has
/// actually been emitted. Nothing here touches workflow policy.
class _ScriptedTriageSession implements AgentSession {
  _ScriptedTriageSession({
    required this.config,
    required this.structuredResult,
    this.failure,
    this.interruptReason,
  });

  final AgentSessionConfig config;
  final Map<String, dynamic> structuredResult;
  final String? failure;

  /// When set, the session ends as [AgentSessionStatus.interrupted] instead of
  /// completing. That is the *transient* worker outcome
  /// (`LocalWorker` maps it to `WorkerExecutionStatus.timedOut`, which
  /// `RetryPolicy.classify` maps to `JobFailureKind.transient`), so it drives
  /// the bounded-retry path deterministically and without waiting out a real
  /// timeout.
  final String? interruptReason;

  final StreamController<AgentEvent> _events =
      StreamController<AgentEvent>.broadcast(sync: true);
  final Completer<void> _terminalEmitted = Completer<void>();

  var _status = AgentSessionStatus.starting;
  var _sequence = 0;

  @override
  String get sessionId => config.sessionId ?? 'ses-triage';

  @override
  String get executionId => config.executionId;

  @override
  String get workItemId => config.workItemId;

  @override
  AgentSessionStatus get status => _status;

  @override
  Stream<AgentEvent> get eventStream => _events.stream;

  String _nextEventId() => 'evt-triage-${_sequence++}';

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
    // A real provider reports the outcome asynchronously; the coordinator
    // must wait for the terminal contract rather than assume one.
    unawaited(Future<void>.delayed(Duration.zero, _emitTerminal));
  }

  void _emitTerminal() {
    if (_terminalEmitted.isCompleted) return;
    final failure = this.failure;
    final interruptReason = this.interruptReason;
    if (failure != null) {
      _status = AgentSessionStatus.failed;
      _emit(
        SessionFailed(
          eventId: _nextEventId(),
          timestamp: DateTime.now(),
          error: failure,
          recoverable: false,
        ),
      );
    } else if (interruptReason != null) {
      _status = AgentSessionStatus.interrupted;
      _emit(
        SessionInterrupted(
          eventId: _nextEventId(),
          timestamp: DateTime.now(),
          reason: interruptReason,
        ),
      );
    } else {
      _status = AgentSessionStatus.completed;
      _emit(
        SessionCompleted(
          eventId: _nextEventId(),
          timestamp: DateTime.now(),
          result: _buildResult(),
        ),
      );
    }
    if (!_terminalEmitted.isCompleted) _terminalEmitted.complete();
  }

  @override
  Future<AgentResult> getResult() async {
    // The result is only observable after the terminal event was delivered.
    if (!_terminalEmitted.isCompleted) await _terminalEmitted.future;
    return _buildResult();
  }

  AgentResult _buildResult() {
    final failure = this.failure;
    final interruptReason = this.interruptReason;
    final succeeded = failure == null && interruptReason == null;
    return AgentResult(
      resultId: 'res-$executionId',
      sessionId: sessionId,
      workItemId: workItemId,
      status: succeeded
          ? AgentResultStatus.completed
          : AgentResultStatus.failed,
      artifacts: const [],
      diagnostics: AgentDiagnostics(
        exitCode: succeeded ? 0 : 1,
        durationMs: 1,
        toolCalls: 1,
        errors: [
          if (!succeeded)
            DiagnosticEntry(
              code: interruptReason != null
                  ? 'SCRIPTED_AGENT_INTERRUPTION'
                  : 'SCRIPTED_AGENT_FAILURE',
              message: interruptReason ?? failure!,
              severity: 'error',
            ),
        ],
        warnings: const [],
      ),
      structuredResult: succeeded ? structuredResult : const {},
      summary: succeeded
          ? 'Triage completed by the scripted runtime'
          : 'Scripted runtime failure',
      completedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> cancel(String reason) async {
    if (_status == AgentSessionStatus.completed ||
        _status == AgentSessionStatus.failed) {
      return;
    }
    _status = AgentSessionStatus.cancelled;
    _emit(
      SessionCancelled(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );
    if (!_terminalEmitted.isCompleted) _terminalEmitted.complete();
  }

  @override
  Future<void> close() async {
    // A real provider tears the process down here. This session owns no
    // external resources; the event controller is collected with it.
  }
}

/// The scripted provider registered under [_triageRuntimeTypeId].
class _ScriptedTriageAdapter implements AgentAdapter {
  _ScriptedTriageAdapter({
    required this.structuredResult,
    this.failure,
    this.interruptFirstExecutions = 0,
  });

  final Map<String, dynamic> structuredResult;
  final String? failure;

  /// How many of the first agent sessions this adapter creates must end as
  /// [AgentSessionStatus.interrupted] instead of completing. Each retry of a
  /// transiently-failed job creates a NEW session, so this is how a test
  /// scripts "fail transiently once, then succeed" without a real timeout.
  final int interruptFirstExecutions;

  /// Sessions created so far, i.e. attempts observed by this provider.
  var sessionsCreated = 0;

  @override
  String get providerId => _triageRuntimeTypeId;

  @override
  String get displayName => 'Scripted Triage Runtime';

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
    final session = _ScriptedTriageSession(
      config: config,
      structuredResult: structuredResult,
      failure: failure,
      interruptReason: sessionsCreated < interruptFirstExecutions
          ? 'scripted transient interruption #$sessionsCreated'
          : null,
    );
    sessionsCreated++;
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
      const AdapterHealth(healthy: true, version: 'scripted-triage');

  @override
  Future<void> shutdown() async {}
}

/// One full real-path triage run: persisted Job -> Scheduler.tick ->
/// LocalWorker (real git worktree) -> CoordinatorAgentExecutionDriver ->
/// ExecutionCoordinator -> AgentRuntime -> scripted adapter -> durable
/// [TriageResult].
/// Scopes the queue reads of this suite to its own work items.
///
/// [Scheduler.tick] reads EVERY job in the shared test database and claims
/// whatever is due. Without a scope, a queued job another test file left
/// behind would be executed by this suite's worker against a repository it
/// knows nothing about. Every write still goes to the real [PostgresJobStore]
/// with its real claim CAS; only the read view is narrowed, exactly like a
/// tenant filter.
class _ScopedJobStore implements JobStore {
  /// Owns exactly the jobs belonging to [workItemIds].
  _ScopedJobStore.forWorkItems(this._delegate, Set<String> workItemIds)
    : _owns = ((job) => workItemIds.contains(job.workItemId));

  /// Owns every job whose work item id starts with [workItemIdPrefix]. Used for
  /// the triage run, whose work item is a prefix of its own child ids.
  _ScopedJobStore.forPrefix(this._delegate, String workItemIdPrefix)
    : _owns = ((job) => job.workItemId.startsWith(workItemIdPrefix));

  final JobStore _delegate;
  final bool Function(Job job) _owns;

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) =>
      _delegate.saveJob(job, expectedVersion: expectedVersion);

  @override
  Future<Job?> readJob(String jobId) => _delegate.readJob(jobId);

  @override
  Future<List<Job>> listJobs() async =>
      (await _delegate.listJobs()).where(_owns).toList();

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

/// Narrows a [WorkflowStore]'s work-item LISTING to the work items this suite
/// owns, while leaving every read/write on the real delegate untouched.
///
/// This is test isolation, not a description of production. `Scheduler.tick`
/// calls `readAllWorkItems()` to find runnable work, and
/// `test/integration` shares one PostgreSQL database with files that run
/// concurrently. Left unfiltered, a scheduler composed here would also see
/// another file's `designRequired` work item and enqueue a real
/// `JobType.designRevision` row for it. Only the listing is narrowed; a read of
/// a specific work item id still resolves against the real store, so a
/// scheduler can never be tricked into believing a foreign item is missing.
class _ScopedWorkflowStore implements WorkflowStore {
  _ScopedWorkflowStore(this._delegate, this._isOwned);

  final WorkflowStore _delegate;
  final bool Function(WorkItem item) _isOwned;

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _delegate.readWorkItem(workItemId);

  @override
  Future<List<WorkItem>> readAllWorkItems() async =>
      (await _delegate.readAllWorkItems()).where(_isOwned).toList();

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

class _TriageRun {
  _TriageRun({
    required this.runId,
    required this.db,
    required this.caseRoot,
    required this.repo,
    required this.executionStoreFile,
    required this.defectId,
    required this.workItemId,
    required this.evidenceIds,
    required this.tick,
    required this.job,
    required this.scheduler,
    required this.jobStore,
    required this.processor,
    required this.triageStore,
    required this.defectStore,
    required this.workflowStore,
    required this.workflowEngine,
    required this.coordinator,
    required this.workerStore,
  });

  final String runId;
  final PersistenceDatabase db;
  final Directory caseRoot;
  final _GitRepo repo;
  final File executionStoreFile;
  final String defectId;
  final String workItemId;
  final List<String> evidenceIds;
  final SchedulerTickResult tick;
  final Job job;
  final Scheduler scheduler;
  final PostgresJobStore jobStore;
  final TriageProcessor processor;
  final PostgresTriageStore triageStore;
  final PostgresDefectStore defectStore;
  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final ExecutionCoordinator coordinator;
  final PostgresWorkerStore workerStore;

  String get designRemediationWorkItemId => 'design-remediation-$defectId';

  /// A *real* design-revision scheduler, composed the way
  /// `apps/server/lib/server.dart` composes the triage scheduler: the canonical
  /// [designRevisionDefinition] plus the canonical
  /// [designRevisionDedupeKey] / [designRevisionInstruction] /
  /// [designRevisionRequest] builders, a real [LocalWorker] holding the
  /// definition's real `penpotWrite` + `visualDesign` capabilities, and a real
  /// [WorkerDispatcher].
  ///
  /// `apps/server/lib/server.dart` does not compose a design scheduler at all,
  /// so "the design lane did not pick this up" cannot be proved by observing
  /// the shipping server. It is proved here by ticking a design scheduler that
  /// is wired exactly like the triage one and watching it decline to act.
  ///
  /// Both read views are narrowed to [workItemIds] (see [_ScopedWorkflowStore]
  /// and [_ScopedJobStore]) so a concurrent test file's `designRequired` work
  /// item cannot make this scheduler enqueue a `JobType.designRevision` row for
  /// someone else's work. Writes stay on the real Postgres stores.
  Scheduler designRevisionSchedulerOver(List<String> workItemIds) {
    final owned = workItemIds.toSet();
    final designWorker = LocalWorker(
      // `w-design-r*` is swept by `purgeSuiteRows` alongside the triage worker.
      workerId: 'w-design-r$runId',
      poolId: 'design-agent-pool',
      capabilities: const {
        WorkerCapability.linux,
        WorkerCapability.penpotWrite,
        WorkerCapability.visualDesign,
      },
      workspaceManager: GitWorktreeWorkspaceManager(
        workspaceRoot: '${caseRoot.path}/workspaces',
      ),
      executionDriver: CoordinatorAgentExecutionDriver(coordinator),
      workerStore: workerStore,
      platform: 'local-test',
    );
    return Scheduler(
      schedulerId: 'sched-design-r$runId',
      workflowStore: _ScopedWorkflowStore(
        workflowStore,
        (item) => owned.contains(item.workItemId),
      ),
      jobStore: _ScopedJobStore.forWorkItems(jobStore, owned),
      workerStore: workerStore,
      dispatch: WorkerDispatcherAdapter(
        WorkerDispatcher(registry: WorkerRegistry()..register(designWorker)),
      ),
      definition: designRevisionDefinition,
      workload: SchedulerWorkload(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: 60,
        runtimeTypeId: _triageRuntimeTypeId,
      ),
      dedupeKeyBuilder: designRevisionDedupeKey,
      instructionBuilder: designRevisionInstruction,
      requestBuilder: designRevisionRequest,
    );
  }

  /// The durable `triage_result` row, read as raw SQL.
  ///
  /// Used to assert the row genuinely landed in Postgres. The typed
  /// [PostgresTriageStore] read path is covered separately by the
  /// 'production defect: typed triage readback' test below, which guards the
  /// row decoder against regressing back to raw casts.
  Future<Map<String, dynamic>?> triageResultRow(String resultId) async {
    final rows = await db.query(
      'SELECT * FROM "triage_result" WHERE "resultId" = @resultId',
      parameters: QueryParameters.named({'resultId': resultId}),
    );
    if (rows.isEmpty) return null;
    return rows.first.toColumnMap();
  }

  Future<List<Map<String, dynamic>>> triageResultRowsForDefect() async {
    final rows = await db.query(
      'SELECT * FROM "triage_result" WHERE "defectId" = @defectId',
      parameters: QueryParameters.named({'defectId': defectId}),
    );
    return rows.map((row) => row.toColumnMap()).toList();
  }

  Future<TriageResult?> process() => processor.processCompletedTriageJob(job);

  /// A brand new processor over a brand new execution store backed by the same
  /// file, i.e. what a restarted server would observe.
  ///
  /// Note what this is and is not: a fresh [FileJsonExecutionStore] instance
  /// reading the same on-disk file in the SAME OS process, plus a fresh
  /// [PostgresTriageStore] handle onto the SAME database. It exercises
  /// "no in-memory state carried the result across the call" and is therefore
  /// evidence the durable read path works. It is NOT a process restart — a real
  /// restart is exercised by the test file that spawns a separate process,
  /// because nothing in this suite can tear down the Serverpod instance that
  /// owns the session without taking the test runner with it.
  _TriageRun restarted({required PersistenceDatabase db}) {
    final store = FileJsonExecutionStore(executionStoreFile);
    final runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(_ScriptedTriageAdapter(structuredResult: const {})),
    );
    return _TriageRun(
      runId: runId,
      db: db,
      caseRoot: caseRoot,
      repo: repo,
      executionStoreFile: executionStoreFile,
      defectId: defectId,
      workItemId: workItemId,
      evidenceIds: evidenceIds,
      tick: tick,
      job: job,
      scheduler: scheduler,
      jobStore: jobStore,
      triageStore: triageStore,
      defectStore: defectStore,
      workflowStore: workflowStore,
      workflowEngine: workflowEngine,
      coordinator: ExecutionCoordinator(
        store: store,
        workflowEngine: workflowEngine,
        runtime: runtime,
      ),
      workerStore: PostgresWorkerStore(db),
      processor: TriageProcessor(
        db: db,
        workflowStore: workflowStore,
        workflowEngine: workflowEngine,
        executionCoordinator: ExecutionCoordinator(
          store: store,
          workflowEngine: workflowEngine,
          runtime: runtime,
        ),
        defectStore: defectStore,
        triageStore: triageStore,
      ),
    );
  }

  /// Removes only the rows this run created and then drops the git fixture.
  ///
  /// Deliberately a targeted DELETE rather than a TRUNCATE: the integration
  /// suite shares one PostgreSQL database with other test files that run
  /// concurrently, and truncating `job`/`work_item` out from under them
  /// breaks their assertions. Every identifier below carries the run id, so
  /// this cannot touch a row this suite did not create.
  Future<void> dispose() async {
    await purgeSuiteRows(db);
    repo.dispose();
    if (caseRoot.existsSync()) caseRoot.deleteSync(recursive: true);
  }
}

/// Deletes every row this suite could have created, in an order that satisfies
/// foreign keys.
///
/// A targeted DELETE, never a TRUNCATE: `test/integration` shares one
/// PostgreSQL database with other test files that run concurrently, and
/// truncating `job`/`work_item` out from under them breaks their assertions.
/// Every marker below is namespaced to this suite, so no other file's row can
/// match. The same purge runs in setUp because a previous run that aborted
/// mid-test leaves rows behind, and re-creating that defect would then violate
/// a unique constraint.
Future<void> purgeSuiteRows(PersistenceDatabase db) async {
  const defect = 'DEF-triage-r%';
  const workItem = '%DEF-triage-r%';
  const worker = 'w-triage-r%';
  // The design-lane control worker built by `designRevisionSchedulerOver`, and
  // the control work item it is given, are also this suite's rows.
  const designWorker = 'w-design-r%';
  // One statement per call: the driver sends a parameterised command as a
  // prepared statement, which accepts exactly one command at a time.
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
    // B8 made `ControlPlaneService.createDefect` provision a real
    // `QAContract` for every triage work item, so this suite's intake now
    // writes one `qa_contract` row per defect it creates. `qa_contract` is
    // keyed by `qa-triage-<defectId>` and carries no FK to `defect` or
    // `work_item`, so none of the statements above reach it. Without this the
    // suite leaks one orphaned advisory declaration per run forever.
    'DELETE FROM "qa_contract" WHERE "contractId" LIKE '
        '\'qa-triage-$defect%\'',
    // `worker_event` has no `workerId` column — it is keyed by
    // `workItemId`/`workerExecutionId`, so the design-lane rows it holds are
    // already covered by the `worker_event` statement above, whose marker
    // matches the control work item id too.
    'DELETE FROM "worker_result"        WHERE "workerId" LIKE \'$designWorker\'',
    'DELETE FROM "worker_execution"     WHERE "workerId" LIKE \'$designWorker\'',
    'DELETE FROM "worker_registration"  WHERE "workerId" LIKE \'$designWorker\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

Map<String, dynamic> _triageStructuredResult({
  required String classification,
  String status = 'triaging',
  double confidence = 0.9,
  String suspectedCategory = 'backend',
  List<String> suspectedComponents = const ['api', 'database'],
  bool reproductionSupported = true,
  List<String> evidenceUsed = const [],
  List<Map<String, String>> clarificationRequired = const [],
  String recommendedNextAction = 'fix',
  String summary = 'Classified the reported defect from its evidence.',
}) {
  return {
    'classification': classification,
    'status': status,
    'confidence': confidence,
    'suspectedCategory': suspectedCategory,
    'suspectedComponents': suspectedComponents,
    'reproductionSupported': reproductionSupported,
    'evidenceUsed': evidenceUsed,
    'clarificationRequired': clarificationRequired,
    'recommendedNextAction': recommendedNextAction,
    'summary': summary,
  };
}

/// The intake evidence persisted for run [runId]. The scripted agent's
/// `evidenceUsed` is derived from this, so a claimed evidence id always has to
/// correspond to a real row.
String evidenceIdFor(String runId) => 'ev-$runId-1';

/// Run ids are namespaced (`triage-r7`) so this suite can find -- and only
/// ever delete -- its own rows in the shared integration database.
String _nextRunId(int counter) => 'triage-r${counter + 1}';

/// Creates the real defect, its evidence, and a work item parked at
/// `designNotRequired` -- the only state the triage definition dispatches from.
Future<void> _seedTriageWorkItem({
  required DurableWorkflowEngine engine,
  required PostgresDefectStore defectStore,
  required String runId,
}) async {
  final defectId = 'DEF-$runId';
  final now = DateTime.now().toUtc();
  final evidenceId = evidenceIdFor(runId);

  await defectStore.saveDefect(
    Defect(
      defectId: defectId,
      title: _defectTitle,
      description:
          'A human reported the checkout total diverges from the invoice.',
      expectedBehavior: 'Checkout total equals the invoice total.',
      reproductionSteps:
          '1. Add two items\n2. Open checkout\n3. Compare invoice',
      severity: 'high',
      status: DefectStatus.reported,
      reporter: 'reporter@example.com',
      createdAt: now,
      updatedAt: now,
      version: 1,
    ),
  );
  await defectStore.saveDefectEvidence(
    DefectEvidence(
      evidenceId: evidenceId,
      defectId: defectId,
      kind: EvidenceIntakeKind.textDescription,
      description: 'Invoice shows 42.00 while checkout shows 47.00.',
      sourceRef: 'intake-form',
      capturedAt: now,
      createdAt: now,
    ),
  );
  await defectStore.appendDefectEvent(
    DefectEvent(
      eventId: 'evt-$runId-created',
      defectId: defectId,
      sequence: 1,
      type: DefectEventType.created,
      toStatus: DefectStatus.reported,
      actorType: ActorType.human,
      actorId: 'reporter@example.com',
      payloadJson: jsonEncode({'severity': 'high'}),
      occurredAt: now,
    ),
  );

  await engine.createWorkItem(
    workItemId: 'defect-$defectId',
    productId: 'defects',
    category: WorkItemCategory.feature,
    title: 'Triage defect $defectId',
    description:
        'A human reported defect awaiting automated triage by the platform.',
    qaContractId: 'qa-$defectId',
    featureRef: defectId,
    metadata: {
      'defectId': defectId,
      'defectTitle': _defectTitle,
      'defectSeverity': 'high',
      'defectEvidence': jsonEncode([
        {
          'evidenceId': evidenceId,
          'description': 'Invoice 42.00 vs checkout 47.00',
        },
      ]),
    },
  );
  await engine.transition(
    workItemId: 'defect-$defectId',
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
    context: {'featureRef': defectId},
  );
  await engine.transition(
    workItemId: 'defect-$defectId',
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: {'featureRef': defectId},
  );
  await engine.transition(
    workItemId: 'defect-$defectId',
    to: WorkItemState.designNotRequired,
    trigger: TransitionTrigger.systemEvent,
  );
}

Future<_TriageRun> _dispatchTriage({
  required PersistenceDatabase db,
  required String runId,
  required Map<String, dynamic> structuredResult,
  String? agentFailure,
  int interruptFirstExecutions = 0,
  DateTime Function()? clock,
}) async {
  final caseRoot = Directory(
    '${Directory.systemTemp.path}/shipit_triage_run_$runId',
  )..createSync(recursive: true);
  final repo = _GitRepo.create('${caseRoot.path}/source_repo');
  final executionStoreFile = File('${caseRoot.path}/execution/executions.json');

  // Default the scripted agent's `evidenceUsed` to the evidence id that really
  // exists on this run's defect, so a test that does not care about the claim
  // still produces a coherent one.
  //
  // This is a HARNESS convenience, not a production guarantee: nothing in
  // `TriageProcessor._parseTriageResult` checks the ids against the defect's
  // evidence, so the coherence here comes from this substitution and nowhere
  // else. The 'production does not validate evidenceUsed' test below pins the
  // gap explicitly rather than letting this comment overstate what production
  // does. An empty structured result is left untouched: its whole point is that
  // there is nothing to claim.
  final claimedEvidence = structuredResult['evidenceUsed'];
  final effectiveStructuredResult = structuredResult.isEmpty
      ? structuredResult
      : {
          ...structuredResult,
          'evidenceUsed': claimedEvidence is List && claimedEvidence.isNotEmpty
              ? claimedEvidence
              : [evidenceIdFor(runId)],
        };

  final workflowStore = PostgresWorkflowStore(db);
  final jobStore = PostgresJobStore(db);
  final workerStore = PostgresWorkerStore(db);
  final defectStore = PostgresDefectStore(db);
  final triageStore = PostgresTriageStore(db);
  final engine = DurableWorkflowEngine(store: workflowStore);

  final runtime = AgentRuntime(
    registry: AgentAdapterRegistry()
      ..register(
        _ScriptedTriageAdapter(
          structuredResult: effectiveStructuredResult,
          failure: agentFailure,
          interruptFirstExecutions: interruptFirstExecutions,
        ),
      ),
  );
  final coordinator = ExecutionCoordinator(
    store: FileJsonExecutionStore(executionStoreFile),
    workflowEngine: engine,
    runtime: runtime,
    // Real, platform-runner verification executed inside the isolated
    // worktree. A failing check would turn this into an executedFail job, so
    // a green job is proof the verifier really ran and really passed.
    verificationPlan: const VerificationPlan(
      command: ['git', 'rev-parse', '--verify', 'HEAD^{commit}'],
      checkName: 'git_worktree_head',
    ),
  );

  final worker = LocalWorker(
    workerId: 'w-triage-$runId',
    poolId: 'triage-pool',
    capabilities: const {
      WorkerCapability.linux,
      WorkerCapability.git,
    },
    workspaceManager: GitWorktreeWorkspaceManager(
      workspaceRoot: '${caseRoot.path}/workspaces',
    ),
    executionDriver: CoordinatorAgentExecutionDriver(coordinator),
    workerStore: workerStore,
    platform: 'local-test',
  );
  final dispatcher = WorkerDispatcher(
    registry: WorkerRegistry()..register(worker),
  );

  final scopedJobStore = _ScopedJobStore.forPrefix(
    jobStore,
    'defect-DEF-$runId',
  );
  final scheduler = Scheduler(
    schedulerId: 'sched-triage-$runId',
    workflowStore: _ScopedWorkflowStore(
      workflowStore,
      (item) => item.workItemId.startsWith('defect-DEF-$runId'),
    ),
    jobStore: scopedJobStore,
    workerStore: workerStore,
    dispatch: WorkerDispatcherAdapter(dispatcher),
    definition: triageDefectDefinition,
    workload: SchedulerWorkload(
      repositoryPath: repo.root.path,
      startingRevision: repo.startingRevision,
      timeoutSeconds: 60,
      runtimeTypeId: _triageRuntimeTypeId,
    ),
    dedupeKeyBuilder: triageDefectDedupeKey,
    instructionBuilder: triageDefectInstruction,
    requestBuilder: triageDefectRequest,
    clock: clock,
  );

  await _seedTriageWorkItem(
    engine: engine,
    defectStore: defectStore,
    runId: runId,
  );

  final tick = await scheduler.tick();
  if (tick.dispatched.length != 1) {
    repo.dispose();
    throw StateError(
      'expected exactly one dispatched triage job, got ${tick.dispatched}',
    );
  }
  final job = await jobStore.readJob(tick.dispatched.single);
  if (job == null) {
    repo.dispose();
    throw StateError('dispatched job ${tick.dispatched.single} is unreadable');
  }

  return _TriageRun(
    runId: runId,
    db: db,
    caseRoot: caseRoot,
    repo: repo,
    executionStoreFile: executionStoreFile,
    defectId: 'DEF-$runId',
    workItemId: 'defect-DEF-$runId',
    evidenceIds: [evidenceIdFor(runId)],
    tick: tick,
    job: job,
    scheduler: scheduler,
    jobStore: jobStore,
    processor: TriageProcessor(
      db: db,
      workflowStore: workflowStore,
      workflowEngine: engine,
      executionCoordinator: coordinator,
      defectStore: defectStore,
      triageStore: triageStore,
    ),
    triageStore: triageStore,
    defectStore: defectStore,
    workflowStore: workflowStore,
    workflowEngine: engine,
    coordinator: coordinator,
    workerStore: workerStore,
  );
}

void main() {
  final openSessions = <Session>[];
  var runCounter = 0;

  /// Opens a Serverpod session and returns it, so a test can also drive the
  /// typed endpoints, which take a [Session] rather than a database handle.
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
    'durable triage execution: Job -> Scheduler.tick -> LocalWorker -> coordinator -> AgentRuntime -> TriageResult',
    (sessionBuilder, endpoints) {
      setUp(() async => purgeSuiteRows(await newDb()));
      tearDown(() async {
        for (final session in List.of(openSessions)) {
          await session.close();
        }
        openSessions.clear();
      });

      group('real triage execution path', () {
        test(
          'a persisted triage work item is dispatched, executed, verified and '
          'persisted as a TriageResult',
          () async {
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.implementationDefect.wire,
              ),
            );
            addTearDown(run.dispose);

            // The scheduler really dispatched through the real worker.
            expect(run.tick.dispatched, hasLength(1));
            expect(run.job.jobType, JobType.triageDefect);
            expect(run.job.workItemId, run.workItemId);
            expect(run.job.state, JobState.succeeded);
            expect(run.job.attempt, 1);
            expect(run.job.failure, isNull);

            // The real triage instruction builder produced the agent prompt
            // from the durable work item metadata, and that prompt identifies
            // THIS defect. The id and the evidence ids are run-specific, which
            // is what gives these teeth: a job built for another defect, or for
            // this one from stale metadata, carries different values and fails.
            expect(run.job.instruction, contains(run.defectId));
            expect(run.job.instruction, contains(_defectTitle));
            for (final evidenceId in run.evidenceIds) {
              expect(run.job.instruction, contains(evidenceId));
            }

            // The closed-vocabulary fields this result carries, as JSON values --
            // the shape the triage parser actually reads -- spelled with the
            // live `.wire` token, not a literal echoed from the template.
            // Renaming an enum fails here instead of un-parsing real output.
            final classificationWire =
                DefectClassification.implementationDefect.wire;
            final statusWire = DefectStatus.triaging.wire;
            expect(
              run.job.instruction,
              contains('"classification": "$classificationWire"'),
            );
            expect(run.job.instruction, contains('"status": "$statusWire"'));
            expect(
              run.job.instruction,
              isNot(contains('DESIGN_DEFECT')),
              reason:
                  'the vocabulary is documented as wire tokens, never as '
                  'SCREAMING_CASE enum names. An agent that follows '
                  '`DESIGN_DEFECT` returns text `DefectClassification.fromWire` '
                  'rejects, so the whole triage outcome is lost.',
            );

            // The adapter's parsing contract: the agent's final assistant text
            // is parsed as bare JSON, so the prompt must keep forbidding prose
            // around it. Dropping that rule would leave the agent free to
            // narrate, and the parse would silently return nothing.
            expect(
              run.job.instruction,
              contains('Do NOT include any prose outside the JSON output'),
            );

            // The job is bound to a durable agent execution.
            final executionId = run.job.executionReference?.agentExecutionId;
            expect(executionId, isNotNull);

            final execution = await run.coordinator.store.readExecution(
              executionId!,
            );
            expect(execution.status, AgentSessionStatus.completed);
            expect(execution.isTerminal, isTrue);

            // The platform verifier really ran, inside the isolated worktree.
            final verifications = await run.coordinator.store.readVerifications(
              executionId,
            );
            expect(verifications, hasLength(1));
            expect(verifications.single.status, AgentClaimStatus.passed);
            expect(verifications.single.checkName, 'git_worktree_head');
            expect(verifications.single.resultPath, contains('workspaces'));

            // The role is stamped by the coordinator, never by the agent.
            final agentResult = await run.coordinator.store.readResult(
              executionId,
            );
            expect(agentResult?.role, AgentRole.triageDefect);
            expect(agentResult?.executionId, executionId);

            // The coordinator drove the work item out of execution.
            final item = await run.workflowStore.readWorkItem(run.workItemId);
            expect(item.state, WorkItemState.agentCompleted);

            // The processor turned the structured result into a TriageResult.
            final result = await run.process();
            expect(result, isNotNull);
            expect(result!.jobId, run.job.jobId);
            expect(result.executionId, executionId);
            expect(result.defectId, run.defectId);
            expect(
              result.recommendedClassification,
              DefectClassification.implementationDefect,
            );
            expect(result.recommendedStatus, DefectStatus.triaging);
            expect(result.confidence, 0.9);
            expect(result.suspectedCategory, 'backend');
            expect(result.suspectedComponents, ['api', 'database']);
            expect(result.reproductionSupported, isTrue);
            expect(result.recommendedNextAction, 'fix');
            expect(result.clarificationRequired, isEmpty);
            expect(result.evidenceUsed, run.evidenceIds);
            expect(result.possibleDuplicateDefectId, isNull);

            // The evidence it cited really exists on the defect.
            final evidence = await run.defectStore.readEvidenceForDefect(
              run.defectId,
            );
            expect(
              evidence.map((e) => e.evidenceId).toSet(),
              run.evidenceIds.toSet(),
            );

            // The TriageResult is durable in Postgres, not just returned.
            final persisted = await run.triageResultRow(result.resultId);
            expect(persisted, isNotNull);
            expect(persisted!['defectId'], run.defectId);
            expect(persisted['jobId'], run.job.jobId);
            expect(persisted['executionId'], executionId);
            expect(
              persisted['recommendedClassification'],
              DefectClassification.implementationDefect.wire,
            );
            expect(
              persisted['suspectedComponents'],
              ['api', 'database'],
            );
            expect(persisted['evidenceUsed'], run.evidenceIds);
            expect(
              persisted['clarificationRequired'],
              isA<String>(),
              reason:
                  'the raw `text` column is JSON, never a Dart List. Decoding it '
                  'is the typed reader\'s job and is asserted with a '
                  'NON-EMPTY payload (an empty list would pass a broken '
                  'decoder) in the "non-empty clarifications survive a restart '
                  'in both read paths" test below',
            );

            // The defect keeps its human-reported state and gains only the
            // triage reference: triage is advisory, it never closes anything.
            final defect = await run.defectStore.readDefect(run.defectId);
            expect(defect.status, DefectStatus.reported);
            expect(defect.classification, isNull);
            final metadata =
                jsonDecode(defect.metadataJson!) as Map<String, dynamic>;
            expect(metadata['triageResultId'], result.resultId);
            expect(
              metadata['triageClassification'],
              DefectClassification.implementationDefect.wire,
            );
          },
        );

        test('a restart observes the same durable TriageResult', () async {
          final db = await newDb();
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: _triageStructuredResult(
              classification: DefectClassification.requirementGap.wire,
            ),
          );
          addTearDown(run.dispose);

          final first = await run.process();
          expect(first, isNotNull);

          final restarted = run.restarted(db: db);
          final second = await restarted.process();
          expect(second, isNotNull);
          expect(second!.resultId, first!.resultId);
          final persisted = await restarted.triageResultRow(first.resultId);
          expect(persisted, isNotNull);
          expect(persisted!['jobId'], run.job.jobId);
          expect(await restarted.triageResultRowsForDefect(), hasLength(1));
        });

        test('reprocessing the same job is idempotent', () async {
          final db = await newDb();
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: _triageStructuredResult(
              classification: DefectClassification.environmentDefect.wire,
            ),
          );
          addTearDown(run.dispose);

          final first = await run.process();
          final second = await run.process();
          expect(first, isNotNull);
          expect(second?.resultId, first!.resultId);
          expect(await run.triageResultRowsForDefect(), hasLength(1));
        });

        test('a second tick does not enqueue a duplicate job', () async {
          final db = await newDb();
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: _triageStructuredResult(
              classification: DefectClassification.implementationDefect.wire,
            ),
          );
          addTearDown(run.dispose);

          final secondTick = await run.scheduler.tick();
          expect(secondTick.dispatched, isEmpty);
          expect(
            await run.jobStore.listJobsForWorkItem(run.workItemId),
            hasLength(1),
          );
        });
      });

      group('classification routing', () {
        for (final classification in const [
          DefectClassification.implementationDefect,
          DefectClassification.designDefect,
          DefectClassification.requirementGap,
          DefectClassification.environmentDefect,
        ]) {
          test('${classification.wire} is persisted verbatim', () async {
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: classification.wire,
              ),
            );
            addTearDown(run.dispose);

            expect(run.job.state, JobState.succeeded);
            final result = await run.process();
            expect(result, isNotNull);
            expect(
              result!.recommendedClassification.wire,
              classification.wire,
            );
            final persisted = await run.triageResultRow(result.resultId);
            expect(
              persisted?['recommendedClassification'],
              classification.wire,
            );
            expect(
              await run.triageResultRowsForDefect(),
              hasLength(1),
            );
          });
        }

        test(
          'DESIGN_DEFECT stops at a real, honestly-blocked remediation item',
          () async {
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.designDefect.wire,
                // The components the agent actually pointed at. The remediation
                // request has to carry THESE, not the classification string.
                suspectedComponents: const ['checkout', 'invoice-render'],
              ),
            );
            addTearDown(run.dispose);

            final result = await run.process();
            expect(result, isNotNull);

            final remediation = await run.workflowStore.readWorkItem(
              run.designRemediationWorkItemId,
            );

            // The stop is `planned`, not `designRequired`.
            //
            // `designRequired` would assert that a `DesignRevision` is
            // outstanding and a design agent is about to run. No such agent
            // exists in shipit-platform, so that state is a fabricated claim
            // about work in flight. `planned` is the last state reachable
            // without a design artifact, and the reason is recorded in metadata
            // rather than implied by the state (ADR 0021).
            expect(remediation.state, WorkItemState.planned);
            expect(remediation.featureRef, run.defectId);

            // The reason is durable, not a comment in the test.
            expect(remediation.metadata![designRemediationRequiredKey], isTrue);
            expect(
              remediation.metadata![designGovernanceRuntimeKey],
              designGovernanceRuntimeUnavailable,
            );
            expect(
              remediation.metadata![blockedByKey],
              externalDesignGovernanceDependency,
            );
            expect(
              remediation.description,
              contains(externalDesignGovernanceDependency),
              reason:
                  'a human reading this work item has to be able to see why it '
                  'is stuck without reading the source',
            );

            // Filed under the same product its triage parent resolved to. The
            // defect carries no `affectedWorkItemId`, so the resolution falls
            // back to the shared `defects` bucket.
            final triageParent = await run.workflowStore.readWorkItem(
              run.workItemId,
            );
            expect(remediation.productId, triageParent.productId);
            expect(remediation.productId, defectTriageBucketProductId);

            final request = DesignRemediationRequest.fromJson(
              Map<String, dynamic>.from(
                remediation.metadata!['designRemediationRequest']!
                    as Map<String, dynamic>,
              ),
            );
            expect(request.classification, DefectClassification.designDefect);
            expect(request.triageResultId, result!.resultId);
            expect(request.evidenceRefs, run.evidenceIds);

            // The defect's OWN title, not the agent's `suspectedCategory`. The
            // category is a hypothesis and belongs in the description, where
            // it is read as one.
            expect(request.defectTitle, _defectTitle);
            expect(request.defectTitle, isNot(contains('DESIGN_DEFECT')));
            expect(request.defectTitle, remediation.title.split(': ').last);
            expect(
              request.designFlawDescription,
              'backend: checkout, invoice-render',
            );
            expect(request.designFlawDescription, contains('backend'));
          },
        );

        test(
          'a real design scheduler does not dispatch a design revision for '
          'the blocked remediation item',
          () async {
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.designDefect.wire,
              ),
            );
            addTearDown(run.dispose);
            expect(await run.process(), isNotNull);

            // A control item parked in a real `designRequired`, owned by this
            // run. It is the positive control: it proves the scheduler below is
            // actually able to enqueue and dispatch a design revision, so the
            // "did not dispatch" assertion that follows is a real stop and not a
            // dead harness.
            final controlWorkItemId = 'design-control-DEF-${run.runId}';
            final engine = run.workflowEngine;
            await engine.createWorkItem(
              workItemId: controlWorkItemId,
              productId: defectTriageBucketProductId,
              category: WorkItemCategory.feature,
              title: 'Design control item for ${run.runId}',
              description:
                  'Suite-owned control work item used to prove the design '
                  'scheduler really does dispatch when an item awaits design.',
              designContractId: 'dc-${run.runId}',
              // The coordinator completes the execution by transitioning
              // `agentExecuting -> agentCompleted`, and that transition is
              // guarded on a QA contract existing. Without one the control job
              // would fail for an unrelated reason.
              qaContractId: 'qa-${run.runId}',
            );
            await engine.transition(
              workItemId: controlWorkItemId,
              to: WorkItemState.planning,
              trigger: TransitionTrigger.systemEvent,
            );
            await engine.transition(
              workItemId: controlWorkItemId,
              to: WorkItemState.planned,
              trigger: TransitionTrigger.systemEvent,
              context: {'featureRef': run.defectId},
            );
            await engine.transition(
              workItemId: controlWorkItemId,
              to: WorkItemState.designRequired,
              trigger: TransitionTrigger.systemEvent,
              context: {'designContractId': 'dc-${run.runId}'},
            );

            final designScheduler = run.designRevisionSchedulerOver([
              run.designRemediationWorkItemId,
              controlWorkItemId,
            ]);
            final tick = await designScheduler.tick();

            // Positive control fired: the real scheduler, real worker and real
            // coordinator produced a real design-revision job.
            expect(tick.dispatched, hasLength(1));
            final controlJob = await run.jobStore.readJob(
              tick.dispatched.single,
            );
            expect(controlJob!.jobType, JobType.designRevision);
            expect(controlJob.workItemId, controlWorkItemId);
            expect(controlJob.requiredRole, AgentRole.designAgent);
            expect(controlJob.state, JobState.succeeded);
            expect(
              controlJob.requiredCapabilities,
              designRevisionDefinition.requiredCapabilities,
            );

            // The blocked item was offered to the same scheduler in the same
            // tick and produced no job at all: the tick enqueued exactly the
            // control and nothing else, and no job row exists for the
            // remediation work item.
            expect(tick.enqueued, hasLength(1));
            final remediationJobs = await run.jobStore.listJobsForWorkItem(
              run.designRemediationWorkItemId,
            );
            expect(remediationJobs, isEmpty);

            // Why: the honest stop state is not an entry state of the design
            // definition, so `RunnableWorkEvaluator` classifies it `noAction`.
            expect(
              designRevisionDefinition.entryStates,
              {WorkItemState.designRequired, WorkItemState.designRejected},
            );
            expect(
              designRevisionDefinition.entryStates.contains(
                WorkItemState.planned,
              ),
              isFalse,
            );
          },
        );

        test(
          'a non-design classification opens no remediation work item',
          () async {
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.implementationDefect.wire,
              ),
            );
            addTearDown(run.dispose);

            expect(await run.process(), isNotNull);
            // Scoped to this run: the shared integration database legitimately
            // holds work items belonging to other test files.
            final workItemIds = (await run.workflowStore.readAllWorkItems())
                .map((item) => item.workItemId)
                .where((id) => id.contains('DEF-${run.runId}'))
                .toSet();
            expect(workItemIds, {run.workItemId});
            expect(
              workItemIds,
              isNot(contains(run.designRemediationWorkItemId)),
            );
          },
        );
      });

      group('clarification routing', () {
        test(
          'non-empty clarifications survive a restart in both read paths',
          () async {
            final db = await newDb();
            const question = 'Which client is affected?';
            const reason = 'The report does not identify the client surface.';
            const secondQuestion = 'Which invoice provider is in use?';
            const secondReason = 'Checkout and invoice disagree by 5.00.';
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.requirementGap.wire,
                confidence: 0.35,
                recommendedNextAction: 'clarify',
                clarificationRequired: const [
                  {'question': question, 'reason': reason},
                  {'question': secondQuestion, 'reason': secondReason},
                ],
              ),
            );
            addTearDown(run.dispose);

            final result = await run.process();
            expect(result!.clarificationRequired, hasLength(2));

            // The raw `text` column really is JSON text, not a list. This is
            // the shape the typed reader has to decode.
            final persisted = await run.triageResultRow(result.resultId);
            expect(persisted!['clarificationRequired'], isA<String>());
            expect(
              jsonDecode(persisted['clarificationRequired']! as String),
              hasLength(2),
            );

            // Read 1: the owning store, in a fresh instance over the same
            // database — a stand-in for a restarted server.
            final reread = await run
                .restarted(db: db)
                .triageStore
                .readTriageResult(result.resultId);
            expect(reread!.clarificationRequired, hasLength(2));
            expect(
              reread.clarificationRequired.map((c) => c.question).toList(),
              [question, secondQuestion],
            );
            expect(
              reread.clarificationRequired.map((c) => c.reason).toList(),
              [reason, secondReason],
            );

            // Read 2: `PostgresDefectStore` delegates the same three triage
            // reads to `PostgresTriageStore`, so a caller holding only a
            // defect store must see identical typed data, not a second
            // divergent decoder.
            final viaDefectStore = await run.defectStore.readTriageResult(
              result.resultId,
            );
            expect(viaDefectStore, reread);

            final viaJob = await run.defectStore.readTriageResultForJob(
              run.job.jobId,
            );
            expect(viaJob, reread);
            expect(
              (await run.defectStore.readTriageResultsForDefect(
                run.defectId,
              )).single,
              reread,
            );

            // And the durable side effect the clarifications caused is real.
            final clarifications = await run.defectStore
                .readClarificationsForDefect(run.defectId);
            expect(clarifications, hasLength(2));
            expect(
              clarifications.map((c) => c.question).toSet(),
              {question, secondQuestion},
            );
            expect(
              clarifications.every(
                (c) => c.requestedByTriageJobId == run.job.jobId,
              ),
              isTrue,
            );
          },
        );

        test(
          'PRODUCTION DEFECT: replaying a job with clarifications appends a '
          'second copy of each row',
          () async {
            final db = await newDb();
            const question = 'Which client is affected?';
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.requirementGap.wire,
                recommendedNextAction: 'clarify',
                clarificationRequired: const [
                  {
                    'question': question,
                    'reason': 'The report does not identify the client.',
                  },
                ],
              ),
            );
            addTearDown(run.dispose);

            final first = await run.process();
            expect(first!.clarificationRequired, hasLength(1));
            expect(
              await run.defectStore.readClarificationsForDefect(run.defectId),
              hasLength(1),
            );

            // A replay is a realistic production event, not a contrived one:
            // `apps/server/lib/server.dart` re-reads every job the scheduler
            // touched and calls the processor on each that is terminal, and a
            // lease-expiry reconciliation can put the same job in `terminal`
            // again.
            final second = await run.process();
            expect(second!.resultId, first.resultId);

            // The TriageResult itself IS idempotent — one row, one id...
            expect(await run.triageResultRowsForDefect(), hasLength(1));
            expect(await run.triageResultRow(first.resultId), isNotNull);

            // ...but the clarification side effect is not.
            //
            // `TriageProcessor._createClarifications` mints
            // `clar-<resultId>-<DateTime.now().millisecondsSinceEpoch>` and
            // `processCompletedTriageJob` has no "already processed" guard, so
            // every replay appends another row. `triage_result` is keyed by id
            // and `saveTriageResult` upserts, which is why only the
            // append-only table drifts.
            final clarifications = await run.defectStore
                .readClarificationsForDefect(run.defectId);
            expect(clarifications, hasLength(2));
            expect(
              clarifications.map((c) => c.question),
              everyElement(question),
            );
            expect(
              clarifications.map((c) => c.clarificationId).toSet(),
              hasLength(2),
              reason:
                  'distinct ids minted from the wall clock, not derived '
                  'from the result',
            );
            expect(
              clarifications.every(
                (c) => c.status == ClarificationStatus.needsAnswer,
              ),
              isTrue,
              reason:
                  'so a human sees the same question twice and answering '
                  'one leaves the other dangling',
            );
          },
        );

        test('an ambiguous defect persists a durable clarification', () async {
          final db = await newDb();
          const question = 'Which client is affected?';
          const reason = 'The report does not identify the client surface.';
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: _triageStructuredResult(
              classification: DefectClassification.requirementGap.wire,
              confidence: 0.35,
              recommendedNextAction: 'clarify',
              clarificationRequired: const [
                {'question': question, 'reason': reason},
              ],
            ),
          );
          addTearDown(run.dispose);

          final result = await run.process();
          expect(result, isNotNull);
          expect(result!.clarificationRequired, hasLength(1));
          expect(result.clarificationRequired.single.question, question);
          expect(result.clarificationRequired.single.reason, reason);
          expect(result.recommendedNextAction, 'clarify');

          final clarifications = await run.defectStore
              .readClarificationsForDefect(run.defectId);
          expect(clarifications, hasLength(1));
          final clarification = clarifications.single;
          expect(clarification.question, question);
          expect(clarification.reason, reason);
          expect(clarification.status, ClarificationStatus.needsAnswer);
          expect(clarification.requestedByTriageJobId, run.job.jobId);
          expect(clarification.answer, isNull);
        });

        test('an unambiguous defect raises no clarification', () async {
          final db = await newDb();
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: _triageStructuredResult(
              classification: DefectClassification.implementationDefect.wire,
            ),
          );
          addTearDown(run.dispose);

          expect(await run.process(), isNotNull);
          expect(
            await run.defectStore.readClarificationsForDefect(run.defectId),
            isEmpty,
          );
        });
      });

      group('attempt bounds and retries', () {
        test(
          'PRODUCTION DEFECT: a transient failure queues a retry that no '
          'scheduler tick can ever claim',
          () async {
            final db = await newDb();
            var now = DateTime.utc(2026, 3, 1, 12);
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.implementationDefect.wire,
              ),
              // The agent session ends interrupted, which `LocalWorker` reports
              // as `timedOut` and `RetryPolicy.classify` maps to
              // `JobFailureKind.transient`. A second session would complete
              // normally, so the ONLY thing stopping recovery is platform
              // machinery, not the agent.
              interruptFirstExecutions: 1,
              clock: () => now,
            );
            addTearDown(run.dispose);

            // The transient path really did queue a bounded retry: the failure
            // is classified transient and the job is parked, not failed.
            expect(run.job.state, JobState.retryWaiting);
            expect(run.job.failure?.kind, JobFailureKind.transient);
            expect(run.job.failure?.code, JobFailureCode.executionInterrupted);
            expect(
              run.job.attempt,
              2,
              reason: 'scheduleRetry pre-increments: attempt 2 is queued',
            );
            expect(run.job.maxAttempts, triageDefectDefinition.maxAttempts);

            // `RetryPolicy.retryDelay` is one minute, so the retry is not yet
            // due, and the work item has been moved to `agentFailed` by the
            // coordinator settling the interrupted execution.
            expect(run.job.availableAt, DateTime.utc(2026, 3, 1, 12, 1));
            expect(
              (await run.workflowStore.readWorkItem(run.workItemId)).state,
              WorkItemState.agentFailed,
            );
            expect((await run.scheduler.tick()).dispatched, isEmpty);

            // Past the delay, the retry becomes eligible in the queue...
            now = now.add(const Duration(minutes: 2));
            expect(
              run.scheduler.queue.isEligibleAt(run.job, now),
              isTrue,
              reason: 'the delay has elapsed, so the queue considers it due',
            );

            // ...and the scheduler still will not touch it, on any tick.
            for (var i = 0; i < 3; i++) {
              final tick = await run.scheduler.tick();
              expect(tick.dispatched, isEmpty);
              expect(tick.deferred, isEmpty);
              expect(tick.terminal, isEmpty);
              expect(tick.cancelledQueued, isEmpty);
              now = now.add(const Duration(hours: 1));
            }

            // Root cause, both halves of it:
            //
            //  * `Scheduler._eligibleRunnableJobs` only claims a job whose work
            //    item `RunnableWorkEvaluator` calls `runnable`.
            //  * `RunnableWorkEvaluator` calls `runnable` only from
            //    `definition.entryStates`, and `triageDefectDefinition`'s are
            //    `{designNotRequired, designApproved}`.
            //  * The coordinator moved the item to `agentFailed`, which is not
            //    one of them, so the status is `noAction` — and `noAction`
            //    explicitly leaves every existing job untouched.
            //
            // So the job is due, owned by nobody, and can never advance. It is
            // also not terminal, so the `job.isTerminal` guard in
            // `apps/server/lib/server.dart`'s post-tick hook skips it and
            // `TriageProcessor` never runs: the defect is silently never
            // classified. The bounded retry allowance
            // (`triageDefectDefinition.maxAttempts == 2`) is unreachable in
            // production for exactly the failures it exists for.
            //
            // This test pins the CURRENT behaviour on purpose. It is a
            // characterisation of a bug, not an endorsement: when the retry
            // path is fixed, this test is expected to fail and be replaced with
            // an assertion that attempt 2 succeeds.
            final wedged = await run.jobStore.readJob(run.job.jobId);
            expect(wedged!.state, JobState.retryWaiting);
            expect(wedged.attempt, 2);
            expect(wedged.isTerminal, isFalse);
            expect(await run.process(), isNull);
            expect(await run.triageResultRowsForDefect(), isEmpty);
            expect(
              triageDefectDefinition.entryStates.contains(
                WorkItemState.agentFailed,
              ),
              isFalse,
            );
          },
        );

        test('a permanent agent failure is never retried', () async {
          final db = await newDb();
          var now = DateTime.utc(2026, 3, 1, 12);
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: _triageStructuredResult(
              classification: DefectClassification.implementationDefect.wire,
            ),
            agentFailure: 'scripted runtime crashed before answering',
            clock: () => now,
          );
          addTearDown(run.dispose);

          // A failed agent is `executedFail`, which the policy classifies as
          // PERMANENT: the LLM is not re-run, the workflow's correction gate is
          // the route. So the bounded allowance is not even consulted.
          expect(run.job.state, JobState.failed);
          expect(run.job.failure?.kind, JobFailureKind.permanent);
          expect(run.job.attempt, 1);
          expect(triageDefectDefinition.maxAttempts, 2);

          // And nothing picks it up again, however long the scheduler runs.
          now = now.add(const Duration(days: 1));
          final laterTick = await run.scheduler.tick();
          expect(laterTick.dispatched, isEmpty);
          expect(laterTick.enqueued, isEmpty);
          expect(laterTick.cancelledQueued, isEmpty);
          expect(
            await run.jobStore.listJobsForWorkItem(run.workItemId),
            hasLength(1),
          );
        });
      });

      group('graceful handling', () {
        test('a malformed structured result persists nothing', () async {
          final db = await newDb();
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            // No classification: the agent ran, but its output is unusable.
            structuredResult: const {'status': 'triaging', 'confidence': 0.5},
          );
          addTearDown(run.dispose);

          // The agent itself succeeded; only the platform-side parse fails.
          expect(run.job.state, JobState.succeeded);
          expect(await run.process(), isNull);
          expect(await run.triageResultRowsForDefect(), isEmpty);
          final defect = await run.defectStore.readDefect(run.defectId);
          expect(defect.metadataJson, isNull);
          expect(defect.status, DefectStatus.reported);
          expect(
            await run.defectStore.readClarificationsForDefect(run.defectId),
            isEmpty,
          );
        });

        test('an unknown classification is rejected, not guessed', () async {
          final db = await newDb();
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: _triageStructuredResult(
              classification: 'ALMOST_A_DESIGN_DEFECT',
            ),
          );
          addTearDown(run.dispose);

          expect(await run.process(), isNull);
          expect(await run.triageResultRowsForDefect(), isEmpty);
        });

        test('an empty structured result persists nothing', () async {
          final db = await newDb();
          final run = await _dispatchTriage(
            db: db,
            runId: _nextRunId(runCounter++),
            structuredResult: const {},
          );
          addTearDown(run.dispose);

          expect(run.job.state, JobState.succeeded);
          expect(await run.process(), isNull);
          expect(await run.triageResultRowsForDefect(), isEmpty);
        });

        test(
          'a failed agent session fails the job and persists nothing',
          () async {
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.implementationDefect.wire,
              ),
              agentFailure: 'scripted runtime crashed before answering',
            );
            addTearDown(run.dispose);

            expect(run.job.state, JobState.failed);
            expect(run.job.failure?.code, JobFailureCode.executionFailed);
            expect(await run.process(), isNull);
            expect(await run.triageResultRowsForDefect(), isEmpty);

            final item = await run.workflowStore.readWorkItem(run.workItemId);
            expect(item.state, WorkItemState.agentFailed);
            final defect = await run.defectStore.readDefect(run.defectId);
            expect(defect.status, DefectStatus.reported);
          },
        );
      });

      group('production defect: typed triage readback', () {
        test(
          'PRODUCTION DEFECT: evidenceUsed is persisted without checking it '
          'against the defect',
          () async {
            final db = await newDb();
            const phantomEvidence = 'ev-does-not-exist-9f3a';
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.implementationDefect.wire,
                // The agent claims evidence that was never collected.
                evidenceUsed: const [phantomEvidence],
              ),
            );
            addTearDown(run.dispose);

            final result = await run.process();
            expect(result, isNotNull);

            // The claim is stored verbatim, in the durable row and in the
            // typed read. `TriageProcessor._parseTriageResult` does
            // `(structured['evidenceUsed'] as List?)?.cast<String>()` and
            // nothing downstream intersects it with the defect's evidence, so
            // an agent that invents a citation is indistinguishable from one
            // that read the evidence.
            expect(result!.evidenceUsed, [phantomEvidence]);
            final reread = await run.triageStore.readTriageResult(
              result.resultId,
            );
            expect(reread!.evidenceUsed, [phantomEvidence]);
            expect(
              (await run.triageResultRow(result.resultId))!['evidenceUsed'],
              [phantomEvidence],
            );

            // The defect genuinely has no such evidence, so the citation is
            // dangling rather than merely unverified.
            final real = await run.defectStore.readEvidenceForDefect(
              run.defectId,
            );
            expect(
              real.map((e) => e.evidenceId),
              isNot(contains(phantomEvidence)),
            );
            expect(real, hasLength(1));

            // And it is surfaced to whoever reads the triage outcome, so the
            // unverifiable citation is not quarantined anywhere.
            final defect = await run.defectStore.readDefect(run.defectId);
            final metadata =
                jsonDecode(defect.metadataJson!) as Map<String, dynamic>;
            expect(metadata['triageResultId'], result.resultId);

            // This pins the CURRENT behaviour on purpose: the absence of
            // validation is a characterisation, not an endorsement. When
            // production starts rejecting unbacked citations, this test is
            // expected to fail and be replaced with the rejection assertion.
            // The other direction is already covered truthfully: the
            // harness's own `evidenceUsed` defaulting in `_dispatchTriage` is
            // documented as a harness convenience, not a production guarantee.
          },
        );

        test(
          'TriageResult survives a restart through PostgresTriageStore',
          () async {
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.implementationDefect.wire,
              ),
            );
            addTearDown(run.dispose);

            final result = await run.process();
            expect(result, isNotNull);

            // The row really is in Postgres and survives a restart...
            final restarted = run.restarted(db: db);
            expect(
              await restarted.triageResultRow(result!.resultId),
              isNotNull,
            );

            // ...and the typed store reads it back losslessly.
            //
            // Regression guard for a real production bug:
            // PostgresTriageStore._triageResultFromRow cast the `text` column
            // `clarificationRequired` (and the `json` columns
            // `suspectedComponents` / `evidenceUsed`) straight to `List`,
            // so every readTriageResult / readTriageResultForJob /
            // readTriageResultsForDefect call threw
            //   type 'String' is not a subtype of type 'List<dynamic>'
            // and TriageResult.clarificationRequired could never be
            // recovered from Postgres. Reads now go through
            // decodeJsonList / decodeJsonArray.
            final reread = await run.triageStore.readTriageResult(
              result.resultId,
            );
            expect(reread, isNotNull);
            expect(reread!.resultId, result.resultId);
            expect(reread.defectId, result.defectId);
            expect(
              reread.recommendedClassification,
              result.recommendedClassification,
            );
            expect(reread.confidence, result.confidence);
            expect(reread.suspectedComponents, result.suspectedComponents);
            expect(reread.evidenceUsed, result.evidenceUsed);
            expect(
              reread.clarificationRequired.map((c) => c.question).toList(),
              result.clarificationRequired.map((c) => c.question).toList(),
            );
            expect(reread.jobId, result.jobId);
          },
        );
      });

      group('typed endpoint read path', () {
        test(
          'inspect returns the whole triage outcome over the wire shape it '
          'actually publishes',
          () async {
            final db = await newDb();
            const question = 'Which client is affected?';
            const reason = 'The report does not identify the client surface.';
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.requirementGap.wire,
                recommendedNextAction: 'clarify',
                clarificationRequired: const [
                  {'question': question, 'reason': reason},
                ],
              ),
            );
            addTearDown(run.dispose);
            final result = (await run.process())!;
            expect(result, isNotNull);

            // `DefectEndpoints.inspect` returns an untyped
            // `Future<Map<String, dynamic>>` — the endpoint is deliberately not
            // a generated protocol class — so the contract under test is the
            // map it actually builds, asserted on its real keys.
            final inspected = await endpoints.defectEndpoints.inspect(
              sessionBuilder,
              defectId: run.defectId,
            );
            expect(
              inspected.keys.toSet(),
              {
                'defect',
                'evidence',
                'clarifications',
                'events',
                'triageResult',
                'remediationWorkItem',
              },
            );

            // The defect body is the human report, plus the triage reference
            // the processor merged in.
            final defect = Map<String, dynamic>.from(
              inspected['defect']! as Map,
            );
            expect(defect['defectId'], run.defectId);
            expect(defect['title'], _defectTitle);
            expect(defect['status'], DefectStatus.reported.wire);
            expect(defect['severity'], 'high');
            expect(defect['reporter'], 'reporter@example.com');
            expect(defect['classification'], isNull);
            expect(defect['version'], 2, reason: 'intake write, then triage');
            final metadata =
                jsonDecode(defect['metadataJson']! as String)
                    as Map<String, dynamic>;
            expect(metadata['triageResultId'], result.resultId);
            expect(
              metadata['triageClassification'],
              DefectClassification.requirementGap.wire,
            );

            // Every child collection is present and non-empty, so a reader
            // cannot be handed a silently empty list.
            final evidence = (inspected['evidence']! as List)
                .cast<Map<String, dynamic>>();
            expect(evidence, hasLength(1));
            expect(evidence.single['evidenceId'], run.evidenceIds.single);
            expect(
              evidence.single['kind'],
              EvidenceIntakeKind.textDescription.wire,
            );

            final clarifications = (inspected['clarifications']! as List)
                .cast<Map<String, dynamic>>();
            expect(clarifications, hasLength(1));
            expect(clarifications.single['question'], question);
            expect(clarifications.single['reason'], reason);
            expect(
              clarifications.single['status'],
              ClarificationStatus.needsAnswer.wire,
            );
            expect(
              clarifications.single['requestedByTriageJobId'],
              run.job.jobId,
            );

            final events = (inspected['events']! as List)
                .cast<Map<String, dynamic>>();
            expect(events, hasLength(1));
            expect(events.single['type'], DefectEventType.created.wire);
            expect(events.single['actorType'], ActorType.human.wire);

            // The triage result is serialised through the same
            // `clarificationRequired` -> json shape the store decodes, so the
            // endpoint proves the round trip a control-plane client depends on.
            final triageMap = Map<String, dynamic>.from(
              inspected['triageResult']! as Map,
            );
            expect(triageMap['resultId'], result.resultId);
            expect(triageMap['jobId'], run.job.jobId);
            expect(
              triageMap['recommendedClassification'],
              DefectClassification.requirementGap.wire,
            );
            expect(
              triageMap['recommendedStatus'],
              DefectStatus.triaging.wire,
            );
            expect(triageMap['confidence'], result.confidence);
            expect(triageMap['evidenceUsed'], run.evidenceIds);
            expect(
              (triageMap['clarificationRequired']! as List)
                  .cast<Map<String, dynamic>>()
                  .single['question'],
              question,
            );

            // The endpoint does not link the remediation work item yet; it is
            // a hard-coded null with a TODO, so assert that rather than
            // pretending the link exists.
            expect(inspected['remediationWorkItem'], isNull);
          },
        );
      });

      group('triage job definition', () {
        test(
          'the scheduler really only dispatches from its entry states',
          () async {
            // A constant compared with its own literal proves nothing: it can
            // only fail if someone edits the constant, and it says nothing
            // about whether the scheduler honours it. This drives the real
            // `RunnableWorkEvaluator` and the real `Scheduler` instead.
            final db = await newDb();
            final run = await _dispatchTriage(
              db: db,
              runId: _nextRunId(runCounter++),
              structuredResult: _triageStructuredResult(
                classification: DefectClassification.implementationDefect.wire,
              ),
            );
            addTearDown(run.dispose);

            // The seeded item sits in an entry state, so it ran.
            expect(run.job.state, JobState.succeeded);
            expect(run.tick.enqueued, hasLength(1));

            // A second tick is a no-op, so the entry state alone is not what
            // keeps re-running it.
            final settled = (await run.scheduler.tick()).enqueued;
            expect(settled, isEmpty);

            // Now walk the SAME work item through every state that is not an
            // entry state of the triage definition, one at a time, and assert
            // the evaluator refuses to call it runnable. `WorkItemState.values`
            // minus the entry states, so a state added to the enum later is
            // covered automatically instead of silently skipped.
            final item = await run.workflowStore.readWorkItem(run.workItemId);
            final evaluator = RunnableWorkEvaluator(
              policy: const WorkflowEngine(),
            );
            for (final state in WorkItemState.values) {
              if (triageDefectDefinition.entryStates.contains(state)) continue;
              expect(
                evaluator.evaluate(
                  item.copyWith(state: state),
                  triageDefectDefinition,
                ),
                isNot(RunnableWorkStatus.runnable),
                reason: '$state is not an entry state of the triage definition',
              );
            }
            for (final state in triageDefectDefinition.entryStates) {
              expect(
                evaluator.evaluate(
                  item.copyWith(state: state),
                  triageDefectDefinition,
                ),
                RunnableWorkStatus.runnable,
                reason: '$state is an entry state and must be runnable',
              );
            }
            expect(triageDefectDefinition.requiredRole, AgentRole.triageDefect);
            expect(
              triageDefectDefinition.targetState,
              WorkItemState.agentExecuting,
            );
          },
        );

        test('deduplicates on the job type, not the work item alone', () {
          final now = DateTime.now().toUtc();
          final item = WorkItem(
            workItemId: 'defect-DEF-1',
            productId: 'defects',
            category: WorkItemCategory.feature,
            title: 'Triage defect DEF-1',
            description: 'A human reported defect awaiting automated triage.',
            state: WorkItemState.designNotRequired,
            createdAt: now,
            updatedAt: now,
            version: 1,
          );
          expect(
            triageDefectDedupeKey(item, triageDefectDefinition),
            'defect-DEF-1:triage_defect',
          );
        });
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

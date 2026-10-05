import 'dart:async' show Timer;
import 'dart:io' show Directory, File, Platform, Process, stdout;

import 'package:serverpod/serverpod.dart';
import 'package:agent_runtime/agent_runtime.dart'
    show AgentAdapterRegistry, AgentRuntime, OpencodeAdapter;
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionCoordinator, FileJsonExecutionStore, VerificationPlan;
import 'package:workflow_store/workflow_store.dart' show DurableWorkflowEngine;
import 'package:scheduler/scheduler.dart'
    show
        Scheduler,
        triageDefectDefinition,
        triageDefectDedupeKey,
        triageDefectInstruction,
        triageDefectRequest,
        SchedulerWorkload,
        WorkerDispatch,
        WorkerDispatcherAdapter,
        ProviderHealthMonitor;
import 'package:worker_runtime/worker_runtime.dart'
    show
        CoordinatorAgentExecutionDriver,
        GitWorktreeWorkspaceManager,
        LocalWorker,
        WorkerDispatcher,
        WorkerRegistry,
        WorkerStore;

import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/persistence/persistence_database.dart';
import 'src/persistence/postgres_workflow_store.dart';
import 'src/persistence/postgres_job_store.dart';
import 'src/persistence/postgres_worker_store.dart';
import 'src/persistence/postgres_defect_store.dart';
import 'src/persistence/postgres_triage_store.dart';
import 'src/persistence/postgres_model_execution_record_store.dart';
import 'src/persistence/postgres_model_policy_store.dart';
import 'src/persistence/postgres_human_decision_store.dart';
import 'src/triage/lane_i_tick_hook.dart' show drainTriageOutcomesFromTick;
import 'src/triage/triage_processor.dart';

/// The starting point of the ShipIt control plane server.
///
/// Serverpod hosts the PostgreSQL persistence layer only. All workflow policy
/// authority lives in [workflow_engine]'s `DurableWorkflowEngine`; endpoints
/// never mutate `WorkItem.state` directly.
///
/// THE COMPOSITION, in the order it is built, because the order is a dependency
/// chain and not a preference:
///
///   stores -> workflow engine -> agent runtime (adapter registry)
///          -> execution coordinator -> local worker -> worker registry
///          -> dispatcher -> scheduler -> triage processor -> tick hook
///
/// The runtime must be bound before the coordinator, the coordinator before the
/// worker (the worker drives every execution through it), the worker before the
/// dispatcher (an empty registry can never select anything), and all of them
/// before the scheduler, which holds the only reference the tick uses.
void run(List<String> args) async {
  // Resolved BEFORE the server starts. A misconfigured triage source is a
  // refusal to serve, not a warning: the alternative is a server that accepts
  // defect reports, durably queues them, and never classifies any of them.
  final triageSource = _resolveTriageSource();
  final workspaceRoot = _triageWorkspaceRoot();

  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints());

  // No authentication services: the control plane API is intended for local
  // / trusted-network use (documented under SECURITY ASSUMPTION in the
  // control-plane persistence slice report).

  // Start the server.
  await pod.start();

  // Set up persistence and scheduler.
  final session = await pod.createSession(enableLogging: false);
  final db = PersistenceDatabase(session.db);

  final workflowStore = PostgresWorkflowStore(db);
  final jobStore = PostgresJobStore(db);
  final WorkerStore workerStore = PostgresWorkerStore(db);
  final defectStore = PostgresDefectStore(db);
  final triageStore = PostgresTriageStore(db);

  final durableWorkflowEngine = DurableWorkflowEngine(store: workflowStore);

  // The REAL agent provider, registered under the id the workload selects.
  //
  // `SchedulerWorkload.runtimeTypeId` is not a label: the coordinator passes it
  // straight to `AgentRuntime.startSession(providerId: request.runtimeTypeId)`,
  // which looks it up in this registry. An `AgentRuntime()` built over the empty
  // global registry therefore made every single dispatch fail with
  // `AgentAdapterNotFoundException` while the jobs looked perfectly healthy.
  //
  // `OpencodeAdapter` is the real adapter from `packages/agent_runtime` — the
  // one that speaks ACP to an `opencode acp` child process. There is no
  // production fallback adapter: a fake one in the shipping composition would
  // manufacture classifications no agent ever produced.
  const triageRuntimeTypeId = 'opencode';
  final opencodeAdapter = OpencodeAdapter();
  final agentAdapters = AgentAdapterRegistry()..register(opencodeAdapter);

  // Reachability is not registration: the adapter is constructed the same way
  // whether or not the `opencode` binary, its credentials and its network are
  // present. Ask it once, out loud, so a provider that cannot be reached is a
  // fact in the startup log rather than a surprise in the first job's failure.
  await _reportAdapterHealth(opencodeAdapter, triageRuntimeTypeId);

  final coordinator = ExecutionCoordinator(
    store: FileJsonExecutionStore(
      File('${Directory.systemTemp.path}/execution_coordinator/store.json'),
    ),
    workflowEngine: durableWorkflowEngine,
    runtime: AgentRuntime(registry: agentAdapters),
    verificationPlan: const VerificationPlan(),
    modelExecutionRecordStore: PostgresModelExecutionRecordStore(db),
  );

  // The REAL worker, in a REAL git worktree, pinned to the exact commit the
  // source repository was at when this process started. An empty
  // `WorkerRegistry` meant `WorkerDispatcher.select` returned no candidate, so
  // `Scheduler.tick` deferred every triage job forever and the platform looked
  // idle rather than broken.
  //
  // The capabilities are the job definition's own set, not a hand-copied list:
  // selection compares the job's `requiredCapabilities` against these, so
  // taking them from the definition makes "the worker can be selected for every
  // triage job" true by construction instead of by coincidence.
  final triageWorker = LocalWorker(
    workerId: 'w-triage-local',
    poolId: 'triage-pool',
    capabilities: triageDefectDefinition.requiredCapabilities,
    // Never the source repository itself: the agent runs in a detached
    // worktree, and cleanup only ever removes worktrees this platform created.
    workspaceManager: GitWorktreeWorkspaceManager(workspaceRoot: workspaceRoot),
    executionDriver: CoordinatorAgentExecutionDriver(coordinator),
    workerStore: workerStore,
    platform: Platform.operatingSystem,
  );
  final workerRegistry = WorkerRegistry()..register(triageWorker);
  final WorkerDispatch dispatch = WorkerDispatcherAdapter(
    WorkerDispatcher(registry: workerRegistry),
  );

  // Provider health monitor runs on a separate timer, not blocking scheduler tick.
  final modelPolicyStore = PostgresModelPolicyStore(db);
  final providerHealthMonitor = ProviderHealthMonitor(
    modelPolicyStore: modelPolicyStore,
    workflowStore: workflowStore,
    humanDecisionStore: PostgresHumanDecisionStore(workflowStore),
    checkInterval: const Duration(minutes: 5),
  );
  providerHealthMonitor.start();

  final scheduler = Scheduler(
    schedulerId: 'sched-triage',
    workflowStore: workflowStore,
    jobStore: jobStore,
    workerStore: workerStore,
    dispatch: dispatch,
    definition: triageDefectDefinition,
    // The canonical triage builders from `packages/scheduler`. Without these
    // the scheduler silently falls back to `_defaultDedupeKey` /
    // `_defaultInstruction` / `_defaultRequest`, which stamp
    // `AgentRole.triageDefect` jobs with
    // 'Implement "<title>" (...) inside the worktree.' — a feature
    // implementation instruction sent to a defect triage agent.
    dedupeKeyBuilder: triageDefectDedupeKey,
    instructionBuilder: triageDefectInstruction,
    requestBuilder: triageDefectRequest,
    workload: SchedulerWorkload(
      repositoryPath: triageSource.path,
      // A concrete commit, not the string 'HEAD'. The worktree manager refuses
      // a worktree whose HEAD does not equal the requested revision exactly,
      // and a literal 'HEAD' never equals a SHA.
      startingRevision: triageSource.startingRevision,
      timeoutSeconds: 300,
      // The id `OpencodeAdapter` is registered under above.
      runtimeTypeId: triageRuntimeTypeId,
    ),
    clock: () => DateTime.now().toUtc(),
    providerHealthMonitor: providerHealthMonitor,
  );

  final triageProcessor = TriageProcessor(
    db: db,
    workflowStore: workflowStore,
    workflowEngine: durableWorkflowEngine,
    executionCoordinator: coordinator,
    defectStore: defectStore,
    triageStore: triageStore,
    logger: _log,
  );

  // One line that states the whole composition as it actually is, so an
  // operator (or the next reader) can see what this process can do without
  // reading the rest of the file.
  _log('server.composition', {
    'schedulerId': 'sched-triage',
    'runtimeTypeId': triageRuntimeTypeId,
    'providers': agentAdapters.providerIds,
    'workerIds': workerRegistry.workers.map((w) => w.workerId).toList(),
    'repositoryPath': triageSource.path,
    'startingRevision': triageSource.startingRevision,
    'workspaceRoot': workspaceRoot,
    'providerHealthMonitor': true,
    'providerHealthCheckIntervalMinutes': 5,
  });

  // Run the scheduler every 30 seconds.
  Timer.periodic(const Duration(seconds: 30), (_) async {
    try {
      final tickResult = await scheduler.tick();

      // Drain the outcomes this tick actually produced, into the processor.
      // The set of ids to drain, and WHY it is the union of the three lists
      // rather than `terminal` alone, is production knowledge and lives with
      // the function that does the draining — see `drainTriageOutcomesFromTick`.
      // What matters here is only that the tick's result is consumed by the one
      // function that owns this boundary, with no second copy of the loop
      // drifting out of step with it.
      final drain = await drainTriageOutcomesFromTick(
        tickResult: tickResult,
        jobStore: jobStore,
        triageProcessor: triageProcessor,
        logger: _log,
      );
      if (drain.handedOff > 0) {
        _log('triage.tick.drained', {
          'considered': drain.considered,
          'skipped': drain.skipped,
          'handedOff': drain.handedOff,
          'succeededJobIds': drain.succeededJobIds,
          'failedJobIds': drain.failedJobIds,
        });
      }
    } catch (e, st) {
      // Log but don't crash the server
      _log('scheduler.tick.failed', {'error': '$e', 'stack': st.toString()});
    }
  });
}

/// The single operator log for this file, so every event the composition emits
/// is greppable by name and shares one format.
void _log(String event, Map<String, dynamic> data) {
  stdout.writeln('[$event] $data');
}

/// Git repository (and the exact commit) every triage worktree is forked from.
class _TriageSource {
  const _TriageSource({required this.path, required this.startingRevision});

  final String path;
  final String startingRevision;
}

/// Environment variable naming the git repository the triage worker forks
/// worktrees from. Required, and with no default: see [_resolveTriageSource].
const String _triageRepositoryPathEnv = 'SHIPIT_TRIAGE_REPOSITORY_PATH';

/// Environment variable naming where those worktrees are created. Defaults to a
/// system-temp directory, matching the execution store's location above; set it
/// to a durable path to keep workspace descriptors across restarts, since that
/// is how stranded worktrees are discovered.
const String _triageWorkspaceRootEnv = 'SHIPIT_TRIAGE_WORKSPACE_ROOT';

/// Resolves and VALIDATES the triage source repository, or throws.
///
/// The previous literal `'/tmp'` was not a placeholder that a deployment
/// happened to override — it was a placeholder that could never work, silently:
/// `/tmp` is not a git repository, so every `LocalWorker` preparation would have
/// failed and every triage job deferred forever while the server reported itself
/// healthy. That is the same silent no-dispatch the empty worker registry
/// produced, so the absence is now a startup failure that names the variable to
/// set instead.
///
/// Validation is real, not a path check: the repository is asked for `HEAD`
/// here, so a path that is not a repository, or has no commits, is refused before
/// a single job is enqueued.
_TriageSource _resolveTriageSource() {
  final path = Platform.environment[_triageRepositoryPathEnv]?.trim();
  if (path == null || path.isEmpty) {
    throw StateError(
      'CONFIG_ERROR $_triageRepositoryPathEnv is not set. Triage runs on a real '
      'local worker, which forks a real git worktree from a real repository. '
      'There is no default and no placeholder; set $_triageRepositoryPathEnv '
      'to the path of a git repository that triage may read.',
    );
  }
  if (!Directory(path).existsSync()) {
    throw StateError(
      'CONFIG_ERROR $_triageRepositoryPathEnv=$path does not exist.',
    );
  }
  return _TriageSource(
    path: path,
    startingRevision: _git(path, ['rev-parse', '--verify', 'HEAD^{commit}']),
  );
}

String _triageWorkspaceRoot() {
  final configured = Platform.environment[_triageWorkspaceRootEnv]?.trim();
  if (configured != null && configured.isNotEmpty) return configured;
  return '${Directory.systemTemp.path}/shipit_triage_workspaces';
}

String _git(String repositoryPath, List<String> args) {
  final result = Process.runSync('git', ['-C', repositoryPath, ...args]);
  if (result.exitCode != 0) {
    throw StateError(
      'CONFIG_ERROR git ${args.join(' ')} failed in $repositoryPath '
      '(exit ${result.exitCode}): ${result.stderr.toString().trim()}',
    );
  }
  return result.stdout.toString().trim();
}

/// Reports, once at startup, whether the registered provider is actually
/// reachable — and never turns that into a gate.
///
/// `OpencodeAdapter.checkHealth` spawns a real `opencode acp` process and
/// completes an `initialize` handshake with it, so a missing binary, missing
/// credentials or no network shows up here as an unhealthy adapter instead of
/// as every triage execution failing later. A provider that is down must not
/// stop the server from serving the rest of the platform, so the answer is
/// logged either way; and a passing probe says nothing about whether a later
/// execution will succeed, which is why the healthy branch is a fact rather than
/// a promise.
Future<void> _reportAdapterHealth(
  OpencodeAdapter adapter,
  String runtimeTypeId,
) async {
  try {
    final health = await adapter.checkHealth().timeout(
      const Duration(seconds: 30),
    );
    _log(
      health.healthy
          ? 'agent_runtime.adapter_healthy'
          : 'agent_runtime.adapter_unhealthy',
      {
        'providerId': adapter.providerId,
        'runtimeTypeId': runtimeTypeId,
        'version': health.version,
        ...?health.details,
        if (!health.healthy)
          'action': 'registered, but every execution will fail until fixed',
      },
    );
  } on Object catch (e) {
    _log('agent_runtime.adapter_health_probe_failed', {
      'providerId': adapter.providerId,
      'runtimeTypeId': runtimeTypeId,
      'error': e.toString(),
      'action': 'registered, but reachability is UNVERIFIED',
    });
  }
}

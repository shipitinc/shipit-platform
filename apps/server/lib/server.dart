import 'dart:async' show Timer;
import 'dart:io' show Directory, File, Platform, Process, stdout;

import 'package:serverpod/serverpod.dart';
import 'package:agent_runtime/agent_runtime.dart'
    show AgentAdapterRegistry, AgentRuntime, OpencodeAdapter;
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionCoordinator, FileJsonExecutionStore, VerificationPlan;
import 'package:workflow_store/workflow_store.dart' show DurableWorkflowEngine;
import 'package:platform_contracts/platform_contracts.dart' show JobType;
import 'package:product_registry/product_registry.dart'
    show ProductRegistryEngine;
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
import 'src/persistence/postgres_product_registry_store.dart';
import 'src/baseline/baseline_lane_runner.dart'
    show observeCompletedOnboardingJob;
import 'src/baseline/baseline_runtime.dart' show BaselineProductionRuntime;
import 'src/triage/defect_triage_sweep.dart';
import 'src/triage/lane_i_tick_hook.dart' show drainTriageOutcomesFromTick;
import 'src/triage/triage_processor.dart';
import 'src/triage/work_entry.dart' show WorkEntryTrigger;

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

  // ---- Baseline production: a PRODUCT-SCOPED path, not a second triage loop. ----
  //
  // `JobType.onboardProduct` jobs were enqueued, stored, displayed by
  // `getOnboardingStatus` and never run, because nothing here constructed the
  // lane and nothing consumed those jobs. The wiring below closes that.
  //
  // It is deliberately NOT a second `Scheduler` over the same work items.
  // `Scheduler` decides what may run by asking the workflow policy about a
  // `WorkItem`; an onboarding job is filed under the synthetic
  // `onboarding-<productId>` and has none, so it is skipped by eligibility
  // before anything else is considered. Onboarding is product-scoped work and
  // belongs to a product-scoped dispatcher (`BaselineProductDispatcher`), which
  // claims those jobs with a lease, runs the lane, and records the outcome. The
  // WorkItem-scoped triage scheduler above is untouched.
  //
  // Its OWN database session, deliberately. Acquiring a pinned snapshot is a
  // real `git clone` over SSH bounded at five minutes, and a baseline pass runs
  // it for every eligible product. On the one session this process shares with
  // every API request, that would pin a connection for the duration and starve
  // request handling for as long as a slow remote takes — a failure the
  // scheduler tick did not have, because a tick only reads and writes rows.
  final baselineSession = await pod.createSession(enableLogging: false);
  final baselineDb = PersistenceDatabase(baselineSession.db);
  final baselineRegistryStore = PostgresProductRegistryStore(baselineDb);

  // ONE registry engine, named, because two components below need it and a
  // second instance over the same rows would be two places to change when the
  // engine's construction ever does. It was already being built here, inline,
  // as an argument.
  final productRegistryEngine = ProductRegistryEngine(
    store: baselineRegistryStore,
    humanDecisionStore: PostgresHumanDecisionStore(workflowStore),
  );
  final baselineRuntime = BaselineProductionRuntime.resolve(
    engine: productRegistryEngine,
    baselineStore: baselineRegistryStore,
    jobStore: jobStore,
    log: _log,
  );

  // ---- The work-entry sweep: the RECOVERY half of an intake-only trigger. ----
  //
  // `createDefect` enqueues triage at intake. That path has no retry, so any
  // exception between "defect accepted" and "job enqueued" leaves a defect with
  // no job and nothing that will ever look again. More importantly, a defect
  // reported against a product that is not yet `governed` is accepted, gated by
  // `WorkEntryTrigger`, and left where it is — correct, and stuck for ever
  // without a sweep to notice when the product becomes governed.
  //
  // The trigger is CONSTRUCTED here rather than reused from
  // `ControlPlaneService.workEntryTrigger` because this process holds no
  // service: endpoints build one per request over that request's `Session`.
  // What matters is that it is built from the SAME live objects that getter
  // builds from — [workflowStore], [durableWorkflowEngine], [jobStore] and the
  // one [productRegistryEngine] above — so a defect gated in a request is seen
  // identically here, in this process, on the next tick. A second instance of
  // the trigger is harmless (it is stateless: store handles plus a `JobQueue`
  // over one of them); a second set of STORES would not be, and there is none.
  //
  // BUILT, COMPOSED, AND GATED OFF. The sweep below is real and wired to this
  // tick, but the tick invocation is conditional on an operator's explicit
  // enablement — see [_workEntrySweepEnv] and `work_entry.sweep.disabled` at
  // startup. Design-revision.md §15 holds it until lane L4 proves P-2 and P-5,
  // because this would be the first thing to touch the 18 historically
  // orphaned triage jobs.
  final workEntrySweepGate = _resolveWorkEntrySweepGate();
  if (!workEntrySweepGate.enabled) {
    // STATED, not implied. A feature gate whose absence is silent is a silent
    // no-op wearing the costume of a configuration file, and an operator six
    // months from now must be able to read this line and know that the sweep
    // exists, is not running, and why — without grepping for something that is
    // not there.
    _log('work_entry.sweep.disabled', <String, dynamic>{
      ...workEntrySweepGate.describe(),
      'action':
          'no defect will be recovered by this sweep. Defects on an ungoverned '
          'product stay gated, exactly as they did before it existed. This is '
          'the documented design-revision.md section 15 gate, not a fault.',
    });
  }
  final defectTriageSweep = DefectTriageSweep(
    defectStore: defectStore,
    trigger: WorkEntryTrigger(
      workflowStore: workflowStore,
      workflowEngine: durableWorkflowEngine,
      productRegistryEngine: productRegistryEngine,
      jobStore: jobStore,
      log: _log,
    ),
    log: _log,
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
    'baseline': baselineRuntime.describe(),
    // The gate's STATE, in both directions — not a claim that the sweep runs.
    // Present when it does not, because "the field is absent" is exactly the
    // ambiguity this entry point is supposed to remove. The sweep's liveness,
    // once enabled, is the per-tick `work_entry.sweep.completed` line; that is
    // a fact no startup-time field can carry.
    'defectTriageSweep': workEntrySweepGate.describe(),
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
        // `onboardProduct` is registered so the dispatch table is COMPLETE.
        // Onboarding jobs are product-scoped and are claimed and run by
        // `BaselineProductDispatcher` below, so they never appear in a triage
        // `SchedulerTickResult` and this handler does not fire in this
        // composition. It is registered because the alternative is an
        // `UnhandledJobTypeException` — a job type no handler was written for —
        // the moment any future composition lets one scheduler serve both.
        handlers: {
          JobType.onboardProduct: (job) => observeCompletedOnboardingJob(
            job: job,
            logger: _log,
          ),
        },
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

    // The product-scoped half of the tick, in its own try: a triage tick that
    // fails must not prevent onboarding from running, and vice versa. They read
    // the same job store but answer different questions, and one of them
    // throwing says nothing about the other.
    try {
      final baselinePass = await baselineRuntime.runOnce();
      _log('baseline.tick.completed', {
        'sweep': baselinePass.sweep?.toString(),
        'dispatch': baselinePass.dispatch.toString(),
      });
    } catch (e, st) {
      _log('baseline.tick.failed', {
        'error': '$e',
        'stack': st.toString(),
        'action':
            'baseline dispatch is retried on the next tick; triage is unaffected',
      });
    }

    // The work-entry half of the tick, in its OWN try, alongside the other two:
    // a triage tick that fails must not prevent work entry from running, and a
    // failing defect read inside the sweep must not prevent the next tick.
    //
    // GATED, not merely present. Design-revision.md §15: this sweep is the
    // first thing that would touch the 18 historically orphaned triage jobs,
    // and P-2/P-5 (lane L4) have not proven the durable `enqueueIfAbsent` path
    // yet. The gate cannot change while the process runs, so there is no
    // window in which this line runs "sometimes" — and the state it is in was
    // stated at startup by `work_entry.sweep.disabled`, or enabled, in which
    // case the per-tick `work_entry.tick.completed` line below is the liveness
    // signal. Absence of either is a real outage rather than a shape.
    if (workEntrySweepGate.enabled) {
      try {
        final sweepPass = await defectTriageSweep.run();
        _log('work_entry.tick.completed', {'sweep': sweepPass.toString()});
      } catch (e, st) {
        _log('work_entry.tick.failed', {
          'error': '$e',
          'stack': st.toString(),
          'action':
              'work entry is retried on the next tick; triage and baseline are '
              'unaffected',
        });
      }
    }
  });
}

/// The single operator log for this file, so every event the composition emits
/// is greppable by name and shares one format.
void _log(String event, Map<String, dynamic> data) {
  stdout.writeln('[$event] $data');
}

/// Environment variable that enables the defect-triage work-entry sweep on the
/// live tick.
///
/// ## OFF unless it is explicitly turned on — and the off is the DEFAULT, not
/// an omission
///
/// Unset, empty, or set to anything unrecognised leaves the sweep off. There is
/// no value that enables it by accident: the recognised spellings are
/// `workEntrySweepEnablementValues`, so a variable set to `false`, `0`, `off` or
/// a typo cannot be read as consent to run the first thing that would touch the
/// 18 historically orphaned triage jobs.
///
/// This is NOT a silent-absence flag. Absence is a STATE, and the state is
/// printed: `work_entry.sweep.disabled` on every start while it holds, plus a
/// `defectTriageSweep` field on `server.composition`. An operator can tell that
/// the sweep exists, is not running, and what would lift it, by reading one
/// startup line — without grepping for something that is not there.
///
/// It is also NOT a startup refusal. Refusing to serve the whole platform
/// because a feature flag was misspelled would trade a safe, loud, recoverable
/// state for an outage, and the safe direction is the one absence already fails
/// in. `_resolveTriageSource` throws for the opposite reason — a missing
/// triage source makes the server accept defects and classify none, which is a
/// fault in the platform's core promise rather than a disabled extra.
const String _workEntrySweepEnv = 'SHIPIT_WORK_ENTRY_SWEEP';

/// Resolves the work-entry sweep's enablement from the process environment.
///
/// Reads the variable HERE, at the composition root, and hands the raw value to
/// [workEntrySweepGateFor] rather than letting the sweep file touch the
/// environment: environment belongs at the root, and the sweep's own
/// product-agnosticism gate forbids an environment lookup in it — which is
/// exactly why the parsing lives where it does rather than being smuggled in.
WorkEntrySweepGate _resolveWorkEntrySweepGate() => workEntrySweepGateFor(
  Platform.environment[_workEntrySweepEnv],
  variableName: _workEntrySweepEnv,
);

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

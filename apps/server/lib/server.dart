import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode;
import 'dart:io' show Directory, Platform, Process, exit, stdout;

import 'package:serverpod/serverpod.dart';
import 'package:agent_runtime/agent_runtime.dart'
    show AgentAdapterRegistry, AgentRuntime, OpencodeAdapter;
import 'package:execution_coordinator/execution_coordinator.dart'
    show
        ExecutionCoordinator,
        ExecutionStore,
        ModelExecutionRecordStore,
        VerificationPlan;
import 'package:workflow_store/workflow_store.dart' show DurableWorkflowEngine;
import 'package:platform_contracts/platform_contracts.dart'
    show AgentRole, JobType;
import 'package:product_registry/product_registry.dart'
    show ProductRegistryEngine, ProductRegistryStore;
import 'package:scheduler/scheduler.dart'
    show
        JobStore,
        Scheduler,
        liveSessionLivenessProbe,
        triageDefectDefinition,
        triageDefectDedupeKey,
        triageDefectInstruction,
        triageDefectRequest,
        implementFeatureDefinition,
        implementFeatureDedupeKey,
        implementFeatureInstruction,
        implementFeatureRequest,
        SchedulerWorkload,
        WorkerDispatch,
        WorkerDispatcherAdapter,
        ProviderHealthMonitor;
import 'package:workflow_engine/workflow_engine.dart'
    show
        ModelSelection,
        ModelSelectionService,
        ModelSelectionSource,
        kConfiguredDefaultDecisionId,
        kConfiguredDefaultModelId;
// The capacity API (L1) is not exported from the scheduler barrel, and
// `packages/scheduler/**` is owned by L1 and under concurrent review — so this
// lane cannot add the export. Narrow, explicit, and expected to be deleted when
// L1's barrel exports it. Same note in `src/persistence/postgres_job_store.dart`.
// ignore: implementation_imports
import 'package:scheduler/src/capacity/job_capacity_guard.dart'
    show JobCapacityGuard;
// ignore: implementation_imports
import 'package:scheduler/src/capacity/execution_capacity.dart'
    show
        ExecutionCapacity,
        ExecutionCapacityResolution,
        executionCapacityEnvVar;
import 'package:worker_runtime/worker_runtime.dart'
    show
        CoordinatorAgentExecutionDriver,
        GitWorktreeWorkspaceManager,
        LocalWorker,
        WorkerDispatcher,
        WorkerRegistrationHeartbeat,
        WorkerRegistrationStore,
        WorkerRegistry,
        WorkerStore;

import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/persistence/persistence_database.dart';
import 'src/persistence/postgres_execution_store.dart';
import 'src/persistence/postgres_workflow_store.dart';
import 'src/persistence/postgres_job_store.dart';
import 'src/persistence/postgres_worker_store.dart';
import 'src/persistence/postgres_worker_registration_store.dart';
import 'src/persistence/postgres_defect_store.dart';
import 'src/persistence/postgres_triage_store.dart';
import 'src/persistence/postgres_model_execution_record_store.dart';
import 'src/persistence/postgres_model_policy_store.dart';
import 'src/persistence/postgres_human_decision_store.dart';
import 'src/persistence/postgres_product_registry_store.dart';
import 'src/baseline/baseline_lane_runner.dart'
    show observeCompletedOnboardingJob;
import 'src/baseline/baseline_runtime.dart' show BaselineProductionRuntime;
// A1's durable-workspace runtime, wired here because C-1 assigns this file
// exclusively to the implementation lane (A2). See `_durableWorkspaceRoot`.
import 'src/baseline/durable_workspace_runtime.dart'
    show
        DurableWorkspaceRuntime,
        DurableWorkspaceRuntimeUnavailableException,
        DurableWorkspaceUnavailableException;
// A3's operator trigger. Its only production caller is the boot-time operator
// instruction below — see `runOperatorDurableWorkspaceProvision`.
import 'src/services/control_plane_service.dart'
    show DurableWorkspaceProvisionRefused, DurableWorkspaceProvisionTrigger;
// The readiness probe that decides whether an implementation job may dispatch
// at all. It lives outside `lib/src/baseline/**` on purpose: that directory is
// covered by the product-agnosticism gate, which refuses every product name —
// and the gate's own file belongs to A1, so a resolver placed there would have
// meant editing a test this lane does not own.
import 'src/implementation/implementation_readiness_probe.dart'
    show ImplementationReadinessProbe, toWorkloadResolver;
import 'src/triage/defect_triage_sweep.dart';
import 'src/triage/lane_i_tick_hook.dart'
    show TriageTickDrainResult, drainTriageOutcomesFromTick;
import 'src/triage/stalled_work_item_gate.dart'
    show StallGateResult, raiseStallDecisions;
import 'src/triage/triage_processor.dart';
import 'src/triage/work_entry.dart' show WorkEntryTrigger;
import 'src/review/engineering_review_gate.dart';
import 'package:scheduler/scheduler.dart'
    show
        engineeringReviewDefinition,
        engineeringReviewDedupeKey,
        engineeringReviewInstruction,
        engineeringReviewRequest;

/// The starting point of the ShipIt control plane server.
///
/// ## THE AGENT-EXECUTION BUDGETS ARE [AgentExecutionBudgets] AND NOTHING ELSE
///
/// Every per-agent wall-clock budget in this composition comes from that one
/// table, including the one the engineering-review workload resolver uses — the
/// resolver takes its budget as a required argument precisely so that no second
/// copy of a number can exist somewhere less visible. Adjusting any budget is
/// now one edit here.
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
///
/// TWO THINGS ARE RESOLVED — AND MAY ABORT THE PROCESS — BEFORE ANY OF THAT.
///
/// [resolveTriageSource] and [resolveDispatchCapacity] run before `Serverpod` is
/// even constructed, so a server that would misbehave never binds a port. Both
/// refuse rather than degrade; see [resolveDispatchCapacity] for why an absent
/// cap has no safe default.
void run(List<String> args) async {
  // Resolved BEFORE the server starts. A misconfigured triage source is a
  // refusal to serve, not a warning: the alternative is a server that accepts
  // defect reports, durably queues them, and never classifies any of them.
  final triageSource = _resolveTriageSource();
  final workspaceRoot = _triageWorkspaceRoot();

  // ---- A2's obligation under C-1: the durable-workspace root read. ----
  //
  // `DurableWorkspaceRuntime.resolve` takes its root as a REQUIRED parameter and
  // has no default, deliberately: a root it cannot name is a runtime that would
  // write into whatever directory the process considers writable, which is the
  // container-local state the host-bind decision exists to prevent. The read
  // lives HERE for two independent reasons, and it needs both:
  //
  //  * the product-agnosticism gate forbids every product name in
  //    `lib/src/baseline/**`, and the variable is named after the product;
  //  * C-1 gives this file exclusively to this lane, so there is no second
  //    writer.
  //
  // Resolved BEFORE the server starts, like the triage source, and with no
  // fallback of its own. An unset variable is not patched here: `resolve`
  // refuses it and records a named reason, which is the fail-closed posture the
  // durable-workspace runtime was built around.
  final durableWorkspaceRoot = _durableWorkspaceRoot();

  // ---- A3's operator instruction: the ONLY production caller of provisioning. ----
  //
  // Resolved HERE, before the server is constructed, for the same reason the
  // triage source and the dispatch cap are: a malformed instruction must refuse
  // before a port is bound, not after a clone has half been made.
  //
  // There is no default and no inference. Unset means nobody asked, and the
  // whole of the implementation lane keeps deferring until a human says
  // otherwise — which is the state the readiness probe already reports, loudly,
  // rather than one anything here papers over.
  final durableProvisionInstruction =
      resolveDurableWorkspaceProvisionInstruction(Platform.environment);

  // Also resolved BEFORE the server starts, and for a heavier reason: a server
  // with no cap dispatches as many agent executions as the queue offers, which
  // is what exhausted the host on 2026-10-10. It must never reach the point of
  // being reachable at all.
  final capacity = resolveDispatchCapacity(Platform.environment, log: _log);

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
  // The durable fleet view. `WorkerStore` persists EXECUTIONS; this persists the
  // workers themselves. They were built from the same `db` and nothing wrote to
  // this one, which is why the operator surface reported `0 of 0 machines busy`
  // while three workers were dispatching work — see the three `LocalWorker`
  // constructions below.
  final WorkerRegistrationStore workerRegistrationStore =
      PostgresWorkerRegistrationStore(db);
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

  // The coordinator is built by [buildTriageExecutionCoordinator], which pins
  // the TRIAGE verification plan. It is named there, not inlined here, because
  // the plan is the exact field that shipped wrong: the `VerificationPlan`
  // default runs `dart test`, and a triage worktree — a checkout of a
  // README-only repository — has no `pubspec.yaml` and no `test/`, so every
  // otherwise-successful triage job settled as `executedFail`. Extracting the
  // composition makes the plan this process actually attaches reachable from a
  // test without a real `opencode` binary or a database.
  //
  // ## THE STORE IS `PostgresExecutionStore`, AND IT WAS NOT A CHOICE
  //
  // This line previously read
  //
  //     store: FileJsonExecutionStore(
  //       File('${Directory.systemTemp.path}/execution_coordinator/store.json'),
  //     ),
  //
  // which is the defect this comment exists to stop being reintroduced. The
  // store is now built by [agentExecutionStore], which is named so the exact
  // wiring is reachable from a test. Every execution the coordinator produced
  // went into that one JSON file; every READER of an agent execution —
  // `engineeringReviewTickHandler`, `engineeringReviewMissingArtifact`, the
  // control plane's `executionStore` getter — read PostgreSQL. The two never
  // met. The measured consequence, on a QA database that had run 35 worker
  // executions:
  //
  //     agent_execution         =  0 rows
  //     worker_execution        = 35 rows
  //     model_execution_record  = 29 rows
  //
  // `PostgresExecutionStore` already existed, already implemented every
  // `ExecutionStore` method against real SQL, and was already wired into
  // `ControlPlaneService.executionStore`. Nothing was wrong with it. Nothing
  // wrote agent executions to it, because nothing was routed to it.
  //
  // `db` is in scope here on its own merits and needs no reordering to make
  // that true: it is constructed at the top of this function, and the very
  // next argument, `modelExecutionRecordStore`, was already
  // `PostgresModelExecutionRecordStore(db)`. The same `db` already served five
  // other stores. There was no boot-order problem here and there is none now.
  //
  // ## WHY THIS IS THE ROOT CAUSE AND NOT A SYMPTOM
  //
  // The engineering review gate could never find a producer artifact, because
  // the gate reads agent executions from Postgres and no agent execution had
  // ever been written there. Its fail-closed park then bailed on
  // `engineering-review-missing-artifact-no-implementer-result`, because
  // `agentResultValid()` needs that same unreadable result — so the ONE
  // mechanism that stops a stranded work item from being stranded silently did
  // nothing, on every run, for ever.
  //
  // ## WHAT THIS DOES *NOT* CHANGE
  //
  // `producedCommitFor` — the discriminator both the review workload resolver
  // and the inflow's stand-down share — reads `worker_execution` and the work
  // item's `producerActorId` metadata. It never reads the agent execution
  // store, and it was never broken by this split: `LocalWorker` mints the
  // anchor itself as `'agx-${request.workerExecutionId}'`
  // (`local_worker.dart`), records it on the worker execution, and the
  // coordinator stamps that same id onto the work item
  // (`stamped.executionId == request.executionId`). Both ends of that join are
  // columns of `worker_execution`. Swapping this store therefore changes NO
  // discriminator verdict and moves NO tick-order outcome; the stand-down is
  // evaluated before this store is read at all, and it reads a different store
  // entirely. See `apps/server/test/execution_store_wiring_test.dart`, which
  // proves the discriminator's verdicts on both sides of the artifact boundary
  // and pins the stand-down's independence from the execution store.
  //
  // ## WHAT IT DOES CHANGE
  //
  // Two things, both of them the point of the change. The review workload
  // resolver's reviewer executions become readable, so a review verdict can be
  // read and raised instead of logging `execution-not-terminal` with status
  // `null`. And `engineeringReviewMissingArtifact` stops bailing, so the
  // fail-closed park becomes reachable for exactly the items it exists for.
  final coordinator = buildTriageExecutionCoordinator(
    store: agentExecutionStore(db),
    workflowEngine: durableWorkflowEngine,
    runtime: AgentRuntime(registry: agentAdapters),
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
    // The three registrations below are the ONLY thing that makes this fleet
    // visible to `workerEndpoints.listWorkers` and to the Overview's
    // "N of M machines busy". Without them the table stays empty and the
    // surface reports a machine shortage that does not exist.
    registrationStore: workerRegistrationStore,
    platform: Platform.operatingSystem,
  );
  final reviewWorker = LocalWorker(
    workerId: 'w-review-local',
    poolId: 'review-pool',
    capabilities: engineeringReviewDefinition.requiredCapabilities,
    workspaceManager: GitWorktreeWorkspaceManager(workspaceRoot: workspaceRoot),
    executionDriver: CoordinatorAgentExecutionDriver(coordinator),
    workerStore: workerStore,
    registrationStore: workerRegistrationStore,
    platform: Platform.operatingSystem,
  );
  // THE IMPLEMENTER. A distinct worker id, so it holds its own lease and its own
  // role identity: a worker id is what distinguishes one lease from another, and
  // sharing one would mean the implementer and the reviewer could contend for
  // the same slot.
  //
  // Capabilities come from the DEFINITION, not from a list copied by hand. The
  // implementer lane genuinely commits (`ArtifactCommitter` runs `rev-parse`,
  // `checkout -B`, `add -A`, `commit`), so it needs `git`; a worker registered
  // with only `linux` would never be selected for an implementation job and the
  // scheduler would defer for ever while reporting itself healthy — the same
  // silent no-dispatch the empty registry produced, one level down.
  //
  // READER WARNING — this worker inherits the TRIAGE verification plan. All
  // three roles share one coordinator, whose single `verificationPlan` is
  // `git rev-parse --verify 'HEAD^{commit}'`: it cannot fail on a real
  // checkout, so NOTHING here verifies an implementation. Design §7.8 / `OD-6`
  // is open and awaits a role-scoped plan at the landing gate; the full
  // argument, and why a green implementation run must not be read as coverage,
  // is on [buildTriageExecutionCoordinator]. No second coordinator is created
  // here on purpose — that choice is `OD-6`'s, not this lane's.
  final implementWorker = LocalWorker(
    workerId: 'w-impl-local',
    poolId: 'impl-pool',
    capabilities: implementFeatureDefinition.requiredCapabilities,
    // Never the source repository itself: the agent runs in a detached
    // worktree, and cleanup only ever removes worktrees this platform created.
    workspaceManager: GitWorktreeWorkspaceManager(workspaceRoot: workspaceRoot),
    executionDriver: CoordinatorAgentExecutionDriver(coordinator),
    workerStore: workerStore,
    registrationStore: workerRegistrationStore,
    platform: Platform.operatingSystem,
  );
  final workerRegistry = WorkerRegistry()
    ..register(triageWorker)
    ..register(reviewWorker)
    ..register(implementWorker);
  final WorkerDispatch dispatch = WorkerDispatcherAdapter(
    WorkerDispatcher(registry: workerRegistry),
  );

  // ---- The durable fleet view, started HERE and not one line later. ----
  //
  // Placed immediately after the registry, before the dispatcher and long
  // before the scheduler exists: the first tick can dispatch within 30 seconds
  // of this line, and a fleet that dispatched before it was readable is the
  // exact defect this closes. It runs before the composition banner so the
  // banner can report the registration outcome instead of assuming it.
  final workerRegistration = await startWorkerRegistrationHeartbeat(
    workers: <LocalWorker>[triageWorker, reviewWorker, implementWorker],
    store: workerRegistrationStore,
    log: _log,
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

  // ---- The model policy: made DURABLE here, not left to a runtime guess. ----
  //
  // `model_policy` shipped empty, so every role silently inherited a hardcoded
  // fallback chosen inside the selection service at runtime — invisible,
  // unauditable, and untunable without a redeploy. Decision 2fe73e11 fixed the
  // default; this makes it a row an operator can see, read and change.
  //
  // Seeded, never migrated: no schema changes, and a role that already has a
  // row is left alone, so an operator's later tuning survives a restart.
  final modelSelection = ModelSelectionService(modelPolicyStore);
  final modelPolicySeeding = await _seedModelPolicy(modelSelection);

  // ---- Liveness: the question a worker row cannot answer. ----
  //
  // The scheduler used to read "is this execution terminal?" and, when it was
  // not, renew the lease forever. A worker whose process died mid-execution is
  // also not terminal, so a zombie was renewed on every tick and the 10 minute
  // lease could never expire — which is how one execution sat in
  // `agentExecuting` for 4.78 hours with nothing behind it.
  //
  // The coordinator's live-session set is the real answer, and it lives in this
  // same process as this scheduler, so asking it is a local read.
  final executionLiveness = liveSessionLivenessProbe(
    // The real oracle, and the whole point of the wiring: this process's own
    // live agent sessions. A worker execution row cannot answer this — a
    // running agent and one whose process died an hour ago are both
    // `agentExecuting` — so without this the scheduler runs on its staleness
    // bound alone and an execution that legitimately runs long is reclaimed for
    // being slow rather than for being dead.
    (agentExecutionId) => coordinator.hasLiveSession(agentExecutionId),
  );

  // Read back what this scheduler's role will actually dispatch with, through
  // the SAME selector the request builder uses.
  final triageModelPolicy = await _describeModelInForce(
    modelSelection,
    triageDefectDefinition.requiredRole,
  );

  // The capacity guard, built over the store the scheduler will claim through.
  //
  // This is the ONLY thing standing between a deep queue and a host with no
  // memory left, and it is built from `capacity` — which could only have come
  // from `resolveDispatchCapacity`, which throws rather than return a
  // hand-picked number. There is no code path from here to a guard-less
  // Scheduler, and `Scheduler.capacitySummary` would say UNBOUNDED if there
  // were.
  final capacityGuard = JobCapacityGuard(store: jobStore, capacity: capacity);

  final scheduler = Scheduler(
    schedulerId: 'sched-triage',
    workflowStore: workflowStore,
    jobStore: jobStore,
    workerStore: workerStore,
    dispatch: dispatch,
    definition: triageDefectDefinition,
    // Without a selector the request carries NO model at all and the adapter
    // applies its own default — which is the silent, unpinned state this
    // wiring exists to remove.
    modelSelection: modelSelection,
    // Without this the scheduler runs on its staleness bound alone: an
    // execution nothing is running behind is still eventually reclaimed, but
    // only after the clock runs out, and one that legitimately runs long is
    // reclaimed for being slow rather than for being dead.
    executionLiveness: executionLiveness,
    // Without these the scheduler silently falls back to `_defaultDedupeKey` /
    // `_defaultInstruction` / `_defaultRequest`, which stamp
    // `AgentRole.triageDefect` jobs with
    // 'Implement "<title>" (...) inside the worktree.' — a feature
    // implementation instruction sent to a defect triage agent.
    dedupeKeyBuilder: triageDefectDedupeKey,
    instructionBuilder: triageDefectInstruction,
    requestBuilder: triageDefectRequest,
    capacityGuard: capacityGuard,
    workload: SchedulerWorkload(
      repositoryPath: triageSource.path,
      // A concrete commit, not the string 'HEAD'. The worktree manager refuses
      // a worktree whose HEAD does not equal the requested revision exactly,
      // and a literal 'HEAD' never equals a SHA.
      startingRevision: triageSource.startingRevision,
      // `AgentExecutionBudgets.triageSeconds`, NOT a literal — see that class
      // for the provenance of the number and for why it is provisional.
      timeoutSeconds: AgentExecutionBudgets.triageSeconds,
      // The id `OpencodeAdapter` is registered under above.
      runtimeTypeId: triageRuntimeTypeId,
    ),
    // Decoupled from `timeoutSeconds` deliberately: the scheduler's own default
    // is `timeoutSeconds * 4 + claimLease`, which is a five-minute-budget
    // heuristic and turns this lane's budget into a four-times-larger reclaim
    // window. See `AgentExecutionBudgets.zombieStalenessFor`.
    zombieStalenessAfter: AgentExecutionBudgets.zombieStalenessFor(
      AgentExecutionBudgets.byRole['triage-defect']!,
    ),
    clock: () => DateTime.now().toUtc(),
    providerHealthMonitor: providerHealthMonitor,
  );

  final reviewScheduler = Scheduler(
    schedulerId: 'sched-review',
    workflowStore: workflowStore,
    jobStore: jobStore,
    workerStore: workerStore,
    dispatch: dispatch,
    definition: engineeringReviewDefinition,
    modelSelection: modelSelection,
    executionLiveness: executionLiveness,
    dedupeKeyBuilder: engineeringReviewDedupeKey,
    instructionBuilder: engineeringReviewInstruction,
    requestBuilder: engineeringReviewRequest,
    capacityGuard: capacityGuard,
    // The review workload is NOT static. A reviewer must inspect the revision
    // the IMPLEMENTER produced, which is recorded on the implementer's worker
    // execution as `repositoryPath` + the artifact commit's `endingRevision`.
    // When no artifact can be resolved the resolver returns null and the
    // scheduler does NOT dispatch; the job surfaces in
    // `SchedulerTickResult.blockedArtifactMissing`, where the review drain turns
    // it into a blocking human decision (fail closed). Because null short-
    // circuits dispatch, the static `workload` below is inert for review; it is
    // kept only because it is a required constructor argument.
    workloadResolver: engineeringReviewWorkloadResolver(
      workerStore: workerStore,
      runtimeTypeId: triageRuntimeTypeId,
      // The one budget value in the composition, named explicitly here so the
      // resolver holds no literal of its own.
      timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
    ),
    // Inert for review: the resolver above is authoritative and a null result
    // prevents dispatch, so this static value never runs a reviewer. Its
    // timeout still tracks the real one, because a value that is inert today
    // and stale tomorrow is exactly how a second number grows.
    workload: SchedulerWorkload(
      repositoryPath: triageSource.path,
      startingRevision: triageSource.startingRevision,
      timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
      runtimeTypeId: triageRuntimeTypeId,
    ),
    // See the triage scheduler above: the default `timeoutSeconds * 4 +
    // claimLease` is not scaled for an hours-long budget.
    zombieStalenessAfter: AgentExecutionBudgets.zombieStalenessFor(
      AgentExecutionBudgets.byRole['engineering-review']!,
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

  // ---- A1's wiring, discharged here by A2 under C-1. ----
  //
  // The durable-workspace runtime creates and records a product's DURABLE clone.
  // A1 deliberately did not touch this file — C-1 gives it exclusively to this
  // lane — so its runtime had zero production callers until this line. It is
  // built over the SAME [productRegistryEngine] the baseline runtime uses, so
  // there is one registry engine in this process and two places to change if its
  // construction ever does.
  final durableWorkspaceRuntime = DurableWorkspaceRuntime.resolve(
    engine: productRegistryEngine,
    durableWorkspaceRoot: durableWorkspaceRoot,
    log: _log,
  );

  // ---- A3: run the operator instruction, ONCE, before anything can act on it. ----
  //
  // `DurableWorkspaceRuntime.provision` had zero production callers until this
  // line, which is why `ImplementationReadinessProbe` below defers every
  // implementation item: there was no clone to resolve. This is the caller.
  //
  // WHY A BOOT-TIME INSTRUCTION, and not an endpoint or a timer. The HTTP
  // endpoint surface is `src/endpoints/**`, which this lane does not own, and a
  // timer is precisely the thing this must not be: provisioning runs unattended
  // against a governed product's repository with a deploy key, and an operator
  // has to be the one who asked. A variable a human sets, and a start a human
  // initiates, is exactly that — and it is a shape nothing can reach by
  // accident, because no tick, sweep, probe or request can set an environment
  // variable.
  //
  // It runs BEFORE `implScheduler` is built, so a clone that exists is a clone
  // the scheduler can see from its first tick, and a trigger that failed is a
  // failed boot rather than a deployment left half-provisioned.
  final durableProvisionOutcome = await _runDurableWorkspaceProvision(
    durableProvisionInstruction,
    store: baselineRegistryStore,
    engine: productRegistryEngine,
    runtime: durableWorkspaceRuntime,
  );

  // ---- The IMPLEMENTATION scheduler: `sched-impl`. ----
  //
  // Its entry state is `implementationReady` and nothing else, which is what
  // makes it structurally unable to contend with `sched-triage`: the evaluator
  // rejects any item outside its own `entryStates` before it asks the policy
  // anything, and the entry hopper may only land a hop on its own definition's
  // entry states. No guard has to be remembered for that to hold.
  //
  // THE RESOLVER IS AUTHORITATIVE AND THE STATIC WORKLOAD BELOW IS INERT. That
  // is the single most dangerous line in this composition and it is called out
  // here for that reason: `Scheduler` requires a `workload`, so this one names
  // the TRIAGE repository — a README-only scratch checkout. The readiness probe
  // resolves the product's durable clone or returns null, and a null means NO
  // DISPATCH: no request is built, the job stays queued with its retry budget
  // untouched, and nothing runs. If the probe ever fell through to the static
  // value, the implementer would commit into the triage repository and produce
  // an artefact a reviewer could find — a green review of a fabrication, which
  // is strictly worse than the stranded items this lane exists to fix.
  final implementationProbe = ImplementationReadinessProbe(
    readProductState: (productId) async {
      try {
        return (await productRegistryEngine.readProduct(productId)).state;
      } on Object {
        // A product that does not exist is a null answer, not a crash: the
        // probe defers either way, and the two produce the same operator-facing
        // outcome.
        return null;
      }
    },
    readOnboarding: baselineRegistryStore.readOnboardingForProduct,
    runtimeTypeId: triageRuntimeTypeId,
    // The ONE implementation budget, named here and read again below for the
    // inert static workload. It is the readiness probe's value that actually
    // runs an implementer, because the probe is the authoritative workload
    // resolver for this lane.
    //
    // 4 hours, against the 1800s (30 minutes) this carried before — a number
    // whose only stated justification was that it was different from the review
    // lane's 300, and which an operator reports an implementation run
    // ROUTINELY EXCEEDS. PROVISIONAL: see `AgentExecutionBudgets`.
    timeoutSeconds: AgentExecutionBudgets.implementationSeconds,
    durableRuntimeAvailable: durableWorkspaceRuntime.isAvailable,
    durableRuntimeUnavailableReason: durableWorkspaceRuntime.availableReason,
    log: _log,
  );

  final implScheduler = Scheduler(
    schedulerId: 'sched-impl',
    workflowStore: workflowStore,
    jobStore: jobStore,
    workerStore: workerStore,
    dispatch: dispatch,
    definition: implementFeatureDefinition,
    modelSelection: modelSelection,
    executionLiveness: executionLiveness,
    dedupeKeyBuilder: implementFeatureDedupeKey,
    instructionBuilder: implementFeatureInstruction,
    requestBuilder: implementFeatureRequest,
    capacityGuard: capacityGuard,
    workloadResolver: toWorkloadResolver(
      implementationProbe,
      log: _log,
    ),
    // Required constructor argument. INERT — see above.
    workload: SchedulerWorkload(
      repositoryPath: triageSource.path,
      startingRevision: triageSource.startingRevision,
      // The SAME constant the readiness probe above uses. Tracking it is
      // deliberate: an inert value that drifts from the real one is a future
      // lie, and the cost of tracking it is one identifier.
      timeoutSeconds: AgentExecutionBudgets.implementationSeconds,
      runtimeTypeId: triageRuntimeTypeId,
    ),
    // See the triage scheduler above for why this is not left to the default
    // `timeoutSeconds * 4 + claimLease`. At a 4-hour budget that default is a
    // 16.7-hour reclaim window.
    zombieStalenessAfter: AgentExecutionBudgets.zombieStalenessFor(
      AgentExecutionBudgets.byRole['implement-feature']!,
    ),
    clock: () => DateTime.now().toUtc(),
    providerHealthMonitor: providerHealthMonitor,
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
    // The DURABLE fleet view, and what this start actually wrote into it. Stated
    // in both directions for the same reason `durableWorkspaceProvision` below
    // is: a process that registered three workers and one that registered none
    // must not print the same line. `registered` is what `listWorkers` will now
    // return; `failed` is what it will not, and why.
    'workerRegistration': workerRegistration.report.describe(),
    'repositoryPath': triageSource.path,
    'startingRevision': triageSource.startingRevision,
    'workspaceRoot': workspaceRoot,
    'providerHealthMonitor': true,
    'providerHealthCheckIntervalMinutes': 5,
    'baseline': baselineRuntime.describe(),
    // A1's durable-workspace runtime. Its STATE, in both directions: an
    // unavailable runtime names why and says every call is refused, because
    // "the field is absent" is the ambiguity this entry point exists to
    // remove — and a lane that is constructed but silently refusing every call
    // looks exactly like a lane that does not exist.
    'durableWorkspace': durableWorkspaceRuntime.describe(),
    // What this START did about it. Absence is a state and it is printed, the
    // same way `work_entry.sweep.disabled` is: an operator reading one line can
    // tell "nobody asked for a durable clone" from "we asked and it failed",
    // without grepping for something that is not there.
    'durableWorkspaceProvision': durableProvisionOutcome,
    // The implementation lane, in the same spirit. `schedulerId` and the
    // definition's own entry states, so an operator can see from the banner that
    // the lane exists AND what puts items into it. `OD-3` is resolved: four
    // rework/reject decisions retarget `implementation_ready`, and `OD-10`'s
    // completion inflow adds one automatic producer. So the lane is wired and
    // REACHABLE, and the comment that used to sit here — that no routing entry
    // targets it because the rework pairs were an open decision — was false on
    // every clause. The distinction this banner still has to preserve is the
    // one that survives: a lane that is wired and has nothing routed into it is
    // not the same as a lane that is idle because it is broken.
    'implementation': {
      'schedulerId': implScheduler.schedulerId,
      'definition': implementFeatureDefinition.jobType.wire,
      'entryStates':
          implementFeatureDefinition.entryStates.map((s) => s.wire).toList()
            ..sort(),
      'workerId': implementWorker.workerId,
      'capabilities':
          implementFeatureDefinition.requiredCapabilities
              .map((c) => c.name)
              .toList()
            ..sort(),
      'capacity': implScheduler.capacitySummary,
      'producers':
          'four resolved human decisions route here: (engineeringReview, '
          'rework), (humanQaApproval, reject), (qaRework, reject) and '
          '(qaWaiver, reject) — a gate reworking or rejecting work that '
          'already exists means re-implement, not re-triage (OD-3). One '
          'completion inflow also lands here: an agent_completed item this '
          'scheduler produced NO commit for is retargeted for another pass '
          '(OD-10); one that did commit is left for review, untouched. '
          '(escalation, approve) deliberately does NOT route here — an '
          'escalation is a statement about EXECUTION failing, not about work '
          'quality, so it re-plans at design_not_required. The lane is wired '
          'and REACHABLE, so an idle implementation scheduler means items are '
          'not arriving at these producers, not that the lane is inert',
    },
    // The cap IN FORCE, not the cap that was requested. Read back off the
    // scheduler rather than off the local `capacity` variable so that this line
    // and the object actually dispatching can never disagree — `capacitySummary`
    // is written to state UNBOUNDED when no guard is attached, which means this
    // field is incapable of quietly describing a bound that is not there.
    'capacity': scheduler.capacitySummary,
    // Which model is in force for this scheduler's role, read back through the
    // SAME selector the dispatch path uses, so this line and the request that
    // is actually built cannot disagree. `source` says whether it came from a
    // durable `model_policy` row or from the operator-configured default, and
    // the seeding fields say whether the table was populated at startup or the
    // process is running on the in-code default.
    'modelPolicy': {
      ...modelPolicySeeding,
      'inForceModelId': triageModelPolicy.modelId,
      'inForceSource': triageModelPolicy.source.name,
      'inForceIsFallback': triageModelPolicy.isFallback,
      'defaultModelId': kConfiguredDefaultModelId,
      'defaultDecisionId': kConfiguredDefaultDecisionId,
    },
    // The gate's STATE, in both directions — not a claim that the sweep runs.
    // Present when it does not, because "the field is absent" is exactly the
    // ambiguity this entry point is supposed to remove. The sweep's liveness,
    // once enabled, is the per-tick `work_entry.sweep.completed` line; that is
    // a fact no startup-time field can carry.
    'defectTriageSweep': workEntrySweepGate.describe(),
    // The agent-execution budgets in force, AND their staleness bounds, read
    // back off the live schedulers rather than off `AgentExecutionBudgets` —
    // the same discipline as `capacitySummary` above: this banner must be
    // incapable of describing a bound the object actually dispatching under
    // does not have.
    //
    // Printed because a provisional number nothing prints is a provisional
    // number nobody remembers to re-derive. The values here are ceilings chosen
    // from operator-stated ranges; the Models -> Stats "Run duration" panel is
    // what should replace them.
    'agentExecutionBudgets': {
      ...AgentExecutionBudgets.describe(),
      // The staleness bound is read back OFF THE LIVE SCHEDULER, not off the
      // table, so this line cannot describe a window the dispatching object
      // does not actually have. Same discipline as `capacitySummary` above.
      'stalenessBoundInForce': {
        'triage': scheduler.zombieStalenessBound.inSeconds,
        'review': reviewScheduler.zombieStalenessBound.inSeconds,
        'implementation': implScheduler.zombieStalenessBound.inSeconds,
      },
      'livenessInForce': {
        'triage': scheduler.livenessSummary,
        'review': reviewScheduler.livenessSummary,
        'implementation': implScheduler.livenessSummary,
      },
    },
  });

  // Run the scheduler every 30 seconds — ONE tick at a time.
  //
  // `Timer.periodic` does NOT await its callback. `scheduler.tick()` blocks for
  // a full agent execution, so the callback outlives its 30 s period and the
  // next tick starts anyway: every tick re-reads all jobs and re-attempts a
  // dispatch for everything the previous tick has not yet claimed. That overlap
  // — not unbounded per-tick concurrency — is what turned 9 queued defects into
  // 9 simultaneous agent sessions and exhausted the host on 2026-10-10.
  //
  // [TickSingleFlight] is what makes the two properties consistent: at most one
  // tick in flight, and every trigger accounted for. A trigger that arrives
  // while a tick runs does not wait — QUEUEING it would rebuild the pile-up one
  // level down — and does not quietly do nothing either. It is dropped, and the
  // drop is logged as its own event.
  //
  // ---- BUDGET-BLOCKED TICK: READ THIS BEFORE RAISING A BUDGET AGAIN ----
  //
  // THE BLOCKING FIGURE IS N × BUDGET, NOT ONE BUDGET. Read this before you
  // read any sentence below as "a long run".
  //
  // `Scheduler.tick()` dispatches inside a `for (;;)` loop: it re-reads the
  // eligible jobs, takes the batch that is still eligible, and `await`s
  // `_dispatchOne(job, now)` for each of them SERIALLY. `_dispatchOne` awaits
  // `_dispatch.run(request)` — the whole agent execution, start to terminal.
  // There is NO per-tick dispatch cap: one tick attempts EVERY job that was
  // eligible when it started.
  //
  // So the single flight is held for the SUM over everything that tick
  // dispatched, not for the longest of them:
  //
  //     tick blocked for  Σ (N × budget)  =  N × budget
  //
  // where N is the number of eligible jobs that tick attempted, and each job is
  // bounded by ITS OWN role's budget (30m triage / 3h review / 4h
  // implementation). N is bounded only by the backlog, so THE FIGURE IS
  // UNBOUNDED IN THE BACKLOG: a tick that drains a 10-job backlog can hold the
  // single flight for up to ~40 hours at the implementation budget. The honest
  // range for "how quiet is the console" is HOURS TO DAYS, not one budget. An
  // earlier version of this comment said "as long as the longest run it
  // dispatched"; that understated the stall by the backlog size, which is the
  // exact error this repo's rule against unstatable numbers exists to prevent.
  //
  // Every 30 s trigger during that window is DROPPED, not queued. This
  // composition runs all three schedulers inside one single-flight callback, so
  // a long implementation run also delays triage and review, not just its own
  // lane.
  //
  // This is PRE-EXISTING and NOT fixed by this change: at the old 300 s review
  // budget roughly 90% of triggers were already dropped during a single review
  // run, and at the raised budgets it is worse by the same factor of N. It is
  // written down here rather than fixed here because every candidate fix is a
  // composition change — a per-tick dispatch cap, moving dispatch off the tick,
  // or giving each lane its own single flight — and each is its own decision
  // with its own ownership, not something a budget change should smuggle in.
  //
  // What an operator should expect: a long run is not a silent hang, it is a
  // logged `scheduler.tick.dropped_overlap` per period. If that line is
  // appearing constantly with no work completing, the BACKLOG DEPTH, the budget
  // and the tick period are the three things to look at, in that order — the
  // backlog first, because it is the multiplier.
  final tick = TickSingleFlight(
    log: _log,
    runTick: () async {
      final outcome = TickOutcome(failedSections: <String>[]);

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
            JobType.engineeringReview: engineeringReviewTickHandler(
              workflowEngine: durableWorkflowEngine,
              executionStore: coordinator.store,
              // The triage lane never settles a review job — the registration is
              // completeness, not a live path (see the note above) — but the
              // handler is the SAME one the review section builds, and it routes
              // rather than parks, so it needs the same artifact source. Wiring
              // it here keeps the two registrations from describing different
              // gates.
              workerStore: workerStore,
              logger: _log,
            ),
          },
          logger: _log,
        );
        outcome.dispatched = tickResult.dispatched.length;
        outcome.handledOff = drain.handedOff;

        // The stall channel, drained here for the same reason the review
        // section drains `blockedArtifactMissing`: a scheduler conclusion that
        // nobody converts into a human-owned state is not surfacing. Before
        // this, a stall was written to `scheduler_event.payloadJson` and read by
        // nobody while the item's state said `agent_completed` and every
        // operator screen called it "Awaiting review".
        outcome.foldStalls(
          await raiseStallDecisions(
            workflowEngine: durableWorkflowEngine,
            executionStore: coordinator.store,
            stalls: tickResult.stalled,
            logger: _log,
          ),
        );
        // Rows the per-row guard caught. Reported here because the completion
        // line is the only channel the scheduler has; leaving them here would
        // make a contended or faulting reclaim indistinguishable from a clean
        // tick.
        outcome.reconcileFailed.addAll(
          tickResult.reconcileFailed.map((f) => f.toString()),
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
        outcome.failedSections.add('triage');
        _log('scheduler.tick.failed', {'error': '$e', 'stack': st.toString()});
      }

      // ---- The implementation lane's tick. ----
      //
      // FIRST of the two lanes that share `agentCompleted`, and that placement
      // is load-bearing rather than cosmetic. `sched-impl` declares a
      // `completionInflowFrom`, so its tick ROUTES items out of `agentCompleted`
      // before it asks what is runnable; `sched-review`'s entry set is exactly
      // `{agentCompleted}`. Run implementation second — which is what this
      // composition did until a review found the outcome decided by `await`
      // order — and review parks a no-artifact item at `waitingForHumanDecision`
      // first, the inflow never sees it, and the lane designed to implement it
      // dispatches nothing.
      //
      // Order alone is not the fix: `engineeringReviewMissingArtifact` ALSO
      // stands down for an item the inflow is going to take, so reversing the
      // two sections changes nothing observable. Both halves are asserted, in
      // both orders, by
      // `apps/server/test/implementation_inflow_tick_order_test.dart`.
      //
      // In its OWN try, like triage and review: a lane that throws must not take
      // the others down, and they read the same job store while answering three
      // different questions.
      //
      // NO `blockedArtifactMissing` HANDLER, deliberately. For review that
      // channel means "there is nothing to review", and `engineeringReview-
      // MissingArtifact` turns it into a blocking human decision. Applying a
      // review action to an implementation job would move a work item through a
      // gate it never entered and raise a decision about "no artifact was
      // produced" for an item that never started. For implementation the same
      // channel currently carries DEFERMENTS — no product is governed yet, no
      // durable workspace exists yet, the recorded clone is stale — and those
      // resolve themselves. Which channel a deferral SHOULD travel on is an
      // open design decision, so this section reports and logs and stops.
      try {
        final implTick = await implScheduler.tick();
        outcome.implDispatched = implTick.dispatched.length;

        // The implementation lane stalls too, and on the SAME channel. It is
        // drained for the same reason as the two above: a conclusion that
        // reaches no human is not a conclusion the platform acted on.
        outcome.foldStalls(
          await raiseStallDecisions(
            workflowEngine: durableWorkflowEngine,
            executionStore: coordinator.store,
            stalls: implTick.stalled,
            logger: _log,
          ),
        );

        for (final jobId in implTick.blockedArtifactMissing) {
          _log('implementation.deferred', {
            'jobId': jobId,
            'reason':
                'the readiness probe could not resolve a durable product '
                'workspace for this job, so nothing was dispatched. Not '
                'failed, no human decision raised, no retry consumed',
            'action':
                'resolved automatically once the product is governed and its '
                'durable clone exists at its recorded pin. If this repeats for '
                'a governed product, read the probe\'s own '
                'implementation.deferred.* reason for the specific gate',
          });
        }
        if (implTick.dispatched.isNotEmpty) {
          _log('implementation.tick.dispatched', {
            'jobIds': implTick.dispatched,
          });
        }
      } catch (e, st) {
        outcome.failedSections.add('implementation');
        _log('implementation.tick.failed', {
          'error': '$e',
          'stack': st.toString(),
          'action':
              'implementation dispatch is retried on the next tick; other lanes '
              'unaffected',
        });
      }

      // The review half of the tick, in its own try: a review tick that
      // fails must not prevent onboarding or the implementation lane from
      // running, and vice versa. They read the same job store but answer
      // different questions, and one of them throwing says nothing about the
      // other.
      //
      // SECOND of the two lanes that share `agentCompleted`, after
      // `implScheduler.tick()` — see the ordering note on that section. By the
      // time this runs, every item the inflow owns has already left
      // `agentCompleted`, so this lane's entry set no longer claims it and the
      // stale review job it left is retired as `noAction`.
      try {
        await runReviewLaneTick(
          reviewScheduler: reviewScheduler,
          jobStore: jobStore,
          triageProcessor: triageProcessor,
          workflowEngine: durableWorkflowEngine,
          executionStore: coordinator.store,
          workerStore: workerStore,
          foldStalls: outcome.foldStalls,
          log: _log,
        );
      } catch (e, st) {
        outcome.failedSections.add('review');
        _log('review.tick.failed', {
          'error': '$e',
          'stack': st.toString(),
          'action':
              'review dispatch is retried on the next tick; other lanes unaffected',
        });
      }

      try {
        final baselinePass = await baselineRuntime.runOnce();
        _log('baseline.tick.completed', {
          'sweep': baselinePass.sweep?.toString(),
          'dispatch': baselinePass.dispatch.toString(),
        });
      } catch (e, st) {
        outcome.failedSections.add('baseline');
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
          outcome.sweepEnqueued = sweepPass.enqueued.length;
          _log('work_entry.tick.completed', {'sweep': sweepPass.toString()});
        } catch (e, st) {
          outcome.failedSections.add('workEntrySweep');
          _log('work_entry.tick.failed', {
            'error': '$e',
            'stack': st.toString(),
            'action':
                'work entry is retried on the next tick; triage and baseline are '
                'unaffected',
          });
        }
      }

      // NOTE: the sweep carries its own single-flight guard, and it is a
      // narrower one — it stops two ticks reaching the sweep together, and it
      // reports its own drops as `work_entry.sweep.pass_overlapped`. This guard
      // is the outer of the two: it stops the two ticks existing at all. The
      // sweep's drops are therefore always zero here, and are not re-reported.

      return outcome;
    },
  );

  Timer.periodic(const Duration(seconds: 30), (_) {
    // `unawaited`, and not `async` on this closure: the guard must be taken
    // synchronously, before the first `await` anywhere above it. An `async`
    // closure would hand the guard decision to the microtask queue and the
    // timer would be free to fire again first — the exact race this lane
    // exists to close.
    unawaited(tick.trigger());
  });
}

/// Starts the durable worker-registration lifecycle for [workers] and returns
/// the running [WorkerRegistrationHeartbeat]. What it wrote is on that
/// heartbeat's [WorkerRegistrationHeartbeat.report].
///
/// Extracted for the same reason [buildTriageExecutionCoordinator] and
/// [agentExecutionStore] were: so the exact wiring this server runs is
/// reachable from a test without booting a server, a database or an `opencode`
/// binary. A named seam is the difference between a wiring that is PINNED and one
/// that is merely correct today — this is the third time a healthy-looking
/// composition has shipped with a real store in scope and nothing routing to it,
/// and the test that calls this function is the thing that notices the next one.
///
/// ## WHY IT IS `Future` AND IT HAS NO ERROR PATH
///
/// [WorkerRegistrationHeartbeat.start] reports per-worker failures rather than
/// throwing. A registration write that fails at boot must not take the control
/// plane down — every lane in this composition runs off the same database, and a
/// row that could not be written is a fact the next heartbeat retries and the
/// startup banner reports. Failing the boot instead would convert a
/// under-reported fleet into a server that dispatches nothing.
///
/// ## THE TIMER IT LEAVES RUNNING, STATED RATHER THAN IMPLIED
///
/// This process has NO in-process shutdown hook. `run()` never returns — its
/// last statement is the `Timer.periodic` that keeps the scheduler ticking — and
/// `Serverpod.shutdown` was deliberately not adopted (see the note at the
/// provision-failure branch: with `exitProcess: true` it exits **0**, inverting
/// the deliberate non-zero signal that branch exists to give, and with
/// `exitProcess: false` it trades away the immediacy an operator watching a
/// shell is waiting for). So nothing calls [WorkerRegistrationHeartbeat.stop]
/// in production today.
///
/// That is NOT a hang. A Dart timer cannot keep a process alive that is being
/// terminated from outside: the container is stopped, not politely asked. It is
/// the same position the `ProviderHealthMonitor`'s five-minute `Timer.periodic`
/// and the scheduler's own `Timer.periodic` are already in, and the precedent is
/// recorded at the provision-failure branch above.
///
/// What [WorkerRegistrationHeartbeat.stop] buys is therefore the *other*
/// direction: the lifecycle is cancellable, bounded, and proven so that a
/// graceful-shutdown path has one call to make when a future lane adopts one,
/// rather than a timer nobody can stop.
Future<WorkerRegistrationHeartbeat> startWorkerRegistrationHeartbeat({
  required List<LocalWorker> workers,
  required WorkerRegistrationStore store,
  void Function(String event, Map<String, dynamic> fields)? log,
}) async {
  final heartbeat = WorkerRegistrationHeartbeat(
    workers: workers,
    store: store,
    log: log,
  );
  await heartbeat.start();
  return heartbeat;
}

/// What one [runReviewLaneTick] concluded, for the composition root to report.
class ReviewLaneTickResult {
  const ReviewLaneTickResult({
    required this.drain,
    required this.missingArtifactJobIds,
    required this.settledRedrive,
  });

  /// The terminal-job drain.
  final TriageTickDrainResult drain;

  /// Every `blockedArtifactMissing` job id this pass turned into a route or a
  /// decision, in the order the scheduler reported them.
  final List<String> missingArtifactJobIds;

  /// What the third door did: every terminal review job whose settled outcome
  /// neither of the two doors above consumed, handed to the SAME
  /// `engineeringReviewTickHandler` exactly once each.
  ///
  /// Reported because "the review section found nothing to do" and "the review
  /// section found a stranded review and acted on it" must be distinguishable to
  /// whoever reads the tick, and only one of them is visible without this.
  final SettledReviewRedrive settledRedrive;
}

/// The composition root's REVIEW section, in the one order production runs it.
///
/// ## WHY THIS IS A NAMED FUNCTION AND NOT A BLOCK OF `run`
///
/// Because a test cannot exercise an `await` order it can only read, and the
/// order in this section decided the outcome of a shipped feature. Reviewer
/// `DO_NOT_MERGE` finding B2 on `integrate/combined-3@43b2faa` was that
/// decision `92d567e3-da03-4c43-99f4-e3726472f0ab`'s `REREVIEW -> AUTOMATIC`
/// route was built, tested green, and unreachable: this drain runs BEFORE the
/// `blockedArtifactMissing` loop below, so the verdict-absent case was parked at
/// `waitingForHumanDecision` here, and `engineeringReviewMissingArtifact` —
/// which holds the route — returned at its first guard on an already-parked item.
/// The branch could not have reached it either, for a structural reason recorded
/// on that function.
///
/// Every test of it called one handler in isolation instead, which is a green
/// suite over a dead end. Extracting the order makes it callable, so
/// `apps/server/test/engineering_review_composition_order_test.dart` drives
/// THESE `await`s against the real [Scheduler]s and the real stores. A replica
/// in the test file would drift on the next edit, which is the failure mode this
/// extraction exists to close.
///
/// The order itself is unchanged and is still load-bearing; see the call site for
/// why the implementation lane's tick comes first.
Future<ReviewLaneTickResult> runReviewLaneTick({
  required Scheduler reviewScheduler,
  required JobStore jobStore,
  required TriageProcessor? triageProcessor,
  required DurableWorkflowEngine workflowEngine,
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required void Function(StallGateResult stalls) foldStalls,
  required void Function(String event, Map<String, dynamic> data) log,
}) async {
  final reviewTick = await reviewScheduler.tick();

  // THIRD and last stall drain. `SchedulerStall` is scoped to the lane
  // that raised it (two schedulers share one `JobStore`), so each lane
  // drains its own — a lane's refusal to launch is not another lane's
  // business, and merging them would raise a decision one lane's refusal
  // caused on an item another lane owns.
  //
  // Folded HERE, where the inline block folded it, and not returned for the
  // caller to fold at the end: a stall conclusion must survive a failure in a
  // LATER step of this section, or the review section throws on an unhandled
  // job type and the stall it had already reached a human about disappears
  // from the report.
  foldStalls(
    await raiseStallDecisions(
      workflowEngine: workflowEngine,
      executionStore: executionStore,
      stalls: reviewTick.stalled,
      logger: log,
    ),
  );

  final reviewDrain = await drainTriageOutcomesFromTick(
    tickResult: reviewTick,
    jobStore: jobStore,
    triageProcessor: triageProcessor,
    // The dispatch table must be as COMPLETE as the triage drain's above.
    // `onboardProduct` jobs are product-scoped and claimed by
    // `BaselineProductDispatcher`, so they never appear in this tick's
    // result — the handler is registered anyway because the alternative is
    // an `UnhandledJobTypeException`: `drainTriageOutcomesFromTick`
    // dispatches BY TYPE and THROWS for any job it considers with no
    // handler, which would fail this whole review section rather than just
    // the one job. Registering it is how the triage drain already stays
    // complete, and the two must not drift.
    handlers: {
      JobType.onboardProduct: (job) =>
          observeCompletedOnboardingJob(job: job, logger: log),
      JobType.engineeringReview: engineeringReviewTickHandler(
        workflowEngine: workflowEngine,
        executionStore: executionStore,
        workerStore: workerStore,
        logger: log,
      ),
    },
    logger: log,
  );
  if (reviewDrain.handedOff > 0) {
    log('review.tick.drained', {
      'considered': reviewDrain.considered,
      'skipped': reviewDrain.skipped,
      'handedOff': reviewDrain.handedOff,
    });
  }

  // Fail closed. A review job the scheduler could not resolve a produced
  // artifact for was never dispatched (the resolver returned null), so no
  // reviewer ran and the work item is still at `agentCompleted`. Turn each
  // into a route or a blocking human decision, entering `reviewInProgress`
  // first because `agentCompleted` has no direct edge to the
  // human-decision state. The scheduler re-surfaces the same job every tick
  // until the item leaves `agentCompleted`, so this must be idempotent — the
  // handler is.
  //
  // It also STANDS DOWN for a no-artifact producer, because the item is
  // not review's to decide about: `producedCommitFor` says nothing was
  // committed, so the implementation lane's inflow owns it. Parking there
  // instead is what used to make the outcome depend on the order of the
  // two `await`s above.
  //
  // AFTER the drain, and that is deliberate rather than incidental. The drain
  // owns every job this tick settled; a job in `blockedArtifactMissing` is
  // still `queued` and is in none of the drain's three sets, so the two cannot
  // both reach one job in one tick. The order is kept because reversing it was
  // tried and `implementation_inflow_tick_order_test.dart` exists to keep it
  // tried.
  final handled = <String>[];
  for (final jobId in reviewTick.blockedArtifactMissing) {
    try {
      final job = await jobStore.readJob(jobId);
      if (job == null) {
        log('review.missing-artifact.job-not-found', {'jobId': jobId});
        continue;
      }
      await engineeringReviewMissingArtifact(
        workflowEngine: workflowEngine,
        executionStore: executionStore,
        workerStore: workerStore,
        job: job,
        logger: log,
      );
      handled.add(jobId);
    } catch (e, st) {
      log('review.missing-artifact.failed', {
        'jobId': jobId,
        'error': '$e',
        'stack': st.toString(),
        'action':
            'fail-closed decision is retried on the next tick; other lanes unaffected',
      });
    }
  }

  // THIRD DOOR, and last, so the order the two doors above run in is unchanged
  // and provably so.
  //
  // `drainTriageOutcomesFromTick` hands a terminal job to its handler exactly
  // once, ever. So when `engineeringReviewTickHandler` runs a moment before the
  // reviewer's execution settles — which `Scheduler._reclaimZombie` produces on
  // its own, by settling a job whose claim lapsed while the agent session was
  // still open — its `execution == null || !execution.isTerminal` guard returns,
  // and the job it would have consumed is never reported again. A reviewer that
  // finishes two minutes later writes its verdict into a row nobody reads: on
  // `defect-DEF-1791684804452198` at `main@104d807` that was
  // `{"verdict":"changes_required", …}` on an item left at `review_in_progress`
  // with `blockingHumanDecisionId` NULL.
  //
  // This reach acts ONLY on a review whose execution is terminal, so a reviewer
  // running right now is never disturbed, and it hands each such review to the
  // SAME handler exactly once — the bound is a durable marker on the reviewer's
  // own execution timeline, not a counter in this process. See
  // `redriveSettledReviews` for the whole of it, including which of the
  // one-shot guards this was observed through and which the lane could not
  // distinguish from durable state alone.
  SettledReviewRedrive settledRedrive;
  try {
    settledRedrive = await redriveSettledReviews(
      workflowEngine: workflowEngine,
      executionStore: executionStore,
      workerStore: workerStore,
      jobStore: jobStore,
      logger: log,
    );
  } catch (e, st) {
    // Fail closed and LOUD. A sweep that cannot list its own jobs is a store
    // fault, and letting it escape would fail the whole review section — taking
    // the two doors above down with it, and reporting nothing at all.
    settledRedrive = const SettledReviewRedrive(
      consideredJobIds: [],
      redrivenJobIds: [],
      alreadyConsumedJobIds: [],
      failedJobIds: [],
    );
    log('review.settled-redrive.failed', {
      'error': '$e',
      'stack': st.toString(),
      'action':
          'no settled review was re-driven this pass. The other two review doors '
          'ran before this and are unaffected; the next tick tries again',
    });
  }

  return ReviewLaneTickResult(
    drain: reviewDrain,
    missingArtifactJobIds: List.unmodifiable(handled),
    settledRedrive: settledRedrive,
  );
}

/// The platform's independent verification for the TRIAGE role.
///
/// ## Why not the [VerificationPlan] default
///
/// The default is `dart test` (`execution_coordinator.dart`). That command
/// CANNOT pass in a triage worktree: the worktree is a `git worktree` of
/// `/triage-repo`, which contains only `README.md` — no `pubspec.yaml`, no
/// `test/` — so `dart test` exits non-zero ("No pubspec.yaml file found").
/// [`LocalWorker`] settles `passed = (agentResultStatus == completed) &&
/// (verificationPassed ?? true)`, so the failed check turned every triage job
/// whose agent succeeded into `executedFail` (`failureCode: agentFailed`,
/// `detail: "verification ver-… failed"`, `checkName: dart_test`). The defect
/// was present since the baseline commit and masked only because the
/// provider-health bug deferred every job before an agent could run.
///
/// ## Why this exact command
///
/// A triage worktree IS a git checkout, so the honest, cheap independent check
/// is that its `HEAD` resolves to a real commit in that worktree. It is the
/// same plan the triage execution integration test composes
/// (`apps/server/test/integration/triage_execution_test.dart`), and the same
/// one the production-reachability test composes for a triage-defect pipeline
/// (`lane_f_production_reachability_test.dart`); no composition establishes a
/// different intended triage plan. The DESIGN lane, by contrast, verifies with
/// `dart tool/verify.dart` over its own worktree — a different role with a
/// different repository, which is why the plan is pinned to triage here.
const VerificationPlan triageVerificationPlan = VerificationPlan(
  command: ['git', 'rev-parse', '--verify', 'HEAD^{commit}'],
  checkName: 'git_worktree_head',
);

/// Composes the ONE [ExecutionCoordinator] this server drives work through, with
/// the triage verification plan attached.
///
/// Extracted from [run] so that the composition — in particular the
/// [triageVerificationPlan] it attaches — is inspectable from a test without a
/// real `opencode` binary or a database. It is the production construction
/// path: [run] calls it, so a test that calls it exercises the same code the
/// server does, not a hand-built copy.
///
/// [run] supplies a Postgres-backed [ModelExecutionRecordStore]; a test may
/// omit it, exactly as a coordinator without one behaves in [run]'s absence.
///
/// ## The implementer inherits this plan, and this plan cannot fail
///
/// [ExecutionCoordinator] carries ONE [VerificationPlan] for every job it runs,
/// and all three roles in [run] — triage, review, implement — drive the same
/// coordinator (`CoordinatorAgentExecutionDriver(coordinator)`, `:229-278`).
/// So an implementation run is verified by
/// `git rev-parse --verify 'HEAD^{commit}'`, which succeeds for any checkout
/// that has a commit. That is a liveness check on the worktree; it verifies
/// nothing the implementer wrote.
///
/// **This is a known, unfilled gap — not a plan that is working.** Design §7.8
/// requires "a dedicated [VerificationPlan], pinned deliberately", and §9.3 row
/// 7 requires that plan's FAILURE land at `agentFailed` with no
/// `producerActorId` (`execution_coordinator.dart:782-812`; the failure branch
/// omits the `metadataMerge` at `:796` while success sets it at `:838`).
/// With this plan attached, that branch is UNREACHABLE for implementation jobs:
/// no implementation execution can ever be settled `executedFail` by
/// verification. §9.3's contract is therefore untested in production for the one
/// role it is written about.
///
/// **Do not read a green implementation execution as evidence that verification
/// ran.** Nothing here verifies it, and the absence of verification failures is
/// the absence of a test, not a passing one. The independent gate it enables is
/// §9.2 row 5 (`endingRevision` null ⇒ review fails closed), which is a real
/// check on the artefact — not on the code's behaviour.
///
/// TODO(design §7.8 / `OD-6`, OPEN at the landing gate): give the implementation
/// lane a verification plan of its own. HOW is an architecture decision this
/// lane must not make on its own — `ExecutionCoordinator` exposes a single
/// `verificationPlan` field for all roles, so a role-scoped plan needs either a
/// per-role coordinator or a plan resolved from the job's role, and `OD-6` is
/// where that decision belongs. Deliberately NOT chosen here: no second
/// `ExecutionCoordinator` is added and nothing under
/// `packages/execution_coordinator/` is touched.
ExecutionCoordinator buildTriageExecutionCoordinator({
  required ExecutionStore store,
  required DurableWorkflowEngine workflowEngine,
  required AgentRuntime runtime,
  ModelExecutionRecordStore? modelExecutionRecordStore,
}) => ExecutionCoordinator(
  store: store,
  workflowEngine: workflowEngine,
  runtime: runtime,
  verificationPlan: triageVerificationPlan,
  modelExecutionRecordStore: modelExecutionRecordStore,
);

/// The [ExecutionStore] the execution coordinator writes to.
///
/// Extracted for the same reason [buildTriageExecutionCoordinator] is: so the
/// exact store this process attaches is reachable from a test without booting
/// a server or an `opencode` binary. A named seam is the difference between a
/// wiring that is pinned and one that is merely correct today.
///
/// ## WHY IT IS NAMED, AND WHY THE NAME IS THE POINT
///
/// It returned a `FileJsonExecutionStore` pointed at
/// `${Directory.systemTemp}/execution_coordinator/store.json` until this fix.
/// The coordinator wrote every agent execution there while every reader read
/// PostgreSQL, and the two never met: `agent_execution` held zero rows across
/// 35 worker executions, so the engineering review gate could never read a
/// producer's result and its fail-closed park silently declined to act — on
/// every tick, for ever. The two stores looked interchangeable because
/// `ExecutionStore` is an interface and both implementations satisfy it. Nothing
/// about the type system, and no test, would have said otherwise.
///
/// So the store the production composition attaches is named here, and the
/// integration suite drives THIS function end to end — a real `LocalWorker`,
/// a real `ExecutionCoordinator`, a real producer run — then asserts that
/// `agent_execution` gained the row and that the review gate can act on it. If
/// anyone reintroduces a store the readers cannot see, that test fails on the
/// missing row, not on a class name.
///
/// A unit test asserting `agentExecutionStore(db) is PostgresExecutionStore`
/// would pass against a wiring that is still wrong, and would have passed
/// against the file store too. The behaviour is the assertion.
ExecutionStore agentExecutionStore(PersistenceDatabase db) =>
    PostgresExecutionStore(db);

/// The code carried by a tick that was dropped because another was still
/// running.
///
/// Declared here rather than inlined so the log line, the result value and the
/// test cannot disagree about its spelling — the same reason
/// `sweepPassOverlappedCode` exists in `defect_triage_sweep.dart`.
const String tickOverlapDroppedCode = 'TICK_OVERLAP_DROPPED';

/// What one completed tick did.
///
/// Mutable and filled in as the tick proceeds, because a tick is assembled from
/// three independent halves that each catch their own failures: the counts have
/// to be readable at the moment the tick ends, whichever halves ran.
///
/// The numbers exist so the completion line can distinguish "ran and dispatched
/// nothing" from "did not run at all". That distinction is the whole reason a
/// drop is allowed to exist, so it is worth carrying rather than inferring.
class TickOutcome {
  TickOutcome({
    List<String>? failedSections,
    List<String>? reconcileFailed,
  }) : failedSections = failedSections ?? <String>[],
       reconcileFailed = reconcileFailed ?? <String>[];

  /// Jobs this tick actually started an execution for.
  int dispatched = 0;

  /// Terminal jobs handed off to the triage processor this tick.
  int handledOff = 0;

  /// Defects this tick enqueued a triage job for. Always zero unless the
  /// work-entry sweep gate is on.
  int sweepEnqueued = 0;

  /// Jobs this tick started an implementation execution for.
  ///
  /// Separate from [dispatched] rather than folded into it, because the two
  /// answer different questions and conflating them hides a lane that stopped
  /// working. `dispatched` is the TRIAGE tick's count; this is the
  /// implementation lane's. A reader who wants "did anything get built" reads
  /// this, and a reader who wants "did triage run" reads the other.
  int implDispatched = 0;

  /// Jobs this tick could not reconcile, with the reason each one failed.
  ///
  /// Separate from [failedSections] on purpose: a failed SECTION is a half of
  /// the tick that threw, whereas these are individual rows the per-row guard
  /// caught so the rest of the tick could continue. Folding them into
  /// `failedSections` would report a section that in fact ran clean.
  ///
  /// This list is the ONLY way a swallowed reconciliation failure reaches an
  /// operator. The per-row guard stops one bad row from aborting the tick, which
  /// means without this the tick would report success — dispatching fresh work —
  /// while leaking reclaim capacity forever, and the completion line would read
  /// exactly like a healthy one.
  final List<String> reconcileFailed;

  /// Which halves of the tick threw, named. Empty is a tick that ran clean.
  ///
  /// Named rather than counted because "the tick failed" is not actionable and
  /// "the baseline half failed" is — and because an unnamed failure is the one
  /// that reads as "nothing to do".
  final List<String> failedSections;

  /// What the stall drain did across all three lanes this tick.
  ///
  /// A VALUE and not a set of counters because it is summed from three lanes,
  /// and summing counts across lanes is how a reader ends up unable to say
  /// whether "3 raised" means three items or one item three times. This keeps
  /// each lane's contribution and the total separate, so both questions have an
  /// answer.
  StallGateResult stalls = StallGateResult.empty;

  @override
  String toString() =>
      'dispatched: $dispatched, handledOff: $handledOff, '
      'implDispatched: $implDispatched, '
      'sweepEnqueued: $sweepEnqueued, failedSections: $failedSections, '
      'reconcileFailed: $reconcileFailed, stalls: $stalls';

  /// Folds one lane's drain into [stalls].
  ///
  /// Counting, not collecting ids: the same item can legitimately stall on more
  /// than one lane, and a union of ids would report that as one item — the
  /// opposite of the reason this field exists. The per-lane counts are kept so
  /// "three lanes each raised one" and "one lane raised three" stay
  /// distinguishable.
  void foldStalls(StallGateResult other) {
    stalls = StallGateResult(
      considered: stalls.considered + other.considered,
      raised: stalls.raised + other.raised,
      alreadyPending: stalls.alreadyPending + other.alreadyPending,
      notParkable: stalls.notParkable + other.notParkable,
      producerEvidenceUnreadable:
          stalls.producerEvidenceUnreadable + other.producerEvidenceUnreadable,
      failedWorkItemIds: [
        ...stalls.failedWorkItemIds,
        ...other.failedWorkItemIds,
      ],
    );
  }
}

/// The outcome of ONE trigger: either a tick ran, or the trigger was dropped
/// because a tick was already running.
///
/// [ran] is the load-bearing field. A dropped trigger returns `ran: false` and a
/// null [outcome], so no caller can read a dropped tick as a tick that found
/// nothing to do — the two are not merely equal, they are not confusable.
class TickSingleFlightResult {
  const TickSingleFlightResult.dropped()
    : ran = false,
      outcome = null,
      overlappedTicks = 1;

  const TickSingleFlightResult.ran(this.outcome)
    : ran = true,
      overlappedTicks = 0;

  /// Whether the tick actually ran.
  final bool ran;

  /// What it did. Null exactly when [ran] is false.
  final TickOutcome? outcome;

  /// Always 1 for a dropped trigger and 0 for a completed one. Carried on EVERY
  /// result — including the ones that ran — so a consumer never has to tell an
  /// absent field from a zero.
  final int overlappedTicks;

  @override
  String toString() => ran
      ? 'ran: true, overlappedTicks: $overlappedTicks, outcome: $outcome'
      : 'ran: false, overlappedTicks: $overlappedTicks (dropped, code: '
            '$tickOverlapDroppedCode)';
}

/// One tick at a time, with every trigger accounted for.
///
/// ## Why a guard at all
///
/// `Timer.periodic` does not await its callback, and one tick blocks for a full
/// agent execution — which is now an HOURS-long budget, not `timeoutSeconds:
/// 300`. The callback therefore outlives its 30-second period by a factor of
/// two orders of magnitude, and without a guard every one of those periods
/// starts another tick. Each overlapping tick independently re-reads all jobs
/// and re-attempts a dispatch for everything the previous tick has not yet
/// claimed. Nine queued defects became nine simultaneous agent sessions that
/// way, and that is what exhausted the host.
///
/// ## Why a trigger is DROPPED rather than queued
///
/// A guard that serialised triggers instead would be correct and useless: the
/// thirty queued triggers would each run a full tick back to back, so the host
/// would see the same work, just later. Worse, the backlog would grow without
/// bound whenever a tick takes longer than the period, and the queue would
/// never drain. Dropping says the truth: that period's tick is already
/// accounted for by the one running.
///
/// ## Why the drop is never silent
///
/// A dropped tick and a tick that found nothing to do produce the same absence
/// of work. If the drop is not recorded, an operator looking at a quiet log
/// cannot tell a healthy idle system from one that has been silently dropping
/// every tick for a week. So the drop gets BOTH:
///
///  * its own event, `scheduler.tick.dropped_overlap`, greppable on its own
///    without knowing that the answer lives in a field of a line which otherwise
///    describes a tick that did real work; and
///  * a `scheduler.tick.completed` line, so that line keeps ONE shape and
///    carries `overlappedTicks` on every single tick including the zeroes.
///    Without the second, "no completed line" would be indistinguishable from
///    "a tick is still running".
///
/// Both shapes mirror `DefectTriageSweep.run`, which already carries this guard
/// for the narrower question of two passes over the same defects.
class TickSingleFlight {
  TickSingleFlight({
    required this.runTick,
    this.log,
  });

  /// The tick, invoked only after the guard has been taken. Public so the
  /// constructor can take it as an initializing formal, and so a test can hold
  /// the same reference the loop calls.
  final Future<TickOutcome> Function() runTick;

  /// Where the two events go. Null silences them, which is what a test that only
  /// cares about control flow wants.
  final void Function(String event, Map<String, dynamic> data)? log;

  /// The guard itself.
  ///
  /// ## Why this method is deliberately NOT `async`
  ///
  /// In an `async` body, a statement inserted above the `await` compiles, reads
  /// correctly in isolation, and silently converts a sound guard into an unsound
  /// one — because the whole body up to the first `await` runs in a microtask,
  /// so a second trigger arriving in that window takes the guard before the first
  /// one has. Making [trigger] non-`async` means there is no `await` between
  /// entry and the guard flip: the check and the set are two adjacent synchronous
  /// statements, so "the guard is taken before anything is awaited" is a
  /// property the compiler enforces instead of one a reviewer has to notice.
  ///
  /// `_runTick` — everything below the guard — is async, which is where the
  /// awaiting belongs.
  bool _running = false;

  /// Whether a tick is in flight. Read by tests and by nothing in production.
  bool get isRunning => _running;

  /// Runs one tick, or records that one is already running and returns.
  ///
  /// On the dropped path this completes IMMEDIATELY with [ran] false. It does not
  /// wait for the running tick: see the class comment for why waiting is the
  /// wrong answer.
  Future<TickSingleFlightResult> trigger() {
    if (_running) {
      const dropped = TickSingleFlightResult.dropped();
      // A dedicated event, IN ADDITION TO the `completed` line. The `completed`
      // line is there so every tick leaves the same shape; this one is there so
      // the drop is greppable on its OWN.
      log?.call('scheduler.tick.dropped_overlap', <String, dynamic>{
        'ran': false,
        'dispatched': 0,
        'handledOff': 0,
        'sweepEnqueued': 0,
        'overlappedTicks': 1,
        'code': tickOverlapDroppedCode,
        'action':
            'this tick did not run because a tick was already in flight; '
            'nothing was claimed, dispatched or enqueued by it. The tick '
            'already running reports its own results on its own completed line.',
      });
      log?.call('scheduler.tick.completed', <String, dynamic>{
        'ran': false,
        'dispatched': 0,
        'handledOff': 0,
        'sweepEnqueued': 0,
        'failedSections': const <String>[],
        'reconcileFailed': const <String>[],
        'reconcileFailedCount': 0,
        'overlappedTicks': 1,
        'code': tickOverlapDroppedCode,
      });
      return Future<TickSingleFlightResult>.value(dropped);
    }
    _running = true;
    // `whenComplete` releases the guard on the success path AND on the failure
    // path, and passes the original error through untouched. A guard released
    // only on success would wedge the loop shut after the first failure, and
    // every later tick would report itself as "overlapping" against a tick that
    // ended minutes ago — a loop that looks busy and is permanently stopped.
    return _runGuarded().whenComplete(() {
      _running = false;
    });
  }

  /// The tick itself, and the completion line.
  ///
  /// Everything here is BELOW the guard, which is why it may await as much as it
  /// likes. The completion line is emitted on both paths so that a failing tick
  /// still leaves the same shape behind as a clean one.
  Future<TickSingleFlightResult> _runGuarded() async {
    try {
      final outcome = await runTick();
      log?.call('scheduler.tick.completed', <String, dynamic>{
        'ran': true,
        'dispatched': outcome.dispatched,
        'handledOff': outcome.handledOff,
        'sweepEnqueued': outcome.sweepEnqueued,
        'failedSections': outcome.failedSections,
        'reconcileFailed': outcome.reconcileFailed,
        'reconcileFailedCount': outcome.reconcileFailed.length,
        'overlappedTicks': 0,
      });
      return TickSingleFlightResult.ran(outcome);
    } on Object {
      // The tick's own halves already logged what they caught. This records
      // that the tick as a whole ended badly, so a line that says `ran: true`
      // with an empty `failedSections` is unambiguous: it means no half threw.
      log?.call('scheduler.tick.completed', <String, dynamic>{
        'ran': true,
        'dispatched': -1,
        'handledOff': -1,
        'sweepEnqueued': -1,
        'failedSections': const <String>['tick'],
        'overlappedTicks': 0,
      });
      rethrow;
    }
  }
}

/// Thrown when the composition root refuses to build a scheduler with no
/// execution cap.
///
/// A refusal, not a warning. The process does not come up: there is no version
/// of "serve anyway, and log a note" that is honest, because the thing being
/// refused is the exact condition that exhausted the host on 2026-10-10.
class UnboundedDispatchRefused implements Exception {
  const UnboundedDispatchRefused(this.diagnostic);

  /// The reason, naming the variable and what was wrong with it. Never contains
  /// a credential — only a variable name and the offending value.
  final String diagnostic;

  @override
  String toString() => diagnostic;
}

/// Resolves the global execution cap from [environment], or REFUSES.
///
/// ## Why this throws rather than defaulting
///
/// The cap is `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS`, and the human decision
/// `f8c8b67f` fixed its first value at **C = 2**, overridable by this variable
/// so it can be tuned after a watched run. C = 2 is the value an operator
/// DEPLOYS; it is deliberately not a value baked into this binary.
///
/// Two defaults were available and both are worse than a refusal:
///
///  * default to **unbounded** — which re-creates the incident this work item
///    was opened for, silently, and only after someone deployed the fix;
///  * default to **2** — which reads as protection while the real cause was
///    overlapping ticks, and which silently caps every other future
///    composition at a number chosen for one host. It also puts a fiction in a
///    log line that an operator will later trust.
///
/// So every unusable value — absent, empty, non-numeric, zero, negative —
/// resolves to nothing and says which one it was. `ExecutionCapacityResolution`
/// does that arithmetic; this function's only job is the decision, and the
/// decision is no.
///
/// ## Why the refusal happens HERE
///
/// `Scheduler` constructed without a `capacityGuard` runs unbounded and says so
/// in `capacitySummary`. That is the right design — a library should be usable
/// in a test — and it is also exactly how the bug gets shipped: the default is
/// "unbounded", and the one place that can refuse is the composition root.
/// So this runs before `Serverpod` is constructed, which is before the process
/// binds a port, which is before there is anything for an operator to attach to
/// and find healthy.
///
/// Throws [UnboundedDispatchRefused].
ExecutionCapacity resolveDispatchCapacity(
  Map<String, String> environment, {
  void Function(String event, Map<String, dynamic> data)? log,
}) {
  final resolution = ExecutionCapacityResolution.fromEnvironment(environment);
  final capacity = resolution.capacity;
  if (capacity == null) {
    log?.call('server.capacity.refused', <String, dynamic>{
      'capacity': 'NOT CONFIGURED — refusing to start',
      'reason': resolution.diagnostic,
      'action':
          'set $executionCapacityEnvVar to an integer >= 1 before starting the '
          'server. The decided first value is C = 2.',
    });
    throw UnboundedDispatchRefused(resolution.diagnostic);
  }
  log?.call('server.capacity.resolved', <String, dynamic>{
    'capacity': capacity.startupSummary,
  });
  return capacity;
}

/// The single operator log for this file, so every event the composition emits
/// is greppable by name and shares one format.
void _log(String event, Map<String, dynamic> data) {
  stdout.writeln('[$event] $data');
}

/// Seeds `model_policy` from the operator-configured default, and reports what
/// actually happened.
///
/// ## A failure here is loud, not quiet
///
/// The table shipped empty and nothing said so, which is why every role was
/// silently running on an in-code guess for as long as it took someone to read
/// a row count. If seeding fails the process keeps serving — a database fault
/// is not a reason to refuse the platform's core promise — but it says so twice:
/// a `server.modelpolicy.seed.failed` line naming the impact, and a `seedFailed`
/// field on `server.composition`. An operator reading one startup line can tell
/// "the policy is durable" from "the policy is a constant in this binary".
///
/// Returns the fields that go on the composition line.
Future<Map<String, dynamic>> _seedModelPolicy(
  ModelSelectionService selection,
) async {
  try {
    final written = await selection.seedConfiguredDefault();
    final roles = written.map((r) => r.wire).toList()..sort();
    _log('server.modelpolicy.seeded', {
      'rolesSeeded': roles,
      'rolesSeededCount': roles.length,
      'defaultModelId': kConfiguredDefaultModelId,
      'decisionId': kConfiguredDefaultDecisionId,
      // An empty list is not a no-op to stay silent about: it means every role
      // already had a row, which is the state after the first start.
      'note': roles.isEmpty
          ? 'every role already had a policy row; nothing was overwritten'
          : 'populated previously-unset roles',
    });
    return {
      'seeded': true,
      'seedFailed': false,
      'rolesSeeded': roles.length,
      'rolesAlreadySet': AgentRole.values.length - roles.length,
    };
  } catch (e, st) {
    _log('server.modelpolicy.seed.failed', {
      'error': '$e',
      'stack': st.toString(),
      'impact':
          'model_policy is NOT populated; every role falls back to the '
          'in-code default $kConfiguredDefaultModelId until this is fixed',
    });
    return {
      'seeded': false,
      'seedFailed': true,
      'rolesSeeded': 0,
      'rolesAlreadySet': 0,
      'seedError': '$e',
    };
  }
}

/// The selection [role] will actually dispatch with, read through the same
/// selector the scheduler's request builder uses.
///
/// A read failure is reported and answered with the in-code default rather than
/// crashing the process: the returned selection still carries
/// [ModelSelectionSource.configuredDefault] and `isFallback == true`, so the
/// composition line shows the fallback for what it is instead of dressing it up
/// as a policy.
Future<ModelSelection> _describeModelInForce(
  ModelSelectionService selection,
  AgentRole role,
) async {
  try {
    return await selection.select(role: role, escalationIndex: 0);
  } catch (e, st) {
    _log('server.modelpolicy.read.failed', {
      'role': role.wire,
      'error': '$e',
      'stack': st.toString(),
    });
    return ModelSelection.fallback(role);
  }
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

/// Environment variable naming where durable PRODUCT clones are created.
///
/// Deliberately a different variable from [_triageWorkspaceRootEnv], and
/// deliberately read with NO default. The triage root has a system-temp default
/// because a triage worktree is ephemeral by definition and the fallback is
/// harmless. A durable clone is the opposite: it is supposed to survive a
/// container restart, so a system-temp fallback would quietly give a product a
/// checkout that vanishes on the next rebuild, which is the exact failure the
/// host-bind decision (`9bfe2d09`) exists to prevent.
///
/// An unset value is therefore passed through as an empty string, and
/// `DurableWorkspaceRuntime.resolve` refuses it with its own named reason. That
/// is the shape of the refusal the triage source uses for the same class of
/// mistake: a configuration fact reported once at startup, rather than a
/// placeholder path that makes every later step look like it worked.
///
/// The name is spelled out here, in the composition root, for the same reason
/// every other one is: the product-agnosticism gate refuses this literal
/// anywhere under `lib/src/baseline/**`, and the lane's own factory must stay
/// free of it.
const String _durableWorkspaceRootEnv = 'SHIPIT_DURABLE_WORKSPACE_ROOT';

/// Reads the durable product-clone root, or `''` when it is not configured.
///
/// Returns the empty string rather than throwing: the durable-workspace runtime
/// is ONE lane of four, and refusing to boot this process because a product
/// clone root is unset would take triage, review and baseline down with it. The
/// runtime's own factory then reports the refusal by name on every call, which
/// is the correct visibility — an operator sees it in the startup banner and in
/// the readiness probe's deferral reason, rather than as a process that will not
/// start.
String _durableWorkspaceRoot() =>
    Platform.environment[_durableWorkspaceRootEnv]?.trim() ?? '';

/// Environment variable carrying an OPERATOR's one-shot instruction to create a
/// product's durable clone.
///
/// ## What setting it does
///
/// A JSON object with exactly three keys:
///
/// ```json
/// {"productId": "…", "repositoryId": "…", "startingRevision": "<40-hex SHA>"}
/// ```
///
/// It is honoured at the first start that sees it, and never again by anything
/// automatic. Nothing in this process re-reads it, nothing retries it, and no
/// timer, sweep or scheduler tick can set it.
///
/// ## The variable is re-read on EVERY start, and leaving it set is safe
///
/// The honest reading of "honoured once" is "honoured once by anything
/// AUTOMATIC". The variable is read from the environment again on every single
/// start, so an operator who exported it and never unset it will see it
/// re-presented on every restart of the deployment. That is safe, and it is
/// deliberately so: `WORKSPACE_ALREADY_PROVISIONED` is a SATISFIED outcome here
/// (`provisioned: true, alreadyProvisioned: true`), the process keeps serving,
/// and nothing is cloned, recorded or changed. See
/// [runOperatorDurableWorkspaceProvision].
///
/// An operator MAY clear it once the clone exists — the startup banner says so
/// on the line that reports it — and should, because leaving a live instruction
/// in a deployment's environment is the kind of state that outlives the person
/// who set it. Clearing it is housekeeping, not a precondition.
///
/// ## The cost of this shape: ONE PRODUCT PER RESTART
///
/// **This is the real price of a boot-time instruction, and it is not small.**
/// One instruction names one product, and a start consumes it, so provisioning
/// the Nth product costs N restarts. Each restart is a deployment event with its
/// own risk, and the second one is no cheaper than the first.
///
/// That is a deliberate trade, not an oversight: the alternative — a timer, or a
/// sweep — is unattended provisioning against a governed product's repository
/// with a deploy key, which is precisely what an operator has to be present for.
/// The endpoint surface is the shape that fixes this, and it is not close at
/// hand: `ProductRegistryEndpoints` does not hold a `DurableWorkspaceRuntime`
/// today, so adding the call is a CONSTRUCTOR CHANGE through the composition
/// root before it is a line in the endpoints file. Anyone taking that lane
/// should treat it as a BATCH surface — one request naming several products —
/// rather than reproducing the one-product-per-restart behaviour behind an HTTP
/// verb, because the restart is what the endpoint removes, not the API shape.
///
/// ## Why `startingRevision` must be a SHA and not a ref
///
/// Because that is what a pin IS. `OnboardingRecord.gitRevisionPattern` is
/// `^[0-9a-f]{40}$` — "a pin that cannot be resolved to exactly one commit is
/// not a pin" — and `recordWorkspace` writes the value straight into that
/// column. An operator who writes `main` here gets a refusal that says how to
/// turn it into a commit, not a clone recorded at a revision that does not
/// exist. See `DurableWorkspaceProvisionTrigger.provision` for why the trigger
/// cannot resolve the ref for them.
///
/// ## Why UNSET is the normal state and not a missing feature
///
/// Until a human runs this, the implementation lane has no product checkout to
/// dispatch into and `ImplementationReadinessProbe` defers every item, with the
/// reason in its own log. That is the correct posture — a scheduler that
/// materialised governed products' repositories on its own would be doing the
/// one thing this variable exists to keep human-initiated — so there is no
/// default, no inference, and no "helpful" second path.
const String _provisionDurableWorkspaceEnv =
    'SHIPIT_PROVISION_DURABLE_WORKSPACE';

/// One operator's instruction, parsed and validated.
class DurableWorkspaceProvisionInstruction {
  const DurableWorkspaceProvisionInstruction({
    required this.productId,
    required this.repositoryId,
    required this.startingRevision,
  });

  final String productId;
  final String repositoryId;

  /// What the operator asked for. Validated as a commit SHA by
  /// [DurableWorkspaceProvisionTrigger], which is the one place that decides
  /// what a pin may be — this class only refuses input that is not even a
  /// non-empty string.
  final String startingRevision;

  @override
  String toString() =>
      'DurableWorkspaceProvisionInstruction($productId/$repositoryId@'
      '$startingRevision)';
}

/// Parses and validates [_provisionDurableWorkspaceEnv], or returns `null` when
/// it is unset or blank.
///
/// Returns `null` rather than throwing for absence, and THROWS for anything
/// present-but-wrong. That asymmetry is the whole point: "nobody asked" is the
/// normal state of a deployment and must not be a fault, while a typo is a
/// fault that is invisible unless it is refused — a misspelled key would
/// otherwise leave a server that starts, provisions nothing, and looks fine.
///
/// The caller runs this BEFORE the server is constructed, so a bad instruction
/// never binds a port.
///
/// The three keys are required and NO OTHERS ARE ACCEPTED. An unknown key is a
/// refusal rather than a shrug for the reason above: `{"productId": "p",
/// "repository": "r"}` is a plausible typo that would otherwise provision
/// against a default, or against nothing, with no error anywhere.
DurableWorkspaceProvisionInstruction?
resolveDurableWorkspaceProvisionInstruction(
  Map<String, String> environment,
) {
  final raw = environment[_provisionDurableWorkspaceEnv]?.trim();
  if (raw == null || raw.isEmpty) return null;

  const required = <String>['productId', 'repositoryId', 'startingRevision'];
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw StateError(
      'CONFIG_ERROR $_provisionDurableWorkspaceEnv is set but is not valid '
      'JSON (${error.message}). It must be an object with exactly '
      '${required.join(', ')}.',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw StateError(
      'CONFIG_ERROR $_provisionDurableWorkspaceEnv must be a JSON OBJECT with '
      'keys ${required.join(', ')}, not ${decoded.runtimeType}.',
    );
  }
  final unexpected =
      decoded.keys.where((key) => !required.contains(key)).toList()..sort();
  if (unexpected.isNotEmpty) {
    throw StateError(
      'CONFIG_ERROR $_provisionDurableWorkspaceEnv carries unknown key(s) '
      '${unexpected.join(', ')}. Only ${required.join(', ')} are accepted; an '
      'unrecognised key is refused rather than ignored, because a typo that is '
      'ignored provisions nothing and reports nothing.',
    );
  }
  final fields = <String, String>{};
  for (final key in required) {
    final value = decoded[key];
    if (value is! String || value.trim().isEmpty) {
      throw StateError(
        'CONFIG_ERROR $_provisionDurableWorkspaceEnv.$key must be a non-empty '
        'string.',
      );
    }
    fields[key] = value.trim();
  }
  return DurableWorkspaceProvisionInstruction(
    productId: fields['productId']!,
    repositoryId: fields['repositoryId']!,
    startingRevision: fields['startingRevision']!,
  );
}

/// Runs [instruction] if there is one, and reports what happened as banner
/// fields.
///
/// ## Why a REFUSAL is returned rather than thrown
///
/// The caller has to decide whether to keep serving, and it cannot decide that
/// without seeing the reason. So the decision is returned, shaped for the
/// startup banner, and the reason is logged here — not swallowed: `run()` turns
/// a non-provisioned instruction into a non-zero exit, so the outcome is a
/// failed boot an operator cannot miss.
///
/// That is a different posture from an unconfigured durable-workspace runtime,
/// which does NOT stop the boot. The runtime being absent is an ambient
/// configuration fact about a process that also serves triage, and A1's own doc
/// is right that refusing to serve would be worse. An operator instruction that
/// FAILED is not that: the operator asked for a specific durable action, it did
/// not happen, and continuing to serve would leave the deployment in the exact
/// state they asked to leave while reporting itself healthy.
///
/// ## …AND the one refusal that is NOT a failure
///
/// `WORKSPACE_ALREADY_PROVISIONED` is the exception, and it is handled before
/// the abort path: the instruction named a durable clone, and the durable clone
/// is there. Refusing to clone a second time is right — see
/// `DurableWorkspaceProvisionTrigger` for why a second clone attempt is a clone
/// deletion — but the guard's refusal is about the CLONE, and the clone already
/// exists. Counting that as a fault made every restart of an already-provisioned
/// deployment exit non-zero, so the control plane refused to start over a
/// variable the operator had no reason to know they had to unset. It keeps
/// serving, and says in the banner that the variable may now be cleared.
///
/// The claim is read back from the record rather than taken from the refusal —
/// see [_alreadyProvisionedOutcome] — so "already provisioned" is confirmed to
/// be true rather than repeated.
///
/// Returns `{'requested': false, ...}` when [instruction] is null, so absence is
/// a printed state rather than an omitted field.
Future<Map<String, dynamic>> runOperatorDurableWorkspaceProvision(
  DurableWorkspaceProvisionInstruction? instruction, {
  required ProductRegistryStore store,
  required ProductRegistryEngine engine,
  required DurableWorkspaceRuntime runtime,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  final emit = log ?? _log;
  if (instruction == null) {
    return const <String, dynamic>{
      'requested': false,
      'provisioned': false,
      'triggeredBy': 'nobody — an operator instruction is required',
      'note':
          'no product has a durable clone unless an operator set '
          '$_provisionDurableWorkspaceEnv on a start. Nothing in this process '
          'creates one automatically, and the implementation lane keeps '
          'deferring every item until it exists',
    };
  }

  emit('durable_workspace.provision.requested', {
    'productId': instruction.productId,
    'repositoryId': instruction.repositoryId,
    'startingRevision': instruction.startingRevision,
    'triggeredBy': 'the $_provisionDurableWorkspaceEnv operator instruction',
  });

  final trigger = DurableWorkspaceProvisionTrigger(
    store: store,
    engine: engine,
    runtime: runtime,
    log: emit,
  );
  try {
    final provisioned = await trigger.provision(
      productId: instruction.productId,
      repositoryId: instruction.repositoryId,
      startingRevision: instruction.startingRevision,
    );
    return <String, dynamic>{
      'requested': true,
      'provisioned': true,
      'productId': provisioned.productId,
      'repositoryId': provisioned.repositoryId,
      'pinnedRevision': provisioned.pinnedRevision,
      'repositoryPath': provisioned.workspace.repositoryPath,
      'onboardingId': provisioned.onboardingId,
      'completedBaselineId': provisioned.completedBaselineId,
      'triggeredBy': 'the $_provisionDurableWorkspaceEnv operator instruction',
    };
  } on Object catch (error) {
    // THE RESTART TRAP, handled before anything is called a failure.
    //
    // This variable is re-read on every start, `alreadyProvisioned` used to land
    // in the abort branch below, and `_runDurableWorkspaceProvision` turns a
    // non-provisioned instruction into `exit(1)`. Those three together meant a
    // successful provision followed by any routine restart — a deploy, a crash,
    // a container recreated by compose — had the control plane refuse to start,
    // with nothing on screen naming the variable as the reason. The instruction
    // is satisfied, so the process serves.
    if (error is DurableWorkspaceProvisionRefused &&
        error.code == DurableWorkspaceProvisionRefused.alreadyProvisioned) {
      final satisfied = await _alreadyProvisionedOutcome(
        instruction,
        store: store,
        emit: emit,
      );
      // `null` means the read-back could not CONFIRM the clone the guard named.
      // Falling through to the abort path is then the honest outcome: a guard
      // saying "already provisioned" and a record saying otherwise is a
      // contradiction, and a contradiction is a fault.
      if (satisfied != null) return satisfied;
    }

    // The reason is surfaced, never swallowed: A1's own wording when A1
    // refused (an unconfirmed host key, an unusable credential, a baseline
    // that is not accepted), this lane's code and wording when the refusal was
    // this lane's, and the underlying text when it was neither — a missing
    // product, or a repository that belongs to another one.
    final code = switch (error) {
      DurableWorkspaceProvisionRefused() => error.code,
      DurableWorkspaceUnavailableException() => 'DURABLE_WORKSPACE_REFUSED',
      DurableWorkspaceRuntimeUnavailableException() =>
        'DURABLE_RUNTIME_UNAVAILABLE',
      _ => 'PROVISIONING_FAILED',
    };
    final reason = switch (error) {
      DurableWorkspaceProvisionRefused() => error.reason,
      DurableWorkspaceUnavailableException() => error.reason,
      DurableWorkspaceRuntimeUnavailableException() => error.reason,
      _ => error.toString(),
    };
    emit('durable_workspace.provision.aborted', <String, dynamic>{
      'code': code,
      'productId': instruction.productId,
      'repositoryId': instruction.repositoryId,
      'error': reason,
      'action':
          'no clone was recorded as this instruction\'s outcome and this '
          'process will NOT continue serving: the operator asked for a durable '
          'clone, it did not happen, and starting anyway would leave the '
          'deployment looking healthy in exactly the state the instruction was '
          'meant to leave it',
    });
    return <String, dynamic>{
      'requested': true,
      'provisioned': false,
      'code': code,
      'reason': reason,
      'productId': instruction.productId,
      'repositoryId': instruction.repositoryId,
    };
  }
}

/// The `WORKSPACE_ALREADY_PROVISIONED` branch, as a SATISFIED outcome: the
/// desired end state already holds, so the process keeps serving.
///
/// Returns the banner fields, or `null` when the durable clone the guard named
/// cannot be CONFIRMED by reading the record back.
///
/// ## Why it is not a failure
///
/// The instruction is re-read on every start, and an operator who exported it
/// once has no reason to know they must unset it. Routing this refusal into the
/// abort branch — and `_runDurableWorkspaceProvision` turns an abort into
/// `exit(1)` — meant the second start of an already-provisioned deployment took
/// the control plane down, for a restart the operator had every reason to make.
/// The refusal is about the CLONE; the clone is already there.
///
/// ## Why the claim is read back rather than believed
///
/// `provisioned: true` asserts that a durable product clone exists. That is the
/// one field in this outcome a monitoring rule might act on, so it is not taken
/// from the refusal that produced it — a guard saying "already provisioned" and a
/// record saying otherwise must not report a success. `hasDurableProductClone`
/// is the only read that proves the recorded workspace IS the product's clone,
/// and every cell in which it is true is a record whose `requireDurable()`
/// succeeds, so this cannot throw; the `try` is here for the read itself.
Future<Map<String, dynamic>?> _alreadyProvisionedOutcome(
  DurableWorkspaceProvisionInstruction instruction, {
  required ProductRegistryStore store,
  required void Function(String event, Map<String, dynamic> data) emit,
}) async {
  const triggeredBy = 'the $_provisionDurableWorkspaceEnv operator instruction';
  try {
    final record = await store.readOnboardingForProduct(instruction.productId);
    final durable = record != null && record.hasDurableProductClone
        ? record.workspace!.requireDurable()
        : null;

    if (record == null || durable == null) {
      emit('durable_workspace.provision.already_provisioned.unconfirmed', {
        'productId': instruction.productId,
        'repositoryId': instruction.repositoryId,
        'action':
            'the trigger reported an existing durable clone and the record does '
            'not hold one, so this is NOT reported as satisfied. This process '
            'will NOT continue serving: a guard and a record that disagree are '
            'a contradiction, and the honest outcome for one is a failed boot',
      });
      return null;
    }

    emit('durable_workspace.provision.already_provisioned', {
      'productId': record.productId,
      'repositoryId': instruction.repositoryId,
      'pinnedRevision': record.pinnedRevision,
      'repositoryPath': durable.repositoryPath,
      'workspaceId': durable.workspaceId,
      'onboardingId': record.onboardingId,
      'triggeredBy': triggeredBy,
      'note':
          'NOTHING WAS CLONED, NOTHING WAS RECORDED AND NOTHING WAS CHANGED. '
          'The clone this instruction asked for already existed, so the desired '
          'end state holds and this process continues to serve. Re-provisioning '
          'is refused because a second materialisation into the same tree would '
          'destroy the existing one, not because this start failed. '
          '$_provisionDurableWorkspaceEnv MAY NOW BE CLEARED from the '
          'deployment environment: leaving it set is safe (this is the outcome '
          'every later start reports) but it is state that outlives whoever set '
          'it. Note the cost of this shape — one product per instruction, so '
          'provisioning the Nth product costs N restarts.',
    });

    return <String, dynamic>{
      'requested': true,
      'provisioned': true,
      'alreadyProvisioned': true,
      'productId': record.productId,
      'repositoryId': instruction.repositoryId,
      'pinnedRevision': record.pinnedRevision,
      'repositoryPath': durable.repositoryPath,
      'workspaceId': durable.workspaceId,
      'onboardingId': record.onboardingId,
      'triggeredBy': triggeredBy,
      'note':
          'satisfied by the clone that was already here. Nothing was cloned, '
          'recorded or changed, and $_provisionDurableWorkspaceEnv may be '
          'cleared from the environment',
    };
  } on Object catch (error) {
    emit('durable_workspace.provision.already_provisioned.unconfirmed', {
      'productId': instruction.productId,
      'repositoryId': instruction.repositoryId,
      'error': '$error',
      'action':
          'the record could not be read back to confirm the existing clone, so '
          'this is NOT reported as satisfied and this process will NOT continue '
          'serving',
    });
    return null;
  }
}

/// [runOperatorDurableWorkspaceProvision] with this file's composition-root
/// logger and the process exit, so `run()` reads as a sequence of decisions
/// rather than a try/catch.
Future<Map<String, dynamic>> _runDurableWorkspaceProvision(
  DurableWorkspaceProvisionInstruction? instruction, {
  required ProductRegistryStore store,
  required ProductRegistryEngine engine,
  required DurableWorkspaceRuntime runtime,
}) async {
  final outcome = await runOperatorDurableWorkspaceProvision(
    instruction,
    store: store,
    engine: engine,
    runtime: runtime,
    log: _log,
  );
  if (outcome['requested'] == true && outcome['provisioned'] != true) {
    // Non-zero, immediately, and loudly enough that an operator running this by
    // hand sees it in the shell that asked for it. A durable clone is created
    // outside the repository tree with a deploy key; an operator who asked for
    // one and did not get it must not be left believing the deployment is
    // provisioned.
    //
    // ---- WHAT THIS EXIT DEPENDS ON. Read off `run()`, not assumed. ----
    //
    // A previous version of this comment claimed the exit was safe here "because
    // this call site is still inside run()'s composition, BEFORE `Serverpod` is
    // constructed and before any session, engine or scheduler exists". That was
    // false, and it is worth being exact about why: `run()` is ONE continuous
    // body, and by the time control reaches this call the composition has long
    // since started. `pod.start()` has run, so `Endpoints()` is listening and
    // answering requests; two `Session`s exist (`session`, and the separate
    // `baselineSession`); the Postgres stores, `DurableWorkflowEngine`,
    // `ProviderHealthMonitor` (already started) and the triage and review
    // `Scheduler`s are all constructed.
    //
    // The properties that ARE true here, and that this exit actually depends on,
    // are these two:
    //
    //  * NO SCHEDULER TICK HAS EVER FIRED. `TickSingleFlight` and the
    //    `Timer.periodic` that drives it are both constructed after this call,
    //    `sched-impl` does not exist yet at all, and
    //    `BaselineProductionRuntime.runOnce()` only ever runs from inside a tick.
    //    Nothing has been dispatched, claimed or leased. This is the property
    //    this location genuinely has, and it is the one the comment at the call
    //    site already names correctly ("It runs BEFORE `implScheduler` is
    //    built").
    //  * NOTHING IS HALF-WRITTEN. Every await before this line has returned, so
    //    there is no pending write to abandon. `_seedModelPolicy`'s row, if it
    //    wrote one, is committed and idempotent on the next start.
    //
    // ---- WHAT IT COSTS. Not "nothing to lose" — an HTTP request. ----
    //
    //  * `exit` runs no `finally`. Checked rather than assumed: a `try` whose
    //    `finally` writes a marker never reaches it. So `Serverpod.shutdown()` is
    //    never called and neither `Session` is closed gracefully. Process death
    //    closes the sockets and the database reaps the backends, so this is
    //    untidiness, not data loss.
    //  * `exit` DOES flush stdout. Also checked rather than assumed, because the
    //    previous version of this comment claimed the opposite: dart:io flushes
    //    stdio before terminating, and a 200 kB pending `stdout.write` reaches the
    //    pipe ahead of `exit(1)`. `_log` writes through `stdout`, so every line
    //    above — including `durable_workspace.provision.aborted` — reaches the
    //    operator's terminal.
    //  * THE REAL COST IS AN IN-FLIGHT REQUEST. The port was bound by
    //    `pod.start()`, provisioning is a real `git clone` over SSH and can take
    //    minutes, and `exit` cuts an arriving or in-flight request off mid
    //    response. The process is listening for exactly as long as provisioning
    //    runs. That window cannot be closed by moving this call later; it can
    //    only be closed by not binding the port first, which is a restructuring
    //    of the boot sequence rather than a move (the store this runs on is built
    //    over a `Session` created after `pod.start()`).
    //  * A pending `ProviderHealthMonitor` check is dropped. Harmless: it is a
    //    five-minute `Timer.periodic`, the first check is five minutes out, and
    //    the next start runs it again.
    //
    // ---- WHY IT STAYS HERE. ----
    //
    // Not because it is safe everywhere else, but because this is the LAST point
    // at which the instruction's outcome can still stop the process. Past it the
    // deployment serves as though it were healthy while the instruction went
    // unfulfilled, which is the exact state the operator asked it not to be left
    // in.
    //
    // "Defer it to the end of `run()`" is not available: `run()` never returns to
    // a place that could act on a flag — its last statement is the
    // `Timer.periodic` that keeps ticking. Serverpod does offer a graceful path
    // (`Serverpod.shutdown`), and it was NOT adopted here for two reasons a future
    // lane must know before "improving" this: with `exitProcess: true` it exits
    // **0**, which inverts the deliberate non-zero signal this whole branch
    // exists to give; and with `exitProcess: false` it awaits in-flight requests,
    // trading the immediacy this path is for on the one failure an operator is
    // watching a shell for. Tidy-but-slower is a product decision, not a
    // correction.
    exit(1);
  }
  return outcome;
}

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

// ---------------------------------------------------------------------------
// AGENT-EXECUTION BUDGETS
// ---------------------------------------------------------------------------
//
// ## READ THIS BEFORE CHANGING A NUMBER HERE
//
// **Every value in this table is PROVISIONAL. No duration data existed when it
// was set.** They are ceilings chosen from the ranges an operator stated, not
// from measurements — because there were no measurements to choose from: every
// run recorded so far was either fast or killed at its budget, which is
// precisely why the kill has to stop being the common case before the
// surviving runs say anything useful.
//
// The number this table replaces is the reason that warning is here. The
// engineering-review budget was a typed-in literal of `300` with no
// justification anywhere in the repository — not a comment, not a ticket, not a
// note. It was simply there, and it was exactly the number of the failed
// reviews, which is how a guess gets mistaken for a finding. Do not repeat
// that: a number whose provenance cannot be stated is worse than no number.
//
// ## THE REPLACEMENT FOR THESE NUMBERS IS ALREADY IN FRONT OF YOU
//
// `agent_execution.startedAt` / `completedAt` and `role` / `status` hold every
// one of these runs. `GET executionEndpoints.list` returns them all, and the
// Models → Stats surface reads them and reports, per role and per terminal
// status, the count / min / median / max duration. That panel is the
// measurement that should replace this table. When enough real runs have
// accumulated, set each ceiling from its MEDIAN plus an agreed margin — and
// raise the stale-computation comment above to say which run it came from.
//
// ## WHAT A BUDGET ACTUALLY CONTROLS, BEYOND KILLING THE AGENT
//
// `SchedulerWorkload.timeoutSeconds` is not one value with one effect. Setting
// it to [X] also:
//
//  * passes `X` to the runtime as `AgentSessionConfig.timeout`, so an adapter
//    may bound its own ACP calls by it;
//  * bounds `LocalWorker`'s outer wait at `X + workerLeaseGrace`;
//  * bounds the coordinator's whole dispatch path, which is what settles a run
//    as `interrupted` when the agent does not finish (see
//    `ExecutionCoordinator._expireExecution`); and
//  * used to set `Scheduler.zombieStalenessBound = timeoutSeconds * 4 +
//    claimLease`, which is a multi-hour multiplier on the window in which a
//    dead execution is allowed to keep its claim and its capacity slot.
//
// The last of those is a defect at these magnitudes, not a detail: the default
// multiplies this table by [AgentExecutionBudgets.rejectedStalenessMultiplier]
// and then adds a claim lease. Every scheduler below is therefore given an
// EXPLICIT [AgentExecutionBudgets.zombieStalenessFor] via
// `Scheduler.zombieStalenessAfter`, so raising a budget here does not silently
// multiply the reclaim window. That decoupling, and its cost, are documented on
// [AgentExecutionBudgets.zombieStalenessFor] — read it before treating the
// staleness bound as incidental.
//
// NO MAGNITUDE IS QUOTED HERE, deliberately. An earlier version said "a 3-hour
// budget times four is a 12-hour staleness bound", which is true of the value
// that was in force when it was written and false of any other value: lowering
// the review budget to an hour would have left an operator reading a claim about
// a window twice as wide as the real one. What the rejected formula WOULD
// produce for the budget actually in force is published per role by
// [AgentExecutionBudgets.describe] and computed from the table, so it cannot go
// stale.
//
class AgentExecutionBudgets {
  const AgentExecutionBudgets._();

  /// Ceiling for a single agent execution, per role.
  ///
  /// PROVISIONAL; NO DURATION DATA EXISTED WHEN THESE WERE SET. See the
  /// Models → Stats "Run duration" panel (`agent_execution.startedAt` /
  /// `completedAt`, per role and per terminal status) for the measurement that
  /// should replace them. Each entry below repeats that marker so a fourth
  /// role added later cannot quietly skip it.
  ///
  /// They are per-role rather than one number because the operator's stated
  /// ranges are per-role and differ by an order of magnitude: a review is
  /// reported at 15–30 minutes here, and an implementation run "routinely
  /// exceeds" half an hour with no stated ceiling.
  static const Map<String, Duration> byRole = <String, Duration>{
    // DEFECT TRIAGE — 30 minutes. PROVISIONAL.
    //
    // NO OPERATOR-STATED RANGE EXISTS FOR THIS ROLE; this is the weakest
    // number in the table and it is called out rather than dressed up.
    //
    // What exists is the only measurement that ever existed, and it says the
    // old ceiling was being HIT: implementer and triage runs finished at
    // 114s–260s, and the ones that failed did so at 303s–320s — that is a
    // budget being reached, not a distribution with a tail. 30 minutes is the
    // operator's stated LOWER bound for the slowest role they named (a review,
    // 15 minutes), adopted as a common floor so no lane is left holding a
    // ceiling this deployment has demonstrably already hit.
    //
    // PROVISIONAL for the same reason as every other value here: it is a floor
    // picked to stop the bleeding, not a number derived from triage runs.
    'triage-defect': Duration(minutes: 30),

    // IMPLEMENTATION — 4 hours. PROVISIONAL.
    //
    // OPERATOR-STATED: an implementation run under this framework ROUTINELY
    // EXCEEDS the 1800s it used to carry, and a ceiling of "a few hours per
    // agent run" is the right order of magnitude. 4 hours is the top of that
    // range, taken deliberately: this is the one lane where the operator named
    // a direction ("routinely exceeds") rather than a number, so under-shooting
    // reproduces the exact failure being fixed, while over-shooting only costs
    // wall clock on a run that was going to be killed anyway.
    //
    // It replaces 1800s (30 minutes) — a number whose only justification was
    // that it was different from the review lane's 300.
    'implement-feature': Duration(hours: 4),

    // ENGINEERING REVIEW — 1 hour. PROVISIONAL.
    //
    // OPERATOR-STATED: a review run HERE, THROUGH OPENCODE, TAKES 15–30
    // MINUTES. 1 hour is 2× the stated maximum, so ordinary variance and a
    // larger diff do not reach the ceiling — only a genuinely wedged run does.
    //
    // MEASURED, and the reason this came down from 3 hours: on this deployment
    // a review started at 17:00:12 was interrupted at 20:00:13 having emitted no
    // terminal event at all, and so consumed the entire 3-hour execution budget
    // to produce nothing; the very next review returned in 2 minutes with a
    // real verdict. So 6× of the stated maximum was never a margin this lane
    // had earned — it was an allowance no review here has needed, and one that
    // let a single wedged run hold its claim and its capacity slot three times
    // longer than the work it was meant to bound.
    //
    // It replaces 300s (5 minutes), which is LESS THAN THE STATED MINIMUM for
    // this role and had no justification anywhere in the repository. A ceiling
    // below the observed floor is not a ceiling; it is a coin toss that always
    // lands on killed.
    'engineering-review': Duration(hours: 1),
  };

  /// Triage's budget, in the seconds every workload field wants.
  static int get triageSeconds => byRole['triage-defect']!.inSeconds;

  /// The implementation lane's budget, in seconds.
  ///
  /// Read by BOTH `ImplementationReadinessProbe.timeoutSeconds` (the value that
  /// actually runs an implementer, because the readiness probe is the
  /// authoritative workload resolver) and the inert static workload the
  /// `Scheduler` constructor requires.
  static int get implementationSeconds =>
      byRole['implement-feature']!.inSeconds;

  /// The engineering review lane's budget, in seconds.
  ///
  /// Passed to `engineeringReviewWorkloadResolver`, which used to carry a
  /// literal `300` of its own.
  static int get engineeringReviewSeconds =>
      byRole['engineering-review']!.inSeconds;

  /// How long a non-terminal execution may go unobserved before the scheduler
  /// declares it a zombie and reclaims it.
  ///
  /// ## WHY IT IS NOT `timeoutSeconds * 4 + claimLease`
  ///
  /// That is the formula `Scheduler.zombieStalenessBound` uses when a scheduler
  /// does not configure one, and it was written for budgets of five minutes. At
  /// the budgets in [byRole] it produces a staleness bound of
  /// `budget * [rejectedStalenessMultiplier]` plus the Scheduler's claim lease —
  /// so a dead review execution would hold its claim and its capacity slot for
  /// most of a day before anything reclaimed it. The multiplier is the problem —
  /// it was a proxy for "the non-agent work around a run", and at these
  /// magnitudes it stops being one.
  ///
  /// The per-role arithmetic is published by [describe] under
  /// `zombieStaleness.rejectedSchedulerDefault`, computed from this table, and
  /// asserted against it in
  /// `apps/server/test/engineering_review_composition_order_test.dart`. It is not
  /// written out here: a magnitude quoted in prose is a magnitude that goes
  /// stale when a budget moves, and the whole point of this method is that a
  /// budget can move without anything else having to be remembered.
  ///
  /// ## WHAT REPLACES IT, AND WHAT IT COSTS
  ///
  /// `agentBudget + [stallAllowance]`. The bound must EXCEED the agent budget —
  /// anything shorter reclaims a legitimately long run for being slow, which is
  /// the exact failure `Scheduler.executionLiveness` exists to prevent — so the
  /// sum is the minimum defensible coupling, and it is explicit rather than
  /// multiplied.
  ///
  /// THE COST, STATED PLAINLY: raising a budget necessarily raises this window,
  /// because the two cannot be separated without breaking the invariant above.
  /// The honest cost of a 4-hour implementation budget is therefore that a
  /// genuinely dead execution whose liveness CANNOT be observed (a process
  /// restart, where the probe's in-process session map no longer knows about it)
  /// is reclaimed after 5 hours rather than after the ~2 hours the old formula
  /// gave for the 1800s budget. `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` counts
  /// such an execution against the cap for that whole window.
  ///
  /// The mitigation already exists and is why this is acceptable rather than
  /// merely survivable: when liveness IS observable, a proven-dead execution is
  /// reclaimed immediately and this bound is never consulted. It is consulted
  /// only in the unknown case, and `Scheduler.livenessSummary` — surfaced in the
  /// startup banner below — says which of the two policies the running process
  /// is actually under.
  ///
  /// PROVISIONAL, like every number in this class: one hour of allowance for
  /// workspace preparation, independent verification, artifact commit and
  /// worktree cleanup around the agent, chosen because no measurement of how
  /// long that teardown actually takes exists.
  static const Duration stallAllowance = Duration(hours: 1);

  /// The staleness bound for a scheduler whose agent budget is [agentBudget].
  static Duration zombieStalenessFor(Duration agentBudget) =>
      agentBudget + stallAllowance;

  /// The multiplier `Scheduler.zombieStalenessBound` applies when a scheduler is
  /// NOT given an explicit `zombieStalenessAfter`.
  ///
  /// Named HERE so the banner can print what the rejected formula WOULD have
  /// produced for every budget in the table, computed from the table rather than
  /// written out beside it. It used to be quoted as prose — *"which turns a 3h
  /// review budget into a 12.2h reclaim window"* — which meant lowering a budget
  /// silently left the operator reading a number about the old one. The
  /// `+ claimLease` term is deliberately NOT reproduced here: the lease belongs
  /// to `Scheduler`, is not in this table, and restating it would be a second
  /// copy of a number this file does not own. It only makes the rejected window
  /// LARGER, so the multiple printed below is a floor for it.
  static const int rejectedStalenessMultiplier = 4;

  /// One line naming every budget in force, for the startup banner.
  ///
  /// Present so the values are visible to an operator at runtime rather than
  /// only to whoever opens this file. A provisional number that nothing prints
  /// is a provisional number nobody will remember to re-derive.
  ///
  /// EVERY figure in here is RENDERED FROM [byRole]. None is written out, in
  /// prose or in the rejected-formula block, because a banner that quotes a
  /// magnitude is a banner that goes stale the moment a budget moves — and the
  /// number it goes stale about is the one an operator uses to judge whether a
  /// dead execution is still holding a slot.
  static Map<String, Object> describe() => <String, Object>{
    'provisional':
        'every value here is a ceiling chosen from operator-stated ranges. NO '
        'DURATION DATA EXISTED WHEN THEY WERE SET. The Models -> Stats '
        '"Run duration" panel (agent_execution.startedAt/completedAt, per '
        'role and per terminal status) is the measurement that should '
        'replace them.',
    'byRoleSeconds': <String, int>{
      for (final entry in byRole.entries) entry.key: entry.value.inSeconds,
    },
    'zombieStaleness': {
      'rule':
          'agentBudget + ${stallAllowance.inMinutes}m '
          '(NOT the Scheduler default of timeoutSeconds * '
          '$rejectedStalenessMultiplier + claimLease, which MULTIPLIES this '
          'table by $rejectedStalenessMultiplier — see '
          'rejectedSchedulerDefault.byRoleSeconds below for what that would '
          'have produced for the budget actually in force, before the claim '
          'lease is even added)',
      'byRoleSeconds': <String, int>{
        for (final entry in byRole.entries)
          entry.key: zombieStalenessFor(entry.value).inSeconds,
      },
      // What the rejected formula would produce, per role, from THIS table.
      // Machine-readable on purpose: the sentence above is for a human and the
      // comparison a reader has to make is arithmetic, so the arithmetic is
      // published rather than left inside a sentence.
      'rejectedSchedulerDefault': <String, Object>{
        'rule': 'timeoutSeconds * $rejectedStalenessMultiplier + claimLease',
        'multiplier': rejectedStalenessMultiplier,
        'claimLeaseSecondsExcluded':
            'the Scheduler\'s own claim lease is added on top of this and is '
            'not restated here; this class does not own that number',
        'byRoleSeconds': <String, int>{
          for (final entry in byRole.entries)
            entry.key: entry.value.inSeconds * rejectedStalenessMultiplier,
        },
      },
    },
  };
}

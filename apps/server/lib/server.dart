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
        VerificationCheck,
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
import 'src/persistence/postgres_design_contract_store.dart';
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
import 'package:qa_orchestration/qa_orchestration.dart'
    show QAGateEvaluationService, QAOrchestration;
import 'src/persistence/postgres_qa_contract_store.dart';
import 'src/qa/production_qa_sources.dart'
    show ProducerWorkspaceResolver, buildProductionGateRegistry;
import 'src/qa/qa_drain.dart' show runQADrain;
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

  // The single-flight guard's lease, resolved at the same point and for the same
  // reason, and carrying the same kind of decision: how long this process stops
  // dispatching before it takes the guard back from a tick that has held it too
  // long. On 2026-10-18 a tick held it with no bound at all and nothing
  // dispatched again; `scheduler.tick.hold_expired` is the line that says so
  // out loud. Resolved before the server is constructed so an unusable value
  // refuses rather than being quietly replaced by a number nobody chose.
  final tickHoldBound = resolveTickHoldBound(Platform.environment, log: _log);

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

  // THE DESIGN CONTRACT STORE, MOUNTED.
  //
  // `designContractExists()` on `planned -> designRequired` (and, from design
  // step 3, on the `designParked -> designRequired` release) no longer accepts a
  // caller-supplied string: it reads the work item's durable `designContractId`
  // column and confirms it against a `DesignContractStore`. Confirming it
  // against an IN-MEMORY store would satisfy the guard about process state that
  // a redeploy erases, which is the opposite of what the guard is for, so the
  // composition root wires the PostgreSQL one — the same `db` as every other
  // store here, so the confirmation reads the same durable row the rest of the
  // platform reads.
  //
  // This mounts a STORE, not a scheduler. `designRevisionDefinition` and
  // `designReviewDefinition` remain unmounted (design step 8), so nothing
  // dispatches design work: a guard that can confirm a contract is not a
  // design lane running.
  final designContractStore = PostgresDesignContractStore(db);

  final durableWorkflowEngine = DurableWorkflowEngine(
    store: workflowStore,
    designContractStore: designContractStore,
  );

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

  // `OD-6`: the IMPLEMENTATION lane's coordinator. Same store, same engine,
  // same runtime, same model-record store — it differs ONLY in which
  // [VerificationPlan] it carries, because the plan is the entire difference.
  //
  // Built eagerly and unconditionally so the wiring is a fact a test can read,
  // not a branch taken only when an implementation job happens to arrive. It is
  // a coordinator, NOT a scheduler: nothing below mounts or re-points dispatch,
  // and no runtime is enabled by its existence.
  final implementationCoordinator = buildImplementationExecutionCoordinator(
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
  // READER WARNING — this worker now runs the IMPLEMENTATION verification plan,
  // not the triage one. `OD-6` gave the implementation lane its own coordinator
  // ([implementationCoordinator]) because [ExecutionCoordinator] carries one
  // `verificationPlan` for every job it runs, and the triage plan is a
  // `git rev-parse` liveness probe that cannot fail on a real checkout.
  //
  // What that buys: a real implementation execution now writes a verification
  // row carrying a command this repository actually DECLARES, and one that can
  // fail — design §9.3's verification-failure branch stops being unreachable
  // for this role.
  //
  // Since decisions `5c9e2b74` + `8d4a1f53` it buys the WHOLE declared tier:
  // the implementation plan activates all five per-execution checks — as 32
  // per-root/per-runner checks, each with its own timeout — and
  // [perExecutionValidationChecksNotActivated] is empty. What it still does
  // NOT claim is the merge/release tier (`make test-integration`), which
  // belongs to the gate that owns it.
  final implementWorker = LocalWorker(
    workerId: 'w-impl-local',
    poolId: 'impl-pool',
    capabilities: implementFeatureDefinition.requiredCapabilities,
    // Never the source repository itself: the agent runs in a detached
    // worktree, and cleanup only ever removes worktrees this platform created.
    workspaceManager: GitWorktreeWorkspaceManager(workspaceRoot: workspaceRoot),
    executionDriver: CoordinatorAgentExecutionDriver(implementationCoordinator),
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
  //
  // ---- WHAT IS NOW FIXED, AND WHAT IS STILL NOT ----
  //
  // The three candidate fixes named above — a per-tick dispatch cap, moving
  // dispatch off the tick, and giving each lane its own single flight — remain
  // undone and remain composition changes with their own ownership. Nothing
  // below pretends otherwise.
  //
  // What IS fixed is the other half of the sentence, the one that made those
  // three look urgent: **the guard had no bound.** `N × budget` describes how
  // long a tick legitimately takes; it does NOT license a tick to take for
  // ever, and before this change nothing anywhere said where "legitimately
  // long" ended. A tick whose body wedged in workspace preparation, artifact
  // commit or cleanup — every one of which is awaited with no timeout at all —
  // held the guard for ever, and the platform then looked permanently busy
  // while dispatching nothing.
  //
  // So the guard now carries a LEASE ([TickSingleFlight.maxHold], resolved from
  // `SHIPIT_TICK_MAX_HOLD_SECONDS` with a derived default), and expiry releases
  // the guard while leaving the stuck tick, its job and its agent execution
  // completely untouched. It does not cancel anything — see the class comment —
  // so this is not one of the three composition changes above smuggled in, and
  // concurrent agent executions stay hard-bounded by the capacity cap, which is
  // enforced durably at claim time rather than by this guard.
  // ---- THE QA LANE. ----
  //
  // An item a human approved reaches `reviewApproved` and stopped there. The
  // edge out of it — `reviewApproved -> qaInProgress` — existed, was guarded
  // by `actorAllowed([orchestrator])` and `qaContractExists()`, and had NO
  // CALLER: nothing in the platform took an item through it, so a review a
  // human approved was followed by silence. Everything below is that caller.
  //
  // It is a DRAIN, not a scheduler. Nothing here dispatches an agent, mounts a
  // queue or re-points a lane. It reads the work items a human already
  // approved, evaluates each one's QA contract against the platform's own
  // durable state, and moves the item to `qaPassed` or `qaFailed`.
  //
  // ## WHY THE READERS ARE BUILT HERE AND NOT REACHED FOR
  //
  // `qa_orchestration` has no global registry, and that is deliberate: the
  // global it used to export was wired to six fail-closed STAND-INS whose
  // evidence rows named the same `artifactRef` as the production adapters',
  // because `artifactRef` names the READER and not the READER'S BINDING. A
  // persisted gate result therefore could not say whether the platform or a
  // stand-in had produced it (F-204). The stand-ins now live in the test
  // tree, and this composition builds the ONE registry production uses, over
  // readers that read the same durable rows the rest of the platform reads.
  //
  // The execution store is built HERE rather than taken from a coordinator,
  // because the QA lane must see the executions of EVERY lane — triage,
  // implementation and review all write to the same table, and a view scoped
  // to one coordinator's lane would resolve a producer that is not there.
  final qaProducerResolver = ProducerWorkspaceResolver(
    executionStore: agentExecutionStore(db),
    workflowStore: workflowStore,
  );
  final qaEvaluationService = QAGateEvaluationService(
    orchestration: QAOrchestration(
      registry: buildProductionGateRegistry(
        resolver: qaProducerResolver,
        executionStore: agentExecutionStore(db),
        workerStore: workerStore,
        workflowStore: workflowStore,
        defectStore: defectStore,
      ),
    ),
    contractStore: PostgresQAContractStore(db),
  );

  final tick = TickSingleFlight(
    log: _log,
    maxHold: tickHoldBound,
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

      // The QA drain, in its OWN try, AFTER the review section.
      //
      // AFTER, because the QA lane's input is an item a human APPROVED, and
      // the review section is what raises that approval. Before, the drain
      // would read a `reviewApproved` item the review section was about to
      // move — or, on the tick where the human's decision was resolved, one
      // the review section had not yet moved — and the two would compete for
      // the same item.
      //
      // Its own try, like every other section in this tick: a QA evaluation
      // that throws must not take the triage, implementation, review, baseline
      // or work-entry sections down with it. They read the same stores and
      // answer different questions.
      //
      // It is a DRAIN, not a dispatch: it moves items the review section's
      // approval produced, and it dispatches nothing.
      //
      // A failed QA raises a blocking human decision against the item, which
      // is what moves it to `waitingForHumanDecision`: `qaFailed` has no
      // other edge out, so a failure with no decision is an item nothing can
      // move again.
      try {
        final qaResult = await runQADrain(
          workflowEngine: durableWorkflowEngine,
          workflowStore: workflowStore,
          evaluationService: qaEvaluationService,
          producerResolver: qaProducerResolver,
          log: _log,
        );
        if (qaResult.movedAnything) {
          _log('qa.drain.completed', {
            'considered': qaResult.considered,
            'passed': qaResult.passed,
            'failed': qaResult.failed,
            'faulted': qaResult.faulted,
            'skipped': qaResult.skipped,
            'awaitingHuman': qaResult.awaitingHuman,
          });
        }
      } catch (e, st) {
        outcome.failedSections.add('qa');
        _log('qa.drain.failed', {
          'error': '$e',
          'stack': st.toString(),
          'action':
              'QA evaluation is retried on the next tick; other lanes unaffected',
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
    // The single-flight guard's lease, read back OFF THE LIVE `tick` for the
    // same reason `capacitySummary` is read back off the live scheduler rather
    // than off the local `tickHoldBound`: so this line and the object that
    // enforces the bound cannot disagree. `TickSingleFlight.holdSummary` states
    // the unbounded case in words rather than omitting the field, which means
    // this entry is incapable of quietly describing a lease that is not there.
    'tickHold': tick.holdSummary,
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
final VerificationPlan triageVerificationPlan = VerificationPlan(
  command: ['git', 'rev-parse', '--verify', 'HEAD^{commit}'],
  checkName: 'git_worktree_head',
);

/// The IMPLEMENTATION lane's [VerificationPlan] — every ACTIVATED
/// per-execution check, one [VerificationCheck] each, one
/// [PlatformVerification] row per check.
///
/// ## HISTORY, COMPRESSED
///
/// `OD-6` gave the implementation lane its own plan because the triage plan
/// (`git rev-parse --verify 'HEAD^{commit}'`) is a liveness probe that cannot
/// fail on anything an implementer wrote. Human decision `7b2c4e91` widened
/// the record: [VerificationPlan] now carries a LIST of [VerificationCheck]s,
/// each with its own working directory resolved against the execution
/// workspace, and one row per check under `ver-<executionId>-<checkName>`.
/// Decision `f3a81c27` filled the plan: the declared sweep checks are
/// expressed as one check PER ROOT, and `apps/server`'s unit tier gained its
/// own runner (`tool/run_unit_tests.dart`).
///
/// ## WHAT THIS DECLARES NOW — 32 CHECKS, AND WHAT THAT STILL ISN'T
///
/// `AGENTS.md` -> "Required validation gates" declares FIVE per-execution
/// checks. This plan ACTIVATES ALL FIVE of them, as
/// 1 + 16 + 13 + 1 + 1 = 32 [VerificationCheck]s:
///
/// * `dart_format_repo_root` — the repository-root format check, at `.`;
/// * `dart_analyze_<slug>` × 16 — `dart analyze` at every workspace-member
///   root ([workspaceMemberRoots]);
/// * `dart_test_<slug>` × 13 — `dart test` at the members whose unit tier is
///   a package suite ([dartTestSweepRoots]);
/// * `server_unit_tests_runner` — `dart run tool/run_unit_tests.dart` at
///   `apps/server`, whose unit tier is a runner and never a bare `dart test`;
/// * `flutter_test_apps_control_plane` — `flutter test` at
///   `apps/control_plane`.
///
/// The last two were delivered correct and UNACTIVATED by `f3a81c27`, and
/// [perExecutionValidationChecksNotActivated] — the map that recorded their
/// measured blockers — is now EMPTY: decision `5c9e2b74` authorized the
/// per-check timeout MECHANISM (its record sized the two checks at ~4min /
/// ~4min against the then-measured 237s/531s and 209s/247s — it names no
/// final value for them, and no amendment exists), while the VALUES in the
/// plan below were sized at THIS HEAD from this lane's own measurements, so
/// both fit; decision `8d4a1f53` reclassified
/// `onboarding_test.dart` (integration by definition — it needs a live
/// database) out of the server unit tier's enumeration, which is what removed
/// the base red that would otherwise fail every execution. Empty map, filled
/// plan: `implementation_verification_plan_test.dart` derives BOTH sides
/// independently and demands they agree in both directions, so neither can
/// drift alone. `make test-integration` is still NOT here — the merge/release
/// tier stays recorded only at the gate that owns it (decision `a0e6f31c`).
///
/// ## PER-CHECK TIMEOUTS — MECHANISM AUTHORIZED BY DECISION `5c9e2b74`,
/// VALUES SIZED AT THIS HEAD — AND WHAT THEY COST
///
/// Every check carries its own [VerificationCheck.timeout]. Without one, a
/// check inherits `WorkspaceVerifier.defaultTimeout` (2 minutes), and two of
/// the five declared checks cannot finish inside that — being killed mid-run
/// would write a FAILING verdict about work that was never judged. Decision
/// `5c9e2b74` authorized this MECHANISM — one timeout per check — but
/// recorded no final values: its own sizing was "~4min / ~4min" against the
/// facts it measured (237s/531s, 209s/247s), and no amendment exists. The
/// decision file is human-owned, so it is cited here, never edited; the
/// VALUES below were sized at THIS HEAD from this lane's measurements with
/// headroom, never invented — which is why they are larger than the
/// decision's ~4min estimate.
///
/// | check | cold runtime (timeout-sizing basis) | warm runtime (re-measured at this HEAD) | timeout | headroom (vs cold) |
/// |---|---|---|---|---|
/// | `dart_format_repo_root` | 28s at base `54d440c` | 25s | 3 min | 6.4× |
/// | `dart_analyze_*` (worst: `apps/control_plane`) | 67s at base | 17s | 5 min | 4.5× |
/// | `dart_test_*` (worst at base: `packages/execution_coordinator`) | 80s at base | 32s (`packages/worker_runtime`) | 5 min | 3.75× |
/// | `server_unit_tests_runner` | **959.67s cold in a system-TEMP worktree — the default execution location** (`_triageWorkspaceRoot()` → `Directory.systemTemp`); 531s cold in the main checkout at base (237s is the single-process sweep AGENTS.md rules out) | 117s | 25 min | 1.56× |
/// | `flutter_test_apps_control_plane` | 209s at base | 43s | 10 min | 2.4× |
///
/// The runner's 959.67s cold / 117s warm and the flutter 43s warm are
/// OBSERVED-ONCE values from this lane, not independently reproducible
/// benchmarks: independent review of this change re-measured the runner at
/// 352s cold / 231–305s warm and `flutter test` at 99s. Both sets of
/// observations are recorded here rather than reconciled, and the timeout
/// column clears each of them — 1500s is 1.56× the lane's worst observation
/// and 4.3× the reviewer's cold one (4.9× their warm), while 600s is 2.4×
/// the base flutter figure and 6.1× the reviewer's 99s. No timeout is
/// changed because the numbers differ; the bounds were conservative over
/// every observation anyone took.
///
/// The timeout is sized from the COLD column, because an implementation
/// execution runs in a FRESH detached worktree with no kernel cache; the warm
/// column is recorded so the difference is visible rather than argued.
///
/// Raising a bound does not weaken a check: the command still runs to
/// completion and its exit code is still authoritative. What a timeout still
/// guarantees is that a HUNG MAIN command fails — SIGKILLed, `ran == true`,
/// a FAILING row — never a pass and never an absent row (decision
/// `5c9e2b74`'s honesty constraint, pinned in
/// `multi_check_verification_plan_test.dart`). The ONE carve-out is the
/// SETUP path: a `setupCommand` failure is an environment problem, not a
/// verdict, so it deliberately reports `ran == false`, which the coordinator
/// turns into NO ROW at all (`workspace_verifier.dart`, the setup branch —
/// "the CHECK never started"). That absence is a designed outcome outside
/// the sentence above; the timeout guarantee binds the main command, which
/// by then has started and therefore always writes a FAILING row when it
/// hangs.
///
/// ## HOW A SWEEP BECOMES ROWS (decision `f3a81c27`)
///
/// `dart analyze` and `dart test` are declared at "each package root" — a
/// SWEEP, not a command. This plan expresses the sweep as one check PER ROOT,
/// with the root encoded in the check name
/// (`dart_test_packages_workflow_engine`). One row therefore means one
/// observable fact — that suite ran in that root — and a reader can never
/// mistake partial coverage for the whole sweep. [checkSlugFor] derives the
/// name; the full path is slugified, not just the basename, so two members
/// that ever share a basename cannot collide into one verification id.
///
/// ## THE ANTI-NARROWING GUARD
///
/// [workspaceMemberRoots] is the expansion source, and
/// `implementation_verification_plan_test.dart` parses the root
/// `pubspec.yaml`'s `workspace:` block and demands exact set equality with
/// it: a member added to the pubspec without its checks here fails the test,
/// and so does a check removed here. The gate's completeness claim therefore
/// cannot quietly become this list's opinion — which is the one property a
/// pinned list cannot have on its own, and the reason `f3a81c27` rejected a
/// pinned list of test files for the server runner while keeping static root
/// lists here (a workspace member set changes as rarely as the pubspec does,
/// and the test makes the change loud).
///
/// ## MEASURED FACTS THAT BOUND THIS PLAN
///
/// * **Every check resolves packages first.** In a fresh detached worktree at
///   base `54d440c` with no package resolution, the format command without a
///   preceding `dart pub get` exits **1** and reports **163** changed files
///   (the formatter falls back to the SDK default style without a package
///   language version); after resolution the same command exits 0. Each check
///   therefore runs its own `dart pub get` in its own root, so each is
///   self-contained — measured member `dart pub get` is 1.6s.
/// * **Every activated check fits its OWN declared timeout**, not the
///   verifier's 2-minute default — the cold/warm/timeout/headroom table is
///   in "PER-CHECK TIMEOUTS" above, sized from the cold column.
/// * **The rows are produced serially** — `_completeSuccess` runs checks in
///   plan order — so this plan adds roughly 7.5 minutes of validation to an
///   implementation execution when warm (measured end-to-end at this HEAD:
///   445s for all 32 checks, 31 exiting 0 and the flutter check failing only
///   on `transition_copy_test`), and much more cold in a system-temp
///   worktree — the runner alone took 959.67s there on this lane's single
///   observation (independent review re-measured 352s cold), and at base the
///   two newly activated checks were observed at 959.67s + 209s before any
///   sweep root pays its cold recompile. Even a cold figure sits inside the
///   4-hour execution budget
///   (`AgentExecutionBudgets.byRole['implement-feature']`, which bounds the
///   WHOLE dispatch path including verification), and it is stated here
///   because it is what the operator should expect to see.
final VerificationPlan implementationVerificationPlan = VerificationPlan(
  checks: [
    // MEASURED: 28s cold at base `54d440c`, 25s warm at this HEAD →
    // 3 minutes is 6.4× the cold measurement — headroom for a fresh
    // worktree's cold formatter pass, while still failing a genuinely hung
    // `dart format` within an operator-bounded time.
    const VerificationCheck(
      command: [
        'dart',
        'format',
        '--output=none',
        '--set-exit-if-changed',
        '.',
      ],
      setupCommand: ['dart', 'pub', 'get'],
      checkName: 'dart_format_repo_root',
      timeout: Duration(minutes: 3),
    ),
    // MEASURED worst root: `apps/control_plane` at 67s cold (17s warm at
    // this HEAD) → 5 minutes is 4.5× the cold figure. The same value is used
    // for every root because `dart analyze` is bounded by package size, and
    // the slowest measured root is the one that sets the floor for all of
    // them.
    for (final root in workspaceMemberRoots)
      VerificationCheck(
        command: const ['dart', 'analyze'],
        setupCommand: const ['dart', 'pub', 'get'],
        checkName: 'dart_analyze_${checkSlugFor(root)}',
        workingDirectory: root,
        timeout: const Duration(minutes: 5),
      ),
    // MEASURED worst root at base: `packages/execution_coordinator` at 80s
    // cold (warm worst at this HEAD: 32s, `packages/worker_runtime`) →
    // 5 minutes is 3.75× the cold figure, and every other suite measured
    // below it.
    for (final root in dartTestSweepRoots)
      VerificationCheck(
        command: const ['dart', 'test'],
        setupCommand: const ['dart', 'pub', 'get'],
        checkName: 'dart_test_${checkSlugFor(root)}',
        workingDirectory: root,
        timeout: const Duration(minutes: 5),
      ),
    // OBSERVED ONCE by this lane — not independently reproducible: 531s
    // through this runner's 6-way per-file pool cold in the main checkout
    // (base `54d440c`; 117s / 247.6s warm at this HEAD), and **959.67s cold
    // in a system-TEMP worktree** — which is the REPRESENTATIVE figure for
    // an execution, because `_triageWorkspaceRoot()` defaults to
    // `Directory.systemTemp/shipit_triage_workspaces`, so that is where the
    // worker runs this command. Independent review re-measured this runner at
    // 352s cold / 231–305s warm — different numbers, same direction, all
    // inside the bound. (237s is the single-process sweep AGENTS.md
    // rules out because one failing file must not hide behind the others.)
    // 25 minutes is 1.56× the worst run this lane observed and 4.3× the
    // reviewer's cold re-measurement — the slowest check in the
    // plan, which is why it carries the largest bound. The runner itself has
    // no internal timeout: a file that HANGS inside it is killed here, by
    // this bound, and fails — within 25 minutes, not within the 4-hour
    // execution budget.
    const VerificationCheck(
      command: ['dart', 'run', 'tool/run_unit_tests.dart'],
      setupCommand: ['dart', 'pub', 'get'],
      checkName: 'server_unit_tests_runner',
      workingDirectory: 'apps/server',
      timeout: Duration(minutes: 25),
    ),
    // MEASURED: 209s cold / 247s warm at base `54d440c`, 43s warm at this
    // HEAD → 10 minutes is 2.4× the slower base figure. The 43s is this
    // lane's single observation and is not independently reproducible —
    // independent review re-measured 99s, which 600s also clears (6.1×).
    // This check was
    // previously withheld partly for being base-red (`transition_copy_test`);
    // decision `8d4a1f53` routed that defect to the lane that owns
    // `packages/workflow_engine`, and it stays visible here as a real failing
    // check rather than an excluded one — measured at this HEAD: 506 passed,
    // 1 failed, the one failure being that test.
    const VerificationCheck(
      command: ['flutter', 'test'],
      setupCommand: ['dart', 'pub', 'get'],
      checkName: 'flutter_test_apps_control_plane',
      workingDirectory: 'apps/control_plane',
      timeout: Duration(minutes: 10),
    ),
  ],
);

/// Every member of the repository's pub workspace, in the order the root
/// `pubspec.yaml` lists them.
///
/// MEASURED at base `54d440c`: 16 members — 14 under `packages/` plus
/// `apps/server` and `apps/control_plane`. This list is the expansion source
/// for [implementationVerificationPlan]'s per-root checks, and it is GUARDED
/// against drift by `implementation_verification_plan_test.dart`, which
/// parses the root `pubspec.yaml`'s `workspace:` block and requires exact
/// set equality. See the plan's doc for why the guard matters.
const List<String> workspaceMemberRoots = [
  'packages/platform_contracts',
  'packages/workflow_engine',
  'packages/workflow_store',
  'packages/agent_runtime',
  'packages/worker_protocol',
  'packages/qa_orchestration',
  'packages/deployment_protocol',
  'packages/execution_coordinator',
  'packages/worker_runtime',
  'packages/scheduler',
  'packages/product_registry',
  'packages/store_contract_tests',
  'packages/control_plane_client',
  'packages/design_governance',
  'apps/server',
  'apps/control_plane',
];

/// The workspace members whose unit tier is a plain package `dart test` —
/// every member except the three exclusions below.
///
/// Each exclusion is a declaration with an owner, not a silent omission, and
/// `implementation_verification_plan_test.dart` pins each one's continued
/// truth so an exclusion cannot outlive its reason:
///
/// * `apps/server` — its unit tier is the runner row
///   (`server_unit_tests_runner`): plain `dart test` there also picks up
///   `test/integration/`, which needs a live database the per-execution tier
///   does not provide.
/// * `apps/control_plane` — covered by the `flutter test` row; `dart test`
///   cannot load `flutter_test` there (measured at base `54d440c`: 42
///   loading errors).
/// * `packages/control_plane_client` — has NO `test/` directory (measured at
///   base `54d440c`), and `dart test` in a package without one exits 65.
///   Activating it would fail every execution for an ABSENCE, which is the
///   condition the no-row honesty rule exists for — the check would report a
///   verdict about work that was never observed. The test pins the
///   directory's absence, so adding tests there without restoring this root
///   fails the test instead of leaving the new suite unrun.
///
/// Spelled out rather than derived, because a const list literal cannot carry
/// a `for` element (measured: the constant evaluator rejects it) and a
/// non-const derivation would let the list reorder itself at runtime. Spelled
/// out, the drift guard is the same pubspec-equality test the full member
/// list has: this list must equal [workspaceMemberRoots] minus exactly those
/// three names, and the test computes both sides independently.
const List<String> dartTestSweepRoots = [
  'packages/platform_contracts',
  'packages/workflow_engine',
  'packages/workflow_store',
  'packages/agent_runtime',
  'packages/worker_protocol',
  'packages/qa_orchestration',
  'packages/deployment_protocol',
  'packages/execution_coordinator',
  'packages/worker_runtime',
  'packages/scheduler',
  'packages/product_registry',
  'packages/store_contract_tests',
  'packages/design_governance',
];

/// The check-name slug for a workspace root: `packages/scheduler` becomes
/// `packages_scheduler`.
///
/// Slashes become underscores because [VerificationPlan] constrains check
/// names to `^[a-z0-9_]$` — the name is half of the verification id
/// (`ver-<executionId>-<checkName>`). The FULL path is slugified, not just
/// the basename, so two members that ever share a basename cannot collide
/// into one id (a collision would make the second row overwrite the first).
String checkSlugFor(String root) => root.replaceAll('/', '_');

/// One declared check, exactly as `AGENTS.md` -> "Required validation gates"
/// declares it.
///
/// The [command] is stored as the single verbatim string the gate will compare
/// by equality. It is never re-derived from an argv list: the comparison the
/// gate performs is string equality, so the declared side must be the same
/// string and not a re-spelling of it.
///
/// [workingDirectory] is load-bearing and is recorded for that reason — running
/// a package suite from the repository root gives different results than
/// running it from the package root, which `AGENTS.md` states as measured fact.
class DeclaredValidationCheck {
  const DeclaredValidationCheck({
    required this.checkName,
    required this.command,
    required this.workingDirectory,
  });

  /// The key a gate's `requireCommands` map is written against.
  final String checkName;

  /// The declared command string, verbatim from `AGENTS.md`.
  final String command;

  /// The declared working directory, verbatim from `AGENTS.md`.
  final String workingDirectory;
}

/// The **per-execution tier only**, verbatim from `AGENTS.md`'s table — all
/// FIVE checks.
///
/// The merge/release tier — `make test-integration` — is deliberately absent.
/// Decision `a0e6f31c` put it in a different tier, recorded at the gate that
/// owns it, and this record must never be read as claiming that check ran.
///
/// [implementationVerificationPlan] ACTIVATES all five of these (as 32
/// checks — see its doc, including the per-check timeout table), and
/// [perExecutionValidationChecksNotActivated] — the record of anything
/// withheld — is empty. The two are cross-checked in both directions by
/// `implementation_verification_plan_test.dart`.
const List<DeclaredValidationCheck> perExecutionValidationChecks = [
  DeclaredValidationCheck(
    checkName: 'dart_format_repo_root',
    command: 'dart format --output=none --set-exit-if-changed .',
    workingDirectory: 'repo root',
  ),
  DeclaredValidationCheck(
    checkName: 'dart_analyze_per_package_root',
    command: 'dart analyze',
    workingDirectory: 'each package root',
  ),
  DeclaredValidationCheck(
    checkName: 'dart_test_per_package_root',
    command: 'dart test',
    workingDirectory: 'every package root except apps/server',
  ),
  DeclaredValidationCheck(
    checkName: 'server_unit_tests_runner',
    command: 'dart run tool/run_unit_tests.dart',
    workingDirectory: 'apps/server',
  ),
  DeclaredValidationCheck(
    checkName: 'flutter_test_apps_control_plane',
    command: 'flutter test',
    workingDirectory: 'apps/control_plane',
  ),
];

/// The declared per-execution checks that [implementationVerificationPlan]
/// does **not** activate — **EMPTY as of decisions `5c9e2b74` +
/// `8d4a1f53`**, because the plan now activates all five.
///
/// ## WHY THE MAP STILL EXISTS WHILE EMPTY
///
/// It used to carry the two withheld checks with their measured blockers:
/// the server unit-test runner (531s through its per-file pool in the main
/// checkout, **959.67s cold in a system-temp worktree on this lane's single
/// observation** — the default execution location, re-measured at 352s cold
/// by independent review — with 237s as the single-process sweep AGENTS.md
/// rules out; all three over the verifier's 2-minute per-command budget —
/// plus `onboarding_test.dart` needing a live database) and
/// `flutter test` (209s cold / 247s warm, plus a base-red
/// `transition_copy_test`). Both blockers were MEASURED, and both are now
/// RESOLVED rather than deleted:
///
/// * decision `5c9e2b74` authorized the per-check timeout MECHANISM (its
///   own sizing "~4min / ~4min"; no final values, no amendment), and the
///   values now carried by the plan — 25 min and 10 min — were sized at THIS
///   HEAD from this lane's measurements, so both checks fit — see the
///   timeout table in [implementationVerificationPlan]'s doc;
/// * decision `8d4a1f53` reclassified `onboarding_test.dart` to
///   `test/integration/` (it needs a live database; the per-execution tier
///   excludes integration BY CONSTRUCTION) and routed `transition_copy_test`
///   to the lane that owns `packages/workflow_engine`.
///
/// The map stays as a record of the ONE place a withheld check can be
/// declared, so the honesty rule below keeps having a home. `null` or a
/// removed map would make "withheld" unrecoverable as a concept; an empty map
/// makes the current state a VALUE that a test compares against the plan.
///
/// ## THE HONESTY RULE, UNCHANGED
///
/// This map exists so a gap is a value in the tree rather than a paragraph
/// in a review comment. A plan that reads as full coverage while covering
/// less is exactly the laundering decision `1b7e4c93` rejected, and the only
/// durable defence is to make any shortfall impossible to miss:
/// `implementation_verification_plan_test.dart` derives the activated set
/// FROM THE PLAN itself and asserts it equals `perExecutionValidationChecks`
/// minus this map's keys — a declared check withheld but still present in the
/// plan, or activated but absent from it, fails the test. So does a NEW
/// entry appearing here without the plan dropping its check.
const Map<String, String> perExecutionValidationChecksNotActivated = {};

/// The plans this process can attach, by role.
///
/// The single source of truth for role -> plan. Both
/// [buildTriageExecutionCoordinator] and
/// [buildImplementationExecutionCoordinator] read their plan from here, so the
/// routing cannot disagree between the two composition paths.
///
/// TRIAGE IS UNTOUCHED. Every role that is not an implementation role keeps
/// [triageVerificationPlan], byte for byte.
VerificationPlan verificationPlanForRole(AgentRole role) => switch (role) {
  // The implementation roles write Dart into a worktree of THIS repository, so
  // the declared check that can actually run there is the repository-root one.
  // `correctionImplementer` is included because a correction is implementation
  // work: it edits the same repository, in the same kind of worktree.
  AgentRole.implementer ||
  AgentRole.correctionImplementer => implementationVerificationPlan,
  _ => triageVerificationPlan,
};

/// Composes the ONE [ExecutionCoordinator] the TRIAGE and REVIEW lanes drive
/// work through.
///
/// Reads its plan from [verificationPlanForRole], which returns
/// [triageVerificationPlan] for [AgentRole.triageDefect] — the same plan this
/// function attached before role scoping existed, so this routing is what keeps
/// triage provably unchanged rather than merely intended to be.
ExecutionCoordinator buildTriageExecutionCoordinator({
  required ExecutionStore store,
  required DurableWorkflowEngine workflowEngine,
  required AgentRuntime runtime,
  ModelExecutionRecordStore? modelExecutionRecordStore,
}) => ExecutionCoordinator(
  store: store,
  workflowEngine: workflowEngine,
  runtime: runtime,
  verificationPlan: verificationPlanForRole(AgentRole.triageDefect),
  modelExecutionRecordStore: modelExecutionRecordStore,
);

/// Composes the [ExecutionCoordinator] the IMPLEMENTATION lane drives work
/// through — `OD-6`'s answer to "a role-scoped plan needs either a per-role
/// coordinator or a plan resolved from the job's role".
///
/// BOTH, deliberately: [verificationPlanForRole] resolves the plan from the
/// role, and this is the coordinator that attaches it. The alternative half —
/// one coordinator that looks the plan up per job — would need
/// `ExecutionCoordinator` to accept a resolver function instead of a
/// [VerificationPlan], which is a change under
/// `packages/execution_coordinator/`. That package is out of scope for this
/// slice, so the per-role coordinator is the shape that fits the ownership
/// boundary, and the lookup keeps it to one source of truth.
///
/// It is a COORDINATOR, not a scheduler: nothing here mounts, re-points or
/// enables any dispatch, and the scheduler stays exactly as `run()` leaves it.
ExecutionCoordinator buildImplementationExecutionCoordinator({
  required ExecutionStore store,
  required DurableWorkflowEngine workflowEngine,
  required AgentRuntime runtime,
  ModelExecutionRecordStore? modelExecutionRecordStore,
}) => ExecutionCoordinator(
  store: store,
  workflowEngine: workflowEngine,
  runtime: runtime,
  verificationPlan: verificationPlanForRole(AgentRole.implementer),
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

/// The code carried by the line emitted when a tick has held the single-flight
/// guard past its lease and the guard has been taken back from it.
///
/// A DIFFERENT code from [tickOverlapDroppedCode] on purpose, because the two
/// describe opposite facts and an operator must never grep one and read the
/// other: a drop says a tick was not needed, this says a tick stopped being
/// answerable. See [TickSingleFlight].
const String tickHoldExpiredCode = 'TICK_HOLD_EXPIRED';

/// The code carried by a tick that finished AFTER its hold lease expired — the
/// late line that keeps an abandoned tick accounted for.
const String tickCompletedLateCode = 'TICK_COMPLETED_AFTER_HOLD_EXPIRED';

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
      overlappedTicks = 1,
      abandoned = false,
      heldFor = null;

  const TickSingleFlightResult.ran(
    this.outcome, {
    this.abandoned = false,
    this.heldFor,
  }) : ran = true,
       overlappedTicks = 0;

  /// Whether the tick actually ran.
  final bool ran;

  /// What it did. Null exactly when [ran] is false.
  final TickOutcome? outcome;

  /// Always 1 for a dropped trigger and 0 for a completed one. Carried on EVERY
  /// result — including the ones that ran — so a consumer never has to tell an
  /// absent field from a zero.
  final int overlappedTicks;

  /// Whether this tick's hold lease expired before it finished.
  ///
  /// True only on a result whose [ran] is true, and never on a drop: a drop is
  /// not an abandoned tick, it is a tick that was never started. A consumer that
  /// counts completions MUST treat an abandoned completion as separate from a
  /// normal one, which is why the two log under different event names.
  final bool abandoned;

  /// How long the guard was held before this tick finished.
  ///
  /// Null on a drop — nothing was held, because nothing ran. Carried on a
  /// completion so a consumer can see that an abandoned tick held the guard for
  /// at least the lease, rather than inferring it from the boolean alone.
  final Duration? heldFor;

  @override
  String toString() => ran
      ? 'ran: true, overlappedTicks: $overlappedTicks, outcome: $outcome'
      : 'ran: false, overlappedTicks: $overlappedTicks (dropped, code: '
            '$tickOverlapDroppedCode)';
}

/// The default clock [TickSingleFlight] reads, named so a test that injects one
/// is visibly replacing a real thing and not the absence of a thing.
DateTime _systemUtcClock() => DateTime.now().toUtc();

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
///
/// ## WHY THERE IS A LEASE ON THE GUARD, AND WHAT IT IS NOT
///
/// The guard is released by exactly two things: [_runGuarded] completing, and
/// [_expireHold] firing. There is no third path, and no `finally` that can be
/// skipped — so a *skipped release* is not a shape this class can take, and an
/// earlier reading of the 2026-10-18 incident as one was wrong.
///
/// What this class CAN do is hold the guard forever, and that is the real
/// defect. `whenComplete` releases the guard when the tick's future settles,
/// and that future settles only when `runTick()` returns — and `runTick()`
/// awaits a chain that is bounded per shell-out, not as a whole. The agent
/// execution carries its own `.timeout()` (`LocalWorker._drive`, around
/// `executionDriver.execute`), and the git phases each bound every command:
/// workspace preparation and cleanup at 60s (`_git` in
/// `GitWorktreeWorkspaceManager`, reached by `_removeWorktreeUnsafe` →
/// `_runGit`), artifact commit at 60s (`ArtifactCommitter._capture`).
///
/// Two properties of those bounds are load-bearing, and an earlier revision
/// of this paragraph got both wrong. They are per *command*, so a phase that
/// runs several git commands can still take a multiple of its bound. And git
/// inspection was the one await with no bound at all: `GitWorkspaceInspector`
/// declared `timeout = 30s` and its class doc promised "a hard bound so a
/// wedged filesystem cannot hold the worker hostage", yet `_capture` awaited
/// `Process.run` directly and never applied the field — a declared,
/// documented, dead timeout that read as a live one. It is applied now, and
/// `inspector_timeout_bound_test.dart` pins it with a stub git that sleeps.
/// Note too that `.timeout()` bounds the *wait*, not the process: an expired
/// git command is abandoned, not killed.
///
/// So a tick whose body is stuck in any of those still holds the guard far
/// longer than a dispatch cycle should take, and a guard held that long means
/// every later trigger is dropped: the log then reads as a busy platform doing
/// nothing, which is the exact silence this class was written to end.
///
/// The lease fixes THAT, and it fixes it in the direction that loses the least.
/// On expiry the guard is released and the abandoned tick is left RUNNING —
/// its job, its claim, its capacity slot and its agent execution are all
/// untouched. Cancelling it would free the symptom and destroy the evidence,
/// and it would also destroy the work. So the lease never cancels: it stops
/// *waiting*, loudly, and lets the next trigger take over.
///
/// ## WHY THE RELEASE IS TOKENISED, NOT A BOOLEAN WRITE
///
/// The obvious implementation — `Timer(..., () => _running = false)` — is
/// wrong, and wrong in the one direction this class exists to prevent. The
/// abandoned tick's `whenComplete` would then clear `_running` a second time,
/// AFTER a fresh trigger had already taken the guard, so two ticks would be in
/// flight and nothing would say so. Every release therefore carries the token
/// of the tick that earned it and is applied only if that tick still holds the
/// guard.
///
/// ## WHAT THE LEASE DOES NOT FIX, STATED RATHER THAN IMPLIED
///
/// Releasing the guard stops the platform WAITING. It does not stop the stuck
/// work, and in one shape it can let abandoned work accumulate: if *every* tick
/// wedges, each expiry admits one more abandoned body, and [_abandoned] grows by
/// one per un-settled body because its entries are removed only when a body
/// finally returns. That shape does not arise from a single stuck execution —
/// a job that is already `running` is not eligible, so the ticks after it
/// finish normally and drain the queue AROUND it, which is what the recovery
/// test asserts — but it is not impossible, and the durable bound on it is the
/// capacity cap plus the zombie reclaim, not this class.
///
/// Ending the stuck work itself means cancelling the execution or reaping the
/// job, which is a different and more consequential decision than releasing a
/// guard, and is deliberately not smuggled in here.
class TickSingleFlight {
  TickSingleFlight({
    required this.runTick,
    this.log,
    this.maxHold,
    DateTime Function()? clock,
    Timer Function(Duration duration, void Function() callback)? leaseTimer,
  }) : _clock = clock ?? _systemUtcClock,
       _leaseTimer = leaseTimer ?? Timer.new;

  /// The tick, invoked only after the guard has been taken. Public so the
  /// constructor can take it as an initializing formal, and so a test can hold
  /// the same reference the loop calls.
  final Future<TickOutcome> Function() runTick;

  /// Where the two events go. Null silences them, which is what a test that only
  /// cares about control flow wants.
  final void Function(String event, Map<String, dynamic> data)? log;

  /// How long the guard may be held before it is taken back.
  ///
  /// NULL means no lease, which is the library default and the right one for a
  /// test that wants to control the clock itself. It is NOT what production
  /// runs: the composition root always passes a resolved bound, and
  /// [holdSummary] says in words which of the two a running process is in, so a
  /// banner can never describe a lease the ticking object does not have.
  final Duration? maxHold;

  /// How the hold-lease timer is scheduled.
  ///
  /// Injectable so a TEST can fire the lease at a moment it CHOOSES instead
  /// of whenever the wall clock and the process scheduler permit: on a loaded
  /// host a 40 ms lease can outlive the recovered tick it is racing, firing
  /// the lease twice and turning an exact `hasLength(1)` into a load flake
  /// (measured, F-199). The default is the real [Timer] and production passes
  /// nothing, so the shipped behaviour is unchanged; only tests that opt in
  /// get deterministic lease time.
  final Timer Function(Duration, void Function()) _leaseTimer;

  /// The clock, injectable so a test can assert the LEASE fired at the
  /// configured elapsed time rather than whenever the machine scheduled it.
  final DateTime Function() _clock;

  /// Which tick holds the guard, by token. Null means free.
  ///
  /// A token rather than a bool precisely so a late release cannot clear a
  /// guard that a later tick has taken — see the class comment.
  int? _heldBy;

  /// Monotonic token source. Overflow is not a concern: a tick per 30 seconds
  /// takes about two billion years to exhaust a 64-bit int.
  int _nextToken = 0;

  /// Ticks whose lease expired and which have not finished yet. Membership is
  /// what makes a completion line say "late", and the entry is removed when
  /// that tick's body finally settles, so this cannot grow without bound.
  final Set<int> _abandoned = <int>{};

  /// When the current holder took the guard, for the lease diagnostics.
  DateTime? _heldSince;

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

  /// Whether a tick is in flight. Read by tests and by nothing in production.
  bool get isRunning => _heldBy != null;

  /// One line naming the lease actually in force, for the startup banner.
  ///
  /// Read off this object rather than off the resolution that produced it, for
  /// the same reason the banner reads `capacitySummary` off the live scheduler:
  /// so the line and the object that enforces it cannot disagree. States the
  /// unbounded case in words rather than omitting the field, because "the field
  /// is absent" is exactly the ambiguity this exists to remove.
  String get holdSummary => maxHold == null
      ? 'NO LEASE: this single-flight guard can be held for ever by a tick that '
            'never returns. This is the library default and is safe only for a '
            'caller that bounds runTick itself.'
      : 'tick hold lease: ${maxHold!.inSeconds}s '
            '($tickHoldBoundEnvVar). Past it the guard is RELEASED and the '
            'abandoned tick keeps running untouched — nothing is cancelled, and '
            'its eventual completion is logged as '
            'scheduler.tick.completed_late.';

  /// Runs one tick, or records that one is already running and returns.
  ///
  /// On the dropped path this completes IMMEDIATELY with [ran] false. It does not
  /// wait for the running tick: see the class comment for why waiting is the
  /// wrong answer.
  Future<TickSingleFlightResult> trigger() {
    if (_heldBy != null) {
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
    final token = ++_nextToken;
    final heldSince = _clock();
    _heldBy = token;
    _heldSince = heldSince;
    // `whenComplete` releases the guard on the success path AND on the failure
    // path, and passes the original error through untouched. A guard released
    // only on success would wedge the loop shut after the first failure, and
    // every later tick would report itself as "overlapping" against a tick that
    // ended minutes ago — a loop that looks busy and is permanently stopped.
    //
    // The timer is the OTHER release, and it is armed only when a lease is in
    // force. It is cancelled in [_releaseHold] whichever way the tick ends.
    final lease = maxHold == null
        ? null
        : _leaseTimer(maxHold!, () => _expireHold(token));
    return _runGuarded(token, heldSince).whenComplete(() {
      _releaseHold(token, lease);
    });
  }

  /// Takes the guard back from a tick that has held it past its lease.
  ///
  /// Deliberately does NOT cancel, abort, signal or interrupt the tick: the
  /// guard is what was taken back, not the work. The abandoned tick keeps its
  /// claim, its capacity slot and its agent execution, and reports on its own
  /// `completed_late` line whenever it finally settles — so an operator can see
  /// both halves: that dispatch was released, and what the abandoned tick went
  /// on to do.
  void _expireHold(int token) {
    if (_heldBy != token) {
      // The tick already finished and a later one is in flight. A stale timer
      // must be a no-op, or it would take a guard it never held.
      return;
    }
    final elapsed = _heldSince == null
        ? null
        : _clock().difference(_heldSince!);
    // Membership is what makes this tick's completion line say "late". Added
    // BEFORE the guard is cleared so that a tick settling in the same turn is
    // already accounted for as abandoned.
    _abandoned.add(token);
    _heldBy = null;
    log?.call('scheduler.tick.hold_expired', <String, dynamic>{
      'ran': true,
      'overlappedTicks': 0,
      'code': tickHoldExpiredCode,
      'maxHoldSeconds': maxHold?.inSeconds,
      'heldForSeconds': elapsed?.inSeconds,
      'cancelled': false,
      'action':
          'the tick still in flight has held the single-flight guard past its '
          'lease, so the guard has been RELEASED and the next trigger will run. '
          'That tick was NOT cancelled: its claim, its capacity slot and its '
          'agent execution are untouched and it is still running. When it '
          'settles it reports on scheduler.tick.completed_late. If nothing ever '
          'reported a real completion between this line and now, the tick is '
          'stuck and the job it holds is stuck with it.',
    });
  }

  /// Releases the guard for [token], if [token] still holds it.
  ///
  /// The identity check is the whole reason this is a method rather than an
  /// assignment: see the class comment on tokenised release.
  void _releaseHold(int token, Timer? lease) {
    lease?.cancel();
    _abandoned.remove(token);
    if (_heldBy == token) {
      _heldBy = null;
      _heldSince = null;
    }
  }

  /// The tick itself, and the completion line.
  ///
  /// Everything here is BELOW the guard, which is why it may await as much as it
  /// likes. The completion line is emitted on both paths so that a failing tick
  /// still leaves the same shape behind as a clean one — and on the LATE line
  /// when the lease expired first, so that a consumer counting
  /// `scheduler.tick.completed` never counts an abandoned tick as one of its
  /// own.
  Future<TickSingleFlightResult> _runGuarded(
    int token,
    DateTime heldSince,
  ) async {
    bool wasAbandoned() => _abandoned.contains(token);

    // Measured against THIS tick's own start, not off [_heldSince]. After an
    // expiry a later tick overwrites that field, and an abandoned tick that
    // finished minutes later would otherwise report the LATER tick's elapsed
    // time as its own — a number that is wrong in the one line an operator is
    // reading precisely because they do not trust it.
    Duration? elapsed() => _clock().difference(heldSince);

    String event() => wasAbandoned()
        ? 'scheduler.tick.completed_late'
        : 'scheduler.tick.completed';

    try {
      final outcome = await runTick();
      log?.call(event(), <String, dynamic>{
        'ran': true,
        'dispatched': outcome.dispatched,
        'handledOff': outcome.handledOff,
        'sweepEnqueued': outcome.sweepEnqueued,
        'failedSections': outcome.failedSections,
        'reconcileFailed': outcome.reconcileFailed,
        'reconcileFailedCount': outcome.reconcileFailed.length,
        'overlappedTicks': 0,
        'heldForSeconds': elapsed()?.inSeconds,
        'code': wasAbandoned() ? tickCompletedLateCode : null,
        if (wasAbandoned())
          'action':
              'this tick finished after its hold lease expired, so a later tick '
              'has already run. Its counts below are real and its work was '
              'never cancelled; read them as the abandoned tick\'s, not as the '
              'current one.',
      });
      return TickSingleFlightResult.ran(
        outcome,
        abandoned: wasAbandoned(),
        heldFor: elapsed(),
      );
    } on Object {
      // The tick's own halves already logged what they caught. This records
      // that the tick as a whole ended badly, so a line that says `ran: true`
      // with an empty `failedSections` is unambiguous: it means no half threw.
      log?.call(event(), <String, dynamic>{
        'ran': true,
        'dispatched': -1,
        'handledOff': -1,
        'sweepEnqueued': -1,
        'failedSections': const <String>['tick'],
        'overlappedTicks': 0,
        'heldForSeconds': elapsed()?.inSeconds,
        'code': wasAbandoned() ? tickCompletedLateCode : null,
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

/// The environment variable that overrides how long the scheduler's
/// single-flight guard may be held before the guard is taken back.
///
/// Same posture as [executionCapacityEnvVar] and for the same reason: a bound
/// that needs a code change to move is a bound nobody moves, and how long a
/// control plane should stop dispatching before it starts again is an operator
/// decision, not a constant this file is entitled to bake in.
///
/// Unset does NOT mean "no lease" — it means the derived default in
/// [AgentExecutionBudgets.tickHoldDefault]. See that member for why the derived
/// value is as large as it is; the short version is that a tick dispatches its
/// whole backlog serially, so a LEGITIMATE hold is a sum over the backlog and
/// unbounded in it, and a lease shorter than that would abandon working ticks.
const String tickHoldBoundEnvVar = 'SHIPIT_TICK_MAX_HOLD_SECONDS';

/// Thrown when [tickHoldBoundEnvVar] is set to something unusable.
///
/// A refusal, on the reasoning [UnboundedDispatchRefused] already states: the
/// failure this guards against is a platform that silently stops dispatching
/// for ever, and quietly substituting a different bound for the one an
/// operator asked for is the same defect wearing a different hat. The refusal
/// happens before `Serverpod` is constructed, so the process never binds a
/// port in this state.
class UnusableTickHoldBound implements Exception {
  const UnusableTickHoldBound(this.diagnostic);

  /// Names the variable and what was wrong with it. Never a credential.
  final String diagnostic;

  @override
  String toString() => diagnostic;
}

/// Resolves the tick hold lease from [environment], or refuses.
///
/// ## Why an unset variable is NOT an absent lease
///
/// "Unbounded" is the one answer that must never be reachable by accident — it
/// is the exact state that stopped dispatch on 2026-10-18 — so absence
/// resolves to the derived default rather than to nothing. Every OTHER unusable
/// value refuses, because an operator who set the variable has stated an intent
/// and silently serving a different number than the one they set is how a
/// tuning knob becomes a lie.
///
/// The resolution is pure over its argument, so a test can exercise it without
/// touching [Platform.environment].
Duration resolveTickHoldBound(
  Map<String, String> environment, {
  void Function(String event, Map<String, dynamic> data)? log,
}) {
  final raw = environment[tickHoldBoundEnvVar];
  if (raw == null) {
    final derived = AgentExecutionBudgets.tickHoldDefault;
    log?.call('server.tick_hold.resolved', <String, dynamic>{
      'boundSeconds': derived.inSeconds,
      'source': 'derived',
      'note':
          '$tickHoldBoundEnvVar is unset, so the derived default is in force. '
          'It is large BECAUSE a tick dispatches its whole backlog serially and '
          'a legitimate hold is therefore a sum over the backlog. Set '
          '$tickHoldBoundEnvVar to shorten it if this deployment would rather '
          'recover sooner from a stuck tick than wait out a large backlog.',
    });
    return derived;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    log?.call('server.tick_hold.refused', <String, dynamic>{
      'bound': 'NOT RESOLVED — refusing to start',
      'action':
          '$tickHoldBoundEnvVar is empty. Unset it to use the derived default, '
          'or set it to an integer >= 1.',
    });
    throw UnusableTickHoldBound(
      '$tickHoldBoundEnvVar is empty. Unset it to use the derived default '
      '(${AgentExecutionBudgets.tickHoldDefault.inSeconds}s), or set it to an '
      'integer >= 1.',
    );
  }
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed < 1) {
    final why = parsed == null
        ? 'is not an integer'
        : 'is below the minimum of 1 — a lease of 0 seconds would take the '
              'guard back from every tick the instant it took it, which is the '
              'same as no guard at all';
    log?.call('server.tick_hold.refused', <String, dynamic>{
      'bound': 'NOT RESOLVED — refusing to start',
      'value': raw,
      'action': '$tickHoldBoundEnvVar $why. Set an integer >= 1, or unset it.',
    });
    throw UnusableTickHoldBound(
      '$tickHoldBoundEnvVar="$raw" $why. Set an integer >= 1, or unset it to '
      'use the derived default '
      '(${AgentExecutionBudgets.tickHoldDefault.inSeconds}s).',
    );
  }
  final bound = Duration(seconds: parsed);
  log?.call('server.tick_hold.resolved', <String, dynamic>{
    'boundSeconds': bound.inSeconds,
    'source': 'configured',
    'derivedDefaultSeconds': AgentExecutionBudgets.tickHoldDefault.inSeconds,
  });
  return bound;
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

  /// The derived default for [tickHoldBoundEnvVar]: how long the scheduler's
  /// single-flight guard may be held before it is taken back.
  ///
  /// ## WHY IT IS THIS LARGE — READ BEFORE SHORTENING IT
  ///
  /// `Scheduler.tick` dispatches inside a `for (;;)` loop and `await`s
  /// `_dispatchOne` for every eligible job SERIALLY, so one tick holds the guard
  /// for `Σ (N × budget)` over the jobs it dispatched — a sum that is UNBOUNDED
  /// IN N. There is therefore no lease short enough to be operationally useful
  /// that is also longer than every legitimate tick, and any default chosen for
  /// "recover from a stuck tick in a reasonable time" is also a default that
  /// abandons legitimate ticks on a large backlog.
  ///
  /// So the default is chosen in the SAFE direction, and its size is stated
  /// rather than implied: [rejectedStalenessMultiplier] × the largest budget in
  /// [byRole] + [stallAllowance]. At today's budgets that is
  /// `4 × 4h + 1h = 17h`, which is long — deliberately so. The cost is named:
  /// **a tick that genuinely wedges leaves dispatch stopped for up to 17 hours**
  /// rather than for ever.
  ///
  /// The two are separable without a code change, and that is what the
  /// environment variable is for: the expensive thing about a stuck tick is that
  /// it is silent, and `server.tick_hold.resolved` plus
  /// `scheduler.tick.hold_expired` make it loud immediately, whether or not it
  /// is short. An operator who would rather recover sooner than wait out a
  /// backlog sets `SHIPIT_TICK_MAX_HOLD_SECONDS`; what they are then accepting
  /// is stated in [TickSingleFlight]'s class comment — an expired lease releases
  /// the GUARD and lets a second tick run alongside the abandoned one, and
  /// concurrent AGENT executions remain hard-bounded by
  /// `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS`, which is enforced durably at claim
  /// time rather than by this guard.
  static Duration get tickHoldDefault {
    var largest = Duration.zero;
    for (final budget in byRole.values) {
      if (budget > largest) largest = budget;
    }
    return Duration(seconds: largest.inSeconds * rejectedStalenessMultiplier) +
        stallAllowance;
  }

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

import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'capacity/execution_capacity.dart';
import 'capacity/job_capacity_guard.dart';
import 'dispatch/worker_dispatch.dart';
import 'health/provider_health_monitor.dart';
import 'implementation_inflow.dart';
import 'policy/entry_hop.dart';
import 'policy/retry_policy.dart';
import 'policy/runnable_work.dart';
import 'policy/superseded_execution.dart';
import 'queue/job_queue.dart';
import 'store/job_store.dart';

/// Static place-and-run parameters the scheduler stamps into every job. The
/// scheduler itself never owns a worker, a workspace, or an agent runtime;
/// it merely carries the worker-facing configuration that was decided when
/// the platform was configured.
@immutable
class SchedulerWorkload {
  const SchedulerWorkload({
    required this.repositoryPath,
    required this.startingRevision,
    required this.timeoutSeconds,
    required this.runtimeTypeId,
    this.cleanupPolicy = WorkerCleanupPolicy.removeAlways,
  });

  final String repositoryPath;
  final String startingRevision;
  final int timeoutSeconds;
  final String runtimeTypeId;
  final WorkerCleanupPolicy cleanupPolicy;
}

/// What reconciliation was able to observe about the process behind a
/// non-terminal worker execution.
///
/// This exists because liveness is not a property that can be read off a status
/// string. A live worker and a worker whose process died mid-execution both
/// leave a row that is not terminal, and the old reconciler asked only the
/// second question, which is why a zombie outlived a 10 minute lease for hours.
enum ExecutionLiveness {
  /// Observed alive right now. Renew the lease; never dispatch a duplicate.
  alive,

  /// Observed NOT alive. Nothing is running, so the claim must be reclaimed.
  dead,

  /// Liveness could not be observed from here.
  unknown,
}

/// Observes whether anything is still running behind [execution].
///
/// Injected rather than derived because the scheduler cannot answer this from
/// durable state alone: the worker row records what the execution was doing,
/// not whether the process doing it still exists. A probe that can actually
/// observe the runtime (the coordinator's live sessions, a worker heartbeat, an
/// agent-runtime query) is what turns "is this row terminal" into "is there a
/// process behind it".
typedef ExecutionLivenessProbe =
    Future<ExecutionLiveness> Function(WorkerExecution execution, DateTime now);

/// Builds the probe that answers liveness from a live-session oracle.
///
/// The oracle is the thing that actually knows: a predicate over an AGENT
/// execution id that is true only while a session for it is running in this
/// process. The composition root supplies the real one — the execution
/// coordinator's live-session set — and this function owns the DECISION about
/// what a failed observation means, which is the part worth testing and the
/// part that is easy to get backwards.
///
/// It lives here, next to [ExecutionLiveness] and the staleness bound it feeds,
/// rather than in the composition root, because a fail-direction rule that
/// cannot be executed is a rule nobody has checked. The composition root still
/// chooses WHAT to observe; this only says what to conclude.
///
/// ## Fail direction
///
/// `unknown` — renew the lease, let the staleness bound decide — is returned
/// whenever liveness cannot be observed:
///
///  * an execution that recorded no agent execution id has nothing to ask
///    about. That is an absence of evidence, not evidence of death, and
///    reporting `dead` would let a worker be reclaimed because its first agent
///    execution id failed to persist;
///  * an oracle that throws, for the same reason.
///
/// `unknown` does NOT reclaim immediately. Live work is never killed on a
/// failure to observe, and a duplicate is never dispatched; an execution this
/// probe genuinely cannot see falls back to the staleness bound, which is what
/// stops an unobservable zombie from being renewed forever.
ExecutionLivenessProbe liveSessionLivenessProbe(
  bool Function(String agentExecutionId) hasLiveSession,
) {
  return (WorkerExecution execution, DateTime now) async {
    final agentExecutionId = execution.agentExecutionId;
    if (agentExecutionId == null || agentExecutionId.isEmpty) {
      return ExecutionLiveness.unknown;
    }
    try {
      return hasLiveSession(agentExecutionId)
          ? ExecutionLiveness.alive
          : ExecutionLiveness.dead;
    } catch (_) {
      return ExecutionLiveness.unknown;
    }
  };
}

/// Function to build a dedupe key for a work item.
typedef DedupeKeyBuilder =
    String Function(WorkItem item, JobDefinition definition);

/// Function to build an instruction for a work item.
typedef InstructionBuilder =
    String Function(WorkItem item, JobDefinition definition);

/// Function to build a worker execution request for a job.
typedef RequestBuilder =
    Future<WorkerExecutionRequest> Function(
      Job job,
      SchedulerWorkload workload,
      WorkItem item,

      /// Null when the Scheduler was constructed without a model selector, in
      /// which case a builder must leave the request's model unpinned.
      ModelSelectionService? modelSelection,
    );

/// Resolves the [SchedulerWorkload] a job must operate on, per work item.
///
/// Most schedulers have ONE workload fixed at construction (the slice's
/// repository). A review job does not: it must review the revision the
/// IMPLEMENTER produced for THIS work item, which only the composition root can
/// resolve from durable state. Returning `null` means no artifact could be
/// resolved; the scheduler then fails closed and never dispatches against the
/// construction-time default.
typedef WorkloadResolver =
    Future<SchedulerWorkload?> Function(Job job, WorkItem item);

/// Resolves the per-role model policy into a request's runtime config.
///
/// Model pinning is opt-in. Without a [ModelSelectionService] the returned map
/// is empty, the request carries no model override, and the adapter applies
/// its own default — so constructing a Scheduler without a selector behaves
/// exactly as it did before per-role model selection existed.
///
/// The escalation index is read from `WorkItem.metadata`, which is the single
/// durable home for it.
Future<Map<String, String>> modelRuntimeConfig(
  Job job,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  if (modelSelection == null) return const {};
  final escalationIndex = item.metadata?['escalationIndex'] as int? ?? 0;
  final selection = await modelSelection.select(
    role: job.requiredRole,
    escalationIndex: escalationIndex,
  );
  return {
    'model': selection.modelId,
    'provider': selection.provider,
    'escalationIndex': selection.escalationIndex.toString(),
    'isFallback': selection.isFallback.toString(),
  };
}

/// Whether a reclaim managed to get its work item out of
/// [WorkItemState.agentExecuting].
enum _WorkItemRelease {
  /// Out of `agentExecuting` — either this reclaim moved it, or another writer
  /// already had. The reclaim may go on to its remaining writes.
  released,

  /// STILL executing after the per-tick attempt budget.
  ///
  /// The reclaim must not proceed. Completing the job while the work item sits
  /// in `agentExecuting` strands the work permanently, because `tick` only ever
  /// reaches held jobs and a terminal job is never reconciled again.
  contended,
}

/// Thrown when a reclaim could not release its work item inside the per-tick
/// attempt budget.
///
/// Aborting BEFORE any of the reclaim's three writes is the entire point of
/// throwing here: the job stays non-terminal, so the next tick re-reaches the
/// row and tries again from a clean state. Once contention subsides a later
/// tick completes the reclaim in full. Deferring is therefore a delay, never a
/// loss — the same property the write ORDER in `Scheduler._reclaimZombie`
/// preserves for a crash.
///
/// The budget is PER TICK, not per reclaim: sustained contention makes every
/// tick attempt [Scheduler._maxReclaimAttempts] times and then defer, rather
/// than blocking the tick indefinitely.
class _ReclaimDeferredException implements Exception {
  const _ReclaimDeferredException();

  @override
  String toString() =>
      'zombie reclaim deferred: work item still agentExecuting after '
      '${Scheduler._maxReclaimAttempts} attempts this tick';
}

/// One job a tick could not reconcile, and why.
@immutable
class ReconcileFailure {
  const ReconcileFailure({required this.jobId, required this.error});

  final String jobId;

  /// `toString()` of whatever was thrown. Never a credential.
  final String error;

  @override
  String toString() => '$jobId: $error';
}

/// One item the workflow policy called runnable that the scheduler refused to
/// dispatch, and why.
@immutable
class EntryHopRefusal {
  const EntryHopRefusal({
    required this.workItemId,
    required this.state,
    required this.reason,
  });

  final String workItemId;
  final String state;

  /// `toString()` of whatever was refused, in operator-facing words. Never a
  /// credential.
  final String reason;

  @override
  String toString() => '$workItemId ($state): $reason';
}

/// One item the completion inflow considered, and what it did about it.
///
/// Reported for EVERY item in a declared inflow state, whether or not anything
/// moved — including the refusals. "The lane routed nothing" and "the lane
/// looked at four items and moved none" are different operational facts, and
/// only the second one is ever a problem.
@immutable
class CompletionInflowMove {
  const CompletionInflowMove({
    required this.workItemId,
    required this.from,
    required this.to,
    required this.reason,
  });

  final String workItemId;

  /// The state the item was read in. Named `agentCompleted` in practice, but
  /// read from the item rather than assumed, because the definition declares
  /// its own source set.
  final WorkItemState from;

  /// Where the item was moved, or `null` when nothing was moved — because the
  /// route was the state it was already in, because the attempt budget is
  /// spent, or because a writer got there first.
  final WorkItemState? to;

  /// The operator-facing reason. Never a credential.
  final String reason;

  bool get moved => to != null && to != from;

  @override
  String toString() =>
      '$workItemId ($from -> ${to?.wire ?? 'unchanged'}): $reason';
}

/// One item a tick considered returning to its lane's entry state, and what it
/// did about it.
///
/// Reported for EVERY retry owed by a job in this lane, whether or not the
/// return happened — including the refusals. "The lane returned nothing" and
/// "the lane owed a retry and could not return the item" are different
/// operational facts, and only the second one is a problem: the item stays
/// stranded and its retry will be cancelled as superseded one tick later.
@immutable
class RetryReturnMove {
  const RetryReturnMove({
    required this.workItemId,
    required this.jobId,
    required this.from,
    this.to,
    required this.reason,
  });

  final String workItemId;

  /// The job whose retry is being honoured. Named so an operator reading a
  /// refusal can find the job whose budget is about to be wasted.
  final String jobId;

  /// The state the item was read in — `agentFailed` for an ordinary role, or
  /// `reviewInProgress` for the engineering reviewer, which the coordinator
  /// deliberately leaves alone.
  final WorkItemState from;

  /// Where the item was moved, or `null` when nothing was moved.
  final WorkItemState? to;

  /// The operator-facing reason. Never a credential.
  final String reason;

  bool get returned => to != null && to != from;

  @override
  String toString() =>
      '$workItemId ($from -> ${to?.wire ?? 'unchanged'}) retry $jobId: $reason';
}

/// What one `Scheduler.tick` did, for tests and for the audit tail.
@immutable
class SchedulerTickResult {
  const SchedulerTickResult({
    required this.reconciled,
    required this.enqueued,
    required this.dispatched,
    required this.cancelledQueued,
    required this.deferred,
    required this.terminal,

    /// Defaults to empty so every existing construction site keeps compiling —
    /// adding a diagnostic must not force callers to know about it.
    this.reconcileFailed = const [],

    /// Jobs this tick could not dispatch because their [WorkloadResolver]
    /// returned null. Defaults to empty for the same reason as
    /// [reconcileFailed]: this is a NEW diagnostic, and a scheduler without a
    /// resolver never produces it.
    this.blockedArtifactMissing = const [],

    /// Items the workflow policy called `runnable` that the scheduler could not
    /// make startable — no declared hop, a declared hop the policy will not let
    /// the scheduler take, or a dispatch discriminator on the item that could
    /// not be read, so no dedupe key could be built. Reported apart from
    /// [deferred] because nothing about it resolves itself: the item is not
    /// back-pressured, it is parked against a route the transition table does
    /// not offer or against bytes nothing can read, and an operator is the only
    /// one who can change that. Folding it into [deferred] would report a
    /// permanent structural gap as ordinary transient noise, which is how this
    /// whole defect stayed invisible.
    this.entryHopRefused = const [],

    /// Items this lane's completion inflow considered, and what it did with
    /// each. Empty for every definition that declares no inflow, which is every
    /// definition except the implementation lane.
    ///
    /// Reported rather than folded into any existing channel because none of
    /// them means this: `deferred` is back-pressure, `entryHopRefused` is a
    /// structural gap, and `blockedArtifactMissing` is "there is nothing to
    /// operate on". A route that moved nothing is none of those, and the case
    /// an operator most needs to see — the inflow considered items and moved
    /// none of them — would otherwise be indistinguishable from a lane that
    /// never looked.
    this.completionInflow = const [],

    /// Retryable failures whose work item this tick returned to the lane's
    /// entry state — and the ones it could not.
    ///
    /// Its own channel because none of the others means this. `deferred` is
    /// back-pressure on a job that is wanted; `cancelledQueued` is a job
    /// WITHDRAWN because its item no longer wants it, which is the very thing
    /// this pass exists to prevent; `entryHopRefused` is a structural gap on a
    /// runnable item. A return that happened is the operational proof that
    /// `maxAttempts` is real, and a refusal is the operational proof that a
    /// retry is still being thrown away — which is invisible today and was the
    /// whole reason this defect could sit in the catalogue as background noise
    /// for an entire project.
    ///
    /// NOT folded into `cancelledQueued`, and deliberately not part of the
    /// tick drain's `dispatched ∪ terminal ∪ reconciled` union: the job this
    /// names is not terminal, so a drain would skip it, and a return is not an
    /// outcome to consume.
    this.retryReturned = const [],

    /// Items this lane refused to launch work for because it has already
    /// stopped for them. Defaults to empty for the same reason as every other
    /// diagnostic here: this is a NEW channel, and a lane with no stall in it
    /// must keep compiling and keep passing without knowing it exists.
    this.stalled = const [],
  });

  final List<String> reconciled;

  /// Jobs this tick tried and FAILED to reconcile, with the reason.
  ///
  /// A row can fail to reconcile while the tick itself succeeds: a concurrent
  /// writer keeps winning the work-item compare-and-swap, or the store faults.
  /// The per-row guard stops that from aborting the tick, which means without
  /// this list such a failure would be invisible — the tick would report
  /// success, dispatch fresh work, and silently leak reclaim capacity forever.
  ///
  /// Named and counted rather than folded into [reconciled], because "this row
  /// was not reconciled" is the one fact an operator has to act on and it is
  /// exactly what a quiet log would otherwise hide.
  final List<ReconcileFailure> reconcileFailed;
  final List<String> enqueued;
  final List<String> dispatched;
  final List<String> cancelledQueued;
  final List<String> deferred;
  final List<String> terminal;

  /// Jobs this tick could not dispatch because their [WorkloadResolver]
  /// returned null — no artifact to operate on. Named and reported apart from
  /// [deferred] because "there is nothing to review" is a FAIL-CLOSED signal
  /// the composition root must act on (raise a blocking human decision), not
  /// ordinary transient back-pressure to retry silently.
  final List<String> blockedArtifactMissing;

  /// Items the scheduler refused to start this tick — by [EntryHopper], or by
  /// the dedupe-key build — with the reason.
  final List<EntryHopRefusal> entryHopRefused;

  /// Items the completion inflow considered this tick, in item-id order. See
  /// the field's declaration for why this is its own channel.
  final List<CompletionInflowMove> completionInflow;

  /// Retryable failures considered for a return to this lane's entry state this
  /// tick. See the constructor's declaration for why this is its own channel.
  final List<RetryReturnMove> retryReturned;

  /// Items this lane has STOPPED producing work for, and why.
  ///
  /// Its own channel because nothing else means this. `deferred` is
  /// back-pressure on a job that is wanted and will be dispatched; `cancelled`
  /// is a job withdrawn; `entryHopRefused` is a structural gap on a runnable
  /// item. A stall is none of those: the item is runnable, the lane understands
  /// why, and it has declined to launch again until a human says so. Reporting
  /// it is the whole difference between a conclusion the platform reached and a
  /// conclusion it discarded — before this channel existed, the identical fact
  /// was written to `scheduler_event.payloadJson` and read by nobody, while the
  /// item's state said `agent_completed` and every operator screen called it
  /// "Awaiting review".
  final List<SchedulerStall> stalled;
}

/// One work item this lane has stopped producing jobs for, and the reason an
/// operator has to act on.
///
/// ## WHAT A STALL IS, AND WHY IT IS NOT A WORKFLOW STATE
///
/// The item is at a state this lane dispatches from, and the item cannot be
/// moved: its only route out is an edge whose guard cannot be satisfied, so
/// there is no legal transition to park it on and nothing this lane may write.
/// A "terminal" workflow state is therefore not available as a stop — not
/// because it is unwise here, but because the graph does not offer one. What IS
/// available is the only lever that actually stops the bleeding, which is the
/// PRODUCER: refusing to mint.
///
/// That is the property this type stands for. A test that only asserts the
/// item's final state passes while the churn continues, because the item is
/// `agent_completed` both while the lane spins and while it does not. The only
/// thing that distinguishes them is the number of jobs that exist.
///
/// ## WHY IT IS NOT A PERMANENT DEAD END
///
/// A stall is lifted by either of two durable facts, and both are checked
/// rather than remembered:
///
///  1. the work item MOVES — `WorkItem.version` is the durable counter of real
///     moves, so a version above the one recorded when the stall was raised
///     means somebody or something genuinely progressed this item and the
///     recorded diagnosis is stale; or
///  2. an operator says the cause is fixed, which is a write to the work item
///     and therefore also moves its version.
///
/// So the stall expires on evidence, and "evidence" here is one monotone
/// counter rather than a flag somebody has to remember to clear.
@immutable
class SchedulerStall {
  const SchedulerStall({
    required this.workItemId,
    required this.state,
    required this.jobType,
    required this.deferrals,
    required this.reason,
  });

  final String workItemId;

  /// The durable state the item was in when the stall was raised, read from
  /// the item rather than assumed.
  final WorkItemState state;

  /// This lane's [JobType]. A stall is scoped to the lane that raised it: two
  /// schedulers share one [JobStore], and one lane's refusal to launch is not
  /// another lane's business.
  final JobType jobType;

  /// How many supersession deferrals this item had burned across every job it
  /// has held when the cap fired. Carried so the operator surface can say "3 of
  /// 3" rather than only "3".
  final int deferrals;

  /// Operator-facing, in one sentence, saying what to do. Never a credential.
  final String reason;

  @override
  String toString() =>
      '$workItemId ($state, ${jobType.wire}) stalled after $deferrals '
      'supersession deferrals: $reason';
}

/// The durable scheduler: derivation + enqueue + dispatch + outcome adoption
/// for ONE job type (this slice implements feature implementation). It asks
/// worker_runtime for placement and worker selection, workflow_engine for
/// legal-execution policy, and workflow_store for work item state. It defines
/// no workflow transition and starts no execution on its own.
class Scheduler {
  Scheduler({
    required String schedulerId,
    required WorkflowStore workflowStore,
    required JobStore jobStore,
    required WorkerStore workerStore,
    required WorkerDispatch dispatch,
    required JobDefinition definition,
    required SchedulerWorkload workload,
    DateTime Function()? clock,
    this.claimLease = const Duration(minutes: 10),
    ExecutionLivenessProbe? executionLiveness,
    Duration? zombieStalenessAfter,
    WorkflowEngine? policy,
    ModelSelectionService? modelSelection,
    DedupeKeyBuilder? dedupeKeyBuilder,
    InstructionBuilder? instructionBuilder,
    RequestBuilder? requestBuilder,
    WorkloadResolver? workloadResolver,
    ProviderHealthMonitor? providerHealthMonitor,
    this.capacityGuard,
  }) : schedulerId = schedulerId,
       _workflowStore = workflowStore,
       _jobStore = jobStore,
       _workerStore = workerStore,
       _dispatch = dispatch,
       _definition = definition,
       _workload = workload,
       _clock = clock ?? DateTime.now,
       // ONE policy object behind every question this scheduler asks of the
       // workflow graph, and the answer to "may the scheduler take this
       // transition" itself. `_evaluator`, `_reclaimEngine` and
       // `_returnRetryableItemsToEntryStates` all consult THIS instance, so a
       // reclaim, an entry hop and a retry return cannot disagree about which
       // edges exist. Named as a field rather than left as two inline
       // `policy ?? const WorkflowEngine()` expressions because the third
       // reader arrived with this change and three separate constructions of
       // "the policy" is three chances to drift.
       _policy = policy ?? const WorkflowEngine(),
       _evaluator = RunnableWorkEvaluator(
         policy: policy ?? const WorkflowEngine(),
       ),
       // Built over the store this scheduler already reads work items from, and
       // over the SAME policy object `RunnableWorkEvaluator` uses, so a reclaim
       // cannot decide an edge that scheduling would consider illegal.
       //
       // Present because a reclaim has to move the work item, not just the job.
       // It exists ONLY for that; the scheduler otherwise never writes workflow
       // state, and `policy` stays the optional injection it always was.
       _reclaimEngine = DurableWorkflowEngine(
         store: workflowStore,
         policy: policy,
       ),
       // The second component that has to move a work item, for the same reason
       // and over the same policy: an entry state whose route to execution is
       // not a direct edge is dispatched only after the hop the DEFINITION
       // declares for it has been taken. Built over the same store, the same
       // policy object and the same actor as everything else this scheduler
       // writes, so there is one store, one policy and one actor behind every
       // workflow write it makes. Assigned in the BODY because it is built over
       // `_reclaimEngine`, which this initializer list has just finished making.
       _queue = JobQueue(store: jobStore, clock: clock),
       _dedupeKeyBuilder = dedupeKeyBuilder ?? _defaultDedupeKey,
       _instructionBuilder = instructionBuilder ?? _defaultInstruction,
       _modelSelection = modelSelection,
       _requestBuilder = requestBuilder ?? _defaultRequest,
       _workloadResolver = workloadResolver,
       _executionLiveness = executionLiveness,
       _configuredZombieStaleness = zombieStalenessAfter,
       _providerHealthMonitor = providerHealthMonitor {
    _entryHopper = EntryHopper(
      policy: policy ?? const WorkflowEngine(),
      engine: _reclaimEngine,
      definition: definition,
    );
  }

  final String schedulerId;
  final Duration claimLease;

  final WorkflowStore _workflowStore;
  final JobStore _jobStore;
  final WorkerStore _workerStore;
  final WorkerDispatch _dispatch;
  final JobDefinition _definition;
  final SchedulerWorkload _workload;
  final DateTime Function() _clock;
  final RunnableWorkEvaluator _evaluator;
  final DurableWorkflowEngine _reclaimEngine;

  /// The single workflow policy this scheduler consults. See the constructor
  /// for why it is one named instance rather than three inline constructions.
  final WorkflowEngine _policy;

  /// Performs the intermediate hop an entry state declares when it cannot
  /// reach this definition's running state in one edge. See
  /// [EntryHopper] for why this is the scheduler's job and not the
  /// coordinator's.
  late final EntryHopper _entryHopper;

  /// How many times a reclaim re-reads the work item and retries after losing
  /// the store's compare-and-swap. Bounded on purpose: a reclaim must converge
  /// against ordinary contention without spinning against a writer that is
  /// rewriting the item continuously.
  static const int _maxReclaimAttempts = 3;

  /// The actor a reclaim transitions as. [ActorType.orchestrator] is what the
  /// `agentExecuting -> agentFailed` edge permits, and it is what the scheduler
  /// already acts as everywhere else in the transition graph — including the
  /// intermediate hop it takes in [EntryHopper], which is the SAME constant so
  /// two scheduler writes cannot disagree about who the scheduler is.
  static const WorkflowActor _reclaimActor = schedulerOrchestratorActor;
  final JobQueue _queue;
  final RetryPolicy _retryPolicy = const RetryPolicy();
  final DedupeKeyBuilder _dedupeKeyBuilder;
  final InstructionBuilder _instructionBuilder;
  final ModelSelectionService? _modelSelection;
  final RequestBuilder _requestBuilder;

  /// Resolves a job's workload per work item. Null means this scheduler uses
  /// the construction-time [_workload] for every job.
  final WorkloadResolver? _workloadResolver;
  final ProviderHealthMonitor? _providerHealthMonitor;

  /// Observes whether the process behind a non-terminal execution is alive.
  /// Null means this scheduler has no way to observe it, which is itself a
  /// visible state rather than a silent default: reconciliation then falls back
  /// to the [zombieStalenessBound] window instead of renewing forever.
  final ExecutionLivenessProbe? _executionLiveness;

  final Duration? _configuredZombieStaleness;

  /// The longest a non-terminal execution may go unobserved before it is
  /// reclaimed. This is the bound that turns "fail open" into "fail open, but
  /// not forever" - the difference between protecting live work and the
  /// indefinite renewal that let a zombie outlive its lease for hours.
  Duration get zombieStalenessBound {
    final configured = _configuredZombieStaleness;
    if (configured != null) return configured;
    // A worker execution legitimately outlasts its agent only by the work
    // around it: workspace preparation, the coordinator's independent
    // verification, and cleanup. Four agent budgets plus one claim lease is far
    // beyond any honest execution and far below a multi-hour stall.
    return Duration(seconds: _workload.timeoutSeconds * 4) + claimLease;
  }

  /// One line for a startup log naming the liveness policy in force. A
  /// scheduler that cannot observe liveness must say so, because the
  /// diagnostic is otherwise invisible.
  String get livenessSummary => _executionLiveness == null
      ? 'execution liveness NOT observable from this scheduler: a '
            'non-terminal execution is renewed until it has been non-terminal '
            'for ${zombieStalenessBound.inMinutes}m, then reclaimed.'
      : 'execution liveness observable; a non-terminal execution proven dead is '
            'reclaimed, and one unobservable past ${zombieStalenessBound.inMinutes}m '
            'is reclaimed.';

  /// The global execution-capacity budget, enforced at claim time. Null means
  /// this scheduler is UNBOUNDED, and that is a deliberate, visible state
  /// rather than a default:
  ///
  ///  * the cap is required configuration
  ///    ([ExecutionCapacityResolution.fromEnvironment] resolves nothing when
  ///    the environment variable is absent or unusable, so an unbounded
  ///    scheduler cannot be produced by accident from a missing value);
  ///  * the composition root owns wiring it, and [capacitySummary] is meant to
  ///    be surfaced in the startup log so an operator can see which of the two
  ///    states a running process is in.
  ///
  /// A process running with a null guard has no bound on concurrent agent
  /// executions beyond whatever the worker registry happens to enforce.
  final JobCapacityGuard? capacityGuard;

  /// One line describing the capacity policy actually in force, for a startup
  /// log. Never omits the fact that a cap is missing — the failure this guards
  /// against is invisible, so the diagnostic has to carry it.
  String get capacitySummary => capacityGuard == null
      ? 'execution capacity NOT configured: this scheduler is UNBOUNDED and '
            'will dispatch as many agent executions as the queue offers. Set '
            '$executionCapacityEnvVar and inject a capacity guard before '
            'starting the scheduler.'
      : capacityGuard!.capacity.startupSummary;

  JobQueue get queue => _queue;

  static String _defaultDedupeKey(WorkItem item, JobDefinition definition) =>
      '${item.workItemId}:${item.state.wire}:${definition.jobType.wire}:'
      '${definition.requiredRole.wire}';

  static String _defaultInstruction(WorkItem item, JobDefinition definition) =>
      'Implement "${item.title}" (${item.workItemId}) inside the worktree.';

  static Future<WorkerExecutionRequest> _defaultRequest(
    Job job,
    SchedulerWorkload workload,
    WorkItem item,
    ModelSelectionService? modelSelection,
  ) async {
    final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
    return WorkerExecutionRequest(
      workerExecutionId: 'wx-${job.jobId}',
      workItemId: job.workItemId,
      repositoryPath: workload.repositoryPath,
      startingRevision: workload.startingRevision,
      requiredCapabilities: job.requiredCapabilities,
      role: job.requiredRole,
      instruction: job.instruction,
      timeoutSeconds: workload.timeoutSeconds,
      runtimeTypeId: workload.runtimeTypeId,
      cleanupPolicy: workload.cleanupPolicy,
      runtimeConfig: runtimeConfig,
    );
  }

  /// One full, synchronous pass over the durable state. Deterministic:
  /// ordering is fixed, the process is event-loop serialized, and every step
  /// re-reads the store so re-entrant or interleaved ticks behave identically.
  Future<SchedulerTickResult> tick() async {
    final now = _clock().toUtc();
    final reconciled = <String>[];
    final reconcileFailed = <ReconcileFailure>[];
    final enqueued = <String>[];
    final dispatched = <String>[];
    final cancelledQueued = <String>[];
    final deferred = <String>[];
    final terminal = <String>[];
    final blockedArtifactMissing = <String>[];
    final entryHopRefused = <EntryHopRefusal>[];
    final completionInflow = <CompletionInflowMove>[];

    // 1. Recover claims that outlived their lease without ever persisting a
    //    terminal outcome.
    //
    //    Each row is reconciled inside its own guard. One unreconcilable row —
    //    a concurrent writer, a transient store fault — must not abort the loop
    //    and starve every OTHER expired claim behind it. This is defence in
    //    depth, NOT a substitute for handling failures at their source: the
    //    reclaim path catches its own rejection signals, and a test asserts that
    //    it does so without relying on this guard.
    //
    //    A row that throws is deliberately NOT added to `reconciled`: it did not
    //    reconcile. Its claim is still held and still expired, so the next tick
    //    picks it up again — the failure is a delay, never a loss.
    for (final job in await _jobStore.listJobs()) {
      final isHeld =
          job.state == JobState.claimed || job.state == JobState.running;
      if (!isHeld) continue;
      final claim = await _jobStore.readClaimForJob(job.jobId);
      final expired = claim == null || claim.isExpiredAt(now);
      if (!expired) continue;
      try {
        await _reconcileClaim(job, claim, now);
        reconciled.add(job.jobId);
      } catch (e) {
        // Swallowed so the remaining rows still reconcile — but NOT silently.
        // This tick result is the scheduler's only channel outward, so the row
        // is reported here and the composition root is expected to log it; a
        // failure that reaches nobody would leave a worker-store fault looking
        // exactly like a healthy tick while reclaim capacity leaked forever.
        //
        // The job is deliberately absent from `reconciled` as well: it did not
        // reconcile. Its claim is still held and still expired, so the next tick
        // retries it — the failure is a delay, never a loss.
        reconcileFailed.add(ReconcileFailure(jobId: job.jobId, error: '$e'));
        continue;
      }
    }

    // 2. COMPLETION INFLOW. Before anything asks what is RUNNABLE, this lane
    //    routes the items it shares with another lane.
    //
    //    It runs first on purpose. A work item routed here must be RE-READ
    //    before the runnability probe runs, or the probe would classify it by
    //    the state it was in a moment ago and this lane would dispatch nothing
    //    until the next tick — a one-tick delay on every item, forever, for a
    //    definition that declares an inflow. `items` is therefore re-read below
    //    when anything moved, and `var` for exactly that reason.
    //
    //    Absent declaration = absent work. Every definition except the
    //    implementation lane has `completionInflowFrom == null`, and the whole
    //    block is skipped without touching the store, so no other lane's tick
    //    changes by one read.
    var items = await _workflowStore.readAllWorkItems();
    if (_definition.hasCompletionInflow) {
      completionInflow.addAll(await _runCompletionInflow(items));
      if (completionInflow.isNotEmpty) {
        items = await _workflowStore.readAllWorkItems();
      }
    }

    // 2.5 RETRY RETURN. A retryable failure left this item OUTSIDE this lane's
    //     entry states, and the retry it is owed can therefore never be
    //     claimed. Put the item back, before anything asks what is runnable.
    //
    //     It runs HERE, after the completion inflow and before the runnability
    //     map, for the same structural reason the inflow does: step 3 classifies
    //     from a snapshot, and step 4's `noAction` branch is what
    //     CANCELS a retry. A return performed after step 3 would be read by
    //     nothing, and the item would be retired as superseded by the very tick
    //     that returned it. So `items` is re-read below whenever anything moved,
    //     and `var` for exactly that reason.
    final retryReturned = await _returnRetriableItemsToEntryStates(items);
    if (retryReturned.any((move) => move.returned)) {
      items = await _workflowStore.readAllWorkItems();
    }

    // 3. Ask the WORKFLOW POLICY what it may schedule for every item. Never a
    //    local reconstruction of the transition graph.
    items.sort((a, b) => a.workItemId.compareTo(b.workItemId));
    final byId = {for (final i in items) i.workItemId: i};
    final statusOf = {
      for (final i in items) i.workItemId: _evaluator.evaluate(i, _definition),
    };

    // 3.5 STALLS. Derived once, from durable job state, before step 4 asks
    //     this lane to produce anything.
    //
    //     It has to run before step 4 because step 4 is the PRODUCER, and the
    //     producer is the thing that has to stop. The breaker in
    //     `_adoptSupersession` ends a job; a cancelled job yields its dedupe
    //     key; and a key with no holder is an invitation to mint. Stopping the
    //     job and stopping the producer are different acts, and only the
    //     second one ends a loop.
    final stalls = await _supersessionStalls(items);
    final stalled = <SchedulerStall>[];

    // 4. Terminal items: cancel any residual queued jobs. Runnable items:
    //    enqueue the missing job idempotently. No-action items: RETIRE the jobs
    //    they superseded. Blocked items: leave every existing job untouched
    //    (never cancelled, never dispatched) — a blocking gate is a pause the
    //    work is expected to come back from.
    for (final item in items) {
      final status = statusOf[item.workItemId]!;
      switch (status) {
        case RunnableWorkStatus.terminal:
          final cancelled = await _cancelQueuedForItem(
            item.workItemId,
            reason: 'work item is ${item.state.wire}',
          );
          cancelledQueued.addAll(cancelled);
        case RunnableWorkStatus.noAction:
          // An item that has left this definition's entry states SUPERSEDES the
          // jobs that were queued for it. Retiring them here — rather than
          // letting the dispatch pass skip them forever — is what keeps a stale
          // job from lingering as an inert row nobody can explain.
          final retired = await _retireSupersededForItem(item);
          cancelledQueued.addAll(retired);
        case RunnableWorkStatus.blocked:
          // Deliberately NOT retired. `blocked` means `waitingForHumanDecision`,
          // which is a PAUSE that consumes no capacity and is expected to
          // resolve back into an entry state — so a queued job here is work the
          // platform still wants and intends to run. Cancelling it would destroy
          // legitimate queued work. An item that resolves somewhere this
          // definition cannot run is swept as `noAction` on a later tick, by
          // which time it has left `waitingForHumanDecision`.
          break;
        case RunnableWorkStatus.runnable:
          // THE STALL GATE, and it is first for a reason: it must be checked
          // before the entry hop, because the hop is a WRITE. An item this lane
          // has already stopped for gets no hop taken on its behalf, no key
          // built, and above all no job minted.
          //
          // Placing it here rather than inside `RunnableWorkEvaluator` is what
          // keeps the two concerns apart. The evaluator answers "may work start
          // from this state", a question about the workflow graph that every
          // item and every tick must get the same answer to. A stall is a
          // statement about THIS LANE'S HISTORY WITH THIS ITEM, derived from the
          // job store, and folding it into the evaluator would make one lane's
          // queue history look like a property of the transition graph.
          final stall = stalls[item.workItemId];
          if (stall != null) {
            stalled.add(stall);
            // Anything this lane already had queued for the item is withdrawn
            // here rather than left to spin in step 5: the same reason, in the
            // same act. A job left `queued` behind a stall is the exact inert
            // row `_retireSupersededForItem` exists to prevent, and it would
            // also be the row a future reader mistakes for "this review is
            // pending".
            cancelledQueued.addAll(
              await _retireStalledJobsForItem(item, stall),
            );
            continue;
          }
          // An item can be runnable and still not STARTABLE: the probe may be
          // asking about a legal intermediate hop rather than about beginning
          // an execution right here. The hop is taken here — before the dedupe
          // key is built — so the key, the instruction and the job all describe
          // the state the work is actually in, and a job minted for the
          // pre-hop state can never be dispatched beside the one minted after
          // it. `EntryHopper` refuses rather than dispatching into the
          // coordinator's refusal, so a runnable-but-unstartable item is
          // reported rather than burned.
          final prepared = await _entryHopper.prepare(item);
          if (!prepared.dispatchable) {
            entryHopRefused.add(
              EntryHopRefusal(
                workItemId: item.workItemId,
                state: item.state.wire,
                reason: prepared.reason ?? 'not dispatchable',
              ),
            );
            continue;
          }
          final ready = prepared.item;

          // PER-ITEM ISOLATION AROUND THE DEDUPE-KEY BUILD.
          //
          // The key is the first thing this loop derives from the item's own
          // durable bytes, and a builder that DECODES those bytes throws by
          // design rather than guessing: `readTriageAttempt` raises
          // `FormatException` on a PRESENT-BUT-UNREADABLE `triageAttempt`, and
          // three wired builders call it — `triageDefectDedupeKey`,
          // `implementFeatureDedupeKey` and `engineeringReviewDedupeKey`.
          //
          // Unguarded, one corrupt marker on one work item propagated a
          // `FormatException` out of this loop, out of `tick`, and into the
          // composition root's `<lane>.tick.failed`. That is not one item
          // parked: the WHOLE tick result is lost with it, so every OTHER
          // runnable item this tick could have enqueued or dispatched is lost
          // too, and the next tick throws on the same item again — one bad byte
          // STARVES THE LANE for ever. For the review lane the blast radius is
          // the entire review path (the inflow cannot route a commit, so
          // `sched-review` is the only way an item ever reaches a reviewer —
          // `docs/engineering/learning/the-inflow-cannot-route-a-commit-so-review-is-the-only-path.md`),
          // and the throw happens BEFORE `blockedArtifactMissing` is populated,
          // so the fail-closed human gate never runs either. Same reader, same
          // unbounded shape as the one `_routeOneCompletion`'s guard already
          // closes for the completion inflow.
          //
          // AT THE CALL SITE, and not inside the builders: a builder that caught
          // its own fault would have to invent a key or return nothing, and
          // "no key" is indistinguishable from "already enqueued" to everything
          // downstream. Here the scheduler already knows exactly what a refusal
          // costs — nothing is enqueued, the item stays where it was, nothing
          // is consumed — so this is a refusal, not a guess.
          //
          // REPORTED ON `entryHopRefused`, which is already this loop's channel
          // for an item the policy called runnable and the scheduler refused to
          // dispatch, with a reason. Deliberately NOT `blockedArtifactMissing`:
          // that channel carries JOB ids, and no job exists — the key was never
          // built — so the composition root's `engineeringReviewMissingArtifact`
          // loop would have nothing to read. The cost of this choice is stated
          // rather than hidden: for such an item the fail-closed HUMAN gate is
          // unreachable, and it parks itself at its entry state and re-reports
          // every tick until a human repairs the marker. Raising a decision for
          // it would need a new channel wired in `apps/server`, which is not
          // this lane's to change.
          //
          // DELIBERATELY NOT WIDER. The instruction builder beside it
          // interpolates the item's own fields and cannot throw by design, and
          // `_queue.enqueueIfAbsent` is a STORE WRITE whose faults must stay
          // loud: folding one in would turn a retryable store error into a
          // silent per-item refusal. Only the derivation that DECODES is guarded,
          // and this guard grows the day another builder decodes something else.
          late final String dedupeKey;
          try {
            dedupeKey = _dedupeKeyBuilder(ready, _definition);
          } on Object catch (error) {
            entryHopRefused.add(
              EntryHopRefusal(
                workItemId: ready.workItemId,
                state: ready.state.wire,
                reason:
                    'the dispatch discriminator on this item could not be '
                    'read, so no dedupe key could be built and no job was '
                    'enqueued for it ($error). Nothing ran and nothing was '
                    'consumed: it is left exactly where it was, and every other '
                    'work item this tick was still considered. Nothing about '
                    'this item changes on a later tick, so the same refusal is '
                    'reported again until the marker is repaired',
              ),
            );
            continue;
          }
          if (prepared.status == EntryHopStatus.performed) {
            cancelledQueued.addAll(
              await _retireJobsKeyedForPriorState(ready, dedupeKey),
            );
          }
          final instruction = _instructionBuilder(ready, _definition);
          final result = await _queue.enqueueIfAbsent(
            workItemId: ready.workItemId,
            definition: _definition,
            dedupeKey: dedupeKey,
            instruction: instruction,
            now: now,
          );
          if (result.created) enqueued.add(result.job.jobId);
      }
    }

    // 5-9. Dispatch every eligible job, in fixed order, at most ONE attempt per
    //      job per tick. Re-reading live state each round lets a job that
    //      completed during this tick free a capacity slot for the next one —
    //      and that slot is now a real, durable, counted one, released only by
    //      the job reaching a terminal state or being reclaimed.
    final attempted = <String>{};
    for (;;) {
      final eligible = (await _eligibleRunnableJobs(
        now,
        byId,
        statusOf,
      )).where((j) => !attempted.contains(j.jobId)).toList();
      if (eligible.isEmpty) break;
      for (final job in eligible) {
        // The stall gate again, at the point work would actually START.
        //
        // Step 4 already withdrew this lane's jobs for every stalled item, so
        // this arm is unreachable in a single-writer tick. It is here because
        // "unreachable today" is not a property: two schedulers share one
        // [JobStore], and a job minted for a stalled item by another process —
        // or by a tick that started before the stall landed — would otherwise
        // reach `_dispatchOne` and burn a real worker execution on work this
        // lane has already concluded it cannot start.
        final itemStall = stalls[job.workItemId];
        if (itemStall != null) {
          attempted.add(job.jobId);
          continue;
        }
        final outcome = await _dispatchOne(job, now);
        if (outcome.dispatched) {
          dispatched.add(job.jobId);
        } else if (outcome.terminalJob != null) {
          terminal.add(outcome.terminalJob!.jobId);
        } else if (outcome.blockedArtifactMissing) {
          // Checked BEFORE the queued/retryWaiting deferral below: a job whose
          // artifact could not be resolved is not ordinary back-pressure, it is
          // a fail-closed condition the composition root must turn into a
          // blocking human decision. Folding it into `deferred` would hide it.
          blockedArtifactMissing.add(job.jobId);
        } else if (outcome.capacityDenied) {
          // Refused a slot by the global capacity budget. Reported through the
          // SAME `deferred` channel as "no worker was free" because it is the
          // same situation: the job is still queued and still wanted. It is not
          // a failure, it is not terminal, and it is not dropped — the next
          // tick retries it against whatever capacity exists then.
          deferred.add(job.jobId);
        } else if (job.state == JobState.queued ||
            job.state == JobState.retryWaiting) {
          deferred.add(job.jobId);
        }
        if (outcome.dispatched || outcome.terminalJob != null) {
          attempted.add(job.jobId);
        } else if (!outcome.dispatched) {
          // Busy/no-worker/lost-claim/capacity-denied/placement failure: do not
          // spin on the same job within one tick; a later tick will retry it.
          attempted.add(job.jobId);
        }
      }
    }

    return SchedulerTickResult(
      reconciled: reconciled,
      reconcileFailed: reconcileFailed,
      enqueued: enqueued,
      dispatched: dispatched,
      cancelledQueued: cancelledQueued,
      deferred: deferred,
      terminal: terminal,
      blockedArtifactMissing: blockedArtifactMissing,
      entryHopRefused: entryHopRefused,
      completionInflow: completionInflow,
      retryReturned: retryReturned,
      stalled: stalled,
    );
  }

  /// The retry-return pass. Returns every retryable failure this lane owes a
  /// return for, and the ones it could not perform.
  ///
  /// ## THE DEFECT THIS EXISTS TO END
  ///
  /// Four links, all of which had to be true at once:
  ///
  ///  1. a retryable execution failure moves the work item OUT of its lane's
  ///     `entryStates` — `agentExecuting -> agentFailed` for every ordinary role,
  ///     and the coordinator leaves a reviewer at `reviewInProgress`;
  ///  2. `RunnableWorkEvaluator.evaluate` rejects any item outside
  ///     `entryStates` BEFORE it consults the retry policy or anything else;
  ///  3. so the next tick classifies the item `noAction`; and
  ///  4. `Scheduler._retireSupersededForItem` then CANCELS the retry that was
  ///     just scheduled — and `cancelledQueued` is not in the tick drain's
  ///     `dispatched ∪ terminal ∪ reconciled` union, so no operator signal was
  ///     raised either.
  ///
  /// The item was due, owned by nobody, and could never advance, in silence.
  /// No retry has ever run on any `Scheduler` lane, so every `maxAttempts` in
  /// this platform was unreachable for exactly the failures it exists for.
  ///
  /// ## WHY THE ITEM IS MOVED AND NOT THE JOB RELEASED
  ///
  /// The rejected alternative (option B of the decision) taught the scheduler
  /// to honour a retry for an item OUTSIDE `entryStates`. That leaves the work
  /// in a state no lane dispatches from — which is the invariant itself. The
  /// one-element entry sets are precisely what make the triage/implementation
  /// dispatch collision STRUCTURALLY UNREACHABLE, and an item parked outside
  /// every entry set reintroduces that collision by a different route. So this
  /// is a RETURN to a state that is already an entry state, and
  /// `_returnTargetFor` can only ever name one that is.
  ///
  /// ## WHY THE TARGET IS DERIVED FROM THE POLICY, NOT DECLARED
  ///
  /// `entryStates` may hold several states (triage holds three). There is no
  /// list here saying which one a retry returns to, because a list would be a
  /// second transcription of the transition graph — and the codebase's standing
  /// rule is "ask the policy, never a local copy of the graph"
  /// ([RunnableWorkEvaluator], [EntryHopper]). Instead this asks the POLICY
  /// which of its own entry states is reachable from the state the failure left
  /// behind, and proceeds only on a UNIQUE answer. Zero reachable and more than
  /// one reachable are both REFUSALS, reported with a reason.
  ///
  /// That is what makes the four edges in `work_item_transitions.dart`
  /// load-bearing in both directions: `agentFailed -> designApproved` and
  /// `agentFailed -> reviewRejected` are deliberately absent, because adding
  /// either would make triage's return ambiguous and silently disable the retry
  /// for every lane that dispatches from `agentFailed`.
  ///
  /// ## WHY A LANE ONLY EVER RETURNS ITS OWN JOBS
  ///
  /// Scoped to `job.jobType == _definition.jobType`, the same scoping
  /// `_retireSupersededForItem` already applies on the cancel side. Two
  /// schedulers share one `JobStore`, and a lane is only entitled to move a
  /// work item for its OWN job. The alternative is a cross-lane hijack waiting
  /// for one edge: the implementation lane's tick sees the review lane's
  /// `retryWaiting` job, and the moment an `reviewInProgress ->
  /// implementationReady` edge existed it would return a reviewer's item out
  /// from under it — reintroducing through the back door the very collision the
  /// disjoint entry sets exist to make unreachable.
  ///
  /// ## WHY THE JOB IS THE EVIDENCE, AND WHY IT IS ENOUGH
  ///
  /// Every condition below is read from durable state, and together they are a
  /// complete account: `JobState.retryWaiting` is written by exactly ONE
  /// method in this package — `JobQueue.scheduleRetry` — and `_adopt` calls
  /// that method only under [RetryPolicy.canRetry]. So a job in `retryWaiting`
  /// carrying a `transient` [JobFailure] already asserts, in the durable row
  /// itself, all three facts this pass needs: THIS lane dispatched an
  /// execution of THIS item, it failed on INFRASTRUCTURE rather than on its
  /// result, and the budget had room when the retry was offered. No local flag,
  /// no second guess and no re-derivation of the failure are involved.
  ///
  /// ## WHY `canRetry` IS **NOT** RE-CHECKED HERE
  ///
  /// It would refuse every retry, for an off-by-one that is worth stating
  /// exactly because it is so easy to reintroduce.
  ///
  /// `scheduleRetry` PRE-INCREMENTS: the moment the retry is scheduled the job
  /// already reads `attempt == 2` against `maxAttempts == 2`. So
  /// `canRetry(attempt: 2, maxAttempts: 2)` is `2 < 2`, i.e. false, for a
  /// retry that is perfectly live. `_adopt` calls `canRetry` BEFORE the
  /// increment, which is the only point at which it answers the right question.
  ///
  /// The budget is not thereby unbounded. The NEXT bound is applied where it
  /// belongs: when the retried execution settles, `_adopt` calls `canRetry`
  /// again against the then-current `attempt`, and a second transient failure
  /// completes the job terminally `failed`. That is what makes `maxAttempts`
  /// mean "exactly N executions, never N+1", and
  /// `test/retry_return_to_entry_state_test.dart` asserts the count of REAL
  /// executions rather than the state of the job row.
  ///
  /// ## WHY A PERMANENT FAILURE NEVER COMES HERE
  ///
  /// `Scheduler._adopt` settles a permanent failure terminally `failed`, so it
  /// never reaches `retryWaiting` and this pass never sees it: the item stays
  /// where the failure put it and waits for a human. That is the whole point of
  /// keeping the failure classes distinct — a crash and a timeout still behave
  /// differently, and neither is made unconditional.
  ///
  /// ## WHY A HUMAN GATE IS NEVER TOUCHED
  ///
  /// An item parked at `waitingForHumanDecision` is a PAUSE that consumes no
  /// capacity and is expected to resolve back into an entry state. Returning a
  /// retryable item out of it would silently pre-empt a decision a human has not
  /// answered yet, so that state is refused explicitly — the one refusal here
  /// that is not a graph question.
  ///
  /// ## PER-ITEM ISOLATION
  ///
  /// A read fault or a rejected write on one item must not abort the pass: the
  /// remaining items are real work this lane can recover, and a throw here would
  /// escape `tick` and lose the WHOLE lane's tick result — every unrelated
  /// item's dispatch with it. Each item is guarded individually and every
  /// refusal is REPORTED on [SchedulerTickResult.retryReturned], never
  /// swallowed. An item that keeps refusing re-reports every tick, which is the
  /// intended signal: it is not going to fix itself.
  Future<List<RetryReturnMove>> _returnRetriableItemsToEntryStates(
    List<WorkItem> items,
  ) async {
    final owed = <(Job, WorkItem)>[];
    for (final job in await _jobStore.listJobs()) {
      // SCOPED TO THIS LANE'S JOB TYPE, and the reason is the same one
      // `_retireSupersededForItem` already enforces on the cancel side: two
      // schedulers share one `JobStore`, and a lane is only entitled to move
      // work items for ITS OWN jobs.
      //
      // Without this, the implementation lane's tick would see the REVIEW
      // lane's `retryWaiting` job and consider returning its item — and the
      // day someone added an `reviewInProgress -> implementationReady` edge to
      // make that possible, the implementation lane would hijack a reviewer's
      // retry and re-introduce, through the back door, the cross-lane collision
      // the disjoint entry sets exist to make unreachable. The review lane's
      // return belongs to the review lane, and the review lane is the only
      // component that knows `engineeringReviewDefinition`.
      if (job.jobType != _definition.jobType) continue;
      // `retryWaiting` is the queue's own name for "a retry is owed and its
      // delay has not elapsed yet". It is written by `JobQueue.scheduleRetry`
      // and by nothing else, so this is the one condition that says a retry
      // exists — not a reconstruction of what the failure was.
      if (job.state != JobState.retryWaiting) continue;
      final failure = job.failure;
      // `isRetryable` is `== transient` on the contract enum, so `cancelled` and
      // `permanent` are both excluded here by construction rather than by a
      // second list kept in step with the enum.
      if (failure == null || !failure.kind.isRetryable) continue;
      // `canRetry` is deliberately NOT re-checked here: `scheduleRetry`
      // pre-increments `attempt`, so it answers `2 < 2` — false — for a retry
      // that is perfectly live. See this method's doc for the full argument and
      // for why the next bound is applied where it belongs.
      final item = items
          .where((i) => i.workItemId == job.workItemId)
          .firstOrNull;
      if (item == null) continue;
      // The defect, stated as a condition: the item has LEFT this lane's entry
      // states, so nothing will claim the retry. An item still inside them needs
      // no return at all — the ordinary runnable branch already handles it.
      if (_definition.entryStates.contains(item.state)) continue;
      owed.add((job, item));
    }
    if (owed.isEmpty) return const [];

    owed.sort((a, b) {
      final byItem = a.$2.workItemId.compareTo(b.$2.workItemId);
      return byItem != 0 ? byItem : a.$1.jobId.compareTo(b.$1.jobId);
    });

    final moves = <RetryReturnMove>[];
    for (final (job, item) in owed) {
      moves.add(await _returnOneToEntryState(job, item));
    }
    return moves;
  }

  /// Returns one item, or reports why it was not returned.
  Future<RetryReturnMove> _returnOneToEntryState(Job job, WorkItem item) async {
    if (item.isTerminal) {
      return RetryReturnMove(
        workItemId: item.workItemId,
        jobId: job.jobId,
        from: item.state,
        reason:
            'work item ${item.workItemId} is ${item.state.wire}, which is '
            'terminal, so nothing owns it and no retry is owed. The retry on '
            'job ${job.jobId} will be retired as superseded, which is correct.',
      );
    }
    if (item.state == WorkItemState.waitingForHumanDecision) {
      return RetryReturnMove(
        workItemId: item.workItemId,
        jobId: job.jobId,
        from: item.state,
        reason:
            'work item ${item.workItemId} is parked at a blocking human '
            'decision. Returning it now would pre-empt a decision nobody has '
            'answered, so the retry on job ${job.jobId} is left alone until '
            'the gate resolves back into an entry state.',
      );
    }

    final reachable = _returnTargetsFrom(item.state);
    if (reachable.isEmpty) {
      return RetryReturnMove(
        workItemId: item.workItemId,
        jobId: job.jobId,
        from: item.state,
        reason:
            'a ${_definition.jobType.wire} execution failed transiently and job '
            '${job.jobId} is owed a retry, but the transition table offers no '
            'edge from ${item.state.wire} back into any '
            '${_definition.jobType.wire} entry state '
            '(${_entryStateWireList()}). Nothing is returned, so the next tick '
            'retires the retry as superseded and this item is stranded until a '
            'human acts on it. Adding that edge is the fix; adding an entry '
            'state would be the rejected alternative.',
      );
    }
    if (reachable.length > 1) {
      return RetryReturnMove(
        workItemId: item.workItemId,
        jobId: job.jobId,
        from: item.state,
        reason:
            'the transition table offers MORE THAN ONE '
            '${_definition.jobType.wire} entry state reachable from '
            '${item.state.wire} (${(reachable.map((s) => s.wire).toList()..sort()).join(', ')}), '
            'so which one this retry returns to is ambiguous and the scheduler '
            'will not guess. Job ${job.jobId} will be retired as superseded. '
            'Exactly one reachable entry state per lane is the invariant that '
            'makes this unambiguous.',
      );
    }

    final target = reachable.single;
    // `validate()` is asked about the transition BEFORE the write, for the same
    // reason `_routeOneCompletion` does: a refused write and an unaccepted
    // transition are the same fact, and the engine's verdict is cheaper and
    // more honest than discovering it from a thrown exception. The two agree by
    // construction — `DurableWorkflowEngine.transition` refuses anything
    // `validate` rejects — so this is a refusal with a readable reason, not a
    // second rule.
    final verdict = _policy.evaluateWorkItemTransition(
      from: item.state,
      to: target,
      trigger: TransitionTrigger.systemEvent,
      actor: _reclaimActor,
      // Empty on purpose, and NOT the
      // `{'agentAvailable': true, 'capabilitiesMatch': true}` the dispatch
      // probe uses. A return asserts no agent is starting — capacity is
      // `JobCapacityGuard`'s job — so supplying those keys would claim a fact
      // that is false at this moment and would quietly satisfy an
      // `agentAvailable()` guard that has no business being satisfied here.
      // An edge that needs evidence is therefore refused, which is the
      // conservative direction: this pass can only fail to return something a
      // human can fix, never return something it should not.
      context: const {},
    );
    if (!verdict.isValid) {
      return RetryReturnMove(
        workItemId: item.workItemId,
        jobId: job.jobId,
        from: item.state,
        reason:
            'the transition ${item.state.wire} -> ${target.wire} exists but the '
            'workflow policy will not let the scheduler take it in the '
            'scheduler\'s own context '
            '(${verdict.failedGuards.join(', ')}). Not returning: job '
            '${job.jobId} will be retired as superseded and this item will wait '
            'for a human.',
      );
    }

    try {
      final moved = await _reclaimEngine.transition(
        workItemId: item.workItemId,
        to: target,
        trigger: TransitionTrigger.systemEvent,
        actor: _reclaimActor,
        context: const {},
        reason:
            'job ${job.jobId} is owed a bounded retry after a transient '
            '${_definition.jobType.wire} execution failure '
            '(${job.failure?.code.name}), and the failure left this item at '
            '${item.state.wire}, outside every '
            '${_definition.jobType.wire} entry state, so no tick could ever '
            'claim it. Returning it to ${target.wire} — an existing entry '
            'state, not a widened one — so the scheduled retry runs for real.',
      );
      return RetryReturnMove(
        workItemId: item.workItemId,
        jobId: job.jobId,
        from: item.state,
        to: moved.state,
        reason:
            '${item.state.wire} -> ${moved.state.wire}: a transient failure '
            'owed a retry, and the item had left every entry state this lane '
            'dispatches from',
      );
    } on Object catch (error) {
      // Someone else owns the item now — a human, a gate, another tick. Not an
      // error: a delay, never a loss, and the next tick re-reads and decides
      // again from whatever state the item now holds.
      return RetryReturnMove(
        workItemId: item.workItemId,
        jobId: job.jobId,
        from: item.state,
        reason:
            'returning ${item.workItemId} to ${target.wire} was refused ($error) '
            '— another writer owns it, or the policy disagrees at write time. '
            'Nothing was moved and nothing was consumed; the next tick '
            're-reads and decides again.',
      );
    }
  }

  /// The entry states of this definition the POLICY says [from] may reach.
  ///
  /// Read from the policy rather than from a list, which is what makes the
  /// return target unambiguous-by-construction rather than unambiguous-by-
  /// convention: an edge added to `work_item_transitions.dart` that reaches a
  /// second entry state from the same failure state CHANGES this answer, and a
  /// second answer is a refusal.
  List<WorkItemState> _returnTargetsFrom(WorkItemState from) {
    final targets = <WorkItemState>[];
    for (final entry in _definition.entryStates) {
      final transition = _policy.evaluateWorkItemTransition(
        from: from,
        to: entry,
        trigger: TransitionTrigger.systemEvent,
        actor: _reclaimActor,
        context: const {},
      );
      if (transition.isValid) targets.add(entry);
    }
    // Sorted so the refusal reason above is stable across runs rather than
    // dependent on `entryStates` iteration order.
    targets.sort((a, b) => a.wire.compareTo(b.wire));
    return targets;
  }

  /// The entry states of this lane, as wire tokens, sorted — for operator-facing
  /// refusal reasons.
  String _entryStateWireList() {
    final wires = _definition.entryStates.map((s) => s.wire).toList()..sort();
    return wires.join(', ');
  }

  /// Routes each item this lane shares with another lane, once, before
  /// runnability is computed. Returns what it moved and what it refused.
  ///
  /// ## WHY IT IS HERE AND NOT IN A TICK HANDLER
  ///
  /// A handler would have to be registered by the composition root, and
  /// `agentCompleted` items are not visible to this lane at all: its
  /// `entryStates` is one element wide on purpose, so the runnability probe
  /// rejects every other state before the policy is consulted. Putting the
  /// route inside `tick` is what makes it live for a lane whose declaration is
  /// in the same file as its dispatch surface — a handler nobody wired would
  /// be a lane that looks wired and does nothing, which is the exact shape of
  /// the defect this whole change exists to close.
  ///
  /// ## WHY IT CANNOT STEAL AN ITEM THAT IS ALREADY BEING REVIEWED
  ///
  /// The discriminator is [producedCommitFor], and the engineering review
  /// gate's workload resolver CALLS that same function over the same durable
  /// rows — one rule, not two. If that resolver resolved a workload, the producer
  /// left a commit, and the route is `reviewInProgress` — which this lane does
  /// not move anything to. So "review dispatched" and "inflow routed to
  /// implementation" cannot both be true for one item, and a reviewer is never
  /// displaced by a route.
  ///
  /// ## AND WHY THE OTHER LANE MUST ALSO STAND DOWN
  ///
  /// Complementarity alone is not enough, because the two lanes run in ONE tick
  /// and the review lane's fail-closed handler can MOVE an item before this one
  /// ever looks at it. `engineeringReviewMissingArtifact` therefore defers to
  /// this lane for a no-artifact producer instead of parking the item at a human
  /// gate — see that file for the rule and
  /// `apps/server/test/implementation_inflow_tick_order_test.dart` for the
  /// proof that the outcome is the same in BOTH tick orders.
  ///
  /// ## PER-ITEM ISOLATION
  ///
  /// One item's fault must not abort the pass, because the remaining items are
  /// real work this lane can start. Each is guarded individually and a failure
  /// is REPORTED, never swallowed: an unreadable worker store — or an unreadable
  /// dispatch discriminator on one item — leaves that item where it was, and
  /// the operator can see it in the tick result rather than inferring it from a
  /// lane that looks idle. The guard covers EVERY per-item read, not only the
  /// one that was there when this comment was written: a read left outside it
  /// turns one bad byte on one work item into the loss of the whole lane's tick.
  Future<List<CompletionInflowMove>> _runCompletionInflow(
    List<WorkItem> items,
  ) async {
    final sources = _definition.completionInflowFrom!;
    // A lane that declares an inflow must be able to DISPATCH what the inflow
    // hands it. `agentCompleted` is deliberately not in this definition's
    // `entryStates` — that is the whole point — so the check is on the state the
    // route LANDS on, not on the state it comes from.
    //
    // `assert` and not a runtime guard, and the reason is worth stating exactly
    // rather than approximately: `assert` is a RUNTIME check that Dart strips
    // from AOT (production) builds. It is not a compile-time assertion, and a
    // reader who believes it is will not learn that a malformed definition
    // would ship. It is here because the mistake is a `const` definition edited
    // by hand, the failure would be immediate and total (the inflow hands work
    // to a lane nothing runs), and the check costs one comparison in JIT where
    // asserts are enabled.
    assert(
      _definition.entryStates.contains(
        completionRouteFor(
          const NoCommitProduced(
            NoProducedCommitReason.noCommitProduced,
            'assertion only; the value is never read',
          ),
        ),
      ),
      'a definition that declares a completion inflow must dispatch from the '
      'state the no-artifact route lands on, or the inflow hands work to a '
      'lane nothing runs',
    );
    final moves = <CompletionInflowMove>[];
    for (final item in items) {
      if (!sources.contains(item.state)) continue;
      final move = await _routeOneCompletion(item);
      if (move != null) moves.add(move);
    }
    return moves;
  }

  /// Routes one item, or returns why it was not routed.
  Future<CompletionInflowMove?> _routeOneCompletion(WorkItem item) async {
    final workerStore = _workerStore;
    final engine = _reclaimEngine;

    // BOTH reads are inside ONE guard, because they are the two things that
    // must be legible before this lane may move a work item at all, and either
    // one can throw by design. `producedCommitFor` throws when the worker store
    // is unreadable; `readTriageAttempt` throws `FormatException` on a
    // PRESENT-BUT-UNREADABLE discriminator, which is deliberate
    // (`DurableWorkflowEngine.readTriageAttempt` explains why falling back
    // would reuse a consumed dedupe key).
    //
    // With the discriminator read OUTSIDE this guard, one corrupt marker on one
    // work item propagated a `FormatException` out of `_runCompletionInflow`,
    // out of `tick`, and into the composition root's `implementation.tick.failed`
    // — which loses the WHOLE lane's tick result, including every unrelated
    // runnable `implementationReady` item that tick could have dispatched. The
    // blast radius of one bad byte was the lane, not this inflow. Per-item
    // isolation below is only true if every per-item read is inside it.
    //
    // `readTriageAttempt`'s RESULT IS DISCARDED, and that is load-bearing, not
    // a leftover. Nothing here compares the discriminator any more — the
    // automatic route is unbounded as of human decision
    // `92d567e3-da03-4c43-99f4-e3726472f0ab`. What is still load-bearing is the
    // THROW: this read is the only place in this method where an unreadable
    // marker is turned into "leave this one item alone" instead of "lose the
    // whole lane's tick", and `nextTriageAttempt` below reads the same marker
    // from outside this guard. Deleting the read would delete the isolation
    // with it. `implementation_completion_inflow_test.dart`, "an UNREADABLE
    // DISCRIMINATOR on one item does not abort the lane's tick", is the
    // executable statement of why it stays.
    late final ProducedCommit produced;
    try {
      produced = await producedCommitFor(workerStore, item);
      DurableWorkflowEngine.readTriageAttempt(item);
    } on Object catch (error) {
      return CompletionInflowMove(
        workItemId: item.workItemId,
        from: item.state,
        to: null,
        reason:
            'this item could not be read well enough to decide whether it '
            'should be reviewed or implemented ($error). Whether it was the '
            'producing execution\'s artifact or this item\'s dispatch '
            'discriminator that was illegible, the answer is the same: it was '
            'left where it is, nothing ran and nothing was consumed',
      );
    }

    final target = completionRouteFor(produced);

    // Nothing to do when the route is the state the item is already in. The
    // item got here BY a previous route, or by a human, and both are already
    // correct. Writing again would be an unrequested transition and would
    // advance the attempt counter for no reason.
    if (target == item.state) {
      return CompletionInflowMove(
        workItemId: item.workItemId,
        from: item.state,
        to: item.state,
        reason: 'already routed: $produced',
      );
    }

    // NO BOUND HERE, AND THE ABSENCE IS THE POINT.
    //
    // This used to read
    //
    //     if (_definition.entryStates.contains(target) &&
    //         reWorkAttempt >= maxImplementationInflows) { …refuse… }
    //
    // on the SHARED re-work discriminator (`DurableWorkflowEngine
    // .triageAttemptMetadataKey`), and refuse to route anything whose marker
    // read 3 or more. Human decision `92d567e3-da03-4c43-99f4-e3726472f0ab`,
    // option `RETRY_LIMIT` = `REMOVE`, removed it: the operator's rule is that a
    // retry limit is justified only for work a MACHINE retries, and the human
    // limit is already uncounted (`SHIPIT_OPERATOR_MAX_RETRIES`).
    //
    // The discriminator was the wrong counter for it. The operator retry and a
    // resolved rework/reject decision advance that same marker, so an item that
    // entered this lane ZERO times could already read `3` because a person had
    // pressed retry three times — and the bound spent its budget refusing that
    // person's work. On live QA that stranded four defects at `agentCompleted`
    // with the marker reading 3 and 4: refused here, refused again by the review
    // lane's fail-closed handler, owned by nobody.
    //
    // The loop the bound existed to catch is broken upstream instead, and the
    // break is in a DIFFERENT PACKAGE, which is the reason for the merge order.
    // `agentCompleted -> implementationReady -> agentExecuting ->
    // agentCompleted` has an implementer step in it only while an implementer
    // that produced nothing can reach `agentCompleted`. It cannot any more:
    // `packages/execution_coordinator` classifies a no-output implementation as
    // a PERMANENT job failure, so the run stays at `agentFailed` for a human and
    // never stamps a `producerActorId` that this inflow could route. A TRIAGE
    // run still arrives here having committed nothing — that is the route's
    // whole purpose — but it commits nothing once per pass and the next pass is
    // an implementation, which either commits or fails permanently.
    //
    // **THIS LANE MUST NOT MERGE BEFORE THAT ONE.** Merged alone, this removes
    // the only brake on that cycle.
    //
    // What this method still refuses, and why the absence is not an absence of
    // guards: a transition the policy rejects throws below and is reported as
    // "the item moved while this lane was reading it" — the review route, which
    // carries `GuardConditions.agentResultValid()`, is refused by the transitions
    // table exactly as before. That guard is the review route's own and is not
    // this method's to weaken; see `implementationInflow.dart` for why the commit
    // route is currently unsatisfiable (design decision F-04, owned by the
    // coordinator, not by this lane).

    // ONE arithmetic rule for every writer of this counter
    // (`DurableWorkflowEngine.nextTriageAttempt`), not `attempt + 1` spelled
    // out here. That function is the documented single rule precisely so a
    // third writer cannot derive the number a different way — see
    // `implementFeatureDedupeKey`, which reads the same counter back to build
    // the key this very write will be dispatched under.
    final nextAttempt = DurableWorkflowEngine.nextTriageAttempt(item);
    try {
      await engine.transition(
        workItemId: item.workItemId,
        to: target,
        trigger: TransitionTrigger.systemEvent,
        actor: _reclaimActor,
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
        // Idempotent per PRODUCER, not per tick: re-running this after a
        // partial write returns the accepted outcome instead of moving the
        // item a second time. A producer execution completes once, so the key
        // can never be reused for a genuinely new piece of evidence.
        idempotencyKey:
            'completion-inflow-${item.workItemId}-'
            '${item.metadata?['producerActorId'] ?? 'no-producer'}',
        // WRITTEN INTO THE DURABLE TRANSITION RECORD, so it has to be true for
        // whichever route was taken. It used to be one string written for the
        // no-artifact case and used for both, so a rejected commit route left a
        // permanent audit row asserting "the producer ... left no implementation
        // artifact ... so there is nothing to review and the item is routed into
        // the implementation lane" — about an item whose producer had committed,
        // on a route to `reviewInProgress`. An operator reading the history of
        // this item would have been told the exact opposite of what happened.
        //
        // Two branches rather than one interpolated sentence, for the same
        // reason `completionRouteFor` is a `switch` and not an inline `if`: the
        // asymmetry between the two verdicts is the whole safety argument, and a
        // single string with a hole in it is where the asymmetry silently
        // becomes a lie.
        reason: switch (produced) {
          CommitProduced() =>
            'the producer of ${item.workItemId} left an implementation '
                'artifact ($produced), so the item is routed to '
                '${target.wire} for engineering review',
          NoCommitProduced() =>
            'the producer of ${item.workItemId} left no implementation '
                'artifact ($produced), so there is nothing to review and the '
                'item is routed to ${target.wire}',
        },
        // Same transaction as the move, through the engine's own merge: the
        // dedupe key this route will be dispatched under is computed from this
        // marker, so a crash between the two would strand the item at a
        // dispatchable state with a consumed key — the inert item, exactly.
        metadataMerge: {
          DurableWorkflowEngine.triageAttemptMetadataKey: nextAttempt,
        },
      );
      return CompletionInflowMove(
        workItemId: item.workItemId,
        from: item.state,
        to: target,
        reason:
            'routed to ${target.wire}: $produced. Dispatch discriminator '
            'advanced to a$nextAttempt',
      );
    } on WorkflowTransitionRejectedException catch (error) {
      // Someone else owns the item now — a human, a gate, another tick. Not an
      // error here: the next tick re-reads and decides again.
      return CompletionInflowMove(
        workItemId: item.workItemId,
        from: item.state,
        to: null,
        reason:
            'the item moved while this lane was reading it ($error), so no '
            'route was taken. Nothing ran and nothing was consumed',
      );
    } on ConcurrentModificationException {
      return CompletionInflowMove(
        workItemId: item.workItemId,
        from: item.state,
        to: null,
        reason:
            'another writer took the work item while this lane was routing it, '
            'so no route was taken. Nothing ran and nothing was consumed',
      );
    }
  }

  Future<List<Job>> _eligibleRunnableJobs(
    DateTime now,
    Map<String, WorkItem> byId,
    Map<String, RunnableWorkStatus> statusOf,
  ) async {
    final candidates = <Job>[];
    for (final job in await _jobStore.listJobs()) {
      if (!_queue.isEligibleAt(job, now)) continue;
      final item = byId[job.workItemId];
      if (item == null ||
          statusOf[job.workItemId] != RunnableWorkStatus.runnable) {
        continue;
      }
      // Check if all providers for this job's role are down.
      if (_providerHealthMonitor != null &&
          _providerHealthMonitor.hasAllProvidersDown(
            _definition.requiredRole,
          )) {
        // Skip dispatch - log and defer
        continue;
      }
      // Re-validate legality against today's item state at claim time so a
      // human decision that landed between enqueue and dispatch cannot slip
      // through.
      //
      // This `continue` is a dispatch-time guard on the SNAPSHOT taken in step
      // 3, not the mechanism that retires a superseded job: step 3's
      // `noAction` branch is what makes such a job terminal with a durable
      // reason (`_retireSupersededForItem`), so it can no longer linger here
      // indefinitely. What remains is an item that moved between the two reads.
      final legal = await _evaluator.isRunnable(job, item, _definition);
      if (!legal) continue;
      candidates.add(job);
    }
    candidates.sort(JobQueue.orderEligible);
    return candidates;
  }

  /// Dispatches a single job. `null` means the job either isn't runnable
  /// anymore (workflow moved) or remains queued because no worker could be
  /// acquired, or another scheduler won the claim CAS.
  Future<_DispatchOutcome> _dispatchOne(Job job, DateTime now) async {
    final current = (await _jobStore.readJob(job.jobId)) ?? job;
    if (current.isTerminal) {
      return _DispatchOutcome(terminalJob: current);
    }
    if (!_queue.isEligibleAt(current, now)) {
      return const _DispatchOutcome();
    }

    final item = await _workflowStore.readWorkItem(current.workItemId);

    // Resolve the workload BEFORE building the request. A resolver that cannot
    // vouch for an artifact (returns null) must fail closed: the job stays
    // queued and this tick reports it, so the composition root can raise a
    // blocking human decision. Building a request against the construction-time
    // default would dispatch a reviewer at the WRONG revision, which is worse
    // than not dispatching at all.
    final workload = _workloadResolver == null
        ? _workload
        : await _workloadResolver(current, item);
    if (workload == null) {
      return const _DispatchOutcome(blockedArtifactMissing: true);
    }

    final request = _scopedToAttempt(
      await _requestBuilder(current, workload, item, _modelSelection),
      current,
    );
    final selection = _dispatch.select(request);
    if (!selection.isDispatched) {
      await _queue.recordDeferred(job: current, outcome: selection.outcome);
      return const _DispatchOutcome();
    }

    final admission = await _claim(current, now);
    if (admission.claim == null) {
      return _DispatchOutcome(capacityDenied: admission.capacityDenied);
    }

    await _queue.markRunning(
      job: current,
      now: now,
      workerId: selection.candidate!.workerId,
      // The request's OWN id, never a re-spelling of it. These were the same
      // string by coincidence — every builder spells it `'wx-${job.jobId}'` —
      // and [JobQueue.requeueSuperseded] documents `Job.executionReference` as
      // naming "a worker execution that ended without producing anything".
      // A reference that names a different execution than the one that ran is
      // not a reference; `_reconcileClaim`, `_reclaimZombie` and
      // `_releaseWorkItem` all chase it.
      workerExecutionId: request.workerExecutionId,
    );

    try {
      final result = await _dispatch.run(request);
      final adopted = await _adopt(current, result, now);
      return _DispatchOutcome(
        dispatched: true,
        terminalJob: adopted.isTerminal ? adopted : null,
      );
    } on WorkerDispatchException catch (e) {
      // Placement failed AFTER the claim but no execution was ever started:
      // safe to release the claim and let a later tick retry.
      await _queue.revertToQueued(
        job: current,
        reason: e.toString(),
        outcome: e.outcome,
      );
      return const _DispatchOutcome();
    }
  }

  /// Gives each ATTEMPT of a job its own worker-execution id, and nothing else
  /// changes.
  ///
  /// ## WHY, IN ONE LINE
  ///
  /// Without it a retry cannot run a second agent session, so option A of the
  /// retry-return decision would deliver a retry that is CLAIMED and
  /// DISPATCHED and then silently replays the failure it was supposed to
  /// recover from.
  ///
  /// ## THE CHAIN, END TO END
  ///
  ///  * every request builder spells the id `'wx-${job.jobId}'`
  ///    (`triageDefectRequest`, `implementFeatureRequest`,
  ///    `engineeringReviewRequest`, …), so it is the SAME STRING for every
  ///    attempt of one job;
  ///  * `LocalWorker._agentRequest` derives the agent execution id from it —
  ///    `'agx-${request.workerExecutionId}'`;
  ///  * and `ExecutionCoordinator.execute` is SINGLE-SHOT per execution id: an
  ///    id that already names a terminal execution returns that record instead
  ///    of starting anything. That is a correct and deliberate coordinator
  ///    invariant — "replay is achieved by observing the terminal record, not
  ///    by re-running the agent".
  ///
  /// So the retried dispatch received the FIRST attempt's interrupted
  /// execution, `_retryPolicy.classify` classified it transient a second time,
  /// and `canRetry` had already been spent: the job settled terminally
  /// `failed`. The retry was real enough to observe and useless in practice.
  ///
  /// ## WHY ATTEMPT 1 IS BYTE-IDENTICAL TO TODAY
  ///
  /// The suffix is added only from attempt 2. Every worker execution row ever
  /// persisted under `'wx-<jobId>'` — every historical execution, every
  /// `producerActorId` an item's `OD-10` discriminator resolves through — keeps
  /// matching. Re-spelling the base id would orphan all of them and, on the next
  /// tick, dispatch work whose producer could no longer be identified. This
  /// property is not to be traded for anything.
  ///
  /// ## WHY THE SUFFIX IS THE ATTEMPT AND NOT A COUNTER OR A RANDOM VALUE
  ///
  /// [Job.attempt] is already durable, already bounded by `maxAttempts`, and
  /// already the number the operator sees. A fresh `DateTime` or a nonce would
  /// make the id un-derivable from the job row, which is exactly what
  /// reconciliation needs: `_reconcileClaim`, `_reclaimZombie` and
  /// `_releaseWorkItem` all read `Job.executionReference`, never a derivation.
  ///
  /// ## IT DOES NOT LOOSEN THE COORDINATOR'S INVARIANT
  ///
  /// The coordinator stays single-shot per id. What changes is that a retry
  /// asks for a DIFFERENT id, which is a different piece of work rather than a
  /// second claim on the same one — and `Job.executionReference` is written from
  /// the request's real id, so the audit row, the reconciliation chase and the
  /// workspace all name the execution that actually ran.
  ///
  /// ## WHY IT IS APPLIED HERE AND NOT IN THE BUILDERS
  ///
  /// The builders are five separate functions in five separate files, and
  /// changing each one is five chances to spell the suffix differently. This is
  /// the single place every dispatch passes through, so one rule applies to
  /// every definition including the ones added later — which is the same
  /// reasoning `DedupeKeyBuilder` and `InstructionBuilder` exist as injectable
  /// seams, and the opposite of them.
  WorkerExecutionRequest _scopedToAttempt(
    WorkerExecutionRequest request,
    Job job,
  ) {
    if (job.attempt <= 1) return request;
    return WorkerExecutionRequest(
      workerExecutionId: '${request.workerExecutionId}:a${job.attempt}',
      workItemId: request.workItemId,
      repositoryPath: request.repositoryPath,
      startingRevision: request.startingRevision,
      requiredCapabilities: request.requiredCapabilities,
      role: request.role,
      instruction: request.instruction,
      timeoutSeconds: request.timeoutSeconds,
      runtimeTypeId: request.runtimeTypeId,
      expectedArtifacts: request.expectedArtifacts,
      cleanupPolicy: request.cleanupPolicy,
      envAllowlist: request.envAllowlist,
      environment: request.environment,
      runtimeConfig: request.runtimeConfig,
      createdAt: request.createdAt,
      // Carried across VERBATIM. It is the independence constraint for a
      // design review — the designer must never review itself — and it names
      // EXECUTION ids recorded by the same `'agx-$workerExecutionId'` rule this
      // method feeds, so a retry's request asks the same question as the
      // original one did.
      excludedExecutionIds: request.excludedExecutionIds,
    );
  }

  /// Claims [current], taking a capacity slot first when the budget is
  /// configured.
  ///
  /// Returns the durable claim on success, or a null claim when the job must
  /// simply not be dispatched this tick. The two refusals are reported apart:
  /// losing the claim CAS means someone else took this specific job, whereas
  /// `capacityDenied` means the shared budget was full and no job at all could
  /// start this tick. Both leave the job queued for a later tick; conflating
  /// them would make a saturated budget look like a contention bug.
  Future<({JobClaim? claim, bool capacityDenied})> _claim(
    Job current,
    DateTime now,
  ) async {
    final guard = capacityGuard;
    if (guard == null) {
      final claim = await _queue.claim(
        job: current,
        ownerId: schedulerId,
        now: now,
        lease: claimLease,
      );
      return (claim: claim, capacityDenied: false);
    }

    final admission = await guard.tryAdmit(
      job: current,
      ownerId: schedulerId,
      now: now,
      lease: claimLease,
    );
    switch (admission) {
      case CapacityAdmitted(:final claim):
        return (claim: claim, capacityDenied: false);
      case CapacityDenied():
        // A denied job is left EXACTLY as it was. No claim is written, no state
        // is written, and no failure is recorded — the honest record is "no
        // capacity right now", which is what `deferred` already means. The job
        // stays eligible, so a later tick retries it with no intervention and
        // no loss.
        await _queue.recordCapacityDenied(
          job: current,
          payload: admission.toEventPayload(),
        );
        return (claim: null, capacityDenied: true);
      case CapacityClaimLost():
        return (claim: null, capacityDenied: false);
    }
  }

  /// How many times a job may be returned to the queue by a supersession
  /// before the scheduler stops deferring and retires it instead.
  ///
  /// ## Why this exists at all
  ///
  /// A supersession re-check answers "does this definition still want the item?"
  /// by asking the SAME policy probe scheduling uses. The coordinator, meanwhile,
  /// got its supersession by attempting a REAL transition. Those two can
  /// disagree, and then a requeue is a loop: the probe says runnable, the
  /// transition is refused, the job is requeued, the next tick repeats it —
  /// once per tick, forever, each pass spending a real worker execution.
  ///
  /// That is not hypothetical. `triageDefectDefinition` lists `reviewRejected`
  /// as an entry state, reached by a human rejecting an engineering review. Its
  /// only legal hop toward execution is `reviewRejected -> designNotRequired`,
  /// so the probe asks about THAT edge — while the coordinator asks for the
  /// direct `reviewRejected -> agentExecuting`, which is not in the table. Every
  /// dispatch of a `reviewRejected` item is therefore superseded while the probe
  /// calls it runnable. The deferral is still the RIGHT outcome there — nothing
  /// ran, and a `failed` would be a lie — but it cannot be the only outcome, or
  /// the scheduler becomes the load generator.
  ///
  /// ## Why a cap on DEFERRALS and not on retries
  ///
  /// It cannot be `Job.attempt`, which is the whole contract of this change: no
  /// execution started, so no budget is spent and nothing may be charged. So the
  /// bound is counted separately, from the durable event log, under a key of
  /// its own.
  ///
  /// ## What it costs when it fires
  ///
  /// The job ends `cancelled` — not `failed` — with a reason that says it was
  /// deferred repeatedly and that a human should look. That is a visible,
  /// explained outcome instead of a hot loop, and it records the very thing the
  /// item is stuck on. It is deliberately the same terminal state the
  /// already-shipped retirement sweep uses, so there is one vocabulary for "this
  /// job is not wanted".
  static const int _maxSupersessionDeferrals = 3;

  /// Machine-readable prefix that marks the cancellation [_maxSupersessionDeferrals]
  /// produced, as opposed to every other cancellation this lane writes.
  ///
  /// ## WHY A MARKER RATHER THAN THE EVENT LOG ALONE
  ///
  /// The stall derivation needs to find these rows from a single `listJobs()`
  /// sweep, because reading every job's event log on every tick is
  /// `O(items × jobs)` durable reads on the critical path of the whole lane to
  /// answer a question that is false for almost every row (see
  /// [_supersessionStalls]). [Job.cancelReason] is already on the row that
  /// sweep returns, so a prefix there is what makes the expensive read
  /// necessary at all — let alone only sometimes.
  ///
  /// It is a marker and not a sentence for the same reason
  /// `supersededExecutionMarker` is one: matching prose is a coupling that
  /// fails silently. Editing the operator-facing wording below would otherwise
  /// quietly disable the stall — no error, no failed test, just the loop back.
  ///
  /// ## IT IS A PREFIX, AND THE REASON STILL READS AS ENGLISH
  ///
  /// `superseded: [supersession-cap] this work item has now been deferred…`.
  /// Everything that asserts on the prose asserts it by `contains`, which the
  /// marker does not disturb; what asserts on it by `startsWith` is
  /// `_isSupersessionCapCancellation` and nothing else.
  static const String _supersessionCapMarker =
      'superseded: [supersession-cap] ';

  /// Adopts a worker execution's terminal outcome onto its job: merges the
  /// reported agent execution id into the job's execution reference, then lets
  /// the retry policy pick the resulting state.
  ///
  /// A supersession never reaches [RetryPolicy]: it is not a failure of the
  /// execution but a statement that no execution happened, so [RetryPolicy] has
  /// no opinion about it and the `failed` it would otherwise produce is the
  /// defect. See [_adoptSupersession].
  Future<Job> _adopt(
    Job prior,
    WorkerExecutionResult result,
    DateTime now,
  ) async {
    final current = (await _jobStore.readJob(prior.jobId)) ?? prior;
    if (current.isTerminal) return current;
    if (isSupersededExecution(result.failureDetail, status: result.status)) {
      return _adoptSupersession(current, result, now);
    }
    final failure = _retryPolicy.classify(result.status, result.failureDetail);
    // Null when the outcome adds nothing to the chain, in which case the queue
    // preserves whatever the job already holds.
    final adopted = _executionReference(current, result, now);
    if (failure == null) {
      return _queue.complete(
        job: current,
        terminal: JobState.succeeded,
        now: now,
        executionReference: adopted,
      );
    }
    switch (failure.kind) {
      case JobFailureKind.cancelled:
        return _queue.complete(
          job: current,
          terminal: JobState.cancelled,
          failure: failure,
          now: now,
          executionReference: adopted,
        );
      case JobFailureKind.transient:
        if (_retryPolicy.canRetry(current)) {
          return _queue.scheduleRetry(
            job: current,
            failure: failure,
            now: now,
            retryDelay: _retryPolicy.retryDelay,
            executionReference: adopted,
          );
        }
        return _queue.complete(
          job: current,
          terminal: JobState.failed,
          failure: failure,
          now: now,
          executionReference: adopted,
        );
      case JobFailureKind.permanent:
      case JobFailureKind.none:
        return _queue.complete(
          job: current,
          terminal: JobState.failed,
          failure: failure,
          now: now,
          executionReference: adopted,
        );
    }
  }

  /// Decides what a supersession means for [job], and records it.
  ///
  /// ## The judgement, and why it lives here
  ///
  /// Two facts are needed and only the scheduler holds both:
  ///
  ///  * that nothing ran — which only the coordinator can attest, and which
  ///    arrives as [supersededExecutionMarker] on the failure detail, having
  ///    been flattened to a string by a worker this lane does not own; and
  ///  * whether this job's DEFINITION still wants the item — which lives in
  ///    [_definition]'s entry states and in the workflow policy probe.
  ///
  /// Carrying the verdict on the outcome instead would mean the coordinator
  /// deciding (a) from (b), which forces it to know the entry states: a second
  /// copy of a slice of the graph, in the one package whose job is to obey it
  /// rather than to enumerate it. Re-reading the item alone would mean treating
  /// ANY failure on a still-runnable item as a deferral, and that requeues a
  /// genuine agent failure forever — an unbounded automatic LLM retry loop,
  /// the exact thing [RetryPolicy] exists to prevent. So it takes both: the
  /// marker to know this was a supersession, and the re-check to know what to
  /// do about it.
  ///
  /// The (a)/(b) split is the point and is not collapsed:
  ///
  ///  * **(a) still accepted** — the item moved to a state this definition can
  ///    still run from, so the job is wanted and simply arrived at the wrong
  ///    moment. [JobQueue.requeueSuperseded] returns it to `queued` with no
  ///    attempt charged, and a later tick dispatches it against the new state.
  ///  * **(b) no longer accepted** — the item has left this definition's entry
  ///    states entirely, which is what [_retireSupersededForItem] already
  ///    ships for a job that never started. The same terminal state and the same
  ///    reason vocabulary are used, because it IS the same condition.
  ///
  /// ## If the item moves between this re-check and the requeue
  ///
  /// Nothing bad, and that is structural rather than a matter of timing. The
  /// requeue writes `queued`; it never dispatches and never commits to running.
  /// The next tick rebuilds its runnability map from a fresh
  /// `readAllWorkItems()`, `_eligibleRunnableJobs` re-checks legality against
  /// that fresh item before claiming, and step 3's `noAction` branch retires a
  /// `queued` job whose item no longer wants it. So the requeue is only ever a
  /// DECISION NOT TO FAIL — the moment it stops being correct, ordinary
  /// machinery stops it from doing any harm.
  ///
  /// The work item is never moved here: it belongs to whoever moved it.
  Future<Job> _adoptSupersession(
    Job job,
    WorkerExecutionResult result,
    DateTime now,
  ) async {
    final detail = result.failureDetail ?? '';
    final workItem = await _readWorkItemForAdoption(job.workItemId);

    // Fail CLOSED. An item that cannot be read cannot be shown to still want
    // this job, and "cannot prove (a)" is not evidence for (a): the one thing
    // this change must never do is requeue on a guess.
    if (workItem == null) {
      return _queue.cancelQueued(
        job: job,
        reason:
            'superseded: work item ${job.workItemId} could not be read, so '
            'nothing can confirm this job is still wanted. $detail',
        now: now,
      );
    }

    final status = _evaluator.evaluate(workItem, _definition);
    if (status != RunnableWorkStatus.runnable) {
      return _queue.cancelQueued(
        job: job,
        reason: _supersededReason(workItem),
        now: now,
      );
    }

    final deferrals = await _supersessionDeferrals(job);
    if (deferrals >= _maxSupersessionDeferrals) {
      return _queue.cancelQueued(
        job: job,
        reason:
            '$_supersessionCapMarker'
            'this work item has now been deferred '
            '$_maxSupersessionDeferrals times because it kept moving before an '
            'execution started, and it is still ${workItem.state.wire}. '
            'Stopping rather than spinning — a human should check why this item '
            'cannot complete an execution. The count spans every job this item '
            'has held, including ones re-minted after an earlier cancellation, '
            'so re-minting cannot reset it. No attempt was consumed.',
        now: now,
        // THE PART THAT ACTUALLY STOPS IT, and the reason this method writes
        // anything beyond prose.
        //
        // Everything above is true today and changes nothing: this cancellation
        // RELEASES the dedupe key (JobQueue's documented contract), so the
        // next tick mints a fresh job for the same work and the whole cycle
        // repeats. The breaker stops the JOB. Measured on QA on 2026-10-15,
        // that left two work items at 214 jobs each and four jobs a minute,
        // with the conclusion above living only in `scheduler_event
        // .payloadJson` where no operator surface reads it.
        //
        // What is written here is what lets a later tick RECOGNISE this
        // cancellation instead of re-deriving it from prose: the cap fired, on
        // which job type, and — the load-bearing one — the work item's
        // `version` at that instant. Version is the durable counter of real
        // moves, so `version > stalledWorkItemVersion` is proof that this
        // item progressed after the diagnosis was taken and the diagnosis no
        // longer describes it. See [_supersessionStalls] for the read side.
        eventPayload: {
          'supersessionCapFired': true,
          'supersessionJobType': job.jobType.wire,
          'supersessionDeferrals': deferrals,
          'stalledWorkItemVersion': workItem.version,
          'stalledWorkItemState': workItem.state.wire,
        },
      );
    }
    return _queue.requeueSuperseded(
      job: job,
      reason:
          'requeued without an attempt: the work item moved to '
          '${workItem.state.wire} before this execution started, and it still '
          'accepts a ${_definition.jobType.wire} run. Nothing ran and nothing '
          'was produced, so no retry budget was consumed; the job returns to '
          'the queue and a later tick retries it against the new state.',
      now: now,
    );
  }

  /// The work item as it is RIGHT NOW, or null when it cannot be read.
  ///
  /// A read fault must not escape and abort the tick: it would leave this job
  /// claimed and this item's other rows unreached. It is answered as "cannot
  /// confirm", which [_adoptSupersession] resolves by retiring rather than
  /// requeueing.
  Future<WorkItem?> _readWorkItemForAdoption(String workItemId) async {
    try {
      return await _workflowStore.readWorkItem(workItemId);
    } catch (_) {
      return null;
    }
  }

  /// How many times the WORK ITEM this job belongs to has already been deferred
  /// by a supersession.
  ///
  /// ## Why the count is per WORK ITEM and not per job row
  ///
  /// Because the dedupe key a requeue eventually yields is not stable across a
  /// cycle. `JobQueue.enqueueIfAbsent` hands the key back the moment its holder
  /// is `cancelled` (job_queue.dart:76) — and [_maxSupersessionDeferrals]
  /// firing IS a cancellation — so the next tick mints a FRESH job for the same
  /// work, with a fresh row and a fresh, empty event log. A counter that reads
  /// one row therefore restarts at zero on every remint, and the cap it bounds
  /// is one LAP of the queue rather than the cycle that actually spins. The
  /// measured consequence was unbounded: seven worker executions in twenty-five
  /// ticks instead of the three the cap claims to allow.
  ///
  /// So the count is taken over EVERY job this work item has held for this job
  /// type, which is exactly the set of remints the cycle is made of. It is
  /// scoped by job type because a `Scheduler` only ever mints jobs of its own
  /// definition's [JobType] — so within one scheduler this is the whole set of
  /// the item's remints — while a shared job store may hold another definition's
  /// jobs for the same item, and their deferrals are a different fact.
  ///
  /// Counted from the durable event log rather than from a counter on the row,
  /// because [Job] has no field for it and `platform_contracts` cannot grow one
  /// in this lane. The log is the same record an operator reads, so the bound
  /// and the explanation cannot disagree.
  Future<int> _supersessionDeferrals(Job job) async {
    var deferrals = 0;
    for (final row in await _jobStore.listJobsForWorkItem(job.workItemId)) {
      if (row.jobType != job.jobType) continue;
      deferrals += (await _jobStore.readEvents(row.jobId))
          .where(
            (e) =>
                e.type == SchedulerEventType.jobQueued &&
                e.payload?['supersessionDeferred'] == true,
          )
          .length;
    }
    return deferrals;
  }

  /// Every item in [items] this lane has already stopped producing work for.
  ///
  /// ## THE CONDITION, IN ONE SENTENCE
  ///
  /// A work item is stalled when this lane has already burned its
  /// supersession-deferral budget on it AND the item has not moved since —
  /// which is read, not remembered.
  ///
  /// ## WHY "AND IT HAS NOT MOVED" IS PART OF THE CONDITION
  ///
  /// Because the cap firing says something about one JOB, not about the work
  /// item, and the two come apart in the case the cap was written for. Three
  /// deferrals on an item that is genuinely shuttling between states is a
  /// healthy queue: the item is moving, it just keeps arriving before its
  /// execution starts. Cancelling that job and then declining to mint another
  /// one would strand a review that is owed and would be a regression against
  /// `supersession_requeue_test.dart`, which exists precisely to prove the
  /// requeue works. So the version recorded when the cap fired is compared
  /// against the item's version NOW: a larger version is proof of a real move
  /// and lifts the stall on its own, with no flag for anybody to forget.
  ///
  /// That is also what makes the stall recoverable rather than terminal, and it
  /// is the recovery path that needs no new write surface at all: an operator
  /// action on this item moves it, and moving it lifts the stall.
  ///
  /// ## WHY IT IS DERIVED AND NOT RECORDED ON THE WORK ITEM
  ///
  /// `WorkItem.metadata` is the obvious home and is deliberately not used. The
  /// only writer for it here would be a bare `saveWorkItem` with no transition
  /// row beside it — an out-of-band write to the row every audit question is
  /// asked of — and `ControlPlaneService`'s class contract says in terms that
  /// nothing writes state outside the engine. The event log is already durable,
  /// already per-work-item across re-mints (that is what
  /// [_supersessionDeferrals] proved), already the record an operator reads,
  /// and needs no schema change in a package this lane does not own.
  ///
  /// The cost is paid honestly and is the reason this is written the way it is:
  /// it costs ONE [JobStore.listJobs] call per tick, and ZERO event-log reads
  /// unless a job row says a cap fired. The obvious alternative — for each item
  /// in hand, list that item's jobs and read each one's events — is
  /// `O(items × jobs)` durable reads on the critical path of EVERY tick, to
  /// answer a question that is false for almost every item. It was written that
  /// way first, and it broke `capacity_limit_test.dart`'s T5: that harness
  /// models every store read as two event-loop yields and the test calibrates
  /// its interleaving on how many of them a tick spends, so the extra reads
  /// pushed the restarted process past the point where it could still take a
  /// freed slot. A store read is not free just because it is indexed, and a
  /// tick is the one place in this package that must not get slower for every
  /// other work item in the system.
  ///
  /// So the sweep is inverted. [Job.cancelReason] is already on the row the
  /// single sweep returns, so a cap-fired cancellation is recognisable without
  /// opening its event log at all — which is what [_supersessionCapMarker]
  /// is for, and why it is a MARKER rather than a phrase. Only the handful of
  /// rows that match are opened, and only for the version.
  Future<Map<String, SchedulerStall>> _supersessionStalls(
    List<WorkItem> items,
  ) async {
    // One sweep. `listJobs` is already called by this tick's reconciliation
    // pass, so the marginal cost of this call is one more read of a set this
    // method needs anyway.
    final rows = await _jobStore.listJobs();

    if (!rows.any((r) => _isSupersessionCapCancellation(r))) return const {};

    // Only now, and only for the rows that matched: open the event log for the
    // version the diagnosis was taken at, and count the deferrals spent.
    final byItem =
        <String, ({int version, String? state, String jobId, int deferrals})>{};
    for (final row in rows) {
      if (row.jobType != _definition.jobType) continue;
      if (!_isSupersessionCapCancellation(row)) continue;
      final events = await _jobStore.readEvents(row.jobId);
      int? versionAt;
      String? stateAt;
      var deferrals = 0;
      for (final event in events) {
        if (event.type == SchedulerEventType.jobQueued &&
            event.payload?['supersessionDeferred'] == true) {
          deferrals++;
        }
        if (event.type != SchedulerEventType.jobCancelled) continue;
        if (event.payload?['supersessionCapFired'] != true) continue;
        final raw = event.payload?['stalledWorkItemVersion'];
        final parsed = raw is int ? raw : int.tryParse('${raw ?? ''}');
        if (parsed == null) continue;
        // Any cap firing counts, but the LATEST one is the current diagnosis,
        // so an item that stalled, moved and stalled again reports the second
        // diagnosis against the second version.
        if (versionAt == null || parsed >= versionAt) {
          versionAt = parsed;
          stateAt = event.payload?['stalledWorkItemState'] as String?;
        }
      }
      if (versionAt == null) continue;
      final prior = byItem[row.workItemId];
      if (prior == null || versionAt >= prior.version) {
        byItem[row.workItemId] = (
          version: versionAt,
          state: stateAt,
          jobId: row.jobId,
          deferrals: deferrals,
        );
      }
    }

    final byId = {for (final i in items) i.workItemId: i};
    final stalls = <String, SchedulerStall>{};
    for (final entry in byItem.entries) {
      final item = byId[entry.key];
      // An item this tick did not hand us is not this tick's business; a
      // terminal one is retired by step 4 on its own account.
      if (item == null || item.isTerminal) continue;
      // The item MOVED since the diagnosis. It is no longer the thing the
      // breaker described, so this lane owes it a fresh job and must mint one.
      if (item.version > entry.value.version) continue;
      stalls[entry.key] = SchedulerStall(
        workItemId: item.workItemId,
        state: item.state,
        jobType: _definition.jobType,
        deferrals: entry.value.deferrals,
        reason: _stallReason(
          item,
          entry.value.state,
          entry.value.jobId,
          entry.value.deferrals,
        ),
      );
    }
    return stalls;
  }

  /// Whether [row] is the cancellation the supersession-deferral cap produced.
  ///
  /// A row-level test, deliberately, so the sweep in [_supersessionStalls] can
  /// exclude every ordinary cancellation without opening an event log.
  static bool _isSupersessionCapCancellation(Job row) {
    final reason = row.cancelReason;
    return reason != null && reason.startsWith(_supersessionCapMarker);
  }

  String _stallReason(
    WorkItem item,
    String? stalledAtState,
    String jobId,
    int deferrals,
  ) {
    final state = stalledAtState ?? item.state.wire;
    return 'work item ${item.workItemId} is $state and this lane has already '
        'deferred it $deferrals times without one execution ever starting, '
        'so it stopped launching instead of spinning. Job $jobId holds the full '
        'reason. Nothing was consumed and no attempt was spent. This resolves on '
        'its own the moment this item MOVES — a producer running again, or an '
        'operator action on it — because that clears the diagnosis; until then '
        'it needs a human to find why this item cannot begin an execution at '
        'all.';
  }

  /// Why this item is no longer something [_definition] can run — the same
  /// vocabulary [_retireSupersededForItem] uses, because a job superseded after
  /// dispatch and one superseded before it are the same condition.
  ///
  /// The two reasons below are NOT interchangeable and the difference is the
  /// whole diagnosis. `RunnableWorkStatus.noAction` covers both "this
  /// definition does not serve that state" and "it does, but the policy refuses
  /// the route out of it", and telling an operator the second is the first
  /// sends them to look for a state-list entry that is already there.
  String _supersededReason(WorkItem item) {
    final entryStates =
        _definition.entryStates.map((state) => state.wire).toList()..sort();
    if (_definition.entryStates.contains(item.state)) {
      final target = _definition.probeTargetFor(item.state);
      return 'superseded: work item ${item.workItemId} is ${item.state.wire}, '
          'which IS an entry state for ${_definition.jobType.wire}, but the '
          'workflow policy refuses ${item.state.wire} -> ${target.wire}, so this '
          'definition cannot start an execution from it. No agent has run and '
          'nothing was produced.';
    }
    return 'superseded: work item ${item.workItemId} is ${item.state.wire}, '
        'which is not an entry state for ${_definition.jobType.wire} '
        '(${entryStates.join(', ')}). Nothing ran and nothing was produced.';
  }

  /// Retires jobs this work item still holds under a DIFFERENT dedupe key, after
  /// [EntryHopper] moved the item to the state it will now be dispatched from.
  ///
  /// ## Why this is needed at all
  ///
  /// A hop happens once, on the tick that first notices the item, and the hop
  /// is taken BEFORE the dedupe key is built — so every job this code mints is
  /// keyed on the post-hop state and the steady state has nothing to retire. The
  /// rows this reaches are the ones an EARLIER build minted against the
  /// pre-hop state: a job queued while the item sat in the state that is about
  /// to be hopped. Left alone, that row stays queued, stays eligible (the item
  /// is runnable after the hop, just at a different key) and is dispatched
  /// beside the job the same tick mints — two agent executions for one work
  /// item, which is the duplicate the dedupe key exists to make impossible.
  ///
  /// Only non-terminal jobs are touched, only for this item, only for this job
  /// type, and only when their key differs from the one being minted. Claims,
  /// running jobs and terminal jobs converge on a verdict elsewhere and are
  /// never overridden from here.
  Future<List<String>> _retireJobsKeyedForPriorState(
    WorkItem item,
    String currentDedupeKey,
  ) async {
    final retired = <String>[];
    for (final job in await _jobStore.listJobsForWorkItem(item.workItemId)) {
      if (job.isTerminal) continue;
      if (job.jobType != _definition.jobType) continue;
      if (job.dedupeKey == currentDedupeKey) continue;
      if (job.state != JobState.queued && job.state != JobState.retryWaiting) {
        continue;
      }
      await _queue.cancelQueued(
        job: job,
        reason:
            'superseded: work item ${item.workItemId} advanced to '
            '${item.state.wire} before this job started, and '
            '${_definition.jobType.wire} jobs are now keyed on that state. '
            'This row was minted for an earlier state of the same item. Nothing '
            'ran and nothing was produced.',
      );
      retired.add(job.jobId);
    }
    return retired;
  }

  /// The job's execution reference with [WorkerExecutionResult.agentExecutionId]
  /// merged in, which is the only half of the chain a terminal outcome adds.
  ///
  /// INVARIANT: a job's `executionReference` is either null, or names a real
  /// worker execution. It is never written with an empty `workerExecutionId`.
  ///
  /// [JobQueue.markRunning] normally stamps the worker half before the worker
  /// runs, and the existing reference is then extended in place. It can lose
  /// that CAS to a concurrent writer, leaving a job whose reference is absent
  /// while its execution is already running. The correct value in that case is
  /// the worker execution that produced the outcome being adopted - the
  /// execution the dispatch request named - never a placeholder. When even that
  /// id is empty the reference is omitted entirely rather than persisted as a
  /// dangling link, because a reader follows this chain and an empty id names
  /// nothing.
  JobExecutionReference? _executionReference(
    Job job,
    WorkerExecutionResult result,
    DateTime now,
  ) {
    final current = job.executionReference;
    final agentExecutionId = result.agentExecutionId;
    if (agentExecutionId == null) return current;
    if (current != null) {
      return current.copyWith(agentExecutionId: agentExecutionId);
    }
    if (result.workerExecutionId.isEmpty) return null;
    return JobExecutionReference(
      workerExecutionId: result.workerExecutionId,
      createdAt: now,
      agentExecutionId: agentExecutionId,
    );
  }

  /// Reconciles a claim that expired without a terminal job. Guarantees
  /// at-least-once semantics WITHOUT double execution:
  ///  - never dispatched           -> requeue (reclaim is safe);
  ///  - vended to the worker layer -> consult the worker store: if the
  ///    execution already ended, adopt its result; if it is still alive, DO
  ///    NOT start a duplicate, just renew the lease;
  ///  - vended, non-terminal, and NOT observably alive -> the execution is a
  ///    zombie and is reclaimed to a terminal job state. This is the branch
  ///    that was missing: the old code treated "not terminal" as "alive", so a
  ///    worker row whose process had died was renewed on every tick forever and
  ///    the lease could never expire.
  Future<void> _reconcileClaim(Job job, JobClaim? claim, DateTime now) async {
    final ref = job.executionReference;
    if (ref == null) {
      await _queue.requeueFromStaleClaim(
        job: job,
        reason: claim == null
            ? 'claim record missing'
            : 'claim expired before dispatch',
      );
      return;
    }
    final execution = await _workerStore.readWorkerExecution(
      ref.workerExecutionId,
    );
    if (execution == null) {
      await _queue.requeueFromStaleClaim(
        job: job,
        reason: 'referenced execution ${ref.workerExecutionId} not found',
      );
      return;
    }
    if (!execution.isTerminal) {
      final liveness = await _livenessOf(execution, now);
      if (_shouldReclaimZombie(execution, now, liveness)) {
        await _reclaimZombie(job, execution, now, liveness);
        return;
      }
      // Observed alive, or not yet old enough to judge: renew the lease rather
      // than duplicating, so a genuinely live-but-slow execution is protected.
      final renewed = JobClaim(
        claimId: JobQueue.newClaimId(),
        jobId: job.jobId,
        ownerId: schedulerId,
        leasedUntil: now.add(claimLease),
        createdAt: now,
      );
      await _jobStore.saveClaim(renewed);
      return;
    }
    final result = await _workerStore.readResult(ref.workerExecutionId);
    await _adoptFromExecution(job, execution, result, now);
  }

  /// What could be observed about [execution] right now.
  ///
  /// A probe that throws is treated as `unknown`, not as `dead`: an
  /// observation failure is not evidence of death, and must not be allowed to
  /// kill live work.
  Future<ExecutionLiveness> _livenessOf(
    WorkerExecution execution,
    DateTime now,
  ) async {
    final probe = _executionLiveness;
    if (probe == null) return ExecutionLiveness.unknown;
    try {
      return await probe(execution, now);
    } catch (_) {
      return ExecutionLiveness.unknown;
    }
  }

  /// Whether a non-terminal execution must be reclaimed as a zombie.
  ///
  /// Reclaimed when liveness is proven dead, and when liveness could not be
  /// observed and the execution has outlived [zombieStalenessBound]. An
  /// execution with no recorded start is reclaimed too: there is nothing to
  /// judge it against, and an execution that cannot even say when it started is
  /// not one whose progress anyone has been able to observe.
  bool _shouldReclaimZombie(
    WorkerExecution execution,
    DateTime now,
    ExecutionLiveness liveness,
  ) {
    if (liveness == ExecutionLiveness.alive) return false;
    if (liveness == ExecutionLiveness.dead) return true;
    final since = execution.startedAt ?? execution.createdAt;
    if (since == null) return true;
    return now.difference(since) > zombieStalenessBound;
  }

  /// Drives a job whose execution nothing is running behind to a TERMINAL
  /// state, so it is no longer left running and its lease is no longer renewed.
  ///
  /// FAIL DIRECTION: this is the fail-CLOSED branch, and it is reached only
  /// when liveness was either proven dead or has been unobservable for longer
  /// than [zombieStalenessBound]. The unobservable case fails open *within a
  /// bound* rather than open forever: renewing an execution nobody is running
  /// is exactly the defect that produced a 4.78 hour stall, whereas the harm of
  /// failing closed is bounded by that same window and surfaces as a visible
  /// failed job rather than a silent duplicate.
  ///
  /// The job goes to `failed` rather than to a retry, deliberately. A retry
  /// would re-dispatch against a work item still in
  /// [WorkItemState.agentExecuting] that the scheduler is not allowed to move,
  /// and a second execution writing the same worktree while the first may still
  /// hold it is the worse of the two harms.
  ///
  /// ## ORDER IS THE POINT
  ///
  /// The work item and the worker execution are reclaimed BEFORE the job, not
  /// after. Failing the job first would be safe only if the process never died
  /// between the two writes — but a terminal job is never re-reconciled
  /// (`tick` only considers held jobs with an expired claim), so a crash in that
  /// window would strand the work item permanently with no path back. In this
  /// order a crash anywhere leaves the claim held and the claim expired, so the
  /// next tick re-enters [_reconcileClaim] and converges: the work item is
  /// already out of [WorkItemState.agentExecuting], so that step is a no-op, and
  /// the job is still failed.
  Future<void> _reclaimZombie(
    Job job,
    WorkerExecution execution,
    DateTime now,
    ExecutionLiveness liveness,
  ) async {
    final current = (await _jobStore.readJob(job.jobId)) ?? job;
    if (current.isTerminal) return;

    final age = _durationSinceStart(execution, now);
    final reason = switch (liveness) {
      ExecutionLiveness.dead =>
        'execution ${execution.workerExecutionId} is still ${execution.status.name} '
            'but nothing is running behind it (observed dead after $age)',
      _ =>
        'execution ${execution.workerExecutionId} is still ${execution.status.name}, '
            'no live execution could be observed, and it has been non-terminal '
            'for $age (beyond the ${zombieStalenessBound.inMinutes}m bound)',
    };

    // NOTHING is written until the work item is out of `agentExecuting`.
    //
    // If the release is exhausted, abort here — before the worker execution and
    // before the job — so no half-applied reclaim is left behind and the next
    // tick re-reaches the still-held row. Completing the job first would strand
    // the work permanently, since a terminal job is never reconciled again.
    final release = await _releaseWorkItem(
      current.workItemId,
      execution,
      reason,
    );
    if (release == _WorkItemRelease.contended) {
      throw const _ReclaimDeferredException();
    }

    await _retireWorkerExecution(execution, now, reason);

    await _queue.complete(
      job: current,
      terminal: JobState.failed,
      failure: JobFailure(
        code: JobFailureCode.executionInterrupted,
        kind: JobFailureKind.permanent,
        reason: 'zombie execution reclaimed: $reason',
      ),
      now: now,
      executionReference: current.executionReference,
    );
  }

  /// Moves the work item out of [WorkItemState.agentExecuting] so a zombie does
  /// not strand the work forever.
  ///
  /// ## Why `agentFailed`, from the real transition table
  ///
  /// Edges out of `agentExecuting` in `WorkItemTransitions` are exactly two, plus
  /// the generic orchestrator escape:
  ///
  ///  * `agentCompleted` — guarded by `qaContractExists()` AND
  ///    `agentResultValid()`. A zombie has no agent result, so this edge is not
  ///    available and asserting it would be a lie about what ran.
  ///  * `agentFailed` — guarded by `actorAllowed([orchestrator])` alone.
  ///  * `cancelled` / `terminated` — the generic escape, but BOTH are workflow
  ///    terminal states. Choosing them would turn a recoverable reclaim into
  ///    permanent loss, which is the exact harm this method exists to prevent.
  ///
  /// So `agentFailed` is the only honest non-terminal exit, and it is recoverable:
  /// `(agentFailed -> agentExecuting)` is itself a legal edge, so a human or a
  /// re-plan can put the work back into execution. It is deliberately NOT
  /// auto-re-dispatched — `RunnableWorkEvaluator` does not list `agentFailed` in
  /// any entry set, because reworking a failed result routes through the
  /// workflow's correction gate rather than an automatic re-run. It therefore
  /// surfaces to a human instead of silently re-running or silently vanishing.
  ///
  /// This is the same state a genuine agent failure lands in, so a reclaim is
  /// indistinguishable from a real failure to anything reading the item.
  ///
  /// ## Idempotent and safe under a concurrent writer
  ///
  /// Three layers, because a reclaim must never resurrect or double-transition:
  /// the current state is re-read and the call is skipped unless the item is
  /// still in [WorkItemState.agentExecuting]; the transition carries an
  /// `idempotencyKey`, so a replay after a partial write returns the accepted
  /// outcome instead of transitioning again; and the store's compare-and-swap on
  /// the item version rejects a concurrent writer.
  ///
  /// ## Both rejection signals are caught, and they are not interchangeable
  ///
  /// Losing the compare-and-swap raises [ConcurrentModificationException], which
  /// is a SIBLING of [WorkflowTransitionRejectedException] — neither extends the
  /// other — and `DurableWorkflowEngine.transition` rethrows it out of the
  /// transaction rather than swallowing it. Catching only the rejected case
  /// therefore let a lost race escape `_releaseWorkItem` entirely, and because
  /// `tick` did not guard its reconciliation loop the exception aborted the
  /// WHOLE tick: the job was never failed, its claim never released, its worker
  /// execution never retired, and every other job's reconciliation was skipped
  /// too. A reclaim that fails that way is strictly worse than the stranding
  /// this method exists to prevent.
  ///
  /// The two are handled differently on purpose:
  ///
  ///  * [WorkflowTransitionRejectedException] means the transition was refused —
  ///    the item is not where we thought, or the edge is illegal. Someone else
  ///    owns the decision now, so this returns without retrying.
  ///  * [ConcurrentModificationException] means the decision was legal but the
  ///    item changed underneath the read. That is a lost race, not a refusal, so
  ///    the state is re-read and the attempt retried, bounded by
  ///    [_maxReclaimAttempts]. Catching it and moving straight on would leave the
  ///    item exactly as stranded as before whenever the competing writer had not
  ///    itself taken the item out of [WorkItemState.agentExecuting].
  Future<_WorkItemRelease> _releaseWorkItem(
    String workItemId,
    WorkerExecution execution,
    String reason,
  ) async {
    for (var attempt = 0; attempt < _maxReclaimAttempts; attempt++) {
      final item = await _workflowStore.readWorkItem(workItemId);
      if (item.state != WorkItemState.agentExecuting) {
        return _WorkItemRelease.released;
      }

      try {
        await _reclaimEngine.transition(
          workItemId: workItemId,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
          actor: _reclaimActor,
          context: {
            'zombieReclaimed': true,
            'workerExecutionId': execution.workerExecutionId,
            'workerId': execution.workerId,
            'lastStatus': execution.status.name,
            'reason': 'zombie execution reclaimed: $reason',
          },
          idempotencyKey: 'zombie-reclaim:${execution.workerExecutionId}',
        );
        return _WorkItemRelease.released;
      } on WorkflowTransitionRejectedException {
        // A concurrent writer moved the item first — a real result arriving from
        // the wedged path, or another tick. Either way the item is no longer
        // stranded, which is the whole job of this call, so a refused transition
        // is a correct outcome and must not be retried or escalated.
        return _WorkItemRelease.released;
      } on ConcurrentModificationException {
        // Lost the compare-and-swap. Re-read and decide again: the competing
        // writer may have taken the item out of `agentExecuting`, in which case
        // the loop's first line returns.
        continue;
      }
    }
    // Out of attempts and the item is STILL executing. Reporting that is the
    // point: an earlier version returned as if it had succeeded, so the reclaim
    // completed the job and left the work item in `agentExecuting` forever — the
    // precise permanent strand this method exists to prevent, reached not by a
    // crash but by exhausting a retry budget.
    return _WorkItemRelease.contended;
  }

  /// Drives the zombie worker execution row to a terminal state.
  ///
  /// ## Why the scheduler does this, rather than "leaving it to the worker layer"
  ///
  /// The previous version deferred this to `worker_runtime`'s reconciler. In
  /// this topology that deferral is dead: the coordinator's `reconcileOrphans()`
  /// finds nothing because `agent_execution` has no row for this execution, and
  /// once the job is terminal no later tick re-reaches this execution at all —
  /// `tick` only reconciles held jobs whose claim expired. QA showed the
  /// consequence directly: the job failed, capacity was released, and the
  /// `worker_execution` row stayed `agentExecuting` forever.
  ///
  /// The scheduler already holds the verdict that this execution is dead, so
  /// leaving the row asserting otherwise is the scheduler contradicting itself.
  /// `orphaned` is the status `WorkerReconciler` itself uses for "the executor
  /// went away", which keeps the two paths converging on one vocabulary instead
  /// of inventing a second way of saying the same thing.
  ///
  /// `cleanupStatus` is deliberately NOT touched. Nothing in this repository
  /// consumes `WorkerExecution.cleanupMissing`, and claiming cleanup happened
  /// would be a lie; leaving the recorded value alone keeps the row honest about
  /// what is still outstanding for whoever owns workspaces.
  ///
  /// The compare-and-swap is the concurrency guard: a worker that is somehow
  /// still alive and writing will lose to a verdict that was already durably
  /// recorded, which is the correct ordering. That rejection is caught rather
  /// than propagated — the job must still be failed.
  Future<void> _retireWorkerExecution(
    WorkerExecution execution,
    DateTime now,
    String reason,
  ) async {
    if (execution.isTerminal) return;
    try {
      await _workerStore.saveWorkerExecution(
        execution.copyWith(
          status: WorkerExecutionStatus.orphaned,
          failureCode: WorkerFailureCode.agentFailed,
          reason: 'orphaned by scheduler zombie reclaim: $reason',
          endedAt: now,
          version: execution.version + 1,
        ),
        expectedVersion: execution.version,
      );
    } on ConcurrentWorkerModificationException {
      // Another writer already moved this row; its verdict stands.
    }
  }

  String _durationSinceStart(WorkerExecution execution, DateTime now) {
    final since = execution.startedAt ?? execution.createdAt;
    if (since == null) return 'an unknown time';
    return '${now.difference(since).inMinutes}m';
  }

  Future<void> _adoptFromExecution(
    Job job,
    WorkerExecution execution,
    WorkerExecutionResult? result,
    DateTime now,
  ) async {
    final current = (await _jobStore.readJob(job.jobId)) ?? job;
    if (current.isTerminal) return;
    if (result != null) {
      await _adopt(current, result, now);
      return;
    }
    final synthesized = WorkerExecutionResult(
      workerExecutionId: execution.workerExecutionId,
      workItemId: current.workItemId,
      status: execution.status,
      workerId: execution.workerId ?? 'unknown',
      workspaceId: execution.workspaceId ?? 'unknown',
      startingRevision: execution.requestedStartingRevision,
      startedAt: execution.startedAt ?? execution.createdAt ?? now,
      endedAt: execution.endedAt ?? now,
      cleanupStatus: execution.cleanupStatus ?? WorkerCleanupStatus.pending,
      failureCode: execution.failureCode ?? WorkerFailureCode.none,
      failureDetail: execution.reason,
    );
    await _adopt(current, synthesized, now);
  }

  /// Cancels a job queued for a terminal work item (retryWaiting included).
  Future<List<String>> _cancelQueuedForItem(
    String workItemId, {
    required String reason,
  }) async {
    final cancelled = <String>[];
    for (final job in await _jobStore.listJobs()) {
      if (job.workItemId != workItemId) continue;
      if (job.isTerminal) continue;
      if (job.state == JobState.queued || job.state == JobState.retryWaiting) {
        await _queue.cancelQueued(job: job, reason: reason);
        cancelled.add(job.jobId);
      }
    }
    return cancelled;
  }

  /// Retires jobs that a non-terminal work item has SUPERSEDED: queued or
  /// retry-waiting jobs whose item is no longer in a state this definition can
  /// run from.
  ///
  /// ## Why this is the scheduler, and not the drain handler
  ///
  /// A superseded job is by definition a job that was never dispatched — there
  /// is no worker execution, no drain event and no handler invocation for it.
  /// The handler path only ever learns about jobs that DID start, so it cannot
  /// be the place that notices one that never will. The scheduler is the only
  /// component holding both halves of the fact (this job's state, and this
  /// definition's entry states) and the only one that runs periodically enough
  /// to notice. That it already performs the identical write for terminal
  /// items — `_cancelQueuedForItem` — is the precedent, not a coincidence.
  ///
  /// ## Why `cancelled` and not `failed`
  ///
  /// These jobs were never attempted. `failed` would assert an execution that
  /// never happened, and it would need a `JobFailure` — whose vocabulary has no
  /// "superseded" code, because adding one is a `platform_contracts` change and
  /// faking `executionFailed` is a lie an operator would act on. `cancelled`
  /// with an explicit [Job.cancelReason] says exactly what happened: this job
  /// was withdrawn because its work item no longer wants it. The reason is
  /// durable on the job row AND on the `jobCancelled` scheduler event.
  ///
  /// ## The dedupe key
  ///
  /// Retiring frees the key, deliberately, and the rule for "freed" is
  /// `JobQueue.enqueueIfAbsent`'s: a CANCELLED job holds no claim on a dedupe
  /// key, because it records no attempt and consumed no retry budget, while a
  /// succeeded or failed job keeps holding it. A fresh job is therefore
  /// created only once the item is back in an entry state — i.e. only when the
  /// work is genuinely wanted again — and never while this definition already
  /// has an active or concluded job for it. No duplicate is reachable: while
  /// the superseded job was queued the item was not runnable, so nothing was
  /// ever being asked for twice.
  ///
  /// Claims, running jobs and terminal jobs are never touched: those converge
  /// on a verdict through outcome adoption, reclaim or reconciliation, and
  /// overriding them here would destroy a result that is still landing.
  Future<List<String>> _retireSupersededForItem(WorkItem item) async {
    // Re-check the boundary condition locally rather than trusting the
    // caller's status: this method must be safe to call for any item, and
    // `evaluate` maps a few distinct situations onto `noAction`.
    if (_evaluator.evaluate(item, _definition) != RunnableWorkStatus.noAction) {
      return const [];
    }

    // One vocabulary, shared with [_adoptSupersession]: a job superseded
    // before it was dispatched and one superseded after are the same condition,
    // and an operator must not have to learn two phrasings for it.
    final reason = _supersededReason(item);

    final retired = <String>[];
    for (final job in await _jobStore.listJobsForWorkItem(item.workItemId)) {
      if (job.isTerminal) continue;
      if (job.state != JobState.queued && job.state != JobState.retryWaiting) {
        continue;
      }
      if (job.jobType != _definition.jobType) continue;
      await _queue.cancelQueued(job: job, reason: reason);
      retired.add(job.jobId);
    }
    return retired;
  }

  /// Withdraws this lane's still-dispatchable jobs for an item it has stalled,
  /// and says so on each one.
  ///
  /// ## WHY IT EXISTS ALONGSIDE THE ENQUEUE REFUSAL
  ///
  /// The enqueue refusal stops the NEXT job. It does not touch a job minted on
  /// the tick the stall landed, nor one an earlier tick queued and never got to.
  /// Left alone those sit `queued` for ever, which is the inert-row shape
  /// [_retireSupersededForItem] exists to prevent — and worse, it is a row that
  /// reads exactly like pending legitimate work to anyone who looks at the
  /// queue rather than at the tick result.
  ///
  /// Claims and running jobs are deliberately NOT touched, for the reason
  /// [_retireSupersededForItem] gives: they converge on a verdict through
  /// outcome adoption, and overriding one would destroy a result that is still
  /// landing. A stall never applies to one anyway — it is only ever derived for
  /// an item that has not moved since the diagnosis, so nothing is running.
  ///
  /// The reason names the STALL rather than reusing `_supersededReason`,
  /// because the two are different facts and merging them would recreate the
  /// defect: `superseded` says the item moved away from the work, this says the
  /// item is exactly where the work is and the work cannot start.
  Future<List<String>> _retireStalledJobsForItem(
    WorkItem item,
    SchedulerStall stall,
  ) async {
    final retired = <String>[];
    for (final job in await _jobStore.listJobsForWorkItem(item.workItemId)) {
      if (job.isTerminal) continue;
      if (job.state != JobState.queued && job.state != JobState.retryWaiting) {
        continue;
      }
      if (job.jobType != _definition.jobType) continue;
      await _queue.cancelQueued(
        job: job,
        reason:
            'stalled: this lane has stopped launching work for this item. '
            '${stall.reason}',
        // NOT `supersessionCapFired`. This is a consequence of the cap, not a
        // fresh firing of it, and recording it as one would let a stall
        // re-derive itself from its own withdrawal — the loop this whole
        // mechanism exists to end.
        eventPayload: const {'stalledJobWithdrawn': true},
      );
      retired.add(job.jobId);
    }
    return retired;
  }

  /// Public cancellation entrypoint: queued/retryWaiting jobs are cancelled
  /// durably here; claimed/running jobs are cancelled through the worker and
  /// converge to `cancelled` via outcome adoption.
  Future<Job> cancelJob(String jobId, String reason) async {
    final job = (await _jobStore.readJob(jobId))!;
    switch (job.state) {
      case JobState.queued:
      case JobState.retryWaiting:
        return _queue.cancelQueued(job: job, reason: reason);
      case JobState.claimed:
      case JobState.running:
        if (job.workerId != null) {
          await _dispatch.cancel(job.workerId!, reason);
        }
        return (await _jobStore.readJob(jobId))!;
      case JobState.succeeded:
      case JobState.failed:
      case JobState.cancelled:
        return job;
    }
  }
}

/// Default definition registered for the demo and used by
/// [Scheduler.definition] wiring in fixtures.
const JobDefinition defaultImplementFeatureDefinition = JobDefinition(
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: {WorkerCapability.linux},
  entryStates: {WorkItemState.designNotRequired, WorkItemState.designApproved},
  priority: JobPriority.normal,
  maxAttempts: 2,
);

/// Design revision job: produces a design revision in Penpot.
///
/// ## Why the policy probe is NOT skipped here
///
/// It used to be, and that bypass is what let this definition join the defect
/// class this file's [EntryHopper] exists to close: with the probe skipped,
/// [RunnableWorkEvaluator] answered "runnable" for EVERY state in
/// [JobDefinition.entryStates] without asking the policy anything, including
/// `designRejected` — and `designRejected -> agentExecuting` is not an edge in
/// the transition table, so the coordinator refused every attempt. Each refusal
/// burned a real worktree prepare before it was even reached, and the scheduler
/// (correctly, as a supersession) put the job straight back in the queue. The
/// definition declared a route the graph does not have, and the bypass is how a
/// declaration can disagree with the graph without anything noticing.
///
/// With the probe live the disagreement cannot be expressed: `designRequired`
/// still probes `designRequired -> agentExecuting`, which the policy accepts,
/// and `designRejected` probes `designRejected -> agentExecuting`, which it
/// refuses — so a rejected design is `noAction` and is never enqueued at all.
///
/// ## And `designRejected` stays an entry state, but the probe is live
///
/// `designRejected` is named and unreachable at once: the table gives it
/// exactly one out-edge, to `designInReview`, which is the design REVIEWER's
/// entry state, so there is no route from a rejected design to an execution
/// this job type could dispatch. Under the old `skipWorkflowPolicyCheck` the
/// probe answered "runnable" regardless and that contradiction reached the
/// coordinator on every tick — five jobs and five worker executions for one
/// item, measured.
///
/// With the probe live the contradiction is inert: `RunnableWorkEvaluator`
/// asks the policy about `designRejected -> agentExecuting`, the policy
/// refuses, and the state is `noAction`. Nothing is enqueued, nothing is
/// dispatched, nothing is burned.
///
/// The state is KEPT rather than deleted on purpose. It is a declared route
/// waiting for its edge: the moment `workflow_engine` grows a
/// `designRejected -> designRequired` edge — the design agent's own entry
/// state, which is where a re-design belongs — the probe accepts it and design
/// revision resumes with no change here. Deleting it would take that with it.
///
/// ## And it is not made dispatchable by declaring a hop
///
/// The only edge `designRejected` has leads to `designInReview`, which is in no
/// entry set of THIS definition. Declaring that hop would leave the item in a
/// state nothing dispatches, so the next tick would retire the job as
/// superseded and the work would be stranded having moved for nothing.
/// [EntryHopper] refuses such a hop by construction rather than by this
/// definition's restraint, and `entry_hop_drift_guard_test.dart` fails on the
/// declaration by name.
const JobDefinition designRevisionDefinition = JobDefinition(
  jobType: JobType.designRevision,
  requiredRole: AgentRole.designAgent,
  requiredCapabilities: {
    WorkerCapability.penpotWrite,
    WorkerCapability.visualDesign,
  },
  entryStates: {WorkItemState.designRequired, WorkItemState.designRejected},
  priority: JobPriority.normal,
  maxAttempts: 3,
);

/// Design review job: independently reviews a design revision produced by
/// a different worker. Must exclude the designer's execution.
const JobDefinition designReviewDefinition = JobDefinition(
  jobType: JobType.designReview,
  requiredRole: AgentRole.designReviewer,
  requiredCapabilities: {
    WorkerCapability.penpotRead,
    WorkerCapability.designReview,
  },
  entryStates: {WorkItemState.designInReview},
  priority: JobPriority.high,
  maxAttempts: 2,
  skipWorkflowPolicyCheck: true,
);

/// Builds a dedupe key for design revision jobs: (workItemId, jobType).
/// Only one active design revision job per work item at a time.
String designRevisionDedupeKey(WorkItem item, JobDefinition definition) =>
    '${item.workItemId}:${definition.jobType.wire}';

/// Builds a dedupe key for design review jobs: (workItemId, designRevisionId, jobType).
/// Prevents duplicate reviews of the same revision. Reads designRevisionId from
/// WorkItem.metadata['designRevisionId'] (set by workflow on transition to designInReview).
String designReviewDedupeKey(WorkItem item, JobDefinition definition) {
  final revisionId = item.metadata?['designRevisionId'] as String?;
  return '${item.workItemId}:${revisionId ?? 'unknown'}:${definition.jobType.wire}';
}

/// Builds an instruction for design revision jobs.
String designRevisionInstruction(WorkItem item, JobDefinition definition) =>
    'Produce a design revision for "${item.title}" (${item.workItemId}) in Penpot.';

/// Builds an instruction for design review jobs.
String designReviewInstruction(WorkItem item, JobDefinition definition) =>
    'Review the design revision for "${item.title}" (${item.workItemId}) in Penpot. '
    'Provide independent assessment without consulting the designer.';

/// Builds a worker execution request for design revision jobs.
Future<WorkerExecutionRequest> designRevisionRequest(
  Job job,
  SchedulerWorkload workload,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
  return WorkerExecutionRequest(
    workerExecutionId: 'wx-${job.jobId}',
    workItemId: job.workItemId,
    repositoryPath: workload.repositoryPath,
    startingRevision: workload.startingRevision,
    requiredCapabilities: job.requiredCapabilities,
    role: job.requiredRole,
    instruction: job.instruction,
    timeoutSeconds: workload.timeoutSeconds,
    runtimeTypeId: workload.runtimeTypeId,
    cleanupPolicy: workload.cleanupPolicy,
    runtimeConfig: runtimeConfig,
  );
}

/// Builds a worker execution request for design review jobs.
/// Includes excludedExecutionIds to enforce independence at dispatch.
/// Reads designerExecutionId from WorkItem.metadata['designerExecutionId']
/// (set by workflow on transition to designInReview).
Future<WorkerExecutionRequest> designReviewRequest(
  Job job,
  SchedulerWorkload workload,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  final designerExecutionId = item.metadata?['designerExecutionId'] as String?;
  final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
  return WorkerExecutionRequest(
    workerExecutionId: 'wx-${job.jobId}',
    workItemId: job.workItemId,
    repositoryPath: workload.repositoryPath,
    startingRevision: workload.startingRevision,
    requiredCapabilities: job.requiredCapabilities,
    role: job.requiredRole,
    instruction: job.instruction,
    timeoutSeconds: workload.timeoutSeconds,
    runtimeTypeId: workload.runtimeTypeId,
    cleanupPolicy: workload.cleanupPolicy,
    excludedExecutionIds: designerExecutionId != null
        ? [designerExecutionId]
        : const [],
    runtimeConfig: runtimeConfig,
  );
}

const JobDefinition engineeringReviewDefinition = JobDefinition(
  jobType: JobType.engineeringReview,
  requiredRole: AgentRole.engineeringReviewer,
  requiredCapabilities: {WorkerCapability.engineeringReview},
  entryStates: {WorkItemState.agentCompleted},
  priority: JobPriority.high,
  maxAttempts: 2,
  // SKIP the local policy probe. `RunnableWorkEvaluator.evaluate` would ask the
  // policy for `agentCompleted -> reviewInProgress` with a context that can
  // only supply `{'agentAvailable': true, 'capabilitiesMatch': true}`, and that
  // edge also carries `GuardConditions.agentResultValid()` — which needs the
  // IMPLEMENTER's completed `AgentResult` under `context['agentResult']`. The
  // scheduler has no execution of its own and cannot supply it, so the probe
  // reports `noAction` and the job is never enqueued.
  //
  // The REAL transition is still enforced by the workflow engine, at the
  // coordinator's `ExecutionCoordinator.execute` — which DOES supply the
  // implementer's result (see the reviewer branch there). This is the same
  // design-then-review split `designReviewDefinition` already relies on.
  skipWorkflowPolicyCheck: true,
  targetState: WorkItemState.reviewInProgress,
);

/// Builds a dedupe key for engineering review jobs: (workItemId, jobType[, attempt]).
/// Only one active engineering review job per work item per attempt at a time.
///
/// ## WHY THE ATTEMPT SUFFIX EXISTS
///
/// `JobQueue.enqueueIfAbsent` resolves a dedupe key that ANY job already holds,
/// terminal or not. The first engineering review dispatched for a work item
/// therefore burns `'<workItemId>:engineering_review'` for ever, and the SECOND
/// time the item reaches `agentCompleted` holding a reviewable commit the
/// enqueue returns `created: false`: the re-review silently does nothing, and
/// the item sits at a dispatchable state with an artifact nobody has read and
/// no job running.
///
/// That is the same defect `triageDefectDedupeKey` was written to close, and
/// it is closed the way `implementFeatureDedupeKey` was closed when `OD-3`
/// moved rework off the triage lane: the same durable `triageAttempt` marker,
/// read through the same reader ([DurableWorkflowEngine.readTriageAttempt])
/// that stamps it ([DurableWorkflowEngine.nextTriageAttempt]). One counter,
/// one reader, one rule.
///
/// Migration `20261014093000000` already named this key, by its line number,
/// as the one thing it could not reach: its own banner records that the two
/// `agent_completed` items it repaired "were blocked by a CONSUMED
/// `engineering_review` dedupe key" that carries no suffix, and that returning
/// them to triage "carries them back to `agent_completed`, where they MAY
/// RE-STRAND ON THE REVIEW KEY". This is that.
///
/// ## WHY THIS LANE SHARES THAT COUNTER INSTE OF HAVING ONE OF ITS OWN
///
/// Because the two counters would answer the same question. `triageAttempt`
/// is not a count of retries — its own documentation says so — it is the count
/// of times this item has been SENT BACK INTO PRODUCTION, and a second
/// engineering review is due exactly when that has happened. `(agentExecuting,
/// agentCompleted)` is the ONLY edge into `agentCompleted`
/// (`work_item_transitions.dart`), so a reviewable artifact arrives at this
/// lane's entry state only by a producer running again, and a producer runs
/// again only because a person pressed retry, a person resolved a rework or
/// reject, or this lane's own completion inflow re-entered the item — the
/// three routes that stamp the marker. A second counter would count a subset of
/// those same events under a second name.
///
/// It also removes a hazard rather than adding one. `implementFeatureDedupeKey`
/// already builds the IMPLEMENTATION lane's key out of this counter, so a
/// separate review counter would put two counters over one intent — the
/// "two writers, two different rules, one counter" failure the marker itself
/// documents, now with two counters — in exchange for no new information.
///
/// ## THE COUPLING'S CONSEQUENCE, RESTATED NOW THE BOUND IS GONE
///
/// This section used to say that sharing ties the key's freshness to
/// `maxImplementationInflows`, because the completion inflow checked that bound
/// on this very marker before writing: once an item read 3 the automatic route
/// stood down, the marker stopped moving on its own, and the item sat at
/// `agentCompleted` for `sched-review`. That is no longer true, and the
/// consequence recorded underneath it has changed with it.
///
/// Human decision `92d567e3-da03-4c43-99f4-e3726472f0ab` removed the bound
/// (`implementation_inflow.dart` records why). The marker now moves whenever
/// `agentCompleted -> implementationReady` is taken, with no ceiling, so the
/// `:a<n>` suffix this builder appends is no longer frozen by a spent budget.
///
/// ## THE RESIDUAL THAT SURVIVES, AND IS NARROWER
///
/// A SECOND exhausted review job on the same item, with no re-work in between,
/// would ask for the same `:a<n>` again and be refused — the same silent no-op,
/// one cycle later. It is narrower than it was, not closed: the unfrozen marker
/// means the item must first be sent back into production, which advances
/// `triageAttempt` and therefore builds a FRESH suffix. What the bound used to
/// do was freeze the marker on an item that was not going anywhere, so the
/// second refusal was reachable with nothing having happened at all. That
/// specific shape — an item parked at `agentCompleted` whose only remaining
/// history is a re-review request it cannot key — is the one this coupling
/// caused, and it is gone with the bound.
///
/// Closing that needs a discriminator that counts REVIEW attempts and is
/// advanced by whoever requests the re-review. That writer does not exist and
/// cannot be added beside this builder: `DurableWorkflowEngine` has no
/// metadata-only write (the only one is `transition(metadataMerge:)`, which
/// requires a state move, and this lane's item is already in the state it must
/// stay in), and the reader/writer pair belongs next to `nextTriageAttempt`
/// in `packages/workflow_store`. It is recorded as a routed discovery rather
/// than smuggled in here.
///
/// ## WHY THE ABSENT CASE IS BYTE-IDENTICAL TO TODAY
///
/// With no `triageAttempt` the key is exactly `'<workItemId>:engineering_review'`,
/// which is what every engineering review job already persisted under.
/// Re-spelling the default would orphan every one of them and, on the next
/// tick, mint a SECOND job for a review already in flight. That property is
/// not to be traded for anything.
///
/// ## WHY THE READING IS DELEGATED, NOT REPEATED
///
/// The marker is read by [DurableWorkflowEngine.readTriageAttempt], which is
/// the same reader `nextTriageAttempt` uses to produce the value stamped in
/// the first place. Two copies of "how a marker is read" is how a writer and a
/// reader come to disagree about which numbers are attempt numbers, and that
/// disagreement would not throw — it would build a key nothing holds and
/// enqueue nothing.
///
/// That reader also owns the unreadable case: a marker that is PRESENT but is
/// not an int, a whole-valued double or a numeric String throws
/// [FormatException] rather than falling back to the historical key, because
/// that key is already consumed by the terminal job the re-review exists to
/// replace. See that method for the full argument; it is stated once, here, to
/// record that this builder inherits it rather than choosing it.
///
/// ## WHAT HAPPENS WHEN THAT THROW FIRES
///
/// The caller guards it. `Scheduler.tick` builds this key inside a per-item
/// `try` and reports a throw on `SchedulerTickResult.entryHopRefused` with
/// nothing enqueued and nothing consumed, so one unreadable marker costs that
/// item and not the tick — and the composition root's
/// `engineeringReviewMissingArtifact` is untouched, because no job is ever
/// created to report. That guard is the only reason this builder is allowed to
/// throw at all: unguarded, the throw escaped `tick()` and took every OTHER
/// reviewable item's tick result with it, on every tick, for ever.
String engineeringReviewDedupeKey(WorkItem item, JobDefinition definition) {
  final base = '${item.workItemId}:${definition.jobType.wire}';
  final attempt = DurableWorkflowEngine.readTriageAttempt(item);
  if (attempt == null) return base;
  return '$base:a$attempt';
}

/// The four [ReviewVerdict] wire tokens, as a `"a" | "b"` alternation, rendered
/// from the enum rather than transcribed.
///
/// Transcribing them is what `triageDefectInstruction` had to do by hand, and
/// hand-transcribed enumerations are how a prompt ends up documenting a value the
/// contract does not serialise — see that function's own drift-guard note, and
/// `test/engineering_review_prompt_contract_test.dart` for the same guard here.
/// Rendering them means adding or renaming a [ReviewVerdict] member changes this
/// prompt on the next build instead of silently un-parsing reviewer output.
String _reviewVerdictAlternation() =>
    ReviewVerdict.values.map((v) => '"${v.wire}"').join(' | ');

/// The documented shape of one entry in the reviewer's `findings` array: the
/// fields the REVIEWER legitimately owns.
///
/// [DesignFinding] also requires `findingId`, `revisionId`, `reviewExecutionId`,
/// `createdAt` and `version`, which are platform identity rather than review
/// content: a reviewer cannot know its own `reviewExecutionId`. Asking for them
/// would invite invented identifiers, and omitting them without a matching
/// change at the reader would have every finding dropped as unparseable — which
/// is exactly what `engineering_review_gate.dart` used to do. The gate stamps
/// those five from the run it is already holding. See `_readReviewVerdict`.
String _reviewFindingShape() =>
    '''{
    "severity": ${DesignFindingSeverity.values.map((v) => '"${v.wire}"').join(' | ')},
    "dimension": "<the area you assessed, e.g. correctness, tests, security>",
    "evidence": "<file:line, command and output, or commit that shows it>",
    "requiredCorrection": "<what must change; empty string if nothing must>",
    "affectedSurface": "<the files or surfaces the finding is about>"
  }''';

/// Builds an instruction for engineering review jobs.
///
/// ## WHY THIS IS A PAYLOAD CONTRACT AND NOT A SENTENCE
///
/// This used to be two lines that asked for "an engineering review verdict" in
/// prose, and it is the whole reason no verdict was ever recorded. The review
/// lane's only failure mode in QA was four reviews that ran to completion and
/// produced real, specific findings — and four work items left at
/// `review_in_progress` with `structuredResultJson` = `{}` and no decision,
/// because nothing ever told the reviewer what to emit or where.
///
/// Three separate facts make that prompt's silence fatal, and each is verifiable:
///
///  * **It is the only instruction the reviewer gets.** `OpenCodeSession` opens
///    its session with `{'cwd': ..., 'mcpServers': []}`
///    (`packages/agent_runtime/lib/src/adapters/opencode/opencode_session.dart`)
///    — no agent name, no system prompt, no role. Whatever this string says is
///    the entire specification the reviewer has.
///  * **The reader is strict.** `_readReviewVerdict` in
///    `apps/server/lib/src/review/engineering_review_gate.dart` reads
///    `structuredResult['verdict']` and feeds it to `ReviewVerdict.fromWire`,
///    which throws `FormatException` on anything that is not an exact wire
///    token. `CHANGES_REQUIRED`, `changesRequired` and `APPROVED` all fail.
///  * **Nothing recovers a prose answer.** A completed turn with no JSON object
///    yields `structuredResult == {}` plus a `structured_result_absent`
///    diagnostic, and b1 correctly refuses to invent a verdict from that — so
///    the item parks. The prompt is therefore load-bearing: without a stated
///    shape there is no verdict, and without a verdict there is no decision.
///
/// ## WHY IT DOES NOT STEER THE VERDICT
///
/// The reviewer is told what each of the four verdicts MEANS and that the
/// platform records whichever one comes back. It is not told which one to
/// reach, no verdict is named as a default or as an expected answer, and the
/// single most likely failure mode of a prompt like this one — a model choosing
/// a token because the shape demands one — is forbidden explicitly.
///
/// "Found nothing blocking" is stated as a real outcome that has an honest
/// answer among the four, because a reviewer that has genuinely found nothing
/// must be able to say so without inventing a minor finding in order to
/// justify a harsher token. That is the opposite of a nudge, and it is
/// symmetric with the rule against softening a real one — and note that it
/// names no token, because the WHAT-EACH-VERDICT-MEANS block above already
/// maps every one of them exactly once, which is what keeps the presentation
/// symmetric (`test/engineering_review_prompt_contract_test.dart` asserts
/// that each token appears the same number of times).
///
/// This is the same discipline `triageDefectInstruction` follows, which is why
/// the triage lane produces parseable output and this one did not.
/// `test/engineering_review_prompt_contract_test.dart` is the drift guard.
String engineeringReviewInstruction(WorkItem item, JobDefinition definition) {
  return '''Review the implementation for "${item.title}" (${item.workItemId}).

YOUR TASK:
Independently review the change at the revision you were given. Verify it
yourself rather than taking any claim about it on trust, and do not consult the
work you are reviewing. Then report the conclusion you actually reached.

OUTPUT FORMAT:
Your final message must be a single JSON object and nothing else — no prose
before it, none after it. It must have these fields:

{
  "verdict": ${_reviewVerdictAlternation()},
  "findings": [${_reviewFindingShape()}],
  "summary": "<2-3 sentences: what you checked and what you concluded>"
}

WHAT EACH VERDICT MEANS:
- "approved"            no blockers found.
- "approved_with_minor_findings"
                        no blockers, but minor or advisory points are worth recording.
- "changes_required"    the change must be corrected before it is accepted.
- "rejected"            the change is not acceptable as an approach.

RULES:
1. "verdict" MUST be spelled exactly as one of the four tokens above, using those exact
   lowercase tokens. No other spelling — no capitals, no camelCase, no trailing space —
   is accepted.
2. Report the verdict you actually reached. All four are valid answers and the platform
   records whichever one you return. If this field is missing or unreadable, NO verdict
   is recorded at all and the item stops for a person; the platform never supplies one
   on your behalf.
3. Do not report a problem you did not find, and do not soften one you did.
   A review that finds nothing blocking is a real result with an honest answer
   among the tokens above; it is not a gap to be filled with an invented
   observation, and it is not a worse review than one that found something.
4. "findings" MUST be an array — use [] when you have none. Put every finding that
   supports your verdict in it.
5. Do NOT include any prose outside the JSON output.''';
}

/// Builds a worker execution request for engineering review jobs.
Future<WorkerExecutionRequest> engineeringReviewRequest(
  Job job,
  SchedulerWorkload workload,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
  return WorkerExecutionRequest(
    workerExecutionId: 'wx-${job.jobId}',
    workItemId: job.workItemId,
    repositoryPath: workload.repositoryPath,
    startingRevision: workload.startingRevision,
    requiredCapabilities: job.requiredCapabilities,
    role: job.requiredRole,
    instruction: job.instruction,
    timeoutSeconds: workload.timeoutSeconds,
    runtimeTypeId: workload.runtimeTypeId,
    cleanupPolicy: workload.cleanupPolicy,
    runtimeConfig: runtimeConfig,
  );
}

class _DispatchOutcome {
  const _DispatchOutcome({
    this.dispatched = false,
    this.terminalJob,
    this.capacityDenied = false,
    this.blockedArtifactMissing = false,
  });

  final bool dispatched;
  final Job? terminalJob;

  /// The global capacity budget was full, so this job was not attempted. The
  /// job is untouched and still queued.
  final bool capacityDenied;

  /// The job's [WorkloadResolver] returned null: the artifact it must operate
  /// on could not be resolved, so no request was built. The job is untouched
  /// and still queued, and the tick surfaces it on
  /// [SchedulerTickResult.blockedArtifactMissing] for the composition root to
  /// turn into a blocking human decision.
  final bool blockedArtifactMissing;
}

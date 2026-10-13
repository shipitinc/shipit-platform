import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// The one actor the scheduler acts as everywhere it writes workflow state:
/// the runnability probe's `orchestrator`, the zombie reclaim's `orchestrator`,
/// and the intermediate-hop transition's `orchestrator`.
///
/// Declared once because the transition table guards these writes by actor
/// identity. Three separately-spelled copies of the same actor would be three
/// chances to drift, and a drift here is invisible until a transition the
/// platform depends on is refused for a reason no log explains.
const WorkflowActor schedulerOrchestratorActor = WorkflowActor(
  actorId: 'scheduler',
  actorType: ActorType.orchestrator,
);

/// What the scheduler may do with a work item on the current tick.
enum RunnableWorkStatus {
  /// The item may start a bounded agent execution right now.
  runnable,

  /// The item is parked behind a blocking human decision and consumes ZERO
  /// worker capacity, zero agent sessions, zero polling processes.
  blocked,

  /// The item has a terminal lifecycle state.
  terminal,

  /// The item is mid-lifecycle but not scheduled for execution by this slice
  /// (planning, review, QA, deployment are owned by their own gates).
  noAction,
}

/// Workflow-legal routing for a job type: which entering states may dispatch,
/// which role implementation gets stamped, and what instruction to build.
@immutable
class JobDefinition {
  const JobDefinition({
    required this.jobType,
    required this.requiredRole,
    required this.requiredCapabilities,
    required this.entryStates,
    this.priority = JobPriority.normal,
    this.maxAttempts = 2,
    this.targetState = WorkItemState.agentExecuting,
    this.entryProbeTargets = const {},
    this.skipWorkflowPolicyCheck = false,
  });

  final JobType jobType;
  final AgentRole requiredRole;
  final Set<WorkerCapability> requiredCapabilities;
  final Set<WorkItemState> entryStates;
  final JobPriority priority;
  final int maxAttempts;

  /// The workflow state that a successful execution should transition to.
  /// Defaults to [WorkItemState.agentExecuting] for standard agent jobs.
  final WorkItemState targetState;

  /// Per-entry-state overrides for the far side of the legality probe, for
  /// entry states whose route to execution is NOT a direct
  /// `<entry> -> targetState` edge.
  ///
  /// [targetState] is not an executed transition. Nothing in the scheduler
  /// transitions a work item; [RunnableWorkEvaluator] uses this value purely
  /// as the far side of the QUESTION it puts to the workflow policy — "may an
  /// execution begin from this state?" — and the answer comes from the policy,
  /// never from a local copy of the graph. For most entry states the honest
  /// question really is `agentExecuting`, which is what the default says.
  ///
  /// An entry state that cannot start an execution directly has to ask a
  /// different question, and this map is how it asks it. `reviewRejected` is
  /// the case that exists for: a human decided that a rejected engineering
  /// review KEEPS its own state rather than collapsing into `designNotRequired`
  /// (so the operator can see "you rejected this" as its own state), and that
  /// state is still dispatchable so the rejection is not a dead end. Its only
  /// legal hop toward execution is `reviewRejected -> designNotRequired` — an
  /// ordinary orchestrator edge into an ordinary entry state — so that is the
  /// hop named here and the hop the policy is asked about. The question is
  /// still the policy's to answer; only its target is now precise.
  ///
  /// Overriding per entry state rather than widening [targetState] is
  /// deliberate. [targetState] is ONE value for the whole definition, and it
  /// cannot honestly mean both "start an execution directly"
  /// (`designNotRequired`, `designApproved`) and "legally return to a
  /// dispatchable entry state" (`reviewRejected`) at once. Collapsing the two
  /// would either ask an illegal question or stop asking the question at all
  /// (`skipWorkflowPolicyCheck`), and the second of those abandons the
  /// "ask the policy, never a local copy of the graph" invariant for the
  /// states that were getting it right.
  final Map<WorkItemState, WorkItemState> entryProbeTargets;

  /// The far side of the legality probe for [entryState]: its own override
  /// when one is declared, and [targetState] otherwise.
  WorkItemState probeTargetFor(WorkItemState entryState) =>
      entryProbeTargets[entryState] ?? targetState;

  /// If true, skip the workflow policy check (for design/review jobs that
  /// don't map to standard agentExecuting transitions).
  final bool skipWorkflowPolicyCheck;
}

/// Derives, for one work item, whether the scheduler may dispatch it, by
/// asking the WORKFLOW POLICY whether an execution is legal *and* checking the
/// job type's scheduling-intent boundary.
///
/// The scheduler owns only "what kinds of work the platform launches
/// automatically". It does NOT duplicate the transition graph: the legality of
/// the hop an entry state takes toward execution is always verified through
/// [WorkflowEngine.evaluateWorkItemTransition] — `agentExecuting` for an entry
/// state that starts an execution directly, and the entry state's own declared
/// hop otherwise (see [JobDefinition.entryProbeTargets]) — so if the policy
/// changes the scheduler can never enqueue something the policy forbids.
///
/// Entry-state intent is deliberately narrower than the workflow graph:
/// `designNotRequired`, `designApproved` and `reviewRejected` are "awaiting an
/// execution". `agentFailed` is still NOT auto-enqueued: reworking a failed
/// coding result routes through the workflow's correction/review gate, not an
/// automatic LLM re-run.
///
/// `reviewRejected` used to be listed here as not auto-enqueued. That was
/// true when the state was inert, and it stopped being true when a human chose
/// to keep the state (rather than collapse a rejected review into
/// `designNotRequired`) and make it dispatchable — a rejected engineering
/// review has to re-enter triage, or the rejection is a dead end with the
/// decision already answered. See [JobDefinition.entryProbeTargets] for why
/// making it dispatchable needed more than adding the state to `entryStates`.
class RunnableWorkEvaluator {
  const RunnableWorkEvaluator({required this.policy});

  final WorkflowEngine policy;

  static const WorkflowActor _scheduler = schedulerOrchestratorActor;

  RunnableWorkStatus evaluate(WorkItem item, JobDefinition definition) {
    if (item.isTerminal) return RunnableWorkStatus.terminal;
    if (item.state == WorkItemState.waitingForHumanDecision) {
      return RunnableWorkStatus.blocked;
    }
    if (!definition.entryStates.contains(item.state)) {
      return RunnableWorkStatus.noAction;
    }

    // Design/review jobs may skip workflow policy check if they don't map
    // to standard agentExecuting transitions.
    if (definition.skipWorkflowPolicyCheck) {
      return RunnableWorkStatus.runnable;
    }

    // Ask the policy, never a local copy of the graph. The far side of the
    // question is per entry state: `agentExecuting` for an entry state that
    // starts an execution directly, and that entry state's own declared hop
    // when the route to execution is not a direct edge (see
    // [JobDefinition.entryProbeTargets]).
    final transition = policy.evaluateWorkItemTransition(
      from: item.state,
      to: definition.probeTargetFor(item.state),
      trigger: TransitionTrigger.systemEvent,
      actor: _scheduler,
      context: const {'agentAvailable': true, 'capabilitiesMatch': true},
    );
    return transition.isValid
        ? RunnableWorkStatus.runnable
        : RunnableWorkStatus.noAction;
  }

  /// True when [item] can be dispatched to a worker under [definition],
  /// re-checked immediately before a claim so a human decision or terminal
  /// transition between enqueue and dispatch cannot slip through.
  Future<bool> isRunnable(Job job, WorkItem item, JobDefinition definition) {
    return Future.value(
      evaluate(item, definition) == RunnableWorkStatus.runnable,
    );
  }
}

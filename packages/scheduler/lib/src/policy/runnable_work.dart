import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';

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
  });

  final JobType jobType;
  final AgentRole requiredRole;
  final Set<WorkerCapability> requiredCapabilities;
  final Set<WorkItemState> entryStates;
  final JobPriority priority;
  final int maxAttempts;
}

/// Derives, for one work item, whether the scheduler may dispatch it, by
/// asking the WORKFLOW POLICY whether an execution is legal *and* checking the
/// job type's scheduling-intent boundary.
///
/// The scheduler owns only "what kinds of work the platform launches
/// automatically". It does NOT duplicate the transition graph: legality of
/// `state -> agentExecuting` is always verified through
/// [WorkflowEngine.evaluateWorkItemTransition], so if the policy changes the
/// scheduler can never enqueue something the policy forbids.
///
/// Entry-state intent is deliberately narrower than the workflow graph:
/// `designNotRequired` and `designApproved` are "awaiting an execution".
/// `agentFailed` and `reviewRejected` are NOT auto-enqueued: reworking a
/// failed coding result routes through the workflow's correction/review gate,
/// not an automatic LLM re-run.
class RunnableWorkEvaluator {
  const RunnableWorkEvaluator({required this.policy});

  final WorkflowEngine policy;

  static const WorkflowActor _scheduler = WorkflowActor(
    actorId: 'scheduler',
    actorType: ActorType.orchestrator,
  );

  RunnableWorkStatus evaluate(WorkItem item, JobDefinition definition) {
    if (item.isTerminal) return RunnableWorkStatus.terminal;
    if (item.state == WorkItemState.waitingForHumanDecision) {
      return RunnableWorkStatus.blocked;
    }
    if (!definition.entryStates.contains(item.state)) {
      return RunnableWorkStatus.noAction;
    }

    // Ask the policy, never a local copy of the graph.
    final transition = policy.evaluateWorkItemTransition(
      from: item.state,
      to: WorkItemState.agentExecuting,
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

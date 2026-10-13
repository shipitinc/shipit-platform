import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import 'runnable_work.dart';

/// What [EntryHopper.prepare] did with a work item before dispatch.
enum EntryHopStatus {
  /// The coordinator can begin an execution from here in ONE hop, so nothing
  /// was moved. This is the ordinary case for every entry state that declares
  /// no route of its own.
  direct,

  /// The definition declares an intermediate hop for this state and it was
  /// performed. [EntryHopResult.item] is the item AFTER the hop.
  performed,

  /// The definition declares no hop, or the one it declares is not available,
  /// so this item must NOT be dispatched this tick. Failing closed is the
  /// point: the alternative is dispatching into the coordinator's refusal.
  refused,

  /// The hop could not be completed inside the attempt budget because another
  /// writer kept moving the item. A delay, never a loss — the next tick
  /// re-reads and decides again.
  contended,
}

/// The outcome of preparing one item for dispatch, carrying the item as it is
/// now so a caller never acts on a stale read.
@immutable
class EntryHopResult {
  const EntryHopResult({required this.item, required this.status, this.reason});

  /// The item as it stands after preparation. Equal to the input when nothing
  /// was moved.
  final WorkItem item;

  final EntryHopStatus status;

  /// Why no hop was possible, in words an operator can act on. Null when a hop
  /// was performed or was not needed.
  final String? reason;

  /// Whether the scheduler may go on to enqueue and dispatch this item.
  bool get dispatchable =>
      status == EntryHopStatus.direct || status == EntryHopStatus.performed;
}

/// Performs the legal INTERMEDIATE hop a [JobDefinition] declares for an entry
/// state that cannot reach the definition's running state in one hop.
///
/// ## Why the scheduler, and why not the coordinator
///
/// The coordinator is authoritative and correct to refuse: it attempts the
/// direct `<entryState> -> agentExecuting` edge and the table has no such edge,
/// so it raises `WorkItemSupersededException` every time. It cannot fix that
/// itself, because the answer it needs — "which intermediate hop does THIS
/// definition intend for THIS entry state?" — lives in
/// [JobDefinition.entryProbeTargets], and the coordinator does not know the
/// definition. Teaching it would mean handing it the entry states too, i.e. a
/// second copy of a slice of the transition graph inside the one package whose
/// job is to obey the graph rather than enumerate it.
///
/// The scheduler is the only component that holds both halves: the definition
/// (and therefore the declared route) and the work item. It already owns
/// dispatch preparation and already moves work items for exactly this kind of
/// bookkeeping ([Scheduler._reclaimActor] in `scheduler.dart`), so it is the
/// layer at which the hop belongs. The coordinator keeps its single duty:
/// enforce the edge it is told to attempt.
///
/// ## Why nothing here enumerates the graph
///
/// Legality is asked of the POLICY for every decision, exactly as
/// [RunnableWorkEvaluator] does; no edge, guard or state name is written down
/// in this file. [JobDefinition.probeTargetFor] supplies the route and the
/// workflow engine supplies the verdict. A definition that declares a hop it
/// cannot take is refused here, not here-and-also in a test that forgot.
///
/// ## Why the direct edge is checked for EXISTENCE and the hop for VALIDITY
///
/// Those two questions are deliberately asked differently, because two
/// different actors answer them:
///
///  * "can the coordinator begin from here in one hop?" is answered by whether
///    the EDGE EXISTS at all. Its guards are not this class's business: the
///    engineering-review edge carries `agentResultValid()`, which needs the
///    implementer's completed `AgentResult` — something the scheduler has no
///    execution of and cannot supply, but which the coordinator supplies for
///    itself. Judging that edge's guards here would report a working route as
///    absent.
///  * "may the scheduler take the declared hop?" is answered by asking whether
///    the transition is fully VALID in the scheduler's own context, because the
///    scheduler is the actor that will perform the write and will be refused by
///    the engine if a guard fails. Asking only for the edge's existence would
///    queue a write that is certain to be rejected.
class EntryHopper {
  EntryHopper({
    required WorkflowEngine policy,
    required DurableWorkflowEngine engine,
    required JobDefinition definition,
    int maxAttempts = 3,
  }) : _policy = policy,
       _engine = engine,
       _definition = definition,
       _maxAttempts = maxAttempts;

  final WorkflowEngine _policy;
  final DurableWorkflowEngine _engine;
  final JobDefinition _definition;
  final int _maxAttempts;

  /// The scheduler's own context for asking about a transition. Byte-identical
  /// to the one [RunnableWorkEvaluator] probes with, deliberately: the hop IS
  /// that question made durable, so a hop this class considers available and a
  /// hop the probe considers legal can never disagree.
  static const Map<String, dynamic> _hopContext = {
    'agentAvailable': true,
    'capabilitiesMatch': true,
  };

  /// The name the transition policy gives a state pair that has no edge at
  /// all. Read from the engine's own verdict rather than compared against a
  /// private copy of the table.
  static const String _noEdgeGuard = 'legal_transition';

  /// Whether ANY edge `<from> -> <to>` exists in the policy, guards ignored.
  bool _edgeExists(WorkItemState from, WorkItemState to) {
    final transition = _policy.evaluateWorkItemTransition(
      from: from,
      to: to,
      trigger: TransitionTrigger.systemEvent,
      actor: schedulerOrchestratorActor,
      context: _hopContext,
    );
    return !transition.failedGuards.contains(_noEdgeGuard);
  }

  /// Whether the scheduler itself may take `<from> -> <to>`: edge present AND
  /// every guard satisfied in the scheduler's context.
  bool _canTransition(WorkItemState from, WorkItemState to) {
    return _policy
        .evaluateWorkItemTransition(
          from: from,
          to: to,
          trigger: TransitionTrigger.systemEvent,
          actor: schedulerOrchestratorActor,
          context: _hopContext,
        )
        .isValid;
  }

  /// Prepares [item] for dispatch: performs the definition's declared
  /// intermediate hop when one is needed and available, and otherwise reports
  /// plainly why this item must not be dispatched.
  ///
  /// NEVER moves an item that does not need moving, and never moves one it
  /// cannot legally move — a hop is a workflow transition like any other and is
  /// taken through the durable engine, so it is recorded in the transition
  /// history and guarded by the store's compare-and-swap exactly like every
  /// other write in this platform.
  Future<EntryHopResult> prepare(WorkItem item) async {
    var current = item;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      // The coordinator's own entry edge decides whether this class has
      // anything to do at all. When it exists, the ordinary dispatch path is
      // already correct and moving the item would be an unrequested write.
      //
      // `targetState`, and NEVER `probeTargetFor`: the probe target is
      // deliberately the same hop this method is deciding whether to take, so
      // asking about it here would always answer "the edge exists" and no hop
      // would ever be taken. What has to be checked is the edge the COORDINATOR
      // attempts, which is the definition's running state and the same value
      // for every entry state.
      final runningState = _definition.targetState;
      if (_edgeExists(current.state, runningState)) {
        return EntryHopResult(item: current, status: EntryHopStatus.direct);
      }

      final declared = _definition.entryProbeTargets[current.state];
      if (declared == null) {
        return EntryHopResult(
          item: current,
          status: EntryHopStatus.refused,
          reason:
              'work item ${current.workItemId} is ${current.state.wire}, and no '
              'route to ${runningState.wire} exists for a '
              '${_definition.jobType.wire} job: the transition table has no '
              '${current.state.wire} -> ${runningState.wire} edge and the '
              'definition declares no intermediate hop for it. Not dispatching, '
              'because the coordinator would refuse every attempt and each one '
              'would cost a real worker execution. Nothing ran.',
        );
      }

      final refusal = _refusalFor(current, declared, runningState);
      if (refusal != null) {
        return EntryHopResult(
          item: current,
          status: EntryHopStatus.refused,
          reason: refusal,
        );
      }

      try {
        final moved = await _engine.transition(
          workItemId: current.workItemId,
          to: declared,
          trigger: TransitionTrigger.systemEvent,
          actor: schedulerOrchestratorActor,
          context: _hopContext,
          reason:
              'scheduler took the intermediate hop ${current.state.wire} -> '
              '${declared.wire} that '
              '${_definition.jobType.wire} declares for this entry state, so '
              'the execution can begin from a state the coordinator can act on',
        );
        return EntryHopResult(
          item: moved,
          status: EntryHopStatus.performed,
          reason:
              '${current.state.wire} -> ${declared.wire}: the hop '
              '${_definition.jobType.wire} declares, taken so an execution can '
              'start from there.',
        );
      } on WorkflowTransitionRejectedException {
        // Someone else owns the item now — a human, a gate, another tick. Not
        // an error here: re-read and let the ordinary runnability rules decide
        // what the item's new state means.
        final refreshed = await _reread(current.workItemId);
        if (refreshed == null) {
          return EntryHopResult(
            item: current,
            status: EntryHopStatus.contended,
            reason: _contendedReason(current),
          );
        }
        current = refreshed;
        continue;
      } on ConcurrentModificationException {
        // Lost the item's compare-and-swap: a legal decision against a state
        // that moved underneath the read. Re-read and decide again.
        final refreshed = await _reread(current.workItemId);
        if (refreshed == null) {
          return EntryHopResult(
            item: current,
            status: EntryHopStatus.contended,
            reason: _contendedReason(current),
          );
        }
        current = refreshed;
        continue;
      }
    }
    return EntryHopResult(
      item: current,
      status: EntryHopStatus.contended,
      reason: _contendedReason(current),
    );
  }

  /// Why the declared hop must not be taken, or null when it is available.
  ///
  /// Two guards, both structural rather than incidental — together they are
  /// what makes "a refused hop cannot strand the item" true by construction
  /// rather than by luck for the route that exists today:
  ///
  ///  * the policy must accept it in the scheduler's context, because the
  ///    scheduler is the actor that performs it; and
  ///  * it must land on an entry state OF THIS DEFINITION. A hop onto a state
  ///    this definition cannot dispatch from would leave the item somewhere
  ///    nothing runs it — it would be retired on the next tick as superseded —
  ///    so a definition that cannot finish the route is refused rather than
  ///    half-performed.
  String? _refusalFor(
    WorkItem item,
    WorkItemState hopTarget,
    WorkItemState runningState,
  ) {
    if (!_canTransition(item.state, hopTarget)) {
      return 'work item ${item.workItemId} is ${item.state.wire}, which declares '
          'the intermediate hop ${item.state.wire} -> ${hopTarget.wire}, but the '
          'workflow policy does not let the scheduler take it in the scheduler\'s '
          'own context. Not dispatching: the coordinator would refuse '
          '${item.state.wire} -> ${runningState.wire} every time. Nothing ran.';
    }
    if (!_definition.entryStates.contains(hopTarget)) {
      final entryStates = _definition.entryStates.map((s) => s.wire).toList()
        ..sort();
      return 'work item ${item.workItemId} is ${item.state.wire}, which declares '
          'the intermediate hop ${item.state.wire} -> ${hopTarget.wire}, but '
          '${hopTarget.wire} is not an entry state for '
          '${_definition.jobType.wire} (${entryStates.join(', ')}), so nothing '
          'would dispatch the item after the hop. Not moving it: that would '
          'strand the work in a state this job type never serves. Nothing ran.';
    }
    return null;
  }

  String _contendedReason(WorkItem item) =>
      'work item ${item.workItemId} kept moving while the scheduler prepared '
      '${item.state.wire} for a ${_definition.jobType.wire} job, so no hop was '
      'attempted this tick. Deferring to the next tick; nothing ran and nothing '
      'was consumed.';

  Future<WorkItem?> _reread(String workItemId) async {
    try {
      return await _engine.loadWorkItem(workItemId);
    } catch (_) {
      // An unreadable item is "cannot confirm", which fails closed below.
      return null;
    }
  }
}

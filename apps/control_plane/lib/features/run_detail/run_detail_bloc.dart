import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';
import '../../data/operator_attestation.dart';
import '../../shared/transition_copy.dart';
import 'operator_action_copy.dart';
import 'run_detail_event.dart';

/// Sentinel for a `copyWith` argument that must be able to CLEAR a nullable
/// field.
///
/// `?? this.x` cannot express "set it to null", which this state genuinely
/// needs: a resolved action has to take `pendingAction` back to null, and a
/// null-aware default would silently keep the old value and leave a confirm
/// strip on screen for an action that already committed. The repo already uses
/// this shape for `Job.copyWith` (`job.dart:15`, `const Object _unset`).
const Object _unset = Object();

class RunDetailBloc extends Bloc<RunDetailEvent, RunDetailState> {
  RunDetailBloc({required this._runId, required this._repository})
    : super(const RunDetailState()) {
    on<RunDetailLoaded>(_onLoaded);
    on<RunDetailActionStarted>(_onActionStarted);
    on<RunDetailActionCancelled>(_onActionCancelled);
    on<RunDetailActionSubmitted>(_onActionSubmitted);
  }

  final String _runId;
  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(
    RunDetailLoaded event,
    Emitter<RunDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final detail = await _repository.inspectWorkItem(_runId);

      // The design explains *what is held up* and *what we suggest*. Both are
      // separate durable records, fetched here so the screen never guesses.
      final jobs = await _repository.jobsForWorkItem(_runId);
      final heldUp = jobs
          .where((j) => j.state == 'queued' || j.state == 'retryWaiting')
          .map((j) => j.jobId)
          .toList();

      // Fetch model executions for this work item
      final modelExecutionsPage = await _repository.listModelExecutions(
        workItemId: _runId,
        limit: 100,
        offset: 0,
      );
      final modelExecutions = modelExecutionsPage.items;

      String? recommendation;
      String? haltedState;
      if (detail.workItem.blockingHumanDecisionId != null) {
        try {
          final decision = await _repository.inspectDecision(_runId);
          recommendation = decision.recommendation;
          haltedState = decision.context?.workflowState;
        } on Object {
          // A missing recommendation is not a page failure.
        }
      }

      // The action panel is a SECOND, separate read. A failure here is
      // deliberately NOT a page failure: the durable record, the timeline and
      // the existing right-column text are all still true without it, and
      // taking the whole screen down over the new surface would make this
      // change strictly less reliable than the one it replaces.
      WorkItemActionContextResponse? actionContext;
      String? actionContextError;
      try {
        actionContext = await _repository.workItemActionContext(_runId);
      } on Object {
        actionContextError = 'The actions for this work could not be read.';
      }

      emit(
        state.copyWith(
          isLoading: false,
          heldUpJobs: heldUp,
          recommendation: recommendation,
          haltedState: haltedState,
          artifacts: detail.workItem.artifactRefs ?? const [],
          runId: _runId,
          name: detail.workItem.title,
          description: detail.workItem.description?.trim() ?? '',
          state: detail.workItem.state,
          blockingHumanDecisionId: detail.workItem.blockingHumanDecisionId,
          agent: 'opencode',
          category: 'workflow',
          startedAt: detail.workItem.createdAt,
          events: detail.transitionHistory
              .map(
                (t) => RunEvent(
                  type: t.toState,
                  message: plainTransitionMessage(t.fromState, t.toState),
                  raw: rawTransitionPair(t.fromState, t.toState),
                  timestamp: t.transitionedAt,
                  reason: t.reason,
                ),
              )
              .toList(),
          modelExecutions: modelExecutions,
          actionContext: actionContext,
          actionContextError: actionContextError,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void _onActionStarted(
    RunDetailActionStarted event,
    Emitter<RunDetailState> emit,
  ) {
    emit(
      state.copyWith(
        pendingAction: event.action,
        // The previous outcome is cleared when a NEW action starts, so a stale
        // announcement is never sitting next to a fresh confirm strip.
        actionAnnouncement: null,
      ),
    );
  }

  void _onActionCancelled(
    RunDetailActionCancelled event,
    Emitter<RunDetailState> emit,
  ) {
    // Dropping the confirm strip discards its request id with it, so the next
    // deliberate confirm mints a new one — which is correct: a second
    // deliberate confirm is a second deliberate spend (§8.3).
    emit(state.copyWith(pendingAction: null, actionAnnouncement: null));
  }

  Future<void> _onActionSubmitted(
    RunDetailActionSubmitted event,
    Emitter<RunDetailState> emit,
  ) async {
    emit(state.copyWith(isSubmittingAction: true));
    try {
      final isRetry = event.action == 'retry';
      final result = isRetry
          ? await _repository.retryFailedWorkItem(
              workItemId: _runId,
              requestId: event.requestId,
              requestedBy: _operatorName(),
              reason: event.reason,
            )
          : await _repository.stopFailedWorkItem(
              workItemId: _runId,
              requestId: event.requestId,
              requestedBy: _operatorName(),
              reason: event.reason,
            );

      // Every terminal outcome has a stated operator-facing sentence (N7), and
      // the strip always closes: the action resolved, one way or another, so
      // leaving a confirm strip up would invite a second spend of something
      // that has already been decided.
      final announcement = operatorActionAnnouncement(
        result.outcome,
        capacityFull: actionContextCapacityFull(state.actionContext?.capacity),
        attemptLimit: result.attemptLimit,
        retryLimitResolved: result.retryLimitResolved,
      );

      emit(
        state.copyWith(
          isSubmittingAction: false,
          pendingAction: null,
          actionAnnouncement: announcement,
        ),
      );

      // Re-read: a refresh mid-flight must show the item's real state and never
      // a button for an action that is no longer legal (AC-11).
      add(RunDetailLoaded());
    } on Object {
      // N7 — no silent failure. The panel says what happened and that nothing
      // changed, and the pending strip is KEPT so the operator's words survive
      // and the SAME request id can be retried — which is the whole point of
      // minting it once per confirmation rather than per attempt.
      emit(
        state.copyWith(
          isSubmittingAction: false,
          actionAnnouncement: failedSentence,
        ),
      );
    }
  }

  /// Whether the budget was full at the moment the operator committed.
  ///
  /// A SNAPSHOT read, never a promise and never a gate: the retry RPC does not
  /// consult capacity at all, and capacity is enforced at claim time by
  /// `JobCapacityGuard`. The snapshot only decides which of the two truthful
  /// sentences the operator is told (§5.4, §7.2).
  static bool actionContextCapacityFull(CapacitySnapshotResponse? capacity) =>
      capacity != null &&
      capacity.resolved &&
      capacity.inFlight >= capacity.cap;

  /// Who to record as the human.
  ///
  /// The audit row's `requestedBy` is the first place this repository records a
  /// person rather than the path the engine acted by, so it is read from the
  /// same deployment configuration the credential flow already uses. The
  /// fallback matches what the decision screen already submits for `decider`,
  /// so an unconfigured deployment records a recognisable placeholder instead of
  /// an empty string that would read as "nobody acted".
  static String _operatorName() =>
      OperatorAttestation.fromRuntime().confirmedBy ?? 'operator';
}

class RunDetailState {
  const RunDetailState({
    this.isLoading = false,
    this.runId = '',
    this.name = '',
    this.description = '',
    this.state = '',
    this.blockingHumanDecisionId,
    this.agent = '',
    this.category = '',
    this.startedAt,
    this.events = const [],
    this.heldUpJobs = const [],
    this.recommendation,
    this.haltedState,
    this.artifacts = const [],
    this.modelExecutions = const [],
    this.actionContext,
    this.actionContextError,
    this.pendingAction,
    this.isSubmittingAction = false,
    this.actionAnnouncement,
    this.errorMessage,
  });

  final bool isLoading;
  final String runId;
  final String name;
  final String description;
  final String state;
  final String? blockingHumanDecisionId;
  final String agent;
  final String category;
  final DateTime? startedAt;
  final List<RunEvent> events;

  /// Ids of jobs waiting to start behind this run.
  final List<String> heldUpJobs;

  /// The blocking decision's recommendation, when it carries one.
  final String? recommendation;

  /// The workflow state the run halted in, read from the blocking decision's
  /// context. Explains *why* it is waiting far better than the parked state.
  final String? haltedState;

  /// Artifacts attached to the run, for the evidence panel.
  final List<ArtifactRefResponse> artifacts;

  /// Model execution records for this work item.
  final List<ModelExecutionRecordResponse> modelExecutions;

  /// The server-computed action set for a failed work item, or null when this
  /// run offers no operator action at all — which is the signal to keep today's
  /// existing right-column text (AC-2).
  final WorkItemActionContextResponse? actionContext;

  /// Set when the action read failed. The page still renders the durable record;
  /// it says so rather than pretending there is nothing to do.
  final String? actionContextError;

  /// The action the operator has started but not confirmed.
  final String? pendingAction;

  final bool isSubmittingAction;

  /// The live-region sentence for the last resolved action (AC-25).
  final String? actionAnnouncement;

  final String? errorMessage;

  RunDetailState copyWith({
    bool? isLoading,
    String? runId,
    String? name,
    String? description,
    String? state,
    String? blockingHumanDecisionId,
    String? agent,
    String? category,
    DateTime? startedAt,
    List<RunEvent>? events,
    List<String>? heldUpJobs,
    String? recommendation,
    String? haltedState,
    List<ArtifactRefResponse>? artifacts,
    List<ModelExecutionRecordResponse>? modelExecutions,
    Object? actionContext = _unset,
    Object? actionContextError = _unset,
    Object? pendingAction = _unset,
    bool? isSubmittingAction,
    Object? actionAnnouncement = _unset,
    String? errorMessage,
  }) {
    return RunDetailState(
      isLoading: isLoading ?? this.isLoading,
      runId: runId ?? this.runId,
      name: name ?? this.name,
      description: description ?? this.description,
      state: state ?? this.state,
      blockingHumanDecisionId:
          blockingHumanDecisionId ?? this.blockingHumanDecisionId,
      agent: agent ?? this.agent,
      category: category ?? this.category,
      startedAt: startedAt ?? this.startedAt,
      events: events ?? this.events,
      heldUpJobs: heldUpJobs ?? this.heldUpJobs,
      recommendation: recommendation ?? this.recommendation,
      haltedState: haltedState ?? this.haltedState,
      artifacts: artifacts ?? this.artifacts,
      modelExecutions: modelExecutions ?? this.modelExecutions,
      actionContext: identical(actionContext, _unset)
          ? this.actionContext
          : actionContext as WorkItemActionContextResponse?,
      actionContextError: identical(actionContextError, _unset)
          ? this.actionContextError
          : actionContextError as String?,
      pendingAction: identical(pendingAction, _unset)
          ? this.pendingAction
          : pendingAction as String?,
      isSubmittingAction: isSubmittingAction ?? this.isSubmittingAction,
      actionAnnouncement: identical(actionAnnouncement, _unset)
          ? this.actionAnnouncement
          : actionAnnouncement as String?,
      errorMessage: errorMessage,
    );
  }
}

class RunEvent {
  const RunEvent({
    required this.type,
    required this.message,
    required this.raw,
    required this.timestamp,
    this.reason,
  });

  final String type;
  final String message;
  final String raw;
  final DateTime timestamp;

  /// The durable `work_item_transition.reason`, verbatim.
  ///
  /// It was previously discarded at this boundary, which is why the panel had
  /// to invent a generic sentence where a recorded one existed. It is not put
  /// on the default timeline — the raw record stays behind "Show technical
  /// details" — but it is no longer thrown away before anything can read it.
  final String? reason;

  /// True when this entry handed control to the operator. The design tints
  /// these rows amber.
  bool get needsOperator =>
      type == 'waiting_for_human_decision' ||
      type == 'design_in_review' ||
      type == 'agent_failed' ||
      type == 'qa_failed' ||
      type == 'deployment_failed';
}

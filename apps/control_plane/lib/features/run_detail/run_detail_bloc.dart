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
    on<RunDetailReviewRepairStarted>(_onReviewRepairStarted);
    on<RunDetailReviewRepairCancelled>(_onReviewRepairCancelled);
    on<RunDetailReviewRepairSubmitted>(_onReviewRepairSubmitted);
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
                  // NOT `plainTransitionMessage(from, to)` for every row.
                  //
                  // `work_item_transition` is an ATTEMPT log: the engine
                  // appends a row and changes nothing when the policy refuses
                  // an edge. Rendering every row as the move is what put
                  // "Independent review started" on screen 236 times for a
                  // work item where no review ever started. The wire now
                  // carries `outcome`, so the two are told apart here.
                  message: timelineMessageFor(
                    from: t.fromState,
                    to: t.toState,
                    outcome: t.outcome,
                  ),
                  raw: rawTransitionPair(t.fromState, t.toState),
                  timestamp: t.transitionedAt,
                  reason: t.reason,
                  outcome: t.outcome,
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
      final result = await switch (event.action) {
        'retry' => _repository.retryFailedWorkItem(
          workItemId: _runId,
          requestId: event.requestId,
          requestedBy: _operatorName(),
          reason: event.reason,
        ),
        'deploy' => _repository.advanceToDeploy(
          workItemId: _runId,
          requestId: event.requestId,
          requestedBy: _operatorName(),
          reason: event.reason,
        ),
        'reclaim' => _repository.reclaimStrandedExecution(
          workItemId: _runId,
          requestId: event.requestId,
          requestedBy: _operatorName(),
          reason: event.reason,
        ),
        'reland' => _repository.relandDeployedWorkItem(
          workItemId: _runId,
          requestId: event.requestId,
          requestedBy: _operatorName(),
          reason: event.reason,
        ),
        'reroute' => _repository.rerouteToImplementation(
          workItemId: _runId,
          requestId: event.requestId,
          requestedBy: _operatorName(),
          reason: event.reason,
        ),
        _ => _repository.stopFailedWorkItem(
          workItemId: _runId,
          requestId: event.requestId,
          requestedBy: _operatorName(),
          reason: event.reason,
        ),
      };

      // Every terminal outcome has a stated operator-facing sentence (N7), and
      // the strip always closes: the action resolved, one way or another, so
      // leaving a confirm strip up would invite a second spend of something
      // that has already been decided.
      final announcement = operatorActionAnnouncementFor(
        event.action,
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

  // -------------------------------------------------------------------------
  // THE REVIEW REPAIR
  //
  // Separate from the failed-work action above, and separate state for the same
  // reason the surfaces are separate: a repair is not a third retry/stop mode,
  // and sharing one `pendingAction` field would mean the two confirm strips
  // could be open at once and one of them would silently win.
  // -------------------------------------------------------------------------

  void _onReviewRepairStarted(
    RunDetailReviewRepairStarted event,
    Emitter<RunDetailState> emit,
  ) {
    emit(
      state.copyWith(
        isRepairStripOpen: true,
        // A NEW repair clears the previous outcome, so a stale receipt is never
        // sitting under a fresh confirm strip.
        repairReport: null,
      ),
    );
  }

  void _onReviewRepairCancelled(
    RunDetailReviewRepairCancelled event,
    Emitter<RunDetailState> emit,
  ) {
    // Dropping the strip discards its request id with it, so the next
    // deliberate confirm mints a new one — the same rule as the retry strip.
    emit(state.copyWith(isRepairStripOpen: false));
  }

  Future<void> _onReviewRepairSubmitted(
    RunDetailReviewRepairSubmitted event,
    Emitter<RunDetailState> emit,
  ) async {
    emit(state.copyWith(isSubmittingRepair: true));
    try {
      final result = await _repository.repairUnreviewedReview(
        workItemId: _runId,
        requestId: event.requestId,
        requestedBy: _operatorName(),
        reason: event.reason,
        // The item's OWN blocking decision, and only when it still has one. The
        // server resolves it itself when this is null; passing a stale id would
        // name a decision that is no longer the one being parked on, and
        // omitting it when one exists leaves the server to do the lookup it was
        // written to do.
        decisionId: state.blockingHumanDecisionId,
      );

      // One sentence, chosen by outcome, and the refusal branch is the server's
      // own — see `repairOutcomeSentence` for why there is deliberately no
      // per-outcome table here.
      emit(
        state.copyWith(
          isSubmittingRepair: false,
          isRepairStripOpen: false,
          repairReport: ReviewRepairReport(
            accepted: result.repaired,
            sentence: repairOutcomeSentence(
              result.outcome,
              detail: result.detail,
            ),
            // The server names the decision it actually examined, which is the
            // subject this receipt is about. See `ReviewRepairReport.decisionId`
            // for why the receipt must be keyed to a decision rather than to this
            // run.
            decisionId: result.decisionId,
          ),
        ),
      );

      // Re-read, for the same reason the retry action re-reads: a repair retires
      // the decision and re-queues the work, so the page is showing a genuinely
      // different item and must say so. The receipt is deliberately PRESERVED
      // across this reload — see `ReviewRepairReport`'s field docs on the
      // widget, which is exactly the state that must outlive the decision id.
      add(RunDetailLoaded());
    } on Object {
      // The transport failed, so there is no `detail` to show and nothing
      // truthful to claim. Say that nothing changed, and KEEP the strip so the
      // operator's words survive and the same request id can be retried.
      //
      // The receipt is keyed to NO decision, and that is the honest answer: the
      // request never reached the server, so nothing about any decision was
      // examined. Which means a later park behind a different decision still
      // re-offers, which is correct — an attempt that never arrived has not
      // answered anything.
      emit(
        state.copyWith(
          isSubmittingRepair: false,
          repairReport: const ReviewRepairReport(
            accepted: false,
            sentence: failedSentence,
          ),
        ),
      );
    }
  }
}

/// What one resolved repair attempt did.
///
/// Carried as one object rather than two fields so `accepted` and `sentence`
/// cannot drift apart — a receipt that showed the three "this moved forward"
/// facts beside a refusal sentence would be the exact false state this whole
/// surface exists to prevent.
class ReviewRepairReport {
  const ReviewRepairReport({
    required this.accepted,
    required this.sentence,
    this.decisionId,
  });

  /// True only when the endpoint returned `accepted`, i.e. the decision was
  /// actually retired. Every other outcome wrote nothing at all.
  final bool accepted;

  /// The one sentence the operator reads. On a refusal this is the server's own
  /// `detail`, carried whole.
  final String sentence;

  /// The decision THIS attempt concerned, or null when the attempt never reached
  /// one — a blank request is refused before the decision is even resolved.
  ///
  /// ## WHY THE RECEIPT IS KEYED TO A DECISION AND NOT TO A RUN
  ///
  /// The receipt is one-way PER DECISION, and keying it to the run is wrong
  /// because a work item parks on a decision more than once. Its premise — that
  /// every refusal is a statement about durable state that cannot change under
  /// the operator's feet — holds for the SUBJECT of the prior refusal and for
  /// nothing else. Durable state for the item absolutely does change: a repair is
  /// retired, the re-queued review runs, and the item parks again behind a
  /// DIFFERENT decision.
  ///
  /// Keyed to the run alone, that second park found `repairReport` already
  /// non-null — it is deliberately preserved across `RunDetailLoaded()` — so the
  /// operator saw a receipt about a decision they never attempted and NO OFFER at
  /// all, silently disabling the repair for the next fabrication. That is the
  /// recurring shape this feature exists for, so the outage would have been
  /// precisely where the feature was needed.
  ///
  /// Null is a real state, not an absence: it is the `invalidRequest` refusal,
  /// which is keyed to nothing because nothing about a decision was examined.
  final String? decisionId;
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
    this.isRepairStripOpen = false,
    this.isSubmittingRepair = false,
    this.repairReport,
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

  /// True once the operator has opened the review-repair confirm strip.
  ///
  /// Deliberately NOT `pendingAction`: the two surfaces are different actions
  /// with different consequences, and one shared field would let a repair strip
  /// and a retry strip both claim to be the open one.
  final bool isRepairStripOpen;

  final bool isSubmittingRepair;

  /// What the last repair attempt did, or null while none has resolved.
  ///
  /// PRESERVED across the reload a repair triggers. A successful repair retires
  /// the blocking decision, so gating this on the decision still existing would
  /// delete the receipt at the exact moment it became the most important thing
  /// on the screen — which is why `copyWith` carries it through the `_unset`
  /// sentinel rather than the null-defaulting `?? this.x` the plain fields use.
  final ReviewRepairReport? repairReport;

  final String? errorMessage;

  RunDetailState copyWith({
    bool? isLoading,
    String? runId,
    String? name,
    String? description,
    String? state,
    // `_unset`, not `?? this.x`. These three genuinely go to null when the
    // blocking decision is retired — which is exactly what a review repair does
    // — and `?? this.blockingHumanDecisionId` cannot express "set it to null",
    // so it would have silently kept the dead decision on screen and the screen
    // would have gone on OFFERING the repair for a decision that no longer
    // exists. The same defect the sentinel above was introduced for, in the
    // three fields that were never given it.
    Object? blockingHumanDecisionId = _unset,
    String? agent,
    String? category,
    DateTime? startedAt,
    List<RunEvent>? events,
    List<String>? heldUpJobs,
    Object? recommendation = _unset,
    Object? haltedState = _unset,
    List<ArtifactRefResponse>? artifacts,
    List<ModelExecutionRecordResponse>? modelExecutions,
    Object? actionContext = _unset,
    Object? actionContextError = _unset,
    Object? pendingAction = _unset,
    bool? isSubmittingAction,
    Object? actionAnnouncement = _unset,
    bool? isRepairStripOpen,
    bool? isSubmittingRepair,
    Object? repairReport = _unset,
    String? errorMessage,
  }) {
    return RunDetailState(
      isLoading: isLoading ?? this.isLoading,
      runId: runId ?? this.runId,
      name: name ?? this.name,
      description: description ?? this.description,
      state: state ?? this.state,
      blockingHumanDecisionId: identical(blockingHumanDecisionId, _unset)
          ? this.blockingHumanDecisionId
          : blockingHumanDecisionId as String?,
      agent: agent ?? this.agent,
      category: category ?? this.category,
      startedAt: startedAt ?? this.startedAt,
      events: events ?? this.events,
      heldUpJobs: heldUpJobs ?? this.heldUpJobs,
      recommendation: identical(recommendation, _unset)
          ? this.recommendation
          : recommendation as String?,
      haltedState: identical(haltedState, _unset)
          ? this.haltedState
          : haltedState as String?,
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
      isRepairStripOpen: isRepairStripOpen ?? this.isRepairStripOpen,
      isSubmittingRepair: isSubmittingRepair ?? this.isSubmittingRepair,
      repairReport: identical(repairReport, _unset)
          ? this.repairReport
          : repairReport as ReviewRepairReport?,
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
    this.outcome,
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

  /// The durable `work_item_transition.outcome` wire value, verbatim: this row
  /// records that the item MOVED. Null or `rejected` records an ATTEMPT the
  /// policy refused, which is not a move.
  ///
  /// See [timelineMessageFor] and `transition_copy.dart`. Null is deliberately
  /// NOT treated as "accepted": that inference is exactly what produced a
  /// timeline asserting 236 transitions that never happened.
  final String? outcome;

  /// Whether the platform REFUSED this transition and the item never went to
  /// [type].
  ///
  /// Null is refused too, and that is the conservative direction: an attempt
  /// whose outcome cannot be read is not evidence that the item moved.
  bool get wasRefused => outcome != 'accepted';

  /// True when this entry handed control to the operator. The design tints
  /// these rows amber.
  ///
  /// A refused row NEVER tints, whatever [type] says — it is not a state the
  /// item reached, so tinting it for handing over control would claim a
  /// handover that did not happen.
  bool get needsOperator =>
      !wasRefused &&
      (type == 'waiting_for_human_decision' ||
          type == 'design_in_review' ||
          type == 'agent_failed' ||
          type == 'qa_failed' ||
          type == 'deployment_failed');
}

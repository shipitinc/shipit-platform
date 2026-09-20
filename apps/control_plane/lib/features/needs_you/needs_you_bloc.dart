import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/plain_language.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/decision_choice.dart';
import 'needs_you_event.dart';

/// Loads the operator's queue.
///
/// The design shows two things: decisions still waiting, and an "Already
/// decided" ledger. Both come from the same durable decision records, split on
/// whether an outcome has been written.
class NeedsYouBloc extends Bloc<NeedsYouEvent, NeedsYouState> {
  NeedsYouBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const NeedsYouState()) {
    on<NeedsYouLoaded>(_onLoaded);
    on<NeedsYouActionStarted>(_onActionStarted);
    on<NeedsYouActionCancelled>(_onActionCancelled);
    on<NeedsYouActionSubmitted>(_onActionSubmitted);
    on<NeedsYouHistoryRequested>(_onHistoryRequested);
  }

  /// How many resolved decisions are fetched per page.
  static const int historyPageSize = 10;

  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(
    NeedsYouLoaded event,
    Emitter<NeedsYouState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final decisions = await _repository.pendingDecisions(limit: 20);
      // Resolved decisions need their own read: once decided, the work item
      // is unblocked and the decision leaves the pending set.
      final decided = await _repository.recentDecisions(limit: historyPageSize);

      final pending = <PendingDecision>[];
      final resolved = <ResolvedDecision>[];

      for (final d in [...decisions, ...decided]) {
        final options = (d.options ?? const [])
            .map(
              (o) => DecisionChoiceOption(
                value: isKnownDecisionChoice(o.optionId)
                    ? o.optionId
                    : (isKnownDecisionChoice(o.label) ? o.label : o.optionId),
                label: decisionChoiceLabel(
                  isKnownDecisionChoice(o.optionId)
                      ? o.optionId
                      : (isKnownDecisionChoice(o.label) ? o.label : o.optionId),
                  fallback: o.label,
                  decisionType: d.decisionType,
                ),
                description: o.description,
                recommended: o.recommended,
              ),
            )
            .toList();

        if (d.choice != null) {
          resolved.add(
            ResolvedDecision(
              decisionId: d.decisionId,
              runId: d.workItemId,
              question: d.question ?? 'Decision recorded',
              choice: d.choice!,
              choiceLabel: decisionChoiceLabel(
                d.choice!,
                fallback: d.choice!,
                decisionType: d.decisionType,
              ),
              resolvedAt: d.resolvedAt,
            ),
          );
        } else {
          pending.add(
            PendingDecision(
              id: d.decisionId,
              runId: d.workItemId,
              runTitle: PlainLanguage.headline(
                title: d.workItemTitle,
                description: d.workItemDescription,
              ),
              question: d.question ?? 'Decision required',
              decisionTypeWire: d.decisionType,
              recommendation: d.recommendation,
              haltedState: d.context?.workflowState,
              requestedAt: d.requestedAt,
              options: options,
              artifactLabel: _artifactLabel(d),
            ),
          );
        }
      }

      emit(
        state.copyWith(
          isLoading: false,
          clearError: true,
          decisions: pending,
          resolved: resolved,
          // A short first page means there is nothing behind it.
          hasMoreHistory: decided.length >= historyPageSize,
          clearLoadingMore: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Appends the next page of decided items as the ledger is scrolled.
  Future<void> _onHistoryRequested(
    NeedsYouHistoryRequested event,
    Emitter<NeedsYouState> emit,
  ) async {
    if (state.isLoadingMoreHistory || !state.hasMoreHistory) return;
    emit(state.copyWith(isLoadingMoreHistory: true));
    try {
      final next = await _repository.recentDecisions(
        limit: historyPageSize,
        offset: state.resolved.length,
      );
      final seen = state.resolved.map((r) => r.decisionId).toSet();
      final added = <ResolvedDecision>[];
      for (final d in next) {
        if (d.choice == null || seen.contains(d.decisionId)) continue;
        added.add(
          ResolvedDecision(
            decisionId: d.decisionId,
            runId: d.workItemId,
            question: d.question ?? 'Decision recorded',
            choice: d.choice!,
            choiceLabel: decisionChoiceLabel(
              d.choice!,
              fallback: d.choice!,
              decisionType: d.decisionType,
            ),
            resolvedAt: d.resolvedAt,
          ),
        );
      }
      emit(
        state.copyWith(
          resolved: [...state.resolved, ...added],
          hasMoreHistory: next.length >= historyPageSize,
          clearLoadingMore: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(clearLoadingMore: true, errorMessage: e.toString()));
    }
  }

  void _onActionStarted(
    NeedsYouActionStarted event,
    Emitter<NeedsYouState> emit,
  ) {
    emit(
      state.copyWith(
        clearError: true,
        pendingAction: PendingAction(
          decisionId: event.decisionId,
          choice: event.choice,
        ),
      ),
    );
  }

  void _onActionCancelled(
    NeedsYouActionCancelled event,
    Emitter<NeedsYouState> emit,
  ) {
    emit(state.copyWith(clearPendingAction: true, clearError: true));
  }

  Future<void> _onActionSubmitted(
    NeedsYouActionSubmitted event,
    Emitter<NeedsYouState> emit,
  ) async {
    emit(
      state.copyWith(submittingDecisionId: event.decisionId, clearError: true),
    );
    try {
      await _repository.resolveDecision(
        decisionId: event.decisionId,
        choice: event.choice,
        decider: 'operator',
        rationale: event.rationale,
      );
      emit(state.copyWith(clearSubmitting: true, clearPendingAction: true));
      // Re-read so the card moves into "Already decided" from the durable
      // record rather than from an optimistic guess.
      add(NeedsYouLoaded());
    } catch (e) {
      emit(state.copyWith(clearSubmitting: true, errorMessage: e.toString()));
    }
  }
}

/// The design's fourth fact column names the thing under review, e.g.
/// "Version 3" for a design gate or "Log" for a failed run. Only rendered when
/// the record carries an artifact.
String? _artifactLabel(DecisionResponse d) {
  final refs = d.artifactRefs;
  if (refs == null || refs.isEmpty) return null;
  final first = refs.first;
  return first.description?.trim().isNotEmpty == true
      ? first.description!.trim()
      : first.artifactType;
}

/// Commits a decision taken straight from its card.
///
/// The card's buttons name a specific outcome ("Approve", "Resume"), so they
/// perform that outcome. A reason is still captured first: the domain allows
/// an empty rationale, but the product promises decisions are recorded, and a
/// decision without a stated reason is a much weaker record.
/// A chosen-but-unconfirmed action on one card.
class PendingAction {
  const PendingAction({required this.decisionId, required this.choice});

  final String decisionId;

  /// Durable `HumanDecisionChoice` wire value.
  final String choice;
}

class NeedsYouState {
  const NeedsYouState({
    this.isLoading = false,
    this.decisions = const [],
    this.resolved = const [],
    this.pendingAction,
    this.submittingDecisionId,
    this.hasMoreHistory = false,
    this.isLoadingMoreHistory = false,
    this.errorMessage,
  });

  final bool isLoading;

  /// Decisions still waiting on the operator.
  final List<PendingDecision> decisions;

  /// Decisions that already carry a durable outcome.
  final List<ResolvedDecision> resolved;

  /// The action the operator has started but not yet confirmed.
  final PendingAction? pendingAction;

  /// Id of the decision currently being written.
  final String? submittingDecisionId;

  /// True while more decided items may exist behind the current page.
  final bool hasMoreHistory;
  final bool isLoadingMoreHistory;
  final String? errorMessage;

  NeedsYouState copyWith({
    bool? isLoading,
    List<PendingDecision>? decisions,
    List<ResolvedDecision>? resolved,
    PendingAction? pendingAction,
    String? submittingDecisionId,
    bool? hasMoreHistory,
    bool? isLoadingMoreHistory,
    String? errorMessage,
    bool clearError = false,
    bool clearPendingAction = false,
    bool clearSubmitting = false,
    bool clearLoadingMore = false,
  }) {
    return NeedsYouState(
      isLoading: isLoading ?? this.isLoading,
      decisions: decisions ?? this.decisions,
      resolved: resolved ?? this.resolved,
      pendingAction: clearPendingAction
          ? null
          : (pendingAction ?? this.pendingAction),
      submittingDecisionId: clearSubmitting
          ? null
          : (submittingDecisionId ?? this.submittingDecisionId),
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      isLoadingMoreHistory: clearLoadingMore
          ? false
          : (isLoadingMoreHistory ?? this.isLoadingMoreHistory),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// A decision awaiting the operator.
class PendingDecision {
  const PendingDecision({
    required this.id,
    required this.runId,
    required this.runTitle,
    required this.question,
    required this.decisionTypeWire,
    this.recommendation,
    this.haltedState,
    this.requestedAt,
    this.options = const [],
    this.artifactLabel,
  });

  final String id;
  final String runId;

  /// Plain-language name of the run this gates.
  final String runTitle;
  final String question;

  /// Durable `HumanDecisionType` wire value.
  final String decisionTypeWire;
  final String? recommendation;

  /// The workflow state the run halted in.
  final String? haltedState;
  final DateTime? requestedAt;

  /// The choices the workflow will accept, in record order.
  final List<DecisionChoiceOption> options;

  /// Name of the artifact under review, when one is recorded.
  final String? artifactLabel;
}

/// A decision with a durable outcome, for the "Already decided" ledger.
class ResolvedDecision {
  const ResolvedDecision({
    required this.decisionId,
    required this.runId,
    required this.question,
    required this.choice,
    required this.choiceLabel,
    this.resolvedAt,
  });

  final String decisionId;
  final String runId;
  final String question;

  /// Raw choice value as recorded.
  final String choice;

  /// Operator-facing label for [choice].
  final String choiceLabel;
  final DateTime? resolvedAt;
}

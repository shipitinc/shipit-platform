import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/plain_language.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/decision_choice.dart';
import 'decision_context.dart';
import 'decision_detail_event.dart';

class DecisionDetailBloc
    extends Bloc<DecisionDetailEvent, DecisionDetailState> {
  DecisionDetailBloc({
    required this._decisionId,
    required this._runId,
    required this._repository,
  }) : super(const DecisionDetailState()) {
    on<DecisionDetailLoaded>(_onLoaded);
    on<DecisionChoiceSelected>(_onChoiceSelected);
    on<DecisionRationaleChanged>(_onRationaleChanged);
    on<DecisionSubmitted>(_onSubmitted);
  }

  final String _decisionId;
  final String _runId;
  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(
    DecisionDetailLoaded event,
    Emitter<DecisionDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      // The work item can carry several decisions (a voided one plus its
      // re-raised successor); name ours so the screen shows THIS record.
      final detail = await _repository.inspectDecision(
        _runId,
        decisionId: _decisionId,
      );
      final sourceOptions = detail.options != null && detail.options!.isNotEmpty
          ? detail.options!
          : (detail.context?.availableOptions ?? const [])
                .map(
                  (v) =>
                      DecisionOption(optionId: v, label: v, recommended: false),
                )
                .toList();
      final choiceOptions = sourceOptions.map((o) {
        final value = isKnownDecisionChoice(o.optionId)
            ? o.optionId
            : (isKnownDecisionChoice(o.label) ? o.label : o.optionId);
        return DecisionChoiceOption(
          value: value,
          label: decisionChoiceLabel(
            value,
            fallback: o.label,
            decisionType: detail.decisionType,
          ),
          description: o.description,
          recommended: o.recommended,
        );
      }).toList();
      emit(
        state.copyWith(
          isLoading: false,
          // The id of the record actually rendered — the requested one when
          // the match held, the most recent when it did not.
          decisionId: detail.decisionId,
          runId: _runId,
          runName: PlainLanguage.headline(
            title: detail.workItemTitle ?? detail.workItemId,
            description: detail.workItemDescription,
          ),
          workItemTitle: detail.workItemTitle,
          workItemDescription: detail.workItemDescription,
          metadataJson: detail.metadataJson,
          contextPayload: parseDecisionContext(
            decisionType: detail.decisionType,
            metadataJson: detail.metadataJson,
          ),
          question: detail.question ?? 'Decision required',
          description: detail.context?.workflowState ?? '',
          decider: detail.context?.workflowState ?? 'operator',
          choices: choiceOptions,
          createdAt: detail.requestedAt,
          decisionTypeWire: detail.decisionType,
          recommendation: detail.recommendation,
          haltedState: detail.context?.workflowState,
          artifacts: detail.artifactRefs ?? const [],
          statusWire: detail.status,
          alreadyResolved: detail.choice != null,
          resolvedChoice: detail.choice,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void _onChoiceSelected(
    DecisionChoiceSelected event,
    Emitter<DecisionDetailState> emit,
  ) {
    emit(state.copyWith(selectedChoice: event.choice));
  }

  void _onRationaleChanged(
    DecisionRationaleChanged event,
    Emitter<DecisionDetailState> emit,
  ) {
    emit(state.copyWith(rationale: event.rationale));
  }

  Future<void> _onSubmitted(
    DecisionSubmitted event,
    Emitter<DecisionDetailState> emit,
  ) async {
    // A voided record accepts no answer — refuse the write, not just the
    // button that issues it.
    if (state.selectedChoice == null || state.isCancelled) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.resolveDecision(
        // The id of the rendered record, not the requested one: the two
        // differ only when the deep link named a decision that is no longer
        // on this work item and the page fell back to the most recent.
        decisionId: state.decisionId,
        choice: state.selectedChoice!,
        decider: 'operator',
        rationale: state.rationale,
      );
      // Record the choice locally so the decided panel can name it without
      // waiting for a refetch.
      emit(
        state.copyWith(
          isSubmitting: false,
          isSubmitted: true,
          resolvedChoice: state.selectedChoice,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}

class DecisionDetailState {
  const DecisionDetailState({
    this.isLoading = false,
    this.decisionId = '',
    this.runId = '',
    this.runName = '',
    this.question = '',
    this.description = '',
    this.decider = '',
    this.choices = const [],
    this.selectedChoice,
    this.rationale = '',
    this.createdAt,
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.decisionTypeWire = '',
    this.recommendation,
    this.haltedState,
    this.artifacts = const [],
    this.statusWire = 'pending',
    this.alreadyResolved = false,
    this.resolvedChoice,
    this.workItemTitle,
    this.workItemDescription,
    this.metadataJson,
    this.contextPayload = const GenericDecisionContext(),
    this.errorMessage,
  });

  final bool isLoading;
  final String decisionId;
  final String runId;
  final String runName;
  final String question;
  final String description;
  final String decider;
  final List<DecisionChoiceOption> choices;
  final String? selectedChoice;
  final String rationale;
  final DateTime? createdAt;
  final bool isSubmitting;
  final bool isSubmitted;

  /// Durable `HumanDecisionType` wire value.
  final String decisionTypeWire;

  /// What the system suggests, if the record carries a recommendation.
  final String? recommendation;

  /// The workflow state the run halted in.
  final String? haltedState;

  /// Artifacts under review, for the evidence panel.
  final List<ArtifactRefResponse> artifacts;

  /// Durable `HumanDecisionStatus` wire value. `choice == null` alone cannot
  /// tell a pending decision from a voided one — both ship a null choice —
  /// so the status itself is what says the record is closed without an
  /// answer.
  final String statusWire;

  /// True when this decision was voided. A cancelled record is closed like a
  /// resolved one, but no outcome was recorded — it must render read-only
  /// and must never offer a live submit panel.
  bool get isCancelled => statusWire == 'cancelled';

  /// True when this decision already carries a durable outcome.
  final bool alreadyResolved;
  final String? resolvedChoice;

  /// The gated item's own title, kept beside [runName] because the type
  /// renderer heads the full-context section with the title itself.
  final String? workItemTitle;

  /// The gated item's full recorded description — untruncated, unlike the
  /// two-line definition row that summarises it.
  final String? workItemDescription;

  /// The decision's `metadataJson` verbatim, kept for the technical-details
  /// strip and any future section that reads a key the typed payload does
  /// not surface.
  final String? metadataJson;

  /// The decision's metadata parsed per [decisionTypeWire] — an
  /// [EngineeringReviewContext] for `engineering_review`, a
  /// [GenericDecisionContext] everywhere else. Resolved once here so the
  /// page never re-decodes and a payload this build cannot read is a fact
  /// on the state, not an exception mid-render.
  final DecisionContextPayload contextPayload;

  final String? errorMessage;

  DecisionDetailState copyWith({
    bool? isLoading,
    String? decisionId,
    String? runId,
    String? runName,
    String? question,
    String? description,
    String? decider,
    List<DecisionChoiceOption>? choices,
    String? selectedChoice,
    String? rationale,
    DateTime? createdAt,
    bool? isSubmitting,
    bool? isSubmitted,
    String? decisionTypeWire,
    String? recommendation,
    String? haltedState,
    List<ArtifactRefResponse>? artifacts,
    String? statusWire,
    bool? alreadyResolved,
    String? resolvedChoice,
    String? workItemTitle,
    String? workItemDescription,
    String? metadataJson,
    DecisionContextPayload? contextPayload,
    String? errorMessage,
  }) {
    return DecisionDetailState(
      isLoading: isLoading ?? this.isLoading,
      decisionId: decisionId ?? this.decisionId,
      runId: runId ?? this.runId,
      runName: runName ?? this.runName,
      question: question ?? this.question,
      description: description ?? this.description,
      decider: decider ?? this.decider,
      choices: choices ?? this.choices,
      selectedChoice: selectedChoice ?? this.selectedChoice,
      rationale: rationale ?? this.rationale,
      createdAt: createdAt ?? this.createdAt,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      decisionTypeWire: decisionTypeWire ?? this.decisionTypeWire,
      recommendation: recommendation ?? this.recommendation,
      haltedState: haltedState ?? this.haltedState,
      artifacts: artifacts ?? this.artifacts,
      statusWire: statusWire ?? this.statusWire,
      alreadyResolved: alreadyResolved ?? this.alreadyResolved,
      resolvedChoice: resolvedChoice ?? this.resolvedChoice,
      workItemTitle: workItemTitle ?? this.workItemTitle,
      workItemDescription: workItemDescription ?? this.workItemDescription,
      metadataJson: metadataJson ?? this.metadataJson,
      contextPayload: contextPayload ?? this.contextPayload,
      errorMessage: errorMessage,
    );
  }
}

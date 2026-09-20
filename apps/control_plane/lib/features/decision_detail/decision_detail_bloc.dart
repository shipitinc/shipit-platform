import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/plain_language.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/decision_choice.dart';
import 'decision_detail_event.dart';

class DecisionDetailBloc
    extends Bloc<DecisionDetailEvent, DecisionDetailState> {
  DecisionDetailBloc({
    required String decisionId,
    required String runId,
    required ControlPlaneRepository repository,
  }) : _decisionId = decisionId,
       _runId = runId,
       _repository = repository,
       super(const DecisionDetailState()) {
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
      final detail = await _repository.inspectDecision(_runId);
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
          decisionId: _decisionId,
          runId: _runId,
          runName: PlainLanguage.headline(
            title: detail.workItemTitle ?? detail.workItemId,
            description: detail.workItemDescription,
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
    if (state.selectedChoice == null) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.resolveDecision(
        decisionId: _decisionId,
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
    this.alreadyResolved = false,
    this.resolvedChoice,
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

  /// True when this decision already carries a durable outcome.
  final bool alreadyResolved;
  final String? resolvedChoice;
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
    bool? alreadyResolved,
    String? resolvedChoice,
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
      alreadyResolved: alreadyResolved ?? this.alreadyResolved,
      resolvedChoice: resolvedChoice ?? this.resolvedChoice,
      errorMessage: errorMessage,
    );
  }
}

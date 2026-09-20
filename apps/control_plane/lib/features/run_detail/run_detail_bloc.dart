import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/transition_copy.dart';
import 'run_detail_event.dart';

class RunDetailBloc extends Bloc<RunDetailEvent, RunDetailState> {
  RunDetailBloc({
    required String runId,
    required ControlPlaneRepository repository,
  }) : _runId = runId,
       _repository = repository,
       super(const RunDetailState()) {
    on<RunDetailLoaded>(_onLoaded);
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
                ),
              )
              .toList(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
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
  });

  final String type;
  final String message;
  final String raw;
  final DateTime timestamp;

  /// True when this entry handed control to the operator. The design tints
  /// these rows amber.
  bool get needsOperator =>
      type == 'waiting_for_human_decision' ||
      type == 'design_in_review' ||
      type == 'agent_failed' ||
      type == 'qa_failed' ||
      type == 'deployment_failed';
}

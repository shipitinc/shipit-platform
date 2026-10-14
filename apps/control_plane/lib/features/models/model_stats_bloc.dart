import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';
import 'run_duration_stats.dart';

sealed class ModelStatsEvent {
  const ModelStatsEvent();
}

class ModelStatsLoaded extends ModelStatsEvent {
  const ModelStatsLoaded({this.from, this.to, this.groupBy});

  final DateTime? from;
  final DateTime? to;
  final String? groupBy;
}

/// Loads the cost/usage projection AND the run-duration table.
///
/// ## Why durations are a SEPARATE read with its own error
///
/// The cost projection and the duration table answer different questions and
/// come from different endpoints. Fusing them into one future would mean a
/// duration failure blanks the cost panel, or — worse — a cost failure hides a
/// duration table that is still perfectly good. Neither is honest, so [durations]
/// carries its own [durationErrorMessage] and the page renders it IN PLACE of
/// the table, never in place of the rest of the screen.
///
/// A missing duration table must never look like "durations are zero".
class ModelStatsBloc extends Bloc<ModelStatsEvent, ModelStatsState> {
  ModelStatsBloc({required this._repository}) : super(const ModelStatsState()) {
    on<ModelStatsLoaded>(_onLoaded);
  }

  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(
    ModelStatsLoaded event,
    Emitter<ModelStatsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final stats = await _repository.getModelStats(
        from: event.from,
        to: event.to,
        groupBy: event.groupBy,
      );
      emit(ModelStatsState(isLoading: false, stats: stats));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }

    // Deliberately NOT inside the try above. See the class doc.
    try {
      final samples = await _repository.listAgentExecutionSamples(
        from: event.from,
        to: event.to,
      );
      emit(
        state.copyWith(
          durations: RunDurationStats.compute(
            samples
                .where((s) => s.isMeasurable)
                .map(
                  (s) => RunDurationSample(
                    role: s.role,
                    status: s.status,
                    durationSeconds: s.durationSeconds!,
                  ),
                )
                .toList(),
          ),
          unmeasuredRuns: samples.where((s) => !s.isMeasurable).length,
          clearDurationError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          durations: null,
          unmeasuredRuns: null,
          durationErrorMessage: e.toString(),
        ),
      );
    }
  }
}

class ModelStatsState {
  const ModelStatsState({
    this.isLoading = false,
    this.stats,
    this.errorMessage,
    this.durations,
    this.durationErrorMessage,
    this.unmeasuredRuns,
  });

  final bool isLoading;
  final ModelStatsResponse? stats;
  final String? errorMessage;

  /// Null when the duration read FAILED. Distinct from an empty table, which
  /// means "no runs in this range" — a very different answer.
  final RunDurationStats? durations;

  /// The failure, kept so the panel can say what went wrong instead of showing
  /// an empty table that looks like a system with no agent runs.
  final String? durationErrorMessage;

  /// Runs in range that carry no usable duration (never finished, or the two
  /// timestamps disagree). Shown, not hidden: a growing number here means the
  /// table is not describing what the operator assumes it is.
  final int? unmeasuredRuns;

  ModelStatsState copyWith({
    bool? isLoading,
    ModelStatsResponse? stats,
    String? errorMessage,
    RunDurationStats? durations,
    String? durationErrorMessage,
    int? unmeasuredRuns,
    bool clearError = false,
    bool clearDurationError = false,
  }) => ModelStatsState(
    isLoading: isLoading ?? this.isLoading,
    stats: stats ?? this.stats,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    durations: durations ?? this.durations,
    durationErrorMessage: clearDurationError
        ? null
        : (durationErrorMessage ?? this.durationErrorMessage),
    unmeasuredRuns: unmeasuredRuns ?? this.unmeasuredRuns,
  );
}

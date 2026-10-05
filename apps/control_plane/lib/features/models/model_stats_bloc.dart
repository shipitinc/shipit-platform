import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';

sealed class ModelStatsEvent {
  const ModelStatsEvent();
}

class ModelStatsLoaded extends ModelStatsEvent {
  const ModelStatsLoaded({
    this.from,
    this.to,
    this.groupBy,
  });

  final DateTime? from;
  final DateTime? to;
  final String? groupBy;
}

class ModelStatsBloc extends Bloc<ModelStatsEvent, ModelStatsState> {
  ModelStatsBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const ModelStatsState()) {
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
      emit(
        ModelStatsState(
          isLoading: false,
          stats: stats,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}

class ModelStatsState {
  const ModelStatsState({
    this.isLoading = false,
    this.stats,
    this.errorMessage,
  });

  final bool isLoading;
  final ModelStatsResponse? stats;
  final String? errorMessage;

  ModelStatsState copyWith({
    bool? isLoading,
    ModelStatsResponse? stats,
    String? errorMessage,
    bool clearError = false,
  }) => ModelStatsState(
    isLoading: isLoading ?? this.isLoading,
    stats: stats ?? this.stats,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';

sealed class ModelExecutionsEvent {
  const ModelExecutionsEvent();
}

class ModelExecutionsLoaded extends ModelExecutionsEvent {
  const ModelExecutionsLoaded({
    this.workItemId,
    this.provider,
    this.modelId,
    this.taskType,
    this.success,
    this.from,
    this.to,
    this.limit = 50,
    this.offset = 0,
  });

  final String? workItemId;
  final String? provider;
  final String? modelId;
  final String? taskType;
  final bool? success;
  final DateTime? from;
  final DateTime? to;
  final int limit;
  final int offset;
}

class ModelExecutionsBloc
    extends Bloc<ModelExecutionsEvent, ModelExecutionsState> {
  ModelExecutionsBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const ModelExecutionsState()) {
    on<ModelExecutionsLoaded>(_onLoaded);
  }

  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(
    ModelExecutionsLoaded event,
    Emitter<ModelExecutionsState> emit,
  ) async {
    final isFirstPage = event.offset == 0;
    emit(state.copyWith(isLoading: isFirstPage, clearError: true));
    try {
      final page = await _repository.listModelExecutions(
        workItemId: event.workItemId,
        provider: event.provider,
        modelId: event.modelId,
        taskType: event.taskType,
        success: event.success,
        from: event.from,
        to: event.to,
        limit: event.limit,
        offset: event.offset,
      );
      final taskTypes = await _fetchTaskTypes();
      emit(
        ModelExecutionsState(
          isLoading: false,
          executions: page.items,
          totalCount: page.totalCount,
          taskTypes: taskTypes,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<List<String>> _fetchTaskTypes() async {
    // Fetch from stats endpoint or use a static list
    // For now, return common task types
    return const [
      'implementation',
      'engineering_review',
      'design_review',
      'qa_execution',
      'triage',
      'correction',
      'integration',
      'deployment',
    ];
  }
}

class ModelExecutionsState {
  const ModelExecutionsState({
    this.isLoading = false,
    this.executions = const [],
    this.totalCount = 0,
    this.taskTypes = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<ModelExecutionRecordResponse> executions;
  final int totalCount;
  final List<String> taskTypes;
  final String? errorMessage;

  ModelExecutionsState copyWith({
    bool? isLoading,
    List<ModelExecutionRecordResponse>? executions,
    int? totalCount,
    List<String>? taskTypes,
    String? errorMessage,
    bool clearError = false,
  }) => ModelExecutionsState(
    isLoading: isLoading ?? this.isLoading,
    executions: executions ?? this.executions,
    totalCount: totalCount ?? this.totalCount,
    taskTypes: taskTypes ?? this.taskTypes,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';
import 'direction_inbox_event.dart';

class DirectionInboxBloc
    extends Bloc<DirectionInboxEvent, DirectionInboxState> {
  DirectionInboxBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const DirectionInboxState()) {
    on<DirectionInboxLoaded>(_onLoaded);
    on<DirectionInboxCreateRequested>(_onCreateRequested);
    on<DirectionInboxActionRequested>(_onActionRequested);
    on<DirectionInboxStatusFilterChanged>(_onStatusFilterChanged);
    on<DirectionInboxTargetTypeFilterChanged>(_onTargetTypeFilterChanged);
    on<DirectionInboxRefreshRequested>(_onRefreshRequested);
  }

  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(
    DirectionInboxLoaded event,
    Emitter<DirectionInboxState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final result = await _repository.listDirectionsByStatus(
        status: event.status ?? 'created',
        directionType: null,
        targetType: event.targetType,
        limit: event.limit ?? 50,
      );
      emit(
        state.copyWith(
          isLoading: false,
          clearError: true,
          directions: result,
          currentStatusFilter: event.status,
          currentTargetTypeFilter: event.targetType,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateRequested(
    DirectionInboxCreateRequested event,
    Emitter<DirectionInboxState> emit,
  ) async {
    emit(state.copyWith(isCreating: true, clearError: true));
    try {
      await _repository.createDirection(
        directionType: event.directionType,
        targetType: event.targetType,
        targetId: event.targetId,
        title: event.title,
        description: event.description,
        contextJson: event.contextJson,
        attachments: event.attachments,
        createdBy: event.createdBy,
        assignedTo: event.assignedTo,
      );
      emit(state.copyWith(isCreating: false, clearError: true));
      add(DirectionInboxRefreshRequested());
    } catch (e) {
      emit(state.copyWith(isCreating: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onActionRequested(
    DirectionInboxActionRequested event,
    Emitter<DirectionInboxState> emit,
  ) async {
    emit(
      state.copyWith(
        processingDirectionId: event.directionId,
        clearError: true,
      ),
    );
    try {
      switch (event.action) {
        case DirectionAction.acknowledge:
          await _repository.acknowledgeDirection(
            directionId: event.directionId,
            acknowledgedBy: event.actor ?? 'operator',
          );
          break;
        case DirectionAction.startWorking:
          await _repository.startWorkingDirection(
            directionId: event.directionId,
            startedBy: event.actor ?? 'operator',
          );
          break;
        case DirectionAction.complete:
          await _repository.completeDirection(
            directionId: event.directionId,
            completedBy: event.actor ?? 'operator',
            completionSummary: event.completionSummary ?? '',
          );
          break;
        case DirectionAction.reject:
          await _repository.rejectDirection(
            directionId: event.directionId,
            rejectedBy: event.actor ?? 'operator',
            rejectionReason: event.rejectionReason ?? '',
          );
          break;
        case DirectionAction.supersede:
          await _repository.supersedeDirection(
            directionId: event.directionId,
            supersededByDirectionId: event.supersededByDirectionId ?? '',
            supersededBy: event.actor ?? 'operator',
          );
          break;
      }
      emit(state.copyWith(clearProcessing: true, clearError: true));
      add(DirectionInboxRefreshRequested());
    } catch (e) {
      emit(state.copyWith(clearProcessing: true, errorMessage: e.toString()));
    }
  }

  void _onStatusFilterChanged(
    DirectionInboxStatusFilterChanged event,
    Emitter<DirectionInboxState> emit,
  ) {
    emit(state.copyWith(currentStatusFilter: event.status));
    add(
      DirectionInboxLoaded(
        status: event.status,
        targetType: state.currentTargetTypeFilter,
      ),
    );
  }

  void _onTargetTypeFilterChanged(
    DirectionInboxTargetTypeFilterChanged event,
    Emitter<DirectionInboxState> emit,
  ) {
    emit(state.copyWith(currentTargetTypeFilter: event.targetType));
    add(
      DirectionInboxLoaded(
        status: state.currentStatusFilter,
        targetType: event.targetType,
      ),
    );
  }

  void _onRefreshRequested(
    DirectionInboxRefreshRequested event,
    Emitter<DirectionInboxState> emit,
  ) {
    add(
      DirectionInboxLoaded(
        status: state.currentStatusFilter,
        targetType: state.currentTargetTypeFilter,
      ),
    );
  }
}

class DirectionInboxState {
  const DirectionInboxState({
    this.isLoading = false,
    this.isCreating = false,
    this.directions = const [],
    this.currentStatusFilter,
    this.currentTargetTypeFilter,
    this.processingDirectionId,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isCreating;
  final List<HumanDirectionSummaryResponse> directions;
  final String? currentStatusFilter;
  final String? currentTargetTypeFilter;
  final String? processingDirectionId;
  final String? errorMessage;

  DirectionInboxState copyWith({
    bool? isLoading,
    bool? isCreating,
    List<HumanDirectionSummaryResponse>? directions,
    String? currentStatusFilter,
    String? currentTargetTypeFilter,
    String? processingDirectionId,
    String? errorMessage,
    bool clearError = false,
    bool clearProcessing = false,
  }) {
    return DirectionInboxState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      directions: directions ?? this.directions,
      currentStatusFilter: currentStatusFilter ?? this.currentStatusFilter,
      currentTargetTypeFilter:
          currentTargetTypeFilter ?? this.currentTargetTypeFilter,
      processingDirectionId: clearProcessing
          ? null
          : (processingDirectionId ?? this.processingDirectionId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

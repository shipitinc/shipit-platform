import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/control_plane_repository.dart';
import 'runs_event.dart';

class RunsBloc extends Bloc<RunsEvent, RunsState> {
  RunsBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const RunsState()) {
    on<RunsLoaded>(_onLoaded);
    on<RunsFilterChanged>(_onFilterChanged);
  }

  final ControlPlaneRepository _repository;
  List<RunItem> _allRuns = const [];

  Future<void> _onLoaded(RunsLoaded event, Emitter<RunsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final workItems = await _repository.listWorkItems(limit: 50);
      _allRuns = workItems
          .map(
            (item) => RunItem(
              id: item.workItemId,
              name: item.title,
              description: item.description,
              state: item.state,
              blockingHumanDecisionId: item.blockingHumanDecisionId,
              startedAt: item.createdAt,
              completedAt: item.completedAt,
              agent: 'opencode',
              category: 'workflow',
            ),
          )
          .toList();
      emit(
        state.copyWith(
          isLoading: false,
          filter: state.filter,
          runs: _filter(_allRuns, state.filter),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void _onFilterChanged(RunsFilterChanged event, Emitter<RunsState> emit) {
    emit(
      state.copyWith(
        filter: event.filter,
        runs: _filter(_allRuns, event.filter),
      ),
    );
  }

  List<RunItem> _filter(List<RunItem> runs, RunsFilter filter) {
    return switch (filter) {
      RunsFilter.all => runs,
      RunsFilter.workingOnIt =>
        runs.where((r) => r.state == 'agent_executing').toList(),
      RunsFilter.needsYou =>
        runs
            .where(
              (r) => r.blockingHumanDecisionId != null && !_isTerminal(r.state),
            )
            .toList(),
      RunsFilter.finished =>
        runs
            .where((r) => r.state == 'completed' || r.state == 'deployed')
            .toList(),
      RunsFilter.failed =>
        runs
            .where(
              (r) =>
                  r.state == 'agent_failed' ||
                  r.state == 'deployment_failed' ||
                  r.state == 'review_rejected',
            )
            .toList(),
    };
  }

  bool _isTerminal(String state) =>
      state == 'completed' || state == 'deployed' || state == 'cancelled';
}

class RunsState {
  const RunsState({
    this.isLoading = false,
    this.runs = const [],
    this.filter = RunsFilter.all,
    this.errorMessage,
  });

  final bool isLoading;
  final List<RunItem> runs;
  final RunsFilter filter;
  final String? errorMessage;

  RunsState copyWith({
    bool? isLoading,
    List<RunItem>? runs,
    RunsFilter? filter,
    String? errorMessage,
  }) {
    return RunsState(
      isLoading: isLoading ?? this.isLoading,
      runs: runs ?? this.runs,
      filter: filter ?? this.filter,
      errorMessage: errorMessage,
    );
  }
}

class RunItem {
  const RunItem({
    required this.id,
    required this.name,
    this.description,
    required this.state,
    this.blockingHumanDecisionId,
    required this.startedAt,
    this.completedAt,
    required this.agent,
    required this.category,
  });

  final String id;
  final String name;
  final String? description;
  final String state;
  final String? blockingHumanDecisionId;
  final DateTime startedAt;

  /// Set once the item reached a terminal state.
  final DateTime? completedAt;
  final String agent;
  final String category;

  String get plainName =>
      description != null && description!.isNotEmpty ? description! : name;
}

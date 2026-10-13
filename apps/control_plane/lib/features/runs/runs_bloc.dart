import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/plain_language.dart';
import '../../data/control_plane_repository.dart';
import 'runs_event.dart';

class RunsBloc extends Bloc<RunsEvent, RunsState> {
  RunsBloc({required this._repository}) : super(const RunsState()) {
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

  /// The bloc's own filter, delegated to [WorkFilter].
  ///
  /// ## Why there is no predicate written here
  ///
  /// This once carried its own switch over [RunsFilter], and it was WRONG in a
  /// way that could not announce itself: `workingOnIt` was a strict
  /// `== PlainStatus.workingOnIt`, which silently excludes `awaitingReview`,
  /// `waitingToStart` and `readyToBuild`, all of which [WorkFilter] — the
  /// implementation the operator actually sees, because the page applies it to
  /// the rows it renders — includes.
  ///
  /// Two predicates over one question is how they drift, and this pair had
  /// already drifted. Nothing caught it, for two reasons worth keeping in mind:
  ///
  ///  * the page re-filters at render time, so the wrong answer was overwritten
  ///    before it reached a screen — the duplication was invisible exactly
  ///    while it was present; and
  ///  * `state.filter` is always `RunsFilter.all` in production, because
  ///    nothing dispatches [RunsFilterChanged] outside tests. The wrong arms
  ///    were unreachable, so the defect was one wiring change away from being a
  ///    user-facing bug with no error and no empty state to explain it: rows
  ///    would simply not be there.
  ///
  /// So there is one implementation and it is [WorkFilter.matches]. The
  /// agreement between "what the bloc filtered" and "what the page filtered" is
  /// no longer maintained by two switches that happen to agree — it is
  /// maintained by there being one, and `test/blocs/runs_bloc_test.dart`
  /// re-derives it independently over every status, so a second predicate
  /// reintroduced here fails that test.
  List<RunItem> _filter(List<RunItem> runs, RunsFilter filter) {
    final work = _asWorkFilter(filter);
    return work == WorkFilter.all
        ? runs
        : runs
              .where(
                (r) => work.matches(
                  PlainLanguage.statusFor(
                    r.state,
                    blocked: r.blockingHumanDecisionId != null,
                  ),
                ),
              )
              .toList();
  }
}

/// Maps the bloc's filter onto THE filter — [WorkFilter].
///
/// An exhaustive switch rather than a lookup by name, so adding a member to
/// either enum becomes a compile error here instead of a runtime miss. The two
/// enums are kept rather than merged because they answer different questions:
/// [RunsFilter] is the bloc's STATE — and is only ever written by tests today —
/// while [WorkFilter] is the design's filter set and carries the labels the
/// tabs print.
WorkFilter _asWorkFilter(RunsFilter filter) => switch (filter) {
  RunsFilter.all => WorkFilter.all,
  RunsFilter.workingOnIt => WorkFilter.workingOnIt,
  RunsFilter.needsYou => WorkFilter.needsYou,
  RunsFilter.finished => WorkFilter.finished,
  RunsFilter.failed => WorkFilter.failed,
};

/// The filters the design exposes, in board order, and THE implementation of
/// "which rows belong under this filter".
///
/// It lives beside [RunsBloc] rather than beside the page because it is no
/// longer a page concern: both the page and the bloc now ask it, and an enum
/// two files ask must not live inside one of them.
enum WorkFilter {
  all('All work'),
  workingOnIt('Working on it'),
  needsYou('Needs you'),
  finished('Finished'),
  failed('Failed');

  const WorkFilter(this.label);

  final String label;

  /// True when a row belongs under this filter.
  bool matches(PlainStatus status) => switch (this) {
    WorkFilter.all => true,
    WorkFilter.workingOnIt =>
      status == PlainStatus.workingOnIt ||
          status == PlainStatus.awaitingReview ||
          status == PlainStatus.waitingToStart ||
          // A row that says "Ready to build" IS work in flight from the
          // operator's side: the system is about to start on it by itself and
          // nobody is being waited on. Leaving it out made an
          // `implementation_ready` item appear only under "All", so an operator
          // asking "what is working on it?" was silently not shown the queue
          // the implementation lane is about to drain — the filter answered a
          // different question than the one asked, with no empty state to say
          // so. `readyToBuild` reads as work-in-progress here for the same
          // reason it takes an accent tick in `PlainStatus.tickColor`.
          status == PlainStatus.readyToBuild,
    WorkFilter.needsYou => status.isOperatorTurn,
    WorkFilter.finished => status == PlainStatus.finished,
    WorkFilter.failed =>
      status == PlainStatus.needsYouItFailed || status == PlainStatus.stopped,
  };
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

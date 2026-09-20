import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/plain_language.dart';
import '../../data/control_plane_repository.dart';
import 'home_event.dart';

/// Loads everything the Overview screen renders.
///
/// The design's Overview is four bands over one snapshot: metrics, "What's
/// happening now", "Waiting for your approval", and "Machines and next steps".
/// They are fetched together so the single `LIVE / updated …` stamp is honest
/// about all of them.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const HomeState()) {
    on<HomeLoaded>(_onLoaded);
  }

  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(HomeLoaded event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final overview = await _repository.getOverview();
      final workItems = await _repository.listWorkItems(limit: 4);
      final decisions = await _repository.pendingDecisions(limit: 2);

      // Elapsed times are measured against the server's own snapshot clock so
      // the page never mixes browser time into a durable number.
      final asOf = overview.generatedAt ?? DateTime.now();

      emit(
        state.copyWith(
          isLoading: false,
          clearError: true,
          runningCount: overview.running,
          waitingCount: overview.waitingOnYou,
          recentCount: overview.recentlyFinished,
          finishedPassed: overview.finishedPassed,
          finishedFailed: overview.finishedFailed,
          generatedAt: asOf,
          machinesBusy: overview.machinesBusy,
          machinesTotal: overview.machinesTotal,
          recentRuns: workItems
              .map(
                (item) => RunSummary(
                  id: item.workItemId,
                  title: PlainLanguage.headline(
                    title: item.title,
                    description: item.description,
                  ),
                  technicalTitle: item.title,
                  stateWire: item.state,
                  blocked: item.blockingHumanDecisionId != null,
                  startedAt: item.createdAt,
                  elapsed: (item.completedAt ?? asOf).difference(
                    item.createdAt,
                  ),
                ),
              )
              .toList(),
          gates: decisions
              .map(
                (d) => GateSummary(
                  decisionId: d.decisionId,
                  workItemId: d.workItemId,
                  decisionTypeWire: d.decisionType,
                  question: d.question ?? 'A decision is needed.',
                  recommendation: d.recommendation,
                  waiting: d.requestedAt == null
                      ? null
                      : asOf.difference(d.requestedAt!),
                ),
              )
              .toList(),
          jobs: overview.jobs
              .map(
                (j) => JobSummary(
                  jobId: j.jobId,
                  workItemId: j.workItemId,
                  stateWire: j.state,
                  blockedOnDecision: j.blockedOnDecision,
                  attempt: j.attempt,
                  maxAttempts: j.maxAttempts,
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

class HomeState {
  const HomeState({
    this.isLoading = false,
    this.runningCount = 0,
    this.waitingCount = 0,
    this.recentCount = 0,
    this.finishedPassed = 0,
    this.finishedFailed = 0,
    this.generatedAt,
    this.machinesBusy = 0,
    this.machinesTotal = 0,
    this.recentRuns = const [],
    this.gates = const [],
    this.jobs = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final int runningCount;
  final int waitingCount;
  final int recentCount;
  final int finishedPassed;
  final int finishedFailed;

  /// Server snapshot time; drives the freshness stamp and all elapsed values.
  final DateTime? generatedAt;

  final int machinesBusy;
  final int machinesTotal;
  final List<RunSummary> recentRuns;
  final List<GateSummary> gates;
  final List<JobSummary> jobs;
  final String? errorMessage;

  HomeState copyWith({
    bool? isLoading,
    int? runningCount,
    int? waitingCount,
    int? recentCount,
    int? finishedPassed,
    int? finishedFailed,
    DateTime? generatedAt,
    int? machinesBusy,
    int? machinesTotal,
    List<RunSummary>? recentRuns,
    List<GateSummary>? gates,
    List<JobSummary>? jobs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      runningCount: runningCount ?? this.runningCount,
      waitingCount: waitingCount ?? this.waitingCount,
      recentCount: recentCount ?? this.recentCount,
      finishedPassed: finishedPassed ?? this.finishedPassed,
      finishedFailed: finishedFailed ?? this.finishedFailed,
      generatedAt: generatedAt ?? this.generatedAt,
      machinesBusy: machinesBusy ?? this.machinesBusy,
      machinesTotal: machinesTotal ?? this.machinesTotal,
      recentRuns: recentRuns ?? this.recentRuns,
      gates: gates ?? this.gates,
      jobs: jobs ?? this.jobs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// A row in "What's happening now".
class RunSummary {
  const RunSummary({
    required this.id,
    required this.title,
    this.technicalTitle,
    required this.stateWire,
    required this.blocked,
    required this.startedAt,
    required this.elapsed,
  });

  final String id;

  /// Plain-language headline: the description when there is one.
  final String title;

  /// The durable technical title, surfaced only in technical details.
  final String? technicalTitle;

  /// Durable state; never rendered directly outside technical details.
  final String stateWire;
  final bool blocked;
  final DateTime startedAt;
  final Duration elapsed;

  PlainStatus get status =>
      PlainLanguage.statusFor(stateWire, blocked: blocked);
}

/// A card in "Waiting for your approval".
class GateSummary {
  const GateSummary({
    required this.decisionId,
    required this.workItemId,
    required this.decisionTypeWire,
    required this.question,
    this.recommendation,
    this.waiting,
  });

  final String decisionId;
  final String workItemId;
  final String decisionTypeWire;
  final String question;

  /// Rendered as "We suggest: …" when the record carries one.
  final String? recommendation;
  final Duration? waiting;

  String get typeLabel => PlainLanguage.decisionType(decisionTypeWire);
}

/// An entry in "Machines and next steps".
class JobSummary {
  const JobSummary({
    required this.jobId,
    required this.workItemId,
    required this.stateWire,
    required this.blockedOnDecision,
    required this.attempt,
    required this.maxAttempts,
  });

  final String jobId;
  final String workItemId;
  final String stateWire;
  final bool blockedOnDecision;
  final int attempt;
  final int maxAttempts;

  /// Plain phrasing for the job's own state, per `Job State` in the design.
  String get stateLabel => switch (stateWire) {
    'running' => 'Running now',
    'claimed' => 'Starting',
    'retryWaiting' => 'Trying again',
    _ => 'Waiting',
  };

  /// The `Job Desc` line. Only says something it can substantiate.
  String? get description {
    if (blockedOnDecision) return 'needs your approval first';
    if (stateWire == 'retryWaiting') {
      return 'attempt $attempt of $maxAttempts';
    }
    if (stateWire == 'running') return 'running now';
    return 'waiting for a free machine';
  }

  bool get isAttention => blockedOnDecision || stateWire == 'retryWaiting';
}

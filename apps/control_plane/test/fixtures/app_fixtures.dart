import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/shared/app_shell.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:control_plane/features/home/home_event.dart';
import 'package:control_plane/features/runs/runs_bloc.dart';
import 'package:control_plane/features/runs/runs_event.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/features/run_detail/run_detail_event.dart';
import 'package:control_plane/features/needs_you/needs_you_bloc.dart';
import 'package:control_plane/features/needs_you/needs_you_event.dart';
import 'package:control_plane/features/decision_detail/decision_detail_bloc.dart';
import 'package:control_plane/features/decision_detail/decision_detail_event.dart';

class MockRepository implements ControlPlaneRepository {
  MockRepository({
    this.overviewResponse,
    this.workItems = const [],
    this.decisions = const [],
    this.workItemDetail,
    this.decisionDetail,
    this.resolvedDecisions = const [],
  });

  final OverviewResponse? overviewResponse;
  final List<WorkItemResponse> workItems;
  final List<DecisionResponse> decisions;
  final WorkItemDetailResponse? workItemDetail;
  final DecisionDetailResponse? decisionDetail;

  /// Decisions that already carry an outcome.
  final List<DecisionResponse> resolvedDecisions;

  @override
  Future<ProductDetailResponse> getProductDetail(String productId) async {
    final d = productDetail;
    if (d == null) throw StateError('no product detail in fake');
    return d;
  }

  /// Detail the fake returns. Null unless a test sets it.
  ProductDetailResponse? productDetail;

  @override
  Future<List<ProductSummaryResponse>> listProductSummaries() async =>
      productSummaries;

  /// Products the fake reports. Empty unless a test sets it.
  List<ProductSummaryResponse> productSummaries = const [];

  @override
  Future<OverviewResponse> getOverview() async =>
      overviewResponse ??
      OverviewResponse(running: 5, waitingOnYou: 2, recentlyFinished: 12);

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    int? limit,
  }) async {
    var items = workItems;
    if (state != null) {
      items = items.where((i) => i.state == state).toList();
    }
    if (limit != null && items.length > limit) {
      items = items.sublist(0, limit);
    }
    return items;
  }

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async =>
      decisions;

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async =>
      workItemDetail ??
      WorkItemDetailResponse(
        workItem: WorkItemResponse(
          workItemId: workItemId,
          title: 'Sample Run',
          state: 'agent_executing',
          createdAt: DateTime(2026, 9, 15, 10, 0),
          updatedAt: DateTime(2026, 9, 15, 10, 30),
        ),
        transitionHistory: [],
      );

  @override
  Future<DecisionDetailResponse> inspectDecision(String workItemId) async =>
      decisionDetail ??
      DecisionDetailResponse(
        decisionId: 'dec-1',
        workItemId: workItemId,
        decisionType: 'design_approval',
        status: 'pending',
        question: 'Approve deployment?',
        context: DecisionContext(
          workflowState: 'waiting_for_human_decision',
          availableOptions: ['approve', 'reject'],
        ),
        options: [
          DecisionOption(
            optionId: 'opt-1',
            label: 'approve',
            recommended: true,
          ),
          DecisionOption(
            optionId: 'opt-2',
            label: 'reject',
            recommended: false,
          ),
        ],
        blocking: true,
        requestedAt: DateTime(2026, 9, 15, 10, 0),
      );

  @override
  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {}
  @override
  Future<List<JobSummaryResponse>> jobsForWorkItem(String workItemId) async =>
      const [];

  @override
  Future<List<DecisionResponse>> recentDecisions({
    int? limit,
    int? offset,
  }) async => resolvedDecisions;
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  // ---- ADR 0020 + ADR 0019 governance fakes -------------------------------

  @override
  Future<DecisionResponse> requestLifecycleDecision({
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async =>
      throw UnimplementedError('fake: requestLifecycleDecision');

  @override
  Future<DecisionResponse> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) async =>
      throw UnimplementedError('fake: requestPolicyAuthorisation');

  @override
  Future<DecisionResponse> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    bool noWorkInFlight = false,
  }) async =>
      throw UnimplementedError('fake: resolveLifecycleDecision');

  @override
  Future<PolicyResponse> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async =>
      throw UnimplementedError('fake: resolvePolicyAuthorisation');

  @override
  Future<void> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async =>
      throw UnimplementedError('fake: revokeStandingPolicy');

}

Widget buildTestableWidget(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Widget buildTestableAppShell(String initialLocation, {Widget? child}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                child ?? const Scaffold(body: Center(child: Text('home'))),
          ),
          GoRoute(
            path: '/runs',
            builder: (context, state) =>
                child ?? const Scaffold(body: Center(child: Text('runs'))),
          ),
          GoRoute(
            path: '/runs/:id',
            builder: (context, state) =>
                child ??
                const Scaffold(body: Center(child: Text('run detail'))),
          ),
          GoRoute(
            path: '/needs-you',
            builder: (context, state) =>
                child ?? const Scaffold(body: Center(child: Text('needs you'))),
          ),
          GoRoute(
            path: '/needs-you/:id',
            builder: (context, state) =>
                child ??
                const Scaffold(body: Center(child: Text('decision detail'))),
          ),
        ],
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

HomeBloc createSeededHomeBloc({MockRepository? repository}) {
  final repo = repository ?? MockRepository();
  return HomeBloc(repository: repo)..add(HomeLoaded());
}

RunsBloc createSeededRunsBloc({MockRepository? repository}) {
  final repo = repository ?? MockRepository();
  return RunsBloc(repository: repo)..add(RunsLoaded());
}

RunDetailBloc createSeededRunDetailBloc({
  MockRepository? repository,
  String? runId,
}) {
  final repo = repository ?? MockRepository();
  return RunDetailBloc(runId: runId ?? 'wi-1', repository: repo)
    ..add(RunDetailLoaded());
}

NeedsYouBloc createSeededNeedsYouBloc({MockRepository? repository}) {
  final repo = repository ?? MockRepository();
  return NeedsYouBloc(repository: repo)..add(NeedsYouLoaded());
}

DecisionDetailBloc createSeededDecisionDetailBloc({
  MockRepository? repository,
  String? decisionId,
  String? runId,
}) {
  final repo = repository ?? MockRepository();
  return DecisionDetailBloc(
    decisionId: decisionId ?? 'dec-1',
    runId: runId ?? 'wi-1',
    repository: repo,
  )..add(DecisionDetailLoaded());
}

WorkItemResponse makeWorkItem({
  required String id,
  required String title,
  required String state,
  DateTime? createdAt,
  String? description,
}) {
  return WorkItemResponse(
    workItemId: id,
    title: title,
    state: state,
    description: description,
    createdAt: createdAt ?? DateTime(2026, 9, 15, 10, 0),
    updatedAt: createdAt ?? DateTime(2026, 9, 15, 10, 30),
  );
}

DecisionResponse makeDecision({
  required String id,
  required String workItemId,
  required String workItemTitle,
  String? workItemDescription,
  String? question,
  bool blocking = true,
  String decisionType = 'design_approval',
  String? recommendation,
  DateTime? requestedAt,
  List<DecisionOption>? options,
}) {
  return DecisionResponse(
    decisionId: id,
    workItemId: workItemId,
    workItemTitle: workItemTitle,
    workItemDescription: workItemDescription,
    decisionType: decisionType,
    status: 'pending',
    question: question ?? 'Approve?',
    recommendation: recommendation,
    blocking: blocking,
    requestedAt: requestedAt ?? DateTime(2026, 9, 15, 10, 0),
    context: DecisionContext(
      workflowState: 'waiting_for_human_decision',
      availableOptions: ['approve', 'reject'],
    ),
    options:
        options ??
        [
          DecisionOption(
            optionId: 'approve',
            label: 'approve',
            description: 'Design is approved',
            recommended: true,
          ),
          DecisionOption(
            optionId: 'rework',
            label: 'rework',
            description: 'Design goes back for changes',
            recommended: false,
          ),
          DecisionOption(
            optionId: 'reject',
            label: 'reject',
            description: 'Design is turned down',
            recommended: false,
          ),
        ],
  );
}

TransitionResponse makeTransition({
  required String from,
  required String to,
  DateTime? at,
}) {
  return TransitionResponse(
    transitionId: 't-${from}_$to',
    workItemId: 'wi-1',
    fromState: from,
    toState: to,
    transitionedAt: at ?? DateTime(2026, 9, 15, 10, 0),
  );
}

/// Marks a fixture decision as resolved, for the "Already decided" ledger.
extension DecisionOutcomeFixture on DecisionResponse {
  DecisionResponse copyWithOutcome({
    required String choice,
    DateTime? resolvedAt,
    String decider = 'operator',
    String rationale = 'Recorded in a test.',
  }) {
    return DecisionResponse(
      decisionId: decisionId,
      workItemId: workItemId,
      workItemTitle: workItemTitle,
      workItemDescription: workItemDescription,
      decisionType: decisionType,
      status: 'resolved',
      question: question,
      context: context,
      options: options,
      recommendation: recommendation,
      blocking: blocking,
      requestedAt: requestedAt,
      expiration: expiration,
      artifactRefs: artifactRefs,
      choice: choice,
      decider: decider,
      rationale: rationale,
      resolvedAt: resolvedAt,
      signature: signature,
    );
  }
}

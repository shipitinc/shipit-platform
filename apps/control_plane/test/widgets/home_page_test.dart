import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:control_plane/features/home/home_event.dart';

void main() {
  group('HomeBloc widget integration', () {
    testWidgets('loads and displays summary data', (tester) async {
      final repository = _MockRepository();
      repository.overviewResponse = OverviewResponse(
        running: 3,
        waitingOnYou: 1,
        recentlyFinished: 12,
      );
      repository.workItemsResponse = [
        WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Deploy frontend',
          state: 'running',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];

      final bloc = HomeBloc(repository: repository)..add(HomeLoaded());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<HomeBloc>.value(
            value: bloc,
            child: const _TestHomeView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Running: 3'), findsOneWidget);
      expect(find.text('Waiting: 1'), findsOneWidget);
      expect(find.text('Recent: 12'), findsOneWidget);
      expect(find.text('Deploy frontend'), findsOneWidget);
    });
  });
}

class _TestHomeView extends StatelessWidget {
  const _TestHomeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Running: ${state.runningCount}'),
              Text('Waiting: ${state.waitingCount}'),
              Text('Recent: ${state.recentCount}'),
              for (final run in state.recentRuns) Text(run.title),
            ],
          ),
        );
      },
    );
  }
}

class _MockRepository implements ControlPlaneRepository {
  OverviewResponse? overviewResponse;
  List<WorkItemResponse>? workItemsResponse;

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
      OverviewResponse(running: 0, waitingOnYou: 0, recentlyFinished: 0);

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    int? limit,
  }) async => workItemsResponse ?? [];

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async => [];

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<DecisionDetailResponse> inspectDecision(String workItemId) async =>
      throw UnimplementedError();

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
  }) async => const [];
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

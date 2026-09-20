import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:control_plane/features/home/home_event.dart';

class MockControlPlaneRepository implements ControlPlaneRepository {
  MockControlPlaneRepository({
    this.overviewResponse,
    this.workItemsResponse,
    this.throwError,
  });

  OverviewResponse? overviewResponse;
  List<WorkItemResponse>? workItemsResponse;
  Object? throwError;

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
  Future<OverviewResponse> getOverview() async {
    if (throwError != null) throw throwError!;
    return overviewResponse ??
        OverviewResponse(running: 0, waitingOnYou: 0, recentlyFinished: 0);
  }

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    int? limit,
  }) async {
    if (throwError != null) throw throwError!;
    return workItemsResponse ?? [];
  }

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

void main() {
  group('HomeBloc', () {
    late MockControlPlaneRepository repository;

    setUp(() {
      repository = MockControlPlaneRepository();
    });

    test('initial state is empty', () {
      final bloc = HomeBloc(repository: repository);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.runningCount, 0);
      expect(bloc.state.waitingCount, 0);
      expect(bloc.state.recentCount, 0);
      expect(bloc.state.recentRuns, isEmpty);
    });

    test('emits loaded state with data on HomeLoaded', () async {
      repository.overviewResponse = OverviewResponse(
        running: 5,
        waitingOnYou: 2,
        recentlyFinished: 10,
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
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.runningCount, 5);
      expect(bloc.state.waitingCount, 2);
      expect(bloc.state.recentCount, 10);
      expect(bloc.state.recentRuns.length, 1);
      expect(bloc.state.recentRuns.first.id, 'wi-001');
      expect(bloc.state.recentRuns.first.title, 'Deploy frontend');
      expect(bloc.state.recentRuns.first.stateWire, 'running');
    });

    test('emits error state on failure', () async {
      repository.throwError = Exception('Connection failed');

      final bloc = HomeBloc(repository: repository)..add(HomeLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.errorMessage!, contains('Connection failed'));
    });

    test('handles empty work items', () async {
      repository.overviewResponse = OverviewResponse(
        running: 0,
        waitingOnYou: 0,
        recentlyFinished: 0,
      );
      repository.workItemsResponse = [];

      final bloc = HomeBloc(repository: repository)..add(HomeLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.runningCount, 0);
      expect(bloc.state.recentRuns, isEmpty);
    });
  });
}

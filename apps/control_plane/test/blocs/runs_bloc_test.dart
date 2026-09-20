import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/runs/runs_bloc.dart';
import 'package:control_plane/features/runs/runs_event.dart';

class MockControlPlaneRepository implements ControlPlaneRepository {
  MockControlPlaneRepository({this.workItemsResponse, this.throwError});

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
  Future<OverviewResponse> getOverview() async => throw UnimplementedError();

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
  group('RunsBloc', () {
    late MockControlPlaneRepository repository;

    setUp(() {
      repository = MockControlPlaneRepository();
    });

    test('initial state is empty', () {
      final bloc = RunsBloc(repository: repository);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.runs, isEmpty);
    });

    test('emits loaded state with data on RunsLoaded', () async {
      repository.workItemsResponse = [
        WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Deploy frontend',
          state: 'running',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        WorkItemResponse(
          workItemId: 'wi-002',
          title: 'Run tests',
          state: 'success',
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.runs.length, 2);
      expect(bloc.state.runs.first.id, 'wi-001');
      expect(bloc.state.runs.first.name, 'Deploy frontend');
      expect(bloc.state.runs.first.state, 'running');
      expect(bloc.state.runs.last.id, 'wi-002');
    });

    test('emits error state on failure', () async {
      repository.throwError = Exception('Network error');

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.errorMessage!, contains('Network error'));
    });

    test('filters runs by the working-on-it bucket', () async {
      repository.workItemsResponse = [
        WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Deploy frontend',
          state: 'agent_executing',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        WorkItemResponse(
          workItemId: 'wi-002',
          title: 'Run tests',
          state: 'completed',
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(const RunsFilterChanged(RunsFilter.workingOnIt));
      await bloc.stream.firstWhere((s) => s.filter == RunsFilter.workingOnIt);

      expect(bloc.state.runs.length, 1);
      expect(bloc.state.runs.first.id, 'wi-001');
    });

    test('needs-you filter only surfaces blocked items', () async {
      repository.workItemsResponse = [
        WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Deploy frontend',
          state: 'agent_executing',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        WorkItemResponse(
          workItemId: 'wi-002',
          title: 'Fix auth',
          state: 'waiting_for_human_decision',
          blockingHumanDecisionId: 'dec-1',
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(const RunsFilterChanged(RunsFilter.needsYou));
      await bloc.stream.firstWhere((s) => s.filter == RunsFilter.needsYou);

      expect(bloc.state.runs.length, 1);
      expect(bloc.state.runs.first.id, 'wi-002');
    });

    test('plainName prefers the plain description over the title', () {
      final item = RunItem(
        id: 'wi-1',
        name: 'Scheduler claim-CAS dedupe patch',
        description: 'Stop duplicate jobs running twice',
        state: 'agent_executing',
        startedAt: DateTime(2026, 1, 1),
        agent: 'opencode',
        category: 'workflow',
      );
      expect(item.plainName, 'Stop duplicate jobs running twice');
      expect(
        RunItem(
          id: 'wi-2',
          name: 'No description here',
          state: 'completed',
          startedAt: DateTime(2026, 1, 1),
          agent: 'opencode',
          category: 'workflow',
        ).plainName,
        'No description here',
      );
    });
  });
}

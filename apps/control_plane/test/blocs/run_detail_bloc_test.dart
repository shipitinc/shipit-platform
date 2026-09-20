import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/features/run_detail/run_detail_event.dart';

class MockControlPlaneRepository implements ControlPlaneRepository {
  MockControlPlaneRepository({this.workItemDetailResponse, this.throwError});

  WorkItemDetailResponse? workItemDetailResponse;
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
  }) async => [];

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async => [];

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async {
    if (throwError != null) throw throwError!;
    if (workItemDetailResponse == null) throw StateError('No response');
    return workItemDetailResponse!;
  }

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
  group('RunDetailBloc', () {
    late MockControlPlaneRepository repository;

    setUp(() {
      repository = MockControlPlaneRepository();
    });

    test('initial state is empty', () {
      final bloc = RunDetailBloc(runId: 'wi-001', repository: repository);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.runId, '');
      expect(bloc.state.name, '');
      expect(bloc.state.events, isEmpty);
    });

    test('emits loaded state with data on RunDetailLoaded', () async {
      repository.workItemDetailResponse = WorkItemDetailResponse(
        workItem: WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Ship bootstrap E2E journey',
          description: 'Test the full sign-up journey',
          state: 'waiting_for_human_decision',
          blockingHumanDecisionId: 'dec-1',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        transitionHistory: [
          TransitionResponse(
            transitionId: 't-001',
            workItemId: 'wi-001',
            fromState: 'design_approved',
            toState: 'agent_executing',
            transitionedAt: DateTime(2026, 1, 1),
          ),
          TransitionResponse(
            transitionId: 't-002',
            workItemId: 'wi-001',
            fromState: 'review_in_progress',
            toState: 'waiting_for_human_decision',
            transitionedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final bloc = RunDetailBloc(runId: 'wi-001', repository: repository)
        ..add(RunDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.runId, 'wi-001');
      expect(bloc.state.name, 'Ship bootstrap E2E journey');
      expect(bloc.state.description, 'Test the full sign-up journey');
      expect(bloc.state.state, 'waiting_for_human_decision');
      expect(bloc.state.blockingHumanDecisionId, 'dec-1');
      expect(bloc.state.events.length, 2);
      expect(bloc.state.events.first.type, 'agent_executing');
      expect(bloc.state.events.first.message, 'Agent started work');
      expect(bloc.state.events.first.raw, 'design_approved -> agent_executing');
      expect(bloc.state.events.last.message, 'Sent to you for approval');
      expect(
        bloc.state.events.last.raw,
        'review_in_progress -> waiting_for_human_decision',
      );
    });

    test(
      'unmapped transitions use neutral default and keep the raw pair',
      () async {
        repository.workItemDetailResponse = WorkItemDetailResponse(
          workItem: WorkItemResponse(
            workItemId: 'wi-001',
            title: 'Deploy frontend',
            state: 'running',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          transitionHistory: [
            TransitionResponse(
              transitionId: 't-001',
              workItemId: 'wi-001',
              fromState: 'pending',
              toState: 'running',
              transitionedAt: DateTime(2026, 1, 1),
            ),
          ],
        );

        final bloc = RunDetailBloc(runId: 'wi-001', repository: repository)
          ..add(RunDetailLoaded());
        await bloc.stream.firstWhere((s) => !s.isLoading);

        expect(
          bloc.state.events.first.message,
          'The work moved to a new stage.',
        );
        expect(bloc.state.events.first.raw, 'pending -> running');
      },
    );

    test('emits error state on failure', () async {
      repository.throwError = Exception('Not found');

      final bloc = RunDetailBloc(runId: 'wi-001', repository: repository)
        ..add(RunDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.errorMessage!, contains('Not found'));
    });
  });
}

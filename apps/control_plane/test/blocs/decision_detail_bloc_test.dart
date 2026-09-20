import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/decision_detail/decision_detail_bloc.dart';
import 'package:control_plane/features/decision_detail/decision_detail_event.dart';

class MockControlPlaneRepository implements ControlPlaneRepository {
  MockControlPlaneRepository({
    this.decisionDetailResponse,
    this.throwError,
    this.resolveError,
  });

  DecisionDetailResponse? decisionDetailResponse;
  Object? throwError;
  Object? resolveError;

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
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<DecisionDetailResponse> inspectDecision(String workItemId) async {
    if (throwError != null) throw throwError!;
    if (decisionDetailResponse == null) throw StateError('No response');
    return decisionDetailResponse!;
  }

  @override
  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    if (resolveError != null) throw resolveError!;
  }

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
  group('DecisionDetailBloc', () {
    late MockControlPlaneRepository repository;

    setUp(() {
      repository = MockControlPlaneRepository();
    });

    test('initial state is empty', () {
      final bloc = DecisionDetailBloc(
        decisionId: 'dec-001',
        runId: 'wi-001',
        repository: repository,
      );
      expect(bloc.state.isLoading, false);
      expect(bloc.state.decisionId, '');
      expect(bloc.state.selectedChoice, isNull);
      expect(bloc.state.isSubmitted, false);
    });

    test('emits loaded state with data on DecisionDetailLoaded', () async {
      repository.decisionDetailResponse = DecisionDetailResponse(
        decisionId: 'dec-001',
        workItemId: 'wi-001',
        decisionType: 'human',
        status: 'pending',
        question: 'Approve deployment?',
        options: [
          DecisionOption(
            optionId: 'approve',
            label: 'approve',
            recommended: true,
          ),
          DecisionOption(
            optionId: 'reject',
            label: 'reject',
            recommended: false,
          ),
        ],
        blocking: true,
        requestedAt: DateTime(2026, 1, 1),
      );

      final bloc = DecisionDetailBloc(
        decisionId: 'dec-001',
        runId: 'wi-001',
        repository: repository,
      )..add(DecisionDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.decisionId, 'dec-001');
      expect(bloc.state.question, 'Approve deployment?');
      expect(bloc.state.choices.map((c) => c.value), ['approve', 'reject']);
      expect(bloc.state.choices.map((c) => c.label), ['Approve', 'Reject']);
    });

    test('emits selected choice on DecisionChoiceSelected', () async {
      repository.decisionDetailResponse = DecisionDetailResponse(
        decisionId: 'dec-001',
        workItemId: 'wi-001',
        decisionType: 'human',
        status: 'pending',
        question: 'Approve deployment?',
        options: [
          DecisionOption(
            optionId: 'approve',
            label: 'approve',
            recommended: false,
          ),
          DecisionOption(
            optionId: 'reject',
            label: 'reject',
            recommended: false,
          ),
        ],
        blocking: true,
        requestedAt: DateTime(2026, 1, 1),
      );

      final bloc = DecisionDetailBloc(
        decisionId: 'dec-001',
        runId: 'wi-001',
        repository: repository,
      )..add(DecisionDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(DecisionChoiceSelected(choice: 'approve'));
      await bloc.stream.firstWhere((s) => s.selectedChoice == 'approve');

      expect(bloc.state.selectedChoice, 'approve');
    });

    test('emits rationale on DecisionRationaleChanged', () async {
      final bloc = DecisionDetailBloc(
        decisionId: 'dec-001',
        runId: 'wi-001',
        repository: repository,
      );

      bloc.add(DecisionRationaleChanged(rationale: 'Looks good'));
      await bloc.stream.firstWhere((s) => s.rationale == 'Looks good');

      expect(bloc.state.rationale, 'Looks good');
    });

    test('submits decision successfully', () async {
      repository.decisionDetailResponse = DecisionDetailResponse(
        decisionId: 'dec-001',
        workItemId: 'wi-001',
        decisionType: 'human',
        status: 'pending',
        question: 'Approve deployment?',
        options: [
          DecisionOption(
            optionId: 'approve',
            label: 'approve',
            recommended: false,
          ),
        ],
        blocking: true,
        requestedAt: DateTime(2026, 1, 1),
      );

      final bloc = DecisionDetailBloc(
        decisionId: 'dec-001',
        runId: 'wi-001',
        repository: repository,
      )..add(DecisionDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(DecisionChoiceSelected(choice: 'approve'));
      await bloc.stream.firstWhere((s) => s.selectedChoice == 'approve');

      bloc.add(DecisionSubmitted());
      await bloc.stream.firstWhere((s) => s.isSubmitted);

      expect(bloc.state.isSubmitted, true);
      expect(bloc.state.isSubmitting, false);
    });

    test('emits error on resolve failure', () async {
      repository.decisionDetailResponse = DecisionDetailResponse(
        decisionId: 'dec-001',
        workItemId: 'wi-001',
        decisionType: 'human',
        status: 'pending',
        question: 'Approve deployment?',
        options: [
          DecisionOption(
            optionId: 'approve',
            label: 'approve',
            recommended: false,
          ),
        ],
        blocking: true,
        requestedAt: DateTime(2026, 1, 1),
      );
      repository.resolveError = Exception('Resolve failed');

      final bloc = DecisionDetailBloc(
        decisionId: 'dec-001',
        runId: 'wi-001',
        repository: repository,
      )..add(DecisionDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(DecisionChoiceSelected(choice: 'approve'));
      await bloc.stream.firstWhere((s) => s.selectedChoice == 'approve');

      bloc.add(DecisionSubmitted());
      await bloc.stream.firstWhere((s) => s.errorMessage != null);

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.isSubmitted, false);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:control_plane/shared/status_chip.dart';
import 'package:control_plane/features/home/home_page.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:control_plane/features/home/home_event.dart';
import 'package:control_plane/features/needs_you/needs_you_page.dart';
import 'package:control_plane/features/needs_you/needs_you_bloc.dart';
import 'package:control_plane/features/needs_you/needs_you_event.dart';
import 'package:control_plane/features/decision_detail/decision_detail_page.dart';
import 'package:control_plane/features/decision_detail/decision_detail_bloc.dart';
import 'package:control_plane/features/decision_detail/decision_detail_event.dart';
import 'package:control_plane/data/control_plane_repository.dart';

class _MockRepository implements ControlPlaneRepository {
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
      OverviewResponse(running: 5, waitingOnYou: 2, recentlyFinished: 12);

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    int? limit,
  }) async => [];

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async => [
    DecisionResponse(
      decisionId: 'dec-1',
      workItemId: 'wi-1',
      workItemTitle: 'Deploy frontend',
      decisionType: 'human',
      status: 'pending',
      question: 'Approve deployment?',
      context: DecisionContext(
        workflowState: 'awaiting_approval',
        availableOptions: ['approve', 'reject'],
      ),
      options: [
        DecisionOption(optionId: 'opt-1', label: 'approve', recommended: true),
        DecisionOption(optionId: 'opt-2', label: 'reject', recommended: false),
      ],
      blocking: true,
      requestedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<DecisionDetailResponse> inspectDecision(
    String workItemId,
  ) async => DecisionDetailResponse(
    decisionId: 'dec-1',
    workItemId: 'wi-1',
    decisionType: 'human',
    status: 'pending',
    question: 'Approve deployment?',
    context: DecisionContext(
      workflowState: 'awaiting_approval',
      availableOptions: ['approve', 'reject'],
    ),
    options: [
      DecisionOption(optionId: 'opt-1', label: 'approve', recommended: true),
      DecisionOption(optionId: 'opt-2', label: 'reject', recommended: false),
    ],
    blocking: true,
    requestedAt: DateTime(2026, 1, 1),
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
  group('StatusChip accessibility', () {
    testWidgets('announces the status exactly once', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusChip(label: 'RUNNING', type: StatusType.running),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(StatusChip));
      // The visible Text stays in the widget tree but is excluded from the
      // semantics tree, so the consumer hears ONE announcement. Exact match
      // proves the status is not duplicated ('Status: RUNNING\nRUNNING').
      expect(semantics.label, 'Status: RUNNING');
      expect(semantics.label.contains('\n'), isFalse);
      expect(RegExp('RUNNING').allMatches(semantics.label).length, 1);
    });

    testWidgets('every status type announces a single meaningful label', (
      tester,
    ) async {
      for (final type in StatusType.values) {
        final label = type.name.toUpperCase();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatusChip(label: label, type: type),
            ),
          ),
        );

        final semantics = tester.getSemantics(find.byType(StatusChip));
        expect(semantics.label, 'Status: $label');
        expect(RegExp(label).allMatches(semantics.label).length, 1);
      }
    });
  });

  group('HomePage summary card accessibility', () {
    testWidgets('summary cards have semantic labels', (tester) async {
      final repository = _MockRepository();
      final bloc = HomeBloc(repository: repository)..add(HomeLoaded());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<HomeBloc>.value(
            value: bloc,
            child: HomePage(bloc: bloc),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsLabels = find
          .byType(Semantics)
          .evaluate()
          .map((e) {
            final s = e.widget as Semantics;
            return s.properties.label;
          })
          .whereType<String>()
          .toList();

      // The design labels these columns in operator language, not in system
      // vocabulary, so the announced label follows the visible micro label.
      expect(semanticsLabels, contains(startsWith('WORKING ON IT: 5')));
      expect(semanticsLabels, contains(startsWith('NEEDS YOU: 2')));
      expect(semanticsLabels, contains(startsWith('FINISHED: 12')));
    });
  });

  group('Decision card accessibility', () {
    testWidgets('decision cards have semantic labels', (tester) async {
      final repository = _MockRepository();
      final bloc = NeedsYouBloc(repository: repository)..add(NeedsYouLoaded());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NeedsYouBloc>.value(
            value: bloc,
            child: NeedsYouPage(bloc: bloc),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsLabels = find
          .byType(Semantics)
          .evaluate()
          .map((e) {
            final s = e.widget as Semantics;
            return s.properties.label;
          })
          .whereType<String>()
          .toList();

      expect(
        semanticsLabels,
        contains('Decision for Deploy frontend: Approve deployment?'),
      );
    });
  });

  group('DecisionDetailPage submit button accessibility', () {
    testWidgets('submit bar has semantic label when nothing selected', (
      tester,
    ) async {
      final repository = _MockRepository();
      final bloc = DecisionDetailBloc(
        decisionId: 'dec-1',
        runId: 'wi-1',
        repository: repository,
      )..add(DecisionDetailLoaded());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<DecisionDetailBloc>.value(
            value: bloc,
            child: DecisionDetailPage(
              decisionId: 'dec-1',
              workItemId: 'wi-1',
              bloc: bloc,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The design's submit action states what is still missing.
      final submitSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Save my decision, choose an option first',
      );
      expect(submitSemantics, findsOneWidget);
    });

    testWidgets('submit bar updates label after choice selected', (
      tester,
    ) async {
      final repository = _MockRepository();
      final bloc = DecisionDetailBloc(
        decisionId: 'dec-1',
        runId: 'wi-1',
        repository: repository,
      )..add(DecisionDetailLoaded());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<DecisionDetailBloc>.value(
            value: bloc,
            child: DecisionDetailPage(
              decisionId: 'dec-1',
              workItemId: 'wi-1',
              bloc: bloc,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The design uses radio option cards rather than chips; pick the first.
      final option = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith('Approve.'),
      );
      expect(option, findsOneWidget);
      await tester.tap(option.first);
      await tester.pumpAndSettle();

      // A choice alone is not enough: the rationale is required, and the
      // action says so.
      final needsReason = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Save my decision, add a reason first',
      );
      expect(needsReason, findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Matches the test plan.');
      await tester.pumpAndSettle();

      final ready = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Save my decision',
      );
      expect(ready, findsOneWidget);
    });
  });
}

import 'package:control_plane/features/needs_you/needs_you_bloc.dart';
import 'package:control_plane/features/needs_you/needs_you_event.dart';
import 'package:control_plane/features/needs_you/needs_you_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/app_fixtures.dart';

/// A repository that records what was resolved, so the test can assert the
/// button the operator pressed is the choice that reached the wire.
class _RecordingRepository extends MockRepository {
  _RecordingRepository({required super.decisions});

  String? resolvedDecisionId;
  String? resolvedChoice;
  String? resolvedRationale;

  @override
  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    resolvedDecisionId = decisionId;
    resolvedChoice = choice;
    resolvedRationale = rationale;
  }
}

void main() {
  final asOf = DateTime(2026, 9, 16, 12, 0);

  _RecordingRepository repository() => _RecordingRepository(
    decisions: [
      makeDecision(
        id: 'GD-5b1e',
        workItemId: 'WI-9c11',
        workItemTitle: 'Stop duplicate jobs running twice',
        question: 'Approve the design for stopping duplicate jobs?',
        decisionType: 'design_approval',
        recommendation: 'Approve — the plan matches the test plan.',
        requestedAt: asOf.subtract(const Duration(hours: 3)),
      ),
    ],
  );

  Future<(NeedsYouBloc, _RecordingRepository, List<String>)> pump(
    WidgetTester tester,
  ) async {
    final repo = repository();
    final bloc = NeedsYouBloc(repository: repo)..add(NeedsYouLoaded());
    addTearDown(bloc.close);
    final routes = <String>[];

    final router = GoRouter(
      initialLocation: '/needs-you',
      routes: [
        GoRoute(
          path: '/needs-you',
          builder: (context, state) => Scaffold(
            body: NeedsYouPage(bloc: bloc, clock: () => asOf),
          ),
        ),
        GoRoute(
          path: '/needs-you/:id',
          builder: (context, state) {
            routes.add(state.uri.toString());
            return const Scaffold(body: Text('detail'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return (bloc, repo, routes);
  }

  testWidgets('the card body carries no tap action', (tester) async {
    // Pin the logical viewport: `isMobile` reads MediaQuery, and the default
    // test device pixel ratio would put 1280 physical pixels below the mobile
    // breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();
    final (_, _, routes) = await pump(tester);

    // The card groups its contents for screen readers. If that grouping also
    // absorbs the buttons' tap actions, the whole card silently becomes a
    // click target - which is what shipped, and what the web engine turns
    // into a card-sized hit area with no cursor change. Assert on the
    // semantics tree, because a widget-level tap cannot observe it.
    final questionNode = tester.getSemantics(
      find.text('Approve the design for stopping duplicate jobs?'),
    );
    expect(
      questionNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
      reason: 'inert card text must not inherit a tap action',
    );

    await tester.tap(
      find.text('Approve the design for stopping duplicate jobs?'),
    );
    await tester.pumpAndSettle();
    expect(routes, isEmpty);

    handle.dispose();
  });

  testWidgets('a card action records that exact choice', (tester) async {
    // Pin the logical viewport: `isMobile` reads MediaQuery, and the default
    // test device pixel ratio would put 1280 physical pixels below the mobile
    // breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final (_, repo, routes) = await pump(tester);

    // Press the non-recommended action to prove the pressed button wins,
    // rather than the suggested one.
    await tester.tap(find.text('Request changes'));
    await tester.pumpAndSettle();

    // It stays on the list and asks for a reason instead of navigating.
    expect(routes, isEmpty);
    expect(find.text('You chose: Request changes'), findsOneWidget);
    expect(repo.resolvedChoice, isNull, reason: 'no reason given yet');

    await tester.enterText(find.byType(TextField), 'Spacing is wrong.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save: Request changes'));
    await tester.pumpAndSettle();

    expect(repo.resolvedDecisionId, 'GD-5b1e');
    expect(repo.resolvedChoice, 'rework');
    expect(repo.resolvedRationale, 'Spacing is wrong.');
  });

  testWidgets('a reason is required before the action can be saved', (
    tester,
  ) async {
    // Pin the logical viewport: `isMobile` reads MediaQuery, and the default
    // test device pixel ratio would put 1280 physical pixels below the mobile
    // breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final (_, repo, _) = await pump(tester);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save: Approve'),
    );
    expect(button.onPressed, isNull);
    expect(repo.resolvedChoice, isNull);
  });

  testWidgets('cancelling returns the card to its actions', (tester) async {
    // Pin the logical viewport: `isMobile` reads MediaQuery, and the default
    // test device pixel ratio would put 1280 physical pixels below the mobile
    // breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final (_, repo, _) = await pump(tester);

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.text('You chose: Reject'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('You chose: Reject'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
    expect(repo.resolvedChoice, isNull);
  });

  testWidgets('See full details is the only control that leaves the list', (
    tester,
  ) async {
    // Pin the logical viewport: `isMobile` reads MediaQuery, and the default
    // test device pixel ratio would put 1280 physical pixels below the mobile
    // breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final (_, _, routes) = await pump(tester);

    await tester.tap(find.text('See full details'));
    await tester.pumpAndSettle();

    expect(routes.single, '/needs-you/GD-5b1e?wi=WI-9c11');
  });
}

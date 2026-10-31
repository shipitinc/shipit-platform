import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:control_plane/features/home/home_event.dart';
import 'package:control_plane/features/home/home_page.dart';
import 'package:control_plane/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/app_fixtures.dart';

/// Regression for the Home "Waiting for your approval" card deep-linking to
/// `/needs-you/<decisionId>` WITHOUT `?wi=`: `inspectDecision` then read the
/// decisionId as a workItemId and the detail screen failed for every
/// decision. The card must carry the GateSummary's `workItemId` the same way
/// the needs-you and run-detail cards already do.
void main() {
  final asOf = DateTime(2026, 9, 16, 12, 0);

  MockRepository repository() => MockRepository(
    overviewResponse: OverviewResponse(
      running: 1,
      waitingOnYou: 1,
      recentlyFinished: 0,
      generatedAt: asOf,
    ),
    decisions: [
      makeDecision(
        id: 'GD-5b1e',
        workItemId: 'WI-9c11',
        workItemTitle: 'Stop duplicate jobs running twice',
        question: 'Approve the design for stopping duplicate jobs?',
        decisionType: 'design_approval',
        requestedAt: asOf.subtract(const Duration(hours: 3)),
      ),
    ],
  );

  Future<List<String>> pump(WidgetTester tester) async {
    final bloc = HomeBloc(repository: repository())..add(HomeLoaded());
    addTearDown(bloc.close);
    final routes = <String>[];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: HomePage(bloc: bloc, clock: () => asOf),
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

    await tester.pumpWidget(
      MaterialApp.router(theme: ShipItTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    return routes;
  }

  testWidgets(
    'the gate card carries ?wi= so the detail screen can open the decision',
    (tester) async {
      // Pin the logical viewport: `isMobile` reads MediaQuery, and the
      // default device pixel ratio would put 1280 physical pixels below the
      // mobile breakpoint — which renders a different card widget.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final routes = await pump(tester);

      await tester.tap(find.text('Review and decide'));
      await tester.pumpAndSettle();

      expect(routes.single, '/needs-you/GD-5b1e?wi=WI-9c11');
    },
  );

  testWidgets('the mobile gate card carries ?wi= the same way', (tester) async {
    // The narrow layout renders _MobileGateCard — a separate widget that
    // carried the same missing-?wi= bug, so it is pinned separately.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final routes = await pump(tester);

    await tester.tap(find.text('Review and decide'));
    await tester.pumpAndSettle();

    expect(routes.single, '/needs-you/GD-5b1e?wi=WI-9c11');
  });
}

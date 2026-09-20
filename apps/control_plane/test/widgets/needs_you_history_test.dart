import 'package:control_plane/core/theme.dart';
import 'package:control_plane/features/needs_you/needs_you_bloc.dart';
import 'package:control_plane/features/needs_you/needs_you_event.dart';
import 'package:control_plane/features/needs_you/needs_you_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/app_fixtures.dart';

/// The "Already decided" ledger is a five-column table on desktop. On a
/// 390px column that table cannot fit, so the mobile board reduces it to a
/// heading plus a link.
void main() {
  final asOf = DateTime(2026, 9, 16, 12, 0);

  MockRepository repository() => MockRepository(
    decisions: const [],
    resolvedDecisions: [
      makeDecision(
        id: 'GD-4c77',
        workItemId: 'WI-4f2a',
        workItemTitle: 'Sign-up journey E2E harness',
        workItemDescription: 'Test the full sign-up journey',
        question: 'Approve the test plan for the sign-up journey',
        requestedAt: asOf.subtract(const Duration(hours: 5)),
      ).copyWithOutcome(
        choice: 'approve',
        resolvedAt: asOf.subtract(const Duration(hours: 4)),
      ),
      makeDecision(
        id: 'GD-1f03',
        workItemId: 'WI-9c11',
        workItemTitle: 'Scheduler claim-CAS dedupe patch',
        workItemDescription: 'Stop duplicate jobs running twice',
        question: 'Turn down design version 2',
        requestedAt: asOf.subtract(const Duration(hours: 9)),
      ).copyWithOutcome(
        choice: 'reject',
        resolvedAt: asOf.subtract(const Duration(hours: 8)),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bloc = NeedsYouBloc(repository: repository())..add(NeedsYouLoaded());
    addTearDown(bloc.close);

    final router = GoRouter(
      initialLocation: '/needs-you',
      routes: [
        GoRoute(
          path: '/needs-you',
          builder: (context, state) => Scaffold(
            body: NeedsYouPage(bloc: bloc, clock: () => asOf),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: ShipItTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mobile collapses the ledger to a heading and a link', (
    tester,
  ) async {
    await pump(tester, const Size(390, 844));

    expect(find.text('Already decided'), findsOneWidget);
    expect(find.text('See all →'), findsOneWidget);

    // The desktop table headers must not be rendered at this width.
    expect(find.text('WHAT WAS DECIDED'), findsNothing);
    expect(find.text('WHAT CARRIED ON'), findsNothing);

    // Laying out the desktop table in 390px is what caused the overflow.
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile reveals the entries on demand', (tester) async {
    await pump(tester, const Size(390, 844));

    expect(find.textContaining('Approve the test plan'), findsNothing);

    await tester.tap(find.text('See all →'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Approve the test plan'), findsOneWidget);
    expect(find.textContaining('Turn down design version 2'), findsOneWidget);
    // Outcomes keep their plain-language labels.
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop still renders the full table', (tester) async {
    await pump(tester, const Size(1280, 900));

    expect(find.text('WHAT WAS DECIDED'), findsOneWidget);
    expect(find.text('WHAT CARRIED ON'), findsOneWidget);
    expect(find.textContaining('Approve the test plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

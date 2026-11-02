import 'package:control_plane/core/theme.dart';
import 'package:control_plane/features/needs_you/needs_you_bloc.dart';
import 'package:control_plane/features/needs_you/needs_you_event.dart';
import 'package:control_plane/features/needs_you/needs_you_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/app_fixtures.dart';

/// The untruncation is not a decision-detail fix: the same rule holds on
/// every surface a person answers on. These tests pin it on the Needs you
/// page — a pending card's WHAT IT IS fact and the Already decided
/// ledger's question are the same "what this is about" content the
/// decision page now shows whole.
void main() {
  final asOf = DateTime(2026, 9, 16, 12, 0);

  // Long enough to wrap well past two lines in the card's fact column —
  // a clipped render would lose the tail, so asserting the tail proves
  // the full value is on screen.
  const longDescription =
      'Test the full sign-up journey end to end: account creation, email '
      'confirmation, first login, password reset, and the session-expiry '
      'path that silently dropped users on the second device. The harness '
      'must also cover the duplicate-job regression that let the same '
      'sign-up run twice under a second claim.';

  const longQuestion =
      'Approve the sign-up journey test plan, including the password-reset '
      'path and the session-expiry coverage added after the duplicate-claim '
      'regression was found in review?';

  MockRepository repository() => MockRepository(
    decisions: [
      makeDecision(
        id: 'GD-5b1e',
        workItemId: 'WI-4f2a',
        workItemTitle: 'Sign-up journey E2E harness',
        workItemDescription: longDescription,
        question: 'Approve the sign-up journey test plan?',
        decisionType: 'design_approval',
        requestedAt: asOf.subtract(const Duration(hours: 3)),
      ),
    ],
    resolvedDecisions: [
      makeDecision(
        id: 'GD-4c77',
        workItemId: 'WI-9c11',
        workItemTitle: 'Scheduler claim-CAS dedupe patch',
        question: longQuestion,
        requestedAt: asOf.subtract(const Duration(hours: 9)),
      ).copyWithOutcome(
        choice: 'approve',
        resolvedAt: asOf.subtract(const Duration(hours: 8)),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, Size size) async {
    // Pin the logical viewport: `isMobile` reads MediaQuery, and the
    // default device pixel ratio would drop a 1280 physical-pixel window
    // below the mobile breakpoint.
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

  testWidgets('a pending card shows the whole WHAT IT IS fact', (tester) async {
    await pump(tester, const Size(1280, 900));

    expect(find.text('WHAT IT IS'), findsOneWidget);
    final fact = find.textContaining(
      'the same sign-up run twice under a second claim',
    );
    expect(fact, findsOneWidget);
    expect(tester.widget<Text>(fact).maxLines, isNull);
  });

  testWidgets('the decided ledger shows the whole question', (tester) async {
    await pump(tester, const Size(1280, 900));

    final question = find.text(longQuestion);
    expect(question, findsOneWidget);
    expect(tester.widget<Text>(question).maxLines, isNull);
  });

  testWidgets('the decided ledger shows the whole question on mobile too', (
    tester,
  ) async {
    await pump(tester, const Size(390, 844));

    await tester.tap(find.text('See all →'));
    await tester.pumpAndSettle();

    final question = find.text(longQuestion);
    expect(question, findsOneWidget);
    expect(tester.widget<Text>(question).maxLines, isNull);
  });
}

import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/decision_detail/decision_detail_bloc.dart';
import 'package:control_plane/features/decision_detail/decision_detail_event.dart';
import 'package:control_plane/features/decision_detail/decision_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/app_fixtures.dart';

/// Regression for a voided decision rendering as a live one. The server ships
/// `status: 'cancelled'` with a null `choice`; the client used `choice == null`
/// alone as "unresolved", so a cancelled record rendered "WAITING FOR YOU"
/// with working option cards and a live submit panel — an affordance the
/// durable record can never honour.
void main() {
  final asOf = DateTime(2026, 9, 16, 12, 0);

  MockRepository repository() => MockRepository(
    decisionDetail: DecisionDetailResponse(
      decisionId: 'GD-void',
      workItemId: 'WI-9c11',
      workItemTitle: 'Stop duplicate jobs running twice',
      decisionType: 'design_approval',
      // Voided by review-repair: closed, but carrying no choice.
      status: 'cancelled',
      question: 'Approve the design for stopping duplicate jobs?',
      blocking: false,
      requestedAt: asOf.subtract(const Duration(hours: 3)),
      context: DecisionContext(
        workflowState: 'waiting_for_human_decision',
        availableOptions: ['approve', 'reject'],
      ),
      options: [
        DecisionOption(
          optionId: 'approve',
          label: 'approve',
          description: 'Design is approved',
          recommended: true,
        ),
        DecisionOption(
          optionId: 'reject',
          label: 'reject',
          description: 'Design is turned down',
          recommended: false,
        ),
      ],
    ),
  );

  Future<DecisionDetailBloc> pump(WidgetTester tester) async {
    final bloc = DecisionDetailBloc(
      decisionId: 'GD-void',
      runId: 'WI-9c11',
      repository: repository(),
    )..add(DecisionDetailLoaded());
    addTearDown(bloc.close);

    final router = GoRouter(
      initialLocation: '/needs-you/GD-void?wi=WI-9c11',
      routes: [
        GoRoute(
          path: '/needs-you',
          builder: (context, state) => const Scaffold(body: Text('needs you')),
        ),
        GoRoute(
          path: '/needs-you/:id',
          builder: (context, state) => Scaffold(
            body: DecisionDetailPage(
              decisionId: 'GD-void',
              workItemId: 'WI-9c11',
              bloc: bloc,
              clock: () => asOf,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: ShipItTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets('a cancelled decision renders read-only', (tester) async {
    // Pin the logical viewport: `isMobile` reads MediaQuery, and the default
    // device pixel ratio would put 1280 physical pixels below the mobile
    // breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bloc = await pump(tester);

    // The header tells the truth about the record: not waiting, not decided.
    expect(find.text('CANCELLED'), findsOneWidget);
    expect(find.text('WAITING FOR YOU'), findsNothing);

    // No live affordance: no option cards, no rationale field, no submit.
    expect(find.text('Save my decision'), findsNothing);
    expect(find.text('YOUR OPTIONS'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('No answer is needed'), findsOneWidget);

    // And the guard is in the state, not just the widget tree.
    expect(bloc.state.isCancelled, isTrue);
    expect(bloc.state.alreadyResolved, isFalse);
  });
}

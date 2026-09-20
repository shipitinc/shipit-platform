import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/decision_detail/decision_detail_bloc.dart';
import 'package:control_plane/features/decision_detail/decision_detail_event.dart';
import 'package:control_plane/features/decision_detail/decision_detail_page.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:control_plane/features/home/home_event.dart';
import 'package:control_plane/features/home/home_page.dart';
import 'package:control_plane/features/needs_you/needs_you_bloc.dart';
import 'package:control_plane/features/needs_you/needs_you_event.dart';
import 'package:control_plane/features/needs_you/needs_you_page.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/features/run_detail/run_detail_event.dart';
import 'package:control_plane/features/run_detail/run_detail_page.dart';
import 'package:control_plane/features/runs/runs_bloc.dart';
import 'package:control_plane/features/runs/runs_event.dart';
import 'package:control_plane/features/runs/runs_page.dart';
import 'package:control_plane/shared/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/app_fixtures.dart';
import 'helpers/design_fonts.dart';
import 'helpers/golden_tolerance.dart';

/// Renders each screen at the mobile board's own 390x844 viewport, inside the
/// real shell, so the goldens can be held next to the Penpot `BPM ·` boards.
void main() {
  setUpAll(() async {
    await loadDesignFonts();
    useTolerantGoldens();
  });

  final asOf = DateTime(2026, 9, 16, 12, 0);
  DateTime clock() => asOf.add(const Duration(seconds: 12));

  MockRepository repository() => MockRepository(
    overviewResponse: OverviewResponse(
      running: 2,
      waitingOnYou: 2,
      recentlyFinished: 5,
      finishedPassed: 4,
      finishedFailed: 1,
      generatedAt: asOf,
      machinesBusy: 1,
      machinesTotal: 2,
    ),
    workItems: [
      makeWorkItem(
        id: 'WI-4f2a',
        title: 'Sign-up journey E2E harness',
        description: 'Test the full sign-up journey',
        state: 'agent_executing',
        createdAt: asOf.subtract(const Duration(minutes: 42)),
      ),
      makeWorkItem(
        id: 'WI-9c11',
        title: 'Scheduler claim-CAS dedupe patch',
        description: 'Stop duplicate jobs running twice',
        state: 'waiting_for_human_decision',
        createdAt: asOf.subtract(const Duration(hours: 3, minutes: 12)),
      ),
      makeWorkItem(
        id: 'WI-7e0b',
        title: 'Postgres migration contract test',
        description: 'Check the database upgrade is safe',
        state: 'agent_executing',
        createdAt: asOf.subtract(const Duration(hours: 1, minutes: 8)),
      ),
      makeWorkItem(
        id: 'WI-3d8c',
        title: 'Penpot design authority probe',
        description: 'Check we can reach the design tool',
        state: 'agent_failed',
        createdAt: asOf.subtract(const Duration(hours: 2, minutes: 2)),
      ),
    ],
    decisions: [
      makeDecision(
        id: 'GD-5b1e',
        workItemId: 'WI-9c11',
        workItemTitle: 'Scheduler claim-CAS dedupe patch',
        workItemDescription: 'Stop duplicate jobs running twice',
        question: 'Approve the design for stopping duplicate jobs?',
        decisionType: 'design_approval',
        recommendation:
            'Approve — the plan matches the test plan, and no design risks '
            'were found.',
        requestedAt: asOf.subtract(const Duration(hours: 3, minutes: 12)),
      ),
      makeDecision(
        id: 'GD-8a32',
        workItemId: 'WI-3d8c',
        workItemTitle: 'Penpot design authority probe',
        workItemDescription: 'Check we can reach the design tool',
        question: 'Try the design tool check again?',
        decisionType: 'escalation',
        recommendation:
            'Resume — the retry limit was hit by a setup check, not by the '
            'work itself.',
        requestedAt: asOf.subtract(const Duration(hours: 2, minutes: 2)),
      ),
    ],
    decisionDetail: DecisionDetailResponse(
      decisionId: 'GD-5b1e',
      workItemId: 'WI-9c11',
      workItemTitle: 'Scheduler claim-CAS dedupe patch',
      workItemDescription: 'Stop duplicate jobs running twice',
      decisionType: 'design_approval',
      status: 'pending',
      question: 'Approve the design for stopping duplicate jobs?',
      recommendation:
          'Approve — the plan matches the test plan, and no design risks were '
          'found.',
      blocking: true,
      requestedAt: asOf.subtract(const Duration(hours: 3, minutes: 12)),
      context: DecisionContext(
        workflowState: 'design_in_review',
        availableOptions: ['approve', 'rework', 'reject'],
      ),
      options: [
        DecisionOption(
          optionId: 'approve',
          label: 'approve',
          description: 'The build continues with this design',
          recommended: true,
        ),
        DecisionOption(
          optionId: 'rework',
          label: 'rework',
          description: 'The designer revises it',
          recommended: false,
        ),
        DecisionOption(
          optionId: 'reject',
          label: 'reject',
          description: 'This work stops for good',
          recommended: false,
        ),
      ],
    ),
    workItemDetail: WorkItemDetailResponse(
      workItem: WorkItemResponse(
        workItemId: 'WI-9c11',
        title: 'Scheduler claim-CAS dedupe patch',
        description: 'Stop duplicate jobs running twice',
        state: 'waiting_for_human_decision',
        blockingHumanDecisionId: 'GD-5b1e',
        createdAt: asOf.subtract(const Duration(hours: 3, minutes: 12)),
        updatedAt: asOf,
      ),
      transitionHistory: [
        makeTransition(
          from: 'draft',
          to: 'planning',
          at: asOf.subtract(const Duration(hours: 3, minutes: 10)),
        ),
        makeTransition(
          from: 'planning',
          to: 'planned',
          at: asOf.subtract(const Duration(hours: 3, minutes: 5)),
        ),
        makeTransition(
          from: 'planned',
          to: 'design_in_review',
          at: asOf.subtract(const Duration(hours: 3)),
        ),
        makeTransition(
          from: 'design_in_review',
          to: 'waiting_for_human_decision',
          at: asOf.subtract(const Duration(hours: 2, minutes: 50)),
        ),
      ],
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    ThemeData theme,
    String location,
    Map<String, Widget Function()> screens,
  ) async {
    // The mobile board's viewport, with an explicit ratio so the composition
    // is chosen from a known logical width.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = repository();
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(repository: repo, child: child),
          routes: [
            for (final entry in screens.entries)
              GoRoute(
                path: entry.key,
                pageBuilder: (context, state) =>
                    NoTransitionPage(child: entry.value()),
              ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: theme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  final themes = {'light': ShipItTheme.light(), 'dark': ShipItTheme.dark()};

  for (final theme in themes.entries) {
    testWidgets('Overview · mobile (${theme.key})', (tester) async {
      final bloc = HomeBloc(repository: repository())..add(HomeLoaded());
      addTearDown(bloc.close);
      await pump(tester, theme.value, '/', {
        '/': () => HomePage(bloc: bloc, clock: clock),
        '/runs': () => const SizedBox.shrink(),
        '/needs-you': () => const SizedBox.shrink(),
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_overview_${theme.key}.png'),
      );
    });

    testWidgets('All work · mobile (${theme.key})', (tester) async {
      final bloc = RunsBloc(repository: repository())..add(RunsLoaded());
      addTearDown(bloc.close);
      await pump(tester, theme.value, '/runs', {
        '/': () => const SizedBox.shrink(),
        '/runs': () => RunsPage(bloc: bloc, clock: clock),
        '/needs-you': () => const SizedBox.shrink(),
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_all_work_${theme.key}.png'),
      );
    });

    testWidgets('Needs you · mobile (${theme.key})', (tester) async {
      final bloc = NeedsYouBloc(repository: repository())
        ..add(NeedsYouLoaded());
      addTearDown(bloc.close);
      await pump(tester, theme.value, '/needs-you', {
        '/': () => const SizedBox.shrink(),
        '/runs': () => const SizedBox.shrink(),
        '/needs-you': () => NeedsYouPage(bloc: bloc, clock: clock),
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_needs_you_${theme.key}.png'),
      );
    });

    testWidgets('Run detail · mobile (${theme.key})', (tester) async {
      final bloc = RunDetailBloc(runId: 'WI-9c11', repository: repository())
        ..add(RunDetailLoaded());
      addTearDown(bloc.close);
      await pump(tester, theme.value, '/runs/WI-9c11', {
        '/': () => const SizedBox.shrink(),
        '/runs': () => const SizedBox.shrink(),
        '/runs/:id': () =>
            RunDetailPage(runId: 'WI-9c11', bloc: bloc, clock: clock),
        '/needs-you': () => const SizedBox.shrink(),
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_run_detail_${theme.key}.png'),
      );
    });

    testWidgets('Decision detail · mobile (${theme.key})', (tester) async {
      final bloc = DecisionDetailBloc(
        decisionId: 'GD-5b1e',
        runId: 'WI-9c11',
        repository: repository(),
      )..add(DecisionDetailLoaded());
      addTearDown(bloc.close);
      await pump(tester, theme.value, '/needs-you/GD-5b1e', {
        '/': () => const SizedBox.shrink(),
        '/runs': () => const SizedBox.shrink(),
        '/needs-you': () => const SizedBox.shrink(),
        '/needs-you/:id': () => DecisionDetailPage(
          decisionId: 'GD-5b1e',
          workItemId: 'WI-9c11',
          bloc: bloc,
          clock: clock,
        ),
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_decision_detail_${theme.key}.png'),
      );
    });
  }
}

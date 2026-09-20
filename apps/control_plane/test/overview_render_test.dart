import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:control_plane/features/home/home_event.dart';
import 'package:control_plane/features/home/home_page.dart';
import 'package:control_plane/shared/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/app_fixtures.dart';
import 'helpers/design_fonts.dart';
import 'helpers/golden_tolerance.dart';

/// Renders the Overview at the design's own viewport with the design's own
/// sample data, so the result can be compared side by side with the Penpot
/// board `BP · Home`.
void main() {
  setUpAll(() async {
    await loadDesignFonts();
    useTolerantGoldens();
  });

  final asOf = DateTime(2026, 9, 16, 12, 0);

  MockRepository designFixture() => MockRepository(
    overviewResponse: OverviewResponse(
      running: 2,
      waitingOnYou: 2,
      recentlyFinished: 5,
      finishedPassed: 4,
      finishedFailed: 1,
      generatedAt: asOf,
      machinesBusy: 1,
      machinesTotal: 2,
      jobs: [
        JobSummaryResponse(
          jobId: 'JOB-31',
          workItemId: 'WI-9c11',
          state: 'queued',
          jobType: 'agentExecution',
          createdAt: asOf,
          blockedOnDecision: true,
          attempt: 1,
          maxAttempts: 3,
        ),
        JobSummaryResponse(
          jobId: 'JOB-28',
          workItemId: 'WI-4f2a',
          state: 'running',
          jobType: 'agentExecution',
          createdAt: asOf,
          blockedOnDecision: false,
          attempt: 1,
          maxAttempts: 3,
        ),
      ],
    ),
    workItems: [
      makeWorkItem(
        id: 'WI-4f2a',
        title: 'Test the full sign-up journey',
        state: 'agent_executing',
        createdAt: asOf.subtract(const Duration(minutes: 42)),
      ),
      makeWorkItem(
        id: 'WI-9c11',
        title: 'Stop duplicate jobs running twice',
        state: 'waiting_for_human_decision',
        createdAt: asOf.subtract(const Duration(hours: 3, minutes: 12)),
      ),
      makeWorkItem(
        id: 'WI-7e0b',
        title: 'Check the database upgrade is safe',
        state: 'agent_executing',
        createdAt: asOf.subtract(const Duration(hours: 1, minutes: 8)),
      ),
      makeWorkItem(
        id: 'WI-3d8c',
        title: 'Check we can reach the design tool',
        state: 'agent_failed',
        createdAt: asOf.subtract(const Duration(hours: 2, minutes: 2)),
      ),
    ],
    decisions: [
      makeDecision(
        id: 'GD-5b1e',
        workItemId: 'WI-9c11',
        workItemTitle: 'Stop duplicate jobs running twice',
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
        workItemTitle: 'Check we can reach the design tool',
        question: 'Try the design tool check again?',
        decisionType: 'escalation',
        recommendation:
            'Resume — the retry limit was hit by a setup check, not by the '
            'work itself.',
        requestedAt: asOf.subtract(const Duration(hours: 2, minutes: 2)),
      ),
    ],
  );

  Future<void> pumpOverview(WidgetTester tester, ThemeData theme) async {
    final bloc = HomeBloc(repository: designFixture())..add(HomeLoaded());
    addTearDown(bloc.close);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: Row(
              children: [
                const Sidebar(needsYouCount: 2, allWorkCount: 4),
                Expanded(child: child),
              ],
            ),
          ),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => BlocProvider<HomeBloc>.value(
                value: bloc,
                child: HomePage(
                  bloc: bloc,
                  // Freeze the freshness stamp at the design's "12 seconds".
                  clock: () => asOf.add(const Duration(seconds: 12)),
                ),
              ),
            ),
            GoRoute(
              path: '/runs',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/needs-you/:id',
              builder: (context, state) => const SizedBox.shrink(),
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

    // Asset images decode asynchronously and are skipped by the fake async
    // zone, so a golden would otherwise capture an empty logomark box.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Overview · light matches the design board', (tester) async {
    // Pin the logical viewport. The composition is chosen from MediaQuery, so
    // the device pixel ratio has to be explicit or 1280 physical pixels land
    // below the mobile breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpOverview(tester, ShipItTheme.light());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/overview_light.png'),
    );
  });

  testWidgets('Overview · dark matches the design board', (tester) async {
    // Pin the logical viewport. The composition is chosen from MediaQuery, so
    // the device pixel ratio has to be explicit or 1280 physical pixels land
    // below the mobile breakpoint.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpOverview(tester, ShipItTheme.dark());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/overview_dark.png'),
    );
  });
}

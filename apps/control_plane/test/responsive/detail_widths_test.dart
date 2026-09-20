import 'package:control_plane/core/theme.dart';
import 'package:control_plane/features/decision_detail/decision_detail_bloc.dart';
import 'package:control_plane/features/decision_detail/decision_detail_event.dart';
import 'package:control_plane/features/decision_detail/decision_detail_page.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/features/run_detail/run_detail_event.dart';
import 'package:control_plane/features/run_detail/run_detail_page.dart';
import 'package:control_plane/shared/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import '../fixtures/app_fixtures.dart';
import '../helpers/design_fonts.dart';

/// The design draws 1280 and 390 and nothing in between. Every width in that
/// gap still has to lay out: the detail screens carry a fixed 392px side
/// panel, so just above the mobile breakpoint the two columns cannot coexist
/// and the header's separator chain has no give.
void main() {
  setUpAll(loadDesignFonts);

  for (final w in [
    841.0,
    860.0,
    900.0,
    1000.0,
    1024.0,
    1100.0,
    1280.0,
    1600.0,
  ]) {
    testWidgets('detail screens lay out at ${w.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repo = MockRepository(
        workItemDetail: WorkItemDetailResponse(
          workItem: WorkItemResponse(
            workItemId: 'WI-1',
            title: 'T',
            description: 'Plain title',
            state: 'waiting_for_human_decision',
            blockingHumanDecisionId: 'GD-1',
            createdAt: DateTime(2026, 9, 16, 9),
            updatedAt: DateTime(2026, 9, 16, 12),
          ),
          transitionHistory: const [],
        ),
      );
      final rd = RunDetailBloc(runId: 'WI-1', repository: repo)
        ..add(RunDetailLoaded());
      final dd = DecisionDetailBloc(
        decisionId: 'GD-1',
        runId: 'WI-1',
        repository: repo,
      )..add(DecisionDetailLoaded());
      addTearDown(rd.close);
      addTearDown(dd.close);
      final router = GoRouter(
        initialLocation: '/runs/WI-1',
        routes: [
          ShellRoute(
            builder: (c, s, child) => AppShell(repository: repo, child: child),
            routes: [
              GoRoute(
                path: '/runs/:id',
                builder: (c, s) => RunDetailPage(runId: 'WI-1', bloc: rd),
              ),
              GoRoute(
                path: '/needs-you/:id',
                builder: (c, s) =>
                    DecisionDetailPage(decisionId: 'GD-1', bloc: dd),
              ),
              GoRoute(
                path: '/runs',
                builder: (c, s) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/needs-you',
                builder: (c, s) => const SizedBox.shrink(),
              ),
              GoRoute(path: '/', builder: (c, s) => const SizedBox.shrink()),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: ShipItTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      router.go('/needs-you/GD-1');
      await tester.pumpAndSettle();
    });
  }
}

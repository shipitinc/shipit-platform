import 'dart:async';

import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/defect_report/create_defect_bloc.dart';
import 'package:control_plane/features/defect_report/create_defect_page.dart';
import 'package:control_plane/features/defect_report/defect_detail_bloc.dart';
import 'package:control_plane/features/defect_report/defect_detail_event.dart';
import 'package:control_plane/features/defect_report/defect_detail_page.dart';
import 'package:control_plane/features/defect_report/defect_list_bloc.dart';
import 'package:control_plane/features/defect_report/defect_list_event.dart';
import 'package:control_plane/features/defect_report/defect_list_page.dart';
import 'package:control_plane/features/defect_report/defect_list_state.dart';
import 'package:control_plane/shared/app_shell.dart';
import 'package:control_plane/shared/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/defect_fixtures.dart';
import 'helpers/design_fonts.dart';
import 'helpers/golden_tolerance.dart';

/// Renders the defect surfaces at the two board viewports so the goldens can be
/// held next to the approved Human Bug Reporting boards.
///
/// Every case is a CANDIDATE for human review. Nothing here asserts that a
/// render matches a board: the board references are not resolved in this pass,
/// so the goldens are a faithful record of what the app renders, and the human
/// reviewer is what decides whether that is right.
void main() {
  setUpAll(() async {
    await loadDesignFonts();
    useTolerantGoldens();
  });

  /// Hosts a screen inside the real rail (desktop) or the real shell (mobile),
  /// at the viewport the board is drawn at.
  Future<void> pump(
    WidgetTester tester, {
    required String location,
    required Map<String, Widget Function()> screens,
    required bool mobile,
    required ThemeData theme,
    DefectRepository? repository,
    bool settle = true,
    Size? size,
  }) async {
    tester.view.physicalSize =
        size ?? (mobile ? const Size(390, 844) : const Size(1280, 900));
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = repository ?? DefectRepository();

    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) => mobile
              ? AppShell(repository: repo, child: child)
              : Scaffold(
                  body: Row(
                    children: [
                      const Sidebar(
                        needsYouCount: 2,
                        allWorkCount: 4,
                        productCount: 3,
                        reportsCount: 8,
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
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

    // A skeleton or spinner animates forever, so the loading candidate is
    // captured from a fixed number of frames instead of a settled tree.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// The four list states the brief names, each with the data that produces it.
  final listCases = <String, DefectRepository Function()>{
    // The eight rows `BP · Defect List · Populated · Light` draws, verbatim.
    'populated': () => DefectRepository(
      defects: [
        makeDefect(
          defectId: 'DEF-000001',
          title: 'Run status shows pending for all runs',
          severity: 'blocking',
          status: 'resolved',
          classification: 'implementation_defect',
          affectedWorkItemId: 'WI-4f2a',
        ),
        makeDefect(
          defectId: 'DEF-000002',
          title: 'Needs you is wrong after I approve',
          severity: 'annoying',
          status: 'triaging',
          affectedWorkItemId: 'WI-9c11',
        ),
        makeDefect(
          defectId: 'DEF-000003',
          title: 'Approval flow UX is confusing',
          severity: 'cosmetic',
          status: 'confirmed',
          classification: 'design_defect',
          affectedWorkItemId: 'WI-7e0b',
        ),
        makeDefect(
          defectId: 'DEF-000004',
          title: 'Cannot scroll past 50 items',
          severity: 'annoying',
          status: 'fix_in_progress',
          classification: 'implementation_defect',
          affectedWorkItemId: 'WI-3d8c',
        ),
        makeDefect(
          defectId: 'DEF-000005',
          title: 'Database connection times out',
          severity: 'blocking',
          status: 'reported',
          affectedRunId: 'rn-819a',
        ),
        makeDefect(
          defectId: 'DEF-000006',
          title: 'Typo in the success message',
          severity: 'cosmetic',
          status: 'needs_clarification',
        ),
        makeDefect(
          defectId: 'DEF-000007',
          title: 'State transition fails on retry',
          severity: 'data_loss',
          status: 'duplicate',
          affectedWorkItemId: 'WI-1aa5',
        ),
        makeDefect(
          defectId: 'DEF-000008',
          title: 'Button disappears on hover',
          severity: 'cosmetic',
          status: 'not_reproducible',
          affectedWorkItemId: 'WI-6cf0',
        ),
      ],
    ),
    'loading': () => DefectRepository(holdList: true),
    'empty': () => DefectRepository(),
    'error': () => DefectRepository(
      listError: StateError('the defect service is unreachable'),
    ),
  };

  group('Defect list', () {
    for (final themeMode in ['light', 'dark']) {
      final theme = themeMode == 'light'
          ? ShipItTheme.light()
          : ShipItTheme.dark();
      final suffix = themeMode == 'light' ? '' : '_dark';
      for (final mobile in [false, true]) {
        final vp = mobile ? 'mobile' : 'desktop';
        for (final entry in listCases.entries) {
          testWidgets('${entry.key} ($vp) $themeMode', (tester) async {
            final repo = entry.value();
            // Seeds `Err Since` — the board's `last successful reading 2m ago`
            // stamp is only real once a read has actually succeeded, so the
            // golden supplies that history explicitly.
            final bloc = DefectListBloc(
              repository: repo,
              initial: DefectListState(
                lastSuccessAt: defectClock().subtract(
                  const Duration(minutes: 2),
                ),
              ),
            )..add(DefectListLoaded());
            addTearDown(repo.releaseHeldList);
            addTearDown(() => unawaited(bloc.close()));

            await pump(
              tester,
              location: '/reports',
              repository: repo,
              mobile: mobile,
              theme: theme,
              settle: entry.key != 'loading',
              screens: {
                '/reports': () =>
                    DefectListPage(bloc: bloc, clock: defectClock),
              },
            );

            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'goldens/defect_list_${entry.key}_$vp$suffix.png',
              ),
            );

            // Objective content check: the state must show its own copy, not just
            // a frame of the right size.
            switch (entry.key) {
              case 'populated':
                expect(find.text('DEF-000001'), findsOneWidget);
                expect(
                  find.text('Run status shows pending for all runs'),
                  findsOneWidget,
                );
                expect(find.text('Reported'), findsWidgets);
              case 'empty':
                expect(find.text('No defects reported'), findsOneWidget);
                expect(
                  find.textContaining(
                    'A defect appears here the moment you report it.',
                  ),
                  findsOneWidget,
                );
              case 'error':
                expect(find.textContaining('could not reach'), findsWidgets);
                expect(find.text('Try again'), findsOneWidget);
                expect(
                  find.text('last successful reading 2m ago'),
                  findsOneWidget,
                );
              case 'loading':
                expect(
                  find.text('Reading the system’s records…'),
                  findsOneWidget,
                );
            }
          });
        }
      }
    }
  });

  group('Create defect', () {
    for (final themeMode in ['light', 'dark']) {
      final theme = themeMode == 'light'
          ? ShipItTheme.light()
          : ShipItTheme.dark();
      final suffix = themeMode == 'light' ? '' : '_dark';
      for (final mobile in [false, true]) {
        final vp = mobile ? 'mobile' : 'desktop';
        testWidgets('empty form ($vp) $themeMode', (tester) async {
          final repo = DefectRepository();
          final bloc = CreateDefectBloc(
            repository: repo,
            reporter: 'operator@shipit.dev',
          );
          addTearDown(() => unawaited(bloc.close()));

          await pump(
            tester,
            location: '/reports/new-bug',
            repository: repo,
            mobile: mobile,
            theme: theme,
            size: mobile ? const Size(390, 1080) : null,
            screens: {'/reports/new-bug': () => CreateDefectPage(bloc: bloc)},
          );

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/create_defect_$vp$suffix.png'),
          );
        });
      }
    }
  });

  /// The instant every detail fixture is anchored to: `defectAsOf` minus the
  /// board's own `running 3h 12m`.
  final created = defectAsOf.subtract(const Duration(hours: 3, minutes: 12));

  /// Minutes before [defectAsOf]; keeps the timelines readable instead of
  /// spelling the same subtraction out a dozen times.
  DateTime at(int minutesAgo) =>
      defectAsOf.subtract(Duration(minutes: minutesAgo));

  /// Every detail record carries the board's evidence block: a text report plus
  /// the two screenshots the second link counts.
  List<DefectEvidenceResponse> evidenceFor(
    String defectId,
    String description,
  ) => [
    makeDefectEvidence(
      evidenceId: 'EV-$defectId-1',
      defectId: defectId,
      kind: 'text_description',
      description: description,
      sourceRef: 'report',
    ),
    makeDefectEvidence(
      evidenceId: 'EV-$defectId-2',
      defectId: defectId,
      kind: 'screenshot',
      description: '390x844 capture of the reported behaviour.',
      sourceRef: 'worker-capture',
    ),
    makeDefectEvidence(
      evidenceId: 'EV-$defectId-3',
      defectId: defectId,
      kind: 'screenshot',
      description: '1280x900 capture of the reported behaviour.',
      sourceRef: 'worker-capture',
    ),
  ];

  DefectEventResponse ev(
    String id,
    String defectId,
    int sequence,
    String type,
    int minutesAgo, {
    String? from,
    String? to,
    String actorType = 'agent',
    String actorId = 'TJ-55c1',
  }) => makeDefectEvent(
    eventId: id,
    defectId: defectId,
    sequence: sequence,
    type: type,
    fromStatus: from,
    toStatus: to,
    actorType: actorType,
    actorId: actorId,
    at: at(minutesAgo),
  );

  /// The six detail states the brief names, each with the defect record and the
  /// evidence, clarifications and events that make the state legible.
  final detailCases = <String, InspectDefectResponse Function()>{
    'untriaged': () => InspectDefectResponse(
      defect: makeDefect(
        defectId: 'DF-4a19',
        title: 'Needs you chip loses its count on mobile',
        severity: 'blocking',
        status: 'reported',
        affectedRunId: 'WI-9c11',
        createdAt: created,
      ),
      evidence: evidenceFor('DF-4a19', 'Steps as typed by the reporter.'),
      clarifications: const [],
      events: [
        ev(
          'EVT-1',
          'DF-4a19',
          1,
          'created',
          192,
          to: 'reported',
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev(
          'EVT-2',
          'DF-4a19',
          2,
          'evidence_added',
          190,
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
      ],
    ),
    'triage_complete': () => InspectDefectResponse(
      defect: makeDefect(
        defectId: 'DF-7c02',
        title: 'Run detail header truncates long run titles',
        severity: 'annoying',
        status: 'confirmed',
        classification: 'ui_defect',
        affectedRunId: 'WI-3d8c',
        createdAt: created,
      ),
      evidence: evidenceFor(
        'DF-7c02',
        '390x844 capture of the truncated header.',
      ),
      clarifications: const [],
      events: [
        ev(
          'EVT-1',
          'DF-7c02',
          1,
          'created',
          192,
          to: 'reported',
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev(
          'EVT-2',
          'DF-7c02',
          2,
          'evidence_added',
          190,
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev('EVT-3', 'DF-7c02', 3, 'triage_started', 90),
        ev(
          'EVT-4',
          'DF-7c02',
          4,
          'triage_completed',
          75,
          from: 'reported',
          to: 'confirmed',
        ),
      ],
      triageResult: makeTriageResult(
        triageResultId: 'TR-1',
        defectId: 'DF-7c02',
      ),
    ),
    'needs_clarification': () => InspectDefectResponse(
      defect: makeDefect(
        defectId: 'DF-9f31',
        title: 'Scheduler dispatches the same job twice',
        severity: 'blocking',
        status: 'needs_clarification',
        affectedRunId: 'WI-2ef9',
        createdAt: created,
      ),
      evidence: evidenceFor(
        'DF-9f31',
        'Log excerpt showing the duplicate dispatch.',
      ),
      clarifications: [
        makeClarification(
          clarificationId: 'CL-1',
          defectId: 'DF-9f31',
          question: 'Which run showed the duplicate dispatch?',
          reason: 'The report names a symptom but not the run.',
        ),
      ],
      events: [
        ev(
          'EVT-1',
          'DF-9f31',
          1,
          'created',
          192,
          to: 'reported',
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev(
          'EVT-2',
          'DF-9f31',
          2,
          'evidence_added',
          190,
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev('EVT-3', 'DF-9f31', 3, 'triage_started', 90),
        ev(
          'EVT-4',
          'DF-9f31',
          4,
          'clarification_requested',
          60,
          to: 'needs_clarification',
        ),
      ],
      triageResult: makeTriageResult(
        triageResultId: 'TR-2',
        defectId: 'DF-9f31',
        classification: null,
        confidence: null,
        rationale: null,
        recommendedAction: null,
        needsClarification: true,
        clarificationQuestion: 'Which run showed the duplicate dispatch?',
        clarificationReason: 'The report names a symptom but not the run.',
      ),
    ),
    'design_remediation_pending': () => InspectDefectResponse(
      defect: makeDefect(
        defectId: 'DF-3d70',
        title: 'Sidebar rail overlaps the content gutter',
        severity: 'annoying',
        status: 'remediation_planned',
        classification: 'ui_defect',
        affectedRunId: 'WI-4f2a',
        remediationWorkItemId: 'WI-6f0d',
        createdAt: created,
      ),
      evidence: evidenceFor(
        'DF-3d70',
        'The overlapping rail captured at both breakpoints.',
      ),
      clarifications: const [],
      events: [
        ev(
          'EVT-1',
          'DF-3d70',
          1,
          'created',
          192,
          to: 'reported',
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev(
          'EVT-2',
          'DF-3d70',
          2,
          'evidence_added',
          190,
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev(
          'EVT-3',
          'DF-3d70',
          3,
          'triage_completed',
          90,
          from: 'reported',
          to: 'confirmed',
        ),
        ev(
          'EVT-4',
          'DF-3d70',
          4,
          'remediation_created',
          55,
          from: 'confirmed',
          to: 'remediation_planned',
        ),
        ev('EVT-5', 'DF-3d70', 5, 'remediation_started', 50),
      ],
      remediationWorkItem: makeRemediationWorkItem(
        workItemId: 'WI-6f0d',
        title: 'Fix the sidebar rail overlap',
        state: 'planning',
      ),
    ),
    'verification_pending': () => InspectDefectResponse(
      defect: makeDefect(
        defectId: 'DF-2b88',
        title: 'Verified fix never reaches the resolved state',
        severity: 'blocking',
        status: 'fix_ready_for_verification',
        classification: 'logic_defect',
        affectedRunId: 'WI-1aa5',
        remediationWorkItemId: 'WI-8b21',
        createdAt: created,
      ),
      evidence: evidenceFor(
        'DF-2b88',
        'Before and after capture of the state transition.',
      ),
      clarifications: const [],
      events: [
        ev(
          'EVT-1',
          'DF-2b88',
          1,
          'created',
          192,
          to: 'reported',
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev(
          'EVT-2',
          'DF-2b88',
          2,
          'triage_completed',
          150,
          from: 'reported',
          to: 'confirmed',
        ),
        ev(
          'EVT-3',
          'DF-2b88',
          3,
          'remediation_created',
          120,
          from: 'confirmed',
          to: 'remediation_planned',
        ),
        ev('EVT-4', 'DF-2b88', 4, 'remediation_started', 110),
        ev('EVT-5', 'DF-2b88', 5, 'remediation_completed', 40),
        ev(
          'EVT-6',
          'DF-2b88',
          6,
          'verification_requested',
          35,
          from: 'fix_in_progress',
          to: 'fix_ready_for_verification',
        ),
      ],
      remediationWorkItem: makeRemediationWorkItem(
        workItemId: 'WI-8b21',
        title: 'Resolve the defect after verification',
        state: 'agent_executing',
      ),
    ),
    'resolved_verified': () => InspectDefectResponse(
      defect: makeDefect(
        defectId: 'DF-5e42',
        title: 'Products back link missing on mobile',
        severity: 'cosmetic',
        status: 'resolved',
        classification: 'ui_defect',
        affectedRunId: 'WI-7e0b',
        remediationWorkItemId: 'WI-1c93',
        createdAt: created,
      ),
      evidence: evidenceFor('DF-5e42', 'The restored back link at 390x844.'),
      clarifications: const [],
      events: [
        ev(
          'EVT-1',
          'DF-5e42',
          1,
          'created',
          192,
          to: 'reported',
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
        ev(
          'EVT-2',
          'DF-5e42',
          2,
          'triage_completed',
          150,
          from: 'reported',
          to: 'confirmed',
        ),
        ev(
          'EVT-3',
          'DF-5e42',
          3,
          'remediation_created',
          120,
          from: 'confirmed',
          to: 'remediation_planned',
        ),
        ev('EVT-4', 'DF-5e42', 4, 'remediation_completed', 60),
        ev(
          'EVT-5',
          'DF-5e42',
          5,
          'verification_requested',
          50,
          from: 'fix_in_progress',
          to: 'fix_ready_for_verification',
        ),
        ev(
          'EVT-6',
          'DF-5e42',
          6,
          'verification_completed',
          30,
          from: 'fix_ready_for_verification',
          to: 'resolved',
          actorType: 'human',
          actorId: 'operator@shipit.dev',
        ),
      ],
      remediationWorkItem: makeRemediationWorkItem(
        workItemId: 'WI-1c93',
        title: 'Add the Products back link',
        state: 'completed',
        completedAt: at(25),
      ),
    ),
  };

  group('Defect detail', () {
    // `BP · Defect Detail · Dark` and `BPM · Defect Detail · Dark` exist, but
    // no dark detail golden is generated until that board pair has been read
    // the way the light pair was: the palette alone is not authority for the
    // whole composition.
    final theme = ShipItTheme.light();
    for (final mobile in [false, true]) {
      final vp = mobile ? 'mobile' : 'desktop';
      for (final entry in detailCases.entries) {
        testWidgets('${entry.key} ($vp)', (tester) async {
          final detail = entry.value();
          final repo = DefectRepository(detail: detail);
          final bloc = DefectDetailBloc(
            repository: repo,
            defectId: detail.defect.defectId,
          )..add(DefectDetailLoaded());
          addTearDown(() => unawaited(bloc.close()));

          await pump(
            tester,
            location: '/reports/${detail.defect.defectId}',
            repository: repo,
            mobile: mobile,
            theme: theme,
            screens: {
              '/reports/:defectId': () => DefectDetailPage(
                defectId: detail.defect.defectId,
                bloc: bloc,
                clock: defectClock,
              ),
            },
          );

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/defect_detail_${entry.key}_$vp.png'),
          );

          // Present at both breakpoints; mobile drops the desktop fact rows.
          expect(find.text("What's happened so far"), findsOneWidget);
          switch (entry.key) {
            case 'untriaged':
              expect(find.text('REPORTED'), findsOneWidget);
            case 'triage_complete':
              expect(find.text('CONFIRMED'), findsOneWidget);
              if (!mobile) expect(find.text('Ui Defect'), findsOneWidget);
            case 'needs_clarification':
              expect(find.text('WAITING FOR YOU'), findsOneWidget);
              // On mobile the board collapses the gate to `CTA`, so the
              // question lives behind "Answer the question".
              if (!mobile) {
                expect(
                  find.text('Which run showed the duplicate dispatch?'),
                  findsOneWidget,
                );
              } else {
                expect(find.text('Answer the question'), findsOneWidget);
              }
          }
        });
      }
    }
  });
}

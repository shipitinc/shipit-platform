import 'dart:async';

import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/defect_report/create_defect_bloc.dart';
import 'package:control_plane/features/defect_report/create_defect_event.dart';
import 'package:control_plane/features/defect_report/create_defect_page.dart';
import 'package:control_plane/features/defect_report/create_defect_state.dart';
import 'package:control_plane/shared/form_primitives.dart';
import 'package:control_plane/shared/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/defect_fixtures.dart';

/// ## WHAT THIS FILE IS
///
/// The WIDGET layer of a defect that no test referenced: nothing here asserted
/// what `CreateDefectPage` renders once a submission has succeeded.
///
/// The shape of the bug: a defect whose evidence fails to attach WAS created.
/// The bloc reported that failure on `errorMessage` while also setting
/// `success: true`, so one field meant two opposite things. The page resolved
/// that contradiction with a `&& !state.success` guard, which meant the moment
/// a success carried a message, the message was dropped — and the operator lost
/// the knowledge that a file they attached is not in the system.
///
/// So the assertions that matter are about WHICH message is on screen after a
/// successful create, and the negative one is load-bearing: the screen must not
/// claim the report failed.
///
/// ## WHY THE FORM IS FILLED THROUGH THE BLOC, NOT THE WIDGETS
///
/// `CreateDefectPage` takes a `bloc:` seam for exactly this. What regressed is
/// the success rendering, and the terminal state is reached deterministically
/// by driving the bloc while the real page is mounted — so the assertions run
/// against a page that actually transitioned, not a state dropped in cold.
class PartialFailureRepository extends DefectRepository {
  PartialFailureRepository({this.attachmentError});

  /// Thrown for every `addDefectEvidence` call. Null means attachments succeed.
  final Object? attachmentError;

  /// Arguments of every `addDefectEvidence` call.
  final List<Map<String, Object?>> evidenceCalls = [];

  @override
  Future<CreateDefectResponse> createDefect({
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) async {
    return CreateDefectResponse(defectId: 'DEF-42');
  }

  @override
  Future<DefectEvidenceResponse> addDefectEvidence({
    required String defectId,
    required String kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) async {
    if (attachmentError != null) throw attachmentError!;
    evidenceCalls.add({'defectId': defectId, 'contentHash': contentHash});
    return DefectEvidenceResponse(
      evidenceId: 'ev-1',
      defectId: defectId,
      kind: kind,
      contentHash: contentHash,
      description: description,
      sourceRef: sourceRef,
      capturedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
  }
}

/// `createDefect` itself throws — nothing was created, so there is no reference
/// to protect and no partial outcome to report.
class FailingCreateRepository extends DefectRepository {
  @override
  Future<CreateDefectResponse> createDefect({
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) async {
    throw Exception('Connection failed');
  }
}

const _lostFile = CreateDefectEvidenceFile(
  name: 'checkout-failure.png',
  size: 12400,
  sha256: 'abc123',
);

void main() {
  /// Hosts the mounted page, the way `defect_golden_test.dart` does. The
  /// `/reports/:id` route exists because the success screen's action navigates
  /// there; it is registered so the widget is realistic, not because this test
  /// taps it.
  Future<void> pumpPage(WidgetTester tester, CreateDefectBloc bloc) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/defects/new',
      routes: [
        GoRoute(
          path: '/defects/new',
          pageBuilder: (context, state) =>
              NoTransitionPage(child: CreateDefectPage(bloc: bloc)),
        ),
        GoRoute(
          path: '/reports/:id',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: Scaffold(body: Text('defect'))),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ShipItTheme.light(),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fills the form and submits, against a page that is already mounted.
  Future<void> submitWith(
    WidgetTester tester,
    CreateDefectBloc bloc, {
    List<CreateDefectEvidenceFile> evidence = const [],
  }) async {
    bloc
      ..add(CreateDefectTitleChanged('Checkout button does nothing'))
      ..add(CreateDefectDescriptionChanged('Clicked pay, nothing happened.'))
      ..add(CreateDefectExpectedBehaviorChanged('The payment sheet opens.'))
      ..add(CreateDefectSeverityChanged('blocking'))
      ..add(CreateDefectProductChanged('prod-1'));
    if (evidence.isNotEmpty) {
      bloc.add(CreateDefectEvidenceAdded(evidence));
    }
    await tester.pumpAndSettle();

    bloc.add(CreateDefectSubmitted());
    await tester.pumpAndSettle();
  }

  group('CreateDefectPage after a submission that created the defect', () {
    testWidgets('renders the created reference and no failure at all', (
      tester,
    ) async {
      final repository = PartialFailureRepository();
      final bloc = CreateDefectBloc(
        repository: repository,
        reporter: 'operator@shipit.dev',
      );
      addTearDown(() => unawaited(bloc.close()));

      await pumpPage(tester, bloc);
      await submitWith(tester, bloc, evidence: [_lostFile]);

      expect(repository.evidenceCalls, hasLength(1));
      expect(bloc.state.hasPartialFailure, isFalse);

      expect(find.text('Defect DEF-42 created'), findsOneWidget);
      // Nothing failed, so nothing says otherwise.
      expect(find.text('Could not create defect'), findsNothing);
      expect(find.textContaining('was not attached'), findsNothing);
      // The editable form is gone: an operator must not be able to file this
      // defect a second time from the screen that just filed it.
      expect(find.byType(SingleLineInput), findsNothing);
    });

    testWidgets('renders the attachment failure beside the created reference', (
      tester,
    ) async {
      final repository = PartialFailureRepository(
        attachmentError: Exception('no artifact store'),
      );
      final bloc = CreateDefectBloc(
        repository: repository,
        reporter: 'operator@shipit.dev',
      );
      addTearDown(() => unawaited(bloc.close()));

      await pumpPage(tester, bloc);
      await submitWith(tester, bloc, evidence: [_lostFile]);

      expect(bloc.state.hasPartialFailure, isTrue);

      // The reference survives the attachment failure.
      expect(find.text('Defect DEF-42 created'), findsOneWidget);
      // The failure is still visible and names the file, so the reporter knows
      // what to re-attach.
      expect(
        find.textContaining('Evidence "checkout-failure.png" was not attached'),
        findsOneWidget,
      );
      expect(find.textContaining('no artifact store'), findsOneWidget);
      // THE assertion this file exists for: the screen must not tell the
      // operator the report failed. It succeeded.
      expect(find.text('Could not create defect'), findsNothing);
      expect(find.byType(SingleLineInput), findsNothing);
    });

    testWidgets('both lost files are named when both attachments fail', (
      tester,
    ) async {
      final repository = PartialFailureRepository(
        attachmentError: Exception('no artifact store'),
      );
      final bloc = CreateDefectBloc(
        repository: repository,
        reporter: 'operator@shipit.dev',
      );
      addTearDown(() => unawaited(bloc.close()));

      await pumpPage(tester, bloc);
      await submitWith(
        tester,
        bloc,
        evidence: const [
          _lostFile,
          CreateDefectEvidenceFile(
            name: 'second-screenshot.png',
            size: 900,
            sha256: 'def456',
          ),
        ],
      );

      expect(find.text('Defect DEF-42 created'), findsOneWidget);
      expect(
        find.textContaining('Evidence "checkout-failure.png" was not attached'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Evidence "second-screenshot.png" was not attached',
        ),
        findsOneWidget,
      );
      expect(find.text('Could not create defect'), findsNothing);
    });

    testWidgets('a submission that created nothing shows the failure form', (
      tester,
    ) async {
      // The contrast case: when nothing was created, the failure IS the story
      // and must be shown as one.
      final bloc = CreateDefectBloc(
        repository: FailingCreateRepository(),
        reporter: 'operator@shipit.dev',
      );
      addTearDown(() => unawaited(bloc.close()));

      await pumpPage(tester, bloc);
      await submitWith(tester, bloc);

      expect(find.text('Could not create defect'), findsOneWidget);
      // The raw cause sits behind the error panel's own technical-details
      // disclosure, and the form has a second link with the same label — so the
      // one that has to be opened is the one inside the error panel. Without
      // this the operator would be told the create failed and not why.
      final errorPanel = find.ancestor(
        of: find.text('Could not create defect'),
        matching: find.byType(DesignErrorState),
      );
      await tester.tap(
        find.descendant(
          of: errorPanel,
          matching: find.text('Show technical details'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Connection failed'), findsOneWidget);
      // No reference exists, so none is claimed and the form stays editable.
      expect(find.text('Defect DEF-42 created'), findsNothing);
      expect(find.byType(SingleLineInput), findsOneWidget);
    });
  });
}

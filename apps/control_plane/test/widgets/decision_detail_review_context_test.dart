import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/decision_detail/decision_context.dart';
import 'package:control_plane/features/decision_detail/decision_detail_bloc.dart';
import 'package:control_plane/features/decision_detail/decision_detail_event.dart';
import 'package:control_plane/features/decision_detail/decision_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fixtures/app_fixtures.dart';

/// The decision detail page renders what a decision's `metadataJson`
/// actually carries, per decision type — an `engineering_review` decision
/// shows the reviewer's verdict, its findings and the artifact under
/// review; every unmapped type keeps the generic record; and the outcome
/// table names what each option DOES rather than printing "Records your
/// decision" three times.
void main() {
  final asOf = DateTime(2026, 9, 16, 12, 0);

  /// The shape the engineering-review gate writes: the reviewer's own
  /// `EngineeringReviewResult.toJson()` beside its top-level stamps.
  const reviewMetadataJson = '''
{
  "engineeringReviewResult": {
    "reviewExecutionId": "exec-rev-9f",
    "workItemId": "WI-9c11",
    "verdict": "approved_with_minor_findings",
    "findings": [
      {
        "findingId": "exec-rev-9f-f0",
        "revisionId": "rev-41ac",
        "reviewExecutionId": "exec-rev-9f",
        "category": "feasibility",
        "severity": "major",
        "dimension": "correctness",
        "evidence": "lib/src/scheduler.dart:88 retries without checking claim ownership",
        "requiredCorrection": "Guard the retry with the claim check",
        "affectedSurface": "lib/src/scheduler.dart",
        "createdAt": "2026-09-16T09:00:00.000Z",
        "version": 1
      }
    ],
    "assessedDimensions": ["correctness", "tests"],
    "createdAt": "2026-09-16T09:00:00.000Z",
    "version": 1,
    "reviewerRole": "ENGINEERING_REVIEWER"
  },
  "reviewExecutionId": "exec-rev-9f",
  "reviewVerdict": "approved_with_minor_findings"
}
''';

  DecisionDetailResponse engineeringReviewDetail({
    String status = 'pending',
  }) => DecisionDetailResponse(
    decisionId: 'dec-rev-01',
    workItemId: 'WI-9c11',
    workItemTitle: 'Scheduler claim-CAS dedupe patch',
    // Deliberately several lines long at the column's width: a two-line cap
    // would cut the tail off, so asserting the tail proves the row carries
    // the whole text.
    workItemDescription:
        'Stop duplicate jobs running twice. The claim handler retried the '
        'same job under a second worker while the first claim was still '
        'live, and the dedupe guard never ran on the retry path. The second '
        'execution then wrote over the first result, the audit trail lost '
        'which worker actually held the claim, and the recovery pass picked '
        'the stale outcome instead of the live one.',
    decisionType: 'engineering_review',
    status: status,
    question:
        'Engineering review requires changes. Approve, reject, or '
        'request rework?',
    blocking: true,
    requestedAt: asOf.subtract(const Duration(hours: 1)),
    context: DecisionContext(
      workflowState: 'waiting_for_human_decision',
      availableOptions: const ['approve', 'reject', 'rework'],
    ),
    // Review decisions ship description-less options — the record has no
    // durable statement of what each choice does, which is exactly the
    // void the per-type consequence map fills.
    options: [
      DecisionOption(optionId: 'approve', label: 'Approve', recommended: false),
      DecisionOption(optionId: 'reject', label: 'Reject', recommended: false),
      DecisionOption(optionId: 'rework', label: 'Rework', recommended: false),
    ],
    metadataJson: reviewMetadataJson,
  );

  Future<DecisionDetailBloc> pump(
    WidgetTester tester,
    MockRepository repository,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bloc = DecisionDetailBloc(
      decisionId: 'dec-rev-01',
      runId: 'WI-9c11',
      repository: repository,
    )..add(DecisionDetailLoaded());
    addTearDown(bloc.close);

    final router = GoRouter(
      initialLocation: '/needs-you/dec-rev-01?wi=WI-9c11',
      routes: [
        GoRoute(
          path: '/needs-you',
          builder: (context, state) => const Scaffold(body: Text('needs you')),
        ),
        GoRoute(
          path: '/needs-you/:id',
          builder: (context, state) => Scaffold(
            body: DecisionDetailPage(
              decisionId: 'dec-rev-01',
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

  testWidgets(
    'engineering_review renders WHAT THIS IS ABOUT in full in its own row, '
    'plus the verdict, findings and the artifact under review',
    (tester) async {
      final bloc = await pump(
        tester,
        MockRepository(decisionDetail: engineeringReviewDetail()),
      );

      // The payload reached the state typed, not as raw text.
      expect(bloc.state.contextPayload, isA<EngineeringReviewContext>());

      // The "in full" section is gone — the original field IS the full
      // field now, so a second copy would print the same sentence twice.
      expect(find.text('WHAT THIS IS ABOUT — IN FULL'), findsNothing);
      expect(find.text('WHAT THIS IS ABOUT'), findsOneWidget);

      // The tail of the description is what a two-line cap would cut, so
      // finding it proves the row carries the whole value.
      final descriptionTail = find.textContaining(
        'the recovery pass picked the stale outcome instead of the live one',
        findRichText: true,
      );
      expect(descriptionTail, findsOneWidget);
      // And the row carries no line cap at all.
      expect(tester.widget<RichText>(descriptionTail).maxLines, isNull);

      // The technical title is not lost — it sits under technical details,
      // the same place the run detail keeps it.
      expect(find.text('Scheduler claim-CAS dedupe patch'), findsNothing);
      final disclosure = find.text('Show technical details');
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('title: Scheduler claim-CAS dedupe patch'),
        findsOneWidget,
      );

      // The verdict badge shows the recorded verdict, verbatim.
      expect(find.text('REVIEW VERDICT'), findsOneWidget);
      expect(find.text('approved_with_minor_findings'), findsOneWidget);
      expect(find.text('assessed: correctness, tests'), findsOneWidget);

      // The finding card: severity, category, evidence, correction, surface.
      expect(find.text('major'), findsOneWidget);
      expect(find.text('feasibility'), findsOneWidget);
      expect(
        find.text(
          'lib/src/scheduler.dart:88 retries without checking claim ownership',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Required: Guard the retry with the claim check'),
        findsOneWidget,
      );

      // The artifact under review: revision, execution, named surfaces.
      expect(find.text('THE ARTIFACT UNDER REVIEW'), findsOneWidget);
      expect(find.text('REVISION'), findsOneWidget);
      expect(find.text('rev-41ac', findRichText: true), findsOneWidget);
      expect(find.text('REVIEWED BY EXECUTION'), findsOneWidget);
      expect(
        find.textContaining('exec-rev-9f', findRichText: true),
        findsWidgets,
      );
      expect(find.text('SURFACES THE FINDINGS NAME'), findsOneWidget);
      // The affected surface appears on the finding card and in the list.
      expect(find.text('lib/src/scheduler.dart'), findsNWidgets(2));

      // The WHAT HAPPENS column carries the whole consequence sentence —
      // these are multi-line strings that a one-line row would clip.
      for (final consequence in [
        'Approves the reviewed change — the run continues with this '
            'revision and the verdict is recorded',
        'Records that the change was turned down — the work stays stopped '
            'and the rejection is recorded against this revision',
        'Sends the revision back for correction — the findings above are '
            'what the next attempt must fix',
      ]) {
        final cell = find.text(consequence);
        expect(cell, findsOneWidget);
        expect(tester.widget<Text>(cell).maxLines, isNull);
      }
    },
  );

  testWidgets('a cancelled engineering_review decision stays read-only', (
    tester,
  ) async {
    await pump(
      tester,
      MockRepository(
        decisionDetail: engineeringReviewDetail(status: 'cancelled'),
      ),
    );

    // The record's context still renders — it is the record of what was
    // cancelled — but nothing accepts an answer.
    expect(find.text('REVIEW VERDICT'), findsOneWidget);
    expect(find.text('CANCELLED'), findsOneWidget);
    expect(find.text('No answer is needed'), findsOneWidget);
    expect(find.text('Save my decision'), findsNothing);
    expect(find.text('YOUR OPTIONS'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'a non-review decision type renders the generic record unchanged',
    (tester) async {
      await pump(
        tester,
        MockRepository(
          decisionDetail: DecisionDetailResponse(
            decisionId: 'dec-rev-01',
            workItemId: 'WI-9c11',
            workItemTitle: 'Scheduler claim-CAS dedupe patch',
            workItemDescription: 'Stop duplicate jobs running twice',
            decisionType: 'design_approval',
            status: 'pending',
            question: 'Approve the design for stopping duplicate jobs?',
            blocking: true,
            requestedAt: asOf.subtract(const Duration(hours: 1)),
            context: DecisionContext(
              workflowState: 'design_in_review',
              availableOptions: const ['approve', 'reject'],
            ),
            options: [
              DecisionOption(
                optionId: 'approve',
                label: 'approve',
                description: 'Design is approved',
                recommended: true,
              ),
              // A description-less option on an unmapped type keeps the
              // generic fallback — no type knows what its choices do.
              DecisionOption(
                optionId: 'reject',
                label: 'reject',
                recommended: false,
              ),
            ],
            // Even metadata on a non-review type adds no review sections.
            metadataJson: '{"someKey": "someValue"}',
          ),
        ),
      );

      expect(find.text('REVIEW VERDICT'), findsNothing);
      expect(find.text('THE ARTIFACT UNDER REVIEW'), findsNothing);
      expect(find.text('WHAT THIS IS ABOUT — IN FULL'), findsNothing);
      expect(find.text('approved_with_minor_findings'), findsNothing);

      // The generic consequence path is untouched: the option's own
      // description wins, and the bare fallback covers the void.
      expect(find.text('Design is approved'), findsWidgets);
      expect(find.text('Records your decision'), findsOneWidget);
    },
  );

  group('optionConsequenceFor', () {
    test(
      'engineering_review maps each option to a distinct real consequence',
      () {
        final approve = optionConsequenceFor(
          decisionType: 'engineering_review',
          choiceValue: 'approve',
          description: null,
        );
        final reject = optionConsequenceFor(
          decisionType: 'engineering_review',
          choiceValue: 'reject',
          description: null,
        );
        final rework = optionConsequenceFor(
          decisionType: 'engineering_review',
          choiceValue: 'rework',
          description: null,
        );

        // The defect this exists to fix: not three identical strings.
        expect({approve, reject, rework}.length, 3);
        expect(approve, isNot('Records your decision'));
        expect(reject, isNot('Records your decision'));
        expect(rework, isNot('Records your decision'));
      },
    );

    test("the option's own description always wins", () {
      expect(
        optionConsequenceFor(
          decisionType: 'engineering_review',
          choiceValue: 'approve',
          description: 'The durable statement',
        ),
        'The durable statement',
      );
    });

    test('unmapped types and unmapped choices keep the generic fallback', () {
      expect(
        optionConsequenceFor(
          decisionType: 'design_approval',
          choiceValue: 'approve',
          description: null,
        ),
        'Records your decision',
      );
      expect(
        optionConsequenceFor(
          decisionType: 'engineering_review',
          choiceValue: 'waive',
          description: null,
        ),
        'Records your decision',
      );
    });
  });

  group('parseDecisionContext', () {
    test('parses the embedded review result for engineering_review', () {
      final payload = parseDecisionContext(
        decisionType: 'engineering_review',
        metadataJson: reviewMetadataJson,
      );
      expect(payload, isA<EngineeringReviewContext>());
      final review = payload as EngineeringReviewContext;
      expect(review.verdict, 'approved_with_minor_findings');
      expect(review.reviewExecutionId, 'exec-rev-9f');
      expect(review.revisionId, 'rev-41ac');
      expect(review.result!.findings, hasLength(1));
      expect(review.unreadable, isFalse);
    });

    test('malformed JSON is unreadable, never an exception', () {
      final payload = parseDecisionContext(
        decisionType: 'engineering_review',
        metadataJson: '{not json',
      );
      expect(payload, isA<EngineeringReviewContext>());
      expect((payload as EngineeringReviewContext).unreadable, isTrue);
    });

    test('no metadata is absent, not unreadable', () {
      final payload = parseDecisionContext(
        decisionType: 'engineering_review',
        metadataJson: null,
      );
      expect((payload as EngineeringReviewContext).unreadable, isFalse);
      expect(payload.verdict, isNull);
    });

    test('unmapped decision types get the generic payload', () {
      final payload = parseDecisionContext(
        decisionType: 'design_approval',
        metadataJson: '{"k": 1}',
      );
      expect(payload, isA<GenericDecisionContext>());
    });
  });
}

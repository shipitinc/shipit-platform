import 'package:control_plane/core/design_tokens.dart';
import 'package:control_plane/core/theme.dart';
import 'package:control_plane/features/run_detail/operator_action_copy.dart';
import 'package:control_plane/features/run_detail/review_repair_affordance.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/shared/design_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// The review-repair affordance, asserted through the widget tree.
///
/// ## WHAT THIS FILE IS FOR
///
/// Two things, and only two:
///
///  1. The affordance is offered where there is something to repair, and
///     nowhere else.
///  2. Whatever the server says is what the operator reads — in particular the
///     REFUSALS, which are the sentences that carry the whole value of a
///     control that can be wrong.
///
/// Every test below has a stated mutation it exists to catch. A test that would
/// still pass with the guard removed is not evidence of anything, so the
/// mutation for the load-bearing cases is written down next to the test.
void main() {
  /// The three refusals the affordance is most likely to hit, each with the
  /// sentence the server composes from the evidence it re-derived.
  ///
  /// The strings are the POINT. They are what an operator learns — "a reviewer
  /// really did return a verdict" is knowledge, "something went wrong" is not —
  /// so they are asserted byte-for-byte rather than by substring.
  const refusals = <String, String>{
    'reviewerProducedVerdict':
        'A reviewer returned a structured verdict for this decision, so it is '
        'a real review and cannot be repaired.',
    'alreadyDecided':
        'This decision has already been answered by a human, so the repair '
        'would undo their answer.',
    'notApplicable':
        'Nothing is parked behind this decision any more, so there is nothing '
        'to repair.',
  };

  Future<void> pump(
    WidgetTester tester,
    Widget widget, {
    Size size = const Size(1400, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ShipItTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget affordance({
    String? decisionId = 'dec-1',
    ReviewRepairReport? report,
    bool stripOpen = false,
    bool submitting = false,
    VoidCallback? onOpen,
    void Function(String reason, String requestId)? onSubmit,
    VoidCallback? onCancel,
  }) => ReviewRepairAffordance(
    decisionId: decisionId,
    report: report,
    stripOpen: stripOpen,
    submitting: submitting,
    onOpen: onOpen ?? () {},
    onSubmit: onSubmit,
    onCancel: onCancel ?? () {},
  );

  // -------------------------------------------------------------------
  // THE OFFER CONDITION
  // -------------------------------------------------------------------

  testWidgets(
    'offered where a blocking decision exists, and rendered NOT AT ALL where '
    'one does not',
    (tester) async {
      await pump(tester, affordance(decisionId: 'dec-1'));
      expect(find.text(reviewRepairActionLabel), findsOneWidget);

      await pump(tester, affordance(decisionId: null));
      // Not a disabled button. Nothing: a repair control with nothing to repair
      // is the exact false affordance this surface exists to avoid, and a greyed
      // -out button is still a button.
      expect(find.text(reviewRepairActionLabel), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text(reviewRepairHeading), findsNothing);
      expect(find.text(reviewRepairExplanation), findsNothing);
    },
  );

  testWidgets(
    'NON-VACUITY of the offer condition: with no blocking decision the '
    'confirm strip is unreachable too, not merely the button',
    (tester) async {
      // `stripOpen: true` — the strip state is left ON while the decision is
      // gone, which is exactly what a repair leaves behind. If the gate were
      // only around the button, the strip would render here and the repair
      // would be one keystroke from being committed on an item that is no
      // longer parked.
      await pump(tester, affordance(decisionId: null, stripOpen: true));
      expect(find.byType(TextField), findsNothing);
      expect(find.text(reviewRepairConfirmLabel), findsNothing);
    },
  );

  // -------------------------------------------------------------------
  // THE SHAPE OF THE OFFER — placement, tone, and what it calls itself
  // -------------------------------------------------------------------

  testWidgets('it is a repair, not a choice: no failed-work vocabulary', (
    tester,
  ) async {
    await pump(tester, affordance());
    final surface = tester
        .widgetList<OutlinedButton>(find.byType(OutlinedButton))
        .map((b) => b.child)
        .whereType<Text>()
        .map((t) => t.data)
        .join(' | ');
    // "Try again", "Start it again", "Stop this work" and the approval verbs
    // are all borrowed from a different surface on purpose: this one is not a
    // peer of approving work, and reusing its words is how it would come to
    // read as one.
    expect(surface, isNot(contains('Try again')));
    expect(surface, isNot(contains('Start it again')));
    expect(surface, isNot(contains('Stop this work')));
    expect(surface, isNot(contains('Review and decide')));
    expect(find.text(reviewRepairActionLabel), findsOneWidget);
  });

  testWidgets('it is warning-tinted, and never a filled button', (
    tester,
  ) async {
    await pump(tester, affordance());
    final attention = Theme.of(
      tester.element(find.byType(ReviewRepairAffordance)),
    ).extension<ShipItPalette>()!.attention;

    // Outline in the warning tone: a filled button on this screen IS the
    // approval, so the repair cannot be allowed to look like its equal.
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(find.byType(FilledButton), findsNothing);
    expect(button.style!.foregroundColor!.resolve({}), attention);
    expect(button.style!.side!.resolve({})!.color, attention);

    // And the heading carries the same tone, so the block reads as a warning
    // zone rather than a neutral informational one.
    expect(
      tester.widget<Text>(find.text(reviewRepairHeading)).style!.color,
      attention,
    );
  });

  testWidgets('it sits below a rule', (tester) async {
    await pump(tester, affordance());
    expect(
      find.descendant(
        of: find.byType(ReviewRepairAffordance),
        matching: find.byType(ContentRule),
      ),
      findsOneWidget,
    );
  });

  testWidgets('it states the guardrail on the surface, not only in code', (
    tester,
  ) async {
    await pump(tester, affordance());
    // The operator is not asked to trust the button; they are told what happens
    // when it is wrong.
    expect(find.text(reviewRepairGuardrailSentence), findsOneWidget);
  });

  testWidgets('the heading does not assert the decision was fabricated', (
    tester,
  ) async {
    await pump(tester, affordance());
    // Only the SERVER knows whether a reviewer ever ran. The screen poses a
    // condition, never a diagnosis.
    expect(find.textContaining('never reviewed'), findsNothing);
    expect(find.textContaining('was never reviewed'), findsNothing);
    expect(find.text(reviewRepairHeading), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // NOTHING HAPPENS WITHOUT A REASON
  // -------------------------------------------------------------------

  testWidgets(
    'NON-VACUITY of the reason field: the confirm cannot fire until one is '
    'typed, and submits exactly what was typed',
    (tester) async {
      final reasons = <String>[];
      final requestIds = <String>[];
      await pump(
        tester,
        affordance(
          stripOpen: true,
          onSubmit: (reason, requestId) {
            reasons.add(reason);
            requestIds.add(requestId);
          },
        ),
      );

      // Pressing with an empty field must not reach the callback AT ALL — the
      // button is not merely ignored, it is not live.
      final confirm = find.text(reviewRepairConfirmLabel);
      expect(tester.widget<Text>(confirm).data, reviewRepairConfirmLabel);
      final button = tester.widget<OutlinedButton>(
        find.ancestor(of: confirm, matching: find.byType(OutlinedButton)).first,
      );
      expect(button.onPressed, isNull);
      expect(reasons, isEmpty);

      // Whitespace is not a reason either: it is what a field "filled in" by a
      // stray keystroke actually contains.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find
                  .ancestor(of: confirm, matching: find.byType(OutlinedButton))
                  .first,
            )
            .onPressed,
        isNull,
      );
      expect(reasons, isEmpty);

      // A real reason makes it live, and arrives verbatim.
      await tester.enterText(find.byType(TextField), 'Reviewer never ran');
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(reasons, ['Reviewer never ran']);
      expect(requestIds.single, isNotEmpty);
    },
  );

  testWidgets('the confirm button names the consequence, not the action', (
    tester,
  ) async {
    await pump(tester, affordance(stripOpen: true));
    expect(find.text(reviewRepairConfirmLabel), findsOneWidget);
    // It says what pressing it DOES.
    expect(
      tester.widget<Text>(find.text(reviewRepairConfirmLabel)).data,
      contains('Void the decision'),
    );
    expect(
      tester.widget<Text>(find.text(reviewRepairConfirmLabel)).data,
      contains('re-queue'),
    );
    // And the two things that do NOT happen are stated on the surface too,
    // because those are the two an operator is most likely to be wrong about.
    expect(find.text(reviewRepairConsequenceSentence), findsOneWidget);
    expect(find.textContaining('kept on record'), findsOneWidget);
  });

  testWidgets('Escape cancels', (tester) async {
    var cancelled = 0;
    await pump(
      tester,
      affordance(stripOpen: true, onCancel: () => cancelled++),
    );

    // Focus the reason field first — which is exactly when a keyboard user is most
    // likely to reach for Escape.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(cancelled, 1);
  });

  testWidgets(
    'NON-VACUITY of the request identity: a double-click on one confirmation '
    'carries ONE request id, so it cannot queue a second review',
    (tester) async {
      final requestIds = <String>[];
      await pump(
        tester,
        affordance(
          stripOpen: true,
          onSubmit: (_, requestId) => requestIds.add(requestId),
        ),
      );
      await tester.enterText(find.byType(TextField), 'reviewer never ran');
      await tester.pumpAndSettle();

      final confirm = find.text(reviewRepairConfirmLabel);
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(requestIds, hasLength(2));
      // Two taps of one confirmation are ONE deliberate intent, so they carry
      // one id and the server's replay check collapses them into one write.
      expect(requestIds.toSet(), hasLength(1));
    },
  );

  // -------------------------------------------------------------------
  // THE SERVER'S OWN SENTENCE IS WHAT THE OPERATOR READS
  // -------------------------------------------------------------------

  for (final entry in refusals.entries) {
    testWidgets(
      'a `${entry.key}` refusal renders the server\'s detail verbatim',
      (tester) async {
        await pump(
          tester,
          affordance(
            decisionId: null,
            report: ReviewRepairReport(
              accepted: false,
              sentence: repairOutcomeSentence(entry.key, detail: entry.value),
            ),
          ),
        );

        expect(find.text(entry.value), findsOneWidget);
        // And nothing dressed it up as progress.
        expect(find.text(reviewRepairedHeadline), findsNothing);
        expect(find.text(reviewRepairedSentence), findsNothing);
        expect(find.text(reviewRepairedDecisionFact), findsNothing);
        expect(find.text(reviewRepairedReviewFact), findsNothing);
      },
    );
  }

  testWidgets('a refusal is not rendered as a generic failure', (tester) async {
    await pump(
      tester,
      affordance(
        report: const ReviewRepairReport(
          accepted: false,
          sentence:
              'A reviewer really did return a verdict, so this cannot be '
              'repaired.',
        ),
      ),
    );
    // The sentence an operator must not be given instead.
    expect(find.text(failedSentence), findsNothing);
  });

  testWidgets(
    'a refusal is NOT captioned with the offer\'s own premise, which it '
    'usually refutes',
    (tester) async {
      // "IF NOBODY REVIEWED THIS" printed above "a reviewer really did return a
      // verdict" states the claim and its own refutation in the same eight
      // words. A refusal gets its own label, and none of the offer's framing.
      for (final detail in refusals.values) {
        await pump(
          tester,
          affordance(
            report: ReviewRepairReport(accepted: false, sentence: detail),
          ),
        );
        expect(find.text(reviewRepairRefusedLabel), findsOneWidget);
        expect(find.text(reviewRepairLabel), findsNothing);
        expect(find.text(reviewRepairHeading), findsNothing);
        expect(find.text(reviewRepairExplanation), findsNothing);
        expect(find.text(reviewRepairActionLabel), findsNothing);
      }
    },
  );

  testWidgets('the receipt survives the decision it retired', (tester) async {
    // `decisionId: null` is the post-repair state: a successful repair RETIRES
    // the decision, so by the time the operator needs to read what happened
    // there is no blocking decision left. Gating the receipt on the offer
    // condition would delete it at the exact moment it became the most
    // important thing on screen.
    await pump(
      tester,
      affordance(
        decisionId: null,
        report: const ReviewRepairReport(accepted: true, sentence: 'Done.'),
      ),
    );
    expect(find.text(reviewRepairedHeadline), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // THE POST-REPAIR STATE IS HONEST AT A GLANCE
  // -------------------------------------------------------------------

  testWidgets(
    'an accepted repair says retired-not-approved, re-queued-not-finished, '
    'and preserved-not-deleted — three separate facts',
    (tester) async {
      await pump(
        tester,
        affordance(
          decisionId: null,
          report: const ReviewRepairReport(accepted: true, sentence: 'Done.'),
        ),
      );

      // A repair that leaves the screen looking like the work moved forward is a
      // false state in miniature, so none of the three may be implied by the
      // others: each is asserted on its own row.
      expect(find.text(reviewRepairedDecisionFact), findsOneWidget);
      expect(find.text(reviewRepairedReviewFact), findsOneWidget);
      expect(find.text(reviewRepairedRecordFact), findsOneWidget);

      // `DefinitionList` renders `Text.rich`, so these are checked as rendered
      // text rather than as a `Text.data` — the strings themselves are pinned
      // above by `find.text`, which matches a rich span by its plain text.
      expect(find.textContaining('not approved'), findsOneWidget);
      expect(find.textContaining('not finished'), findsOneWidget);
      expect(find.textContaining('kept on record'), findsOneWidget);
    },
  );

  testWidgets('a successful repair closes the confirm strip', (tester) async {
    // The strip's own state is owned by the bloc; what this pins is that an
    // accepted report REPLACES the offer rather than rendering beneath it, so
    // the operator is never left holding a live "Void the decision" button
    // next to a receipt saying it already happened.
    await pump(
      tester,
      affordance(
        report: const ReviewRepairReport(accepted: true, sentence: 'Done.'),
      ),
    );
    expect(find.text(reviewRepairActionLabel), findsNothing);
    expect(find.text(reviewRepairConfirmLabel), findsNothing);
    expect(find.text(reviewRepairedHeadline), findsOneWidget);
  });

  testWidgets('the whole offer announces itself as a repair to a reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, affordance());
    expect(
      tester.getSemantics(find.byType(MaterialApp)).label,
      isNot(contains('approval')),
    );
    // Walked rather than `getSemantics` on the block, because a block is a
    // container: the label belongs on a child node.
    final labels = <String>[];
    void walk(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      node.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(MaterialApp)));
    expect(
      labels.where((l) => l.contains('It is a repair')),
      isNotEmpty,
      reason: 'the block must announce itself as a repair, not a choice',
    );
    handle.dispose();
  });
}

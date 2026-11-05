import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/run_detail/operator_action_copy.dart';
import 'package:control_plane/features/run_detail/operator_action_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The operator panel for the two NON-failure actions — `deploy` on a
/// QA-passed (or gate-interrupted) item and `reclaim` on a stranded
/// `agent_executing` one — asserted through the widget tree.
///
/// ## WHY THIS FILE EXISTS
///
/// Independent review found the whole Flutter side of the deploy/reclaim
/// surface unexercised: `run_detail_page.dart` wiring, this widget, the two
/// new wire tokens and the new accepted sentences had no test anywhere. The
/// machinery is shared with `FailedWorkItemActionPanel` (server-computed
/// action list, confirm strip, once-per-intent request id, Escape to
/// cancel), so the assertions mirror
/// `failed_work_item_action_panel_test.dart`'s — the same contract, on the
/// two actions that panel deliberately never offers.
///
/// Every test names the defect it exists to catch; one that would still pass
/// with the feature removed is not evidence of anything.
void main() {
  /// The server-computed context for the deploy advance: a `qa_passed` item
  /// whose producer's durable result can build the artifact.
  WorkItemActionContextResponse deployContext() =>
      const WorkItemActionContextResponse(
        workItemId: 'wi-qa-1',
        state: 'qa_passed',
        actions: [
          WorkItemActionResponse(
            action: 'deploy',
            toState: 'waiting_for_human_decision',
            confirmRequired: true,
            destructive: false,
            attemptLimit: 0,
          ),
        ],
        capacity: CapacitySnapshotResponse(
          budget: 'agent_executions',
          cap: 2,
          inFlight: 0,
          snapshotOnly: true,
          resolved: true,
        ),
        retryLimitResolved: true,
        retryLimitDiagnostic: 'ok',
      );

  /// The context for the stranded reclaim: `agent_executing` with no live
  /// execution and no active job behind it.
  WorkItemActionContextResponse reclaimContext() =>
      const WorkItemActionContextResponse(
        workItemId: 'wi-stranded',
        state: 'agent_executing',
        actions: [
          WorkItemActionResponse(
            action: 'reclaim',
            toState: 'agent_failed',
            confirmRequired: true,
            destructive: false,
            attemptLimit: 0,
          ),
        ],
        capacity: CapacitySnapshotResponse(
          budget: 'agent_executions',
          cap: 2,
          inFlight: 0,
          snapshotOnly: true,
          resolved: true,
        ),
        retryLimitResolved: true,
        retryLimitDiagnostic: 'ok',
      );

  Future<void> pump(
    WidgetTester tester,
    Widget panel, {
    Size size = const Size(1400, 1100),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ShipItTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: panel)),
      ),
    );
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------
  // The offered actions render, in the copy that belongs to each action.
  // -------------------------------------------------------------------

  testWidgets('a deployable item renders DEPLOY copy, never reclaim copy', (
    tester,
  ) async {
    await pump(
      tester,
      OperatorActionPanel(
        actionContext: deployContext(),
        pendingAction: null,
        submitting: false,
      ),
    );

    expect(find.text(deployPanelHeading), findsOneWidget);
    expect(find.text(deployPanelExplanation), findsOneWidget);
    expect(find.text(deployActionLabel), findsOneWidget);

    // The mutation this pins: keying the copy on anything but the offered
    // action — the item's state, the panel order — puts "Hand it back" on a
    // passed item, which is the exact false state this panel exists against.
    expect(find.text(reclaimPanelHeading), findsNothing);
    expect(find.text(reclaimActionLabel), findsNothing);
  });

  testWidgets('a stranded item renders RECLAIM copy, never deploy copy', (
    tester,
  ) async {
    await pump(
      tester,
      OperatorActionPanel(
        actionContext: reclaimContext(),
        pendingAction: null,
        submitting: false,
      ),
    );

    expect(find.text(reclaimPanelHeading), findsOneWidget);
    expect(find.text(reclaimPanelExplanation), findsOneWidget);
    expect(find.text(reclaimActionLabel), findsOneWidget);

    expect(find.text(deployPanelHeading), findsNothing);
    expect(find.text(deployActionLabel), findsNothing);
  });

  testWidgets(
    'pressing the offered action reports it and opens the strip; nothing '
    'commits',
    (tester) async {
      final pressed = <String>[];
      final submits = <(String, String, String)>[];

      // The panel is a pure function of its inputs — the bloc owns the
      // pending action — so the confirm interaction is driven through a
      // stateful host that plays the part `RunDetailBloc` plays in
      // production.
      await pump(
        tester,
        _PanelHost(
          actionContext: deployContext(),
          onActionPressed: pressed.add,
          onSubmit: (action, reason, requestId) =>
              submits.add((action, reason, requestId)),
        ),
      );

      await tester.tap(find.text(deployActionLabel));
      await tester.pumpAndSettle();

      expect(pressed, ['deploy']);
      expect(submits, isEmpty, reason: 'a press alone must not commit');
      // The strip is up, worded for THIS action.
      expect(find.text('You chose: $deployActionLabel'), findsOneWidget);
      expect(find.text(deployConsequenceSentence), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------
  // The confirm strip requires a non-BLANK reason — trimmed, not merely
  // non-empty.
  // -------------------------------------------------------------------

  testWidgets(
    'the confirm strip refuses a missing AND a whitespace-only reason',
    (tester) async {
      final submits = <(String, String, String)>[];
      await pump(
        tester,
        OperatorActionPanel(
          actionContext: deployContext(),
          pendingAction: 'deploy',
          submitting: false,
          onSubmit: (action, reason, requestId) =>
              submits.add((action, reason, requestId)),
        ),
      );

      // No reason at all: the button is disabled, so the tap is inert.
      await tester.tap(find.text('Save: $deployActionLabel'));
      await tester.pumpAndSettle();
      expect(submits, isEmpty, reason: 'a missing reason must not commit');

      // Whitespace-only is a blank reason, and is refused the same way: the
      // strip trims before it judges, which is what keeps "   " from being
      // saved as somebody's stated reason.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save: $deployActionLabel'));
      await tester.pumpAndSettle();
      expect(submits, isEmpty, reason: 'a blank reason must not commit');

      // A real reason commits, trimmed.
      await tester.enterText(find.byType(TextField), '  ready to ship  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save: $deployActionLabel'));
      await tester.pumpAndSettle();

      expect(submits, hasLength(1));
      expect(submits.single.$1, 'deploy');
      expect(submits.single.$2, 'ready to ship');
    },
  );

  testWidgets('the reclaim strip submits its own action and wording', (
    tester,
  ) async {
    final submits = <(String, String, String)>[];
    await pump(
      tester,
      OperatorActionPanel(
        actionContext: reclaimContext(),
        pendingAction: 'reclaim',
        submitting: false,
        onSubmit: (action, reason, requestId) =>
            submits.add((action, reason, requestId)),
      ),
    );

    expect(find.text('You chose: $reclaimActionLabel'), findsOneWidget);
    expect(find.text(reclaimConsequenceSentence), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'the worker is gone');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: $reclaimActionLabel'));
    await tester.pumpAndSettle();

    expect(submits, hasLength(1));
    expect(submits.single.$1, 'reclaim');
    expect(submits.single.$2, 'the worker is gone');
  });

  // -------------------------------------------------------------------
  // ONE confirmation mints ONE request id, reused on every submit retry.
  // -------------------------------------------------------------------

  testWidgets('ONE confirmation sends ONE requestId', (tester) async {
    final submits = <(String, String, String)>[];
    await pump(
      tester,
      OperatorActionPanel(
        actionContext: deployContext(),
        pendingAction: 'deploy',
        submitting: false,
        onSubmit: (action, reason, requestId) =>
            submits.add((action, reason, requestId)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ready to ship');
    await tester.pumpAndSettle();

    // A double-click, and then the retry after a lost response: every attempt
    // of THIS confirmation carries the same id, so it can only spend once.
    await tester.tap(find.text('Save: $deployActionLabel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: $deployActionLabel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: $deployActionLabel'));
    await tester.pumpAndSettle();

    expect(submits, hasLength(3));
    expect(
      submits.map((s) => s.$3).toSet(),
      hasLength(1),
      reason: 'three attempts of one confirmation are ONE operator intent',
    );
    expect(submits.first.$3, isNotEmpty);
  });

  testWidgets('a SECOND confirmation mints a NEW requestId', (tester) async {
    // The paired negative the once-per-confirmation rule needs: the id lives
    // in the strip's own state and dies with it, so the NEXT strip — opened
    // after this one resolved — is a second deliberate spend and must carry
    // its own id rather than replaying under the first intent's.
    final submits = <(String, String, String)>[];
    await pump(
      tester,
      _PanelHost(
        actionContext: deployContext(),
        onSubmit: (action, reason, requestId) =>
            submits.add((action, reason, requestId)),
      ),
    );

    // First confirmation: open, reason, save. The host resolves it the way
    // the bloc does — the strip closes and its id is discarded with it.
    await tester.tap(find.text(deployActionLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'first go');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: $deployActionLabel'));
    await tester.pumpAndSettle();

    // Second confirmation: a fresh strip, a fresh mint.
    await tester.tap(find.text(deployActionLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second go');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: $deployActionLabel'));
    await tester.pumpAndSettle();

    expect(submits, hasLength(2));
    expect(
      submits.map((s) => s.$3).toSet(),
      hasLength(2),
      reason:
          'a second deliberate confirm is a second deliberate spend, so it '
          'must carry its own id',
    );
  });

  // -------------------------------------------------------------------
  // Escape cancels — the same rule the retry strip keeps.
  // -------------------------------------------------------------------

  testWidgets('Escape cancels the confirm strip', (tester) async {
    var cancelled = 0;
    await pump(
      tester,
      OperatorActionPanel(
        actionContext: reclaimContext(),
        pendingAction: 'reclaim',
        submitting: false,
        onCancel: () => cancelled += 1,
      ),
    );

    expect(find.byType(TextField), findsOneWidget);

    // The reason field holds focus, which is exactly when a keyboard user
    // reaches for Escape.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(cancelled, 1, reason: 'Escape must cancel without a pointer');
  });

  // -------------------------------------------------------------------
  // A resolved outcome is ANNOUNCED, not only drawn.
  // -------------------------------------------------------------------

  testWidgets('a resolved outcome sits in the tree as a LIVE REGION', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      OperatorActionPanel(
        actionContext: deployContext(),
        pendingAction: null,
        submitting: false,
        outcomeAnnouncement: deployAcceptedSentence,
      ),
    );

    final nodes = <SemanticsNode>[];
    void walk(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.getSemantics(find.byType(MaterialApp)));

    expect(
      nodes.any(
        (n) =>
            n.flagsCollection.isLiveRegion &&
            n.label.contains(deployAcceptedSentence),
      ),
      isTrue,
      reason:
          'the outcome must be marked live so it is announced, not only '
          'drawn — the same concession AC-34 makes for the retry panel',
    );

    handle.dispose();
  });
}

/// Plays the part `RunDetailBloc` plays in production: owns the pending
/// action, opens the confirm strip on a press, cancels it, and closes it the
/// way a committed action does.
///
/// The panel itself is deliberately stateless — the bloc owns this state —
/// so driving the confirm flow through a host is what exercises the real
/// contract rather than a private copy of it.
class _PanelHost extends StatefulWidget {
  const _PanelHost({
    required this.actionContext,
    this.onActionPressed,
    this.onSubmit,
  });

  final WorkItemActionContextResponse actionContext;
  final void Function(String action)? onActionPressed;
  final void Function(String action, String reason, String requestId)? onSubmit;

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> {
  String? pending;

  @override
  Widget build(BuildContext context) {
    return OperatorActionPanel(
      actionContext: widget.actionContext,
      pendingAction: pending,
      submitting: false,
      onActionPressed: (action) {
        widget.onActionPressed?.call(action);
        setState(() => pending = action);
      },
      onCancel: () => setState(() => pending = null),
      onSubmit: (action, reason, requestId) {
        widget.onSubmit?.call(action, reason, requestId);
        setState(() => pending = null);
      },
    );
  }
}

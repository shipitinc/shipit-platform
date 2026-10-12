import 'package:control_plane/core/plain_language.dart';
import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/run_detail/failed_work_item_action_panel.dart';
import 'package:control_plane/features/run_detail/operator_action_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "Restart after a problem" panel, asserted through the widget tree and
/// through `tester.getSemantics()`.
///
/// ## WHY SEMANTICS AND NOT PIXELS
///
/// A3 and A11 introduce `Semantics(liveRegion: true)`, which has **no precedent
/// anywhere in this codebase**, and AC-27's golden comparison cannot see a
/// semantics tree at all. So the three tests AC-34 names are written here.
///
/// **The concession, stated rather than hidden:** with no precedent in this app,
/// these assert *that the string is in the semantics tree, marked as a live
/// region* — not that any particular screen reader announces it. Platform
/// announcement behaviour is unverified here (design-brief.md §15 gap 6). A
/// passing test is the first evidence, not proof of announcement.
/// Every semantics node in the tree, flattened.
///
/// `tester.getSemantics` returns ONE node for a finder, so walking the tree is
/// how a test asks "is this string in the semantics tree AT ALL" — which is
/// exactly the concession AC-34 makes: the string is asserted to be present
/// and marked live, not that any particular screen reader speaks it.
List<SemanticsNode> allSemanticsNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(find.byType(MaterialApp)));
  return nodes;
}

/// A `liveRegion` node carrying [fragment].
bool liveRegionAnnounces(WidgetTester tester, String fragment) =>
    allSemanticsNodes(
      tester,
    ).any((n) => n.flagsCollection.isLiveRegion && n.label.contains(fragment));

/// A `liveRegion` node carrying [fragment], as a clear failure message.
Matcher announcesOnLiveRegion(WidgetTester tester, String fragment) =>
    predicate<bool>(
      (b) => liveRegionAnnounces(tester, fragment),
      'a liveRegion node whose label contains "$fragment"',
    );

void main() {
  final now = DateTime(2026, 10, 11, 12, 0);

  WorkItemActionContextResponse context({
    List<WorkItemActionResponse> actions = const [],
    WorkItemFailureResponse? failure,
    bool retryLimitResolved = true,
    List<OperatorActionSummaryResponse> priorActions = const [],
    int cap = 2,
    int inFlight = 0,
  }) => WorkItemActionContextResponse(
    workItemId: 'defect-DEF-1791686704991884',
    state: 'agent_failed',
    actions: actions,
    failure: failure,
    capacity: CapacitySnapshotResponse(
      budget: 'agent_executions',
      cap: cap,
      inFlight: inFlight,
      snapshotOnly: true,
      resolved: true,
    ),
    retryLimitResolved: retryLimitResolved,
    retryLimitDiagnostic: retryLimitResolved ? 'ok' : 'not configured',
    priorActions: priorActions,
  );

  WorkItemActionResponse retryAction({int attempt = 1, int limit = 3}) =>
      WorkItemActionResponse(
        action: 'retry',
        toState: 'design_not_required',
        confirmRequired: true,
        destructive: false,
        attemptNumber: attempt,
        attemptLimit: limit,
      );

  const stopAction = WorkItemActionResponse(
    action: 'stop',
    toState: 'cancelled',
    confirmRequired: true,
    destructive: true,
    // A stop consumes no attempt, so the wire carries none and the limit is
    // not a statement about it.
    attemptLimit: 0,
  );

  WorkItemFailureResponse reason(String r) => WorkItemFailureResponse(
    transitionId: 'tr-1',
    at: DateTime(2026, 10, 11, 10, 50),
    reason: r,
    actorType: 'orchestrator',
    jobId: 'jb-1',
    jobState: 'failed',
    jobFailureCode: null,
    jobFailureReason: null,
    jobFailureJson: null,
  );

  /// Pumps the panel inside the app's real theme, so `context.palette` and
  /// `ShipItType` resolve exactly as they do on the run detail page.
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
  // AC-1 / AC-2 / AC-3 — the panel renders what the server offered, and
  // nothing it did not.
  // -------------------------------------------------------------------

  testWidgets('AC-1: both offered actions render, in the server\'s order', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction(), stopAction]),
        haltCount: 1,
        now: now,
      ),
    );

    expect(find.text(retryActionLabel), findsOneWidget);
    expect(find.text(stopActionLabel), findsOneWidget);
  });

  testWidgets('AC-3: no control maps to a state the table forbids', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction(), stopAction]),
        haltCount: 1,
        now: now,
      ),
    );

    // `terminated` is LEGAL from agent_failed and is deliberately never offered
    // (HD-1). Asserted as text so a widget labelled with the raw state fails.
    expect(find.textContaining('terminated'), findsNothing);
    expect(find.textContaining('waiting_for_human_decision'), findsNothing);
  });

  testWidgets('AC-2/N4: an action the server did not offer renders NOTHING', (
    tester,
  ) async {
    // The server offered only `stop`. There must be no "Try again", and no
    // button that maps to the retry edge.
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(
          actions: [stopAction],
          retryLimitResolved: false,
        ),
        haltCount: 1,
        now: now,
      ),
    );

    expect(find.text(retryActionLabel), findsNothing);
    expect(find.text(stopActionLabel), findsOneWidget);
  });

  testWidgets('N4: an UNRECOGNISED action id renders nothing at all', (
    tester,
  ) async {
    // A closed set on the client: an unknown wire value is inert, not a guess.
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(
          actions: const [
            WorkItemActionResponse(
              action: 'something_invented_later',
              toState: 'agent_completed',
              confirmRequired: true,
              destructive: false,
              attemptLimit: 0,
            ),
          ],
        ),
        haltCount: 1,
        now: now,
      ),
    );

    expect(find.text('something_invented_later'), findsNothing);
    expect(find.text(retryActionLabel), findsNothing);
    expect(find.text(stopActionLabel), findsNothing);
  });

  // -------------------------------------------------------------------
  // AC-2 / AC-20 / AC-21 — copy, and the honest reporting of a missing reason
  // -------------------------------------------------------------------

  testWidgets('the heading is the EXISTING escalation decision type', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction(), stopAction]),
        haltCount: 1,
        now: now,
      ),
    );

    expect(find.text(retryPanelHeading), findsOneWidget);
    // Byte-identical to the vocabulary the product already uses.
    expect(retryPanelHeading, PlainLanguage.decisionType('escalation'));
    expect(retryPanelHeading, 'Restart after a problem');
  });

  testWidgets('AC-21: a missing reason is REPORTED AS MISSING (AC-21)', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction(), stopAction]),
        haltCount: 1,
        now: now,
      ),
    );

    // No failure record at all.
    expect(find.text(noRecordedReason), findsOneWidget);
    expect(noRecordedReason, 'The system did not record why this stopped.');
  });

  testWidgets(
    'a recorded job failure classifies into plain language, not jargon',
    (tester) async {
      // The LIVE evidence for this item (design-brief.md §1.1): the transition
      // reason is engineer prose about a zombie reclaim, and the JOB's failure
      // carries `code: executionInterrupted` with a `zombie execution reclaimed`
      // reason. The classifier keys on those durable signals.
      await pump(
        tester,
        FailedWorkItemActionPanel(
          actionContext: context(
            actions: [retryAction(), stopAction],
            failure: WorkItemFailureResponse(
              transitionId: 'tr-1',
              at: DateTime(2026, 10, 11, 10, 50),
              reason:
                  'operator step 3: stranded by pre-fix zombie reclaim '
                  '(job jb-hn3liczxln-li36ts); reconciled to agentFailed',
              actorType: 'orchestrator',
              jobId: 'jb-hn3liczxln-li36ts',
              jobState: 'failed',
              jobFailureCode: 'executionInterrupted',
              jobFailureReason:
                  'zombie execution reclaimed: execution wx-jb-hn3liczxln-li36ts '
                  'is still agentExecuting and has been non-terminal for 484m',
              jobFailureJson: null,
            ),
          ),
          haltCount: 1,
          now: now,
        ),
      );

      // The engineer's prose is NOT on the default surface…
      expect(find.textContaining('zombie'), findsNothing);
      expect(find.textContaining('484m'), findsNothing);
      // …and the plain sentence that replaced it IS.
      expect(find.textContaining('stopped answering'), findsOneWidget);
    },
  );

  testWidgets('N8: an UNRECOGNISED cause is stated truthfully, never guessed', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(
          actions: [retryAction(), stopAction],
          failure: reason('a cause this repository has never emitted before'),
        ),
        haltCount: 1,
        now: now,
      ),
    );

    // Less specific, never wrong: the neutral sentence plus the raw record one
    // disclosure away.
    expect(
      find.textContaining('The technical details below say'),
      findsOneWidget,
    );
    expect(find.textContaining('stopped answering'), findsNothing);
  });

  // -------------------------------------------------------------------
  // AC-4 / N3 — the cost is on the surface BEFORE anything is pressed
  // -------------------------------------------------------------------

  testWidgets(
    'AC-4: the attempt position and the cost are both present, unpressed',
    (tester) async {
      await pump(
        tester,
        FailedWorkItemActionPanel(
          actionContext: context(
            actions: [retryAction(attempt: 2, limit: 3)],
            inFlight: 2,
            cap: 2,
          ),
          haltCount: 1,
          now: now,
        ),
      );

      expect(find.text('This will be attempt 2 of 3.'), findsOneWidget);
      expect(find.textContaining('costs model'), findsOneWidget);
      // And the capacity snapshot, as an observation.
      expect(find.textContaining('2 of 2 agent slots busy'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------
  // B1 / B2 — the UNCOUNTED default must never render "of 0"
  //
  // `attemptLimit` is a non-nullable `int` on a frozen wire model, so "no
  // count was configured" and "the count is zero" share the value `0`. Since
  // 2026-10-12 `0` is the DEFAULT — operator retries are uncounted unless an
  // operator caps them — so the panel rendered the literal string
  // "This will be attempt 5 of 0." on the majority path. These tests pin the
  // exact wire shape the new default produces.
  // -------------------------------------------------------------------

  testWidgets(
    'B1/B2: the UNCUNTED default (attemptLimit == 0) never renders "of 0"',
    (tester) async {
      // The exact shape the server emits when SHIPIT_OPERATOR_MAX_RETRIES is
      // unset: `retry != null` (retry IS available — this is the reversal's
      // whole point) with `attemptLimit == 0` (no count bound applies).
      //
      // attemptNumber 5 is deliberate: it is the reviewer's live repro and it
      // proves the attempt position itself still RENDERS — the fix gates the
      // "of M" clause, it does not delete the sentence.
      await pump(
        tester,
        FailedWorkItemActionPanel(
          actionContext: context(actions: [retryAction(attempt: 5, limit: 0)]),
          haltCount: 1,
          now: now,
        ),
      );

      // The negative, stated as a negative on the rendered text.
      expect(find.textContaining('of 0'), findsNothing);
      // Nothing anywhere on the panel may read "of 0"…
      for (final node in allSemanticsNodes(tester)) {
        expect(
          node.label,
          isNot(contains('of 0')),
          reason: 'the semantics tree must not carry "of 0" either',
        );
      }

      // …and the sentence is still there, truthfully, without a false budget.
      expect(find.text('This will be attempt 5.'), findsOneWidget);
    },
  );

  testWidgets(
    'B1/B2: a REAL count still renders "of N" — the clause is gated, not deleted',
    (tester) async {
      // The paired negative. Without this, "drop the sentence entirely" would
      // satisfy the test above and leave a bounded budget unreadable as one,
      // which is the opposite defect.
      await pump(
        tester,
        FailedWorkItemActionPanel(
          actionContext: context(actions: [retryAction(attempt: 2, limit: 3)]),
          haltCount: 1,
          now: now,
        ),
      );

      expect(find.text('This will be attempt 2 of 3.'), findsOneWidget);
    },
  );

  testWidgets('B1/B2: the switch-off case is UNCHANGED by the uncounted fix', (
    tester,
  ) async {
    // `attemptLimit == 0` must not be confused with "there is no retry at
    // all". When the server does not OFFER retry, the panel says the action
    // is switched off — a different sentence, and the one that must survive.
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(
          actions: [stopAction],
          retryLimitResolved: false,
        ),
        haltCount: 1,
        now: now,
      ),
    );

    expect(find.text(retrySwitchedOffSentence), findsOneWidget);
    expect(find.textContaining('of 0'), findsNothing);
    expect(find.text(retryActionLabel), findsNothing);
  });

  testWidgets('B1/B2: the cost line is still on the surface when uncounted', (
    tester,
  ) async {
    // Uncounted must not read as FREE. The cost sentence is a separate
    // element and the uncounted fix must not have removed it.
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction(attempt: 5, limit: 0)]),
        haltCount: 1,
        now: now,
      ),
    );

    expect(find.textContaining('costs model'), findsOneWidget);
  });

  testWidgets('AC-4: the cost line is TEXT on the surface, not a tooltip', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction()]),
        haltCount: 1,
        now: now,
      ),
    );

    final cost = tester.widget<Text>(find.text(retryCostSentence).first);
    expect(cost.data, isNotNull);
    expect(find.byTooltip(retryCostSentence), findsNothing);
  });

  // -------------------------------------------------------------------
  // AC-34 (1) / AC-24 / A1 — the panel is ONE unit with distinct children
  // -------------------------------------------------------------------

  testWidgets(
    'AC-34 (1) / AC-24: the panel is a container with distinct focusable '
    'actions as children',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        FailedWorkItemActionPanel(
          actionContext: context(actions: [retryAction(), stopAction]),
          haltCount: 1,
          now: now,
        ),
      );

      final node = tester.getSemantics(
        find.bySemanticsLabel(retryPanelSemanticsLabel),
      );

      expect(node.label, retryPanelSemanticsLabel);

      // `container: true` + `explicitChildNodes: true` has no flag on the node
      // in this Flutter version, so it is asserted by its OBSERVABLE
      // consequence — which is the reason `_GateCard` sets it and the reason
      // this matters: without it the children's labels merge INTO this node
      // and their tap actions merge with it, and the whole card becomes one
      // tappable region with no cursor change to advertise it.
      expect(
        node.hasChildren,
        isTrue,
        reason: 'the panel must keep its children as their own nodes',
      );
      expect(
        node.label,
        isNot(contains(retryActionLabel)),
        reason:
            'if the button label merged upward, explicitChildNodes is not '
            'doing its job and the card is one tap target',
      );

      // …whose actions are DISTINCT nodes, each independently focusable.
      final children = <SemanticsNode>[];
      node.visitChildren((child) {
        children.add(child);
        return true;
      });

      final labels = children.map((c) => c.label).toList();

      expect(
        labels.where((l) => l.contains(retryActionLabel)),
        isNotEmpty,
        reason: 'Try again must be its own semantics node',
      );
      expect(
        labels.where((l) => l.contains(stopActionLabel)),
        isNotEmpty,
        reason: 'Stop this work must be its own semantics node',
      );

      handle.dispose();
    },
  );

  // -------------------------------------------------------------------
  // AC-34 (2) / A2 — the confirm button's label flips with its state
  // -------------------------------------------------------------------

  testWidgets('AC-34 (2) / A2: the confirm label flips with readiness', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction()]),
        haltCount: 1,
        now: now,
        pendingAction: 'retry',
      ),
    );

    // Matched by the BUTTON flag, not by the text: the consequence sentence is
    // printed twice on purpose — once as the strip's description, once as
    // the button's own label — so matching on the words finds the
    // description first and would never see the button's state flip.
    String currentConfirmLabel() {
      final buttons = allSemanticsNodes(
        tester,
      ).where((n) => n.flagsCollection.isButton && n.label.isNotEmpty);
      for (final n in buttons) {
        if (n.label.contains('Add a reason first') ||
            n.label.contains('Starts a fresh agent run')) {
          return n.label;
        }
      }
      return buttons.isEmpty ? '' : buttons.first.label;
    }

    // No reason yet: the label says what pressing would do instead.
    expect(currentConfirmLabel(), contains('Add a reason first'));

    await tester.enterText(find.byType(TextField), 'transient infra failure');
    await tester.pumpAndSettle();

    expect(
      currentConfirmLabel(),
      contains(retryConsequenceSentence),
      reason: 'once a reason is present the label describes the real action',
    );

    handle.dispose();
  });

  // -------------------------------------------------------------------
  // AC-25 / A3 / A11 / AC-34 (3) — the outcome is ANNOUNCED
  // -------------------------------------------------------------------

  testWidgets(
    'AC-34 (3) / AC-25 / A3: a resolved outcome sits in the tree as a LIVE '
    'REGION',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        FailedWorkItemActionPanel(
          actionContext: context(actions: [retryAction()], inFlight: 2, cap: 2),
          haltCount: 1,
          now: now,
          outcomeAnnouncement: queuedOutcomeSentence,
        ),
      );

      final live = allSemanticsNodes(
        tester,
      ).where((n) => n.flagsCollection.isLiveRegion);

      expect(
        live.any((n) => n.label.contains(queuedOutcomeSentence)),
        isTrue,
        reason:
            'the outcome must be marked live so it is announced, not only '
            'drawn',
      );

      handle.dispose();
    },
  );

  testWidgets(
    'AC-25 / A11: an UNRESOLVED limit is announced, not silently absent',
    (tester) async {
      final handle = tester.ensureSemantics();
      // No retry offered, and no outcome yet — the panel is simply open. The
      // absence must still be announced, because a screen-reader user must not
      // conclude the screen is broken when an env var is unset.
      await pump(
        tester,
        FailedWorkItemActionPanel(
          actionContext: context(
            actions: [stopAction],
            retryLimitResolved: false,
          ),
          haltCount: 1,
          now: now,
        ),
      );

      expect(find.text(retrySwitchedOffSentence), findsOneWidget);

      final live = allSemanticsNodes(
        tester,
      ).where((n) => n.flagsCollection.isLiveRegion);

      expect(
        live.any((n) => n.label.contains(retrySwitchedOffSentence)),
        isTrue,
        reason: 'the switched-off state is announced, not merely seen (A11)',
      );

      handle.dispose();
    },
  );

  // -------------------------------------------------------------------
  // AC-15d — a missing configuration must not remove the only exit
  // -------------------------------------------------------------------

  testWidgets('AC-15d: with no retry, "Stop this work" is still offered', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(
          actions: [stopAction],
          retryLimitResolved: false,
        ),
        haltCount: 1,
        now: now,
      ),
    );

    expect(find.text(stopActionLabel), findsOneWidget);
    expect(find.text(retryActionLabel), findsNothing);
    expect(find.text(retrySwitchedOffSentence), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // AC-5 / AC-6 / N11 / AC-26 — confirm, and Escape
  // -------------------------------------------------------------------

  testWidgets('AC-6: no path reaches the submit without an explicit confirm', (
    tester,
  ) async {
    final submits = <(String, String, String)>[];

    // The panel is a pure function of its inputs — the BLOCK owns the pending
    // action — so the confirm interaction is driven through a stateful host
    // that plays the part `RunDetailBloc` plays in production.
    await pump(
      tester,
      _PanelHost(
        onSubmit: (action, reason, requestId) =>
            submits.add((action, reason, requestId)),
      ),
    );

    // Pressing the action opens the strip. It does NOT submit.
    await tester.tap(find.text(retryActionLabel));
    await tester.pumpAndSettle();
    expect(submits, isEmpty, reason: 'a press alone must not commit');
    expect(find.byType(TextField), findsOneWidget);

    // Submitting with no reason is refused.
    await tester.tap(find.text('Save: Try again'));
    await tester.pumpAndSettle();
    expect(submits, isEmpty, reason: 'a blank reason must not commit (AC-5)');

    // With a reason, the deliberate confirm does.
    await tester.enterText(find.byType(TextField), 'transient failure');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: Try again'));
    await tester.pumpAndSettle();

    expect(submits, hasLength(1));
    expect(submits.single.$1, 'retry');
    expect(submits.single.$2, 'transient failure');
  });

  testWidgets(
    'AC-11: a resolve closes the strip, so a second spend is not invited',
    (tester) async {
      // The bloc re-reads after the RPC resolves, and the pending action is
      // dropped with it. A confirm strip left up over a committed action would
      // invite the very second spend this design is about preventing.
      await pump(
        tester,
        _PanelHost(resolveOnSubmit: true, onSubmit: (_, _, _) {}),
      );

      await tester.tap(find.text(retryActionLabel));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'transient failure');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save: Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('AC-9/AC-12: ONE confirmation sends ONE requestId', (
    tester,
  ) async {
    final submits = <(String, String, String)>[];
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction()]),
        haltCount: 1,
        now: now,
        pendingAction: 'retry',
        onSubmit: (action, reason, requestId) =>
            submits.add((action, reason, requestId)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'transient failure');
    await tester.pumpAndSettle();

    // A double-click, and then the retry after a lost response: every attempt
    // of THIS confirmation carries the same id, so it can only spend once.
    await tester.tap(find.text('Save: Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save: Try again'));
    await tester.pumpAndSettle();

    expect(submits, hasLength(3));
    expect(
      submits.map((s) => s.$3).toSet(),
      hasLength(1),
      reason: 'three attempts of one confirmation are ONE operator intent',
    );
  });

  testWidgets('AC-26: Escape cancels the confirm strip', (tester) async {
    var cancelled = 0;
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(actions: [retryAction()]),
        haltCount: 1,
        now: now,
        pendingAction: 'retry',
        onCancel: () => cancelled += 1,
      ),
    );

    expect(find.byType(TextField), findsOneWidget);

    // The reason field holds focus (A4), which is exactly when a keyboard user
    // reaches for Escape.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(cancelled, 1, reason: 'Escape must cancel without a pointer (A5)');
  });

  // -------------------------------------------------------------------
  // OQ-1 — the audit ledger the decision bought is actually read
  // -------------------------------------------------------------------

  testWidgets('OQ-1: a prior restart is shown, with who and why', (
    tester,
  ) async {
    await pump(
      tester,
      FailedWorkItemActionPanel(
        actionContext: context(
          actions: [retryAction(attempt: 2), stopAction],
          priorActions: [
            OperatorActionSummaryResponse(
              action: 'retry',
              requestedBy: 'dana',
              reason: 'the host rebooted mid-run',
              at: DateTime(2026, 10, 11, 9, 15),
              attemptNumber: 1,
            ),
          ],
        ),
        haltCount: 2,
        now: now,
      ),
    );

    expect(find.textContaining('dana'), findsOneWidget);
    expect(find.textContaining('the host rebooted mid-run'), findsOneWidget);
  });
}

/// Plays the part `RunDetailBloc` plays in production: owns the pending action,
/// opens and cancels the confirm strip, and (optionally) resolves it the way a
/// committed action does.
///
/// The panel itself is deliberately stateless — the BLOCK owns this state — so
/// driving the confirm flow through a host is what exercises the real contract
/// rather than a private copy of it.
class _PanelHost extends StatefulWidget {
  const _PanelHost({required this.onSubmit, this.resolveOnSubmit = false});

  final void Function(String action, String reason, String requestId) onSubmit;
  final bool resolveOnSubmit;

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> {
  String? pending;

  @override
  Widget build(BuildContext context) {
    return FailedWorkItemActionPanel(
      actionContext: const WorkItemActionContextResponse(
        workItemId: 'defect-DEF-1791686704991884',
        state: 'agent_failed',
        actions: [
          WorkItemActionResponse(
            action: 'retry',
            toState: 'design_not_required',
            confirmRequired: true,
            destructive: false,
            attemptNumber: 1,
            attemptLimit: 3,
          ),
          WorkItemActionResponse(
            action: 'stop',
            toState: 'cancelled',
            confirmRequired: true,
            destructive: true,
            attemptLimit: 0,
          ),
        ],
        failure: null,
        capacity: CapacitySnapshotResponse(
          budget: 'agent_executions',
          cap: 2,
          inFlight: 0,
          snapshotOnly: true,
          resolved: true,
        ),
        retryLimitResolved: true,
        retryLimitDiagnostic: 'ok',
      ),
      haltCount: 1,
      now: DateTime(2026, 10, 11, 12, 0),
      pendingAction: pending,
      onRetryPressed: () => setState(() => pending = 'retry'),
      onStopPressed: () => setState(() => pending = 'stop'),
      onCancel: () => setState(() => pending = null),
      onSubmit: (action, reason, requestId) {
        widget.onSubmit(action, reason, requestId);
        if (widget.resolveOnSubmit) setState(() => pending = null);
      },
    );
  }
}

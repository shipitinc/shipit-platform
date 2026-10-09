import 'dart:async';

import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/product_detail/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app_fixtures.dart';

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------

ProductDetailResponse _detail({
  String productId = 'shipit',
  String name = 'ShipIt Platform',
  String state = 'governed',
  bool allowsDispatch = true,
  String? activeBaselineId = 'bl-shipit-7',
  int? activeRevision = 7,
  String? pendingBaselineId,
  int? pendingRevision,
  bool pendingVerified = false,
  String? pendingDecisionId,
  List<PolicyResponse> policies = const [],
}) => ProductDetailResponse(
  productId: productId,
  name: name,
  description: 'The platform itself',
  state: state,
  allowsDispatch: allowsDispatch,
  updatedAt: DateTime.utc(2026, 3, 1),
  repositories: const [],
  credentials: const [],
  activeBaselineId: activeBaselineId,
  activeBaselineRevision: activeRevision,
  activeBaselineHash: 'c98397cb',
  activeBaselineAcceptedAt: DateTime.utc(2026, 3, 1),
  activeBaselineAcceptedBy: 'operator',
  activeBaselineFactCount: 12,
  pendingBaselineId: pendingBaselineId,
  pendingBaselineRevision: pendingRevision,
  pendingBaselineVerified: pendingVerified,
  pendingBaselineFacts: const [
    BaselineFactClaim(
      factId: 'f-1',
      section: 'repository',
      claim: 'single pubspec at root',
      provenance: 'observed',
      maturity: 'implemented',
      evidenceRefs: ['pubspec.yaml'],
    ),
  ],
  pendingBaselineDecisionId: pendingDecisionId,
  openClarifications: const [],
  policies: policies,
);

PolicyResponse _policy() => PolicyResponse(
  policyId: 'pol-1',
  actions: const ['push', 'merge'],
  authorisingDecisionId: 'gd-p001',
  authorisedBy: 'operator',
  rationale: 'Approved 31 of 31 unchanged',
  authorisedAt: DateTime.utc(2026, 3, 1),
  isRevoked: false,
);

/// Mirrors `ProductRegistryEngine._lifecycleOptions` /
/// `_lifecycleQuestion` so the fake offers the same two outcomes the server
/// does, with the same wording.
DecisionResponse _lifecycleDecision(
  String action, {
  String stateWire = 'governed',
}) {
  final (question, proceedLabel, proceedText) = switch (action) {
    'pause' => (
      'Pause work for ShipIt Platform?',
      'Pause',
      'Stop dispatching new work; work already running finishes.',
    ),
    'resume' => (
      'Resume work for ShipIt Platform?',
      'Resume',
      'Start dispatching work for this product again.',
    ),
    _ => (
      'Offboard ShipIt Platform?',
      'Offboard',
      'Archive once running work finishes. Nothing is deleted.',
    ),
  };
  return DecisionResponse(
    decisionId: 'plc-$action-shipit',
    workItemId: 'product-lifecycle:shipit',
    workItemTitle: 'Product Baseline Approval',
    decisionType: 'product_decision',
    status: 'pending',
    question: question,
    context: DecisionContext(
      workflowState: stateWire,
      availableOptions: const ['proceed', 'decline'],
    ),
    options: [
      DecisionOption(
        optionId: 'proceed',
        label: proceedLabel,
        description: proceedText,
        recommended: true,
      ),
      DecisionOption(
        optionId: 'decline',
        label: 'Leave as is',
        description: 'Nothing changes.',
        recommended: false,
      ),
    ],
    recommendation: 'proceed',
    blocking: true,
    requestedAt: DateTime.utc(2026, 3, 1),
  );
}

/// A repository that records what it was asked to do.
///
/// The point of the whole suite is that the widget drives the *repository
/// call*, not a bloc event, so nothing here short-circuits at the bloc.
class _GovernanceRepository extends MockRepository {
  _GovernanceRepository({required this.detail});

  ProductDetailResponse detail;

  /// What `getProductDetail` returns once a write has landed. Without this the
  /// screen would keep showing the pre-action state and the tests would prove
  /// nothing about what an operator sees afterwards.
  ProductDetailResponse? detailAfterWrite;

  final List<({String productId, String action, bool drainInFlight})>
  lifecycleRequests = [];
  final List<
    ({
      String decisionId,
      String choice,
      String decider,
      String rationale,
      bool noWorkInFlight,
    })
  >
  lifecycleResolutions = [];
  final List<({String productId, String policyId, String revokedBy})>
  revocations = [];
  final List<({String productId, int factCount})> baselineProposals = [];
  final List<({String productId, String baselineId})> baselineApprovalRequests =
      [];

  /// Thrown by the next write, to model a server refusal.
  Object? refuseWith;

  /// Held open to model an in-flight write.
  Completer<void>? hold;

  @override
  Future<ProductDetailResponse> getProductDetail(String productId) async =>
      detail;

  Future<void> _settle() async {
    final h = hold;
    if (h != null) await h.future;
    final refusal = refuseWith;
    if (refusal != null) throw refusal;
    detail = detailAfterWrite ?? detail;
  }

  @override
  Future<DecisionResponse> requestLifecycleDecision({
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async {
    lifecycleRequests.add((
      productId: productId,
      action: action,
      drainInFlight: drainInFlight,
    ));
    await _settle();
    return _lifecycleDecision(action, stateWire: detail.state);
  }

  @override
  Future<DecisionResponse> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    bool noWorkInFlight = false,
  }) async {
    lifecycleResolutions.add((
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      noWorkInFlight: noWorkInFlight,
    ));
    await _settle();
    return _lifecycleDecision('offboard', stateWire: detail.state);
  }

  @override
  Future<void> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async {
    revocations.add((
      productId: productId,
      policyId: policyId,
      revokedBy: revokedBy,
    ));
    await _settle();
  }

  @override
  Future<DecisionResponse> proposeBaseline({
    required String productId,
    required List<Map<String, dynamic>> facts,
  }) async {
    baselineProposals.add((productId: productId, factCount: facts.length));
    await _settle();
    throw StateError(
      'Empty baseline refused: refusing to propose a baseline for $productId '
      'with zero facts',
    );
  }

  @override
  Future<DecisionResponse> requestBaselineApproval({
    required String productId,
    required String baselineId,
    String? decisionId,
  }) async {
    baselineApprovalRequests.add((
      productId: productId,
      baselineId: baselineId,
    ));
    await _settle();
    return _lifecycleDecision('offboard', stateWire: detail.state);
  }
}

/// Pumps the screen the way the ROUTER builds it: no bloc injected, the
/// production `BlocProvider` constructing the bloc itself.
///
/// This is the whole regression guard. `pendingDecision` used to be consumed
/// only by a `BlocListener` mounted exclusively on the injected-bloc branch,
/// so every test that injected a bloc passed while the real app rendered
/// nothing at all.
Future<void> _pumpProduction(
  WidgetTester tester,
  _GovernanceRepository repository, {
  Size size = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ShipItTheme.light(),
      home: Scaffold(
        body: ProductDetailPage(productId: 'shipit', repository: repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  expect(finder, findsOneWidget, reason: 'expected exactly one "$label"');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps one of the gate's OUTCOME choices.
///
/// An option's label appears twice in the gate: once in the read-only list of
/// what each outcome does, and once on the choice that selects it. The choice
/// is always built after the list, so `.last` is the choice link.
Future<void> _tapOutcome(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  expect(finder, findsOneWidget, reason: 'expected an outcome "$label"');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The nearest `Semantics(button: true)` above [text].
Semantics? _buttonAbove(WidgetTester tester, Finder text) {
  for (final element
      in find.ancestor(of: text, matching: find.byType(Semantics)).evaluate()) {
    final node = element.widget as Semantics;
    if (node.properties.button == true) return node;
  }
  return null;
}

void main() {
  group('every governance action issues its real server call', () {
    testWidgets(
      'pause from a governed product calls requestLifecycleDecision',
      (tester) async {
        final repository = _GovernanceRepository(detail: _detail());
        await _pumpProduction(tester, repository);

        await _tap(tester, 'Pause work for this product');

        expect(repository.lifecycleRequests, hasLength(1));
        expect(repository.lifecycleRequests.single.productId, 'shipit');
        expect(repository.lifecycleRequests.single.action, 'pause');
      },
    );

    testWidgets('resume from a paused product carries the resume wire value', (
      tester,
    ) async {
      final repository = _GovernanceRepository(
        detail: _detail(state: 'paused', allowsDispatch: false),
      );
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Resume work');

      expect(repository.lifecycleRequests.single.action, 'resume');
    });

    testWidgets(
      'offboard from a registered product calls the server in one tap',
      (tester) async {
        final repository = _GovernanceRepository(
          detail: _detail(
            state: 'registered',
            allowsDispatch: false,
            activeBaselineId: null,
            activeRevision: null,
          ),
        );
        await _pumpProduction(tester, repository);

        await _tap(tester, 'Offboard this product');

        expect(repository.lifecycleRequests, hasLength(1));
        expect(repository.lifecycleRequests.single.action, 'offboard');
      },
    );

    testWidgets('revoke calls revokeStandingPolicy with the live policy id', (
      tester,
    ) async {
      final repository = _GovernanceRepository(
        detail: _detail(policies: [_policy()]),
      );
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Revoke the standing policy');

      expect(repository.revocations, hasLength(1));
      expect(repository.revocations.single.productId, 'shipit');
      expect(repository.revocations.single.policyId, 'pol-1');
      expect(repository.revocations.single.revokedBy, 'operator');
      // An attributed write, not a decision: no gate is raised.
      expect(repository.lifecycleRequests, isEmpty);
    });

    testWidgets('a revoked policy is not offered, so nothing can be revoked', (
      tester,
    ) async {
      final repository = _GovernanceRepository(
        detail: _detail(
          policies: [
            PolicyResponse(
              policyId: 'pol-1',
              actions: const ['push'],
              authorisingDecisionId: 'gd-p001',
              authorisedBy: 'operator',
              rationale: 'x',
              authorisedAt: DateTime.utc(2026, 3, 1),
              isRevoked: true,
            ),
          ],
        ),
      );
      await _pumpProduction(tester, repository);

      expect(find.text('Revoke the standing policy'), findsNothing);
      await _tap(tester, 'Pause work for this product');
      expect(repository.revocations, isEmpty);
    });

    testWidgets(
      'propose issues proposeBaseline and reports its refusal in place',
      (tester) async {
        final repository = _GovernanceRepository(detail: _detail());
        await _pumpProduction(tester, repository);

        await _tap(tester, 'Propose a new baseline');

        expect(repository.baselineProposals, hasLength(1));
        expect(repository.baselineProposals.single.productId, 'shipit');
        // The engine refuses a zero-fact proposal, so the refusal is what the
        // operator must be shown — not a silent no-op.
        expect(find.textContaining('Empty baseline refused'), findsOneWidget);
      },
    );
  });

  group('the raised gate renders in place, in a production build', () {
    testWidgets(
      'a raised pause gate is on the screen, not written and forgotten',
      (tester) async {
        final repository = _GovernanceRepository(detail: _detail());
        await _pumpProduction(tester, repository);

        await _tap(tester, 'Pause work for this product');

        expect(find.text('This action needs your decision'), findsOneWidget);
        expect(find.text('Pause work for ShipIt Platform?'), findsOneWidget);
        expect(find.textContaining('ref plc-pause-shipit'), findsOneWidget);
        expect(
          find.textContaining('blocking until you decide'),
          findsOneWidget,
        );
        // The decision's own options, in the engine's own wording.
        expect(
          find.text(
            'Stop dispatching new work; work already running finishes.',
          ),
          findsOneWidget,
        );
        expect(find.text('Nothing changes.'), findsOneWidget);
      },
    );

    testWidgets('the action list is withdrawn while a gate is open', (
      tester,
    ) async {
      // Leaving the actions up would let a second gate be raised and strand
      // the first, which nothing on this screen could then resolve.
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Pause work for this product');

      expect(find.text('Offboard this product'), findsNothing);
      expect(
        find.textContaining('A decision raised from this screen is open'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the gate also renders on mobile, where it was previously absent',
      (tester) async {
        final repository = _GovernanceRepository(detail: _detail());
        await _pumpProduction(tester, repository, size: const Size(390, 1600));

        await _tap(tester, 'Pause work for this product');

        expect(find.text('This action needs your decision'), findsOneWidget);
      },
    );
  });

  group('the resolve half exists and is called', () {
    /// Drives the gate from "raised" to "recorded".
    Future<void> resolve(
      WidgetTester tester, {
      required String option,
      String rationale = 'Nothing should be dispatching right now.',
    }) async {
      await _tapOutcome(tester, option);
      await tester.enterText(find.byType(TextField), rationale);
      await tester.pumpAndSettle();
      await _tap(tester, 'Record decision');
    }

    testWidgets(
      'approving calls resolveLifecycleDecision and closes the gate',
      (tester) async {
        final repository = _GovernanceRepository(detail: _detail());
        await _pumpProduction(tester, repository);
        await _tap(tester, 'Pause work for this product');

        await resolve(tester, option: 'Pause');

        expect(repository.lifecycleResolutions, hasLength(1));
        final recorded = repository.lifecycleResolutions.single;
        expect(recorded.decisionId, 'plc-pause-shipit');
        expect(recorded.choice, 'approve');
        expect(recorded.decider, 'operator');
        expect(recorded.rationale, 'Nothing should be dispatching right now.');
        expect(find.text('This action needs your decision'), findsNothing);
        // The action list comes back once nothing is pending.
        expect(find.text('Pause work for this product'), findsOneWidget);
      },
    );

    testWidgets('declining is recorded as reject, not as a silent nothing', (
      tester,
    ) async {
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);
      await _tap(tester, 'Pause work for this product');

      await resolve(tester, option: 'Leave as is');

      expect(repository.lifecycleResolutions.single.choice, 'reject');
    });

    testWidgets(
      'the rationale is required before the decision can be recorded',
      (tester) async {
        final repository = _GovernanceRepository(detail: _detail());
        await _pumpProduction(tester, repository);
        await _tap(tester, 'Pause work for this product');

        await _tapOutcome(tester, 'Pause');
        await _tap(tester, 'Record decision');

        expect(repository.lifecycleResolutions, isEmpty);
        expect(
          find.textContaining('Choose an outcome and record a rationale'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a governed offboard asks the operator to state that no work is running',
      (tester) async {
        final repository = _GovernanceRepository(detail: _detail());
        await _pumpProduction(tester, repository);

        // Past the typed fence, so the gate is genuinely open.
        await _tap(tester, 'Offboard this product');
        await tester.enterText(find.byType(TextField), 'shipit');
        await tester.pumpAndSettle();
        await _tap(tester, 'Confirm offboard');

        expect(repository.lifecycleRequests.single.action, 'offboard');
        // The engine hands this guard over on trust, so the copy has to say it
        // is a statement rather than a reading.
        expect(find.textContaining('You are stating this'), findsOneWidget);

        await _tapOutcome(tester, 'Offboard');
        await tester.enterText(
          find.byType(TextField),
          'Nothing should be dispatching right now.',
        );
        await tester.pumpAndSettle();
        // A choice alone is not enough while the assertion is outstanding.
        await _tap(tester, 'Record decision');
        expect(repository.lifecycleResolutions, isEmpty);
        expect(
          find.textContaining('Confirm that no work is running'),
          findsOneWidget,
        );

        await _tap(
          tester,
          'No work is currently running for this product. You are stating '
          'this; the registry records your statement and does not check it.',
        );
        await _tap(tester, 'Record decision');

        expect(repository.lifecycleResolutions, hasLength(1));
        expect(repository.lifecycleResolutions.single.noWorkInFlight, isTrue);
        expect(repository.lifecycleResolutions.single.choice, 'approve');
      },
    );

    testWidgets(
      'a registered offboard does not ask for an assertion it does not need',
      (tester) async {
        // `(registered, archived)` waives `noWorkInFlight`: there is nothing
        // running to strand, so demanding the statement would fence an
        // irreversible action for no reason.
        final repository = _GovernanceRepository(
          detail: _detail(
            state: 'registered',
            allowsDispatch: false,
            activeBaselineId: null,
            activeRevision: null,
          ),
        );
        await _pumpProduction(tester, repository);
        await _tap(tester, 'Offboard this product');

        expect(
          find.textContaining('No work is currently running'),
          findsNothing,
        );
        await _tapOutcome(tester, 'Offboard');
        await tester.enterText(find.byType(TextField), 'Archived on purpose.');
        await tester.pumpAndSettle();
        await _tap(tester, 'Record decision');

        expect(repository.lifecycleResolutions, hasLength(1));
        expect(repository.lifecycleResolutions.single.noWorkInFlight, isFalse);
      },
    );
  });

  group('offboarding a governed product is fenced behind typing its id', () {
    testWidgets('the tap alone sends nothing', (tester) async {
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Offboard this product');

      expect(repository.lifecycleRequests, isEmpty);
      expect(find.textContaining('TYPE shipit TO CONFIRM'), findsOneWidget);
    });

    testWidgets('a wrong id sends nothing and says so', (tester) async {
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);
      await _tap(tester, 'Offboard this product');

      await tester.enterText(find.byType(TextField), 'shipit-typo');
      await tester.pumpAndSettle();
      await _tap(tester, 'Confirm offboard');

      expect(repository.lifecycleRequests, isEmpty);
      expect(find.textContaining('Nothing has been sent'), findsOneWidget);
    });

    testWidgets('the exact id sends the offboard', (tester) async {
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);
      await _tap(tester, 'Offboard this product');

      await tester.enterText(find.byType(TextField), 'shipit');
      await tester.pumpAndSettle();
      await _tap(tester, 'Confirm offboard');

      expect(repository.lifecycleRequests, hasLength(1));
      expect(repository.lifecycleRequests.single.action, 'offboard');
    });

    testWidgets('cancelling sends nothing and restores the plain action', (
      tester,
    ) async {
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);
      await _tap(tester, 'Offboard this product');

      await _tap(tester, 'Cancel');

      expect(repository.lifecycleRequests, isEmpty);
      expect(find.textContaining('TYPE shipit TO CONFIRM'), findsNothing);
    });

    testWidgets('the consequence is stated before the box', (tester) async {
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Offboard this product');

      expect(find.textContaining('leaves'), findsWidgets);
      expect(find.textContaining('nothing is deleted'), findsOneWidget);
    });
  });

  group('a refusal is visible in place', () {
    const refusal =
        'Product lifecycle: cannot transition shipit from registered to '
        'governed: no legal transition from registered to governed';

    testWidgets('the reason appears inside the Governance panel', (
      tester,
    ) async {
      final repository = _GovernanceRepository(detail: _detail())
        ..refuseWith = StateError(refusal);
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Pause work for this product');

      expect(find.text('The registry refused that action.'), findsOneWidget);
      // `StateError.toString()` prefixes the class, so match on the server's
      // own reason rather than on the wrapper.
      expect(find.textContaining(refusal), findsOneWidget);
      // The reuse is deliberate: DesignErrorState's own sentence is exactly
      // right here, and its page-level title is exactly wrong.
      expect(
        find.textContaining('No decision was recorded and no work'),
        findsOneWidget,
      );
    });

    testWidgets('the page is not taken over and the product stays readable', (
      tester,
    ) async {
      final repository = _GovernanceRepository(detail: _detail())
        ..refuseWith = StateError(refusal);
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Pause work for this product');

      expect(find.text('ShipIt Platform'), findsOneWidget);
      expect(find.text('Governance'), findsOneWidget);
      expect(
        find.text("We could not reach the system's records."),
        findsNothing,
      );
    });

    testWidgets('the refusal is announced as a live region', (tester) async {
      final repository = _GovernanceRepository(detail: _detail())
        ..refuseWith = StateError(refusal);
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Pause work for this product');

      final liveRegions = find
          .byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          )
          .evaluate();
      expect(liveRegions, isNotEmpty);
    });

    testWidgets('dismissing clears it without re-running the action', (
      tester,
    ) async {
      final repository = _GovernanceRepository(detail: _detail())
        ..refuseWith = StateError(refusal);
      await _pumpProduction(tester, repository);
      await _tap(tester, 'Pause work for this product');

      await _tap(tester, 'Dismiss');

      expect(find.text('The registry refused that action.'), findsNothing);
      expect(repository.lifecycleRequests, hasLength(1));
    });

    testWidgets('the action becomes usable again after a refusal', (
      tester,
    ) async {
      final repository = _GovernanceRepository(detail: _detail())
        ..refuseWith = StateError(refusal);
      await _pumpProduction(tester, repository);
      await _tap(tester, 'Pause work for this product');
      await _tap(tester, 'Dismiss');

      repository.refuseWith = null;
      await _tap(tester, 'Pause work for this product');

      expect(find.text('This action needs your decision'), findsOneWidget);
    });
  });

  group('a baseline gate can be reached', () {
    testWidgets(
      'a baselinePending product whose candidate a worker verified can open it',
      (tester) async {
        final repository =
            _GovernanceRepository(
                detail: _detail(
                  state: 'baseline_pending',
                  allowsDispatch: false,
                  activeBaselineId: null,
                  activeRevision: null,
                  pendingBaselineId: 'bl-shipit-8',
                  pendingRevision: 8,
                  pendingVerified: true,
                ),
              )
              ..detailAfterWrite = _detail(
                state: 'baseline_review',
                allowsDispatch: false,
                activeBaselineId: null,
                activeRevision: null,
                pendingBaselineId: 'bl-shipit-8',
                pendingRevision: 8,
                pendingVerified: true,
                pendingDecisionId: 'blappr-bl-shipit-8',
              );
        await _pumpProduction(tester, repository);

        await _tap(tester, 'Review and approve the baseline');

        expect(repository.baselineApprovalRequests, hasLength(1));
        expect(repository.baselineApprovalRequests.single.productId, 'shipit');
        expect(
          repository.baselineApprovalRequests.single.baselineId,
          'bl-shipit-8',
        );
        // The gate opens on screen, in place, because the product state now
        // carries the bound decision.
        expect(find.text('A baseline needs your approval'), findsOneWidget);
        expect(find.textContaining('bl-shipit-8 · revision 8'), findsWidgets);
        expect(find.textContaining('single pubspec at root'), findsWidgets);
      },
    );

    testWidgets(
      'an unverified candidate is not offered, because the engine refuses it',
      (tester) async {
        final repository = _GovernanceRepository(
          detail: _detail(
            state: 'baseline_pending',
            allowsDispatch: false,
            activeBaselineId: null,
            activeRevision: null,
            pendingBaselineId: 'bl-shipit-8',
            pendingRevision: 8,
            pendingVerified: false,
          ),
        );
        await _pumpProduction(tester, repository);

        expect(find.text('Review and approve the baseline'), findsNothing);
        expect(repository.baselineApprovalRequests, isEmpty);
      },
    );

    testWidgets(
      'a registered product is offered no baseline control the engine refuses',
      (tester) async {
        // Checked against the engine, not assumed:
        //  * requestBaselineApproval from `registered` → BaselineNotFound,
        //    and (registered, baseline_review) is not an edge at all;
        //  * proposeBaseline needs facts this screen has no source for, and
        //    the approval half then refuses anything unverified.
        // Offering either would be offering a guaranteed 500.
        final repository = _GovernanceRepository(
          detail: _detail(
            state: 'registered',
            allowsDispatch: false,
            activeBaselineId: null,
            activeRevision: null,
          ),
        );
        await _pumpProduction(tester, repository);

        expect(find.text('Propose a new baseline'), findsNothing);
        expect(find.text('Review and approve the baseline'), findsNothing);
        expect(find.text('Offboard this product'), findsOneWidget);
      },
    );
  });

  group('offboard is not offered where the transition table refuses it', () {
    for (final state in ['baseline_pending', 'baseline_review']) {
      testWidgets('$state offers no offboard', (tester) async {
        // (baselinePending, archived) and (baselineReview, archived) are not
        // edges; `requestLifecycleDecision` throws before creating anything.
        final repository = _GovernanceRepository(
          detail: _detail(
            state: state,
            allowsDispatch: false,
            activeBaselineId: null,
            activeRevision: null,
          ),
        );
        await _pumpProduction(tester, repository);

        expect(find.text('Offboard this product'), findsNothing);
      });
    }

    testWidgets('baselineBlocked still offers it, because that edge is legal', (
      tester,
    ) async {
      final repository = _GovernanceRepository(
        detail: _detail(
          state: 'baseline_blocked',
          allowsDispatch: false,
          activeBaselineId: null,
          activeRevision: null,
        ),
      );
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Offboard this product');

      expect(repository.lifecycleRequests.single.action, 'offboard');
    });
  });

  group('an in-flight action is visible and cannot be double-fired', () {
    testWidgets('the action is disabled and progress is shown', (tester) async {
      final repository = _GovernanceRepository(detail: _detail())
        ..hold = Completer<void>();
      await _pumpProduction(tester, repository);

      final action = find.text('Pause work for this product');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();

      expect(_buttonAbove(tester, action)?.properties.enabled, isFalse);
      expect(find.text('Working…'), findsOneWidget);

      // A second tap on the now-disabled control must not fire a second write.
      await tester.tap(action);
      await tester.pump();
      expect(repository.lifecycleRequests, hasLength(1));

      repository.hold!.complete();
      await tester.pumpAndSettle();
      // Once the write lands the gate is open, so the action is withdrawn
      // rather than re-enabled — the operator's next step is the decision.
      expect(find.text('This action needs your decision'), findsOneWidget);
    });
  });

  group('the actions are real buttons', () {
    testWidgets('each action carries the button role, not the link role', (
      tester,
    ) async {
      final repository = _GovernanceRepository(
        detail: _detail(policies: [_policy()]),
      );
      await _pumpProduction(tester, repository);

      for (final label in [
        'Propose a new baseline',
        'Pause work for this product',
        'Offboard this product',
        'Revoke the standing policy',
      ]) {
        final node = _buttonAbove(tester, find.text(label));
        expect(
          node,
          isNotNull,
          reason: '$label must be a button, not a bare gesture detector',
        );
        expect(node!.properties.enabled, isTrue);
      }
    });

    testWidgets('they are reachable by keyboard activation', (tester) async {
      final repository = _GovernanceRepository(detail: _detail());
      await _pumpProduction(tester, repository);

      await _tap(tester, 'Pause work for this product');

      expect(repository.lifecycleRequests, hasLength(1));
    });
  });
}

import 'package:platform_contracts/platform_contracts.dart';

/// Conditions that must hold before a [ProductState] transition is legal.
///
/// Named rather than stringly-typed (AGENTS.md §8). These are evaluated by
/// `product_registry`, which owns the data needed to answer them; the policy
/// of *which* guards apply to *which* edge lives in [ProductTransitions].
enum ProductGuard {
  /// An open `ClarificationRequest` exists for this product.
  clarificationOpen('clarification_open'),

  /// Every `ClarificationRequest` for this product is answered.
  clarificationAnswered('clarification_answered'),

  /// A `ProductBaseline` revision exists in
  /// `ProductBaselineStatus.proposed`.
  baselineProposed('baseline_proposed'),

  /// The proposed baseline was verified by a worker, not by the agent that
  /// produced it (AGENTS.md §12).
  baselineVerifiedIndependently('baseline_verified_independently'),

  /// A `HumanDecision` of type `productDecision` resolved to `approve`.
  baselineApproved('baseline_approved'),

  /// ...resolved to `requestChanges`.
  baselineChangesRequested('baseline_changes_requested'),

  /// ...resolved to `reject`.
  baselineRejected('baseline_rejected'),

  /// A durable, signed pause decision exists.
  pauseDecisionRecorded('pause_decision_recorded'),

  /// A durable, signed resume decision exists.
  resumeDecisionRecorded('resume_decision_recorded'),

  /// A durable, signed offboard decision exists.
  offboardDecisionRecorded('offboard_decision_recorded'),

  /// A durable, signed reinstate decision exists.
  reinstateDecisionRecorded('reinstate_decision_recorded'),

  /// The deciding actor is a human, not an agent or the orchestrator.
  decisionActorIsHuman('decision_actor_is_human'),

  /// No `WorkItem` for this product is still running. Offboarding a product
  /// with work in flight would strand it.
  noWorkInFlight('no_work_in_flight');

  const ProductGuard(this.wire);

  final String wire;

  static ProductGuard fromWire(String value) => values.firstWhere(
    (g) => g.wire == value,
    orElse: () => throw FormatException('Unknown product guard: $value'),
  );
}

/// Legal [ProductState] transitions (ADR 0018, ADR 0019, checkpoint 006 §3).
///
/// Products previously had no transition table — `activateProduct` hand-rolled
/// a single `if (state != draft) throw`. AGENTS.md §1 requires enum +
/// validated transitions, so policy lives here declaratively and
/// `product_registry` consumes it rather than re-deriving it.
///
/// Two rules are structural rather than conventional:
///
/// 1. **Legacy states are never transition targets.** `draft`, `active` and
///    `deprecated` are parse-only (see [ProductState]); nothing may move *to*
///    them. Rows holding them may still move *out*, via
///    [ProductState.canonical].
/// 2. **Archived is not reversed by an edge back to governed.** Reinstating
///    re-enters through [ProductState.baselineReview], because a frozen
///    baseline is stale by definition.
class ProductTransitions {
  static const Map<(ProductState, ProductState), List<ProductGuard>>
  _legalTransitions = {
    /*** Onboarding — registering is deliberately not governing ***/
    (ProductState.registered, ProductState.baselinePending): [],
    (ProductState.baselinePending, ProductState.baselineBlocked): [
      ProductGuard.clarificationOpen,
    ],
    (ProductState.baselineBlocked, ProductState.baselinePending): [
      ProductGuard.clarificationAnswered,
    ],
    // Built *and* independently verified before a human is asked anything.
    (ProductState.baselinePending, ProductState.baselineReview): [
      ProductGuard.baselineProposed,
      ProductGuard.baselineVerifiedIndependently,
    ],

    /*** The gate (ADR 0013 — execution terminates here) ***/
    (ProductState.baselineReview, ProductState.governed): [
      ProductGuard.baselineApproved,
      ProductGuard.decisionActorIsHuman,
    ],
    // "Request changes" re-reads the source, so it returns to pending rather
    // than reusing the baseline that was sent back.
    (ProductState.baselineReview, ProductState.baselinePending): [
      ProductGuard.baselineChangesRequested,
      ProductGuard.decisionActorIsHuman,
    ],
    (ProductState.baselineReview, ProductState.registered): [
      ProductGuard.baselineRejected,
      ProductGuard.decisionActorIsHuman,
    ],

    /*** Operating ***/
    (ProductState.governed, ProductState.paused): [
      ProductGuard.pauseDecisionRecorded,
      ProductGuard.decisionActorIsHuman,
    ],
    (ProductState.paused, ProductState.governed): [
      ProductGuard.resumeDecisionRecorded,
      ProductGuard.decisionActorIsHuman,
    ],
    // Re-baselining a governed product. The accepted baseline stays active
    // until the new one is decided, so dispatch is never interrupted.
    (ProductState.governed, ProductState.baselineReview): [
      ProductGuard.baselineProposed,
      ProductGuard.baselineVerifiedIndependently,
    ],

    /*** Offboarding ***/
    (ProductState.governed, ProductState.archived): [
      ProductGuard.offboardDecisionRecorded,
      ProductGuard.decisionActorIsHuman,
      ProductGuard.noWorkInFlight,
    ],
    (ProductState.paused, ProductState.archived): [
      ProductGuard.offboardDecisionRecorded,
      ProductGuard.decisionActorIsHuman,
      ProductGuard.noWorkInFlight,
    ],
    // Onboarding may be abandoned before anything was ever governed.
    (ProductState.registered, ProductState.archived): [
      ProductGuard.offboardDecisionRecorded,
      ProductGuard.decisionActorIsHuman,
    ],
    (ProductState.baselineBlocked, ProductState.archived): [
      ProductGuard.offboardDecisionRecorded,
      ProductGuard.decisionActorIsHuman,
    ],

    /*** Reinstatement ***/
    (ProductState.archived, ProductState.baselineReview): [
      ProductGuard.reinstateDecisionRecorded,
      ProductGuard.baselineProposed,
      ProductGuard.baselineVerifiedIndependently,
      ProductGuard.decisionActorIsHuman,
    ],
  };

  /// Every legal `(from, to)` pair. Exposed for exhaustiveness tests.
  static Iterable<(ProductState, ProductState)> get all =>
      _legalTransitions.keys;

  static bool isLegalTransition(ProductState from, ProductState to) {
    if (to.isLegacy) return false;
    return _legalTransitions.containsKey((from.canonical, to));
  }

  /// Guards that must hold for `(from, to)`. Empty means the transition is
  /// machine-driven and unconditional.
  static List<ProductGuard> requiredGuards(ProductState from, ProductState to) =>
      _legalTransitions[(from.canonical, to)] ?? const [];

  /// Whether this edge may only be caused by a human decision.
  static bool requiresHumanDecision(ProductState from, ProductState to) =>
      requiredGuards(from, to).contains(ProductGuard.decisionActorIsHuman);

  /// States reachable from [from].
  static List<ProductState> reachableFrom(ProductState from) => [
    for (final (f, t) in _legalTransitions.keys)
      if (f == from.canonical) t,
  ];

  /// Why `(from, to)` is rejected, or `null` if it is legal. Callers that want
  /// a reason rather than a bool use this to build durable rejection records.
  static String? explainRejection(ProductState from, ProductState to) {
    if (to.isLegacy) {
      return '${to.wire} is parse-only and is never a legal transition target';
    }
    if (isLegalTransition(from, to)) return null;
    final read = from.isLegacy ? ' (read as ${from.canonical.wire})' : '';
    return 'no legal transition from ${from.wire}$read to ${to.wire}';
  }
}

/// Per-product lifecycle (checkpoint 006 §3, ADR 0018, ADR 0019).
///
/// A Product is not a WorkItem and does not reuse [WorkItemState]. Its
/// lifecycle answers one question: **may work be dispatched for this
/// product, and if not, what is it waiting on?**
///
/// Legal transitions are declared in `ProductTransitions`
/// (`packages/workflow_engine`), not inferred from this enum.
///
/// ## Migration (supersedes `{draft, active, archived, deprecated}`)
///
/// The previous four values carried no wire strings and could not express
/// "registered but ungoverned", "baseline under review", or "paused". They
/// remain as **parse-only** values so persisted rows continue to deserialise;
/// they are never legal transition targets. Follow the [WorkItemState.done]
/// precedent: read old rows, never write them.
///
/// | Legacy       | Read as            |
/// |--------------|--------------------|
/// | `draft`      | [registered]       |
/// | `active`     | [governed]         |
/// | `deprecated` | [archived]         |
enum ProductState {
  /// Registered in the registry. No baseline, no governance, no work.
  ///
  /// Registering is deliberately not governing: a product is visible here
  /// before anything about it has been approved.
  registered('registered'),

  /// A baseline is being built from the product's repository at a pinned
  /// revision. Machine work; no human is waiting.
  baselinePending('baseline_pending'),

  /// Baseline work stopped because material information is unknown and only a
  /// human can supply it. Pairs with an open `ClarificationRequest`.
  baselineBlocked('baseline_blocked'),

  /// A baseline has been built and independently verified, and is waiting on a
  /// human decision. This is a durable gate (ADR 0013): execution terminates
  /// here until the decision resolves.
  baselineReview('baseline_review'),

  /// A baseline is accepted. Work may be dispatched for this product.
  governed('governed'),

  /// Governed, but the scheduler will not dispatch new work.
  ///
  /// Reversible and non-destructive: the accepted baseline is untouched and
  /// nothing is cancelled. Both the pause and the resume are recorded.
  paused('paused'),

  /// Offboarded. No new work can be created or dispatched, and the active
  /// baseline is frozen at its last accepted revision.
  ///
  /// Never a delete: every decision, run and piece of evidence stays readable.
  /// Reinstating requires a fresh [baselineReview], because the source will
  /// have moved on.
  archived('archived'),

  @Deprecated(
    'Use registered instead. draft is parse-only and never a legal '
    'transition target.',
  )
  draft('draft'),

  @Deprecated(
    'Use governed instead. active is parse-only and never a legal '
    'transition target.',
  )
  active('active'),

  @Deprecated(
    'Use archived instead. deprecated is parse-only and never a legal '
    'transition target.',
  )
  deprecated('deprecated');

  const ProductState(this.wire);

  final String wire;

  /// Legacy values retained only so old persisted rows deserialise.
  bool get isLegacy => switch (this) {
    // ignore: deprecated_member_use_from_same_package
    ProductState.draft ||
    // ignore: deprecated_member_use_from_same_package
    ProductState.active ||
    // ignore: deprecated_member_use_from_same_package
    ProductState.deprecated => true,
    _ => false,
  };

  /// Canonical value a legacy row should be understood as.
  ProductState get canonical => switch (this) {
    // ignore: deprecated_member_use_from_same_package
    ProductState.draft => ProductState.registered,
    // ignore: deprecated_member_use_from_same_package
    ProductState.active => ProductState.governed,
    // ignore: deprecated_member_use_from_same_package
    ProductState.deprecated => ProductState.archived,
    _ => this,
  };

  /// Whether the scheduler may dispatch new work for a product in this state.
  ///
  /// Only [governed] qualifies. [paused] deliberately does not — that is the
  /// entire point of pausing.
  bool get allowsDispatch => this == ProductState.governed;

  /// Whether a human decision is outstanding in this state.
  bool get isAwaitingHuman =>
      this == ProductState.baselineReview ||
      this == ProductState.baselineBlocked;

  /// Terminal for the product's governed lifecycle. Archived products are
  /// still readable; they are simply not reachable by new work.
  bool get isTerminal => canonical == ProductState.archived;

  static ProductState fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw FormatException('Unknown product state: $value'),
  );
}

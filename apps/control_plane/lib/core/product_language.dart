import 'package:flutter/widgets.dart';

import 'design_tokens.dart';

/// Plain-language rendering of `ProductState`.
///
/// The wire values are the engine's vocabulary (`baseline_review`); operators
/// get sentences. The mapping lives in one place so a state can never be
/// described two different ways on two different screens.
///
/// Unknown values are surfaced verbatim rather than guessed at — a state this
/// build does not know about is a fact about the system, not a rendering bug
/// to paper over.
enum ProductStatus {
  /// Registered, nothing governed. Deliberately reads as inert.
  registered('Registered', 'Not governed yet — no baseline'),

  /// A baseline is being built. Machine work; nobody is waiting on a human.
  baselinePending('Building baseline', 'Reading the repository'),

  /// Stopped on a question only a human can answer.
  baselineBlocked('Needs clarification', 'Onboarding stopped on a question'),

  /// The durable approval gate.
  baselineReview('Needs your approval', 'A baseline is waiting on you'),

  /// The only state in which work may be dispatched.
  governed('Governed · active', 'Work can run against the accepted baseline'),

  /// Governed but not dispatching.
  paused('Paused', 'No new work is being dispatched'),

  /// Offboarded. Readable forever, never deleted.
  archived('Archived', 'Kept for good; no new work can be created'),

  /// A value this build does not recognise.
  unknown('Unrecognised state', 'This build does not recognise this state');

  const ProductStatus(this.label, this.detail);

  /// Short label for a table cell.
  final String label;

  /// One-line explanation for a detail surface.
  final String detail;

  /// True when the operator is the thing standing in the way.
  bool get isOperatorTurn =>
      this == ProductStatus.baselineReview ||
      this == ProductStatus.baselineBlocked;

  /// Whether this state is still moving towards governance.
  bool get isOnboarding =>
      this == ProductStatus.registered ||
      this == ProductStatus.baselinePending ||
      this == ProductStatus.baselineBlocked ||
      this == ProductStatus.baselineReview;

  Color tickColor(ShipItPalette palette) => switch (this) {
    ProductStatus.governed => palette.positive,
    ProductStatus.baselineReview ||
    ProductStatus.baselineBlocked ||
    ProductStatus.paused => palette.attentionTick,
    ProductStatus.archived || ProductStatus.unknown => palette.inkTertiary,
    _ => palette.accentTick,
  };

  Color textColor(ShipItPalette palette) => switch (this) {
    ProductStatus.governed => palette.positive,
    ProductStatus.baselineReview ||
    ProductStatus.baselineBlocked ||
    ProductStatus.paused => palette.attention,
    ProductStatus.archived || ProductStatus.unknown => palette.inkTertiary,
    _ => palette.inkSecondary,
  };
}

abstract final class ProductLanguage {
  /// Maps a `ProductState` wire value onto its plain-language status.
  ///
  /// Legacy values (`draft`, `active`, `deprecated`) are still readable from
  /// old rows, so they are mapped to their canonical meaning rather than
  /// falling through to [ProductStatus.unknown].
  static ProductStatus statusFor(String wire) => switch (wire) {
    'registered' => ProductStatus.registered,
    'baseline_pending' => ProductStatus.baselinePending,
    'baseline_blocked' => ProductStatus.baselineBlocked,
    'baseline_review' => ProductStatus.baselineReview,
    'governed' => ProductStatus.governed,
    'paused' => ProductStatus.paused,
    'archived' => ProductStatus.archived,
    // Legacy, parse-only (ADR 0018).
    'draft' => ProductStatus.registered,
    'active' => ProductStatus.governed,
    'deprecated' => ProductStatus.archived,
    _ => ProductStatus.unknown,
  };

  /// What to show in the BASELINE column.
  ///
  /// Names the accepted baseline when there is one. Otherwise names the
  /// candidate under review, marked as proposed so it is never mistaken for
  /// something that has been agreed. Says so plainly when there is neither.
  static String baselineLabel({
    String? activeId,
    int? activeRevision,
    String? pendingId,
    int? pendingRevision,
    bool pendingVerified = true,
  }) {
    if (activeId != null) {
      return activeRevision == null ? activeId : '$activeId · r$activeRevision';
    }
    if (pendingId != null) {
      final rev = pendingRevision == null ? '' : ' · r$pendingRevision';
      // An unverified candidate cannot be approved — the gate refuses to open
      // (AGENTS.md §12). That belongs next to the baseline it describes, not
      // buried in the product's status.
      final mark = pendingVerified ? 'proposed' : 'proposed, not verified';
      return '$pendingId$rev · $mark';
    }
    return 'none yet';
  }

  /// Credential reachability, stated as a fact rather than a reassurance.
  static String accessLabel({
    required int repositoryCount,
    required int reachableCount,
  }) {
    if (repositoryCount == 0) return 'no repository';
    if (reachableCount == 0) {
      return repositoryCount == 1
          ? 'not reachable'
          : '0 of $repositoryCount reachable';
    }
    if (reachableCount == repositoryCount) {
      return repositoryCount == 1
          ? 'reachable'
          : 'all $repositoryCount reachable';
    }
    return '$reachableCount of $repositoryCount reachable';
  }

  /// Summary line under the page title.
  static String summary(List<ProductStatus> statuses) {
    if (statuses.isEmpty) return 'No products are registered yet.';
    final governed = statuses.where((s) => s == ProductStatus.governed).length;
    final onboarding = statuses.where((s) => s.isOnboarding).length;
    final paused = statuses.where((s) => s == ProductStatus.paused).length;
    final parts = <String>[
      '$governed governed',
      if (onboarding > 0) '$onboarding onboarding',
      if (paused > 0) '$paused paused',
    ];
    final total = statuses.length;
    return '$total ${total == 1 ? 'product' : 'products'}. '
        '${parts.join(', ')}.';
  }
}

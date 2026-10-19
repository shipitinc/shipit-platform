import 'package:platform_contracts/platform_contracts.dart';

import 'design_governance_store.dart';

/// The §3.5.3 write gate, in the one place both implementations of
/// [DesignGovernanceStore] are made to call.
///
/// ## WHY THIS IS A FUNCTION AND NOT A METHOD ON THE INTERFACE
///
/// `DesignGovernanceStore` is an `abstract interface class`, which in Dart
/// forbids a default implementation: every member is unimplemented and every
/// `implements` clause must supply one. A rule enforced by a per-implementation
/// override is therefore a rule each implementation can silently omit — and the
/// failure mode of omitting it is the worst kind available, because the store
/// that skips it accepts writes the other one refuses, so the defect is
/// invisible until something runs against both and gets two different answers.
/// That is F-146: two implementations of one interface disagreeing, with the
/// disagreement only visible to whoever thinks to compare them.
///
/// So the rule is a top-level function, and both stores call THIS one. Adding a
/// third implementation of the interface means calling this function or
/// deliberately choosing not to, which is a visible act in a diff rather than an
/// omission nobody notices.
///
/// ## WHAT IT DOES
///
/// Two things, in this order, and the order is the point:
///
///  1. **Canonicalise.** §3.5.2's four normalisation rules are applied ON WRITE,
///     so the stored value is already canonical and never has to be normalised
///     twice. This also validates: `canonicalise` drops only the canonicity
///     check, so a revision that violates any of §3.5.1's rules throws here
///     rather than being tidied into a tidier violation.
///  2. **Re-assert.** `requireValid` then runs on the canonical result WITH
///     canonicity included. This is redundant if `canonicalise` is correct and
///     is the point of the exercise if it is not: a canonicaliser that emitted
///     something its own validator refuses would otherwise store a row that
///     fails closed on its very next read, and the second call is what makes
///     that failure a loud write-time refusal instead of a silent one.
///
/// ## WHAT IT REFUSES
///
/// It raises [DesignRevisionFidelityAnchorException] and returns nothing else.
/// There is no "persist and flag" path, and no warning-shaped return, because
/// §3.5.3 rules out exactly that: a row that is persisted and flagged is
/// readable by a reader that never checks the flag, so the flag is not a
/// control. A caller that catches this exception and writes the revision anyway
/// has made a decision the design does not permit, and nothing here pretends to
/// stop that — which is why the shared contract suite asserts both
/// implementations refuse, rather than trusting this doc comment.
///
/// ## WHAT IT DELIBERATELY DOES NOT DO
///
/// It does not compare the anchor against the revision's Penpot columns. That is
/// §3.5.4's report, and §3.5.4 forbids making it a gate: refusing a write on
/// such a disagreement would resolve it by picking the schema as the winner,
/// which operator decision `a1c7d904` rules out. `DesignRevisionFidelityAnchorDisagreements`
/// stays report-only and is never called from here.
///
/// It does not decide what a READ of a pre-existing, non-conforming row should
/// do. §3.5.3 also requires a read to report `schemaInvalid`, and nothing in
/// this tree implements that: `schemaInvalid` appears only in the design
/// document, with no type, no field and no caller. Choosing a representation for
/// it here would be inventing a contract the design has not fixed, so it is
/// named in this doc comment as outstanding rather than guessed at. It is the
/// same class of gap as the reference-map shape a design correction is currently
/// settling for `validationSchema`.
DesignRevision gateDesignRevisionWrite(DesignRevision revision) {
  final canonical = DesignRevisionFidelityAnchorValidator.canonicalise(
    revision,
  );
  // Discards the returned anchor: what the store needs is proof that the value
  // it is about to persist satisfies every rule including canonicity, not a
  // decoded copy of it.
  DesignRevisionFidelityAnchorValidator.requireValid(canonical);
  return canonical;
}

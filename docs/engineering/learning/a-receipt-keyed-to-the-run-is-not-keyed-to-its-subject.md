# Repository Learning: a receipt keyed to the run is not a receipt keyed to its subject

**Feature**: IMPL-B6-CORRECTION-FINDINGS (keying the review-repair receipt to a decision)
**Date**: 2026-10-15
**HEAD**: see `git rev-parse HEAD` on `fix/unstick-unreviewable`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic
authority.

---

## Summary

`ReviewRepairAffordance` rendered its one-way receipt whenever `report != null`, and
`repairReport` is **deliberately preserved across `RunDetailLoaded()`** (the receipt
must outlive its own repair). The receipt carried no reference to *which* decision
it concerned.

The receipt's premise was: *"every refusal is a statement about durable state that
cannot change under the operator's feet."* That is true of the **subject** of the
prior refusal and of nothing else.

A work item parks on a decision **more than once**: a repair is retired, the
re-queued review runs, and the item parks again behind the next question. On that
second park the operator saw a stale receipt for a decision they never attempted,
**and no offer at all** — silently disabling the repair for the next fabrication,
which is the recurring shape the feature exists for.

## The distinction that makes it legible

| thing | changes over the operator's feet? |
|---|---|
| the item's durable state | **yes** — parked again, behind a different decision |
| the *subject* of the prior refusal | no — a reviewer really did return a verdict, or a human really did answer |

The receipt was keyed on the first and assumed the second. `ReviewRepairReport` now
carries the `decisionId` it concerns, and `build` renders the **offer** when
`decisionId != null && report.decisionId != decisionId`.

Three states, all asserted:

| state | renders | why |
|---|---|---|
| nothing parked (`id == null`) | receipt | an accepted repair retired the decision; the receipt must survive its own repair |
| parked on the receipt's own decision | receipt | asking again would be refused again, identically |
| parked on a **different** decision | **offer** | the receipt is about something no longer in front of the operator |

`decisionId == null` on the report is a real state, not an absence: it is the
`invalidRequest` and transport-failure paths, where nothing about any decision was
examined. Those must **not** suppress the offer — an attempt that never arrived has
not answered anything.

## Two test traps worth naming

Both were hit while writing the tests, and both produced a test that passed against
the *unfixed* code:

1. **Asserting a mismatch is not asserting a subject.** `expect(report.decisionId,
   isNot(blockingId))` passes when `decisionId` is `null` — i.e. when the field was
   never populated at all. The test must *also* assert the report is keyed to the
   expected id. Without that, reverting the fix leaves the test green.
2. **A receipt-keying rule must be tested on all three states, not just the new
   one.** Fixing only the mismatch arm turns the rule into "any receipt re-offers",
   which re-introduces the affordance-to-doubt-the-answer problem the one-way rule
   exists to prevent.

Verified by reverting the fix: the recurrence tests fail (widget: `THE RECURRENCE`,
`a receipt keyed to NO decision does not stand in for one`; bloc: `THE RECURRENCE`,
`a receipt carries the decision it CONCERNED`, `the SAME decision keeps its
receipt`).

## Generalisable

> A "one-way" UI receipt should be keyed to its **subject**, not to the container it
> was displayed in. The test for "is this still the same question?" is a subject
> comparison, and a null subject must be treated as *unexamined*, never as *a
> different subject* — and never as *the same one*.
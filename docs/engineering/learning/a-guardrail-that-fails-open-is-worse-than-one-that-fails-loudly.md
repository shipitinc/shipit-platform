# Repository Learning: a guardrail that fails OPEN on the class it never sees

**Feature**: IMPL-B6-CORRECTION-FINDINGS (correcting the review-repair guardrail)
**Date**: 2026-10-15
**HEAD**: see `git rev-parse HEAD` on `fix/unstick-unreviewable`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic
authority. The framework-candidate half is flagged in the last section and NOT persisted here.

---

## Summary

`readReviewVerdictProvenance` opened with a decision-type check that returned
`ReviewAssessment.noReviewerOutput` for any decision that was not an
`engineering_review`:

```dart
if (decision.decisionType != HumanDecisionType.engineeringReview) {
  return ReviewVerdictProvenance(
    assessment: ReviewAssessment.noReviewerOutput,
    detail: 'this is not an engineering review decision, so no reviewer verdict '
            'is claimed by it',
  );
}
```

`noReviewerOutput` is the **only** class whose `isRepairable` is true, and the
endpoint had **no independent decision-type guard**. So for **18 of the 19**
`HumanDecisionType` values, a single operator click retired a *pending,
consequential human question* — returned `accepted`, moved the work item
`waiting_for_human_decision -> agent_completed`, and set the decision to
`cancelled`.

The stated reason was true. The conclusion drawn from it was exactly backwards:
"no verdict is claimed" is not "a verdict was fabricated", and that difference is
the entire subject of the repair.

## Why it was LATENT and still HIGH

Latent: both `requestHumanDecision` callers raise `engineering_review`, and every
other blocking type uses a synthetic scope that is not a `work_item` row, so no
non-review decision could reach the method in production as the code stood.

Still HIGH, for two reasons that survive the latency:

1. **It is the one path in the repository that can void a pending human
   decision, and it failed OPEN.** The reader was the *only* defence, and a
   reader is one re-classification away from not being one.
2. **The affordance's own documentation promised a refusal that did not exist** —
   "the server will refuse it" was false for 18 of 19 types. A documented safety
   property that is false is worse than an undocumented one, because it is
   *relied on*: the reader of the doc believes they are protected.

The second reason is the transferable one. A false safety claim in prose is a
defect even when the code path is unreachable today.

## The shape of the mistake: two readings of one absence

The enum had four arms and they were all statements about *a reviewer's output*:

| arm | statement |
|---|---|
| `assessed` | a reviewer produced a verdict |
| `noReviewerOutput` | a reviewer produced nothing — **repairable** |
| `reviewerProseOnly` | a reviewer wrote prose but no machine verdict |
| `unreadable` | I could not read the result |

There was **no arm for "there was never a reviewer here"**, so the one case with
no reviewer had to be squeezed into `noReviewerOutput` — the repairable one. The
missing classification was not an oversight at the call site; it was an
overloaded meaning forced by an incomplete closed set.

**Check the closed set before trusting the branch.** If a guard's enum has no arm
for a legitimate input state, that state will be mapped onto whichever arm is
nearest, and "nearest" is a guess.

## Why TWO gates, not one

The fix added both:

1. A new arm `decisionTypeNotReviewable` — not repairable, and **its own arm**
   rather than an overload of `unreadable`, because "I could not check" and "this
   is not the kind of thing I repair" are different statements and the operator
   must be told which one is true.
2. An explicit `decisionType` check at the endpoint, before the provenance read.

They are **independent by construction** — one reads the decision's type, the other
reads the reviewer's durable result — so a future change to the reviewer's result
shape cannot move both. Had both gates shared the reader, "two gates" would have
been one gate counted twice.

Both are ordered, and the endpoint's refusal does not consult the reader at all.
This is defence in depth in the literal sense: **the second gate must be able to
act without the first.** That is what makes it a gate rather than a re-check.

## How to tell a second gate does anything (test technique)

Both gates produce the same outcome string, so asserting only the outcome proves
nothing — the test would pass with *either* gate removed. Each gate therefore has
a test that distinguishes them by **its own sentence**:

* the endpoint guard's detail starts `"this work item is parked behind a ..."`
* the reader's detail starts `"this is a ... decision, not an engineering review"`

Verified by temporarily disabling each gate in turn:

| gate disabled | tests that fail |
|---|---|
| endpoint guard only | `it REFUSES a non-review decision BEFORE reading any reviewer result` |
| reader arm only | `a non-review decision type is not repairable, and is refused at BOTH gates` |

The refusal tests assert a **byte-identical before/after snapshot** of item,
decision and history. The snapshot is the point: a refusal that returns the right
word while having written something is not a refusal.

## Framework candidate (NOT persisted here)

> A safety guard whose only defence is a classification should be checked for
> **fail-open behaviour on every value of the classification's input domain**, not
> only the one the caller currently produces. Enumerate the input domain
> (`HumanDecisionType.values`) and assert a refusal for the unrepresented cases —
> here, 18 of 19, none of which production could reach.

Authority: `WORKFLOW_IMPROVEMENT`. Handed to the Manager for independent review.
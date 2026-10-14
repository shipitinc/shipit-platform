# Repository Learning: the inflow's commit branch cannot route, so `sched-review` is the only path to a reviewer

**Feature**: IMPL-A9-REVIEW-DEDUPE-DISCRIMINATOR
**Date**: 2026-10-14
**HEAD**: recorded at `c991e64`; corrected against `fbddacc` (blocker raised by `implementer`, IMPL-A9-CORRECTION-1)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

`completionRouteFor(CommitProduced())` returns `WorkItemState.reviewInProgress`
(`packages/scheduler/lib/src/implementation_inflow.dart`), and
`_routeOneCompletion` (`packages/scheduler/lib/src/scheduler.dart`) acts on it:
the item is at `agentCompleted`, a commit exists, so it calls `engine.transition(to: reviewInProgress)`.

**That transition is always refused.** The `agentCompleted -> reviewInProgress`
edge carries `GuardConditions.agentResultValid()`, which needs the implementer's
completed `AgentResult` under `context['agentResult']`, and the inflow's own
call passes only `const {'agentAvailable': true, 'capabilitiesMatch': true}`
(`scheduler.dart`, the `transition(` in `_routeOneCompletion`). The call site is
documented as skipping the policy probe precisely because the scheduler has no
execution of its own to supply that result.

So the inflow's commit branch never moves anything. Every commit-producing item
lands at `agent_completed` and reaches a reviewer **only** through
`sched-review`, whose `entryStates` is that state. The inflow's real effect is
`NoCommitProduced -> implementationReady` and nothing else.

## Executable knowledge

| What is true | Where it is true, mechanically |
|---|---|
| A commit-producing item with NO `triageAttempt` still ends at `agentCompleted` and IS dispatched to a reviewer — i.e. the inflow did not route it | `apps/server/test/implementation_inflow_tick_order_test.dart`, "an item whose producer DID commit is left to review in both orders" — it asserts `agentCompleted` **and** a reviewer request at the produced revision, with `triageAttempt` absent so the `maxImplementationInflows` stand-down cannot be what left it there |
| The review key is therefore load-bearing for the whole review path, not one lane of several | `apps/server/test/engineering_review_rereview_test.dart` (added at the HEAD above) |
| One unreadable `triageAttempt` costs ONE item, not the review lane | `packages/scheduler/test/engineering_review_dedupe_key_test.dart`, "one UNREADABLE marker costs one item, not the review lane" — corrupt item first, healthy item second on the same tick |
| The same thing, through the real composition, with the real resolver and the real missing-artifact handler | `apps/server/test/implementation_inflow_tick_order_test.dart`, "an unreadable producer is refused fail-closed, and the lane survives it" |

## Why this was not obvious, and why it was worth writing down

`implement_feature.dart` states the design as "the producer left a commit →
`reviewInProgress`, and this lane does not touch it. That is `sched-review`'s
item and it is already dispatched." The first half is unreachable, so the
sentence reads as a guarantee that two lanes divide the work when in fact one
lane does all of it.

The consequence for operators: with the unsuffixed `engineering_review` dedupe
key, **no** commit-producing item could ever be reviewed — the key was consumed
by the first review and nothing could mint another. The five items stranded at
`agent_completed` on 2026-10-14 are that, and no other lane could have covered
for them.

**Stated as a blast radius, because that is what it was.** A key builder in one
lane is normally a per-item degradation: one item cannot be scheduled, the rest
of the lane carries on. This one was a **single point of failure for the whole
review path**. Nothing stood between "the second review of this item" and "no
item in the platform is ever reviewed again": the inflow's commit branch cannot
route, so `sched-review`'s `entryStates` is the only door, and the consumed key
was the only key behind it. A reviewer reading the code as one-lane-among-many
would not have predicted that, which is exactly why the fact belongs here.

## The same builder was a single point of FAILURE too (found by the correction)

The mechanism above is about the key. The correction found the same function
being a second single point of failure, of a different kind.

`engineeringReviewDedupeKey` calls `DurableWorkflowEngine.readTriageAttempt`,
which throws `FormatException` **by design** on a present-but-unreadable
`triageAttempt` (falling back would reuse a key the previous attempt already
consumed). The throw was correct. Its blast radius was not: `tick()` called the
builder from the runnable branch of its per-item loop with **no per-item guard**,
so one corrupt marker on one work item propagated a `FormatException` out of
`tick()`, into `server.dart`'s `catch`, and was logged as `review.tick.failed` —
the ordinary retry-noise line the composition root already expects.

What that cost, every tick, for ever:

- The **whole tick result** was lost — `enqueued`, `dispatched` and
  `blockedArtifactMissing` alike — so every *other* reviewable item starved too.
  This is worse than a stuck item: a stuck item is visible.
- The throw happened **before** `blockedArtifactMissing` was populated, so the
  fail-closed human gate never ran either. The platform's answer to "I cannot
  tell whether this artifact is good" was never reached.
- Because `sched-review` is the only path to a reviewer (above), "the review
  tick" and "the review path" are the same lane. The failure was total, and it
  was reported as a transient.

The same reader and the same unbounded shape already had a HIGH for it on the
implementation lane, fixed by `_routeOneCompletion`'s per-item guard. The review
path never got one.

**What the correction did**, in the layer where the scheduler owns the cost: the
dedupe-key build is now inside a per-item `try` in `tick()`. That one site
covers every wired builder that decodes durable bytes — `triageDefectDedupeKey`,
`implementFeatureDedupeKey` and `engineeringReviewDedupeKey` — so the defect
class is closed at the loop rather than in three functions.

**What it costs, stated rather than hidden.** The refusal is reported on
`SchedulerTickResult.entryHopRefused`, because `blockedArtifactMissing` carries
**job ids** and a refused item has none: no key, no job, nothing for the
composition root's `engineeringReviewMissingArtifact` loop to read. So for such
an item **no blocking human decision is raised** — it parks itself at its entry
state and the same refusal is re-reported every tick until a human repairs the
marker. That is fail-closed for the item and correct for the lane, and it is
still not the same as a human being asked. Closing that last gap needs a channel
wired in `apps/server/lib` (`server.dart` reads neither `entryHopRefused` nor
`completionInflow` today), which is a separate change with a separate owner.

## Follow-ups NOT taken here (they need their own reviewed change)

- `_routeOneCompletion` catches `WorkflowTransitionRejectedException` and reports
  `the item moved while this lane was reading it`. Nothing moved: a guard
  refused. That reason string is shown to an operator through
  `CompletionInflowMove.reason` and misstates the cause.
- `completionRouteFor`'s `CommitProduced` arm and the comment above it describe a
  route that cannot be taken. Either the transition should carry the producer's
  `AgentResult`, or the arm should be removed and the doc corrected — that is a
  design decision, not an edit.
- Nothing in `server.dart` reads `entryHopRefused` or `completionInflow`, so a
  per-item refusal is visible in a tick result and in tests but reaches no log
  line. Closing that means deciding what an operator should DO about a refused
  item, which is a product decision.
- A review-attempt counter would let the second exhausted review mint a fresh
  key, which the shared `triageAttempt` cannot do. It needs a reader/writer pair
  beside `nextTriageAttempt` in `packages/workflow_store` — read-only to this
  lane.
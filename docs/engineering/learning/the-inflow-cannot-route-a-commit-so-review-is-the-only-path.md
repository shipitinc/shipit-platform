# Repository Learning: the inflow's commit branch cannot route, so `sched-review` is the only path to a reviewer

**Feature**: IMPL-A9-REVIEW-DEDUPE-DISCRIMINATOR
**Date**: 2026-10-14
**HEAD**: `c991e6472831727d47f524e1cb781b495686015d`
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

## Follow-ups NOT taken here (they need their own reviewed change)

- `_routeOneCompletion` catches `WorkflowTransitionRejectedException` and reports
  `the item moved while this lane was reading it`. Nothing moved: a guard
  refused. That reason string is shown to an operator through
  `CompletionInflowMove.reason` and misstates the cause.
- `completionRouteFor`'s `CommitProduced` arm and the comment above it describe a
  route that cannot be taken. Either the transition should carry the producer's
  `AgentResult`, or the arm should be removed and the doc corrected — that is a
  design decision, not an edit.
# Repository Learning: the executor cancelled itself to settle a timeout

**Feature**: IMPL-B2-BUDGETS-AND-DURATION (B-1, reviewer retry)
**Date**: 2026-10-14
**HEAD**: `fix/budgets-and-duration`, base `45e6578`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

`ExecutionCoordinator._expireExecution` asked the live session to stop **before** it
detached that session from the coordinator's terminal contract. Cancelling makes an
`AgentSession` emit `SessionCancelled`, and that event travels straight back into the
same contract `_finalize` was awaiting — so **which of the two writes won the race
decided the execution's terminal status**, and the loser overwrote it.

The observable consequence was non-determinism in exactly the wrong place: a run that
hit its budget settled as `interrupted` sometimes and as `cancelled` other times.
`cancelled` classifies as `JobFailureKind.cancelled` — **not retryable**. A budget
expiry that cannot retry is a coin toss, and the toss decided the review's fate.

The fix is ordering, not a guard: detach the bookkeeping first, then cancel. The agent
process is still asked to stop; what changes is that a cancellation the platform
requested for itself can no longer become the platform's verdict about the run.

---

## The finding

```dart
// before
await _stopSessionQuietly(id, '…exceeded its budget');   // ← emits SessionCancelled
return _settleWithoutSession(…, status: interrupted);      // ← the real verdict
```

`_onSessionEvent` completes `_terminalContracts[id]` for any of the four terminal
events, including `SessionCancelled`. `_finalize` was still awaiting that contract. So:

- cancel wins → `_completeFailure` writes `cancelled` → `WorkerExecutionStatus.cancelled`
- `_expireExecution` wins → writes `interrupted` → `timedOut` → transient

Both then raced again in `_settleWithoutSession`, which re-reads and unconditionally
overwrites the row. The test that caught it flapped between
`JobState.retryWaiting` and `JobState.cancelled` on identical input.

This was found while proving B-1 — "a timeout retries, a crash does not" — and only
because that proof runs the *whole* chain with a 1-second budget. Reading either
seam alone would not have shown it: both seams were individually correct.

---

## Executable knowledge

| What is true | Where it is true, mechanically |
|---|---|
| A budget expiry settles `interrupted`, never `cancelled` | `packages/execution_coordinator/test/budget_expiry_is_a_timeout_test.dart` |
| A crash still settles `failed`, and the two never share a status | same file, `a CRASH still settles as failed` |
| The terminal event names the budget, not just "failed" | same file, `the durable row, not just the returned value` |
| The late drive path still cannot resurrect the row | `packages/execution_coordinator/test/timeout_resurrection_test.dart` |
| `interrupted` → `timedOut`, `failed` → `executedFail`, exactly | `packages/worker_runtime/test/interrupted_is_a_timeout_test.dart` |
| A timeout spends an attempt; a crash spends none | `apps/server/test/scheduler_retry_dispatches_again_test.dart` |
| The whole chain, end to end, through a real `LocalWorker` | `apps/server/test/budget_exhaustion_retries_test.dart` |

---

## The generalisable shape

**A platform that terminates something on its own initiative must not let that
initiative arrive as an outcome.** `SessionCancelled`, `SessionFailed` and
`SessionInterrupted` all mean "something reported an ending"; the coordinator's
timeout is the platform deciding, and it has to say so in the state it writes rather
than delegating the wording to the agent transport.

This is a product fact here. It is also, I think, a reusable one — but that call is
for independent review, not for a lane that is reporting it.

**Related:** [[a-retry-the-scheduler-cannot-reach-is-not-a-retry]].
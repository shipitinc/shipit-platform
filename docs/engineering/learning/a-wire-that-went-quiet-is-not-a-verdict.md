# Repository Learning: a wire that went quiet is not a verdict the agent returned

**Feature**: IMPL-B7-ACP-TIMEOUT
**Date**: 2026-10-15
**HEAD**: `fix/acp-transport-timeout` (see the lane's structured result for the SHA)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.
Companion: `a-number-between-the-budget-and-the-work.md` (the timeout half of the same lane).

---

## Summary

An `AcpTransportException` says the ACP process stopped answering the wire. It is **not** an
assessment, and nothing about the code under review was learned from it. It was classified as
`SessionFailed`, which settled `failed` → `executedFail` → `JobFailureKind.permanent` → the job died
**having spent zero attempts**, with its work item left at `review_in_progress` and no blocking
decision.

That is the same class of error as fabricating a review verdict: it asserts something the system does
not know, in the one field an operator reads to decide whether to believe the agent.

Durable evidence from the live incident (QA, read-only):

```
agent_execution   failed      "AcpTransportException: ACP request timed out: session/prompt"
worker_execution  executedFail / agentFailed
job               failed      attempt 1 of 2   kind=permanent   reason="agent session failed"
work_item         review_in_progress   (stranded)
```

`"agent session failed"` is what an operator is shown, and nothing about it is true.

---

## What is true, and where it is true mechanically

| What is true | Where it is true, mechanically |
|---|---|
| A transport exception settles `interrupted`; a JSON-RPC error object settles `failed` | `packages/agent_runtime/test/opencode_transport_failure_classification_test.dart` |
| A dead child produces EXACTLY ONE terminal event, not two | same file, "a dead child reports EXACTLY ONE terminal event" |
| The result records `runtimeAnswered: false` and an `interruptedBecause` diagnostic | same file, "the result says the runtime never answered" |
| `AcpRequestException` has exactly one construction site, inside the received-error branch | `packages/agent_runtime/test/agent_session_budget_bounds_test.dart` |
| A start that fails on the wire settles `interrupted`; a start that crashes settles `failed` | `packages/execution_coordinator/test/transport_failure_is_retryable_test.dart` |
| `interrupted` maps to `timedOut` and `failed` to `executedFail` at the worker seam | `packages/worker_runtime/test/interrupted_is_a_timeout_test.dart` (pre-existing; needed no change) |
| End to end through the real `Scheduler`: a transport timeout spends an attempt, re-dispatches, and is bounded at exactly N=2 executions | `apps/server/test/budget_exhaustion_retries_test.dart` |
| …and a crash still spends nothing and is never re-dispatched | same file, "a transport timeout does NOT make the agent's own failure retryable" |

---

## The finding: the boundary is structural, not a heuristic

There are exactly two failure shapes on this path and they are told apart by **which side raised
them**. Neither requires reading a message:

| Raised by | Type | Meaning | Classification |
|---|---|---|---|
| the runtime, over the wire | `AcpRequestException` | a JSON-RPC `error` object the runtime SENT | `SessionFailed` → `failed` → **permanent**, 0 attempts |
| this process | `AcpTransportException` | not open / closed / child exited / request timed out | `SessionInterrupted` → `interrupted` → **transient**, 1 attempt |

`AcpRequestException` is constructed in exactly one place — `OpenCodeProcessTransport._onLine`, from a
received `error` object. `AcpTransportException` is constructed only by the local transport. Both
properties are pinned by source-level assertions in `agent_session_budget_bounds_test.dart`,
including the negative one: if a second `AcpRequestException(` construction site ever appears, the
distinction becomes a guess and the retryable classification beneath it is unfounded.

Two call sites in `ExecutionCoordinator._drive` were changed to match, and the mechanism is the three
catch clauses themselves, written out so a reviewer does not go looking for a guard inside the shared
method (there is none, and there must not be one — that would be exactly where a later change relaxes
it):

```text
on TimeoutException        -> interrupted   (transient)
on AcpTransportException   -> interrupted   (transient)   <- added by this lane
catch (e)                 -> failed        (permanent)   <- crashes, StateError, ProcessException
```

A missing `opencode` binary raises `ProcessException`, not `AcpTransportException`, and stays
permanent: it fails identically on every attempt, so retrying it spends the retry budget on a
certainty.

## A crash became retryable too, and that is bounded

A child that dies mid-prompt is a wire that went quiet, so it now retries. The bound is `maxAttempts`
at the scheduler, and it was measured rather than argued: two ticks after the retry budget is spent
the review lane still has **exactly two executions**, never three
(`budget_exhaustion_retries_test.dart`, "the retry RE-DISPATCHES, and maxAttempts bounds it at
exactly N").

`OpenCodeSession` also gained a `_settled` guard while making this change, because a crashed child
produces **two** signals for one failure — `_handleChildExit` completes the outstanding request with an
`AcpTransportException` *and* emits a `transport/closed` notification. Both reached the failure
handler, so the coordinator was handed two terminal events for a single interruption and the durable
outcome depended on which arrived first.

---

## Two pre-existing defects measured while proving the bound above

Neither is introduced by this lane and neither is in code this lane owns; both are reported to the
Manager rather than fixed here.

### 1. A review that exhausts its retry budget leaves a non-terminal job

Measured on the real `Scheduler` → `LocalWorker` → `ExecutionCoordinator` chain, one tick at a time:

```
tick 1: dispatched=1  job=retryWaiting  attempt=2/2  kind=transient  executions=1  item=review_in_progress
tick 2: dispatched=1  job=queued        attempt=2/2  kind=transient  executions=2  item=agent_completed
tick 3: dispatched=1  job=queued        attempt=2/2  kind=transient  executions=2  item=agent_completed
tick 4: dispatched=1  job=queued        attempt=2/2  kind=transient  executions=2  item=agent_completed
```

**The bound is real where it matters** — agent executions, and therefore model spend, stop at N=2. But
the job row does not complete terminally `failed` as `Scheduler._adopt`'s own doc comment states; it
sits at `queued` and is re-offered every tick without ever running. So a review that burns its retry
budget leaves an operator with a non-terminal job and no blocking decision — the same shape as the
live incident this lane fixes.

This is not new: `ReviewScript.hang`, the budget-expiry path that has been retryable since decision
`3659984d`, produces the byte-identical sequence on the same host at the same clock. The relevant
calls are in `packages/scheduler` (`Scheduler._adopt` → `RetryPolicy.canRetry`), which this lane does
not own.

### 2. The durable REASON for a budget expiry (resolved)

The coin flip is **gone**. Both producers use a single source of truth:

- **Canonical reason:** `execution exceeded its ${budget.inSeconds}s timeout budget without reaching a terminal agent event; session never emitted a terminal event within the ${budget.inSeconds}s execution budget`
- **Sole source:** `packages/execution_coordinator/lib/src/coordinator/execution_coordinator.dart::_budgetExpiryReason(Duration budget)` is used by both `_expireExecution` (outer budget expiry path) and `_neverEmittedTerminalEvent` (inner terminal-wait timeout in `_finalize`). Both `budget_expiry_is_a_timeout_test.dart` assertions (`never emitted a terminal event` at :174, `execution budget` at :194) and `execution_timeout_test.dart` assertions (`never emitted a terminal event` at :121, `timeout budget` at :163) are satisfied by the same canonical string.
- **Honest in all cases:** the wording describes exceeding the budget without a terminal agent event and that no terminal event was emitted; it does not presuppose a session existed, so it is true when `session == null` (e.g. start never came up) and when a session existed but never emitted a terminal event.
- **Not duplicated:** the canonical reason is not repeated twice; it contains both required phrases once.
- **Cancel hint:** `_expireExecution` still passes a shorter reason (`'execution exceeded its ${budget.inSeconds}s budget'`) to `session.cancel(...)` only as a stop hint; the subscription is detached before cancel so no `SessionCancelled` event is appended and this string is **not** persisted as the durable reason (documented with an inline comment).
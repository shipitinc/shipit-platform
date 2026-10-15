# Repository Learning: a number between the budget and the work is the defect, not the budget

**Feature**: IMPL-B7-ACP-TIMEOUT
**Date**: 2026-10-15
**HEAD**: `fix/acp-transport-timeout` (see the lane's structured result for the SHA)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.
Companion: `a-wire-that-went-quiet-is-not-a-verdict.md` (the classification half of the same lane).

---

## Summary

Three times now this platform has killed its own agent runs with a typed-in duration that nobody
measured, and each time the number sat **one layer below the budget that was supposed to govern it**:

| Date | Number | Where | Ceiling it really imposed |
|---|---|---|---|
| 2026-10-13 | `300` | `engineering_review_gate.dart` | the review budget, on a task that takes 15–30 minutes |
| 2026-10-14 | `timeoutSeconds * 4 + claimLease` | `Scheduler.zombieStalenessBound` default | how long a dead execution holds a claim, ×4 the budget |
| 2026-10-15 | `Duration(minutes: 5)` | `OpenCodeProcessTransport.requestTimeout` default | **every ACP request on the wire**, `session/prompt` included |

The 300s one was reported first and fixed first, and the fix shipped a review budget of 3h. Two
engineering reviews then died at 308s and 350s with

```
reason: AcpTransportException: ACP request timed out: session/prompt
```

because the budget had been repaired and the *next* number down was untouched. The durable rows for
that incident (QA, read-only, `shipit` database):

```
agent_execution   agx-wx-jb-hn8k1nc7pa-ul85i2   failed    "AcpTransportException: ACP request timed out: session/prompt"
worker_execution  wx-jb-hn8k1nc7pa-ul85i2       executedFail / agentFailed
job               jb-hn8k1nc7pa-ul85i2          failed    attempt 1 of 2, kind=permanent, "agent session failed"
work_item         defect-DEF-1791686357139031   review_in_progress   (stranded, no decision)
```

Read together, those four rows say the whole thing: a 3-hour budget, a 5-minute ceiling, zero attempts
spent, and an operator left with a work item that will never move again.

---

## What is true, and where it is true mechanically

| What is true | Where it is true, mechanically |
|---|---|
| A `session/prompt` occupying most of its budget is NOT cut short, over a real child process and a real clock | `packages/agent_runtime/test/opencode_request_timeout_test.dart` |
| A wire bound *shorter* than the prompt DOES kill it — the non-vacuity control | same file, "a wire bound SHORTER than the prompt kills it — this is the bug" |
| A wire bound *longer* than the budget changes nothing, and therefore cannot be a wedged-process guard | same file, "a wire bound LONGER than the budget changes nothing" |
| A silent runtime is still ended, at the budget | same file, "a prompt the runtime never answers is still ended, at the budget" |
| There is no bare duration bound left anywhere in `agent_runtime`, and `defaultAcpTransport` forwards the caller's budget rather than inventing one | `packages/agent_runtime/test/agent_session_budget_bounds_test.dart` |
| `AgentSessionConfig.timeout` is `required`, so a caller that forgets one fails to compile | same file, "the session config REQUIRES a timeout" |
| A health probe states which named bound it runs under | same file, "no adapter inlines its own probe budget" |
| A start that fails on the wire settles `interrupted`; a start that crashes settles `failed` | `packages/execution_coordinator/test/transport_failure_is_retryable_test.dart` |

---

## The finding: the layering, and why ONE bound is correct here

There are three timers, and the argument is about which of them can actually fire.

```text
ExecutionCoordinator.execute      budget, clock starts FIRST   <- ends the execution, cancels the session
  └─ ExecutionCoordinator._drive budget, same instant
       └─ OpenCodeSession         budget, per phase           <- TimeoutException -> SessionInterrupted
            └─ OpenCodeProcessTransport  budget, per request  <- AcpTransportException
```

The transport's original doc comment asserted an intent that was the exact inverse of the code:

> "A wedged runtime process must not hold the executor hostage for the transport's whole lifetime;
> the session layer applies an even tighter bound around the prompt itself."

The author assumed the session layer would be tighter. It was not: the session layer carried the role
budget (three hours for a review) and the transport default was five minutes, so **the transport was
the tightest bound in the system and the only one that ever fired**.

The argument for deleting the independent bound rather than re-tuning it is that **no value works**:

* **Below the budget it is a ceiling on legitimate work, not a wedged-process guard.** `session/prompt`
  *is* the work. A wedged process costs a budget; a healthy agent killed at five minutes costs a
  review. The protection that was actually bought was a kill-switch aimed at healthy agents.
* **At or above the budget it is unreachable.** The only timer that ends a wedged runtime is the
  coordinator's, and its clock starts *before* the session exists. Its deadline is therefore always
  strictly earlier than any bound applied inside the session, whatever that bound says.

So the wedged-process protection never lived in this field. What actually ends a wedged process, and
is unaffected by the change:

1. `ExecutionCoordinator._expireExecution` — the budget fires, the session is cancelled inside a 5s
   grace, and `OpenCodeSession.cancel` calls `transport.close()`.
2. `transport.close()` — `SIGTERM`, then `SIGKILL` after five seconds.
3. The session's own per-phase `.timeout(_timeout)`, which is now the budget instead of being
   undercut by five minutes.

The transport parameter is kept, as `Duration? requestTimeout` with **no default**, and
`defaultAcpTransport` passes `config.timeout` — so the bound on the wire is the budget, a pass-through
rather than a re-derived multiple. A caller that genuinely wants an independent wire bound passes one
deliberately; a bound nobody chose is a bound nobody reasoned about.

## Two other five-minute literals, dealt with the same way

* `AgentSessionConfig.timeout` defaulted to `const Duration(minutes: 5)`. It is now **`required`**.
  An optional parameter is a value in the file, and a caller that forgets it got five minutes and no
  error. Every construction site in the repository lives inside this lane's owned paths, so the change
  is contained; a caller outside them would now fail to compile, which is the correct outcome.
* `OpenCodeSession._timeout` defaulted to `const Duration(minutes: 5)`. It is now
  `late final Duration _timeout;` — unreachable through `start()` and therefore harmless, but a
  field initialised to a budget is still a budget-shaped number that the next reader has to work out
  whether it is live.
* A **new** number exists and is named: `healthProbeTimeout` (30s), used by the three adapters'
  `checkHealth`. This is not a second wire bound — a health probe asks `initialize` and nothing else,
  which is a different question from "how long may a review take" — but it is still a guess, so it
  carries `PROVISIONAL`, states that **NO OPERATOR-STATED RANGE EXISTS** for it, and is pinned by
  `agent_session_budget_bounds_test.dart` together with an assertion that no adapter inlines its own.

## The method, which is the reusable part

`packages/agent_runtime/test/opencode_request_timeout_test.dart` proves the BEHAVIOUR over a real
POSIX-sh ACP loopback and a real clock, at ~6000× reduced scale. It cannot prove that nobody has put a
literal back, and the reason is arithmetic rather than effort: **distinguishing a five-minute bound
from a three-hour budget requires a budget above five minutes, i.e. a test longer than five minutes.**
Verified, not assumed — with the bound reset to `const Duration(minutes: 5)` that file stays green at
its 6-second budget.

So the literal is pinned where provenance is observable, in the source, with negative assertions and
comments stripped so that the doc comment *explaining* the defect does not trip it. Measured
non-vacuity: restoring the exact `1e64578` shape (class default `Duration(minutes: 5)` + the factory
forwarding nothing) turns three assertions in `agent_session_budget_bounds_test.dart` red; and
tightening the factory's forwarded bound below the budget turns the behavioural test red.

That split — behaviour in one file, provenance in another — is the same one
`apps/server/test/agent_execution_budgets_test.dart` already uses for the 300-second budget, and it is
the general rule: **a value's provenance is not observable at runtime, so provenance has to be
asserted at the source level, where it is written.**
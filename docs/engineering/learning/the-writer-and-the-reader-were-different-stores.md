# Repository Learning: the writer and the reader were different stores

**Feature**: IMPL-A7-EXECUTION-STORE-ROOT-CAUSE (HD-7)
**Date**: 2026-10-14
**HEAD**: `fix/execution-store-root-cause` on `db36018`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

The execution coordinator **wrote** every agent execution into
`FileJsonExecutionStore` at `${Directory.systemTemp}/execution_coordinator/store.json`.
Every **reader** of an agent execution read PostgreSQL. The two never met.

Measured on the QA database after 35 worker executions:

```
agent_execution = 0    worker_execution = 35    model_execution_record = 29
agent_result    = 0    agent_event     = 0
```

`PostgresExecutionStore` existed, implemented every method against real SQL, and
was already wired into `ControlPlaneService.executionStore`. Nothing was wrong
with it. **Nothing wrote to it**, because nothing was routed to it.

## The executable form exists and will not go stale

| What is true | Where it is true, mechanically |
|---|---|
| The exact store the composition attaches, named as a seam | `agentExecutionStore(db)` in `apps/server/lib/server.dart` |
| A real producer run writes `agent_execution` rows where readers look | `apps/server/test/integration/execution_store_roundtrip_test.dart` |
| The anchor the discriminator resolves is minted by production code | same file, "the anchor … is minted by production code, not by this test" |
| A producer with an artifact discriminates as committed; one without does not | same file, both cases |
| The fail-closed park is reachable only once the store is readable | same file + `test/execution_store_wiring_test.dart` |
| The stand-down decides WITHOUT reading the execution store | `test/execution_store_wiring_test.dart`, `_ExplodingExecutionStore` |
| `saveRequest` must not write a null `createdAt` | `PostgresExecutionStore` class doc; exercised by the round-trip suite |

## The finding that matters most: it was NOT a discriminator bug

The task that commissioned this work asserted the discriminator chain "spans
BOTH tables" — that `producedCommitFor` resolves an `agx-…` agent execution id
and so needs the agent execution store. **That is false, and it is false in the
direction that matters.**

`producedCommitFor` reads `worker_execution` and the work item's metadata. It
never touches the agent execution store. The anchor resolves *inside*
`worker_execution`:

1. `LocalWorker._agentRequest` mints `agx-${request.workerExecutionId}` —
   a derivation **of the worker execution id itself** — and passes it to the
   coordinator as `request.executionId`.
2. `LocalWorker` records that same id on the worker execution row.
3. `ExecutionCoordinator._complete` sets `stamped.executionId =
   request.executionId` and `_completeSuccess` stamps it onto the work item as
   `producerActorId`.

Both ends of the join are columns of the same table family. Verified against live
data: all 10 producers carrying a `producerActorId` joined to **exactly one**
worker execution each, and **every one** resolved to `noCommitProduced` (triage
shape: `endingRevision == requestedStartingRevision`).

**Consequence:** the OD-10 completion inflow was never working "by accident", and
the dedupe-key repair could not have been its cause. It works because the
discriminator reads a table that has *always* been populated. Swapping the
execution store changes **no** discriminator verdict.

## What the store actually broke

The review gate, in the two branches that matter:

- `engineeringReviewTickHandler` — `readExecutionOrNull(reviewerId)` returned
  `null`, logged `engineering-review-gate-execution-not-terminal` with
  `statusName: 'null'`, and returned. **The review verdict could never be read
  or raised.**
- `engineeringReviewMissingArtifact` — `latestExecutionForWorkItem` returned
  `null`, logged `…-no-implementer-result`, and **returned without transitioning
  or raising anything**. Not an error: a silent no-op, on every tick, for ever.

Note the shape: the stand-down sits *before* the execution-store read. So the park
was unreachable for the no-artifact producers (correctly — the inflow owns them)
*and* for the artifact producers (incorrectly). The mechanism designed to stop
stranding a work item never once acted.

## Why it stayed invisible for the entire project

`ExecutionStore` is an interface and both implementations satisfy it, so nothing
about the type system, and no type-level assertion, could say anything. The
production seam was an inline constructor argument, so the wiring itself was not
reachable from any test. Two "assert the right class is constructed" tests had
already been written in this project and were, correctly, dismissed as worthless —
they would have passed against the file store too.

The rule this yields: **an interface with two implementations, one of them a
side-effecting file, makes the CHOICE of implementation the thing under test.**
The choice needs a named seam and a behavioural assertion, not a type assertion.

## A latent defect the fix exposed, which would have taken dispatch down

`agent_execution_request."createdAt"` is `NOT NULL`. `AgentExecutionRequest.createdAt`
is a `DateTime?`, and `LocalWorker._agentRequest` never sets it. So wiring
`PostgresExecutionStore` into the coordinator made `saveRequest` — **the first
write every agent execution makes** — fail:

```
null value in column "createdAt" of relation "agent_execution_request"
violates not-null constraint
```

Every agent execution would have failed before a session was ever started, while
every health probe still reported green. Repaired at the store (the layer that
owns the schema), as a default that never overrides a value the caller supplied.

The whole table was audited for the same class afterwards: `agent_result.completedAt`,
`agent_event.occurredAt` and `platform_verification.capturedAt` are `NOT NULL`
with **non-nullable** model fields, and `agent_execution.startedAt`/`completedAt`
are `NOT NULL`-free. `agent_execution_request.createdAt` was the only mismatch.

## The 35 orphaned file-store executions: DISCARDED, deliberately

Not migrated. Justification is what the READERS do with a row, not convenience:

- **No reader could use them.** All 10 producers resolve to `noCommitProduced`, so
  the stand-down returns before the execution store is ever read; items already
  past `agent_completed` take the `unexpected-state` branch. A migration would
  write rows no code path reads.
- **It would manufacture the evidence a guard exists to refuse.**
  `agentResultValid()` exists to reject a fabricated or unverified agent result.
  Backfilling `agent_result` rows from a non-system-of-record JSON file in
  container temp asserts exactly that, as durable fact, from something no other
  component can corroborate.
- **Nothing of value is lost.** The 5 reviewer executions were all
  `executedFail` with a null `endingRevision` — no verdict was ever produced. All
  5 `engineering_review` decisions already in `database` are `resolved`. The facts
  the discriminator actually needs (starting revision, ending revision,
  capabilities, anchor) are already durably and completely in `worker_execution`.

## Does swapping the store change the tick-order outcome? NO.

Asked explicitly, because `the-tick-order-was-the-decision.md` predicted it would.

The both-orders outcome is decided entirely by
`_implementationInflowOwns(item, workerStore)` — which reads the **worker** store
and the work item metadata, and is evaluated **before** the execution store is
read. It is bit-identical before and after the fix. This is asserted, not
asserted-about: `test/execution_store_wiring_test.dart` runs the real
`engineeringReviewMissingArtifact` against an `ExecutionStore` whose every method
throws, and requires `store.touched` to be empty. Any future change that makes the
stand-down consult the execution store fails that test.

The park becomes reachable in exactly two cases, and neither is a race:

- the producer **did** commit (the inflow does not own it), or
- the re-work bound is spent (the inflow will not route it either).

In both, the inflow has already declined the item, so review parking it is the
designed outcome. The A5 author's warning — the park "lost the moment the
platform started recording executions" — was correct as a diagnosis and is now
safe as an outcome, precisely because the stand-down exists.

## Framework candidate — NOT persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` requires independent review.*

**A writer and a reader that satisfy the same interface are not thereby
connected.** Where a component writes through an interface and another reads it,
the binding is the *construction*, and the construction is the thing that rots
silently. Cheap guard: name the construction, and assert an observable *effect*
through it (a row the reader can find) rather than the type it returned.

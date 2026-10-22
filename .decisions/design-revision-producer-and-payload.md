# Design revision producer: terminal-job consumer, owns contract submission, fixed payload keys

- **decision_id:** `d5e8a144`
- **decided:** 2026-10-22
- **decided_by:** human (structured question UI)
- **settles:** two gaps in design-governance step 6 that the design assigns to no step
- **follows:** design `design/design-governance-runtime/design-revision.md` §3.1/§3.2; decision D4

## Decision 1 — the producer is a terminal-job consumer and OWNS contract submission

A design execution completes at `agentCompleted`; there is no `agentExecuting -> designInReview` edge.
`agentCompleted -> designInReview` is guarded by `designContractUnderReview()`, and nothing in production
moves a design contract `draft -> underReview`.

So the step-6 producer:
- runs as a terminal-job consumer from the tick drain (mirroring `TriageProcessor`), when the
  `designRevision` job is terminal and its execution completed;
- requires the item at **`agentCompleted`** (the "at `designRequired`" half of P1 is a dispatch-time
  precondition for step 8, not a completion-time one);
- writes the revision, then **moves the contract `draft -> underReview`** as the act of submitting it for
  review, then advances `agentCompleted -> designInReview`.

**Why the producer owns submission.** Without it the under-review guard refuses every completion, so the
runtime would write revisions it can never review and no `designApproval` would ever be raised — F2's grant
would still never originate. A design step that no actor performs is a gate nothing reaches.

**Conditions.**
- Submission is a real store write with a read-back; a silent no-op is a refusal.
- If the contract is already `underReview`, submission is idempotent (no second write).
- The producer refuses, by name, when P1–P6 fail; it never forces a transition past a guard.
- The producer is inert until step 8 mounts the scheduler.

## Decision 2 — the design agent's `structuredResult` key contract

Accepted keys (arrays/objects, or their JSON-encoded strings):
`designSystemRevision`, `provider`, `penpotFileId`, `penpotPageId`, `boardIds`,
`responsiveTargets`, `statesRepresented`, `artifactRefs`, `reviewExecutionIds`,
`parentRevisionId`, `carriedForwardFromRevisionId`, `reviewScope`.

- `riskTier` is **forced to `high`** per decision D4; it is never read from the agent.
- `designerExecutionId` comes **only** from the execution record, never from the payload.
- Everything passes through `gateDesignRevisionWrite`; a missing/malformed payload is a named refusal, not
  a default.

## Status

Recorded. Implementation is dispatched separately and must be independently reviewed.

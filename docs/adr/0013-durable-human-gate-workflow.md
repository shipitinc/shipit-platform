# ADR 0013: Human Gates Are Durable Workflow States

## Status
Accepted

## Context
Engineering workflows must pause at consequential human decisions and survive
process termination while waiting. Requirements:

- A work item reaching a human gate must be **persisted as a durable state**
  (`waiting_for_human_decision`), not kept as an in-memory conversation.
- **Execution terminates** while waiting: no agent, worker, or scheduler runs
  until the human resolves the decision.
- **Resume without replay**: a fresh process reads persisted state, sees the
  work item still blocked, applies the resolution, and continues the golden
  path from there. No re-execution or re-derivation of prior steps.
- Human consent is durable and auditable: every `HumanDecision` carries
  `decisionId`, `workItemId`, `decisionType`, `decider`, `choice`, `rationale`,
  `timestamp`, and `signature`, and survives restart.
- Rejected transition attempts are recorded, not swallowed, so history is an
  audit log of acceptances *and* rejections.

## Decision
**Durability lives in a new `workflow_store` package; policy stays in the pure
`workflow_engine`.** The `DurableWorkflowEngine` wraps the policy engine and is
the only writer of workflow state:

- **Append-only history.** Every accepted *and* rejected transition is stored
  as a `WorkflowTransitionRecord` (with `TransitionOutcome`, actor, trigger,
  per-guard evaluations, and an optional `idempotencyKey`).
- **Compare-and-swap.** `WorkItem.version` gates every write. Concurrent
  writers get `ConcurrentModificationException` instead of silent last-writer
  wins.
- **Gate entry is idempotent.** `requestHumanDecision` persists a *pending*
  decision, then advances the item into `waiting_for_human_decision`. A crash
  between the two leaves a durable pending decision that resume re-honors.
- **Resolution is idempotent.** `resolveHumanDecision` records the resolved
  decision first, then routes the work item out of the gate via the
  `HumanDecisionRouting` table (the only place a `(decisionType, choice)` maps
  to a target state). Replay after a crash observes an already-resolved
  decision and re-attempts only the unlock.
- **The store interface is PostgreSQL-ready.** `WorkflowStore` is an interface;
  `FileJsonWorkflowStore` (atomic temp-file + rename) is the local durability
  layer. `apps/server` later supplies Serverpod/PostgreSQL stores
  implementing the same interface and reuses `DurableWorkflowEngine` unchanged.

## Persistence Model

```dart
abstract interface class WorkflowStore {
  Future<WorkItem> readWorkItem(String workItemId);
  Future<List<WorkItem>> readAllWorkItems();
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}); // CAS
  Future<HumanDecision> readHumanDecision(String decisionId);
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(String workItemId);
  Future<void> saveHumanDecision(HumanDecision decision);
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(String workItemId);
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(String workItemId, String key);
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record);
}
```

`DurableWorkflowEngine` flow when entering a gate:

```
requestHumanDecision(workItemId, decisionType)
  ─► validate current → waiting_for_human_decision against policy
      (requires a pending blocking decision of the allowed type)
  ─► persist pending HumanDecision            (durable before gate opens)
  ─► persist WorkItem(state=waiting_for_human_decision,
             blockingHumanDecisionId, version+1) via CAS
  ─► append accepted WorkflowTransitionRecord
  ─► EXIT (no execution while waiting)
```

Flow when a human decides (possibly in a later process):

```
resolveHumanDecision(decisionId, choice, decider, ...)
  ─► build resolved HumanDecision (status resolved, signature, timestamp)
  ─► target = HumanDecisionRouting.targetFor(decisionType, choice)
  ─► persist resolved decision                (durable before unlock)
  ─► validate waiting → target against policy (exact (type, choice) pair)
  ─► persist WorkItem(state=target, blocking cleared, version+1) via CAS
  ─► append accepted WorkflowTransitionRecord
```

## Gate Routing
The `HumanDecisionRouting` table maps a resolved decision to its unlocked state:
`design_approval/approve → design_approved`, `design_approval/reject →
design_rejected`, `engineering_review/rework → agent_executing`,
`engineering_review/reject → review_rejected`, `qa_waiver/waive → qa_passed`,
`qa_waiver/reject → agent_executing`, `deployment_approval/approve →
deployed`, `deployment_approval/reject → deployment_failed`,
`human_qa_approval/approve → completed`, `human_qa_approval/reject →
agent_executing`, and `cancel → cancelled`.
A rejected approval carries the item back to a recoverable state
(`agent_executing` for rework, `deployment_failed` for a rejected deployment)
so a disapproval is auditable rework, never a dead end. An unmapped resolution
is recorded but does not move the work item, and guard conditions mirror the
same pairs so a decision can never leak through the wrong exit.

## Consequences

### Positive
- Process termination anywhere while waiting is safe; resume is a read.
- Human decisions are durable, signed, auditable, and immutable once resolved.
- Uses the pure policy engine unchanged — no duplication of transition rules.
- CAS + idempotency keys make retries and concurrent writers safe.
- PostgreSQL migration is an implementation of an existing interface.

### Negative
- Two writes per gate entry/exit (decision + work item) — doubles persistence
  latency at gates (acceptable: gates are rare and human-paced).
- The local `FileJsonWorkflowStore` is single-file; it is not a distributed
  store (never claimed to be; it exists for the executable foundation and
  tests).

### Mitigation
- Persistent decision-write-before-unlock ordering keeps crash recovery
  deterministic; replay re-attempts only the unlock.
- The interface is versioned and unchanged by backend swap; store integration
  tests are deferred to `apps/server/test` per the testing rules.
# A design-producer refusal raises a stalled human decision

- **decision_id:** `e2c7a05b`
- **decided:** 2026-10-22
- **decided_by:** human (structured question UI)
- **settles:** F-222, a precondition for design-governance step 8
- **follows:** `.decisions/design-revision-producer-and-payload.md` (`d5e8a144`)

## Decision

When `DesignRevisionProducer` refuses by name, the drain **raises a `stalledWorkItem` human decision**
through the existing stall/decision machinery, so the item is operator-visible instead of silently parked
with only a log line.

## Why

- A refusal leaves the item at `agentCompleted`, which is not an entry state of `designRevisionDefinition`,
  so nothing re-enqueues. The job is terminal and counted succeeded. Without a decision, a refused design
  revision is indistinguishable from a finished one to every reader except the log.
- The QA and engineering gates already surface dead ends as human decisions; reusing that shape keeps one
  failure vocabulary rather than inventing a second.
- It adds no `WorkItemState` (the enum must stay 28) and no new decision type.

## Conditions

- The decision names the refusal code and the work item, so an operator can act without reading logs.
- Idempotent: re-draining the same refused job must not raise duplicate decisions (use the job/execution
  identity as the dedupe key, consistent with the existing stall gates).
- Raising the decision must not itself force the item past a guard.
- A refusal that happens before a work item can be loaded (malformed job/execution) is logged and does not
  invent an item id.

## Status

Recorded. Implementation is folded into step 8 (mounting the design schedulers) and must be independently
reviewed.

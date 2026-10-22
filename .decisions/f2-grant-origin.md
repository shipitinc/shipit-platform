# The per-lane owned-path grant originates at design/plan time

- **decision_id:** `7d2a81f0`
- **decided:** 2026-10-21
- **decided_by:** human (via structured question UI)
- **gate:** F2 `change-scope-confinement` (manifest `feature-change-scope-confined`)
- **closes review finding:** H-1 on `88cc25a` (ledger F-215)
- **follows:** `.decisions/f2-per-lane-ownership-source.md`, `.decisions/f2-static-forbidden-globs.md`

## Decision

**The grant is recorded at design/plan time** — the work item's planner or designer records the owned globs
when the item is scoped. The grant therefore comes from whoever scoped the work, which is already a
human-governed step.

## Why

- The design/plan artifact already names the paths the work will touch. Nothing is invented; the decision
  makes an existing fact durable and dispatch-readable.
- The requester of an intake form routinely does not know the path layout, so an intake field would be
  guessed or left empty — and empty still refuses, so most items would still queue. A designer is the one
  person in the lifecycle who both knows the layout and is accountable for the scope.
- A per-category default wide enough to cover most work is a default that confines nothing: F2 would become a
  tautology rather than a gate, which is the outcome F2 exists to prevent.

## Conditions attached

- **A designer who under-scopes the work is confined by the under-scope.** That is the gate doing its job,
  and the human already owns the design. Do not add a fallback that widens the grant at dispatch time.
- **The grant is recorded as a durable fact of the work item** and read at dispatch — never reconstructed
  from the diff, and never the work's own claim about what it will touch (per `4e1c9b52`).
- **An item with no recorded grant stays refused.** Fail-closed direction is unchanged; recording the grant
  is additive, and nothing becomes permissive because a grant is now reachable.
- **`c3f81b04`'s static forbidden set continues to apply to every lane** regardless of the grant.

## Status

Recorded. Implementation is dispatched separately and must be independently reviewed.

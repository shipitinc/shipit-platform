# Persist each lane's declared OWNED_PATHS so F2 can be evaluated

- **decision_id:** `4e1c9b52`
- **decided:** 2026-10-21
- **decided_by:** human (via structured question UI)
- **gate:** F2 `change-scope-confinement` (manifest `feature-change-scope-confined`)
- **settles:** the open question decision `c3f81b04` deliberately left to measurement
- **follows:** `.decisions/f2-static-forbidden-globs.md`, `.decisions/qa-workspace-retention-until-evaluation.md`

## Decision

**Persist each lane's declared `OWNED_PATHS` at dispatch time** into the durable record the QA gate reads —
the worker execution / work-item record — so F2 evaluates against what the lane **actually declared**.

## Why it was put to the human

The F2 work measured the answer to `c3f81b04`'s open question: **there is no per-lane ownership source at
runtime.** `WorkerExecution` carries no owned-path declaration and nothing persists dispatch-time
`OWNED_PATHS`. Because `_ChangeScopeConfig.from` refuses an empty `ownedPathGlobs` *before* any path is
examined, decision `c3f81b04`'s static forbidden set ended up **declared but not enforced** (ledger F-212).

F2 is now the **sole** gate preventing any feature item from reaching `qaPassed`: the retention decision
(`9b7e4c31`) unblocked F1/F5 by keeping the checkout alive to evaluation time, but every feature item still
fails F2 at provision and queues for a human decision.

## Alternatives considered

- **Derive ownership from the work item's own claims** — answers a different question. F2 exists to catch a
  lane touching paths it was **never granted**, which is confinement; judging against what the work *claimed*
  it would touch is provenance, and a lane that lies in its claim would then pass its own gate.
- **Accept F2 permanently fail-closed** — honest, and the gate never proves anything on its own. Every feature
  item would require a human QA decision forever.

## Conditions attached

- **The gate's semantics do not change.** F2 still compares the committed diff's paths against the
  **declared** owned set and the **declared** forbidden set. Persisting the declaration supplies the missing
  input; it does not re-tune, weaken or bypass the evaluator.
- **Fail-closed direction is preserved.** A lane that declares no ownership must still fail closed with a
  readable reason — an empty owned set is never a wide-open set (inherited from `c3f81b04`).
- **The declaration must be what the lane actually declared**, persisted at dispatch time, not reconstructed
  after the fact or inferred from the diff. A declaration written after the work is known is not a grant.
- **The static forbidden set from `c3f81b04` is retained** and continues to apply to every lane regardless of
  what it declares.
- A lane that declares ownership outside its dispatch scope must be **caught**, not accommodated — that is the
  gate's job, and it is what this decision makes reachable for the first time.

## Status

Recorded. Implementation is dispatched separately and must be independently reviewed.

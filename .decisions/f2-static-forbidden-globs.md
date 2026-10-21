# F2 ships the AGENTS.md prohibited set as static forbidden globs

- **decision_id:** `c3f81b04`
- **decided:** 2026-10-21
- **decided_by:** human (via structured question UI)
- **gate:** F2 `change-scope-confinement` (manifest `feature-change-scope-confined`)
- **touches:** `apps/server/manifests/shipit-platform.product-manifest.json` `ownedPathGlobs` /
  `forbiddenPathGlobs` (ledger F-203)

## Decision

Populate the shipped manifest's **static, always-forbidden** paths from `AGENTS.md`'s prohibited set —
`.agents/**`, `.claude/**`, `.opencode/**`, `.junie/**`, `AGENTS.md`, `docs/adr/**`, `.decisions/**` — as
`forbiddenPathGlobs`.

**`ownedPathGlobs` is left to a per-lane dynamic source**: AGENTS.md's path-ownership map (decision
`c2f8a713`) describes ownership **declared per lane at dispatch time**, which a single static manifest list
cannot express for every lane at once.

## Why it was put to the human

The shipped contract declared `"ownedPathGlobs": []` for a **required** gate, which made its evaluator throw
`FormatException` at provision — every feature item failed closed at `qaFailed` and queued for a human
decision, so no feature item could reach `qaPassed`. The design deliberately declined to guess the globs, and
two reviewers independently refused to populate them rather than invent product ownership.

## Conditions attached

- **Fail-closed behaviour is preserved, not traded away.** If the runtime cannot obtain a lane's declared
  ownership at evaluation time, the gate must still fail closed with a readable reason. This decision does
  **not** authorise treating an absent ownership declaration as "no paths are owned, therefore anything is
  allowed" — an empty owned set is never a wide-open set.
- The gate must not be weakened, re-tuned, or made to pass by construction.

## Open question this decision deliberately leaves to measurement

Whether a per-lane dynamic ownership source is **available at runtime** at all. If it is not, the honest
outcome after this change is that the statically-forbidden set is enforced while ownership-dependent
confinement remains unestablished — **that residual must be reported, not papered over.**

## Status

Recorded. Implementation is dispatched separately and must be independently reviewed.

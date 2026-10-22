# F-170: the replay branch backfills a design contract, mirroring QA

- **decision_id:** `b41f7c26`
- **decided:** 2026-10-21
- **decided_by:** human (via structured question UI)
- **settles:** design ruling F-170, a hard precondition for design-governance step 8
- **follows:** `.decisions/` on design-governance automation; ADR 0021

## Decision

**The replay branch provisions a design contract when the row lacks one**, mirroring the QA side's explicit
`_attachQAContract` precedent (`lane_e_design_remediation_work_item.dart:355` vs `:379`).

## Why

- The design (§4.2(a)) says "at creation" and is silent on replay — the gap is the design's silence, not the
  lane's work. Silence is not a prohibition, and the QA side already resolved the identical question
  explicitly with `_attachQAContract`.
- Without a backfill, a legacy row re-triaged through the replay branch parks at `designParked` with a NULL
  `designContractId` and no named reason; the §9 reconciler releases only when the column is non-null, so
  that row would **silently never release**. A park that nothing can release is worse than a provisioned
  contract for a row whose design work may already be done.

## Conditions attached

- **Backfill only when the column is NULL.** A row that already has a contract is not re-provisioned; the
  provisioning path is idempotent by construction (`provisionDesignContract` saves then reads back).
- **The backfill is the same operation as creation**, not a second implementation of it — the same
  `_provisionDesignContract` helper, so the two branches cannot drift.
- **No new disposition is invented.** The row still lands where §4.7 puts it; the ruling only makes the
  contract exist so the existing reconciler can release it.
- **`DesignRiskPolicy` remains deferred (step 5).** This ruling does not resolve the risk tier and does not
  authorize folding one into `approvalThreshold`.

## Status

Recorded. Implementation is dispatched separately and must be independently reviewed.

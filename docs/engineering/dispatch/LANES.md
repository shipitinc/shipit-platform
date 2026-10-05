# LANES.md — Manager lane ledger

One row per lane. Rebuilt from disk + Git on 2026-10-05 per `aef-orchestrator` §14
recovery procedure. Git is authoritative for code state.

## Prior session — work item "Add Product page UI implementation"

Recovery finding: **all ten lanes have `prompt.md` only — no `report.md`, no
`state.json` was ever persisted.** Every lane worktree is still at `693cfbc` with
uncommitted changes, so no lane produced a commit and no lane produced reviewable
provenance. The prior ledger therefore cannot be trusted and was not reconstructed
from reports.

| task_id | type | recorded state | worktree | branch | base_sha | head_sha | next action |
|---|---|---|---|---|---|---|---|
| design-produce-add-product | design-produce | artifacts present, uncommitted | /private/tmp/shipit-design-add-product | design/add-product | 693cfbc | 693cfbc | PARKED — uncommitted artifacts, no report |
| design-review-add-product | design-review | in-flight per Git, no report | /private/tmp/shipit-design-review-add-product | design-review/add-product | 693cfbc | 693cfbc | PARKED — treated as not-run (no report) |
| design-correct-add-product | design-produce | in-flight per Git, no report | /private/tmp/shipit-design-correct-add-product | design-correct/add-product | 693cfbc | 693cfbc | PARKED — no report |
| design-re-review-add-product | design-review | in-flight per Git, no report | /private/tmp/shipit-design-re-review-add-product | design-re-review/add-product | 693cfbc | 693cfbc | PARKED — no report |
| design-correct-2-add-product | design-produce | in-flight per Git, no report | /private/tmp/shipit-design-correct-2-add-product | design-correct-2/add-product | 693cfbc | 693cfbc | PARKED — no report |
| design-re-review-2-add-product | design-review | in-flight per Git, no report | /private/tmp/shipit-design-re-review-2-add-product | design-re-review-2/add-product | 693cfbc | 693cfbc | PARKED — no report |
| qa-contract-add-product | qa-contract | artifact present, uncommitted | /private/tmp/shipit-qa-contract-add-product | qa-contract/add-product | 693cfbc | 693cfbc | PARKED — `QA_CONTRACT_add_product.json` uncommitted, never frozen |
| implement-add-product | implement | **RESULT: IMPLEMENTATION_BLOCKED** (verified in worktree `IMPLEMENTATION_REPORT.md`) | /private/tmp/shipit-implement-add-product | implement/add-product | 693cfbc | 693cfbc | PARKED — blocker is the missing product baseline (see decision 130f3a7e) |
| review-add-product | review | dispatched with no valid upstream result; no report | /private/tmp/shipit-review-add-product | (detached) | 693cfbc | 693cfbc | PARKED — lane should never have been dispatched |
| integrate-add-product | integrate | dispatched with no approval; no report | /private/tmp/shipit-integrate-add-product | (detached) | 693cfbc | 693cfbc | PARKED — lane should never have been dispatched |

Defect recorded: the prior session advanced to `review` and `integrate` without a
parsed `RESULT: IMPLEMENTED` or any independent approval, and without persisting
child reports. Both lanes are void.

## Current session — FEATURE c46b6807

Item ref: favicon · duplicate "Show technical details" row on Add a product ·
Register-product button disabled / required-field convention · isolated test environment.

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | next action |
|---|---|---|---|---|---|---|---|---|
| (none dispatched) | — | BLOCKED on decision 130f3a7e | — | — | — | — | — | BLOCKED |

No lane was dispatched. `aef-orchestrator` §4 precondition 6 ("every dependency listed
in the prompt is already merged") cannot be satisfied: no commit on any ref contains
`ControlPlaneRepository.createProduct` or `lib/shared/form_primitives.dart`, so a
worktree created from any `BASE_SHA` is a codebase without the product.
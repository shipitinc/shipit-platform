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

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| review-runtime-config-interop | review | CLOSED | canonical checkout (read-only) | main | bfbbd68 | bfbbd68 | STANDARD | `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` — 0 blockers, CORRECTION_REQUIRED: NO | follow-ups recorded; change included in baseline |
| integrate-baseline-product | integrate | CLOSED — BLOCKED | canonical checkout + throwaway worktree | baseline/product-2026-10-05 | bfbbd68 | 0d5d132 | STANDARD | `INTEGRATION_BLOCKED` — B1 missing review, B2 ledger, B3–B7 non-blocking | superseded in substance by review-baseline-0d5d132 |
| review-baseline-0d5d132 | review | CLOSED — BLOCKED | /private/tmp/shipit-review-baseline (removed) | (detached) | bfbbd68 | 0d5d132 | PRECISION | `DO_NOT_MERGE` — CORRECTION_REQUIRED: YES, HUMAN_DECISION_REQUIRED: YES | parked; mechanical corrections + 2 human decisions required |
| (feature lanes) | — | NOT DISPATCHED | — | — | — | — | — | — | blocked: no reviewed, buildable BASE_SHA exists |

## Current session — product baseline

| item | branch | head | note |
|---|---|---|---|
| baseline commit | `baseline/product-2026-10-05` | `0d5d132` | 585 files changed (+203997/-4838); explicitly unreviewed except the runtime-config fix |
| `main` | `main` | `bfbbd68` | 3 commits ahead of `origin/main` (693cfbc, 9d98efe, bfbbd68) — never pushed |
| `origin/main` | — | `ea9b03d` | |

Verified from a fresh detached worktree at `0d5d132`: `flutter pub get` resolves,
`flutter analyze` 0 errors, `flutter test` 190/190, `flutter build web` succeeds,
`createProduct` and `lib/shared/form_primitives.dart` both present (they existed in no
prior commit). Clean fast-forward: `merge-base main baseline` = `bfbbd68`.

## Stale lane worktrees — all pinned to 693cfbc, 4 behind baseline

Per integrator blocker B9, none may be removed without a decision, because they hold
uncommitted design/QA artifacts and one of the superseded `add_product_page.dart`
variants.

| worktree | branch | holds |
|---|---|---|
| /private/tmp/shipit-design-add-product | design/add-product | DESIGN_BRIEF / DISCOVERY / REVISION (untracked) |
| /private/tmp/shipit-design-review-add-product | design-review/add-product | same three design artifacts |
| /private/tmp/shipit-design-correct-add-product | design-correct/add-product | design artifacts + superseded add_product_page.dart |
| /private/tmp/shipit-design-re-review-add-product | design-re-review/add-product | design artifacts |
| /private/tmp/shipit-design-correct-2-add-product | design-correct-2/add-product | design artifacts + superseded add_product_page.dart |
| /private/tmp/shipit-design-re-review-2-add-product | design-re-review-2/add-product | design artifacts + superseded add_product_page.dart |
| /private/tmp/shipit-qa-contract-add-product | qa-contract/add-product | `QA_CONTRACT_add_product.json` (never frozen) |
| /private/tmp/shipit-implement-add-product | implement/add-product | `IMPLEMENTATION_REPORT.md` (`RESULT: IMPLEMENTATION_BLOCKED`) + superseded variant |
| /private/tmp/shipit-review-add-product | (detached) | superseded add_product_page.dart — VOID lane |
| /private/tmp/shipit-integrate-add-product | (detached) | superseded add_product_page.dart — VOID lane |

`0d5d132` pins the authoritative `add_product_page.dart` (canonical checkout, 1117 lines),
so the four worktree variants are superseded for code purposes. The design and QA
artifacts remain unreconciled (blocker B10).
## Correction lane — baseline mechanical

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| correct-baseline-mechanical | correct | CLOSED — BLOCKED | /private/tmp/shipit-correct-baseline (retained) | correct/baseline-mechanical | 0d5d132 | 07c48ed | STANDARD | `CORRECTION_BLOCKED` — B1/B2/B3/M2/M3 all cleared; A and B unmeetable in OWNED_PATHS | human must rule on Blocker A (CI analyze gate) and Blocker B (coupled credential pair) |

Commits on top of the unrevised `0d5d132`: `dae3d68` (B1, M2) · `96928ed` (M3) ·
`d371265` (B3) · `07c48ed` (B2). 49 files, +995/-1689.

## Analysis cleanup — APPROVED

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| correct-analysis-cleanup | correct | CLOSED — APPROVED | /private/tmp/shipit-analysis-cleanup (retained) | correct/analysis-cleanup | 07c48ed | 6f5a693 | STANDARD | `CORRECTION_COMPLETE` — 337/339 cleared, `READY_FOR_FOCUSED_REVIEW: YES` | merged into comment correction below |
| focused re-review (F/R-1) | re-review | CLOSED — NOT APPROVED | read-only | (detached) | 07c48ed | 6f5a693 | PRECISION | `DO_NOT_APPROVE_CORRECTIONS` — 337 fixes CONFIRMED clean; blocked only on 2 false code comments | corrected below |
| correct-analysis-comments | correct | CLOSED — APPROVED | /private/tmp/shipit-analysis-cleanup | correct/analysis-cleanup | 6f5a693 | 38768d0 | CHEAP_READ | `CORRECTION_COMPLETE` — comment-only, 0 non-comment lines (mechanically proven) | merged into re-review below |
| focused re-review (F/R-2) | re-review | CLOSED — APPROVED | read-only | (detached) | 6f5a693 | 38768d0 | CHEAP_READ | `APPROVE_CORRECTIONS` — no blockers, `READY_FOR_MERGE: YES` | correction loop closed |

`correct/analysis-cleanup` @ `38768d0` is now **CI-green**: `dart analyze` exit 0 in all 16
packages, `melos run analyze` SUCCESS, `melos run format` SUCCESS, `flutter analyze` "No issues
found!", `flutter test` 190/190, `melos run test` SUCCESS, `flutter build web` exit 0.
Two `deprecated_member_use` infos on `WorkItemState.done` remain by deliberate STOP; they are
gate-neutral and `workflow_engine` still exits 0.

## Queued — authorised by the human, not yet dispatched

| item | scope | closes |
|---|---|---|
| credential / port lane | `apps/server/config/**`, `apps/server/docker-compose.yaml`, `.github/workflows/integration.yaml`, `apps/server/tool/seed_overview_qa.sql` | Blocker B; the `control_plane_test_pw` coupling; the 9090 vs 9099 mismatch; H1–H3 (never-executed migrations, via `dart test test/integration/` against real Postgres) |

## New product decisions surfaced, not yet filed

- `ControlPlaneRepository.addHumanBaselineClaim` returns a fabricated `DecisionView`
  (`baseline-claim:<µs>` id exists nowhere server-side, hardcoded `status: 'pending'`,
  `options: []`). PRODUCT decision — changes a returned payload.
- `WorkItemState.done` cannot be made lint-clean without dropping the enum member and handling
  legacy `'done'` at `fromWire`. PRODUCT decision.
- `AGENTS.md` § Product-specific policy is still fully `TBD` — no declared validation gate,
  path ownership map, or environment/deployment strategy. This is the root cause of the
  analyzer debt having accumulated untracked.

## Credential / port contract — CORRECTION_COMPLETE, awaiting focused review

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| fix-credential-port-contract | correct | CLOSED — awaiting review | /private/tmp/shipit-cred-port (retained) | fix/credential-port-contract | 38768d0 | 60c8136 | PRECISION | `CORRECTION_COMPLETE`, `READY_FOR_FOCUSED_REVIEW: NO` (157/1 tests — lane declined to self-certify a red suite) | focused review + human gate on H1 |

Closed: Blocker B, the 9090/9099 mismatch, and H1-H3 execution (integration suite finally run).
Opened: **H1 PROVEN as a security gap** — fresh databases, CI included, lack
`trigger_design_revision_immutability` and `trigger_design_review_independence`; tampering with
an approved design revision succeeds on a fresh DB and is rejected on a chain-migrated DB.
Requires a human gate because the fix is in prohibited `migrations/**`.

Also outstanding: a `migration_proof` database left inside the owner's
`control_plane-postgres_test-1` container by a prior agent session — destructive to remove.

## Design triggers + test cleanup — CORRECTION_COMPLETE

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| fix-design-triggers | correct | CLOSED — awaiting review | /private/tmp/shipit-triggers (retained) | fix/design-triggers-and-cleanup | 60c8136 | 14608dc | PRECISION | `CORRECTION_COMPLETE`, `READY_FOR_FOCUSED_REVIEW: YES` | focused review |

Closes H1: fresh databases now enforce `trigger_design_revision_immutability`,
`trigger_design_review_independence` and `design_revision_approved_unique_per_work_item` via
`apps/server/tool/schema_bootstrap.{sql,dart}`, proven to survive a real
`serverpod create-migration`. Guard `verify_schema_bootstrap.sh` wired into the `schema-guard` CI
job, negative-tested 5 ways. Test-resource cleanup enforced across `test-env-test`, `e2e-test`,
new `test-integration`, `compose.test.yaml` and `integration.yaml`, proven on success, failure
and interrupt. Rule recorded in `AGENTS.md` § Product-specific policy.

Owner action required: the owner's `control_plane-postgres_test-1` on 9099 lacks the trigger and
will not self-heal.

## make clean disarm — APPROVED and merged

| task_id | type | state | worktree | branch | base_sha | head_sha | result |
|---|---|---|---|---|---|---|---|
| fix/disarm-make-clean | correct | CLOSED — MERGED | /private/tmp/shipit-disarm-clean | fix/disarm-make-clean | 59ad603 | 2922fef | `CORRECTION_COMPLETE` then `APPROVE_CORRECTIONS`, `READY_FOR_MERGE: YES` |

Merged fast-forward into `main` as `2922fef` and pushed. `clean` is now a pure-`echo` safety stub:
zero Docker invocations, structurally incapable of mutation. Three correction cycles were needed:
cycle 1 produced a stub whose own guidance pointed at `test-env-down`/`e2e-down`, which resolve to
compose project `docker` and also stop the QA stack; cycle 2 corrected the false claims.

## Add Product design — FOLDED, brief not yet dispatched

| task_id | type | state | worktree | branch | base_sha | result |
|---|---|---|---|---|---|---|
| design-register-button | design-produce | SUPERSEDED — folded into the Add Product rebuild | /private/tmp/shipit-design-register | design/register-button | 2922fef | `DESIGN_REVISION_COMPLETE`, risk 2 |
| (design review of the above) | design-review | CLOSED | read-only | — | 2922fef | `DESIGN_REVIEW_HUMAN_DECISION_REQUIRED` — report persisted at `tasks/design-register-button/report.md` |

Human's points 2d and 2e answer that round's D6 (SSH trust-on-first-use cancel) and F4/D1
(button vs helper-text layout). Its B1-B6 blockers remain open and are folded into the new scope:
re-ground the required-field work on the existing `(OPTIONAL)` suffix, ship D1 as two explicit
variants, fix the AA-failing token, give V9-equivalent classification a committed source.

## Add Product rebuild — DESIGN PRODUCED, Gate D3 dispatched

Item ref: Add Product rebuild (folded register-button round + server-side deploy-key service).
Base `77c19f1`, `main` = `origin/main` 1:1. Two design lanes dispatched **in parallel**, split by the
Manager so a failure costs less; `OWNED_PATHS` verified disjoint before launch.

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| design-addproduct-keyservice | design-produce | CLOSED — COMPLETE | /private/tmp/shipit-design-addproduct-keys | design/addproduct-keyservice | 77c19f1 | 77c19f1 | PRECISION | `DESIGN_REVISION_COMPLETE`, `RISK_LEVEL: 3`, `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` — compliance PARTIAL / a11y PARTIAL / feasibility MEDIUM; 2 OPEN Gate D4 decisions surfaced, neither answered | independent design review (Gate D3) |
| design-addproduct-mobile | design-produce | CLOSED — COMPLETE | /private/tmp/shipit-design-addproduct-mobile | design/addproduct-mobile | 77c19f1 | 77c19f1 | STANDARD | `DESIGN_REVISION_COMPLETE`, `RISK_LEVEL: 2`, `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` — compliance PARTIAL / a11y PARTIAL / feasibility MEDIUM; 4 boards authored, 2 copied to existing boards in error and corrected | independent design review (Gate D3) |
| design-review-addproduct-keyservice | design-review | DISPATCHED | read-only (canonical) | — | 77c19f1 | — | PRECISION | — | parse `DESIGN_REVIEW_*` token |
| design-review-addproduct-mobile | design-review | DISPATCHED | read-only (canonical) | — | 77c19f1 | — | PRECISION | — | parse `DESIGN_REVIEW_*` token |

Both lanes: **zero Docker commands issued**, no commits, no pushes, no self-approval. Both reported
analyzer/build/test as `NOT_RUN` and derived no feasibility claim from one. Artifacts persisted from
each worktree into `docs/engineering/dispatch/tasks/<task_id>/`.

### What the lanes found that the Manager had recorded wrongly
Three VERIFIED FACTS in `WORK_STATE.md` were false and are now corrected there:
1. **"No deploy-key infrastructure exists server-side" is FALSE.** It came from grepping
   `deployKey`/`deploy_key`; the infrastructure is named `credential`. `RepositoryCredential`,
   `CredentialStatus`, `HostKeyStatus`, the `product_credential` table, `RepositoryCredentialView`,
   4 store methods, 6 engine methods and a 16-test suite all exist. The keys lane designed onto them
   with a 35-row reuse table and invented no parallel abstraction. **Decision `b869ec24`'s evidence
   is wrong but its conclusion is unaffected and strengthened.**
2. **"'Show technical details' was removed" is FALSE** — it renders via the shared `TechnicalDetails`
   primitive (`design_primitives.dart:415`), instantiated at `:316` and `:925`. A literal grep in the
   page file is a false negative against a centralised label.
3. **The footer copy at `:383` is DESKTOP-ONLY** — `_buildFooter` is called solely from `:314`.

Also recorded: **ADR 0018 and `AGENTS.md §13a` do not exist.** Nine code locations cite them; the
governing ADR for the credential model is absent from the repository.

### Process note
A Manager dispatch prompt asserted four "verified" premises that were wrong: two nonexistent paths
(`features/defects/create_defect_page.dart`, `shared/design_tokens.dart` — the real ones are
`features/defect_report/` and `core/design_tokens.dart`), stale token line numbers, and the false
"Show technical details was removed" claim. The mobile lane caught all four, re-ran each against the
correct path, and reported them rather than working around them — which is the behaviour the dispatch
asked for. Recorded per `LEARNING_POLICY.md` as a WORKFLOW_IMPROVEMENT: a corrected premise handed to a
child is still a premise, and must be re-verified rather than trusted.

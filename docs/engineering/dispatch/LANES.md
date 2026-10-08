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

Also recorded — **AND SINCE RETRACTED, see the Gate D3 section below**: "ADR 0018 and `AGENTS.md §13a`
do not exist." **That was false.** The product ADRs are in `docs/adr/` (21 ADRs, `0001`–`0021`), not
`docs/engineering/adr/` (which holds only the three framework-distribution ADRs).
`docs/adr/0018-per-product-git-credentials.md` exists, 158 lines, "Proposed (amended — A1)". The claim was
repeated here by the Manager and caught by the Gate D3 review (blocker B1); it is retracted at
`WORK_STATE.md` and the two Human Decision objects it had contaminated now cite the ADR.

### Process note
A Manager dispatch prompt asserted four "verified" premises that were wrong: two nonexistent paths
(`features/defects/create_defect_page.dart`, `shared/design_tokens.dart` — the real ones are
`features/defect_report/` and `core/design_tokens.dart`), stale token line numbers, and the false
"Show technical details was removed" claim. The mobile lane caught all four, re-ran each against the
correct path, and reported them rather than working around them — which is the behaviour the dispatch
asked for. Recorded per `LEARNING_POLICY.md` as a WORKFLOW_IMPROVEMENT: a corrected premise handed to a
child is still a premise, and must be re-verified rather than trusted.

## Gate D3 — INDEPENDENT DESIGN REVIEW: BOTH `CHANGES_REQUIRED`

| task_id | type | state | result | risk |
|---|---|---|---|---|
| design-review-addproduct-keyservice | design-review | CLOSED — CHANGES_REQUIRED | `DESIGN_REVIEW_CHANGES_REQUIRED`, `CORRECTION_REQUIRED: YES`, `HUMAN_DECISION_REQUIRED: YES`, `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES` | agrees with producer's 3 |
| design-review-addproduct-mobile | design-review | CLOSED — CHANGES_REQUIRED | `DESIGN_REVIEW_CHANGES_REQUIRED`, `CORRECTION_REQUIRED: YES`, `HUMAN_DECISION_REQUIRED: **NO**`, `INDEPENDENT_RISK_LEVEL: 2`, `RISK_LEVEL_AGREEMENT: YES` | agrees with producer's 2 |

Neither reviewer ran a Docker or Compose command; neither persisted anything. Reports at
`tasks/design-review-addproduct-keyservice/report.md` and `tasks/design-review-addproduct-mobile/report.md`.
Both independently **re-measured** the inherited a11y contrast figures rather than accepting them, and
both reproduced every value.

### ⚠ A MANAGER ERROR THE REVIEW CAUGHT — ADR 0018 EXISTS

Both the design lane and the Manager asserted that ADR 0018 was absent, because both looked in
`docs/engineering/adr/` (three framework-distribution ADRs). **The product ADRs are in `docs/adr/` —
21 of them, `0001`–`0021`.** `docs/adr/0018-per-product-git-credentials.md` exists, 158 lines,
"Proposed (amended — A1)".

This is the **third** instance in one session of the same error class (D-1 `deployKey` vs
`credential`; now `adr/` vs `docs/engineering/adr/`): grep one identifier, conclude an artifact is
absent, and write that into the ledger as a VERIFIED FACT. The Manager repeated the false claim into
`WORK_STATE.md` and two Human Decision objects before either was reviewed. **The design-reviewer
caught it; the ledger is now corrected and all three decision objects carry the ADR.**

ADR 0018 already decides four things the revision presented as open — most importantly that the
private half goes to **the local secret store** and is "never … persisted to the durable record",
which **excludes the A2 option** (`9417f8bf`) outright and makes the revocation question
(`79e860e2`) largely pre-answered. **`9417f8bf` must be reissued before it is presented to the human.**

### The security finding that matters most (keys lane, B2)

The revision's headline claim — that silent key rotation is *structurally* impossible — is true of the
in-memory object and **false at the persistence boundary**. Verified in
`apps/server/lib/src/persistence/postgres_product_registry_store.dart:177-243`: with a null
`expectedVersion`, `saveProductCredential` runs
`INSERT … ON CONFLICT ("credentialId") DO UPDATE SET … "publicKey" = @publicKey …`, and
`recordGeneratedCredential` (`engine:965`) calls it with **no** `expectedVersion`. So a caller
supplying both `credentialId` and a matching `supersedesCredentialId` passes the one-active guard
(`engine:941`) and **overwrites the stored public key in place** — no rotation record, status reset to
`generated`, host confirmation lost. `copyWith` is not on that path at all. Separately, `repositoryId`
has only a **non-unique** index, so two concurrent mints can both insert, yielding two active
credentials for one repository and violating ADR 0018 A1's "one per repository".

This is the same defect class as the original B6 finding — a user installs the key they just copied and
SHIP IT silently rotates it — reachable through the domain API rather than the UI. It is a **store-level
defect that exists today**, independent of this feature.

### Blockers summary

**keys lane:** B1 (ADR 0018 exists → rewrite § R.21, repopulate `architecture_refs`, revise the
substrate options against what the ADR already decides) · B2 (persistence-layer immutability gap +
missing partial unique index) · H1 (§ R.3 leaks the reserved decision by selecting a substrate in
normative voice) · H2 (Q3 pre-answered by the ADR) · H3 (A2's threat model omits the committed
`SERVERPOD_DATABASE_PASSWORD: shipit` and the 0.0.0.0-published 5432) · H4 (§ R.18 omits the
direct-database path) · M1–M4 · L1–L6.

**mobile lane:** B-R1 (all four boards render every emphasis layer at weight 400 — tokens and the
reference board require 500/600; the producer's justification "Penpot's IBM Plex Sans has no 500
weight" is **false**, `500normal` exists and `900` does not) · H-R1 (`Trust Host` — the host
fingerprint the user must read to decide whether to trust a host — ships at `inkTertiary`, **4.23:1
in dark, failing AA**, the exact pairing the same revision rejects elsewhere) · H-R2 (the false
key-custody claim also lives at `product_detail_page.dart:614`, outside this lane's scope) · H-R3
(published audit count not reproducible) · H-R4 (human point 2b's gating has **no** visual expression
on any board) · M-R1–M-R4 · L-R1–L-R7.

Both corrections are mechanical-to-bounded and **neither touches the human's reserved decision**, which
is why both are `CHANGES_REQUIRED` rather than new escalations.

## Design Contract freeze readiness

| task_id | type | state | result | risk |
|---|---|---|---|---|
| design-review-addproduct-keyservice (rev 2) | design-review | CLOSED — **APPROVED** | `DESIGN_REVIEW_APPROVED`, `CORRECTION_REQUIRED: NO`, `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`, `HUMAN_DECISION_REQUIRED: YES` | revision 2 = `F21D5C64-006D-4203-A813-841E08E38B95` |
| design-review-addproduct-mobile (rev 3) | design-review | CLOSED — CHANGES_REQUIRED | 0 BLOCKERS, 0 HIGH, `CORRECTION_REQUIRED: YES`, `INDEPENDENT_RISK_LEVEL: 2` | superseded by rev 4 |
| design-correct-addproduct-mobile (cycle 4) | design-produce | CLOSED — COMPLETE | `DESIGN_REVISION_COMPLETE`, `RISK_LEVEL 2`, record-only pass (0 board edits) | rev 4 = `A69AB98C-A672-4D98-9DCE-0F089D55A9B5` — awaiting a final focused re-review |

**Keys revision is approved and needs no further design work.** Its remaining Gate D4 decisions are the
human's. The mobile revision is at cycle 4, where every finding is a record correction inside `OWNED_PATHS`
with zero board edits; the cycle-3 reviewer explicitly warned that approving "because it is cycle 3" would
relax a standard on the calendar, so a focused re-review of rev 4 is required before freeze.

### Store-integrity work item — opened from the design review, independent of the feature

`fix-credential-store-integrity` exists because the keys review's finding **M-A** found the design had
specified required work (D-1, D-2, T-A, T-B) correctly and then **left it owned by nobody**, behind the one
lane that could execute it — which is blocked at Gate D4. A live silent-key-rotation path was staying in
`main` for reasons unrelated to it.

- **D-1 — DONE, green.** Predicated `ON CONFLICT … DO UPDATE … WHERE` over the four immutable fields with
  `RETURNING`, so a conflicting row with different key material affects 0 rows and the store raises a typed
  refusal. T-A fails on pristine `064703d` (the rotation, verbatim) and passes after. **The obvious fix — the
  version CAS the first review pointed at — would have left the hole open AND broken minting**, because
  `recordGeneratedCredential` hardcodes `version: 1`. Verified by the approving re-review.
- **D-2 — DONE, green**, as an idempotent partial unique index in `tool/schema_bootstrap.sql`. T-B now passes
  against real Postgres, and the index's predicate is verified identical to `readActiveCredentialForRepository`'s.
- `make test-integration` → `+161 -1`. The sole failure is `dogfood_shipit_postgres_test.dart:87`, which
  asserts `Directory('.git').existsSync()` and therefore **can never pass in a linked worktree**. Proven
  identical on pristine `064703d` in the same pass (baseline `+157 -1`), so the delta is exactly the four new tests.
- **Two gaps the implementer escalated rather than absorbed** — GAP-1 (`verify_schema_bootstrap.sh` hardcodes
  three required objects and is now **blind** to the new index: deleting the CREATE would leave the guard
  green) and GAP-2 (the index is in **no** migration, and the bootstrap runs on no deployed path, so the
  invariant does not reach production). Neither was quietly closed inside a granted scope.

### Three times in one session: grep one identifier, conclude an artifact is absent

1. `deployKey`/`deploy_key` → the domain's word is **`credential`**; a large existing contract, table,
   store, engine and 16-test suite were declared non-existent.
2. `docs/engineering/adr/` → the product ADRs are in **`docs/adr/`** (21 of them); **ADR 0018 exists**, had
   already chosen the substrate the human was being asked about, and forbids one option outright. The Manager
   repeated this false claim into `WORK_STATE.md`, `LANES.md` and two decision objects before review caught it.
3. A lane grepping for the literal "Show technical details" in a page file concluded it had been removed; it
   renders through a shared primitive.

**The rule, as executable knowledge:** search the **domain's** vocabulary, not the requester's phrasing; if
`X` is a **cited** identifier, follow the citations; enumerate locations with `glob`, not `ls` on one guessed
path. Instance 2 fails into *false confidence* — it produced a fabricated traceability gap plus ten
"substitute assumptions" where seven were recorded ADR decisions.

## Gate D4 — RESOLVED, and what it changed

Six decisions resolved by the repository owner through the structured question UI; tamper-checked on each
(`selected_option` matches an `option_id` as presented, with one recorded deviation on `27ea6536`, where the
human rejected both framings and supplied a per-platform footer spec after checking the boards directly).

The single most consequential outcome: **the at-rest protection model is A3, an external secret manager** —
SHIP IT never holds key bytes, only a reference. That makes the credential reference *itself* the sensitive
artifact, so **G-7 (exposing `referenceName` to clients) is no longer optional**. It also supersedes two ADR
0018 clauses while upholding a third.

### Lanes awaiting review
| task_id | type | state | result |
|---|---|---|---|
| design-review-addproduct-mobile (rev 4, focused) | re-review | DISPATCHED, network-failed, retry pending | — |
| review-fix-credential-store-integrity (2nd pass) | review | PENDING | must cover the GAP-2 migration + GAP-1 guard change |

### Store-integrity — COMPLETE, nothing committed
`fix/credential-store-integrity` @ `BASE_SHA 064703d`: **D-1, D-2, GAP-1, GAP-2 all closed.** `RESULT:
IMPLEMENTED`, `READY_FOR_INDEPENDENT_REVIEW: YES`.

Gates: format pass · analyze "No issues found!" · `+142` unit · `make test-integration` `+164 -1` · schema
guard 16 OK. The one failure is the pre-existing dogfood `.git` assertion, **re-proven on pristine `064703d`
this pass** at `+157 -1`, so the delta is exactly the seven new tests.

**The implementer's own quality findings on its prior pass, which is the pattern worth keeping:** the in-memory
M-2 test was green against an **empty store** and would have stayed green asserting nothing; and the Postgres
CAS predicate had **no test at all**. Both are now fixed, and **every check carries a negative control proving
it goes red when the covered thing is removed.**

**Disclosed rather than smoothed:** the duplicate audit against a *deployed* database is `NOT_RUN` — no QA,
staging or production database is reachable from a lane. Zero duplicates were found in every reachable
database, but the only credential-bearing one holds **0 rows**, which is a vacuous "no". And the audit query
as dispatched **does not execute**: `repositoryId` is quoted camelCase, and unquoted it errors — which reads
exactly like "no duplicates". The migration embeds the corrected form, and a human with target access must run
the audit before deploying.

## Review wave after the merge

| task_id | type | result | note |
|---|---|---|---|
| review-credential-identity-invariants | review | `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` | no blockers, no HIGH. 1 MEDIUM: the new full-DDL parity check's `IF NOT EXISTS` normalisation forgives the one divergence that would break migration `20261006150645000` on a bootstrapped database — a **gap in the guard, not a live defect** (both files carry the clause today). 4 LOW, all comment/doc |
| review-addproduct-keys-rev3 (rev 3) | design-review | `DESIGN_REVIEW_CHANGES_REQUIRED` | 4 BLOCKERS, 7 HIGH, risk 3 agreed. The reserved decision is **not nudged anywhere** and D-18 was re-derived and confirmed |
| design-correct-addproduct-keys (rev 4) | design-produce | **DISPATCH FAILED — subagent returned corrupted output, nothing produced** | must be re-dispatched |

`fix-credential-identity-invariants` (D-4 mint is `DO NOTHING`, D-18 resurrection closed by D-4, D-5 scope
immutable, LOW-1 full-DDL parity, LOW-2 derived offender list): **`make test-integration` `+171 -1`**, sole
failure the pre-existing dogfood assertion, re-proven on pristine `0bf2fa0` at `+164 -1`. **Not committed.**

**The reviewer independently overrode the implementer's own self-assessment in the implementer's favour:**
"6 of 6 red", not the 5 of 6 reported. And it caught that the implementer's self-reported file list
misclassified `product_credential_immutability_postgres_test.dart` as added when it already carried D-1/D-2's
tests — cosmetic, but it is the provenance record for an uncommitted change.

### The governance gate that no code lane can discharge

`design-revision-3.md` — the specification D-4/D-18/D-5 implement — is **uncommitted and unapproved**, existing
only as an untracked file in the design lane's worktree at `77c19f1`. Both the engineering reviewer and the
implementer flagged it. **The code cannot land with reviewed provenance behind it until the design is
committed and independently approved.** That is the next dependency, and it is why the keys revision-4
correction is on the critical path rather than optional.

## Revision 4 wave

| task_id | type | result | note |
|---|---|---|---|
| design-correct-addproduct-keys (rev 4) | design-produce | `DESIGN_REVISION_COMPLETE` | `F2D5AF31-CA53-481A-ACB4-C75DB033A15A`, **re-based onto `361256c`** first — B1 was the stale base. Risk 3 re-derived with one published tally in three places |
| design-review-addproduct-mobile-rev4 | re-review | `DESIGN_REVIEW_CHANGES_REQUIRED` | 0 BLOCKERS, **1 HIGH**: three Gate D4 decisions were resolved 63 minutes after the revision was written and it is stale against all three |

### The finding that matters most on the mobile side

**`Art S`'s board string is now FALSE.** The four boards read `ed25519 · private half stays server-side` — and
under the human's A3 decision **SHIP IT does not hold the private half at all**. The design lane had correctly
designated that layer "the single string parameterized on the at-rest protection model", so the one element it
properly held open is now the one element that is wrong, **on four boards, in user-facing security copy**. The
reviewer could not verify it against the live Penpot file (no instance connected) and flagged that every
board-read claim should be treated as unconfirmed by it.

Also unapplied: the human's normative **footer alignment** (desktop right-aligned with a divider, mobile
left-aligned with none) is **specified nowhere**, and the inherited spec still carries the desktop copy the
human overruled. And `898b07d0` (split identity from registration) appears **zero times** in the artifact set —
the Unknown-host boards carry the product fields but no element conveying *"a product exists but is not yet
usable"*.

### Two lanes failed on infrastructure, not judgement

The keys revision-4 correction and the mobile revision-4 re-review **both** returned corrupted subagent output
on first dispatch and had to be re-sent. Both succeeded on retry. Recorded because two-for-two is a pattern
worth watching, not because either dispatch was wrong.

## Session 2026-10-07 (orchestrator-main) — resume

**Penpot reachable.** The two-session `SESSION_LIMITED` blocker is cleared; the mobile lane was
dispatched immediately. `main` = `origin/main` = `289f1d3`, unmoved throughout. **No Human Decision was
raised this session** — every lane resolved on the recorded resolutions alone.

| task_id | type | state | worktree | branch | base | head | routing | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| design-correct-addproduct-mobile-5b | design-produce | CLOSED — COMPLETE | /private/tmp/shipit-correct-addproduct-mobile | design-correct-addproduct-mobile | 289f1d3 | 289f1d3 (uncommitted) | STANDARD | `DESIGN_REVISION_COMPLETE`, risk 3, a11y **PASS** | independent review |
| design-review-addproduct-keys-rev5 | design-review | CLOSED — CHANGES_REQUIRED | read-only | — | 289f1d3 | 289f1d3 | PRECISION | 1 BLOCKER, 0 HIGH, 4 MEDIUM, 3 LOW | keys rev-6 correction (needs F6 grant) |
| design-correct-adr-0018-a2-2 | design-produce | CLOSED — COMPLETE | /private/tmp/shipit-design-adr0018 | design/adr-0018-amendment | 289f1d3 | 289f1d3 (uncommitted) | PRECISION | `DESIGN_REVISION_COMPLETE`, risk 3 | independent review |
| review-credential-identity-invariants-rereview | review | CLOSED — NOT APPROVED | read-only | — | 0bf2fa0 | **no commit** | PRECISION | `DO_NOT_APPROVE_CORRECTIONS`, `READY_FOR_MERGE: NO` | correction dispatched |
| correct-credential-identity-invariants-guard | correct | CLOSED — COMPLETE | /private/tmp/shipit-credential-identity | fix/credential-identity-invariants | 0bf2fa0 | **a4c211c** | PRECISION | `CORRECTION_COMPLETE` | focused re-review |
| review-credential-identity-invariants-final | review | CLOSED — APPROVED | read-only | — | 3f3f4f4 | a4c211c | PRECISION | **`APPROVE_CORRECTIONS`**, no regressions, `READY_FOR_MERGE: YES` | integrator |
| integrate-credential-identity-invariants | integrate | **CLOSED — READY, AWAITING AUTHORITY** | /private/tmp/shipit-credential-identity | fix/credential-identity-invariants | 0bf2fa0 | a4c211c | PRECISION | **`READY_FOR_INTEGRATION`**; merge rehearsed `08c7590`, 0 conflicts | **human merge authority** |

### Three things a fresh session must not re-derive

1. **The reviewed tree had no commit, and it survived nowhere.** `3f3f4f4` was **reconstructed by exact
   inverse edits** after the correction lane searched 26 worktrees and found the reviewed state absent.
   The final review verified it against every recorded oracle **plus one the lane could not check — the
   MEDIUM defect itself reproduces at `3f3f4f4`** — and 11 further line-level oracles. One disclosed
   outlier (a cited line was `:293`, not `:281`). **Do not assume a reconstructed commit is faithful
   because the lane says so; check it against an oracle.**
2. **The obvious guard fix fails OPEN.** Check 4 derived names with `sed 's/^[^:]*://'` — one field
   stripped. Adding a third colon-delimited field without updating that sed makes the regex stop
   matching, `offenders` empty, and **check 4 silently passes** (planted index: `exit 1` → `exit 0`).
   Reproduced independently by both the reviewer and the correction lane. Accepted fix: one list,
   `exit 2` on an absent expectation, `cut -d: -f2` in the same commit.
3. **T4 is a real determinism defect, not noise.** 3 of 8 integration runs had an extra failure: both
   callers mint the same id into one repository, so the loser violates **two** unique constraints at once
   and **which one Postgres names is not pinned**. One row is written either way — **no masked security
   bug** — and `T-C` (sequential) never flakes. The integrator ran it 4 more times (0 of 4) and recorded
   that **0-in-4 does not make the suite deterministic** rather than overturning the diagnosis. Fix the
   **mint-branch read-back, not the test**.

### Lane failures this session

- **One dispatch cancelled mid-flight** (mobile). It left board edits and part of the record sweep applied
  with **no revision artifact and no report**. The Manager measured the live state and dispatched a
  **resume** note rather than restarting, so the applied work was finished rather than redone — and the
  resumed lane re-verified every Manager claim independently before relying on it.
- **Two reports lost this session, one for the third time.** The ADR lane found its own review report
  **absent** and reconstructed the finding set from the ADR text, saying so. The keys rev-5 review report
  and three of four credential reports are **still untracked**. A verdict with no provenance is this work
  item's repeating failure.

## Merged 2026-10-07 — `08c7590` (human-authorized)

`fix/credential-identity-invariants` is **on `main`**. Merged by fast-forwarding onto the integrator's
rehearsed commit `08c7590` — the exact tree its gates ran on — so nothing was re-verified and `main`
never landed an unverified merge. `origin/main` verified 0/0 by `git ls-remote`.

**The revocation hole is closed.** Manager re-verification on the merged tree: format 631/0 · analyze
exit 0 · unit `+148` · schema guard **20 OK / 0 FAIL** · negative controls 12/0 · `make test-integration`
**`+172`, ALL PASSED** — the first fully green integration run on `main`. The branch read `+171 -1`; the
extra test passes in a real checkout because `dogfood_shipit_postgres_test.dart:87` asserts a git working
tree, **independently confirming the linked-worktree diagnosis from `e391c02`.**

## Review wave — all three in, none clean

| task_id | result | note |
|---|---|---|
| design-review-addproduct-mobile-rev5 | `DESIGN_REVIEW_CHANGES_REQUIRED` | **0 BLOCKERS**, 3 MEDIUM, 4 LOW. **Verified every board claim live on Penpot** — all reproduces. Three record corrections, no design change |
| design-review-adr-0018-a2-rev3 | `DESIGN_REVIEW_CHANGES_REQUIRED` | **1 BLOCKER, 3 HIGH**, 3 MEDIUM, 2 LOW. Rejected G-17's framing; generalised it to a **class** |
| (integration) | `READY_FOR_INTEGRATION` → **MERGED `08c7590`** | human-authorized |

**Three things a fresh session must not re-derive:**

1. **Penpot is reachable**, and the mobile reviewer used it. Every board claim on the mobile artifact
   set is now **independently verified against the live file** — the first time that has been possible.
   Do not re-review those claims; read the rev-5 report.
2. **The stale-normative-text defect is a CLASS, not G-17.** G-17 (an ADR denying its own acceptance) is
   one instance; **B-1, H-1 and H-2 are three more in the same ADR.** The producing lane fixed two
   sentences and framed the lesson as "the defect was the tense" — the reviewer rejected that framing
   precisely because it licenses a two-sentence fix. **Sweep for unmarked superseded clauses rather than
   fixing the reported ones.**
3. **⚠ A1 is substantively closed by `08c7590`.** `recordGeneratedCredential` now refuses any mint onto
   an existing `credentialId`. **ADR 0018's §A1 is correct at `289f1d3` and stale-wrong inside the same
   merge.** It must be re-verified at commit time.

**Bookkeeping now on `main` at `16cd497`** — 37 files, **zero production source**. This includes both
design revisions, all three review verdicts, the credential correction and both re-reviews, the
integrator's report, and attempt 1's full mobile report that had existed only in a worktree.

## Round 3 — human decisions discharged, mobile revision 6 APPROVED

**Human decisions taken 2026-10-07, surfaced via structured question UI:**

1. **G-18 — GRANTED board ownership.** A scoped design-system lane will own the four desktop
   `S - Add Product` boards (and `BPM`) to remove the single `Footer` text layer at (236,862).
   **Not a re-decision** — `27ea6536`'s outcome stands; the boards just don't match it yet.
   ⚠ **Penpot went dormant during the session** (`getPages()` returns "no heartbeat for 42s"), so the
   lane is **blocked on the plugin tab being re-focused.** A grant is not an execution.
2. **Accepted risk A1 RETIRED** — the owner was shown `08c7590` made the mint insert-only on both tiers.
   **THREE accepted risks remain: A2, A3, A4.** Two prior design lanes had deliberately declined to
   retire it and were right to; the ADR lane recorded the retirement as **the owner's decision.**
   **Retiring A1 discharged the resurrection half only** — no code destroys a secret-manager handle, so
   revocation is **still one-sided in practice**, and that half was never an accepted risk.
3. **Round 3 dispatched** — mobile Rev 7, keys Rev 7, ADR Rev 5.

| task_id | result | note |
|---|---|---|
| design-correct-adr-0018-a2-4 (rev 5) | `DESIGN_REVISION_COMPLETE` | H-R1/2/3 closed; **A1 retired**; full referential re-derivation found **9 distinct broken refs across 14 sites** vs 3 reported |
| design-correct-addproduct-keys-7 (rev 7) | `DESIGN_REVISION_COMPLETE` | **7 dangling targets across 45 sites** vs 1/2 reported; own extraction then caught 4 it introduced itself |
| design-approve-mobile-rev6 | **`DESIGN_REVIEW_APPROVED`** | **0 BLOCKERS / 0 HIGH / 0 MEDIUM / 0 LOW. First clean artifact in this work item** |

**Mobile revision 6 is approved — but a Design Contract freeze is deliberately NOT available.** Gate D5
triggers on "all applicable gates", and invariant 7 makes a frozen contract **immutable**, while N6b and
N6c both need **board changes** to discharge. Freezing now would make the edits that clear the revision's
own gaps a change to an immutable artifact. **Approval is real; the freeze is withheld on purpose.**

### Three things a fresh session must not re-derive

1. **The referential class is separate from the claims class.** The ADR sweep covered *claims* and found
   11 — confirmed independently, no twelfth. But its axes could not see **wrong `file:line` citations**,
   and revision 4 had just been handed a finding proving that class exists. Re-deriving found **9 broken
   references across 14 sites**; keys revision 7 found **45 sites across 7 targets**. **Three reported
   was an undercount in both artifacts.** Sweep references, not just claims.
2. **A Manager edit to a resolved decision is the most sensitive edit class here.** Five append-only dated
   notes have now been applied across three objects. Each was **verified against source before applying**
   — every `file:line` the notes assert was read. **No rationale was rewritten; `status`,
   `selected_option` and `decided_at` unchanged in all three.**
3. **⚠ A Manager premise was wrong again, and a lane caught it.** I dispatched keys revision 7 naming
   `762e5cd` when `main` was at `14b0267`; the lane based on the real head and disclosed it. **The keys
   lane has twice declined a false Manager premise** — once a file asserted committed when a basename
   glob had matched another lane's file, once this. **Verify Manager claims against `git log --all
   --diff-filter=A -- <exact path>`; full paths, never basenames.**

### Infrastructure this session

- **Penpot reachable at session start** (`getPages()` → `["Page 1"]`, all four `SM` boards located) after
  two sessions blocked on the token binding. **It went dormant mid-session** — the plugin tab is suspended.
  **G-18's board edit is blocked until it is re-focused.**
- **`git push` rejected 6/6 attempts** with `Internal Server Error` while `git ls-remote` kept working.
  Transient and remote-side; recovered on retry. **A rejected push leaves the commit safe locally** —
  verify `rev-list --left-right --count main...origin/main` before assuming a push landed.
- **F-16: `--ff-only` fails when untracked files shadow content already on `main`.** Hit twice — six files
  on the ADR lane, nineteen on the keys lane. **All were byte-identical.** A lane obeying that pre-flight
  blindly would have had to choose between refusing to start and deleting unchecked files. Compare by
  blob hash, back up outside the repo, move rather than delete.

## Round 4 — build side merged; Penpot transport exhausted

| task_id | result | note |
|---|---|---|
| implement-add-product-custody-and-footer | `IMPLEMENTED` → `DO_NOT_MERGE` (1 string) → `CORRECTION_COMPLETE` → **`APPROVE_CORRECTIONS`** | **MERGED as `c32f4f4`**, human-authorized |
| design-apply-f5-copy (r1→r4) | `DESIGN_REVISION_BLOCKED` ×4 | **0 of 76 mutations applied.** All four stopped correctly |

### The build-side merge — and the error behind it

`37aadc5` merged as `c32f4f4`, remote 0/0, **190/190 on the merged tree.** It closes four false
key-custody sites under `9417f8bf` (A3), deletes `_buildFooter` plus both `TechnicalDetails` notes under
`27ea6536`, and adds `showRule`/`disclosureAlignment` to the shared primitive so mobile's footer spec
becomes expressible.

**The engineering review returned `DO_NOT_MERGE` on exactly one string, and found the DISPATCH at fault
rather than the implementer.** My dispatch gave the eyebrow replacement as the 80-char
`ed25519 · generated on the server · …` and then forbade "the 80-char string" — conflating it with a
**different layer on a different board** (`BP · Rotate Key`'s `Art Sub`, 380px box). The approved value
was directly discoverable at `design-draft-f5-copy/report.md` **§7:299**, which even notes it is
**already correct on all 12 boards**. Three artifacts agreed; mine was the odd one out.

**Six of seven verify-items PASSED** and are worth recording because these are the checks that keep
mattering: the `:409-411` mid-page prose trap survived with all three proofs re-derived; the shared
primitive has **17 callers with 2 passing the new args and no regression**, `Expanded` kept on the
trailing-edge branch because dropping it would move the disclosure left on all 17; the gate failure the
implementer introduced was fixed at the delimiter with the rendered string byte-identical; the 69-file
phantom format failure was the pub-workspace hazard and `apps/server` is untouched; `_buildStatusRow` is
intact after its mid-course brace correction.

**Two corrections the review made to the implementer, both mine by proxy:** "`ed25519` appears nowhere
else on the page" is **false** — it renders at `:135`, displays at `:526`/`:1021` — so the divergence was
prose-only and less severe than reported; and "instructions cannot both be satisfied" mischaracterised a
self-inflicted dispatch error as an inherent conflict.

**Still unverified: the gates cover none of the visual outcome.** Zero of 26 test files import
`add_product_page.dart`; none reference `TechnicalDetails`. The `Expanded` invariant is asserted nowhere.
A follow-up, not coverage.

### Penpot — the board work is transport-blocked, and the session has now lost the MCP entirely

Four apply rounds, **0 of 76 mutations applied**, no unknown-state writes at any point. Each round stopped
rather than half-applying against a live shared file with **no version history** — the correct outcome
each time.

**The diagnosis moved twice and neither reading survived:**

1. **r1, r2** — tab dormancy, no cause identified.
2. **r3** — blamed **its own** heavy read (24 `findShapes` subtree traversals in one call). The next round
   was engineered around it: single-shape `findShapeById`, one shape per call, 76 calls inside one focus
   window.
3. **r4** — **falsified that.** The tab was dead before its first call, and
   `getPages().length` is a single scalar read that cannot starve a heartbeat. **Call weight was never the
   cause.** One-shape-per-call remains correct discipline; it is simply not sufficient.

**And now the constraint has moved again: the Penpot MCP server has disconnected from this session
entirely.** `penpot_execute_code` is no longer in the toolset, and `list_mcp_resources` /
`list_mcp_resource_templates` both return empty — where the pre-Gate-D4 baseline recorded `figma-desktop`
and `postgresql` as available. **No lane can be dispatched with those tools, and neither can the
Manager.** This is a session-level disconnection, not tab focus, and it is not recoverable from inside
the session.

**Everything the next round needs is already recorded, so nothing needs re-deciding or re-deriving:**

- 24 copy proposals, **human-approved**, with measured fit per layer
- the 52-layer footer census verified **twice**, naming-independent, at y = 862×48 + 910×2 + 926×2
- the `Disclose` baseline as a **pair** — 116 exact + 4 `Disclose · single footer row` = 120. **A
  strict-equality count reads 116 and would falsely report four missing layers.**
- exact layer ids, boxes, fonts and positions for all 24 copy targets
- three pre-write safety facts no earlier lane checked: **no flex/grid on any target board**, all targets
  `growType: fixed`, every prefix resolving to exactly one candidate
- the human's `R Submit Sub` ruling: option (a), apply as drafted, **do not resize**

### Penpot connectivity check — 2026-10-07, late session

**Penpot reconnected and responded, then died again inside the same check.** Sequence as observed:

1. `penpot_high_level_overview` — returned its full document. **This proves nothing**: two lanes
   independently established it is not a health check.
2. `execute_code` → `getPages().length` → **`1`**. **Liveness confirmed by the correct probe.**
3. `execute_code` → naming-independent footer sweep → **`52` layers, y = 862×48 + 910×2 + 926×2,
   root children `164`** — byte-identical to the recorded census.
4. `execute_code` → `Disclose` count → **timed out** (`-32001`).
5. Retry → **`no heartbeat for 69s`**.

**What this establishes, and what it does not.**

- **No partial state exists from the four blocked rounds.** The footer census is unchanged at 52 and
  root children at 164, confirming what the rounds each reported: 0 mutations applied, no unknown-state
  writes to reconcile.
- **The recorded `Disclose` baseline of 116 + 4 = 120 stands unverified by this check**, but nothing was
  deleted in any round, so no damage is possible.
- **Liveness is intermittent, not restored.** A window of roughly 2–3 calls opened and closed. That is
  the behaviour r4 diagnosed: the tab dies between windows rather than staying dead, which is why three
  rounds each reported a *new* first-call failure.

**The operational lesson for the next dispatch** — one probe, then act immediately on already-recorded
ids, with **no re-derivation at all**:

- `findShapeById` on the ids already in `design-apply-f5-copy/report-r3.md`. **No `findShapes` traversal,
  ever** — a traversal is what plausibly stalled the heartbeat in r3, and there is no reason to spend the
  window rediscovering what is recorded.
- Apply the **24 copy proposals first** (they are the security-relevant ones), then the **52 footer
  deletions**.
- After each write, one `findShapeById` read-back. **A write timeout still does not mean the write
  failed** — read that shape before deciding, which is cheap with `findShapeById`.
- Check `Disclose` (116 + 4) **before the first `remove()` and once at the end.**

### ⚠ CORRECTION — "zero mutations" was wrong, and the Manager's own verification missed it

`design-apply-f5-copy` r5 found, and the Manager has now **confirmed directly**, that **at least 3 of the
24 approved copy proposals were already applied** — with no report claiming them.

Confirmed by the Manager, reading the live file:

| layer | live text | status |
|---|---|---|
| `BP · Rotate Key · Dark` `Art Sub` | `Generated on the server · the private half stays in the secret manager` | **string H — applied** |
| `BP · Rotate Key · Dark` `Tech 0` | `GIT_PRODUCT_PR_SHIP_SSH · ed25519 · private half in the secret manager, never shown` | **applied** |
| `BP · Rotate Key · Dark` `L Sub` | `A new keypair is generated on the server. You install the public half, then work resumes.` | **string F — applied** |
| `BP · Rotate Key · Light` — all three | **identical to Dark** | **applied** |

**So ≥6 of the 24 are done, and 18 remain unexamined.**

**How this survived four rounds of "0 applied" plus an independent verification.** The Manager's
connectivity check re-verified **52 footer layers, the y-distribution, and root children 164** — all
**footer and page-level** figures. **The 24 copy layers were never among them.** A careful verification of
the wrong quantity is not a verification; this is the same failure class as the ADR's §Status claiming
review had not happened, and as `9417f8bf:116-119` being 43 lines off: **a check that confirms a
neighbouring fact is not a check of the one at issue.**

**Attribution is not established and is not guessed here.** Five reports and the git history record zero
mutations; the file records six. No lane is accused. Note that the drafting lane had **no write grant**
and reported zero mutations, and the strings match its proposals verbatim — which is suggestive of
something, and Penpot has no version history, so it is not provable from inside.

**What r5 did that was right, and is the reusable part:** its writes were placed behind a **pre-write
guard asserting the recorded pre-state AND the absence of the post-state**, so all three writes
**declined at the guard before the assignment statement**. There is therefore **no unknown-state write**,
provable from the guard code. That guard fired with **no timeout to trigger it**, which is the whole point:
it catches a silent concurrent edit that a timeout check cannot.

**Also established this round:** **24 × O(1) `findShapeById` timed out too**, so r3's prescription was
necessary but not sufficient — the safe batch is below 24, traversal or not.

### State the next lane must read before writing

- **≥6 of 24 copy layers already applied** (the `BP · Rotate Key` pair, all three layers each).
- **18 copy layers unexamined** — not "unapplied", *unexamined*.
- **52 footer deletions outstanding.** `Disclose` untouched at its recorded **116 + 4 = 120**.
- **Build is merged** (`c32f4f4`), which **inverts the divergence**: the boards are now the *sole*
  remaining surface asserting the false claim. That raises the cost of writing, not lowers it.
- **Guard every write on pre-state AND absence-of-post-state**, and report any layer found already
  correct as a finding rather than as a no-op.

### ⚠ r6 — the arithmetic, not the discipline, is now the problem

r6 got past the probe **for the first time in six rounds**, started a 6-shape guarded batch on
`BP · Rotate Key`, and it **timed out**. Because that call contained writes, those 6 layers are
**UNKNOWN, not clean.** Its read-only recovery call then timed out identically, and the probe reported
72s dormancy. **0 of the 24 copy layers were read.**

**The Manager verified the in-doubt layers directly:** `BP · Rotate Key · Dark` still reads 114 children
with `Art Sub` = `Generated on the server · the private half stays in the secret manager`. **So the 6
in-doubt layers carry the approved strings either way** — the guarded writes declined or landed
identically, and neither is harmful.

### Two findings that change the next lane's design

**1. The safe batch is now bracketed on both sides.**

| batch | result |
|---|---|
| 12 × O(1) reads (r3) | passed |
| 24 × O(1) reads (r5) | **timed out** |
| 6 × O(1) **read+write** (r6) | **timed out** |

**The unit is one shape per call.** At roughly **4 productive calls per window**, 76 mutations need
**~20 windows.** That is arithmetic, not a discipline problem, and continuing to dispatch one round per
window will consume the session without finishing.

**2. A read-only recovery call is NOT cheaper than the write call it follows.** r6's recovery read did
strictly less work and timed out identically. That **upgrades a write-timeout from "slow" to "unknown and
not cheaply recoverable"** — and it **inverts the copies-first priority order: verify-then-write beats
write-then-reconcile here.**

### What is durable work product from r6, despite the blocked result

The complete **18-needle substitution table** and the **6-clause guard**, with the
**derivation-by-substitution rule** — which is why the damaging branch of the guard would still land on an
approved string rather than a corrupt one. That inference is what makes the 6 in-doubt layers low-risk,
and it is **labelled inference, not measurement.**

### Standing state, unchanged and now precisely known

- **≥6 of 24 copy layers already correct** (`BP · Rotate Key` pair, all three layers each) — owned by no
  report. The other **18 have never been examined by anyone.**
- **52 footer deletions outstanding.** `Disclose` untouched at **116 + 4 = 120**.
- **Build merged at `c32f4f4`** — the boards are the **sole** remaining surface asserting the false claim.

### ✅ r7 — the copy half is COMPLETE. Zero false custody layers remain on the page.

**17 of 24 written and confirmed by settled read-back**, 1 found already correct (its write **declined**
by the guard), 6 Manager-verified and untouched. **19 assignments, 0 failed, 0 UNKNOWN** — the **first
provably clean ledger in this work item**, achieved by ordering fit read-backs last so every write had
already returned before the window closed.

**Manager verification, independent and direct:**

```
secretManagerLayers          : 28    (24 applied + 4 pre-existing on the SM boards)
remainingFalseCustodyLayers  : 0     needle: keychain | created on this device |
                                      generated here | never leaves the
```

**So all 24 approved copy proposals are now applied. The security-relevant half of F5 is DONE.**

⚠ **My first verification needle was too broad** — `/this device/i` returned **114** "hits" that were
mostly **`Rail Identity` / "Signed in on this device"**, which is authentication, not key custody. A
caller who had taken the 114 at face value would have concluded almost nothing had been fixed. **The
narrowed needle returns 0.** Recorded because a too-broad needle reads as a near-complete failure and
would have sent the next lane chasing the wrong 114 layers.

**The footer half is the only thing left, and it is intact:**

```
footerText (type text, name "Footer") : 52     ← all 52 outstanding, zero deleted
footerRule (rectangles)                : 76     ← dividers, NOT in scope
discloseExact                          : 116
discloseSuffixed ("Disclose · …")      :   4
                                       ────
Disclose total                         : 120    ← precondition intact, undisturbed
```

### r7's findings worth keeping

**r6's inherited substitution table was defective and r7 caught it in-window.** Rows 7–8 replace
`this device's keychain` with `secret manager` — **dropping the article "the"**, giving 93 chars where
approved string **A** is 97. **It applied it verbatim, the read-back showed it, and it corrected on the
next call.** Blast radius had the read-back not existed: **4 layers of non-approved copy**.

**Generalisable, and it corrects r6's own framing:** *derivation-by-substitution guarantees you land on
a **deterministic** string, not an **approved** one. The replacement column must be validated against the
draft and its length asserted.* The same lane found r6's row 15/16 would have **typed an em dash** into
`R Submit Sub`, which it measured as pure ASCII — and derived it by code point with a numeric assertion.

**The unowned partial application is LAYER-scoped and Dark-side-first, not board-scoped.** That Dark
board's `L Sub` was already correct while its **Light twin was still false**, and the **same Dark board's**
`F V 0` and `Act What 0` were **both still false**. **No automated lane leaves a board 50% done and its
progress unreported** — which weakens the "a lane wrote these and misreported" reading and leaves the
attribution genuinely open.

**My "~20 windows" estimate was falsified.** r7 landed **17 mutations in 46 calls** — the longest window
yet, and the one-shape-per-call bracket r6 reported was **looser than stated**: what actually held was
**no traversal, `findShapeById` only, and verify-then-write.** A larger batch is not claimed; the
discipline is sufficient and the batch limit is looser than believed.

**`R Submit Sub` measured for the first time: 2 lines, 10 px overflow, identical before and after** — so
the box defect is **provably not dischargeable by a copy-only change**, which settles the option (a)/(b)
question on evidence.

### ⚠ The blocker on the remaining 52 is MINE, and it is one word

r7 deleted nothing because **two instructions from me cannot both be satisfied**: the `Disclose` 120
precondition "must precede the first `remove()`", and I simultaneously **forbade `findShapes`
traversal** — while the precondition requires a page-wide count. It took the conservative branch and
deleted nothing, which was right. **Authorising one read-only name-scoped census unblocks all 52.**

### ✅✅ F5 COMPLETE — all 52 footer deletions applied. Board half closed.

**All 52 of 52 deleted, ids not reached: NONE.** Split **862 ×48, 910 ×2, 926 ×2**, matching the
precondition census exactly. **63 `execute_code` calls and the window never closed** — no heartbeat
error, no dormancy, no recovery probe. The first round in this work item to run to completion.

**Manager verification, independent and page-wide (not per-id, because a per-id check cannot prove a
layer no lane ever held an id for is gone):**

```
footerAnyType (name === "Footer")        : 0     ← all 52 deleted; zero of ANY type remain
footerRule  (rectangles)                 : 76    ← dividers untouched
remainingFalseCustody (needle as before) : 0     ← still zero
```

**So both halves of F5 are done: 24/24 copy proposals applied, 52/52 footers deleted, zero false
custody layers and zero footer copy anywhere on the page.**

**Precondition honoured and proven:** `Disclose` **116 exact + 4 `Disclose · single footer row` = 120
before and after**, byte-identical. **A strict-equality count alone reads 116 and would falsely report
four missing layers** — that trap has now been documented in three separate reports.

**The type check made the delete set structurally safe, not merely guarded.** With `name === 'Footer'` as
the predicate, **the 76 `Footer Rule` rectangles were unreachable by construction** — a prefix sweep would
have matched all 76 and put every divider in the delete set.

### Three disclosures from the deletion lane, none buried

**1. A second defective inherited artefact.** **r3's recorded layer id is wrong** — `…b4919c7d0ca57f`
against actual `…b4919d0ca57f`. Treating the `ABSENT_ALREADY` result as "already deleted" would have
**left 1 of 52 behind silently**. Second time an inherited id list was defective in this work item, after
r6's substitution table — **the recurring lesson is that an artefact produced by one lane is a premise,
not a fact, and must be re-verified at point of use.**

**2. Four write timeouts, and all four had landed** — resolved by **read, not re-apply.** This was only
safe because the parent-anchored form is idempotent by construction: **`remove()` does not throw on an
absent shape, so an id-based retry would have returned a false `REMOVED`** and inflated the ledger.

**3. Transient lookup staleness.** `findShapeById` returned `null` for ids **the live shapes themselves
had just reported**, on rows 29–32. Re-anchoring on the parent board and matching the child by name
recovered all four. **A `null` from `findShapeById` is not proof of absence** — the same failure mode as a
write timeout, on the read side.

### The Manager's ruling it flagged rather than absorbed

It ran **two** traversals, not the one authorised: the after-count cannot be obtained by
`findShapeById`, and deliverable 1 requires it. **It flagged this as a Manager ruling to be made rather
than passing it silently.** Correct: it exceeded a narrow grant, said so, and the excess was necessary to
produce the proof that the disclosures survived. **Recorded so the ruling is not retro-fitted.**

### What remains, precisely

- **The BUILD still asserts the footer copy** — 11 sites in 10 files. **The boards and the build have not
  converged.** The board half of G-18 is closed; the build half is the remaining half.
- **r7's `R Submit Sub` box overflow** — 2 lines in 352×15, 10px, measured and provably **not**
  dischargeable by a copy-only change. The only remaining defect on the two `No key` boards.
- **Keys revision 7 and ADR revision 5** corrected but never re-reviewed.
- **The feature implementation remains unblocked.**

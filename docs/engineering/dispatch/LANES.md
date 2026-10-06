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

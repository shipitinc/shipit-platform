# DECISIONS.md — index of Human Decision objects

Objects live under `.decisions/`. State machine and schema per
`docs/engineering/HUMAN_DECISIONS.md`.

| decision_id | type | status | blocks | created_at |
|---|---|---|---|---|
| 130f3a7e-c364-4c1e-acd5-409d7af80675 | INFRASTRUCTURE | RESOLVED (OPTION_C) | FEATURE c46b6807 baseline | 2026-10-05T00:11:28Z |
| 70b47372-8814-4098-81b2-6614497bad12 | OTHER_CONSEQUENTIAL | PENDING (premise refuted by review; recommendation superseded to OPTION_C) | Product baseline 0d5d132 integration, transitively FEATURE c46b6807 | 2026-10-05T01:01:56Z |
| 048f3367-5836-43c8-af05-747dbc9d3afd | SECURITY | RESOLVED (OPTION_C — fix and add authentication) | Committed Postgres superuser credential + unauthenticated control-plane API | 2026-10-05T01:42:04Z |
| 73097d48-3e8b-48d7-b3d8-8834168c5113 | PRODUCT | RESOLVED (OPTION_A — real key generation, fold scope) | Add Product rebuild: mobile SM boards, host-trust transition, points 2a-2f | 2026-10-06T08:50:42Z |
| b869ec24-236e-4e9c-8703-70656fa368c4 | ARCHITECTURE | RESOLVED (OPTION_A — server-side key service) | Deploy-key generation and storage location | 2026-10-06T08:57:01Z |

## Add Product rebuild — Gate D4 decisions filed 2026-10-06

All five are `PENDING`, created by `orchestrator-main` per `aef-orchestrator` §13 Phase 1. Objects in
`.decisions/`.

| decision_id | type | question (one line) | source |
|---|---|---|---|
| `9417f8bf-73b8-4827-9515-bdfe92e5a9d5` | SECURITY | Does b869ec24 supersede ADR 0018 `:85-88`'s local-secret-store clause — and what becomes of "never persisted to the durable record"? | **REISSUED** from "which substrate?" after the keys review found ADR 0018 already names A1+A4 and forbids A2. **The decision the human explicitly reserved.** |
| `7b1bc8b7-6cd1-4ddc-a94f-366de2bed38a` | SECURITY | When protection cannot be established, refuse to mint or mint with a warning? | keys lane `OPEN-D4-1` Q2 — unaffected by the reissue |
| `79e860e2-4edf-4510-8d5f-435460255848` | SECURITY | Does ADR 0018 `:113-114` ("no Shipit-side action") survive the custody move — and if not, how is the private half disposed of? | **RESTATED as Q3′**; `b869ec24` is silent on revocation, so the supersession question is the real content |
| `898b07d0-e848-4774-8007-f4dacbd89c78` | ARCHITECTURE | ADR 0018 `:100-102` makes human point 2b settled architecture, and it is unsatisfiable. Which resolution? | **REFRAMED** as an ADR contradiction, severity raised. Found by the lane, not requested by the human |
| `27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0` | DESIGN | Does human point 2f's footer-copy removal apply to desktop too? | mobile lane `B3` — unchanged |

**Also filed: `fix-credential-store-integrity` GAP-2** — the D-2 partial unique index exists only in
`apps/server/tool/schema_bootstrap.sql`, and `schema_bootstrap.dart` is wired into `Makefile:228` and
`integration.yaml:131` only, so **no QA/staging/production path runs it**. A chain-migrated database
therefore does not get the index, and the "one active credential per repository" invariant does not reach a
deployed database. The repository's own parity contract (`schema_bootstrap.sql:37-44`) calls that asymmetry
"the defect this file exists to remove", and the identical shape
(`design_revision_approved_unique_per_workitem`) was solved by putting the index in **both** the bootstrap
**and** `migrations/20260920232118956/migration.sql`. Closing GAP-2 needs `apps/server/migrations/**`, which
is prohibited — see the Human Decision filed with it.

Recorded as **design-system-owner notifications** rather than escalated (Level 1 is AUTO with
notification per `DESIGN_GOVERNANCE.md`): the Penpot board-naming convention conflict, and
`ShipItPalette.negative` failing WCAG AA on dark (4.02:1 canvas / 3.68:1 card, measured).

Previously resolved and unchanged: `130f3a7e-c364-4c1e-acd5-409d7af80675` (INFRASTRUCTURE),
`048f3367-5836-43c8-af05-747dbc9d3afd` (SECURITY), `70b47372-8814-4098-81b2-6614497bad12`
(OTHER_CONSEQUENTIAL), `73097d48-3e8b-48d7-b3d8-8834168c5113` (PRODUCT),
`b869ec24-236e-4e9c-8703-70656fa368c4` (ARCHITECTURE), `570bb640-76e1-485d-9a80-309b07585ccd`
(DEPLOYMENT_AUTHORITY — API authentication deferred with a blocking production precondition; the
"local only" scope must be ENFORCED, and its loopback-pinning follow-up is verified still un-implemented).

**Not amended:** `b869ec24`'s evidence records "0 existing deploy-key infrastructure", which is false —
the grep used the wrong identifiers. The audit trail is immutable, so the correction is recorded in
`WORK_STATE.md` and in the dispatch ledger instead. The decision's *conclusion* is unaffected and in
fact strengthened.

## RESOLVED 2026-10-06 — Gate D4

All six PENDING decisions resolved by the repository owner through the structured question UI. Tamper-check
performed on each: `selected_option` matches an `option_id` as presented, with one recorded deviation (below).

| decision_id | outcome | binding consequence |
|---|---|---|
| `9417f8bf` | **OPTION_C** — supersede ADR 0018 `:85-88`, use **A3, an external secret manager** | ADR 0018 `:85-88` is SUPERSEDED and must be amended. **A2 permanently excluded.** **G-7 becomes required**: under A3 the `referenceName` reference *is* the sensitive artifact, so `RepositoryCredentialView` must stop exposing it |
| `7b1bc8b7` | **OPTION_A** — fail closed with named remediation | Remediation copy is a **required deliverable**, not a nicety. Under A3 the substrate is a runtime dependency, so this path is common rather than edge |
| `79e860e2` | **OPTION_A** — destroy the private half on revoke, keep the row | "Destroy" = delete the manager handle. **ADR 0018 `:113-114` is SUPERSEDED**: revocation now has a ShipIt-side action |
| `898b07d0` | **OPTION_A** — split identity from registration | **ADR 0018 `:100-102` is UPHELD, not contradicted** — human point 2b becomes satisfiable. Known accepted trade: a visible product may exist with no usable credential |
| `4d2c6b81` | **OPTION_A** — add the index to the migration chain | Requires a **NEW migration** (no template exists — the prior instance ran the other way). A duplicate-credential audit must run **before** it, because `CREATE UNIQUE INDEX` fails on existing duplicates |
| `27ea6536` | **OPTION_A + recorded deviation** — see below | Per-platform footer spec from the boards, not from either lane's reading |

### The footer decision — the human corrected both lanes

The human checked the Penpot boards directly and reported, verbatim:

> "I believe you're mistaken. `S · Add Product · Unknown host · Light/Dark` and `S · Add Product · Verified ·
> Light/Dark` Do not have the disclosure in their footer. Only a divider, and a righ aligned Show technical
> details text button. I just checked. Our Add product desktop should be the same way. `BPM · Add Product ·
> Light/Dark` have Show technical details button left align with now divider. Stay true to both designs in
> Penpot and in code."

**Recorded as a deviation from the presented options rather than forced into an `option_id`.** Both options
as presented assumed a shared footer structure; the human established that the two platforms genuinely
differ, and that the boards — not either lane's reading of them — are authoritative. The design lane's
reading of a `Footer` layer at (236,862) on the desktop boards is treated as a misidentification.

Governing spec: **desktop** = divider + right-aligned `Show technical details` text button, no copy;
**mobile** = left-aligned `Show technical details`, **no** divider, no copy.

### ADR 0018 is now partly superseded — a follow-up is owed

`:85-88` (custody) and `:113-114` (revocation) are superseded by the human's answers. `:100-102`
(registration gated on a proven connectivity check) is **upheld** and becomes satisfiable. Owner: the human,
as ADR owner.

## Resolved after the merge — three more, 2026-10-06

| decision_id | type | outcome | note |
|---|---|---|---|
| `ae1c1f79-338c-4d8f-97e0-452adaed021d` | ARCHITECTURE | **OPTION_A — refusal creates nothing** | Created RESOLVED, not PENDING-then-resolved. Exists because **two already-resolved decisions interacted and neither addressed the other's row**: `7b1bc8b7` scopes its fail-closed refusal to the credential and is silent on the `Product` row, while `898b07d0` makes that row the flow's first step. Design Revision 3 finding D-19 escalated it rather than deriving it |
| ADR 0018 A2 status | ADR OWNER | **Accepted, with four gaps recorded as accepted** | The amendment lane deliberately did not mark it Accepted — that is the ADR owner's call. Now given |
| `AGENTS.md` §13 | GOVERNANCE | **Written, with §13a and the §13b carve-out** | §13 was quoted verbatim by ADR 0018 and depended on by ADR 0012:34 and ADR 0019:121, yet did not exist in the file. The wording restored is what ADR 0018 already quoted — a restoration, not new policy |

**Why D-19 was worth asking rather than deriving.** `898b07d0` was accepted with a known trade: leaving
early leaves a **visible product with no usable credential**, accepted because step 1 makes the mint
satisfiable and so honours human point 2b. If the substrate fails instead, that same bad state appears with
**none of the benefit that made it acceptable** — an infrastructure outage leaves a persistent, visible
artefact the user cannot complete. That is the dead end human point 2d rejected, reached by a different route.

## Index correction — `70b47372` is RESOLVED, not PENDING

The table row above still read `PENDING (premise refuted by review; recommendation superseded
to OPTION_C)`. The **object** at `.decisions/70b47372-8814-4098-81b2-6614497bad12.yaml` reads
`status: RESOLVED`, `selected_option: OPTION_B`, decided `2026-10-05T10:30:58Z`. The index was
stale; the object is authoritative. **No decision was actually pending** — corrected here so the
next session does not re-present a settled question.

## Three decisions filed 2026-10-08 — all PENDING, created by `orchestrator-main` per `aef-orchestrator` §13 Phase 1

Raised by the QA bring-up and the H-R2 custody close. None blocks safe dispatchable work; each
records a choice the Manager may not make unilaterally.

| decision_id | type | question (one line) | source |
|---|---|---|---|
| `1ed57d5d-b1d4-4956-a428-0cf4df98bc6b` | DESIGN | Product Detail `:614` ships a string no board scopes to that slot — ratify, commission board copy, or drop the subtitle? | H-R2 close, open finding **F1** |
| `cff0e948-80a5-48ab-9a7b-f2a99be6f870` | OTHER_CONSEQUENTIAL | 44 of 54 goldens pass only because their delta is inside the 0.005 tolerance — add a domination check and regenerate, or defer? | golden refresh, open finding **N2** |
| `6d2bfffe-1631-498a-b053-4edaf8bd3048` | INFRASTRUCTURE | A database carrying the hand-maintained objects cannot satisfy the analyzer, so boot fails — document plus preflight, restructure startup, fix the generator, or recreate per migration? | QA bring-up, two-fault diagnosis |

None of the three is a `G1`–`G5` gate violation or a stop condition for the Add Product
orchestration: safe lanes continue while they are pending.

## Resolved 2026-10-08 — all three, via the structured question UI

| decision_id | selected | one-line effect |
|---|---|---|
| `1ed57d5d-b1d4-4956-a428-0cf4df98bc6b` | **OPTION_A** | `:614` **ratified as an accepted deviation**. Bounded: applies to this slot only, does not license composing shipped copy elsewhere, and a future board pass **supersedes** rather than merely aligns with it. Key A's `— never shown, logged or stored` explicitly NOT extended without a board pass. |
| `cff0e948-80a5-48ab-9a7b-f2a99be6f870` | **OPTION_A** | Add a tolerance-domination CI check **and** regenerate the 44 stale goldens. Comparator itself untouched — it classifies, it does not weaken. |
| `6d2bfffe-1631-498a-b053-4edaf8bd3048` | **OPTION_B** | **Restructure server startup** so the bootstrap runs after the analyzer — **the human's choice, not the Manager's recommendation**, and the more invasive option. |

**On `6d2bfffe`, recorded because it departs from the recommendation.** The human chose to remove the
failure entirely rather than make it actionable. That is sound reasoning and it is honoured. Two
consequences are accepted explicitly rather than discovered late:

- Compose and entrypoint ordering are **production-promotion-affecting**. `AGENTS.md` § Shared Docker
  state records that a compose file with no explicit project name resolves to project `docker`, which is
  the **live QA stack's project** — so a careless edit here reaches the stack this repository has already
  lost a database to. **Design and independent review precede implementation**; this does not run as a
  direct implementation lane.
- Verification cannot be done on the current fresh QA database, because a fresh database has none of the
  hand-maintained objects and therefore does not exhibit the fault. The failing behaviour must be
  reproduced in a **disposable** environment first — never the live QA stack.

All three tamper-checks pass: each `selected_option` is one of the option_ids as originally presented, and
no question or option was altered after presentation.

## Two more decisions filed 2026-10-08 — both PENDING

Raised by continuing after the first round, not by the first round itself.

| decision_id | type | question (one line) | source |
|---|---|---|---|
| `30c00e6e-4168-44e0-8d1e-34d7de7e4c46` | INFRASTRUCTURE | Design Revision F38E4B34 is RISK_LEVEL 3 and needs Gate D4 — accept that the analyzer stops gating QA boot? | `design-qa-startup-restructure` |
| `3e9dfb75-7bdf-4a8c-89dd-c76779a65371` | INFRASTRUCTURE | Golden gate needs a rendering environment CI does not provide — land the 40 baselines now and hold the wiring, or ship the gate anyway? | `review-fix-golden-domination-n2` (`DO_NOT_MERGE`, `HUMAN_DECISION_REQUIRED: YES`) |

**Manager self-correction, recorded.** Both worktrees were dispatched at `1657082`, which predates
the resolution commit `a8a990b`, so each lane's worktree showed its decision as `PENDING`. **Both
agents detected this independently and worked against the resolved object rather than the stale copy**
— one recorded it as `DL-4`, the other verified against `main`. The dispatch base was wrong; the lanes
were right. Both branches were rebased onto `a8a990b` and the rebase verified content-neutral
(all 45 changed files byte-identical blobs), so their reported provenance is now sound.

**What the two lanes found that the Manager's own framing had wrong**, recorded because each refuted a
premise the dispatch asserted:

- The golden staleness count is **40, not 44** — four of the 44 were byte-identical to a fresh render.
  Absence-of-badge is not a staleness test. Nor is presence-of-badge a coverage count: **26** goldens
  carry a badge, not 54, because 26 desktop frames render the count as text in the sidebar rail rather
  than as an 18x18 disc.
- **The golden suite was never run by any CI job** — 0 of 5 workflows, and `pubspec.yaml:87-98` already
  documented it as unreachable from melos. The tolerance was not merely hiding drift; nothing was
  checking. That is a pre-existing gap now re-activated, not a surprise.
- The startup fault's **ordering premise does not survive Serverpod's source**: `verifyDatabaseIntegrity`
  is called outside the `applyMigrations` guard, and the only fatal branch is `runMode == 'development'`.
  The bootstrap already runs in `test` mode and has always tolerated the mismatch. On a chain-migrated
  database the analyzer never passes, so "run the bootstrap after the analyzer" is unsatisfiable as
  literally written.
- **`docker/compose.qa.yaml` applies no bootstrap at all** (0 references under `docker/`). A fresh QA
  database is silently unenforced — analyzer-clean while missing all six hand-maintained objects. The
  analyzer passing is currently evidence of an un-enforced schema, not a correct one.

## Resolved 2026-10-08 (second round) — via the structured question UI

| decision_id | selected | effect |
|---|---|---|
| `30c00e6e-4168-44e0-8d1e-34d7de7e4c46` | **OPTION_C** | Design Revision F38E4B34 **rejected at Gate D4**. Re-sequencing refused; the analyzer keeps gating. **This reverses `6d2bfffe` OPTION_B** — marked SUPERSEDED IN PART in that object. |
| `3e9dfb75-7bdf-4a8c-89dd-c76779a65371` | **OPTION_C** | Pin CI to the exact rendering environment (**macOS arm64 + Flutter 3.44.7**) and make it a **checked precondition** the check enforces before grading. Neither split nor predicted-red. |

**The reversal is the substantive event.** On the first pass the human chose OPTION_B — restructure
startup so the bootstrap runs in a mode where the analyzer does not gate — on a described cost. On the
second pass, with the cost visible as a fact (in QA the analyzer stops gating boot, so model-derived
drift surfaces only as a log warning), the human reversed it and kept the safety property, landing on
the generator change this repository had classified HIGH risk and originally declined. That is a
considered change of position, not an inconsistency, and both states are recorded.

One benefit of the reversal, recorded because it is not obvious: teaching the generator to emit the
hand-maintained objects into `definition.sql` means a database **missing** them fails the analyzer
instead of passing it. That turns DL-2 — compose.qa.yaml applies no bootstrap, so a fresh QA database is
silently unenforced and looks correct — from a false assurance into a loud failure. DL-2 is not thereby
fixed: `compose.qa.yaml` must still be made to apply the bootstrap, or every fresh QA boot fails loudly
instead of silently starting unenforced. Loud failure is better; it is still a failure.

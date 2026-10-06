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

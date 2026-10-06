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
| `9417f8bf-73b8-4827-9515-bdfe92e5a9d5` | SECURITY | Which substrate holds the server-stored private half? | keys lane `OPEN-D4-1` Q1 — **the decision the human explicitly reserved** |
| `7b1bc8b7-6cd1-4ddc-a94f-366de2bed38a` | SECURITY | When protection cannot be established, refuse to mint or mint with a warning? | keys lane `OPEN-D4-1` Q2 |
| `79e860e2-4edf-4510-8d5f-435460255848` | SECURITY | On revocation, is the private half destroyed, retained, or grace-perioded? | keys lane `OPEN-D4-1` Q3 |
| `898b07d0-e848-4774-8007-f4dacbd89c78` | ARCHITECTURE | How is the registration-ordering circular dependency resolved? | keys lane `OPEN-D4-2` — **found by the lane, not requested by the human** |
| `27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0` | DESIGN | Does human point 2f's footer-copy removal apply to desktop too? | mobile lane `B3` |

Recorded as **design-system-owner notifications** rather than escalated (Level 1 is AUTO with
notification per `DESIGN_GOVERNANCE.md`): the Penpot board-naming convention conflict, and
`ShipItPalette.negative` failing WCAG AA on dark (4.02:1 canvas / 3.68:1 card, measured).

Previously resolved and unchanged: `130f3a7e` (INFRASTRUCTURE), `048f3367` (SECURITY),
`570bb640` (DEPLOYMENT_AUTHORITY), `70b47372` (OTHER_CONSEQUENTIAL), `73097d48` (PRODUCT),
`b869ec24` (ARCHITECTURE).

**Not amended:** `b869ec24`'s evidence records "0 existing deploy-key infrastructure", which is false —
the grep used the wrong identifiers. The audit trail is immutable, so the correction is recorded in
`WORK_STATE.md` and in the dispatch ledger instead. The decision's *conclusion* is unaffected and in
fact strengthened.

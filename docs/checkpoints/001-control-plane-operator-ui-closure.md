# CLOSURE — CONTROL_PLANE_OPERATOR_UI_001

| Field | Value |
|---|---|
| **Feature ID** | `CONTROL_PLANE_OPERATOR_UI_001` |
| **Status** | **COMPLETE** (2026-09-16) |
| **Human QA decision** | `APPROVE` (in person, 2026-09-16) |
| **Gate** | `HUMAN_QA_REQUIRED` → satisfied |
| **Source package** | `docs/checkpoints/001-control-plane-operator-ui-human-qa.md` |
| **Design authority** | Penpot `d8ac01df-6646-81d2-8008-a366c09aa9d3` / page `d8ac01df-6646-81d2-8008-a366c09aa9d3`, team `c828d3cf-7d4e-8145-8008-98dfd6576a0c`, IMPLEMENTATION_AUTHORITATIVE (frozen 2026-09-14; `ADOPT_PLAIN` 2026-09-15) |
| **Implementation baseline** | Git working tree at HEAD `6584e7d` (restructure + feature work uncommitted) |

---

## 1. HUMAN QA DECISION (truthful per-revision record)

| Field | Value |
|---|---|
| HUMAN_VISUAL_REVIEW | `APPROVED` |
| HUMAN_QA | `APPROVED` |
| GOLDEN_BASELINE_APPROVAL | `APPROVED` |
| AI_PIXEL_REVIEW | `SUPERSEDED_BY_HUMAN_VISUAL_APPROVAL` (NOT recorded as PASS — an independent AI pixel review did not occur in the closure run) |

The APPROVE is bound to the exact implementation/design revision reviewed and
the golden baselines bound to it; it does NOT generalize to future changes.

---

## 2. GOLDEN AUTHORITY — approved baselines (20, SHA-256 verified 2026-09-16)

Golden tests compare within the 0.5% tolerance defined in
`test/helpers/golden_tolerance.dart`.

| SHA-256 | Golden file |
|---|---|
| `45f8b48ce1b9df9914f0abf31c30f8d6c9d5bf9ce1a35dabf78aa67a70869a6f` | `all_work_dark.png` |
| `db4dea7d297d6d910feaa4defb065ee3fc1540309317b2701480d66021c1c61f` | `all_work_light.png` |
| `e7687946b4a233ab8247ba7f933352c9c603bcbed2477002483a60f0a0930023` | `decision_detail_dark.png` |
| `69b6bdc157febb11e813a2cd87dcbd578114b83145aa49a7a77f2c7d9d30a8d4` | `decision_detail_light.png` |
| `367733f54e2f999f486a4fe72cde909fbfe09e25e39f8351f54008045ab35d93` | `mobile_all_work_dark.png` |
| `fa6447d41fce83b93cb4bb2e25ad5d54b1b4f738b483cb5b2eb9f158dcc91861` | `mobile_all_work_light.png` |
| `cffaef4e1c0487cf73a5e16ae3dd9100b15b10e403a7288b9b36a324fa2bd46c` | `mobile_decision_detail_dark.png` |
| `ddca8fdb348dd82937f91d1278e5bbaff62102fd9d50446cb79d3efad3d733b0` | `mobile_decision_detail_light.png` |
| `974bf7987b1d75ad9813e90a1ae5c5a3eb3d2108cf661ba6991388895e19bea9` | `mobile_needs_you_dark.png` |
| `9ee7f68ff85e14418b30e8bc8b68082f0e8ec74db709528d058eb99c20e209a3` | `mobile_needs_you_light.png` |
| `b5680a66990ea28b675d6e9f489b836fe37d6f0e88c84d7d29880b40a15141c1` | `mobile_overview_dark.png` |
| `75efc660079743f91e6e695139774eaf222421577c1add372164c42505891333` | `mobile_overview_light.png` |
| `025ac3a5556d560896a94f8063443b0bb9bbc67beeede057c161ce3680f4f9b5` | `mobile_run_detail_dark.png` |
| `4745b31ba8a3b3d7b4a199941569b9b4f8234e6808b6e464fe89162e1cce53b0` | `mobile_run_detail_light.png` |
| `fe69cc5fccd1bff6a090df19e726a69e20f23179010abbda126e986ae9e91da9` | `needs_you_dark.png` |
| `3c8ba07056a6dc1bb5c89f19fe6211e334ea3e9de80adb327e2b1ab188dccf0e` | `needs_you_light.png` |
| `64567aed652fd1596733ccdc5a13a46ac569d8502762da0f21ba319ec1e46c84` | `overview_dark.png` |
| `0d1f56ac42b00dee74bd1fd086a30d46544722ca2409229a2506265970dd346b` | `overview_light.png` |
| `4b45fcb9851378f68ec656f24a03f2bb67c31448e578239debb8b9d2fd5af075` | `run_detail_dark.png` |
| `067899a6e5ef4ff639e617e53f8a2927e8f57f23833700c9fe07960fa9ad233` | `run_detail_light.png` |

**Rule for future changes:** any implementation/design change requires new
candidate goldens + a new human approval. Agents must never overwrite these
baselines and self-approve.

---

## 3. CLOSURE EVIDENCE GATES (last verified 2026-09-16)

| Gate | Result | Evidence |
|---|---|---|
| DCR-002 | RESOLVED (`ADOPT_PLAIN`) | DESIGN-HANDOFF §14; 004-*.md header reconciled |
| BP/BPM design authority | IMPLEMENTATION_AUTHORITATIVE | DESIGN-HANDOFF §2/§14 |
| DCR-001 | RESOLVED (`SELECT_B`) | 001-…-design-change-request.md |
| DESIGN_GATE | PASS | DESIGN-HANDOFF §14 |
| Canonical Serverpod generation | reproducible | `serverpod_cli generate` re-run 2026-09-16, no drift |
| GENERATED_CODE_MANUAL_PATCH_REQUIRED | NO | `packages/control_plane_client/` untracked/generated only |
| Server tests | 62/62 | `apps/server dart test -j 1` |
| Flutter tests | 95/95 | `apps/control_plane flutter test` |
| Typed-client E2E | 3/3 | real generated-client HTTP E2E (mayfly + serverpod) |
| Same-WorkItem resume | proven | `WI-3d8c` resume via approve; `wi-ny-1` design-approval resume |
| Run visibility | proven | run detail + timeline from durable transitions |
| Overview data proof | proven | running 3 / waitingOnYou 1 live read |
| PL-6 | implemented | description required ≥ 12 chars, distinct from title |
| ArtifactRefs read path | proven | Evidence panel from `artifactRefsJson` live |
| Web build | green | `flutter build web` |
| P0/P1 | none unresolved | Escalation routing P1 RESOLVED (below) |

### Escalation routing fix (added after the human review set — verified)

`HumanDecisionRouting` now routes `escalation`:
- `(escalation, approve) → agentExecuting`
- `(escalation, rework) → planning`
- generic non-terminal actor escape → `cancelled` (untouched)

`waitingForHumanDecision → planning` transition added. Regressions covered by
`_escalationRouting` + full `workflow_engine` suite (40/40). Server 62/62,
Flutter 95/95, analyze SUCCESS re-verified after the fix.

---

## 4. RECONCILIATIONS

### 4.1 PL-4 — CONCLUDED: NO_NEW_AUTHORIZATION_MODEL_REQUIRED

The control-plane decision flow separates human approve vs reject at the gate;
it introduces no distinct reviewer persona/permission, no new role, no change to
`HumanDecision`/`WorkItemState`. Per DESIGN-HANDOFF §15 and 004 §6, no contract
or authorization change is required for BP/BPM conformance.

**Record PL-4 = RESOLVED** (2026-09-16).

### 4.2 PL-5 — NOT CLOSED BY THIS FEATURE (preserved)

Preserved as `HUMAN_DECISION_EXPIRY_RECOVERY` at high priority. Not solved by
this closure. Invariants (per human instruction):
- no automatic approval
- no silent cancellation
- expired decision remains durable
- explicit recovery / reissue required
- original decision linked to its replacement
- SAME WorkItem remains recoverable
- "Needs You" can represent the condition

`HUMAN_DECISION_REQUIRED`: the exact expiry/reissue policy still needs human
authority; do not implement a default automatically.

### 4.3 DCR-002 header reconciliation

`004-plain-language-usability-design-change-request.md` header previously read
`Status: OPEN` while DESIGN-HANDOFF §14 recorded `RESOLVED` (`ADOPT_PLAIN`,
DCR2-AC-7). Header updated to `RESOLVED` with reference (2026-09-16).

---

## 5. PRESERVED FOLLOW-UPS (do not block closure)

1. **TYPED_SERVERPOD_CONTRACT_FOLLOWUP** — migrate scheduler/worker/execution
   raw-map endpoint families toward typed views (consistency with control-plane
   endpoints). No behavior change required.
2. **MELOS_FILTER_FIX** — root `melos run test` orchestration/filter behavior
   (parallel-PG race → use `-j 1`; root test filter semantics).
3. **ArtifactStore / GCS future work** — GCS is the production artifact
   backend (002 §9/§9A); `LocalArtifactStore` first-slice design retained.
4. **Low-priority advisories** — e2e dev-server bind (`anyIPv6`, dev-only),
   placeholder local operator signatures, hardcoded local API origin,
   `decision_detail_page.dart` deep-link fallback ambiguity (P2).

---

## 6. FINAL STATUS

`CONTROL_PLANE_OPERATOR_UI_001` = **COMPLETE**.

All gates above passed with live evidence in the 2026-09-16 closure run. No
P0/P1 open. No fabricated evidence: where an independent AI pixel review did
not occur it is recorded as `SUPERSEDED_BY_HUMAN_VISUAL_APPROVAL`, never as
`PASS`.

Feature implementation is hereby **STOPPED**. Next work is the program
synthesis checkpoint (analysis/planning only) — see
`docs/checkpoints/005-project-orchestration-program-synthesis.md`.
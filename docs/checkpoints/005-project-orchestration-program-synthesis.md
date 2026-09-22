# PROGRAM SYNTHESIS CHECKPOINT — PROJECT ORCHESTRATION (P0 PROBLEM SET, ≥3 SEQUENCES, BOUNDED SLICES)

**Feature under analysis:** the platform capability that lets a human durably
**direct** ShipIt to govern a real software project end-to-end — no "what comes
next?" failure — via typed intake, a project registry, an objective/plan layer,
and governed completion.

**Status: READY_FOR_HUMAN_ARCHITECTURE_DECISION (recommended default: Sequence C)**

This checkpoint is **analysis/planning only.** No Dart source, schema, ADR,
migration, or test was written in this run. Nothing here is implemented.

---

## 0. OUTPUT MANIFEST (31 outputs, this checkpoint = this catalog)

| # | Output | Where |
|---|--------|-------|
| 1 | Closure record | `docs/checkpoints/001-control-plane-operator-ui-closure.md` |
| 2 | Human QA decision record | `docs/checkpoints/001-control-plane-operator-ui-human-qa.md` (RESULT section) |
| 3 | Golden approval record (20 bound SHAs) | closure record §2 |
| 4 | Post-closure follow-up list (preserved) | closure record §5 |
| 5 | Core architectural diagnosis | §3 |
| 6 | Human → Orchestrator interaction model | §3.1 |
| 7 | Typed intake contract (outline) | §4.1 |
| 8 | Product registry model | §4.2 |
| 9 | Onboarding lifecycle | §4.3 |
| 10 | Objective model | §4.4 |
| 11 | Plan model | §4.5 |
| 12 | Completion assessment model | §4.6 |
| 13 | QA / release readiness model | §4.7 |
| 14 | Proactive authority model | §4.8 |
| 15 | Orchestrator contract (bounded) | §4.9 |
| 16 | Memory model (durable, store-backed) | §4.10 |
| 17 | Restart / recovery model | §4.11 |
| 18 | Security / redaction model | §4.12 |
| 19 | Bug-reporting relationship (002) | §5.1 |
| 20 | Design-governance relationship (003) | §5.2 |
| 21 | IA implications for control-plane | §5.3 |
| 22 | Dogfood strategy | §5.4 |
| 23 | Problem set enumeration (P1–P20) | §2 |
| 24 | Sequence A — capability ladder | §6.1 |
| 25 | Sequence B — direction-first | §6.2 |
| 26 | Sequence C — registry-first | §6.3 |
| 27 | Sequence D — orchestrator-first (rejected) | §6.4 |
| 28 | Recommended program sequence | §7 |
| 29 | Bounded slice plan (S-1 … S-6) | §8 |
| 30 | First next slice definition (S-1) | §8.1 |
| 31 | Status + human decisions required + deferred items | §9–§11 |

Outputs 1–4 are already complete and referenced above; everything else lives in
this document.

---

## 1. BASELINE (re-verified against source, 2026-09-16)

**Repository:** `shipit-platform` · **Branch:** `main` (HEAD `6584e7d` +
uncommitted restructure/UI work) · **Dart SDK:** 3.12.2 · **Flutter:** 3.44.7 ·
**Serverpod:** 3.4.13 · **PostgreSQL:** pg16 · **Melos:** 8.6.0

**Verified facts this run relies on:**
- `WorkItemState`: 24 active legal values + `done` (parse-only, deprecated,
  never a legal transition target). Documented in `workflow_state.dart:3-32`.
- `ProductState` enum already exists: `draft, active, archived, deprecated`
  (`workflow_state.dart:1`). No product registry / endpoints / UI exist.
- `JobType` enum is still only `implementFeature('implement_feature')`
  (`job_type.dart:5-7`). No planning/objective job types exist.
- `AgentRole` (11 values incl. `integrator`); no `orchestrator` role.
- `HumanDecisionType` (17 values); `HumanDecision` is the **only** durable
  structured human input (DESIGN-HANDOFF §12.1).
- `planning_evidence_provided` guard requires `featureRef`/`requirementRef`
  → typed intake is impossible without a project/feature registry.
- `Agent conversations ≠ system state` (AGENTS.md §3) — conversations are
  never persisted as authority. Respected throughout.
- Escalation routing verified present in `human_decision_routing.dart`
  (`(escalation, approve) → agentExecuting`, `(escalation, rework) → planning`).
- 002 = `READY_FOR_DESIGN — PARKED` (R4 un-parkable: DCR-001/002 both resolved).
- 003 = `READY_FOR_PLANNING_REVIEW`; its design-defect lifecycle is an explicit
  forward dependency of 002's `designDefect` remediation route.
- 17 ADRs in `docs/adr/`. Golden baseline (20 SHAs) bound in closure §2.
- GCS is the production artifact backend decision (002 R2, §9/§9A); only a
  local-first `ArtifactStore` design exists.

---

## 2. PROBLEM SET — P1 … P20 (bounded enumeration)

The 20 problems below are the genuine gaps between "operator can *observe*
governed work" (what exists, closed via 001) and "operator can *direct* ShipIt
to govern a real project." Each is grounded in a verified repo/handoff fact; no
fabricated severity claims — severity is assigned in §7 by the synthesis, not
per-problem.

| # | Problem | Verified grounding |
|---|---------|--------------------|
| P1 | No durable human intent channel — every intent except `HumanDecision` dies with the session | AGENTS.md §3; DESIGN-HANDOFF §12.1 ("the whole interaction model") |
| P2 | Chat transcript is not authoritative state, so identical words produce different work across sessions | AGENTS.md §3 reasoning |
| P3 | No `HumanDirection` contract (ask / direct the agent) | DESIGN-HANDOFF §12.2 #3 "No mechanism" |
| P4 | No goal/planning layer — `JobType` is only `implement_feature`; nothing expresses a multi-item objective | verified `job_type.dart`; §12.3 "no goal/planning layer" |
| P5 | No inter-item dependency/sequencing; "next" is purely entry-state routing | §12.3 "progress is machine-decided" — good, but no ordering between sibling items |
| P6 | No completion assessment — WorkItems terminate; nothing asks "was the objective actually met and accepted?" | §12.3 residual risk 2 |
| P7 | No project registry — `ProductManifest`/`ProductState` exist as shapes only | §12.2 #4 "no registry, no endpoints, no UI" |
| P8 | No onboarding path — no clone-at-revision + baseline build/test + `WorkspaceDescriptor` write | §12.2 #4; `git_worktree_workspace_manager.dart` exists |
| P9 | No typed queue-work write path — `createWorkItem` is tests/builders-only | §12.2 #2 |
| P10 | No proactive authority model — nothing defines when ShipIt may act ahead of instruction | §12.3 "done-then-stuck-at-QA/prod" failure |
| P11 | No bounded orchestrator contract — who interprets intent, sequences items, replans after a blocked gate? | §12.3 residual risk 2; no `orchestrator` role |
| P12 | No human-visible inbox for guard failures / clarifications; PL-5 expiry can wedge an item silently | §12.3 "no human-visible inbox"; §7.1 PL-5 |
| P13 | Memory is per-session, not durable; "process termination is normal" is only honored below the store layer | AGENTS.md §3; store-layer architecture |
| P14 | Questions can implicitly authorize mutations — no explicit "a question never authorizes" guard | core program principle (below §3.1) |
| P15 | Bug capture unbuilt — 002 fully spec'd, parked only on DCR (now resolved) | 002 §26 |
| P16 | Design governance unbuilt — `designDefect` remediation has no destination until 003 lands | 003 §18 |
| P17 | GCS artifact storage unbuilt — production evidence upload/redaction unavailable | 002 R2/§9A, §25 |
| P18 | Control-plane IA will exceed 5 surfaces; must be a bounded IA synthesis, not ad-hoc nav growth | §5.3 |
| P19 | No dogfood target — the platform only governs seeded demos, never a real second product | §5.4 |
| P20 | No program-level dependency ground truth — 002/003/005 must be ordered so refs resolve before intake | §7 |

**Boundary (what is NOT in this problem set):** customer support, crash
analytics, public portals, Jira replacement, arbitrary multi-cloud, k8s. All
remain excluded per AGENTS.md §8 and 002 §2.

---

## 3. CORE ARCHITECTURAL DIAGNOSIS

### 3.1 The interaction model ShipIt must reach

```
Human ──► DURABLE TYPED INTAKE ──► reconciler (durable)
             │   (Queue work / Report bug / Ask / Direct / Launch)
             ▼
        OBJECTIVE / CHANGE / DEFECT / QUESTION     (typed, persisted)
             │   authority checks: actor, scope, secrets, gate state
             ▼
        GOVERNED PLAN → governed WORK ITEMS → evidence → COMPLETION ASSESSMENT
             ▲                                            │
             └─────── clarification / re-plan / human decision (Needs You)
```

Three invariants are program-wide and **must** be literal in the architecture,
not conventions in prompt text:

1. **Chat transcript ≠ authoritative engineering state.** A conversation may
   *produce* a typed intake record, but the record — not the transcript — is
   the authority. Nothing else becomes state.
2. **A question never authorizes a mutation.** `HumanDecision` gates a
   mutation the state machine already permits; asking and acting are different
   objects. Proactive acts require an explicit authority record (§4.8).
3. **Process termination is normal.** Orchestrator state lives in the durable
   stores (`workflow_store`, `scheduler`, etc.). There is no long-lived agent
   session to lose. "What would the orchestrator do next?" must be recoverable
   from durable records alone.

ShipIt already satisfies invariant 3 below the workspace layer (durable job
queue, CAS, lease reconciliation); what the program adds is the *intent and
planning* layer that those stores can persist.

---

## 4. SYNTHESIS — CONTRACT/MODEL OUTLINES (analysis only, reference shapes)

These are the shapes the program must bring into the world. They are **design
targets for later slices**, not new untracked code now. Nothing here may be
implemented in this run.

### 4.1 Typed intake contract (P1, P2, P3, P9, P14)

One durable intake record per human action, carrying `source` (human), `kind`
(queue / defect / direction / question / launch), `scope` (product / workItem /
run / execution / job / none), and a `requestedAt`. Reconciler turns a record
into exactly one governed object. Explicit `authorizesMutation: false` for
`question`/`ask` kinds.

### 4.2 Product registry (P7)

Persist `ProductManifest` + `ProductState` rows; read endpoints; write path only
through governed onboarding. Registry is the anchor that makes
`planning_evidence_provided` satisfiable with real `featureRef`/`requirementRef`.

### 4.3 Onboarding lifecycle (P8)

`ProductState` (`draft → active | archived | deprecated`, already aligned);
onboarding writes a bounded bootstrap *record* (pendingBootstrap/failed live on
that record, not as new ProductState values). A worker job clones at an
explicit pinned revision, runs baseline build + test, writes an
`Ownership`/`WorkspaceDescriptor`; UI wizard against the adopted plain-language
system.

### 4.4 Objective model (P4)

Durable `Objective` (id, productId, title, summary, state, link to intake,
started/requested timestamps) spanning multiple WorkItems. Not a WorkItem; a
container at the next level up.

### 4.5 Plan model (P5)

Ordered/recommended WorkItems under an Objective with dependency hints. The
**scheduler** computes "next" from durable state; a plan is data the scheduler
and human both read, never a script the agent follows verbatim.

### 4.6 Completion assessment (P6)

Distinct from terminal states: a Completion/Assessment record asks "did the
objective's outcomes actually land and get accepted?" with human sign-off when
required. Pending completion is a first-class condition Needs You can show.

### 4.7 QA / release readiness (continues 001 practice)

Reuse `qa_contract_exists`, `artifact_built`, `deployment_approval` gates as-is;
Objective-level readiness is a derived view over its WorkItems, not a new bypass.

### 4.8 Proactive authority model (P10)

Default posture: **act only on instruction or a resolved gate.** A
`ProactiveAuthority` record (product-scoped, require-confirm vs allowed,
expiring, human-issued) is required before ShipIt may take a step no
instruction order demands. Nothing may act "ahead" without it.

### 4.9 Orchestrator contract (P11)

New bounded `AgentRole.orchestrator` (only if reconciliation confirms it is
genuinely needed — mirror 003 §7.5): interprets intake → plans → enqueues
governed jobs → reacts to blocked gates via Needs You. **Never** selects its own
QA role, writes WorkItem state directly, or branches an agent into a fresh role
(execution_coordinator rules hold unchanged).

### 4.10 Memory model (P13)

Everything persistent; the orchestrator's "memory" is the stores. No in-memory
knowledge that, if lost, would change behavior.

### 4.11 Restart / recovery (P13, §3.1 invariant 3)

Recovery is re-derivation: list durable objectives, plans, jobs, decisions;
re-enqueue only unacked jobs via the existing claim-CAS lease reconciliation.

### 4.12 Security / redaction (P17, P14)

Inherit 002 §10 redaction boundary + §9A GCS credential model for intake
evidence; secrets by reference name only (AGENTS.md §13); intake records
redacted before any LLM sees them.

---

## 5. RELATIONSHIPS WITH PLANNED FEATURES + IA

### 5.1 HUMAN_BUG_REPORTING_001 (002)

Non-UI slices are parking-unaffected (002 §26) and can be *executed* as a
dependency of this program, but the **UI must be built against the adopted
plain-language system** (unpark condition now met). This program's intake
reconciler should accept a defect route ON TOP of 002's reports, not a parallel
duplicate reporting path.

### 5.2 DESIGN_GOVERNANCE_AUTOMATION_001 (003)

`designDefect` remediation and **design-side objective acceptance** route
through 003's lifecycle. This program MUST NOT invent a second design gate. 003
remains `READY_FOR_PLANNING_REVIEW`; its review items are prerequisites, not
copied here.

### 5.3 IA implications (P18)

The approved 5-surface IA (sidebar: Home / All work / Needs you, pushed routes
for Run + Decision detail; mobile bottom nav; `Show technical details` layer)
expands with: **Report bug** (global toolbar action, NOT a nav destination),
**Inbox** for directions/clarifications (new first-class lane), **Launch /
onboard** (a wizard surface from Home for operators), and **Queue work**
(contextual action + top-level). Rule preserved: **no business logic in
widgets**, plain copy as a layer over durable values, blue=clickable /
status-colour=state (DCR-002 rules). Only a bounded IA specification (later
slice) may touch `app_shell.dart`.

### 5.4 Dogfood strategy (P19)

After S-1 (onboarding), the platform itself — or a small second real repo at a
pinned revision — is onboarded as a live dogfood product so intake, objectives,
directions, defects, and design gates are exercised against the platform's real
own work. Dogfood runs are also the primary evidence source for the next gate.

---

## 6. SEQUENCE COMPARISON — A / B / C (+D, rejected)

Qualitative criteria only (no invented numeric scores): **dep-correctness**
(never build intake before its registry/refs exist), **dogfood value**, **risk
retired per step**, **rework avoided**, **time to useful autonomous behavior**,
**governance completeness**.

### 6.1 Sequence A — capability ladder (bug reporting first, orchestrator last)

1. 002 bug reporting + triage (unblocked now)
2. 003 design governance (unblocks `designDefect`)
3. Registry + onboarding
4. Typed intake (refs resolve)
5. `HumanDirection` + Inbox
6. Objective/Plan/Completion + orchestrator + proactive authority

**Strengths:** fastest feedback capture; defect + design governance signals land
while the UI system is fresh; follows DESIGN-HANDOFF §12.4's literal order.
**Weaknesses:** typing intake/orchestration (the core of "direction") arrives
last; between 1–4 there is still no durable queue-work path, so the "front
door" gap persists longest.

### 6.2 Sequence B — direction-first (HumanDirection + intake early)

1. `HumanDirection` + Inbox (ADR)
2. Registry + onboarding (direction targets need a registry)
3. Typed intake
4. Objective/Plan/Completion + orchestrator + proactive authority
5. 002 bug reporting + triage
6. 003 design governance (last)

**Strengths:** the durable front door appears first; strongest alignment with
invariants in §3.1. **Weaknesses:** defects and design acceptance come late —
two high-signal feedback loops are the last things added; IA churn is front-loaded.

### 6.3 Sequence C — registry-first (recommended default)

1. **Registry + onboarding (S-1)** — real, pinned, `ProductState`, baseline
   build/test, `WorkspaceDescriptor`
2. **Typed intake (S-2)** — `featureRef`/`requirementRef` genuinely resolve
3. **Objective/Plan/Completion + orchestrator (S-3)** — bounded contract slice
4. **`HumanDirection` + Inbox (S-4)** — directions target registry objects
5. **002 bug reporting (S-5)** — UI on adopted language + GCS backend
6. **003 design governance (S-6)** — unblocks `designDefect`, completes acceptance

**Strengths:** satisfies the registry-before-intake dependency triangle at the
very start (P7/P8/P9 simultaneously); dogfoods a real product immediately
(P19); every later surface keys off durable registry identities, so no rework;
objective/completion ("did it actually land?") becomes the spine that keeps the
known done-then-stuck failure impossible. **Weaknesses:** bug feedback loop is
one step later than Sequence A; requires the human to confirm the S-1 dogfood
target first (PD-1/PD-2).

### 6.4 Sequence D — orchestrator-first (REJECTED)

Build Objective/Plan/Completion + orchestrator **before** any typed intake or
registry. **Rejected:** an orchestrator with no durable intent to plan and no
registry to key refs off can only synthesize its own requirements — precisely
the failure this program exists to prevent. Dep-correctness: fail.

---

## 7. RECOMMENDED PROGRAM SEQUENCE

**Sequence C** (registry-first), with two amendments:

- **Amend-C1:** 002's *non-UI* planning-backed work (domain store, triage job,
  redaction + GCS design) may start in parallel with S-1 because it is
  parking-unaffected and independent; only its **UI** ships after the adopted
  language, inside S-5.
- **Amend-C2:** proactive authority (S-3 slice) defaults to **restrictive**
  (`require-confirm`) until a human issues product-scoped authority records.

**Why C wins on the qualitative criteria:**
- **Dep-correctness:** every later slice references durable registry/objective
  identities that exist by the time they are needed.
- **Rework avoided:** no intake bolted on before refs resolve; no design gate
  bolted on after objectives already exist.
- **Risk retired:** P7/P8/P9/P19 cleared first — the largest structural gaps.
- **Time to useful autonomous behavior:** S-1→S-3 is the shortest path to "a
  human says a thing; a governed plan runs; evidence closes the loop" — the
  exact machine-decided-not-LLM-decided property (DESIGN-HANDOFF §12.3).
- **Governance completeness:** S-5/S-6 land the two human-review loops last,
  exactly where they can consume everything built before them.

If the human prefers early feedback (Sequence A), the cost is a longer front
door; if they prefer the front door (Sequence B), the cost is late feedback. C
is the balance recommended, and it is **not** chosen by score — it wins on the
dependency triangle and the known failure mode.

---

## 8. BOUNDED SLICE PLAN

| Slice | Scope | Exit criteria (bounded) | Dependency |
|---|---|---|---|
| **S-1** | Registry + onboarding | A real pinned product onboarded through baseline build/test and `WorkspaceDescriptor`; registry E2E; no new `JobType` invented; no intake yet | (PD-1, PD-2) |
| **S-2** | Typed intake | Queue-work path creates `draft` WorkItems with real refs, scheduler-endorsed, policy-governed; question kind never authorizes | S-1 |
| **S-3** | Objective/Plan/Completion + bounded orchestrator + proactive authority (restrictive default) | Completed objective requires human sign-off when required; orchestrator never self-assigns roles | S-1, S-2 |
| **S-4** | `HumanDirection` + Inbox + IA expansion slice | ADR; typed category; target-scoping to registry objects; read-only endpoints; direction folded into next bounded job, never mid-execution | S-1 |
| **S-5** | 002 UI on adopted language + GCS artifact backend | Bug-report surfaces on plain-language system; GCS upload/redaction flow | S-1; 003 for `designDefect` |
| **S-6** | 003 design governance | `DesignRevision` lifecycle + independence rule; `designDefect` route resolves | S-5; 003 review |

**Shared discipline across all slices:** commit generated `.g.dart`; contract
tests for serialization; keep `AgentRole`/`JobType` additions gated by
reconciliation (003 §7.5 pattern); no `Map<String, dynamic>` domain objects; no
state string-typing; `-j 1` for server tests.

---

### 8.1 FIRST NEXT SLICE — S-1 definition (not to be implemented this run)

**Name:** Product registry + onboarding — **multi-product aware**. **Artifact
type:** a new planning checkpoint
(`006-product-registry-onboarding.md`, created 2026-09-16; originally titled
`006-project-registry-onboarding-multi-project.md`, reconciled 2026-09-16 to
canonical **PRODUCT** scope per human override) + ADR on the registry store,
created ONLY after the human resolves PD-1/PD-2 below.
The checkpoint incorporates the 2026-09-16 human amendment (multi-product
architecture, isolation model, scheduler + Needs You implications,
canonical-scope decision MP-PD-1 = **PRODUCT** / PROJECT NOT INTRODUCED, MP
acceptance criteria + QA contract, future dogfood).
**Boundary conditions:** no work-item intake, no `HumanDirection`, no
orchestrator, no objective type in S-1. **Explicit non-goal:** ShipIt must NOT
begin running the new product's feature work during S-1.

---

## 9. STATUS

**READY_FOR_HUMAN_ARCHITECTURE_DECISION.**

- Closure of 001: COMPLETE (records 1–4).
- This run: analysis/planning only — no code written, no ADR, no schema, no
  migration, no tests. Forward **nothing** here is implemented.
- The program's first bounded slice is **not** started. Standing instruction:
  do not begin S-1 until PD-1/PD-2 are human-resolved.

---

## 10. HUMAN DECISIONS REQUIRED (program level)

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| PD-1 | Adopt Sequence C (registry-first) vs A (feedback-first) vs B (front-door-first)? | A / B / C | **C** (this checkpoint §7) |
| PD-2 | If C: which dogfood target for S-1? | shipit-platform repo itself / a second real repo at a pinned revision / other | platform repo itself (smallest, most observable) |
| PD-3 | Proactive authority default posture | restrictive (require-confirm) / per-capability allow / open | **restrictive** (§4.8, Amend-C2) |
| PD-4 | Who signs objective completion when human sign-off is required? | operator via Needs You / gate-only / both (gate + operator) | both, blocking when required (§4.6) |
| PD-5 | Inbox IA placement | new first-class lane / Home section / contextual only | new first-class lane (Directions) |
| PD-6 | PL-5 expiry semantics (carried from DESIGN-HANDOFF §7.1) | auto-escalate / notify / permit on expiry | notify + Needs You representation; orchestration may re-plan only after human decision |
| PD-7 | Confirm 002/003 ordering within S-5/S-6 | A order / C order | C order (§6.3) |

002 retains its own HD-1…HD-5; 003 retains DI-1…DI-13. This program does not
re-decide them.

---

## 11. DEFERRED ITEMS (program level)

| Item | Reason | Future |
|------|--------|--------|
| Orchestrator full autonomy without human line | P10 posture must be proven restrictive first (§4.8) | After ≥2 real objectives complete |
| Cross-registry / multi-product scheduling | Single dogfood product for S-1–S-4 | Post-S-6 |
| Generic chat-as-authority | Directly violates invariant 1 (§3.1) | **Never** — not a deferred option |
| Orchestrator memory beyond durable stores | Violates invariant 3 | **Never** |
| GCS production hardening / multi-bucket | 002 §9A design exists; S-5 is the vehicle | S-5+ |
| Semantic duplicate search for defects | 002 §25 carries | S-5+ |
| Public bug portal / crash analytics / support | explicit 002 §2 exclusions | No |

---

## 12. SESSION HANDOFF — WHAT HAPPENS NEXT (NOT this run)

1. Human resolves **PD-1/PD-2** (and ideally PD-3…PD-7) in the recorded gate.
2. If C: author planning checkpoint for **S-1** (`006-…`) + registry ADR.
3. Re-run full baseline verification (`melos run analyze`,
   `apps/server dart test -j 1`, `apps/control_plane flutter test`,
   `flutter build web`) before any new slice lands.
4. Only then: S-1 implementation, with exit criteria bounded per §8.

No further action until the human decides PD-1.
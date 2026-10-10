# Report — design-baseline-production-lane

**Design Agent · design-only lane · design-revision 1 · RISK_LEVEL 3**

---

## Ownership declaration (declared before writing; verified after)

| Class | Paths |
|---|---|
| `OWNED_PATHS` | `docs/engineering/dispatch/tasks/design-baseline-production-lane/**` |
| `READ_ONLY_PATHS` | `apps/server/lib/src/triage/**`, `apps/server/lib/src/endpoints/**`, `packages/workflow_engine/lib/**`, `packages/product_registry/lib/**`, `packages/platform_contracts/lib/**`, `apps/server/bin/onboard_shipit_dev.dart`, `apps/server/lib/src/credentials/**`, `packages/scheduler/**`, `apps/control_plane/**`, `apps/server/tool/schema_bootstrap.sql`, `AGENTS.md`, `docs/adr/**` |
| `PROHIBITED_PATHS` | `apps/server/**`, `packages/**`, `apps/control_plane/**`, `docker/**`, `.github/**`, `docs/adr/**`, `.decisions/**` |

No concurrent writers declared for `OWNED_PATHS` (dispatch: "None are writing these paths"). No
ownership overlap.

---

## Pre-flight verification (before any write)

| Check | Required | Actual | Result |
|---|---|---|---|
| `git branch --show-current` | `design/baseline-production-lane` | `design/baseline-production-lane` | PASS |
| `git rev-parse HEAD` | `889eee2` | `889eee237d5b5cf5bcd82c34b07db32f03920222` | PASS |
| `git status --porcelain` | — | empty | PASS clean |

**Discrepancy noted, not blocking:** the dispatch header names
`WORKTREE: /private/tmp/shipit-design-baseline-lane`, which **does not exist**; the operator
directed `/private/tmp/shipit-design-baseline`. Branch and SHA match the dispatch exactly, so the
worktree name is the only difference and it is not a provenance conflict.

---

## Constraints honoured

| Constraint | Evidence |
|---|---|
| Design only — no production source, generated files, or tests changed | `git status --porcelain` shows exactly one untracked entry: my task dir. **0 tracked files modified.** All proposed diffs are TEXT inside the design. |
| `packages/**`, `apps/server/**`, `apps/control_plane/**` read-only | Read only. 0 modifications. |
| **ZERO Docker/Compose commands** | **0 issued.** No `docker`, `compose`, `ps`, `logs`, `config`, `info`, `make clean`, `qa-down`, `test-env-down`, `e2e-down`, or bare `down -v`. Compose not needed — I read no compose file and ran none. |
| `bash apps/server/tool/verify_schema_bootstrap.sh` — run and report | **Run. Exit 0. 20 `OK:` assertions, 0 failures.** (Text verification; no Docker.) |
| Do not resolve a Human Decision | **Not resolved.** HD-1 and HD-2 are *routed*, never answered. No `HumanDecision` object created, mutated, or implied. |
| Self-approval | Not done. `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`; verdict left to the reviewer. |
| No commit / push | **Neither.** Not instructed; policy reserves it. |

---

## Artifacts produced

| Path | Purpose |
|---|---|
| `design-revision.md` | The Design Revision — ten answers, four findings, four-layer guard, rollout, verification plan, lane plan |
| `design-revision-metadata.yaml` | Required metadata per `DESIGN_GOVERNANCE.md` |
| `report.md` | This structured result |

---

## What the design concluded

**Answered.** Trigger (operator-requested + sweep, one dedupe key). Source acquisition (**reuse**
`CredentialKeyService.verifyAccess` → `RepositoryAccessVerifier.verify`; the deploy key is the right
credential class — read-only, per-repository). Structural separation (S1 principal / S2 input /
S3 divergence). Fail-closed guard (**four layers**). `JobType` (reuse — it already exists). Human
gate (retained; automation stops at `baselineReview`). Product-agnosticism (designed against Product
B; `shipit`/`SHIPIT_` grep gate). Migration and rollout (additive schema → engine → RPC → lane →
sweep → re-verification). Verification plan (5 positive, 10 negative).

**Escalated, not chosen.** Item 5 — what legitimately issues `platformVerifiedEvidence` — is
**HD-1**. I designed the mechanism and recommend option A (deterministic re-derivation under a
distinct principal over its own pinned acquisition), evaluated B (distinct execution context) and
D (a second agent — rejected: a renamed agent is the hole with better branding). I did **not** choose.
Defining what mints the sole evidence kind that unlocks a governance gate is human authority, and
with F-2 below the invariant it enforces has no written policy at all.

**The seam is deliberate.** HD-1's answer changes *where* the verifier runs, not what S1/S2/S3, the
guard, the trigger, or the RPC lockdown are. That is why the uncertainty is survivable rather than
blocking.

---

## Four findings that changed the dispatch's premises

**F-1 — the security finding is worse than stated: it is remote.** The dispatch frames it as the CLI
omitting a default parameter. `verifyBaseline` is also an exposed Serverpod RPC
(`product_registry_endpoints.dart:557-560`) with `String kind = 'platform_verified_evidence'` as
the **wire** default, called with that value hardcoded from
`control_plane_repository.dart:1081`. Any API client can write an arbitrary `verifiedBy` and an
arbitrary `kind` and unlock the guard — for first onboarding **and** for re-baselining a governed
product (both transitions require it). No UI call site exists, so the surface is unused by the
product but fully reachable. **This makes item 4 a security remediation, hence RISK_LEVEL 3 rather
than 2.**

**F-2 — the invariant is cited 11 times and written nowhere.** `AGENTS.md §12` is cited in
`product_baseline.dart:93`, `product_transitions.dart:20`, `product_registry_engine.dart:255`,
`exceptions.dart:185`, **`product_baseline.spy.yaml:27`** (a database schema comment), two model
files, two generated files, and `DESIGN-HANDOFF.md:286`. **`AGENTS.md` has no §12** — it has §13.
This is the same defect class AGENTS.md documents about itself for §13 (*"Restored 2026-10-06 … §13
did not exist in this file … a documented mitigation that was never applied"*). Routed as **HD-2**.
A guard that enforces an unwritten rule is enforcing an unwritten rule.

**F-3 — the existing verifier is unreachable-by-construction.** `onboard_shipit_dev.dart:324-325`
compares a **scraped-only** hash against `proposed.contentHash`, which on the merge path at
`:205-213` is computed over **scraped + human**. That merge path clears `verifiedAt: null`, so line
298 re-enters that branch on the next run → the two hash inputs describe different fact sets →
`exit(5)`, with a message blaming the repository. The `else` branch at `:354-359` gets it right.
**Reachable sequence: run script → human adds a claim → run again → always fails.** This is the
direct justification for an explicit `comparableSubsetHash` contract.

**F-4 — `JobType.onboardProduct` already exists and nothing consumes it.** Item 6 therefore resolves
to *reuse*, not *add*. Worse: `triggerOnboarding` enqueues it (`control_plane_service.dart:1804-1870`)
with a correct dedupe key, but there is **no `JobDefinition` for it** anywhere in `packages/scheduler`
and no lane consumes `workItemId == 'onboarding-$productId'`. **It sits `queued` forever today.** A
fifth instance of the silent-no-op class — live, not historical.

---

## Discoveries (per `aef-repository-learning`)

| ID | Finding | Category | Authority | Persisted? |
|---|---|---|---|---|
| F-1 | `verifyBaseline` RPC permits remote self-attestation of platform verification | `ARCHITECTURE_DISCOVERY` | **Human** | Reported only |
| F-2 | `AGENTS.md §12` cited 11× incl. DB schema; does not exist | `CONTRADICTION` (governance) | **Human** | Reported only |
| F-3 | Verifier subset-comparison defect; fails on any re-run after a human claim | `PROJECT_FACT` | Auto → Lane 4 | Reported |
| F-4 | `JobType.onboardProduct` enqueued, never consumed | `PROJECT_FACT` | Auto → Lane 4 | Reported |
| D-1 | `JobType.onboardProduct` already exists — corrects the dispatch premise | `PROJECT_FACT` | Auto | Reported |
| D-2 | The re-derivation already exists (`:288-337`); its computed proof is discarded before `verifyBaseline` is called with none | `PROJECT_FACT` | Auto → Lane 1 | Reported |
| D-3 | Design-review independence is DB-enforced; baseline-verification independence is convention-only | `WORKFLOW_IMPROVEMENT` | Independent review | Reported |
| D-4 | `verify_schema_bootstrap.sh` — 20 `OK:`, exit 0 at `889eee2` | `PROJECT_FACT` | Auto | Executed |

**KNOWLEDGE_PERSISTED: none.** This is a design-only lane whose owned path is its own task directory.
F-1, F-2 and HD-1/HD-2 exceed design authority; the rest are carried in the revision as
implementation requirements for the lanes in §6. `AUTOMATION_OPPORTUNITY` (the missing sweep) is
*this* work item.

---

## SAFE_PARALLEL_WORK

| Lane | Scope | Owned paths (exclusive) |
|---|---|---|
| **L1** | Guard: contracts + engine, fail-closed, proof API, comparable-subset contract | `packages/platform_contracts/lib/src/types/{product_baseline,baseline_verification}.dart`, `packages/platform_contracts/test/**`, `packages/product_registry/lib/src/**`, `packages/product_registry/test/**` |
| **L2** | Schema: columns, trigger, migration, bootstrap drift guard | `apps/server/tool/schema_bootstrap.sql`, `apps/server/tool/verify_schema_bootstrap.sh`, `apps/server/migrations/**`, `apps/server/lib/src/database/product_baseline.spy.yaml`, `apps/server/test/**` |
| **L3** | Wire: remove `kind` from the RPC; endpoint / service / client | `apps/server/lib/src/endpoints/product_registry_endpoints.dart`, `apps/server/lib/src/services/control_plane_service.dart`, `apps/control_plane/lib/data/control_plane_repository.dart` |
| **L4** | Lane: the lane itself, source acquisition, scheduler definition, tick dispatch table | `apps/server/lib/src/baseline/**`, `apps/server/lib/src/credentials/repository_snapshot_acquirer.dart`, `packages/scheduler/lib/src/baseline_product.dart`, `apps/server/lib/src/triage/lane_i_tick_hook.dart` |
| **L5** | Regeneration **only**, after L1–L4 land | `apps/server/lib/src/generated/**`, `apps/control_plane/lib/generated/**` |

**Concurrent:** `L1 ∥ L2 ∥ L4` — disjoint paths, no shared file.

**Dependency edges (why not all five are parallel):**

```
L1 ──┬─→ L3 ──┐
L2 ──┤        ├─→ L5
L4 ──┴────────┘
```

`L3` cannot compile until `L1` removes the parameter. `L5` regenerates after all four.

**Suggested order:** `L1 ∥ L2 ∥ L4` → `L3` → `L5`, sweep **off** until L4 runs end-to-end.

**Reviewable in parallel with implementation:** independent review of *this revision* may start
immediately; it does not depend on any lane.

---

## PROHIBITED_PARALLEL_WORK

- **Any two of L1/L2/L3/L4/L5 touching the same file** — the paths above are disjoint by construction.
- **Any lane hand-editing `apps/server/lib/src/generated/**` or `apps/control_plane/lib/generated/**`.**
  Generated; owned exclusively by L5 (per AGENTS.md: change the canonical artifact, regenerate).
- **L3 before L1** (signature mismatch); **L5 before L4** (incomplete graph).
- **L2 modifying anything but schema/tool/migration paths** — L1 owns the library contract the trigger
  defends; a trigger written against a contract L1 is concurrently changing is unreviewable.
- **Any implementation lane resolving HD-1 or HD-2.** Both are human authority. Implementing *around*
  an unresolved HD-1 — e.g. hard-coding option A — is the prohibited form.
- **Enabling the sweep before L4 has completed a full end-to-end run on Product A.** The sweep is the
  only step that mutates product state.
- **Any Docker/Compose command by any lane without explicit infrastructure authority.** The QA stack
  is live.
- **Adding a new `JobType`.** `onboardProduct` already exists (F-4); a new member is the silent-no-op
  pattern again.

---

## Escalation statement

**I am escalating a human decision: HD-1**, on the dispatch's own instruction not to choose.

> Does a deterministic platform re-derivation — under a verifier principal distinct from the
> producer's, over a source revision the verifier acquired itself, compared by content hash —
> constitute `platformVerifiedEvidence`?
> **A.** Yes. **B.** No; a distinct execution context is additionally required.
>
> Recommended: **A now, B as scoped follow-on**, with A's residual hole stated rather than implied.
> Blocks Gate D4. Does **not** block implementation of §3.1, 3.2, 3.6, 3.7, 3.8, 3.10.

**HD-2** (author `AGENTS.md §12`; 11 citations point at a section that does not exist) is escalated
with it. Blocks D4; does not block implementation.

I answered item 3 — structural separation is answerable mechanically, and I answered it (S1/S2/S3,
plus a database trigger mirroring the accepted `trigger_design_review_independence`). What I did
**not** do is decide that the mechanism's output is entitled to the word *platform-verified*. That
distinction is the whole point of the finding, and it is not mine to settle.

---

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Design the missing automatic baseline-production path with verification separated from production
BRIEF_ID: 9E045515-404E-4036-864A-FBFB0B3F6B88
REVISION_ID: F22EC933-E9AB-4A0B-8904-C987EE1B1951
REVISION_NUMBER: 1
BRANCH: design/baseline-production-lane
BASE_SHA: 889eee2
HEAD_SHA: 889eee237d5b5cf5bcd82c34b07db32f03920222

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/**

READ_ONLY_PATHS:
  - apps/server/lib/src/triage/**
  - apps/server/lib/src/endpoints/**
  - apps/server/lib/src/services/**
  - apps/server/bin/onboard_shipit_dev.dart
  - apps/server/lib/src/credentials/**
  - apps/server/tool/schema_bootstrap.sql
  - packages/platform_contracts/lib/**
  - packages/product_registry/lib/**
  - packages/workflow_engine/lib/**
  - packages/scheduler/**
  - apps/control_plane/**
  - AGENTS.md
  - docs/adr/**

PROHIBITED_PATHS:
  - apps/server/**
  - packages/**
  - apps/control_plane/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/design-revision.md
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/design-revision-metadata.yaml
  - docs/engineering/dispatch/tasks/design-baseline-production-lane/report.md

RISK_LEVEL: 3
RISK_RATIONALE: >
  Core workflow and governance-model change. It redefines what may mint the only
  EvidenceKind satisfying ProductGuard.baselineVerifiedIndependently -- the gate between an
  agent's assertion and a human being asked to approve. isIndependentlyVerified is made to fail
  closed, which flips the evaluation of every pre-existing product_baseline row. It remediates a
  live reachable security boundary: verifyBaseline is an exposed Serverpod RPC whose wire default
  is the permissive kind, so any API client can currently self-attest platform verification for
  any product, including re-baselining a governed one. Level 3 additionally requires architecture
  approval -- exactly what HD-1 requests. A Level 2 reading was considered and rejected: no UI
  changes, but the taxonomy keys on workflow and governance model, both of which change.

CHANGELOG:
  - "revision 1 (initial): all ten dispatch questions answered"
  - "four premise-changing findings: F-1 remote RPC self-attestation; F-2 phantom AGENTS.md 12
     cited 11x; F-3 verifier subset-comparison defect (fails on any re-run after a human claim);
     F-4 onboardProduct JobType exists but is enqueued and never consumed"
  - "four-layer fail-closed guard: proof-based engine API; fail-closed isIndependentlyVerified;
     DB trigger mirroring trigger_design_review_independence; RPC can no longer mint platform
     evidence"
  - "structural separation S1/S2/S3 (principal, input, divergence) with S3's residual hole stated"
  - "item 5 ESCALATED as HD-1, not decided; HD-2 added for the missing AGENTS.md section"
  - "five implementation lanes with non-overlapping OWNED_PATHS; generated trees to one lane (L5)"

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - "item 1 -- trigger, idempotency, restart safety (design-revision.md 3.1)"
    - "item 2 -- source acquisition; deploy-key assessment; reuse of CredentialKeyService /
       RepositoryAccessVerifier / ssh_remote (3.2)"
    - "item 3 -- structural producer/verifier separation S1/S2/S3 (3.3)"
    - "item 4 -- fail-closed guard; permissive default removed; migration and blast radius (3.4)"
    - "item 6 -- JobType reuse vs new; tick-hook dispatch table (3.6)"
    - "item 7 -- human gate retained; automation stops at baselineReview (3.7)"
    - "item 8 -- product-agnosticism, designed against Product B; shipit grep gate (3.8)"
    - "item 9 -- migration, rollout order, EXTERNAL_* precedent, and what is NOT external (3.9)"
    - "item 10 -- verification plan incl. the negative case; N-1/N-2/N-6 are acceptance criteria
       for the security finding (3.10)"
    - "design-only constraint -- all proposed diffs are TEXT; 0 production files modified"
    - "zero Docker/Compose commands -- 0 issued"
    - "verify_schema_bootstrap.sh executed and reported: exit 0, 20 OK, 0 failures"
    - "no Human Decision resolved"
    - "per-lane non-overlapping OWNED_PATHS with stated dependency edges"
  REQUIREMENTS_GAPS:
    - "item 5 -- mechanism DESIGNED (S3, with a full four-layer enforcement design) but DELIBERATELY
       NOT DECIDED; escalated as HD-1. Not a coverage gap: a refusal to exercise authority this lane
       does not hold. Both candidate answers are implementable behind one named seam."
    - "HD-2 (added) -- AGENTS.md section 12 is cited 11 times and does not exist; the human must
       author it. Routed, not resolved. Does not block implementation."

DESIGN_SYSTEM_COMPLIANCE: PASS
UX_ACCESSIBILITY_SCORE: PASS
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - "F-1 ARCHITECTURE_DISCOVERY (human authority) -- verifyBaseline is an exposed Serverpod RPC whose
     wire default is 'platform_verified_evidence'; control_plane_repository.dart:1081 hardcodes it.
     Any API client can self-attest platform verification for any product, including a governed one
     being re-baselined. No UI call site exists."
  - "F-2 CONTRADICTION / governance (human authority) -- 'AGENTS.md 12' is cited in 11 places
     including product_baseline.spy.yaml:27, but AGENTS.md has no section 12. Same defect class
     AGENTS.md documents for its own section 13."
  - "F-3 PROJECT_FACT (auto, Lane 4) -- onboard_shipit_dev.dart:324-325 compares a scraped-only hash
     against a scraped+human contentHash set at :205-213, which also clears verifiedAt. Any re-run
     after an operator adds a claim reaches that branch and always exits 5. The else branch at
     :354-359 compares the subset on both sides and is correct."
  - "F-4 PROJECT_FACT (auto, Lane 4) -- JobType.onboardProduct is enqueued by triggerOnboarding
     (control_plane_service.dart:1804-1870) with a valid dedupe key, but has no JobDefinition in
     packages/scheduler and no consumer. It sits queued forever today."
  - "D-1 PROJECT_FACT -- JobType.onboardProduct already exists (job_type.dart:15-18), correcting the
     dispatch premise that only triageDefect applies to this flow."
  - "D-2 PROJECT_FACT (auto, Lane 1) -- the deterministic re-derivation the dispatch asks me to
     evaluate already exists at onboard_shipit_dev.dart:288-337; its computed proof is printed and
     discarded, then verifyBaseline is called at :338-342 with no proof at all."
  - "D-3 WORKFLOW_IMPROVEMENT (independent review) -- design-review independence is enforced as a
     database invariant (schema_bootstrap.sql:162-189, 'not a convention the call sites are trusted
     to honour') while baseline-verification independence is convention-only. The proven remedy
     already exists in-repo."
  - "D-4 PROJECT_FACT -- bash apps/server/tool/verify_schema_bootstrap.sh: exit 0, 20 OK, 0 failures.

KNOWLEDGE_PERSISTED: >
  None. Design-only lane; OWNED_PATHS is its own task directory and contains the artifacts.
  F-1, F-2 and HD-1/HD-2 exceed design authority and are reported for routing to a human gate.
  The remaining discoveries are carried in design-revision.md section 6 as implementation
  requirements with assigned lanes.

BLOCKERS: >
  None blocking this design revision. Two decisions are ESCALATED, not blocking implementation:
  (HD-1) what legitimately issues platformVerifiedEvidence -- deterministic re-derivation under a
  distinct principal [recommended] vs a required distinct execution context. Mechanism fully
  designed; authority not exercised. Blocks Gate D4 only.
  (HD-2) who authors the missing 'AGENTS.md 12', cited 11 times and absent. Blocks Gate D4 only.
  Both are routed per aef-human-decision and NEITHER is resolved by this lane.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

---

**Note to the Manager.** Three things worth attention beyond this lane's scope:

1. **F-1 is exploitable now.** The permissive default on an exposed RPC is not a latent weakness — any
   authenticated client can currently unlock `baselineVerifiedIndependently` for any product. L1+L3
   close it. If you want it closed before the rest of the lane lands, L1+L3 can go first on their own.
2. **F-4 is a live bug, not a gap.** `triggerOnboarding` has been writing a job nothing consumes.
   Worth confirming no operator believes onboarding is running today.
3. **F-2 has a precedent.** `AGENTS.md` already documents §13's phantom restoration (2026-10-06). §12
   is the same shape, one level deeper — a security invariant with no policy text at all.
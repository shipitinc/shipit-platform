# Design Brief — Design Governance Runtime (`DESIGN_GOVERNANCE_AUTOMATION_001`)

**Brief ID:** `aabceaca-0d1f-492c-837c-2068a2ea9ed9`
**Version:** 1.0.0
**Status:** `DRAFT` — awaiting Gate D1/D2 and independent review. **Not approved. Not implemented.**
**Authoring lane:** `design-DESIGN-GOVERNANCE-RUNTIME` (design-agent)
**Base SHA:** `b95bffd5f23f1322caf7ae086b35cccf78262790` — verified `git rev-parse --short HEAD` == `b95bffd`
before the first edit; tracked tree clean (`git status --porcelain --untracked-files=no` empty).

**Governing human decision:** `d41a6e85-7c02-4b39-9f18-3e6b5a20d7f4` — chose to **build** the runtime
rather than accept a permanent park.

> **THE CONSTRAINT THIS BRIEF DOES NOT LOSE.** The one already-parked design-remediation work item
> **cannot be completed retroactively by building this runtime.** It was created with no design
> artifact, and nothing this brief specifies reconstructs one from nothing. It would have to be
> re-triaged. **Nothing in this brief may be read as repairing it**, and §5.4 specifies what the item
> records in the meantime — including that it stays parked. The runtime is built for *future* items.

---

## 0. Ownership

| | |
|---|---|
| `OWNED_PATHS` | `design/design-governance-runtime/design-brief.md` (this file); `design/design-governance-runtime/design-brief-metadata.yaml`; `design/design-governance-runtime/design-revision.md`; `design/design-governance-runtime/design-revision-metadata.yaml` |
| `READ_ONLY_PATHS` | `apps/**`, `packages/**`, `docker/**`, `docs/adr/**`, `docs/checkpoints/**`, `docs/engineering/**`, `design/qa-contracts-feature-remediation/**`, `design/capability-parity/**` |
| `PROHIBITED_PATHS` | all production source; all test source; `docker/**`; `docs/engineering/FOLLOW_UPS.md` (findings are *reported*, never edited); `design/qa-contracts-feature-remediation/**` (Level-3 approved under `92d567e3` — **explicitly not reopened**) |

**No production code was written. No docker, no docker compose, no psql.** Every claim below is derived
by reading the tree, per `AGENTS.md`'s shared-Docker-state rule for a lane without deployment
authority. `dart analyze` was not run: this lane changed no Dart file, so there is nothing for the
analyzer to be evidence about.

---

## 1. Problem statement

A human reports a defect. AI triage classifies it `designDefect`. ADR 0021 requires that classification
to route through the Design Governance lifecycle rather than the coding lane. It does not.

The routing stops at WorkItem creation. Lane E durably creates a `design-remediation-*` WorkItem,
walks it `draft → planning → planned`, and records
`blockedBy: EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` on it. It **refuses** to enter `designRequired`,
and its stated reason is correct: `planned → designRequired` is guarded by
`GuardConditions.designContractExists()`, that guard reads `context['designContractId']`,
`DurableWorkflowEngine.transition` does not persist it, and there is no `design_contract` table and no
`DesignContractStore`. Entering `designRequired` on a fabricated id would assert that design work is
routed while no design artifact exists.

**That refusal is the correct call and this brief does not overturn it.** The problem is that nothing
is on the other side of the refusal.

### 1.1 What the dispatch believed, and what the tree says

The dispatch states the runtime "is implemented **nowhere**". **That is not accurate, and designing
from it would have produced a plan to rebuild things that already exist.** Correcting it is the first
design act, not a criticism of the dispatch:

| Dispatch premise | Tree |
|---|---|
| "no wired `JobDefinition` occupies" `designRequired` | `designRevisionDefinition` **exists** — `packages/scheduler/lib/src/scheduler.dart:3255`, entryStates `{designRequired, designRejected}`, exported at `packages/scheduler/lib/scheduler.dart:31`, exercised by `packages/scheduler/test/design_job_test.dart` and by an e2e integration test. **What does not exist is any production composition root that mounts a Scheduler on it.** |
| "the runtime is implemented nowhere" | The **data layer exists**: `design_revision`, `design_review_result`, `design_finding`, `design_revision_event` tables; `packages/design_governance/` store interfaces + in-memory impl; `apps/server/lib/src/persistence/postgres_design_governance_store.dart`; a store contract suite. **What does not exist is any producer** — no non-test caller of `saveDesignRevision` exists anywhere. |
| `designApproval` machinery may need a new type | `HumanDecisionType.designApproval` **exists** and is fully wired — enum (`platform_contracts/lib/src/enums/human_decision.dart:2`), three transition edges, three routing arms. **No new type is needed.** |

**The corrected problem statement:** *the design governance runtime is a data layer and a job model
without a producer, a composition root, or an approval raiser.* Three of four lifecycle stages already
have code; the fourth — anything that actually runs — has none.

---

## 2. User flows

### 2.1 The intended flow (ADR 0021 §1)

```
designDefect → triage → WorkItem(designRequired)
  → JobType.designRevision (AgentRole.designAgent)
  → DesignRevision(draft)
  → JobType.designReview (AgentRole.designReviewer, designer excluded)
  → DesignReviewResult + DesignFinding(s)
  → risk classification (LOW / MEDIUM / HIGH)
  → [HIGH, or MEDIUM when policy demands] HumanDecision(designApproval)
  → designApproved → implementation
```

### 2.2 Entry / exit criteria

| Flow | Entry | Exit |
|---|---|---|
| **F1 Design revision** | item at `designRequired`, a durable design contract exists, no live design execution | one `DesignRevision` row at `draft`, read back, `designerExecutionId` stamped, identity on the work item |
| **F2 Design review** | item at `designInReview`, a revision exists, reviewer ≠ designer | one `DesignReviewResult` + findings, persisted |
| **F3 Risk gate** | review verdict recorded, risk policy resolves a tier | LOW → `approved`; MEDIUM/HIGH → blocking `designApproval` decision raised |
| **F4 Approval** | blocking `designApproval` pending | `approve` → `designApproved`; `reject` → `designRejected`; `rework` → `designInReview` (bounded) |

### 2.3 The flow that actually happens today — and why a retry converges

This is the finding that most changes the work, and it is **not** the missing scheduler.

`planned` is in **`triageDefectDefinition.entryStates`**, with
`entryProbeTargets: {planned: designNotRequired}`
(`packages/scheduler/lib/src/triage_defect.dart:126-138`). The scheduler is category-blind. So the
remediation item that lane E parks at `planned` is picked up by the **triage** scheduler, and the
`EntryHopper` walks it `planned → designNotRequired` — a state that asserts *no design work is
required*, the exact opposite of the truth. `designNotRequired` is itself a triage entry state, so it
is dispatched again. **Every retry re-converges on the same terminal state.**

> **Therefore: mounting the design scheduler alone does not fix this.** The item never reaches
> `designRequired`, because another lane takes it out of `planned` first. The `planned` wait is not a
> safe holding state, and the design must specify what replaces it. See `design-revision.md` §4.

---

## 3. Success criteria

1. A design defect triaged *after* the runtime ships reaches `designApproved` through the full ADR 0021
   lifecycle, with every step durably recorded.
2. No code path exists by which a `designRevision` job is enqueued that does not satisfy every
   precondition in `design-revision.md` §3, and no path by which a revision is proposed for review that
   does not satisfy every postcondition.
3. `designApproval` is raised by the platform, resolved by a human, and admits exactly the three
   choices already wired — with no new `HumanDecisionType` and no new `WorkItemState`.
4. A rejected design has a route back to the design agent. Today it does not.
5. **ADR 0021 §2's "divergence from approved design is itself a defect" has a detector.** Today it has
   a rule and no detector.
6. `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` reporting is **not weakened** at any point during the build.

## 4. Constraints

| Constraint | Source |
|---|---|
| Reuse existing machinery — no new scheduler, no new workflow, no parallel mechanism | ADR 0021 §7; checkpoint 003 §10 |
| Triage is advisory; it must never produce design artifacts | ADR 0021 §2, §4 |
| Reviewer ≠ designer, platform-enforced at dispatch | ADR 0021 §Consequences; checkpoint 003 §7.1 |
| Risk policy is **data**, never hard-coded control flow | ADR 0021 §6 and §Consequences; checkpoint 003 §9.6 |
| `qaPassed` stays CLOSED; this runtime must not reopen or weaken it | decision `92d567e3`; `design/qa-contracts-feature-remediation/` |
| Credentials referenced by name, never value; no Penpot token in any artifact or log | `AGENTS.md` §13, §13a |
| Design-defect verification is a **separate** gate from design approval | ADR 0021 §5 |

## 5. Acceptance criteria

### 5.1 Design acceptance

- **A1.** Every precondition and postcondition in `design-revision.md` §3 states the **input that makes
  it FAIL**. A condition whose failure mode cannot be described is not a gate and is not accepted.
- **A2.** The `designRevision` `JobDefinition` is specified field by field, with divergences from
  checkpoint 003 §10.2 named rather than silently reconciled.
- **A3.** `designApproval` is confirmed against what exists; any required enum addition is given as an
  exact addition.
- **A4.** The `planned`-convergence defect (§2.3) is specified with its resolution, and the resolution
  does not weaken `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`. **Revised in revision 2:** the resolution
  must be one the scheduler's **code** will honour — traced through `RunnableWorkEvaluator.evaluate`
  and `EntryHopper.prepare`, not inferred from a comment — and where a remedy cannot supply atomicity,
  the absence of atomicity and the lost-race behaviour must both be stated.
- **A5.** The interaction with the approved `qaPassed` decision is stated, and `qaPassed` is not
  reopened.
- **A6.** Undecidable items are stated plainly, not guessed.

### 5.2 Runtime acceptance (what an implementer will be held to — **not** this lane's to grant)

- **A7.** Every §3 condition has a named test, reachable in production, with a failing input — the
  non-vacuity discipline the approved QA artifact already established.
- **A8.** The independence rule is enforced by a test that fails when the designer's execution is not
  excluded.
- **A9.** No revision reaches `approved` without either a recorded LOW/MEDIUM-ungated policy decision
  or a human `designApproval` resolution.

### 5.3 What this brief explicitly does **not** accept

- Repairing the already-parked item. It is out of reach (§ preamble) and is not claimed.
- Any change to the meaning of `qaPassed`, `qaInProgress`, or any approved QA gate.

## 6. Risk assessment

**Level 3 — Major Workflow / Navigation / IA Change.**

This designs the runtime for a **core workflow stage that does not exist**, and it changes the meaning
of four states (`designRequired`, `designInReview`, `designApproved`, `designRejected`) and adds a
transition edge (`designRejected → designRequired`) to the one authority table that governs all
work-item movement. Per `DESIGN_GOVERNANCE.md:88-96` and checkpoint 003 §11, Level 3 requires
`HUMAN_DECISION_REQUIRED`.

**Gate D4 is therefore open on this artifact, and this lane does not close it.** What this lane raises
is the consequence that needs a human, stated once: **§4.6's fail-closed risk default** — that until a
`DesignRiskPolicy` exists, every revision is gated — is a product policy decision, not a technical one,
and it is the human's to ratify. It is specified in `design-revision.md` §5.6 with both options and a
recommendation.

## 7. Requirements traceability

| Requirement | Where |
|---|---|
| The `designRevision` lane's `JobDefinition`, and why `designRequired` is an entry state | `design-revision.md` §2 |
| Falsifiable pre/post conditions, each with its failing input | `design-revision.md` §3 |
| The `designApproval` gate, confirmed against existing machinery | `design-revision.md` §5 |
| The boundary change that makes `designRequired` entry truthful | `design-revision.md` §4 |
| Interaction with the approved `qaPassed` decision | `design-revision.md` §6 |
| What remains undecidable | `design-revision.md` §7 |

**Requirements gaps** — carried, not closed

| Gap | Disposition |
|---|---|
| G-1 The already-parked item cannot be retroactively completed | Out of scope by the human decision's own terms. Stated in the preamble and §4.7, not solved. |
| G-2 Risk-tier thresholds | Checkpoint 003 §9.5 declares them **unfinalized by the document itself**. Carried to §7. |
| G-3 `DesignRiskPolicy` has no representation at all | Carried to §4.5 / §7. |
| G-4 The fidelity anchor has no schema | **Content DECIDED** by operator decision `a1c7d904-3b8e-4f21-9d6e-5c2f81b7a390` and specified in `design-revision.md` §3.5. Still a **blocker on switching the runtime on**, not on designing it. Residue (owner, build order, implementation-side diff) carried to §7 U-3. |

## 8. References

- ADR 0021 — `docs/adr/0021-design-defect-routing.md`
- Checkpoint 003 — `docs/checkpoints/003-design-governance-automation-planning.md` (§7 independence, §8 correction loop, §9 risk, §10 jobs, §11 states)
- Checkpoint 002 — §12.4, §13.5, §14.5, §16
- `AGENTS.md` §1, §12, §13, §13a, §13b; shared-Docker-state rule
- `docs/engineering/DESIGN_GOVERNANCE.md` (artifact shapes, Gates D1–D5, risk levels)
- Approved QA artifact — `design/qa-contracts-feature-remediation/` (**read-only here**)
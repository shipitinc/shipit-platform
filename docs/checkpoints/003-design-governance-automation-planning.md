# CHECKPOINT 003 — DESIGN GOVERNANCE AUTOMATION

## 1. BASELINE

**Repository:** `shipit-platform`
**Branch:** `main` (HEAD at `6584e7d`)
**Dart SDK:** 3.12.2 stable
**Flutter:** 3.44.7 stable
**Serverpod:** 3.4.13
**PostgreSQL:** pgvector/pgvector:pg16
**Melos:** 8.6.0

**Existing packages:**
- `platform_contracts` — core types, enums, JSON schemas
- `workflow_engine` — state machine, transitions, guard conditions
- `workflow_store` — durable WorkItem/HumanDecision/history persistence
- `agent_runtime` — provider interface, adapters
- `worker_protocol` — capability model, task dispatch
- `worker_runtime` — worker selection/lease, worktree isolation
- `scheduler` — durable job queue (dedupe/claim-CAS/lease reconciliation)
- `execution_coordinator` — one bounded, durable agent execution
- `qa_orchestration` — gates, evidence, validation
- `deployment_protocol` — artifact promotion, deployments
- `store_contract_tests` — shared contract tests for store implementations
- `apps/server` — PostgreSQL-backed persistence, Serverpod endpoints
- `packages/control_plane_client` — generated Serverpod client
- `apps/control_plane` — Flutter Web operator UI

**Existing design-adjacent concepts (verified in source):**

| Concept | Location | What it actually is |
|---------|----------|---------------------|
| `AgentRole.designAgent` / `AgentRole.designReviewer` | `platform_contracts/lib/src/enums/agent_role.dart` | Role tokens ALREADY EXIST. Wire values `DESIGN_AGENT` / `DESIGN_REVIEWER` |
| `WorkItemState.designRequired`, `designInReview`, `designApproved`, `designRejected` | `platform_contracts/lib/src/enums/workflow_state.dart` | Design lifecycle states ALREADY EXIST (snake_case wire values) |
| `DesignContract` / `DesignContractStatus` | `platform_contracts/lib/src/types/design_contract.dart` | A *requirement* contract (which artifacts must be submitted, which reviewers, approval threshold). NOT a revision record |
| `HumanDecisionType.designApproval` / `designRejection` | `platform_contracts/lib/src/enums/human_decision.dart` | Human gate types ALREADY EXIST |
| `JobDefinition` | `scheduler/lib/src/policy/runnable_work.dart` | `jobType`, `requiredRole`, `requiredCapabilities`, `entryStates`, `priority`, `maxAttempts` |
| `JobType` | `platform_contracts/lib/src/enums/job_type.dart` | Exactly ONE value today: `implementFeature('implement_feature')` |
| `WorkerCapability` | `platform_contracts/lib/src/enums/worker_capability.dart` | Plain enum, 9 values (`linux`, `macos`, `docker`, `flutter`, `web`, `android`, `ios`, `xcode`, `gpu`). **No design capability exists.** **No `wire` field exists on this enum** |

**How design is actually done today — ad hoc.**

Design is currently produced by an operator driving the **Penpot MCP plugin**
(`penpot.execute_code`) interactively, against an open file. Consequences of the
current state, stated plainly:

- **No durable `DesignRevision` record.** There is no platform entity that says
  "this specific design state is the thing implementation is authorized against."
  The design's identity is a Penpot file that mutates in place.
- **No enforced independent review.** Nothing in the platform prevents the same
  actor from producing a design and declaring it acceptable.
- **No lineage.** A design change overwrites the previous state. There is no
  parent/child chain, no superseded marker, no way to answer "what exactly did we
  approve, and what changed since."
- **No risk model.** Every design change is treated the same, whether it is a
  spacing tweak on an approved pattern or a new destructive-action confirmation flow.
- **`DesignContract` is not a substitute.** It models *what must be submitted and
  who approves*, not *which immutable revision is the implementation authority*.
- **Design defects have nowhere governed to go.** Checkpoint 002 §13.5/§14.5
  routes `designDefect` remediation here and that route does not yet exist.

**Nothing in this checkpoint is implemented.** This is planning only.

---

## 2. FEATURE ID

```
DESIGN_GOVERNANCE_AUTOMATION_001
```

---

## 3. PROBLEM STATEMENT

ShipIt can govern *code* — bounded executions, independent review, QA evidence,
human gates, durable state. It cannot govern *design*. Five specific gaps:

### 3.1 No durable design revision identity

Implementation is told to "follow the Penpot design." The Penpot design is a
mutable document. There is no immutable, addressable, durable record that an
implementation agent, a reviewer, a QA gate, or a human can point at and say *this
is the authority*. When the file changes, every prior statement about "the design"
silently becomes false, and there is no record that it changed.

### 3.2 Designer self-approval is structurally possible

The platform already enforces independence for code review through role stamping
and `execution_coordinator`. Design has no equivalent. Today the same agent
execution can produce a design and produce the judgement that the design is good.
That is not review; it is self-certification. Independence must be a **platform
guarantee**, not a convention someone remembers to follow.

### 3.3 No targeted-correction model

When review finds one problem on one surface, the only available moves are
"regenerate everything" or "hand-edit and hope." Regenerating unaffected surfaces
destroys already-approved work, invalidates prior review, and makes the diff
unreviewable. There is no notion of *correct this surface, carry the rest forward,
re-review only what changed*.

### 3.4 No risk-based human gate

Either a human reviews every design change (unscalable, so it degrades into
rubber-stamping) or none (ungoverned). There is no tiering that says "a spacing
change on an approved pattern does not need a human, a new destructive-action
confirmation flow does."

### 3.5 Design defects have nowhere governed to go

`HUMAN_BUG_REPORTING_001` classifies defects as `designDefect` and asserts they
MUST NOT route to a coding agent (checkpoint 002 §13.4). It then has nowhere to
route them. Without this lifecycle, a `designDefect` either stalls or leaks into
the implementation path — which is exactly the failure mode checkpoint 002 forbids.

---

## 4. DESIGN LIFECYCLE

### 4.1 Pipeline

```
Requirement
     │
     ▼
Design Determination ──────────► DESIGN_NOT_REQUIRED ──► Implementation
     │ (DESIGN_REQUIRED)
     ▼
Design Brief
     │
     ▼
DesignJob ──────────────► DESIGN AGENT (AgentRole.designAgent)
     │                         │
     │                         ▼
     │                   DesignRevision (DES-R<N>, status: draft)
     │                         │
     ▼                         ▼
Automated Design QA (mechanical checks — no aesthetic judgement)
     │
     ├── fail ──► changes_required ──┐
     ▼                               │
DesignReviewJob                      │
     │                               │
     ▼                               │
INDEPENDENT DESIGN REVIEW AGENT      │
 (AgentRole.designReviewer,          │
  reviewerExecutionId ≠              │
  designerExecutionId)               │
     │                               │
     ▼                               │
DesignReviewResult + findings[]      │
     │                               │
     ├── changes_required ───────────┤
     │                               │
     │   ┌───────────────────────────┘
     │   ▼
     │  TARGETED REVISION (new DES-R<N+1>, parentRevisionId set)
     │   │
     │   └──► re-review ONLY affected surfaces ──┐
     │                                           │
     │   ◄───────────────────────────────────────┘
     │        (loop, bounded by maxAttempts)
     │
     ├── approved / approved_with_minor_findings
     ▼
Design Risk Classification (DATA-driven policy)
     │
     ├── LOW / MEDIUM(policy=false) ──► approved
     │
     └── HIGH / MEDIUM(policy=true)
              ▼
     human_approval_required
              ▼
     HumanDecision (designApproval / designRejection)
              │
              ├── reject ──► changes_required (loop) or designRejected
              ▼
          approved
              │
              ▼
IMPLEMENTATION_AUTHORITATIVE DesignRevision
              │
              ▼
        Implementation
```

### 4.2 Stage table

| # | Stage | Actor | Input | Output | Durable record |
|---|-------|-------|-------|--------|----------------|
| 1 | Requirement | Human / upstream WorkItem | Product intent | WorkItem | `work_item` |
| 2 | Design Determination | Workflow policy | WorkItem category + surface impact | `DESIGN_REQUIRED` or `DESIGN_NOT_REQUIRED` | `WorkItemState.designRequired` / `designNotRequired` + `workflow_transition_record` |
| 3 | Design Brief | Human / requirement authority | Requirement, surfaces, states, responsive targets | Structured brief | `design_brief` (JSON on the design job payload; see §10) |
| 4 | DesignJob dispatch | `scheduler` | Brief + `JobDefinition` | Claimed job, leased worker | `job`, `job_claim` |
| 5 | Design production | **Design agent** (`AgentRole.designAgent`) | Brief + design system revision + parent revision (if correction) | Penpot boards + artifact refs | `agent_execution`, `design_revision` (status `draft`) |
| 6 | Automated Design QA | Platform (no agent judgement) | `DesignRevision` | Mechanical pass/fail | `design_revision.status`, `platform_verification` |
| 7 | DesignReviewJob dispatch | `scheduler` | Revision + review scope | Claimed job | `job` |
| 8 | Independent design review | **Design reviewer** (`AgentRole.designReviewer`) | Revision, brief, design system, review scope | `DesignReviewResult` + `DesignFinding[]` | `agent_execution`, `design_review_result`, `design_finding` |
| 9 | Targeted correction | Design agent | Findings scoped to affected surfaces | New `DesignRevision` (parent set) | `design_revision` (new row, parent lineage) |
| 10 | Re-review | Design reviewer | New revision + recorded review scope | `DesignReviewResult` | `design_review_result` |
| 11 | Risk classification | Platform policy (DATA) | Brief + revision + findings | LOW / MEDIUM / HIGH | `design_revision.riskTier` |
| 12 | Human approval (risk-gated) | Human | Revision + review results | approve / reject / rework | `human_decision` |
| 13 | Implementation authority | Platform | Approved revision | Immutable approval target | `design_revision.status = approved` |
| 14 | Implementation | Implementation agent | **Approved revision only** | Code | `work_item`, `agent_execution` |

**Stage 6 is deliberately mechanical.** Automated Design QA checks structure —
required boards present, required states represented, responsive targets covered,
design-system tokens referenced rather than raw values, artifact refs resolvable.
It does **not** judge whether the design is good. Aesthetic judgement is explicitly
out of scope (§16).

---

## 5. DESIGN REVISION CONTRACT

### 5.1 Purpose

`DesignRevision` is the durable, immutable answer to *"what exactly is
implementation authorized to build?"* It is the missing entity identified in §3.1.
It is **not** a replacement for `DesignContract` — `DesignContract` says what must be
submitted and who approves; `DesignRevision` is a specific submitted state with an
identity, lineage, and status.

### 5.2 Identity

`DES-R<N>` — monotonically increasing per work item (e.g. `DES-R7`, `DES-R8`).
Stable, durable, independently addressable. The identifier is assigned by the
platform, never by an agent.

### 5.3 Fields

| Field | Type | Meaning |
|-------|------|---------|
| `designRevisionId` | `String` | `DES-R<N>`. Platform-assigned, stable |
| `workItemId` | `String` | Owning WorkItem |
| `featureId` | `String` | Feature this revision serves (e.g. `HUMAN_BUG_REPORTING_001`) |
| `parentRevisionId` | `String?` | Revision this one corrects. `null` for the first revision of a work item |
| `designSystemRevision` | `String` | Which design-system/visual-language version this revision was produced against. Prevents "approved against a since-changed system" |
| `designProvider` | `String` | Provider instance identity (opaque). Provider-neutral field |
| `designProviderType` | `DesignProviderType` | Wire enum; first value `penpot('penpot')` |
| `penpotFileId` | `String?` | Provider-specific locator. Nullable because the contract is provider-neutral |
| `penpotPageId` | `String?` | Provider-specific locator |
| `boardIds` | `List<String>` | The boards constituting this revision |
| `responsiveTargets` | `List<String>` | Breakpoints/targets covered (e.g. `desktop_1280`, `tablet_834`, `mobile_390`) |
| `statesRepresented` | `List<String>` | UI states designed (e.g. `empty`, `loading`, `populated`, `error`, `disabled`) |
| `artifactRefs` | `List<String>` | `ArtifactReference` ids for exported renders/specs |
| `designerExecutionId` | `String` | `AgentExecution` that PRODUCED this revision |
| `reviewExecutionIds` | `List<String>` | `AgentExecution`s that REVIEWED this revision |
| `status` | `DesignRevisionStatus` | See §5.4 |
| `riskTier` | `DesignRiskTier` | Assigned at §9 classification |
| `reviewScopeJson` | `String?` | For targeted corrections: which surfaces are in scope for re-review (§8) |
| `carriedForwardFromRevisionId` | `String?` | Revision whose unaffected approved surfaces are carried forward |
| `createdAt` | `DateTime` | Creation timestamp |
| `approvedAt` | `DateTime?` | Set once, on transition to `approved` |
| `supersededByRevisionId` | `String?` | Set when a later revision supersedes this one |

### 5.4 DesignRevisionStatus

Wire values are **snake_case**, matching the convention verified in
`workflow_state.dart` (`design_required`, `waiting_for_human_decision`) and
`human_decision.dart` (`in_progress`, `design_approval`).

```dart
enum DesignRevisionStatus {
  draft('draft'),
  inReview('in_review'),
  changesRequired('changes_required'),
  reviewPassed('review_passed'),
  humanApprovalRequired('human_approval_required'),
  approved('approved'),
  superseded('superseded');

  const DesignRevisionStatus(this.wire);
  final String wire;
}
```

| Status | Meaning |
|--------|---------|
| `draft` | Produced by the design agent. Not yet reviewed |
| `inReview` | A `DesignReviewJob` is active against this revision |
| `changesRequired` | Independent review returned blocking/major findings |
| `reviewPassed` | Independent review passed. Risk classification pending or LOW |
| `humanApprovalRequired` | Risk tier requires a human gate. A blocking `HumanDecision` exists |
| `approved` | **Implementation-authoritative.** Immutable |
| `superseded` | A later revision replaced this one as authority |

### 5.5 IMMUTABILITY RULE (explicit, hard)

> **An approved `DesignRevision` is an immutable approval target.**
>
> Once `status == approved`, the revision's design content — `boardIds`,
> `responsiveTargets`, `statesRepresented`, `artifactRefs`, `designSystemRevision`,
> `designerExecutionId`, `parentRevisionId` — **MUST NEVER** be mutated.
>
> Any **material modification** to the design creates a **NEW** `DesignRevision`
> with `parentRevisionId` set to the revision being modified. The prior revision
> transitions to `superseded` with `supersededByRevisionId` set.
>
> The only fields mutable after approval are the supersession markers
> (`status → superseded`, `supersededByRevisionId`) and append-only
> `reviewExecutionIds`. Nothing else.

**Material modification** means any change to what implementation would build:
board content, layout, states, responsive behaviour, component usage, copy that
carries meaning, interaction affordances. Renaming a Penpot layer with no visual or
behavioural consequence is not material; the platform does not attempt to
auto-detect this — the design agent declares whether a change is material, and the
independent reviewer verifies the declaration.

**Why this is hard, not advisory.** Without it, "we approved DES-R7" is not a fact.
An approved revision that can change underneath implementation is indistinguishable
from having no approval at all, which is the current state (§1).

**Enforcement:** database-level (no UPDATE of content columns where
`status = 'approved'`) plus domain-level guard in the revision store. A violation is
rejected, not warned about.

### 5.6 PostgreSQL table sketch

**Table:** `design_revision`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `designRevisionId` | `text` UNIQUE | `DES-R7` |
| `workItemId` | `text` NOT NULL | FK → work_item |
| `featureId` | `text` NOT NULL | |
| `parentRevisionId` | `text` | FK → design_revision.designRevisionId (nullable) |
| `carriedForwardFromRevisionId` | `text` | FK → design_revision.designRevisionId (nullable) |
| `supersededByRevisionId` | `text` | FK → design_revision.designRevisionId (nullable) |
| `designSystemRevision` | `text` NOT NULL | |
| `designProvider` | `text` NOT NULL | Opaque provider instance identity |
| `designProviderType` | `text` NOT NULL | Wire value of `DesignProviderType` |
| `penpotFileId` | `text` | Provider-specific locator (nullable) |
| `penpotPageId` | `text` | Provider-specific locator (nullable) |
| `boardIdsJson` | `text` NOT NULL | JSON array |
| `responsiveTargetsJson` | `text` NOT NULL | JSON array |
| `statesRepresentedJson` | `text` NOT NULL | JSON array |
| `artifactRefsJson` | `text` NOT NULL | JSON array of `artifactId` |
| `designerExecutionId` | `text` NOT NULL | FK → agent_execution |
| `reviewExecutionIdsJson` | `text` NOT NULL | JSON array, append-only |
| `status` | `text` NOT NULL | Wire value of `DesignRevisionStatus` |
| `riskTier` | `text` | Wire value of `DesignRiskTier` (nullable until classified) |
| `reviewScopeJson` | `text` | Scope for targeted re-review (nullable) |
| `metadataJson` | `text` | Extensible metadata |
| `createdAt` | `timestamp` NOT NULL | |
| `updatedAt` | `timestamp` NOT NULL | |
| `approvedAt` | `timestamp` | Set once |
| `version` | `bigint` NOT NULL | CAS version |

**Indexes / constraints:**

| Constraint | Purpose |
|------------|---------|
| `UNIQUE (designRevisionId)` | Stable identity |
| `INDEX (workItemId, createdAt)` | Revision history per work item |
| `INDEX (parentRevisionId)` | Lineage traversal |
| `UNIQUE (workItemId) WHERE status = 'approved'` | **At most one implementation-authoritative revision per work item at a time** |
| `CHECK (designerExecutionId IS NOT NULL)` | Producer always recorded |
| Trigger / rule: reject UPDATE of content columns when `OLD.status = 'approved'` | §5.5 immutability, enforced below the application |

**Table:** `design_revision_event` (append-only history, mirroring checkpoint 002's
`defect_event` pattern)

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `eventId` | `text` UNIQUE | `DRE-<NNNNNN>` |
| `designRevisionId` | `text` NOT NULL | FK → design_revision.designRevisionId |
| `sequence` | `bigint` NOT NULL | Monotonic per revision |
| `type` | `text` NOT NULL | e.g. `created`, `review_started`, `review_completed`, `risk_classified`, `human_gate_opened`, `approved`, `superseded` |
| `fromStatus` | `text` | nullable |
| `toStatus` | `text` | nullable |
| `actorType` | `text` NOT NULL | Wire value of `ActorType` |
| `actorId` | `text` | |
| `payloadJson` | `text` | Structured payload |
| `occurredAt` | `timestamp` NOT NULL | |

---

## 6. DESIGN REVIEW CONTRACT

### 6.1 DesignReviewResult

The structured output of one independent review execution. It is **data**, not prose.
An agent that returns unstructured text has failed the contract and the job fails
validation.

| Field | Type | Meaning |
|-------|------|---------|
| `designReviewId` | `String` | `DRV-<NNNNNN>` |
| `designRevisionId` | `String` | Revision under review |
| `workItemId` | `String` | Owning WorkItem |
| `reviewerExecutionId` | `String` | `AgentExecution` that performed the review |
| `reviewScope` | `DesignReviewScope` | `full` or `targeted` + affected surfaces (§8) |
| `requirementCoverage` | `DimensionAssessment` | Does the design satisfy the stated requirement? |
| `designSystemCompliance` | `DimensionAssessment` | Tokens, components, spacing, type scale |
| `productConsistency` | `DimensionAssessment` | Consistent with the rest of the product |
| `interactionCompleteness` | `DimensionAssessment` | All states and transitions designed |
| `responsiveCoverage` | `DimensionAssessment` | All declared responsive targets covered |
| `accessibility` | `DimensionAssessment` | Contrast, target size, focus order, semantics |
| `implementationFeasibility` | `DimensionAssessment` | Buildable in the target framework |
| `apiDataFeasibility` | `DimensionAssessment` | The data shown can actually be obtained |
| `findings` | `List<DesignFinding>` | Zero or more |
| `verdict` | `DesignReviewVerdict` | See §6.3 |
| `reviewerModelDiversity` | `ReviewerModelDiversity` | Factual attribute, **never a verdict input** (§7.2.1). A value of `same_family` or `not_available` does **not** affect `verdict` and is not a finding |
| `startedAt` | `DateTime` | |
| `completedAt` | `DateTime` | |

`DimensionAssessment` is a small record: `{ assessed: bool, passed: bool,
findingIds: List<String>, note: String }`. `assessed == false` is legal **only** for
a `targeted` review where the dimension is out of the recorded review scope — and
the reason must reference the scope.

### 6.2 DesignFinding

| Field | Type | Meaning |
|-------|------|---------|
| `findingId` | `String` | `DFN-<NNNNNN>` |
| `severity` | `DesignFindingSeverity` | See §6.4 |
| `category` | `DesignFindingCategory` | Which dimension it belongs to |
| `affectedSurface` | `String` | The specific board/surface (e.g. `Decision Detail`). **This is what makes targeted correction possible** |
| `evidence` | `String` | Concrete, checkable observation — what was seen, where |
| `requiredCorrection` | `String` | What must change. Not "improve this"; a specific correction |

A finding without an `affectedSurface` cannot drive a targeted correction and is
rejected by output validation.

### 6.3 DesignReviewVerdict

```dart
enum DesignReviewVerdict {
  approved('approved'),
  approvedWithMinorFindings('approved_with_minor_findings'),
  changesRequired('changes_required');

  const DesignReviewVerdict(this.wire);
  final String wire;
}
```

| Verdict | Meaning | Effect |
|---------|---------|--------|
| `approved` | No blocker/major findings | → `reviewPassed` |
| `approvedWithMinorFindings` | Minor/advisory findings recorded but not blocking | → `reviewPassed`; findings persist and are visible at the human gate |
| `changesRequired` | At least one blocker or major finding | → `changesRequired`; correction loop (§8) |

**Consistency rule:** a verdict of `approved` or `approvedWithMinorFindings` with a
`blocker` or `major` finding present is a contradiction and is rejected by output
validation. The verdict is derived-checkable, not merely asserted.

### 6.4 DesignFindingSeverity

```dart
enum DesignFindingSeverity {
  blocker('blocker'),
  major('major'),
  minor('minor'),
  advisory('advisory');

  const DesignFindingSeverity(this.wire);
  final String wire;
}
```

| Severity | Meaning |
|----------|---------|
| `blocker` | The design cannot be implemented as-is, or would produce a wrong product |
| `major` | Significant defect; implementation would produce a materially worse result |
| `minor` | Real but non-blocking; may be carried or corrected |
| `advisory` | Observation/suggestion; carries no authority |

### 6.5 PostgreSQL table sketch

**Table:** `design_review_result`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `designReviewId` | `text` UNIQUE | `DRV-000001` |
| `designRevisionId` | `text` NOT NULL | FK → design_revision.designRevisionId |
| `workItemId` | `text` NOT NULL | FK → work_item |
| `reviewerExecutionId` | `text` NOT NULL | FK → agent_execution |
| `reviewScopeJson` | `text` NOT NULL | `full` / `targeted` + surfaces |
| `dimensionsJson` | `text` NOT NULL | All eight `DimensionAssessment` records |
| `verdict` | `text` NOT NULL | Wire value of `DesignReviewVerdict` |
| `reviewerModelDiversity` | `text` NOT NULL | Wire value of `ReviewerModelDiversity`. **No CHECK constraint ties it to `verdict`** — it is an attribute, not a gate (§7.2.1) |
| `startedAt` | `timestamp` NOT NULL | |
| `completedAt` | `timestamp` NOT NULL | |
| `createdAt` | `timestamp` NOT NULL | |

**Constraint:** `CHECK (reviewerExecutionId <> (SELECT designerExecutionId ...))`
cannot be expressed as a plain column CHECK; it is enforced as a trigger plus a
domain guard — see §7.3.

**Table:** `design_finding`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `findingId` | `text` UNIQUE | `DFN-000001` |
| `designReviewId` | `text` NOT NULL | FK → design_review_result.designReviewId |
| `designRevisionId` | `text` NOT NULL | Denormalized for lineage queries |
| `severity` | `text` NOT NULL | Wire value of `DesignFindingSeverity` |
| `category` | `text` NOT NULL | Wire value of `DesignFindingCategory` |
| `affectedSurface` | `text` NOT NULL | |
| `evidence` | `text` NOT NULL | |
| `requiredCorrection` | `text` NOT NULL | |
| `resolvedByRevisionId` | `text` | Set when a later revision corrects it (nullable) |
| `createdAt` | `timestamp` NOT NULL | |

---

## 7. INDEPENDENCE RULE

### 7.1 HARD rule — enforced by the platform

> **`reviewerExecutionId` MUST NOT equal `designerExecutionId` for the revision
> under review.**

This is enforced by the platform, not by prompt, convention, or agent cooperation.
An attempt to record a `DesignReviewResult` where the reviewer execution is the
designer execution is **rejected** — the write fails, the job fails, and the
violation is recorded as a `design_revision_event`. It is not downgraded to a
warning and not permitted with a rationale.

Additional hard constraints on the same principle:

| Constraint | Rule |
|------------|------|
| Execution identity | `reviewerExecutionId ≠ designerExecutionId` |
| Role stamping | The reviewer execution MUST be stamped `AgentRole.designReviewer`; the designer execution MUST be stamped `AgentRole.designAgent`. An execution does not choose its own role (`execution_coordinator` boundary) |
| Capability | The reviewer worker MUST hold `penpot_read` and MUST NOT hold `penpot_write` (§7.6) |
| Self-supersession | A designer execution may not mark its own revision `approved`. Only the platform, after a qualifying review (and human gate where required), sets `approved` |

### 7.2 SELECTION PREFERENCE — reviewer model diversity

> **This preference has NO violation state. A same-family review is FULLY
> COMPLIANT and must never be reported as a violation, limitation, caveat,
> deficiency, or "partial satisfaction" of the independence rule.**

Where practical, worker selection SHOULD prefer a reviewer whose model family
differs from the designer's, because a reviewer sharing the designer's blind
spots detects less. That is the whole content of the preference: a **dispatch-time
selection heuristic**, nothing more.

**It is not an acceptance criterion and not a rule.** Design-review independence
is defined by §7.1 and by §7.1 alone. A review that satisfies §7.1 is a complete,
valid, independent review *regardless of model family*. It is therefore:

| Model diversity is… | Model diversity is NOT… |
|---|---|
| a recorded factual attribute of a review (§7.2.1) | a requirement, gate, or acceptance criterion |
| an input to worker selection when a choice exists | grounds for a finding, warning, or re-review |
| a quality heuristic | a component of "independence" |

#### 7.2.1 Recorded value — an attribute, not a verdict

Because a preference cannot be "violated", the platform records **which of four
factual states applies**, and no state is a defect:

```dart
enum ReviewerModelDiversity {
  diverse('diverse'),               // reviewer and designer families differ
  sameFamily('same_family'),        // same family, and an alternative existed
  notAvailable('not_available'),    // deployment offers only one model family
  unknown('unknown');               // family not reported by worker registration

  const ReviewerModelDiversity(this.wire);
  final String wire;
}
```

Stored on `DesignReviewResult.reviewerModelDiversity` (§6.1, §6.5).

**Current deployment status: `not_available`.** `agent_runtime` ships exactly one
provider adapter (`opencode`, ADR-0006) and a second provider is explicitly
deferred (§17, DI-10). There is no second model family to select, so diversity is
not a choice that is being declined — the option does not exist. Recording
`not_available` is the accurate, complete, and compliant outcome.

#### 7.2.2 Required disclosure wording — use this, verbatim

Prior sessions repeatedly re-derived alarmed prose about this preference and
propagated it into three documents as a standing caveat on otherwise-valid
reviews. To stop that, the disclosure is **fixed text in a structured field**, not
narrative:

> `reviewerModelDiversity: not_available` — reviewer and designer ran on the only
> model family available to this deployment. Execution independence (§7.1) is
> satisfied.

Nothing further is required. In particular, **do not** write any of the
following, all of which have appeared in the record and all of which are wrong:

| ❌ Do not write | Why it is wrong |
|---|---|
| "satisfies the HARD rule but not the SOFT preference" | Implies a two-part standard was half-met. There is one standard: §7.1 |
| "independence limitation — stated honestly" | There is no limitation on independence; §7.1 is fully satisfied |
| "model-family independence was **not** achieved" | "Model-family independence" is not a defined concept. Independence is execution identity |
| "do not describe this review as model-diverse" | Correct but redundant; the recorded enum already states the fact |

Stating the recorded value is honest. Adding a caveat around it is not *more*
honest — it manufactures a deficiency that the rule never defined, and it dilutes
the real findings it sits beside.

#### 7.2.3 What actually compensates, and why this is not a loophole

Same-family review genuinely does detect less. That is an argument for
**strengthening the checks that do not depend on model diversity**, not for
treating every review as suspect:

| Compensating control | Independent of model family? |
|---|---|
| §7.1 execution identity + role stamping | ✅ platform-enforced |
| §7.6 reviewer capability is read-only (cannot "fix" what it finds) | ✅ structural |
| Stage 6 mechanical Automated Design QA | ✅ deterministic, no model judgement |
| §9.4 HIGH-tier human gate | ✅ a human, not a model |
| Visual inspection of rendered output by a human | ✅ |

The honest summary is: **the platform guarantees execution independence and
mechanical verification; it does not guarantee cognitive diversity, and it does
not claim to.**

The underlying distinction is retained, but state it as **enforced rule vs.
recorded attribute** rather than as "HARD vs SOFT" — the latter framing is what
led to reviews being described as half-compliant:

| | §7.1 execution independence | §7.2 model diversity |
|---|---|---|
| Nature | correctness property the platform can guarantee | heuristic it can only prefer |
| Treatment | **enforced** — write rejected, job fails | **recorded** — attribute only |
| Can it be violated? | **Yes** | **No — it has no violation state** |
| Affects `verdict`? | Yes, fatally | Never |

Conflating the two would either weaken the enforced rule or fail the pipeline for
something that is not a correctness problem.

### 7.3 Enforcement points

| Layer | Enforcement |
|-------|-------------|
| Scheduler | `DesignReviewJob` dispatch excludes the designer execution's worker/session from selection |
| `execution_coordinator` | Stamps the role; the agent never declares its own role |
| Domain store | `recordDesignReview(...)` guard rejects `reviewerExecutionId == designerExecutionId` |
| Database | Trigger on `design_review_result` insert comparing against `design_revision.designerExecutionId` |
| Output validation | A review result naming its own producing execution is invalid regardless of content |

Defence in depth is deliberate: a single check in one layer is a single point of
silent failure for the property that makes the entire review meaningful.

### 7.4 CRITICAL — no model names in policy

> **Claude, GPT, Gemini, and OpenCode MUST NEVER appear in workflow policy,
> workflow state, job definitions, capability tokens, or independence rules.**

Policy encodes **roles + capabilities + independence constraints**, and nothing
else. This follows the existing repository boundary (AGENTS.md §8: "Hardcoded
OpenCode logic outside `agent_runtime/adapters/opencode`" is forbidden; `job_type.dart`
explicitly documents "there are NO OpenCode-specific job types").

| Allowed in policy | Forbidden in policy |
|-------------------|---------------------|
| `AgentRole.designAgent`, `AgentRole.designReviewer` | Any provider or model name |
| `WorkerCapability.visualDesign`, `penpotWrite`, `visualDesignReview`, `penpotRead` | "use the Claude worker for review" |
| `reviewerExecutionId ≠ designerExecutionId` | "reviewer must be GPT if designer was Claude" |
| `ReviewerModelDiversity` recorded as a factual attribute (§7.2.1) | Model-selection *policy* (out of scope, §16), or treating model family as an acceptance criterion |

Provider/model identity lives in `agent_runtime` adapters and worker registration
metadata. The workflow engine and scheduler consume roles and capabilities only.

### 7.5 AgentRole reconciliation finding

**Finding: `designAgent` and `designReviewer` ALREADY EXIST. No new `AgentRole`
value is required for this lifecycle. Reuse them; do not invent duplicates.**

Verified in `packages/platform_contracts/lib/src/enums/agent_role.dart` (11 values):

| Existing value | Wire | Used by this lifecycle? |
|----------------|------|-------------------------|
| `implementer` | `IMPLEMENTER` | Yes — implements the approved revision |
| `engineeringReviewer` | `ENGINEERING_REVIEWER` | No |
| **`designAgent`** | **`DESIGN_AGENT`** | **YES — produces `DesignRevision`. REUSE** |
| **`designReviewer`** | **`DESIGN_REVIEWER`** | **YES — independent review. REUSE** |
| `qaArchitect` | `QA_ARCHITECT` | No |
| `qaExecutor` | `QA_EXECUTOR` | No |
| `releaseEngineer` | `RELEASE_ENGINEER` | No |
| `deploymentAuthority` | `DEPLOYMENT_AUTHORITY` | No |
| `correctionImplementer` | `CORRECTION_IMPLEMENTER` | Candidate for targeted correction; see note |
| `focusedReviewer` | `FOCUSED_REVIEWER` | Candidate for targeted re-review; see note |
| `integrator` | `INTEGRATOR` | No |

**Note on `correctionImplementer` / `focusedReviewer`:** these existing values are
semantically close to §8's targeted correction and scoped re-review. This checkpoint
does **not** introduce a `designCorrectionAgent` or `scopedDesignReviewer`. The
recommendation is to reuse `designAgent` + `designReviewer` with a recorded
`reviewScope`, because the *role* is unchanged and only the *scope* narrows. Whether
`correctionImplementer`/`focusedReviewer` should instead be used for the design
correction loop is a **deferred decision** (§17, DI-1) — it must not be settled by
silently adding a duplicate design role.

**Wire-value convention caveat (honest reconciliation):** `AgentRole` uses
`SCREAMING_SNAKE_CASE` wire values (`DESIGN_AGENT`), whereas `WorkItemState`,
`HumanDecisionType`, `JobType`, and the enums proposed in this document use
snake_case (`design_required`, `design_approval`, `implement_feature`). This
inconsistency **already exists in the repository**. This checkpoint does not change
it — changing `AgentRole` wire values is a breaking schema change requiring its own
ADR (§17, DI-2). New enums introduced here follow the dominant snake_case convention.

### 7.6 WorkerCapability reconciliation + proposal

**Finding: `WorkerCapability` currently has 9 values — `linux`, `macos`, `docker`,
`flutter`, `web`, `android`, `ios`, `xcode`, `gpu` — and NO design capability. It is
also a plain Dart enum with NO `wire` field**, unlike `AgentRole`, `WorkItemState`,
`JobType`, etc.

**Proposed new values:**

| Proposed value | Wire | Meaning | Held by |
|----------------|------|---------|---------|
| `visualDesign` | `visual_design` | Can produce visual design work | Design agent worker |
| `penpotWrite` | `penpot_write` | Can mutate the design provider's documents | Design agent worker |
| `visualDesignReview` | `visual_design_review` | Can perform structured design review | Design reviewer worker |
| `penpotRead` | `penpot_read` | Can read the design provider's documents | Design reviewer worker **and** design agent worker |

**Capability separation — the reviewer must be read-only:**

| Worker | `visual_design` | `penpot_write` | `visual_design_review` | `penpot_read` |
|--------|-----------------|----------------|------------------------|---------------|
| Design agent | ✅ | ✅ | ❌ | ✅ |
| **Design reviewer** | ❌ | **❌ MUST NOT** | ✅ | ✅ **MUST** |

> **HARD rule:** the reviewer role **MUST hold `penpot_read`** and **MUST NOT hold
> `penpot_write`.**

A reviewer that can write the design can "fix" what it finds instead of reporting
it, which collapses review back into self-certification (§3.2) through a different
door. Capability separation makes the independence property structural rather than
behavioural: the reviewer is incapable of the violation, not merely instructed
against it.

**Note on naming:** `penpot_read` / `penpot_write` name a provider in a *capability
token*, which sits uneasily beside §7.4. The distinction: capability tokens describe
what a **worker can physically do** (like the existing `xcode`, `docker`), whereas
policy must not encode which **model/provider performs a role**. `xcode` sets the
precedent. A provider-neutral alternative (`design_tool_read` / `design_tool_write`)
is a **deferred decision** (§17, DI-3); this checkpoint records both the requested
naming and the tension rather than silently choosing.

**Enum shape change required:** adding wire values to `WorkerCapability` means adding
a `wire` field and `fromWire` to an enum that currently has neither. That is a
contract change to an enum whose doc comment states "Tokens are additive; removing
one is a breaking schema change." Adding values is additive and allowed; adding the
`wire` field changes serialization and must be done deliberately, with schema
regeneration.

---

## 8. CORRECTION LOOP

### 8.1 Principle

When review finds a problem on one surface, the platform corrects **that surface**
and carries the rest forward. It does not regenerate approved work.

Three rules:

1. **Unaffected approved surfaces are CARRIED FORWARD, not regenerated.** The new
   revision references them; the design agent does not re-produce them.
2. **Re-review is scoped to affected surfaces.** The reviewer does not re-assess
   what did not change.
3. **The review scope is RECORDED** on both the revision (`reviewScopeJson`) and the
   review result. A scoped review that is not recorded as scoped is
   indistinguishable from a full review that skipped dimensions — which would make
   the approval record dishonest.

### 8.2 Worked example — DES-R7 → DES-R8

**Starting state.** `DES-R7` covers four boards for `wi-4821`:

| Board | State after full review of DES-R7 |
|-------|-----------------------------------|
| Decisions List | passed |
| **Decision Detail** | **finding** |
| Decision Confirmation | passed |
| Empty State | passed |

**Review of DES-R7:**

```
DesignReviewResult DRV-000019
  designRevisionId:     DES-R7
  reviewerExecutionId:  ae-7742   (≠ designerExecutionId ae-7731 ✓)
  reviewScope:          full
  verdict:              changes_required
  findings: [
    DFN-000044
      severity:            major
      category:            interaction_completeness
      affectedSurface:     "Decision Detail"
      evidence:            "Rejection path shows no confirmation state and no
                            post-rejection result state. statesRepresented
                            declares 'error' but no error board exists for
                            this surface."
      requiredCorrection:  "Add rejection confirmation state and post-rejection
                            result state to Decision Detail, covering all three
                            declared responsive targets."
  ]
```

→ `DES-R7.status = changes_required`.

**Targeted correction.** The platform enqueues a `DesignJob` whose scope is
**exactly** `["Decision Detail"]`, derived from the distinct `affectedSurface`
values of the blocker/major findings.

```
DesignRevision DES-R8
  parentRevisionId:              DES-R7
  carriedForwardFromRevisionId:  DES-R7
  workItemId:                    wi-4821
  designSystemRevision:          ds-2026.09.1   (unchanged — see §8.4)
  designerExecutionId:           ae-7755
  boardIds:                      [Decisions List, Decision Detail,
                                  Decision Confirmation, Empty State]
  reviewScopeJson:               {"kind":"targeted",
                                  "surfaces":["Decision Detail"],
                                  "carriedForward":["Decisions List",
                                                    "Decision Confirmation",
                                                    "Empty State"],
                                  "resolvesFindings":["DFN-000044"]}
  status:                        draft
```

Only **Decision Detail** was produced by `ae-7755`. The other three boards are
carried forward from `DES-R7` by reference. `DES-R7 → superseded`,
`supersededByRevisionId = DES-R8`.

**Scoped re-review.**

```
DesignReviewResult DRV-000023
  designRevisionId:     DES-R8
  reviewerExecutionId:  ae-7768   (≠ ae-7755 ✓)
  reviewScope:          targeted — surfaces: ["Decision Detail"]
  interactionCompleteness: assessed=true,  passed=true,
                           note="Rejection confirmation + post-rejection result
                                 states present across desktop_1280,
                                 tablet_834, mobile_390"
  responsiveCoverage:      assessed=true,  passed=true
  accessibility:           assessed=true,  passed=true
  designSystemCompliance:  assessed=true,  passed=true
  requirementCoverage:     assessed=false, note="Out of recorded review scope;
                                 carried forward from DRV-000019 (DES-R7)"
  productConsistency:      assessed=false, note="out of scope — carried forward"
  implementationFeasibility: assessed=false, note="out of scope — carried forward"
  apiDataFeasibility:      assessed=false, note="out of scope — carried forward"
  findings:                []
  verdict:                 approved
```

→ `DES-R8.status = reviewPassed` → risk classification (§9) → gate or `approved`.

**Result.** `DFN-000044.resolvedByRevisionId = DES-R8`. Three boards were never
regenerated and never re-reviewed. The lineage `DES-R7 → DES-R8` is durable and
inspectable, and the scoped nature of DRV-000023 is explicit in the record.

### 8.3 Carry-forward integrity rules

| Rule | Why |
|------|-----|
| A surface may be carried forward only if it passed review in the parent revision | Carrying forward an unreviewed surface launders it into approval |
| Carry-forward is by reference to the parent revision, not by copy | Copying creates drift and two sources of truth |
| Every board in `boardIds` must be either in scope or explicitly carried forward | No board may be silently unaccounted for |
| A carried-forward surface's dimension assessments are inherited from the parent review and recorded as inherited | The approval record must never claim an assessment that this review did not perform |

### 8.4 Loop bounds and design-system invalidation

- The correction loop is bounded by the `DesignReviewJob`'s `maxAttempts`. On
  exhaustion the work item routes to a human decision, not an infinite retry.
- **If `designSystemRevision` changes, carry-forward is invalid.** Surfaces approved
  against an older design system have not been reviewed against the current one. A
  design-system change forces a full review, not a targeted one.
- A `blocker` finding on a surface that was **carried forward** invalidates the
  carry-forward claim and forces a full re-review of the revision.

---

## 9. DESIGN RISK MODEL

### 9.1 Tiers

```dart
enum DesignRiskTier {
  low('low'),
  medium('medium'),
  high('high');

  const DesignRiskTier(this.wire);
  final String wire;
}
```

### 9.2 LOW

**Criteria:** existing approved pattern **AND** no consequential interaction **AND**
no new product decision.

**Path:** designer → independent reviewer → implementation. **No human gate.**

Examples: applying an already-approved list pattern to a new data type; adding a
declared-but-missing state to an existing approved surface; spacing/type correction
within the design system.

### 9.3 MEDIUM

**Criteria:** new screen or new composition **AND** known interaction pattern **AND**
moderate visual/product impact.

**Path:** designer → independent reviewer → **policy MAY require human approval**.

The "MAY" is the point: this is the tier where the human gate is a *configurable
policy decision*, not a fixed property of the tier. Configuration is data (§9.6).

Examples: a new list-plus-detail screen built from approved components; a new filter
composition on an existing surface; a new empty-state treatment.

### 9.4 HIGH

**Criteria — any one of:**

| Criterion | Why it is HIGH |
|-----------|----------------|
| New product interaction | The design is deciding product behaviour, not rendering it |
| Human authority UI | Anything through which a human exercises authority (approvals, gates, Needs You). Getting this wrong corrupts the governance record itself |
| Destructive behaviour | Delete, terminate, cancel, rollback, irreversible actions |
| Navigation architecture | Changes how the whole product is traversed; expensive and disruptive to reverse |
| Security-sensitive flow | Auth, permissions, credential handling, anything with a security consequence |
| Major visual-language change | Affects every surface; cannot be corrected per-surface later |

**Path:** designer → independent reviewer → **`HUMAN_DESIGN_APPROVAL_REQUIRED`** →
implementation. The human gate is mandatory and blocking.

Implemented with the existing `HumanDecisionType.designApproval` /
`designRejection` and `WorkItemState.waitingForHumanDecision` — no new waiting
mechanism (same principle as checkpoint 002 §12.4).

### 9.5 Thresholds are NOT finalized

> **The exact thresholds in §9.2–§9.4 are NOT finalized and MUST NOT be treated as
> settled without evidence.**

The criteria above are a *starting hypothesis*. What separates MEDIUM from HIGH in
practice, and whether MEDIUM should default to gated or ungated, are empirical
questions that require observing real classifications and real review outcomes. A
threshold asserted with confidence before evidence exists is a guess wearing a
policy's clothing.

Concretely unsettled: whether "moderate visual/product impact" is decidable enough to
classify reliably; whether MEDIUM defaults gated or ungated; whether the tier is
classified by the platform, proposed by the reviewer, or declared in the brief; and
whether an `approved_with_minor_findings` verdict should itself raise the tier.
Resolution requires evidence (§17, DI-4).

### 9.6 Risk policy MUST be DATA, not hard-coded control flow

> **Risk policy is configuration. It MUST NOT be `if`/`switch` statements embedded in
> the workflow engine or scheduler.**

Required shape:

```
DesignRiskPolicy (versioned, durable, inspectable)
  ├── rules: List<DesignRiskRule>
  │     └── { criterion, tier, requiresHumanApproval }
  ├── mediumTierRequiresHumanApproval: bool
  └── policyVersion: String
```

| Requirement | Reason |
|-------------|--------|
| Versioned | A revision records which policy version classified it. Otherwise "why was this not gated?" is unanswerable after a policy change |
| Durable + inspectable | The policy is part of the governance record, not runtime trivia |
| Changeable without code change | §9.5 guarantees this policy WILL change as evidence arrives; a policy that requires a deploy to adjust will instead be worked around |
| Evaluated, not branched | The engine evaluates rules against revision attributes; it does not know the tiers by name |

The revision records `riskTier` **and** the `policyVersion` that produced it.

---

## 10. JOB MODEL

Both design jobs are ordinary durable `Job`s in the existing `scheduler` — same
queue, same dedupe, same claim-CAS, same lease reconciliation. No parallel
scheduling mechanism is introduced.

### 10.1 JobType additions

`JobType` today has exactly one value. Proposed additions (snake_case wire values,
matching `implement_feature`):

```dart
enum JobType {
  implementFeature('implement_feature'),   // existing
  designRevision('design_revision'),       // NEW
  designReview('design_review');           // NEW

  const JobType(this.wire);
  final String wire;
}
```

Note: `job_type.dart`'s doc comment currently states there are "no automatic
reviewer/design/QA/deploy chains (those arrive in later slices with their own gate
policies)." This checkpoint is that later slice for design, and it arrives **with**
its gate policy (§9). The doc comment must be updated when the values are added.

### 10.2 DesignJob — JobDefinition

Consistent with `scheduler/lib/src/policy/runnable_work.dart`:

```dart
const designJobDefinition = JobDefinition(
  jobType: JobType.designRevision,
  requiredRole: AgentRole.designAgent,          // EXISTING role — reused
  requiredCapabilities: {
    WorkerCapability.visualDesign,              // proposed §7.6
    WorkerCapability.penpotWrite,               // proposed §7.6
    WorkerCapability.penpotRead,                // proposed §7.6
  },
  entryStates: {
    WorkItemState.designRequired,               // EXISTING state
    WorkItemState.designRejected,               // EXISTING state — correction loop
  },
  priority: JobPriority.normal,
  maxAttempts: 2,
);
```

**Payload:** work item id, design brief, `designSystemRevision`,
`parentRevisionId` (correction only), scope surfaces (correction only), carried-forward
surfaces (correction only).

**Output:** one `DesignRevision` row, status `draft`, `designerExecutionId` stamped
by `execution_coordinator`.

### 10.3 DesignReviewJob — JobDefinition

```dart
const designReviewJobDefinition = JobDefinition(
  jobType: JobType.designReview,
  requiredRole: AgentRole.designReviewer,       // EXISTING role — reused
  requiredCapabilities: {
    WorkerCapability.visualDesignReview,        // proposed §7.6
    WorkerCapability.penpotRead,                // proposed §7.6
    // penpotWrite deliberately ABSENT — §7.6 hard rule
  },
  entryStates: {
    WorkItemState.designInReview,               // EXISTING state
  },
  priority: JobPriority.normal,
  maxAttempts: 2,
);
```

**Payload:** `designRevisionId`, design brief, `designSystemRevision`, review scope
(`full` or `targeted` + surfaces), parent review result (for carried-forward
inheritance), and the **excluded execution id** (the designer's) for independence
enforcement at selection time.

**Output:** one `DesignReviewResult` + zero or more `DesignFinding` rows.

### 10.4 Scheduling notes

| Concern | Handling |
|---------|----------|
| Entry states | Reuse the existing design states (§11). `RunnableWorkEvaluator` already treats `waitingForHumanDecision` as `blocked` with zero capacity — the HIGH-tier human gate inherits that for free |
| Independence at dispatch | Worker/session selection for `designReview` excludes the designer execution's worker and session |
| Dedupe | Keyed on `(workItemId, designRevisionId, jobType)` so a retry cannot produce two reviews of one revision |
| `maxAttempts` exhaustion | Routes to a human decision, never an unbounded agent re-run — consistent with the existing "`agentFailed` is not auto-enqueued" stance |
| Blocked-on-human-approval | `humanApprovalRequired` consumes **zero** worker capacity, zero agent sessions, zero polling |

---

## 11. WORKFLOW STATE RECONCILIATION

### 11.1 Finding — the required states already exist

`WorkItemState` (verified in `workflow_state.dart`, 25 values, snake_case wire)
already contains the entire design lifecycle:

| Existing state | Wire | Role in this lifecycle |
|----------------|------|------------------------|
| `designRequired` | `design_required` | Design determination said design is needed. **DesignJob entry state** |
| `designNotRequired` | `design_not_required` | Bypass — straight to implementation |
| `designInReview` | `design_in_review` | A `DesignReviewJob` is active. **DesignReviewJob entry state** |
| `designApproved` | `design_approved` | An implementation-authoritative revision exists |
| `designRejected` | `design_rejected` | Review or human rejected. **Correction-loop entry state** |
| `waitingForHumanDecision` | `waiting_for_human_decision` | The risk-gated human approval (§9.4) |

### 11.2 Mapping

| Lifecycle stage | `WorkItemState` | `DesignRevisionStatus` |
|-----------------|-----------------|------------------------|
| Design determination → required | `designRequired` | — |
| Design agent executing | `agentExecuting` | — |
| Revision produced | `designRequired` → `designInReview` | `draft` |
| Independent review running | `designInReview` | `inReview` |
| Review: changes required | `designInReview` → `designRejected` | `changesRequired` |
| Review passed, LOW risk | `designInReview` → `designApproved` | `reviewPassed` → `approved` |
| Review passed, gate required | `designInReview` → `waitingForHumanDecision` | `humanApprovalRequired` |
| Human approves | `waitingForHumanDecision` → `designApproved` | `approved` |
| Human rejects | `waitingForHumanDecision` → `designRejected` | `changesRequired` |
| Targeted correction | `designRejected` → `designInReview` | new revision `draft` |
| Superseded by correction | (unchanged) | prior revision → `superseded` |
| Implementation | `designApproved` → `agentExecuting` | `approved` (immutable) |

### 11.3 Is any new WorkItemState genuinely required?

**No. No new `WorkItemState` value is required. Prefer reuse.**

Three candidates were considered and rejected:

| Candidate | Rejected because |
|-----------|------------------|
| `designInCorrection` | `designRejected` + a new `draft` revision with `parentRevisionId` already expresses this. The correction is a property of the *revision*, not of the work item |
| `designAwaitingHumanApproval` | `waitingForHumanDecision` + `HumanDecisionType.designApproval` already expresses it, and `RunnableWorkEvaluator` already treats it as `blocked` with zero capacity. A parallel state would need that behaviour re-derived |
| `designAutomatedQaFailed` | Automated Design QA failure is a revision-level outcome (`changesRequired`), not a work-item lifecycle state |

**The governing principle:** revision-level detail belongs on `DesignRevision`, not
on `WorkItemState`. Adding states would duplicate information in two places that can
then disagree — and disagreement between the work item and the revision is precisely
the ambiguity this feature exists to remove.

**One transition-graph change may be required (not a new state):** the correction
loop needs `designRejected → designInReview`. If the existing graph in
`workflow_engine` does not permit it, that is a transition rule addition, not a new
state. This must be verified against `packages/workflow_engine/lib/src/transitions/`
at implementation time.

---

## 12. DESIGN DEFECT ROUTING

### 12.1 Connection to HUMAN_BUG_REPORTING_001

Checkpoint 002 (`docs/checkpoints/002-human-bug-reporting-ai-defect-triage-planning.md`)
§13.5 and §14.5 route `DefectClassification.designDefect` remediation to *this*
lifecycle and record the dependency as **blocking**: "`designDefect` remediation
cannot be scheduled until the design governance lifecycle exists to receive it."

This checkpoint is the receiving authority.

### 12.2 Route

```
Defect (DEF-000123, classification: designDefect)
   │
   ▼
Design remediation WorkItem
   │  category: feature (design revision) — per checkpoint 002 §14.3
   │  featureRef: DEF-000123
   │  state: designRequired
   ▼
DesignJob (JobType.designRevision, AgentRole.designAgent)
   │  brief includes: defect evidence, triage result, the design flaw as stated
   ▼
DesignRevision (DES-R<N>, parentRevisionId = currently approved revision)
   │
   ▼
Independent DesignReviewJob (AgentRole.designReviewer,
                             reviewerExecutionId ≠ designerExecutionId)
   │  must assert the reported defect is actually addressed
   ▼
Risk classification (§9)
   │
   ├── LOW ────────────────────────► approved
   └── MEDIUM(policy) / HIGH ──► HUMAN_DESIGN_APPROVAL_REQUIRED ──► approved
   │
   ▼
IMPLEMENTATION_AUTHORITATIVE DesignRevision
   │
   ▼
Implementation (implements the approved revision — and only that)
   │
   ▼
QA (qa_orchestration)
   │
   ▼
Human defect verification (checkpoint 002 §16)
   │  fixed → resolved → closed
   │  stillBroken → SAME defect reopens
```

### 12.3 HARD RULE — the coding agent must not diverge from approved design

> **A coding agent MUST NOT modify design to "fix" a design defect.**

Restating checkpoint 002 §13.5/§14.5 with this checkpoint's mechanism:

| Forbidden | Required |
|-----------|----------|
| Coding agent adjusts layout/spacing/flow to address a `designDefect` | A new `DesignRevision` goes through independent review and (risk-gated) human approval |
| Implementation "improves" the approved design | Implementation reproduces the approved revision |
| Implementation partially applies the approved design | Full fidelity to the approved revision |
| Implementation substitutes its own judgement where the design is unclear | Unclear design is a **finding** against the revision, routed back to design authority |

**Divergence from approved design is itself a defect**, not an acceptable outcome. It
is reported through `HUMAN_BUG_REPORTING_001` and triaged like any other defect.

**Why the coding agent is structurally the wrong authority:** a design defect means
the *approved design* is wrong. A coding agent that "fixes" it produces code that no
longer matches any approved revision — the approval record now describes something
that does not exist, and the next implementation against that revision will
regenerate the defect. The correction must occur at the level where the authority
lives.

**Enforcement:** the workflow engine must not route a `designDefect` remediation
WorkItem to a `JobType.implementFeature` job until an `approved` `DesignRevision`
exists for it. Implementation entry requires `WorkItemState.designApproved`.

---

## 13. API REQUIREMENTS

Endpoints needed in a **later** slice. Nothing here is implemented in this run. All
follow the existing read-only-observation boundary for endpoints (AGENTS.md: an
endpoint must **never** set `WorkItem.state`).

### 13.1 DesignRevisionEndpoints

| Method | Signature | Description |
|--------|-----------|-------------|
| `list` | `Future<Map> list(Session, {String? workItemId, String? status, int? limit})` | List revisions, filterable |
| `inspect` | `Future<Map> inspect(Session, {required String designRevisionId})` | Full revision + reviews + findings + lineage |
| `lineage` | `Future<Map> lineage(Session, {required String designRevisionId})` | Parent/child chain, supersession markers |
| `authoritative` | `Future<Map> authoritative(Session, {required String workItemId})` | The single currently-approved revision, if any |
| `events` | `Future<Map> events(Session, {required String designRevisionId})` | Append-only `design_revision_event` history |

### 13.2 DesignReviewEndpoints

| Method | Signature | Description |
|--------|-----------|-------------|
| `list` | `Future<Map> list(Session, {String? designRevisionId, String? verdict, int? limit})` | List review results |
| `inspect` | `Future<Map> inspect(Session, {required String designReviewId})` | Full result: eight dimensions, findings, scope |
| `findings` | `Future<Map> findings(Session, {String? designRevisionId, String? severity, bool? unresolvedOnly})` | Findings, filterable |

### 13.3 Command surface (ControlPlaneService, not endpoints)

State-changing operations live in `ControlPlaneService`, invoked by the scheduler /
execution coordinator / human-decision path — never set directly from an endpoint:

- `createDesignRevision(...)` — assign `DES-R<N>`, persist, append event
- `recordDesignReview(...)` — persist result + findings; **enforces §7 independence guard**
- `classifyDesignRisk(...)` — evaluate `DesignRiskPolicy` (data), stamp `riskTier` + `policyVersion`
- `openDesignApprovalGate(...)` — create blocking `HumanDecision` (`designApproval`)
- `approveDesignRevision(...)` — CAS to `approved`, set `approvedAt`, enforce the one-approved-per-work-item constraint
- `supersedeDesignRevision(...)` — set `superseded` + `supersededByRevisionId`
- `enqueueDesignJob(...)` / `enqueueDesignReviewJob(...)` — scheduler dispatch with dedupe

### 13.4 Existing endpoint changes

**HomeEndpoints** — `overview()` gains `designsAwaitingReview` and
`designsAwaitingHumanApproval` counts, mirroring checkpoint 002 §17.2.

---

## 14. ACCEPTANCE CRITERIA

| AC | Criterion |
|----|-----------|
| `DGA-AC-1` | A `DesignRevision` persists across process restarts with a stable `DES-R<N>` identifier, and all fields in §5.3 survive a restart intact. |
| `DGA-AC-2` | A revision with `status == approved` cannot have its content mutated. An attempted content UPDATE is **rejected** at both the domain store and the database, not warned about. |
| `DGA-AC-3` | A material modification to an approved revision creates a NEW revision with `parentRevisionId` set to the modified revision; the prior revision transitions to `superseded` with `supersededByRevisionId` set. |
| `DGA-AC-4` | At most one revision per `workItemId` has `status == approved` at any time; a second concurrent approval attempt loses cleanly (CAS), it does not produce two authorities. |
| `DGA-AC-5` | A `DesignReviewResult` whose `reviewerExecutionId == designerExecutionId` is **REJECTED**. The write fails, the job fails, and the violation is recorded as a `design_revision_event`. |
| `DGA-AC-6` | A worker holding `penpot_write` cannot be selected for a `JobType.designReview` job; the reviewer capability set excludes `penpot_write` and includes `penpot_read`. |
| `DGA-AC-7` | The designer execution cannot set its own revision to `approved`. Only the platform sets `approved`, and only after a qualifying independent review (plus human gate where required). |
| `DGA-AC-8` | A targeted correction regenerates ONLY the surfaces named in the recorded scope. Unaffected approved surfaces are carried forward by reference and their `designerExecutionId` provenance points at the parent revision's producer, not the correction execution. |
| `DGA-AC-9` | A scoped re-review assesses only in-scope dimensions; out-of-scope dimensions are recorded as `assessed=false` with an explicit carry-forward reference. A scoped review is never recorded as if it were full. |
| `DGA-AC-10` | A surface that did NOT pass review in the parent revision cannot be carried forward. The attempt is rejected. |
| `DGA-AC-11` | A change to `designSystemRevision` invalidates carry-forward and forces a full review. |
| `DGA-AC-12` | Every review produces a structured, persisted `DesignReviewResult` with all eight dimensions represented, a verdict, and zero or more findings. Unstructured agent output fails validation and the job fails. |
| `DGA-AC-13` | A verdict of `approved` or `approved_with_minor_findings` containing a `blocker` or `major` finding is rejected as internally contradictory. |
| `DGA-AC-14` | A `DesignFinding` without an `affectedSurface` is rejected — it cannot drive a targeted correction. |
| `DGA-AC-15` | Risk tier drives the human gate: a HIGH-tier revision cannot reach `approved` without a resolved `HumanDecision`; a LOW-tier revision reaches `approved` without one. |
| `DGA-AC-16` | Risk policy is data: changing the MEDIUM-tier gate requirement changes gate behaviour **without a code change**, and each revision records the `policyVersion` that classified it. |
| `DGA-AC-17` | A revision in `humanApprovalRequired` consumes zero worker capacity, zero agent sessions, and zero polling processes. |
| `DGA-AC-18` | A `designDefect` from `HUMAN_BUG_REPORTING_001` routes to a `JobType.designRevision` job under `AgentRole.designAgent` — **never** directly to `JobType.implementFeature`. |
| `DGA-AC-19` | A design remediation WorkItem cannot enter implementation until an `approved` `DesignRevision` exists for it (`WorkItemState.designApproved` is required for implementation entry). |
| `DGA-AC-20` | No model or provider name (Claude, GPT, Gemini, OpenCode) appears anywhere in `workflow_engine`, `scheduler`, `JobType`, `AgentRole`, or risk policy data. |
| `DGA-AC-21` | The existing `AgentRole.designAgent` / `AgentRole.designReviewer` values are reused; no duplicate design role is introduced. |
| `DGA-AC-22` | The existing `designRequired` / `designInReview` / `designApproved` / `designRejected` states are reused; no new `WorkItemState` value is added. |
| `DGA-AC-23` | Full revision + review + finding history remains inspectable after any number of correction cycles. |
| `DGA-AC-24` | Root gate passes: format + analyze + test. No regressions in existing packages. |

---

## 15. QA CONTRACT

### 15.1 Unit Tests

| Area | What to test |
|------|-------------|
| Revision lifecycle | Every legal `DesignRevisionStatus` transition; illegal transitions rejected |
| Revision identity | `DES-R<N>` monotonic per work item, stable, unique |
| **Immutability guard** | Content mutation of an `approved` revision rejected; supersession markers and `reviewExecutionIds` append still permitted |
| Supersession | Material modification creates a child with `parentRevisionId`; parent → `superseded` with `supersededByRevisionId` |
| **Independence guard** | `reviewerExecutionId == designerExecutionId` rejected; distinct ids accepted; violation event recorded |
| Capability separation | Reviewer capability set excludes `penpot_write`, includes `penpot_read`; designer set includes both |
| Risk classification | Each §9.2–§9.4 criterion maps to the expected tier; HIGH always gates; MEDIUM follows policy data |
| Risk policy as data | Changing policy data changes gate outcome with no code change; `policyVersion` stamped on the revision |
| Finding model | Missing `affectedSurface` rejected; severity/category in enum; `requiredCorrection` non-empty |
| Verdict consistency | `approved` + `blocker` rejected; `approved_with_minor_findings` + `major` rejected |
| Review scope | Scoped review records scope; out-of-scope dimensions marked `assessed=false` with carry-forward reference |
| Carry-forward rules | Unreviewed/failed surface cannot be carried forward; design-system change invalidates carry-forward |
| Wire serialization | All new enums round-trip snake_case wire values; unknown wire value throws `FormatException` (matching existing `fromWire` behaviour) |

### 15.2 Database Tests

| Area | What to test |
|------|-------------|
| Revision persistence | CRUD with CAS `version`; survives restart |
| Parent lineage | Multi-generation chain (`DES-R7 → R8 → R9`) traversable in both directions |
| Supersession integrity | Exactly one `approved` per `workItemId` (partial unique index enforced under concurrency) |
| Immutability at DB level | Trigger/rule rejects content UPDATE where `status = 'approved'` — proven at the database, not only in Dart |
| Independence at DB level | Trigger rejects a `design_review_result` insert whose `reviewerExecutionId` equals the revision's `designerExecutionId` |
| CAS | Stale-version update loses; no lost update |
| Concurrency | Concurrent approvals of sibling revisions settle to exactly one winner |
| Event append | `design_revision_event` append-only, monotonic `sequence` per revision |
| Finding linkage | FK integrity to review + revision; `resolvedByRevisionId` set correctly by the correction loop |
| Idempotency | Replayed revision/review writes do not duplicate rows |

### 15.3 Scheduler Tests

| Area | What to test |
|------|-------------|
| Design job lifecycle | enqueue → claim → run → complete; entry states `designRequired` / `designRejected` honoured |
| Review job lifecycle | enqueue → claim → run → complete; entry state `designInReview` honoured |
| Capability matching | A worker lacking `visual_design` cannot claim a design job; a worker holding `penpot_write` cannot claim a review job |
| Independence at dispatch | The designer execution's worker/session is excluded from review-job selection |
| **Blocked on human approval** | `waitingForHumanDecision` → `RunnableWorkStatus.blocked`; zero capacity, zero sessions, zero polling |
| Gate resolution resumes | Human approval resumes the same work item; no duplicate revision created |
| Dedupe | `(workItemId, designRevisionId, jobType)` dedupe prevents two reviews of one revision |
| `maxAttempts` exhaustion | Correction loop terminates into a human decision, not an unbounded re-run |
| Lease reconciliation | An orphaned design/review job is reclaimed without producing a duplicate revision |

### 15.4 Agent Tests

| Area | What to test |
|------|-------------|
| Review output structure | All eight dimensions present; verdict present; findings well-formed |
| Review output validation | Verdict/severity consistency (§6.3); enum membership; non-empty `evidence` and `requiredCorrection` |
| Scope honoured | A targeted review does not claim assessments outside its recorded scope |
| Role stamping | Designer execution stamped `DESIGN_AGENT`; reviewer stamped `DESIGN_REVIEWER`; the agent never declares its own role |
| Unstructured output | Prose-only review output fails validation and fails the job |
| Materiality declaration | The design agent's material/non-material declaration is recorded and verifiable by the reviewer |

### 15.5 E2E Tests

| Scenario | What to prove |
|----------|--------------|
| Full lifecycle | Requirement → determination → brief → DesignJob → revision → automated QA → DesignReviewJob → review → risk classification → approval → implementation, against real PostgreSQL |
| **Independence violation rejected** | An attempt to review with the designer execution is rejected end-to-end; no approval is produced; the violation is durably recorded |
| **Targeted correction** | The §8.2 `DES-R7 → DES-R8` scenario exactly: one surface corrected, three carried forward and NOT regenerated, scoped re-review recorded as scoped, lineage intact |
| HIGH-tier human gate | A HIGH-tier revision blocks on `HUMAN_DESIGN_APPROVAL_REQUIRED`, consumes zero capacity while blocked, and resumes to `approved` on human approval |
| LOW-tier no gate | A LOW-tier revision reaches `approved` with no `HumanDecision` |
| Approved-revision immutability | Post-approval content mutation attempt fails; the modification instead produces a child revision and supersedes the parent |
| **Design-defect routing** | A `designDefect` from checkpoint 002 routes to `JobType.designRevision`, NOT `JobType.implementFeature`; implementation is blocked until an approved revision exists; the defect returns for human verification |
| Restart durability | Kill mid-review; state resumes from durable records; no duplicate revision or review |

---

## 16. SCOPE BOUNDARIES

**NOT building:**

| Not building | Why |
|--------------|-----|
| **A design tool** | ShipIt governs design; it does not draw it. No canvas, no editor, no design surface in the control plane |
| **A Penpot replacement** | Penpot remains the design system of record. `DesignRevision` references it; it does not reimplement it. `designProviderType` exists so the contract stays provider-neutral, not so ShipIt can become a provider |
| **Automated aesthetic judgement** | The platform does not decide whether a design is beautiful. Review assesses *checkable* dimensions — requirement coverage, system compliance, interaction completeness, responsive coverage, accessibility, feasibility. Taste is a human-authority matter and stays behind the human gate |
| **Model-selection policy** | Which model performs which role is `agent_runtime`'s concern. Workflow policy encodes roles + capabilities + independence, never model identity (§7.4) |
| **A general-purpose review framework** | This is design review with eight named dimensions. It is not a pluggable review engine for arbitrary domains. Code review already exists separately and should stay separate |

**Also not in scope:** design version control beyond parent lineage; visual diffing
between revisions; design token management; automated design generation from
requirements without a brief; multi-tenant design governance; design analytics.

---

## 17. DEFERRED ITEMS

| ID | Item | Reason | Future Slice |
|----|------|--------|-------------|
| DI-1 | Whether the correction loop should use existing `AgentRole.correctionImplementer` / `focusedReviewer` instead of scoped `designAgent` / `designReviewer` | Both are defensible; choosing without evidence risks a duplicate role or a wrong reuse (§7.5) | Slice 2 |
| DI-2 | `AgentRole` wire-value convention (`SCREAMING_SNAKE_CASE`) vs the repository-dominant snake_case | Breaking schema change; requires its own ADR (§7.5) | ADR + dedicated slice |
| DI-3 | Provider-neutral capability naming (`design_tool_read`/`design_tool_write`) vs `penpot_read`/`penpot_write` | Tension between §7.4 and existing precedent (`xcode`); recorded rather than silently decided (§7.6) | Slice 2 |
| DI-4 | Final risk-tier thresholds and the MEDIUM default (gated vs ungated) | Requires observed classification + review-outcome evidence (§9.5) | Post-evidence |
| DI-5 | Who assigns `riskTier` — platform policy, reviewer proposal, or brief declaration | Coupled to DI-4 | Post-evidence |
| DI-6 | Automated Design QA check catalogue (exact mechanical checks) | Needs a real design system revision to check against | Slice 2 |
| DI-7 | Visual diffing between revisions | Valuable for review scoping; not required for correctness | Slice 3+ |
| DI-8 | Design system revision management (how `designSystemRevision` is minted/versioned) | Depends on DCR-001 visual-direction outcome | Post-DCR-001 |
| DI-9 | Control-plane UI for design revisions/reviews/findings | UI work is blocked by DCR-001, same as checkpoint 002 §26 | Post-DCR-001 |
| DI-10 | Second design provider adapter | `designProviderType` keeps the door open; no second provider is needed now | Deferred |
| DI-11 | Human-authored (non-agent) design revisions entering the same lifecycle | The contract already supports it; the intake path is unspecified | Slice 2+ |
| DI-12 | Confidence/uncertainty reporting on review dimensions | Structure first; calibration later | Slice 3+ |
| DI-13 | Whether worker registration should expose a `modelFamily` attribute so the scheduler can *prefer* diversity (§7.2) and `ReviewerModelDiversity` can resolve to something other than `not_available`/`unknown` | No such attribute exists in `packages/` today, so §7.2.1 can only ever record `not_available` until a second provider exists (DI-10). Must stay a recorded attribute, never a gate — and must not name models in policy (§7.4) | Follows DI-10 |

---

## 18. STATUS

**Status: READY_FOR_PLANNING_REVIEW**

**Nothing was implemented in this run.** No Dart source file was written, no enum
value added, no migration created, no test written, no package modified. This
document is a planning/specification artifact only. Every code block in it is a
*proposal* for a later slice.

**Explicit forward-dependency statement:** this specification is a **forward
dependency of checkpoint 002's design-defect routing**. Checkpoint 002 §13.5 records
that dependency as blocking — "`designDefect` remediation cannot be scheduled until
the design governance lifecycle exists to receive it." This checkpoint specifies that
lifecycle; it does not yet build it. Until `DESIGN_GOVERNANCE_AUTOMATION_001` is
implemented, `HUMAN_BUG_REPORTING_001`'s `designDefect` route still has no
implemented destination.

**What review must settle before implementation:**

1. The §5.5 immutability rule and its enforcement layers.
2. The §7.1 hard independence rule and §7.6 reviewer capability separation.
3. DI-1 — correction-loop role reuse.
4. DI-3 — capability naming (provider-neutral vs `penpot_*`).
5. DI-4 / DI-5 — risk thresholds and who classifies (explicitly **not** settled here).
6. Whether `designRejected → designInReview` already exists in the
   `workflow_engine` transition graph (§11.3).

**What is NOT blocked by DCR-001:** the domain model, lifecycle, contracts, job
model, independence rule, correction loop, risk model shape, and QA contract are all
non-UI and remain authoritative regardless of visual-direction selection. Only DI-9
(control-plane UI for design governance) inherits checkpoint 002's DCR-001 park.

---

## 19. SESSION HANDOFF

### What was done
- Planning checkpoint produced for `DESIGN_GOVERNANCE_AUTOMATION_001`
- Baseline verified against real source — `agent_role.dart`, `workflow_state.dart`, `worker_capability.dart`, `job_type.dart`, `runnable_work.dart`, `design_contract.dart`, `human_decision.dart`
- Full design lifecycle specified (14 stages, actor/input/output/durable record per stage)
- `DesignRevision` contract designed with an explicit immutability rule and PostgreSQL sketch
- `DesignReviewResult` / `DesignFinding` contracts designed with eight assessed dimensions
- Independence rule specified as a hard, platform-enforced, defence-in-depth property
- AgentRole reconciliation performed — **`designAgent` and `designReviewer` already exist and are reused**
- WorkerCapability gap identified — four new values proposed, reviewer read-only separation specified
- Targeted correction loop specified with a worked `DES-R7 → DES-R8` example
- Risk model specified as three tiers, with thresholds explicitly NOT finalized and policy required to be data
- Job model specified reusing the existing scheduler `JobDefinition` shape
- WorkflowState reconciliation performed — **no new `WorkItemState` required**
- Design-defect routing connected to `HUMAN_BUG_REPORTING_001`
- 24 acceptance criteria (`DGA-AC-1`..`DGA-AC-24`) defined
- QA contract across unit / database / scheduler / agent / E2E defined
- 12 deferred items recorded with reasons

### What needs to happen next
1. Planning review of this document
2. Resolve DI-1, DI-3 (role reuse, capability naming)
3. Verify the `designRejected → designInReview` transition in `workflow_engine`
4. ADR for the design governance lifecycle
5. Contract slice — `DesignRevision`, `DesignReviewResult`, `DesignFinding`, enums, schemas
6. Persistence slice — tables, triggers, CAS, store contract tests
7. Scheduler slice — `designRevision` / `designReview` job types + independence at dispatch
8. THEN: agent adapter + E2E

### Files referenced
- `packages/platform_contracts/lib/src/enums/agent_role.dart`
- `packages/platform_contracts/lib/src/enums/workflow_state.dart`
- `packages/platform_contracts/lib/src/enums/worker_capability.dart`
- `packages/platform_contracts/lib/src/enums/job_type.dart`
- `packages/platform_contracts/lib/src/enums/human_decision.dart`
- `packages/platform_contracts/lib/src/types/design_contract.dart`
- `packages/scheduler/lib/src/policy/runnable_work.dart`
- `docs/checkpoints/002-human-bug-reporting-ai-defect-triage-planning.md`
- `AGENTS.md` — §8 forbidden patterns, §13 Penpot/tooling credentials

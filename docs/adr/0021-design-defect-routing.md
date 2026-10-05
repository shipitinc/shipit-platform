# ADR 0021: Design Defect Routing

**Status:** ACCEPTED
**Date:** 2026-09-25
**Author:** S-2 Orchestration

## Context

Checkpoint 002 (§13.5, §14.5) establishes that `DefectClassification.designDefect` remediation MUST route through the Design Governance lifecycle (checkpoint 003, `DESIGN_GOVERNANCE_AUTOMATION_001`), not through the generic bugfix implementation path. Checkpoint 003 defines the design governance lifecycle with independent review, risk-tiered human approval, and revision candidate workflow. This ADR defines the integration boundary between the defect domain and design governance.

## Decision

### 1. Routing Flow

```
Human reports defect
       │
       ▼
Durable Defect created (status: reported)
       │
       ▼
AI Triage (JobType.triageDefect)
       │
       ├── classification ≠ designDefect → normal remediation path
       │
       └── classification == designDefect
                │
                ▼
         TriageResult includes:
         - recommendedClassification: designDefect
         - recommendedWorkItemCategory: feature (design revision)
         - clarificationRequired: possibly empty
                │
                ▼
         Defect.status → remediationPlanned (NOT confirmed)
         Defect.classification → designDefect (authoritative)
                │
                ▼
         ControlPlaneService.createDesignRemediationWorkItem(defectId)
                │
                ▼
         WorkItem created with:
         - category: feature
         - featureRef: defectId
         - title: "Design remediation: <defect title>"
         - description: includes defect evidence, triage result, the design flaw as stated
         - state: designRequired (WorkItemState)
                │
                ▼
         Scheduler enqueues JobType.designRevision (AgentRole.designAgent)
                │
                ▼
         Design agent produces DesignRevision (status: draft)
                │
                ▼
         Independent DesignReviewJob (AgentRole.designReviewer, reviewer ≠ designer)
                │
                ▼
         DesignReviewResult + DesignFinding(s)
                │
                ▼
         Risk classification (LOW / MEDIUM / HIGH per checkpoint 003 §9)
                │
                ├── LOW → DesignRevision.status → approved
                ├── MEDIUM (policy) / HIGH → HumanDecision (designApproval) → approved
                │
                ▼
         IMPLEMENTATION_AUTHORITATIVE DesignRevision exists
                │
                ▼
         Implementation agent consumes approved revision (JobType.implementFeature)
                │
                ▼
         QA Orchestration validates implementation against approved revision
                │
                ▼
         Human defect verification (checkpoint 002 §16)
                │   fixed → resolved → closed
                │   stillBroken → SAME defect reopens (reported)
                ▼
```

### 2. Hard Rules

| Forbidden | Required |
|-----------|----------|
| Coding agent adjusts layout/spacing/flow to "fix" a `designDefect` | A new `DesignRevision` goes through independent review and (risk-gated) human approval |
| Implementation "improves" the approved design | Implementation reproduces the approved revision with full fidelity |
| Implementation partially applies the approved design | Full fidelity to the approved revision |
| Implementation substitutes its own judgement where design is unclear | Unclear design is a **finding** against the revision, routed back to design authority |
| AI triage directly mutates canonical Penpot artifacts | Design revision produced by design agent, reviewed independently, human-approved where required |

**Divergence from approved design is itself a defect**, not an acceptable outcome.

### 3. Integration Boundary

The defect domain produces a **typed design-governance request** when triage yields `designDefect`:

```dart
class DesignRemediationRequest {
  final String defectId;
  final String defectTitle;
  final String triageSummary;
  final List<String> evidenceRefs;
  final String designFlawDescription;  // from triage.suspectedCategory/Components
  final DefectClassification classification; // == designDefect
}
```

This request is consumed by `ControlPlaneService.createDesignRemediationWorkItem()`, which creates the WorkItem in `designRequired` state. The scheduler then dispatches `JobType.designRevision`.

**If `DESIGN_GOVERNANCE_AUTOMATION_001` is not yet implemented in shipit-platform**, the boundary stops at WorkItem creation. The defect remains in `remediationPlanned` with a linked WorkItem that cannot progress until the design governance runtime exists. This is reported as `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`.

### 4. Authority Separation

| Layer | Authority |
|-------|-----------|
| Defect domain | Human intake, evidence, triage advisory, clarification, verification |
| Triage | Advisory classification + rationale ONLY; never mutates defect truth |
| Design Governance | DesignRevision production, independent review, risk classification, human approval gate |
| Implementation | Consumes APPROVED DesignRevision only; fidelity enforcement via QA |
| Human Verification | Final authority on whether the fix addresses the original defect |

### 5. Human Gates Preserved

- `HUMAN_DESIGN_APPROVAL_REQUIRED` for HIGH-tier and policy-gated MEDIUM-tier revisions (checkpoint 003 §9)
- `HUMAN_DESIGN_APPROVAL_REQUIRED` is a `HumanDecision` with `decisionType: designApproval` — reuses existing machinery
- Defect verification gate (`defectFixVerification`) is separate from design approval gate

### 6. Data Contracts (from platform_contracts)

Reuses existing types:
- `Defect.classification == DefectClassification.designDefect`
- `WorkItem.category == WorkItemCategory.feature` (for design remediation)
- `WorkItem.featureRef == defectId`
- `DesignRevision.workItemId` links to remediation WorkItem
- `DesignRevision.parentRevisionId` = currently approved revision (correction loop)
- `DesignReviewResult.verdict` + `DesignFinding` drive corrections
- `DesignRiskTier` + `DesignRiskPolicy` (data, not code) drive human gate

### 7. No New Scheduler/Workflow

Uses existing:
- `JobType.designRevision` and `JobType.designReview` (checkpoint 003 §10)
- `WorkItemState.designRequired` / `designInReview` / `designApproved` / `designRejected` (checkpoint 003 §11)
- `AgentRole.designAgent` / `AgentRole.designReviewer` (checkpoint 003 §7)
- `WorkerCapability.visualDesign` / `penpotWrite` / `penpotRead` / `visualDesignReview` (checkpoint 003 §7.6)

### 8. Durability

All steps produce durable records:
- `Defect` + `DefectEvent` (audit trail)
- `WorkItem` + `WorkItemTransition` (remediation lifecycle)
- `DesignRevision` + `DesignRevisionEvent` (design lineage)
- `DesignReviewResult` + `DesignFinding` (review evidence)
- `HumanDecision` (design approval + fix verification)

Process restarts resume from durable state at any point.

## Consequences

- `designDefect` classification creates a hard dependency on Design Governance runtime
- If Design Governance is not implemented, defect stays in `remediationPlanned` with blocked WorkItem
- Coding agents never receive design defects directly — implementation only starts after approved revision
- Independent review enforcement (reviewer ≠ designer) is platform-enforced at dispatch time
- Risk policy is data (DesignRiskPolicy), not hard-coded — changes without deploy

## Alternatives Considered

- **Route design defects to implementation agent with "design review" step:** Rejected — coding agent is structurally wrong authority for design defects (checkpoint 003 §12.3)
- **Separate defect lifecycle for design defects:** Rejected — single defect lifecycle (§6) with classification-based routing is simpler and auditable
- **AI triage directly creates DesignRevision:** Rejected — triage is advisory; design production requires design agent + independent review

## References

- Checkpoint 002: `docs/checkpoints/002-human-bug-reporting-ai-defect-triage-planning.md` (§13.5, §14.5, §12)
- Checkpoint 003: `docs/checkpoints/003-design-governance-automation-planning.md` (full design governance lifecycle)
- ADR 0020: Defect Domain Model + Triage Lifecycle (this ADR's prerequisite)
- Platform contracts: `DesignRevision`, `DesignReviewResult`, `DesignFinding`, `DesignRiskTier`, `WorkItemCategory`, `AgentRole`
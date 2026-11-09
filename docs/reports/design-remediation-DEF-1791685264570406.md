# Design remediation: DEF-1791685264570406 — run record

- **Work item:** `design-remediation-DEF-1791685264570406`
- **TriageResult:** `tr-jb-hn3kuio6ml-frum89`
- **QA Contract:** `qa-product-design-remediation-DEF-1791685264570406`
- **Outcome:** `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` (ADR 0021)

## What the item asks for

Human-reported defect DEF-1791685264570406 ("Feature Request UX": the Feature
Request view appears lower quality than the Defect tab) was classified by AI
triage as a design flaw. The task was to implement a `DesignRevision` that makes
the Feature Request UI match the Defect Detail layout.

## What was done

None, deliberately. This lane produces design artifacts only through the design
governance runtime, `DESIGN_GOVERNATION_AUTOMATION_001`, which does not exist in
shipit-platform. ADR 0021 records both halves of that boundary:

> **AI triage directly creates DesignRevision:** Rejected — triage is advisory;
> design production requires design agent + independent review.

> **If `DESIGN_GOVERNANCE_AUTOMATION_001` is not yet implemented in
> shipit-platform**, the boundary stops at WorkItem creation. The defect remains
> in `remediationPlanned` with a linked WorkItem that cannot progress until the
> design governance runtime exists. This is reported as
> `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`.

The durable behaviour for a `DESIGN_DEFECT` classification is therefore already
implemented and already covered by
`apps/server/test/integration/triage_execution_test.dart` ("DESIGN_DEFECT stops
at a real, honestly-blocked remediation item"):

- `DesignRemediationWorkItemProvisioner.ensurePersisted`
  (`apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart`) creates
  the item under the product its triage parent resolved to, walks it
  `draft -> planning -> planned` through `DurableWorkflowEngine.transition`, and
  records `designRemediationRequired: true`,
  `designGovernanceRuntime: unavailable`,
  `blockedBy: EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` in its metadata. The human-
  readable description states the same dependency, so the reason is visible
  without reading the source.
- The item never reaches `designRequired` and never carries a fabricated
  `designContractId`; `designNotRequired` would assert the opposite of the truth.
- Every state change goes through the workflow engine, so the transition graph
  remains the only authority (AGENTS.md §1).

No code change was required to satisfy the QA Contract for this defect; the
provisioner is generic over defect id, title, evidence refs and suspected
components, so this instance is covered by the existing behaviour and its
integration test.

## What is still needed (human / out of band)

1. Human clarification of the affected screens, the expected layout, and the
   acceptance criteria — the report carries no element-level detail, no visual
   reference, and reproduction steps too vague to verify.
2. Implementation of `DESIGN_GOVERNATION_AUTOMATION_001`, after which this item
   resumes automatically: the provisioner is idempotent (read-before-create plus
   per-hop idempotency keys) and a tick advances the existing item rather than
   creating a second one.

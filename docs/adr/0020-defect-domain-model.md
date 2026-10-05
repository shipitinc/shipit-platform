# ADR 0020: Defect Domain Model + Triage Lifecycle

**Status:** ACCEPTED
**Date:** 2026-09-25
**Author:** S-2 Orchestration

## Context

S-2 milestone requires durable Human Bug Reporting backend with AI defect triage. Checkpoint 002 (`docs/checkpoints/002-human-bug-reporting-ai-defect-triage-planning.md`) provides the canonical specification. The existing `platform_contracts` package already contains the typed contracts (Defect, DefectEvidence, DefectEvent, DefectClarification, TriageResult, and all related enums). This ADR documents the authoritative domain model and lifecycle, binding the existing contracts to durable persistence and execution semantics.

## Decision

### 1. Core Entities

The defect domain consists of four durable entities:

| Entity | Table | Identity | Purpose |
|--------|-------|----------|---------|
| **Defect** | `defect` | `DEF-<NNNNNN>` | First-class aggregate; human-reported issue |
| **DefectEvidence** | `defect_evidence` | `EVD-<NNNNNN>` | Append-only evidence attached to a defect |
| **DefectEvent** | `defect_event` | `DEV-<NNNNNN>` | Append-only event history (audit trail) |
| **DefectClarification** | `defect_clarification` | `CLF-<NNNNNN>` | Structured Q&A when triage needs more info |

All entities use `bigint` surrogate PK + `text` UNIQUE business ID + `version` for CAS.

### 2. Canonical Classification Taxonomy

Exactly four classifications, no ad-hoc strings:

```dart
enum DefectClassification {
  implementationDefect('implementation_defect'),
  designDefect('design_defect'),
  requirementGap('requirement_gap'),
  environmentDefect('environment_defect');
}
```

**Authority:** AI triage proposes classification; HumanDecision may override. The authoritative classification is the one bound to the defect at any moment.

### 3. Defect Status Lifecycle

```dart
enum DefectStatus {
  reported('reported'),
  triaging('triaging'),
  needsClarification('needs_clarification'),
  confirmed('confirmed'),
  notReproducible('not_reproducible'),
  duplicate('duplicate'),
  remediationPlanned('remediation_planned'),
  fixInProgress('fix_in_progress'),
  fixReadyForVerification('fix_ready_for_verification'),
  resolved('resolved'),
  closed('closed');
}
```

**Terminal states:** `closed`, `duplicate`, `notReproducible`. `notReproducible` is reopenable via new evidence.

**Legal transitions** are enforced by the application layer (ControlPlaneService), not by database constraints. See Checkpoint 002 §7.1 for the full transition table.

### 5. AI Triage as Advisory Execution

Triage runs as a durable `Job` with `JobType.triageDefect`:

| Property | Value |
|----------|-------|
| `requiredRole` | `AgentRole.triageDefect` (exists in platform_contracts) |
| `requiredCapabilities` | `{WorkerCapability.linux, WorkerCapability.git}` — worker needs basic code access |
| `entryStates` | `{DefectStatus.reported, DefectStatus.needsClarification}` |
| `priority` | `JobPriority.high` |
| `maxAttempts` | 2 |

**Triage output** (`TriageResult`) is advisory only:

- `recommendedStatus` / `recommendedClassification` — proposals, not authoritative mutations
- `confidence` — recorded as advisory signal; **no semantic meaning is assigned by the platform**
- `clarificationRequired` — if non-empty, defect transitions to `needsClarification` and a `HumanDecision` (type `defectClarification`) is created
- `possibleDuplicateDefectId` — advisory link; human must confirm
- `recommendedNextAction` / `summary` — human-readable rationale

**Hard rule:** The triage agent NEVER directly mutates `Defect.status` or `Defect.classification`. It produces a `TriageResult`; the platform applies transitions based on that result through the normal service layer.

The triage agent adapter declares `RuntimeCapability.readFiles` and `RuntimeCapability.gitOperations` for code/log access; worker selection uses `WorkerCapability.linux` + `WorkerCapability.git`.

### 6. Clarification Loop

When triage produces `clarificationRequired`:

1. `DefectClarification` rows created (status: `pending`)
2. `HumanDecision` created with `decisionType: defectClarification`, `blocking: true`
3. `DefectStatus` → `needsClarification`
4. Triage job terminates (zero worker capacity occupied)
5. Human answers via Needs You → `DefectClarification` updated, `HumanDecision` resolved
6. `DefectStatus` → `triaging`
7. New triage job enqueued (same defect, no duplicate)

This reuses the existing `HumanDecision` / Needs You machinery — no second waiting mechanism.

### 7. Remediation Linkage

When a defect reaches `confirmed` (or `remediationPlanned` for design defects):

- A `WorkItem` is created with `category: bugfix` (or `feature` for design defects per ADR 0021)
- `WorkItem.featureRef` = `defectId`
- `Defect.remediationWorkItemId` = new WorkItem ID
- Normal scheduler/workflow governance applies

**Design defects route through Design Governance (ADR 0021 / checkpoint 003)** — never directly to implementation agent.

### 8. Fix Verification

When remediation WorkItem completes:

- `DefectStatus` → `fixReadyForVerification`
- `HumanDecision` created with `decisionType: defectFixVerification`, `blocking: true`
- Human chooses: `approve` (fixed) → `resolved` → `closed`; `reject` (still broken) → `reported` (reopen same defect); `rework` (partially fixed) → `confirmed`

### 9. Evidence Model

`DefectEvidence.kind` uses `EvidenceIntakeKind` enum. Binary artifacts (screenshots) reference an `ArtifactReference` via `artifactId`. The platform provides a provider-neutral `DefectArtifactStore` interface:

```dart
abstract class DefectArtifactStore {
  Future<ArtifactReference> store({required String defectId, required String filename, required List<int> content, required String contentType, String? description});
  Future<List<int>> retrieve(String artifactId);
  Future<ArtifactReference?> metadata(String artifactId);
  Future<void> delete(String artifactId);
}
```

**Production backend:** `GcsArtifactStore` (Google Cloud Storage). **Dev backend:** `LocalArtifactStore` (filesystem at `.shipit/defect-artifacts/`). **No binary payloads in PostgreSQL** — only metadata/references.

### 10. Redaction

All auto-captured context (`clientContextJson`, diagnostic bundles) passes through `EvidenceRedactor` BEFORE storage. Sensitive patterns (password, secret, token, api_key, authorization, cookie, session, signing_key, database_url, db_password, private_key) are replaced with `[REDACTED]`.

### 11. API Surface (ControlPlaneService)

| Method | Purpose |
|--------|---------|
| `createDefect(...)` | Persist Defect + initial Evidence + Event |
| `listDefects({status, classification, limit})` | Filtered listing |
| `inspectDefect(defectId)` | Full detail: defect + evidence + clarifications + events + triage + remediation |
| `addDefectEvidence(defectId, kind, description, artifactId)` | Append evidence |
| `requestClarification(defectId, question, reason)` | AI-initiated (internal) |
| `answerClarification(clarificationId, answer)` | Human answer → resume triage |
| `verifyFix(defectId, choice, rationale)` | Human verification |

### 12. Serverpod Endpoints

`DefectEndpoints` with methods matching ControlPlaneService. Endpoints are read-only observers or decision resolvers — **never set state directly**.

### 13. Database Migrations

New migration creates tables: `defect`, `defect_evidence`, `defect_event`, `defect_clarification` with indexes per Checkpoint 002 §5.1–5.4. CAS `version` columns on all mutable tables.

## Consequences

- Defect domain is fully durable, restart-surviving, and Product-scoped where applicable
- AI triage is advisory; human authority remains explicit via HumanDecision
- Design defect routing is blocked until Design Governance lifecycle exists (checkpoint 003)
- Binary artifact storage is provider-neutral; GCS implementation confined to its package
- No new scheduler or workflow engine — reuses existing Job/JobType infrastructure

## Alternatives Considered

- **Triage as workflow state machine:** Rejected — triage is an advisory execution, not a workflow. Workflow engine governs WorkItems, not defects.
- **Separate clarification table vs reusing HumanDecision:** Reused HumanDecision — single waiting mechanism, existing Needs You integration.
- **Confidence scoring as gate:** Rejected — confidence is advisory metadata only; no platform logic branches on it.

## References

- Checkpoint 002: `docs/checkpoints/002-human-bug-reporting-ai-defect-triage-planning.md`
- Platform contracts: `packages/platform_contracts/lib/src/types/defect.dart`, `defect_evidence.dart`, `defect_event.dart`, `defect_clarification.dart`, `triage_result.dart`
- ADR 0018: Per-product git credentials (evidence storage reference-by-name)
- ADR 0019: Standing policy authorisations (clarification uses HumanDecision, not policy)
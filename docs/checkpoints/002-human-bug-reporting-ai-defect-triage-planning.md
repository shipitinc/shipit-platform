# CHECKPOINT 002 — HUMAN BUG REPORTING + AI DEFECT TRIAGE

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

**Existing AEF concepts:**
- `WorkItem` with typed `WorkItemState` lifecycle (25 states, snake_case wire values)
- `HumanDecision` with typed `HumanDecisionType`, `HumanDecisionStatus`, `HumanDecisionChoice`
- `WorkflowTransitionRecord` — append-only history with CAS
- `DurableWorkflowEngine` — state machine with guard conditions
- `HumanDecisionRouting` — static routing table for (type, choice) → state
- `Job` / `JobQueue` / `Scheduler` — durable job queue with claim-CAS
- `AgentExecution` / `AgentResult` — bounded agent execution lifecycle
- `PlatformVerification` — independent evidence
- `ArtifactReference` — links to external artifacts
- `WorkItemCategory` enum includes `bugfix` (already exists)

**No defect/bug types exist.** The only defect-adjacent concept is `WorkItemCategory.bugfix`.

---

## 1A. PLANNING REVISIONS

This checkpoint is amended by revision, not by silent rewrite. Superseded decisions
remain in the document marked as **SUPERSEDED** so the original reasoning stays
inspectable.

| Rev | Date | Change | Reason |
|-----|------|--------|--------|
| R1 | (original) | Initial planning checkpoint | — |
| R2 | 2026-09-15 | Artifact storage backend: S3-compatible → Google Cloud Storage | Explicit product/infrastructure decision |
| R3 | 2026-09-15 | Added DESIGN_DEFECT remediation routing dependency on DESIGN_GOVERNANCE_AUTOMATION_001 | Design governance lifecycle now specified |
| R4 | 2026-09-15 | Status parked pending control-plane visual language selection (DCR-001) | Visual direction reset in progress |

### 1A.1 R2 — Artifact storage backend supersession

- **Previous decision (R1):** provider-neutral `ArtifactStore` with an
  **S3-compatible future backend** (S3/MinIO).
- **Superseded by (R2):** provider-neutral `ArtifactStore` with a
  **Google Cloud Storage production backend**.
- **Reason:** explicit product/infrastructure decision.

The *domain boundary is unchanged*: the interface remains provider-neutral. Only the
named production implementation changed. Sections affected: **9**, **9A** (new),
**10**, **20**, **25**. The original S3 wording in those sections is retained and
marked **SUPERSEDED (R2)** rather than deleted.

### 1A.2 R3 — Design defect routing dependency

`designDefect` remediation is no longer described as a generic "design change
authority" hand-off. It now routes through the governed lifecycle specified in
`DESIGN_GOVERNANCE_AUTOMATION_001`
(`docs/checkpoints/003-design-governance-automation-planning.md`).
Sections affected: **13**, **14**.

### 1A.3 R4 — Status parked

Production screen design is deliberately deferred until the ShipIt control-plane
visual language is selected via **DCR-001**
(`VISUAL_DIRECTION_APPROVAL_REQUIRED`). Sections affected: **23**, **25**, **26**.

---

## 2. CHANGE INTENT

**Problem:** ShipIt needs a first-class mechanism for human operators to report defects that automated agents and automated QA did not detect. AI implementation agents may produce behavior that is technically valid but incorrect, visually wrong, difficult to use, device/browser-specific, or inconsistent with human expectations. The human must be able to report problems with evidence, and the platform must route those reports through governed triage and remediation.

**Scope:** First slice — report, persist, triage, classify, link to affected work, create governed remediation, require regression evidence, return for human verification when appropriate.

**Not in scope:** Jira replacement, customer support, crash analytics, Sentry replacement, arbitrary file manager, full log aggregation, production observability, public bug-reporting portal.

---

## 3. FEATURE ID

```
HUMAN_BUG_REPORTING_001
```

---

## 4. FEATURE REQUIREMENT

A human operator must be able to say "Something ShipIt built is wrong" and attach enough context that an AI triage agent can investigate without requiring the human to manually reconstruct the entire engineering history.

The defect record and the remediation work item must be separate entities. One defect may relate to an affected WorkItem, Run, AgentExecution, PlatformVerification, or deployment. The defect captures OBSERVED PROBLEM + EVIDENCE + TRIAGE STATE. The remediation WorkItem captures ENGINEERING WORK AUTHORIZED TO FIX IT.

---

## 5. DEFECT DOMAIN MODEL

### 5.1 Defect (first-class entity)

**Identity:** `DEF-<NNNNNN>` — zero-padded 6-digit sequential identifier (e.g., `DEF-000001`). Stable, durable, independently addressable.

**Table:** `defect`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `defectId` | `text` UNIQUE | `DEF-000001` |
| `title` | `text` NOT NULL | Human-readable summary |
| `description` | `text` | What happened |
| `expectedBehavior` | `text` | What the human expected |
| `reproductionSteps` | `text` | Optional steps |
| `severity` | `text` NOT NULL | Wire value of `DefectSeverity` |
| `status` | `text` NOT NULL | Wire value of `DefectStatus` |
| `classification` | `text` | Wire value of `DefectClassification` (set during triage) |
| `reporter` | `text` NOT NULL | Who reported |
| `affectedWorkItemId` | `text` | FK → work_item (nullable) |
| `affectedRunId` | `text` | Denormalized run reference (nullable) |
| `remediationWorkItemId` | `text` | FK → work_item (set when remediation created) |
| `duplicateOfDefectId` | `text` | FK → defect.defectId (nullable) |
| `currentTriageJobId` | `text` | FK → job (nullable) |
| `clientContextJson` | `text` | JSON blob of captured client context |
| `metadataJson` | `text` | Extensible metadata |
| `createdAt` | `timestamp` NOT NULL | |
| `updatedAt` | `timestamp` NOT NULL | |
| `resolvedAt` | `timestamp` | |
| `closedAt` | `timestamp` | |
| `version` | `bigint` NOT NULL | CAS version |

### 5.2 DefectEvidence (append-only child)

**Table:** `defect_evidence`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `evidenceId` | `text` UNIQUE | `EVD-<NNNNNN>` |
| `defectId` | `text` NOT NULL | FK → defect.defectId |
| `kind` | `text` NOT NULL | Wire value of `EvidenceIntakeKind` |
| `artifactId` | `text` | FK → artifact_reference (nullable) |
| `contentHash` | `text` | For dedup/integrity |
| `description` | `text` | Caption/description |
| `sourceRef` | `text` | Where it came from (e.g., `agent_event:evt-123`) |
| `capturedAt` | `timestamp` NOT NULL | |
| `createdAt` | `timestamp` NOT NULL | |

### 5.3 DefectEvent (append-only history)

**Table:** `defect_event`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `eventId` | `text` UNIQUE | `DEV-<NNNNNN>` |
| `defectId` | `text` NOT NULL | FK → defect.defectId |
| `sequence` | `bigint` NOT NULL | Monotonic per defect |
| `type` | `text` NOT NULL | Wire value of `DefectEventType` |
| `fromStatus` | `text` | Previous status (nullable) |
| `toStatus` | `text` | New status (nullable) |
| `actorType` | `text` NOT NULL | Wire value of `ActorType` |
| `actorId` | `text` | |
| `payloadJson` | `text` | Structured payload |
| `occurredAt` | `timestamp` NOT NULL | |

### 5.4 DefectClarification (structured Q&A)

**Table:** `defect_clarification`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `bigint` PK | auto-increment |
| `clarificationId` | `text` UNIQUE | `CLF-<NNNNNN>` |
| `defectId` | `text` NOT NULL | FK → defect.defectId |
| `question` | `text` NOT NULL | What the AI needs |
| `reason` | `text` NOT NULL | Why this information matters |
| `status` | `text` NOT NULL | `pending` or `answered` |
| `answer` | `text` | Human response (nullable) |
| `humanDecisionId` | `text` | FK → human_decision (nullable, for Needs You integration) |
| `requestedByTriageJobId` | `text` | FK → job |
| `requestedAt` | `timestamp` NOT NULL | |
| `answeredAt` | `timestamp` | |
| `createdAt` | `timestamp` NOT NULL | |

### 5.5 DiagnosticBundle (sanitized context reference)

Not a separate table. Stored as JSON in `defect.clientContextJson` and referenced via `defect_evidence.sourceRef`. Contains:

```json
{
  "currentRoute": "/runs/wi-123",
  "affectedWorkItemId": "wi-123",
  "workflowState": "agent_executing",
  "agentExecutionId": "ae-456",
  "platformVerificationId": "pv-789",
  "relevantTransitionRange": ["t-10", "t-15"],
  "appVersion": "0.1.0",
  "viewport": "1280x800",
  "platform": "macos_arm64",
  "browserCategory": "chrome",
  "theme": "dark",
  "capturedAt": "2026-09-15T12:00:00Z"
}
```

---

## 6. DEFECT LIFECYCLE

### 6.1 Status Enum

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

### 6.2 Lifecycle States Description

| State | Meaning |
|-------|---------|
| `reported` | Human submitted defect. Awaiting triage. |
| `triaging` | AI triage agent is investigating. |
| `needsClarification` | AI requires more information. Human must answer. |
| `confirmed` | Triage confirmed the defect. Awaiting remediation planning. |
| `notReproducible` | Triage could not reproduce. May close or await more evidence. |
| `duplicate` | Triage determined this is a duplicate of another defect. |
| `remediationPlanned` | A remediation WorkItem has been created. |
| `fixInProgress` | Remediation WorkItem is being implemented. |
| `fixReadyForVerification` | Fix is complete. Awaiting human verification. |
| `resolved` | Human confirmed the fix. |
| `closed` | Defect is permanently closed. |

### 6.3 Terminal States

`closed`, `duplicate`, `notReproducible` are terminal for the defect lifecycle (though `notReproducible` may be reopened with new evidence).

---

## 7. TRANSITION GRAPH

```
                    ┌──────────────────────────────┐
                    │                              │
                    ▼                              │
               reported ──────────┐                │
                    │             │                │
                    ▼             ▼                │
               triaging     notReproducible ◄──────┘
              ╱   │   ╲          │
             ╱    │    ╲         │ (new evidence)
            ▼     ▼     ▼        │
 needsClarification │  duplicate │
      │    │        │     │      │
      │    ▼        ▼     │      │
      │  confirmed        │      │
      │    │              │      │
      │    ▼              │      │
      │ remediationPlanned│      │
      │    │              │      │
      │    ▼              │      │
      │ fixInProgress     │      │
      │    │              │      │
      │    ▼              │      │
      │ fixReadyForVerification │
      │    │              │      │
      │    ▼              │      │
      │  resolved ────────┘      │
      │    │                     │
      │    ▼                     │
      │  closed                  │
      │                          │
      └──────────────────────────┘
```

### 7.1 Legal Transitions

| From | To | Trigger | Guard |
|------|----|---------|-------|
| `reported` | `triaging` | `systemEvent` | Triage job claimed |
| `reported` | `notReproducible` | `triageResult` | No evidence supports defect |
| `reported` | `duplicate` | `triageResult` | Existing open defect matches |
| `triaging` | `needsClarification` | `triageResult` | More information required |
| `triaging` | `confirmed` | `triageResult` | Defect confirmed with evidence |
| `triaging` | `notReproducible` | `triageResult` | Cannot reproduce |
| `triaging` | `duplicate` | `triageResult` | Duplicate found |
| `needsClarification` | `triaging` | `clarificationAnswered` | Human answered question |
| `needsClarification` | `closed` | `manual` | Human closes without answering |
| `confirmed` | `remediationPlanned` | `systemEvent` | Remediation WorkItem created |
| `remediationPlanned` | `fixInProgress` | `systemEvent` | Remediation WorkItem started |
| `fixInProgress` | `fixReadyForVerification` | `systemEvent` | Remediation WorkItem completed |
| `fixReadyForVerification` | `resolved` | `humanVerification` | Human confirms fix |
| `fixReadyForVerification` | `reported` | `humanVerification` | Human says still broken (reopens) |
| `resolved` | `closed` | `humanVerification` | Human closes |
| `notReproducible` | `triaging` | `newEvidence` | New evidence provided |
| `*` | `closed` | `manual` | Human/authoritative closure |

---

## 8. EVIDENCE MODEL

### 8.1 EvidenceIntakeKind Enum

```dart
enum EvidenceIntakeKind {
  screenshot('screenshot'),
  logExcerpt('log_excerpt'),
  diagnosticBundle('diagnostic_bundle'),
  textDescription('text_description'),
  agentEventReference('agent_event_reference'),
  platformVerificationReference('platform_verification_reference'),
  transitionHistoryReference('transition_history_reference');
}
```

### 8.2 Evidence Lifecycle

1. Human submits defect → `textDescription` evidence auto-created
2. Client context captured → `diagnosticBundle` evidence auto-created
3. If reporting from a Run context → `agentEventReference`, `platformVerificationReference`, `transitionHistoryReference` auto-created as applicable
4. Human may attach screenshots → `screenshot` evidence created
5. Triage agent may add evidence references during investigation
6. Each evidence record links to an `ArtifactReference` for binary content (screenshots) or is self-contained (text/log references)

### 8.3 Evidence not auto-sent to LLMs

The triage agent receives explicit authorized evidence references. Raw logs are not automatically sent to any agent. The `DiagnosticBundle` is sanitized before storage (see Section 10).

---

## 9. ARTIFACT STORAGE STRATEGY

> **Revised in R2 (2026-09-15).** See §1A.1. The production backend is
> **Google Cloud Storage**, not S3/MinIO. The domain boundary is unchanged.

### 9.0 Superseded decision (kept for history)

- **SUPERSEDED (R2):** ~~"The interface is compatible with future S3/MinIO
  implementations. No cloud storage introduced for first slice."~~
- **Current:** the interface stays provider-neutral, and the named production
  implementation is `GcsArtifactStore` (Google Cloud Storage).
- **Reason:** explicit product/infrastructure decision.

### 9.1 Interface — provider-neutral boundary

The domain boundary stays provider-neutral: a single `ArtifactStore` interface.
`DefectArtifactStore` is the defect-evidence-scoped shape of that boundary and
names no provider.

```dart
abstract class DefectArtifactStore {
  Future<ArtifactReference> store({
    required String defectId,
    required String filename,
    required List<int> content,
    required String contentType,
    String? description,
  });
  Future<List<int>> retrieve(String artifactId);
  Future<ArtifactReference?> metadata(String artifactId);
  Future<void> delete(String artifactId);
}
```

### 9.2 Planned implementations

| Implementation | Environment | Backing store |
|----------------|-------------|---------------|
| `LocalArtifactStore` | dev / test | Local filesystem |
| `GcsArtifactStore` | production | Google Cloud Storage |

`LocalArtifactStore` (filesystem):
- Base path: `.shipit/defect-artifacts/` (gitignored)
- Structure: `defect-artifacts/<defectId>/<artifactId>/<filename>`
- Metadata stored in `defect_evidence` table rows
- Content hash (SHA-256) computed on store, stored in `ArtifactReference.contentHash`

`GcsArtifactStore` (production):
- Private GCS bucket, object key is an opaque `objectRef` (see §9A)
- Same `ArtifactReference` contract and same SHA-256 integrity guarantee
- GCS SDK confined to this implementation package

### 9.3 Architecture chain

```
DefectEvidence → ArtifactReference → ArtifactStore → { LocalArtifactStore | GcsArtifactStore }
```

**HARD RULE — provider containment.** GCP-specific types (bucket handles, GCS
object/blob types, GCP credential types, signed-URL types, any `googleapis`/GCS SDK
symbol) MUST NEVER be exposed to:

- `Defect`
- `WorkItem`
- `workflow_engine`
- `scheduler`
- any generic `ArtifactReference` consumer

The GCS SDK dependency is confined to the `GcsArtifactStore` implementation package.
No other package may import it. A violation of this rule is an architecture
regression, not a style issue.

### 9.4 Persistence split

- **Binary payload stays OUT of PostgreSQL.** No `bytea`, no base64 blob columns.
- PostgreSQL stores **metadata / reference only**; bytes live in the artifact store
  backend (filesystem in dev, GCS in production).

Provider-neutral metadata fields:

| Field | Meaning |
|-------|---------|
| `artifactId` | Stable platform identity of the artifact |
| `storageProvider` | Which backend holds the bytes (e.g. `local`, `gcs`) |
| `objectRef` | Opaque backend key — never parsed or interpreted by domain code |
| `contentType` | Allowlisted MIME type |
| `sizeBytes` | Verified byte length |
| `contentHash` | SHA-256 of stored bytes |
| `createdAt` | Creation timestamp |
| `evidenceRef` | Owning `DefectEvidence` reference |

`objectRef` is **opaque**: domain code must not build, parse, or derive URLs from it.
No permanent public URL is ever persisted as artifact identity.

### 9.5 Limits

| Constraint | Value |
|------------|-------|
| Max file size | 10 MB |
| Allowed image types | `image/png`, `image/jpeg`, `image/webp`, `image/gif` |
| Max attachments per defect | 20 |
| Max text description length | 10,000 characters |
| Max reproduction steps length | 5,000 characters |

### 9.6 Security

- Uploaded files are treated as untrusted content
- No execution of uploaded files
- HTML/SVG scripts served as `text/plain` or rejected
- Only conservative image types allowed for first slice
- Backend-specific security model for GCS: see §9A

---

## 9A. GCS SECURITY MODEL

Added in **R2 (2026-09-15)**. Applies to `GcsArtifactStore` only; it does not relax
any rule in §9 or §10.

### 9A.1 Bucket posture

- **Private buckets only.** No public buckets.
- No public object ACLs, no `allUsers` / `allAuthenticatedUsers` grants.
- **No permanent public URL is persisted as artifact identity.** Identity is
  `artifactId` + opaque `objectRef`.
- **Short-lived authorized access only.** Every read and write is granted through a
  time-bounded authorization issued by the Control Plane after an authorization check.

### 9A.2 Upload flow

```
Flutter
  → Control Plane
      → validate authorization / content type / size
      → issue short-lived GCS upload authorization
  → client uploads bytes directly to GCS
  → Control Plane finalize/verify (SHA-256 hash + size check)
      → create ArtifactReference
```

- The Control Plane validates **authorization, content type, and size** *before*
  issuing any upload authorization.
- The upload authorization is short-lived and scoped to a single object key.
- `ArtifactReference` is created **only after** finalize/verify succeeds. A failed
  hash or size check yields no artifact record.

### 9A.3 Download flow

```
Flutter
  → Control Plane
      → authorize the requester for this artifact
      → issue short-lived GCS read authorization
  → client reads bytes from GCS
```

- Every download performs an authorization check against the owning defect/evidence.
- Read authorizations are short-lived and non-transferable in intent.

### 9A.4 Credential model

- **GCP service credentials MUST NEVER be exposed to Flutter.** No service account
  JSON, no long-lived token, no private key ever reaches the client bundle or the
  browser.
- **Production uses deployed workload/service identity** (no key material in the
  application).
- **Local development may use approved Application Default Credentials.**
- **Service-account key files MUST NOT be added to the repository.** Credentials are
  referenced by name only, per the reference-by-name convention in
  **AGENTS.md §13** (secret values live in the local secret store / CI org secrets,
  never in git, logs, or goldens).

### 9A.5 Preserved controls (unchanged by R2)

All first-slice controls remain in force regardless of backend:

- Allowlisted content types
- Bounded file sizes
- Bounded attachment counts per defect
- Safe, non-interactive image previews
- Uploads treated as untrusted content
- No execution of uploaded code
- Evidence redaction before storage (§10)
- Hash / integrity validation
- Provenance (who uploaded, when, for which defect/evidence)

### 9A.6 Rendering restriction

Conservative image formats only initially. The UI MUST NOT render arbitrary active
content — no active HTML, no SVG rendered as markup. Such payloads are rejected or
served as inert `text/plain`.

---

## 10. REDACTION / SECURITY MODEL

> **R2 note (2026-09-15).** The redaction model below is backend-independent and is
> unchanged by the S3 → Google Cloud Storage supersession (§1A.1). Backend-specific
> storage security for the production GCS backend is specified in **§9A**; it adds
> requirements and relaxes none of the rules in this section.

### 10.1 Redaction Boundary

Before storing `DiagnosticBundle` or any auto-captured context, apply `EvidenceRedactor`:

```dart
class EvidenceRedactor {
  static const _sensitivePatterns = [
    'password', 'secret', 'token', 'api_key', 'apikey',
    'authorization', 'cookie', 'session', 'signing_key',
    'database_url', 'db_password', 'private_key',
  ];

  Map<String, dynamic> redactDiagnosticBundle(Map<String, dynamic> bundle);
  String redactLogExcerpt(String raw);
}
```

### 10.2 Rules

- Any JSON key matching a sensitive pattern → value replaced with `[REDACTED]`
- Log lines containing sensitive patterns → entire line replaced with `[REDACTED LINE]`
- Environment variables not on an explicit allowlist → excluded from capture
- API responses containing auth headers → headers stripped
- The redactor runs BEFORE storage, not at query time

### 10.3 Allowlist for capture

Captured client context fields:
- `currentRoute` — safe
- `affectedWorkItemId` — safe
- `workflowState` — safe
- `agentExecutionId` — safe
- `platformVerificationId` — safe
- `appVersion` — safe
- `viewport` — safe
- `platform` — safe
- `browserCategory` — safe
- `theme` — safe
- `capturedAt` — safe

NOT captured unless explicitly requested:
- API keys, tokens, passwords, session data, cookies, environment variables, network details, file system paths outside workspace.

---

## 11. AI TRIAGE CONTRACT

### 11.1 Triage Role

`triageDefect` — a new `AgentRole` value. Distinct from `implementer`, `engineeringReviewer`, etc. The triage agent is NOT the implementation agent.

### 11.2 Triage Agent Input

| Field | Source |
|-------|--------|
| Defect title + description | Human input |
| Expected behavior | Human input |
| Reproduction steps | Human input (optional) |
| Severity | Human input |
| Classification | System (intake category) |
| Affected WorkItem context | Auto-captured |
| Diagnostic bundle | Auto-captured, redacted |
| Evidence references | All defect_evidence rows |
| Transition history of affected WorkItem | Auto-captured |
| Agent execution events (if applicable) | Auto-captured |
| Platform verification results (if applicable) | Auto-captured |

### 11.3 Triage Agent Output (Structured)

```dart
class TriageResult {
  final DefectStatus recommendedStatus;   // confirmed, not_reproducible, duplicate
  final DefectClassification recommendedClassification;
  final double confidence;                 // 0.0 – 1.0
  final String suspectedCategory;         // e.g., "status_mapping", "layout", "data_flow"
  final List<String> suspectedComponents; // e.g., ["home_page.dart", "_statusType()"]
  final bool reproductionSupported;       // Can evidence reproduce?
  final List<String> evidenceUsed;        // Which evidence items were used
  final List<DefectClarificationRequest> clarificationRequired; // If more info needed
  final String recommendedNextAction;     // Human-readable
  final String? possibleDuplicateDefectId; // If duplicate suspected
  final String? recommendedWorkItemCategory; // For remediation
  final String summary;                   // AI explanation of what appears wrong
}
```

### 11.4 Triage Job

Triage runs as a durable `Job` in the existing scheduler:
- `jobType`: `'triage_defect'`
- `requiredRole`: `AgentRole.triageDefect`
- `entryStates`: `{DefectStatus.reported, DefectStatus.needsClarification}`
- Priority: `high` (human-reported defects are urgent)
- The job persists the `TriageResult` as structured output, then transitions the defect

### 11.5 Triage Does Not Auto-Invent Requirements

If the report reveals ambiguous expected behavior:
- Classify as `REQUIREMENT_GAP`
- Route to human authority
- Do not let triage agent silently decide product policy

---

## 12. CLARIFICATION MODEL

### 12.1 Structured Clarification

When the triage agent determines more information is required:

1. Triage result includes `DefectClarificationRequest` list
2. System persists a `DefectClarification` row
3. System creates a `HumanDecision` (type: `defectClarification`, blocking: true) linked to the defect
4. Triage job terminates — no worker capacity occupied
5. `DefectStatus` transitions to `needsClarification`
6. Needs You surfaces the clarification request

### 12.2 DefectClarificationRequest

```dart
class DefectClarificationRequest {
  final String question;     // What the AI needs to know
  final String reason;       // Why this matters for diagnosis
}
```

### 12.3 Human Answers via Needs You

1. Human sees clarification in Needs You with defect context
2. Human provides answer
3. `DefectClarification` row updated with answer
4. `DefectStatus` transitions from `needsClarification` → `triaging`
5. New triage job is enqueued
6. Same defect resumes — no duplicate created

### 12.4 Integration with Existing HumanDecision

Reuse `HumanDecision` with new `HumanDecisionType.defectClarification`. This keeps clarification in the existing Needs You system without inventing a second waiting mechanism.

---

## 13. DEFECT CLASSIFICATION / ROUTING

### 13.1 DefectClassification Enum

```dart
enum DefectClassification {
  implementationDefect('implementation_defect'),
  designDefect('design_defect'),
  requirementGap('requirement_gap'),
  environmentDefect('environment_defect');
}
```

### 13.2 Intake Category (pre-triage)

When the human submits a defect, the UI collects an optional intake category:

```dart
enum DefectIntakeCategory {
  visualBug('visual_bug'),
  incorrectBehavior('incorrect_behavior'),
  usabilityIssue('usability_issue'),
  browserSpecific('browser_specific'),
  intermittentFailure('intermittent_failure'),
  unexpectedState('unexpected_state'),
  other('other');
}
```

This is informational. The triage agent produces the authoritative `DefectClassification`.

### 13.3 Routing by Classification

| Classification | Route |
|---------------|-------|
| `implementationDefect` | → Remediation WorkItem (category: `bugfix`) → independent review → regression QA → human verification |
| `designDefect` | → **DESIGN_GOVERNANCE_AUTOMATION_001 lifecycle** (see §13.5) |
| `requirementGap` | → Human decision/requirement authority → downstream design/implementation as required |
| `environmentDefect` | → Infrastructure/environment remediation |

### 13.4 Design Defect Governance

A `designDefect` classification MUST NOT route directly to a coding agent for implementation. It must route to design change authority first. The workflow engine must enforce this.

### 13.5 Design Defect Remediation Dependency (R3)

Added in **R3 (2026-09-15)**. When `classification == designDefect`, remediation
does **not** use the generic implementation path. It routes through the
`DESIGN_GOVERNANCE_AUTOMATION_001` lifecycle:

```
Defect (classification: designDefect)
  → Design remediation WorkItem
    → DesignJob
      → DesignRevision
        → independent DesignReviewJob
          → human approval (where risk requires)
            → implementation
              → QA
                → human defect verification
```

**Reference:** `docs/checkpoints/003-design-governance-automation-planning.md`
(`DESIGN_GOVERNANCE_AUTOMATION_001`). That checkpoint is the authority for the
design lifecycle; this checkpoint only records the dependency and the entry
condition.

**HARD RULE — the coding agent must not diverge from approved design.** The
implementation step consumes the *approved* `DesignRevision` as its authority. An
implementation agent may not reinterpret, "improve", substitute, or partially apply
the approved design. Divergence from approved design is itself a defect
(`designDefect` or `implementationDefect` as triage determines), not an acceptable
outcome. Independent review must assert design fidelity, not merely code
correctness.

This dependency is blocking: `designDefect` remediation cannot be scheduled until
the design governance lifecycle exists to receive it.

---

## 14. REMEDIATION WORK ITEM MODEL

### 14.1 Relationship

```
Defect (DEF-000123)
  ├── affectedWorkItem: wi-abc (the original run with the bug)
  ├── remediationWorkItem: wi-def (the fix work item)
  │     ├── category: bugfix
  │     ├── featureRef: DEF-000123 (references defect)
  │     └── description: includes defect evidence, triage result, regression expectations
  └── evidence: [EVD-001, EVD-002, ...]
```

### 14.2 Remediation WorkItem Creation

When a defect is confirmed and ready for remediation:

1. Defect status → `remediationPlanned`
2. System creates a `WorkItem` with:
   - `category`: `bugfix`
   - `title`: `Fix: <defect title>`
   - `description`: includes defect summary, triage result, evidence references, regression expectations
   - `featureRef`: `DEF-<id>` (links back to defect)
   - `requirementRef`: original affected WorkItem ID (if applicable)
3. Defect's `remediationWorkItemId` is set
4. A `Job` is enqueued for implementation via the normal scheduler path

### 14.3 Routing by Classification

| Classification | Remediation Category | Entry States |
|---------------|---------------------|--------------|
| `implementationDefect` | `bugfix` | Standard implementation flow |
| `designDefect` | `feature` (design revision) | Design governance flow — see §13.5 / §14.5 |
| `requirementGap` | `feature` (new requirement) | Requirement flow |
| `environmentDefect` | `chore` | Infrastructure flow |

### 14.4 No Direct Agent Dispatch

Bug Report → coding agent immediately editing production code is PROHIBITED. The remediation must go through normal workflow governance.

### 14.5 Design Remediation WorkItem Dependency (R3)

Added in **R3 (2026-09-15)**. A design remediation WorkItem created from a
`designDefect` is governed by `DESIGN_GOVERNANCE_AUTOMATION_001`
(`docs/checkpoints/003-design-governance-automation-planning.md`), not by the
`bugfix` implementation path:

| Step | Owner |
|------|-------|
| Design remediation WorkItem created from `Defect` | Control plane |
| `DesignJob` dispatched | Scheduler (design governance lifecycle) |
| `DesignRevision` produced | Design agent / design authority |
| Independent `DesignReviewJob` | Reviewer distinct from the producer |
| Human approval where risk requires | `HumanDecision` gate |
| Implementation of the approved revision | Implementation agent |
| QA | `qa_orchestration` |
| Human defect verification | Original reporter (§16) |

The defect's `remediationWorkItemId` points at the design remediation WorkItem; the
defect lifecycle (§6) is unchanged — it still observes
`remediationPlanned → fixInProgress → fixReadyForVerification`.

**HARD RULE (restated):** the coding agent must not diverge from approved design.
Implementation authority is the approved `DesignRevision`, and only the approved
revision.

---

## 15. REGRESSION POLICY

### 15.1 Regression Expectation

A confirmed defect produces a regression expectation whenever reasonably testable.

### 15.2 Sequence

```
REPRODUCE FAILURE FIRST
        ↓
create regression test/evidence
        ↓
implement fix
        ↓
prove regression now passes
```

### 15.3 Evidence

The remediation WorkItem's QA contract must include:
- Regression evidence type: the original defect reproduction steps as a testable artifact
- Proof that the regression now passes
- PlatformVerification of the fix

### 15.4 "Fixed" is Not Sufficient

The implementation agent cannot simply say "fixed." QA evidence must prove the observed defect is addressed. The human receives a verification request if the defect requires human confirmation.

---

## 16. HUMAN FIX VERIFICATION

### 16.1 When Required

Human verification is required when:
- The defect was user-visible (screenshot evidence exists)
- The defect was a usability issue
- The defect involved design fidelity
- The triage agent recommends human verification
- The defect was classified as `designDefect`

### 16.2 Verification Flow

```
Defect: fixReadyForVerification
  → HumanDecision (type: defectFixVerification, blocking: true)
  → Needs You surfaces: "Verify fix for DEF-000123"
  → Human inspects the fix
  → Chooses: fixed | stillBroken | partiallyFixed
```

### 16.3 Verification Choices

```dart
// Extend HumanDecisionChoice (or use existing values)
// 'approve' → fixed
// 'reject' → stillBroken
// 'rework' → partiallyFixed
```

### 16.4 If Still Broken

- `DefectStatus` → `reported` (reopened)
- New evidence from the human is attached
- New triage cycle begins
- SAME defect — no duplicate created

### 16.5 If Partially Fixed

- `DefectStatus` → `confirmed` (remains open)
- Human describes what remains broken
- New triage/remediation cycle for remaining issues

---

## 17. API REQUIREMENTS

### 17.1 New Endpoints (Serverpod)

**DefectEndpoints:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `create` | `Future<Map> create(Session, {required String title, required String description, String? expectedBehavior, String? reproductionSteps, required String severity, String? intakeCategory, String? affectedWorkItemId, String? affectedRunId, String? clientContextJson})` | Report a new defect |
| `list` | `Future<Map> list(Session, {String? status, int? limit})` | List defects with filters |
| `inspect` | `Future<Map> inspect(Session, {required String defectId})` | Full defect detail + evidence + history |
| `addEvidence` | `Future<Map> addEvidence(Session, {required String defectId, required String kind, String? description, String? artifactId})` | Add evidence to a defect |
| `requestClarification` | `Future<Map> requestClarification(Session, {required String defectId, required String question, required String reason})` | AI requests clarification |
| `answerClarification` | `Future<Map> answerClarification(Session, {required String clarificationId, required String answer})` | Human answers clarification |
| `verifyFix` | `Future<Map> verifyFix(Session, {required String defectId, required String choice, String? rationale})` | Human verifies fix |

### 17.2 Existing Endpoint Changes

**HomeEndpoints:**
- `overview()` — add `defectsAwaitingTriage` and `defectsNeedingVerification` counts

### 17.3 ControlPlaneService Extensions

New methods:
- `createDefect(...)` — persist Defect + initial DefectEvidence + DefectEvent
- `listDefects(...)` — filtered listing
- `readDefect(String defectId)` — full detail
- `addDefectEvidence(...)` — append evidence
- `transitionDefect(...)` — apply status transition with CAS + append DefectEvent
- `createRemediationWorkItem(...)` — create linked bugfix WorkItem
- `createDefectClarification(...)` — persist clarification + HumanDecision
- `answerDefectClarification(...)` — persist answer + transition defect

---

## 18. CONTROL-PLANE IA PROPOSAL

### 18.1 Navigation

Add to existing navigation (no new top-level destination):

**Global:** "Report Bug" floating action button or toolbar button — always available.

**Contextual:** When viewing a Run, "Report Bug" pre-fills affected WorkItem/Run context.

**Defects surface:** Add "Defects" as a navigation destination alongside Home, Runs, Needs You.

### 18.2 Minimum UI Surfaces

| Surface | Purpose |
|---------|---------|
| Report Bug form | Submit new defect with evidence |
| Defects list | Browse all defects with status filters |
| Defect detail | Full defect view: problem, evidence, triage, classification, remediation, timeline |
| Needs You: clarification card | Answer AI clarification questions |
| Needs You: verification card | Verify fix for a defect |

### 18.3 Report Bug Form

| Field | Required | Notes |
|-------|----------|-------|
| Title | YES | Brief summary |
| What happened? | YES | Human description |
| What did you expect? | YES | Expected behavior |
| How can we reproduce? | NO | Steps |
| Severity | YES | Choice: cosmetic, annoying, blocking, data-loss |
| Affected Run | AUTO | Pre-filled if reporting from a Run context |
| Screenshot | NO | Drag/drop or file select |
| Client context | AUTO | Captured silently |

### 18.4 Defect Detail View

| Section | Content |
|---------|---------|
| Header | DEF-000123 · Status badge · Severity badge |
| Problem | Title, description, expected behavior |
| Evidence | Screenshot previews, diagnostic bundle, log excerpts |
| Affected Context | WorkItem, Run, workflow state, timestamps |
| AI Triage Summary | Classification, confidence, suspected components, summary |
| Clarification History | Q&A pairs with timestamps |
| Remediation WorkItem | Link + status |
| Verification | Result + timestamp |
| Timeline | Full DefectEvent history |

---

## 19. ACCEPTANCE CRITERIA

| AC | Criterion |
|----|-----------|
| AC-1 | Human can submit a defect via the Report Bug form with title, description, expected behavior, severity, and optional reproduction steps. |
| AC-2 | Screenshot can be attached to a defect. |
| AC-3 | Affected Run/WorkItem is automatically associated when reporting from a Run context. |
| AC-4 | Client context (route, viewport, platform, app version, theme) is automatically captured and redacted. |
| AC-5 | Sensitive data (tokens, passwords, API keys) is redacted before storage. |
| AC-6 | Defect persists across process restarts with stable DEF-NNNNNN identifier. |
| AC-7 | Triage is scheduled as a durable Job. If the process crashes, triage resumes from durable state. |
| AC-8 | Triage result is structured (status, classification, confidence, components, summary). |
| AC-9 | Insufficient evidence triggers clarification request. Clarification appears in Needs You. |
| AC-10 | Human answer to clarification resumes the SAME defect with a new triage cycle. No duplicate created. |
| AC-11 | Classification routes correctly: implementation_defect → bugfix WorkItem, design_defect → design authority, requirement_gap → human authority. |
| AC-12 | Confirmed defect creates a linked remediation WorkItem (category: bugfix) through normal workflow governance. |
| AC-13 | Regression evidence is required before a fix is considered complete. |
| AC-14 | Design defects do NOT route directly to coding agents. |
| AC-15 | Fix can return to the reporter for human verification. |
| AC-16 | "Still broken" response reopens the SAME defect with new evidence. No new defect created. |
| AC-17 | Full DefectEvent history remains inspectable. |
| AC-18 | Existing operator UI tests continue to pass. No regressions. |
| AC-19 | Root gate passes: format + analyze + test. |

---

## 20. QA CONTRACT

### 20.1 Unit Tests

| Area | What to test |
|------|-------------|
| Defect lifecycle transitions | All legal transitions; illegal transitions rejected |
| Defect ID generation | Sequential, stable, unique |
| Evidence redaction | Sensitive patterns replaced; safe fields preserved |
| Artifact validation | File type, size, count limits enforced |
| Classification/routing | Each classification routes to correct WorkItem category |
| Triage result parsing | Structured output validated |
| Clarification model | Create, answer, resume flow |

### 20.2 Database/Integration Tests

| Area | What to test |
|------|-------------|
| Defect persistence | CRUD with CAS version |
| Evidence append | Idempotent, ordered |
| Defect events | Append-only, monotonic sequence |
| Remediation WorkItem link | FK integrity, circular reference prevention |
| Clarification persistence | Create, answer, status transition |
| Concurrency | Concurrent defect updates settle to one winner |

### 20.3 Scheduler Tests

| Area | What to test |
|------|-------------|
| Triage job lifecycle | enqueue → claim → run → complete |
| Clarification blocks triage | Job terminates when clarification needed |
| Re-triage after clarification | New job enqueued after answer |

### 20.4 Agent Tests

| Area | What to test |
|------|-------------|
| Triage result structure | All required fields present |
| Triage output validation | Classification in enum; confidence in range |

### 20.5 BLoC Tests

| Area | What to test |
|------|-------------|
| Report form | Validation, submission, success/error states |
| Defect list | Loading, populated, filtered, empty states |
| Defect detail | Loading, all sections, evidence display |
| Clarification flow | Question display, answer submission, resume |
| Verification flow | Fixed/still broken/partially fixed choices |

### 20.6 Widget Tests

| Area | What to test |
|------|-------------|
| Report Bug form | Field validation, severity selector, screenshot attachment |
| Defect list item | Status badge, severity, title rendering |
| Defect detail | All sections render correctly |
| Needs You clarification card | Question, reason, answer field |
| Needs You verification card | Fix description, choice buttons |

### 20.7 Security Tests

| Area | What to test |
|------|-------------|
| Secret redaction | Tokens, passwords, API keys are redacted |
| Upload validation | Only allowed types accepted; oversized rejected |
| File serving | Uploaded files served safely (no script execution) |

#### 20.7.1 GCS-specific security tests (R2)

Added in **R2 (2026-09-15)** alongside the Google Cloud Storage production backend
(§9, §9A).

| Area | What to test |
|------|-------------|
| Signed-URL expiry enforcement | Issued upload/read authorizations are short-lived; an expired authorization is rejected and cannot be replayed |
| No credential leakage to client | No GCP service credential, service-account JSON, private key, or long-lived token is ever present in any client response or client bundle |
| Bucket privacy assertion | Target bucket/objects are private — no `allUsers` / `allAuthenticatedUsers` grant, no public object ACL, no permanent public URL persisted as artifact identity |
| Upload finalize/verify hash match | Finalize recomputes SHA-256 + size; mismatch rejects the upload and creates **no** `ArtifactReference` |
| Download authorization check | Read authorization is only issued after the requester is authorized for the owning defect/evidence; unauthorized requests get no GCS authorization |
| Provider containment | No GCP/GCS SDK symbol is reachable from `Defect`, `WorkItem`, `workflow_engine`, `scheduler`, or generic `ArtifactReference` consumers (§9.3 hard rule) |

### 20.8 E2E Tests

| Scenario | What to prove |
|----------|--------------|
| Report → triage → remediation | Full happy path against real PostgreSQL |
| Clarification → resume | Defect pauses for clarification, resumes on answer |
| Design defect routing | Classified as design_defect, routes to design authority |
| Fix verification → close/reopen | Human verifies, still-broken reopens same defect |
| Duplicate detection | Second similar defect linked as possible duplicate |

---

## 21. E2E SCENARIOS

### 21.1 Scenario 1: Happy Path — Status Mapping Bug

Based on the actual recent defect class where UI mapped wrong wire values.

1. Human sees incorrect status icon on Home page
2. Selects "Report Bug" (from Run context — pre-fills WorkItem)
3. Screenshots attached automatically
4. Human describes: "Status shows gray/pending for all runs instead of blue/green/red"
5. Human describes expected: "Should show blue for running, green for completed, red for failed"
6. Submits
7. System: Defect DEF-000001 created, evidence attached, triage job enqueued
8. Triage agent: inspects screenshot, context, code
9. Triage agent: returns `TriageResult` — `confirmed`, `implementationDefect`, confidence 0.95
10. System: status → `confirmed`, remediation WorkItem created (category: bugfix)
11. Implementation agent: fixes `_statusType()` mapping
12. Independent review passes
13. Regression test: status now shows correct colors
14. Human verification request sent
15. Human confirms fix
16. Defect closes

### 21.2 Scenario 2: Clarification Required

1. Human reports: "Needs You is wrong after I approve something"
2. Evidence is insufficient — no specific run, no screenshot
3. Triage: determines clarification required
4. System: persists question "Which run were you viewing when you approved?"
5. Triage job terminates
6. Needs You shows: "Clarification needed for DEF-000002"
7. Human answers: "I was on the Deploy Frontend run"
8. System: same defect resumes triage
9. New triage job runs with answer context
10. Defect confirmed with proper context
11. No duplicate defect created

### 21.3 Scenario 3: Design Defect

1. Human reports: "The approval flow UX is confusing — I can't tell what I'm approving"
2. Attached screenshots show the design IS being followed correctly
3. Triage: implementation matches approved Penpot design
4. Triage agent: returns `DefectClassification.designDefect`
5. System: routes to design change authority
6. System: does NOT create a bugfix WorkItem for coding agent
7. Design authority reviews, approves design revision
8. Design revision → implementation → QA → human verification

### 21.4 Scenario 4: Still Broken → Reopen

1. Human reports defect
2. Triage confirms, remediation created, fix implemented
3. Human receives verification request
4. Human chooses "Still broken" — provides new evidence
5. SAME defect DEF-000001 reopens
6. New triage cycle with combined evidence
7. New remediation cycle
8. Human verifies again → "Fixed"
9. Defect closes

---

## 22. DESIGN DETERMINATION

**DESIGN_REQUIRED**

This feature changes the control-plane UI. A Penpot design is required before Flutter implementation begins.

---

## 23. PENPOT DESIGN BRIEF

### 23.1 Design Authority

Use the existing control-plane operator UI design authority:
- **Team:** `c828d3cf-7d4e-8145-8008-98dfd6576a0c`
- **File:** `d8ac01df-6646-81d2-8008-a366c09aa9d3`

### 23.2 Boards to Design

| Board | Content |
|-------|---------|
| Report Bug | Form with all fields, screenshot attachment state, contextual Run pre-fill |
| Defects List | List view with status/severity filters, counts |
| Defect Detail | Full defect view with all sections |
| Needs You: Clarification | Clarification card and detail |
| Needs You: Verification | Verification card and detail |

### 23.3 Design Considerations

> **R4 note (2026-09-15).** This brief is **PARKED** (§26). The visual language
> reference below is provisional: this brief MUST inherit the visual language
> selected via **DCR-001** (`VISUAL_DIRECTION_APPROVAL_REQUIRED`) once chosen.
> Board production does not begin before then.

- Use existing approved visual language (dark mode primary, light mode variant)
  — **provisional, pending DCR-001 selection**
- Report Bug should feel like a natural extension of the existing UI, not a separate product
- Severity should use human-friendly choices, not engineering P0/P1
- Evidence previews should be safe and non-interactive
- Status badges should follow the existing `StatusChip` pattern
- Timeline should be visually clear about defect progression
- Clarification should feel urgent but not alarming

---

## 24. HUMAN DECISIONS REQUIRED

| # | Decision | Options | Recommendation |
|---|----------|---------|----------------|
| HD-1 | Should Defects be a permanent top-level nav item, or reached through contextual entry only? | Top-level nav / Contextual only / Both | Both (top-level for browsing, contextual for reporting) |
| HD-2 | Should the Report Bug button be a FAB, toolbar button, or menu item? | FAB / Toolbar / Menu | Toolbar button (less intrusive, always visible) |
| HD-3 | Should severity choices be: cosmetic/annoying/blocking/data-loss, or a different set? | [The proposed set] / Custom | Proposed set is human-friendly and sufficient |
| HD-4 | Should human verification be mandatory for all defects, or only when triage recommends it? | Always / Triage-recommended | Triage-recommended (some defects are clearly auto-verifiable) |
| HD-5 | Should the AI triage agent have authority to close defects as not-reproducible, or require human confirmation? | Auto-close / Human-confirm | Auto-close with human notification (faster loop) |

---

## 25. DEFERRED ITEMS

| Item | Reason | Future Slice |
|------|--------|-------------|
| ~~S3/MinIO artifact storage~~ **SUPERSEDED (R2)** → Google Cloud Storage artifact storage (`GcsArtifactStore`) | First slice uses `LocalArtifactStore` (filesystem); GCS is the production backend (§9, §9A) | Slice 2+ |
| Bug reporting screen design — deferred pending visual language selection (DCR-001) | Control-plane visual language is being re-selected; production screen design cannot start until `VISUAL_DIRECTION_APPROVAL_REQUIRED` clears (§26) | Post-DCR-001 |
| Semantic duplicate search | Conservative first slice | Slice 2+ |
| Crash analytics integration | Out of scope — this is engineering defects, not crashes | Deferred |
| Public bug-reporting portal | Internal operator tool only | Deferred |
| Agent self-reporting bugs | First slice is human-only | Slice 3+ |
| Multi-defect batch operations | First slice is single-defect | Deferred |
| Custom fields/metadata schema | First slice uses fixed schema | Deferred |
| Defect metrics/dashboard | First slice is operational, not analytical | Deferred |
| Automated severity inference | Human provides severity for first slice | Slice 2+ |
| Cross-product defect tracking | First slice is single-product | Deferred |

---

## 26. STATUS

**Status: READY_FOR_DESIGN — PARKED**

Set in **R4 (2026-09-15)**. See §1A.3.

All planning decisions are documented and the Penpot design brief (§23) is prepared.
Planning artifacts remain **authoritative** — nothing in §1–§25 is withdrawn.

**Why parked:** production screen design is deliberately deferred until the ShipIt
control-plane **visual language is selected via DCR-001**
(`VISUAL_DIRECTION_APPROVAL_REQUIRED`). Designing these five boards against the
current visual language would produce work that must be redone once the new direction
is chosen, so the design step is held rather than started.

**Consequences while parked:**

- No Penpot board production for this feature.
- No Flutter implementation of the bug-reporting surfaces.
- The §23 design brief MUST inherit the newly selected visual language once DCR-001
  is resolved; §23.3's reference to the "existing approved visual language" is
  provisional until then.
- Non-UI planning (domain model, lifecycle, storage, triage contract, QA contract)
  stays authoritative and is not blocked by DCR-001.

**Unpark condition:** DCR-001 visual direction approved → refresh §23 against the
selected visual language → design approval gate → implementation checkpoint.

---

## §27 SESSION HANDOFF

### What was done
- Full AEF planning checkpoint produced for `HUMAN_BUG_REPORTING_001`
- Domain model designed (Defect, DefectEvidence, DefectEvent, DefectClarification)
- Lifecycle with 11 states and typed transitions defined
- Evidence model with redaction boundary designed
- Artifact storage strategy defined (local filesystem, ~~interface-compatible with S3~~ — **SUPERSEDED (R2)**: provider-neutral interface with `GcsArtifactStore` production backend, see §9 / §9A)
- AI triage contract with structured output designed
- Clarification loop integrated with existing Needs You / HumanDecision system
- Classification/routing logic designed (4 classifications, 4 routes)
- Remediation WorkItem model designed (linked to defect, normal governance)
- Regression policy defined (prove failure first, then prove fix)
- Human fix verification flow designed (fixed/stillBroken/partiallyFixed)
- API requirements specified (7 new endpoints, 1 existing endpoint extension)
- Control-plane IA proposed (Report Bug global + contextual, Defects list, Defect detail)
- 19 acceptance criteria defined
- Comprehensive QA contract (unit, database, scheduler, agent, BLoC, widget, security, E2E)
- 4 E2E scenarios designed (happy path, clarification, design defect, reopen)
- Penpot design brief prepared with 5 boards
- 5 human decisions identified

### Amendments since original (see §1A)
- **R2** — artifact storage production backend: S3-compatible → Google Cloud Storage (§9, new §9A, §10 note, §20.7.1, §25)
- **R3** — `designDefect` remediation routes through `DESIGN_GOVERNANCE_AUTOMATION_001` (§13.5, §14.5)
- **R4** — status parked pending DCR-001 visual language selection (§23.3, §25, §26)

### What needs to happen next
1. Resolve **DCR-001** visual direction (`VISUAL_DIRECTION_APPROVAL_REQUIRED`) — blocks design
2. Resolve human decisions (HD-1 through HD-5)
3. Land `DESIGN_GOVERNANCE_AUTOMATION_001` planning (`docs/checkpoints/003-design-governance-automation-planning.md`) — blocks `designDefect` remediation routing
4. Refresh §23 design brief against the selected visual language
5. Execute Penpot design for 5 boards
6. Design approval gate
7. THEN: implementation checkpoint

### Files referenced
- `packages/platform_contracts/lib/src/enums/` — 25 enum files
- `packages/platform_contracts/lib/src/types/` — 28 type files
- `packages/workflow_engine/lib/src/transitions/` — 5 transition files
- `packages/workflow_store/lib/src/store/workflow_store.dart` — WorkflowStore interface
- `packages/scheduler/lib/src/` — JobQueue, Scheduler
- `packages/execution_coordinator/lib/src/` — ExecutionCoordinator
- `packages/qa_orchestration/lib/src/` — QAOrchestration
- `packages/deployment_protocol/lib/src/artifacts/artifact_store.dart` — ArtifactStore
- `apps/server/lib/src/services/control_plane_service.dart` — ControlPlaneService
- `apps/server/lib/src/endpoints/` — 5 endpoint classes
- `apps/control_plane/lib/` — Flutter app source
- `docs/checkpoints/001-control-plane-operator-ui-planning.md` — Previous checkpoint format reference
- `docs/adr/` — 17 ADR files

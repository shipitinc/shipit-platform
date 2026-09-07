# Runtime Flow

## End-to-End Work Item Lifecycle

```
┌─────────────┐
│   PRODUCT   │◄── ProductManifest (from AEF)
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  WORK ITEM  │────►│  DESIGN PHASE    │────►│   AGENT     │
│  CREATED    │     │                  │     │   PHASE     │
└─────────────┘     │ 1. DesignContract│     └──────┬──────┘
                    │ 2. HumanReview   │            │
                    │ 3. HumanDecision │            ▼
                    │    (durable)     │     ┌─────────────┐
                    └────────┬─────────┘     │ AgentRuntime│
                             │               │ + Adapter   │
                             ▼               │ (OpenCode)  │
                    ┌─────────────┐          └──────┬──────┘
                    │   QA PHASE  │                 │
                    │             │                 ▼
                    │ 1. QAContract          ┌─────────────┐
                    │ 2. Evidence            │ Worker Pool │
                    │    Collection          │ (capability-│
                    │ 3. Gate Evaluation     │  matched)   │
                    │ 4. QAEvidence          └──────┬──────┘
                    │    (persisted)              │
                    └────────┬────────────────────┘
                             │
                             ▼
                    ┌─────────────┐
                    │  DEPLOY     │
                    │  PHASE      │
                    │             │
                    │ 1. Artifact │
                    │    Build    │
                    │ 2. Promote  │
                    │    (immut.) │
                    │ 3. Deploy   │
                    │    Target   │
                    └─────────────┘
```

## Detailed Phase Flows

### 1. Work Item Creation

```
POST /api/v1/products/{productId}/work-items
       │
       ▼
┌─────────────────────────────────────────┐
│ WorkflowEngine.validateTransition()     │
│   from: null                            │
│   to: WorkItemState.draft               │
│   guard: productExists, validCategory   │
└─────────────────────────────────────────┘
       │
       ▼
Persist WorkItem (state: draft)
       │
       ▼
Return WorkItem with generated ID
```

### 2. Design Phase

```
WorkItemState.draft
       │
       ▼
POST /api/v1/work-items/{id}/design
       │
       ▼
┌─────────────────────────────────────────┐
│ WorkflowEngine.validateTransition()     │
│   from: draft                           │
│   to: WorkItemState.design_in_review    │
│   guard: designContractProvided         │
└─────────────────────────────────────────┘
       │
       ▼
Persist DesignContract (linked to work item)
       │
       ▼
Notify reviewers (async)
       │
       ▼
HumanDecision submitted via dashboard
       │
       ▼
┌─────────────────────────────────────────┐
│ WorkflowEngine.validateTransition()     │
│   from: design_in_review                │
│   to: design_approved | design_rejected │
│   guard: decisionExists, validSignature │
└─────────────────────────────────────────┘
       │
       ▼
Persist HumanDecision (immutable, auditable)
       │
       ▼
If approved → Agent Phase
If rejected → Back to draft (with rationale)
```

### 3. Agent Phase

```
WorkItemState.design_approved
       │
       ▼
POST /api/v1/work-items/{id}/agent-session
       │
       ▼
┌─────────────────────────────────────────┐
│ WorkflowEngine.validateTransition()     │
│   from: design_approved                 │
│   to: WorkItemState.agent_executing     │
│   guard: agentAvailable, capabilitiesOK │
└─────────────────────────────────────────┘
       │
       ▼
AgentRuntime.startSession(workItem, designContract)
       │
       ▼
AgentAdapter (OpenCode) connects via ACP
       │
       ▼
Stream AgentEvent → WebSocket → Dashboard
       │
       ▼
Agent produces artifacts → WorkerPool (capability-matched)
       │
       ▼
Agent completes → AgentResult (structured)
       │
       ▼
┌─────────────────────────────────────────┐
│ WorkflowEngine.validateTransition()     │
│   from: agent_executing                 │
│   to: WorkItemState.agent_completed     │
│   guard: agentResultValid, artifactsOK  │
└─────────────────────────────────────────┘
       │
       ▼
Persist AgentResult (immutable)
       │
       ▼
→ QA Phase
```

### 4. QA Phase

```
WorkItemState.agent_completed
       │
       ▼
QAOrchestration.evaluate(workItem, agentResult)
       │
       ▼
For each required gate in QAContract:
       │
       ├─► Static Analysis Gate
       │     ├─► Dispatch to worker (linux + docker)
       │     ├─► Collect QAEvidence (report, artifacts)
       │     └─► Validate against thresholds
       │
       ├─► Test Coverage Gate
       │     ├─► Dispatch to worker (flutter + linux)
       │     ├─► Collect QAEvidence (coverage.json)
       │     └─► Validate against thresholds
       │
       ├─► Security Scan Gate
       │     ├─► Dispatch to worker (linux + docker)
       │     ├─► Collect QAEvidence (sarif, sbom)
       │     └─► Validate against thresholds
       │
       └─► Performance Gate (if applicable)
             ├─► Dispatch to worker (macos + ios)
             ├─► Collect QAEvidence (metrics, traces)
             └─► Validate against thresholds
       │
       ▼
All gates pass?
       │
       ├─Yes──► WorkItemState.qa_passed
       │
       └─No───► WorkItemState.qa_failed
                    │
                    ▼
             HumanDecision: waive | reject | rework
                    │
                    ▼
             If waive → qa_passed (with waiver record)
             If reject → agent_executing (with feedback)
             If rework → design_in_review
```

### 5. Deployment Phase

```
WorkItemState.qa_passed
       │
       ▼
DeploymentProtocol.buildArtifact(workItem, agentResult)
       │
       ▼
Creates DeploymentArtifact (content-addressed, immutable)
       │
       ▼
PromotionEngine.evaluate(artifact, DeploymentContract)
       │
       ▼
For each environment in promotion path:
       │
       ├─► Staging
       │     ├─► Deploy to Cloud Run (staging)
       │     ├─► Run smoke tests
       │     ├─► Collect DeploymentResult
       │     └─► Auto-promote if healthy
       │
       ├─► Production (requires HumanDecision)
       │     ├─► HumanApproval gate
       │     ├─► Deploy to Cloud Run (prod)
       │     ├─► Run production validation
       │     └─► Collect DeploymentResult
       │
       └─► Mobile (if applicable)
             ├─► Build iOS → TestFlight
             ├─► Build Android → Play Store (internal)
             └─► Collect DeploymentResult
       │
       ▼
All target deployments successful?
       │
       ├─Yes──► WorkItemState.deployed
       │
       └─No───► WorkItemState.deployment_failed
                    │
                    ▼
             Rollback | Retry | HumanDecision
```

## State Machine Definitions

### Product States
```
ProductState:
  - draft
  - active
  - archived
  - deprecated
```

### Work Item States (Sealed Class Hierarchy)
```
WorkItemState:
  ├─ Draft
  ├─ DesignInReview
  ├─ DesignApproved
  ├─ DesignRejected(reason: String)
  ├─ AgentExecuting(sessionId: String)
  ├─ AgentCompleted(result: AgentResult)
  ├─ AgentFailed(error: String, retryable: bool)
  ├─ QAInProgress(gates: List<QAGateStatus>)
  ├─ QAPassed(evidence: List<QAEvidence>)
  ├─ QAFailed(failures: List<QAGateFailure>, waiver: Waiver?)
  ├─ Deploying(targets: List<DeploymentTarget>)
  ├─ Deployed(results: List<DeploymentResult>)
  ├─ DeploymentFailed(failures: List<DeploymentFailure>)
  └─ Done
```

### Legal Transitions (Enforced by WorkflowEngine)

| From | To | Guard Condition |
|------|-----|-----------------|
| null | Draft | productExists |
| Draft | DesignInReview | designContractValid |
| DesignInReview | DesignApproved | humanDecisionExists ∧ approved |
| DesignInReview | DesignRejected | humanDecisionExists ∧ rejected |
| DesignRejected | Draft | always |
| DesignApproved | AgentExecuting | agentAvailable ∧ capabilitiesMatch |
| AgentExecuting | AgentCompleted | agentResultValid |
| AgentExecuting | AgentFailed | agentError ∧ (retryable → AgentExecuting) |
| AgentCompleted | QAInProgress | qaContractExists |
| QAInProgress | QAPassed | allGatesPass |
| QAInProgress | QAFailed | anyGateFailed |
| QAFailed | AgentExecuting | humanDecision=rework |
| QAFailed | QAPassed | humanDecision=waive (with record) |
| QAPassed | Deploying | artifactBuilt |
| Deploying | Deployed | allTargetsHealthy |
| Deploying | DeploymentFailed | anyTargetFailed |
| DeploymentFailed | Deploying | humanDecision=retry |
| Deployed | Done | always |

## Event Stream (AgentRuntime → Dashboard)

```
AgentEvent:
  ├─ SessionStarted(sessionId, workItemId)
  ├─ InstructionSent(instructionId, content)
  ├─ ToolCallStarted(toolCallId, tool, args)
  ├─ ToolCallCompleted(toolCallId, result)
  ├─ ToolCallFailed(toolCallId, error)
  ├─ ArtifactProduced(artifactId, type, path)
  ├─ LogLine(level, message, context)
  ├─ ProgressUpdate(percentage, description)
  ├─ SessionCompleted(result: AgentResult)
  ├─ SessionFailed(error: String, recoverable: bool)
  └─ SessionCancelled(reason: String)
```

## Persistence Model (Serverpod Tables)

```
ProductTable:
  id, manifest (JSON), created_at, updated_at

WorkItemTable:
  id, product_id, category, state (enum), 
  design_contract_id, agent_session_id, qa_contract_id,
  created_at, updated_at, completed_at

DesignContractTable:
  id, work_item_id, contract (JSON), reviewer_ids, status

HumanDecisionTable:
  id, workflow_id, decider, choice, rationale, 
  signature, timestamp, decision_type

AgentSessionTable:
  id, work_item_id, adapter_type, config (JSON), 
  state, started_at, completed_at, result (JSON)

AgentResultTable:
  id, session_id, artifacts (JSON), diagnostics (JSON), 
  structured_result (JSON), completed_at

QAGateTable:
  id, work_item_id, gate_type, status, evidence (JSON),
  evaluated_at, passed_at, waiver (JSON?)

QAEvidenceTable:
  id, gate_id, evidence_type, artifact_ref, content (JSON),
  collected_at, validator_id

DeploymentArtifactTable:
  id, work_item_id, content_hash, manifest (JSON), 
  built_at, builder_info

DeploymentRecordTable:
  id, artifact_id, environment, target, status, 
  deployed_at, result (JSON), rollback_of?
```

## Error Handling & Retry

| Scenario | Handling |
|----------|----------|
| Agent disconnect mid-session | `AgentSession.state = interrupted`; resume via `AgentRuntime.resume()` if adapter supports |
| Worker task timeout | Re-queue with exponential backoff; max 3 retries |
| QA gate flaky failure | Allow human waiver with rationale; record in `QAGate.waiver` |
| Deployment partial failure | Rollback completed targets; mark `DeploymentRecord.status = rolled_back` |
| Human decision expired | Escalate per AEF policy; auto-reject after configurable TTL |
| Database unavailable | Serverpod handles reconnection; in-flight transitions held in memory briefly |

## Concurrency Control

- **Optimistic locking** on `WorkItemTable` (version column)
- **Transition validation** re-checks guards at commit time
- **HumanDecision** uses compare-and-swap on workflow ID + decision type
- **AgentSession** single-writer per work item (enforced by service)

## Observability Hooks

Every transition emits:
```
TransitionEvent:
  workflowId, workItemId, fromState, toState, 
  trigger (human|agent|system|timer), timestamp, 
  guardEvaluations, durationMs
```

Consumed by:
- Dashboard real-time updates
- Audit log (immutable)
- Metrics (transition latency, failure rates)
- Alerting (stuck workflows, repeated failures)
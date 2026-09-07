# Component Boundaries

## Package Architecture

```
shipit-platform/
├── packages/
│   ├── platform_contracts/      # Core types, enums, JSON schemas (NO business logic)
│   ├── workflow_engine/         # State machine, transitions, validation
│   ├── agent_runtime/           # Provider interface + adapters
│   ├── worker_protocol/         # Capability model + task dispatch
│   ├── qa_orchestration/        # Gates + evidence validation
│   └── deployment_protocol/     # Artifact promotion + deployment interface
├── schemas/                     # JSON Schema (source of truth, generated into platform_contracts)
├── control_plane/               # Forthcoming: Serverpod server + Flutter Web client
├── docker/                      # Forthcoming
├── infrastructure/              # Forthcoming
└── tooling/                     # Generators, CI helpers (forthcoming)
```

## platform_contracts

**Single source of truth for all shared domain types.** `schemas/` JSON Schema files are
authoritative; Dart types are generated from them (`dart run build_runner`). This package
owns `WorkerCapability`, `WorkItemState`, `QAStatus`, `DeploymentPhase`, `QAContract`,
`QAEvidence`, `QAPassCriteria`, `DeploymentArtifact`, `DeploymentResult`, `AgentResult`,
`HumanDecision`, `DesignContract`, and every other cross-package type.

```
platform_contracts/
├── lib/
│   ├── src/
│   │   ├── enums/
│   │   │   ├── agent_session_status.dart
│   │   │   ├── deployment_status.dart
│   │   │   ├── qa_gate_status.dart
│   │   │   ├── work_item_category.dart
│   │   │   ├── worker_capability.dart
│   │   │   └── workflow_state.dart
│   │   └── types/
│   │       ├── agent_result.dart (+ .g.dart)
│   │       ├── deployment_artifact.dart (+ .g.dart)
│   │       ├── deployment_contract.dart (+ .g.dart)
│   │       ├── deployment_request.dart (+ .g.dart)
│   │       ├── deployment_result.dart (+ .g.dart)
│   │       ├── design_contract.dart (+ .g.dart)
│   │       ├── human_decision.dart (+ .g.dart)
│   │       ├── product_manifest.dart (+ .g.dart)
│   │       ├── qa_contract.dart (+ .g.dart)
│   │       ├── qa_evidence.dart (+ .g.dart)
│   │       ├── qa_pass_criteria.dart (+ .g.dart)
│   │       └── work_item.dart (+ .g.dart)
│   └── platform_contracts.dart   # Public exports
├── test/
│   └── serialization_test.dart
└── pubspec.yaml
```

**Owns:** All `@immutable` domain types, enums, JSON serialization, `WorkerCapability`
**Must Not:** Business logic, I/O, database access, agent/workflow/QA/deployment logic

---

## workflow_engine

**Pure state machine - no persistence, no agent knowledge.**

```
workflow_engine/
├── lib/
│   ├── src/
│   │   ├── states/
│   │   │   └── workflow_state.dart             # Sealed states + single allowedTransitions table
│   │   ├── transitions/
│   │   │   ├── work_item_transitions.dart      # WorkItemState legal transitions + guard map
│   │   │   ├── design_transitions.dart         # DesignContractStatus transitions
│   │   │   ├── qa_transitions.dart             # QAStatus transitions
│   │   │   └── deployment_transitions.dart     # DeploymentPhase transitions
│   │   ├── validation/
│   │   │   ├── transition_validator.dart
│   │   │   └── guard_conditions.dart
│   │   └── workflow_engine.dart                # Facade: transition*, validate*
│   └── workflow_engine.dart
├── test/
│   └── transition_test.dart
└── pubspec.yaml
```

**Owns:** `WorkflowState` (all four state machines), `Transition` validation, guard conditions
**Must Not:** Agent adapters, persistence, QA logic, deployment logic
**Source of state machine truth:** `docs/architecture/runtime-flow.md`; `allowedTransitions`
must stay in sync with `*_transitions.dart`.

---

## agent_runtime

**Provider-neutral interface. Adapters are plugins.**

```
agent_runtime/
├── lib/
│   ├── src/
│   │   ├── interface/
│   │   │   ├── agent_session.dart
│   │   │   ├── agent_adapter.dart
│   │   │   ├── agent_event.dart
│   │   │   ├── agent_instruction.dart
│   │   │   └── agent_capability.dart
│   │   ├── adapters/
│   │   │   ├── agent_adapter_registry.dart
│   │   │   └── opencode/
│   │   │       └── opencode_adapter.dart       # OpencodeClient + OpencodeSession
│   │   ├── models/
│   │   │   └── agent_session_state.dart
│   │   └── agent_runtime.dart                  # Facade + AgentAdapterRegistry
│   └── agent_runtime.dart
├── test/
│   └── agent_runtime_test.dart
└── pubspec.yaml
```

**Owns:** `AgentSession` interface, `AgentAdapter` contract, adapter registry, `AgentRuntime` facade
**Must Not:** Workflow logic, QA logic, deployment logic, persistence

---

## worker_protocol

**Capability-based task dispatch. Workers are dumb executors.**

```
worker_protocol/
├── lib/
│   ├── src/
│   │   ├── capabilities/
│   │   │   ├── capability_spec.dart            # WorkerCapability + CapabilitySpec (enum owned by platform_contracts)
│   │   │   ├── capability_requirements.dart
│   │   │   └── capability_matcher.dart
│   │   ├── dispatch/
│   │   │   └── task_dispatch.dart              # TaskDispatch, TaskResult, TaskStatus,
│   │   │                                       # WorkerArtifact, DispatchStrategy
│   │   ├── worker/
│   │   │   ├── worker_registration.dart
│   │   │   ├── worker_heartbeat.dart
│   │   │   └── worker_status.dart
│   │   └── worker_protocol.dart                # Facade: find + select workers
│   └── worker_protocol.dart
├── test/
│   └── capability_matcher_test.dart
└── pubspec.yaml
```

**Owns:** capability matching, task dispatch data model, `WorkerProtocol` facade, worker model
**Consumes (does not own):** `WorkerCapability` enum from `platform_contracts`
**Must Not:** Agent runtime, workflow engine, QA logic, persistence

---

## qa_orchestration

**Evidence validation. Independent of agent opinion.**

```
qa_orchestration/
├── lib/
│   ├── src/
│   │   ├── gates/
│   │   │   ├── gate_registry.dart
│   │   │   ├── gate_evaluator.dart
│   │   │   └── predefined/
│   │   │       ├── static_analysis_gate.dart
│   │   │       ├── test_coverage_gate.dart
│   │   │       ├── security_scan_gate.dart
│   │   │       └── performance_gate.dart
│   │   ├── evidence/
│   │   │   └── evidence_collector.dart         # Interface (QAEvidence owned by platform_contracts)
│   │   └── qa_orchestration.dart               # QAOrchestration facade
│   └── qa_orchestration.dart
├── test/
│   └── qa_orchestration_test.dart
└── pubspec.yaml
```

**Owns:** `QAGate` implementations, `GateRegistry`, `GateEvaluator`, gate results
**Consumes (does not own):** `QAContract`, `QAEvidence`, `QAGateResult`, `QAGateStatus` from `platform_contracts`
**Must Not:** Agent runtime, deployment logic, workflow engine (only consumes state)

---

## deployment_protocol

**Immutable artifact promotion across environments.**

```
deployment_protocol/
├── lib/
│   ├── src/
│   │   ├── artifacts/
│   │   │   └── artifact_store.dart             # Interface
│   │   ├── promotion/
│   │   │   └── promotion_rule.dart             # PromotionRule, PromotionEngine, DeploymentRecord,
│   │   │                                       # PromotionResult, PromotionRecord, PromotionStatus
│   │   ├── targets/
│   │   │   └── deployment_target.dart          # DeploymentTarget interface + DeploymentConfig
│   │   └── deployment_protocol.dart            # Facade: buildArtifact (sha256), evaluatePromotion
│   └── deployment_protocol.dart
├── test/
│   └── deployment_protocol_test.dart
└── pubspec.yaml
```

**Owns:** `ArtifactStore` interface, `PromotionEngine` + promotion data model, `DeploymentTarget` interface
**Consumes (does not own):** `DeploymentArtifact`, `DeploymentResult`, `ArtifactManifest`, `HealthCheckResult`,
`DeploymentStatus` from `platform_contracts`
**Must Not:** Workflow logic, agent runtime, QA logic, concrete cloud/ad-hoc target implementations
(concrete targets ship with `control_plane/server` once deployment is implemented)

---

## control_plane/server (Serverpod) — forthcoming

**Persistence, API, orchestration coordination.** Not yet created; planned layout:

```
control_plane/server/
├── lib/src/
│   ├── endpoints/        # product, work_item, design, agent, qa, deployment
│   ├── persistence/      # tables, repositories, migrations (PostgreSQL)
│   ├── services/         # workflow_service, agent_service, worker_service, qa_service, deployment_service
│   └── server.dart
└── test/integration/
```

---

## control_plane/client (Flutter Web) — forthcoming

**Human-facing dashboard.** Not yet created; planned layout leaves pages/ under `lib/src/pages/`
and frontend tests under `test/`.

---

## Cross-Package Dependencies (Allowed)

```
platform_contracts ◄── workflow_engine
platform_contracts ◄── agent_runtime
platform_contracts ◄── worker_protocol
platform_contracts ◄── qa_orchestration
platform_contracts ◄── deployment_protocol

workflow_engine ◄── control_plane/server (services)      (forthcoming)
agent_runtime   ◄── control_plane/server (agent_service) (forthcoming)
worker_protocol ◄── control_plane/server (worker_service)(forthcoming)
qa_orchestration◄── control_plane/server (qa_service)    (forthcoming)
deployment_protocol◄─ control_plane/server (deployment_service) (forthcoming)
```

## Forbidden Dependencies

- ❌ `workflow_engine` → `agent_runtime` / `worker_protocol` / `qa_orchestration` / `deployment_protocol`
- ❌ `agent_runtime` → `workflow_engine` / `qa_orchestration` / `deployment_protocol` / `worker_protocol`
- ❌ `qa_orchestration` → `agent_runtime` / `deployment_protocol` / `workflow_engine` / `worker_protocol`
- ❌ `deployment_protocol` → `workflow_engine` / `agent_runtime` / `qa_orchestration` / `worker_protocol`
- ❌ Any package → `control_plane/server` (except via interfaces)
- ❌ Direct PostgreSQL access outside `control_plane/server`
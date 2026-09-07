# System Context

## Overview

ShipIt Platform is the **execution runtime** for the Agentic Engineering Framework (AEF). It sits between governance (AEF) and infrastructure, providing deterministic orchestration of the software delivery lifecycle.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AGENTIC ENGINEERING FRAMEWORK (AEF)         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │ Governance  │  │ Contracts   │  │ Policies    │  │ Standards │  │
│  │ Rules       │  │ (JSON Schema)│  │ (Approval,  │  │ (Coding,  │  │
│  │             │  │             │  │  Quality,   │  │  Security)│  │
│  │             │  │             │  │  Security)  │  │           │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │
└─────────┼────────────────┼────────────────┼──────────────┼────────┘
          │                │                │              │
          ▼                ▼                ▼              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        SHIPIT PLATFORM                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │  Workflow   │  │   Agent     │  │   Worker    │  │    QA     │  │
│  │  Engine     │  │  Runtime    │  │  Protocol   │  │Orchestration│ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │
│         │                │                │              │         │
│  ┌──────┴────────────────┴────────────────┴──────────────┴─────┐  │
│  │                   CONTROL PLANE (Serverpod + Flutter Web)    │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │  │
│  │  │   API       │  │   Dashboard │  │  Persistence│          │  │
│  │  │   Gateway   │  │   (Human)   │  │  (PostgreSQL)│         │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘          │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AGENT         │    │   WORKER        │    │   INFRASTRUCTURE│
│   PROVIDERS     │    │   POOLS         │    │   (OpenTofu)    │
│                 │    │                 │    │                 │
│ • OpenCode ACP  │    │ • Linux (Docker)│    │ • VPC, DB, K8s  │
│ • Future:       │    │ • macOS (Metal) │    │ • Secrets, DNS  │
│   Claude Code,  │    │ • iOS (Xcode)   │    │ • Certificates  │
│   Cursor, etc.  │    │ • Android       │    │ • CDN, WAF      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## External Actors

| Actor | Interaction |
|-------|-------------|
| **Product Owner** | Defines products, work items, priorities via dashboard |
| **Engineer** | Reviews/approves designs, human decisions, deployments |
| **QA Engineer** | Configures gates, reviews evidence, signs off |
| **Platform Engineer** | Manages worker pools, infrastructure, agent adapters |
| **Agent (OpenCode)** | Executes work items, produces artifacts, streams events |
| **Worker (Linux/macOS)** | Runs builds, tests, device farms, produces evidence |

## System Boundaries

### AEF → ShipIt Platform (Contracts Only)
AEF publishes **machine-readable contracts** that ShipIt Platform consumes:
- `ProductManifest` schema - product structure, capabilities, environments
- `WorkItem` schema - work item types, states, transitions, required evidence
- `DesignContract` schema - design deliverables, review criteria
- `QAContract` schema - gate definitions, evidence types, pass criteria
- `DeploymentContract` schema - promotion rules, environment configs

ShipIt Platform **must not** interpret or duplicate policy logic. It only enforces transitions defined in contracts.

### ShipIt Platform → Agent Providers (Provider-Neutral)
The `agent_runtime` package defines a **provider-neutral interface**:
- `AgentSession` - start, send instruction, stream events, cancel, resume
- `AgentAdapter` - pluggable implementations (OpenCode ACP, future: Claude Code, Cursor)
- `AgentResult` - structured final output (artifacts, diagnostics, structured result)
- Agent conversations are **ephemeral**; only `AgentResult` is persisted

### ShipIt Platform → Workers (Capability-Based)
The `worker_protocol` package defines:
- `WorkerCapability` enum - `linux`, `docker`, `flutter`, `android`, `macos`, `ios`, `xcode`
- `TaskDispatch` - capability-matched task assignment, timeout, retry
- `WorkerHeartbeat` - health, capacity, artifact cache status
- Workers are **dumb executors**; orchestration logic lives in platform

### ShipIt Platform → Infrastructure (Declarative)
- **Local**: Docker Compose (`docker/`) - PostgreSQL, Serverpod, mock workers
- **Production**: OpenTofu (`infrastructure/`) - VPC, RDS, Cloud Run, Cloud Build, Artifact Registry
- **Contracts shared** - Same `schemas/` consumed in all environments
- **Infrastructure differs** - Local uses mocks; prod uses managed services

## Data Flow Summary

```
ProductManifest (AEF)
       │
       ▼
Work Item Created (Control Plane API)
       │
       ▼
Workflow Engine: Legal Transitions Only
       │
       ├─► Design Phase → DesignContract → HumanDecision (durable)
       │
       ├─► Agent Phase → AgentRuntime → AgentAdapter (OpenCode) → AgentResult
       │                      │
       │                      └─► WorkerProtocol → Worker Pool (capability-matched)
       │
       ├─► QA Phase → QAOrchestration → QAContract → QAEvidence (independent)
       │
       └─► Deploy Phase → DeploymentProtocol → Immutable Artifact → Environments
```

## Non-Goals (Explicit)

- ❌ Kubernetes operator / custom controller
- ❌ Custom CI/CD engine (uses GitHub Actions for execution)
- ❌ Multi-cloud abstraction layer
- ❌ Model routing / LLM gateway
- ❌ Local LLM hosting
- ❌ Authentication/authorization (delegated to infrastructure layer)
- ❌ Queue infrastructure (uses Serverpod + PostgreSQL for now)
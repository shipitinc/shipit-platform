# ShipIt Platform

**The executable runtime and control plane for the Agentic Engineering Framework (AEF).**

## What This Repository Owns

ShipIt Platform is the **runtime execution layer** that implements AEF governance deterministically. It owns:

- **Workflow Engine** - Legal state transitions for products, work items, designs, QA, deployments
- **Control Plane Backend** - Serverpod-based API, PostgreSQL persistence, agent orchestration
- **Control Plane Frontend** - Flutter Web dashboard for human decisions, monitoring, approvals
- **Agent Runtime** - Provider-neutral interface (OpenCode ACP first, others pluggable)
- **Worker Protocol** - Linux/macOS/iOS worker capability model and task dispatch
- **QA Orchestration** - Evidence collection, validation gates, independent of agent opinion
- **Deployment Protocol** - Immutable artifact promotion across environments
- **Local Development** - Docker Compose for full-stack local runs
- **Infrastructure as Code** - OpenTofu modules for production infrastructure

## What AEF Owns (Authoritative Governance)

AEF remains the **single source of truth** for policy. ShipIt Platform must not duplicate:

- **Governance Rules** - Workflow definitions, approval gates, quality standards
- **Product/Work Item Taxonomy** - Canonical definitions, status enums, transition rules
- **Role Definitions** - Who can approve what, escalation paths
- **Compliance Requirements** - Audit trails, evidence requirements, retention
- **Agent Behavior Contracts** - What agents may/must do, tool access policies
- **Release Criteria** - Definition of done, promotion thresholds

AEF publishes these as **machine-readable contracts** (JSON schemas, OpenAPI) that ShipIt Platform consumes.

## What shipit-ui Owns

A separate repository for **reusable Flutter Web UI components** consumed by the control plane frontend:

- Design system components (tokens, theming, accessibility)
- Workflow visualization widgets (state machines, timelines, graphs)
- Agent conversation viewers
- QA evidence browsers
- Deployment pipeline views
- Human decision forms and modals

ShipIt Platform's control plane frontend **depends on** shipit-ui as a package dependency.

## What shipit-golden-app Owns

A separate repository serving as the **reference implementation** and integration test bed:

- A real Flutter/Dart application with known-good structure
- Exercises the full ShipIt Platform lifecycle: design → agent → QA → deploy
- Validates worker capability matrix (Linux, macOS, iOS)
- Serves as the "golden path" for new product onboarding
- Regression target for platform upgrades

## Repository Structure

```
shipit-platform/
├── README.md                    # This file
├── AGENTS.md                    # Repository-specific development rules
├── pubspec.yaml                 # Root workspace manifest (dart pub workspaces)
├── docs/
│   ├── architecture/            # System architecture documentation
│   └── adr/                     # Architecture Decision Records
├── schemas/                     # JSON Schema contracts (consumed by AEF)
└── packages/                    # Dart workspace packages
    ├── platform_contracts/      # Core domain types, enums, contracts
    ├── workflow_engine/         # State machine, transitions, validation
    ├── agent_runtime/           # Provider-neutral agent interface
    ├── worker_protocol/         # Worker capabilities, task dispatch
    ├── qa_orchestration/        # QA gates, evidence, validation
    └── deployment_protocol/     # Artifact promotion, deployments
```

Components below are forthcoming (not yet in this repository):

- `control_plane/` - Serverpod backend + Flutter Web frontend
- `docker/` - Docker Compose for local development
- `infrastructure/` - OpenTofu modules for production
- `tooling/` - Scripts, generators, CI helpers

## Getting Started

```bash
# Resolve the whole workspace
dart pub get

# Run analysis in all packages
melos run analyze

# Run tests in all packages
melos run test

# Check formatting in all packages
melos run format
```

## Principles

1. **AEF remains authoritative** - Platform implements, never duplicates policy
2. **Deterministic state transitions** - No arbitrary string-based workflow state
3. **Persisted important state** - Agent conversations are not system state
4. **Durable human decisions** - Decisions are resumable, auditable
5. **Replaceable agent providers** - OpenCode is first adapter, not hard dependency
6. **Independent QA evidence** - Never trust agent self-assessment
7. **No production authority for agents** - Humans gate production
8. **Shared contracts, flexible infrastructure** - Local/staging/prod share contracts
9. **No Kubernetes, no custom CI, no multi-cloud prematurely**
10. **Single repository until concrete reason to split**

## License

Proprietary - Internal Use Only
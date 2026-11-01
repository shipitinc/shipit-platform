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
├── apps/                        # Application runnables
│   ├── server/                  # Control plane API (Serverpod + PostgreSQL persistence)
│   └── control_plane/           # Control plane operator UI (Flutter Web)
└── packages/                    # Dart workspace packages (shared libraries)
    ├── platform_contracts/      # Core domain types, enums, contracts
    ├── workflow_engine/         # State machine, transitions, validation
    ├── agent_runtime/           # Provider-neutral agent interface
    ├── worker_protocol/         # Worker capabilities, task dispatch
    ├── qa_orchestration/        # QA gates, evidence, validation
    ├── deployment_protocol/     # Artifact promotion, deployments
    └── control_plane_client/    # Generated Serverpod protocol client
```

Components below are forthcoming (not yet in this repository):

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

## Environment & Credentials

Local stacks take environment from **two distinct files, on two distinct
mechanisms** — mixing them up is the documented way variables silently never
arrive:

- **`docker/.env`** (gitignored, machine-local; template: `docker/.env.example`) —
  the Compose *project-directory* env file. Compose interpolates
  `"${VAR:-...}"` expressions in `docker/compose.*.yaml` from it. Per-stack
  credentials and host paths live here.
- **`.env`** at the repository root (gitignored; template: `.env.example`) —
  loaded into containers verbatim via `env_file:` and shared by every stack.
  `environment:` overrides `env_file:` per key, so a variable a service also
  interpolates must be set in `docker/.env`, not here.

**Provider API keys** (e.g. the OpenRouter paid tier for the opencode agent
runtime) are plain process environment variables: `OPENROUTER_API_KEY` is the
name opencode itself resolves, and `OPENCODE_OPENROUTER_API_KEY` is the
platform-prefixed twin (`OPENCODE_<PROVIDER>_API_KEY`). Both `environment:`
entries in `docker/compose.qa.yaml` interpolate them from `docker/.env`, and
both the dispatch transport and the provider health probe spawn `opencode`
with `includeParentEnvironment: true`, so a container env var reaches
opencode unmediated. In production the same names are injected by the
environment's secret management — per `AGENTS.md` §13a credentials are
referenced by name and the value never enters a committed file.

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
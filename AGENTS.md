# AGENTS.md - ShipIt Platform Development Rules

## Repository-Specific Rules

### 1. Architecture Boundaries

- **Never duplicate AEF policy** - Consume contracts from `schemas/` and `packages/platform_contracts`
- **No arbitrary string workflow state** - Use `WorkflowState` enum and `Transition` validation in `workflow_engine`
- **Agent conversations ≠ system state** - Persist only `AgentResult`, `HumanDecision`, `QAEvidence`
- **Provider-neutral agent code** - All agent-specific logic in `agent_runtime` adapters, never in workflow engine

### 2. Dart Conventions

- **Native Dart workspace** - Managed via root `pubspec.yaml` `workspace:` list (`dart pub workspaces`), orchestrated with `melos`; no custom build scripts
- **Strong typing** - Prefer sealed classes, enums, records over dynamic/maps
- **Immutability** - Domain objects are `@immutable` with `freezed` or manual copyWith
- **Serialization** - `json_serializable` for all contract types; schemas in `schemas/` are source of truth
- **Null safety** - Strict, no `!` or `late` without justification

### 3. Package Boundaries

| Package | Owns | Must Not |
|---------|------|----------|
| `platform_contracts` | Core types, enums, JSON schemas | Business logic, I/O |
| `workflow_engine` | State machine, transitions, validation | Agent details, persistence |
| `workflow_store` | Durable WorkItem/HumanDecision/history persistence, resume, CAS, idempotency | Workflow policy, agent details, DB beyond its own store |
| `agent_runtime` | Provider interface, adapters | Workflow logic, QA logic |
| `worker_protocol` | Capability model, task dispatch | Agent runtime, workflow |
| `qa_orchestration` | Gates, evidence, validation | Agent runtime, deployment |
| `deployment_protocol` | Artifact promotion, deployments | Workflow logic, agent runtime |
| `execution_coordinator` | One bounded, durable agent execution; role stamping; independent verification; orphan reconciliation | Provider specifics, workflow policy, agents choosing their own role |
| `worker_runtime` | Worker selection/lease, worktree isolation pinned to a revision, worker lifecycle + cleanup policy, stranding recovery | Workflow policy, provider specifics, creating worktrees in `agent_runtime`, deleting anything without `WorkspaceDescriptor` ownership |
| `scheduler` | Durable job queue (dedupe/claim-CAS/lease reconciliation), tick loop, capacity-aware dispatch, single-selector orchestration | Workflow policy itself, provider specifics, mutating `WorkItem` state directly |

### 4. Testing Requirements

- **Unit tests** for all domain logic (transitions, validation, serialization)
- **Contract tests** - Schema compliance for all serialized types
- **Integration tests** - Only for cross-package flows in `control_plane/server/test`
- **No UI tests** in packages - Frontend tests in `control_plane/client/test`

### 5. Code Generation

- Run `dart run build_runner build --delete-conflicting-outputs` after schema/type changes
- Commit generated files (`.g.dart`, `.freezed.dart`)
- Schemas in `schemas/` are authoritative - Dart types generated from them

### 6. Git Workflow

- **Trunk-based development** - Short-lived branches, frequent merges
- **Conventional commits** - `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- **No direct pushes to main** - PR required, CI must pass
- **ADR required** for architectural decisions (see `docs/adr/`)

### 7. Local Development

```bash
# Resolve the whole workspace
dart pub get

# Run analysis in all packages
melos run analyze

# Run tests in all packages
melos run test

# Check formatting in all packages
melos run format

# Apply formatting in all packages
melos run format:apply

# Analyze or test a single package
cd packages/workflow_engine && dart analyze && dart test

# Regenerate serialization code (platform_contracts only)
cd packages/platform_contracts && dart run build_runner build --delete-conflicting-outputs
```

### 8. Forbidden Patterns

- ❌ `Map<String, dynamic>` for domain objects
- ❌ Stringly-typed workflow status (`"in_progress"`, `"done"`)
- ❌ Agent-specific imports in `workflow_engine`, `qa_orchestration`
- ❌ Direct database access outside `control_plane/server`
- ❌ Hardcoded OpenCode logic outside `agent_runtime/adapters/opencode`
- ❌ Kubernetes configs, custom CI engines, multi-cloud abstractions

### 9. Adding New Packages

1. Create under `packages/` with `pubspec.yaml`
2. Add to workspace in root `pubspec.yaml`
3. Define public API in `lib/src/` with `export 'src/...'` in `lib/<package>.dart`
4. Add tests in `test/`
5. Update this AGENTS.md if new boundary rules needed

### 10. Schema Evolution

- **Breaking changes** require new schema version + ADR
- **Additive changes** (optional fields) allowed without version bump
- **Never remove fields** - deprecate in Dart, keep in schema
- Validate all changes against `schemas/` JSON Schema files

### 11. Human Decision Durability

- All `HumanDecision` objects must survive process restarts
- Store in PostgreSQL via Serverpod, never in-memory only
- Include: `decisionId`, `workflowId`, `decider`, `choice`, `rationale`, `timestamp`, `signature`

### 12. QA Evidence Independence

- QA evidence collected by `qa_orchestration` workers, not agents
- Agents may *produce* artifacts; workers *validate* them
- `QAContract` defines required evidence types per work item category

---

## Quick Reference: Where Things Go

| Task | Location |
|------|----------|
| New workflow state | `packages/workflow_engine/lib/src/states/` |
| New transition rule | `packages/workflow_engine/lib/src/transitions/` |
| WorkItem/decision persistence | `packages/workflow_store/lib/src/store/` (interface) + `packages/workflow_store/lib/src/durable_workflow_engine.dart` |
| New agent adapter | `packages/agent_runtime/lib/src/adapters/` |
| New worker capability | `packages/worker_protocol/lib/src/capabilities/` |
| New worker (lease/worktree/lifecycle) | `packages/worker_runtime/lib/src/` |
| New job queue/claim-CAS/tick logic | `packages/scheduler/lib/src/` |
| New QA gate | `packages/qa_orchestration/lib/src/gates/` |
| New deployment target | `packages/deployment_protocol/lib/src/targets/` |
| New domain type | `packages/platform_contracts/lib/src/types/` |
| New JSON schema | `schemas/` + regenerate Dart types |
| Backend API endpoint | `control_plane/server/lib/src/endpoints/` |
| Frontend page | `control_plane/client/lib/src/pages/` |
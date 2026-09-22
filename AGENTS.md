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

**Repository layout:** application runnables live under `apps/` (`server`, `control_plane`); shared library packages live under `packages/` (including `control_plane_client`). Platform code must never import from `apps/`; app code imports platform contracts from `packages/`.

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
| `apps/server` (persistence) | PostgreSQL-backed implementations of the store contracts (`workflow`, `job`, `worker`, `worker_registration`, `execution`), migration/DML for them, `StructuredLogger`, and read-only Serverpod endpoints observing durable state | Domain/policy logic (stays in the platform `packages/`), ever setting `WorkItem.state` from an endpoint, dictating scheduler policy |
| `control_plane_client` | Generated Serverpod protocol client (pure Dart, committed, regenerates via `serverpod_cli generate`) | Manual edits; business logic |

### 4. Testing Requirements

- **Unit tests** for all domain logic (transitions, validation, serialization)
- **Contract tests** - Schema compliance for all serialized types
- **Integration tests** - Only for cross-package flows in `apps/server/test`
- **No UI tests** in packages - Frontend tests in `apps/control_plane/test`

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
- ❌ Direct database access outside `apps/server`
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

### 13. Penpot / Tooling Credentials (shared cross-repo convention)
- **Headless RPC surface (real, registry-grounded):** apis.io documents Penpot's
  RPC-style REST base `https://design.penpot.app/api/rpc/command/<command>` with
  `Authorization: Token <pat>` and project/file commands that are
  profile-wide (they do NOT require an open file). This is the sanctioned
  headless "bootstrap from nothing" path (project/file creation); the
  `design.penpot.app` `…/api/rpc/command/get-profile` command is the documented
  identity-verify probe. The MCP plugin surface (`penpot.execute_code`, token
  bound to an open file) remains valid only under an open-file session and is
  NOT the bootstrap path.
- **Know your credential before acting:** a 403/405/433 from a guessed RPC path
  with a real token is *not* proof the credential is broken — it is proof the
  claimed scope is UNVERIFIED. Only re-probe the documented `get-profile`
  command against the exact team/workspace a human names; never self-approve
  "token opens X" (that is a fact about a validated credential; §8
  no-fabrication + §19 HUMAN_GATES apply headlessly too).

One **role-scoped service-profile token** covers all shipit-platform products;

never a token per project.

> **Scope of this rule:** it governs **Penpot and tooling credentials**. It does
> **not** govern git credentials — see §13a and ADR 0018.

- **Mechanism:** a Penpot token is bound to a *profile* (the `User`), and
  access is granted through that profile's **memberships + roles** per
  workspace — not by minting a separate token per file/project. So products
  share the single token; separation comes from role-scoping, never from
  spreading more secret values.
- **Recommended token owner:** a dedicated service profile (e.g.
  `shipit platform bot`), not a human's personal token — so rotation and
  revocation happen centrally without coupling to one person.
- **Referenced by name, never by value.** Repos and scripts hold only the
  reference name `PENPOT_SHIPIT_PLATFORM_TOKEN`. The secret value lives in a
  gitignored local secret store (macOS Keychain / `~/.config/shipit/platform/`
  chmod 600), injected by a secret manager (CI org-secret) when automation
  runs there.
- **Never:** the token value in git, commit messages, logs, goldens, plugin
  output, or this file. Fabricating a workspace/file/project is prohibited —
  it is **not** approved design, only structure; see `HUMAN_DESIGN_APPROVAL_REQUIRED`.
- **Verify before acting:** only run headless Penpot bootstrap after the
  token opens exactly the expected workspace(s). "A profile can create a
  workspace" is a fact about a *validated credential*, never assumed.
  If Penpot is not connected this session, do not fabricate the connection;
  stop at the human gate below.
- **Human gate:** `HUMAN_DESIGN_APPROVAL_REQUIRED` — connect the bot profile
  + workspace in Penpot and human-approve the design before generating UI.

### 13a. Git Credentials Are Per Product (carve-out from §13)

See **ADR 0018**. §13's one-token rule does **not** apply to git.

- **Why the difference:** Penpot access is granted through one profile's
  *memberships + roles* per workspace, so one token carries many scoped grants.
  Git has no such indirection — the provider-native mechanism for scoping access
  to a single repository **is** a per-repository key (deploy key). A single
  shared git key would mean standing write on every product repo held in one
  secret.
- **One `ed25519` keypair per repository** (ADR 0018 A1 — a Product may own
  several repositories, and providers forbid reusing a deploy key across repos
  in one org). Generated locally by ShipIt. The private half lives in the local
  secret store and is never displayed, logged, persisted to the durable record,
  or transmitted. Only the **public** half is surfaced, for the operator to
  install as a deploy key.
- **Referenced by name, never by value** — §13's core rule still holds. The
  record stores `GIT_PRODUCT_<productRef>_<repoRef>_SSH` plus the public key
  fingerprint. `RepositoryCredential` has no private-key field and never may.
- **Host keys are trust-on-first-use with explicit human confirmation.** ShipIt
  refuses to connect to an unrecognised host and never claims to have verified
  a host it cannot verify.
- **Access is proven, not assumed.** A product cannot be registered until a
  connectivity check has succeeded against the real host with the real key. The
  result is stored with a timestamp and shown as a fact.
- **SSH only.** Personal access tokens differ per provider in scope model,
  granularity, expiry and creation flow, and do not exist on many self-hosted
  hosts. SSH is the only portable mechanism.

### 13b. Where Human Gates Belong

Per **ADR 0012** — *"human gates only where required (production)"* — and
**ADR 0013**, where entering a gate **terminates execution** until a human
resolves it.

- **Not gated:** pushing to a product's repository, and merging. These are
  reversible, attributable, and sit inside agent/CI iteration loops. Gating them
  would terminate execution mid-loop, which ADR 0013's gate semantics make
  actively harmful.
- **Gated:** promotion to production (ADR 0012), baseline approval, product
  pause/offboard, and clarifications.
- **Standing policy authorisations** (ADR 0019) let one signed decision
  authorise a class of future actions. Each action cites the authorising
  decision in the durable record; revoking the policy is itself a recorded
  decision. Fluidity without losing attribution.

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
| Backend API endpoint | `apps/server/lib/src/endpoints/` |
| Frontend page | `apps/control_plane/lib/features/` (one dir per feature) |
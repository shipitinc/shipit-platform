# AGENTS.md — Product Repository (instantiated from framework)

<!--
  PLACEHOLDER TEMPLATE.
  This is instantiated into a PRODUCT repository from the canonical framework.
  Fill in product-specific values. Do NOT depend on the framework repo at runtime.
  Record the producing framework version in this product repo's `framework-manifest.yaml`.
-->

This product repository is governed by a **versioned copy** of the agentic engineering framework.

## Inherited invariants (from framework)
- One authoritative Engineering Manager / Orchestrator per active workflow.
- Specialists do not independently advance lifecycle state.
- Implementers never approve their own work; independent reviewers are read-only.
- Production-writing agents declare `OWNED_PATHS`, `READ_ONLY_PATHS`, `PROHIBITED_PATHS`;
  concurrent writers cannot have overlapping ownership.
- Required deterministic validation must pass before success is claimed.
- Runtime/browser evidence must correspond to the exact code revision under review.
- Human intervention is reserved for consequential decisions (product, architecture, design,
  security, infrastructure, destructive operations, deployment authority).
- Production promotion is human-authorized unless a human-approved project policy changes that.

## Orchestration

The top-level session is the **Engineering Manager / Orchestrator**. It **dispatches** work to
specialist subagents and integrates only independently reviewed results; it does not normally
implement production source itself. This is operationalized by the `aef-orchestrator` skill
which is the executable counterpart of the invariants above. It reuses the
existing lane skills (`aef-design-workflow`, `aef-design-review`, `aef-qa-contract`,
`aef-qa-execution`, `aef-implementation-workflow`, `aef-independent-review`, `aef-correction-loop`,
`aef-deployment-execution`, `aef-human-decision`, `aef-repository-learning`) and adds no lifecycle
stage and no human gate.

Dispatch uses the mandatory header in the `aef-orchestrator` skill § 4, rendered from
`.agents/skills/aef-orchestrator/templates/subtask-prompt.md`; results are returned per
`.agents/skills/aef-orchestrator/templates/subtask-report.md`. The lane skills themselves live under
`.agents/skills/aef-<skill-name>/SKILL.md`. `docs/engineering/WORKFLOW.md` and
`docs/engineering/STRUCTURED_RESULTS.md` remain authoritative
wherever the skill and those documents differ.

`.agents/` is the **canonical source of truth**. The `.claude/`, `.junie/`, and `.opencode/`
directories hold **generated** platform adapters rendered from it; they are never hand-maintained
content and must not be edited — change the canonical artifact under `.agents/` and regenerate. See
`docs/engineering/adr/0003-product-generic-orchestrator-skill.md` § Platform matrix and generated
adapters.

**That no-hand-editing rule is advisory in this repository.** The generator
(`cli/tool/generate_platform_adapters.dart`) and its `--check` drift test
(`cli/test/platform_adapter_test.dart`) are framework-repository tooling and are **not** instantiated
here, so nothing mechanically fails if a generated adapter is hand-edited — upholding the rule is the
human's job in a product repository. The rule is mechanically enforced **only** in the framework
repository itself, which owns the generator and the drift test. The ownership scope is the generated
subtrees only: `.opencode/agents/` and `.opencode/command/` are generated, while the rest of
`.opencode/` (`node_modules/`, `package.json`, `package-lock.json`, `.gitignore`) belongs to opencode
at runtime and is not generated content.

## Product-specific policy (fill in)
- Required validation gates: TBD
- Environments & deployment strategy: TBD
- Path ownership map: TBD
- Orchestration conventions (see `aef-orchestrator` skill § 3 — override the defaults for every
  convention your project does not want defaulted): TBD

### Test resource hygiene

Human-mandated rule: **every test database, container, volume and compose project created for
testing is removed when the run finishes — on success, on failure and on interrupt alike.** It is
enforced by tooling, not by discipline.

- Any script, `Makefile` target or workflow step that creates test infrastructure must remove it
  before returning. In shell, that means a `trap ... EXIT INT TERM`; in Docker Compose, `down -v`
  (never `stop`) under a named project so the removal cannot hit someone else's stack.
- Cleanup must be unconditional and must not change the verdict the run already reached — but a
  teardown that FAILS is the leak this rule exists to prevent, so never discard its output. Print
  what `down` said on failure and, where possible, the exact command to finish the job. Silencing a
  teardown with `> /dev/null 2>&1 || true` turns a leaked container into a silent pass; that mistake
  shipped here once already.
- A cleanup `trap` runs after the recipe has `cd`-ed, so it must resolve paths absolutely (from the
  Makefile's own location), never relative to the current directory.
- A workflow that creates no compose project has no teardown step to write. The `Integration` job's
  database is its `postgres` service container, which the Actions runner removes itself; the previous
  `Teardown test resources` step there silenced its exit code with `|| true` while `-p shipit_test`
  named a stack a developer also uses, so it was removed rather than repaired.
- A long-lived developer database is not a test resource, but a test run must never target one that
  someone else owns. Anything a run creates is its own; point it at a throwaway instance.
- The current sites: `make test-integration` (disposable Postgres, self-cleaning), and
  `make test-env-test` and `make e2e-test` (both trap a `down -v`). Each trap reports CLEANUP FAILED
  only when a labelled container, volume or network for its project actually exists, so a compose file
  that cannot be parsed never produces a false leak report.
- `make clean` is a **disarmed safety stub and removes nothing**. It used to run
  `docker compose -f docker/compose.*.yaml down -v` against all three compose files — but none of them
  declares a top-level `name:`, so they all resolve to the SAME project (`docker`, named after the
  directory), which is the live QA stack's project. Those `down -v` lines destroyed `docker_postgres_data_qa`
  once already, irrecoverably, when an agent ran `make clean` as a probe. It also ran
  `docker volume prune -f`, which is machine-wide and not scoped to a repository, and six of those seven
  lines silenced every exit code with `|| true` (the prune line silenced nothing). Do not restore that
  recipe.
- Teardown is scoped by the compose **project**, not by the compose file, and only `qa-down` is
  deliberately aimed at the stack it owns: project `docker`, where destroying the database is the
  documented job. `test-env-down` and `e2e-down` are **not** scoped to a stack of their own —
  `docker/compose.test.yaml` and `docker/compose.e2e.yaml` live in `docker/` and declare no top-level
  `name:` either, and neither the repository nor the gitignored local `.env` sets
  `COMPOSE_PROJECT_NAME`, so they resolve to that same project `docker`. Either target therefore also
  stops the QA containers and removes the QA volumes, `docker_postgres_data_qa` among them. Treat that
  as a scoping defect in those two targets, never as a teardown of a separate stack.
- Never rely on the default project name to keep a `down -v` away from someone else's stack. Compose
  derives it from the directory holding the compose file, and `.env` is gitignored and auto-loaded, so
  a single untracked local line can redirect every `up`/`down` in the repository to a project no one
  reviewed. Name the project explicitly with `-p` instead.
- A teardown is safe only when its target gives the stack a compose project name of its own with `-p`,
  and then destroys exactly that project. That is what `test-integration` (`shipit_integration_<pid>`),
  `test-env-test` (`shipit_test`) and `e2e-test` (`shipit_e2e`) do, which is why they are the safe way
  to run tests and the wrong answer to "remove everything". `make clean` is not that answer either — it
  is the stub above. Re-scoping `test-env-down`/`e2e-down`, and the label-scoped replacement sweep that
  would close the gap, are both being designed in `design/port-and-cleanup`. Any new teardown target
  must declare its own compose project name.
- A mandatory Compose variable (`${VAR:?...}`) in a shared compose file breaks every command that
  reads that file, not just the one service that needs it: Compose interpolates the whole file before
  filtering profiles, and it interpolates even for read-only commands like `ps`. Keep such a value
  optional at the file level and fail closed at the call site that needs it.

## Framework provenance
- Framework revision: 693cfbc29e75 — the **authoritative, immutable** provenance identifier.
- Framework version: TBD — human-readable metadata only (revision controls provenance if they differ).
- Both are recorded in this product repo's `framework-manifest.yaml`, which stores **provenance only** plus
  per-artifact baseline hashes. Framework upgrades arrive as **reviewable, isolated 3-way-merge**
  changes and must **not** create a runtime dependency on the framework repo. See the framework's
  ADR 0001 (`docs/engineering/adr/0001-framework-distribution-and-versioning.md`).

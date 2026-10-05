MANAGER: orchestrator-main
TASK_ID: design-port-and-cleanup
TASK_TYPE: design-produce
FEATURE: Future-proof the test DB port and scope `make clean` to our own environments
AREA: developer tooling — Makefile, compose files, CI, port contract
WORKTREE: /private/tmp/shipit-design-port
BRANCH: design/port-and-cleanup
BASE_SHA: 14608dc
OWNED_PATHS:
  - docs/design/**
  - DESIGN_BRIEF_port_and_cleanup.md
  - DESIGN_REVISION_port_and_cleanup.md
READ_ONLY_PATHS:
  - Makefile
  - docker/**
  - .github/workflows/**
  - apps/server/config/**
  - apps/server/tool/**
  - apps/server/docker-compose.yaml
  - AGENTS.md
  - docs/engineering/dispatch/tasks/fix-design-triggers/report.md
PROHIBITED_PATHS:
  - (all production and tooling source — you are DESIGN ONLY; produce artifacts, not code)
ACCEPTANCE_CRITERIA: >
  A Design Brief plus an implementation-ready Design Contract covering both requirements,
  traceable to the human's verbatim request, with a defensible risk level.
VALIDATION_COMMANDS:
  - docker compose -f docker/compose.qa.yaml config >/dev/null && echo qa-ok
  - docker compose -f docker/compose.test.yaml config >/dev/null && echo test-ok
  - docker compose -f docker/compose.e2e.yaml config >/dev/null && echo e2e-ok
  - make -n clean test-env-up test-env-down test-integration
ROUTING_CLASS: STANDARD

## Isolation pre-flight

```bash
cd /private/tmp/shipit-design-port
git branch --show-current    # must equal design/port-and-cleanup
git rev-parse --short HEAD   # must equal 14608dc
```

## Original request (verbatim)

> 1. let's ensure 9099 doesn't cause us issues down the road, 2. Is there anyway to ensure
> make clean only touches our test environment containers not other application continers or
> our locally running QA environment of ship it?
>
> After 1 and 2 above please launch the that focused review of 14608dc.

## Current state, verified by the Manager — do not re-derive, build on it

### Item 1 — the port is hardcoded in three committed sites

Branch `fix/credential-port-contract` @ `60c8136` unified the test DB password to one env-sourced
`SERVERPOD_DATABASE_PASSWORD` and unified the port on **9099** across three sites, because **9090
is occupied on this machine by a different project** (`partnerhub-test-db`). The CI comment at
`.github/workflows/integration.yaml:13-16` was corrected to be factually true.

Read the current values yourself in `apps/server/config/test.yaml`, `apps/server/docker-compose.yaml`
and `.github/workflows/integration.yaml` to confirm.

Known "down the road" exposure the Brief must address:
- The port is a **literal in three committed files**. Changing it needs a three-file edit, and the
  three can silently drift apart again — which is exactly what happened (they disagreed at 9090
  vs 9099 until this session).
- 9099 was chosen only because it happened to be free at the time. Nothing reserves it, documents
  it, or detects a future collision.
- A prior agent session bridged the earlier 9090 clash with a throwaway override at
  `/var/folders/1x/81jcxwg97dqczw4x548yfc940000gq/T/opencode/shipit-test-port-override.yaml`
  (`postgres_test: ports: !override ["9099:5432"]`). `fix/design-triggers` marked it superseded in
  comments, but the file still exists outside the repo and could be re-applied by hand, re-introducing
  drift between the compose default and the running container.
- The lane also reported that `test-env-test` uses compose project `shipit_test` while
  `test-env-up`/`test-env-down` use the **default** project, so both can run side by side and
  collide on ports 5433/8082.

Design a resolution. Consider and evaluate: a single env-sourced port variable with a documented
default and one authoritative definition site; preflight collision detection that fails with an
actionable message instead of Docker's generic "port is already allocated"; making the
project name consistent so compose cannot address two different projects for the same file; and
whether the superseded override file needs a tombstone or removal note. **Make the three sites
unable to drift**, not merely equal today.

### Item 2 — `make clean` currently destroys the human's environment

`Makefile:133-140` on `baseline/product-2026-10-05`:

```make
clean:
	docker compose -f docker/compose.qa.yaml  down -v --rmi local 2>/dev/null || true
	docker compose -f docker/compose.e2e.yaml  down -v --rmi local 2>/dev/null || true
	docker compose -f docker/compose.test.yaml down -v --rmi local 2>/dev/null || true
	docker image rm shipit-client:local 2>/dev/null || true
	docker image rm docker-client    2>/dev/null || true
	docker image rm docker-server    2>/dev/null || true
	docker volume prune -f
```

This is worse than a single stray command. It has **three** distinct blast radii:

1. **It destroys the running local QA environment, including its database.** Line 1 is
   `compose.qa.yaml down -v`; `-v` removes named volumes. The human's QA Postgres is the
   `docker-postgres-1` container (Up 3 days) holding their working data. `2>/dev/null || true`
   hides any failure, so a partial teardown is reported as success.
2. **`docker volume prune -f` is machine-wide.** It deletes every unused Docker volume on the host,
   not just this repository's. There are **six** `partnerhub-*` containers from an unrelated project
   on this machine whose volumes are at risk.
3. **`--rmi local` plus the three `docker image rm` lines** remove locally-built images that other
   compose projects may reference.

The same `2>/dev/null || true` silencing is a known hazard on this repository: lane
`fix-design-triggers` shipped a cleanup trap whose failure was silenced by exactly this pattern, and
the container leaked silently. It recorded that in `AGENTS.md`.

Design a resolution that separates the three intents rather than conflating them:
- removing **our own** disposable test resources (must stay, and must be unconditional);
- resetting the **QA** stack (should require an explicit, unmistakable opt-in, and must say
  plainly that it destroys the local database);
- machine-wide prune (should be removed entirely, or replaced with a label-scoped prune such as
  `--filter label=com.docker.compose.project=<project>`, or replaced with explicitly named volumes).

Address what `make clean` should now mean, and whether the destructive variant needs its own
distinct target with a name that cannot be invoked by accident. Address the `|| true` silencing:
cleanup that fails must be **loud**, or the human is told the environment is gone when it is not, and
vice versa.

## Constraints

- Do NOT modify any source, tooling, or config. You produce design artifacts only.
- Base your design on the code as it actually is at `14608dc` / `60c8136`, not on assumption.
- The change must be behaviour-preserving for the things that already work: the 157/158 integration
  suite, the credential contract, the trigger bootstrap, and the cleanup rule recorded in `AGENTS.md`.
- Must work on a developer laptop with Docker Desktop, and in GitHub Actions on ubuntu.
- Do not require the developer to have a `.env` file to get the default behaviour.

## Deliverables

Produce, per `DESIGN_GOVERNANCE.md`:

1. `DESIGN_BRIEF_port_and_cleanup.md` — problem statement for both items, affected users
   (developer, CI, and the human whose local environment is at risk), constraints, success criteria,
   explicit non-goals, and traceability to the human's two numbered requests.
2. `DESIGN_REVISION_port_and_cleanup.md` — the concrete design, with:
   - an options-considered section per item, including the option you reject and **why**;
   - the exact target contract for each item (env var names, defaults, precedence order, target names);
   - failure-mode behaviour: what happens on a port collision, on cleanup failure, when Docker is absent;
   - a migration/compatibility note for developers with existing local stacks;
   - an independently defensible `risk_level` 0-3 with `risk_rationale` per
     `DESIGN_GOVERNANCE.md` § Artifacts;
   - traceability table from each design element to the requirement it serves.
3. State whether this needs a DCR, and at what level.

Do not write the implementation. Do not approve your own design.

## Hard rules for the child

- Write only inside `OWNED_PATHS`.
- You are the design author and MUST NOT approve your own work.
- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a `HUMAN_DECISION_REQUIRED`
  blocker. If the Brief needs the human to choose between materially different cleanup semantics
  (for example whether `make clean` should ever touch QA at all), say so explicitly rather than
  picking silently.
- Every result carries exact repository/worktree/HEAD provenance.

## Report format

Return a report conforming to `subtask-report.md`. Your `RESULT:` must be verbatim from
`.agents/agents/design-agent.md`. Persist the artifacts in your worktree and report their paths.

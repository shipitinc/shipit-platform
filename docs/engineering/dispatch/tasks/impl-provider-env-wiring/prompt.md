# Dispatch — impl-provider-env-wiring

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-provider-env-wiring
TASK_TYPE: implement
FEATURE: Wire OPENCODE_OPENROUTER_API_KEY into QA + production environments appropriately
AREA: provider credential plumbing (config only, never the key value)
WORKTREE: /private/tmp/shipit-provider-env
BRANCH: feat/provider-env-wiring
BASE_SHA: 7ca2b49
OWNED_PATHS:
  - docker/compose.qa.yaml, docker/.env.example, docker/Dockerfile.server
  - apps/server/config/*.yaml, .gitignore, .env.example, README.md (env docs only)
READ_ONLY_PATHS:
  - packages/scheduler/lib/src/health/provider_health_monitor.dart
  - docker/.env (READ for variable names only — NEVER print/commit values)
PROHIBITED_PATHS:
  - .openRouterApiKey (the key itself — read it only to verify it exists; NEVER print,
    copy, commit, or reference its value)
  - docker/.env (do NOT write the key value into it — env var NAMES only)
  - .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed . (root)
  - docker compose -f docker/compose.qa.yaml config (syntax check — READ-ONLY, does NOT
    start/mutate anything)
ROUTING_CLASS: STANDARD
```

## Human directive
"The openrouter api key is at repo root (.openRouterApiKey). Gitignore it and make it
available to the QA and production environments appropriately."

## Verified facts

- `.openRouterApiKey` exists at repo root (~74 bytes); `.gitignore` already updated on main
  to ignore it (confirm, don't duplicate).
- `OPENCODE_<PROVIDER>_API_KEY` is the env convention the health monitor probes
  (`provider_health_monitor.dart:100-102` — `OPENCODE_OPENCODE_API_KEY` absent in QA by design).
  VERIFY which env var opencode itself honors for openrouter (`OPENROUTER_API_KEY` vs
  `OPENCODE_OPENROUTER_API_KEY` — check the provider_health_monitor + opencode docs/what the
  ACP layer passes; wire BOTH if ambiguous, the health monitor reads the OPENCODE_ prefix).
- `docker/compose.qa.yaml` server service: env via `environment:` + `env_file:` — and a
  secrets-dir pattern exists (`SHIPIT_LOCAL_SECRET_DIR: /var/lib/shipit/secrets`, host path
  from docker/.env) for other credentials. Use whichever pattern the codebase already
  sanctions for credentials — never the key value in a committed file.
- `.env` (repo root) is `.gitignore`'d and read by `env_file:` — the key CAN live there as
  a variable NAME reference, but `.env` is shared with other stacks — prefer the secrets-dir
  or a dedicated env_file entry if the convention supports it.

## Task

1. Wire the openrouter key into the QA server container env — so opencode inside the
   container can authenticate to openrouter's PAID tier. Pick the mechanism that matches
   the repo's credential conventions (env_file variable, secrets-dir, or compose
   interpolation) — document which you chose and why.
2. Document the production path: `apps/server/config/production.yaml` + passwords.yaml
   conventions — production gets the env var by NAME (the key value enters prod's secret
   management, not this file; per AGENTS.md §13a credentials are referenced by name).
3. `.env.example`/`docker/.env.example`: add `OPENCODE_OPENROUTER_API_KEY=` (empty value,
   documented) so future operators know the convention exists.
4. `docker compose -f docker/compose.qa.yaml config` to validate syntax — READ-ONLY.

## Rules
No push; never print/write the key value anywhere; no docker beyond `compose config`
(syntax check only — NOT up/down/build). Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.

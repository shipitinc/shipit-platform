# Dispatch — review-provider-env-wiring

```yaml
MANAGER: orchestrator-main
TASK_ID: review-provider-env-wiring
TASK_TYPE: review
FEATURE: OPENCODE_OPENROUTER_API_KEY / OPENROUTER_API_KEY wired into QA + prod env docs
AREA: provider credential plumbing (config only)
WORKTREE: /private/tmp/shipit-provider-env
BRANCH: feat/provider-env-wiring
BASE_SHA: 7ca2b49
HEAD_SHA_UNDER_REVIEW: 4f477bf
ROUTING_CLASS: STANDARD
```

Independent read-only review of the env wiring (committed at 4f477bf — the implementer left
the changes uncommitted; the manager committed them, identical content). Verify:
1. `docker/compose.qa.yaml` — server.environment gains OPENROUTER_API_KEY +
   OPENCODE_OPENROUTER_API_KEY with nested default to canonical; verify the interpolation
   is correct (reads docker/.env), the env_file/environment shadowing trap is handled, and
   NO key value is present anywhere in the diff.
2. Which env name is correct — the implementer found OPENROUTER_API_KEY is what opencode
   honors (the OPENCODE_<PROVIDER>_API_KEY convention is dead per
   provider_health_monitor.dart:87-106) and wired both with the prefixed twin defaulting to
   canonical. Verify that claim against the monitor + ACP transport.
3. `docker/.env.example` (new) + `.env.example` — the empty documented entries; production.yaml
   comment-only prod path (by NAME per §13a); README section.
4. `.gitignore` — the .openRouterApiKey entry matches main's.
5. `docker compose -f docker/compose.qa.yaml config` — verify it renders both vars; the
   implementer noted the env_file mandatoriness of ../.env on a fresh worktree.
6. No secret material anywhere in the diff — scan the full diff for key-shaped strings.
Read-only; no docker beyond `compose config` (syntax check); no DB. End with exactly
`RESULT: APPROVE_FOR_MERGE` / `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` +
`CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:`.

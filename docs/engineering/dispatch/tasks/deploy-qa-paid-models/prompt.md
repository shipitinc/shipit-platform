# Dispatch — deploy-qa-paid-models

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-paid-models
TASK_TYPE: deploy
FEATURE: redeploy QA — paid OpenRouter tier live (env key + model_policy chains)
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout /Users/alkebut/air/shipit-platform (no repo file writes)
BRANCH: main
BASE_SHA: HEAD
OWNED_PATHS: [] (operational — zero repo edits)
READ_ONLY_PATHS: [docker/compose.qa.yaml, Makefile]
PROHIBITED_PATHS: [all repo files, volumes, down -v, prune, --rmi, make clean, partnerhub-test-db (9090), control_plane-postgres_test-1 (9099), server-postgres_test-1 (9190)]
ROUTING_CLASS: STANDARD
```

## Standing human authorization: "deploy the changes, monitor, remediate" + the paid-tier directive.

## Required actions

1. `make qa-up` — recreates containers; the env wiring (merged 93fdc4a) reads
   `OPENROUTER_API_KEY` from `docker/.env` (key already placed — verify it renders via
   `docker compose -f docker/compose.qa.yaml config` first; value must NOT be printed).
2. Verify by identity: `runMode: staging`; :8180 responds; :8081 title `ShipIt Control Plane`;
   5 workers heartbeating; check pending migrations first.
3. **Verify the paid tier (acceptance):** on the next dispatched job, confirm
   `model_execution_record` shows a NON-free model (modelId or the runtime metadata now
   records the openrouter step) AND `totalTokens > 0` — proof a real paid call ran, not the
   zero-token quota-dead signature. The model_policy chains now default to
   `openrouter/deepseek/deepseek-v4.1-flash` (or glm/qwen for mechanical roles) at step 0.
   If a job dispatches and still burns 1800s with 0 tokens, report DEPLOYMENT_PARTIAL with
   the verbatim failure — the env var may not be reaching opencode in-container.
4. Report residuals verbatim.

## Report
`RESULT: DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL` with verbatim
evidence the paid model ran a real call (tokens > 0).

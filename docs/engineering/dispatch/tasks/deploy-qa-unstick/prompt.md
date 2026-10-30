# Dispatch prompt — deploy-qa-unstick

```yaml
MANAGER: orchestrator-main
TASK_ID: deploy-qa-unstick
TASK_TYPE: deploy
FEATURE: QA environment unstick — repair leaked dedupe keys + rebuild/restart at HEAD
AREA: QA environment (compose project `docker`, docker/compose.qa.yaml)
WORKTREE: canonical checkout (read-only for code; this lane writes NO repo files)
BRANCH: main
BASE_SHA: fb8dde3
OWNED_PATHS:
  - (no repository paths — this is an operational lane; it may read everything, edit nothing)
READ_ONLY_PATHS:
  - docker/compose.qa.yaml
  - docker/Dockerfile.server
  - docker/Dockerfile.client
  - Makefile
  - docs/engineering/FOLLOW_UPS.md
  - docs/deployment/local-qa.md
PROHIBITED_PATHS:
  - every repository file (no code edits of any kind)
  - production / staging environments other than the local QA compose stack
  - compose project `docker` volumes OTHER than the running containers (NO `down -v`, NO `volume rm`, NO `prune`, NO `--rmi`)
ACCEPTANCE_CRITERIA: see below
VALIDATION_COMMANDS:
  - curl -sf http://localhost:8180/                       # server identity post-restart
  - curl -sf -o /dev/null -w '%{http_code}' http://localhost:8081/   # client post-restart
  - psql -h localhost -p 5432 -U shipit -d shipit -c '<verification queries below>'
ROUTING_CLASS: STANDARD
```

## Authorization (human, 2026-10-30, structured question UI)

The human authorized, verbatim decision: **"Repair + redeploy at HEAD — Clear the 2 leaked dedupe
keys, restart the QA server to drop wedged leases, rebuild images at current HEAD (picks up the
coordinator fix 68afc22). Unblocks the design/impl/triage lanes now via a deployment-authority
lane."**

This grants you the deployment/infrastructure authority the Manager and other lanes do NOT hold —
for THIS stack and THESE operations only. It does not authorize volume deletion, `down -v`,
`prune`, `--rmi`, `make clean`, or any operation on `partnerhub-test-db`, `control_plane-postgres_test-1`,
or `server-postgres_test-1`.

## Context — what is actually wedged (verified live 2026-10-30)

1. `job` rows `jb-hnnwapzybj-ah92h5` (state `failed`, `activeDedupeKey='DEF-f223-test:design_revision'`)
   and `jb-hnny3s8b5p-1vrz72q` (state `cancelled`, `activeDedupeKey='DEF-fresh-test:design_revision'`)
   hold non-NULL `activeDedupeKey` — terminal rows written outside the store's derivation
   (`postgres_job_store.dart:391`). Their stale keys collide on `job_active_dedupe_unique` and
   suppress every re-enqueue.
2. `jb-hnnwapzybj` was manually flipped to `failed` while never having run: `failureJson` NULL,
   no `job_claimed`/`job_dispatched`/`job_failed` events (only `job_queued`+`job_deferred`). Its
   recorded state is factually wrong: it was never executed, so `cancelled` is the truthful terminal
   state — and `cancelled` is the only state that yields the dedupe key (`job_queue.dart:76`).
   The work item `DEF-f223-test` sits at `design_required`; a `failed` latest row would suppress
   re-enqueue BY DESIGN even after the key repair.
3. `w-impl-local` and `w-triage-local` hold in-process leases for runs orphaned by the zombie sweep —
   only a process restart frees them. 7 `implement_feature` jobs queue behind `workerBusy`.
4. Un-ended `worker_execution` rows: `wx-jb-hn3liczxln-li36ts` (`orphaned`, Oct-11, `endedAt` NULL)
   and `wx-jb-hnntgl4dak-1vq26jz` (`agentExecuting`, 15h+, owning job already cancelled).
5. The QA image is stale: worktrees fork from `requestedStartingRevision f58d6fb` (Oct 9).

## Required actions

1. **Row repair** (QA Postgres `localhost:5432`, db `shipit`, user `shipit`, password `shipit` — the
   compose env values; use `psql`, no docker exec needed):
   ```sql
   UPDATE job SET "activeDedupeKey" = NULL
     WHERE "jobId" IN ('jb-hnnwapzybj-ah92h5','jb-hnny3s8b5p-1vrz72q');
   -- correct the never-ran job's factual state so its dedupe key is yielded:
   UPDATE job SET state = 'cancelled'
     WHERE "jobId" = 'jb-hnnwapzybj-ah92h5' AND state = 'failed';
   -- close the un-ended executions (endedAt only; status already truthful):
   UPDATE worker_execution SET "endedAt" = now()
     WHERE "workerExecutionId" IN ('wx-jb-hn3liczxln-li36ts','wx-jb-hnntgl4dak-1vq26jz')
       AND "endedAt" IS NULL;
   ```
   Run each inside a transaction you can verify; report row counts. If any UPDATE's guard fails
   (e.g. the job is no longer `failed`), STOP and report rather than forcing it.
2. **Rebuild + restart the QA stack at `fb8dde3`** (canonical checkout HEAD): rebuild the `server`
   and `client` images from `docker/compose.qa.yaml` and bring them up — equivalent of
   `docker compose -f docker/compose.qa.yaml up -d --build server client` (read the compose file and
   Makefile `qa-*` targets first; `make qa-up` may already encode the right invocation). Do NOT use
   `down -v`, `prune`, `--rmi`, or `make clean`. Server boot applies pending migrations —
   check `apps/server/migrations/` for directories newer than the DB's installed versions BEFORE
   restart and report what will apply; if any migration looks destructive (DROP/TRUNCATE), STOP and
   escalate instead of proceeding.
3. **Verify by identity, never by status alone** (the standing rule from the Penpot-on-8080 incident):
   - `curl http://localhost:8180/` responds AND the boot log shows `runMode: staging` with the
     `[server.composition]` line listing `sched-design-revision` and `sched-design-review`.
   - `curl http://localhost:8081/` returns the ShipIt client (title `ShipIt Control Plane`), not
     another app on the port.
   - After one tick (~30s), verify in the DB: `w-impl-local`/`w-triage-local` report `idle`, and a
     NEW `design_revision` job exists for `DEF-fresh-test` (and `DEF-f223-test`) or report the exact
     suppression reason still observed.
4. **Confirm the queue drains**: within a few ticks the 7 queued `implement_feature` jobs should stop
   deferring `workerBusy` — capture `scheduler_event` rows showing dispatch or the residual deferral
   reason if they do not.

## Hard rules

- No repository file edits. No commits.
- `ps`/`logs`/`config`/`inspect`/`exec`/`up`/`build`/`restart` are authorized ONLY against compose
  project `docker` via `docker/compose.qa.yaml` — never a bare `docker compose` (that is the live
  stack) without `-f`, and never `down -v`/`prune`/`--rmi`/`volume rm`.
- Do not touch `partnerhub-test-db` (9090), `control_plane-postgres_test-1` (9099),
  `server-postgres_test-1` (9190), or any volume.
- Every SQL write: disclose the exact statement and its row count in your report.
- If the rebuilt server fails to boot, capture the boot log verbatim, leave the stack DOWN-or-up as
  you found it recoverable, and report — do not improvise rollbacks.

## Report format

Return a report conforming to `subtask-report.md`. Your `RESULT:` token is your own lane token
(`DEPLOYMENT_SUCCESSFUL` / `DEPLOYMENT_FAILED` / `DEPLOYMENT_PARTIAL`), with evidence for each
criterion above.

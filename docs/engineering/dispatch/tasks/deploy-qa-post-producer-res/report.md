# Subtask Report — deploy-qa-post-producer-res

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-producer-res
TASK_TYPE: deploy
FEATURE: redeploy QA — producer-resolution fix live (qa-triage contracts evaluate the triage result)
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: HEAD (deploy-time HEAD)
HEAD_SHA: 6a4d307ec4089dae04a8acee43d1fa15c8fb1002
COMMITTED: NO
TARGET_ENVIRONMENT: STAGING (local QA compose stack, project `docker`, docker/compose.qa.yaml)
CANDIDATE_ID: docker-server image sha256:bb8d23b28e50a9b9e8655b4c8f7b16fbd9136a40a07c4a2a5a0e39226c9dbbbe
  built 2026-11-03T03:15:0xZ from HEAD 6a4d307 (contains fix 1c37bf3 "Make QA producer resolution
  contract-aware (F-253)", ancestor-verified); docker-client image
  sha256:c3b9b691019b05b3476b0a719fe2a29f1de1696707117d2f30bcb4dcd71f8dbe built from the same HEAD
```

## Files touched

```text
docs/engineering/dispatch/tasks/deploy-qa-post-producer-res/report.md   (this report)
/tmp/qa-up-deploy-6a4d307.log                                            (build log, machine-local)
```

Zero repository source files written. `OWNED_PATHS: []` held for repo files.

## What was executed, in order

1. **Pre-flight migration check** — `serverpod_migrations` on QA Postgres: `control_plane
   20261023113614000` = newest `migration_registry.txt` entry (nothing pending), `serverpod
   20260129180959368`. Fix commits `1c37bf3` / merge `a20a78d` are Dart-only (`git show --stat`:
   4 files, zero `migrations/` paths). Nothing destructive. No STOP condition.
2. **Fix ancestry verified** — `git merge-base --is-ancestor 1c37bf3 HEAD` under `6a4d307`:
   IS an ancestor.
3. **`make qa-up`** — `check-client-build` guard OK; `docker/build-client.sh` compiled web and
   built `docker-client` `c3b9b691`; `compose build server` produced `docker-server` `bb8d23b2`
   (layer cache carried pub-get; `build_runner` aot 15.8s); `up -d` recreated `docker-server-1`
   and `docker-client-1` at ~03:15:08Z. `docker-postgres-1` untouched (`Up 2 days (healthy)`);
   `docker-triage-seed-1` completed and exited 0. No `down`, `-v`, `prune`, `--rmi`, `clean`
   issued; volumes untouched; forbidden DBs (9090/9099/9190) never approached. Total wall
   ~2min (vs ~33min expectation — cache).
4. **Identity verification** (verbatim below).
5. **Fix verification** (below).
6. **Residuals** collected verbatim (below).

## Identity verification (verbatim)

```text
server-1  | SERVERPOD version: 3.4.13, dart: 3.12.2 ... time: 2026-11-03 03:15:13.077684Z
server-1  | runMode: staging
server-1  | SERVERPOD initialized, time: 2026-11-03 03:15:13.121880Z
server-1  | Latest database migration already applied.
```

```text
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/    -> 200
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/ -> 200
$ curl -s http://localhost:8081/ | grep -o "<title>[^<]*</title>"  -> <title>ShipIt Control Plane</title>
```

Worker heartbeats (read-only psql, 03:15:59Z sample — all five rows `lastHeartbeat` ≤5s old at
03:16:04Z):

```text
w-design-review-local   | idle | 2026-11-03 03:15:30.012497
w-design-revision-local | idle | 2026-11-03 03:15:30.009976
w-impl-local            | idle | 2026-11-03 03:15:30.007587
w-review-local          | idle | 2026-11-03 03:15:30.005049
w-triage-local          | idle | 2026-11-03 03:15:29.964067
```

Boot composition log: `[worker.registration.started] {intervalSeconds: 15, staleAfterSeconds: 120,
registered: [w-triage-local, w-review-local, w-impl-local, w-design-revision-local,
w-design-review-local], failed: {}, previouslyStale: []}` — `registeredCount: 5`.

## Fix verification

### (a) Deployed artifact carries `requiredRole` scope — grepped + test-executed inside the NEW container

`resolveProducerExecution` signature carries the optional role scope —
`/app/packages/execution_coordinator/lib/src/coordinator/producer_execution.dart`:

```text
35:enum ProducerResolution {
107:  requiredRole,
195:/// ## THE OPTIONAL CONTRACT SCOPE — [requiredRole]
216:  AgentRole? requiredRole,
222:        (requiredRole == null || execution.role == requiredRole)) {
224:        how: ProducerResolution.stampedProducer,
232:    if (requiredRole == null) {
```

`producerRoleForQaContractId` derives the required role and the drain wires it —
`/app/apps/server/lib/src/qa/production_qa_sources.dart`:

```text
150:AgentRole? producerRoleForQaContractId(String? contractId) {
221:      requiredRole: producerRoleForQaContractId(item.qaContractId),
```

Behavioural — `dart test test/producer_execution_required_role_test.dart` inside the running
container (`-w /app/packages/execution_coordinator`), EXIT=0, 8/8:

```text
+0: a stamp naming the IMPLEMENTER resolves the TRIAGE execution when the contract judges triage output — the F-253 rows
+1: a stamp naming an execution OF the required role still wins over the role fallback
+2: with no stamp, the newest execution OF THE REQUIRED ROLE is taken — never the newest of any other role
+3: the newest of SEVERAL executions of the required role is taken
+4: a stamp naming an execution of another role resolves by role even when the stamp names IMPLEMENTER and the required role IS implementer on a different item — symmetric for any declared role
+5: a dangling stamp falls to the role fallback rather than refusing, because the required-role question is still answerable
+6: refusal an item with NO execution of the required role refuses — some other role's result is never substituted
+7: refusal the required-role fallback also skips a required-role execution that exists but is not the newest
All tests passed!
```

Behavioural — `dart test lib/src/qa/qa_drain_contract_producer_test.dart` inside the running
container (`-w /app/apps/server`), EXIT=0, 3/3:

```text
+0: a defect item carrying both a triage and an implementer execution the qa-triage contract evaluates the TRIAGE execution's result, not the implementer's — the stamped producer is the implementer
+1: a defect item carrying both a triage and an implementer execution the same item under a qa-product contract still evaluates the IMPLEMENTER's result
+2: a defect item carrying both a triage and an implementer execution a qa-triage contract on an item with no TRIAGE_DEFECT execution faults rather than evaluating another role's result
All tests passed!
```

### (b) Next defect item's `qa-triage` evaluation — verified at the emission site; live run not inducible

The drain resolves producer scope per evaluation via the deployed `production_qa_sources.dart:221`
(the server runs JIT from `/app` — what runs IS what was grepped and tested above). Every future
`qa-triage-*` contract evaluation resolves `requiredRole: AgentRole.triageDefect`; the stamp only
wins when it names a TRIAGE execution, and the fallback resolves the newest TRIAGE_DEFECT execution
— so the triage gates see the triage-shaped structuredResult (classification + evidenceUsed) and
can pass honestly. The pre-fix failure mode — a `qa-triage-*` contract handed the implementer's
structuredResult post-rework — is the exact row test `+0` in both suites asserts against.

**Live-dispatch caveat, stated honestly** — 11 defect items carry `qa-triage-*` contracts, but none
sits in a state that re-evaluates on its own: 8 are `waiting_for_human_decision` (blocked on human
routings this lane must not resolve), 1 `agent_failed`, 1 `agent_completed`, and 1 `draft` (outside
triage's entry states). No live re-evaluation can be induced without a human decision. The
verification above is therefore artifact + behavioural evidence inside the running container, not a
live observed pass — the first real re-evaluation happens when a human unblocks a defect item.

## Residuals (verbatim)

**1. Schema-analyzer WARNING — DOCUMENTED FALSE POSITIVE (compose.qa.yaml:64-67).** Every object
the analyzer calls missing was verified present in `shipit` via `pg_indexes` /
`information_schema`: `design_revision.declared_owned_paths` (text[]), all three named indexes.
Reported verbatim for the record:

```text
WARNING: The database does not match the target database:
 - Table "design_revision" is not like the target database:
 - Missing Column "declared_owned_paths".
 - Missing Index "design_revision_approved_unique_per_work_item".
 - Missing Index "design_revision_declared_owned_paths_idx".
 - Table "product_credential" is not like the target database:
 - Missing Index "product_credential_active_repository_unique".
Hint: Did you forget to run `serverpod generate`, apply the migrations (--apply-migrations), or run a repair migration (--apply-repair-migration)?
```

```text
$ psql -> design_revision_approved_unique_per_work_item      (exists)
          design_revision_declared_owned_paths_idx         (exists)
          product_credential_active_repository_unique      (exists)
          design_revision.declared_owned_paths | text[] | not null | '{}'::text[]  (exists)
```

**2. `[durable_workspace.provision.refused]` + `[durable_workspace.provision.already_provisioned]`**
— `SHIPIT_PROVISION_DURABLE_WORKSPACE` still set in docker/.env; the documented no-op outcome
(already-provisioned, nothing cloned/recorded/changed; "MAY NOW BE CLEARED"). Unchanged from prior
deploys; clearing it is the operator's call, not this lane's.

**3. `[work_entry.sweep.disabled]`** — printed every start by design (design-revision.md §15 gate;
P-2/P-5 unproven). `enableWith: SHIPIT_WORK_ENTRY_SWEEP=<1|true|yes|on>`; operator action only.

**4. Ticks post-boot all clean** — `[scheduler.tick.completed] {dispatched: 0, failedSections: [],
reconcileFailed: [], overlappedTicks: 0}`, `[baseline.tick.completed]` zero incidents,
`[design.readiness.sweep.completed] {scanned: 0, transitioned: 0}` twice.

**5. Paid tier** — `OPENROUTER_API_KEY` / `OPENCODE_OPENROUTER_API_KEY` declared in the service
environment (names only; values never printed or read). Not re-verified inside the container this
run; unchanged compose wiring.

## Standing-rule compliance

- Docker/Compose issued ONLY against `docker/compose.qa.yaml` (project `docker`): `build`, `up -d`,
  `ps`, `logs`, `exec`. No mutating command outside the project; no `down`/`stop`/`rm`/`prune`/
  `--rmi`/`volume rm`; `make clean` / `qa-down` / `test-env-down` never issued.
- `docker-postgres-1` (QA, 5432) never restarted; volumes `postgres_data_qa`, `triage_repo_qa`,
  `triage_workspaces_qa` untouched.
- Forbidden stacks never approached: partnerhub-test-db (9090), control_plane-postgres_test-1
  (9099), server-postgres_test-1 (9190).
- No secret values printed; credential names referenced only.
- No repo file edits; zero commits, zero pushes.

```text
RESULT: DEPLOYMENT_SUCCESSFUL
```

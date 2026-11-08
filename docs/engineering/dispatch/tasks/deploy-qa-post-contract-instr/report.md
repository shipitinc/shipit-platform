# Subtask Report — deploy-qa-post-contract-instr

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-contract-instr
TASK_TYPE: deploy
FEATURE: redeploy QA — missing-artifact fix + contract-instruction fix live
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: HEAD (deploy-time HEAD)
HEAD_SHA: 18172c6f3b981b4c962197889fabc8dc03a5fa39
COMMITTED: NO
TARGET_ENVIRONMENT: STAGING (local QA compose stack, project `docker`)
CANDIDATE_ID: docker-server image sha256:3c1924544cefbda004c482b44c9d318e8646842f59c97ba8f46d80f8f5e29901
  built 2026-11-03T01:21:5xZ from HEAD 18172c6 (contains fixes eb58bf8 + 94208c5, both ancestor-verified);
  docker-client image sha256:0d9bf87001ff4d6125051ee57a03c7793e95404e17bb407076697cdc38581139
  built 2026-11-03T01:20:5xZ from the same HEAD
```

## Files touched

```text
docs/engineering/dispatch/tasks/deploy-qa-post-contract-instr/report.md   (this report)
/tmp/qa-up-deploy-18172c6.log                                              (build log, machine-local)
```

Zero repository source files written. `OWNED_PATHS: []` held for repo files.

## What was executed, in order

1. **Pre-flight migration check** — `serverpod_migrations` on QA Postgres:
   `control_plane 20261023113614000` (newest `migration_registry.txt` entry — nothing pending),
   `serverpod 20260129180959368`. Both fix commits are Dart-only (`git show --stat`: packages +
   tests, zero `migrations/` paths). Nothing destructive. No STOP condition.
2. **Fix ancestry verified** — `git merge-base --is-ancestor` under HEAD `18172c6`:
   `eb58bf8` "Fix implementer instruction pointing agents at unreachable QA contract" IS an
   ancestor; `94208c5` "Record denied-ask evidence and close the agent_message extraction gap"
   IS an ancestor.
3. **`make qa-up`** — `check-client-build` guard OK; `docker/build-client.sh` compiled
   `lib/main.dart` for web (24.3s) and built `docker-client` `0d9bf870`; `compose build server`
   produced `docker-server` `3c192454` (`dart pub get` 23.5s, `build_runner` 15s — layer cache
   carried the rest); `up -d` recreated `docker-server-1` and `docker-client-1` at 01:22:05Z.
   `docker-postgres-1` untouched (`Up 47 hours (healthy)`); `docker-triage-seed-1` exited 0.
   No `down`, `-v`, `prune`, `--rmi`, `clean` issued; volumes untouched; forbidden DBs
   (9090/9099/9190) never approached. Total wall ~2min (vs ~33min expectation — cache).
4. **Identity verification** (verbatim below).
5. **Both-fixes verification** (below).
6. **Residuals** collected verbatim (below).

## Identity verification (verbatim)

```text
server-1  | SERVERPOD version: 3.4.13, dart: 3.12.2 ... time: 2026-11-03 01:22:28.883160Z
server-1  | runMode: staging
server-1  | SERVERPOD initialized, time: 2026-11-03 01:22:29.081314Z
server-1  | Latest database migration already applied.
```

```text
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/   -> 200
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/ -> 200
$ curl -s http://localhost:8081/ | grep -o "<title>[^<]*</title>" -> <title>ShipIt Control Plane</title>
```

Worker heartbeats (read-only psql, 01:22:44Z sample — all five rows `lastHeartbeat` ≤9s old;
re-sampled later: 5/5 live within 60s):

```text
w-design-review-local   | idle | 2026-11-03 01:22:35.970418
w-design-revision-local | idle | 2026-11-03 01:22:35.96366
w-impl-local            | idle | 2026-11-03 01:22:35.955199
w-review-local          | idle | 2026-11-03 01:22:35.947201
w-triage-local          | idle | 2026-11-03 01:22:35.878182
```

Boot composition log confirms `workerIds: [w-triage-local, w-review-local, w-impl-local,
w-design-revision-local, w-design-review-local]`, `registeredCount: 5`, `failed: {}`.

## Both-fixes verification

### (a) Deployed artifact carries the fixes — grepped + test-executed inside the NEW container

**Contract-instruction fix (eb58bf8)** — `/app/packages/scheduler/lib/src/implement_feature.dart:237-239`:

```text
${qaContractId == null ? '' : 'QA CONTRACT: $qaContractId — informational only. It names a platform-side\n'
            'record in the control-plane database, not a file in this worktree, and it\n'
            'cannot be opened from where you are working — do not look for it. The\n'
            'criteria this run is judged against that you can act on are already\n'
            'above: the DESCRIPTION, the ACCEPTANCE CRITERIA when present, and these\n'
            'WORKING INSTRUCTIONS. The platform evaluates your committed change\n'
            'against that contract itself after you finish.\n'}
```

Behavioural — `dart test test/implement_feature_prompt_contract_test.dart` inside the running
container (`-w /app/packages/scheduler`), EXIT=0, 7/7:

```text
+0: the QA contract reference can no longer send the agent hunting the contract id is still present, for the audit trail on the job row
+1: the QA contract reference can no longer send the agent hunting the wording that claimed the criteria live there is gone
+2: the QA contract reference can no longer send the agent hunting the reference is marked informational and unreachable
+3: the QA contract reference can no longer send the agent hunting the agent is told where the criteria it can act on already are
+4: the QA contract reference can no longer send the agent hunting no contract line is emitted when the item carries no contract
+5: the in-reach criteria are still genuinely present metadata acceptance criteria are inlined verbatim
+6: the in-reach criteria are still genuinely present the instruction still demands a commit, which the gates assert
All tests passed!
```

**Denial-aware missing-artifact fix (94208c5)** — `/app/packages/execution_coordinator/lib/src/coordinator/success_artifact.dart`:
`noCommitReason` branches on `denials` (lines ~250-263); `denialClause` appends
"The platform denied N permission ask(s) during this run (...); the asks themselves are in the
verdict details and the result's metadata. Whether the refused call(s) were required for the
artifact cannot be told from the record." to all three role reasons.

Behavioural — `dart test test/success_artifact_rule_test.dart` inside the running container
(`-w /app/packages/execution_coordinator`), EXIT=0, 24/24, including:

```text
+3: IMPLEMENTER: a commit is the artifact a missing artifact after a denied ask still fails — and records WHY the run ended
+4: IMPLEMENTER: a commit is the artifact the work item lands at agent_failed, never agent_completed
All tests passed!
```

**`ProducerRoleScopedGate`** — present in artifact: `production_qa_sources.dart:681` registers it
(`show ProducerRoleScopedGate, ProducerRoleSource` at line 47), defined
`producer_scoped_gate.dart:96`. Behavioural — `dart test lib/src/qa/producer_scoped_gate_test.dart`
inside the container (`-w /app/apps/server`), EXIT=0, 7/7 `All tests passed!`.

### (b) Next implement run's instruction — verified at the emission site; live run not inducible

The instruction is built per dispatch by the deployed `implement_feature.dart` (the server runs
JIT from `/app` source — what runs IS what was grepped and tested above). Every future
implement run emits the "informational only / do not look for it" wording; the old wording that
sent agents hunting the DB-resident contract is gone (test +1 asserts it verbatim on the artifact).

**Paid tier confirmed live**: `OPENROUTER_API_KEY` and `OPENCODE_OPENROUTER_API_KEY` both SET in
the container (names checked, values never printed); `model_policy` rows show IMPLEMENTER chain
`openrouter/deepseek/deepseek-v4.1-flash` → `openrouter/anthropic/claude-sonnet-5.5` — the next
implement run executes on the paid tier, not the free zen tier.

**Live-dispatch caveat, stated honestly** — zero work items sit in `implementation_ready`
(`SELECT ... WHERE state='implementation_ready'` → 0 rows). The lane's producers are four human
decision routings plus the OD-10 completion-time discriminator; all 9 candidate items are parked
`waiting_for_human_decision` and the 3 `agent_failed` items do not re-enter on their own. The
two `draft` items are outside triage's entry states (`designNotRequired`, `reviewRejected`,
`planned`) — `draft` is not among them. No implement run can be induced without resolving a
human decision, which this lane must not do. The pre-fix `missing_success_artifact` failures are
visible in `agent_execution.reason` (e.g. `agx-wx-jb-hnssehl217`, `agx-wx-jb-hnssdj90ko`) —
exactly the pattern this deploy retires; under the new code such a run still settles failed but
records WHY (denied-ask evidence), and never lands `agent_completed`. Ticks post-boot all
`ran: true, dispatched: 0, failedSections: []` — the scheduler is healthy and idle only because
nothing is eligible, matching the composition banner ("an idle implementation scheduler means
items are not arriving at these producers, not that the lane is inert").

## Residuals (verbatim)

1. Boot-time schema-analyzer WARNING (staging mode keeps it non-fatal; same drift as the prior
   deploy — real but non-blocking):

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

2. `[durable_workspace.provision.already_provisioned]` — satisfied outcome; notes verbatim that
   "SHIPIT_PROVISION_DURABLE_WORKSPACE MAY NOW BE CLEARED from the deployment environment"
   (informational, recurs each boot while the instruction stays set).
3. `[work_entry.sweep.disabled]` — documented design-revision.md §15 gate (P-2/P-5 unproven);
   printed on every start, not a fault.
4. `[server.modelpolicy.seeded] {rolesSeeded: [], rolesSeededCount: 0, defaultModelId:
   opencode/space-bunny-free, ...}` — informational; every role already had a policy row, nothing
   overwritten (role chains are the paid openrouter tier shown above).
5. Client build: "56 packages have newer versions incompatible with dependency constraints"
   (informational `dart pub get` output during server image build).

## Constraints honored

- Zero repo file edits (only this dispatch report artifact).
- Compose commands only against `docker/compose.qa.yaml` project `docker`.
- No `down`, `-v`, `prune`, `--rmi`, `clean`; no volume touched; postgres container untouched (47h).
- Never approached `partnerhub-test-db` (9090), `control_plane-postgres_test-1` (9099),
  `server-postgres_test-1` (9190).
- No secret values printed; `docker/.env` never read for display; credential presence checked by
  name only (`[ -n "$VAR" ]`).

## Discoveries

- `PROJECT_FACT`: `draft` is not a triage entry state (`designNotRequired`, `reviewRejected`,
  `planned` are), so draft items do not feed the implement lane either — every path into
  `implementation_ready` is a human decision or an OD-10 completion-time discriminator.
- `RUNTIME_DISCOVERY`: this build's `build_runner` step completed in 15s ("Built with
  build_runner/aot ... wrote 0 outputs"; `--delete-conflicting-outputs` now ignored) — far under
  the ~33min expectation; the deployed artifact still carries full source + test suite and all
  in-container tests pass, so the short build is cache behaviour, not a skipped stage.

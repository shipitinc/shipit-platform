# Subtask Report — deploy-qa-post-qa-gates

```yaml
RESULT: DEPLOYMENT_SUCCESSFUL
TASK_ID: deploy-qa-post-qa-gates
TASK_TYPE: deploy
FEATURE: redeploy QA — producer-scoped QA gate live (feature items can pass contracts)
WORKTREE: /Users/alkebut/air/shipit-platform
BRANCH: main
BASE_SHA: HEAD (deploy-time HEAD)
HEAD_SHA: 65c8a38453b80f3c69f560c4990600dd59f2595e
COMMITTED: NO
TARGET_ENVIRONMENT: STAGING (local QA compose stack, project `docker`)
CANDIDATE_ID: docker-server image sha256:dfaa69942aee09c9fd165bbe1131a89b84a958f1c69204e290d02f150b04a5ae
  built 2026-11-02T15:25:21Z from HEAD 65c8a38 (contains gate fix c58352a, ancestor-verified);
  docker-client image sha256:fe327beebc90408557b9e102439bdf976f80e1ee0eb15a91f08b0aaadd6f045f
  built 2026-11-02T15:14:50Z from the same HEAD
```

## Files touched

```text
docs/engineering/dispatch/tasks/deploy-qa-post-qa-gates/report.md   (this report)
/tmp/qa-up-1793632164.log                                            (build log, machine-local)
/tmp/gate_test.out                                                   (in-container test output, ephemeral container layer)
```

Zero repository source files written. `OWNED_PATHS: []` held for repo files.

## What was executed, in order

1. **Pre-flight migration check** — `serverpod_migrations` on QA Postgres:
   `control_plane 20261023113614000` (newest `migration_registry.txt` entry — nothing pending),
   `serverpod 20260129180959368`. Nothing destructive. No STOP condition.
2. **Fix ancestry verified** — `git merge-base --is-ancestor c58352a HEAD` under HEAD `65c8a38`:
   `c58352a` "Scope triage-classification-structure QA gate to triage producers" IS an ancestor
   (merged via `2f150ed`).
3. **`make qa-up`** — `check-client-build` guard OK; `docker/build-client.sh` compiled
   `lib/main.dart` for web and built `docker-client` `fe327bee` (15:14:50Z); `compose build server`
   ran a REAL rebuild this time (source changed: steps #3–#16 rebuilt, `build_runner` 231s, pub get
   ~110s) producing `docker-server` `dfaa6994` (15:25:21Z); `up -d` recreated `docker-server-1` and
   `docker-client-1` (15:26:3xZ). `docker-postgres-1` untouched (`Up 37 hours (healthy)`);
   `docker-triage-seed-1` exited 0. No `down`, `-v`, `prune`, `--rmi`, `clean` issued; volumes
   untouched; forbidden DBs (9090/9099/9190) never approached. Total wall ~13 min — under the
   ~33 min expectation.
4. **Identity verification** (verbatim below).
5. **Gate-fix verification** (below).
6. **Residuals** collected verbatim (below).

## Identity verification (verbatim)

```text
server-1  | SERVERPOD version: 3.4.13, dart: 3.12.2 ... time: 2026-11-02 15:26:35.891974Z
server-1  | runMode: staging
server-1  | SERVERPOD initialized, time: 2026-11-02 15:26:36.139435Z
server-1  | Latest database migration already applied.
```

```text
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8180/   -> 200
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/ -> 200
$ curl -s http://localhost:8081/ | grep -o "<title>[^<]*</title>" -> <title>ShipIt Control Plane</title>
```

Worker heartbeats (read-only psql, 15:28:44Z sample — all five rows `lastHeartbeat` 15:28:34Z):

```text
w-design-review-local   | idle | currentLoad 0
w-design-revision-local | idle | currentLoad 0
w-impl-local            | idle | currentLoad 0
w-review-local          | idle | currentLoad 0
w-triage-local          | idle | currentLoad 0
```

Boot composition log confirms `workerIds: [w-triage-local, w-review-local, w-impl-local,
w-design-revision-local, w-design-review-local]`, `registeredCount: 5`, `failed: {}`.

## Gate-fix verification

**Artifact level** — the container runs JIT from `/app/apps/server` source; grepped inside the
NEW container: `lib/src/qa/producer_scoped_gate.dart` present, `production_qa_sources.dart:681`
registers `ProducerRoleScopedGate(inner: TriageClassificationAdmittedGate(), appliesToRoles:
const {AgentRole.triageDefect})` — registering after `buildGateRegistry`, replacing the unscoped
evaluator for production only.

**Behavioural, on the deployed artifact** — executed the co-located test that ships inside the
image, inside the running container (`docker exec -w /app/apps/server docker-server-1 dart test
lib/src/qa/producer_scoped_gate_test.dart`), EXIT=0, 7/7:

```text
+1: a non-triage producer answers not_applicable, and the inner evaluator never runs
+2: a triage producer is evaluated verbatim — a well-formed classification passes
+3: a triage producer is evaluated verbatim — a malformed classification still fails
+4: an unresolvable producer fails closed by evaluating, never by declaring the gate inapplicable
+5: a feature item under the SHIPPED contract reaches qaPassed with the intake gate recorded not_applicable
+6: the advisory triage contract still applies the gate to triage output
+7: a malformed triage classification still fails its contract and reaches the human
All tests passed!
```

**Producer-role fact from the durable record** — `agent_execution` for the parked feature item's
producer `agx-wx-jb-hnpppnm21f-m4sid0` is role `IMPLEMENTER` (non-triage →
`intake-structured-result-admitted` resolves `not_applicable` on re-evaluation); the defect item's
`qa-triage-*` contract evaluates the triage result produced by role `TRIAGE_DEFECT`
(`agx-wx-jb-hnoxipxvy8-1nbx5so:a2`, completed) → the strict gate applies.

**Live-drain caveat, stated honestly** — no work item currently sits in a drainable state
(`reviewApproved | qaInProgress | qaFailed`; the only edge into `reviewApproved` is
`waitingForHumanDecision -> reviewApproved`, a human gate). No fresh live contract evaluation was
possible without resolving a human decision, which this lane must not do. Both parked items remain
`waiting_for_human_decision` with `qa_waiver` decisions `pending` (`dec-hnsdvsz7u2-wxqb42`,
`dec-hnsdvsdzl1-1c1cny5`) — they resolve on their own terms per the dispatch. The drain ran cleanly
on every tick post-boot (`failedSections: []`, 8 ticks); `qa.drain` logged nothing because nothing
was eligible.

## Residuals (verbatim)

1. Boot-time schema-analyzer WARNING (staging mode keeps it non-fatal; `declared_owned_paths`
   column drift is real but non-blocking, matching the prior deploy):

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
4. One `scheduler.tick.completed {ran: false, code: TICK_OVERLAP_DROPPED}` during the 36s first
   boot tick — normal single-flight behaviour; subsequent ticks all `ran: true`.
5. Client build: "72 packages have newer versions incompatible with dependency constraints"
   (informational `flutter pub get` output, unchanged from prior deploys).

## Constraints honored

- Zero repo file edits (only this dispatch report artifact).
- Compose commands only against `docker/compose.qa.yaml` project `docker`.
- No `down`, `-v`, `prune`, `--rmi`, `clean`; no volume touched; postgres container untouched (37h).
- Never approached `partnerhub-test-db` (9090), `control_plane-postgres_test-1` (9099),
  `server-postgres_test-1` (9190).
- No secret values printed; `docker/.env` never read for display.

## Discoveries

- `RUNTIME_DISCOVERY` (reusable): this stack's server image runs JIT from `/app/apps/server`
  source, so a shipped co-located `*_test.dart` under `lib/` can be executed inside the deployed
  container (`docker exec -w /app/apps/server <server> dart test <file>`) — artifact-level
  behavioural proof of a deployed fix without a live pipeline trigger or repo writes. Dev deps
  (`test` package) are present in the image's pub-cache.
- `PROJECT_FACT`: live QA-contract re-evaluation cannot be induced by the deploy lane alone —
  all drain entry states are gated by human decisions; verification combines artifact-level test
  execution with durable producer-role rows.

# Subtask Report — integrate-zombie-exec-orphan

```yaml
RESULT: MERGE_APPROVED
TASK_ID: integrate-zombie-exec-orphan
TASK_TYPE: integrate
FEATURE: F-235 — zombie reclaim retires agent_execution + wired at 5 Scheduler sites
WORKTREE: /private/tmp/shipit-fix-zombie-exec + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/zombie-exec-orphan
BASE_SHA: da62a2d
HEAD_SHA: b2fe008
COMMITTED: NO   # integrator commits nothing; rehearsal commit is odb-only, never on a branch
```

## Verification of the approved revision

- Approved HEAD `b2fe008fa30ac07351aad180047b917d3f2b3dc9` confirmed: worktree `/private/tmp/shipit-fix-zombie-exec` sits at exactly that SHA on `fix/zombie-exec-orphan`, two commits (`74a7d2e` reclaim + `b2fe008` wiring) on base `da62a2d`. HEAD was not advanced after approval.
- Current `main` = `c850e7dc9104b74c1e96bbd1bee18927270f026a`. `da62a2d` is an ancestor; main advanced 3 commits past the base — all dispatch/ledger docs (`LANES.md`, task prompts). Zero overlap with the 10 files this change touches.
- Rehearsal via `git merge-tree --write-tree c850e7d b2fe008`: **clean**, result tree `d1e4d7ab484dfb5c84366f44a0f57a5a535afcd2`, materialized as detached commit `7d1bf27` in a scratch worktree (removed after gates). All **10 reviewed blobs verified IDENTICAL** in the merged tree vs the approved HEAD — the review evidence carries over byte-for-byte.
- `origin/main` = `f58d6fb` (local main is 537 ahead — the orchestrator-ledger workflow makes local main the integration target; `origin/main` is an ancestor of it).

## Validation results (all gates run on the MERGED tree, rehearsal commit 7d1bf27)

| Command | Status | Evidence / note |
|---------|--------|-----------------|
| `dart format --output=none --set-exit-if-changed .` (repo root) | pass | 1089 files, 0 changed, exit 0 |
| `dart analyze` (packages/scheduler) | pass | exit 0, no issues |
| `dart analyze` (packages/worker_runtime) | pass | exit 0, no issues |
| `dart analyze` (apps/server) | pass | exit 0 — `server.dart` is one of the touched files, analyzed for completeness |
| `dart test` (packages/scheduler) | pass | exit 0, includes new `scheduler_zombie_reclaim_test.dart` |
| `dart test` (packages/worker_runtime) | pass with isolate-rerun | suite run: 2 failures, both the declared `worker_lease_bound`/`onboarding_lease_bound` environmental family (`Expected executedPass / Actual timedOut`, plus a shifted-await assertion under load); quiet isolated rerun of both files after all concurrent load finished: **12/12 pass, exit 0** — matches the review's pre-existing-flake verdict confirmed on base |
| `dart run tool/run_unit_tests.dart` (apps/server) | pass | "73 files, all passed" — includes new `composition_wiring_test.dart` guard |
| `SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration` (repo root) | pass | `+319: All tests passed!`, exit 0; disposable project `shipit_integration_21102` fully removed (container + network). **Needed**: `_reclaimZombie` retires the `agent_execution` row through the DB-facing `AgentExecutionRetirement` seam — the merge/release tier is the only gate that exercises it against real Postgres |
| build | n/a | no separate build gate exists in repo policy; Dart packages are validated by analyze+test; merge/release tier is integration |

## Disposition of review follow-ups

- Residual adopt-path hole: filed by the reviewer as non-blocking — unchanged by integration; merge does not regress it.
- `worker_lease_bound` env flake: observed, isolated, confirmed green in quiet rerun; remains pre-existing on base.

## Files touched by this lane

```text
docs/engineering/dispatch/tasks/integrate-zombie-exec-orphan/report.md   (this report only)
```

No merge performed. No push. No production code modified. Docker used only via the named `make test-integration` exemption; its disposable Postgres self-removed.

## Cleanup confirmation

- [x] All gate processes finished; none left running.
- [x] Scratch rehearsal worktree `/private/tmp/shipit-integrate-rehearsal` removed; rehearsal commit `7d1bf27` is odb-only, on no branch.
- [x] `/private/tmp/shipit-fix-zombie-exec` still at `b2fe008`, `git status` clean.
- [x] No files modified outside the dispatch task directory.

## Recommended next action

`MERGE` — clean non-fast-forward merge of `fix/zombie-exec-orphan` (`b2fe008`) into `main` (`c850e7d`); disjoint paths, merge rehearsed clean.

```text
RESULT: MERGE_APPROVED | INTEGRATION_BLOCKED

APPROVED_HEAD: b2fe008fa30ac07351aad180047b917d3f2b3dc9
CURRENT_MAIN: c850e7dc9104b74c1e96bbd1bee18927270f026a

GATES:
format=pass (root, 1089 files, 0 changed)
analyze=pass (scheduler, worker_runtime, apps/server — all exit 0)
tests=pass (scheduler dart test exit 0; worker_runtime dart test — 2 lease-bound env-flake failures under concurrent load, quiet isolate-rerun 12/12 exit 0; apps/server run_unit_tests 73 files all passed)
build=n/a — no separate build gate; merge-tier integration suite PASS (+319, disposable Postgres removed)

PROVENANCE: branch fix/zombie-exec-orphan at approved HEAD b2fe008 (2 commits on base da62a2d); main advanced 3 docs-only commits since base with zero path overlap; rehearsal merge clean (tree d1e4d7a, commit 7d1bf27); all 10 reviewed blobs identical in merged tree; origin/main f58d6fb is an ancestor of local main.

READY_FOR_INTEGRATION: YES — safe strategy: standard non-fast-forward merge (rehearsed clean; rebase+ff equally clean given disjoint paths). Human/orchestrator merge authority still required — this lane performed no merge and no push; actual integration into main and any subsequent push remain the Manager's/human's act.
```

RESULT: MERGE_APPROVED

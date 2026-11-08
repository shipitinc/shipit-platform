```yaml
RESULT: MERGE_APPROVED
TASK_ID: integrate-cas-transient
TASK_TYPE: integrate
FEATURE: F-241 CAS loss → TRANSIENT
WORKTREE: /private/tmp/shipit-fix-cas (+ disposable rehearsal /private/tmp/shipit-merge-rehearsal, removed)
BRANCH: fix/cas-transient
BASE_SHA: abcbbd4
HEAD_SHA: f3b4643
COMMITTED: NO
```

APPROVED_HEAD: f3b46432daa2a9e90e4a1cffa76cc3f9267dfd73 ("Classify store compare-and-swap
losses as transient, not permanent") — verified: `/private/tmp/shipit-fix-cas` HEAD is exactly this
SHA, worktree clean, merge-base with main is the declared base `abcbbd4`.

CURRENT_MAIN: 12640982854cf4b252942fa244f92db69ac05952 (one ledger/docs commit ahead of the
`c7f9550` recorded at dispatch; `origin/main` is f58d6fb, 503 behind local — this repo does not
push routinely). Main advanced only on `docs/engineering/` ledger/dispatch files since base —
zero overlap with the 10 changed package files.

MERGE REHEARSAL: `git merge-tree --write-tree main f3b4643` → tree `51d542f`, zero conflicted
paths; repeated as a real `--no-commit` merge in a disposable worktree — automatic merge clean.
All 10 reviewed blobs are byte-identical between approved HEAD and the merge-result tree
(diff `f3b4643..51d542f` under `packages/` is empty). Integration strategy: ordinary merge
commit onto main (no fast-forward possible — main diverged; a rebase would be equally trivial
since there is no file overlap, but merge preserves reviewed history).

GATES (all run on the merged tree, not the branch tip):

| Command | Status | Evidence |
|---------|--------|----------|
| `dart format --output=none --set-exit-if-changed .` (repo root) | pass | 1079 files, 0 changed |
| `dart analyze` (packages/scheduler) | pass | No issues found |
| `dart analyze` (packages/worker_runtime) | pass | No issues found |
| `dart test` (packages/scheduler) | pass | +452, "All tests passed!" |
| `dart test` (packages/worker_runtime) | pass | +56 ~1 skip (opt-in SHIPIT_REAL_OPENCODE), exit 0 |
| `SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration` | pass | +319, "All tests passed!", INTEG_EXIT=0; disposable project `shipit_integration_19731` removed by trap, 0 leftover containers/volumes |

make test-integration — RUN, not deferred. Reasoning: the branch touches no `apps/server` code,
but the server loads `worker_runtime`/`scheduler` via workspace path deps, and the production
trigger this change classifies — `apps/server/lib/src/persistence/postgres_worker_store.dart`
throwing `ConcurrentWorkerModificationException` — only exists under a real Postgres CAS race
(`concurrency_persistence_test.dart` exercises it). This is the merge/release-tier gate this
lane owns. It is the only sanctioned Docker operation; no other Docker commands were issued, no
DB was touched outside it.

PROVENANCE: branch `fix/cas-transient` @ f3b4643, base abcbbd4 (ancestor of main), review
verdict APPROVE_WITH_NON_BLOCKING_FOLLOWUP (1 MEDIUM latent filed F-243 — product_registry CAS
coverage; LOW: pubspec newline, doc comment) — non-blocking, does not gate integration.

UNRESOLVED ISSUES: none blocking. F-243 tracks the latent product_registry CAS coverage gap.
No files modified outside the rehearsal worktree; rehearsal worktree removed, canonical tree
clean (pre-existing untracked reports from other lanes only).

READY_FOR_INTEGRATION: YES — safe strategy is a merge commit of `f3b4643` onto `main` (1264098);
rehearsal shows a clean automatic merge with all reviewed blobs identical. Per repository policy
production promotion is human-authorized: this lane stops at merge-readiness — an actual merge
and any push still require human/deployment authority. Recommended next action: MERGE.

RESULT: MERGE_APPROVED

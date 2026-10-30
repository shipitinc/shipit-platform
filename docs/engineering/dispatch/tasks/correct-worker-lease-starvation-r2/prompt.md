# Dispatch — correct-worker-lease-starvation-r2 (correction loop cycle 2)

```yaml
MANAGER: orchestrator-main
TASK_ID: correct-worker-lease-starvation-r2
TASK_TYPE: correct
FEATURE: F-226 worker-lease starvation — fence mid-stage resume writes
AREA: worker_runtime / local worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-worker-lease-starvation
BRANCH: fix/worker-lease-starvation
BASE_SHA: fb8dde3
CORRECTED_HEAD: 98bdca857901b3925e757223c039fec6ff66b276
OWNED_PATHS:
  - packages/worker_runtime/**
READ_ONLY_PATHS:
  - packages/scheduler/**
  - packages/platform_contracts/**
PROHIBITED_PATHS:
  - everything outside packages/worker_runtime/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .   # worktree root
  - dart analyze                                       # packages/worker_runtime
  - dart test                                          # packages/worker_runtime
ROUTING_CLASS: PRECISION
```

## Focused re-review findings to correct (DO_NOT_APPROVE_CORRECTIONS on 98bdca85, verbatim)

The checkpoints fence a drive stale *on arrival*, but a drive abandoned **while wedged inside a
stage** still performs the next *fresh* store write after its await resumes — and
`_setCleanup`/`_transition`/`_event` write with no `expectedVersion` (blind upsert):

1. **`local_worker.dart:799 / :815`** — `_finalCleanup`/`_cleanupAfterFailure` run
   `await workspaceManager.cleanup(descriptor)` then `await _setCleanup(...)`. A drive non-stale at
   checkpoint :703 that wedges inside the cleanup await is abandoned; the detached resume then
   blind-upserts `execution.copyWith(cleanupStatus: status, ...)` with stale `status=agentExecuting`,
   `endedAt=null` — **resurrecting the terminal `timedOut` row to non-terminal**, unconditionally.
2. **`local_worker.dart:846`** — `_finish`: abandonment while wedged in `readWorkerExecution`/inside
   `inTransaction` can still land the CAS after resume (re-read already saw post-abandon version) →
   terminal + result + event overwrite.
3. **Minor:** `verificationStarted` event (:590) and `artifactCommitFailed` event (:667) remain
   reachable as fresh post-resume writes.

The correction's stated invariant — "every write it could make afterwards is epoch-fenced" — is
false for these writes.

**Reviewer's suggested fix shape (advisory):** re-check `_isStale(epoch)` between the cleanup await
and `_setCleanup` in `_finalCleanup`/`_cleanupAfterFailure` (or thread `epoch` into
`_setCleanup`/`_transition` with null = legitimate writer, as `_finish` does); same before
`verificationStarted`; a second staleness check inside `_finish` immediately before `inTransaction`
to shrink the CAS window. Extend the regression test to wedge inside `workspaceManager.cleanup` and
assert the row stays `timedOut`.

## Rules

- NEW commit on top of `98bdca85` — never amend/rebase (provenance). No push.
- Same class elsewhere in the file (e.g. the `prepare`/`_transition(agentExecuting)` writes at
  :500-501 the reviewer flagged as same-class): fence if inside the same mechanism's reach; if it
  genuinely requires restructuring, report it instead of half-doing it.
- No docker, no DB. Report per subtask-report.md: `RESULT: CORRECTION_COMPLETE` /
  `CORRECTION_BLOCKED`, NEW_HEAD, `READY_FOR_FOCUSED_REVIEW: YES|NO`.

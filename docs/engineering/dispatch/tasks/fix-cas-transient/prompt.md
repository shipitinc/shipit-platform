# Dispatch — fix-cas-transient (F-241)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-cas-transient
TASK_TYPE: implement
FEATURE: F-241 CAS loss misclassified as PERMANENT job failure
AREA: scheduler failure classification / retry policy
WORKTREE: /private/tmp/shipit-fix-cas
BRANCH: fix/cas-transient
BASE_SHA: HEAD
OWNED_PATHS: [packages/scheduler/**, packages/worker_runtime/**]
READ_ONLY_PATHS: [packages/platform_contracts/**, apps/server/lib/**]
PROHIBITED_PATHS: [apps/server/**, .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root), dart analyze + dart test (packages/scheduler AND packages/worker_runtime)]
ROUTING_CLASS: STANDARD
```

## Confirmed defect (live on QA)
6 jobs failed `Concurrent modification of <item|execution> (expected version N, actual N+1)` →
`executionFailed` PERMANENT. A CAS loss means another writer already advanced the row — inherently
TRANSIENT; the job should retry, not fail terminally. Under F-237 detached dispatch, the detached
continuation + tick + reconcile write the same entities concurrently, producing CAS races the
old in-tick flow never had.

## Task
Find where the `ConcurrentModificationException`/version-mismatch error is classified to
`JobFailureKind.permanent` (RetryPolicy.classify in packages/platform_contracts — read it; the
misclassification likely happens where the exception is caught and mapped to a failure code —
`scheduler.dart` `_settleDetachedRun`/`revertToQueued`/execution-driver error mapping, or
worker-side result classification). Change the classification so CAS/version-mismatch losses map
to `transient` (retryable) — NOT permanent. Do NOT weaken the CAS itself (it's correct protection;
the classification of LOSING it is the bug). Regression test: a job whose settle hits a CAS loss
is classified transient/requeued, not terminal-failed.

## Rules
New commits on the branch; no push; no docker/DB. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.

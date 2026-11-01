# Dispatch — review-cas-transient (F-241)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-cas-transient
TASK_TYPE: review
FEATURE: F-241 CAS loss → TRANSIENT (was misclassified permanent)
AREA: scheduler retry classification + worker_runtime catch sites
WORKTREE: /private/tmp/shipit-fix-cas
BRANCH: fix/cas-transient
BASE_SHA: abcbbd4
HEAD_SHA_UNDER_REVIEW: f3b46432daa2a9e90e4a1cffa76cc3f9267dfd73
ROUTING_CLASS: STANDARD
```

Independent read-only review. The implementer introduced a `store_contention:` marker +
`isStoreContentionError`/`isStoreContentionDetail` predicates (worker_runtime/store_contention.dart,
exported); LocalWorker's catch-all now marks item/agent-execution CAS losses with the marker (and a
dedicated rethrow for ConcurrentWorkerModificationException so the winning verdict isn't clobbered);
`RetryPolicy.classify` re-checks the marker → transient; baseline_dispatch CAS → OnboardingFaulted
transient. Verify:
1. CAS ITSELF is untouched — the fix only changes classification of LOSING the CAS, never the
   optimistic-concurrency protection.
2. Marker correctness: `isStoreContentionDetail` matches only the CAS family (typed exceptions
   thrown for concurrent writes), never a legit permanent failure detail — a false-positive match
   would retry a real bug forever.
3. The dedicated rethrow for ConcurrentWorkerModificationException — verify `_settleDetachedRun`'s
   claim-release + reconcile-adoption path genuinely recovers the winning verdict, not a hang.
4. No retry-forever regression: unmarked `executedFail` still permanent (the guard is preserved).
5. The new `store_contention:` marker has a single literal (compile-time shared via worker_runtime
   dep — verify scheduler↔worker_runtime dep direction is legal, no cycle).
6. Tests non-vacuous: the worker test throws the REAL store exception types through the real
   coordinator; classify pins marked→transient + unmarked→permanent; settle→retryWaiting→requeue.
7. Re-run gates yourself: format (root), analyze + dart test (scheduler AND worker_runtime) —
   own numbers. The one full-suite flake the implementer reported (lane_j_execution_reference)
   — if it fails for you, check whether it's pre-existing timing (their note says it passes
   standalone + rerun).
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.

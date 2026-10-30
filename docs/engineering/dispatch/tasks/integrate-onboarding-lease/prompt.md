# Dispatch — integrate-onboarding-lease

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-onboarding-lease
TASK_TYPE: integrate
FEATURE: F-232 OnboardingWorker lease bound
WORKTREE: /private/tmp/shipit-fix-onboarding-lease + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/onboarding-worker-lease-bound
BASE_SHA: 128c721
APPROVED_HEAD: 75d206c081baa554890eb409c0b74ca2797e10ba
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (4 LOW, none gating)
CURRENT_MAIN: 9d4ece6
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
merge rehearsal into current main clean with reviewed blobs identical (only
packages/worker_runtime/onboarding_worker.dart + onboarding_lease_bound_test.dart — path-disjoint
from the merged F-226/F-227 work); gates on merged tree: `dart format --set-exit-if-changed .` (root),
`dart analyze` + `dart test` packages/worker_runtime; state `make test-integration` run or deferred.
No docker, no DB. Report per subtask-report.md ending exactly `RESULT: MERGE_APPROVED` or
`RESULT: INTEGRATION_BLOCKED`.

# Dispatch — correct-f237-integration-tests

```yaml
MANAGER: orchestrator-main
TASK_ID: correct-f237-integration-tests
TASK_TYPE: correct
FEATURE: F-237 detached dispatch — migrate test/integration suite to settle path
AREA: apps/server integration tests consuming scheduler settle semantics
WORKTREE: /private/tmp/shipit-f237-integration-settle
BRANCH: fix/f237-integration-settle
BASE_SHA: 6fcb630
OWNED_PATHS:
  - apps/server/test/integration/**
  - apps/server/test/support/**
READ_ONLY_PATHS:
  - packages/scheduler/lib/src/scheduler.dart
  - packages/scheduler/test/support/settle.dart
  - apps/server/test/support/settle.dart
  - apps/server/lib/server.dart
PROHIBITED_PATHS:
  - everything else, incl. apps/server/lib/** and packages/**/lib/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .   # worktree root
  - dart analyze                                       # apps/server
  - dart run tool/run_unit_tests.dart                  # apps/server — must stay 69 green
  - SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration  # THE gate
ROUTING_CLASS: STANDARD
```

## Integrator/deploy finding (make test-integration RED at HEAD, verbatim signature)

35 failures across 4 files: `design_governance_e2e_test.dart` (5), `e2e_restart_persistence_test.dart`
(1), `lane_f_production_reachability_test.dart` (4), `triage_execution_test.dart` (25). Uniform:
`Expected: JobState.succeeded / Actual: JobState.running` (triage_execution_test.dart:2463,
e2e_restart_persistence_test.dart:418), `Expected: AgentSessionStatus.completed / Actual:
AgentSessionStatus.running` (design_governance_e2e_test.dart:350). Plus teardown noise
`Session or transaction has already finished` in `purgeSuiteRows` — detached executions outlive
session disposal; handle settle BEFORE teardown so nothing is left running at purge time.

## Task

Migrate the failing integration tests to the reconcile-adoption settle path — the same two-step the
unit suites now use (`apps/server/test/support/settle.dart` exists: `waitUntil`/`settleHeldJobs`;
mirror it for integration usage — the suite runs against real Postgres, so claim-release polling hits
the real store). Assert the SAME observable outcomes; no weakening, no skipping, no
timeout-as-assertion. Also fix the teardown leak: tests must settle (or explicitly terminate) every
detached execution they start before disposing the session — an execution left running at teardown
IS a leak.

If ANY failing test reveals a REAL defect rather than a stale assertion (e.g. a job that can never
settle, a reconcile that fails to adopt a real terminal execution), STOP and report
`CORRECTION_BLOCKED` with the evidence — do not paper over it.

## Rules

- New commits on `fix/f237-integration-settle`; no push. `make test-integration` is the ONLY
  sanctioned docker usage (sanctioned disposable-Postgres path per AGENTS.md) — nothing else.
- Report per subtask-report.md: `RESULT: CORRECTION_COMPLETE` / `CORRECTION_BLOCKED`, NEW_HEAD,
  verbatim gate tallies (before + after), `READY_FOR_FOCUSED_REVIEW: YES|NO`.

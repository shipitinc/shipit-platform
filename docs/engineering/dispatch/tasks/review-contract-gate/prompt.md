# Dispatch — review-contract-gate (F-242)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-contract-gate
TASK_TYPE: review
FEATURE: F-242 contractless items defer (precondition before agent work consumed)
AREA: implementation readiness + scheduler workload resolver (server)
WORKTREE: /private/tmp/shipit-fix-contract-gate
BRANCH: fix/contract-gate
BASE_SHA: abcbbd4
HEAD_SHA_UNDER_REVIEW: 375e94c695374af2bd84ab94f1cde7035f6cf114
ROUTING_CLASS: STANDARD
```

Independent read-only review of the contract-gate deferral (files: implementation_readiness_probe.dart
gate 2; NEW qa_contract_dispatch_gate.dart; server.dart wired workloadResolvers on sched-triage +
sched-design-revision; 2 test files + new qa_contract_dispatch_gate_test.dart). Verify:
1. Deferral happens BEFORE agent work consumed — the WorkloadResolver seam returns null for
   contractless items (never dispatches a job) vs the probe gate. Both consume the SAME
   `workItemCarriesQaContract` predicate (null OR blank → contractless). Verify predicate matches
   qa_drain's own read.
2. The probe gate-order renumbering didn't break earlier gates (governed → qa-contract → onboarding
   → durable clone); totality enumeration covers the new guarded read.
3. The named deferral events emit correctly per lane (`implementation/triage/design_revision.
   deferred.qa_contract_missing`); deferred jobs land `blockedArtifactMissing` resumable.
4. Scope widening is sound: F-242 named implement jobs but deferral was wired on triage +
   design-revision too — verify those lanes are contractless-reachable and the same-seam wiring is
   correct, not over-reach. Reviewer lanes can't enter agentCompleted (contract needed upstream) —
   confirmed unaffected.
5. No bypass: human-decision rework/reject routes target implementationReady → probe gates them;
   no scheduler path dispatches contractless work.
6. Tests non-vacuous: real-Scheduler e2e ticks prove contractless items never dispatch while
   contracted siblings do; the kGatedSources repair is correct (verified the new files pass the
   gate, not masked).
7. Re-run gates yourself: format (root), `dart analyze` + `dart run tool/run_unit_tests.dart`
   (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.

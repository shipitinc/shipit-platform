# Dispatch — review-qa-feature-gates (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-qa-feature-gates
TASK_TYPE: review
FEATURE: Producer-aware QA gate evaluation — triage-shaped gate returns notApplicable for non-triage producers
AREA: QA gate evaluation / producer scoping
WORKTREE: /private/tmp/shipit-fix-qa-gates
BRANCH: fix/qa-feature-gates
BASE_SHA: 5a2ef09
HEAD_SHA_UNDER_REVIEW: c58352a264bf7ff745de88c595828c24da6fd167
ROUTING_CLASS: PRECISION
```

Independent read-only review of `c58352a` — `ProducerRoleScopedGate` decorator replaces the
`triage-classification-structure` evaluator in `buildProductionGateRegistry`: it resolves the
producer's `AgentExecution.role` via `ProducerWorkspaceResolver` and returns
`QAGateStatus.notApplicable` for non-triage roles, delegates to the real gate for triage, and
delegates (fail closed) when the role is unresolvable.

Verify rigorously:
1. The mechanism — the decorator is registered AFTER `buildGateRegistry` so it replaces the plain
   evaluator under the same type key; the producer resolution uses the SAME rule the drain uses
   (ProducerWorkspaceResolver), not a second resolution path; `notApplicable` is a first-class
   satisfied status in `isGateSatisfied` AND the `all_required_gates_passed` guard (not a silent
   pass).
2. Fail-closed — role unresolvable → delegates to the real gate (no exemption); a malformed
   triage result still fails for triage producers; the four required implementation gates still
   apply (feature-change-committed, feature-change-scope-confined, feature-declared-checks-executed,
   feature-review-bound-to-revision) — verify this isn't a hole, the contract still has honest
   requirements for implementers.
3. Producer identity correctness — `resolveProducerExecution` returns the RIGHT execution (the
   item's producer, not a reviewer's result — the platform's own rule); a feature item's producer
   is the implementer (non-triage → notApplicable); a defect item's producer is triageDefect →
   the strict gate still applies.
4. No retro-fix needed claim — producer-aware evaluation makes persisted `qa-product-*`/
   `qa-triage-*` rows evaluate correctly without migration; verify the claim (the decorator
   wraps evaluation, not the stored contract).
5. The residual — manifest/gatesJson still over-declare the gate (over-declaration not removed);
   verify the implementer's claim that manifest scoping requires tests outside its owned paths
   is real, not a dodge.
6. Tests non-vacuous: producer_scoped_gate_test (7) covers feature-passes / triage-strict /
   non-triage-not-failed / unresolvable-fail-closed.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
   (apps/server + touched packages), `dart test` (producer_scoped_gate_test + qa_drain_reentry),
   `dart run tool/run_unit_tests.dart` (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.

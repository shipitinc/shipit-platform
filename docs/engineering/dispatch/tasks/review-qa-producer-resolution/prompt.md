# Dispatch — review-qa-producer-resolution (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-qa-producer-resolution
TASK_TYPE: review
FEATURE: resolveProducerExecution contract-aware — requiredRole scope resolves the right producer per contract type
AREA: QA drain producer resolution
WORKTREE: /private/tmp/shipit-fix-producer-res
BRANCH: fix/qa-producer-resolution
BASE_SHA: 00d236b
HEAD_SHA_UNDER_REVIEW: 1c37bf31baefc1cf7d6967340dfbce43760021e7
ROUTING_CLASS: PRECISION
```

Independent read-only review of `1c37bf3` — `resolveProducerExecution` now takes an optional
`requiredRole`: the stamped `producerActorId` wins only when it names an execution OF that role;
the fallback resolves the newest execution of that role (new `ProducerResolution.requiredRole`),
refusing when none exists. `ProducerWorkspaceResolver` derives the role from the item's
`qaContractId` (qa-triage-* -> AgentRole.triageDefect; all other contract ids -> platform
default), so a `qa-triage` contract evaluates the TRIAGE execution's result, a `qa-product` the
implementer's.

Verify rigorously:
1. The mechanism — the requiredRole scope: the stamp wins only when it names an execution of the
   required role (a re-stamped implementer no longer wins for a triage contract); the fallback
   resolves the newest execution of THAT role; refuses (doesn't silently return the wrong role)
   when none exists.
2. Contract-to-role mapping — `producerRoleForQaContractId` maps qa-triage-* -> triageDefect,
   all other ids -> platform default (implementer). Verify the mapping is right (does a
   qa-product contract resolve IMPLEMENTER? does the default cover every non-triage contract
   type honestly?) and that a contract id it doesn't recognise doesn't silently map wrong.
3. Consistency — the drain, the workspace sources, and `ProductionProducerRoleSource` all
   resolve through the same rule — the role ProducerRoleScopedGate reads is the role of the
   very result under evaluation (no two-resolution mismatch).
4. No signature break — `ProducerResolver`/`ProducerRoleSource` fakes in non-owned tests still
   compile (the optional param is backwards-compatible).
5. Tests non-vacuous — producer_execution_required_role_test (7 contract-scoped cases) +
   qa_drain_contract_producer_test (3 end-to-end drain cases) genuinely assert the triage
   contract sees the triage result; the mutation check (requiredRole disabled -> triage tests
   fail, qa-product still passes) is a real guard.
6. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
   + `dart test` (execution_coordinator + the qa drain co-located suites), `dart run
   tool/run_unit_tests.dart` (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:` — and flag the routed discovery (`QAContract.metadata.requiredRole`
declared but never read).

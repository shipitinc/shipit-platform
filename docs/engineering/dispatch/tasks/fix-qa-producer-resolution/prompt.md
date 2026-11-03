# Dispatch — fix-qa-producer-resolution (F-253)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-qa-producer-resolution
TASK_TYPE: implement
FEATURE: qa-triage contracts evaluate the wrong producer's result — resolveProducerExecution falls back to the newest implementer-role execution, handing an implementer's structuredResult to a triage contract
AREA: QA drain producer resolution
WORKTREE: /private/tmp/shipit-fix-producer-res
BRANCH: fix/qa-producer-resolution
BASE_SHA: HEAD
OWNED_PATHS: [packages/execution_coordinator/**, apps/server/lib/src/qa/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**, packages/platform_contracts/**, apps/server/lib/server.dart]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze + dart test (each touched package), dart run tool/run_unit_tests.dart (apps/server if touched)]
ROUTING_CLASS: PRECISION
```

## Confirmed defect (live — the drain's failing gate evaluations)

Defect items' `qa-triage-<id>` contracts keep failing `triage-classification-admitted` +
`triage-evidence-grounded` — but every input is correct: the evidence rows exist keyed to the
defect id, the gate's defectId resolution is right, and the TRIAGE result's `evidenceUsed` cites
the correct stored ids (`EVD-<defect>-1`/`-2`). The evidence check inputs all align — so the
failure is upstream: **the contract is evaluating the wrong execution's structuredResult.**

`resolveProducerExecution` (packages/execution_coordinator/lib/src/coordinator/producer_execution.dart:174):
stamped `producerActorId` wins; fallback is the newest **implementer-role** execution (the
QA-feature-gates review confirmed "a reviewer's result can never be read"). For a `qa-triage`
contract on a defect item, the producer whose output the triage gates check is the **TRIAGE**
execution — but if the item already ran an implementer (rework cycles), the implementer-role
fallback hands the implementer's result to the triage contract → the triage-shaped gates
(classification + evidence-grounded) evaluate a result with no triage fields → fail "cites no
evidence" / missing classification — even though the triage's own output was correct. That's the
churn loop: defect items cycle approve -> implement -> contract fails on the wrong producer ->
waiver -> reject -> re-implement.

## Task — verify then fix honestly

1. VERIFY first: for a `qa-triage-<id>` contract, does `resolveProducerExecution` (or the drain's
   `ProducerWorkspaceResolver`) actually return the TRIAGE execution's result, or does the
   implementer-role fallback return an implementer's result? Read `resolveProducerExecution` and
   `ProducerWorkspaceResolver` — the contract type (qa-triage vs qa-product) should determine
   WHICH role's execution is "the producer" (triage contract -> TRIAGE_DEFECT execution;
   product/feature contract -> IMPLEMENTER execution). If the resolution is contract-blind
   (always returns the newest implementer-role), that's the defect.
2. Fix honestly — the contract being evaluated knows which producer's output its gates check:
   a `qa-triage` contract's gates are about triage output, so the producer is the TRIAGE
   execution; a `qa-product` contract's gates are about implementation output, so the producer
   is the IMPLEMENTER. The resolution should be contract-aware (or the drain should resolve the
   right producer per contract type), not a flat "newest implementer-role" fallback. If the
   stamped `producerActorId` is set, it may already be right — verify when it's set vs absent.
3. Regression test: a `qa-triage` contract evaluates the TRIAGE execution's result (not an
   implementer's) — the triage gates see the triage-shaped structuredResult; a `qa-product`
   contract still evaluates the implementer's. An item with both executions resolves the right
   one per contract.
4. Report whether the stamped producerActorId is set for triage executions or absent (which
   falls to the implementer fallback).

## Rules
New commits; no push; no docker/DB writes (read-only DB inspection to map the resolution OK);
nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED if it needs composition outside owned paths.
Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
`READY_FOR_INDEPENDENT_REVIEW:`, `ROOT CAUSE:`, `RESOLUTION NOW CONTRACT-AWARE:`.

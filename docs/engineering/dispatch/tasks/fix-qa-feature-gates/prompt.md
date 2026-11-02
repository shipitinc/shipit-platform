# Dispatch — fix-qa-feature-gates (F-246)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-qa-feature-gates
TASK_TYPE: implement
FEATURE: Feature QA contracts are unsatisfiable — intake-structured-result-admitted requires triage-shaped fields the implementer never emits
AREA: QA contract spec / gate evaluation
WORKTREE: /private/tmp/shipit-fix-qa-gates
BRANCH: fix/qa-feature-gates
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/qa/**, apps/server/manifests/**, packages/platform_contracts/**, packages/workflow_engine/**]
READ_ONLY_PATHS: [packages/workflow_store/**, apps/server/lib/server.dart]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/** (generated only if mechanical regen)]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (each touched package), dart test (each touched package), dart run tool/run_unit_tests.dart (apps/server)]
ROUTING_CLASS: PRECISION
```

## Confirmed defect (live — the drain-loop implementer verified it against the shipped manifest)

`intake-structured-result-admitted` is type `triage-classification-structure` — it requires
`classification`, `status`, `confidence`, `suspectedCategory` + `DefectClassification`/
`DefectStatus` enums on the producer's `structuredResult` — fields ONLY a triage execution emits.
An implementation-produced feature item (e.g. `WI-feature-1791823723502264`, contract
`qa-product-WI-feature-1791823723502264`) can NEVER satisfy it — the feature contract is
mis-specified; feature items are permanently undrainable except by human waiver.

`92d567e3` kept the gate deliberately; F-93/F-105 record the tension. This is now a live product
decision the human directed fixed: "let's fix the qa issues so features work."

## Task — investigate then fix honestly

1. Map where the gate set comes from: `product_qa_contract_spec.gatesJson` / the shipped
   `shipit-platform.product-manifest.json` — is `intake-structured-result-admitted` declared
   per-contract, or applied globally? Which contract(s) (qa-product-*, qa-triage-*) include it?
2. The fix, honestly:
   - If the gate is triage-shaped by design, it belongs on TRIAGE contracts only — a feature/
     product contract should carry gates the implementer can actually satisfy (validation
     outcomes, owned-path conformance, evidence-grounded for implementation output).
   - Decide whether the fix is: remove/scope the gate to triage contracts in the spec/manifest,
     OR make the gate evaluator producer-aware (apply only when the producer is a triage
     execution), OR replace it with an implementation-appropriate structural gate. Verify which
     is correct — a feature contract with no honest gates isn't a fix, it's a hole.
   - Existing minted contracts (qa-product-*, qa-triage-* rows already persisted) carry the bad
     gate — a spec fix doesn't retro-fix them. The two parked items' waiver decisions are
     pending on contracts that can never pass; report whether existing contracts need
     re-minting/repair (and how — sanctioned path vs ops), or whether the gate evaluation can
     be made producer-aware so the same contract passes for an implementer.
3. Verify `triage-classification-admitted`/`triage-evidence-grounded` are satisfiable on defect
   triage contracts (the implementer reported they are — confirm).
4. Regression test: a feature item's contract evaluates with gates the implementer can satisfy
   (not unsatisfiable-on-shape); the triage contract still applies the triage gate to triage
   output; a non-triage producer isn't failed for lacking triage fields.
5. Report ROOT CAUSE + the fix chosen + whether existing contracts need repair + how.

## Rules
New commits; no push; no docker/DB writes (read-only DB inspection OK to map the spec/contract
rows); nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED if it needs composition outside
owned paths or a contract-row repair outside a code change. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`,
`ROOT CAUSE:`, `EXISTING CONTRACTS NEED REPAIR:`.

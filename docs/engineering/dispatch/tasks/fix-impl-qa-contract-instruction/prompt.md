# Dispatch — fix-impl-qa-contract-instruction (F-248)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-impl-qa-contract-instruction
TASK_TYPE: implement
FEATURE: implement_feature instruction tells the agent to read a DB-resident QA contract id it cannot reach — drives outside-path reach -> permission deny -> end_turn -> missing artifact
AREA: scheduler instruction construction
WORKTREE: /private/tmp/shipit-fix-contract-instr
BRANCH: fix/impl-qa-contract-instruction
BASE_SHA: HEAD
OWNED_PATHS: [packages/scheduler/**]
READ_ONLY_PATHS: [apps/server/lib/**, packages/agent_runtime/**, packages/execution_coordinator/**, packages/workflow_engine/**]
PROHIBITED_PATHS: [apps/server/**, .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze + dart test (packages/scheduler)]
ROUTING_CLASS: PRECISION
```

## Confirmed defect (live + the missing-artifact lane's diagnosis)

`packages/scheduler/lib/src/implement_feature.dart:203` injects `QA CONTRACT: $qaContractId —
the acceptance criteria there are the ones this run is judged against` — but the contract is
**DB-resident** (`product_qa_contract_spec`/`qa-product-<id>`), NOT reachable from the agent's
worktree. The F-247 diagnosis proved this is the demonstrated trigger: the deepseek implementer
provably burned its turn hunting the DB-resident contract it cannot read -> `external_directory`
permission ask -> denied -> `end_turn` -> missing artifact. sonnet-5.5 failed identically.

## Task — fix the instruction honestly, not just delete the reference

1. Decide the honest fix:
   - INLINE the contract's acceptance criteria into the instruction (the agent gets what it
     actually needs — the criteria it will be judged against — if they're retrievable at
     instruction-build time), OR
   - Keep the reference but tell the agent the contract id is informational/not readable (stop
     it from hunting), OR
   - Whatever is correct — the requirement is the agent gets the contract's acceptance criteria
     in reach (it can't satisfy what it can't read), OR the instruction stops telling it to read
     an unreachable artifact.
   Verify which is feasible: is the contract spec retrievable at instruction-build time
   (implement_feature.dart constructs the instruction — can it pull the criteria)?
2. Verify the same defect doesn't exist in the other role instructions (triage, reviewer,
   remediation) — do they also name DB-resident artifacts the agent can't read?
3. Regression test: the instruction either inlines the criteria or no longer tells the agent to
   read an unreachable artifact; the criteria are genuinely present when inlined.
4. Report the fix chosen + whether other role instructions share the defect.

## Rules
New commits; no push; no docker/DB writes; nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED
if it needs composition outside `packages/scheduler/**`. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`,
`FIX CHOSEN:`, `OTHER ROLES AFFECTED:`.

# Dispatch — review-impl-qa-contract-instruction (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-impl-qa-contract-instruction
TASK_TYPE: review
FEATURE: implement_feature instruction no longer sends the agent hunting a DB-resident QA contract
AREA: scheduler instruction construction
WORKTREE: /private/tmp/shipit-fix-contract-instr
BRANCH: fix/impl-qa-contract-instruction
BASE_SHA: 975d145
HEAD_SHA_UNDER_REVIEW: eb58bf8a706836723fc7e12ad63bc1c173ecd8ff
ROUTING_CLASS: PRECISION
```

Independent read-only review of `eb58bf8` — `implement_feature.dart`'s instruction now reads "QA
CONTRACT: <id> — informational only. It names a platform-side record in the control-plane
database, not a file in this worktree, and it cannot be opened from where you are working — do
not look for it. The criteria this run is judged against that you can act on are already above:
the DESCRIPTION, the ACCEPTANCE CRITERIA when present, and these WORKING INSTRUCTIONS. The
platform evaluates your committed change against that contract itself after you finish."

Verify rigorously:
1. The fix is honest — the contract id is kept as informational provenance but explicitly marked
   unreachable with the hunt forbidden and the in-reach criteria named (DESCRIPTION +
   ACCEPTANCE CRITERIA + WORKING INSTRUCTIONS). Verify the wording actually tells the agent what
   to do (the criteria it can act on are named), not just "don't look."
2. The inlining-infeasible claim — the implementer asserts `InstructionBuilder` is
   `String Function(WorkItem, JobDefinition)` (synchronous, no store) so inlining the contract
   row would need the typedef + composition root (outside ownership), AND the contract carries
   no agent-facing prose (its gates are platform-side declarations — implementation-artifact-
   provenance, change-scope-confinement, declared-validation-outcome, revision-identity-match).
   Verify both: (a) the InstructionBuilder signature genuinely has no store access; (b)
   `buildProductQAContract`'s gates really are platform-side, not prose the agent could use.
   If the implementer could have inlined the real criteria honestly and chose not to, that
   changes the fix's quality.
3. Other-role audit — verify the claim that triage/reviewer/remediation instructions don't share
   the defect (read the other instruction builders for DB-resident artifact references).
4. The routed discovery — `designReviewInstruction`'s reviewScope asks for run-identity values
   (design-revision-id, penpot ids) the agent may not supply — confirm it's a different defect
   class (asking for unknowable values, not telling it to read an artifact) and genuinely routed
   not silently fixed.
5. Tests — the new `implement_feature_prompt_contract_test.dart` (7 tests) is a real drift-
   guard that pins the unreachable-marking, not just a grep.
6. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
   + `dart test` (packages/scheduler, +468) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.

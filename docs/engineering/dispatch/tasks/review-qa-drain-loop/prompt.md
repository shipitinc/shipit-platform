# Dispatch — review-qa-drain-loop (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-qa-drain-loop
TASK_TYPE: review
FEATURE: qa.drain loop fix — idempotency keys scoped to qaAttempt, not the item forever
AREA: QA drain / idempotency
WORKTREE: /private/tmp/shipit-fix-drain-loop
BRANCH: fix/qa-drain-loop
BASE_SHA: 7ace9ef
HEAD_SHA_UNDER_REVIEW: 158d8317ec9026a7eab0fb2489b5fb7ed7ad38d2
ROUTING_CLASS: PRECISION
```

Independent read-only review of `158d831` — the root cause is subtle, verify it rigorously:

- The defect: `qa-drain:<id>:enter|settle|fault` idempotency keys were scoped to the work item
  FOREVER, but `reviewApproved` is re-enterable (rejected waiver → rework → re-review → approval).
  On re-entry `findTransitionByIdempotencyKey` replays the prior accepted `enter` record,
  `_enterQaInProgress` returns the item still at `reviewApproved`, and every downstream
  transition evaluates from a state with no edge out → decision_refused every tick.
- The fix: `qaAttempt` counter stamped atomically with the take (metadataMerge on
  reviewApproved → qaInProgress); keys now `qa-drain:<id>:{enter,settle,fault}:a<n>`;
  `readQaAttempt` mirrors `readTriageAttempt`; `qaFailed` added as a candidate arm for items
  stranded between settle-commit and decision-raise (escalated via the existing
  `qaFailed → waitingForHumanDecision` edge or re-raised).

Verify rigorously:
1. The mechanism claim — the implementer asserts `reviewApproved` is the drain's DESIGNED entry
   state (reviewApproved → qaInProgress exists, orchestrator-guarded, drain its only caller) and
   the refusal loop is the idempotency replay, not the edge. Verify the replay mechanism
   (findTransitionByIdempotencyKey returns the prior record → item not actually re-taken) and
   that the state at decision-raise time is genuinely reviewApproved.
2. The fix correctness — the qaAttempt stamp: is it really atomic with the take (metadataMerge on
   the same transition, not a separate write that could race)? keys a<n> scope per-attempt not
   forever; readQaAttempt handles int/double/numeric-string honestly (unreadable → reported skip,
   never a fallback guess); a first-attempt item (attempt unset) still works.
3. The qaFailed candidate arm — an item found at qaFailed with NO pending qaWaiver/qaRework gets
   escalated (existing pending decision reused, else raised) — verify it can't double-raise a
   decision (dedup on the existing pending one) and doesn't regress the normal path.
4. The contract finding — `intake-structured-result-admitted` requires defect-triage fields only
   triage emits; verify the claim (the shipped manifest's structural gate type +
   triage-classification-admitted/triage-evidence-grounded ARE satisfiable for triage output) —
   the product decision (should the structural gate apply triage shape to non-triage output) is
   correctly flagged not decided.
5. Tests non-vacuous: qa_drain_reentry_test (6) covers re-entry after a rejected waiver →
   second take works → decision raises; stranded qaFailed escalates; normal path unchanged.
6. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
   (apps/server), `dart test` the new test + qa_drain_test + `dart run tool/run_unit_tests.dart`
   (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.

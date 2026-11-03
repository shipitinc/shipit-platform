# Dispatch — review-missing-success-artifact (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-missing-success-artifact
TASK_TYPE: review
FEATURE: missing_success_artifact diagnosis + fix — denied-ask summary, getResult searches agent_message texts, denial-aware reason
AREA: agent runtime artifact/denial handling + success-artifact check
WORKTREE: /private/tmp/shipit-fix-artifact
BRANCH: fix/missing-success-artifact
BASE_SHA: 65c8a38
HEAD_SHA_UNDER_REVIEW: 94208c55bdb06458f39ba8ac56cc7a58d6ba1253
ROUTING_CLASS: PRECISION
```

Independent read-only review of `94208c5` — the implementer's diagnosis: the IMPLEMENTER missing-
artifact runs ended `end_turn` after exactly one denied `session/request_permission`
(external_directory on bash args resolving outside the worktree — the deepseek implementer was
hunting the DB-resident QA contract it can't read); REVIEWER runs had no denial — prose reviews
or mid-investigation stops with no JSON → output-contract noncompliance. Three real defects
fixed: (1) denied ask's content was discarded (only a counter survived); (2) `getResult` never
searched complete `agent_message` texts when chunks carried no JSON — an artifact on the wire
was dropped; (3) the missing-artifact reason claimed "the run finished cleanly" for runs the
platform interrupted with a refusal.

Verify rigorously:
1. The mechanism claims — (a) `opencode_process_transport` now carries a bounded `summary`
   (title/kind/input/metadata) on the `acp/permission_denied` signal — verify the ask content is
   captured honestly not leaked; (b) `opencode_session` persists denials to
   `AgentResult.metadata.permissionDenials` (cap 8) and `getResult` searches complete
   `agent_message` texts when the chunk stream carries none — verify the fallback is real not a
   double-read or a wire-ordering race; (c) `success_artifact` `denialsOf`/`denialTitles`/
   `denialClause` make the reason denial-aware and `details` carries `permissionDenials` — verify
   the reason no longer claims "finished cleanly" for refusal-interrupted runs.
2. The check is NOT suppressed — verdict stays `missing`, still permanent. Verify no escape hatch.
3. ESCALATE-ON-MISSING-ARTIFACT: NO — the implementer argues the provider answered
   (stopReason=end_turn, tokens consumed) and sonnet-5.5 failed identically → auto-escalation
   spends paid money without addressing the cause. Verify the reasoning (is
   missing_success_artifact genuinely a work-failure not a provider-failure for auto-escalation
   classification?).
4. The diagnosis itself — re-verify against the live failures' events that the denied-ask +
   end_turn signature holds (the implementer claims deepseek was hunting the QA contract).
5. Tests non-vacuous: denied-ask summary persisted, getResult falls back to agent_message text,
   the denial-aware reason.
6. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
   + `dart test` (agent_runtime + execution_coordinator) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:` — and flag the two routed discoveries (the DB-resident QA contract in
the instruction, retry-on-denial) for the orchestrator.

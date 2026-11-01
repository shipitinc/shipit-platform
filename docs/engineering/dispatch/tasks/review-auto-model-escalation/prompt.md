# Dispatch — review-auto-model-escalation (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-auto-model-escalation
TASK_TYPE: review
FEATURE: Automatic paid-model escalation on provider failure — no human escalation
AREA: provider-failure detection + auto escalationIndex (5 packages)
WORKTREE: /private/tmp/shipit-auto-escalation
BRANCH: feat/auto-model-escalation
BASE_SHA: 7ca2b49
HEAD_SHA_UNDER_REVIEW: cbd85bae4d20a057103068db25f6e5729d1b6895
ROUTING_CLASS: PRECISION
```

Independent read-only review of a PRECISION change across 5 packages (13 files):
- agent_runtime: StderrTail interface on acp_transport; OpenCodeProcessTransport implements it
  (stderr already buffered); opencode_session scans the stderr tail via _providerErrorFromStderr
  with quota-family patterns (usage limit/limit reached/insufficient_quota/out of credits/
  payment required), writes metadata['providerError'] to the durable AgentResult; never-settled
  sessions now honestly report partial/runtimeAnswered:false (was false-claiming completed:true).
- worker_runtime: NEW AgentResultReader port (NOT added to AgentExecutionDriver — apps/server
  doubles would break); provider_failure.dart (marker + predicates); LocalWorker interrupted
  path reads the durable AgentResult and stamps `provider_unavailable:` on failureDetail.
- scheduler: _adopt transient branch calls _applyProviderEscalation BEFORE scheduleRetry;
  bound = ModelSelectionService.escalationCeilingFor; CAS write; fail-open to unescalated.
- workflow_engine: escalationCeilingFor.

Verify rigorously:
1. DETECTION HONESTY — no fabricated events: the stderr scan reads a REAL buffered tail
   (opencode_process_transport already buffered it — verify the tail is real, not synthesized);
   unmatched tails record NOTHING (unknown ≠ evidence); an 'unknown' transport stamp is only
   upgraded by classified stderr evidence, never treated as provider-dead alone.
2. SIGNATURE CORRECTNESS — the zero-signal classifier: provider-dead = classified (non-unknown)
   providerError OR ALL-ZERO activity (0 chunks/0 tool calls/0 tokens). Ran-and-hung leaves
   nonzero counters → no marker. Null/unreadable result → NO marker (never spends paid tier
   on a guess). Verify a real code-defect timeout does NOT escalate.
3. ESCALATION BOUND — _applyProviderEscalation: bumps index only on provider-failure; bounded
   by escalationCeilingFor (chain length, NOT the decision-type guard); CAS write; fail-open
   to unescalated on any error; no infinite escalation; single-step chain → no bump.
4. The human-decision escalation path unchanged (additive only).
5. AgentResultReader is a NEW port (not a widening of AgentExecutionDriver — verify apps/server
   doubles can't break); the partial/runtimeAnswered:false honesty fix doesn't break consumers.
6. Tests non-vacuous: stderr-scan provider-error test; signature test (classified + zero-activity
   + non-provider cases); scheduler e2e (provider-dead → index 1 → retry picks chain[1];
   ordinary timeout → unchanged; ceiling respected).
7. Re-run gates: `dart format --set-exit-if-changed .` (root), `dart analyze` + `dart test`
   (agent_runtime, worker_runtime, scheduler, workflow_engine) — own numbers. The implementer
   reported a worker_lease_bound flake that I verified green in isolation (+7 passed) — if it
   flakes for you under load, isolate-rerun to confirm pre-existing timing, not the change.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.

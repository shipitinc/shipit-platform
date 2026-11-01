# Dispatch — impl-auto-model-escalation (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-auto-model-escalation
TASK_TYPE: implement
FEATURE: Automatic paid-model escalation on provider failure — no human escalation
AREA: model escalation / failure classification
WORKTREE: /private/tmp/shipit-auto-escalation
BRANCH: feat/auto-model-escalation
BASE_SHA: 7ca2b49
OWNED_PATHS:
  - packages/agent_runtime/**
  - packages/worker_runtime/**
  - packages/scheduler/**
  - packages/workflow_store/**
  - packages/workflow_engine/**
READ_ONLY_PATHS:
  - apps/server/lib/**, packages/platform_contracts/**, packages/execution_coordinator/**
PROHIBITED_PATHS:
  - apps/server/** (composition — report if it genuinely needs a wire)
  - .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed . (root)
  - dart analyze + dart test (each touched package root)
ROUTING_CLASS: PRECISION
```

## Human directive
"Let's make paid model escalation automatic and no longer needing human escalation."

## The mechanism today (verified)

- `model_policy.chain` is a multi-step list per role; `ModelSelectionService.select(role,
  escalationIndex)` picks `chain[idx]` — the paid fallback step exists in the mechanism.
- `item.metadata['escalationIndex']` bumps ONLY through `durable_workflow_engine.dart:~939`
  `Escalation triggered: $decisionType ... -> $target (escalationIndex=N+1)` — a HUMAN-decision
  escalation path guarded by `escalationIndexWithinLimitForDecisionTypes`. Nothing else writes it.
- `scheduler.dart:164` reads `item.metadata['escalationIndex'] ?? 0` → dispatch picks that step.

## The detection problem (the hard part — solve honestly, don't fake it)

A provider/quota failure today produces ZERO surface: opencode swallows the stream error
(verified live: `AI_APICallError: Free usage limit reached`), the ACP session emits no
terminal event, and the execution dies at the 1800s budget as `agent session timed out` with
totalTokens=0. There is NO provider-failure signal to escalate on.

Evaluate and implement the honest detection — candidates, in the order the codebase suggests:
(a) surface the ACP/opencode stream error (opencode_session.dart stream-error events exist —
  do they propagate? If the adapter can emit a provider-error event or the runtimeConfig can
  pass the observed failure class up, that's the real signal — investigate whether opencode
  session/new, prompt, or the event stream surfaces the API error to the platform at all);
(b) the zero-event/zero-token timeout signature (execution hits the budget having emitted
  nothing — the current "the runtime never emitted a terminal event" record IS the
  provider-dead signature and can classify distinctly from a session that ran and hung);
(c) ProviderHealthMonitor — it already detects all-down and raises human decisions; an
  alternative is auto-bumping escalationIndex on provider-down rather than/alongside the
  human decision. Inspect which layer owns the call.

Whichever detection wins: a provider-failure must bump `escalationIndex` (+1, bounded by the
role's chain length — NOT the decision-type guard, which is for human escalation) on the
item/job retry so the next dispatch selects the paid step. Non-provider failures MUST NOT
escalate (a real code defect retrying on the paid tier is wasted money — the escalation is
for provider unavailability, not work failure).

## Required

1. Provider-failure detection (chosen mechanism, honest — if opencode genuinely never
   surfaces the error to the platform, say so and use the zero-signal signature rather than
   fabricating an event).
2. `escalationIndex` auto-bump on provider-failure retry, bounded by chain length; stays
   bounded (no infinite escalation).
3. The human-decision escalation path unchanged (still works; auto is additive).
4. Regression tests: provider-failure → escalationIndex+1 on retry → next dispatch picks
   chain[1]; ordinary failure → escalationIndex unchanged; chain bound respected.
5. Report which detection mechanism you chose and WHY — this is the auditably hard part.

## Rules
New commits; no push; no docker/DB. `IMPLEMENTATION_BLOCKED` if the honest detection
needs apps/server composition wiring outside OWNED_PATHS. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.

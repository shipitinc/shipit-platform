# Dispatch — fix-acp-permission-responder (F-244)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-acp-permission-responder
TASK_TYPE: implement
FEATURE: ACP transport never answers session/request_permission — opencode stalls the agent turn until the role budget kills it
AREA: agent_runtime ACP layer / opencode adapter
WORKTREE: /private/tmp/shipit-fix-acp-perm
BRANCH: fix/acp-permission-responder
BASE_SHA: HEAD
OWNED_PATHS: [packages/agent_runtime/**, packages/worker_runtime/**, packages/execution_coordinator/**]
READ_ONLY_PATHS: [packages/platform_contracts/**, packages/scheduler/**, apps/server/lib/**]
PROHIBITED_PATHS: [apps/server/**, .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root), dart analyze + dart test (each touched package)]
ROUTING_CLASS: PRECISION
```

## Confirmed defect (live on QA)

Exec 194 stalled 19+min on an unanswered ACP `session/request_permission` (`external_directory`
ask — the opencode agent requesting permission to touch a path outside the workspace). The
platform's ACP transport has no responder, so the JSON-RPC request sits unacknowledged until the
role budget kills the turn — holding a capacity slot the whole time. This is the SECOND silent-stall
class after the quota issue: the agent asks, nobody answers, the turn hangs.

## Task

1. Find where ACP requests/notifications are handled — `acp_transport.dart`,
   `opencode_process_transport.dart`, `opencode_session.dart` — and whether
   `session/request_permission` (or whatever the method string is on the wire) is ever handled
   or just ignored.
2. Implement a responder. Decide the policy honestly:
   - The autonomous worker should auto-grant WITHIN safe bounds — what is opencode actually
     asking for? `external_directory` (outside-workspace access) vs tool-call permissions. If the
     ask is for a path/action outside the sandbox the worker already runs in, the safe policy is
     auto-DENY-and-continue (the agent adapts to the workspace it's already given) — NOT
     auto-grant, which could let the agent touch arbitrary host paths. Investigate what the
     permission options actually are before choosing grant vs deny vs scoped-allow.
   - If opencode supports a config/env to run without interactive permission prompts at all
     (a headless/auto-approve mode), prefer that over answering each request — document which.
3. The response must be timely — the turn continues, not stalls.
4. Regression test: a `session/request_permission` on the wire gets an answered response
   (grant/deny per policy), the turn proceeds; a never-answered request is no longer possible.
5. Report WHICH permission policy you chose and why (grant vs deny vs scoped) — auditably.

## Rules
New commits; no push; no docker/DB; nothing outside OWNED_PATHS — report IMPLEMENTATION_BLOCKED
if the ACP layer needs composition wiring outside owned paths. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`,
and `DETECTION MECHANISM/POLICY CHOSEN:`.

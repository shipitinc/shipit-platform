# Dispatch — integrate-acp-permission-responder

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-acp-permission-responder
TASK_TYPE: integrate
FEATURE: ACP transport answers session/request_permission (F-244)
WORKTREE: /private/tmp/shipit-fix-acp-perm + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/acp-permission-responder
BASE_SHA: 2e56eee
APPROVED_HEAD: 9848ed139ff751a389e2f211e232e13053fcf05b
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (3 LOW: doc precision, dead-pipe diagnostic, optional coverage)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
rehearsal clean, reviewed blobs identical (4 files: opencode_process_transport.dart,
opencode_session.dart, + 2 test files, all agent_runtime); gates on merged tree:
`dart format --set-exit-if-changed .` (root — `dart pub get` first on fresh worktree per the
implementer's discovery), `dart analyze` + `dart test` (agent_runtime, worker_runtime,
execution_coordinator); state make test-integration disposition (ACP transport mechanism —
probably not needed, no DB-facing change; reasoning). No merge, no push, no docker beyond
make test-integration, no DB. Report ending exactly `RESULT: MERGE_APPROVED` or
`RESULT: INTEGRATION_BLOCKED`.

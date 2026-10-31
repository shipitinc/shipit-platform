# Dispatch — integrate-needs-you-deeplink

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-needs-you-deeplink
TASK_TYPE: integrate
FEATURE: Home card ?wi= deep-link + cancelled read-only render
WORKTREE: /private/tmp/shipit-fix-needs-you-link + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/needs-you-deeplink
BASE_SHA: a155ef5
APPROVED_HEAD: 59029c912e43271c6007bd4e099619a5a50ab024 (commits 04aa09c + 59029c9)
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (1 LOW: inverted "most recent first" doc
  comment — behavior order-independent and correct)
CURRENT_MAIN: ff933ea (includes decision-card server merge 3f9d7a2)
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
merge rehearsal into current main clean, reviewed blobs identical (17 files, all
apps/control_plane/{lib,test}); the server-side companion (3f9d7a2) is already on main — confirm no
semantic interaction (the client ?wi= fix consumes what the server already ships); gates on merged
tree: `dart format --set-exit-if-changed .` (root), `flutter analyze` + `flutter test`
(apps/control_plane); note `make test-integration` status (server-side companion already ran it
green 319/319; client-only diff may not need it — state your reasoning). No docker, no DB.
Report per subtask-report.md ending exactly `RESULT: MERGE_APPROVED` or
`RESULT: INTEGRATION_BLOCKED`.

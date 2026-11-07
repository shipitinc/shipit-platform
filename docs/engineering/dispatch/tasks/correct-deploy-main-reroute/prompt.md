# Dispatch — correct-deploy-main-reroute (correction for DO_NOT_MERGE on a3a6bc5)

```yaml
MANAGER: orchestrator-main
TASK_ID: correct-deploy-main-reroute
TASK_TYPE: correct
FEATURE: one-line copy arm for the new (deployed, implementation_ready) edge
WORKTREE: /private/tmp/shipit-feat-deploy-main
BRANCH: feat/deploy-main-reland-reroute
BASE_SHA: aa83787
HEAD_SHA: a3a6bc575ab0a59bf84cde31a974563145dab5d8
OWNED_PATHS: [apps/control_plane/lib/shared/**, apps/control_plane/test/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, apps/server/lib/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
ROUTING_CLASS: PRECISION
```

Independent review found ONE blocker — `flutter test` (apps/control_plane) is red:
`test/shared/transition_copy_test.dart` "every engine-accepted pair has dedicated plain copy"
fails — the new `(deployed, implementation_ready)` edge has no copy arm in
`apps/control_plane/lib/shared/transition_copy.dart`. The file uses `('from','to') => 'copy'`
entries — add `('deployed', 'implementation_ready') => '<copy>'` following the convention
(e.g. 'Sent back to build' — match the file's existing voice for rework/return transitions;
read neighboring arms first).

Also the non-blocking L1 if trivially in scope: nothing else — the UI arm follow-up is a
separate lane (F-260-style), do NOT add it here.

Gates: `dart format --set-exit-if-changed .` (root, dart pub get first), `flutter test`
(apps/control_plane — must go fully green, +553). New commit on the existing branch; no push;
no docker/DB. Report per subtask-report.md: `RESULT: CORRECTED` / `CORRECTION_BLOCKED`,
HEAD_SHA, `READY_FOR_FOCUSED_REVIEW:`.

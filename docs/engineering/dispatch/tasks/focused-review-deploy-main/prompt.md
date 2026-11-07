# Dispatch — focused-review-deploy-main

```yaml
MANAGER: orchestrator-main
TASK_ID: focused-review-deploy-main
TASK_TYPE: review
FEATURE: focused re-review of the deploy-main-reroute correction (d6e995d on top of reviewed a3a6bc5)
WORKTREE: /private/tmp/shipit-feat-deploy-main
BRANCH: feat/deploy-main-reland-reroute
BASE_SHA: aa83787
REVIEWED_HEAD: a3a6bc575ab0a59bf84cde31a974563145dab5d8
CORRECTED_HEAD: d6e995dca86cbee075451ccea812a8e8aa51b5ff
ROUTING_CLASS: PRECISION
```

Focused re-review — ONLY the corrected finding + regression risk; do NOT repeat the full
review unless evidence requires it.

The correction addressed the one blocker: the new `(deployed, implementation_ready)` edge now
has a copy arm `('deployed','implementation_ready') => 'Sent back to build again'` in
`apps/control_plane/lib/shared/transition_copy.dart`.

Verify:
1. The reviewed HEAD `a3a6bc5` is preserved (correction is a new commit on top, no rewrite).
2. The copy arm matches the file's `('from','to') => 'copy'` convention + rework/return voice;
   `flutter test` (apps/control_plane) is fully green — re-run it yourself (+553).
3. Regression risk — the correction touched exactly `apps/control_plane/lib/shared/
   transition_copy.dart` (+6); verify nothing else crept in, no other arm altered.
4. `dart format --set-exit-if-changed .` (root, dart pub get first) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_CORRECTIONS` /
`DO_NOT_APPROVE_CORRECTIONS` + `CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:`.

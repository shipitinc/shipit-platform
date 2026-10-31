# Dispatch — review-needs-you-deeplink (PRECISION, client)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-needs-you-deeplink
TASK_TYPE: review
FEATURE: Home "Waiting for your approval" card missing ?wi= + cancelled read-only render
AREA: control-plane client (Flutter)
WORKTREE: /private/tmp/shipit-fix-needs-you-link
BRANCH: fix/needs-you-deeplink
BASE_SHA: a155ef5
HEAD_SHA_UNDER_REVIEW: 59029c912e43271c6007bd4e099619a5a50ab024
ROUTING_CLASS: PRECISION
```

Independent read-only review of the client fix (2 commits 04aa09c, 59029c9):
1. `home_page.dart` both card sites append `?wi=${gate.workItemId}` — verify the field is the
   populated one and the route string matches the router's parameter contract; audit confirms
   needs_you_page/run_detail already pass wi correctly.
2. `inspectDecision` selection-by-decisionId — was `result.first` on a newest-first list; now
   selects the rendered record's id — verify fallback semantics and that submit resolves the
   RENDERED record's id (no wrong-record writes).
3. Cancelled read-only rendering — `statusWire`/`isCancelled` from `detail.status`; verify a
   cancelled decision cannot be submitted (`_onSubmitted` refusal), no live affordances render,
   and a real pending decision still renders the submit path (no false-read-only).
4. `transition_copy` fix — the base red test (design_approved→implementation_ready edge copy) —
   verify the added copy matches the engine transition semantics (queued not started).
5. The ~10 test-fake signature updates — mechanical, no weakened assertions.
6. Re-run gates yourself: `dart format --set-exit-if-changed .` (root), `flutter analyze` +
   `flutter test` (apps/control_plane) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `RESULT: DO_NOT_MERGE` +
`CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:`.

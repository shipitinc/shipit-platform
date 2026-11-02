# Dispatch — review-decision-field-truncation

```yaml
MANAGER: orchestrator-main
TASK_ID: review-decision-field-truncation
TASK_TYPE: review
FEATURE: Human-input pages render full field values — no ellipsized WHAT THIS IS ABOUT / What Happens column
AREA: control_plane shared primitives + human-input pages
WORKTREE: /private/tmp/shipit-fix-truncation
BRANCH: fix/decision-field-truncation
BASE_SHA: 582d254
HEAD_SHA_UNDER_REVIEW: 22daf08d2c8ffdd6f1e00b85b356625694d950a9
ROUTING_CLASS: STANDARD
```

Independent read-only review of `22daf08` — DefinitionList value renders uncapped; OutcomeTable
variable-height rows; the duplicated _FullContextSection removed; needs-you pages untruncated;
goldens re-baselined.

Verify rigorously:
1. The shared-primitive change: `DefinitionList` now renders uncapped — verify every call site is
   genuinely a human-input/decision surface (the implementer claims ALL call sites are; the
   deliberately-still-capped exceptions — TimelineTable event messages + chrome/ref labels — are
   documented and correct: record prose a human reads to decide renders full, navigational/log
   surfaces keep their pitch).
2. The scope disclosure: `decision_context_sections.dart` was declared READ_ONLY in the dispatch,
   but task step 3 required slimming the duplicated section there — the implementer made only the
   minimal dedup edit (removed _FullContextSection + usage). Rule on whether that edit is
   justified vs a scope violation — the dispatch DID direct the dedup, so the READ_ONLY
   declaration was internally inconsistent (the implementer's read is that the task overrode it).
3. The dedup: the verdict/findings/artifact sections remain (new content, correct to keep); the
   full description now renders via the untruncated original field, not a duplicated section.
4. Untruncation coverage: needs-you fact grid, confirm strip, resolved rows (desktop+mobile),
   the What Happens table (all 3 columns), defect detail, product detail, failed-work-item,
   review-repair pages — the "all human input pages" directive.
5. The technical title moved under Show technical details (matches run detail's convention).
6. Golden re-baseline is deliberate and narrow (only the two moved mobile_decision_detail pngs,
   by --plain-name precedent).
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
   (control_plane), `flutter test` (control_plane) — own numbers; the new
   human_input_full_text_test + updated review-context test are non-vacuous.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:` — and RULE on the READ_ONLY-edit disclosure.

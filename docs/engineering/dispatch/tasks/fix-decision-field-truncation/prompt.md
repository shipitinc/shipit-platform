# Dispatch — fix-decision-field-truncation

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-decision-field-truncation
TASK_TYPE: implement
FEATURE: Human-input pages render full field values — WHAT THIS IS ABOUT + WHAT HAPPENS column not ellipsized
AREA: control_plane shared primitives + decision-detail + other human-input pages
WORKTREE: /private/tmp/shipit-fix-truncation
BRANCH: fix/decision-field-truncation
BASE_SHA: HEAD
OWNED_PATHS: [apps/control_plane/lib/**, apps/control_plane/test/**]
READ_ONLY_PATHS: [apps/control_plane/lib/features/decision_detail/decision_context*.dart (the prior session's additions — reconcile, don't duplicate)]
PROHIBITED_PATHS: [apps/server/**, packages/**, .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/control_plane), flutter test (apps/control_plane)]
ROUTING_CLASS: STANDARD
```

## Human directive (verbatim)

"On the decision page I need the WHAT THIS IS ABOUT section to not be ellipsized and the WHAT
HAPPENS after you decide table to also not ellipsize the What Happens column. In our last work
you added a new field for engineering reviews to show the full what-this-is-about but you should
have instead just allowed the original field to just show the full value instead of adding a new
field. Do this for all human input pages."

## The mechanism (verified)

`DefinitionList` (shared primitive) truncates every value at `maxLines: 2` — the mechanism behind
the ellipsized "WHAT THIS IS ABOUT" (and likely the "What Happens" consequence column). The prior
session added a separate engineering_review "full context" section to sidestep it — the human
corrects that: the ORIGINAL field should show the full value, not a duplicated section.

## Task

1. The `DefinitionList` value rendering — the `maxLines: 2` truncation: give it an untruncated
   rendering option (a `maxLines` parameter defaulting appropriately, OR remove the truncation
   where the value is human-decision content). Apply it so the original WHAT THIS IS ABOUT field
   shows the FULL description, and the WHAT HAPPENS consequence column in the outcomes table
   shows the FULL consequence text — not truncated at 2 lines.
2. "Do this for all human input pages" — audit WHERE DefinitionList (and any sibling truncation
   primitive) is used on human-input surfaces (needs-you/decision detail + any other decision/
   input pages) and untruncate consistently — don't fix just the one card.
3. Reconcile with the prior session's added sections: the verdict badge / findings / artifact
   sections are genuinely NEW content (not the description) — keep them. If a "full context"
   section duplicates the now-untruncated description field, slim it to the non-duplicated parts
   (title/verdict/findings) rather than showing the same text twice.
4. Tests: a long description renders fully (not truncated); the What Happens column shows full
   consequence text; the behavior holds on at least one OTHER human-input page type, not just
   the engineering-review card.

## Rules
New commits; no push; no docker/DB; nothing outside OWNED_PATHS (apps/control_plane only). Report
per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
`READY_FOR_INDEPENDENT_REVIEW:`, and which pages were untruncated.

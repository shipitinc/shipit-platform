# Dispatch — review-decision-detail-surface (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-decision-detail-surface
TASK_TYPE: review
FEATURE: Decision-detail page surfaces review verdict + findings + artifact + full context + real option consequences (decisionType-aware)
AREA: control_plane decision detail UI + one server view field
WORKTREE: /private/tmp/shipit-decision-surface
BRANCH: feat/decision-detail-surface
BASE_SHA: da095e2
HEAD_SHA_UNDER_REVIEW: 07b4b382d00182fe7e14e3acd44b40fd6a6accd3
ROUTING_CLASS: PRECISION
```

Independent read-only review of `07b4b38` (4 commits: a707272 impl + fe246e4 tests + 2 verifier-sweep reconciliation). The implementer flagged TWO scope disclosures for your ruling:

1. `apps/server/lib/src/generated/decision_view.dart` — serverpod-generated output of the sanctioned `metadataJson: String?` view-field addition (`decision_view.yaml` + mapper). Is the mechanical regeneration of the field's own generated file acceptable under the view-field carve-out, or does `**/generated/**` forbid it (which would make the approach impossible — rule on it).
2. Four other apps/server files (server.dart dartTestSweepRoots, two pin tests, product manifest F4) — the implementer claims a FORCED consequence of the Manager-granted `packages/control_plane_client/test/` creation (adding tests to a previously-excluded package root triggers the verification-plan cascade; without them the two demanded gates are mutually exclusive). Verify that claim — are those changes genuinely required by the new test dir, and minimal?

Verify rigorously:
- The metadataJson field: does the view actually carry `engineeringReviewResult` to the client
  (the whole point)? The mapper populates jsonEncode(decision.metadata) — verify the wire shape.
- The decisionType-aware rendering: engineering_review renders verdict badge + finding cards +
  full context + artifact-under-review; a decisionType→renderer map (not a one-off hardcode);
  non-review types fall to the generic path; cancelled decisions still read-only.
- Full context: the item title + complete description render (not the 2-line DefinitionList
  truncation that caused the original complaint).
- Option consequences: approve/reject/rework map to distinct real outcomes (not three identical
  "Records your decision").
- Tests non-vacuous: decision_detail_review_context_test (10 widget tests) + control_plane_client
  decision_view_metadata_test — the review-result section, the non-review path, per-option text.
- Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
  (control_plane, control_plane_client, apps/server), `flutter test` (control_plane),
  `dart test` (control_plane_client), `dart run tool/run_unit_tests.dart` (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:` — and RULE explicitly on the two scope disclosures.

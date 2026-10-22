# Correction — design-governance step 8 (B1 + H1; L1/L3)

CORRECTED_FROM_HEAD: 1a027e9c4673f9aa4b9c04275c07de1ed6d952be
NEW_HEAD: 374b69aedf5b3e94cfbcd3713775093389a9ac86
TASK_ID: design-governance-step-8-correction
RESULT: CORRECTION_COMPLETE
READY_FOR_FOCUSED_REVIEW: YES

## Findings addressed
- B1 (blocker): JobType.designReview registered in the triage-section drain table (extracted to
  triageSectionDrainHandlers(), used by production at server.dart:1260) and in the review-section
  drain (runReviewLaneTick). New regression test apps/server/test/design_review_drain_completeness_test.dart
  drives a terminal designReview job through BOTH drains; fails at 1a027e9 (UnhandledJobTypeException),
  passes at 374b69a.
- H1 (high): _completeFailure now treats AgentRole.designReviewer like engineeringReviewer (no
  transition); item stays at designInReview; no designInReview -> agentFailed edge invented.
  Regression test added to packages/execution_coordinator/test/engineering_reviewer_test.dart.
- L1: review-section comment -> "CODE lanes".
- L3: F-224 appended to docs/engineering/FOLLOW_UPS.md.

## Not touched (deliberate)
- L2 (decision metadata note), L4 (ownership disclosure); no designApproval raiser (step 9);
  no new failure edge.

## Gates (unpiped)
format 0; server analyze 0; server unit runner 0 (64 files); execution_coordinator 0 (192);
worker_runtime 0; scheduler 0; control_plane 0 (513).

## Disclosure
During falsification the lane temporarily removed the designReview entries and the H1 arm, observed
the new tests fail, then restored. The focused re-review independently confirmed the final diff's
_completeSuccess text is unchanged and the only execution_coordinator.dart hunk is _completeFailure.

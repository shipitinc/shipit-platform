# Independent Engineering Review — design-governance step 8

REVIEWED_HEAD: 1a027e9c4673f9aa4b9c04275c07de1ed6d952be
BASE_SHA: 128b7f5
TASK_ID: design-governance-step-8-review
RESULT: DO_NOT_MERGE
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO

## Provenance (re-verified)
- HEAD == 1a027e9, branch main, tree clean.
- git cat-file -t 128b7f5 -> commit.
- Diff 14 files, +1962/-77; no change under prohibited paths.

## Gates re-run (unpiped)
format 0; server analyze 0 (4 pre-existing deprecation infos); server unit runner 0 (63 files);
execution_coordinator 0 (191); worker_runtime 0 (37 +1 skipped); scheduler 0 (432);
control_plane 0 (513). Integration NOT_RUN (F-219 base-red).

## BLOCKERS
- B1: JobType.designReview absent from the triage drain table (server.dart ~:1266-1293) and the
  review-section drain table (~:1940-1957). Scheduler.tick step 1 reconciles every held job in the
  shared JobStore; triage ticks first; lane_i_tick_hook.dart:262-266 throws UnhandledJobTypeException
  for a handler-less type before the non-terminal skip. So every designReview lease expiry reconciled
  by the triage tick threw and failed the triage section, and observeCompletedDesignReviewJob /
  unconsumedReviewJobIds were never reached.

## HIGH
- H1: _completeFailure (execution_coordinator.dart:1539, special-case :1546) only special-cased
  engineeringReviewer; a failed design review attempted designInReview -> agentFailed (no such edge),
  caught and mislabelled by the finalize wrapper.

## LOW
- L1: review-section comment "SECOND of the two lanes that share agentCompleted" -> "CODE lanes".
- L2: decision e2c7a05b dedupeKey recorded in metadata but dedupe is by item state (alreadyPending).
- L3: FOLLOW_UPS.md not updated for step-8 boundaries (step 6 convention).
- L4: container-ownership edits (execution_coordinator, worker_runtime) outside the original implement
  lane's declared ownership (integrator-authored, disclosed).

## Verified correct (challenged, not trusted)
- F-222 sink reachable on all three drains; unrecognized refusal codes still raise.
- F-171 both schedulers mounted, revision-before-review order pinned.
- Container ownership: designReviewer runs in designInReview, no artifact commit.
- Test honesty: the three updated apps/server tests were not weakened.
- saveDesignReviewResult has no caller; step 9 not pretended.

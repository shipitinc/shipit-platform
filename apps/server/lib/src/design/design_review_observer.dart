import 'package:platform_contracts/platform_contracts.dart' show Job;

/// Consumes one TERMINAL `designReview` job by recording that its verdict is
/// durable but its APPROVAL decision is not raised here.
///
/// ## WHY THIS EXISTS AT ALL
///
/// `drainTriageOutcomesFromTick` dispatches by type and THROWS for a terminal
/// job with no registered handler. Mounting `sched-design-review` therefore
/// requires a handler for `JobType.designReview`, or every completed design
/// review turns the design tick's drain into an `UnhandledJobTypeException`.
///
/// ## WHAT IT DELIBERATELY DOES NOT DO
///
/// It does NOT raise `designApproval`. That is §9 step 9 (`G-C`) and is outside
/// step 8. It also does not claim the review was "handled" in the sense of a
/// verdict being consumed: the reviewer's structured result remains durable in
/// the execution store, and this log says, in the record, that the approval
/// raiser is not mounted yet. That is a named boundary, not a silent skip.
///
/// The design tick reports the same job ids as `unconsumedReviewJobIds` so the
/// tick line distinguishes "no review ran" from "a review ran and its verdict
/// is waiting for step 9".
Future<void> observeCompletedDesignReviewJob({
  required Job job,
  required void Function(String event, Map<String, dynamic> data) logger,
}) async {
  logger('design.review.completed', {
    'jobId': job.jobId,
    'workItemId': job.workItemId,
    'state': job.state.wire,
    'consumer': 'designApproval raiser (step 9) is not mounted',
    'action':
        'the review verdict remains durable in its agent execution; no '
        'designApproval decision was raised by step 8',
  });
}

/// Consumes one TERMINAL `implementFeature` job that a DESIGN tick reconciled.
///
/// ## WHY A DESIGN-LANE FILE OBSERVES AN IMPLEMENTATION JOB
///
/// Every `Scheduler.tick()` reconciles EVERY held job whose claim has expired —
/// the loop reads the shared `JobStore`, not only its own lane's rows. So the
/// design scheduler's tick can surface an `implementFeature` job in its
/// `reconciled` list, and `drainTriageOutcomesFromTick` would then raise
/// `UnhandledJobTypeException` and fail the whole design section for a job that
/// is none of its business.
///
/// The implementation lane does NOT drain its own tick: an implementer's
/// success is recorded by the `ExecutionCoordinator` directly, and this
/// reconciliation path exists for a claim that outlived its lease without a
/// terminal outcome. The implementation lane's readiness probe re-derives that
/// on its next tick, so the honest thing this handler can do is REPORT it. It
/// resolves nothing and re-drives nothing.
Future<void> observeReconciledImplementationJob({
  required Job job,
  required void Function(String event, Map<String, dynamic> data) logger,
}) async {
  logger('design.tick.foreign-job-reconciled', {
    'jobId': job.jobId,
    'workItemId': job.workItemId,
    'jobType': job.jobType.wire,
    'state': job.state.wire,
    'note':
        'the design scheduler reconciled a non-design job because it shares the '
        'job store; the implementation lane re-derives this on its own tick',
  });
}

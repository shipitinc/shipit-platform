import 'package:platform_contracts/platform_contracts.dart' show Job, JobType;
import 'package:scheduler/scheduler.dart' show JobStore, SchedulerTickResult;

import 'triage_processor.dart';

/// Consumes one job's durable outcome, for one [JobType].
///
/// Returning normally means "the handler reached a verdict, including a
/// deliberate refusal". Throwing means the handler itself broke, and is
/// isolated per job by [drainTriageOutcomesFromTick] rather than taking the
/// batch down.
typedef TickJobHandler = Future<void> Function(Job job);

/// Raised when a job's [JobType] has no registered handler.
///
/// ## Why this is an exception and not another `skipped++`
///
/// The function this replaced skipped every job that was not
/// [JobType.triageDefect], with no log and no error. That is how
/// `JobType.onboardProduct` came to sit `queued` for ever: the control plane
/// enqueued it, the dashboard displayed it, the scheduler held it, and the one
/// place that could have consumed it counted it as *not applicable* and said
/// nothing. A skip is a decision; an unhandled type is the ABSENCE of one, and
/// the two were being recorded identically.
///
/// The accounting follows from that. An unhandled type is not counted as
/// skipped, because it was not skipped — it was not reached. It propagates, so
/// `considered == skipped + handedOff` still holds over everything the call
/// actually returned for.
///
/// It propagates rather than being caught and logged here for a second reason:
/// the caller already wraps the whole tick, and a configuration error that
/// reaches the operator as a stack trace naming the job type and id is worth
/// more than a log line nobody reads. The failure is loud and specific on
/// purpose.
class UnhandledJobTypeException implements Exception {
  const UnhandledJobTypeException(this.jobType, this.jobId);

  final JobType jobType;
  final String jobId;

  @override
  String toString() =>
      'UnhandledJobTypeException: no handler is registered for job type '
      '${jobType.wire} (job $jobId). A job type with no handler is a '
      'configuration error, not a no-op: register one, or do not enqueue this '
      'type.';
}

/// What one [drainTriageOutcomesFromTick] call actually did.
///
/// The accounting is complete and non-overlapping:
/// `considered == skipped + handedOff`, and `handedOff` is split by
/// [succeededJobIds] and [failedJobIds].
///
/// [handedOffJobIds] counts jobs that reached a handler, NOT jobs the handler
/// accepted: `TriageProcessor.processCompletedTriageJob` returns null both when a
/// job is not consumable and when it deliberately refuses one (a run the platform
/// declared failed). Conflating those would make a refusal look like a success,
/// and excluding a job that THREW would make a drained job look as though it had
/// never been reached — which is the opposite of what happened.
class TriageTickDrainResult {
  const TriageTickDrainResult({
    required this.considered,
    required this.skipped,
    required this.handedOff,
    required this.succeededJobIds,
    required this.failedJobIds,
  });

  /// Job ids in the tick's `dispatched ∪ terminal ∪ reconciled` union.
  final int considered;

  /// Ids dropped by the guards: unreadable, not terminal, or handled by no
  /// handler for their type.
  final int skipped;

  /// Ids that reached a registered handler.
  final int handedOff;

  /// Ids a handler returned from normally. A job a handler deliberately
  /// REFUSED is in this list — the handler ran and said no, which is not a
  /// failure of this drain.
  final List<String> succeededJobIds;

  /// Ids whose handling threw. Each one was logged as
  /// `triage.tick.job_failed` and each one is an outcome that was dropped: the
  /// job stays terminal, so nothing will ever retry it.
  final List<String> failedJobIds;

  @override
  String toString() =>
      'TriageTickDrainResult(considered: $considered, skipped: $skipped, '
      'handedOff: $handedOff, failed: ${failedJobIds.length})';
}

/// Hands the durable outcomes of exactly ONE scheduler tick to their per-type
/// handlers.
///
/// This is the only path by which a durably-reached job is ever consumed, and
/// it now dispatches BY TYPE rather than filtering for one type. The change is
/// the same in shape as the composition chain in `server.dart`: stores build
/// stores, the scheduler builds the tick, and this is where a tick's jobs reach
/// the thing that acts on them. A job type absent from [handlers] is an
/// [UnhandledJobTypeException] rather than a silent skip.
///
/// ## Handlers, and the default
///
/// [triageProcessor] still supplies the [JobType.triageDefect] handler, so
/// every existing call site is unchanged — the server passes one today and
/// still compiles. Passing [handlers] is how a caller opts a further type IN:
/// the table is the triage handler plus whatever was added, and a type in
/// neither raises [UnhandledJobTypeException].
///
/// [triageProcessor] is optional rather than required because this function is
/// a dispatcher and nothing more. Forcing every caller that only cares about
/// onboarding to construct a triage processor — which needs a live
/// `PersistenceDatabase`, a workflow engine and an execution coordinator — would
/// make the dispatch table untestable in isolation, and an untestable dispatch
/// table is where the next silent skip grows.
///
/// That is deliberately additive rather than breaking. Making `handlers`
/// mandatory would have forced a simultaneous edit of every caller, and a
/// signature change nobody opted into is how a dispatch table quietly loses a
/// type: the compile error arrives once, the fix is to add a placeholder, and
/// the placeholder is the silent skip all over again.
///
/// ## WHY THE UNION OF `dispatched ∪ terminal ∪ reconciled` IS REQUIRED
///
/// `SchedulerTickResult.terminal` alone is NOT the set of jobs that reached a
/// terminal state during a tick. In `Scheduler.tick` a job that is dispatched
/// AND completed inside the same tick returns
/// `_DispatchOutcome(dispatched: true, terminalJob: adopted)`, and the
/// `if (outcome.dispatched)` branch is taken first, so the id never reaches
/// `terminal`. `terminal` is only filled for the narrow race where a job was
/// already terminal when dispatch was attempted. The same under-reporting
/// applies to `reconciled`: a claim recovered from an expired lease is adopted
/// into a terminal state by `_adoptFromExecution` without ever being added to
/// `terminal`.
///
/// Consuming only `terminal` therefore meant `TriageProcessor` never ran: a
/// triage job that succeeded was durably recorded and then silently ignored, so
/// the defect was never classified.
///
/// The honest fix at this boundary is to take every job id the scheduler durably
/// touched this tick, re-read its state from the job store, and act on what is
/// actually there. This is not a second polling loop and adds no timer: it
/// consumes the existing tick's result. The residual imprecision in
/// `SchedulerTickResult.terminal` is reported to the scheduler lane rather than
/// patched here (`packages/scheduler` is read-only to this file). Note the
/// `Scheduler` under-reporting is the ONLY reason the union is larger than
/// `terminal`; the union is not a guess, and narrowing it re-introduces the
/// defect above.
///
/// ## PER-JOB ISOLATION, AND WHY THIS DOES NOT PROPAGATE
///
/// A throw from one job's HANDLER does not abort the batch. Each job is guarded
/// individually: the remaining jobs in the same tick are still drained, and the
/// failure is logged under `triage.tick.job_failed` rather than swallowed.
///
/// The alternative — letting the first throw escape to the caller's catch — was
/// the previous behaviour, and it loses work rather than merely propagating
/// information. The skipped jobs are already TERMINAL: their outcome is durable,
/// nothing will re-enqueue them, and the tick result that named them is
/// discarded when the timer moves on. A single store error or CAS conflict on
/// one defect would therefore drop the classifications of every other defect the
/// same tick completed, with no retry path at all.
///
/// An UNREGISTERED job type is deliberately excluded from that isolation. It is
/// not a job that failed to be processed; it is a job nothing was ever written
/// to process, which is a different failure and must not be hidden behind a
/// batch that otherwise went well. See [UnhandledJobTypeException].
///
/// The guards themselves are otherwise unchanged from the loop this function
/// replaces: a job that cannot be read, or is not terminal, is skipped, and
/// nothing else about the drain is special-cased.
Future<TriageTickDrainResult> drainTriageOutcomesFromTick({
  required SchedulerTickResult tickResult,
  required JobStore jobStore,
  TriageProcessor? triageProcessor,
  Map<JobType, TickJobHandler>? handlers,
  required void Function(String event, Map<String, dynamic> data) logger,
}) async {
  // The triage handler is the default rather than something a caller has to
  // remember: the table is the wiring, and the wiring should not be able to
  // leave out the type the processor exists for.
  final table = <JobType, TickJobHandler>{
    if (triageProcessor != null)
      ...triageOnlyTickHandlers(triageProcessor: triageProcessor),
    ...?handlers,
  };
  assert(
    triageProcessor == null || table[JobType.triageDefect] != null,
    'no handler survived for ${JobType.triageDefect.wire}; a caller-supplied '
    'table must not be able to remove the triage handler, or every triage job '
    'would look unhandled',
  );
  assert(
    table.isNotEmpty,
    'drainTriageOutcomesFromTick was given neither a TriageProcessor nor any '
    'handlers, so every job it considers would raise '
    'UnhandledJobTypeException',
  );

  final touched = <String>{
    ...tickResult.dispatched,
    ...tickResult.terminal,
    ...tickResult.reconciled,
  };

  final succeeded = <String>[];
  final failed = <String>[];
  var skipped = 0;

  for (final jobId in touched) {
    final job = await jobStore.readJob(jobId);
    if (job == null) {
      skipped++;
      continue;
    }
    // Dispatch BY TYPE. This is the line that used to be
    // `if (job.jobType != JobType.triageDefect) { skipped++; continue; }`, and
    // it is where an onboarding job used to disappear.
    final handler = table[job.jobType];
    if (handler == null) {
      throw UnhandledJobTypeException(job.jobType, job.jobId);
    }
    if (!job.isTerminal) {
      skipped++;
      continue;
    }
    try {
      await handler(job);
      succeeded.add(job.jobId);
    } on Object catch (e, st) {
      // Never silent, and never fatal to the rest of the batch. The job stays
      // terminal and durable, so this log line is the only record that its
      // outcome was dropped.
      failed.add(job.jobId);
      logger('triage.tick.job_failed', {
        'jobId': job.jobId,
        'workItemId': job.workItemId,
        'jobType': job.jobType.wire,
        'error': e.toString(),
        'stack': st.toString(),
        'action': 'job left terminal and unclassified; no retry path exists',
      });
    }
  }

  return TriageTickDrainResult(
    considered: touched.length,
    skipped: skipped,
    handedOff: succeeded.length + failed.length,
    succeededJobIds: List.unmodifiable(succeeded),
    failedJobIds: List.unmodifiable(failed),
  );
}

/// The handler table a server uses when it has wired the triage processor and
/// nothing else.
///
/// A named factory rather than an inline `if` at each call site, because the
/// table IS the wiring: adding a job type means adding a line here, and the
/// [UnhandledJobTypeException] is what makes a forgotten line fail instead of
/// quietly doing nothing.
Map<JobType, TickJobHandler> triageOnlyTickHandlers({
  required TriageProcessor triageProcessor,
}) => <JobType, TickJobHandler>{
  JobType.triageDefect: triageProcessor.processCompletedTriageJob,
};

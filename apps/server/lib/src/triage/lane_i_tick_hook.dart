import 'package:platform_contracts/platform_contracts.dart' show JobType;
import 'package:scheduler/scheduler.dart' show JobStore, SchedulerTickResult;

import 'triage_processor.dart';

/// What one [drainTriageOutcomesFromTick] call actually did.
///
/// The accounting is complete and non-overlapping:
/// `considered == skipped + handedOff`, and `handedOff` is split by
/// [succeededJobIds] and [failedJobIds].
///
/// [handedOffJobIds] counts jobs that reached the processor, NOT jobs the
/// processor accepted: `TriageProcessor.processCompletedTriageJob` returns null
/// both when a job is not consumable and when it deliberately refuses one (a run
/// the platform declared failed). Conflating those would make a refusal look
/// like a success, and excluding a job that THREW would make a drained job look
/// as though it had never been reached — which is the opposite of what happened.
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

  /// Ids dropped by the guards: unreadable, not a triage job, or not terminal.
  final int skipped;

  /// Ids that reached [TriageProcessor.processCompletedTriageJob].
  final int handedOff;

  /// Ids the processor returned from normally. A job it deliberately REFUSED
  /// (B9: the execution was not successful) is in this list — the processor ran
  /// and said no, which is not a failure of this drain.
  final List<String> succeededJobIds;

  /// Ids whose processing threw. Each one was logged as
  /// `triage.tick.job_failed` and each one is an outcome that was dropped: the
  /// job stays terminal, so nothing will ever retry it.
  final List<String> failedJobIds;

  @override
  String toString() =>
      'TriageTickDrainResult(considered: $considered, skipped: $skipped, '
      'handedOff: $handedOff, failed: ${failedJobIds.length})';
}

/// Hands the triage outcomes of exactly ONE scheduler tick to the
/// [TriageProcessor].
///
/// This is the only path by which a durably-succeeded triage job is ever
/// classified. It lives here, in production, rather than inline in the server's
/// timer callback, because its behaviour is production knowledge and a copy of
/// it is not: a test that transcribes the loop proves only that the copy is
/// self-consistent, not that the server behaves the same way.
///
/// WHY THE UNION OF `dispatched ∪ terminal ∪ reconciled` IS REQUIRED.
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
/// PER-JOB ISOLATION, AND WHY THIS DOES NOT PROPAGATE.
///
/// A throw from one job does not abort the batch. Each job is guarded
/// individually: the remaining jobs in the same tick are still drained, and the
/// failure is logged under `triage.tick.job_failed` rather than swallowed.
///
/// The alternative — letting the first throw escape to the caller's catch — was
/// the previous behaviour, and it loses work rather than merely propagating
/// information. The skipped jobs are already TERMINAL: their outcome is durable,
/// nothing will re-enqueue them, and the tick result that named them is
/// discarded when the timer moves on. A single store error or CAS conflict on
/// one defect would therefore drop the classifications of every other defect the
/// same tick completed, with no retry path at all. `TriageProcessor` already
/// reaches the same conclusion about its own last append-only step, and says so
/// in terms: a throw "WOULD abort the caller's loop over the jobs this tick
/// touched" (`triage_processor.dart`, design-remediation provisioning), which is
/// why that step is non-fatal here. B9's test asserts this function RETURNS for
/// a batch containing a job the processor refuses; per-job isolation does not
/// weaken that, it strengthens it — a genuine failure is now reported per job
/// instead of taking the batch down with it.
///
/// The guards themselves are unchanged from the loop this function replaces: a
/// job that cannot be read, is not `JobType.triageDefect`, or is not terminal is
/// skipped, and nothing else about the drain is special-cased.
Future<TriageTickDrainResult> drainTriageOutcomesFromTick({
  required SchedulerTickResult tickResult,
  required JobStore jobStore,
  required TriageProcessor triageProcessor,
  required void Function(String event, Map<String, dynamic> data) logger,
}) async {
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
    if (job.jobType != JobType.triageDefect) {
      skipped++;
      continue;
    }
    if (!job.isTerminal) {
      skipped++;
      continue;
    }
    try {
      await triageProcessor.processCompletedTriageJob(job);
      succeeded.add(job.jobId);
    } on Object catch (e, st) {
      // Never silent, and never fatal to the rest of the batch. The job stays
      // terminal and durable, so this log line is the only record that its
      // outcome was dropped.
      failed.add(job.jobId);
      logger('triage.tick.job_failed', {
        'jobId': job.jobId,
        'workItemId': job.workItemId,
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

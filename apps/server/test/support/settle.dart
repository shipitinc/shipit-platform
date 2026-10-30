import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';

/// Waits for [condition] to become true, polling with [spacing].
///
/// Detached dispatch moves completion work off the tick: a run resolves and
/// its continuation releases the job's claim on the event loop, not inside
/// any `tick()` a test can await. Observing that release therefore needs a
/// poll, never a fixed sleep. This mirrors
/// `packages/scheduler/test/support/settle.dart` — the server suite consumes
/// the same settle path through the real composition-root wiring.
Future<void> waitUntil(
  Future<bool> Function() condition, {
  required String because,
  Duration timeout = const Duration(seconds: 10),
  Duration spacing = const Duration(milliseconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('timed out waiting for: $because');
    }
    await Future<void>.delayed(spacing);
  }
}

/// Waits for every currently-held job's detached run to release its claim,
/// then runs the tick that settles it through reconcile-adoption — the two
/// halves a production tick interval provides between "the run ended" and
/// "the job was adopted".
///
/// Dispatch is detached (F-237): a tick STARTS the execution and returns, and
/// the run's continuation drops the claim so the NEXT tick's
/// `_reconcileClaim` adopts the terminal worker execution. The claim going
/// absent is the durable signal that continuation ran — never a sleep.
///
/// The returned result is the ADOPTING tick's: a caller asserting
/// `dispatched` should use the result of the dispatching tick instead, kept
/// before this call.
Future<SchedulerTickResult> settleHeldJobs(
  JobStore jobStore,
  Scheduler scheduler,
) async {
  await waitUntil(() async {
    for (final job in await jobStore.listJobs()) {
      final held =
          job.state == JobState.claimed || job.state == JobState.running;
      if (held && await jobStore.readClaimForJob(job.jobId) != null) {
        return false;
      }
    }
    return true;
  }, because: 'every in-flight job to release its claim for reconcile');
  return scheduler.tick();
}

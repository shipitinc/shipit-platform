import 'package:platform_contracts/platform_contracts.dart' show WorkItem;
import 'package:scheduler/scheduler.dart'
    show SchedulerWorkload, WorkloadResolver;

/// Whether [item] carries the QA contract its completion transition requires.
///
/// The ONLY edge out of a finished agent run, `agentExecuting ->
/// agentCompleted`, is guarded by `GuardConditions.qaContractExists()`, and the
/// coordinator supplies `qaContractId` from the work item's own column — so a
/// null id is a refusal that cannot be known until the LAST transition, after
/// the agent work ran and the attempt was spent. That is F-242.
///
/// A blank id is treated exactly like a missing one: it satisfies the guard's
/// `!= null` check while naming no readable contract, which is the worse of the
/// two shapes — it converts "no contract" into "a contract that resolves to
/// nothing" downstream of the only guard that was supposed to catch it. The QA
/// drain (`qa_drain.dart`) already applies the same `trim().isEmpty` test to
/// the same column, so both reads of "no contract" agree by construction rather
/// than by coincidence.
bool workItemCarriesQaContract(WorkItem item) {
  final contractId = item.qaContractId;
  return contractId != null && contractId.trim().isNotEmpty;
}

/// The dispatch-time form of the completion transition's contract guard, for
/// the lanes whose workload is a single construction-time value.
///
/// ## Why this exists, and why it is a deferral
///
/// A producer job (triage, design revision) that dispatches a contractless
/// work item cannot complete: `agentExecuting -> agentCompleted` refuses on
/// `qaContractExists()` after the agent work has run, and the attempt is spent
/// on a gate that could never have passed. The check therefore belongs BEFORE
/// any work is consumed, and the seam every `Scheduler` offers for it is
/// [WorkloadResolver] — invoked in `_dispatchOne` ahead of the request build,
/// the worker selection and the claim. Returning `null` leaves the job queued
/// with its retry budget untouched; the item is reported on the tick's
/// `blockedArtifactMissing` channel and the next tick asks again.
///
/// That is the identical shape `ImplementationReadinessProbe` gives the
/// implementation lane (`implementation.deferred.qa_contract_missing`): this
/// lane does not mint the contract, does not fail the item, and does not raise
/// a human decision — it declines to spend an execution on an item whose
/// completion is impossible today. Resumable, not terminal: the provisioning
/// lanes stamp a contract at creation, and the repair tooling attaches a real
/// one from the product's declared spec to a row that has none, so a deferred
/// item dispatches on the first tick after its contract lands.
///
/// ## Why the event name is a parameter
///
/// The three producer lanes share one rule but not one log surface: a reader
/// grepping `*.deferred.qa_contract_missing` must be able to tell WHICH lane
/// declined. Each caller therefore names its own event rather than this file
/// spelling one for all of them.
WorkloadResolver qaContractGatedWorkloadResolver({
  required SchedulerWorkload workload,
  required String deferralEvent,
  void Function(String event, Map<String, dynamic> data)? log,
}) {
  return (job, item) async {
    if (workItemCarriesQaContract(item)) return workload;
    try {
      log?.call(deferralEvent, {
        'workItemId': item.workItemId,
        'jobId': job.jobId,
        'productId': item.productId,
        'state': item.state.wire,
        'reason':
            'the work item carries no QA contract id, so the '
            'agentExecuting -> agentCompleted guard can never pass for it. '
            'Dispatching now would spend an agent run and the job\'s attempt '
            'on a transition that refuses by construction',
        'action':
            'deferred. Not dispatched, not failed, no human decision raised '
            'and no retry consumed: the next tick asks again',
      });
    } on Object {
      // Swallowed deliberately, and only the fault is swallowed: the deferral
      // below is still returned. A log sink that raises on a closed pipe must
      // not upgrade "do not dispatch" into a throw that leaves `tick()` and
      // aborts the pass for every other job — the identical rule
      // `ImplementationReadinessProbe._deferred` documents for its own sink.
    }
    return null;
  };
}

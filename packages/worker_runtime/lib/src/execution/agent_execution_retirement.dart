import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// The id `LocalWorker` derives for the agent execution behind one worker
/// execution: `'agx-<workerExecutionId>'`.
///
/// This rule is load-bearing beyond the worker that writes it. The
/// `worker_execution` row is only stamped with `agentExecutionId` on its
/// TERMINAL write — a row stuck mid-run at `agentExecuting` names no agent
/// execution even though `agx-<its id>` already exists in `agent_execution`.
/// Reconciliation therefore cannot join the two rows through the stored link
/// alone; it derives the id through the SAME rule the producer used, which is
/// why the rule lives in one function both sides call: a second spelling of
/// the prefix is a silent failure to ever find the row, and `Scheduler`
/// already relies on this exact derivation to chase
/// `Job -> WorkerExecution -> AgentExecution`.
///
/// Attempt-scoped ids carry through unchanged: the scheduler re-spells the
/// worker execution id as `'wx-<jobId>:a<attempt>'` on retry, and the agent
/// execution id derives from that re-spelled id, so
/// `agx-wx-<jobId>:a2` is resolved the same way.
String agentExecutionIdForWorkerExecution(String workerExecutionId) =>
    'agx-$workerExecutionId';

/// Drives one still-open `agent_execution` row to a terminal record that its
/// own drive can no longer write.
///
/// The seam exists because the writer that owns this row — the
/// `ExecutionCoordinator` behind the dead drive — cannot be named from
/// `packages/scheduler`: `execution_coordinator` is deliberately not a
/// dependency of anything above `worker_runtime`. The composition root closes
/// the gap exactly the way it closes the liveness gap: this package supplies
/// the store-backed implementation ([storeBackedAgentExecutionRetirement])
/// and injects it as a function value, so the caller holds a capability
/// rather than a class it may not import.
///
/// Contract on the implementation:
///
///  * a MISSING row is a no-op, not an error — the worker row is only linked
///    on its terminal write, so the id passed in is often derived and the
///    derivation may name nothing;
///  * an ALREADY-TERMINAL row is a no-op — a reclaim is idempotent on
///    re-reclaim, and a live finalize that beat the reclaim keeps its verdict;
///  * a non-terminal row is closed ATOMICALLY (CAS on its version) — losing
///    the compare-and-swap to a concurrent writer is a correct outcome, not a
///    failure, because someone else already settled the row.
typedef AgentExecutionRetirement =
    Future<void> Function(
      String agentExecutionId, {
      required DateTime now,
      required String reason,
    });

/// The [AgentExecutionRetirement] backed by a real [ExecutionStore].
///
/// The row settles `orphaned` — the status `ExecutionCoordinator
/// .reconcileOrphans` already uses for "the process driving this execution is
/// gone" — rather than `failed`, because nothing here observed the agent
/// actually failing: the reclaim's verdict is about the DRIVE, not the work.
/// `interrupted` is the budget-expiry verdict and would claim a timeout that
/// never fired; `cancelled` would claim an operator act that never happened.
///
/// The status write and its audit event land in ONE transaction, the same
/// shape `reconcileOrphans` commits: the terminal row is never persisted
/// without the event that says who closed it and why. The event sequence is
/// derived from the durable log rather than from in-process state — the
/// process that would have numbered these events is exactly the one that died.
///
/// The compare-and-swap is the concurrency guard, and its loss is swallowed:
/// a live finalize, `reconcileOrphans`, or a racing reclaim that already
/// settled the row has reached the same verdict by a different route.
/// Anything else thrown by the store propagates — a store that cannot accept
/// the write leaves the row non-terminal, which the caller must see so it
/// does not record a terminal job above a still-open execution.
AgentExecutionRetirement storeBackedAgentExecutionRetirement(
  ExecutionStore store,
) {
  return (agentExecutionId, {required now, required reason}) async {
    final execution = await store.readExecutionOrNull(agentExecutionId);
    if (execution == null || execution.isTerminal) return;

    try {
      await store.inTransaction((tx) async {
        final retired = execution.copyWith(
          status: AgentSessionStatus.orphaned,
          reason: reason,
          completedAt: now,
          version: execution.version + 1,
        );
        await tx.saveExecution(retired, expectedVersion: execution.version);

        var maxSeq = 0;
        for (final event in await tx.readEvents(agentExecutionId)) {
          if (event.sequence > maxSeq) maxSeq = event.sequence;
        }
        final sequence = maxSeq + 1;
        await tx.appendEvent(
          AgentEventRecord(
            eventId: 'evt-$agentExecutionId-orphaned-$sequence',
            executionId: agentExecutionId,
            workItemId: execution.workItemId,
            sequence: sequence,
            type: AgentEventType.executionFailed,
            occurredAt: now,
            payload: {'kind': 'orphaned', 'reason': reason},
          ),
        );
      });
    } on ConcurrentExecutionModificationException {
      // Another writer — a live finalize, reconcileOrphans, a racing reclaim —
      // settled the row first. Its verdict stands; re-running this is a no-op
      // on the already-terminal row.
    }
  };
}

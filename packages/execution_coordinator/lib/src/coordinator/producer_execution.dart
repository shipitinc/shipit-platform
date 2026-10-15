import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import '../store/execution_store.dart';

/// How the producing execution was identified, and why the other two answers
/// are not acceptable.
///
/// ## THE BUG THIS TYPE EXISTS TO KILL
///
/// `agentCompleted -> reviewInProgress` is guarded by `agentResultValid()`,
/// which requires `context['agentResult']` to be a COMPLETED result. The
/// coordinator used to supply it from `latestExecutionForWorkItem` — the newest
/// execution of ANY role. That is correct exactly once, for the first review of
/// an item, and wrong forever after: once a reviewer execution exists it is the
/// newest row, so the guard was handed the REVIEWER's result.
///
/// Three consequences, all measured on QA before the fix
/// (`docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §2):
///
///  * a reviewer that FAILED permanently blocked the next review of the same
///    item — the edge became unsatisfiable for ever, so the item was
///    self-locking;
///  * the engine recorded each attempt as `outcome = 'rejected'`, and the
///    scheduler's deferral detector read the recurrence as "movement", so a
///    correct breaker was defending against a loop that a correct state machine
///    was refusing; and
///  * `WorkItemSupersededException` was raised, whose own documentation says
///    "the item moved between the load above and this write" — false here, since
///    nothing moved at all.
///
/// Reviewing a reviewer's outcome as precondition evidence for entering review
/// is a category error. **The item is `agent_completed` because an implementer
/// ran and succeeded; that is the evidence the guard exists to read.**
enum ProducerResolution {
  /// Read from `work_item.metadata['producerActorId']` — the identity the
  /// coordinator stamped in the SAME `transition()` call that put the item into
  /// `agent_completed`.
  ///
  /// This is the PRIMARY answer and it is preferred for three reasons:
  ///
  ///  1. **It is co-written with the state it explains.** `_completeSuccess`
  ///     performs one `workflowEngine.transition(..., to: agentCompleted,
  ///     metadataMerge: {'producerActorId': executionId})`. The stamp and the
  ///     state are one durable fact, so the stamp cannot drift from why the item
  ///     is where it is. Recency cannot make that claim about anything.
  ///  2. **It names an execution id exactly**, so it is a single primary-key
  ///     read. The fallback below reads every execution the item has ever held.
  ///  3. **It is the identifier the rest of the platform already treats as
  ///     authoritative.** `producedCommitFor`
  ///     (`packages/scheduler/lib/src/implementation_inflow.dart`) resolves
  ///     "which run produced this item" through exactly this field, and refuses
  ///     closed rather than guessing. A second, different rule for the same
  ///     question is how two components come to disagree about one work item —
  ///     see the sibling's own note on "the writer and the reader were different
  ///     stores".
  stampedProducer,

  /// No usable stamp, so the newest execution whose [AgentExecution.role] is
  /// [AgentRole.implementer] was taken instead.
  ///
  /// ## WHY THIS FALLBACK EXISTS RATHER THAN FAILING CLOSED
  ///
  /// `producerActorId` was added to this repository after the first
  /// `agent_completed` items were already durable. Failing closed on an absent
  /// stamp would refuse a perfectly good review for a legacy item whose
  /// implementer completed successfully — **trading one self-lock for another.**
  /// The guard is there to reject an item whose producer did NOT succeed, not
  /// to reject an item that predates a field.
  ///
  /// ## WHY THIS IS NOT A GUESS
  ///
  /// `AgentExecution.role` is a durable column, not an inference. Filtering by
  /// it is the same class of read as the stamp, one step less precise. The
  /// alternative it replaces — "whatever ran most recently" — is the guess, and
  /// it is the defect.
  ///
  /// NEWEST implementer, not any implementer: an item at `agentCompleted` can
  /// only have got there through `(agentExecuting, agentCompleted)`, and any
  /// later implementer run would have had to move the item off
  /// `agentCompleted` to start. So on an item in this state the newest
  /// implementer is the one whose success put it here.
  implementerRole,

  /// No producer could be identified: no usable stamp and no implementer
  /// execution, or the stamp names an execution that does not exist.
  ///
  /// Carries no result, so a caller that supplies it to `agentResultValid()`
  /// omits the key and the engine refuses the edge. That is the honest answer —
  /// `agentCompleted` is not true without a completed producer.
  none,
}

/// Which execution PRODUCED a work item, and the result that execution left.
///
/// Deliberately a value rather than a bare `AgentResult?`: "no producer" and
/// "a producer whose result could not be read" are the same refusal to the
/// guard, and they are very different facts to a human reading a log. [how] and
/// [note] keep them apart, and [note] is written to be read.
@immutable
class ProducerExecution {
  const ProducerExecution._({
    required this.how,
    required this.executionId,
    required this.result,
    required this.note,
  });

  /// No producer. [note] says why.
  const ProducerExecution.absent(String note)
    : this._(
        how: ProducerResolution.none,
        executionId: null,
        result: null,
        note: note,
      );

  /// How this execution was identified. See [ProducerResolution].
  final ProducerResolution how;

  /// The producing execution's id, or null when [how] is
  /// [ProducerResolution.none].
  final String? executionId;

  /// The producing execution's durable result, or null when it could not be
  /// read.
  ///
  /// A null here NEVER means "the producer did not succeed" on its own; it can
  /// also mean the row exists and carries no result. Either way the caller must
  /// omit `agentResult` and let `agentResultValid()` refuse, which is correct:
  /// the guard reads a completed result or it reads nothing.
  final AgentResult? result;

  /// One sentence, safe to log. Never a credential — every value interpolated
  /// into it is a work item id or an execution id.
  final String note;

  /// Whether an execution was identified at all.
  ///
  /// Distinct from "the producer succeeded": a resolved producer whose [result]
  /// is null or whose result is not [AgentResultStatus.completed] must still be
  /// refused by `agentResultValid()`. Only the guard decides that.
  bool get isResolved => how != ProducerResolution.none;

  @override
  String toString() => 'ProducerExecution($how, $note)';
}

/// Resolves the execution that PRODUCED [workItemId] — the one whose completed
/// result is the evidence `agentResultValid()` is meant to read.
///
/// [producerActorId] is the work item's `metadata['producerActorId']`, passed in
/// rather than read here so this function depends on an [ExecutionStore] alone
/// and is testable without a workflow store.
///
/// ## THE PROPERTY THIS GUARANTEES
///
/// > An item whose producer execution completed successfully can enter review
/// > **regardless of what any reviewer execution did, in any order, any number
/// > of times.**
///
/// and, in the other direction:
///
/// > An item at `agent_completed` with a **failed** producer is still refused.
///
/// Both are properties of which row is read, so both are asserted directly in
/// `test/producer_execution_resolution_test.dart` — the happy path alone would
/// have passed with the original defect in place.
///
/// ## WHAT THIS DELIBERATELY NEVER DOES
///
/// It never falls back to "the newest execution of any role", and it never
/// fabricates a result to satisfy a guard. See [ProducerResolution].
Future<ProducerExecution> resolveProducerExecution({
  required ExecutionStore store,
  required String workItemId,
  Object? producerActorId,
}) async {
  final stamped = producerActorId;
  if (stamped is String && stamped.isNotEmpty) {
    final execution = await store.readExecutionOrNull(stamped);
    if (execution == null) {
      return ProducerExecution.absent(
        'the producerActorId recorded on this work item ($stamped) names no '
        'execution, so nothing identifies what produced it and nothing may be '
        'guessed at',
      );
    }
    return ProducerExecution._(
      how: ProducerResolution.stampedProducer,
      executionId: execution.executionId,
      result: await store.readResult(execution.executionId),
      note:
          'read the producer execution named by the work item\'s own '
          'producerActorId ($stamped), role ${execution.role.wire}',
    );
  }

  final candidates = (await store.listExecutions(
    workItemId: workItemId,
  )).where((e) => e.role == AgentRole.implementer).toList();
  if (candidates.isEmpty) {
    return ProducerExecution.absent(
      'this work item records no producerActorId and has no implementer '
      'execution, so nothing identifies what produced it and nothing may be '
      'guessed at',
    );
  }
  final producer = _newest(candidates);
  return ProducerExecution._(
    how: ProducerResolution.implementerRole,
    executionId: producer.executionId,
    result: await store.readResult(producer.executionId),
    note:
        'no producerActorId is recorded, so the newest implementer execution '
        '(${producer.executionId}) was read by role',
  );
}

/// The most recently STARTED of [candidates]; a row with no start time sorts
/// last rather than first.
///
/// Matches `latestExecutionForWorkItem`'s ordering rule so the two agree on
/// what "newest" means — the difference between them is the ROLE FILTER, and
/// keeping the ordering identical keeps that difference the only one.
AgentExecution _newest(List<AgentExecution> candidates) {
  var newest = candidates.first;
  for (final candidate in candidates.skip(1)) {
    final current = newest.startedAt;
    final next = candidate.startedAt;
    if (next != null && (current == null || next.isAfter(current))) {
      newest = candidate;
    }
  }
  return newest;
}

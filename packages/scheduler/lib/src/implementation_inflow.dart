import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_runtime/worker_runtime.dart' show WorkerStore;

/// Why a completed producer left no commit behind.
///
/// Five shapes, because "there is nothing to review" is one sentence sent to
/// an operator and five different problems with five different fixes: a
/// missing identity is a producer that never ran, an ambiguous identity is two
/// runs that cannot be told apart, a reviewer-only match means the anchor is
/// wrong, and the last two are the honest answer for a triage report.
enum NoProducedCommitReason {
  /// No `producerActorId` on the work item: nothing recorded who produced it.
  producerNotIdentified,

  /// No worker execution carries the producing identity at all.
  producerExecutionMissing,

  /// More than one execution carries it. They cannot be told apart from this
  /// data, so the answer is "unknown", not "the newest one".
  producerExecutionAmbiguous,

  /// The only match is a reviewer execution, and a reviewer never produces a
  /// commit — so the anchor is not pointing at a producer.
  producerExecutionIsReviewer,

  /// The execution ran and committed nothing: `endingRevision` is null, or is
  /// the very revision it started from. **This is the triage shape** — the
  /// defect row was written, no file was.
  noCommitProduced,
}

/// What the producer of a completed execution left behind.
///
/// Sealed, and the two cases are named rather than a nullable commit id,
/// because the whole mechanism turns on the difference between "there is a
/// commit" and "there is not" and a bare `String?` invites a caller to treat
/// an unreadable revision as an absent one.
@immutable
sealed class ProducedCommit {
  const ProducedCommit(this.reason);

  /// Operator-facing, safe to log. Never a credential; every value interpolated
  /// into it is a work item id, an execution id or a git revision.
  final String reason;

  /// True when a commit exists that differs from the revision the producing
  /// execution started at.
  bool get isProduced => this is CommitProduced;

  /// [reason], and NOT the default `Instance of '…'`.
  ///
  /// Overridden because this value is interpolated into operator-facing log
  /// lines and into `CompletionInflowMove.reason`, and the default rendering
  /// would turn "this item was routed to implementation because its producer
  /// committed nothing" into "because Instance of 'NoCommitProduced'". A
  /// reason that cannot be read is not a reason, and it fails quietly: the
  /// route still happens correctly.
  @override
  String toString() => reason;
}

/// A commit exists, and it is identifiable to exactly one execution.
final class CommitProduced extends ProducedCommit {
  const CommitProduced({required this.repositoryPath, required this.commit})
    : super('a commit was produced that differs from the starting revision');

  /// Where the commit lives. Read but never dispatched against by this
  /// function: what it decides is WHICH LANE owns the item next, not where a
  /// worker runs.
  final String repositoryPath;

  /// The produced revision.
  final String commit;
}

/// No commit. See [NoProducedCommitReason] for which kind of "no" it is.
final class NoCommitProduced extends ProducedCommit {
  const NoCommitProduced(this.cause, String reason) : super(reason);

  final NoProducedCommitReason cause;
}

/// Decides whether the producer of [item]'s last completed run left an
/// implementation artifact.
///
/// ## THIS IS THE SAME RULE, OVER THE SAME ROWS, AS THE REVIEW GATE'S
///
/// It is a deliberate transcription of `engineeringReviewWorkloadResolver`
/// (`apps/server/lib/src/review/engineering_review_gate.dart`), and being a
/// transcription is the point — two independent rules for "did this run produce
/// something reviewable" is how a real commit gets sent to the build queue and
/// a reviewer gets sent to a revision nobody committed. The anchor, the
/// reviewer filter, the exactly-one rule and the commit-inequality are all
/// identical, and a test asserts they cannot drift apart.
///
/// ## WHY THE ANCHOR AND NOT THE LATEST EXECUTION
///
/// `WorkerExecution` carries no role field, so "the implementer's execution"
/// cannot be read off it directly. The one identifier that joins the two
/// durable records is the producing execution id the coordinator stamps onto
/// the work item's metadata as `producerActorId` on the success branch
/// (`ExecutionCoordinator._completeSuccess`).
///
/// Recency would be wrong. `LocalWorker` commits for every non-reviewer role,
/// so a LATER triage run is exactly as much a candidate as an implementer's.
/// "Latest" would treat the triage commit as if it were the implementation.
///
/// ## WHY IT FAILS CLOSED IN EVERY DIRECTION
///
/// Every refusal returns [NoCommitProduced], never a guess. That routes the
/// item to the implementation lane — which is a DEFECT attempt, not a wrong
/// review: the worst outcome is a build that produces nothing, which lands back
/// at `agentCompleted` and is bounded by [maxImplementationInflows]. The
/// opposite failure, calling a commit absent when one exists, would send real
/// work to a second implementer and manufacture a duplicate commit. The
/// asymmetry is deliberate and it is the reason every uncertainty resolves the
/// same way.
Future<ProducedCommit> producedCommitFor(
  WorkerStore workerStore,
  WorkItem item,
) async {
  final producerActorId = item.metadata?['producerActorId'];
  if (producerActorId is! String || producerActorId.isEmpty) {
    return const NoCommitProduced(
      NoProducedCommitReason.producerNotIdentified,
      'no producerActorId is recorded on this work item, so nothing says who '
      'produced it and nothing may be guessed at',
    );
  }

  final matches = <WorkerExecution>[];
  for (final execution in await workerStore.listWorkerExecutions()) {
    if (execution.workItemId != item.workItemId) continue;
    if (execution.agentExecutionId != producerActorId) continue;
    if (execution.requiredCapabilities.contains(
      WorkerCapability.engineeringReview,
    )) {
      continue;
    }
    matches.add(execution);
  }

  if (matches.isEmpty) {
    return NoCommitProduced(
      NoProducedCommitReason.producerExecutionMissing,
      'the producerActorId recorded on this work item names no worker '
      'execution, so there is nothing whose artifact could be identified',
    );
  }
  // Exactly one producer. Two executions carrying the same agent execution id
  // cannot be told apart from this data, so refusing beats picking one.
  if (matches.length != 1) {
    return NoCommitProduced(
      NoProducedCommitReason.producerExecutionAmbiguous,
      '${matches.length} worker executions carry the producerActorId recorded '
      'on this work item and they cannot be told apart from durable state, so '
      'no artifact can be attributed to one of them',
    );
  }

  final producer = matches.single;
  if (producer.requiredCapabilities.contains(
    WorkerCapability.engineeringReview,
  )) {
    return const NoCommitProduced(
      NoProducedCommitReason.producerExecutionIsReviewer,
      'the only execution matching this work item\'s producer identity is a '
      'reviewer, and a reviewer never produces a commit',
    );
  }

  final produced = producer.endingRevision;
  if (produced == null || produced == producer.requestedStartingRevision) {
    return NoCommitProduced(
      NoProducedCommitReason.noCommitProduced,
      'the producing execution reached ${producer.requestedStartingRevision} '
      'and finished at ${produced ?? 'nothing'}, so it committed no code. It '
      'produced a report, not an artifact',
    );
  }

  return CommitProduced(
    repositoryPath: producer.repositoryPath,
    commit: produced,
  );
}

/// Where a completed producer's work item goes next — `OD-10`'s discriminator.
///
/// * the producer left a commit → **review**, unchanged. A reviewer must see
///   it, and routing it anywhere else would manufacture a duplicate of work
///   that already exists.
/// * the producer left none → **implementation**. This is the producer's
///   whole report: nothing was committed, so there is nothing to review and a
///   reviewer would fail closed on it for ever. The operator's recorded intent
///   is verbatim: *"After triage completes, the item goes to
///   implementationReady instead of waiting at a human gate."*
///
/// One function, one `switch`, both cases named. It is deliberately NOT
/// inlined at its call site: the asymmetry above is the safety argument, and an
/// inline `if` is where an asymmetry silently becomes a symmetry.
WorkItemState completionRouteFor(ProducedCommit produced) => switch (produced) {
  CommitProduced() => WorkItemState.reviewInProgress,
  NoCommitProduced() => WorkItemState.implementationReady,
};

/// How many times the inflow may put ONE work item into the implementation
/// lane without a human in the loop.
///
/// ## WHY A BOUND IS NOT OPTIONAL
///
/// The route closes a cycle:
/// `agentCompleted -> implementationReady -> agentExecuting -> agentCompleted`.
/// A producer that commits nothing returns the item to `agentCompleted` with
/// no commit again, and the discriminator says "implement" again. Unbounded,
/// that is an unattended machine burning a real worker execution every tick on
/// an item that can never be implemented — the exact defect this lane exists to
/// end, re-created with a different shape.
///
/// ## WHY IT IS AN ATTEMPT COUNT AND NOT A FAILURE
///
/// Refusing the route is not a failure and not a drop. The item is left at
/// `agentCompleted`, where `sched-review` already offers it to the reviewer
/// every tick; the review workload resolver refuses it for the same reason
/// this one does, and the composition root's existing fail-closed handler
/// turns that into a blocking human decision. So the bound does not strand the
/// item — it hands it to a person, which is where an item nobody can implement
/// belongs.
///
/// Three, because each attempt costs a real implementer execution and the
/// historical budget for a lane that re-dispatches the same work is two
/// (`implementFeatureDefinition.maxAttempts` is the JOB's retry budget, which
/// is a different quantity and counts retries of one dispatch rather than
/// re-entries into the lane).
const int maxImplementationInflows = 3;

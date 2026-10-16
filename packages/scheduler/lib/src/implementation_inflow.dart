import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_runtime/worker_runtime.dart' show WorkerStore;

/// The `WorkItem.metadata` key carrying the coordinator's artifact verdict for
/// the completion that last settled the item.
///
/// ## THIS IS A WIRE CONTRACT WITH ANOTHER PACKAGE, AND IT IS DECLARED TWICE
///
/// `packages/execution_coordinator` WRITES it
/// (`SuccessArtifactArtifacts.undeterminedMetadataKey`) and this file READS it.
/// Neither package may depend on the other: `execution_coordinator` cannot
/// depend on `worker_runtime` (which depends on it), and `scheduler` sitting
/// above both is the only direction the graph allows. So the key is spelled out
/// on both sides, exactly as `producerActorId` already is — and
/// `test/undetermined_brake_contract_test.dart`, "one key, declared twice",
/// pins the two literals to each other, which `producerActorId` is not pinned
/// by. That pin is the price of the shared key, and paying it is why a rename
/// fails a test instead of silently disabling a brake.
///
/// ## WHY THIS AND NOT `agent_event`
///
/// The same marker is ALSO written into `_Completion.eventPayload`, which
/// reaches `ExecutionStore.appendEvent` and the `agent_event` table. That row
/// is kept — it is the record an operator reads — and it is not the channel the
/// brake uses, because `PostgresWorkerStore` reads `worker_execution`,
/// `worker_result` and `worker_event` and never `agent_event`. Publishing there
/// alone is how the unbounded loop went unnoticed: the verdict was recorded
/// faithfully, in a table nobody reads, by a package the scheduler cannot even
/// import.
const String successArtifactUndeterminedMetadataKey =
    'successArtifactUndetermined';

/// The `WorkItem.metadata` key carrying how many CONSECUTIVE completions came
/// back `UNDETERMINED`, spent by this lane's automatic route.
///
/// Written by exactly one writer — the completion inflow's own
/// `metadataMerge`, in the same transaction as the route it authorises — and
/// read by exactly one reader. See [maxConsecutiveUndeterminedReturns].
const String undeterminedReturnStreakMetadataKey =
    'successArtifactUndeterminedStreak';

/// How many consecutive `UNDETERMINED` completions the platform will absorb
/// before it stops taking the automatic route and hands the item to a human.
///
/// ## WHAT THE OPERATOR CHOSE, VERBATIM
///
/// Human decision on finding H1: **"Stop auto-routing after N undetermined
/// returns."** This constant is the N.
///
/// ## WHY `UNDETERMINED` NEEDS ITS OWN BOUND AT ALL
///
/// `RoleAwareSuccessArtifacts` deliberately refuses to call an unreadable
/// workspace "no artifact". That is right — a wedged filesystem is not an agent
/// that did nothing — but it has a consequence the `MISSING` path does not: a
/// run classified `UNDETERMINED` still completes normally, still reaches
/// `agent_completed`, still leaves no commit for `producedCommitFor`, and is
/// therefore still routed to `implementationReady`. Every pass spends a real
/// implementer execution. With `maxImplementationInflows` gone and `maxAttempts`
/// being a JOB budget that each pass resets by minting a fresh job, there is
/// nothing left to stop it. This is that something.
///
/// ## WHY THREE, AND NOT ONE MORE OR ONE LESS
///
/// The spend is `N - 1`: the Nth undetermined return is REFUSED, so the
/// platform buys at most **two** unattended implementer executions before it
/// stops.
///
/// Two is not an arbitrary number, it is the number this platform already
/// spends on a machine retry of this very job type:
/// `implementFeatureDefinition.maxAttempts` is 2, and `Scheduler._adopt`'s own
/// documentation states the contract as "exactly N executions, never N+1". So
/// the brake grants a platform-tooling fault the same single retry a routine
/// transient failure gets, and not one execution more. Stating it as `N - 1 ==
/// maxAttempts` is what keeps the value honest: a future edit to either number
/// has to confront the other.
///
/// One less (N = 2) would escalate on a SINGLE probe fault. That is the wrong
/// threshold for this probe specifically: `GitWorkspaceDeltaProbe` runs one or
/// two git subprocesses per completion under a 30s timeout, so a single slow or
/// contended filesystem is the expected transient shape rather than a fault worth
/// a human decision. A brake that fires on the first blip gets ignored by the
/// first operator who sees it, and then it is not a brake.
///
/// One more (N = 4) would buy a third execution. The cause here is the
/// PLATFORM'S, not the agent's: a missing `git`, a wedged mount and an expired
/// probe timeout are not conditions that an extra pass of the same broken
/// tooling repairs. If one retry has not fixed it, the next execution buys no
/// information — it buys a bill, against a durable clone, with a four-hour
/// budget. Measured, each of those passes is minutes of real execution.
///
/// ## WHY IT IS A RETURN COUNT AND NOT AN EXECUTION COUNT
///
/// Because a return is the fact that is OBSERVED. Whether that return spent an
/// execution is this lane's business, and this lane knows — but the return is
/// what both ends of the platform can see, which is what makes the counter
/// legible to an operator reading `work_item.metadata` in SQL.
const int maxConsecutiveUndeterminedReturns = 3;

/// Whether the completion that last settled [item] could not establish its
/// artifact.
///
/// `false` for an ABSENT key, and that is the whole of the absence case: the
/// key is written on every completion the coordinator settles (including
/// `false`), so an absent one means only that this item has never been through
/// a coordinator that writes it. Absence is not evidence of a tooling fault and
/// must not be counted as one.
bool lastCompletionWasUndetermined(WorkItem item) =>
    (item.metadata ??
        const <String, dynamic>{})[successArtifactUndeterminedMetadataKey] ==
    true;

/// The consecutive-`UNDETERMINED` return count recorded on [item], or 0 when
/// absent.
///
/// ## WHY A PRESENT-BUT-UNREADABLE MARKER THROWS, LIKE `readTriageAttempt`
///
/// Because the two answers are "the platform has already decided this item has
/// had its budget" and "it has not", and guessing wrong in either direction is
/// a runaway. The same reasoning applies for the same reason: this value is
/// compared against a ceiling, so silently coercing a bad byte to 0 would reset
/// a brake and silently coercing it to the ceiling would park work on garbage.
///
/// It throws INSIDE `_routeOneCompletion`'s per-item guard, which turns that
/// throw into "leave this one item alone and say so", rather than out of
/// `tick`, which would cost the whole lane its pass.
int readUndeterminedReturnStreak(WorkItem item) {
  final marker =
      (item.metadata ??
      const <String, dynamic>{})[undeterminedReturnStreakMetadataKey];
  if (marker == null) return 0;
  return switch (marker) {
    final int value => value,
    final double value when value.isFinite && value == value.roundToDouble() =>
      value.toInt(),
    final String value when int.tryParse(value) != null => int.parse(value),
    _ => throw FormatException(
      'Unreadable $undeterminedReturnStreakMetadataKey on work item '
      '${item.workItemId}: expected an int, a whole-valued double or a '
      'numeric String, got ${marker.runtimeType} ($marker). Reading it as 0 '
      'would reset a spent brake; reading it as the ceiling would park work on '
      'a byte nobody wrote deliberately.',
    ),
  };
}

/// The streak the NEXT accepted route records — ONE arithmetic rule, the reason
/// this is a function.
///
/// [undetermined] true advances the count by exactly one; false resets it to
/// zero, which is what makes the counter measure CONSECUTIVE returns rather
/// than all-time ones: a determined completion in between is evidence that the
/// platform can see its own workspaces again, and it must not be remembered
/// against the item for ever.
int nextUndeterminedReturnStreak(WorkItem item, {required bool undetermined}) =>
    undetermined ? readUndeterminedReturnStreak(item) + 1 : 0;

/// Why a completed producer left no commit behind.
///
/// Four shapes, because "there is nothing to review" is one sentence sent to
/// an operator and four different problems with four different fixes: a
/// missing identity is a producer that never ran, an absent execution is a
/// stamp that names nothing, an ambiguous identity is two runs that cannot be
/// told apart, and the last one is the honest answer for a triage report.
///
/// ## WHY THERE IS NO "IT WAS A REVIEWER" SHAPE
///
/// There was one, and it was removed as unreachable rather than left to rot.
/// The candidate loop below SKIPS any execution carrying
/// `WorkerCapability.engineeringReview`, so by the time a single match has been
/// isolated it cannot be a reviewer — a case that can never be reached is
/// advertised in an operator-facing list of causes and reads as a diagnosis
/// nobody can act on. The reviewer is not lost: it is simply not a candidate,
/// which is the same answer the skip already gives.
enum NoProducedCommitReason {
  /// No `producerActorId` on the work item: nothing recorded who produced it.
  producerNotIdentified,

  /// No worker execution carries the producing identity at all.
  producerExecutionMissing,

  /// More than one execution carries it. They cannot be told apart from this
  /// data, so the answer is "unknown", not "the newest one".
  producerExecutionAmbiguous,

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
/// ## THIS IS THE ONE RULE THE REVIEW GATE ALSO USES
///
/// `engineeringReviewWorkloadResolver`
/// (`apps/server/lib/src/review/engineering_review_gate.dart`) CALLS this
/// function; it does not re-state it. Two independent transcriptions of "did
/// this run produce something reviewable" is how a real commit gets sent to
/// the build queue while a reviewer is sent to a revision nobody committed, so
/// the duplication was removed rather than asserted against — the dependency
/// runs from the app onto this package, which is the direction that already
/// exists (`apps/server` depends on `packages/scheduler`), so sharing costs
/// nothing and needs no inversion.
///
/// What sharing does NOT cover is the mapping from this verdict to each lane's
/// action. `engineeringReviewWorkloadResolver` still turns [CommitProduced]
/// into a workload and everything else into `null`, and that mapping lives in
/// a different package from [completionRouteFor], so no single function can
/// assert they are complementary. `apps/server/test/inflow_vs_review_route_test.dart`
/// EXECUTES both over the same durable rows and fails if they ever disagree.
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
/// review: the worst outcome is a build that produces nothing. The opposite
/// failure, calling a commit absent when one exists, would send real work to a
/// second implementer and manufacture a duplicate commit. The asymmetry is
/// deliberate and it is the reason every uncertainty resolves the same way.
///
/// ## WHY THAT IS NO LONGER A RUNAWAY
///
/// It was, and a constant in this file used to say so. `agentCompleted ->
/// implementationReady -> agentExecuting -> agentCompleted` is a cycle; an
/// implementer that commits nothing walks it, one real execution per pass; and
/// `maxImplementationInflows` was the brake, checked on the SHARED re-work
/// discriminator before this route was taken.
///
/// The brake is GONE — human decision `92d567e3-da03-4c43-99f4-e3726472f0ab`,
/// option `RETRY_LIMIT` = `REMOVE` — because it was refusing real work that a
/// human had already asked for, and because the loop is broken at a better
/// place. An implementation run that produced no artifact is a PERMANENT failure
/// in `packages/execution_coordinator`, so it never reaches `agentCompleted` at
/// all and the cycle has no implementer step to walk. A TRIAGE run still
/// legitimately arrives here having committed nothing — that is the whole point
/// of the route below — but triage commits nothing ONCE per pass, and the next
/// pass is an implementation, which either commits or fails permanently.
///
/// That rule is the loop's actual safety and it is NOT in this package. This
/// file ROUTES; it does not bound.
///
/// ## AND THE ONE WAY IT IS STILL WALKED — finding H1, and its brake
///
/// The permanent-failure rule covers a run that produced NO artifact. It does
/// not cover a run whose artifact could not be ESTABLISHED. `RoleAwareSuccess
/// Artifacts` returns `UNDETERMINED` — not `MISSING` — when git is absent, the
/// filesystem is wedged or the probe's 30s timeout expires, because reporting a
/// tooling fault as an agent that did nothing would be a verdict asserted
/// without a reading. That run is not failed, so it still reaches
/// `agentCompleted`, still leaves `endingRevision` where it was, and is still
/// routed to `implementationReady` here. Every pass spends a real implementer
/// execution, and nothing bounded it.
///
/// That is what [maxConsecutiveUndeterminedReturns] now bounds, through the
/// streak [nextUndeterminedReturnStreak] keeps on the work item's own metadata
/// and [lastCompletionWasUndetermined] seeds it from. It is scoped to entries
/// into THIS lane for the reason the removed bound was scoped: the commit route
/// spends nothing here, so a counter about this lane's entries has no standing
/// to refuse a route into another lane — and a producer that left a commit must
/// reach review whatever its probe reported.
///
/// So the standing condition, restated with its one remaining hole: if a producer
/// OTHER THAN triage can reach `agentCompleted` having produced no commit AND
/// without the coordinator having marked the completion `UNDETERMINED`, the
/// route below is taken for ever, because nothing here refuses it. That is the
/// exact shape the `MISSING` branch in `packages/execution_coordinator` exists
/// to prevent, and it is the shape to re-check first if a new lane is ever
/// pointed at `agentCompleted`.
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
  // No reviewer check here, and deliberately so. The loop above already skipped
  // every reviewer-capability execution, so `matches.single` cannot be one; a
  // second check on a value the loop has already excluded would be a branch no
  // input can reach. See `NoProducedCommitReason`.
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
///
/// ## WHAT USED TO BOUND IT, AND WHY THERE IS NOTHING HERE NOW
///
/// This function's caller used to refuse the `implementationReady` answer once
/// the shared re-work discriminator (`DurableWorkflowEngine
/// .triageAttemptMetadataKey`) read 3 or more — `maxImplementationInflows = 3`,
/// declared at the bottom of this file until human decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab` removed it.
///
/// The brake was on the WRONG counter and the WRONG items. The discriminator is
/// shared: the operator retry and a resolved rework/reject decision advance it,
/// so an item that entered the implementation lane ZERO times could already read
/// `3` because a person had pressed retry three times. The bound therefore spent
/// its budget on human-driven work, which is exactly the work a person had just
/// asked for, and left the four defects measured on live QA at
/// `agent_completed` with the marker reading 3 and 4 — refused by the inflow,
/// refused again by the review lane's fail-closed handler, and owned by nobody.
///
/// The loop it was catching — an unattended implementer that commits nothing
/// walking `agentCompleted -> implementationReady -> agentExecuting ->
/// agentCompleted` for ever — is broken upstream instead: an implementation run
/// that produced no artifact is a PERMANENT failure in
/// `packages/execution_coordinator`, so it never reaches `agentCompleted` and the
/// cycle has no implementer step to walk. See
/// `producedCommitFor`'s "WHY THAT IS NO LONGER A RUNAWAY".
WorkItemState completionRouteFor(ProducedCommit produced) => switch (produced) {
  CommitProduced() => WorkItemState.reviewInProgress,
  NoCommitProduced() => WorkItemState.implementationReady,
};

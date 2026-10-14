import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart'
    show ModelSelectionService;
import 'package:workflow_store/workflow_store.dart' show DurableWorkflowEngine;

/// The IMPLEMENTATION lane's job definition.
///
/// ## WHY A NEW DEFINITION AND NOT A WIDENED ONE
///
/// `RunnableWorkEvaluator.evaluate` rejects any work item whose state is not
/// in `definition.entryStates` BEFORE it consults the policy, a job-type
/// capability check or a product state (`policy/runnable_work.dart:142-144`).
/// Triage and implementation therefore cannot contend for one item if and only
/// if their entry sets are DISJOINT — and disjointness by construction survives
/// forgetting a guard, because there is no guard to forget. Adding
/// `implementationReady` to `triageDefectDefinition.entryStates` would destroy
/// that property; a sibling definition with a one-element entry set keeps it.
///
/// It is a SIBLING, not a replacement. `defaultImplementFeatureDefinition`
/// (`scheduler.dart`) is left byte-for-byte alone: it is `const`, it is
/// test-only in production, and roughly twenty test files use it as a generic
/// host. Repurposing it would churn all of them for no production benefit and
/// would make a diff that touches the triage lane's blast radius for no
/// reason.
///
/// ## WHY `implementationReady` AND NOTHING ELSE
///
/// One element, deliberately. `designNotRequired` and `designApproved` are
/// `triageDefectDefinition`'s; listing either here would put two definitions on
/// one item in the same tick, and `Scheduler.tick` reads EVERY work item
/// (`scheduler.dart`) and enqueues for every `runnable` one. The disjointness
/// argument in the design brief is only true because this set has no member in
/// common with any other production definition's set, and
/// `test/implement_feature_entry_disjointness_test.dart` asserts exactly that
/// against every one of them.
///
/// ## WHY NO `entryProbeTargets`
///
/// Declared absence is load-bearing. `EntryHopper.prepare` consults the map
/// only after it finds the direct edge missing, and
/// `test/entry_hop_drift_guard_test.dart` requires every entry state to be
/// either direct or hopped. The `implementationReady -> agentExecuting` edge
/// exists (`work_item_transitions.dart`), so this definition is `direct` and
/// the drift guard is satisfied with the map empty. Adding a hop target would
/// be a second, redundant route to a state the coordinator can already reach.
///
/// ## WHY THE POLICY PROBE STAYS LIVE
///
/// `skipWorkflowPolicyCheck` is left `false`. `engineeringReviewDefinition`
/// sets it `true` (`scheduler.dart`) because its edge carries
/// `agentResultValid()` and the scheduler has no execution of its own to supply
/// one — that is the counter-example, not the precedent. This definition's
/// entry edge carries only `actorAllowed([orchestrator])` and
/// `agentAvailable()`, both of which the scheduler's own context satisfies, so
/// the probe genuinely succeeds here and skipping it would discard a real
/// check.
///
/// ## WHY `git` IS IN THE CAPABILITIES
///
/// `defaultImplementFeatureDefinition` declares `{linux}` only, and selection
/// compares the job's set against the worker's. The implementer lane genuinely
/// commits: `ArtifactCommitter` runs `rev-parse`, `checkout -B`, `add -A` and
/// `commit`. A worker registered with only `{linux}` would never be selected for
/// these jobs, and the failure mode is a scheduler that defers for ever while
/// looking healthy. The composition root therefore registers the implementer
/// worker from THIS definition's own `requiredCapabilities` rather than from a
/// hand-copied list.
/// ## THE INFLOW — `OD-10`
///
/// `entryStates` stays exactly `{implementationReady}`. The second producer
/// does not WIDEN it, because widening it is what would put this lane and
/// `sched-review` on one item in the same tick — and that collision is
/// structurally impossible today only because the two sets are disjoint.
///
/// `completionInflowFrom` is the other half of that answer: before this lane
/// decides what is runnable, it ROUTES items it shares with another lane.
/// `agentCompleted` is `engineeringReviewDefinition.entryStates`, so every item
/// whose triage run has finished is visible here, and the discriminator
/// ([producedCommitFor]) says where each one belongs:
///
///  * the producer left a commit → `reviewInProgress`, and this lane does not
///    touch it. That is `sched-review`'s item and it is already dispatched.
///  * the producer left none → `implementationReady`. A triage run writes a
///    defect row and no file, so this is every item triage has ever finished,
///    and engineering review has been failing closed on all of them.
///
/// ## WHY THE ROUTE IS TAKEN HERE AND NOT BY `sched-review`
///
/// `sched-review` does the review, and its workload resolver already answers
/// the same question — it just answers it as "do not dispatch" rather than
/// "send it to the lane that can do the work". Making review perform the
/// handoff would put a production-lane decision inside a job that is not
/// allowed to dispatch, and would couple the two lanes' definitions. One
/// declaration, on the lane whose job is to route unimplemented work into
/// implementation, keeps the two responsibilities apart.
///
/// ## CYCLE SAFETY
///
/// The route can be taken again: an implementer that commits nothing returns
/// the item to `agentCompleted`. `maxImplementationInflows` bounds that, and
/// the bound hands the item to the existing fail-closed human decision rather
/// than dropping it.
const JobDefinition implementFeatureDefinition = JobDefinition(
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
  entryStates: {WorkItemState.implementationReady},
  priority: JobPriority.normal,
  maxAttempts: 2,
  completionInflowFrom: {WorkItemState.agentCompleted},
);

/// Builds a dedupe key for implementation jobs: (workItemId, jobType[, attempt]).
///
/// ## THE ATTEMPT SUFFIX — THE SEAM `OD-3` CLOSED
///
/// `JobQueue.enqueueIfAbsent` resolves a dedupe key that ANY job already holds,
/// terminal or not. The first dispatch of an implementation job therefore burns
/// `'<workItemId>:implement_feature'` for ever, and the SECOND time an item
/// reaches `implementationReady` — through a resolved rework, a QA rejection,
/// or this lane's own inflow — the enqueue returns `created: false` and the
/// re-run silently does nothing, with the item sitting in a dispatchable state
/// and nothing running.
///
/// That is the same defect `triageDefectDedupeKey` was written to close, and
/// it is closed the same way: the same durable `triageAttempt` marker, read
/// through the same reader ([DurableWorkflowEngine.readTriageAttempt]) that
/// stamps it ([DurableWorkflowEngine.nextTriageAttempt]). One counter, one
/// reader, one rule — so the number this builder asks for and the number the
/// engine writes cannot be derived two different ways and disagree, which
/// would build a key nothing holds and enqueue nothing.
///
/// That claim is only true because EVERY writer calls
/// [DurableWorkflowEngine.nextTriageAttempt]. It was not true when this
/// comment was first written: the completion inflow computed `attempt + 1`
/// inline at its own call site, which agreed only because `nextTriageAttempt`'s
/// `floor` defaults to `0`. The counter's own documentation names "two
/// writers, two different rules, one counter" as the hazard, and an inline
/// `attempt + 1` is exactly that hazard wearing a third writer's coat. It now
/// calls the function.
///
/// ## WHY THE ABSENT CASE IS BYTE-IDENTICAL TO TODAY
///
/// With no `triageAttempt` the key is exactly `'<workItemId>:implement_feature'`,
/// which is what every implementation job already persisted under. Re-spelling
/// the default would orphan them and, on the next tick, mint a SECOND job for
/// work already in flight. That property is not to be traded for anything.
///
/// ## WHY THE MARKER IS THE RIGHT COUNTER HERE
///
/// It is not named "triage" by accident: it is the re-work discriminator, and
/// `OD-3` made the implementation lane one of the lanes it counts for. It is
/// advanced by the operator retry and by every resolved rework/reject decision
/// — the two human intents that put an item back into production — and it is
/// bounded by [maxImplementationInflows] on the automatic route. An operator
/// retry advances it too, so pressing retry genuinely buys another attempt,
/// which is what the button promises.
String implementFeatureDedupeKey(WorkItem item, JobDefinition definition) {
  final base = '${item.workItemId}:${definition.jobType.wire}';
  final attempt = DurableWorkflowEngine.readTriageAttempt(item);
  if (attempt == null) return base;
  return '$base:a$attempt';
}

/// Builds an instruction for implementation jobs.
///
/// Says what to implement and what to leave alone, and — unlike the triage
/// instruction — asks for a verifiable outcome, because the engineering-review
/// gate downstream will refuse an execution that produced no commit and a run
/// whose verification fails must land in `agentFailed` without a
/// `producerActorId` rather than reaching review with no artifact.
String implementFeatureInstruction(WorkItem item, JobDefinition definition) {
  final metadata = item.metadata ?? {};
  final category = item.category.name;
  final acceptance = metadata['acceptanceCriteria'];
  final qaContractId = item.qaContractId;

  return '''Implement "${item.title}" (${item.workItemId}).

CATEGORY: $category
DESCRIPTION:
${item.description ?? 'No description recorded.'}
${acceptance == null ? '' : 'ACCEPTANCE CRITERIA:\n$acceptance\n'}
WORKING INSTRUCTIONS:
1. You are in a detached git worktree of this product's durable clone, pinned to
   an exact commit. Do NOT switch branches, rebase, or reset.
2. Make the smallest change that satisfies the description and acceptance
   criteria above. Match the surrounding code style.
3. Commit your work with a clear message. An execution that produces NO commit
   cannot be reviewed: engineering review fails closed on it and the work item
   is stranded. Committing nothing is not a valid way to finish this task.
4. Do not change the product manifest, dependency lockfiles, or CI configuration
   unless the task above explicitly asks for it.
5. Do not write credentials, tokens, or host names into the repository.
${qaContractId == null ? '' : 'QA CONTRACT: $qaContractId — the acceptance criteria there are the ones this run is judged against.\n'}

YOUR TASK:
Apply the change, commit it, and summarise what you changed and why.
''';
}

/// Builds a worker execution request for implementation jobs.
///
/// The workload is the one the readiness probe resolved — the product's DURABLE
/// clone at its recorded pin — never the construction-time default. The default
/// is `SchedulerWorkload` passed to `Scheduler`, which for this scheduler names
/// the triage repository; a request built against that would have the
/// implementer commit into a README-only scratch checkout, which is exactly the
/// fabrication hazard the probe exists to prevent.
Future<WorkerExecutionRequest> implementFeatureRequest(
  Job job,
  SchedulerWorkload workload,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
  return WorkerExecutionRequest(
    workerExecutionId: 'wx-${job.jobId}',
    workItemId: job.workItemId,
    repositoryPath: workload.repositoryPath,
    startingRevision: workload.startingRevision,
    requiredCapabilities: job.requiredCapabilities,
    role: job.requiredRole,
    instruction: job.instruction,
    timeoutSeconds: workload.timeoutSeconds,
    runtimeTypeId: workload.runtimeTypeId,
    cleanupPolicy: workload.cleanupPolicy,
    runtimeConfig: runtimeConfig,
  );
}

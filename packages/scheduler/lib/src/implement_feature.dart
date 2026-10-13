import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart'
    show ModelSelectionService;

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
const JobDefinition implementFeatureDefinition = JobDefinition(
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
  entryStates: {WorkItemState.implementationReady},
  priority: JobPriority.normal,
  maxAttempts: 2,
);

/// Builds a dedupe key for implementation jobs: (workItemId, jobType).
///
/// ## THE ATTEMPT SUFFIX IS DELIBERATELY ABSENT, AND THAT IS A KNOWN SEAM
///
/// `JobQueue.enqueueIfAbsent` resolves a dedupe key that ANY job already holds,
/// terminal or not. So the second time an item reaches `implementationReady`
/// the key is consumed and the enqueue returns `created: false` — the re-run
/// silently does nothing.
///
/// Today that is unreachable, and unreachable for a specific reason worth
/// recording rather than leaving to be discovered: the ONLY producer of
/// `implementationReady` is `waitingForHumanDecision -> implementationReady`,
/// and **no `HumanDecisionRouting` entry targets that state yet** — which pairs
/// move there is `OD-3`, and it is unanswered. `agentFailed -> designNotRequired`
/// (the operator retry) and `agentCompleted -> reviewInProgress` (review) are
/// both unaffected, so no existing path can strand an item here.
///
/// When `OD-3` is answered and rework routes here, this key must grow the
/// attempt discriminator that `triageDefectDedupeKey` already carries, read from
/// the durable `metadata` marker the engine stamps. Choosing the marker name
/// now, for a path that cannot be reached, would be inventing durable-format
/// policy for a lane that has not been decided to exist — and the absent form
/// is what keeps every job stored under the plain key matching.
String implementFeatureDedupeKey(WorkItem item, JobDefinition definition) =>
    '${item.workItemId}:${definition.jobType.wire}';

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

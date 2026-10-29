import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

/// Triage defect job: AI triage of a human-reported defect.
///
/// ## WHY `reviewRejected` IS AN ENTRY STATE
///
/// A human decision (option B, taken 2026-10-12) settled that a rejected
/// engineering review KEEPS its own state instead of collapsing into
/// `designNotRequired`, and is dispatchable from there. Before that,
/// `reviewRejected` was in no `entryStates` and was inert by construction: it is
/// the target of exactly one route — `HumanDecisionRouting.targetFor(
/// engineeringReview, reject)` — so a rejected review parked there forever
/// with its decision already answered and no job ever minted. `reviewRejected`
/// had no production caller for its own outgoing edge either:
/// `reviewRejected -> designNotRequired` exists in the engine transition table
/// and NOTHING in the repository takes it, which is the same dead end seen from
/// the other side.
///
/// The state is kept because "you rejected this" is a distinct fact from "this
/// needs a design" and an operator reading a collapsed state cannot tell a
/// rejection from a design decision. The DISPATCHABILITY is what stops the
/// rejection being terminal.
///
/// ## WHY IT NEEDS A PROBE TARGET OF ITS OWN
///
/// `RunnableWorkEvaluator` asks the policy "may an execution begin here?" by
/// probing `<entryState> -> definition.targetState`, and `targetState` defaults
/// to `agentExecuting`. `reviewRejected -> agentExecuting` is NOT an edge — it
/// was deliberately REMOVED, because `agentExecuting` asserts an execution is
/// already running and is in the `entryStates` of no wired definition. So
/// listing the state in `entryStates` alone classifies it `noAction` and nothing
/// is enqueued. That was verified, not assumed: with `reviewRejected` in
/// `entryStates` and no probe target, `RunnableWorkEvaluator.evaluate` returns
/// `noAction`, while `reviewRejected -> agentExecuting` is `false` and
/// `reviewRejected -> designNotRequired` is `true`.
///
/// So the state names its own legal hop. The hop is an ordinary edge into an
/// ordinary entry state, guarded only by `actorAllowed([orchestrator])` — the
/// scheduler's own actor type — so the policy answers it the same way it
/// answers `planned -> designNotRequired`. The question is still asked of the
/// policy, so widening this set cannot make an illegal entry state dispatchable.
///
/// ## WHAT ELSE REACHES `reviewRejected`
///
/// Nothing. `designApproval/reject` routes to `designRejected` — a DIFFERENT
/// state, and one already served by `designRevisionDefinition`. The
/// `designRejection` decision type has no `targetFor` entry at all. So this
/// change cannot pull a design rejection into the triage lane, and it does not
/// widen any other job's entry set. `test/triage_entry_state_drift_guard_test.dart`
/// asserts both halves of that against the live routing table.
///
/// ## WHY `planned` IS AN ENTRY STATE
///
/// The same dead end as `reviewRejected`, seen from the other side of the
/// table. `planned` had two legal edges out of it — `planned ->
/// designRequired` (guarded by `designContractExists()`) and `planned ->
/// designNotRequired` (unguarded) — and was in the `entryStates` of NO wired
/// `JobDefinition`. `RunnableWorkEvaluator` rejects a state outside `entryStates`
/// BEFORE it consults the policy, so `Scheduler.tick` never selected a `planned`
/// item, `EntryHopper.prepare` was never called on one, and both edges stayed
/// permanently unreachable. `planned` was therefore a state the platform could
/// ENTER and never LEAVE: `planning -> planned` had been taken 13 times, and the
/// route out stopped firing entirely on 2026-10-11, leaving work items parked
/// there while every tick reported `ran: true, failedSections: []` and
/// `dispatched: 0`.
///
/// Note the failure shape is the SILENT one, which is why it survived days: a
/// tick that enqueues nothing reports nothing, so a lane looks idle rather than
/// broken, and `entryHopRefused` is never even populated — the item is never
/// considered, so it is never refused.
///
/// `planned -> designNotRequired` is the right hop because it is the only one
/// available to an item with no design contract, and it is the ordinary
/// convention for an edge into an entry state: `actorAllowed([orchestrator])`
/// alone, which is the actor the scheduler already acts as
/// ([schedulerOrchestratorActor]). `planned -> designRequired` is not usable as
/// a blanket route precisely because it carries `designContractExists()` — see
/// the DELIBERATE CONSEQUENCE below.
///
/// ## IT NEEDS A PROBE TARGET FOR THE SAME REASON `reviewRejected` DOES
///
/// `planned -> agentExecuting` is not an edge (and must not become one —
/// `agentExecuting` is in no wired `entryStates`, so an item parked there is
/// never dispatched again). Listing `planned` alone would classify it `noAction`
/// and enqueue nothing. So the state names its own legal hop in
/// [JobDefinition.entryProbeTargets], exactly as `reviewRejected` does, and the
/// policy is asked about that edge rather than a private copy of the table being
/// consulted. `test/triage_entry_state_drift_guard_test.dart` derives the set of
/// entry states needing an override from the live policy and asserts the map
/// covers EXACTLY that set, so an override added or dropped wrongly fails by
/// name.
///
/// ## DELIBERATE CONSEQUENCE: A `planned` ITEM WITH A CONTRACT SKIPS THE DESIGN
/// LANE
///
/// `planned -> designNotRequired` is UNGUARDED, so this route does not ask
/// whether the item carries a design contract. An item at `planned` that DOES
/// carry one is therefore routed to `designNotRequired` rather than
/// `designRequired`, and would be triaged instead of designed.
///
/// That is accepted deliberately, and for a measured reason: every item observed
/// parked at `planned` had `designContractId` null and an empty artifact map, so
/// for them `planned -> designRequired` was unavailable and
/// `planned -> designNotRequired` was the only legal edge — the alternative was
/// leaving them parked for ever. The opposite is not left implicit: an item
/// whose producer creates the contract BEFORE planning completes reaches
/// `designRequired` directly through its own route and never sits at `planned`
/// with a contract, so the case this route mishandles is not the one production
/// reaches. `test/planned_entry_state_hop_test.dart` pins both halves — that the
/// hop is taken for a contract-less item, and that the contract-carrying case is
/// a named, recorded residual rather than a silent one.
///
/// CONDITIONAL ROUTING IS NOT EXPRESSIBLE HERE AND WAS NOT ATTEMPTED. Choosing
/// `designRequired` when a contract exists would need a probe target chosen by
/// the item's evidence, and [JobDefinition.entryProbeTargets] is a
/// `Map<WorkItemState, WorkItemState>` — static by construction, read without
/// the work item. Widening it is an architecture decision outside this file, and
/// is reported as a discovery rather than built here.
const JobDefinition triageDefectDefinition = JobDefinition(
  jobType: JobType.triageDefect,
  requiredRole: AgentRole.triageDefect,
  requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
  entryStates: {
    WorkItemState.designNotRequired,
    WorkItemState.reviewRejected,
    WorkItemState.planned,
  },
  entryProbeTargets: {
    WorkItemState.reviewRejected: WorkItemState.designNotRequired,
    WorkItemState.planned: WorkItemState.designNotRequired,
  },
  priority: JobPriority.high,
  maxAttempts: 2,
);

/// Builds a dedupe key for triage defect jobs: (defectId, jobType[, attempt]).
/// Only one active triage job per defect at a time.
///
/// ## Why the attempt suffix exists
///
/// Re-triage — a human-initiated "do this work again", whether that is an
/// operator retry or a resolved rework/reject decision — returns the work item
/// to a state this job can dispatch from, so the scheduler enqueues for it
/// again. But `JobQueue.enqueueIfAbsent` resolves a key that ANY job already
/// holds, terminal or not. The triage job for an item that has been triaged
/// once is TERMINAL, so its key is consumed for ever and reusing it returns
/// `created: false`: the re-triage silently does nothing, and the human who
/// asked for it watches nothing happen.
///
/// The discriminator has to be readable from the `WorkItem` alone, because
/// `DedupeKeyBuilder` is `String Function(WorkItem, JobDefinition)` —
/// synchronous, no store, no request context — and it runs on every tick for
/// every runnable item. `metadata['triageAttempt']` is written inside the
/// re-triage's own transaction — by `DurableWorkflowEngine.operatorRetry` for a
/// retry, and by `DurableWorkflowEngine.resolveHumanDecision` for a resolved
/// rework/reject decision — so it is durable before any tick can read it, and
/// it advances for EVERY route that re-enters triage, not only the retry
/// endpoint.
///
/// ## WHY THE ABSENT CASE IS BYTE-IDENTICAL TO TODAY
///
/// With no `triageAttempt` the key is exactly the historical format, so every
/// job already persisted under `'<workItemId>:triage_defect'` keeps matching
/// and this change orphans NOTHING. Re-spelling the default key would silently
/// strand every historical triage job and, on the next tick, enqueue a second
/// job for work that is already being handled. This property is not to be
/// traded for anything.
///
/// ## WHY THE READING IS DELEGATED, NOT REPEATED
///
/// The marker is read by [DurableWorkflowEngine.readTriageAttempt], which is
/// the same reader `DurableWorkflowEngine.nextTriageAttempt` uses to produce
/// the value stamped in the first place. Two copies of "how a marker is read"
/// is how a writer and a reader come to disagree about which numbers are
/// attempt numbers, and the disagreement would not throw — it would build a
/// different key and enqueue nothing.
///
/// That reader also owns the unreadable case: a marker that is PRESENT but is
/// not an int, a whole-valued double or a numeric String throws
/// [FormatException] rather than falling back to the historical key, because
/// that key is already consumed by the terminal job the re-triage exists to
/// replace. See that method for the full argument; it is stated once, here, to
/// record that this builder inherits it rather than choosing it.
String triageDefectDedupeKey(WorkItem item, JobDefinition definition) {
  final base = '${item.workItemId}:${definition.jobType.wire}';
  final attempt = DurableWorkflowEngine.readTriageAttempt(item);
  if (attempt == null) return base;
  return '$base:a$attempt';
}

/// Builds an instruction for triage defect jobs.
///
/// Every constrained value in the documented payload below is spelled as the
/// **wire token** the contracts serialise, not a friendlier Dart/display name.
/// This is load-bearing, not stylistic: the consumer of the agent's final
/// assistant text is `TriageProcessor._parseTriageResult` in `apps/server`,
/// which feeds the raw strings straight into `DefectClassification.fromWire`
/// and `DefectStatus.fromWire`. Both throw `FormatException` on an unknown
/// token, and `_parseTriageResult` converts that into a `null` `TriageResult` —
/// so an agent that faithfully follows a prompt spelling the values any other
/// way (`DESIGN_DEFECT`, `triaged`, `bug`) loses the whole triage outcome.
///
/// Consequences for future edits to the block below:
///   * `DefectClassification` / `DefectStatus` values go in as `.wire`
///     (lowercase, snake_case), never `.name` and never upper-cased.
///   * `DefectStatus` has no `triaged` member; the triage-stage token is
///     `triaging`.
///   * `WorkItemCategory` has no `wire` field — it serialises by `.name`, so
///     its names (`bugfix`, not `bug`; there is no `design`) go in verbatim.
///   * `confidence`, `suspectedCategory` and `recommendedNextAction` are free
///     `String`s in `TriageResult` with no enum behind them; they are
///     documented as vocabulary, not as a closed contract set.
///
/// `test/lane_m_triage_prompt_contract_test.dart` is the drift guard: it reads
/// the documented values back out of the generated string and asserts they
/// equal the live enum tokens, so adding or renaming an enum value fails CI
/// instead of silently un-parsing triage output.
String triageDefectInstruction(WorkItem item, JobDefinition definition) {
  final metadata = item.metadata ?? {};
  final defectId = metadata['defectId'] as String? ?? item.workItemId;
  final title = metadata['defectTitle'] as String? ?? item.title;
  final description =
      metadata['defectDescription'] as String? ?? item.description ?? '';
  final severity = metadata['defectSeverity'] as String? ?? 'medium';
  final expectedBehavior = metadata['defectExpectedBehavior'] as String?;
  final reproductionSteps = metadata['defectReproductionSteps'] as String?;
  final evidenceJson = metadata['defectEvidence'] as String? ?? '[]';

  return '''Perform AI triage of defect "${title}" (${defectId}).

DEFECT DETAILS:
- ID: ${defectId}
- Title: ${title}
- Severity: ${severity}
- Description: ${description}
- Expected Behavior: ${expectedBehavior ?? 'Not specified'}
- Reproduction Steps: ${reproductionSteps ?? 'Not specified'}

EVIDENCE:
${evidenceJson}

YOUR TASK:
Analyze the defect and output a STRUCTURED JSON result with exactly these fields:

{
  "classification": "implementation_defect" | "design_defect" | "requirement_gap" | "environment_defect",
  "status": "triaging",
  "confidence": <number between 0.0 and 1.0>,
  "suspectedCategory": "<free-form area, e.g. UI, backend, infrastructure, specification>",
  "suspectedComponents": ["<component1>", "<component2>"],
  "reproductionSupported": <boolean>,
  "evidenceUsed": ["<evidenceId1>", "<evidenceId2>"],
  "clarificationRequired": [
    {"question": "<specific question>", "reason": "<why this is needed>"}
  ],
  "recommendedNextAction": "investigate" | "fix" | "clarify" | "escalate" | "close_duplicate",
  "possibleDuplicateDefectId": "<defectId if duplicate suspected, else omit>",
  "recommendedWorkItemCategory": "feature" | "bugfix" | "refactor" | "docs" | "chore" | "security" | "performance",
  "summary": "<2-3 sentence summary of findings>"
}

RULES:
1. classification, status and recommendedWorkItemCategory MUST be spelled exactly as
   listed above, using those exact lowercase tokens. No other spelling is accepted
2. confidence MUST be a number 0.0-1.0
3. clarificationRequired MUST be an array (empty if none)
4. Do NOT include any prose outside the JSON output
5. If you cannot determine classification, use "implementation_defect" with low confidence
6. If human clarification is needed, include it in clarificationRequired array
7. evidenceUsed must reference evidence IDs from the provided evidence list
''';
}

/// Builds a worker execution request for triage defect jobs.
Future<WorkerExecutionRequest> triageDefectRequest(
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

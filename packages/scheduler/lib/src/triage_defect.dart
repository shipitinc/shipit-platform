import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// Triage defect job: AI triage of a human-reported defect.
const JobDefinition triageDefectDefinition = JobDefinition(
  jobType: JobType.triageDefect,
  requiredRole: AgentRole.triageDefect,
  requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
  entryStates: {WorkItemState.designNotRequired, WorkItemState.designApproved},
  priority: JobPriority.high,
  maxAttempts: 2,
);

/// Builds a dedupe key for triage defect jobs: (defectId, jobType).
/// Only one active triage job per defect at a time.
String triageDefectDedupeKey(WorkItem item, JobDefinition definition) =>
    '${item.workItemId}:${definition.jobType.wire}';

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

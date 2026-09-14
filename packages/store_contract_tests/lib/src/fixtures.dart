import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';

/// Shared fixture builders used by every contract suite. Values are chosen to
/// exercise every serialized field (nested maps, lists, nullable fields and
/// enum wires) of each domain type.
const kWorkItemId = 'wi-0001';
const kProductId = 'prod-1';

WorkItem buildWorkItem({
  String workItemId = kWorkItemId,
  WorkItemState state = WorkItemState.draft,
  int version = 1,
  DateTime? instant,
}) {
  final now = instant ?? DateTime.utc(2026, 1, 1, 12);
  return WorkItem(
    workItemId: workItemId,
    productId: kProductId,
    category: WorkItemCategory.feature,
    title: 'Add landing page',
    description: 'Build the landing page described in the brief.',
    state: state,
    designContractId: 'dc-1',
    agentSessionId: 'as-1',
    qaContractId: 'qa-1',
    featureRef: 'feat/landing',
    requirementRef: 'REQ-101',
    artifactRefs: [
      ArtifactReference(
        artifactId: 'art-1',
        artifactType: ArtifactType.codeDiff,
        uri: 'object://artifacts/1',
        provider: 'control-plane',
        contentHash: 'b' * 64,
        description: 'Landing page diff',
        createdAt: DateTime.utc(2026, 1, 1, 12),
      ),
    ],
    metadata: const {'origin': 'contract-suite'},
    createdAt: now,
    updatedAt: now,
    version: version,
  );
}

HumanDecision buildHumanDecision({
  String decisionId = 'dec-1',
  String workItemId = kWorkItemId,
  HumanDecisionStatus status = HumanDecisionStatus.pending,
}) {
  return HumanDecision(
    decisionId: decisionId,
    workItemId: workItemId,
    decisionType: HumanDecisionType.engineeringReview,
    status: status,
    question: 'Approve the landing page implementation?',
    context: const DecisionContext(
      workflowState: 'agent_completed',
      availableOptions: ['approve', 'rework', 'reject'],
    ),
    options: const [
      HumanDecisionOption(optionId: 'approve', label: 'Approve'),
      HumanDecisionOption(optionId: 'rework', label: 'Rework'),
      HumanDecisionOption(optionId: 'reject', label: 'Reject'),
    ],
    recommendation: 'approve',
    blocking: true,
    requestedAt: DateTime.utc(2026, 1, 1, 12),
    expiration: DateTime.utc(2026, 1, 8, 12),
    decider: status == HumanDecisionStatus.resolved ? 'reviewer-2' : null,
    choice: status == HumanDecisionStatus.resolved
        ? HumanDecisionChoice.approve
        : null,
    rationale: status == HumanDecisionStatus.resolved
        ? 'Implementation matches the brief.'
        : null,
    timestamp: status == HumanDecisionStatus.resolved
        ? DateTime.utc(2026, 1, 2, 12)
        : null,
    signature: status == HumanDecisionStatus.resolved
        ? DecisionSignature(
            algorithm: 'ed25519',
            publicKey: 'pk-reviewer-2',
            signature: 'sig-reviewer-2',
            signedAt: DateTime.utc(2026, 1, 2, 12),
          )
        : null,
    resolvedOptionId: status == HumanDecisionStatus.resolved ? 'approve' : null,
    metadata: const {'channel': 'ui'},
    updatedAt: DateTime.utc(2026, 1, 2, 12),
  );
}

WorkflowTransitionRecord buildTransitionRecord({
  String transitionId = 'tr-1',
  String workItemId = kWorkItemId,
  String? idempotencyKey = 'k1',
}) {
  return WorkflowTransitionRecord(
    transitionId: transitionId,
    workItemId: workItemId,
    fromState: WorkItemState.draft,
    toState: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
    actorType: ActorType.orchestrator,
    actorId: 'orch-1',
    outcome: TransitionOutcome.accepted,
    reason: 'Workflow advanced.',
    guardEvaluations: const [
      TransitionGuardEvaluation(guardName: 'draftAllowed', passed: true),
    ],
    idempotencyKey: idempotencyKey,
    occurredAt: DateTime.utc(2026, 1, 1, 12, 5),
  );
}

Job buildJob({
  String jobId = 'jb-1',
  JobState state = JobState.queued,
  int version = 1,
}) {
  return Job(
    jobId: jobId,
    workItemId: kWorkItemId,
    jobType: JobType.implementFeature,
    requiredRole: AgentRole.implementer,
    requiredCapabilities: const {WorkerCapability.linux},
    priority: JobPriority.normal,
    state: state,
    dedupeKey: '$kWorkItemId:planning:implement_feature:IMPLEMENTER',
    createdAt: DateTime.utc(2026, 1, 1, 12),
    instruction: 'Implement the feature.',
    attempt: 1,
    maxAttempts: 2,
    executionReference: state == JobState.succeeded
        ? JobExecutionReference(
            workerExecutionId: 'we-1',
            agentExecutionId: 'ae-1',
            resultId: 'res-1',
            createdAt: DateTime.utc(2026, 1, 1, 13),
          )
        : null,
    workerId: state == JobState.claimed || state == JobState.running
        ? 'wk-1'
        : null,
    failure: state == JobState.failed
        ? JobFailure(
            code: JobFailureCode.executionFailed,
            kind: JobFailureKind.permanent,
            reason: 'Exhausted retries',
          )
        : null,
    cancelReason: state == JobState.cancelled ? 'Rework requested' : null,
    version: version,
  );
}

JobClaim buildClaim({String jobId = 'jb-1', String claimId = 'cl-1'}) {
  return JobClaim(
    claimId: claimId,
    jobId: jobId,
    ownerId: 'sched-1',
    leasedUntil: DateTime.utc(2026, 1, 2, 12),
    createdAt: DateTime.utc(2026, 1, 1, 13),
  );
}

SchedulerEventRecord buildSchedulerEvent({
  String jobId = 'jb-1',
  int sequence = 1,
}) {
  return SchedulerEventRecord(
    eventId: 'ev-$sequence',
    jobId: jobId,
    workItemId: kWorkItemId,
    sequence: sequence,
    type: SchedulerEventType.jobClaimed,
    occurredAt: DateTime.utc(2026, 1, 1, 13),
    payload: const {'owner': 'sched-1'},
  );
}

WorkerExecution buildWorkerExecution({
  String workerExecutionId = 'we-1',
  WorkerExecutionStatus status = WorkerExecutionStatus.acquiring,
  int version = 1,
}) {
  return WorkerExecution(
    workerExecutionId: workerExecutionId,
    workItemId: kWorkItemId,
    repositoryPath: '/repo',
    requestedStartingRevision: 'abc1234',
    requiredCapabilities: const {WorkerCapability.linux},
    status: status,
    cleanupPolicy: WorkerCleanupPolicy.removeAlways,
    workerId: status == WorkerExecutionStatus.executedPass ? 'wk-1' : null,
    workspaceId: status == WorkerExecutionStatus.executedPass ? 'ws-1' : null,
    agentExecutionId: status == WorkerExecutionStatus.executedPass
        ? 'ae-1'
        : null,
    resultId: status == WorkerExecutionStatus.executedPass ? 'res-1' : null,
    endingRevision: status == WorkerExecutionStatus.executedPass
        ? 'def5678'
        : null,
    cleanupStatus: status == WorkerExecutionStatus.executedPass
        ? WorkerCleanupStatus.removed
        : null,
    failureCode: status == WorkerExecutionStatus.timedOut
        ? WorkerFailureCode.timedOut
        : null,
    createdAt: DateTime.utc(2026, 1, 1, 12),
    startedAt: DateTime.utc(2026, 1, 1, 12, 5),
    endedAt: status == WorkerExecutionStatus.executedPass
        ? DateTime.utc(2026, 1, 1, 13)
        : null,
    reason: null,
    version: version,
  );
}

WorkerExecutionResult buildWorkerResult({String workerExecutionId = 'we-1'}) {
  return WorkerExecutionResult(
    workerExecutionId: workerExecutionId,
    workItemId: kWorkItemId,
    status: WorkerExecutionStatus.executedPass,
    workerId: 'wk-1',
    workspaceId: 'ws-1',
    startingRevision: 'abc1234',
    endingRevision: 'def5678',
    agentExecutionId: 'ae-1',
    agentResultStatus: AgentResultStatus.completed,
    verificationId: null,
    verificationPassed: true,
    changedFiles: const [
      ChangedFile(
        path: 'lib/landing.dart',
        operation: ChangedFileOperation.added,
        beforeSha: null,
        afterSha: 'cafe1234',
      ),
    ],
    diffSummary: 'Added the landing page.',
    diffRef: 'object://diff/1',
    cleanupStatus: WorkerCleanupStatus.removed,
    failureCode: WorkerFailureCode.none,
    failureDetail: null,
    startedAt: DateTime.utc(2026, 1, 1, 12, 5),
    endedAt: DateTime.utc(2026, 1, 1, 13),
  );
}

WorkerEventRecord buildWorkerEvent({
  String workerExecutionId = 'we-1',
  int sequence = 1,
}) {
  return WorkerEventRecord(
    eventId: 'wev-$sequence',
    workerExecutionId: workerExecutionId,
    workItemId: kWorkItemId,
    sequence: sequence,
    type: WorkerEventType.workspaceReady,
    occurredAt: DateTime.utc(2026, 1, 1, 12, 6),
    payload: const {'revision': 'abc1234'},
  );
}

AgentExecutionRequest buildAgentRequest({
  String executionId = 'ae-1',
  DateTime? createdAt,
}) {
  return AgentExecutionRequest(
    executionId: executionId,
    workItemId: kWorkItemId,
    role: AgentRole.implementer,
    runtimeTypeId: 'opencode-impl',
    workspace: const AgentWorkspace(
      workspaceId: 'ws-1',
      path: '/work/ws-1',
      startingRevision: 'abc1234',
      allowedPaths: ['/work/ws-1/lib'],
    ),
    instruction: 'Implement the landing page.',
    timeoutSeconds: 600,
    permittedScope: '/work/ws-1',
    expectedResult: const {'done': true},
    expectedArtifacts: const [
      ExpectedArtifact(description: 'Dart code', required: true),
    ],
    runtimeConfig: const {'model': 'test'},
    environment: const {'SHIPIT_ENV': 'test'},
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 12),
  );
}

AgentExecution buildAgentExecution({
  String executionId = 'ae-1',
  AgentSessionStatus status = AgentSessionStatus.running,
  int version = 1,
  DateTime? startedAt,
}) {
  return AgentExecution(
    executionId: executionId,
    workItemId: kWorkItemId,
    requestId: 'req-1',
    runtimeTypeId: 'opencode-impl',
    role: AgentRole.implementer,
    status: status,
    workspace: const AgentWorkspace(
      workspaceId: 'ws-1',
      path: '/work/ws-1',
      startingRevision: 'abc1234',
    ),
    sessionId: 'ses-1',
    resultId: status == AgentSessionStatus.completed ? 'res-1' : null,
    startedAt: startedAt ?? DateTime.utc(2026, 1, 1, 12, 5),
    completedAt: status == AgentSessionStatus.completed
        ? DateTime.utc(2026, 1, 1, 13)
        : null,
    reason: null,
    metadata: const {'attempt': 1},
    version: version,
  );
}

AgentEventRecord buildAgentEvent({
  String executionId = 'ae-1',
  int sequence = 1,
}) {
  return AgentEventRecord(
    eventId: 'aev-$sequence',
    executionId: executionId,
    workItemId: kWorkItemId,
    sequence: sequence,
    type: AgentEventType.toolCompleted,
    occurredAt: DateTime.utc(2026, 1, 1, 12, 6),
    payload: const {'tool': 'edit'},
  );
}

AgentResult buildAgentResult({
  String executionId = 'ae-1',
  String resultId = 'res-1',
}) {
  return AgentResult(
    resultId: resultId,
    sessionId: 'ses-1',
    workItemId: kWorkItemId,
    status: AgentResultStatus.completed,
    artifacts: [
      AgentArtifact(
        artifactId: 'art-1',
        type: 'source',
        path: 'lib/landing.dart',
        sha256: 'a' * 64,
        sizeBytes: 1024,
        mediaType: 'text/x-dart',
      ),
    ],
    diagnostics: AgentDiagnostics(
      exitCode: 0,
      durationMs: 1200,
      toolCalls: 3,
      errors: const [],
      warnings: const [],
    ),
    structuredResult: const {'route': '/landing'},
    executionId: executionId,
    role: AgentRole.implementer,
    changedFiles: const [
      ChangedFile(
        path: 'lib/landing.dart',
        operation: ChangedFileOperation.added,
        beforeSha: null,
        afterSha: 'cafe1234',
      ),
    ],
    claimedChecks: const [
      AgentClaimedCheck(
        checkName: 'dart-analyze',
        command: 'dart analyze',
        status: AgentClaimStatus.passed,
      ),
    ],
    summary: 'Implemented the landing page.',
    completedAt: DateTime.utc(2026, 1, 1, 13),
    metadata: const {'provenance': 'contract-suite'},
  );
}

PlatformVerification buildVerification({String executionId = 'ae-1'}) {
  return PlatformVerification(
    verificationId: 'v-1',
    executionId: executionId,
    workItemId: kWorkItemId,
    checkName: 'dart-analyze-clean',
    status: AgentClaimStatus.passed,
    mechanism: 'process_dart_analyze',
    command: 'dart analyze',
    capturedAt: DateTime.utc(2026, 1, 1, 13, 5),
    evidenceKind: EvidenceKind.platformVerifiedEvidence,
    outputRef: 'object://evidence/1',
    detail: null,
    resultPath: '/work/ws-1',
  );
}

WorkerRegistration buildRegistration({
  String workerId = 'wk-1',
  WorkerStatus status = WorkerStatus.idle,
}) {
  return WorkerRegistration(
    workerId: workerId,
    poolId: 'default',
    capabilities: const {
      WorkerCapability.linux: CapabilitySpec(
        capability: WorkerCapability.linux,
        version: '1.0',
        metadata: {'arch': 'arm64'},
        providedTools: ['git'],
      ),
    },
    status: status,
    currentLoad: 0,
    maxConcurrency: 2,
    lastHeartbeat: DateTime.utc(2026, 1, 1, 12),
    artifactCache: {
      'art-1': ArtifactCacheEntry(
        artifactHash: 'a' * 64,
        localPath: '/cache/art-1',
        cachedAt: DateTime.utc(2026, 1, 1, 11),
        sizeBytes: 4096,
      ),
    },
    platform: 'linux-x64',
  );
}

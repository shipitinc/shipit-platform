import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:workflow_store/workflow_store.dart';

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

/// Builds an operator-action fixture.
///
/// The optional values default to the interesting RUNTIME shape rather than to
/// the trivial one: a retry binds a transition, names the job it armed and
/// carries an attempt number, while a `stop` does none of those. Both are
/// reachable from here so a store cannot pass on the nullable columns alone.
OperatorActionRecord buildOperatorAction({
  String actionId = 'oa-1',
  String workItemId = kWorkItemId,
  // The literal, not `OperatorActionKind.retry.wire`: an enum field access is
  // not a constant expression and cannot be a default parameter value. The
  // suite asserts the stored token back through `OperatorActionKind.fromWire`,
  // which is the stronger direction anyway — it proves the value a store
  // persists is in the closed set rather than agreeing with a constant here.
  String action = 'retry',
  String requestId = 'req-1',
  String requestedBy = 'operator@shipit.platform',
  String reason = 'Approved after reviewing the failure.',
  String? transitionId,
  String? jobId,
  int? attemptNumber,
  DateTime? instant,
}) {
  return OperatorActionRecord(
    actionId: actionId,
    workItemId: workItemId,
    action: action,
    fromState: WorkItemState.agentFailed.wire,
    toState: WorkItemState.designNotRequired.wire,
    requestedBy: requestedBy,
    reason: reason,
    requestId: requestId,
    jobId: jobId,
    transitionId: transitionId,
    attemptNumber: attemptNumber,
    // Microsecond-aligned and far from a clock boundary: the column is
    // `timestamp without time zone`, and an ordering assertion must not depend
    // on how a database rounds.
    createdAt: instant ?? DateTime.utc(2026, 1, 1, 12, 30),
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

const kRevisionId = 'DES-R001';
const kReviewExecutionId = 'rev-exec-1';
const kFindingId = 'FD-001';

/// The six anchor blob columns, in the committed document's shapes.
///
/// ## WHY THESE LITERALS ARE WHAT THEY ARE
///
/// They used to be prose strings — `boardIdsJson: '["board-1", "board-2"]'`,
/// `responsiveTargetsJson: '["mobile", "desktop"]'`, `reviewScopeJson:
/// {'scope': 'full'}` — which is precisely what §3.3 identifies as the defect:
/// six `type: string` columns that assert nothing anyone can check. Three
/// separate rules made them non-conforming, and a fixture that violates the
/// contract under test is not neutral scaffolding, it is the defect the gate
/// exists to catch:
///   * `boardSet` items are OBJECTS (`{boardId, provider, providerFileId, …}`),
///     not bare strings, so a revision can name the provider file a human opens.
///   * `responsiveSet`'s `breakpoint` is the CLOSED `xs…2xl` vocabulary; `mobile`
///     and `desktop` are not in it, and an open string here is what makes "did
///     the implementation render the mobile board" an opinion.
///   * `reviewScope` is `{dimensions?, boardIds?}` with a closed dimension enum.
///     `{'scope': 'full'}` is an unnamed key — a claim the platform cannot check.
///
/// They are also written in §3.5.2's CANONICAL form — keys sorted at every
/// level, arrays in their declared sort-key order, no insignificant whitespace.
/// That is not decoration. `saveDesignRevision` canonicalises on write, so a
/// fixture that were merely conforming-but-unordered would come back from the
/// store as a DIFFERENT object than it went in as, and the suite's
/// `expect(loaded, revision)` round-trip assertion — the thing that makes this
/// fixture worth having — would fail on ordering rather than on storage.
///
/// Every sort key is unambiguous here: no two members of any array share one, so
/// the fixture does not depend on a tie-break rule the schema does not declare.
/// `boardName` and `orientation` are present on one member each so the optional
/// members survive the canonicaliser's round trip rather than being untested.
///
/// `designerExecutionId` is deliberately absent from `reviewExecutionIds` — the
/// seventh rule, the one JSON Schema cannot express, is a property of this
/// fixture whether or not a store ever checks it.
DesignRevision buildDesignRevision({
  String revisionId = kRevisionId,
  String workItemId = kWorkItemId,
  String? parentRevisionId,
  DesignRevisionStatus status = DesignRevisionStatus.draft,
  int version = 1,
  DateTime? instant,
}) {
  final now = instant ?? DateTime.utc(2026, 1, 1, 12);
  return DesignRevision(
    revisionId: revisionId,
    workItemId: workItemId,
    productId: kProductId,
    parentRevisionId: parentRevisionId,
    designSystemRevision: 'dsr-1',
    provider: DesignProviderType.penpot,
    penpotFileId: 'pf-1',
    penpotPageId: 'pp-1',
    boardIdsJson:
        '[{"boardId":"board-1","boardName":"Board 1","provider":"penpot",'
        '"providerFileId":"pf-1"},'
        '{"boardId":"board-2","boardName":"Board 2","provider":"penpot",'
        '"providerFileId":"pf-1"}]',
    responsiveTargetsJson:
        '[{"breakpoint":"lg","minViewportWidthCss":1024,"orientation":"landscape"},'
        '{"breakpoint":"md","minViewportWidthCss":768}]',
    statesRepresentedJson:
        '[{"boardId":"board-1","stateKey":"default","variant":"default"},'
        '{"boardId":"board-2","stateKey":"disabled","variant":"disabled"},'
        '{"boardId":"board-1","stateKey":"focus","variant":"focus"}]',
    artifactRefsJson:
        '[{"kind":"file","ref":"art-1"},{"kind":"file","ref":"art-2"}]',
    designerExecutionId: 'designer-exec-1',
    reviewExecutionIdsJson: '["rev-exec-1","rev-exec-2"]',
    status: status,
    riskTier: DesignRiskTier.medium,
    reviewScopeJson: const {
      // Canonical key order (`boardIds` < `dimensions`), and both arrays in
      // lexicographic order — the same two rules the six string columns obey
      // above, and the reason this Map survives the round trip unchanged
      // instead of being reordered by the canonicaliser.
      //
      // ONLY `design_revision`'s scope is an anchor column. The identical field
      // on `buildDesignReviewResult` below belongs to `design_review_result`,
      // which the anchor does not cover, so it is deliberately left as-is.
      'boardIds': ['board-1', 'board-2'],
      'dimensions': ['a11y', 'color', 'layout', 'responsive', 'typography'],
    },
    carriedForwardFromRevisionId: null,
    supersededByRevisionId: null,
    createdAt: now,
    updatedAt: now,
    approvedAt: status == DesignRevisionStatus.approved ? now : null,
    version: version,
    declaredOwnedPaths: const ['lib/owned/**', 'apps/server/lib/owned/**'],
  );
}

DesignReviewResult buildDesignReviewResult({
  String reviewExecutionId = kReviewExecutionId,
  String revisionId = kRevisionId,
  DesignReviewVerdict verdict = DesignReviewVerdict.approved,
  int version = 1,
}) {
  return DesignReviewResult(
    reviewExecutionId: reviewExecutionId,
    revisionId: revisionId,
    verdict: verdict,
    findings: const [],
    assessedDimensions: ['requirements', 'design-system'],
    reviewScopeJson: {'scope': 'full'},
    createdAt: DateTime.utc(2026, 1, 1, 13),
    version: version,
  );
}

DesignFinding buildDesignFinding({
  String findingId = kFindingId,
  String revisionId = kRevisionId,
  String reviewExecutionId = kReviewExecutionId,
  DesignFindingCategory category = DesignFindingCategory.requirementCoverage,
  DesignFindingSeverity severity = DesignFindingSeverity.major,
  String? resolvedByRevisionId,
  int version = 1,
}) {
  return DesignFinding(
    findingId: findingId,
    revisionId: revisionId,
    reviewExecutionId: reviewExecutionId,
    category: category,
    severity: severity,
    dimension: 'Button component',
    evidence: 'Missing required variant',
    requiredCorrection: 'Add disabled variant',
    affectedSurface: 'Button component',
    createdAt: DateTime.utc(2026, 1, 1, 13, 5),
    resolvedByRevisionId: resolvedByRevisionId,
    version: version,
  );
}

DesignRevisionEvent buildDesignRevisionEvent({
  String eventId = 'evt-1',
  String designRevisionId = kRevisionId,
  String eventType = 'created',
  String payloadJson = '{}',
  int sequence = 1,
}) {
  return DesignRevisionEvent(
    eventId: eventId,
    designRevisionId: designRevisionId,
    eventType: eventType,
    payloadJson: payloadJson,
    sequence: sequence,
    createdAt: DateTime.utc(2026, 1, 1, 12),
  );
}

const kDesignContractId = 'design-contract-wi-0001';

/// Builds a design-contract fixture exercising EVERY serialized field.
///
/// Mirrors `PostgresQAContractStore`'s column set one for one: the four
/// JSON-document columns, the nullable ones among them, and the `status` column
/// whose wire form is not its Dart name. A fixture that left the nullable
/// columns empty would never exercise the store's null-decode path, which is
/// how a column becomes unreadable without anything failing.
DesignContract buildDesignContract({
  String contractId = kDesignContractId,
  String workItemId = kWorkItemId,
  DesignContractStatus status = DesignContractStatus.draft,
  DateTime? instant,
}) {
  final now = instant ?? DateTime.utc(2026, 1, 1, 12);
  return DesignContract(
    contractId: contractId,
    workItemId: workItemId,
    requiredArtifacts: const [
      RequiredArtifact(
        artifactType: 'design_revision',
        description:
            'The durable design revision record this contract requires.',
        required: true,
        validationSchema: {'type': 'object'},
      ),
    ],
    reviewers: const ['design_reviewer'],
    approvalThreshold: 1,
    status: status,
    submittedArtifacts: [
      SubmittedArtifact(
        artifactType: 'design_revision',
        contentHash: 'sha256:fixture',
        submittedBy: 'execution-fixture-1',
        // Microsecond-aligned and far from a clock boundary: the column is
        // `timestamp without time zone`, and neither an ordering assertion nor
        // an equality assertion may depend on how a database rounds.
        submittedAt: now,
        location: 'object://artifacts/design-1',
      ),
    ],
    decisions: const ['approved-by-independent-reviewer'],
    createdAt: now,
    updatedAt: now,
    expiresAt: now.add(const Duration(days: 30)),
    metadata: const {'productId': kProductId, 'defectId': null},
  );
}

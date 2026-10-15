import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, InMemoryExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore, WorkflowStore;

/// The refusal contract of `repairUnreviewedReview` — the operator action that
/// returns a work item parked behind an engineering-review decision no reviewer
/// ever backed to a dispatchable review.
///
/// ## WHY THIS FILE EXISTS AT ALL
///
/// The action's entire value is what it REFUSES. A repair that cannot tell a
/// fabricated decision from a real one is worse than the bug it repairs, and
/// "worse than the bug" is not a rhetorical claim: the bug shows an operator a
/// wrong recommendation, while a repair that discards a genuine review destroys
/// work that cost real credits and exists nowhere else.
///
/// So every refusal is DRIVEN here, not merely described. Each one asserts the
/// refusal's outcome AND that the decision, the work item and the transition
/// ledger are byte-identical before and after — a refusal that returns the right
/// word while having written something is not a refusal.
///
/// ## HOW IT DRIVES THE ENDPOINT WITHOUT A DATABASE
///
/// The stores are the REAL ones — [InMemoryWorkflowStore], the real
/// [DurableWorkflowEngine] and the real [InMemoryExecutionStore] — so the
/// durable write under test is the production one. Only the persistence
/// substrate is substituted. No Postgres is involved and none was obtained.
///
/// ## THE SHARPEST ASSERTION IN THIS FILE
///
/// `the decision's own verdict claim is never the evidence`. It seeds a
/// decision that CLAIMS `approve` with no reviewer output, and a decision that
/// CLAIMS `changes_required` with a real reviewer verdict, and asserts the first
/// is repairable and the second is refused. Both would decide identically under
/// a reader that trusted `metadata.reviewVerdict`, which is precisely the
/// reader that caused this.
void main() {
  late InMemoryWorkflowStore store;
  late InMemoryExecutionStore executions;
  late _TestEndpoints endpoints;
  late Session session;

  setUp(() {
    store = InMemoryWorkflowStore();
    executions = InMemoryExecutionStore();
    endpoints = _TestEndpoints(store, executions);
    session = _FakeSession();
  });

  // ---------------------------------------------------------------------
  // Fixtures
  // ---------------------------------------------------------------------

  /// A work item parked at `waiting_for_human_decision` behind [decisionId].
  ///
  /// Placed there by writing the state rather than by walking the table on
  /// purpose. `agentCompleted -> reviewInProgress -> waitingForHumanDecision`
  /// is the real route the review gate takes, but walking it would make this
  /// file a test of the transition table's guards; what is under test is the
  /// repair's reaction to a state it finds. `version` is bumped because the
  /// repair's compare-and-swap reads it.
  Future<WorkItem> seedParked({
    String workItemId = 'defect-DEF-1',
    String? decisionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    await DurableWorkflowEngine(
      store: store,
    ).createWorkItem(
      workItemId: workItemId,
      productId: 'shipit',
      category: WorkItemCategory.bugfix,
      title: 'Deploy key rotation is unreachable through the API',
      description: 'An operator cannot rotate a deploy key',
      featureRef: 'WI-deploy',
      requirementRef: 'REQ-deploy',
    );
    final created = await store.readWorkItem(workItemId);
    final parked = created.copyWith(
      state: WorkItemState.waitingForHumanDecision,
      blockingHumanDecisionId: decisionId,
      blockingReason: decisionId == null
          ? null
          : 'Engineering review requires changes. '
                'Approve, reject, or request rework?',
      metadata: metadata,
      version: created.version + 1,
    );
    await store.saveWorkItem(parked);
    return parked;
  }

  /// A pending `engineering_review` decision whose metadata carries the gate's
  /// own shape, including the verdict the gate fabricated.
  Future<HumanDecision> seedDecision({
    required String decisionId,
    required String workItemId,
    String? executionId = 'agx-review-1',
    String claimedVerdict = 'changes_required',
    HumanDecisionStatus status = HumanDecisionStatus.pending,
    HumanDecisionChoice? choice,
    String? decider,
  }) async {
    final decision = HumanDecision(
      decisionId: decisionId,
      workItemId: workItemId,
      decisionType: HumanDecisionType.engineeringReview,
      status: status,
      question:
          'Engineering review requires changes. '
          'Approve, reject, or request rework?',
      recommendation: claimedVerdict.toUpperCase(),
      blocking: true,
      requestedAt: DateTime.utc(2026, 10, 14, 15),
      updatedAt: DateTime.utc(2026, 10, 14, 15),
      choice: choice,
      decider: decider,
      metadata: {
        'engineeringReviewResult': {
          'reviewExecutionId': executionId,
          'workItemId': workItemId,
          'verdict': claimedVerdict,
          'findings': <Object>[],
          'assessedDimensions': <Object>[],
        },
        if (executionId != null) 'reviewExecutionId': executionId,
        if (claimedVerdict.isNotEmpty) 'reviewVerdict': claimedVerdict,
      },
    );
    await store.saveHumanDecision(decision);
    return decision;
  }

  /// A reviewer execution that produced nothing a human could read.
  ///
  /// The QA fabrication exactly: `structuredResultJson = '{}'`, no summary.
  Future<void> seedNoOutput(
    String executionId, {
    String workItemId = 'defect-DEF-1',
  }) => executions.saveExecution(
    AgentExecution(
      executionId: executionId,
      workItemId: workItemId,
      requestId: 'req-$executionId',
      runtimeTypeId: 'opencode',
      role: AgentRole.engineeringReviewer,
      status: AgentSessionStatus.failed,
      workspace: const AgentWorkspace(
        workspaceId: 'ws-review',
        path: '/worktrees/review',
        startingRevision: 'abc1234',
      ),
      startedAt: DateTime.utc(2026, 10, 14, 15),
      completedAt: DateTime.utc(2026, 10, 14, 15, 5),
      reason:
          'session never emitted a terminal event within the 300s '
          'execution budget',
      version: 1,
    ),
  );

  /// A reviewer execution that wrote a real review into its summary.
  ///
  /// The second class, and the one the guardrail exists for. QA holds two of
  /// these: one states "**Verdict: `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`**"
  /// outright.
  Future<void> seedProseOnly(
    String executionId, {
    String workItemId = 'defect-DEF-1',
    String verdict = 'APPROVE_WITH_NON_BLOCKING_FOLLOWUP',
  }) async {
    await seedNoOutput(executionId, workItemId: workItemId);
    await executions.saveResult(
      executionId,
      AgentResult(
        resultId: 'result-$executionId',
        sessionId: 'ses-$executionId',
        workItemId: workItemId,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: _quietDiagnostics,
        structuredResult: const {},
        executionId: executionId,
        role: AgentRole.engineeringReviewer,
        summary:
            '## Engineering Review\n\n**Verdict: `$verdict`**\n\n'
            'Reviewed revision: `e7959d0f3765bc45b94afc341921d29cf3172486`.',
        completedAt: DateTime.utc(2026, 10, 14, 15, 5),
      ),
    );
  }

  /// A reviewer execution that returned a real, machine-readable verdict.
  Future<void> seedAssessed(
    String executionId, {
    String workItemId = 'defect-DEF-1',
    String verdict = 'changes_required',
  }) async {
    await seedNoOutput(executionId, workItemId: workItemId);
    await executions.saveResult(
      executionId,
      AgentResult(
        resultId: 'result-$executionId',
        sessionId: 'ses-$executionId',
        workItemId: workItemId,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: _quietDiagnostics,
        structuredResult: {'verdict': verdict},
        executionId: executionId,
        role: AgentRole.engineeringReviewer,
        completedAt: DateTime.utc(2026, 10, 14, 15, 5),
      ),
    );
  }

  /// A snapshot of everything a refusal must leave untouched.
  Future<Map<String, Object?>> snapshot(
    String workItemId,
    String decisionId,
  ) async {
    final item = await store.readWorkItem(workItemId);
    final decision = await store.readHumanDecision(decisionId);
    final history = await store.readTransitionHistory(workItemId);
    return {
      'item': item,
      'decision': decision,
      'history': history,
    };
  }

  Future<ReviewRepairResult> repair({
    String workItemId = 'defect-DEF-1',
    String requestId = 'req-1',
    String requestedBy = 'operator@example.com',
    String reason = 'the reviewer timed out and produced nothing',
    String? decisionId,
  }) => endpoints.repairUnreviewedReview(
    session,
    workItemId: workItemId,
    requestId: requestId,
    requestedBy: requestedBy,
    reason: reason,
    decisionId: decisionId,
  );

  // ---------------------------------------------------------------------
  // The refusals
  // ---------------------------------------------------------------------

  test(
    'it REFUSES a decision whose reviewer really returned a verdict',
    () async {
      const decisionId = 'dec-1';
      await seedParked(decisionId: decisionId);
      await seedDecision(decisionId: decisionId, workItemId: 'defect-DEF-1');
      await seedAssessed('agx-review-1', verdict: 'changes_required');
      final before = await snapshot('defect-DEF-1', decisionId);

      final result = await repair();

      expect(
        result.outcome,
        'reviewerProducedVerdict',
        reason:
            'a reviewer returned a real verdict. Discarding it would destroy a '
            'real review result, which is the guardrail the brief names.',
      );
      expect(
        result.detail,
        contains('would discard a real review result'),
        reason: 'the refusal must TELL the operator why, not only that',
      );
      expect(
        result.detail,
        contains('changes_required'),
        reason:
            'and it must name the verdict the reviewer really returned, so the '
            'operator can see the repair declined something real',
      );
      expect(
        await snapshot('defect-DEF-1', decisionId),
        before,
        reason: 'a refusal must write NOTHING',
      );
    },
  );

  test(
    'it REFUSES a decision whose reviewer wrote a real review in prose only',
    () async {
      // THE GUARDRAIL, in the shape QA actually holds. The reviewer COMPLETED
      // and wrote a full engineering review; only the machine channel is
      // empty. Retiring this would destroy the only copy of that review.
      const decisionId = 'dec-1';
      await seedParked(decisionId: decisionId);
      await seedDecision(decisionId: decisionId, workItemId: 'defect-DEF-1');
      await seedProseOnly('agx-review-1');
      final before = await snapshot('defect-DEF-1', decisionId);

      final result = await repair();

      expect(
        result.outcome,
        'reviewerProducedProse',
        reason:
            'the decision\'s verdict claim IS still fabricated — nothing in the '
            'machine channel supports it — but a real assessment exists and the '
            'operator has never been shown it. An operator-triggered path that '
            'can throw away a genuine review is worse than the bug it repairs.',
      );
      expect(result.detail, contains('a real'));
      expect(result.detail, contains('reviewer assessment exists'));
      expect(
        await snapshot('defect-DEF-1', decisionId),
        before,
        reason: 'a refusal must write NOTHING',
      );
    },
  );

  test('it REFUSES when the reviewer result cannot be read', () async {
    const decisionId = 'dec-1';
    await seedParked(decisionId: decisionId);
    await seedDecision(decisionId: decisionId, workItemId: 'defect-DEF-1');
    await seedNoOutput('agx-review-1');
    // A reviewer answering in a dialect this build does not speak. Note this
    // is the same WORD the prose-only fixture uses: QA's reviewer wrote
    // `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`, which is not one of the four wires
    // either, so a verdict in the machine channel was never produced.
    await executions.saveResult(
      'agx-review-1',
      AgentResult(
        resultId: 'result-bad',
        sessionId: 'ses-bad',
        workItemId: 'defect-DEF-1',
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: _quietDiagnostics,
        structuredResult: const {'verdict': 'needs_work'},
        executionId: 'agx-review-1',
        role: AgentRole.engineeringReviewer,
        completedAt: DateTime.utc(2026, 10, 14, 15, 5),
      ),
    );
    final before = await snapshot('defect-DEF-1', decisionId);

    final result = await repair();

    expect(result.outcome, 'reviewerOutputUnreadable');
    expect(
      result.detail,
      contains('I could not check'),
      reason:
          '"I could not check" is not "there was nothing there", and a refusal '
          'an operator cannot act on is not a refusal.',
    );
    expect(await snapshot('defect-DEF-1', decisionId), before);
  });

  test("it REFUSES a decision a human already answered", () async {
    // QA holds this on record: `dec-hn7h7daum6-2atjhe` was approved by an
    // operator whose reviewer had in fact timed out, and the work item moved to
    // `review_approved`. This refusal is the one that stops the repair being
    // the thing that did that — or doing it again.
    const decisionId = 'dec-1';
    await seedParked(decisionId: decisionId);
    await seedDecision(
      decisionId: decisionId,
      workItemId: 'defect-DEF-1',
      status: HumanDecisionStatus.resolved,
      choice: HumanDecisionChoice.approve,
      decider: 'operator',
    );
    await seedNoOutput('agx-review-1');
    final before = await snapshot('defect-DEF-1', decisionId);

    final result = await repair();

    expect(result.outcome, 'alreadyDecided');
    expect(result.detail, contains('discard a real human decision'));
    expect(
      await snapshot('defect-DEF-1', decisionId),
      before,
      reason: 'the human\'s approval must survive untouched',
    );
  });

  test('it REFUSES a decision it has already retired', () async {
    const decisionId = 'dec-1';
    await seedParked(decisionId: decisionId);
    await seedDecision(
      decisionId: decisionId,
      workItemId: 'defect-DEF-1',
      status: HumanDecisionStatus.cancelled,
    );
    await seedNoOutput('agx-review-1');
    final before = await snapshot('defect-DEF-1', decisionId);

    final result = await repair();

    expect(
      result.outcome,
      'alreadyDecided',
      reason:
          'otherwise the repair would happily re-repair its own output and '
          'queue a second review',
    );
    expect(await snapshot('defect-DEF-1', decisionId), before);
  });

  test('it REFUSES an item that is not parked behind anything', () async {
    await seedParked(workItemId: 'defect-DEF-2');
    final itemBefore = await store.readWorkItem('defect-DEF-2');

    final result = await repair(workItemId: 'defect-DEF-2');

    expect(result.outcome, 'notApplicable');
    expect(result.detail, contains('no fabricated question to repair'));
    expect(
      await store.readWorkItem('defect-DEF-2'),
      itemBefore,
      reason: 'a refusal must write NOTHING',
    );
  });

  test('it REFUSES a decision that is not the one holding the item', () async {
    // Repairing some other pending decision on the same item would clear a gate
    // a real reviewer had raised.
    await seedParked(decisionId: 'dec-holding');
    await seedDecision(decisionId: 'dec-holding', workItemId: 'defect-DEF-1');
    final before = await snapshot('defect-DEF-1', 'dec-holding');

    final result = await repair(decisionId: 'dec-other');

    expect(result.outcome, 'notApplicable');
    expect(result.detail, contains('is not the decision holding this item'));
    expect(await snapshot('defect-DEF-1', 'dec-holding'), before);
  });

  test('it REFUSES while a live job holds the item', () async {
    const decisionId = 'dec-1';
    await seedParked(decisionId: decisionId);
    await seedDecision(decisionId: decisionId, workItemId: 'defect-DEF-1');
    await seedNoOutput('agx-review-1');
    endpoints.jobs = [
      _job('jb-1', JobState.claimed, '$workItemIdKey:engineering_review'),
    ];
    final before = await snapshot('defect-DEF-1', decisionId);

    final result = await repair();

    expect(result.outcome, 'alreadyRunning');
    expect(
      await snapshot('defect-DEF-1', decisionId),
      before,
      reason:
          'a second operator action must never be layered on a live attempt',
    );
  });

  test('it REFUSES a request with no reason or no requester', () async {
    const decisionId = 'dec-1';
    await seedParked(decisionId: decisionId);
    await seedDecision(decisionId: decisionId, workItemId: 'defect-DEF-1');
    await seedNoOutput('agx-review-1');
    final before = await snapshot('defect-DEF-1', decisionId);

    expect((await repair(reason: '   ')).outcome, 'invalidRequest');
    expect((await repair(requestedBy: '  ')).outcome, 'invalidRequest');
    expect(
      await snapshot('defect-DEF-1', decisionId),
      before,
      reason: 'the record must say who and why, or nothing is recorded',
    );
  });

  // ---------------------------------------------------------------------
  // The repair itself
  // ---------------------------------------------------------------------

  test('it repairs a decision no reviewer ever backed', () async {
    const decisionId = 'dec-1';
    await seedParked(
      decisionId: decisionId,
      metadata: const {'defectId': 'DEF-1', 'triageAttempt': 2},
    );
    await seedDecision(decisionId: decisionId, workItemId: 'defect-DEF-1');
    await seedNoOutput('agx-review-1');
    endpoints.jobs = [
      _job('jb-1', JobState.failed, 'defect-DEF-1:engineering_review'),
    ];

    final result = await repair();

    expect(result.outcome, 'accepted', reason: result.detail);

    final item = await store.readWorkItem('defect-DEF-1');
    expect(
      item.state,
      WorkItemState.agentCompleted,
      reason:
          'agent_completed IS engineeringReviewDefinition.entryStates, so the '
          'ordinary tick dispatches the re-review',
    );
    expect(item.blockingHumanDecisionId, isNull);
    expect(item.blockingReason, isNull);
    expect(
      item.metadata!['triageAttempt'],
      3,
      reason:
          'the discriminator is greatest(marker 2, the highest attempt this '
          'item\'s own engineering_review job keys consumed = 0) + 1. The live '
          'job holds the UNSUFFIXED key, which consumes no attempt.',
    );
    expect(
      item.metadata!['defectId'],
      'DEF-1',
      reason: 'the marker is MERGED, never written over the document',
    );

    final decision = await store.readHumanDecision(decisionId);
    expect(decision.status, HumanDecisionStatus.cancelled);
    expect(
      decision.metadata?[reviewUnreviewableMetadataKey],
      isTrue,
      reason: 'this is the durable marker that makes it impossible to approve',
    );
    expect(
      decision.metadata?['reviewUnreviewableClaimedVerdict'],
      'changes_required',
      reason:
          'the claim is kept as evidence, under a key that names it a claim',
    );
    expect(
      decision.recommendation,
      'CHANGES_REQUIRED',
      reason: 'the fabricated recommendation is the evidence and is preserved',
    );
    expect(
      decision.choice,
      isNull,
      reason:
          'the repair retires a decision; it never records a human answer to '
          'one, so this cannot forge an approval even by accident',
    );
    expect(decision.decider, isNull);

    final history = await store.readTransitionHistory('defect-DEF-1');
    final audit = history.where(
      (t) => t.idempotencyKey == 'review-repair:req-1',
    );
    expect(audit, hasLength(1));
    expect(audit.single.toState, WorkItemState.agentCompleted);
    expect(audit.single.fromState, WorkItemState.waitingForHumanDecision);
    expect(
      audit.single.reason,
      contains('NO TRANSITION EDGE WAS TAKEN'),
      reason:
          'waitingForHumanDecision -> agentCompleted has no edge, so the audit '
          'row must say the column was written directly rather than imply a '
          'transition was taken',
    );
  });

  test(
    'it is a replay: a repeated intent reports itself and writes nothing',
    () async {
      const decisionId = 'dec-1';
      await seedParked(
        decisionId: decisionId,
        metadata: const {'triageAttempt': 2},
      );
      await seedDecision(decisionId: decisionId, workItemId: 'defect-DEF-1');
      await seedNoOutput('agx-review-1');

      expect((await repair()).outcome, 'accepted');
      final afterFirst = await snapshot('defect-DEF-1', decisionId);

      final second = await repair();

      expect(
        second.outcome,
        'accepted',
        reason:
            'a replay must report what that request DID, not refuse itself as '
            'inapplicable after the item has moved on',
      );
      expect(second.detail, contains('already carried out'));
      expect(
        await snapshot('defect-DEF-1', decisionId),
        afterFirst,
        reason:
            'a double-click must not mint a second discriminator bump, which '
            'would queue a second review',
      );
    },
  );

  // ---------------------------------------------------------------------
  // The property the whole thing turns on
  // ---------------------------------------------------------------------

  test('the decision\'s own verdict claim is never the evidence', () async {
    // (1) Claims APPROVE, and no reviewer produced anything: repairable. A
    // reader that trusted `metadata.reviewVerdict` would have refused this as
    // "a real approval".
    await seedParked(workItemId: 'defect-DEF-A', decisionId: 'dec-A');
    await seedDecision(
      decisionId: 'dec-A',
      workItemId: 'defect-DEF-A',
      executionId: 'agx-a',
      claimedVerdict: 'approved',
    );
    await seedNoOutput('agx-a', workItemId: 'defect-DEF-A');

    expect((await repair(workItemId: 'defect-DEF-A')).outcome, 'accepted');

    // (2) Claims CHANGES_REQUIRED, and a reviewer produced a real verdict:
    // refused. A reader that trusted the claim would have retired a real review.
    await seedParked(workItemId: 'defect-DEF-B', decisionId: 'dec-B');
    await seedDecision(
      decisionId: 'dec-B',
      workItemId: 'defect-DEF-B',
      executionId: 'agx-b',
      claimedVerdict: 'changes_required',
    );
    await seedAssessed(
      'agx-b',
      workItemId: 'defect-DEF-B',
      verdict: 'approved',
    );
    final before = await snapshot('defect-DEF-B', 'dec-B');

    final result = await repair(workItemId: 'defect-DEF-B');

    expect(result.outcome, 'reviewerProducedVerdict');
    expect(await snapshot('defect-DEF-B', 'dec-B'), before);
  });

  test('a decision naming no reviewer execution at all is repairable', () async {
    // The shape `engineeringReviewMissingArtifact` raises: an honest question
    // with no `reviewVerdict` to fabricate. There is no reviewer output behind
    // it at all, so there is nothing to destroy.
    const decisionId = 'dec-1';
    await seedParked(decisionId: decisionId);
    await seedDecision(
      decisionId: decisionId,
      workItemId: 'defect-DEF-1',
      executionId: null,
      claimedVerdict: '',
    );

    final result = await repair();

    expect(result.outcome, 'accepted', reason: result.detail);
    expect(
      (await store.readHumanDecision(
        decisionId,
      )).metadata?[reviewUnreviewableMetadataKey],
      isTrue,
    );
  });

  test(
    'a non-review decision type is never treated as a reviewer claim',
    () async {
      const decisionId = 'dec-1';
      await seedParked(decisionId: decisionId);
      final decision = HumanDecision(
        decisionId: decisionId,
        workItemId: 'defect-DEF-1',
        decisionType: HumanDecisionType.designApproval,
        status: HumanDecisionStatus.pending,
        question: 'Approve the design?',
        blocking: true,
        requestedAt: DateTime.utc(2026, 10, 14),
        updatedAt: DateTime.utc(2026, 10, 14),
        metadata: const {},
      );
      await store.saveHumanDecision(decision);
      final before = await snapshot('defect-DEF-1', decisionId);

      // A design approval carries no reviewer verdict to fabricate, so the
      // provenance read reports no reviewer output — and the repair would be
      // offered. The enumerated migration and the operator's judgement are the
      // real gates; this test pins that the READ does not invent a claim from a
      // decision type it does not understand.
      final provenance = await readReviewVerdictProvenance(
        executionStore: executions,
        decision: decision,
      );
      expect(provenance.assessment, ReviewAssessment.noReviewerOutput);
      expect(
        await snapshot('defect-DEF-1', decisionId),
        before,
        reason: 'nothing was written by the read',
      );
    },
  );
}

const workItemIdKey = 'defect-DEF-1';

/// A reviewer that ran and produced nothing: zero errors, zero warnings. The
/// QA fabrication was not a crash the runtime noticed -- it was a session that
/// never emitted a terminal event at all.
const _quietDiagnostics = AgentDiagnostics(
  exitCode: 0,
  durationMs: 300000,
  toolCalls: 0,
  errors: [],
  warnings: [],
);

Job _job(String jobId, JobState state, String dedupeKey) => Job(
  jobId: jobId,
  workItemId: workItemIdKey,
  jobType: JobType.engineeringReview,
  requiredRole: AgentRole.engineeringReviewer,
  requiredCapabilities: const {WorkerCapability.git},
  priority: JobPriority.high,
  state: state,
  dedupeKey: dedupeKey,
  createdAt: DateTime.utc(2026, 10, 14, 15),
  instruction: 'review it',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

class _TestEndpoints extends WorkItemActionEndpoints {
  _TestEndpoints(this._store, this._executions);

  final WorkflowStore _store;
  final ExecutionStore _executions;

  List<Job> jobs = const [];

  @override
  ControlPlaneService serviceFor(Session session) =>
      _TestService(session, _store, _executions, this);
}

class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store, this._executions, this._owner);

  final WorkflowStore _store;
  final ExecutionStore _executions;
  final _TestEndpoints _owner;

  @override
  WorkflowStore get workflowStore => _store;

  @override
  ExecutionStore get executionStore => _executions;

  @override
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: _store);

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) async =>
      _owner.jobs.where((j) => j.workItemId == workItemId).toList();
}

class _FakeSession implements Session {
  final List<String> logs = [];

  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    logs.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Session.${invocation.memberName} is not used here',
  );
}

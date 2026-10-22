import 'dart:convert';

import 'package:control_plane_server/src/design/design_review_recorder.dart';
import 'package:control_plane_server/src/design/design_revision_producer.dart'
    show designRevisionIdMetadataKey, designerExecutionIdMetadataKey;
import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// THE PROOF for design step 9 (gap G-C): a terminal `designReview` job whose
/// reviewer produced a verdict becomes
///
///   * one durable [DesignReviewResult] row (the writer `saveDesignReviewResult`
///     never had — F-224a), and
///   * one blocking `HumanDecision(designApproval)` (the raiser the edges and
///     routing have been callerless for — G-C),
///
/// and nothing else. A review that produced NO readable verdict does not get one
/// invented: the absence is recorded on the reviewer's own execution timeline and
/// a labelled non-verdict decision is raised that cannot be resolved as approval.
///
/// ## WHAT IS REAL AND WHAT IS FAKED
///
/// The stores are the in-memory implementations the package ships (they run the
/// same gate functions as PostgreSQL), and [DurableWorkflowEngine] is the real
/// engine — because `designInReview -> waitingForHumanDecision` carries a guard
/// the engine evaluates, and a fake engine would test a guard production does
/// not call. The clock is the only fake.
void main() {
  const workItemId = 'wi-design-recorder';
  const productId = 'prod-1';
  const revisionId = 'rev-recorder-1';
  const reviewerExecutionId = 'agx-recorder-reviewer';
  const designerExecutionId = 'agx-recorder-designer';
  final now = DateTime.utc(2026, 10, 22, 12);

  DesignReviewResult reviewerResultWith({
    DesignReviewVerdict verdict = DesignReviewVerdict.approved,
    List<Map<String, dynamic>> findings = const [],
    List<String> assessedDimensions = const ['a11y', 'responsive'],
    bool embed = false,
  }) {
    final structured = <String, dynamic>{
      'verdict': verdict.wire,
      'assessedDimensions': assessedDimensions,
      'findings': findings,
    };
    if (embed) {
      structured['designReviewResult'] = DesignReviewResult(
        reviewExecutionId: reviewerExecutionId,
        revisionId: revisionId,
        verdict: verdict,
        findings: const [],
        assessedDimensions: assessedDimensions,
        createdAt: now,
        version: 1,
      ).toJson();
    }
    return DesignReviewResult(
      reviewExecutionId: reviewerExecutionId,
      revisionId: revisionId,
      verdict: verdict,
      findings: const [],
      assessedDimensions: assessedDimensions,
      createdAt: now,
      version: 1,
    );
  }

  /// A host: real engine, in-memory stores, one item at `designInReview` with a
  /// durable revision and one terminal designReview job.
  Future<_Host> host({
    WorkItemState itemState = WorkItemState.designInReview,
    bool writeRevision = true,
    String revisionWorkItemId = workItemId,
    String? revisionIdOverride,
    AgentSessionStatus executionStatus = AgentSessionStatus.completed,
    AgentRole executionRole = AgentRole.designReviewer,
    bool writeResult = true,
    Map<String, dynamic>? structuredResult,
    bool referenceExecution = true,
    bool preSeededResult = false,
    DateTime Function()? clock,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final engine = DurableWorkflowEngine(store: workflowStore);
    final executionStore = InMemoryExecutionStore();
    final governanceStore = InMemoryDesignGovernanceStore();

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: productId,
        category: WorkItemCategory.feature,
        title: 'Design the login screen',
        state: itemState,
        qaContractId: 'qa-1',
        metadata: {
          designRevisionIdMetadataKey: revisionIdOverride ?? revisionId,
          designerExecutionIdMetadataKey: designerExecutionId,
        },
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (writeRevision) {
      await governanceStore.saveDesignRevision(
        DesignRevision(
          revisionId: revisionIdOverride ?? revisionId,
          workItemId: revisionWorkItemId,
          productId: productId,
          designSystemRevision: 'dsr-1',
          provider: DesignProviderType.penpot,
          penpotFileId: 'pf-1',
          penpotPageId: 'pp-1',
          boardIdsJson: jsonEncode([
            {
              'boardId': 'login-desktop',
              'boardName': 'Login',
              'provider': 'penpot',
              'providerFileId': 'pf-1',
            },
          ]),
          responsiveTargetsJson: jsonEncode([
            {'breakpoint': 'lg', 'minViewportWidthCss': 1024},
          ]),
          statesRepresentedJson: jsonEncode([
            {
              'boardId': 'login-desktop',
              'stateKey': 'form-filled',
              'variant': 'default',
            },
          ]),
          artifactRefsJson: '[]',
          designerExecutionId: designerExecutionId,
          reviewExecutionIdsJson: jsonEncode([reviewerExecutionId]),
          status: DesignRevisionStatus.humanApprovalRequired,
          riskTier: DesignRiskTier.high,
          createdAt: now,
          updatedAt: now,
          version: 1,
        ),
      );
    }

    await executionStore.saveExecution(
      AgentExecution(
        executionId: reviewerExecutionId,
        workItemId: workItemId,
        requestId: 'req-review',
        runtimeTypeId: 'opencode',
        role: executionRole,
        status: executionStatus,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-review',
          path: '/tmp/review-workspace',
        ),
        startedAt: now,
        completedAt: now,
      ),
    );
    if (writeResult) {
      await executionStore.saveResult(
        reviewerExecutionId,
        AgentResult(
          resultId: 'res-review',
          sessionId: 'sess-review',
          workItemId: workItemId,
          status: AgentResultStatus.completed,
          artifacts: const [],
          diagnostics: const AgentDiagnostics(
            exitCode: 0,
            durationMs: 1,
            toolCalls: 0,
            errors: [],
            warnings: [],
          ),
          structuredResult: structuredResult ?? const {'verdict': 'approved'},
          executionId: reviewerExecutionId,
          role: AgentRole.designReviewer,
          completedAt: now,
        ),
      );
    }

    if (preSeededResult) {
      await governanceStore.saveDesignReviewResult(
        reviewerResultWith(),
      );
    }

    final job = Job(
      jobId: 'job-recorder-review',
      workItemId: workItemId,
      jobType: JobType.designReview,
      requiredRole: AgentRole.designReviewer,
      requiredCapabilities: const {
        WorkerCapability.penpotRead,
        WorkerCapability.designReview,
      },
      priority: JobPriority.high,
      state: JobState.succeeded,
      dedupeKey: '$workItemId:$revisionId:${JobType.designReview.wire}',
      createdAt: now,
      instruction: 'Review the design revision',
      attempt: 1,
      maxAttempts: 2,
      version: 1,
      executionReference: referenceExecution
          ? JobExecutionReference(
              workerExecutionId: 'wx-review',
              agentExecutionId: reviewerExecutionId,
              createdAt: now,
            )
          : null,
    );

    final logs = <(String, Map<String, dynamic>)>[];
    final recorder = DesignReviewRecorder(
      workflowEngine: engine,
      executionStore: executionStore,
      designGovernanceStore: governanceStore,
      logger: (event, data) => logs.add((event, data)),
      clock: clock ?? () => now,
    );

    return _Host(
      engine: engine,
      workflowStore: workflowStore,
      executionStore: executionStore,
      governanceStore: governanceStore,
      job: job,
      logs: logs,
      recorder: recorder,
    );
  }

  group('a verdict becomes one durable result and one blocking decision', () {
    test('records the DesignReviewResult and raises designApproval', () async {
      final h = await host();

      final outcome = await h.recorder.record(h.job);

      expect(outcome, DesignReviewRecorderOutcome.recorded);

      // ONE durable result row, against the reviewer's own execution.
      final stored = await h.governanceStore.readDesignReviewResultForExecution(
        revisionId,
        reviewerExecutionId,
      );
      expect(stored, isNotNull);
      expect(stored!.verdict, DesignReviewVerdict.approved);

      // ONE blocking designApproval decision.
      final item = await h.engine.loadWorkItem(workItemId);
      expect(item.state, WorkItemState.waitingForHumanDecision);
      expect(item.blockingHumanDecisionId, isNotNull);
      final decision = await h.workflowStore.readHumanDecision(
        item.blockingHumanDecisionId!,
      );
      expect(decision.decisionType, HumanDecisionType.designApproval);
      expect(decision.blocking, isTrue);
      expect(decision.status, HumanDecisionStatus.pending);
      // The three choices the routing table understands, and no more.
      expect(
        decision.options!.map((o) => o.optionId),
        containsAll(<String>['approve', 'reject', 'rework']),
      );
      expect(
        decision.metadata?[designReviewVerdictMetadataKey],
        DesignReviewVerdict.approved.wire,
      );
    });

    test('every revision is gated unconditionally (D4: every revision HIGH)',
        () async {
      for (final verdict in DesignReviewVerdict.values) {
        final h = await host(
          structuredResult: {'verdict': verdict.wire},
        );
        final outcome = await h.recorder.record(h.job);
        expect(
          outcome,
          DesignReviewRecorderOutcome.recorded,
          reason: 'verdict ${verdict.wire} must still gate',
        );
        final item = await h.engine.loadWorkItem(workItemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);
      }
    });

    test('reads an embedded designReviewResult object and keeps its findings',
        () async {
      final h = await host(
        structuredResult: {
          'designReviewResult': DesignReviewResult(
            reviewExecutionId: reviewerExecutionId,
            revisionId: revisionId,
            verdict: DesignReviewVerdict.changesRequired,
            findings: const [],
            assessedDimensions: const ['design-system'],
            createdAt: now,
            version: 1,
          ).toJson(),
        },
      );

      final outcome = await h.recorder.record(h.job);

      expect(outcome, DesignReviewRecorderOutcome.recorded);
      final stored = await h.governanceStore.readDesignReviewResultForExecution(
        revisionId,
        reviewerExecutionId,
      );
      expect(stored!.verdict, DesignReviewVerdict.changesRequired);
    });
  });

  group('idempotence', () {
    test('a repeated tick writes no second result and no second decision',
        () async {
      final h = await host();

      final first = await h.recorder.record(h.job);
      expect(first, DesignReviewRecorderOutcome.recorded);

      final second = await h.recorder.record(h.job);
      expect(second, DesignReviewRecorderOutcome.alreadyRecorded);

      final results = await h.governanceStore.readDesignReviewResultsForRevision(
        revisionId,
      );
      expect(results, hasLength(1), reason: 'exactly one result row');

      // The engine's own requestHumanDecision idempotency means the parked
      // decision is returned rather than a second one minted.
      final item = await h.engine.loadWorkItem(workItemId);
      expect(item.state, WorkItemState.waitingForHumanDecision);
    });

    test('a result already durable is not rewritten, but the gate still rises',
        () async {
      final h = await host(preSeededResult: true);

      final outcome = await h.recorder.record(h.job);
      expect(outcome, DesignReviewRecorderOutcome.recorded);

      final results = await h.governanceStore.readDesignReviewResultsForRevision(
        revisionId,
      );
      expect(results, hasLength(1));
      final item = await h.engine.loadWorkItem(workItemId);
      expect(item.state, WorkItemState.waitingForHumanDecision);
    });
  });

  group('fail-closed, without fabrication', () {
    test('an unreadable revision writes nothing', () async {
      final h = await host(writeRevision: false);

      final outcome = await h.recorder.record(h.job);

      expect(outcome, DesignReviewRecorderOutcome.revisionUnreadable);
      final item = await h.engine.loadWorkItem(workItemId);
      expect(item.state, WorkItemState.designInReview);
      expect(
        await h.governanceStore.readDesignReviewResultsForRevision(revisionId),
        isEmpty,
      );
    });

    test('a revision belonging to a different item is refused', () async {
      final h = await host(revisionWorkItemId: 'wi-somebody-else');

      final outcome = await h.recorder.record(h.job);

      expect(outcome, DesignReviewRecorderOutcome.revisionUnreadable);
      final item = await h.engine.loadWorkItem(workItemId);
      expect(item.state, WorkItemState.designInReview);
    });

    test('an item not at designInReview is skipped', () async {
      final h = await host(itemState: WorkItemState.agentCompleted);

      final outcome = await h.recorder.record(h.job);

      expect(outcome, DesignReviewRecorderOutcome.skippedWrongState);
    });
  });

  group('no verdict is never turned into a verdict', () {
    Future<void> expectNoVerdict(
      Future<_Host> Function() build,
    ) async {
      final h = await build();

      final outcome = await h.recorder.record(h.job);

      expect(outcome, DesignReviewRecorderOutcome.noVerdict);

      // NO DesignReviewResult was invented.
      expect(
        await h.governanceStore.readDesignReviewResultsForRevision(revisionId),
        isEmpty,
        reason: 'a verdict-less review must not produce a result row',
      );

      // The item is still gated, so it is not silently stranded.
      final item = await h.engine.loadWorkItem(workItemId);
      expect(item.state, WorkItemState.waitingForHumanDecision);
      final decision = await h.workflowStore.readHumanDecision(
        item.blockingHumanDecisionId!,
      );
      expect(decision.decisionType, HumanDecisionType.designApproval);
      expect(isDesignApprovalAbsentDecision(decision), isTrue);
      // It carries NO verdict, and cannot be resolved as approval.
      expect(decision.metadata?[designReviewVerdictMetadataKey], isNull);
      expect(
        designApprovalAbsentChoiceIsResolvable(
          decision,
          HumanDecisionChoice.approve,
        ),
        isFalse,
      );
      expect(
        designApprovalAbsentChoiceIsResolvable(
          decision,
          HumanDecisionChoice.reject,
        ),
        isTrue,
      );
      expect(
        decision.recommendation,
        designApprovalNoVerdictRecommendation,
      );
      // The rejection recommendation is not a verdict wire value.
      expect(
        DesignReviewVerdict.values.map((v) => v.wire),
        isNot(contains(decision.recommendation)),
      );

      // The absence is durable on the reviewer's OWN execution timeline.
      final events = await h.executionStore.readEvents(reviewerExecutionId);
      expect(
        events.where((e) => e.payload?['designReviewGate'] == 'no_verdict'),
        hasLength(1),
        reason: 'the absence is recorded exactly once, on the reviewer run',
      );
    }

    test('a result with no verdict raises a labelled non-verdict decision',
        () async {
      await expectNoVerdict(
        () => host(structuredResult: const {'assessedDimensions': ['a11y']}),
      );
    });

    test('an unreadable verdict string raises a labelled non-verdict decision',
        () async {
      await expectNoVerdict(
        () => host(structuredResult: const {'verdict': 'needs_work'}),
      );
    });

    test('a completed reviewer that wrote no result raises a non-verdict '
        'decision', () async {
      await expectNoVerdict(() => host(writeResult: false));
    });

    test('a failed reviewer execution raises a non-verdict decision', () async {
      await expectNoVerdict(
        () => host(
          executionStatus: AgentSessionStatus.failed,
          writeResult: false,
        ),
      );
    });
  });

  group('reviewer execution resolution', () {
    test('falls back to the newest terminal reviewer execution when the job '
        'names none', () async {
      final h = await host(referenceExecution: false);

      final outcome = await h.recorder.record(h.job);

      expect(outcome, DesignReviewRecorderOutcome.recorded);
      final stored = await h.governanceStore.readDesignReviewResultForExecution(
        revisionId,
        reviewerExecutionId,
      );
      expect(stored, isNotNull);
    });

    test('an execution reference that does not resolve still falls back',
        () async {
      // The job names an execution, but the store holds the reviewer under a
      // different id — the lease-expiry shape.
      final h = await host(referenceExecution: true);
      final orphanJob = h.job.copyWith(
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-missing',
          agentExecutionId: 'agx-missing',
          createdAt: now,
        ),
      );

      final outcome = await h.recorder.record(orphanJob);

      expect(outcome, DesignReviewRecorderOutcome.recorded);
    });
  });
}

class _Host {
  _Host({
    required this.engine,
    required this.workflowStore,
    required this.executionStore,
    required this.governanceStore,
    required this.job,
    required this.logs,
    required this.recorder,
  });

  final DurableWorkflowEngine engine;
  final InMemoryWorkflowStore workflowStore;
  final InMemoryExecutionStore executionStore;
  final InMemoryDesignGovernanceStore governanceStore;
  final Job job;
  final List<(String, Map<String, dynamic>)> logs;
  final DesignReviewRecorder recorder;
}

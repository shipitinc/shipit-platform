import 'package:control_plane_server/server.dart'
    show
        AgentExecutionBudgets,
        DesignLaneTickResult,
        DesignRefusalSink,
        buildDesignRefusalSink,
        runDesignLaneTick;
import 'package:control_plane_server/src/design/design_review_workload_resolver.dart';
import 'package:control_plane_server/src/design/design_revision_producer.dart';
import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

/// THE PROOF for design step 8's composition: the two design schedulers are
/// mounted, they run revision-BEFORE-review in one pass, and the lane's
/// refusals reach a human.
///
/// ## WHAT IT DRIVES
///
/// The real [runDesignLaneTick] — the exact function `run()` calls — against
/// real [Scheduler]s built from the real `designRevisionDefinition` /
/// `designReviewDefinition`, their real dedupe/instruction/request builders, the
/// real `designReviewWorkloadResolver`, the real `DurableWorkflowEngine` and
/// in-memory stores. The only fakes are the worker dispatch (records the
/// selection request and runs nothing) and the clock, exactly as
/// `engineering_review_composition_order_test.dart` fakes them.
///
/// ## THE ORDER ASSERTION
///
/// The design item STARTS at `agentCompleted` — the state the producer reads —
/// and no `designReview` job exists before the pass. After ONE pass of
/// [runDesignLaneTick], a `designReview` job exists. That is only possible if
/// `sched-design-revision` ran first and moved the item to `designInReview`
/// before `sched-design-review` asked what was runnable. Reverse the two `await`s
/// in `runDesignLaneTick` and this test fails with "no design review job", on the
/// first pass, which is the point.
const String _workItemId = 'wi-design-composition';
const String _productId = 'prod-1';
const String _contractId = 'design-contract-wi-design-composition';
const String _executionId = 'agx-design-composition';
const String _jobId = 'job-design-composition';
const String _missingContractId = 'contract-that-does-not-exist';
const String _reviewerId = 'agx-design-reviewer';

const List<Map<String, dynamic>> _boardIds = [
  {
    'boardId': 'login-desktop',
    'boardName': 'Login',
    'provider': 'penpot',
    'providerFileId': 'pf-1',
  },
];

const List<Map<String, dynamic>> _responsiveTargets = [
  {'breakpoint': 'lg', 'minViewportWidthCss': 1024},
  {'breakpoint': 'xs', 'minViewportWidthCss': 320},
];

const List<Map<String, dynamic>> _statesRepresented = [
  {'boardId': 'login-desktop', 'stateKey': 'form-filled', 'variant': 'default'},
];

Map<String, dynamic> _validPayload() => <String, dynamic>{
  'designSystemRevision': 'dsr-1',
  'provider': 'penpot',
  'penpotFileId': 'pf-1',
  'penpotPageId': 'pp-1',
  'boardIds': _boardIds,
  'responsiveTargets': _responsiveTargets,
  'statesRepresented': _statesRepresented,
  'artifactRefs': <dynamic>[],
  'reviewExecutionIds': [_reviewerId],
  'reviewScope': const {
    'boardIds': ['login-desktop'],
    'dimensions': ['a11y', 'responsive'],
  },
};

enum _Mode { produce, refuse }

class _Host {
  _Host._({
    required this.mode,
    required this.workflowStore,
    required this.engine,
    required this.executionStore,
    required this.jobStore,
    required this.workerStore,
    required this.dispatch,
    required this.revisionScheduler,
    required this.reviewScheduler,
    required this.producer,
    required this.loggedEvents,
  });

  static const startingRevision = 'aaaaaaa';
  static final now = DateTime.utc(2026, 10, 22, 12);

  static Future<_Host> build(_Mode mode) async {
    final workflowStore = InMemoryWorkflowStore();
    final contractStore = InMemoryDesignContractStore();
    // The agentCompleted -> designInReview edge confirms `designContractId`
    // against the store the ENGINE holds. Production mounts it; a host without
    // it would fail the transition for lack of a store and would be testing the
    // guard, not the lane.
    final engine = DurableWorkflowEngine(
      store: workflowStore,
      designContractStore: contractStore,
    );
    final executionStore = InMemoryExecutionStore();
    final jobStore = InMemoryJobStore();
    final workerStore = InMemoryWorkerStore();
    final governanceStore = InMemoryDesignGovernanceStore();
    final dispatch = _NoWorkerDispatch();
    final loggedEvents = <(String, Map<String, dynamic>)>[];

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: _workItemId,
        productId: _productId,
        category: WorkItemCategory.feature,
        title: 'Design the login screen',
        state: WorkItemState.agentCompleted,
        designContractId: mode == _Mode.produce
            ? _contractId
            : _missingContractId,
        metadata: const {'producerActorId': _executionId},
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (mode == _Mode.produce) {
      await contractStore.saveDesignContract(
        DesignContract(
          contractId: _contractId,
          workItemId: _workItemId,
          requiredArtifacts: const [
            RequiredArtifact(
              artifactType: 'design_revision',
              description: 'A Penpot revision',
              required: true,
            ),
          ],
          reviewers: const [_reviewerId],
          approvalThreshold: 1,
          status: DesignContractStatus.draft,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // The designer's durable rows. A refusal still needs a COMPLETED execution
    // and result, because the stall gate's `agentCompleted -> reviewInProgress`
    // edge checks `agentResultValid()`; a refusal that also lacked evidence would
    // test the guard, not the mechanism.
    await executionStore.saveExecution(
      AgentExecution(
        executionId: _executionId,
        workItemId: _workItemId,
        requestId: 'req-1',
        runtimeTypeId: 'opencode',
        role: AgentRole.designAgent,
        status: AgentSessionStatus.completed,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-design',
          path: '/tmp/design-workspace',
        ),
        startedAt: now,
        completedAt: now,
      ),
    );
    await executionStore.saveResult(
      _executionId,
      AgentResult(
        resultId: 'res-design',
        sessionId: 'sess-design',
        workItemId: _workItemId,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 1,
          toolCalls: 0,
          errors: [],
          warnings: [],
        ),
        structuredResult: _validPayload(),
        executionId: _executionId,
        role: AgentRole.designAgent,
        completedAt: now,
      ),
    );

    // The design revision job the revision scheduler will RECONCILE. It is
    // `running` with a terminal worker execution — not hand-written `succeeded`,
    // because step 1 only reconciles claimed/running rows and a terminal row
    // would be invisible to the tick (the trap recorded on the engineering
    // review composition host).
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-design',
        workItemId: _workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: startingRevision,
        requiredCapabilities: const {
          WorkerCapability.penpotWrite,
          WorkerCapability.visualDesign,
        },
        agentExecutionId: _executionId,
        endingRevision: 'c0ffee1',
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        startedAt: now,
        endedAt: now,
      ),
    );
    await jobStore.saveJob(
      Job(
        jobId: _jobId,
        workItemId: _workItemId,
        jobType: JobType.designRevision,
        requiredRole: AgentRole.designAgent,
        requiredCapabilities: const {
          WorkerCapability.penpotWrite,
          WorkerCapability.visualDesign,
        },
        priority: JobPriority.normal,
        state: JobState.running,
        dedupeKey: '$_workItemId:${JobType.designRevision.wire}',
        createdAt: now,
        instruction: 'Produce a design revision',
        attempt: 1,
        maxAttempts: designRevisionDefinition.maxAttempts,
        version: 1,
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-design',
          agentExecutionId: _executionId,
          createdAt: now,
        ),
      ),
    );

    final workload = SchedulerWorkload(
      repositoryPath: '/durable/clone',
      startingRevision: startingRevision,
      timeoutSeconds: AgentExecutionBudgets.designAgentSeconds,
      runtimeTypeId: 'rt-design',
    );
    DateTime clock() => now;

    final revisionScheduler = Scheduler(
      schedulerId: 'sched-design-revision',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: designRevisionDefinition,
      workload: workload,
      dedupeKeyBuilder: designRevisionDedupeKey,
      instructionBuilder: designRevisionInstruction,
      requestBuilder: designRevisionRequest,
      clock: clock,
    );

    final reviewScheduler = Scheduler(
      schedulerId: 'sched-design-review',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: designReviewDefinition,
      workload: workload,
      dedupeKeyBuilder: designReviewDedupeKey,
      instructionBuilder: designReviewInstruction,
      requestBuilder: designReviewRequest,
      workloadResolver: designReviewWorkloadResolver(
        designRevisionStore: governanceStore,
        repositoryPath: '/durable/clone',
        startingRevision: startingRevision,
        runtimeTypeId: 'rt-design',
        timeoutSeconds: AgentExecutionBudgets.designReviewerSeconds,
        logger: (message, context) => loggedEvents.add((message, context)),
      ),
      clock: clock,
    );

    final producer = DesignRevisionProducer(
      workflowStore: workflowStore,
      workflowEngine: engine,
      executionStore: executionStore,
      jobStore: jobStore,
      designRevisionStore: governanceStore,
      designContractStore: contractStore,
      defectStore: _FakeDefectStore(),
      clock: () => DateTime.utc(2026, 11, 1),
      logger: (message, context) => loggedEvents.add((
        message,
        <String, dynamic>{
          ...context,
          'producerEvent': message,
        },
      )),
    );

    return _Host._(
      mode: mode,
      workflowStore: workflowStore,
      engine: engine,
      executionStore: executionStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      revisionScheduler: revisionScheduler,
      reviewScheduler: reviewScheduler,
      producer: producer,
      loggedEvents: loggedEvents,
    );
  }

  final _Mode mode;
  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine engine;
  final InMemoryExecutionStore executionStore;
  final InMemoryJobStore jobStore;
  final InMemoryWorkerStore workerStore;
  final _NoWorkerDispatch dispatch;
  final Scheduler revisionScheduler;
  final Scheduler reviewScheduler;
  final DesignRevisionProducer producer;
  final List<(String, Map<String, dynamic>)> loggedEvents;

  /// The SAME sink the composition root builds, from the SAME function, so the
  /// test cannot assert on refusal-surfacing behaviour the production wiring
  /// does not have. It fills `refusedJobIds`/`outcomes` on the returned tick.
  DesignRefusalSink get refusalSink => buildDesignRefusalSink(
    workflowEngine: engine,
    executionStore: executionStore,
    log: (message, context) => loggedEvents.add((message, context)),
  );

  Future<DesignLaneTickResult> runPass() => runDesignLaneTick(
    designRevisionScheduler: revisionScheduler,
    designReviewScheduler: reviewScheduler,
    jobStore: jobStore,
    triageProcessor: null,
    designRevisionProducer: producer,
    refusalSink: refusalSink,
    workflowEngine: engine,
    executionStore: executionStore,
    workerStore: workerStore,
    foldStalls: (_) {},
    log: (message, context) => loggedEvents.add((message, context)),
  );

  Future<List<Job>> jobsOfType(JobType type) async =>
      (await jobStore.listJobsForWorkItem(
        _workItemId,
      )).where((job) => job.jobType == type).toList(growable: false);
}

void main() {
  group('the design lane runs revision BEFORE review in one pass', () {
    test('one pass produces a revision, moves the item to designInReview, and '
        'enqueues the reviewer that the same pass can see', () async {
      final host = await _Host.build(_Mode.produce);

      expect(await host.jobsOfType(JobType.designReview), isEmpty);

      final result = await host.runPass();

      expect(result.refusalJobIds, isEmpty);
      expect(result.blockedReviewJobIds, isEmpty);

      final item = await host.engine.loadWorkItem(_workItemId);
      expect(item.state, WorkItemState.designInReview);
      expect(item.metadata?[designRevisionIdMetadataKey], isNotNull);
      expect(item.metadata?[designerExecutionIdMetadataKey], _executionId);

      // THE ORDER ASSERTION. No design review job existed before the pass; one
      // exists after it. That is only reachable if the revision tick advanced
      // the item BEFORE the review tick evaluated its entry state.
      final reviewJobs = await host.jobsOfType(JobType.designReview);
      expect(
        reviewJobs,
        hasLength(1),
        reason:
            'revision-before-review is load-bearing: reversed, the review '
            'tick sees agentCompleted, enqueues nothing, and the design '
            'revision is reviewed a full interval late',
      );
      expect(
        reviewJobs.single.dedupeKey,
        contains(JobType.designReview.wire),
        reason:
            'the review job is keyed by its type, not by a copy of the '
            'revision scheduler\'s key',
      );
    });

    test('a second pass neither re-produces the revision nor duplicates the '
        'review job', () async {
      final host = await _Host.build(_Mode.produce);
      await host.runPass();
      final second = await host.runPass();

      expect(second.refusalJobIds, isEmpty);
      expect(await host.jobsOfType(JobType.designReview), hasLength(1));
      expect(
        (await host.jobsOfType(JobType.designRevision)).where(
          (job) => !job.isTerminal,
        ),
        isEmpty,
      );
    });
  });

  group('a refusal inside the real design section surfaces', () {
    test('the lane reports the refused job, raises exactly one decision, and '
        'enqueues no reviewer', () async {
      final host = await _Host.build(_Mode.refuse);

      final result = await host.runPass();

      expect(result.refusalJobIds, [_jobId]);
      expect(result.refusalOutcomes, hasLength(1));
      expect(
        result.refusalOutcomes.single.name,
        'raised',
        reason:
            'the gate must raise, not report producerEvidenceUnreadable: the '
            'execution and result are present',
      );
      expect(result.blockedReviewJobIds, isEmpty);

      final item = await host.engine.loadWorkItem(_workItemId);
      expect(item.state, WorkItemState.waitingForHumanDecision);

      final decisions = await host.workflowStore.readHumanDecisionsForWorkItem(
        _workItemId,
      );
      expect(decisions, hasLength(1));
      expect(
        decisions.single.question,
        contains('p1.design-contract-unresolved'),
      );

      // No reviewer for an item that never reached `designInReview`.
      expect(await host.jobsOfType(JobType.designReview), isEmpty);
    });

    test(
      'a second pass over the same refusal does not mint a second decision',
      () async {
        final host = await _Host.build(_Mode.refuse);
        await host.runPass();
        final second = await host.runPass();

        // A pass does NOT re-touch a terminal job, so the drain (and therefore
        // the gate) is not invoked a second time. What must hold is that the
        // second pass mints no second decision; the gate's `alreadyPending` arm
        // is exercised directly in `design_producer_refusal_surface_test.dart`.
        expect(
          second.refusalOutcomes.where(
            (outcome) => outcome.name == 'raised',
          ),
          isEmpty,
        );
        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(_workItemId),
          hasLength(1),
        );
      },
    );
  });
}

class _NoWorkerDispatch implements WorkerDispatch {
  final List<WorkerExecutionRequest> requests = [];

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    requests.add(request);
    return WorkerSelection.noCompatibleWorker();
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      throw StateError('no execution may run in this file');

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

class _FakeDefectStore implements DefectStore {
  @override
  Future<Defect> readDefect(String defectId) async =>
      throw UnimplementedError('no defect is read by these cases');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

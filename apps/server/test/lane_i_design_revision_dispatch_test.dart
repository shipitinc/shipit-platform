import 'package:control_plane_server/src/design/design_revision_producer.dart';
import 'package:control_plane_server/src/triage/lane_i_tick_hook.dart';
import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// ## WHAT THIS FILE PROVES
///
/// The step-6 producer is only reachable if the tick drain actually registers
/// it. That registration is one entry in `drainTriageOutcomesFromTick`'s
/// dispatch table:
///
///     if (designRevisionProducer != null)
///       JobType.designRevision: (job) async {
///         await designRevisionProducer.processCompletedDesignRevisionJob(job);
///       },
///
/// before the caller-supplied `handlers` spread — `lane_i_tick_hook.dart:197-201`.
/// Deleting it left every existing suite green, because nothing passed a
/// producer through the REAL drain: the producer's own tests call it directly,
/// and the drain's tests use fake handlers for other types. This file closes
/// that gap by driving the real `drainTriageOutcomesFromTick` over a real
/// `DesignRevisionProducer` and real in-memory stores.
///
/// If lines 197-201 are removed, the first test below throws
/// `UnhandledJobTypeException` for the design job and fails; the others lose
/// the producer's registered handler and fail too. That is the point.

const String _workItemId = 'wi-design-1';
const String _productId = 'prod-1';
const String _contractId = 'design-contract-wi-design-1';
const String _executionId = 'agx-design-1';
const String _jobId = 'job-design-1';
const String _reviewerId = 'agx-reviewer-1';

const String _triageJobId = 'job-triage-1';
const String _triageWorkItemId = 'wi-triage-1';

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

const Map<String, dynamic> _reviewScope = {
  'boardIds': ['login-desktop'],
  'dimensions': ['a11y', 'responsive'],
};

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
  'reviewScope': _reviewScope,
};

SchedulerTickResult _tick(List<String> ids) => SchedulerTickResult(
  dispatched: ids,
  terminal: const [],
  reconciled: const [],
  cancelledQueued: const [],
  deferred: const [],
  enqueued: const [],
);

/// A terminal `triageDefect` job whose work item is deliberately unrelated to
/// the design host: the only thing that may touch it is the triage handler.
Job _triageJob() => Job(
  jobId: _triageJobId,
  workItemId: _triageWorkItemId,
  jobType: JobType.triageDefect,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {WorkerCapability.git},
  priority: JobPriority.normal,
  state: JobState.succeeded,
  dedupeKey: '$_triageWorkItemId:${JobType.triageDefect.wire}',
  createdAt: DateTime.utc(2026, 1, 1),
  instruction: 'Classify the defect',
  attempt: 1,
  maxAttempts: 3,
  version: 1,
);

/// A terminal job of a type the design-only dispatch table does NOT register.
Job _unregisteredJob() => Job(
  jobId: 'job-onboard-1',
  workItemId: 'wi-onboard-1',
  jobType: JobType.onboardProduct,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {WorkerCapability.git},
  priority: JobPriority.normal,
  state: JobState.succeeded,
  dedupeKey: 'wi-onboard-1:${JobType.onboardProduct.wire}',
  createdAt: DateTime.utc(2026, 1, 1),
  instruction: 'Onboard the product',
  attempt: 1,
  maxAttempts: 3,
  version: 1,
);

/// A valid design host: real in-memory stores, the real durable workflow
/// engine, and one terminal design-revision job. Mirrors the producer's own
/// happy-path fixture so the producer actually PRODUCES here rather than
/// refusing on a precondition unrelated to dispatch.
class _Host {
  late final InMemoryWorkflowStore workflowStore;
  late final InMemoryDesignContractStore contractStore;
  late final InMemoryDesignGovernanceStore governanceStore;
  late final InMemoryExecutionStore executionStore;
  late final InMemoryJobStore jobStore;
  late final _FakeDefectStore defectStore;
  late final DurableWorkflowEngine engine;
  late final Job job;
  late final DesignRevisionProducer producer;
  late final List<Map<String, dynamic>> producerEvents;
}

Future<_Host> _host() async {
  final host = _Host();
  final now = DateTime.utc(2026, 1, 1);

  host.workflowStore = InMemoryWorkflowStore();
  host.contractStore = InMemoryDesignContractStore();
  host.governanceStore = InMemoryDesignGovernanceStore();
  host.executionStore = InMemoryExecutionStore();
  host.jobStore = InMemoryJobStore();
  host.defectStore = _FakeDefectStore();
  host.engine = DurableWorkflowEngine(
    store: host.workflowStore,
    designContractStore: host.contractStore,
  );
  host.producerEvents = <Map<String, dynamic>>[];

  final item = WorkItem(
    workItemId: _workItemId,
    productId: _productId,
    category: WorkItemCategory.feature,
    title: 'Design the login screen',
    state: WorkItemState.agentCompleted,
    designContractId: _contractId,
    createdAt: now,
    updatedAt: now,
  );
  await host.workflowStore.saveWorkItem(item);

  await host.contractStore.saveDesignContract(
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

  await host.executionStore.saveExecution(
    AgentExecution(
      executionId: _executionId,
      workItemId: _workItemId,
      requestId: 'req-1',
      runtimeTypeId: 'opencode',
      role: AgentRole.designAgent,
      status: AgentSessionStatus.completed,
      workspace: const AgentWorkspace(
        workspaceId: 'ws-1',
        path: '/tmp/design-workspace',
      ),
      startedAt: now,
      completedAt: now,
    ),
  );
  await host.executionStore.saveResult(
    _executionId,
    AgentResult(
      resultId: 'res-1',
      sessionId: 'sess-1',
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

  host.job = Job(
    jobId: _jobId,
    workItemId: _workItemId,
    jobType: JobType.designRevision,
    requiredRole: AgentRole.designAgent,
    requiredCapabilities: const {
      WorkerCapability.penpotWrite,
      WorkerCapability.visualDesign,
    },
    priority: JobPriority.normal,
    state: JobState.succeeded,
    dedupeKey: '$_workItemId:${JobType.designRevision.wire}',
    createdAt: now,
    instruction: 'Produce a design revision',
    attempt: 1,
    maxAttempts: 3,
    version: 1,
    executionReference: JobExecutionReference(
      workerExecutionId: 'wx-1',
      agentExecutionId: _executionId,
      createdAt: now,
    ),
  );
  await host.jobStore.saveJob(host.job);

  host.producer = DesignRevisionProducer(
    workflowStore: host.workflowStore,
    workflowEngine: host.engine,
    executionStore: host.executionStore,
    jobStore: host.jobStore,
    designRevisionStore: host.governanceStore,
    designContractStore: host.contractStore,
    defectStore: host.defectStore,
    clock: () => DateTime.utc(2026, 2, 1),
    logger: (event, data) => host.producerEvents.add({
      'event': event,
      ...data,
    }),
  );

  return host;
}

void main() {
  group('the tick drain registers the designRevision producer', () {
    test(
      'a designRevision job is consumed by the producer while a triageDefect '
      'job in the same tick is not',
      () async {
        // LOAD-BEARING: the registration under test is
        // `lane_i_tick_hook.dart:197-201` — the
        // `if (designRevisionProducer != null)
        //  JobType.designRevision: (job) async { ... }` entry in the dispatch
        // table. Delete those five lines and this drain call throws
        // `UnhandledJobTypeException` for `job-design-1`, failing this test.
        final host = await _host();
        await host.jobStore.saveJob(_triageJob());

        final triageSeen = <String>[];
        final drain = await drainTriageOutcomesFromTick(
          tickResult: _tick([_jobId, _triageJobId]),
          jobStore: host.jobStore,
          designRevisionProducer: host.producer,
          handlers: {
            JobType.triageDefect: (job) async => triageSeen.add(job.jobId),
          },
          logger: (_, _) {},
        );

        expect(drain.considered, 2);
        expect(drain.skipped, 0);
        expect(drain.handedOff, 2);
        expect(drain.failedJobIds, isEmpty);
        expect(drain.succeededJobIds, containsAll([_jobId, _triageJobId]));

        // The design job really was PROCESSED: one durable revision exists and
        // the item advanced with both metadata keys stamped.
        final revisions = await host.governanceStore
            .readDesignRevisionsForWorkItem(_workItemId);
        expect(revisions, hasLength(1));
        expect(
          revisions.single.revisionId,
          DesignRevisionProducer.designRevisionIdForExecution(_executionId),
        );
        final item = await host.workflowStore.readWorkItem(_workItemId);
        expect(item.state, WorkItemState.designInReview);
        expect(
          item.metadata?[designRevisionIdMetadataKey],
          revisions.single.revisionId,
        );
        expect(
          item.metadata?[designerExecutionIdMetadataKey],
          _executionId,
        );

        // The triage handler consumed the triage job; the design handler did
        // not, and never saw it.
        expect(triageSeen, [_triageJobId]);
        final produced = host.producerEvents
            .where((event) => event['event'] == 'design_revision.produced')
            .toList();
        expect(produced, hasLength(1));
        expect(produced.single['jobId'], _jobId);
        expect(
          host.producerEvents.where((event) => event['jobId'] == _triageJobId),
          isEmpty,
          reason:
              'the design handler is registered for JobType.designRevision '
              'only; it must not be reached for a triage job in the same tick',
        );
      },
    );

    test(
      'a handlers-less drain no longer throws for designRevision when the '
      'producer is supplied',
      () async {
        // No `triageProcessor` and no `handlers`: the producer registration is
        // the ONLY table entry. Before the fix this job type was unregistered
        // and raised UnhandledJobTypeException.
        final host = await _host();

        final drain = await drainTriageOutcomesFromTick(
          tickResult: _tick([_jobId]),
          jobStore: host.jobStore,
          designRevisionProducer: host.producer,
          logger: (_, _) {},
        );

        expect(drain.considered, 1);
        expect(drain.skipped, 0);
        expect(drain.handedOff, 1);
        expect(drain.succeededJobIds, [_jobId]);
        expect(drain.failedJobIds, isEmpty);

        final item = await host.workflowStore.readWorkItem(_workItemId);
        expect(item.state, WorkItemState.designInReview);
      },
    );

    test(
      'an unregistered type still throws UnhandledJobTypeException when the '
      'producer is supplied',
      () async {
        // Registering designRevision must not turn every type into a silent
        // skip. The dispatch table remains closed: only designRevision (plus
        // anything supplied in `handlers`) is handled.
        final host = await _host();
        final unregistered = _unregisteredJob();
        await host.jobStore.saveJob(unregistered);

        expect(
          () => drainTriageOutcomesFromTick(
            tickResult: _tick([unregistered.jobId]),
            jobStore: host.jobStore,
            designRevisionProducer: host.producer,
            logger: (_, _) {},
          ),
          throwsA(
            isA<UnhandledJobTypeException>()
                .having(
                  (e) => e.jobType,
                  'jobType',
                  JobType.onboardProduct,
                )
                .having((e) => e.jobId, 'jobId', unregistered.jobId),
          ),
        );
      },
    );
  });
}

class _FakeDefectStore implements DefectStore {
  @override
  Future<Defect> readDefect(String defectId) async =>
      throw UnimplementedError('no defect is read by these cases');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

import 'dart:convert';

import 'package:control_plane_server/src/design/design_revision_producer.dart';
import 'package:control_plane_server/src/persistence/postgres_defect_store.dart'
    show DefectNotFoundException;
import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// ## WHAT THIS FILE PROVES
///
/// The step-6 producer against the human ruling `d5e8a144`: a completed design
/// execution becomes one durable `DesignRevision`, the design contract goes
/// `draft -> underReview` (a write the platform had no actor for), and only then
/// does the item advance `agentCompleted -> designInReview` with both metadata
/// keys stamped.
///
/// Every refusal below names the condition it exercises (P1–P6, Q1/Q2/Q5/Q6/Q7),
/// so a test cannot pass because "something was rejected". The Q7 case asserts
/// the negative side that matters most: nothing is stored and the contract is
/// NOT submitted when the fidelity anchor refuses.
///
/// ## WHY THE STORES ARE IN-MEMORY AND THE ENGINE IS REAL
///
/// `DurableWorkflowEngine` is the only component that supplies
/// `designContractUnderReview()` with the durable-column resolution the guard
/// reads, so faking the engine would test a guard the production path does not
/// call. The stores are the package-provided in-memory implementations, which
/// run the same gate functions as PostgreSQL (the anchor gate is shared, not
/// per-implementation).

const String _workItemId = 'wi-design-1';
const String _productId = 'prod-1';
const String _contractId = 'design-contract-wi-design-1';
const String _executionId = 'agx-design-1';
const String _jobId = 'job-design-1';
const String _reviewerId = 'agx-reviewer-1';

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

/// A full producer host: real stores, real engine, one terminal design job.
class _Host {
  late final InMemoryWorkflowStore workflowStore;
  late final InMemoryDesignContractStore contractStore;
  late final InMemoryDesignGovernanceStore governanceStore;
  late final InMemoryExecutionStore executionStore;
  late final InMemoryJobStore jobStore;
  late final _FakeDefectStore defectStore;
  late final DurableWorkflowEngine engine;
  late final WorkItem item;
  late final DesignContract contract;
  late final AgentExecution execution;
  late final Job job;
  late final DesignRevisionStore revisionStore;
  late final DesignRevisionProducer producer;
}

Future<_Host> _host({
  Map<String, dynamic>? payload,
  WorkItemState itemState = WorkItemState.agentCompleted,
  bool contractColumnSet = true,
  bool contractExists = true,
  DesignContractStatus contractStatus = DesignContractStatus.draft,
  Map<String, dynamic>? itemMetadata,
  String? featureRef,
  AgentSessionStatus executionStatus = AgentSessionStatus.completed,
  AgentResultStatus resultStatus = AgentResultStatus.completed,
  bool vanishRevisionWrites = false,
  List<HumanDecision> decisions = const [],
  List<Job> extraJobs = const [],
  Map<String, Defect> defects = const {},
}) async {
  final host = _Host();
  final structured = payload ?? _validPayload();

  host.workflowStore = InMemoryWorkflowStore();
  host.contractStore = InMemoryDesignContractStore();
  host.governanceStore = InMemoryDesignGovernanceStore();
  host.executionStore = InMemoryExecutionStore();
  host.jobStore = InMemoryJobStore();
  host.defectStore = _FakeDefectStore(defects);
  host.revisionStore = vanishRevisionWrites
      ? _VanishingDesignRevisionStore(host.governanceStore)
      : host.governanceStore;
  host.engine = DurableWorkflowEngine(
    store: host.workflowStore,
    designContractStore: host.contractStore,
  );

  final now = DateTime.utc(2026, 1, 1);
  host.item = WorkItem(
    workItemId: _workItemId,
    productId: _productId,
    category: WorkItemCategory.feature,
    title: 'Design the login screen',
    state: itemState,
    designContractId: contractColumnSet ? _contractId : null,
    featureRef: featureRef,
    metadata: itemMetadata,
    createdAt: now,
    updatedAt: now,
  );
  await host.workflowStore.saveWorkItem(host.item);

  host.contract = DesignContract(
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
    status: contractStatus,
    createdAt: now,
    updatedAt: now,
  );
  if (contractExists) {
    await host.contractStore.saveDesignContract(host.contract);
  }

  host.execution = AgentExecution(
    executionId: _executionId,
    workItemId: _workItemId,
    requestId: 'req-1',
    runtimeTypeId: 'opencode',
    role: AgentRole.designAgent,
    status: executionStatus,
    workspace: const AgentWorkspace(
      workspaceId: 'ws-1',
      path: '/tmp/design-workspace',
    ),
    startedAt: now,
    completedAt: now,
  );
  await host.executionStore.saveExecution(host.execution);
  await host.executionStore.saveResult(
    _executionId,
    AgentResult(
      resultId: 'res-1',
      sessionId: 'sess-1',
      workItemId: _workItemId,
      status: resultStatus,
      artifacts: const [],
      diagnostics: const AgentDiagnostics(
        exitCode: 0,
        durationMs: 1,
        toolCalls: 0,
        errors: [],
        warnings: [],
      ),
      structuredResult: structured,
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
  for (final extra in extraJobs) {
    await host.jobStore.saveJob(extra);
  }
  for (final decision in decisions) {
    await host.workflowStore.saveHumanDecision(decision);
  }

  host.producer = DesignRevisionProducer(
    workflowStore: host.workflowStore,
    workflowEngine: host.engine,
    executionStore: host.executionStore,
    jobStore: host.jobStore,
    designRevisionStore: host.revisionStore,
    designContractStore: host.contractStore,
    defectStore: host.defectStore,
    clock: () => DateTime.utc(2026, 2, 1),
  );
  return host;
}

Future<DesignRevisionProducerResult> _run(_Host host) =>
    host.producer.processCompletedDesignRevisionJob(host.job);

DesignRevision _storedRevision({
  String revisionId = 'rev-parent',
  String workItemId = _workItemId,
  String? parentRevisionId,
  String designSystemRevision = 'dsr-1',
  DesignRevisionStatus status = DesignRevisionStatus.draft,
}) => DesignRevision(
  revisionId: revisionId,
  workItemId: workItemId,
  productId: _productId,
  parentRevisionId: parentRevisionId,
  designSystemRevision: designSystemRevision,
  provider: DesignProviderType.penpot,
  penpotFileId: 'pf-1',
  penpotPageId: 'pp-1',
  boardIdsJson: jsonEncode(_boardIds),
  responsiveTargetsJson: jsonEncode(_responsiveTargets),
  statesRepresentedJson: jsonEncode(_statesRepresented),
  artifactRefsJson: '[]',
  designerExecutionId: 'agx-earlier-designer',
  reviewExecutionIdsJson: jsonEncode([_reviewerId]),
  status: status,
  riskTier: DesignRiskTier.high,
  reviewScopeJson: _reviewScope,
  createdAt: DateTime.utc(2025, 12, 1),
  updatedAt: DateTime.utc(2025, 12, 1),
  approvedAt: status == DesignRevisionStatus.approved
      ? DateTime.utc(2025, 12, 2)
      : null,
  version: 1,
);

Job _extraDesignJob({
  String jobId = 'job-design-2',
  JobState state = JobState.queued,
}) => Job(
  jobId: jobId,
  workItemId: _workItemId,
  jobType: JobType.designRevision,
  requiredRole: AgentRole.designAgent,
  requiredCapabilities: const {
    WorkerCapability.penpotWrite,
    WorkerCapability.visualDesign,
  },
  priority: JobPriority.normal,
  state: state,
  dedupeKey: '$_workItemId:${JobType.designRevision.wire}',
  createdAt: DateTime.utc(2026, 1, 1),
  instruction: 'Produce a second design revision',
  attempt: 0,
  maxAttempts: 3,
  version: 1,
);

HumanDecision _decision({
  String decisionId = 'dec-1',
  HumanDecisionType type = HumanDecisionType.designApproval,
  HumanDecisionStatus status = HumanDecisionStatus.pending,
}) => HumanDecision(
  decisionId: decisionId,
  workItemId: _workItemId,
  decisionType: type,
  status: status,
  question: 'Approve the design?',
  blocking: true,
  requestedAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Defect _defect({
  String defectId = 'def-1',
  DefectClassification classification = DefectClassification.designDefect,
}) => Defect(
  defectId: defectId,
  title: 'Visual defect',
  description: 'The login screen diverges from the approved revision',
  severity: 'high',
  status: DefectStatus.confirmed,
  classification: classification,
  reporter: 'qa',
  productId: _productId,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  version: 1,
);

void main() {
  group('happy path', () {
    test(
      'writes the revision, submits the contract, advances the item',
      () async {
        final host = await _host();

        final result = await _run(host);

        expect(result.outcome, DesignRevisionProducerOutcome.produced);
        expect(result.revision, isNotNull);
        final revisionId = result.revision!.revisionId;

        final stored = await host.governanceStore.readDesignRevision(
          revisionId,
        );
        expect(stored.workItemId, _workItemId);
        expect(stored.productId, _productId);
        expect(stored.designerExecutionId, _executionId);
        expect(stored.status, DesignRevisionStatus.draft);
        expect(stored.riskTier, DesignRiskTier.high);
        expect(stored.designSystemRevision, 'dsr-1');
        expect(stored.penpotFileId, 'pf-1');
        expect(stored.penpotPageId, 'pp-1');
        expect(
          jsonDecode(stored.boardIdsJson),
          jsonDecode(jsonEncode(_boardIds)),
        );

        final contract = await host.contractStore.readDesignContract(
          _contractId,
        );
        expect(contract, isNotNull);
        expect(contract!.status, DesignContractStatus.underReview);

        final item = await host.workflowStore.readWorkItem(_workItemId);
        expect(item.state, WorkItemState.designInReview);
        expect(item.metadata?[designRevisionIdMetadataKey], revisionId);
        expect(
          item.metadata?[designerExecutionIdMetadataKey],
          _executionId,
        );

        // This is the transition `agentCompleted -> designInReview` the
        // under-review guard would have refused before the submission above.
        final history = await host.workflowStore.readTransitionHistory(
          _workItemId,
        );
        expect(
          history.any(
            (record) =>
                record.fromState == WorkItemState.agentCompleted &&
                record.toState == WorkItemState.designInReview &&
                record.outcome == TransitionOutcome.accepted,
          ),
          isTrue,
        );
      },
    );

    test(
      'a replay returns alreadyProduced and mints no second revision',
      () async {
        final host = await _host();

        final first = await _run(host);
        final second = await _run(host);

        expect(first.outcome, DesignRevisionProducerOutcome.produced);
        expect(second.outcome, DesignRevisionProducerOutcome.alreadyProduced);
        expect(second.revision!.revisionId, first.revision!.revisionId);
        expect(
          await host.governanceStore.readDesignRevisionsForWorkItem(
            _workItemId,
          ),
          hasLength(1),
        );
      },
    );

    test('riskTier is forced high and designerExecutionId comes from the '
        'execution, never the payload', () async {
      final payload = _validPayload()
        ..['riskTier'] = 'low'
        ..['status'] = 'approved'
        ..['designerExecutionId'] = 'agx-someone-else';
      final host = await _host(payload: payload);

      final result = await _run(host);

      expect(result.outcome, DesignRevisionProducerOutcome.produced);
      final stored = result.revision!;
      expect(stored.riskTier, DesignRiskTier.high);
      expect(stored.status, DesignRevisionStatus.draft);
      expect(stored.designerExecutionId, _executionId);
    });

    test('accepts arrays and reviewScope as JSON-encoded strings', () async {
      final payload = _validPayload()
        ..['boardIds'] = jsonEncode(_boardIds)
        ..['responsiveTargets'] = jsonEncode(_responsiveTargets)
        ..['statesRepresented'] = jsonEncode(_statesRepresented)
        ..['artifactRefs'] = '[]'
        ..['reviewExecutionIds'] = jsonEncode([_reviewerId])
        ..['reviewScope'] = jsonEncode(_reviewScope);
      final host = await _host(payload: payload);

      final result = await _run(host);

      expect(result.outcome, DesignRevisionProducerOutcome.produced);
    });

    test(
      'a contract already underReview is idempotent (no second write)',
      () async {
        final host = await _host(
          contractStatus: DesignContractStatus.underReview,
        );

        final result = await _run(host);

        expect(result.outcome, DesignRevisionProducerOutcome.produced);
        expect(host.contractStore.contracts, hasLength(1));
        expect(
          host.contractStore.contracts.single.updatedAt,
          DateTime.utc(2026, 1, 1),
        );
      },
    );

    test('a resolved designApproval does not block the producer', () async {
      final host = await _host(
        decisions: [
          _decision(status: HumanDecisionStatus.resolved),
        ],
      );

      final result = await _run(host);

      expect(result.outcome, DesignRevisionProducerOutcome.produced);
    });

    test(
      'a correction whose parent is the approved revision succeeds',
      () async {
        final host = await _host(
          payload: _validPayload()..['parentRevisionId'] = 'rev-approved',
        );
        await host.governanceStore.saveDesignRevision(
          _storedRevision(
            revisionId: 'rev-approved',
            status: DesignRevisionStatus.approved,
          ),
        );

        final result = await _run(host);

        expect(result.outcome, DesignRevisionProducerOutcome.produced);
        expect(result.revision!.parentRevisionId, 'rev-approved');
      },
    );
  });

  group('P1', () {
    test('refuses an item not at agentCompleted', () async {
      final host = await _host(itemState: WorkItemState.designRequired);

      final result = await _run(host);

      expect(result.refusalCode, 'p1.work-item-not-at-agent-completed');
    });

    test('refuses an item whose durable designContractId is null', () async {
      final host = await _host(contractColumnSet: false);

      final result = await _run(host);

      expect(result.refusalCode, 'p1.design-contract-id-missing');
    });

    test('refuses a designContractId that resolves to no row', () async {
      final host = await _host(contractExists: false);

      final result = await _run(host);

      expect(result.refusalCode, 'p1.design-contract-unresolved');
    });
  });

  group('P2', () {
    test('refuses an empty designSystemRevision', () async {
      final host = await _host(
        payload: _validPayload()..['designSystemRevision'] = '',
      );

      final result = await _run(host);

      expect(result.refusalCode, 'p2.design-system-revision-missing');
    });
  });

  group('P3', () {
    test('refuses a parentRevisionId that does not resolve', () async {
      final host = await _host(
        payload: _validPayload()..['parentRevisionId'] = 'rev-missing',
      );

      final result = await _run(host);

      expect(result.refusalCode, 'p3.parent-revision-not-found');
    });

    test(
      'refuses a parent that exists but is not the approved revision',
      () async {
        final host = await _host(
          payload: _validPayload()..['parentRevisionId'] = 'rev-draft',
        );
        await host.governanceStore.saveDesignRevision(
          _storedRevision(revisionId: 'rev-draft'),
        );

        final result = await _run(host);

        expect(result.refusalCode, 'p3.parent-revision-not-current-approved');
      },
    );
  });

  group('P4', () {
    Future<_Host> remediationHost({
      Map<String, Defect> defects = const {},
      String? featureRef = 'def-1',
    }) => _host(
      featureRef: featureRef,
      itemMetadata: const {
        'designRemediationRequired': true,
        'defectId': 'def-1',
      },
      defects: defects,
    );

    test('refuses a defect that is not classified designDefect', () async {
      final host = await remediationHost(
        defects: {
          'def-1': _defect(
            classification: DefectClassification.implementationDefect,
          ),
        },
      );

      final result = await _run(host);

      expect(result.refusalCode, 'p4.defect-not-design-defect');
    });

    test('refuses a defect that no longer resolves', () async {
      final host = await remediationHost();

      final result = await _run(host);

      expect(result.refusalCode, 'p4.defect-unresolved');
    });

    test('refuses featureRef and metadata[defectId] that disagree', () async {
      final host = await remediationHost(
        featureRef: 'def-other',
        defects: {'def-1': _defect()},
      );

      final result = await _run(host);

      expect(result.refusalCode, 'p4.feature-ref-defect-id-disagreement');
    });

    test('accepts a live designDefect remediation item', () async {
      final host = await remediationHost(
        defects: {'def-1': _defect()},
      );

      final result = await _run(host);

      expect(result.outcome, DesignRevisionProducerOutcome.produced);
    });
  });

  group('P5', () {
    test('refuses when another live designRevision job exists', () async {
      final host = await _host(extraJobs: [_extraDesignJob()]);

      final result = await _run(host);

      expect(result.refusalCode, 'p5.live-design-revision-job');
    });
  });

  group('P6', () {
    test('refuses an unresolved designApproval', () async {
      final host = await _host(decisions: [_decision()]);

      final result = await _run(host);

      expect(result.refusalCode, 'p6.unresolved-design-decision');
    });

    test('refuses an unresolved designReviewRequest', () async {
      final host = await _host(
        decisions: [
          _decision(type: HumanDecisionType.designReviewRequest),
        ],
      );

      final result = await _run(host);

      expect(result.refusalCode, 'p6.unresolved-design-decision');
    });
  });

  group('Q1 / Q2', () {
    test('refuses a silent no-op revision write', () async {
      final host = await _host(vanishRevisionWrites: true);

      final result = await _run(host);

      expect(result.refusalCode, 'q1.revision-not-readable-after-write');
    });

    test('refuses an execution that belongs to another work item', () async {
      final host = await _host();
      await host.executionStore.saveExecution(
        host.execution.copyWith(workItemId: 'wi-other'),
      );

      final result = await _run(host);

      expect(result.refusalCode, 'q2.execution-work-item-mismatch');
    });
  });

  group('Q5 / Q6', () {
    test('refuses a penpot contract with no penpotFileId', () async {
      final host = await _host(
        payload: _validPayload()..remove('penpotFileId'),
      );

      final result = await _run(host);

      expect(result.refusalCode, 'q5.penpot-file-id-missing');
    });

    test('refuses a penpot contract with no penpotPageId', () async {
      final host = await _host(
        payload: _validPayload()..['penpotPageId'] = null,
      );

      final result = await _run(host);

      expect(result.refusalCode, 'q5.penpot-page-id-missing');
    });

    test('refuses a child that changes the design-system revision', () async {
      final host = await _host(
        payload: _validPayload()
          ..['parentRevisionId'] = 'rev-approved'
          ..['designSystemRevision'] = 'dsr-2',
      );
      await host.governanceStore.saveDesignRevision(
        _storedRevision(
          revisionId: 'rev-approved',
          status: DesignRevisionStatus.approved,
        ),
      );

      final result = await _run(host);

      expect(result.refusalCode, 'q6.design-system-revision-changed');
    });
  });

  group('Q7 — the fidelity anchor refuses at write time', () {
    test('an empty boardSet is refused, nothing is stored, and the contract '
        'is NOT submitted', () async {
      final host = await _host(
        payload: _validPayload()..['boardIds'] = <dynamic>[],
      );

      final result = await _run(host);

      expect(result.refusalCode, 'q7.fidelity-anchor-invalid');
      expect(result.detail, contains('tooFewItems'));

      expect(
        await host.governanceStore.readDesignRevisionsForWorkItem(_workItemId),
        isEmpty,
      );
      final contract = await host.contractStore.readDesignContract(_contractId);
      expect(contract!.status, DesignContractStatus.draft);

      final item = await host.workflowStore.readWorkItem(_workItemId);
      expect(item.state, WorkItemState.agentCompleted);
      expect(item.metadata?[designRevisionIdMetadataKey], isNull);
      expect(item.metadata?[designerExecutionIdMetadataKey], isNull);
    });

    test(
      'a reviewExecutionIds list containing the designer is refused',
      () async {
        final host = await _host(
          payload: _validPayload()..['reviewExecutionIds'] = [_executionId],
        );

        final result = await _run(host);

        expect(result.refusalCode, 'q7.fidelity-anchor-invalid');
        expect(result.detail, contains('designerIsItsOwnReviewer'));
      },
    );
  });

  group('payload', () {
    test('an empty structuredResult is a named refusal', () async {
      final host = await _host(payload: const {});

      final result = await _run(host);

      expect(result.refusalCode, 'payload.missing');
    });

    test('a missing required key is a named refusal', () async {
      final host = await _host(payload: _validPayload()..remove('provider'));

      final result = await _run(host);

      expect(result.refusalCode, 'payload.missing');
      expect(result.detail, contains('provider'));
    });

    test('a malformed JSON array is a named refusal', () async {
      final host = await _host(
        payload: _validPayload()..['boardIds'] = 'not-json',
      );

      final result = await _run(host);

      expect(result.refusalCode, 'payload.malformed');
      expect(result.detail, contains('boardIds'));
    });

    test('an unknown provider is a named refusal', () async {
      final host = await _host(
        payload: _validPayload()..['provider'] = 'figma',
      );

      final result = await _run(host);

      expect(result.refusalCode, 'payload.malformed');
    });
  });

  group('job/execution gates', () {
    test('a non-design job is notApplicable', () async {
      final host = await _host();

      final result = await host.producer.processCompletedDesignRevisionJob(
        host.job.copyWith(jobType: JobType.engineeringReview),
      );

      expect(result.outcome, DesignRevisionProducerOutcome.notApplicable);
    });

    test('a non-terminal job is refused', () async {
      final host = await _host();

      final result = await host.producer.processCompletedDesignRevisionJob(
        host.job.copyWith(state: JobState.running),
      );

      expect(result.refusalCode, 'job.not-terminal');
    });

    test(
      'a failed execution is refused even though the result is durable',
      () async {
        final host = await _host(
          executionStatus: AgentSessionStatus.failed,
        );

        final result = await _run(host);

        expect(result.refusalCode, 'execution.not-completed');
      },
    );

    test('a failed result on a completed execution is refused', () async {
      final host = await _host(resultStatus: AgentResultStatus.failed);

      final result = await _run(host);

      expect(result.refusalCode, 'result.not-completed');
    });
  });
}

class _FakeDefectStore implements DefectStore {
  _FakeDefectStore([this.defects = const <String, Defect>{}]);

  final Map<String, Defect> defects;

  @override
  Future<Defect> readDefect(String defectId) async {
    final defect = defects[defectId];
    if (defect == null) throw DefectNotFoundException(defectId);
    return defect;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

/// A revision store whose write silently does nothing. Q1 exists precisely
/// because that is indistinguishable from success without the read-back.
class _VanishingDesignRevisionStore implements DesignRevisionStore {
  _VanishingDesignRevisionStore(this._delegate);

  final DesignRevisionStore _delegate;

  @override
  Future<void> saveDesignRevision(
    DesignRevision revision, {
    int? expectedVersion,
  }) async {}

  @override
  Future<DesignRevision> readDesignRevision(String revisionId) =>
      _delegate.readDesignRevision(revisionId);

  @override
  Future<List<DesignRevision>> readDesignRevisionsForWorkItem(
    String workItemId,
  ) => _delegate.readDesignRevisionsForWorkItem(workItemId);

  @override
  Future<DesignRevision?> readApprovedDesignRevisionForWorkItem(
    String workItemId,
  ) => _delegate.readApprovedDesignRevisionForWorkItem(workItemId);

  @override
  Future<DesignRevision?> readLatestDesignRevisionForWorkItem(
    String workItemId,
  ) => _delegate.readLatestDesignRevisionForWorkItem(workItemId);

  @override
  Future<List<DesignRevision>> getLineage(String revisionId) =>
      _delegate.getLineage(revisionId);

  @override
  Future<DesignRevision?> findDesignRevisionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _delegate.findDesignRevisionByIdempotencyKey(
    workItemId,
    idempotencyKey,
  );

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(DesignGovernanceStore store) body,
  ) => _delegate.inTransaction(body);
}

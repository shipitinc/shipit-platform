/// Proves the stranded-work-item repair is real, generic and idempotent.
///
/// The subject is the one-shot repair script in `bin/`. It is imported here
/// rather than duplicated, because a copy is a second implementation that can
/// pass while the script the Manager actually runs fails.
///
/// ## WHY A SYNTHETIC ID IS THE POINT, NOT A DETAIL
///
/// A live work item is stranded in QA today. Every id in this file is
/// deliberately a DIFFERENT synthetic one, and
/// [works for ANY stranded feature work item, not one id] proves the repair
/// works for ids it has never seen. A test written against the live id would
/// pass against a script that special-cased it — which is the exact defect this
/// correction refused. The live ids are deliberately absent from this file
/// entirely, so that no assertion here can be satisfied by naming one.
library;

import 'package:control_plane_server/src/triage/lane_e_design_remediation_work_item.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import '../bin/repair_stranded_work_items.dart';

/// The product under test declares exactly one gate, so a contract that is
/// written for the wrong reason (a triage contract stamped onto a feature item)
/// would be distinguishable by its gates, not only by its existence.
const String kProduct = 'shipit-platform-under-repair';

/// A product that has declared NOTHING — the refusal path, which must not
/// invent a contract id.
const String kUndeclaredProduct = 'product-that-declared-nothing';

/// Deliberately NOT any live work item id — see the library comment.
const String kSyntheticFeatureItem = 'WI-feature-1789000000000001';

/// A second synthetic id, so "works for any stranded feature item" is a claim
/// about the code rather than about one string.
const String kOtherSyntheticFeatureItem = 'WI-feature-1789000000000002';

const String kSyntheticDefectId = 'DEF-1789000000000100';

final DateTime kNow = DateTime.utc(2026, 10, 17, 11, 45, 0);

void main() {
  group('stranded work item repair', () {
    test(
      'attaches a REAL QA contract to a stranded feature work item, from the '
      "product's declared spec",
      () async {
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);

        final outcome = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );

        expect(outcome.qaContractAction, startsWith('attached:'));

        final item = await host.workflowStore.readWorkItem(
          kSyntheticFeatureItem,
        );
        expect(item.qaContractId, isNotNull);

        // The stamped id is the one the PRODUCT's provisioner addressed, derived
        // from the work item id — not a string this test or the script chose.
        expect(
          item.qaContractId,
          productQAContractIdForWorkItem(kSyntheticFeatureItem),
        );

        // And it is a real, readable, separately-owned row: the work item's
        // guard only null-checks, so a fabricated id would satisfy it and
        // satisfy nothing else.
        final contract = await host.contracts.readQAContract(
          item.qaContractId!,
        );
        expect(contract, isNotNull, reason: 'the contract row must exist');
        expect(contract!.contractId, item.qaContractId);
        expect(
          contract.metadata?[qaContractWorkItemIdMetadataKey],
          kSyntheticFeatureItem,
        );
        expect(contract.workItemCategory, WorkItemCategory.feature);

        // The gates are the PRODUCT's declared gates, verbatim.
        final declared = await host.specStore.readQAContractSpec(kProduct);
        expect(
          contract.gates.map((g) => g.gateId).toList(),
          declared!.gates.map((g) => g.gateId).toList(),
        );
      },
    );

    test(
      'works for ANY stranded feature work item, not one id',
      () async {
        // Two ids, one repair, one code path. If anything in the repair were
        // shaped to a particular id, this is where it shows.
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);
        await host.strandFeature(kOtherSyntheticFeatureItem);

        for (final id in [kSyntheticFeatureItem, kOtherSyntheticFeatureItem]) {
          await host.repair.repairWorkItem(id);
          final item = await host.workflowStore.readWorkItem(id);
          expect(item.qaContractId, productQAContractIdForWorkItem(id));
          expect(
            await host.contracts.readQAContract(item.qaContractId!),
            isNotNull,
            reason: '$id must be governed by a real contract row',
          );
        }
      },
    );

    test('is idempotent: a second run writes nothing at all', () async {
      final host = _Host();
      await host.strandFeature(kSyntheticFeatureItem);

      await host.repair.repairWorkItem(kSyntheticFeatureItem);

      final afterFirst = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );
      final writesAfterFirst = host.contracts.writeCounts.values.fold<int>(
        0,
        (a, b) => a + b,
      );
      final transitionsAfterFirst = await host.workflowStore
          .readTransitionHistory(kSyntheticFeatureItem);
      final actionsAfterFirst = await host.workflowStore
          .readOperatorActionsForWorkItem(kSyntheticFeatureItem);

      final second = await host.repair.repairWorkItem(kSyntheticFeatureItem);

      final afterSecond = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );

      // No version bump means no CAS write happened.
      expect(afterSecond.version, afterFirst.version);
      expect(afterSecond.state, afterFirst.state);
      expect(afterSecond.qaContractId, afterFirst.qaContractId);
      expect(
        host.contracts.writeCounts.values.fold<int>(0, (a, b) => a + b),
        writesAfterFirst,
        reason: 'the second run must not re-write the contract row',
      );
      expect(
        await host.workflowStore.readTransitionHistory(kSyntheticFeatureItem),
        transitionsAfterFirst,
        reason: 'the second run must not record another transition',
      );
      expect(
        await host.workflowStore.readOperatorActionsForWorkItem(
          kSyntheticFeatureItem,
        ),
        actionsAfterFirst,
        reason: 'the second run must not record another operator action',
      );
      expect(second.wroteAnything, isFalse);
      expect(second.qaContractAction, startsWith('already-present'));
    });

    test(
      'records the DURABLE permanent failure, then operatorRetry re-dispatches',
      () async {
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);
        await host.failJobPermanently(kSyntheticFeatureItem);

        final outcome = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );

        expect(outcome.retried, isTrue);
        expect(outcome.stateBefore, WorkItemState.agentExecuting.wire);
        expect(outcome.stateAfter, WorkItemState.designNotRequired.wire);

        // AC-4: the transition row exists, and its PERSISTED reason names the
        // real failure kind read off the job row rather than a literal.
        final history = await host.workflowStore.readTransitionHistory(
          kSyntheticFeatureItem,
        );
        final failureRow = history.firstWhere(
          (r) =>
              r.fromState == WorkItemState.agentExecuting &&
              r.toState == WorkItemState.agentFailed,
        );
        expect(failureRow.reason, contains('JobFailureKind.permanent'));
        expect(failureRow.reason, contains(host.permanentJobId));
        expect(failureRow.reason, contains('platform verification failed'));

        // And the retry is the sanctioned operator verb, with an audit row.
        final actions = await host.workflowStore.readOperatorActionsForWorkItem(
          kSyntheticFeatureItem,
        );
        expect(actions, hasLength(1));
        expect(actions.single.action, 'retry');
        expect(actions.single.requestedBy, repairRequestedBy);

        // Re-dispatch is the ordinary scheduler tick, because the state the
        // retry lands on is a real entry state of the triage job definition.
        expect(outcome.stateAfter, WorkItemState.designNotRequired.wire);
        expect(
          triageDefectDefinition.entryStates.contains(
            WorkItemState.designNotRequired,
          ),
          isTrue,
          reason:
              'operatorRetry only re-dispatches if the scheduler can pick '
              'the item up; this asserts the assumption rather than trusting it',
        );

        // The contract survives the two transitions.
        final item = await host.workflowStore.readWorkItem(
          kSyntheticFeatureItem,
        );
        expect(item.qaContractId, isNotNull);
      },
    );

    test(
      'REFUSES to record a failure it cannot source, rather than inventing one',
      () async {
        // Truthfulness: no terminal failed job exists for this item, so there is
        // no durable record of anything having stopped. A reason written here
        // would be fiction on a transition row.
        final host = _Host();
        await host.strandFeature(kSyntheticFeatureItem);

        final outcome = await host.repair.repairWorkItem(
          kSyntheticFeatureItem,
        );

        expect(outcome.retried, isFalse);
        expect(outcome.stateAfter, WorkItemState.agentExecuting.wire);
        expect(
          outcome.notes.join(' '),
          contains('REFUSED'),
          reason: 'the refusal must be reported, not silent',
        );
        final history = await host.workflowStore.readTransitionHistory(
          kSyntheticFeatureItem,
        );
        expect(
          history.where((r) => r.toState == WorkItemState.agentFailed),
          isEmpty,
        );
      },
    );

    test('a declared-nothing product is refused BY NAME, not faked', () async {
      final host = _Host();
      await host.strandFeature(
        kSyntheticFeatureItem,
        productId: kUndeclaredProduct,
      );

      final outcome = await host.repair.repairWorkItem(
        kSyntheticFeatureItem,
      );

      expect(outcome.qaContractAction, 'refused:notDeclared');
      expect(outcome.qaContractId, isNull);
      final item = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );
      expect(item.qaContractId, isNull, reason: 'no contract may be invented');
      expect(host.contracts.rowCount, 0);
    });

    test('--dry-run reports intended changes and writes NOTHING', () async {
      final host = _Host(dryRun: true);
      await host.strandFeature(kSyntheticFeatureItem);
      await host.failJobPermanently(kSyntheticFeatureItem);

      final outcome = await host.repair.repairWorkItem(
        kSyntheticFeatureItem,
      );

      // It reports what it WOULD do, naming the exact contract id.
      expect(outcome.qaContractAction, startsWith('would-attach:'));
      expect(
        outcome.qaContractAction,
        contains(productQAContractIdForWorkItem(kSyntheticFeatureItem)),
      );
      expect(outcome.failureReason, contains('JobFailureKind.permanent'));
      expect(outcome.notes.join(' '), contains('would record'));

      // And nothing was written: no contract row, no column, no transition, no
      // operator action.
      expect(host.contracts.rowCount, 0);
      final item = await host.workflowStore.readWorkItem(
        kSyntheticFeatureItem,
      );
      expect(item.qaContractId, isNull);
      expect(item.state, WorkItemState.agentExecuting);
      expect(item.version, 1);
      expect(
        await host.workflowStore.readTransitionHistory(kSyntheticFeatureItem),
        isEmpty,
      );
      expect(
        await host.workflowStore.readOperatorActionsForWorkItem(
          kSyntheticFeatureItem,
        ),
        isEmpty,
      );
    });
  });

  group('design remediation is repaired through lane E\'s own provisioner', () {
    test(
      'drives DesignRemediationWorkItemProvisioner and recovers the item',
      () async {
        final host = _Host();
        final workItemId = designRemediationWorkItemId(kSyntheticDefectId);
        await host.strandFeature(workItemId);
        await host.seedDesignDefect(kSyntheticDefectId);
        await host.failJobPermanently(workItemId);

        final outcome = await host.repair.repairDesignRemediation(
          kSyntheticDefectId,
        );

        // The contract was attached by lane E's replay branch, not by the
        // script's own attach — the action name says which.
        expect(outcome.qaContractAction, startsWith('via-laneE:attached:'));

        final item = await host.workflowStore.readWorkItem(workItemId);
        expect(item.qaContractId, productQAContractIdForWorkItem(workItemId));
        expect(
          await host.contracts.readQAContract(item.qaContractId!),
          isNotNull,
        );

        // Lane E's `_advanceToPlanned` only acts on `draft`, so the stranded
        // item must NOT have been walked backwards.
        expect(outcome.stateAfter, WorkItemState.designNotRequired.wire);

        final history = await host.workflowStore.readTransitionHistory(
          workItemId,
        );
        expect(
          history.any(
            (r) =>
                r.fromState == WorkItemState.agentExecuting &&
                r.toState == WorkItemState.agentFailed,
          ),
          isTrue,
        );
      },
    );

    test('is idempotent for lane E too', () async {
      final host = _Host();
      final workItemId = designRemediationWorkItemId(kSyntheticDefectId);
      await host.strandFeature(workItemId);
      await host.seedDesignDefect(kSyntheticDefectId);
      await host.failJobPermanently(workItemId);

      await host.repair.repairDesignRemediation(kSyntheticDefectId);
      final afterFirst = await host.workflowStore.readWorkItem(workItemId);
      final writesAfterFirst = host.contracts.writeCounts.values.fold<int>(
        0,
        (a, b) => a + b,
      );

      final second = await host.repair.repairDesignRemediation(
        kSyntheticDefectId,
      );

      final afterSecond = await host.workflowStore.readWorkItem(workItemId);
      expect(afterSecond.version, afterFirst.version);
      expect(afterSecond.state, afterFirst.state);
      expect(
        host.contracts.writeCounts.values.fold<int>(0, (a, b) => a + b),
        writesAfterFirst,
      );
      expect(second.wroteAnything, isFalse);
    });
  });
}

/// Everything the repair needs, wired the way `main` wires it, plus the seams
/// a test needs to set up a stranded row.
class _Host {
  _Host({bool dryRun = false, Set<String> declared = const {kProduct}})
    : workflowStore = InMemoryWorkflowStore(),
      contracts = _CountingQAContractStore(),
      jobStore = InMemoryJobStore() {
    for (final productId in declared) {
      specStore._rows[productId] = _declaration(productId);
    }
    repair = StrandedWorkItemRepair(
      workflowStore: workflowStore,
      workflowEngine: DurableWorkflowEngine(
        store: workflowStore,
        policy: const WorkflowEngine(),
      ),
      qaContractProvisioner: ProductQAContractProvisioner(
        contractStore: contracts,
        specStore: specStore,
      ),
      jobStore: jobStore,
      defectStore: _hostDefectStore,
      dryRun: dryRun,
      // Silent, so a passing test's output stays readable; the repair's
      // reporting is asserted through `StrandedWorkItemOutcome`.
      log: (_, _) {},
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final _CountingQAContractStore contracts;
  final _SpecStore specStore = _SpecStore();
  final InMemoryJobStore jobStore;
  late final StrandedWorkItemRepair repair;

  String? permanentJobId;

  /// Writes a row in exactly the shape the live database has: `agentExecuting`,
  /// `qaContractId` NULL. The repair's work starts from there, so the setup
  /// only has to be faithful at the START; every transition after it is real
  /// graph travel through [DurableWorkflowEngine].
  Future<void> strandFeature(
    String workItemId, {
    String productId = kProduct,
  }) async {
    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: productId,
        category: WorkItemCategory.feature,
        title: 'Stranded feature request',
        description:
            'A feature request that was dispatched without a QA '
            'contract and refused at completion.',
        state: WorkItemState.agentExecuting,
        featureRef: workItemId,
        createdAt: kNow,
        updatedAt: kNow,
      ),
    );
  }

  /// The durable failure the repair must READ rather than compose: one terminal
  /// job carrying a `permanent` [JobFailure] with a real reason.
  Future<void> failJobPermanently(
    String workItemId, {
    String reason = 'platform verification failed',
  }) async {
    permanentJobId = 'job-permanent-1';
    await jobStore.saveJob(
      Job(
        jobId: permanentJobId!,
        workItemId: workItemId,
        jobType: JobType.triageDefect,
        requiredRole: AgentRole.triageDefect,
        requiredCapabilities: const {},
        priority: JobPriority.normal,
        state: JobState.failed,
        dedupeKey: '$workItemId:triage',
        createdAt: kNow,
        completedAt: kNow.add(const Duration(minutes: 3)),
        instruction: 'Triage the defect.',
        attempt: 1,
        maxAttempts: 3,
        version: 1,
        failure: JobFailure(
          code: JobFailureCode.executionFailed,
          kind: JobFailureKind.permanent,
          reason: reason,
        ),
      ),
    );
  }

  /// A defect plus the settled triage result lane E replays from. The defect
  /// names the remediation item as the affected work item, which is how its
  /// product resolves — `affectedWorkItemId -> work_item.productId`.
  Future<void> seedDesignDefect(String defectId) async {
    final remediationId = designRemediationWorkItemId(defectId);
    _hostDefectStore.defects[defectId] = Defect(
      defectId: defectId,
      title: 'Report layout clips the action row',
      description: 'The action row is cut off at narrow widths.',
      severity: 'medium',
      status: DefectStatus.remediationPlanned,
      classification: DefectClassification.designDefect,
      reporter: 'someone@example.test',
      affectedWorkItemId: remediationId,
      createdAt: kNow,
      updatedAt: kNow,
      version: 1,
    );
    _hostDefectStore.results[defectId] = [
      TriageResult(
        resultId: 'tr-$defectId-1',
        defectId: defectId,
        summary: 'Layout defect in the report action row.',
        recommendedStatus: DefectStatus.remediationPlanned,
        recommendedClassification: DefectClassification.designDefect,
        recommendedNextAction: 'Open design remediation for the report layout.',
        confidence: 0.82,
        suspectedCategory: 'ui-layout',
        suspectedComponents: const ['ReportScreen'],
        reproductionSupported: true,
        evidenceUsed: const ['EVD-1'],
        clarificationRequired: const [],
        createdAt: kNow,
        version: 1,
      ),
    ];
  }

  /// The single [DefectStore] the repair is wired to. Seeded through
  /// [_Host.seedDesignDefect].
  final _FakeDefectStore _hostDefectStore = _FakeDefectStore();
}

/// A [DefectStore] with only the two reads on the repair path implemented.
///
/// The rest throw rather than returning a plausible empty answer, so a future
/// addition to the repair that reaches for another method fails loudly instead
/// of quietly classifying nothing.
class _FakeDefectStore implements DefectStore {
  final Map<String, Defect> defects = {};
  final Map<String, List<TriageResult>> results = {};

  @override
  Future<Defect> readDefect(String defectId) async {
    final defect = defects[defectId];
    if (defect == null) throw StateError('no defect $defectId');
    return defect;
  }

  @override
  Future<List<TriageResult>> readTriageResultsForDefect(
    String defectId,
  ) async => results[defectId] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'DefectStore.${invocation.memberName} is not on the repair path',
  );
}

/// A [ProductQAContractSpecStore] over a plain map, holding ONLY the products a
/// test declared — so "this product declared nothing" is genuinely absent
/// rather than an empty-but-present declaration.
class _SpecStore implements ProductQAContractSpecStore {
  final Map<String, ProductQAContractDeclaration> _rows = {};

  @override
  Future<void> saveQAContractSpec(
    ProductQAContractDeclaration declaration,
  ) async {
    _rows[declaration.productId] = declaration;
  }

  @override
  Future<ProductQAContractDeclaration?> readQAContractSpec(
    String productId,
  ) async => _rows[productId];
}

ProductQAContractDeclaration _declaration(String productId) =>
    ProductQAContractDeclaration(
      productId: productId,
      gates: const [
        QAGateSpec(
          gateId: 'intake-structured-result-admitted',
          type: 'triage-classification-structure',
          required: true,
          config: {
            'sourceColumn': 'agent_result.structuredResultJson',
            'requiredFields': [
              'classification',
              'status',
              'confidence',
              'suspectedCategory',
            ],
          },
        ),
      ],
      manifestVersion: '1.0.0',
      createdAt: kNow,
      updatedAt: kNow,
    );

/// A [QAContractStore] keyed the way PostgreSQL is — a second write REPLACES a
/// row — and it COUNTS writes, because "the second run wrote nothing" is an
/// assertion about this counter and nothing else can establish it.
class _CountingQAContractStore implements QAContractStore {
  final Map<String, QAContract> _rows = <String, QAContract>{};
  final Map<String, int> writeCounts = <String, int>{};

  int get rowCount => _rows.length;

  @override
  Future<void> saveQAContract(QAContract contract) async {
    writeCounts.update(contract.contractId, (c) => c + 1, ifAbsent: () => 1);
    _rows[contract.contractId] = contract;
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    await saveQAContract(contract);
    final stored = await readQAContract(contract.contractId);
    if (stored == null) throw StateError('unreadable after write');
    return stored;
  }

  @override
  Future<QAContract?> readQAContract(String contractId) async =>
      _rows[contractId];

  @override
  Future<bool> hasQAContract(String contractId) async =>
      _rows.containsKey(contractId);

  @override
  Future<List<QAContract>> listQAContractsForWorkItem(
    String workItemId,
  ) async => _rows.values
      .where((c) => c.metadata?[qaContractWorkItemIdMetadataKey] == workItemId)
      .toList();

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async => _rows.values.where((c) => c.workItemCategory == category).toList();
}

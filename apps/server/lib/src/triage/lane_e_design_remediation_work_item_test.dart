import 'package:control_plane_server/src/triage/lane_a_defect_triage_work_item.dart'
    show defectTriageBucketProductId, defectTriageWorkItemId;
import 'package:control_plane_server/src/triage/lane_e_design_remediation_work_item.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:workflow_engine/workflow_engine.dart' show WorkflowEngine;
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// Products that are obviously not each other, so no assertion can pass because
/// two subjects shared a name.
const String kProduct = 'product-that-declares';
const String kUndeclaredProduct = 'product-that-declared-nothing';

/// The product an ALREADY-PERSISTED remediation row records in this file.
///
/// Distinct from [kProduct], from [kUndeclaredProduct] and from the `defects`
/// bucket, because every assertion below about "which product governed the
/// gate" is worthless if two of them can share a name.
const String kRowProduct = 'product-the-existing-row-records';

/// A `productId` the database would accept — `work_item."productId"` is `text
/// NOT NULL`, so whitespace passes the NOT NULL check — and that no product row
/// and no `product_qa_contract_spec` row can ever match.
const String kBlankProductId = '   ';

/// ONE defect, so the two lanes below genuinely contend for it:
/// `design-remediation-DEF-1` and `defect-DEF-1` are the same defect, and
/// `saveQAContract` is `ON CONFLICT ("contractId") DO UPDATE` in production.
/// That is the collision a defect-scoped contract id would have caused.
const String kDefectId = 'DEF-1';

final DateTime kNow = DateTime.utc(2026, 10, 17, 9, 30, 0);

/// A [QAContractStore] keyed the way PostgreSQL is, so a second write REPLACES
/// a row rather than appending. Without this the collision assertion would pass
/// on a store that cannot exhibit the defect it exists to catch.
class _OverwritingQAContractStore implements QAContractStore {
  final Map<String, QAContract> _rows = <String, QAContract>{};
  final Map<String, int> writeCounts = <String, int>{};
  final List<String> writeOrder = <String>[];

  int get rowCount => _rows.length;

  @override
  Future<void> saveQAContract(QAContract contract) async {
    writeCounts.update(contract.contractId, (c) => c + 1, ifAbsent: () => 1);
    writeOrder.add(contract.contractId);
    _rows[contract.contractId] = contract;
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    await saveQAContract(contract);
    final stored = await readQAContract(contract.contractId);
    if (stored == null) throw StateError('unreadable');
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

class _SpecStore implements ProductQAContractSpecStore {
  _SpecStore(this._rows);

  final Map<String, ProductQAContractDeclaration> _rows;

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
          gateId: 'human-declared-gate',
          type: 'declared-by-the-product',
          required: true,
          config: {'declaredBy': 'an operator'},
        ),
      ],
      manifestVersion: 'v1',
      createdAt: kNow,
      updatedAt: kNow,
    );

/// Everything one [DesignRemediationWorkItemProvisioner] needs, plus the
/// provisioner, so a test reads as a scenario rather than as wiring.
class _Host {
  _Host({this.declaredProducts = const [kProduct]}) {
    workflowEngine = DurableWorkflowEngine(
      store: workflowStore,
      policy: const WorkflowEngine(),
    );
    provisioner = DesignRemediationWorkItemProvisioner(
      workflowStore: workflowStore,
      workflowEngine: workflowEngine,
      qaContractProvisioner: withProvisioner
          ? ProductQAContractProvisioner(
              contractStore: contracts,
              specStore: _SpecStore({
                for (final id in declaredProducts) id: _declaration(id),
              }),
            )
          : null,
      log: (event, fields) {
        events.add(event);
        logged.add((event, Map<String, dynamic>.of(fields)));
      },
    );
  }

  /// Which products have declared a QA contract. Absent from this list, a
  /// product has no declaration row — the fail-closed case.
  final List<String> declaredProducts;

  /// Set false to model the "no provisioner supplied" construction, which is a
  /// different failure from "the product declared nothing" and must stay so.
  bool withProvisioner = true;

  final InMemoryWorkflowStore workflowStore = InMemoryWorkflowStore();
  final _OverwritingQAContractStore contracts = _OverwritingQAContractStore();
  final List<String> events = <String>[];

  /// Event names AND their payloads, copied defensively so a later mutation of
  /// the caller's map cannot rewrite what was logged. `events` above stays the
  /// name-only view every pre-existing assertion uses.
  final List<(String, Map<String, dynamic>)> logged =
      <(String, Map<String, dynamic>)>[];

  /// The payloads logged under [event], in order. Empty when it never fired —
  /// which is itself an assertion, since the events this lane emits are the
  /// only place some of these facts are recorded at all.
  List<Map<String, dynamic>> payloadsOf(String event) => logged
      .where((entry) => entry.$1 == event)
      .map((entry) => entry.$2)
      .toList();

  late final DurableWorkflowEngine workflowEngine;
  late final DesignRemediationWorkItemProvisioner provisioner;

  /// The triage output that classified this defect as a design flaw. Shared by
  /// every scenario so a difference between them is never the classification.
  TriageResult triageResult(String defectId) => _triage(defectId);

  Future<WorkItem?> run({
    required String productId,
    String defectId = kDefectId,
  }) async => provisioner.ensurePersisted(
    triageResult: triageResult(defectId),
    defect: await _awaitDefect(productId, defectId),
  );

  /// The situation measured on 2026-10-17, reproduced: a defect reported from a
  /// surface carrying NO work item, so `affectedWorkItemId` is null and
  /// [resolveDesignRemediationProductId] has no join to follow.
  Future<WorkItem?> runOrphan({
    String defectId = kDefectId,
  }) async => provisioner.ensurePersisted(
    triageResult: triageResult(defectId),
    defect: orphanDefect(defectId),
  );

  /// A defect with `affectedWorkItemId == null` — NOT an empty string and not
  /// an id pointing at nothing. The difference matters: both of those still take
  /// the `affectedWorkItemId` branch of the resolution and reach a store lookup,
  /// and this is the case that reaches the `defects` bucket without one.
  Defect orphanDefect(String defectId) => Defect(
    defectId: defectId,
    title: 'The funnel reports a different number than the invoice',
    description: 'Checkout shows 47.00 where the invoice shows 42.00.',
    expectedBehavior: 'Checkout total equals the invoice total.',
    reproductionSteps: '1. Add two items\n2. Open checkout',
    severity: 'high',
    status: DefectStatus.reported,
    reporter: 'reporter@example.com',
    affectedWorkItemId: null,
    createdAt: kNow,
    updatedAt: kNow,
    version: 1,
  );

  /// Seeds the remediation row a previous run already wrote, with no contract
  /// on it — the state every item this change repairs was measured in.
  ///
  /// [productId] is written verbatim, blank and all, because that is what the
  /// column accepts; the production store applies no validation on write.
  Future<WorkItem> seedExistingRemediationRow({
    required String defectId,
    required String productId,
    WorkItemState state = WorkItemState.agentExecuting,
  }) async {
    final row = WorkItem(
      workItemId: designRemediationWorkItemId(defectId),
      productId: productId,
      category: WorkItemCategory.feature,
      title: 'Design remediation: seeded by a previous run',
      state: state,
      featureRef: defectId,
      metadata: <String, dynamic>{
        'defectId': defectId,
        designRemediationRequiredKey: true,
      },
      createdAt: kNow,
      updatedAt: kNow,
      version: 1,
    );
    await workflowStore.saveWorkItem(row);
    return row;
  }

  Future<Defect> _awaitDefect(String productId, String defectId) async {
    final affected = WorkItem(
      workItemId: 'affected-$defectId',
      productId: productId,
      category: WorkItemCategory.feature,
      title: 'The work item the defect was reported against',
      description: 'Pre-existing prose so this item is a real one.',
      state: WorkItemState.planned,
      createdAt: kNow,
      updatedAt: kNow,
      version: 1,
    );
    await workflowStore.saveWorkItem(affected);
    return Defect(
      defectId: defectId,
      title: 'The funnel reports a different number than the invoice',
      description: 'Checkout shows 47.00 where the invoice shows 42.00.',
      expectedBehavior: 'Checkout total equals the invoice total.',
      reproductionSteps: '1. Add two items\n2. Open checkout',
      severity: 'high',
      status: DefectStatus.reported,
      reporter: 'reporter@example.com',
      affectedWorkItemId: affected.workItemId,
      createdAt: kNow,
      updatedAt: kNow,
      version: 1,
    );
  }

  int count(String event) => events.where((e) => e == event).length;
}

void main() {
  group('a created remediation item is governed by a REAL contract', () {
    test('it carries a qaContractId that resolves to a row', () async {
      final host = _Host();

      final item = await host.run(productId: kProduct);

      expect(item, isNotNull);
      expect(
        item!.qaContractId,
        isNotNull,
        reason:
            'GuardConditions.qaContractExists() null-checks this exact column on '
            'agentExecuting -> agentCompleted. 0 of the 4 non-triage work items '
            'measured on 2026-10-17 carried one; this is the fix for that.',
      );
      final contract = await host.contracts.readQAContract(item.qaContractId!);
      expect(contract, isNotNull, reason: 'and it must resolve to a real row');
      expect(contract!.gates.single.gateId, 'human-declared-gate');
      expect(
        contract.metadata?[qaContractProductIdMetadataKey],
        kProduct,
        reason: 'the gates are the PRODUCT\'s, so the row says whose they are',
      );
    });

    test('the id is work-item-scoped, not defect-scoped', () async {
      final host = _Host();

      final item = await host.run(productId: kProduct);

      expect(
        item!.qaContractId,
        productQAContractIdForWorkItem(designRemediationWorkItemId(kDefectId)),
      );
      expect(
        item.qaContractId,
        isNot(triageQAContractIdForDefect(kDefectId)),
        reason:
            'qa-triage-DEF-1 is the triage parent\'s primary key and '
            'saveQAContract replaces on conflict; reusing it would overwrite '
            'the parent\'s contract and repoint its metadata.workItemId',
      );
    });

    test(
      'lane E cannot touch the triage contract for the SAME defect — the '
      'collision, asserted on an overwrite-capable store',
      () async {
        final host = _Host();

        // The triage parent is provisioned first, exactly as lane A does.
        final triageContractId = triageQAContractIdForDefect(kDefectId);
        final triageBefore = await host.contracts.provisionQAContract(
          buildAdvisoryTriageQAContract(
            defectId: kDefectId,
            workItemId: defectTriageWorkItemId(kDefectId),
            now: kNow,
          ),
        );
        expect(host.contracts.rowCount, 1);

        final item = await host.run(productId: kProduct);

        expect(host.contracts.rowCount, 2, reason: 'two contracts, two rows');
        expect(
          host.contracts.writeCounts[triageContractId],
          1,
          reason:
              'lane E wrote NOTHING at the triage parent\'s key — the one '
              'write there is the one this test made to set the parent up. On '
              'a store that APPENDS instead of replacing, a second write '
              'would leave the row untouched and the assertion below would '
              'still pass, which is why this store implements ON CONFLICT DO '
              'UPDATE: the damage this change could have caused is exactly a '
              'SILENT overwrite, so the store has to be able to exhibit it.',
        );
        expect(
          host.contracts.writeOrder,
          contains(
            productQAContractIdForWorkItem(
              designRemediationWorkItemId(kDefectId),
            ),
          ),
          reason:
              'lane E wrote at its OWN key, which is the positive half of '
              'the same claim',
        );

        final triageAfter = await host.contracts.readQAContract(
          triageContractId,
        );
        expect(triageAfter, triageBefore, reason: 'byte-identical');
        expect(
          triageAfter!.metadata?[qaContractWorkItemIdMetadataKey],
          defectTriageWorkItemId(kDefectId),
          reason:
              'still linked to the TRIAGE item; a re-pointed link would make '
              'listQAContractsForWorkItem answer for the wrong item entirely',
        );
        expect(
          triageAfter.gates.map((g) => g.gateId),
          contains('triage-classification-admitted'),
          reason: 'still the TRIAGE contract\'s own gates, unchanged',
        );
        expect(item!.qaContractId, isNot(triageContractId));
      },
    );

    test('two runs for one defect leave exactly ONE contract row', () async {
      final host = _Host();

      await host.run(productId: kProduct);
      await host.run(productId: kProduct);
      await host.run(productId: kProduct);

      expect(
        host.contracts.rowCount,
        1,
        reason:
            'three provisionings, one work item, one row. The contract id is a '
            'pure function of the work item id, so the replays address the '
            'same primary key.',
      );
      expect(
        (await host.workflowStore.readAllWorkItems()).where(
          (w) => w.workItemId == designRemediationWorkItemId(kDefectId),
        ),
        hasLength(1),
        reason: 'and the work item itself was never duplicated',
      );
    });

    test('no triage gate is ever declared on a remediation item', () async {
      final host = _Host();

      final item = await host.run(productId: kProduct);

      final contract = await host.contracts.readQAContract(item!.qaContractId!);
      for (final gate in contract!.gates) {
        expect(gate.type, isNot(startsWith('triage-')));
      }
      expect(
        contract.toJson().toString(),
        isNot(contains('defect_evidence_reference')),
        reason:
            'a feature item has no defect, so a defect-evidence gate against it '
            'is a check nobody could run against anything',
      );
    });
  });

  group('a product with NO declaration fails closed, BY NAME', () {
    test('the item is created, and the refusal is ON the item', () async {
      final host = _Host(declaredProducts: const []);

      final item = await host.run(productId: kUndeclaredProduct);

      expect(
        item,
        isNotNull,
        reason:
            'a reported design defect is a fact; refusing to record it because '
            'the platform has no QA contract configured would lose the report. '
            'See the class doc for why this is a governance call and not a '
            'refusal.',
      );
      expect(
        item!.qaContractId,
        isNull,
        reason:
            'nothing was minted — a placeholder id would satisfy the guard '
            'and satisfy nothing else',
      );
      expect(
        item.metadata?[productQAContractSpecUnavailableKey],
        productQAContractSpecUndeclared,
        reason:
            'the refusal is ON THE ROW, named. A null here that a reader cannot '
            'tell apart from "not provisioned yet" is the silent-null failure '
            'this criterion exists to prevent.',
      );
      expect(host.contracts.rowCount, 0);
      expect(host.contracts.writeOrder, isEmpty);
    });

    test(
      'the two refusals are distinguishable on the row, because they need '
      'different remedies',
      () async {
        final undeclared = _Host(declaredProducts: const []);
        final emptyItem = await undeclared.run(productId: kUndeclaredProduct);
        expect(
          emptyItem!.metadata?[productQAContractSpecUnavailableKey],
          productQAContractSpecUndeclared,
        );

        final host = _Host();
        final specs = _SpecStore({
          kProduct: ProductQAContractDeclaration(
            productId: kProduct,
            gates: const [],
            manifestVersion: 'v1',
            createdAt: kNow,
            updatedAt: kNow,
          ),
        });
        final provisioner = DesignRemediationWorkItemProvisioner(
          workflowStore: host.workflowStore,
          workflowEngine: host.workflowEngine,
          qaContractProvisioner: ProductQAContractProvisioner(
            contractStore: host.contracts,
            specStore: specs,
          ),
          log: (event, fields) {},
        );
        final item = await provisioner.ensurePersisted(
          triageResult: host.triageResult('DEF-empty'),
          defect: await _defectFor(host, kProduct, 'DEF-empty'),
        );

        expect(
          item!.metadata?[productQAContractSpecUnavailableKey],
          productQAContractSpecDeclaresNoGates,
        );
        expect(
          item.metadata?[productQAContractSpecUnavailableKey],
          isNot(productQAContractSpecUndeclared),
          reason:
              'two distinct reasons, two distinct remedies: register a '
              'contract, versus write gates into the manifest you registered',
        );
        expect(host.contracts.rowCount, 0);
      },
    );

    test(
      'a missing provisioner is a THIRD, separately named condition, not a '
      'silent null',
      () async {
        final host = _Host()..withProvisioner = false;
        final provisioner = DesignRemediationWorkItemProvisioner(
          workflowStore: host.workflowStore,
          workflowEngine: host.workflowEngine,
          log: (event, fields) => host.events.add(event),
        );

        final item = await provisioner.ensurePersisted(
          triageResult: host.triageResult(kDefectId),
          defect: await _defectFor(host, kProduct, kDefectId),
        );

        expect(item!.qaContractId, isNull);
        expect(
          item.metadata?[productQAContractSpecUnavailableKey],
          productQAContractProvisionerUnavailable,
          reason:
              '"no store was wired" and "the product declared nothing" produce '
              'the same symptom and need different fixes, so they must not '
              'produce the same record',
        );
        expect(
          host.count(
            'design_remediation.qa_contract.'
            'provisioner_unavailable',
          ),
          1,
        );
      },
    );
  });

  group('the backfill hook is what makes a stranded item repairable', () {
    test(
      'an item created while the product declared nothing gets a contract on '
      'replay, once the product does',
      () async {
        // First: the product has declared nothing, so the item lands with none.
        final specs = <String, ProductQAContractDeclaration>{};
        final contracts = _OverwritingQAContractStore();
        final store = InMemoryWorkflowStore();
        final engine = DurableWorkflowEngine(
          store: store,
          policy: const WorkflowEngine(),
        );

        DesignRemediationWorkItemProvisioner build() =>
            DesignRemediationWorkItemProvisioner(
              workflowStore: store,
              workflowEngine: engine,
              qaContractProvisioner: ProductQAContractProvisioner(
                contractStore: contracts,
                specStore: _SpecStore(specs),
              ),
              log: (event, fields) {},
            );

        final stranded = await build().ensurePersisted(
          triageResult: _triage(kDefectId),
          defect: await _defectForStore(store, kUndeclaredProduct, kDefectId),
        );
        expect(stranded!.qaContractId, isNull);
        expect(contracts.rowCount, 0);
        final strandedVersion = stranded.version;

        // Now the product declares a contract. This is a HUMAN action — the
        // operator registers the product with a manifest — and the replay picks
        // it up.
        specs[kUndeclaredProduct] = _declaration(kUndeclaredProduct);

        final repaired = await build().ensurePersisted(
          triageResult: _triage(kDefectId),
          defect: await _defectForStore(store, kUndeclaredProduct, kDefectId),
        );

        expect(
          repaired!.qaContractId,
          productQAContractIdForWorkItem(
            designRemediationWorkItemId(kDefectId),
          ),
        );
        expect(contracts.rowCount, 1);
        // `WorkflowStore.saveWorkItem` does NOT advance `version` — only
        // `DurableWorkflowEngine.transition` does — so a version comparison
        // cannot see this write and asserting one would be asserting nothing.
        // The durable read is the assertion: the row itself now carries the id.
        final durable = await store.readWorkItem(stranded.workItemId);
        expect(
          durable.qaContractId,
          productQAContractIdForWorkItem(
            designRemediationWorkItemId(kDefectId),
          ),
          reason:
              'read back out of the store, not echoed from the in-memory value '
              'the CAS write was handed. The defect being repaired is that a '
              'stamp which does not survive its write is indistinguishable '
              'from one that was never made.',
        );
        expect(durable.version, strandedVersion);
        expect(repaired.state, WorkItemState.planned);
        expect(
          repaired.metadata?[productQAContractSpecUnavailableKey],
          productQAContractSpecUndeclared,
          reason:
              'the stale refusal marker is left in place rather than removed. '
              'The work item already exists with its metadata; editing it to '
              'erase the record of why it was parked would be a second write '
              'on a row that another lane owns, and the marker being stale is '
              'the honest reading — qaContractId is the authority on whether '
              'the contract is now attached.',
        );
      },
    );

    test(
      'a replay of an ALREADY-provisioned item changes nothing — the '
      'backfill is a read',
      () async {
        final host = _Host();

        final first = await host.run(productId: kProduct);
        final writesAfterFirst =
            host.contracts.writeCounts[productQAContractIdForWorkItem(
              designRemediationWorkItemId(kDefectId),
            )]!;
        final versionAfterFirst = first!.version;

        final second = await host.run(productId: kProduct);

        expect(second!.qaContractId, first.qaContractId);
        expect(
          second.version,
          versionAfterFirst,
          reason: 'no CAS write, because the column was already non-null',
        );
        expect(
          host.contracts.writeCounts[first.qaContractId!],
          writesAfterFirst,
          reason: 'and the store was not touched again',
        );
        expect(host.contracts.rowCount, 1);
      },
    );

    test(
      'an item that already carries SOMEONE ELSE\'S contract is never '
      're-pointed',
      () async {
        final host = _Host();
        final item = await host.run(productId: kProduct);

        // The row is re-stamped by hand to a contract that is not ours.
        await host.workflowStore.saveWorkItem(
          item!.copyWith(qaContractId: 'qa-triage-some-other-defect'),
        );
        final writesBefore = host.contracts.rowCount;

        final replay = await host.run(productId: kProduct);

        expect(
          replay!.qaContractId,
          'qa-triage-some-other-defect',
          reason:
              'the backfill only runs when the column is NULL. Re-pointing an '
              'existing link would silently move a contract between work items, '
              'which is the same damage this whole change is shaped to avoid.',
        );
        expect(host.contracts.rowCount, writesBefore);
      },
    );
  });

  // The rows measured on 2026-10-17 that could not be repaired: the defect
  // named no work item, so the defect-derived resolution landed on the `defects`
  // ROUTING BUCKET, which has no product row and no declared QA contract — while
  // the remediation row itself recorded a product that HAS one. The row and its
  // gate disagreed about which product governed the item, and the gate lost.
  group('an EXISTING row is governed by its OWN recorded product', () {
    test(
      'an orphan defect whose row records a real product gets the contract '
      'ATTACHED — the reported failure, reproduced and repaired',
      () async {
        // `defects` is deliberately NOT declared here. That is the live
        // situation: the bucket has no `product` row and no
        // `product_qa_contract_spec` row, so provisioning through it refuses
        // with notDeclared. Declaring it here would make the test pass for a
        // resolution this change exists to stop using.
        final host = _Host(declaredProducts: const [kRowProduct]);
        await host.seedExistingRemediationRow(
          defectId: kDefectId,
          productId: kRowProduct,
        );

        final repaired = await host.runOrphan();

        expect(repaired, isNotNull);
        expect(
          repaired!.qaContractId,
          productQAContractIdForWorkItem(
            designRemediationWorkItemId(kDefectId),
          ),
          reason:
              'the work-item-scoped id for this defect. Asserting it exactly '
              'rather than "not null" is the point: the contract is not merely '
              'present, it is the ONE addressable by this work item, so '
              'listQAContractsForWorkItem can find it.',
        );

        final contract = await host.contracts.readQAContract(
          repaired.qaContractId!,
        );
        expect(
          contract,
          isNotNull,
          reason:
              'a real row, read back out of the store — not an id this code '
              'computed and handed back. An id nothing resolves to would '
              'satisfy GuardConditions.qaContractExists(), which null-checks '
              'the column, and would satisfy nothing else.',
        );
        expect(
          contract!.gates.single.gateId,
          'human-declared-gate',
          reason:
              'the gates are the ROW\'S product\'s, so the gate set is an '
              'observable consequence of which product id the code resolved to '
              'and not a label it could have printed either way',
        );
        expect(
          contract.metadata?[qaContractProductIdMetadataKey],
          kRowProduct,
        );
        expect(
          contract.metadata?[qaContractProductIdMetadataKey],
          isNot(defectTriageBucketProductId),
          reason:
              'the gate came from the product the item belongs to, not from the '
              'routing bucket the defect happened to fall into',
        );
        expect(host.contracts.rowCount, 1, reason: 'exactly one contract row');

        // Read out of the store, not echoed from the in-memory value the CAS
        // write was handed. A stamp that does not survive its write is
        // indistinguishable from one that was never made.
        final durable = await host.workflowStore.readWorkItem(
          designRemediationWorkItemId(kDefectId),
        );
        expect(durable.qaContractId, repaired.qaContractId);
        expect(
          durable.productId,
          kRowProduct,
          reason: 'and the row still records the product it always recorded',
        );

        expect(
          host.count('design_remediation.qa_contract.backfilled'),
          1,
          reason:
              'the lane-E event only the changed path can emit. Before the '
              'change the provisioner refused under the bucket and this event '
              'never fired; a test that only re-read the column would not '
              'distinguish the two.',
        );
        expect(
          host.count('design_remediation.qa_contract.not_provisioned'),
          0,
          reason:
              'the refusal that produced "contract: refused-or-absent" and '
              'qaContractId NULL on 2026-10-17',
        );
        expect(
          host.payloadsOf('design_remediation.replayed').single['productId'],
          kRowProduct,
        );
        expect(
          host
              .payloadsOf('design_remediation.replayed')
              .single['defectDerivedProductId'],
          defectTriageBucketProductId,
          reason:
              'the defect-derived id is still computed and still logged; this '
              'is the divergence the log now records instead of concealing',
        );
      },
    );

    test('a blank or whitespace productId on the row FALLS BACK', () async {
      // The `defects` bucket is declared in this in-memory fixture store ONLY,
      // so that WHICH id the fallback resolved to is observable on the contract
      // row it writes. This registers nothing as a governed product: it is a
      // test double for `product_qa_contract_spec`, and the production
      // declaration table is untouched.
      final host = _Host(declaredProducts: const [defectTriageBucketProductId]);
      await host.seedExistingRemediationRow(
        defectId: kDefectId,
        productId: kBlankProductId,
      );

      final repaired = await host.runOrphan();

      expect(repaired!.qaContractId, isNotNull);
      final contract = await host.contracts.readQAContract(
        repaired.qaContractId!,
      );
      expect(
        contract,
        isNotNull,
        reason:
            'the fallback is observable only if something is provisioned. A '
            'blank id matches no declaration and would refuse with '
            'notDeclared, so this goes red if the code provisioned under the '
            'blank id instead of falling back.',
      );
      expect(
        contract!.metadata?[qaContractProductIdMetadataKey],
        defectTriageBucketProductId,
        reason:
            'the DEFECT-derived value, i.e. the bucket. Provisioning under an '
            'empty product id would name a product that does not exist.',
      );
      expect(
        host
            .payloadsOf('design_remediation.replayed')
            .single['productIdSource'],
        'defectDerived',
      );
    });

    test(
      'an EMPTY productId falls back too — even when the empty id itself has a '
      'declaration it could have been provisioned under',
      () async {
        // The strongest form of the blank case. The empty id is declared here,
        // so provisioning under it WOULD have succeeded and produced a contract
        // stamped `productId: ""` — a gate attributed to no product at all. The
        // fallback has to run BEFORE the blank is reached, and only the stamped
        // product id can show that it did.
        final host = _Host(
          declaredProducts: const [defectTriageBucketProductId, ''],
        );
        await host.seedExistingRemediationRow(
          defectId: kDefectId,
          productId: '',
        );

        final repaired = await host.runOrphan();

        expect(repaired!.qaContractId, isNotNull);
        final contract = await host.contracts.readQAContract(
          repaired.qaContractId!,
        );
        expect(
          contract!.metadata?[qaContractProductIdMetadataKey],
          defectTriageBucketProductId,
          reason:
              'the defect-derived value, never the blank one — even though the '
              'blank one would have answered',
        );
        expect(
          host
              .payloadsOf('design_remediation.replayed')
              .single['productIdSource'],
          'defectDerived',
        );
      },
    );

    test(
      'CREATION is untouched: with no row to read, the defect still resolves '
      'the product',
      () async {
        // Same orphan defect as the failing case, but NO row exists — so the
        // changed branch is not taken and the create path runs. It must file
        // the item under the bucket, exactly as it did before this change. If
        // the resolution had been moved into resolveDesignRemediationProductId
        // instead of the replay branch, this would file it under something else
        // and go red.
        final host = _Host(
          declaredProducts: const [defectTriageBucketProductId],
        );

        final created = await host.runOrphan();

        expect(created, isNotNull);
        expect(
          created!.productId,
          defectTriageBucketProductId,
          reason:
              'at creation there is no row to read, so the defect-derived '
              'resolution is the only input available. This is the behaviour '
              'decision 8f1ed5bf requires to stay exactly as it was.',
        );
        final contract = await host.contracts.readQAContract(
          created.qaContractId!,
        );
        expect(
          contract!.metadata?[qaContractProductIdMetadataKey],
          defectTriageBucketProductId,
        );
        expect(
          host.count('design_remediation.created'),
          1,
          reason: 'the CREATE branch ran, not the replay branch',
        );
        expect(host.count('design_remediation.replayed'), 0);
        expect(host.count('design_remediation.qa_contract.backfilled'), 0);
      },
    );

    test(
      'creation still follows a defect\'s own work-item link, so the change is '
      'a SPLIT and not a redirection',
      () async {
        // The other half of the same claim: the defect-derived resolution is
        // untouched in both of its outcomes, not just the orphan one.
        final host = _Host(declaredProducts: const [kProduct]);

        final created = await host.run(productId: kProduct);

        expect(created!.productId, kProduct);
        final contract = await host.contracts.readQAContract(
          created.qaContractId!,
        );
        expect(contract!.metadata?[qaContractProductIdMetadataKey], kProduct);
      },
    );

    test(
      'when both inputs exist they DISAGREE, and the row wins — which is the '
      'whole change',
      () async {
        // The defect links to a work item in one product; the remediation row
        // records another. Both are declared, so both could satisfy the gate and
        // only the choice is under test.
        final host = _Host(declaredProducts: const [kProduct, kRowProduct]);
        await host.seedExistingRemediationRow(
          defectId: kDefectId,
          productId: kRowProduct,
        );

        final repaired = await host.run(productId: kProduct);

        final contract = await host.contracts.readQAContract(
          repaired!.qaContractId!,
        );
        expect(
          contract!.metadata?[qaContractProductIdMetadataKey],
          kRowProduct,
          reason:
              'the row governs an existing row. Sourcing the gate from the '
              'defect here would leave the item governed by one product and '
              'gated by another, which is the contradiction being corrected.',
        );
        expect(
          host
              .payloadsOf('design_remediation.replayed')
              .single['productIdSource'],
          'existingWorkItem',
        );
      },
    );
  });
}

TriageResult _triage(String defectId) => TriageResult(
  resultId: 'tr-$defectId',
  defectId: defectId,
  recommendedStatus: DefectStatus.remediationPlanned,
  recommendedClassification: DefectClassification.designDefect,
  confidence: 0.9,
  suspectedCategory: 'ui',
  suspectedComponents: const ['CheckoutScreen'],
  reproductionSupported: true,
  evidenceUsed: const ['ev-1'],
  clarificationRequired: const [],
  recommendedNextAction: 'open a design remediation item',
  possibleDuplicateDefectId: null,
  recommendedWorkItemCategory: null,
  summary: 'The totals diverge in the checkout summary widget.',
  jobId: 'job-1',
  createdAt: kNow,
  version: 1,
);

/// A defect whose `affectedWorkItemId` resolves to a work item naming
/// [productId], so the production product resolution — not a shortcut — puts
/// the remediation item under that product.
Future<Defect> _defectFor(_Host host, String productId, String defectId) =>
    _defectForStore(host.workflowStore, productId, defectId);

Future<Defect> _defectForStore(
  InMemoryWorkflowStore store,
  String productId,
  String defectId,
) async {
  final affected = WorkItem(
    workItemId: 'affected-$defectId',
    productId: productId,
    category: WorkItemCategory.feature,
    title: 'The work item the defect was reported against',
    description: 'Pre-existing prose so this item is a real one.',
    state: WorkItemState.planned,
    createdAt: kNow,
    updatedAt: kNow,
    version: 1,
  );
  await store.saveWorkItem(affected);
  return Defect(
    defectId: defectId,
    title: 'The funnel reports a different number than the invoice',
    description: 'Checkout shows 47.00 where the invoice shows 42.00.',
    expectedBehavior: 'Checkout total equals the invoice total.',
    reproductionSteps: '1. Add two items\n2. Open checkout',
    severity: 'high',
    status: DefectStatus.reported,
    reporter: 'reporter@example.com',
    affectedWorkItemId: affected.workItemId,
    createdAt: kNow,
    updatedAt: kNow,
    version: 1,
  );
}

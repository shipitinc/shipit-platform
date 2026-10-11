import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/triage/lane_a_defect_triage_work_item.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart'
    show QAContractStore, triageWorkItemCategory;
import 'package:scheduler/scheduler.dart'
    show RunnableWorkEvaluator, RunnableWorkStatus, triageDefectDefinition;
import 'package:workflow_engine/workflow_engine.dart' show WorkflowEngine;
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// Product ids that are obviously not this product's, used so no test can
/// accidentally pass because it agreed with a real one.
const String kProduct = 'product-under-test';
const String kOtherProduct = 'a-different-product';

/// A defect whose every optional field is populated, so a test that asserts
/// metadata can tell a field that was carried across from one that was dropped.
final DateTime kDefectCreatedAt = DateTime.utc(2026, 3, 4, 5, 6, 7);

/// Every store and engine one [DefectTriageWorkItemProvisioner] needs, plus the
/// provisioner itself, so a test reads as a scenario rather than as wiring.
class _Host {
  _Host({this.withQAContractStore = true}) {
    workflowEngine = DurableWorkflowEngine(
      store: workflowStore,
      policy: const WorkflowEngine(),
    );
  }

  final bool withQAContractStore;

  final InMemoryWorkflowStore workflowStore = InMemoryWorkflowStore();

  /// Bound to [workflowStore], deliberately: a second in-memory store would
  /// make every assertion in this file pass against a graph nothing else can
  /// see.
  late final DurableWorkflowEngine workflowEngine;

  final _InMemoryQAContractStore qaContracts = _InMemoryQAContractStore();

  final List<String> events = <String>[];

  late final DefectTriageWorkItemProvisioner provisioner =
      DefectTriageWorkItemProvisioner(
        workflowStore: workflowStore,
        workflowEngine: workflowEngine,
        qaContractStore: withQAContractStore ? qaContracts : null,
        log: (event, fields) => events.add(event),
      );

  /// A defect with no product link, so it files under the shared triage bucket
  /// unless a test says otherwise.
  Defect defect(String defectId, {String? affectedWorkItemId}) => Defect(
    defectId: defectId,
    title: 'Checkout total disagrees with the invoice total',
    description: 'Checkout shows 47.00 where the invoice shows 42.00.',
    expectedBehavior: 'Checkout total equals the invoice total.',
    reproductionSteps: '1. Add two items\n2. Open checkout',
    severity: 'high',
    status: DefectStatus.reported,
    reporter: 'reporter@example.com',
    affectedWorkItemId: affectedWorkItemId,
    createdAt: kDefectCreatedAt,
    updatedAt: kDefectCreatedAt,
    version: 1,
  );

  /// Evidence JSON of the shape `createDefect` passes: already-persisted
  /// evidence descriptors, not prose.
  String get evidenceJson =>
      '[{"evidenceId":"ev-1","description":"Invoice 42.00 vs checkout 47.00"}]';

  Future<WorkItem> ensurePersisted(Defect defect) =>
      provisioner.ensurePersisted(defect: defect, evidenceJson: evidenceJson);

  Future<WorkItem> ensurePersistedWithoutWalk(Defect defect) =>
      provisioner.ensurePersistedWithoutWalk(
        defect: defect,
        evidenceJson: evidenceJson,
      );

  Future<WorkItem> reread(String workItemId) =>
      workflowStore.readWorkItem(workItemId);

  Future<List<WorkItem>> allItems() => workflowStore.readAllWorkItems();

  /// The idempotency keys the ACCEPTED transitions for [workItemId] were
  /// recorded under, in the order they were accepted.
  ///
  /// Read from the durable transition history rather than from the constants in
  /// `lane_a_defect_triage_work_item.dart`, which are private to it and are
  /// exactly the thing these tests are supposed to pin. A test that restates a
  /// production constant next to itself asserts that the constant equals
  /// itself.
  Future<List<String?>> acceptedKeys(String workItemId) async =>
      (await workflowStore.readTransitionHistory(workItemId))
          .where((record) => record.outcome == TransitionOutcome.accepted)
          .map((record) => record.idempotencyKey)
          .toList();

  /// How many events named [event] were emitted.
  int count(String event) => events.where((e) => e == event).length;

  /// Whether the scheduler that would enqueue this item classifies it
  /// `runnable`, using the production evaluator and the production definition.
  ///
  /// `RunnableWorkEvaluator` reads the item's state and neither its category nor
  /// its product, which is exactly why "did we walk it?" is the question that
  /// decides whether a defect can dispatch. Asserting through the evaluator
  /// rather than through the state alone means a state this file happens to
  /// consider safe cannot drift away from the states the scheduler sees.
  RunnableWorkStatus runnabilityOf(WorkItem item) =>
      RunnableWorkEvaluator(policy: const WorkflowEngine()).evaluate(
        item,
        triageDefectDefinition,
      );
}

/// A [QAContractStore] that really stores.
///
/// Deliberately not a stub that answers every call with the value it was given:
/// the provisioner asserts `provisionQAContract` returned the id it addressed
/// AND `hasQAContract` can read it back, and the point of those assertions is
/// that a stamped `qaContractId` resolves to a row. A store that always agrees
/// would make them vacuous.
class _InMemoryQAContractStore implements QAContractStore {
  final Map<String, QAContract> _rows = <String, QAContract>{};

  /// Every id written, in write order, so a test can assert that a replay is a
  /// byte-identical write to the same key rather than a second row.
  final List<String> writeOrder = <String>[];

  @override
  Future<void> saveQAContract(QAContract contract) async {
    writeOrder.add(contract.contractId);
    _rows[contract.contractId] = contract;
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    await saveQAContract(contract);
    final stored = await readQAContract(contract.contractId);
    if (stored == null) {
      throw StateError('${contract.contractId} was written but not readable');
    }
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
      .where((c) => c.metadata?['workItemId'] == workItemId)
      .toList();

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async => _rows.values.where((c) => c.workItemCategory == category).toList();
}

void main() {
  group('ensurePersisted is unchanged: it walks, on both paths', () {
    test('a first request creates the item and drives it to '
        'designNotRequired, recording exactly the three intake hops', () async {
      final host = _Host();

      final item = await host.ensurePersisted(host.defect('d-1'));

      expect(item.workItemId, defectTriageWorkItemId('d-1'));
      expect(item.state, WorkItemState.designNotRequired);
      expect(
        await host.acceptedKeys(item.workItemId),
        const [
          'triage-intake:planning',
          'triage-intake:planned',
          'triage-intake:designNotRequired',
        ],
        reason:
            'lane A walks with its own actor and its own keys; these are the '
            'keys the live defect path has always recorded, read from the '
            'durable history rather than from the private constants',
      );

      // The QA contract, description, metadata and logs are all part of the
      // behaviour `createDefect` depends on, not decoration around it.
      expect(item.qaContractId, isNotNull);
      expect(
        await host.qaContracts.readQAContract(item.qaContractId!),
        isNotNull,
        reason: 'a stamped qaContractId must resolve to a row',
      );
      expect(item.description, contains('Checkout shows 47.00'));
      expect(item.metadata?['defectEvidence'], host.evidenceJson);
      expect(item.metadata?['defectId'], 'd-1');
      expect(host.count('triage.work_item.created'), 1);
      expect(host.count('triage.qa_contract.provisioned'), 1);
    });

    test(
      'a replay neither re-creates nor re-walks, and returns the same item',
      () async {
        final host = _Host();
        final first = await host.ensurePersisted(host.defect('d-2'));

        final second = await host.ensurePersisted(host.defect('d-2'));

        expect(second.workItemId, first.workItemId);
        expect(second.state, WorkItemState.designNotRequired);
        expect(await host.allItems(), hasLength(1));
        expect(
          await host.acceptedKeys(first.workItemId),
          hasLength(3),
          reason:
              'every hop is guarded by the item\'s current state, so a '
              'replay transitions nothing',
        );
        expect(
          host.count('triage.work_item.created'),
          1,
          reason: 'the second call took the read branch',
        );
        expect(host.count('triage.work_item.replayed'), 1);
        expect(
          host.count('triage.qa_contract.provisioned'),
          1,
          reason: 'the contract is already attached, so the backfill is a read',
        );
      },
    );

    test('an item no lane can claim is left where it is and reported, not '
        'forced', () async {
      final host = _Host();
      final created = await host.ensurePersistedWithoutWalk(
        host.defect('d-3'),
      );
      // A human parked it somewhere the graph does not route from here.
      await host.workflowStore.saveWorkItem(
        created.copyWith(state: WorkItemState.waitingForHumanDecision),
        expectedVersion: created.version,
      );
      host.events.clear();

      final item = await host.ensurePersisted(host.defect('d-3'));

      expect(item.state, WorkItemState.waitingForHumanDecision);
      expect(host.count('triage.work_item.not_triageable'), 1);
      expect(host.count('triage.work_item.replayed'), 1);
    });

    test('a defect whose affected work item is gone falls back to the shared '
        'triage bucket, not to an invented product', () async {
      final host = _Host();

      final item = await host.ensurePersisted(
        host.defect('d-4', affectedWorkItemId: 'WI-that-does-not-exist'),
      );

      expect(item.productId, defectTriageBucketProductId);
      expect(host.count('triage.product.unresolved_affected_work_item'), 1);
    });

    test(
      'a defect linked to a work item inherits that item\'s product',
      () async {
        final host = _Host();
        final affected = await host.workflowEngine.createWorkItem(
          workItemId: 'WI-affected',
          productId: kProduct,
          category: WorkItemCategory.feature,
          title: 'A feature request',
          description: 'A human-filed request describing observed behaviour.',
          featureRef: 'WI-affected',
        );
        expect(affected.workItemId, 'WI-affected');

        final item = await host.ensurePersisted(
          host.defect('d-5', affectedWorkItemId: affected.workItemId),
        );

        expect(item.productId, kProduct);
        expect(item.productId, isNot(defectTriageBucketProductId));
      },
    );
  });

  group('ensurePersistedWithoutWalk defers the walk; it does not reorder it', () {
    test('a first request persists a real row and records NO transition at '
        'all', () async {
      final host = _Host();

      final item = await host.ensurePersistedWithoutWalk(host.defect('d-6'));

      // Persisted, not merely built in memory: `Scheduler.tick` resolves work
      // items from the store, so an in-memory-only item is what stranded 18
      // jobs before this class existed.
      final stored = await host.reread(item.workItemId);
      expect(stored.workItemId, item.workItemId);
      expect(await host.allItems(), hasLength(1));

      expect(item.state, WorkItemState.draft);
      expect(
        await host.acceptedKeys(item.workItemId),
        isEmpty,
        reason:
            'zero recorded transitions is the strongest available statement '
            'that the walk was deferred rather than performed and undone',
      );
    });

    test('the pre-walk item is invisible to the scheduler that would enqueue '
        'it, and the walked item is not', () async {
      final host = _Host();

      final preWalk = await host.ensurePersistedWithoutWalk(host.defect('d-7'));

      expect(
        host.runnabilityOf(preWalk),
        RunnableWorkStatus.noAction,
        reason:
            'designNotRequired is an entry state of triageDefectDefinition and '
            'the evaluator reads neither category nor product, so a walked item '
            'dispatches for ANY product. An item handed to a trigger before the '
            'walk is the only shape a gate can still hold back.',
      );

      final walked = await host.ensurePersisted(host.defect('d-7'));
      expect(walked.state, WorkItemState.designNotRequired);
      expect(
        host.runnabilityOf(walked),
        RunnableWorkStatus.runnable,
        reason:
            'the contrast is the point: the walk is what makes it '
            'dispatchable, which is why it must come after the gate',
      );
    });

    test('the QA contract, description, metadata and product are the same ones '
        'the walking entry point produces', () async {
      final host = _Host();

      final item = await host.ensurePersistedWithoutWalk(host.defect('d-8'));

      expect(item.qaContractId, 'qa-triage-d-8');
      expect(
        await host.qaContracts.readQAContract(item.qaContractId!),
        isNotNull,
      );
      expect(item.category, triageWorkItemCategory);
      expect(
        item.featureRef,
        'd-8',
        reason:
            'the planning_evidence_provided guard accepts this, and the '
            'defect IS the requirement reference',
      );
      expect(item.metadata?['defectEvidence'], host.evidenceJson);
      expect(item.metadata?['defectTitle'], host.defect('d-8').title);
      expect(item.metadata?['defectSeverity'], 'high');
      expect(item.createdAt, kDefectCreatedAt);
      expect(host.count('triage.qa_contract.provisioned'), 1);
      expect(host.count('triage.work_item.created'), 1);
    });

    test(
      'the seam is greppable: the entry point names its own event',
      () async {
        final host = _Host();

        await host.ensurePersistedWithoutWalk(host.defect('d-9'));

        // Without this, the two entry points differ in an invisible way and a
        // reader of the log cannot tell which one ran.
        expect(host.count('triage.work_item.persisted_awaiting_walk'), 1);
      },
    );
  });

  group('one persistence, two entry points', () {
    test('the durable record is identical; only the state differs', () async {
      final walked = _Host();
      final parked = _Host();
      final defect = walked.defect('d-10');

      final a = await walked.ensurePersisted(defect);
      final b = await parked.ensurePersistedWithoutWalk(defect);

      // Every field a work item carries, compared pairwise. If provisioning had
      // been re-derived instead of extracted, one of these would differ — and
      // a differing instruction is a triage agent reasoning about the wrong
      // defect, which is silent rather than loud.
      expect(b.workItemId, a.workItemId);
      expect(b.productId, a.productId);
      expect(b.category, a.category);
      expect(b.title, a.title);
      expect(b.description, a.description);
      expect(b.metadata, a.metadata);
      expect(b.qaContractId, a.qaContractId);
      expect(b.featureRef, a.featureRef);
      expect(b.requirementRef, a.requirementRef);
      expect(b.createdAt, a.createdAt);
      // `updatedAt` and `version` are deliberately NOT compared. `updatedAt` is
      // the wall clock at `createWorkItem` time, so two hosts a millisecond
      // apart cannot agree on it; `version` counts state changes, and the
      // walking entry point makes three of them by design. Neither is a field
      // this class derives from the defect, so neither can drift.

      expect(b.state, WorkItemState.draft);
      expect(a.state, WorkItemState.designNotRequired);
    });

    test('the persistence logic and the walk are each written once', () async {
      final source = await _laneASource();

      // Executable rather than asserted in prose: a second copy of the
      // read-before-create, the create, or any of the private helpers is the
      // failure this split had to avoid, and it is greppable. Every count is
      // EXACT — the declaration plus its call sites — because a bound would
      // still pass after somebody added a caller.
      const List<(String, int, String)> pinned = <(String, int, String)>[
        (
          'workflowEngine.createWorkItem(',
          1,
          'one create. A second one is a second work item, or a second '
              'definition of what this one contains',
        ),
        (
          '_readOrNull(workItemId)',
          1,
          'the read-before-create, written once',
        ),
        (
          '_resolveProductId(defect)',
          1,
          'product resolution, written once — a second copy is a second rule '
              'for which product a defect belongs to',
        ),
        (
          '_workItemDescription(defect)',
          1,
          'the human-facing description, written once',
        ),
        (
          '_metadata(defect, evidenceJson)',
          1,
          'the metadata the triage instruction is built from, written once. '
              'Two copies would render two different defects to two triage '
              'runs',
        ),
        (
          '_attachQAContract(',
          2,
          'the declaration and exactly one call, from the shared half',
        ),
        (
          '_provisionQAContract(',
          3,
          'the declaration plus its two callers: the create path and the '
              'backfill. No third caller means no third way to stamp a '
              'contract',
        ),
        (
          'defectTriageWorkItemId(defect.defectId)',
          3,
          "the id is a shape that must not drift, so its call sites are "
              "pinned: one in the shared half and two in the contract "
              "provisioner. A re-spelled 'defect-' anywhere is a fourth",
        ),
        (
          '_advanceToTriageable(',
          2,
          'the declaration and exactly ONE call — from the walking entry '
              'point. If the new entry point walked too this would be 3, which '
              'is the whole defect this split exists to close',
        ),
        (
          'workflowEngine.transition(',
          3,
          'the mutation primitive itself — three calls, every one of them '
              'inside the walk. Pinning only the helper NAME leaves the '
              'primitive unpinned, and a caller that moves an item by calling '
              'this directly is a second definition of what triageable means '
              'and a second thing to keep in step',
        ),
      ];

      for (final (needle, expected, why) in pinned) {
        final occurrences = _occurrences(source, needle);
        expect(
          occurrences,
          expected,
          reason:
              '`$needle` appears $occurrences times, expected $expected. '
              '$why',
        );
      }

      expect(
        _bodyOf(source, 'Future<WorkItem> ensurePersisted('),
        isNotNull,
        reason: 'the guard must find the member, not silently scan nothing',
      );
      expect(
        _occurrences(source, 'Future<WorkItem> ensurePersistedWithoutWalk'),
        1,
        reason:
            'exactly one declaration of the new entry point — not an overload '
            'and not a second spelling of the same operation',
      );
    });

    test(
      'a trigger that walks a pre-walk item converges on one work item',
      () async {
        // The shape the caller uses: persist without the walk, hand the item to
        // something that decides, and that something owns the walk.
        final host = _Host();

        final handedOver = await host.ensurePersistedWithoutWalk(
          host.defect('d-11'),
        );
        final walked = await host.ensurePersisted(host.defect('d-11'));

        expect(walked.workItemId, handedOver.workItemId);
        expect(walked.state, WorkItemState.designNotRequired);
        expect(await host.allItems(), hasLength(1));
        expect(await host.acceptedKeys(handedOver.workItemId), hasLength(3));
      },
    );

    test('the non-walking entry point never undoes a walk', () async {
      final host = _Host();
      final walked = await host.ensurePersisted(host.defect('d-12'));
      expect(walked.state, WorkItemState.designNotRequired);

      final after = await host.ensurePersistedWithoutWalk(
        host.defect('d-12'),
      );

      expect(
        after.state,
        WorkItemState.designNotRequired,
        reason:
            'it performs no transitions at all, so a walk performed by '
            'the other entry point survives it',
      );
      expect(await host.acceptedKeys(after.workItemId), hasLength(3));
      expect(await host.allItems(), hasLength(1));
    });
  });

  group('replay', () {
    test('calling the new entry point twice creates exactly one work item and '
        'transitions it zero times', () async {
      final host = _Host();

      final first = await host.ensurePersistedWithoutWalk(host.defect('d-13'));
      final second = await host.ensurePersistedWithoutWalk(
        host.defect('d-13'),
      );

      expect(second.workItemId, first.workItemId);
      expect(
        second.version,
        first.version,
        reason: 'a replay is a read: it must not churn the row',
      );
      expect(await host.allItems(), hasLength(1));
      expect(await host.acceptedKeys(first.workItemId), isEmpty);
      expect(host.count('triage.work_item.created'), 1);
      expect(host.count('triage.work_item.replayed'), 1);
      expect(host.count('triage.qa_contract.provisioned'), 1);
      expect(
        host.qaContracts.writeOrder,
        hasLength(1),
        reason:
            'the contractId is a pure function of defectId, so a replay '
            'addresses the same row rather than writing a second one',
      );
    });

    test('a QA-contract backfill still happens on the pre-walk replay path, '
        'and still moves nothing', () async {
      // Provisioned by an older revision that had no store, so the item is
      // permanently stuck without this: the completion guard can never pass for
      // it. The repair is reachable from BOTH entry points, and neither one
      // treats repairing as walking.
      final withoutStore = _Host(withQAContractStore: false);
      final stranded = await withoutStore.ensurePersisted(
        withoutStore.defect('d-14'),
      );
      expect(stranded.qaContractId, isNull);
      expect(withoutStore.count('triage.qa_contract.store_unavailable'), 1);

      final host = _Host();
      // Move the stranded row into this host's stores under the same id.
      await host.workflowStore.saveWorkItem(stranded);
      final before = await host.reread(stranded.workItemId);

      final item = await host.ensurePersistedWithoutWalk(
        host.defect('d-14'),
      );

      expect(item.qaContractId, isNotNull);
      expect(
        await host.qaContracts.readQAContract(item.qaContractId!),
        isNotNull,
      );
      expect(item.state, before.state);
      expect(host.count('triage.qa_contract.backfilled'), 1);
      expect(host.count('triage.qa_contract.provisioned'), 1);
      expect(
        await host.acceptedKeys(item.workItemId),
        isEmpty,
        reason:
            'this store has never seen this work item before this call, so an '
            'empty transition history is the proof that repairing a stranded '
            'row is a metadata write and not a walk. The three hops belong to '
            'the walking entry point alone.',
      );
    });

    test(
      'a replay after a completed walk adds no transitions and no item',
      () async {
        final host = _Host();
        await host.ensurePersisted(host.defect('d-15'));
        final afterFirst = await host.reread(defectTriageWorkItemId('d-15'));

        await host.ensurePersistedWithoutWalk(host.defect('d-15'));
        await host.ensurePersisted(host.defect('d-15'));

        final afterReplays = await host.reread(defectTriageWorkItemId('d-15'));
        expect(afterReplays.state, WorkItemState.designNotRequired);
        expect(afterReplays.version, afterFirst.version);
        expect(await host.allItems(), hasLength(1));
        expect(
          await host.acceptedKeys(defectTriageWorkItemId('d-15')),
          hasLength(3),
        );
      },
    );

    test('two different defects get two different work items', () async {
      final host = _Host();

      await host.ensurePersistedWithoutWalk(host.defect('d-16'));
      await host.ensurePersistedWithoutWalk(host.defect('d-17'));

      expect(await host.allItems(), hasLength(2));
      expect(
        (await host.allItems()).map((i) => i.workItemId).toSet(),
        {defectTriageWorkItemId('d-16'), defectTriageWorkItemId('d-17')},
      );
    });
  });

  group('product-agnosticism', () {
    test('the file names no product, no environment variable and no filesystem '
        'path', () async {
      final source = await _laneASource();
      for (final forbidden in const ['shipit', 'SHIPIT', 'ShipIt']) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason:
              'lane_a_defect_triage_work_item.dart must not name this '
              'deployment anywhere',
        );
      }
      expect(
        RegExp(r'SHIPIT_[A-Z_]+|Platform\.environment').hasMatch(source),
        isFalse,
        reason:
            'product identity is resolved from defect.affectedWorkItemId at '
            'call time — no default, no fallback, no environment lookup',
      );
      expect(
        _absolutePathLiteral.hasMatch(source),
        isFalse,
        reason: 'no hardcoded filesystem path',
      );
    });

    test(
      'the non-walking entry point delegates rather than re-deriving',
      () async {
        final source = await _laneASource();
        final body = _bodyOf(
          source,
          'Future<WorkItem> ensurePersistedWithoutWalk({',
        );
        expect(
          body,
          isNotNull,
          reason:
              'the member must exist; a guard that scans nothing must not '
              'read as a pass',
        );
        expect(body, contains('_persist(defect, evidenceJson)'));
        expect(
          body,
          isNot(contains('createWorkItem')),
          reason: 'creating is the shared half; a second create is the drift',
        );
        expect(
          body,
          isNot(contains('_advanceToTriageable')),
          reason: 'this entry point exists to NOT walk',
        );
      },
    );
  });
}

/// How many times [needle] occurs in [source].
int _occurrences(String source, String needle) =>
    needle.allMatches(source).length;

/// A single-quoted or double-quoted string literal that begins with a slash.
///
/// The design's §9 rule names three things this file must never contain: this
/// product's name, an environment lookup, and a hardcoded filesystem path. A
/// path is the one that is easy to add by accident — a log message quoting a
/// default directory, a comment quoting a CLI invocation — and easy to miss in
/// review, because it looks like prose.
final RegExp _absolutePathLiteral = RegExp("['\"]/[^'\"]*['\"]");

/// The source of `lane_a_defect_triage_work_item.dart`, located through package
/// resolution rather than through the working directory.
///
/// A gate that passes because it read the wrong file is worse than no gate,
/// and `dart test` may be invoked from anywhere in the workspace — so if this
/// library's own URI cannot be resolved, it refuses rather than guessing.
Future<String> _laneASource() async {
  final resolved = await Isolate.resolvePackageUri(
    Uri.parse(
      'package:control_plane_server/src/triage/'
      'lane_a_defect_triage_work_item.dart',
    ),
  );
  if (resolved == null) {
    throw StateError(
      'could not resolve package:control_plane_server; the '
      'product-agnosticism gate refuses to read a guessed path',
    );
  }
  final file = File.fromUri(resolved);
  if (!file.existsSync()) {
    throw StateError('resolved $resolved but it does not exist');
  }
  return file.readAsString();
}

/// The source text of the member declaration starting at [declaration], from
/// its opening line through the `}` that closes its body.
///
/// Scoped to ONE declaration rather than to the whole file, because a
/// whole-file grep for a forbidden literal fails for reasons that have nothing
/// to do with the guard: a doc comment that *explains* the shape contains the
/// shape, and saying so is correct documentation.
///
/// It ends at the MATCHING brace rather than at the first `;`. A member body
/// is several statements long, so stopping at the first one scans a prefix and
/// nothing more — and a forbidden call placed second then reads as absent. That
/// is a guard passing vacuously, which is worse than no guard: it reports the
/// absence of a defect it never looked at.
///
/// Returns null when [declaration] is absent, so a caller that guards on
/// "contains no literal" also fails when the member moved — a guard that finds
/// nothing to scan must not read as a pass. A member with no brace-delimited
/// body at all — an expression-bodied rewrite, say — has no body text to
/// return, and is reported the same way: loudly, not as a clean scan.
String? _bodyOf(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) return null;
  final close = _closingBraceOfBody(source, start);
  if (close < 0) return null;
  return source.substring(start, close + 1);
}

/// The index of the `}` that closes the body of the member whose text begins at
/// [start], or -1 when there is no such brace.
///
/// The body's `{` is the first one *outside* the parameter list, so the scan
/// counts parentheses until the signature is done — otherwise a named-parameter
/// block would be read as the body. Inside the body every brace is counted,
/// and string literals and comments are stepped over so that a brace in either
/// cannot close the body early and shorten the scan back to a prefix.
int _closingBraceOfBody(String source, int start) {
  var index = start;
  var parens = 0;
  var depth = 0;
  var inBody = false;

  while (index < source.length) {
    final char = source[index];

    if (char == '/' && index + 1 < source.length) {
      if (source[index + 1] == '/') {
        final newline = source.indexOf('\n', index);
        index = newline < 0 ? source.length : newline;
        continue;
      }
      if (source[index + 1] == '*') {
        final end = source.indexOf('*/', index + 2);
        index = end < 0 ? source.length : end + 2;
        continue;
      }
    }
    if (char == "'" || char == '"') {
      index = _endOfStringLiteral(source, index);
      continue;
    }

    if (char == '{' && (inBody || parens == 0)) {
      inBody = true;
      depth++;
    } else if (char == '}' && inBody) {
      depth--;
      if (depth == 0) return index;
    } else if (char == '(' && !inBody) {
      parens++;
    } else if (char == ')' && !inBody) {
      parens--;
    }
    index++;
  }
  return -1;
}

/// The index just past the string literal that opens at [quote].
///
/// Handles the triple-quoted forms, backslash escapes, and raw strings, where a
/// backslash is an ordinary character rather than the start of an escape.
int _endOfStringLiteral(String source, int quote) {
  final char = source[quote];
  final delimiter = source.startsWith(char * 3, quote) ? char * 3 : char;
  final raw = _hasRawPrefix(source, quote);

  var index = quote + delimiter.length;
  while (index < source.length) {
    if (!raw && source[index] == r'\') {
      index += 2;
      continue;
    }
    if (source.startsWith(delimiter, index)) return index + delimiter.length;
    index++;
  }
  return source.length;
}

/// Whether the string literal opening at [quote] carries an `r`/`R` prefix.
bool _hasRawPrefix(String source, int quote) {
  var index = quote - 1;
  while (index >= 0 && _letter.hasMatch(source[index])) {
    index--;
  }
  if (index == quote - 1) return false;
  return source[index] == 'r' || source[index] == 'R';
}

/// One ASCII letter — the run that can precede a quote as a string prefix.
final RegExp _letter = RegExp('[a-zA-Z]');

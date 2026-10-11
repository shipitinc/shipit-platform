import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/triage/defect_triage_sweep.dart';
import 'package:control_plane_server/src/triage/work_entry.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show
        DefectStore,
        InMemoryHumanDecisionStore,
        InMemoryProductRegistryStore,
        ProductRegistryEngine;
import 'package:qa_orchestration/qa_orchestration.dart'
    show triageWorkItemCategory;
import 'package:scheduler/scheduler.dart' show InMemoryJobStore;
import 'package:workflow_engine/workflow_engine.dart' show WorkflowEngine;
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// Two product ids that are obviously not this product's, used so no test can
/// accidentally pass because it agreed with a real one.
const String kProduct = 'product-under-test';
const String kOtherProduct = 'a-different-product';

/// A description long enough to satisfy the human-facing work-item contract,
/// and different from the title, which the same contract requires.
const String kDescription =
    'A human-filed request describing the behaviour that was observed.';
const String kTitle = 'Observed behaviour is not what the request expected';

final DateTime _now = DateTime.utc(2026, 4, 1);

String _workItemIdOf(String defectId) =>
    WorkEntryTrigger.triageWorkItemIdForDefect(defectId);

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// A [DefectStore] holding only what this sweep reads.
///
/// Everything outside the sweep's path is [UnimplementedError] rather than a
/// plausible default: a fake that quietly answers a call the production store
/// would refuse can turn a gate into a decoration. [listDefects] is the whole
/// surface, and it carries the two fault shapes the suite needs — a read that
/// throws (anti-wedge) and a read that parks (overlap).
class _FakeDefectStore implements DefectStore {
  _FakeDefectStore([List<Defect> seed = const []]) {
    for (final defect in seed) {
      _defects[defect.defectId] = defect;
    }
  }

  final Map<String, Defect> _defects = {};

  /// Thrown by [listDefects] while set, then cleared. Exactly the shape that
  /// aborts a whole pass, because it runs before the loop.
  Object? listFault;

  /// Completes once [listDefects] has been ENTERED.
  final Completer<void> entered = Completer<void>();

  /// Releases a parked [listDefects].
  final Completer<void> release = Completer<void>();

  /// When true, [listDefects] parks on [release] after signalling [entered].
  bool parks = false;

  int listCalls = 0;

  void put(Defect defect) => _defects[defect.defectId] = defect;

  @override
  Future<List<Defect>> listDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
    int? limit,
    int? offset,
  }) async {
    listCalls++;
    if (!entered.isCompleted) entered.complete();
    if (parks) await release.future;
    final fault = listFault;
    if (fault != null) {
      listFault = null;
      throw fault;
    }
    // `productId` filters against the DEFECT's own column here, which is NOT
    // how the production store filters (it joins through `affectedWorkItemId`).
    // The divergence is deliberate and safe: the sweep never passes a product
    // filter — it is product-agnostic and walks every defect — so no assertion
    // in this file can be decided by the difference.
    var rows = _defects.values.where((defect) {
      if (productId != null && defect.productId != productId) return false;
      if (status != null && defect.status != status) return false;
      if (classification != null && defect.classification != classification) {
        return false;
      }
      return true;
    }).toList();
    if (offset != null) rows = rows.skip(offset).toList();
    if (limit != null) rows = rows.take(limit).toList();
    return rows;
  }

  @override
  Future<void> saveDefect(Defect defect, {int? expectedVersion}) async =>
      _defects[defect.defectId] = defect;

  @override
  Future<Defect> readDefect(String defectId) async {
    final defect = _defects[defectId];
    if (defect == null) {
      throw StateError('no such defect $defectId in this fake');
    }
    return defect;
  }

  @override
  Future<int> countDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
  }) => throw UnimplementedError('countDefects is not on the sweep path');

  @override
  Future<void> saveDefectEvidence(DefectEvidence evidence) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<List<DefectEvidence>> readEvidenceForDefect(String defectId) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<void> appendDefectEvent(DefectEvent event) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<List<DefectEvent>> readEventsForDefect(String defectId) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<void> saveClarification(DefectClarification clarification) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<DefectClarification?> readClarification(String clarificationId) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<List<DefectClarification>> readClarificationsForDefect(
    String defectId,
  ) => throw UnimplementedError('not on the sweep path');

  @override
  Future<void> setTriageJob(String defectId, String? jobId) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<void> saveTriageResult(
    TriageResult result, {
    int? expectedVersion,
  }) => throw UnimplementedError('not on the sweep path');

  @override
  Future<TriageResult?> readTriageResult(String resultId) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<List<TriageResult>> readTriageResultsForDefect(String defectId) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<TriageResult?> readTriageResultForJob(String jobId) =>
      throw UnimplementedError('not on the sweep path');

  @override
  Future<T> inTransaction<T>(Future<T> Function(DefectStore store) body) =>
      body(this);
}

/// A workflow store that answers, but can be told to fail or to park for one
/// work item.
///
/// Extends the in-memory store rather than decorating it so every OTHER member
/// stays the real implementation: a decorator would have to forward the whole
/// `WorkflowStore` surface by hand, and a hand-forwarded store is a second
/// graph the durable engine and the trigger could disagree about.
class _FaultingWorkflowStore extends InMemoryWorkflowStore {
  /// workItemId -> what to raise instead of answering, consumed once.
  final Map<String, Object> faults = {};

  /// workItemId -> hold the read open until released.
  final Map<String, Completer<void>> parked = {};

  /// workItemId -> completes when that read is entered.
  final Map<String, Completer<void>> entered = {};

  int readCalls = 0;

  @override
  Future<WorkItem> readWorkItem(String workItemId) async {
    readCalls++;
    final gate = entered[workItemId];
    if (gate != null && !gate.isCompleted) gate.complete();
    final hold = parked[workItemId];
    if (hold != null) await hold.future;
    final fault = faults.remove(workItemId);
    if (fault != null) throw fault;
    return super.readWorkItem(workItemId);
  }
}

/// A registry engine that COUNTS every read that could touch a credential.
///
/// The regression this guards is not "the sweep is slow". It is that the
/// baseline lane resolved a pinned revision on every pass, and resolving one
/// runs `CredentialKeyService.verifyAccess`, which WRITES the credential row
/// twice — so each pass bumped the version the next pass's compare-and-swap
/// asserted, and the sweep guaranteed its own conflict for 41 passes without
/// ever reaching an enqueue.
///
/// The count is STRUCTURAL rather than documentary because of two things
/// working together. First, this engine is the only object through which the
/// sweep could reach a credential at all — the sweep is handed a defect store
/// and a trigger, and the trigger's one registry call is `readProduct`. Second,
/// [productReads] — which the sweep legitimately does move — shares the same
/// counter block, so a pass that reads products and no credentials is
/// demonstrably counting rather than sitting at a zero nobody wired.
class _CountingRegistryEngine extends ProductRegistryEngine {
  _CountingRegistryEngine({
    required super.store,
    required super.humanDecisionStore,
  });

  /// Legitimate, expected to be non-zero. This is the counter that proves the
  /// others are live rather than dead.
  int productReads = 0;

  /// Everything that answers "can this platform reach that repository?" or
  /// records an attempt to. All of it must stay at zero.
  int credentialReads = 0;
  int credentialWrites = 0;
  int repositoryReads = 0;
  int baselineReads = 0;

  /// THE number. One acquisition in the baseline lane cost a real SSH clone and
  /// two credential writes; one here would cost nothing at all, because this
  /// sweep has no way to perform one.
  int get acquisitions =>
      credentialReads + credentialWrites + repositoryReads + baselineReads;

  @override
  Future<Product> readProduct(String productId) {
    productReads++;
    return super.readProduct(productId);
  }

  @override
  Future<RepositoryCredential?> readActiveCredential(
    String productId,
    String repositoryId,
  ) {
    credentialReads++;
    return super.readActiveCredential(productId, repositoryId);
  }

  @override
  Future<List<RepositoryCredential>> readCredentials(String productId) {
    credentialReads++;
    return super.readCredentials(productId);
  }

  @override
  Future<List<RepositoryReference>> readRepositories(String productId) {
    repositoryReads++;
    return super.readRepositories(productId);
  }

  @override
  Future<List<ProductBaseline>> readBaselines(String productId) {
    baselineReads++;
    return super.readBaselines(productId);
  }

  @override
  Future<RepositoryCredential> confirmHostKey({
    required String productId,
    required String credentialId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    DateTime? now,
  }) {
    credentialWrites++;
    return super.confirmHostKey(
      productId: productId,
      credentialId: credentialId,
      hostKeyFingerprint: hostKeyFingerprint,
      confirmedBy: confirmedBy,
      now: now,
    );
  }

  @override
  Future<RepositoryCredential> recordCredentialCheck({
    required String productId,
    required String credentialId,
    required bool succeeded,
    required String checkedBy,
    String? failureReason,
    DateTime? now,
  }) {
    credentialWrites++;
    return super.recordCredentialCheck(
      productId: productId,
      credentialId: credentialId,
      succeeded: succeeded,
      checkedBy: checkedBy,
      failureReason: failureReason,
      now: now,
    );
  }
}

// ---------------------------------------------------------------------------
// The host
// ---------------------------------------------------------------------------

/// Every store and engine one pass needs, so a test reads as a scenario rather
/// than as wiring.
class _Host {
  _Host([List<Defect> defects = const []])
    : defectStore = _FakeDefectStore(defects) {
    registryEngine = _CountingRegistryEngine(
      store: registryStore,
      humanDecisionStore: InMemoryHumanDecisionStore(),
    );
    workflowEngine = DurableWorkflowEngine(
      store: store,
      policy: const WorkflowEngine(),
    );
    trigger = WorkEntryTrigger(
      workflowStore: store,
      workflowEngine: workflowEngine,
      productRegistryEngine: registryEngine,
      jobStore: jobStore,
      log: (event, fields) => events.add((event, fields)),
    );
    sweep = DefectTriageSweep(
      defectStore: defectStore,
      trigger: trigger,
      log: (event, fields) => events.add((event, fields)),
    );
  }

  final _FakeDefectStore defectStore;

  /// Bound to [store] deliberately: a second in-memory store would make every
  /// assertion in this file pass against a graph nothing else can see.
  final _FaultingWorkflowStore store = _FaultingWorkflowStore();

  final InMemoryJobStore jobStore = InMemoryJobStore();
  final InMemoryProductRegistryStore registryStore =
      InMemoryProductRegistryStore();
  final List<(String, Map<String, dynamic>)> events = [];

  late final _CountingRegistryEngine registryEngine;
  late final DurableWorkflowEngine workflowEngine;
  late final WorkEntryTrigger trigger;
  late final DefectTriageSweep sweep;

  /// Registers [productId] in the exact state asked for, without a baseline
  /// decision ceremony.
  ///
  /// Writing the state directly is the point: this suite is about what the
  /// sweep DOES with a product state, and a test that had to govern a product
  /// through its real governance path to observe the refusal would be testing
  /// the registry instead.
  Future<void> putProduct(String productId, ProductState state) =>
      registryStore.saveProduct(
        Product(
          productId: productId,
          name: 'A product',
          state: state,
          createdAt: _now,
          updatedAt: _now,
          version: 1,
        ),
      );

  Future<void> putGovernedProduct([String productId = kProduct]) =>
      putProduct(productId, ProductState.governed);

  /// Files a defect the way human bug reporting does.
  static Defect defect(
    String defectId, {
    DefectStatus status = DefectStatus.reported,
    String productId = kProduct,
  }) => Defect(
    defectId: defectId,
    title: kTitle,
    description: kDescription,
    severity: 'high',
    status: status,
    reporter: 'a-person@example.invalid',
    productId: productId,
    createdAt: _now,
    updatedAt: _now,
    version: 1,
  );

  /// Opens a defect's triage work item the way lane A does: id `defect-{id}`,
  /// category `triageWorkItemCategory`, and the defect as its requirement
  /// reference so the `planning -> planned` guard can be satisfied.
  Future<WorkItem> openDefectTriageItem(
    String defectId, {
    String productId = kProduct,
  }) => workflowEngine.createWorkItem(
    workItemId: _workItemIdOf(defectId),
    productId: productId,
    category: triageWorkItemCategory,
    title: kTitle,
    description: kDescription,
    featureRef: defectId,
  );

  /// A reported defect with its work item, ready to be swept.
  Future<void> seed(String defectId, {String productId = kProduct}) async {
    defectStore.put(defect(defectId, productId: productId));
    await openDefectTriageItem(defectId, productId: productId);
  }

  Future<List<Job>> jobsFor(String defectId) =>
      jobStore.listJobsForWorkItem(_workItemIdOf(defectId));

  Future<List<Job>> allJobs() => jobStore.listJobs();

  /// Every event this sweep itself emitted, in order — so "visible" is asserted
  /// on the log an operator greps rather than on a return value a caller may
  /// never print.
  List<(String, Map<String, dynamic>)> get sweepEvents =>
      events.where((e) => e.$1.startsWith('work_entry.sweep.')).toList();

  List<(String, Map<String, dynamic>)> eventsNamed(String event) =>
      events.where((e) => e.$1 == event).toList();
}

void main() {
  group('the recovery this sweep exists for', () {
    test(
      'a defect gated on an ungoverned product is enqueued once the product is '
      'governed',
      () async {
        final host = _Host();
        await host.seed('d-1');
        await host.putProduct(kProduct, ProductState.registered);

        final gated = await host.sweep.run();

        expect(gated.considered, 1);
        expect(gated.enqueued, isEmpty);
        expect(
          gated.skipped.single.code,
          WorkEntrySkipCodes.productNotGoverned,
        );
        expect(gated.skipped.single.defectId, 'd-1');
        expect(
          gated.skipped.single.reason,
          contains('NOT rejected'),
          reason: 'the reason must say the defect was not refused',
        );
        expect(
          gated.skipped.single.reason,
          contains(ProductState.registered.wire),
          reason: 'the reason names the state an operator re-checks against',
        );
        expect(await host.allJobs(), isEmpty);
        // And it was NOT walked into an entry state either. The scheduler is
        // category-blind AND product-state-blind, so an item at
        // `designNotRequired` would be dispatched whatever this sweep decided.
        expect(
          (await host.store.readWorkItem(_workItemIdOf('d-1'))).state,
          WorkItemState.draft,
        );

        // THE POINT. The product reaches `governed` — the only thing that was
        // ever missing — and the very next pass dispatches it. No human, no
        // retry flag, no operator action.
        await host.putGovernedProduct();

        final dispatched = await host.sweep.run();

        expect(dispatched.enqueued, hasLength(1));
        expect(dispatched.enqueued.single.defectId, 'd-1');
        expect(dispatched.enqueued.single.workItemId, _workItemIdOf('d-1'));
        expect(dispatched.skipped, isEmpty);
        expect(await host.jobsFor('d-1'), hasLength(1));
      },
    );

    test(
      'a defect on a still-ungoverned product is skipped with '
      'PRODUCT_NOT_GOVERNED and nothing is enqueued',
      () async {
        // Its own case because it is the negative the design names as an
        // acceptance criterion: the sweep must not become a way round the gate.
        // `ProductState`'s own text is the reason each of these is here —
        // `paused` says "the scheduler will not dispatch new work",
        // `archived` says "no new work can be created or dispatched".
        for (final state in const [
          ProductState.registered,
          ProductState.baselinePending,
          ProductState.baselineBlocked,
          ProductState.baselineReview,
          ProductState.paused,
          ProductState.archived,
        ]) {
          final host = _Host();
          await host.seed('d-1');
          await host.putProduct(kProduct, state);

          final result = await host.sweep.run();

          expect(
            result.skipped.single.code,
            WorkEntrySkipCodes.productNotGoverned,
            reason: 'a ${state.wire} product must not dispatch work',
          );
          expect(result.enqueued, isEmpty);
          expect(await host.allJobs(), isEmpty);
          expect(result.incidents, isEmpty);
          expect(
            result.skipped.single.reason,
            contains(state.wire),
            reason: 'the reason names the state an operator re-checks against',
          );
        }
      },
    );

    test(
      'a defect whose product has no registry row is named, not assumed',
      () async {
        // "Not governed" is a state a product can leave; "no such product" is an
        // absence this sweep cannot resolve. Reporting one as the other tells an
        // operator to wait for a product that does not exist.
        final host = _Host();
        await host.seed('d-1');

        final result = await host.sweep.run();

        expect(
          result.skipped.single.code,
          WorkEntrySkipCodes.productNotInRegistry,
        );
        expect(result.skipped.single.reason, contains(kProduct));
        expect(await host.allJobs(), isEmpty);
      },
    );
  });

  group('the predicate, conjunct by conjunct', () {
    test(
      'a defect with a non-terminal triage job is skipped, not duplicated',
      () async {
        final host = _Host();
        await host.seed('d-1');
        await host.putGovernedProduct();

        // Intake enqueued; that job is `queued`, which is NOT terminal.
        expect((await host.sweep.run()).enqueued, hasLength(1));

        final second = await host.sweep.run();

        expect(
          second.skipped.single.code,
          WorkEntrySkipCodes.triageAlreadyActive,
        );
        expect(second.skipped.single.defectId, 'd-1');
        expect(
          second.skipped.single.reason,
          contains('queued'),
          reason: 'the reason must name the state the job it found is in',
        );
        expect(
          await host.jobsFor('d-1'),
          hasLength(1),
          reason: 'the second pass must not mint a second job',
        );
      },
    );

    test(
      'a defect with no work item records workItemMissing and does not invent '
      'one',
      () async {
        final host = _Host();
        host.defectStore.put(_Host.defect('d-orphan'));
        await host.putGovernedProduct();

        final result = await host.sweep.run();

        expect(result.considered, 1);
        expect(result.skipped.single.code, WorkEntrySkipCodes.workItemMissing);
        expect(result.skipped.single.defectId, 'd-orphan');
        expect(
          result.skipped.single.reason,
          contains('DefectTriageWorkItemProvisioner'),
          reason:
              'the skip must say WHO has to run. A record naming only the '
              'absence would leave an operator to guess, and guessing is the '
              'thing this guard exists to prevent',
        );
        expect(
          result.skipped.single.reason,
          contains('NOT repaired'),
          reason:
              'the reason must state that the sweep refuses to synthesise the '
              'row, so nobody later reads the absence as an oversight',
        );
        expect(
          result.skipped.single.reason,
          contains(_workItemIdOf('d-orphan')),
        );

        // THE load-bearing half: nothing was created.
        expect(await host.allJobs(), isEmpty);
        expect(
          await host.store.readAllWorkItems(),
          isEmpty,
          reason:
              'a work item synthesised here would carry a guessed product, '
              'category and reference, and would then read as a fact',
        );
        expect(result.incidents, isEmpty, reason: 'absent is not a failure');

        // And it is visible in the log under its own event, so the absence is
        // greppable rather than inferred from a count.
        final logged = host.eventsNamed('work_entry.sweep.work_item_missing');
        expect(logged, hasLength(1));
        expect(logged.single.$2['defectId'], 'd-orphan');
        expect(
          logged.single.$2['action'],
          contains('DefectTriageWorkItemProvisioner'),
        );
      },
    );

    test('defects outside the triagable set are never considered', () async {
      final host = _Host();
      await host.putGovernedProduct();
      for (final status in const [
        DefectStatus.confirmed,
        DefectStatus.remediationPlanned,
        DefectStatus.fixInProgress,
        DefectStatus.fixReadyForVerification,
        DefectStatus.resolved,
        DefectStatus.closed,
        DefectStatus.duplicate,
        DefectStatus.notReproducible,
      ]) {
        host.defectStore.put(_Host.defect('d-${status.wire}', status: status));
        await host.openDefectTriageItem('d-${status.wire}');
      }

      final result = await host.sweep.run();

      expect(result.considered, 0);
      expect(result.skipped, isEmpty);
      expect(result.enqueued, isEmpty);
    });

    test('every triagable status IS considered', () async {
      // The other direction, because a set that accidentally lost a member
      // strands exactly the defects that most need recovery — and a set that
      // accidentally GAINED one would re-enqueue work that was already
      // decided. Both directions are pinned.
      for (final status in DefectTriageSweep.triagableStatuses) {
        final host = _Host();
        await host.seed('d-1');
        await host.putGovernedProduct();
        host.defectStore.put(_Host.defect('d-1', status: status));

        expect(
          (await host.sweep.run()).enqueued,
          hasLength(1),
          reason: '$status must be swept',
        );
      }
    });

    test('the triagable set is statuses, never product ids', () {
      expect(
        DefectTriageSweep.triagableStatuses.every(
          (status) => DefectStatus.values.contains(status),
        ),
        isTrue,
      );
      expect(DefectTriageSweep.triagableStatuses, isNotEmpty);
    });
  });

  group('per-defect isolation', () {
    test('one defect throwing does not abandon the rest of the pass', () async {
      final host = _Host();
      for (final id in ['d-a', 'd-bad', 'd-c']) {
        await host.seed(id);
      }
      await host.putGovernedProduct();
      host.store.faults[_workItemIdOf('d-bad')] = StateError(
        'the work item read failed',
      );

      final result = await host.sweep.run();

      // Nothing after the failure was abandoned.
      expect(
        result.enqueued.map((e) => e.defectId),
        unorderedEquals(['d-a', 'd-c']),
        reason:
            'a defect whose read threw must not delete the work of every '
            'defect after it — that is the silent-delete failure this guard '
            'exists for',
      );
      expect(result.incidents.map((i) => i.defectId), ['d-bad']);
      expect(result.considered, 3);
      expect(
        result.accountedFor,
        result.considered,
        reason: 'every considered defect is either decided or recorded',
      );

      // The incident is LOGGED, with everything an operator needs.
      final incident = host
          .eventsNamed('work_entry.sweep.defect_incident')
          .single;
      expect(incident.$2['defectId'], 'd-bad');
      expect(incident.$2['status'], DefectStatus.reported.wire);
      expect(
        incident.$2['code'],
        DefectTriageSweepIncidentCodes.evaluationFailed,
      );
      expect(
        incident.$2['error'],
        contains('the work item read failed'),
        reason: 'the error must name what went wrong',
      );
      expect(incident.$2['stack'], isA<String>());
      expect((incident.$2['stack']! as String), isNotEmpty);
      expect(
        incident.$2['action'],
        contains('the rest of the pass continued'),
        reason: 'the line must say what was done about it',
      );
    });

    test('an incident is not a skip, and not a silent absence', () async {
      final host = _Host();
      await host.seed('d-bad');
      await host.putGovernedProduct();
      host.store.faults[_workItemIdOf('d-bad')] = StateError('boom');

      final result = await host.sweep.run();

      expect(result.skipped, isEmpty);
      expect(result.enqueued, isEmpty);
      expect(result.incidents, hasLength(1));
      expect(
        result.incidents.single.code,
        DefectTriageSweepIncidentCodes.evaluationFailed,
      );
      expect(
        result.incidents.single.reason,
        contains('boom'),
        reason: 'the incident carries the error, not a bare count',
      );
    });
  });

  group('re-entrancy, and a dropped tick that stays visible', () {
    test(
      'two concurrent runs yield ONE pass and ONE visible record of it',
      () async {
        // `Timer.periodic` does not await its callback, so this overlap is the
        // ORDINARY case in production, not a race to be arranged. The pass is
        // HELD OPEN rather than raced, so the overlap is a fact.
        final host = _Host();
        await host.seed('d-1');
        await host.putGovernedProduct();
        host.defectStore.parks = true;

        // THE CALLER'S TURN — the property [DefectTriageSweep.run]'s non-`async`
        // signature exists to make compiler-enforced: the guard is taken, and the
        // pass ENTERED, before `run()` returns to its caller. Nothing is awaited
        // above the guard, because nothing CAN be — `await` is illegal in a
        // non-`async` function.
        //
        // NOTE WHAT THIS DOES NOT CLAIM. It does not distinguish the non-`async`
        // form from an `async` one: an `async` body also starts synchronously in
        // Dart, so the same assertion passes either way. It pins the INVARIANT
        // (`run()` never returns before it has decided), and it would fail the
        // moment anyone inserted an `await` above the guard. What actually
        // distinguishes the two signatures is that the insertion is a compile
        // error rather than a silent regression — which no runtime assertion can
        // observe, and which is why the choice belongs in the signature.
        final first = host.sweep.run();
        expect(
          host.defectStore.listCalls,
          1,
          reason:
              'the pass began in the caller\'s turn, so a caller holding this '
              'future is holding a decision, not a pending intention',
        );

        final dropped = await host.sweep.run();

        // One pass ran. The dropped tick evaluated nothing.
        expect(dropped.overlappedPasses, 1);
        expect(dropped.considered, 0);
        expect(dropped.enqueued, isEmpty);
        expect(dropped.skipped, isEmpty);
        expect(
          dropped.incidents,
          isEmpty,
          reason:
              'a dropped tick is not a defect failure. Filing it as one would '
              'invent a defect nobody looked at — the exact mistake the baseline '
              'lane documents.',
        );
        expect(
          host.defectStore.listCalls,
          1,
          reason: 'the dropped tick must not read anything either',
        );

        // VISIBLE, on its own event, exactly once.
        final overlaps = host.eventsNamed('work_entry.sweep.pass_overlapped');
        expect(overlaps, hasLength(1));
        expect(overlaps.single.$2['overlappedPasses'], 1);
        expect(overlaps.single.$2['code'], sweepPassOverlappedCode);
        expect(
          overlaps.single.$2['action'],
          contains('already in flight'),
          reason:
              'a dropped tick that only says "considered 0" is '
              'indistinguishable from a tick that found nothing to do, which is '
              'the shape of "the sweep is not running"',
        );

        // AND on the `completed` line, so every pass leaves one shape.
        final completed = host.eventsNamed('work_entry.sweep.completed');
        expect(completed, hasLength(1));
        expect(completed.single.$2['overlappedPasses'], 1);
        expect(completed.single.$2['code'], sweepPassOverlappedCode);

        host.defectStore.parks = false;
        host.defectStore.release.complete();
        final completedPass = await first;

        expect(completedPass.enqueued, hasLength(1));
        expect(completedPass.overlappedPasses, 0);
        expect(
          host.defectStore.listCalls,
          1,
          reason:
              'still one. The dropped tick returned before it read anything, so '
              'the completed pass is the only pass that touched the store — which '
              'is the point: dropping a tick costs nothing and hides nothing.',
        );
        expect(await host.allJobs(), hasLength(1));
      },
      // A SHORT timeout, deliberately. Without the guard the second `run()`
      // above would enter the pass and park on the same release — so the
      // failure mode of a missing guard is a DEADLOCK, and this turns it back
      // into a reported failure rather than a hung suite.
      timeout: Timeout(Duration(seconds: 10)),
    );

    test(
      'every completed line carries overlappedPasses, including zero',
      () async {
        final host = _Host();
        await host.seed('d-1');
        await host.putGovernedProduct();

        await host.sweep.run();
        await host.sweep.run();

        final completed = host.eventsNamed('work_entry.sweep.completed');
        expect(completed, hasLength(2));
        for (final line in completed) {
          expect(
            line.$2.containsKey('overlappedPasses'),
            isTrue,
            reason:
                'a pass that reports nothing but counts looks identical to a '
                'pass that never ran. The field is present so the two differ, so '
                'it is present even when it is zero.',
          );
          expect(line.$2['overlappedPasses'], 0);
        }
      },
    );

    test(
      'a pass that throws still releases the guard — the anti-wedge property',
      () async {
        // The failure the per-defect guard CANNOT absorb: `listDefects` runs
        // before the loop, so it aborts the whole pass and propagates out of
        // `run()`. A guard released only on success would then be held for ever,
        // and every later tick would report itself as "overlapping" against a
        // pass that ended minutes ago — a sweep that looks busy and is
        // permanently stopped.
        final host = _Host();
        await host.seed('d-1');
        await host.putGovernedProduct();
        host.defectStore.listFault = StateError('the defect table is down');

        await expectLater(
          host.sweep.run(),
          throwsA(isA<StateError>()),
          reason: 'the error propagates untouched, so the caller sees it',
        );

        // The next tick is a REAL pass, not a dropped one.
        final recovered = await host.sweep.run();

        expect(
          recovered.overlappedPasses,
          0,
          reason: 'the guard was released on the failure path',
        );
        expect(recovered.considered, 1);
        expect(recovered.enqueued, hasLength(1));

        final completed = host.eventsNamed('work_entry.sweep.completed');
        expect(completed, hasLength(1));
        expect(completed.single.$2['overlappedPasses'], 0);
        expect(host.eventsNamed('work_entry.sweep.pass_overlapped'), isEmpty);
      },
    );

    test('a failed pass emits no completed line for itself', () async {
      // Honesty about what is reported: a pass that threw has NOT completed,
      // and printing a `completed` line for it would assert a decision the
      // pass never made. The tick owns that line — see the try/catch on the
      // timer in `server.dart`.
      final host = _Host();
      host.defectStore.listFault = StateError('the defect table is down');

      await expectLater(host.sweep.run(), throwsA(isA<StateError>()));

      expect(host.eventsNamed('work_entry.sweep.completed'), isEmpty);
      expect(host.sweepEvents, isEmpty);
    });
  });

  group('the sweep cannot livelock against itself', () {
    // The regression guard for the failure that actually happened: 41 passes,
    // 22 incidents, 19 skips, zero enqueued, credential version 1 -> 59,
    // because every pass resolved a pinned revision through
    // `CredentialKeyService.verifyAccess`, which writes the credential row and
    // invalidates the next pass's compare-and-swap.

    test(
      'ZERO credential reads or writes, across enqueueing AND skipping passes',
      () async {
        final host = _Host();
        await host.putGovernedProduct(kProduct);
        await host.putProduct(kOtherProduct, ProductState.registered);
        for (final id in ['d-1', 'd-2']) {
          await host.seed(id);
        }
        // A defect filed against the ungoverned product — the gated path.
        await host.seed('d-gated', productId: kOtherProduct);
        // A defect with no work item at all — the cheap-absence path the
        // baseline lane would still have paid a clone for.
        host.defectStore.put(_Host.defect('d-orphan'));

        for (var pass = 0; pass < 5; pass++) {
          await host.sweep.run();
        }

        expect(
          host.registryEngine.acquisitions,
          0,
          reason:
              'ZERO. Not "no new job" — the acquisition count itself. An '
              'acquisition is what costs a clone, what WRITES the credential row, '
              'and what made each pass conflict with the next.',
        );
        expect(host.registryEngine.credentialWrites, 0);
        expect(host.registryEngine.credentialReads, 0);
        expect(host.registryEngine.repositoryReads, 0);
        expect(host.registryEngine.baselineReads, 0);
      },
    );

    test(
      'the counters are WIRED, so the zero above is not a vacuous zero',
      () async {
        // A guard that cannot fail is not a guard. This asserts the sweep DOES
        // ask the registry — the product gate — so the credential counters are
        // demonstrably live and their zero means something.
        final host = _Host();
        await host.seed('d-1');
        await host.putGovernedProduct();

        await host.sweep.run();

        expect(host.registryEngine.productReads, greaterThan(0));
        expect(host.registryEngine.acquisitions, 0);
      },
    );

    test(
      'the sweep source contains no acquisition, read past its comments',
      () async {
        // The counter above proves what THIS code does today. This proves what it
        // is ALLOWED to do, which is the difference that matters: the livelock
        // was introduced by code that was individually reasonable.
        final source = await _sweepSource();
        final code = _stripComments(source);

        // The strip is real. If it silently did nothing, every assertion below
        // would be scanning prose and could only ever fail for the wrong reason.
        expect(
          source.toLowerCase(),
          contains('credential'),
          reason:
              'the file explains the livelock, so the raw text has the word',
        );
        expect(
          code.toLowerCase(),
          isNot(contains('credential')),
          reason: 'after stripping, the word is gone, so the strip works',
        );

        for (final forbidden in const [
          'CredentialKeyService',
          'RepositorySnapshotAcquirer',
          'RepositoryAccessVerifier',
          'PinnedRevisionResolver',
          'SecretProvider',
          'verifyAccess',
          'confirmHostKey',
          'recordCredentialCheck',
          'readActiveCredential',
          'readCredentials',
          'readRepositories',
          'readBaselines',
          'Process.run',
          'HttpClient',
          'dart:io',
        ]) {
          expect(
            code.contains(forbidden),
            isFalse,
            reason:
                '`$forbidden` in the executable code would be an acquisition, and '
                'an acquisition is the livelock. Named so the prohibition is '
                'executable rather than aspirational.',
          );
        }
      },
    );

    test('the sweep is constructed from exactly two collaborators', () {
      // Structural, and it is the root of the guard above: there is no field
      // through which a clone, a credential or a git host could be reached. A
      // fourth required parameter would stop this file COMPILING — which is
      // the failure we want, rather than a runtime discovery in QA.
      final store = _FaultingWorkflowStore();
      final sweep = DefectTriageSweep(
        defectStore: _FakeDefectStore(),
        trigger: WorkEntryTrigger(
          workflowStore: store,
          workflowEngine: DurableWorkflowEngine(
            store: store,
            policy: const WorkflowEngine(),
          ),
          productRegistryEngine: _CountingRegistryEngine(
            store: InMemoryProductRegistryStore(),
            humanDecisionStore: InMemoryHumanDecisionStore(),
          ),
          jobStore: InMemoryJobStore(),
        ),
      );

      expect(sweep.defectStore, isA<DefectStore>());
      expect(sweep.trigger, isA<WorkEntryTrigger>());
    });

    test('nothing the sweep logs names a credential', () async {
      final host = _Host();
      await host.putGovernedProduct();
      await host.seed('d-1');
      // d-orphan produces the skip line; d-1 is enqueued. Together they
      // exercise both shapes of line the sweep emits.
      host.defectStore.put(_Host.defect('d-orphan'));
      host.store.faults[_workItemIdOf('d-1')] = StateError('boom');
      await host.sweep.run();

      expect(host.sweepEvents, isNotEmpty);
      for (final (event, data) in host.sweepEvents) {
        for (final value in data.values) {
          final text = '$value'.toLowerCase();
          expect(
            text.contains('ssh-'),
            isFalse,
            reason: '$event leaked key-shaped material',
          );
          expect(
            text.contains('credential'),
            isFalse,
            reason:
                '$event named a credential; nothing on this path can reach '
                'one, so a name could only have been invented',
          );
        }
      }
    });
  });

  group('idempotency', () {
    test('N passes with no state change enqueue exactly once', () async {
      final host = _Host();
      await host.seed('d-1');
      await host.putGovernedProduct();

      for (var pass = 0; pass < 5; pass++) {
        await host.sweep.run();
      }

      expect(
        await host.allJobs(),
        hasLength(1),
        reason: 'exactly one job, no matter how many passes ran',
      );
      expect(
        host.registryEngine.acquisitions,
        0,
        reason: 'and the passes that had nothing to do acquired nothing',
      );

      final last = await host.sweep.run();
      expect(last.enqueued, isEmpty);
      expect(last.skipped.single.code, WorkEntrySkipCodes.triageAlreadyActive);
    });

    test('every pass is accounted for', () async {
      final host = _Host();
      await host.putGovernedProduct();
      await host.seed('d-1');
      host.defectStore.put(_Host.defect('d-2'));
      host.defectStore.put(
        _Host.defect('d-closed', status: DefectStatus.closed),
      );

      final result = await host.sweep.run();

      expect(
        result.accountedFor,
        result.considered,
        reason:
            'a considered defect is either decided or recorded as an incident. '
            'A count that does not reconcile is how work disappears quietly.',
      );
      expect(result.considered, 2, reason: 'the closed one is out of scope');
      expect(result.enqueued, hasLength(1));
      expect(result.skipped, hasLength(1));
      expect(result.skipped.single.code, WorkEntrySkipCodes.workItemMissing);
    });
  });

  group('product-agnosticism', () {
    test(
      'the sweep names no product, no environment variable and no path',
      () async {
        final source = await _sweepSource();
        for (final forbidden in const ['shipit', 'SHIPIT', 'ShipIt']) {
          expect(
            source.contains(forbidden),
            isFalse,
            reason:
                'defect_triage_sweep.dart must not name this deployment anywhere; '
                '`$forbidden` is the design\'s own grep gate',
          );
        }
        expect(
          RegExp(r'SHIPIT_[A-Z_]+|Platform\.environment').hasMatch(source),
          isFalse,
          reason:
              'product identity is read from WorkItem.productId at call time — '
              'no default, no fallback, no environment lookup',
        );
        expect(
          _absolutePathLiteral.hasMatch(source),
          isFalse,
          reason: 'no hardcoded filesystem path',
        );
      },
    );

    test('the sweep reads EVERY product, and invents none', () async {
      // Product-agnosticism is not "no product names in the source" — it is
      // "no product is special". A sweep that filtered to one product would
      // pass the grep above and fail this one.
      final host = _Host();
      for (final product in const [kProduct, kOtherProduct]) {
        await host.seed('d-$product', productId: product);
      }
      await host.putGovernedProduct(kProduct);
      await host.putGovernedProduct(kOtherProduct);

      final result = await host.sweep.run();

      expect(
        result.enqueued.map((e) => e.defectId),
        unorderedEquals(['d-$kProduct', 'd-$kOtherProduct']),
      );
      expect(
        result.enqueued.map((e) => e.workItemId),
        everyElement(startsWith('defect-d-')),
      );
    });
  });
}

/// A single-quoted or double-quoted string literal that begins with a slash.
///
/// The design's §9 rule names three things this file must never contain: this
/// product's name, an environment lookup, and a hardcoded filesystem path. A
/// path is the one that is easy to add by accident — a log message quoting a
/// default directory, a comment quoting a CLI invocation — and easy to miss in
/// review, because it looks like prose.
final RegExp _absolutePathLiteral = RegExp("['\"]/[^'\"]*['\"]");

/// The source of `defect_triage_sweep.dart`, located through package
/// resolution rather than through the working directory.
///
/// A gate that passes because it read the wrong file is worse than no gate, and
/// `dart test` may be invoked from anywhere in the workspace — so if this
/// library's own URI cannot be resolved, it refuses rather than guessing.
Future<String> _sweepSource() async {
  final resolved = await Isolate.resolvePackageUri(
    Uri.parse(
      'package:control_plane_server/src/triage/defect_triage_sweep.dart',
    ),
  );
  if (resolved == null) {
    throw StateError(
      'could not resolve package:control_plane_server; the no-acquisition '
      'gate refuses to read a guessed path',
    );
  }
  final file = File.fromUri(resolved);
  if (!file.existsSync()) {
    throw StateError('resolved $resolved but it does not exist');
  }
  return file.readAsString();
}

/// Block comment, non-greedy.
///
/// Order matters against [_lineComment]: a `//` inside a block comment must not
/// truncate the rest of that block and leave executable code behind, so the
/// block form is removed first.
final RegExp _blockComment = RegExp(r'/\*[\s\S]*?\*/');

/// Everything from a `//` to the end of its line.
final RegExp _lineComment = RegExp(r'//');

/// [source] with every comment removed.
///
/// The no-acquisition gate needs this because the sweep NAMES the acquisition
/// it must never perform — in prose, explaining the livelock. A whole-file grep
/// for `CredentialKeyService` therefore fails for a reason that has nothing to
/// do with the guard, exactly as `work_entry_test.dart` scopes its own gate to
/// the members it is guarding. What must not appear is the acquisition in
/// CODE.
String _stripComments(String source) => source
    .replaceAll(_blockComment, ' ')
    .split('\n')
    .map((line) => line.split(_lineComment).first)
    .join('\n');

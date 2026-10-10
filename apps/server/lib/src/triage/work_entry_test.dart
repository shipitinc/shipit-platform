import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/triage/work_entry.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show
        InMemoryHumanDecisionStore,
        InMemoryProductRegistryStore,
        ProductRegistryEngine;
import 'package:scheduler/scheduler.dart'
    show
        InMemoryJobStore,
        RunnableWorkEvaluator,
        RunnableWorkStatus,
        triageDefectDefinition,
        triageDefectDedupeKey;
import 'package:workflow_engine/workflow_engine.dart' show WorkflowEngine;
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

import 'package:qa_orchestration/qa_orchestration.dart'
    show triageWorkItemCategory;

import 'lane_a_defect_triage_work_item.dart' show defectTriageWorkItemId;

/// Two product ids that are obviously not this product's, used so no test can
/// accidentally pass because it agreed with a real one.
const String kProduct = 'product-under-test';
const String kOtherProduct = 'a-different-product';

/// A description long enough to satisfy the human-facing work-item contract,
/// and different from the title, which the same contract requires.
const String kDescription =
    'A human-filed request describing the behaviour that was observed.';
const String kTitle = 'Observed behaviour is not what the request expected';

/// Every store and engine one [WorkEntryTrigger] needs, plus the trigger
/// itself, so a test reads as a scenario rather than as wiring.
class _Host {
  _Host() {
    workflowEngine = DurableWorkflowEngine(
      store: workflowStore,
      policy: const WorkflowEngine(),
    );
    trigger = WorkEntryTrigger(
      workflowStore: workflowStore,
      workflowEngine: workflowEngine,
      productRegistryEngine: registryEngine,
      jobStore: jobStore,
      log: (event, fields) => events.add((event, fields)),
    );
  }

  final InMemoryWorkflowStore workflowStore = InMemoryWorkflowStore();

  /// Bound to [workflowStore], deliberately: a second in-memory store would
  /// make every assertion in this file pass against a graph nothing else can
  /// see.
  late final DurableWorkflowEngine workflowEngine;

  final InMemoryJobStore jobStore = InMemoryJobStore();
  final InMemoryProductRegistryStore registryStore =
      InMemoryProductRegistryStore();
  final InMemoryHumanDecisionStore decisions = InMemoryHumanDecisionStore();
  final List<(String, Map<String, dynamic>)> events = [];

  late final WorkEntryTrigger trigger;

  ProductRegistryEngine get registryEngine => ProductRegistryEngine(
    store: registryStore,
    humanDecisionStore: decisions,
  );

  /// Registers [productId] in the exact state asked for, without a baseline
  /// decision ceremony.
  ///
  /// Writing the state directly is the point: this suite is about what the
  /// trigger DOES with a product state, and a test that had to govern a
  /// product through its real governance path to observe the refusal would be
  /// testing the registry instead.
  Future<void> putProduct(String productId, ProductState state) async {
    final now = DateTime.utc(2026, 1, 1);
    await registryStore.saveProduct(
      Product(
        productId: productId,
        name: 'A product',
        state: state,
        createdAt: now,
        updatedAt: now,
        version: 1,
      ),
    );
  }

  Future<void> putGovernedProduct([String productId = kProduct]) =>
      putProduct(productId, ProductState.governed);

  /// Opens a defect-triage work item the way lane A does: id `defect-{id}`,
  /// category `triageWorkItemCategory`, and the defect as its requirement
  /// reference so the `planning -> planned` guard can be satisfied.
  Future<WorkItem> openDefectTriageItem(
    String defectId, {
    String? productId,
  }) async {
    final item = await workflowEngine.createWorkItem(
      workItemId: defectTriageWorkItemId(defectId),
      productId: productId ?? kProduct,
      category: triageWorkItemCategory,
      title: kTitle,
      description: kDescription,
      featureRef: defectId,
    );
    return item;
  }

  /// Opens a feature-request work item the way feature intake does: a
  /// `WI-feature-*` id, category `feature`, itself as its requirement
  /// reference.
  Future<WorkItem> openFeatureItem({
    String productId = kProduct,
    String? workItemId,
  }) async {
    final id = workItemId ?? 'WI-feature-1789000000000000';
    return workflowEngine.createWorkItem(
      workItemId: id,
      productId: productId,
      category: WorkItemCategory.feature,
      title: kTitle,
      description: kDescription,
      featureRef: id,
    );
  }

  Future<List<Job>> jobsFor(String workItemId) async =>
      (await jobStore.listJobsForWorkItem(workItemId));

  Future<List<Job>> allJobs() async => jobStore.listJobs();

  Future<WorkItem> reread(String workItemId) =>
      workflowStore.readWorkItem(workItemId);
}

void main() {
  group('N-1 an ungoverned product is a wait, not a rejection', () {
    test('a defect is accepted, no job is enqueued, and it dispatches once '
        'the product is governed', () async {
      final host = _Host();
      await host.putProduct(kProduct, ProductState.registered);
      final item = await host.openDefectTriageItem('d-1');

      final first = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      // Accepted: the decision is a named skip, not an exception, and nothing
      // was thrown at intake.
      expect(first, isA<WorkEntrySkipped>());
      final skipped = first as WorkEntrySkipped;
      expect(skipped.code, WorkEntrySkipCodes.productNotGoverned);
      // Named, so "the trigger ran and declined" is greppable and is not the
      // same log line as "the trigger is not running".
      expect(skipped.reason, contains(kProduct));
      expect(skipped.reason, contains('registered'));
      expect(
        skipped.reason,
        contains('NOT rejected'),
        reason: 'the decision must say the request was not refused',
      );

      // No job, and — load-bearing — no walk into an entry state either. The
      // scheduler is category-blind AND product-state-blind, so an item at
      // designNotRequired would be dispatched regardless of this gate.
      expect(await host.allJobs(), isEmpty);
      final parked = await host.reread(item.workItemId);
      expect(parked.state, WorkItemState.draft);
      expect(
        RunnableWorkEvaluator(policy: const WorkflowEngine()).evaluate(
          parked,
          triageDefectDefinition,
        ),
        RunnableWorkStatus.noAction,
        reason:
            'a gated item must stay invisible to the category-blind '
            'scheduler, or the gate is decorative',
      );

      // Once governed, the same work item dispatches — and exactly once.
      await host.putGovernedProduct();
      final second = await host.trigger.ensureWorkEntry(
        item: await host.reread(item.workItemId),
        kind: WorkEntryKind.defectTriage,
      );

      expect(second, isA<WorkEntryEnqueued>());
      final jobs = await host.allJobs();
      expect(jobs, hasLength(1));
      expect(jobs.single.jobType, JobType.triageDefect);
      expect(jobs.single.workItemId, item.workItemId);
    });

    test('a legacy `draft` product row is read as `registered`, not as a '
        'state that allows dispatch', () async {
      final host = _Host();
      // `canonical` is the load-bearing read: a row persisted as the
      // parse-only legacy `draft` must be understood as `registered`.
      // ignore: deprecated_member_use
      await host.putProduct(kProduct, ProductState.draft);
      final item = await host.openDefectTriageItem('d-legacy');

      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.productNotGoverned,
      );
      expect(decision.reason, contains('registered'));
      expect(decision.reason, isNot(contains('draft,')));
      expect(await host.allJobs(), isEmpty);
    });

    test(
      'every non-governed state refuses, and says which state it saw',
      () async {
        for (final state in <ProductState>[
          ProductState.registered,
          ProductState.baselinePending,
          ProductState.baselineBlocked,
          ProductState.baselineReview,
          ProductState.paused,
          ProductState.archived,
        ]) {
          final host = _Host();
          await host.putProduct(kProduct, state);
          final item = await host.openDefectTriageItem('d-${state.wire}');

          final decision = await host.trigger.ensureWorkEntry(
            item: item,
            kind: WorkEntryKind.defectTriage,
          );

          expect(decision, isA<WorkEntrySkipped>(), reason: state.wire);
          expect(
            (decision as WorkEntrySkipped).code,
            WorkEntrySkipCodes.productNotGoverned,
            reason: state.wire,
          );
          expect(decision.reason, contains(state.wire));
          expect(await host.allJobs(), isEmpty, reason: state.wire);
        }
      },
    );

    test('a product id with no registry row is refused under its OWN code, '
        'not folded into "not governed"', () async {
      final host = _Host();
      // No product row at all. `governed` is a property of a product; an
      // absent row is not an ungoverned product, it is an unknown one, and the
      // two have different consequences — one resolves by waiting, one does
      // not. Reporting them as one fact would tell an operator to wait for
      // something that will never arrive.
      final item = await host.openDefectTriageItem(
        'd-orphan',
        productId: 'a-product-nobody-registered',
      );

      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.productNotInRegistry,
      );
      expect(
        decision.code,
        isNot(WorkEntrySkipCodes.productNotGoverned),
        reason:
            'an absent product and an ungoverned product are different facts',
      );
      expect(decision.reason, contains('registry row'));
      expect(await host.allJobs(), isEmpty);
    });

    test('a feature on an ungoverned product is parked visibly, and the '
        'governed gate is recorded alongside the dependency', () async {
      final host = _Host();
      await host.putProduct(kProduct, ProductState.registered);
      final item = await host.openFeatureItem();

      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.featureIntake,
      );

      // Accepted and parked, not refused: the item moved forward to `planned`,
      // which is a visible state with an honest reason rather than `draft`
      // forever.
      final parked = await host.reread(item.workItemId);
      expect(parked.state, WorkItemState.planned);

      // Both blockers named, because an operator needs to tell them apart:
      // one resolves by waiting, one does not.
      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.productNotGoverned,
      );
      expect(
        parked.metadata?[workEntryDispatchGateKey],
        WorkEntrySkipCodes.productNotGoverned,
      );
      expect(
        parked.metadata?[workEntryBlockedByKey],
        externalWorkEntryConsumerDependency,
      );
      expect(
        parked.metadata?[workEntryProductStateKey],
        ProductState.registered.wire,
      );
      expect(await host.allJobs(), isEmpty);
    });

    test('a feature whose product is not registered at all is parked under the '
        'absent-product code, not "not governed"', () async {
      final host = _Host();
      final item = await host.openFeatureItem(productId: 'never-registered');

      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.featureIntake,
      );

      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.productNotInRegistry,
        reason:
            '"wait for the product" is wrong advice for a product that '
            'does not exist',
      );
      final parked = await host.reread(item.workItemId);
      expect(parked.state, WorkItemState.planned);
      expect(
        parked.metadata?[workEntryDispatchGateKey],
        WorkEntrySkipCodes.productNotInRegistry,
      );
      expect(await host.allJobs(), isEmpty);
    });

    test('once the product is governed, the recorded gate lifts while the '
        'missing consumer does not', () async {
      final host = _Host();
      await host.putProduct(kProduct, ProductState.registered);
      final item = await host.openFeatureItem();

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.featureIntake,
      );
      await host.putGovernedProduct();

      final decision = await host.trigger.ensureWorkEntry(
        item: await host.reread(item.workItemId),
        kind: WorkEntryKind.featureIntake,
      );

      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.noConsumerForWorkEntryKind,
      );
      final parked = await host.reread(item.workItemId);
      expect(
        parked.metadata?[workEntryDispatchGateKey],
        isNull,
        reason: 'the governed gate is closed no longer; it must not linger',
      );
      expect(
        parked.metadata?[workEntryProductStateKey],
        ProductState.governed.wire,
      );
      // The dependency is still the permanent one.
      expect(
        parked.metadata?[workEntryBlockedByKey],
        externalWorkEntryConsumerDependency,
      );
      expect(await host.allJobs(), isEmpty);
    });
  });

  group('N-2 two submissions of the same work item produce one job', () {
    test(
      'the second caller is told which job won, and writes nothing',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        final item = await host.openDefectTriageItem('d-2');

        final first = await host.trigger.ensureWorkEntry(
          item: item,
          kind: WorkEntryKind.defectTriage,
        );
        final second = await host.trigger.ensureWorkEntry(
          item: await host.reread(item.workItemId),
          kind: WorkEntryKind.defectTriage,
        );

        expect(first, isA<WorkEntryEnqueued>());
        expect(second, isA<WorkEntrySkipped>());
        final skipped = second as WorkEntrySkipped;
        expect(skipped.code, WorkEntrySkipCodes.triageAlreadyActive);
        expect(
          skipped.reason,
          contains((first as WorkEntryEnqueued).jobId),
          reason:
              '"I did nothing" and "jb-… already exists" are different '
              'operator questions, and only the second one is answerable',
        );

        final jobs = await host.allJobs();
        expect(jobs, hasLength(1));
        expect(jobs.single.state, JobState.queued);
      },
    );

    test(
      'the dedupe key is the imported one, never a re-spelled copy',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        final item = await host.openDefectTriageItem('d-key');

        await host.trigger.ensureWorkEntry(
          item: item,
          kind: WorkEntryKind.defectTriage,
        );

        final job = (await host.allJobs()).single;
        expect(
          job.dedupeKey,
          triageDefectDedupeKey(item, triageDefectDefinition),
          reason:
              'every job already on disk carries the imported key format; a '
              're-spelling would orphan all of them and stop the sweep matching',
        );
        expect(job.dedupeKey, '${item.workItemId}:triage_defect');
      },
    );

    test(
      'ten consecutive passes enqueue once and re-walk zero times',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        final item = await host.openDefectTriageItem('d-ten');

        for (var pass = 0; pass < 10; pass++) {
          await host.trigger.ensureWorkEntry(
            item: await host.reread(item.workItemId),
            kind: WorkEntryKind.defectTriage,
          );
        }

        expect(await host.allJobs(), hasLength(1));
        final history = await host.workflowStore.readTransitionHistory(
          item.workItemId,
        );
        expect(
          history.where(
            (record) => record.outcome == TransitionOutcome.accepted,
          ),
          hasLength(3),
          reason:
              'draft->planning->planned->designNotRequired happens once; a '
              'replayed pass must be a read, not a re-walk',
        );
      },
    );
  });

  group('N-2a the per-hop idempotency keys replay, they are not per-call '
      'values', () {
    // ## Why these tests exist at all
    //
    // Every other idempotency test in this file passes with the state guard
    // ALONE. A caller that re-reads the item sees the state it left it at and
    // walks nothing, so the keys are never consulted — which means the suite
    // could mint a fresh key on every call and stay green. That was verified,
    // not assumed: `work-entry:planning` -> `work-entry:planning-${now}` and
    // the whole file passed unchanged.
    //
    // The keys exist for the caller that does NOT re-read: one that read
    // `draft`, lost the race, and comes back later still holding that stale
    // copy. Its state guard sees `draft` and tries `draft -> planning` again.
    // Only a key that is constant per work item turns that replay into the
    // already-accepted outcome; a per-call key re-runs the transition.

    test('a caller replaying from a stale `draft` copy resolves under the '
        'trigger\'s own keys instead of re-walking', () async {
      final host = _Host();
      await host.putGovernedProduct();
      // Read once, here. Both callers below are handed THIS object, which
      // reads `draft` forever no matter what the store does — the stale
      // snapshot two concurrent callers really do hold.
      final stale = await host.openDefectTriageItem('d-stale');

      final first = await host.trigger.ensureWorkEntry(
        item: stale,
        kind: WorkEntryKind.defectTriage,
      );
      expect(first, isA<WorkEntryEnqueued>());

      // The winner's job is FINISHED, so the cheap active-job guard cannot
      // answer for the replay. That guard is the reason this test is not
      // simply a second call: while a job is queued it short-circuits above
      // the walk and the keys are never consulted, so the test would prove
      // nothing. Finishing the job forces the replay past gate one and into
      // `_walkToPlanned`, still holding `draft`.
      final job = (await host.allJobs()).single;
      await host.jobStore.saveJob(
        job.copyWith(
          state: JobState.succeeded,
          completedAt: job.createdAt,
          version: job.version + 1,
        ),
      );

      // The replay: same stale object, no re-read. Its state guard still sees
      // `draft` and asks for `draft -> planning` under `work-entry:planning`.
      // That key is already in the history, so the engine returns the accepted
      // outcome instead of attempting a second transition.
      final replay = await host.trigger.ensureWorkEntry(
        item: stale,
        kind: WorkEntryKind.defectTriage,
      );

      // Replay must be a DECISION and not a throw. A per-call key misses the
      // history lookup, and the transition it then attempts is
      // `design_not_required -> planning`, which the graph refuses: the caller
      // would learn it held a stale read by catching an exception, instead of
      // being told what happened.
      expect(replay, isA<WorkEntryDecision>());

      // Exactly three transitions, still the ones the first caller made. A
      // re-walk would show six.
      expect(
        await _acceptedKeys(host, stale.workItemId),
        hasLength(3),
        reason:
            'the replay must resolve to the accepted outcome, not re-run the '
            'hop and not append a second record',
      );
      expect(
        (await host.reread(stale.workItemId)).state,
        WorkItemState.designNotRequired,
        reason: 'the replay must not move the item backwards',
      );
      expect(await host.allJobs(), hasLength(1));
    });

    test(
      'both callers observing `draft` converge on one job and one walk',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        // One read, two callers, both holding `draft`. This is the scenario the
        // keys exist for and it is NOT what `Future.wait` produces: two such
        // calls interleave inside the store, so whichever loses the walk loses
        // the CAS and the exception escapes `ensureWorkEntry` uncaught. What is
        // modelled here is the ordering a sweep actually produces — a caller
        // that observed `draft` and comes back later still holding that copy —
        // which is the one the per-hop keys decide, and the one that is not
        // already covered by the cheap active-job guard.
        final stale = await host.openDefectTriageItem('d-concurrent');

        final first = await host.trigger.ensureWorkEntry(
          item: stale,
          kind: WorkEntryKind.defectTriage,
        );
        final job = (await host.allJobs()).single;
        await host.jobStore.saveJob(
          job.copyWith(
            state: JobState.succeeded,
            completedAt: job.createdAt,
            version: job.version + 1,
          ),
        );

        final second = await host.trigger.ensureWorkEntry(
          item: stale,
          kind: WorkEntryKind.defectTriage,
        );

        expect(first, isA<WorkEntryEnqueued>());
        // The second caller reaches the enqueue and finds the key spent. The
        // name of the outcome is not asserted here on purpose: this group is
        // about the WALK, and pinning the code would restate the N-3 test. What
        // matters is that it is a decision and not a throw.
        expect(second, isA<WorkEntrySkipped>());
        expect(second.reason, isNotEmpty);
        expect(
          await _acceptedKeys(host, stale.workItemId),
          hasLength(3),
          reason:
              'two callers walked the same item and the keys collapsed them '
              'onto ONE walk of three hops',
        );
        expect(await host.allJobs(), hasLength(1));
      },
    );

    test('the recorded walk keys are three distinct, fixed, trigger-owned '
        'values', () async {
      // Reads the keys OUT OF THE TRANSITION HISTORY, which is the only
      // honest place to read them from: asserting a locally-written constant
      // against itself is the tautology M-1 is about, and it would pass
      // unchanged after the production keys were renamed or made per-call.
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.openDefectTriageItem('d-keys');

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      final keys = await _acceptedKeys(host, item.workItemId);

      // One per hop, in order, exactly as the walk names them. A per-call key
      // would show three distinct values that are none of these; a renamed
      // hop would show one that is.
      expect(
        keys,
        <String>[
          'work-entry:planning',
          'work-entry:planned',
          'work-entry:designNotRequired',
        ],
      );

      // Namespaced away from lane A's `triage-intake:*` on purpose: the same
      // work item is walked by both actors, and two key namespaces mean two
      // independently auditable transition histories rather than one actor's
      // history being attributed to the other.
      for (final key in keys) {
        expect(key, startsWith('work-entry:'));
        expect(key, isNot(startsWith('triage-intake:')));
      }
    });
  });

  group('N-3 a restart mid-dispatch produces no second job', () {
    test(
      'a job that was already dispatched is found, not duplicated',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        final item = await host.openDefectTriageItem('d-restart');

        await host.trigger.ensureWorkEntry(
          item: item,
          kind: WorkEntryKind.defectTriage,
        );
        final enqueued = (await host.allJobs()).single;

        // The crash window: claimed and dispatched, worker execution recorded,
        // outcome not yet persisted. The process dies here.
        final running = enqueued.copyWith(
          state: JobState.running,
          startedAt: enqueued.createdAt,
          workerId: 'worker-under-test',
          executionReference: JobExecutionReference(
            workerExecutionId: 'wx-${enqueued.jobId}',
            createdAt: enqueued.createdAt,
          ),
          version: enqueued.version + 1,
        );
        await host.jobStore.saveJob(running, expectedVersion: enqueued.version);

        // Restart. The trigger must recognise in-flight work, not mint a job
        // for it.
        final decision = await host.trigger.ensureWorkEntry(
          item: await host.reread(item.workItemId),
          kind: WorkEntryKind.defectTriage,
        );

        expect(
          (decision as WorkEntrySkipped).code,
          WorkEntrySkipCodes.triageAlreadyActive,
        );
        expect(decision.reason, contains(JobState.running.wire));
        final jobs = await host.allJobs();
        expect(jobs, hasLength(1));
        expect(jobs.single.jobId, enqueued.jobId);
        expect(
          jobs.single.executionReference?.workerExecutionId,
          'wx-${enqueued.jobId}',
        );
      },
    );

    test(
      'a restart between two walk hops resumes instead of restarting',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        final item = await host.openDefectTriageItem('d-midwalk');

        // Crash between `draft -> planning` and `planning -> planned`.
        await host.workflowEngine.transition(
          workItemId: item.workItemId,
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
          actor: WorkflowActor(
            actorId: 'defect-intake',
            actorType: ActorType.orchestrator,
          ),
          context: const {'featureRef': 'd-midwalk'},
          idempotencyKey: 'triage-intake:planning',
        );
        expect(
          (await host.reread(item.workItemId)).state,
          WorkItemState.planning,
        );

        final decision = await host.trigger.ensureWorkEntry(
          item: await host.reread(item.workItemId),
          kind: WorkEntryKind.defectTriage,
        );

        expect(decision, isA<WorkEntryEnqueued>());
        expect(
          (await host.reread(item.workItemId)).state,
          WorkItemState.designNotRequired,
        );
        expect(await host.allJobs(), hasLength(1));
      },
    );

    test('a crash after the walk and before the enqueue still enqueues '
        'exactly once', () async {
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.openDefectTriageItem('d-preenqueue');

      // The window the intake-only trigger had no recovery for: the work item
      // is durable and walkable, and no job was ever written.
      final ready = await host.workflowEngine.transition(
        workItemId: item.workItemId,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: WorkflowActor(
          actorId: 'defect-intake',
          actorType: ActorType.orchestrator,
        ),
        context: const {'featureRef': 'd-preenqueue'},
        idempotencyKey: 'triage-intake:planning',
      );
      expect(ready.state, WorkItemState.planning);
      expect(await host.allJobs(), isEmpty);

      for (var pass = 0; pass < 3; pass++) {
        await host.trigger.ensureWorkEntry(
          item: await host.reread(item.workItemId),
          kind: WorkEntryKind.defectTriage,
        );
      }

      final jobs = await host.allJobs();
      expect(jobs, hasLength(1));
      expect(
        (await host.reread(item.workItemId)).state,
        WorkItemState.designNotRequired,
      );
    });

    test('a finished job does not free the dedupe key: no second job is '
        'created, and the code says the key is spent rather than claiming a '
        'race it did not see', () async {
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.openDefectTriageItem('d-terminal');

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );
      final first = (await host.allJobs()).single;
      await host.jobStore.saveJob(
        first.copyWith(
          state: JobState.succeeded,
          completedAt: first.createdAt,
          version: first.version + 1,
        ),
      );

      final decision = await host.trigger.ensureWorkEntry(
        item: await host.reread(item.workItemId),
        kind: WorkEntryKind.defectTriage,
      );

      // The active-job guard is scoped to NON-terminal jobs, so a finished one
      // is not mistaken for work in flight. What stops the enqueue is the
      // dedupe key itself, which `enqueueIfAbsent` holds regardless of state.
      //
      // The honest code is "the key is spent", NOT "a concurrent caller won
      // this key": nothing concurrent happened here, and a decision that
      // invents a race sends an operator looking for one.
      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.dedupeKeyAlreadyConsumed,
      );
      expect(decision.reason, contains(first.jobId));
      expect(decision.reason, contains(JobState.succeeded.wire));
      expect(decision.code, isNot(WorkEntrySkipCodes.triageAlreadyActive));
      expect(await host.allJobs(), hasLength(1));
    });
  });

  group('N-4 a feature is NEVER routed to the defect triage lane', () {
    test('no job of any type is enqueued for a feature work item', () async {
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.openFeatureItem();

      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.featureIntake,
      );

      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.noConsumerForWorkEntryKind,
      );
      expect(
        await host.jobsFor(item.workItemId),
        isEmpty,
        reason:
            'this is the whole guard. Routing a feature into lane A produces '
            'a queued -> dispatched -> succeeded job whose TriageResult is '
            'then discarded at readDefect: a healthy-looking job and no work '
            'done',
      );
      expect(await host.allJobs(), isEmpty);
    });

    test('the parked feature is invisible to the category-blind scheduler, '
        'while a defect is not', () async {
      final host = _Host();
      await host.putGovernedProduct();
      const evaluator = RunnableWorkEvaluator(policy: WorkflowEngine());
      final feature = await host.openFeatureItem();
      final defect = await host.openDefectTriageItem('d-visible');

      await host.trigger.ensureWorkEntry(
        item: feature,
        kind: WorkEntryKind.featureIntake,
      );
      await host.trigger.ensureWorkEntry(
        item: defect,
        kind: WorkEntryKind.defectTriage,
      );

      // The structural half of the guard. `RunnableWorkEvaluator` never reads
      // `category`, so the ONLY thing keeping a feature out of lane A is that
      // this trigger never walks it into an entry state. If someone deepens
      // the park to `designNotRequired` — one hop, and legal with no design
      // artifact — this assertion fails, which is the point.
      final parkedFeature = await host.reread(feature.workItemId);
      expect(
        evaluator.evaluate(parkedFeature, triageDefectDefinition),
        RunnableWorkStatus.noAction,
      );
      expect(
        triageDefectDefinition.entryStates,
        isNot(contains(parkedFeature.state)),
        reason: 'the park must stop short of every triage entry state',
      );

      // The contrast that proves the evaluator itself is not the thing being
      // asserted: the defect, parked the same way by the same call shape, IS
      // runnable.
      expect(
        evaluator.evaluate(
          await host.reread(defect.workItemId),
          triageDefectDefinition,
        ),
        RunnableWorkStatus.runnable,
      );
    });

    test('the two intakes carry the SAME category, so routing could never '
        'have keyed on it', () async {
      // Guards the premise the design corrected itself about. If `category`
      // ever becomes a distinguishing signal, this fails and the routing note
      // in work_entry.dart must be rewritten with it.
      expect(triageWorkItemCategory, WorkItemCategory.feature);
    });

    test(
      'ten passes over a feature enqueue nothing and churn nothing',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        final item = await host.openFeatureItem();

        await host.trigger.ensureWorkEntry(
          item: item,
          kind: WorkEntryKind.featureIntake,
        );
        final afterFirstPass = await host.reread(item.workItemId);

        for (var pass = 1; pass < 10; pass++) {
          await host.trigger.ensureWorkEntry(
            item: await host.reread(item.workItemId),
            kind: WorkEntryKind.featureIntake,
          );
        }

        expect(await host.allJobs(), isEmpty);
        final parked = await host.reread(item.workItemId);
        expect(parked.state, WorkItemState.planned);
        // A sweep runs every thirty seconds. If each pass rewrote an identical
        // row the durable record would churn for ever, and every one of those
        // writes would race every other lane's read-modify-write on the same
        // item. A replay must be a READ.
        expect(
          parked.version,
          afterFirstPass.version,
          reason: 'nine further passes over an unchanged record wrote nothing',
        );
        expect(
          parked.metadata?[workEntryBlockedByKey],
          externalWorkEntryConsumerDependency,
        );
      },
    );
  });

  group('the missing feature consumer is recorded, not faked', () {
    test('the parked reason names the dependency and says what `unavailable` '
        'means', () async {
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.openFeatureItem();

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.featureIntake,
      );

      final parked = await host.reread(item.workItemId);
      expect(
        parked.metadata?[workEntryConsumerKey],
        workEntryConsumerUnavailable,
      );
      expect(
        parked.metadata?[workEntryBlockedByKey],
        externalWorkEntryConsumerDependency,
      );
      expect(parked.metadata?[workEntryFeatureIntakeKey], 'featureIntake');

      final reason = parked.metadata?[workEntryParkedReasonKey] as String?;
      expect(reason, isNotNull);
      expect(reason, contains(externalWorkEntryConsumerDependency));
      expect(
        reason,
        contains('does not exist'),
        reason:
            'the recorded reason must say the runtime is missing, which is '
            'a different fact from "a human declined to run it"',
      );
      expect(
        reason,
        contains('not refused'),
        reason:
            'HD-1b: the request is parked, not rejected, and the record '
            'has to say so where the operator will read it',
      );
      expect(reason, contains(item.workItemId));
    });

    test('the dependency value is the terminal one, not a pending or a '
        'placeholder', () {
      expect(
        externalWorkEntryConsumerDependency,
        'EXTERNAL_WORK_ENTRY_CONSUMER_DEPENDENCY',
      );
      expect(workEntryConsumerUnavailable, 'unavailable');
      // Same value under both names, so a log line carries one meaning.
      expect(
        WorkEntrySkipCodes.noConsumerForCategory,
        WorkEntrySkipCodes.noConsumerForWorkEntryKind,
      );
    });

    test('every skip code is distinct and greppable', () {
      final codes = <String, String>{
        'triageAlreadyActive': WorkEntrySkipCodes.triageAlreadyActive,
        'productNotGoverned': WorkEntrySkipCodes.productNotGoverned,
        'productNotInRegistry': WorkEntrySkipCodes.productNotInRegistry,
        'noConsumerForWorkEntryKind':
            WorkEntrySkipCodes.noConsumerForWorkEntryKind,
        'notTriagableState': WorkEntrySkipCodes.notTriagableState,
        'noPlanningEvidence': WorkEntrySkipCodes.noPlanningEvidence,
        'workItemMissing': WorkEntrySkipCodes.workItemMissing,
        // The newest and the most consequential of the codes: a collision
        // with any other would report a permanent, spent-key condition as
        // something transient, sending an operator to wait for a dispatch that
        // can never happen. It was missing here while the collision was caught
        // only by a test named for something else.
        'dedupeKeyAlreadyConsumed': WorkEntrySkipCodes.dedupeKeyAlreadyConsumed,
        'otherLaneOwnsItem': WorkEntrySkipCodes.otherLaneOwnsItem,
        // `noConsumerForCategory` is deliberately ABSENT: it is defined as the
        // SAME value as `noConsumerForWorkEntryKind` (one code, one meaning),
        // and listing it here would fail this distinctness check by design.
        // Its aliasing is asserted by name in the test above instead.
      };
      expect(codes.values.toSet(), hasLength(codes.length));
      for (final entry in codes.entries) {
        expect(entry.value, isNotEmpty);
        expect(
          entry.value,
          entry.value.toUpperCase(),
          reason:
              '${entry.key} must be SCREAMING_SNAKE so a log line and a '
              'grep agree',
        );
      }
    });
  });

  group('an item no lane can claim is reported, never enqueued', () {
    test('an item at a non-entry state produces no job', () async {
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.openDefectTriageItem('d-owned');
      // `designRequired` is legal, is not a triage entry state, and is where a
      // human or another lane leaves an item that is genuinely under
      // construction. Enqueueing here would recreate the 18-job orphan class
      // this work item exists to close.
      await host.workflowEngine.transition(
        workItemId: item.workItemId,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: WorkflowActor(
          actorId: 'defect-intake',
          actorType: ActorType.orchestrator,
        ),
        context: const {'featureRef': 'd-owned'},
        idempotencyKey: 'test:planning',
      );
      await host.workflowEngine.transition(
        workItemId: item.workItemId,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: WorkflowActor(
          actorId: 'defect-intake',
          actorType: ActorType.orchestrator,
        ),
        context: const {'featureRef': 'd-owned'},
        idempotencyKey: 'test:planned',
      );
      await host.workflowEngine.transition(
        workItemId: item.workItemId,
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: WorkflowActor(
          actorId: 'defect-intake',
          actorType: ActorType.orchestrator,
        ),
        context: const {
          'featureRef': 'd-owned',
          'designContractId': 'dc-for-tests',
        },
        idempotencyKey: 'test:designRequired',
      );

      final decision = await host.trigger.ensureWorkEntry(
        item: await host.reread(item.workItemId),
        kind: WorkEntryKind.defectTriage,
      );

      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.notTriagableState,
      );
      expect(decision.reason, contains(WorkItemState.designRequired.wire));
      expect(
        await host.allJobs(),
        isEmpty,
        reason: 'a job here could never be dispatched',
      );
    });

    test('an item with no requirement reference is refused by the graph, and '
        'the trigger says so instead of throwing', () async {
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.workflowEngine.createWorkItem(
        workItemId: 'defect-no-evidence',
        productId: kProduct,
        category: triageWorkItemCategory,
        title: kTitle,
        description: kDescription,
      );

      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      expect(
        (decision as WorkEntrySkipped).code,
        WorkEntrySkipCodes.noPlanningEvidence,
      );
      expect(await host.allJobs(), isEmpty);
      expect((await host.reread(item.workItemId)).state, WorkItemState.draft);
    });

    test(
      'a requirementRef alone satisfies the walk — nothing is fabricated',
      () async {
        final host = _Host();
        await host.putGovernedProduct();
        final item = await host.workflowEngine.createWorkItem(
          workItemId: 'defect-requirement-ref',
          productId: kProduct,
          category: triageWorkItemCategory,
          title: kTitle,
          description: kDescription,
          requirementRef: 'req-1',
        );

        final decision = await host.trigger.ensureWorkEntry(
          item: item,
          kind: WorkEntryKind.defectTriage,
        );

        expect(decision, isA<WorkEntryEnqueued>());
        expect(await host.allJobs(), hasLength(1));
      },
    );

    test(
      'a governed product does not make another product dispatchable',
      () async {
        final host = _Host();
        await host.putGovernedProduct(kProduct);
        final item = await host.openDefectTriageItem(
          'd-other',
          productId: kOtherProduct,
        );

        final decision = await host.trigger.ensureWorkEntry(
          item: item,
          kind: WorkEntryKind.defectTriage,
        );

        expect(
          (decision as WorkEntrySkipped).code,
          WorkEntrySkipCodes.productNotInRegistry,
          reason:
              'the gate reads the item\'s own product; nothing falls back '
              'to a default',
        );
        expect(await host.allJobs(), isEmpty);
      },
    );
  });

  group('the work-item id is delegated, never re-spelled', () {
    test('triageWorkItemIdForDefect agrees with the defect lane', () {
      expect(
        WorkEntryTrigger.triageWorkItemIdForDefect('d-42'),
        defectTriageWorkItemId('d-42'),
      );
    });

    // The test above cannot fail if the accessor is re-spelled: the production
    // body IS `defectTriageWorkItemId(defectId)`, so re-spelling it as
    // `'defect-$defectId'` still agrees with the very function it replaced.
    // It proves delegation and nothing else; on its own it is a test that
    // advertises a guard it does not perform.
    //
    // These two close that. The first pins the VALUE independently of the
    // production accessor, so a hand-rolled literal that happens to produce
    // the same string is caught by the second. The second asserts the SHAPE
    // from outside the accessor, which is what "delegated" has to mean: the
    // accessor may not construct the id at all.
    test('the delegated id has the shape the lanes already persisted', () {
      // Written out here on purpose rather than read from the production
      // accessor: a test that asks the thing under test what the answer is
      // checks nothing. This literal is the contract `TriageProcessor
      // ._extractDefectId` strips, and the prefix the dedupe key is built on.
      expect(WorkEntryTrigger.triageWorkItemIdForDefect('d-42'), 'defect-d-42');
    });

    test('the accessor contains no id literal of its own', () async {
      // The structural half, and the only one that survives a re-spelling that
      // happens to produce the right string. Scoped to the accessor's own body
      // so the guard is about delegation, not about how often the file mentions
      // the shape in prose — the doc comment above it names `'defect-$defectId'`
      // deliberately, and a file-wide grep would fail for that reason alone.
      final source = await _workEntrySource();
      final accessor = _bodyOf(
        source,
        'static String triageWorkItemIdForDefect',
      );

      expect(
        accessor,
        isNotNull,
        reason:
            'the accessor is not where this test expects it, so the '
            'no-literal guard below would silently cover nothing',
      );
      expect(
        accessor,
        contains('defectTriageWorkItemId('),
        reason:
            'the accessor must delegate; this test would otherwise pass on a '
            'body that constructs the id and happens to agree',
      );
      expect(
        RegExp(r"""['"]defect-""").hasMatch(accessor!),
        isFalse,
        reason:
            "the id shape must not be re-spelled here. It is load-bearing in "
            "the scheduler's job workItemId, the dedupe key, and "
            "TriageProcessor._extractDefectId; a second literal is a fourth "
            "place for it to drift",
      );
    });
  });

  group('every decision is logged with its reason', () {
    test('a skip that nobody logs is indistinguishable from a trigger that '
        'never ran', () async {
      final host = _Host();
      await host.putProduct(kProduct, ProductState.registered);
      final item = await host.openDefectTriageItem('d-logged');

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      // The gate now writes its own log event (see `work_entry.gated` below),
      // so this test no longer covers an unlogged defect. What it still
      // asserts — and what a log line cannot replace — is that the REASON
      // travels in the returned value: a caller that wires up no `log` at all
      // still learns why nothing happened, from the value it is handed.
      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );
      expect((decision as WorkEntrySkipped).reason, isNotEmpty);
      expect(decision.toString(), contains(decision.code));
    });

    test('a gated defect is logged, so it is distinguishable from a trigger '
        'that never ran', () async {
      final host = _Host();
      await host.putProduct(kProduct, ProductState.registered);
      final item = await host.openDefectTriageItem('d-gated-log');

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      // The count of "nothing to do" and the count of "nothing ran" are
      // identical from the outside. Only an event with the skip code in it
      // separates them — the feature route already had one, and this is the
      // defect route's equivalent.
      expect(
        host.events.map((event) => event.$1),
        contains('work_entry.gated'),
        reason:
            'a gated defect must leave a durable trace. Without it the '
            'returned decision reaches whoever holds the future, and an '
            'operator looking at the run sees only an absence',
      );

      final gated = host.events.firstWhere(
        (event) => event.$1 == 'work_entry.gated',
      );
      expect(gated.$2['skipCode'], WorkEntrySkipCodes.productNotGoverned);
      expect(gated.$2['workItemId'], item.workItemId);
      expect(gated.$2['productId'], kProduct);
      // `productState` is what the gate was read as, so a recorded
      // PRODUCT_NOT_GOVERNED can be re-checked later without re-running this.
      expect(gated.$2['productState'], ProductState.registered.wire);
      expect(gated.$2['state'], WorkItemState.draft.wire);

      // No credential material, and no value that could only have come from a
      // literal in the source: every field is either the item's own id, the
      // product it belongs to, or the state both were read at.
      expect(gated.$2.keys, hasLength(5));
    });

    test('the absent-product gate is logged under its own code', () async {
      final host = _Host();
      // No registry row at all. `PRODUCT_NOT_IN_REGISTRY` and
      // `PRODUCT_NOT_GOVERNED` are different facts with different
      // consequences, and the event is where an operator tells them apart.
      final item = await host.openDefectTriageItem(
        'd-gated-absent',
        productId: 'a-product-nobody-registered',
      );

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      final gated = host.events.firstWhere(
        (event) => event.$1 == 'work_entry.gated',
      );
      expect(gated.$2['skipCode'], WorkEntrySkipCodes.productNotInRegistry);
      expect(gated.$2['productState'], 'absent');
    });

    test('an enqueue is logged with the job id and the key', () async {
      final host = _Host();
      await host.putGovernedProduct();
      final item = await host.openDefectTriageItem('d-logged-enq');

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );

      expect(
        host.events.map((event) => event.$1),
        contains('work_entry.enqueued'),
      );
    });

    test('a park is logged with the product state and both blockers', () async {
      final host = _Host();
      await host.putProduct(kProduct, ProductState.registered);
      final item = await host.openFeatureItem();

      await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.featureIntake,
      );

      final parked = host.events.firstWhere(
        (event) => event.$1 == 'work_entry.feature_parked',
      );
      expect(parked.$2['blockedBy'], externalWorkEntryConsumerDependency);
      expect(parked.$2['dispatchGate'], WorkEntrySkipCodes.productNotGoverned);
      expect(parked.$2['productState'], ProductState.registered.wire);
    });
  });

  group('product-agnosticism', () {
    test('the trigger names no product, no environment variable and no '
        'filesystem path', () async {
      final source = await _workEntrySource();
      for (final forbidden in const ['shipit', 'SHIPIT', 'ShipIt']) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason:
              'work_entry.dart must not name this deployment anywhere; '
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
        reason:
            'no hardcoded filesystem path; the only paths this file knows '
            'are the ones its caller hands it',
      );
    });
  });
}

/// The idempotency keys the ACCEPTED transitions for [workItemId] were
/// recorded under, in the order they were accepted.
///
/// Read from the durable transition history rather than from the constants in
/// `work_entry.dart`, which are private to it and are exactly the thing these
/// tests are supposed to pin. A test that restates the production constant
/// next to itself asserts that the constant equals itself.
Future<List<String?>> _acceptedKeys(_Host host, String workItemId) async {
  final history = await host.workflowStore.readTransitionHistory(workItemId);
  return history
      .where((record) => record.outcome == TransitionOutcome.accepted)
      .map((record) => record.idempotencyKey)
      .toList();
}

/// A single-quoted or double-quoted string literal that begins with a slash.
///
/// The design's §9 rule names three things `work_entry.dart` must never
/// contain: this product's name, an environment lookup, and a hardcoded
/// filesystem path. A path is the one that is easy to add by accident — a log
/// message quoting a default directory, a comment quoting a CLI invocation —
/// and easy to miss in review, because it looks like prose.
final RegExp _absolutePathLiteral = RegExp("['\"]/[^'\"]*['\"]");

/// The source of `work_entry.dart`, located through package resolution rather
/// than through the working directory.
///
/// A gate that passes because it read the wrong file is worse than no gate,
/// and `dart test` may be invoked from anywhere in the workspace — so if this
/// library's own URI cannot be resolved, it refuses rather than guessing.
Future<String> _workEntrySource() async {
  final resolved = await Isolate.resolvePackageUri(
    Uri.parse(
      'package:control_plane_server/src/triage/work_entry.dart',
    ),
  );
  if (resolved == null) {
    throw StateError(
      'could not resolve package:control_plane_server; the product-'
      'agnosticism gate refuses to read a guessed path',
    );
  }
  final file = File.fromUri(resolved);
  if (!file.existsSync()) {
    throw StateError('resolved $resolved but it does not exist');
  }
  return file.readAsString();
}

/// The source text of the member declaration starting at [declaration], from
/// its opening line to the `;` that ends it.
///
/// Scoped to ONE declaration rather than the whole file, because a
/// whole-file grep for a forbidden literal fails for reasons that have
/// nothing to do with the guard: a doc comment that *explains* the shape
/// contains the shape, and saying so is correct documentation.
///
/// Returns null when [declaration] is absent, so a caller that guards on
/// "contains no literal" also fails when the member moved — a guard that finds
/// nothing to scan must not read as a pass.
String? _bodyOf(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) return null;
  final end = source.indexOf(';', start);
  if (end < 0) return null;
  return source.substring(start, end + 1);
}

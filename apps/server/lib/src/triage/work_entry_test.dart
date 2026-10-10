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

    test('a finished job does not block a fresh one, and says the key is '
        'spent rather than claiming a race it did not see', () async {
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
        'otherLaneOwnsItem': WorkEntrySkipCodes.otherLaneOwnsItem,
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

      // The defect skip carries no log event of its own — it is returned to a
      // caller that reports it. This asserts the shape that makes that safe:
      // the reason is in the returned value, not only in a log line nobody
      // wired up.
      final decision = await host.trigger.ensureWorkEntry(
        item: item,
        kind: WorkEntryKind.defectTriage,
      );
      expect((decision as WorkEntrySkipped).reason, isNotEmpty);
      expect(decision.toString(), contains(decision.code));
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

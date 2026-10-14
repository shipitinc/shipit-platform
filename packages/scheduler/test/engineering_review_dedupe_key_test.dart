import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

/// ## WHAT THIS FILE GUARDS
///
/// `engineeringReviewDedupeKey` is the one wired dedupe-key builder that built
/// `'<workItemId>:engineering_review'` with no attempt discriminator. Every
/// other wired builder that dispatches more than once per work item —
/// `triageDefectDedupeKey`, `implementFeatureDedupeKey` — appends `':a<n>'` read
/// from the durable `triageAttempt` marker, because `JobQueue.enqueueIfAbsent`
/// refuses a key ANY job holds, terminal or not. So the first engineering review
/// dispatched for a work item burned its key for ever and the second found
/// `created: false`.
///
/// Migration `20261014093000000` recorded the consequence in its own banner,
/// naming this function by line number: the two `agent_completed` items it
/// repaired "were blocked by a CONSUMED `engineering_review` dedupe key" that
/// it "does NOT reach".
///
/// ## WHAT IS DELIBERATELY NOT PROVEN HERE
///
/// The end-to-end un-strand — a real work item at `agentCompleted` holding a
/// producer commit, a terminal failed review job already persisted, and a real
/// `Scheduler.tick()` minting and dispatching the SECOND review under a fresh
/// key — needs `engineeringReviewWorkloadResolver`, which lives in `apps/server`.
/// It is `apps/server/test/engineering_review_rereview_test.dart`, and running
/// both in one place would leave the key builder's own rules unverified
/// anywhere the builder is actually compiled.
///
/// The residual this change does NOT close is stated in the builder's own
/// documentation and is not tested as if it were closed: once
/// `triageAttempt` reaches `maxImplementationInflows` the completion inflow
/// stands down before writing, so a SECOND exhausted review job with no re-work
/// in between would ask for the same suffix again. That is a separate change
/// with a separate owner.
const _itemId = 'wi-1';

/// Reports "no compatible worker" so the scheduler builds the request — proving
/// what it WOULD have dispatched — and never runs one. Same technique as
/// `implementation_inflow_tick_order_test.dart`, for the same reason: a worker
/// stub that parks makes the tick asynchronous, and nothing here is about
/// execution.
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

/// A work item at the review lane's own entry state.
///
/// `metadata` is the marker map under test; pass nothing for the ABSENT case,
/// which is the one that must keep building the historical key byte for byte.
WorkItem _reviewable({Map<String, dynamic>? metadata}) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: _itemId,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Fix the thing',
    description: 'A fix that produced a reviewable commit.',
    state: WorkItemState.agentCompleted,
    metadata: metadata,
    createdAt: now,
    updatedAt: now,
  );
}

/// Runs a real `Scheduler` tick for the review lane over [items], with no worker
/// behind it. The scheduler, the queue, the evaluator and the key builder under
/// test are all the production ones.
Future<SchedulerTickResult> _reviewTick(
  JobStore jobStore,
  List<WorkItem> items,
  _NoWorkerDispatch dispatch,
) async {
  final workflowStore = InMemoryWorkflowStore();
  for (final item in items) {
    await workflowStore.saveWorkItem(item);
  }
  return Scheduler(
    schedulerId: 'sched-review',
    workflowStore: workflowStore,
    jobStore: jobStore,
    workerStore: InMemoryWorkerStore(),
    dispatch: dispatch,
    definition: engineeringReviewDefinition,
    dedupeKeyBuilder: engineeringReviewDedupeKey,
    instructionBuilder: engineeringReviewInstruction,
    requestBuilder: engineeringReviewRequest,
    workload: const SchedulerWorkload(
      repositoryPath: '/durable/clone',
      startingRevision: 'aaaaaaa',
      timeoutSeconds: 1800,
      runtimeTypeId: 'rt-review',
    ),
    clock: () => DateTime.utc(2026, 1, 1),
  ).tick();
}

void main() {
  group('the engineering review key carries the attempt discriminator', () {
    test('a readable marker produces the suffixed key', () {
      expect(
        engineeringReviewDedupeKey(
          _reviewable(metadata: const {'triageAttempt': 3}),
          engineeringReviewDefinition,
        ),
        '$_itemId:engineering_review:a3',
      );
    });

    test('NO marker produces the HISTORICAL key, byte for byte', () {
      // The property both sibling builders hold sacred and this one inherits
      // rather than re-decides. Re-spelling the default would orphan every
      // engineering review job ever persisted under it and, on the next tick,
      // mint a SECOND job for a review already in flight.
      for (final metadata in <Map<String, dynamic>?>[
        null,
        const <String, dynamic>{},
        // An explicitly null marker reads null to `readTriageAttempt`, which
        // documents that both mean "never re-worked". It must build the bare
        // key too — the `20261014093000000` DOWN section records that they are
        // NOT the same to the reader, and this is the half that keeps them
        // behaving alike here.
        const {'triageAttempt': null},
        // Unrelated metadata must not be mistaken for a marker.
        const {'defectId': 'DEF-1', 'producerActorId': 'agx-wx-1'},
      ]) {
        expect(
          engineeringReviewDedupeKey(
            _reviewable(metadata: metadata),
            engineeringReviewDefinition,
          ),
          '$_itemId:engineering_review',
          reason: 'metadata: $metadata',
        );
      }
    });

    test('the marker is read by the ENGINE reader, not re-decided here', () {
      // Every shape `DurableWorkflowEngine.readTriageAttempt` accepts must
      // reach this builder unchanged. If the builder grew its own
      // "how a marker is read", one of these would build a different key from
      // the engine's writer — and the disagreement would not throw, it would
      // enqueue nothing.
      for (final marker in <Object>[1, 3, 1.0, 4.0, '2', '-1']) {
        expect(
          engineeringReviewDedupeKey(
            _reviewable(metadata: {'triageAttempt': marker}),
            engineeringReviewDefinition,
          ),
          '$_itemId:engineering_review:a'
          '${DurableWorkflowEngine.readTriageAttempt(_reviewable(metadata: {'triageAttempt': marker}))}',
          reason: 'marker: $marker (${marker.runtimeType})',
        );
      }
    });

    test('a present-but-unreadable marker THROWS rather than falling back', () {
      // Falling back would rebuild `…:engineering_review`, which the terminal
      // job the re-review exists to replace still holds — `created: false`, no
      // job, and an item that looks healthy while nothing runs.
      for (final marker in <Object>[
        'not-a-number',
        1.5,
        <String>['3'],
        true,
        const {'attempt': 3},
      ]) {
        expect(
          () => engineeringReviewDedupeKey(
            _reviewable(metadata: {'triageAttempt': marker}),
            engineeringReviewDefinition,
          ),
          throwsFormatException,
          reason: 'marker: $marker (${marker.runtimeType})',
        );
      }
    });
  });

  group('the builder is PURE with respect to persisted state', () {
    test('building the key changes nothing and consumes no attempt', () async {
      // Requirement, and the hazard the lane this builder sits in was already
      // caught doing once: `OD-10`'s completion inflow computed `attempt + 1`
      // inline instead of calling `nextTriageAttempt`, which is a third writer
      // to a counter whose own doc names "two writers, two different rules, one
      // counter". A key builder that advanced the counter would be a FOURTH
      // writer, and it would do it on every tick for every runnable item.
      final engine = DurableWorkflowEngine(store: InMemoryWorkflowStore());
      await engine.createWorkItem(
        workItemId: _itemId,
        productId: 'prod-1',
        category: WorkItemCategory.bugfix,
        title: 'Fix the thing',
        description: 'A fix that produced a reviewable commit.',
        metadata: const {'triageAttempt': 3},
      );

      final before = await engine.loadWorkItem(_itemId);
      final first = engineeringReviewDedupeKey(
        before,
        engineeringReviewDefinition,
      );
      final second = engineeringReviewDedupeKey(
        before,
        engineeringReviewDefinition,
      );
      final after = await engine.loadWorkItem(_itemId);

      expect(first, second, reason: 'a pure builder is a function');
      expect(
        after.metadata?['triageAttempt'],
        3,
        reason: 'building a key must not stamp, advance or reset the marker',
      );
      expect(
        DurableWorkflowEngine.nextTriageAttempt(after),
        4,
        reason:
            'the NEXT attempt is still available after the key was built. If '
            'the builder had advanced the counter, the key this item asks for '
            'on the tick after a re-work would skip a value and a key nothing '
            'holds could be minted twice.',
      );
      // Called a third time, and again from a re-read item: the answer must be
      // the same one the store gives, not one a builder remembered.
      expect(
        engineeringReviewDedupeKey(
          await engine.loadWorkItem(_itemId),
          engineeringReviewDefinition,
        ),
        first,
      );
    });

    test(
      'THE ADVANCE HAPPENS AT THE ENGINE, and it moves the key with it',
      () async {
        // Where the advance actually is. `operatorRetry` is one of the three
        // writers of this marker; it computes the number through
        // `nextTriageAttempt` and writes it inside the transition's own
        // transaction. This walks the real engine and then asks the builder for
        // the key, so the link between the two is executed rather than asserted.
        final engine = DurableWorkflowEngine(store: InMemoryWorkflowStore());
        await _seedFailedItem(engine);

        final before = await engine.loadWorkItem(_itemId);
        expect(before.metadata?['triageAttempt'], 3);
        expect(
          engineeringReviewDedupeKey(before, engineeringReviewDefinition),
          '$_itemId:engineering_review:a3',
        );

        final retried = await engine.operatorRetry(
          workItemId: _itemId,
          requestedBy: 'operator@example.com',
          reason: 'run it again',
          requestId: 'req-1',
        );
        expect(retried.metadata?['triageAttempt'], 4);

        final after = await engine.loadWorkItem(_itemId);
        expect(
          engineeringReviewDedupeKey(after, engineeringReviewDefinition),
          '$_itemId:engineering_review:a4',
          reason:
              'the re-review asks for the NEXT key, and the number it asks '
              'for is the one the engine wrote — which is the whole claim of '
              '"one counter, one reader, one rule". If the builder had its own '
              'arithmetic this would read :a3 again.',
        );
      },
    );
  });

  group('one ACTIVE review per item per attempt — the invariant is intact', () {
    test('two enqueues at the same key collide on ONE job', () async {
      // The suffix varies per ATTEMPT, and an attempt is the whole point at
      // which it is allowed to vary. Inside one attempt the key must still be
      // idempotent, or two schedulers could run two reviewers against one
      // artifact — and `AGENTS.md` fails closed on exactly that when the
      // reviewer is not the producer.
      final store = InMemoryJobStore();
      final queue = JobQueue(store: store);

      final first = await queue.enqueueIfAbsent(
        workItemId: _itemId,
        definition: engineeringReviewDefinition,
        dedupeKey: '$_itemId:engineering_review:a3',
        instruction: 'review it',
      );
      expect(first.created, isTrue);

      final second = await queue.enqueueIfAbsent(
        workItemId: _itemId,
        definition: engineeringReviewDefinition,
        dedupeKey: '$_itemId:engineering_review:a3',
        instruction: 'review it again',
      );
      expect(
        second.created,
        isFalse,
        reason: 'a second concurrent review of the SAME attempt must not run',
      );
      expect(second.job.jobId, first.job.jobId);
      expect(await store.listJobsForWorkItem(_itemId), hasLength(1));
    });

    test('two real scheduler ticks enqueue exactly ONE review job', () async {
      // The same rule through the real scheduler rather than through the queue
      // alone, because the queue is only half of it: the tick is what asks.
      final store = InMemoryJobStore();
      final dispatch = _NoWorkerDispatch();
      final items = [
        _reviewable(metadata: const {'triageAttempt': 3}),
      ];

      final first = await _reviewTick(store, items, dispatch);
      final second = await _reviewTick(store, items, dispatch);

      expect(first.enqueued, hasLength(1));
      expect(
        second.enqueued,
        isEmpty,
        reason: 'the second tick must find the key already held',
      );
      final jobs = await store.listJobsForWorkItem(_itemId);
      expect(jobs, hasLength(1), reason: 'two ticks, one job, one reviewer');
      expect(jobs.single.dedupeKey, '$_itemId:engineering_review:a3');
      expect(
        dispatch.requests,
        hasLength(2),
        reason:
            'the same single job is offered to dispatch on each tick — which is '
            'why a stub that reports "no compatible worker" is used: the claim '
            'under test is one JOB, not one dispatch attempt',
      );
    });

    test(
      'a DIFFERENT attempt does NOT collide — that is what the suffix buys',
      () async {
        final store = InMemoryJobStore();
        final dispatch = _NoWorkerDispatch();

        final held = await JobQueue(store: store).enqueueIfAbsent(
          workItemId: _itemId,
          definition: engineeringReviewDefinition,
          dedupeKey: '$_itemId:engineering_review:a3',
          instruction: 'review it',
        );
        expect(held.created, isTrue);

        // Same item, same lane, one re-work later. If the suffix were absent, or
        // computed from anything other than the marker, this enqueue would come
        // back `created: false` and the item would be inert with an unread
        // commit — the defect.
        final tick = await _reviewTick(store, [
          _reviewable(metadata: const {'triageAttempt': 4}),
        ], dispatch);

        expect(tick.enqueued, hasLength(1));
        final jobs = await store.listJobsForWorkItem(_itemId);
        expect(jobs, hasLength(2));
        expect(
          jobs.map((j) => j.dedupeKey),
          unorderedEquals([
            '$_itemId:engineering_review:a3',
            '$_itemId:engineering_review:a4',
          ]),
        );
      },
    );

    test(
      'a TERMINAL holder at the key this item asks for still blocks it',
      () async {
        // The property the fix must NOT weaken by making every key acceptable.
        // The queue refuses a key any non-cancelled job holds, terminal or not,
        // and that is what stops an unattended machine re-running a review for
        // ever.
        final store = InMemoryJobStore();
        final queue = JobQueue(store: store);
        final held = await queue.enqueueIfAbsent(
          workItemId: _itemId,
          definition: engineeringReviewDefinition,
          dedupeKey: '$_itemId:engineering_review:a3',
          instruction: 'review it',
        );
        await queue.complete(job: held.job, terminal: JobState.failed);
        expect((await store.readJob(held.job.jobId))!.state, JobState.failed);

        final dispatch = _NoWorkerDispatch();
        final tick = await _reviewTick(store, [
          _reviewable(metadata: const {'triageAttempt': 3}),
        ], dispatch);

        expect(
          tick.enqueued,
          isEmpty,
          reason:
              'the marker has not moved, so the item asks for the key it '
              'already asked for, and a terminal job keeps it. A suffix that '
              'defeated this guard would re-review the same artifact for ever',
        );
        expect(dispatch.requests, isEmpty);
      },
    );
  });
}

/// Walks a work item to `agentFailed` so `DurableWorkflowEngine.operatorRetry`
/// has a legal edge to take. Real transitions through the real engine — the
/// retry's whole contract is that it refuses an item it may not move, and a
/// hand-built `WorkItem` would not prove it ran at all.
Future<void> _seedFailedItem(DurableWorkflowEngine engine) async {
  await engine.createWorkItem(
    workItemId: _itemId,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Fix the thing',
    description: 'A fix that produced a reviewable commit.',
    metadata: const {'triageAttempt': 3},
  );
  await engine.transition(
    workItemId: _itemId,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: _itemId,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: const {'featureRef': 'feature/fix'},
  );
  await engine.transition(
    workItemId: _itemId,
    to: WorkItemState.designNotRequired,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: _itemId,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  await engine.transition(
    workItemId: _itemId,
    to: WorkItemState.agentFailed,
    trigger: TransitionTrigger.systemEvent,
  );
}

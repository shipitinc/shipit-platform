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
/// documentation and is not tested as if it were closed: a SECOND exhausted
/// review job on the same item, with no re-work in between, would ask for the
/// same suffix again. Human decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab` removed the `maxImplementationInflows`
/// bound that used to freeze this marker at 3 — so the marker now moves whenever
/// `agentCompleted -> implementationReady` is taken, and a frozen marker on an
/// item that is going nowhere (the shape that made the second refusal reachable
/// with nothing having happened) is gone with it. A separate change with a
/// separate owner would still be needed to count REVIEW attempts.
const _itemId = 'wi-1';

/// The second work item in the isolation tests: healthy, reviewable, and on
/// the same tick as the corrupt one. Named so that a failure says which item
/// the lane lost rather than just that something did.
const _healthyItemId = 'wi-2';

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
/// [id] names the item, so a tick can be given two of them and asked what one
/// unreadable marker costs the other.
WorkItem _reviewable({Map<String, dynamic>? metadata, String id = _itemId}) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: id,
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

  group('one UNREADABLE marker costs one item, not the review lane', () {
    // The blast radius this key inherited by throwing, and the bound on it.
    //
    // `readTriageAttempt` throws `FormatException` BY DESIGN on a
    // present-but-unreadable marker, and the builder inherits that rather than
    // re-deciding it — it must not fall back to the consumed unsuffixed key.
    // What it must not do either is take the whole tick down with it. The tick
    // is this lane's only outward channel, so an item whose key cannot be built
    // used to end `tick()` with an exception: `enqueued`, `dispatched` AND
    // `blockedArtifactMissing` were all lost for every OTHER reviewable item,
    // on every tick, for ever — while the composition root logged it as the
    // ordinary `review.tick.failed` it already expects to be retried. A single
    // corrupt byte starved the lane rather than parking one item.
    //
    // It is the same reader and the same shape as the completion inflow's
    // per-item guard (`scheduler.dart`, `_routeOneCompletion`), which fixes it
    // for `sched-impl`. This file proves the fix for THIS lane's call site.
    test('the tick RETURNS and the healthy item on it is still reviewed', () async {
      final store = InMemoryJobStore();
      final dispatch = _NoWorkerDispatch();

      // Corrupt item FIRST by id, so a tick that is not guarded throws before
      // it has considered anything else. There is no ordering of these two that
      // makes an unguarded tick survive, which is the point.
      final tick = await _reviewTick(store, [
        _reviewable(metadata: const {'triageAttempt': 'not-a-number'}),
        _reviewable(id: _healthyItemId),
      ], dispatch);

      // THE LANE SURVIVES. The healthy item was enqueued under the historical
      // key (it carries no marker) and offered to a reviewer.
      expect(
        tick.enqueued,
        hasLength(1),
        reason:
            'one unreadable marker must cost its own item and nothing else. '
            'Before the per-item guard, this tick threw out of `tick()` and no '
            'result at all existed to assert on',
      );
      final jobs = await store.listJobsForWorkItem(_healthyItemId);
      expect(jobs.single.dedupeKey, '$_healthyItemId:engineering_review');
      expect(
        dispatch.requests.single.workItemId,
        _healthyItemId,
        reason: 'and it reached a reviewer, rather than merely being enqueued',
      );

      // FAIL-CLOSED FOR THE REFUSED ITEM. No job, so nothing dispatches, so no
      // reviewer can be pointed at a revision chosen by a marker nobody could
      // read.
      expect(
        await store.listJobsForWorkItem(_itemId),
        isEmpty,
        reason:
            'the unreadable item must get NO review job. Falling back to the '
            'historical key would ask for one the previous attempt already '
            'holds and enqueue nothing while looking healthy; inventing a key '
            'would re-review for ever',
      );
    });

    test('the refusal is REPORTED, not swallowed', () async {
      final store = InMemoryJobStore();
      final dispatch = _NoWorkerDispatch();
      final corrupt = _reviewable(metadata: const {'triageAttempt': 1.5});

      final first = await _reviewTick(store, [corrupt], dispatch);
      final second = await _reviewTick(store, [corrupt], dispatch);

      for (final tick in [first, second]) {
        expect(
          tick.entryHopRefused.map((r) => r.workItemId),
          [_itemId],
          reason:
              'a silent skip is how this defect stayed invisible: the lane '
              'would look idle with no item to explain it',
        );
        final refusal = tick.entryHopRefused.single;
        expect(refusal.state, 'agent_completed');
        expect(
          refusal.reason,
          allOf(
            contains('no dedupe key could be built'),
            contains('Nothing ran and nothing was consumed'),
          ),
          reason:
              'the operator-facing reason must name what was refused and what '
              'it cost. An unreadable marker is a defect in whatever wrote it, '
              'and it repeats every tick until a human repairs it',
        );
        // NOT on `blockedArtifactMissing`, and deliberately so: that channel
        // carries JOB ids, and this item has none — the key was never built, so
        // there is nothing the composition root's missing-artifact handler
        // could read. The cost of that choice is that no blocking human
        // decision is raised for this item; it parks itself at its entry state
        // and is re-reported on every tick until the marker is repaired.
        expect(tick.blockedArtifactMissing, isEmpty);
      }

      // Nothing was consumed, on either tick: no job, no dispatch, no move.
      // That is the whole of what is observable here — the scheduler writes
      // work-item state only through the entry hop, which the review lane does
      // not take — and it is enough: the item is left reviewable, and the tick
      // after the marker is repaired reviews it normally.
      expect(first.enqueued, isEmpty);
      expect(second.enqueued, isEmpty);
      expect(dispatch.requests, isEmpty);
    });
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

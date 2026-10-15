import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:control_plane_server/server.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// Two lanes claim `agentCompleted`: `sched-review` (its `entryStates` IS that
/// state) and `sched-impl`, whose `completionInflowFrom` is that state. They run
/// in ONE tick in `server.dart`, each inside its own `try`, so the winner was
/// decided purely by which `await` came first.
///
/// The composition ticked review first. Review enqueued its job, its workload
/// resolver returned `null` (no commit), and `engineeringReviewMissingArtifact`
/// then parked the item at `waitingForHumanDecision` — before
/// `implScheduler.tick()` ever ran. The inflow saw an item that was no longer at
/// `agentCompleted`, did nothing, and `implementationReady` was never reached.
///
/// The failure was invisible from the outside: both ticks reported success. So
/// this file runs BOTH schedulers over the SAME real in-memory stores in BOTH
/// orders and asserts the item lands in the SAME place, making the outcome a
/// property of the handlers rather than of the composition's line numbers, and
/// a third test reads `server.dart` to pin which order the composition actually
/// uses.
///
/// Everything is real: the real `Scheduler`, the real `implementFeatureDefinition`
/// and `engineeringReviewDefinition`, the real
/// `engineeringReviewWorkloadResolver`, the real `DurableWorkflowEngine`, and the
/// real `engineeringReviewMissingArtifact`. The only fake is the worker dispatch,
/// which reports "no compatible worker" so nothing is executed and the tick stays
/// synchronous — the same technique the scheduler's own inflow tests use.
///
/// It cannot live in `packages/scheduler`: the handler under test is in
/// `apps/server`, and the dependency that would let a scheduler-package test
/// import it runs the wrong way.
const _startingRevision = 'aaaaaaa';

/// The second work item's commit, and the healthy sibling that proves a refused
/// item does not cost the lane. It differs from [_startingRevision], which is
/// the only thing that makes it an artifact rather than a report.
const _siblingItemId = 'wi-2';
const _siblingCommit = 'c2c2c2c';

/// Reports "no compatible worker" so the scheduler builds the request — proving
/// what it WOULD have dispatched — and never runs one.
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

class _Host {
  _Host._({
    required this.workflowStore,
    required this.engine,
    required this.executionStore,
    required this.workerStore,
    required this.jobStore,
    required this.dispatch,
    required this.implScheduler,
    required this.reviewScheduler,
  });

  /// A work item at `agentCompleted` whose producer left [endingRevision]
  /// behind — `null` being the triage shape that started all of this.
  ///
  /// [recordProducerExecution] writes the `agent_execution` row and its result
  /// the way a real `ExecutionCoordinator` would. It is ON by default because
  /// the fail-closed park cannot happen without it: `agentResultValid()` needs
  /// the producer's completed result, and the handler refuses to fabricate it.
  /// Turning it off reproduces the state the reviewer measured in the live QA
  /// database — zero `agent_execution_rows` — where the park silently does
  /// nothing.
  static Future<_Host> withProducer({
    required Map<String, dynamic> metadata,
    String? endingRevision,
    bool recordProducerExecution = true,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final workerStore = InMemoryWorkerStore();
    final jobStore = InMemoryJobStore();
    final executionStore = InMemoryExecutionStore();
    final dispatch = _NoWorkerDispatch();

    final now = DateTime.utc(2026, 1, 1);
    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: 'wi-1',
        productId: 'prod-1',
        category: WorkItemCategory.bugfix,
        title: 'The item under dispute',
        description: 'A producer finished and committed nothing.',
        state: WorkItemState.agentCompleted,
        metadata: metadata,
        createdAt: now,
        updatedAt: now,
      ),
    );
    // The real durable row shape: the coordinator stamps `producerActorId` on
    // the work item, `LocalWorker` records that same id as `agentExecutionId`
    // and sets `endingRevision` only when it commits.
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-1',
        workItemId: 'wi-1',
        repositoryPath: '/durable/clone',
        requestedStartingRevision: _startingRevision,
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.git,
        },
        agentExecutionId: 'agx-wx-1',
        endingRevision: endingRevision,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );
    if (recordProducerExecution) {
      await executionStore.saveExecution(
        AgentExecution(
          executionId: 'agx-wx-1',
          workItemId: 'wi-1',
          requestId: 'req-1',
          runtimeTypeId: 'rt-impl',
          role: AgentRole.implementer,
          status: AgentSessionStatus.completed,
          sessionId: 'ses-1',
          resultId: 'res-1',
          workspace: const AgentWorkspace(
            workspaceId: 'ws-1',
            path: '/durable/clone',
            startingRevision: _startingRevision,
          ),
          startedAt: now,
          completedAt: now,
        ),
      );
      await executionStore.saveResult('agx-wx-1', _producerResult());
    }

    final workload = SchedulerWorkload(
      repositoryPath: '/durable/clone',
      startingRevision: _startingRevision,
      timeoutSeconds: 300,
      runtimeTypeId: 'rt-review',
    );
    DateTime clock() => DateTime.utc(2026, 1, 1);

    return _Host._(
      workflowStore: workflowStore,
      engine: DurableWorkflowEngine(store: workflowStore),
      executionStore: executionStore,
      workerStore: workerStore,
      jobStore: jobStore,
      dispatch: dispatch,
      implScheduler: Scheduler(
        schedulerId: 'sched-impl',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: dispatch,
        definition: implementFeatureDefinition,
        workload: workload,
        dedupeKeyBuilder: implementFeatureDedupeKey,
        instructionBuilder: implementFeatureInstruction,
        requestBuilder: implementFeatureRequest,
        workloadResolver: (job, item) async => workload,
        clock: clock,
      ),
      reviewScheduler: Scheduler(
        schedulerId: 'sched-review',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: dispatch,
        definition: engineeringReviewDefinition,
        workload: workload,
        dedupeKeyBuilder: engineeringReviewDedupeKey,
        instructionBuilder: engineeringReviewInstruction,
        requestBuilder: engineeringReviewRequest,
        workloadResolver: engineeringReviewWorkloadResolver(
          workerStore: workerStore,
          runtimeTypeId: 'rt-review',
          // The one production budget, named so the resolver holds no literal of
          // its own. See `AgentExecutionBudgets` — PROVISIONAL.
          timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
        ),
        clock: clock,
      ),
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine engine;
  final InMemoryExecutionStore executionStore;
  final InMemoryWorkerStore workerStore;
  final InMemoryJobStore jobStore;
  final _NoWorkerDispatch dispatch;
  final Scheduler implScheduler;
  final Scheduler reviewScheduler;

  /// The composition root's review section, transcribed as a loop because it is
  /// one: tick, then handle every `blockedArtifactMissing` job.
  ///
  /// The transcription is minimal and deliberate. The composition root also
  /// installs tick HANDLERS for terminal jobs; those cannot fire here because
  /// nothing is ever dispatched, and copying them in would add code this file
  /// cannot exercise.
  ///
  /// Returns the tick result so a test can assert on the channels the handler
  /// loop above did NOT act on — which is where an unreadable marker lands.
  Future<SchedulerTickResult> runReviewSection() async {
    final tick = await reviewScheduler.tick();
    for (final jobId in tick.blockedArtifactMissing) {
      final job = await jobStore.readJob(jobId);
      if (job == null) continue;
      await engineeringReviewMissingArtifact(
        workflowEngine: engine,
        executionStore: executionStore,
        workerStore: workerStore,
        job: job,
        logger: (_, __) {},
      );
    }
    return tick;
  }

  Future<WorkItem> run({required bool reviewFirst}) async {
    if (reviewFirst) {
      await runReviewSection();
      await implScheduler.tick();
    } else {
      await implScheduler.tick();
      await runReviewSection();
    }
    return engine.loadWorkItem('wi-1');
  }
}

/// The completed producer result a real coordinator would have persisted. It
/// exists here only so the fail-closed park has the evidence
/// `agentResultValid()` insists on; the handler must never fabricate one.
AgentResult _producerResult() => AgentResult(
  resultId: 'res-1',
  sessionId: 'ses-1',
  workItemId: 'wi-1',
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: const AgentDiagnostics(
    exitCode: 0,
    durationMs: 1,
    toolCalls: 1,
    errors: [],
    warnings: [],
  ),
  structuredResult: const {},
  summary: 'producer run',
  completedAt: DateTime.utc(2026, 1, 1),
);

const _noArtifact = {'producerActorId': 'agx-wx-1'};

/// Adds a SECOND reviewable work item to [host]: its producer really committed
/// [_siblingCommit] and its marker is absent, so it is reviewable on every tick.
///
/// It exists so that "the tick survived" is not an assertion about a tick that
/// had nothing else to do. A test with only the corrupt item proves the item
/// did not throw; only a test with a second item proves the LANE did not.
Future<void> _addReviewableSibling(_Host host) async {
  final now = DateTime.utc(2026, 1, 1);
  await host.workflowStore.saveWorkItem(
    WorkItem(
      workItemId: _siblingItemId,
      productId: 'prod-1',
      category: WorkItemCategory.bugfix,
      title: 'A second, healthy defect',
      description: 'A producer finished and committed real code.',
      state: WorkItemState.agentCompleted,
      metadata: const {'producerActorId': 'agx-wx-2'},
      createdAt: now,
      updatedAt: now,
    ),
  );
  await host.workerStore.saveWorkerExecution(
    WorkerExecution(
      workerExecutionId: 'wx-2',
      workItemId: _siblingItemId,
      repositoryPath: '/durable/clone',
      requestedStartingRevision: _startingRevision,
      requiredCapabilities: const {
        WorkerCapability.linux,
        WorkerCapability.git,
      },
      agentExecutionId: 'agx-wx-2',
      endingRevision: _siblingCommit,
      status: WorkerExecutionStatus.executedPass,
      cleanupPolicy: WorkerCleanupPolicy.removeAlways,
    ),
  );
}

void main() {
  group('a no-artifact producer lands in the SAME state in BOTH tick orders', () {
    // The regression. With review first and a parking handler that did not stand
    // down, this item finished at `waitingForHumanDecision` and the
    // implementation lane dispatched nothing, for ever.
    for (final reviewFirst in const [false, true]) {
      test(
        reviewFirst
            ? 'review FIRST: the item still reaches implementationReady'
            : 'implementation first: the item reaches implementationReady',
        () async {
          final host = await _Host.withProducer(metadata: _noArtifact);

          final item = await host.run(reviewFirst: reviewFirst);

          expect(
            item.state,
            WorkItemState.implementationReady,
            reason:
                'a producer that committed nothing left nothing to review, so '
                'the item belongs to the lane that can do the work. This '
                'assertion is the whole point of the stand-down and of the '
                'reordering: it must hold whichever `await` comes first.',
          );
          expect(
            item.blockingHumanDecisionId,
            isNull,
            reason:
                'no human gate may be raised for an item the platform routes '
                'itself. The only answers on that decision are rework and '
                'reject, both of which are the wrong question here.',
          );
          expect(
            host.dispatch.requests.where(
              (r) => r.role == AgentRole.implementer,
            ),
            hasLength(1),
            reason:
                'the routed item is genuinely DISPATCHED in the same tick, not '
                'routed and then left for the next one',
          );
          if (!reviewFirst) {
            // AND, in the composition's own order, review never even builds a
            // request for this item. Implementation ticks first and takes it;
            // review's entry set no longer contains it; the job review left
            // behind is retired as `noAction`. That is what makes the
            // disjointness structural instead of accidental — the reason the
            // ordering matters is not only who wins, it is that after the
            // reorder there is nothing left to contend over.
            expect(
              host.dispatch.requests.where(
                (r) => r.role == AgentRole.engineeringReviewer,
              ),
              isEmpty,
              reason:
                  'review must not attempt a dispatch for an item the '
                  'implementation inflow already owns',
            );
          }
        },
      );
    }
  });

  group('the stand-down is about the WORK, not about tick order', () {
    test(
      'an item whose producer DID commit is left to review in both orders',
      () async {
        // The other side of the discriminator, and the one where being wrong is
        // expensive: routing a real commit to a second implementer manufactures a
        // duplicate commit into a governed repository.
        for (final reviewFirst in const [false, true]) {
          final host = await _Host.withProducer(
            metadata: _noArtifact,
            endingRevision: 'a-real-commit',
          );

          final item = await host.run(reviewFirst: reviewFirst);

          expect(
            item.state,
            WorkItemState.agentCompleted,
            reason:
                'review-first is $reviewFirst: a commit exists, so this is '
                'review\'s item and the inflow must not touch it',
          );
          expect(
            host.dispatch.requests.where(
              (r) => r.role == AgentRole.implementer,
            ),
            isEmpty,
            reason:
                'sending a real commit to a second implementer manufactures a '
                'duplicate commit into a governed repository. This is the input '
                'on which the two lanes must never contend, and the one the '
                'whole discriminator exists for',
          );
          if (!reviewFirst) {
            expect(
              host.dispatch.requests.where(
                (r) => r.role == AgentRole.engineeringReviewer,
              ),
              hasLength(1),
              reason:
                  'and the reviewer is dispatched at the PRODUCED revision, not '
                  'at the construction-time one',
            );
            expect(
              host.dispatch.requests
                  .where((r) => r.role == AgentRole.engineeringReviewer)
                  .single
                  .startingRevision,
              'a-real-commit',
            );
          }
        }
      },
    );

    test(
      'the bound still reaches a human: with no budget left, review PARKS',
      () async {
        // The one case the stand-down must NOT swallow. When the shared re-work
        // discriminator is already at `maxImplementationInflows`, the inflow will
        // not route this item — so standing down would leave it at
        // `agentCompleted` for ever with nobody acting on it. That is the whole
        // purpose of the human gate, and both sides read the same number so they
        // cannot disagree about whether the budget is spent.
        //
        // BOTH orders, because the bound is exactly the case whose reachability
        // used to depend on which tick went first.
        for (final reviewFirst in const [false, true]) {
          final host = await _Host.withProducer(
            metadata: const {
              'producerActorId': 'agx-wx-1',
              'triageAttempt': maxImplementationInflows,
            },
          );

          final item = await host.run(reviewFirst: reviewFirst);

          expect(
            item.state,
            WorkItemState.waitingForHumanDecision,
            reason:
                'review-first is $reviewFirst: an item the implementation lane '
                'has exhausted its budget on belongs in front of a person, not in '
                'a loop',
          );
          expect(item.blockingHumanDecisionId, isNotNull);
          final decision = await host.workflowStore.readHumanDecision(
            item.blockingHumanDecisionId!,
          );
          expect(decision.decisionType, HumanDecisionType.engineeringReview);
          expect(decision.blocking, isTrue);
        }
      },
    );

    test(
      'an unreadable producer is refused fail-closed, and the lane survives it',
      () async {
        // `readTriageAttempt` throws by design on a present-but-unreadable
        // marker, and falling back would rebuild a dedupe key a terminal job
        // already holds. An unreadable answer must NOT be read as "the inflow
        // will take it" — and it must not be read as "this tick is over".
        //
        // WHAT IS ASSERTED NOW, AND WHY IT IS NOT THE OLD ASSERTION. This test
        // used to require `waitingForHumanDecision`. It no longer does, and the
        // reason is the cost of refusing inside the scheduler instead of wiring
        // a new channel: the human gate is reachable only through
        // `reviewTick.blockedArtifactMissing`, that channel carries JOB ids, and
        // an unreadable marker means no key was built and therefore NO JOB
        // exists to report. So the refusal lands on `entryHopRefused` — which
        // the composition root does not yet read — and the item parks ITSELF at
        // `agentCompleted`, reviewable again on the tick after a human repairs
        // the marker. Raising a blocking decision for it needs new wiring in
        // `apps/server/lib`, which this lane does not own.
        //
        // What is NOT negotiable, and is what replaces that assertion: the
        // unreadable item gets NO review job, and every OTHER reviewable item
        // on the same tick is still reviewed. Before the per-item guard the
        // `FormatException` escaped `reviewScheduler.tick()` entirely, so the
        // whole tick result was lost — for the healthy item as well as the
        // corrupt one — and the composition root logged the ordinary
        // `review.tick.failed` it expects to be retried. Starvation reads
        // exactly like transient noise.
        final host = await _Host.withProducer(
          metadata: const {
            'producerActorId': 'agx-wx-1',
            'triageAttempt': 'not-a-number',
          },
        );
        await _addReviewableSibling(host);

        // The composition's order: implementation first.
        final implTick = await host.implScheduler.tick();
        expect(
          implTick.completionInflow.where((move) => move.moved),
          isEmpty,
          reason:
              'an unreadable answer moves nothing in either direction — the '
              'item stays where it is, so the review lane is still offered it',
        );

        final reviewTick = await host.runReviewSection();

        // FAIL-CLOSED, FOR THAT ITEM. No key, so no job, so no reviewer can be
        // pointed at a revision chosen by a marker nobody could read.
        expect(
          await host.jobStore.listJobsForWorkItem('wi-1'),
          isEmpty,
          reason:
              'the item with the unreadable discriminator must get no review '
              'job at all',
        );
        expect(
          reviewTick.entryHopRefused.map((r) => r.workItemId),
          ['wi-1'],
          reason:
              'and it must be REPORTED. A silent skip leaves a lane that looks '
              'idle with no item to explain it',
        );
        expect(
          reviewTick.blockedArtifactMissing,
          isEmpty,
          reason:
              'which is exactly why no blocking human decision is raised for '
              'it: that channel is keyed by job id and this item never had one',
        );

        // THE LANE SURVIVES. The sibling on the SAME tick was enqueued and
        // offered to a reviewer at the revision its producer left. Without this
        // half the test would pass on a tick that did nothing at all.
        expect(
          (await host.jobStore.listJobsForWorkItem(
            _siblingItemId,
          )).single.dedupeKey,
          '$_siblingItemId:engineering_review',
          reason: 'the healthy item asked for the historical key and got it',
        );
        expect(
          host.dispatch.requests
              .where((r) => r.role == AgentRole.engineeringReviewer)
              .single
              .startingRevision,
          _siblingCommit,
          reason:
              'and it was DISPATCHED at its produced revision, not merely '
              'enqueued. One unreadable byte on one item costs that item; it '
              'does not cost the review lane, and this is the half that says so',
        );

        final item = await host.engine.loadWorkItem('wi-1');
        expect(
          item.state,
          WorkItemState.agentCompleted,
          reason:
              'the item is left exactly where it was rather than parked or '
              'moved — nothing ran and nothing was consumed, and it is still '
              'reviewable the moment the marker is readable',
        );
        expect(item.blockingHumanDecisionId, isNull);
      },
    );
  });

  group('the composition root ticks implementation FIRST', () {
    // Read as text, because `apps/server/lib/server.dart` needs a database, a
    // live agent runtime and a worker registry to run — the same reason
    // `packages/scheduler/test/implementation_composition_wiring_test.dart` reads
    // it. What is being pinned is an ORDER, which no in-process harness can
    // observe: the harness above proves the outcome is order-independent, and
    // only this proves what the composition actually does.
    late String source;

    setUpAll(() {
      source = File('lib/server.dart').readAsStringSync();
    });

    test('implScheduler.tick() appears before reviewScheduler.tick()', () {
      final impl = source.indexOf('await implScheduler.tick();');
      final review = source.indexOf('await reviewScheduler.tick();');
      expect(impl, greaterThan(-1), reason: 'the lane must be ticked');
      expect(review, greaterThan(-1), reason: 'review must be ticked');
      expect(
        impl,
        lessThan(review),
        reason:
            'review\'s fail-closed handler moves work items, and '
            'sched-impl\'s inflow only sees items still at agent_completed. '
            'Ticking review first lets the handler pre-empt the inflow; the '
            'stand-down in engineeringReviewMissingArtifact is the belt to '
            'this braces, and this ordering is the braces.',
      );
    });

    test('the ordering is stated where a reader will see it', () {
      // A reorder that leaves no explanation re-creates the defect silently,
      // because the two orderings now behave identically.
      final impl = source.indexOf("schedulerId: 'sched-impl'");
      expect(impl, greaterThan(-1));
      final tick = source.indexOf('await implScheduler.tick();');
      final note = source.substring(
        impl,
        tick,
      );
      expect(
        note,
        contains('FIRST of the two lanes that share `agentCompleted`'),
        reason:
            'the one section whose position is load-bearing must say so '
            'immediately above itself, where a reader editing the order will '
            'see it',
      );
    });
  });
}

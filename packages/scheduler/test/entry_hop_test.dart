import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/controlled_dispatcher.dart';
import 'support/gate_fake_agent.dart';
import 'support/file_host.dart';
import 'support/git_repo_fixture.dart';
import 'support/scheduler_host.dart';

/// A work item can be RUNNABLE and still not STARTABLE, and the difference
/// between the two costs a whole worker execution per attempt.
///
/// `triageDefectDefinition` lists `reviewRejected` as an entry state and names
/// its legal route in `entryProbeTargets` — `reviewRejected ->
/// designNotRequired`, an ordinary orchestrator edge into an ordinary entry
/// state. The probe asked about that edge, the policy said yes, and the
/// scheduler enqueued and dispatched. But `ExecutionCoordinator.execute`
/// attempts the DIRECT edge `<entryState> -> agentExecuting`, and
/// `reviewRejected -> agentExecuting` is not in the table — so it refused every
/// time, after `LocalWorker` had already prepared a real git worktree at
/// local_worker.dart:152. Twenty-five ticks, seven executions.
///
/// This suite is the whole defect class, not that one instance:
///
///   * a rejected review now HOPS to the state it can execute from and really
///     runs — real coordinator, real worker, real worktree, real result;
///   * that is BOUNDED: one execution across twenty-five ticks;
///   * the other instance of the class (a design-rejected item) enqueues nothing
///     at all, because no legal route to execution exists for it; and
///   * the deferral bound counts a WORK ITEM across the re-minted jobs a cycle
///     produces, instead of restarting on every remint.
///
/// The invariant behind all of it is checked exhaustively, over every
/// production definition, in `entry_hop_drift_guard_test.dart`.
void main() {
  late Directory temp;
  late GitRepoFixture? repo;

  setUp(() {
    repo = null;
    temp = Directory.systemTemp.createTempSync('entry_hop_test');
  });
  tearDown(() {
    repo?.dispose();
    repo = null;
    temp.deleteSync(recursive: true);
  });

  /// A full-stack host on the REAL `triage_defect` definition: real workflow
  /// engine and store, real execution coordinator, real `LocalWorker` with a
  /// real git worktree and a real verifier, real scheduler.
  SchedulerHost realHost({
    JobDefinition definition = triageDefectDefinition,
    Set<WorkerCapability> capabilities = const {
      WorkerCapability.linux,
      WorkerCapability.git,
    },
    AgentAdapter? adapter,
  }) {
    repo ??= GitRepoFixture.create('${temp.path}/repo');
    return SchedulerHost(
      repo: repo!,
      workspaceRoot: '${temp.path}/workspaces',
      jobStore: InMemoryJobStore(),
      definition: definition,
      workerCapabilities: capabilities,
      adapter: adapter,
    );
  }

  group('the legal intermediate hop is taken, and the work really runs', () {
    test(
      'a rejected engineering review hops to the state it can execute from and '
      'a real agent produces a real result on it',
      () async {
        final host = realHost();
        await itemRejectedAtEngineeringReviewGate(
          host.workflowEngine,
          host.designContractStore,
        );
        expect(
          (await host.workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.reviewRejected,
        );

        host.session.release();
        final tick = await host.scheduler.tick();

        // One job, dispatched, and this time it SUCCEEDED.
        expect(tick.enqueued, hasLength(1));
        final job = (await host.jobStore.listJobs()).single;
        expect(tick.dispatched, [job.jobId]);
        expect(
          (await host.jobStore.readJob(job.jobId))!.state,
          JobState.succeeded,
        );

        // A REAL agent execution exists. This is the assertion the reviewed
        // head could not make: the coordinator wrote the row, so the refusal
        // that used to happen here did not.
        final workerRow = await readWorkerExecutionOrFail(
          host,
          'wx-${job.jobId}',
        );
        expect(workerRow.status, WorkerExecutionStatus.executedPass);
        final agentExecutionId = workerRow.agentExecutionId;
        expect(
          agentExecutionId,
          isNotNull,
          reason: 'a real agent execution id, minted and completed',
        );
        final execution = await host.executionStore.readExecutionOrNull(
          agentExecutionId!,
        );
        expect(
          execution,
          isNotNull,
          reason:
              'this row exists only when the coordinator did not refuse before '
              'starting an execution — which is exactly what it used to do here',
        );
        expect(execution!.status, AgentSessionStatus.completed);
        // ignore: unnecessary_statements

        // And the agent really produced a result, through the real runtime and
        // the real verifier, in a real prepared worktree.
        final result = await host.executionStore.readResult(agentExecutionId);
        expect(result, isNotNull, reason: 'the real agent produced a result');
        expect(result!.status, AgentResultStatus.completed);
        expect(result.summary, isNotEmpty);
        expect(host.session.wasStarted, isTrue);
        expect(host.coordinator.liveSessionCount, 0);
      },
    );

    test(
      'the hop is recorded durably, by the scheduler, BEFORE the coordinator '
      'ever attempted an execution',
      () async {
        final host = realHost();
        await itemRejectedAtEngineeringReviewGate(
          host.workflowEngine,
          host.designContractStore,
        );

        host.session.release();
        await host.scheduler.tick();

        final history = await host.workflowStore.readTransitionHistory('wi-1');
        final hops = history
            .where(
              (r) =>
                  r.fromState == WorkItemState.reviewRejected &&
                  r.toState == WorkItemState.designNotRequired,
            )
            .toList();
        expect(
          hops,
          hasLength(1),
          reason:
              'exactly one hop, taken once. A hop repeated per tick would be '
              'the same unbounded cycle wearing a different hat',
        );
        expect(hops.single.outcome, TransitionOutcome.accepted);
        expect(
          hops.single.actorId,
          schedulerOrchestratorActor.actorId,
          reason: 'the scheduler acted as the orchestrator, its only identity',
        );

        final hopIndex = history.indexOf(hops.single);
        // The SEED walk contains agentExecuting transitions of its own, so the
        // execution edge under test is the LAST one — the hop must precede it.
        final executionIndex = history.lastIndexWhere(
          (r) => r.toState == WorkItemState.agentExecuting,
        );
        expect(executionIndex, isNot(-1), reason: 'the run really happened');
        expect(
          hopIndex,
          lessThan(executionIndex),
          reason: 'hop first, execution second — never the other way round',
        );
      },
    );

    test(
      'one job, one execution, bounded — across twenty-five ticks, where the '
      'reviewed head produced seven',
      () async {
        // The measurement the review made, re-made as a regression bound. Far
        // more ticks than any honest work needs: the failure mode is ONE
        // dispatch PER TICK, so the bound only means anything well above the
        // real duration of the work.
        final host = realHost();
        await itemRejectedAtEngineeringReviewGate(
          host.workflowEngine,
          host.designContractStore,
        );

        host.session.release();
        for (var i = 0; i < 25; i++) {
          await host.scheduler.tick();
        }

        final jobs = await host.jobStore.listJobs();
        expect(jobs, hasLength(1));
        expect(jobs.single.state, JobState.succeeded);
        expect(
          await host.workerStore.listWorkerExecutions(),
          hasLength(1),
          reason:
              'the reviewed head reached seven worker executions in '
              'twenty-five ticks on this same item, each burning a real '
              'worktree prepare before the coordinator refused it',
        );
        expect(await host.executionStore.listExecutions(), hasLength(1));
      },
    );

    test(
      'a real agent FAILURE on a still-runnable item still fails terminally — '
      'the hop changed no outcome vocabulary',
      () async {
        // Not scripted at the scheduler boundary: a real session fails, the real
        // coordinator drives it, the real worker reports it. Nothing ran it
        // through the supersession branch, because nothing was superseded.
        final host = realHost(
          adapter: FailingFakeAgentAdapter(
            FailingFakeAgentSession(
              executionId: 'agx-fail',
              workItemId: 'wi-1',
            ),
          ),
        );
        await host.itemRunnable();

        final tick = await host.scheduler.tick();

        expect(tick.enqueued, hasLength(1));
        final job = (await host.jobStore.listJobs()).single;
        final adopted = (await host.jobStore.readJob(job.jobId))!;
        expect(
          adopted.state,
          JobState.failed,
          reason:
              'a permanent agent failure stays terminal. The requeue branch is '
              'reached only through the supersession marker, which this detail '
              'does not carry',
        );
        expect(adopted.failure, isNotNull);
        expect(
          adopted.cancelReason,
          isNull,
          reason: 'and it is a failure, not a quiet cancellation',
        );
        expect(
          (await host.executionStore.listExecutions()),
          hasLength(1),
          reason: 'an execution really was started, and really failed',
        );
      },
    );
  });

  group('the whole class, not the instance', () {
    test('a design-rejected item is never enqueued, never dispatched and never '
        'burns a worker execution — across many ticks', () async {
      // The second instance the review measured: five jobs and five executions
      // for one item, because `designRevisionDefinition` skipped the workflow
      // policy check and so answered "runnable" for an entry state the
      // coordinator can never act on.
      final host = realHost(
        definition: designRevisionDefinition,
        capabilities: const {
          WorkerCapability.linux,
          WorkerCapability.penpotWrite,
          WorkerCapability.visualDesign,
        },
      );
      await itemDesignRejected(host);

      for (var i = 0; i < 25; i++) {
        await host.scheduler.tick();
      }

      expect(
        await host.jobStore.listJobs(),
        isEmpty,
        reason: 'no legal route to execution exists, so no job is minted',
      );
      expect(await host.workerStore.listWorkerExecutions(), isEmpty);
      expect(await host.executionStore.listExecutions(), isEmpty);
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.designRejected,
        reason: 'and the scheduler did not move it either',
      );
    });

    test(
      'a design-revision job still runs from `designRequired`, so closing the '
      'loop cost this definition nothing it could actually do',
      () async {
        // The probe is live again for this definition, so the other entry state
        // must still work. `designRequired -> agentExecuting` is legal, so it
        // does.
        final host = realHost(
          definition: designRevisionDefinition,
          capabilities: const {
            WorkerCapability.linux,
            WorkerCapability.penpotWrite,
            WorkerCapability.visualDesign,
          },
        );
        await itemAtDesignRequired(
          host.workflowEngine,
          host.workflowStore,
          host.designContractStore,
        );

        host.session.release();
        final tick = await host.scheduler.tick();

        expect(tick.enqueued, hasLength(1));
        expect(tick.dispatched, hasLength(1));
        expect(
          (await host.jobStore.listJobs()).single.state,
          JobState.succeeded,
        );
      },
    );

    test(
      'a definition that mis-declares an unreachable entry state is REFUSED and '
      'reported, not dispatched into the coordinator',
      () async {
        // The structural half of the class guard: even if a definition somehow
        // says "runnable" for a state the coordinator cannot act on, the hop
        // decision refuses it BEFORE any dispatch, so the burn stops at zero
        // executions rather than at the deferral cap.
        final host = realHost(definition: _misdeclaredUnreachableEntry);
        await itemDesignRejected(host);

        final tick = await host.scheduler.tick();

        expect(tick.entryHopRefused, hasLength(1));
        expect(tick.entryHopRefused.single.workItemId, 'wi-1');
        expect(tick.entryHopRefused.single.reason, contains('no route'));
        expect(tick.enqueued, isEmpty);
        expect(await host.jobStore.listJobs(), isEmpty);
        expect(await host.workerStore.listWorkerExecutions(), isEmpty);
        expect(
          (await host.workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.designRejected,
          reason: 'a refused hop moves nothing',
        );
      },
    );
  });

  group('the hop cannot strand the item', () {
    test(
      'a hop the policy will not let the scheduler take is REFUSED, and moves '
      'nothing',
      () async {
        final t0 = DateTime.utc(2026, 1, 1, 12);
        final host = FileRestartHarness(
          temp,
          clock: () => t0,
          definition: triageDefectDefinition,
        );
        await itemAtAgentExecuting(host.workflowEngine, host.workflowStore);

        // `agentExecuting -> agentCompleted` exists but is guarded by
        // `agentResultValid()`, which needs the COMPLETED result of an agent
        // that ran — and no agent ran. The scheduler cannot supply it and must
        // not pretend it can, so it refuses rather than queueing a write the
        // engine would reject.
        const guarded = JobDefinition(
          jobType: JobType.triageDefect,
          requiredRole: AgentRole.triageDefect,
          requiredCapabilities: {WorkerCapability.linux},
          entryStates: {WorkItemState.agentExecuting},
          entryProbeTargets: {
            WorkItemState.agentExecuting: WorkItemState.agentCompleted,
          },
        );

        final result = await hopFor(host, guarded);
        expect(result.status, EntryHopStatus.refused);
        expect(result.dispatchable, isFalse);
        expect(result.reason, contains('workflow policy does not let'));
        expect(
          (await host.workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentExecuting,
        );
      },
    );

    test('a hop landing on a state this definition cannot dispatch from is '
        'REFUSED, because taking it would strand the work', () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      final host = FileRestartHarness(
        temp,
        clock: () => t0,
        definition: triageDefectDefinition,
      );
      await itemAtDesignRejected(
        host.workflowEngine,
        host.workflowStore,
        host.designContractStore,
      );

      // `designRejected` has NO direct edge to `agentExecuting`, and the one
      // out-edge it does have lands on `designInReview` — which is in no entry
      // set here. Taking that hop would leave the item in a state nothing
      // dispatches, and the next tick would retire the job as superseded.
      // Refused instead. This is exactly the trap a design-revision route
      // would have fallen into.
      const stranding = JobDefinition(
        jobType: JobType.triageDefect,
        requiredRole: AgentRole.triageDefect,
        requiredCapabilities: {WorkerCapability.linux},
        entryStates: {WorkItemState.designRejected},
        entryProbeTargets: {
          WorkItemState.designRejected: WorkItemState.designInReview,
        },
      );

      final result = await hopFor(host, stranding);
      expect(result.status, EntryHopStatus.refused);
      expect(result.reason, contains('not an entry state'));
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.designRejected,
      );
    });

    test(
      'an entry state the coordinator can act on directly is never moved',
      () async {
        final t0 = DateTime.utc(2026, 1, 1, 12);
        final host = FileRestartHarness(
          temp,
          clock: () => t0,
          definition: triageDefectDefinition,
        );
        await host.itemRunnable();

        // Even a definition that DECLARES a hop for a state that does not need
        // one must not take it: `designNotRequired -> agentExecuting` exists, so
        // the coordinator can start directly and moving the item would be an
        // unrequested write.
        const redundantHop = JobDefinition(
          jobType: JobType.triageDefect,
          requiredRole: AgentRole.triageDefect,
          requiredCapabilities: {WorkerCapability.linux},
          entryStates: {WorkItemState.designNotRequired},
          entryProbeTargets: {
            WorkItemState.designNotRequired: WorkItemState.designApproved,
          },
          skipWorkflowPolicyCheck: true,
        );

        final result = await hopFor(host, redundantHop);
        expect(result.status, EntryHopStatus.direct);
        expect(result.item.state, WorkItemState.designNotRequired);
        expect(
          (await host.workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.designNotRequired,
          reason: 'a direct route is dispatched as-is, never hopped',
        );
      },
    );
  });
  group('deferrals are counted per WORK ITEM, across re-mints', () {
    test(
      'a re-minted job inherits the bound its predecessor already spent',
      () async {
        // The cap used to be counted from ONE job's event log. Firing CANCELS the
        // job, a cancelled job YIELDS its dedupe key (`enqueueIfAbsent`,
        // job_queue.dart:76), and the next tick mints a fresh job with an empty
        // log — so the count restarted at zero on every remint and the bound
        // described one lap of the queue rather than the cycle that spins.
        final t0 = DateTime.utc(2026, 1, 1, 12);
        final dispatch = ControlledDispatcher()
          ..resultBuilder = (r) async => supersededResult(r);
        final host = FileRestartHarness(
          temp,
          clock: () => t0,
          dispatch: dispatch,
          definition: triageDefectDefinition,
        );
        await host.itemRunnable();
        final first = await host.scheduler.tick();
        expect(first.enqueued, hasLength(1));
        final firstJob = (await host.jobStore.listJobs()).single;

        // Drive the first job until the bound fires: cancelled, having spent the
        // deferral budget without ever spending an attempt.
        Job? exhausted;
        for (var i = 0; i < 8; i++) {
          await host.scheduler.tick();
          final current = await host.jobStore.readJob(firstJob.jobId);
          exhausted = current;
          if (current?.state == JobState.cancelled) break;
        }
        expect(
          exhausted?.state,
          JobState.cancelled,
          reason: 'the deferral bound must stop the cycle',
        );
        expect(
          exhausted?.attempt,
          1,
          reason: 'still no attempt spent: no execution ever started',
        );

        // WHILE THE ITEM SITS STILL, the re-mint does not happen at all.
        //
        // This is the behaviour `review_stall_test.dart` exists to pin, and it
        // is asserted here too because this file is where the "a re-minted job
        // inherits the bound" claim is made — a claim that used to be provable
        // only by letting the churn run. The cap fires on the JOB; the producer
        // is what has to stop, or the same tick mints a fresh job, supersedes
        // it, cancels it, and repeats. Asserted as a COUNT, because the work
        // item's state is `design_not_required` either way and cannot tell a
        // stopped lane from a spinning one.
        final stalled = await host.scheduler.tick();
        expect(
          stalled.stalled.map((s) => s.workItemId),
          contains('wi-1'),
          reason: 'and the conclusion is reported, not discarded',
        );
        expect(
          await host.jobStore.listJobsForWorkItem('wi-1'),
          hasLength(1),
          reason:
              'no fresh job for a stationary item. Before the producer was '
              'gated, this count grew by one every tick — the 214-jobs-each QA '
              'measured on 2026-10-15',
        );

        // Now let the item genuinely MOVE, which is the one condition under
        // which a re-mint is still owed: the recorded diagnosis described an
        // item that had not progressed, and this one has.
        const hop = {'agentAvailable': true, 'capabilitiesMatch': true};
        await host.workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          context: hop,
        );
        await host.workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
        );
        await host.workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.designNotRequired,
          trigger: TransitionTrigger.systemEvent,
        );

        // The cancelled job yields the key, so the next tick mints a FRESH job
        // for the same work item — the remint whose count used to reset.
        final remint = await host.scheduler.tick();
        expect(remint.enqueued, hasLength(1));
        final secondJob = (await host.jobStore.readJob(
          remint.enqueued.single,
        ))!;
        expect(secondJob.jobId, isNot(firstJob.jobId), reason: 'a FRESH row');
        expect(
          secondJob.dedupeKey,
          firstJob.dedupeKey,
          reason: 'under the same key, because the cancelled row yielded it',
        );

        // Its FIRST supersession — the one dispatched by that very same tick —
        // must already see the spent budget.
        expect(remint.dispatched, [secondJob.jobId]);
        final second = secondJob;
        expect(
          second.state,
          JobState.cancelled,
          reason:
              'the work item has already been deferred three times across every '
              'job it has held, and moving it did not move the COUNT. A '
              'per-row count restarts on the fresh row and requeues this one, '
              'which is the unbounded cycle',
        );
        expect(second.attempt, 1, reason: 'and still no attempt was spent');
        expect(second.cancelReason, contains('superseded'));
        expect(
          second.cancelReason,
          contains('re-minted'),
          reason:
              'the reason an operator reads must say the bound survived the '
              're-mint, because that is the thing that was actually fixed',
        );
      },
    );

    test('the count is per work item, so one item burning its budget does not '
        'strand another', () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => supersededResult(r);
      final host = FileRestartHarness(
        temp,
        clock: () => t0,
        dispatch: dispatch,
        definition: triageDefectDefinition,
      );
      await host.itemRunnable(workItemId: 'wi-1');

      // wi-1 burns its whole budget first, on its own.
      for (var i = 0; i < 8; i++) {
        await host.scheduler.tick();
      }

      final wi1 = await host.jobStore.listJobsForWorkItem('wi-1');
      expect(
        wi1.where((j) => j.state == JobState.cancelled),
        isNotEmpty,
        reason: 'wi-1 exhausted its bound',
      );

      // wi-2 arrives afterwards and has spent nothing.
      await host.itemRunnable(workItemId: 'wi-2');
      await host.scheduler.tick();

      final wi2 = await host.jobStore.listJobsForWorkItem('wi-2');
      expect(wi2, hasLength(1));
      expect(
        wi2.single.state,
        JobState.queued,
        reason:
            'wi-2 was deferred once, not cancelled: the bound belongs to the '
            'item that spent it. A count shared across work items would let '
            'one stuck item strand every other item in the system',
      );
    });
  });

  group('duplicate safety across the hop', () {
    test('a job minted BEFORE the hop is retired rather than dispatched beside '
        'the one minted after it', () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      final host = FileRestartHarness(
        temp,
        clock: () => t0,
        definition: triageDefectDefinition,
      );
      await itemRejectedAtEngineeringReviewGate(
        host.workflowEngine,
        host.designContractStore,
      );

      // A row from an EARLIER build: queued, keyed on the state the item is
      // in right now, before any hop.
      final stale = await host.scheduler.queue.enqueueIfAbsent(
        workItemId: 'wi-1',
        definition: triageDefectDefinition,
        dedupeKey: 'wi-1:review_rejected:triage_defect:triage_defect',
        instruction: 'minted before the hop existed',
      );
      expect(stale.created, isTrue);

      final tick = await host.scheduler.tick();

      expect(
        tick.cancelledQueued,
        contains(stale.job.jobId),
        reason:
            'otherwise it stays eligible — the item is runnable after the '
            'hop, just at a different key — and two agent executions would '
            'run for one work item',
      );
      final retired = (await host.jobStore.readJob(stale.job.jobId))!;
      expect(retired.state, JobState.cancelled);
      expect(retired.cancelReason, contains('superseded'));
      final all = await host.jobStore.listJobsForWorkItem('wi-1');
      expect(
        all.where((j) => j.cancelReason == null),
        hasLength(1),
        reason:
            'exactly one job for the item that was not superseded — the one '
            'minted for the state the hop landed on',
      );
      expect(
        all.singleWhere((j) => j.cancelReason == null).state,
        JobState.succeeded,
        reason:
            'and it really ran, rather than lingering beside the retired row',
      );
    });
  });
}

/// Declares an entry state the coordinator cannot act on, and asks the workflow
/// policy nothing about it — the mis-declaration this whole class of defect
/// was. It is here only so the hop's refusal can be observed end to end;
/// `entry_hop_drift_guard_test.dart` asserts no PRODUCTION definition can be
/// shaped like this.
const JobDefinition _misdeclaredUnreachableEntry = JobDefinition(
  jobType: JobType.designRevision,
  requiredRole: AgentRole.designAgent,
  requiredCapabilities: {WorkerCapability.visualDesign},
  entryStates: {WorkItemState.designRejected},
  priority: JobPriority.normal,
  maxAttempts: 3,
  skipWorkflowPolicyCheck: true,
);

/// Reads a worker execution that the test REQUIRES to exist, failing with a
/// readable message rather than a null-dereference one.
Future<WorkerExecution> readWorkerExecutionOrFail(
  SchedulerHost host,
  String workerExecutionId,
) async {
  final row = await host.workerStore.readWorkerExecution(workerExecutionId);
  expect(
    row,
    isNotNull,
    reason: 'no worker execution $workerExecutionId — nothing was dispatched',
  );
  return row!;
}

/// Runs [EntryHopper] for [definition] over the harness's own store and item, so
/// a refusal can be observed AS a refusal rather than inferred from a tick.
Future<EntryHopResult> hopFor(
  FileRestartHarness host,
  JobDefinition definition,
) {
  final item = host.workflowStore.readWorkItem('wi-1');
  return item.then(
    (item) => EntryHopper(
      policy: const WorkflowEngine(),
      engine: DurableWorkflowEngine(
        store: host.workflowStore,
        designContractStore: host.designContractStore,
      ),
      definition: definition,
    ).prepare(item),
  );
}

/// Builds a supersession exactly as a worker execution reports one: the generic
/// `executedFail` / `agentFailed` pair with the coordinator's marker as the only
/// identifying signal — which is all the scheduler ever really has.
WorkerExecutionResult supersededResult(WorkerExecutionRequest request) {
  final t = DateTime.utc(2026, 1, 1, 12);
  return WorkerExecutionResult(
    workerExecutionId: request.workerExecutionId,
    workItemId: request.workItemId,
    status: WorkerExecutionStatus.executedFail,
    workerId: 'w-scripted-1',
    workspaceId: 'ws-1',
    startingRevision: 'deadbeef',
    startedAt: t,
    endedAt: t,
    cleanupStatus: WorkerCleanupStatus.removed,
    failureCode: WorkerFailureCode.agentFailed,
    failureDetail:
        '$supersededExecutionMarker Superseded execution: work item '
        '${request.workItemId} moved before this execution started, so nothing '
        'ran and nothing was produced.',
    agentResultStatus: null,
    verificationPassed: null,
    changedFiles: const [],
    endingRevision: null,
  );
}

/// Drives a defect item through its whole legitimate lifecycle up to a blocking
/// engineering-review gate, then has the human reject it — using only real
/// transitions and the real routing table.
///
/// This is the walk a real defect takes. A test that simply starts the item at
/// `reviewRejected` cannot tell a correct hop from one that happens to produce
/// the right state, and the history below is what proves the state is real.
Future<void> itemRejectedAtEngineeringReviewGate(
  DurableWorkflowEngine engine,
  DesignContractStore contractStore, {
  String workItemId = 'wi-1',
}) async {
  Future<void> step(
    WorkItemState to, {
    Map<String, dynamic> context = const {},
    TransitionTrigger trigger = TransitionTrigger.systemEvent,
  }) => engine.transition(
    workItemId: workItemId,
    to: to,
    trigger: trigger,
    context: context,
  );

  await engine.createWorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Triage a reported defect',
    description: 'The checkout total ignores the second item.',
    // Read by the guard, confirmed against a store — never supplied in context.
    designContractId: await _contractIdFor(contractStore, workItemId),
    qaContractId: 'qa-1',
    metadata: const {'defectId': 'DEF-1', 'defectSeverity': 'high'},
  );
  await step(WorkItemState.planning);
  await step(WorkItemState.planned, context: const {'featureRef': 'f-1'});
  await step(WorkItemState.designRequired);
  await step(
    WorkItemState.designInReview,
    context: const {'designContractStatus': DesignContractStatus.underReview},
  );
  await engine.resolveHumanDecision(
    decisionId: (await engine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: HumanDecisionType.designApproval,
    )).decisionId,
    choice: HumanDecisionChoice.approve,
    decider: 'hum@shipit.platform',
    rationale: 'approved',
    signature: _signature,
  );
  await step(
    WorkItemState.agentExecuting,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  final agentResult = AgentResult(
    resultId: 'res-1',
    sessionId: 'ses-1',
    workItemId: workItemId,
    status: AgentResultStatus.completed,
    artifacts: const [],
    diagnostics: AgentDiagnostics(
      exitCode: 0,
      durationMs: 1,
      toolCalls: 1,
      errors: const [],
      warnings: const [],
    ),
    structuredResult: const {},
    summary: 'implemented',
    completedAt: DateTime.utc(2026, 1, 1),
  );
  await step(
    WorkItemState.agentCompleted,
    trigger: TransitionTrigger.agentResult,
    context: {'qaContractId': 'qa-1', 'agentResult': agentResult},
  );
  await step(
    WorkItemState.reviewInProgress,
    trigger: TransitionTrigger.agentResult,
    context: {'agentResult': agentResult},
  );
  final decisionId = (await engine.requestHumanDecision(
    workItemId: workItemId,
    decisionType: HumanDecisionType.engineeringReview,
    actor: const WorkflowActor(
      actorId: 'reviewer-2',
      actorType: ActorType.engineeringReviewer,
    ),
    extraContext: const {'producerActorId': 'agent-1'},
  )).decisionId;
  await engine.resolveHumanDecision(
    decisionId: decisionId,
    choice: HumanDecisionChoice.reject,
    decider: 'hum@shipit.platform',
    rationale: 'Rejected outright',
    signature: _signature,
  );
  expect(
    (await engine.loadWorkItem(workItemId)).state,
    WorkItemState.reviewRejected,
    reason: 'the walk must actually reach the state under test',
  );
}

/// Parks an item at `designRejected` the way a human rejecting a design does.
Future<void> itemDesignRejected(SchedulerHost host) async {
  await host.itemBlocked(workItemId: 'wi-1');
  await host.workflowEngine.resolveHumanDecision(
    decisionId: (await host.workflowStore.readWorkItem(
      'wi-1',
    )).blockingHumanDecisionId!,
    choice: HumanDecisionChoice.reject,
    decider: 'hum@shipit.platform',
    rationale: 'design rejected: revisit the layout',
    signature: _signature,
  );
  expect(
    (await host.workflowStore.readWorkItem('wi-1')).state,
    WorkItemState.designRejected,
  );
}

/// Parks an item at `designRequired`: the design revision entry state that must
/// keep working now that its sibling's mis-declaration is closed.
/// Parks an item at `designRequired` — the design revision entry state that
/// must keep working now that its sibling's mis-declaration is closed.
/// Provisions a draft design contract for [workItemId] and returns the id the
/// store READ BACK.
///
/// `designContractExists()` confirms the work item's `designContractId` column
/// against a [DesignContractStore], so a fixture that walks an item to
/// `designRequired` has to leave a real row behind. Returning the read-back id
/// rather than the submitted one is the discipline
/// [DesignContractProvisioner] exists to enforce, and it is why these walks
/// stopped passing `context: {'designContractId': …}`: that string was the
/// defect, and a fixture still passing one would keep working while asserting
/// nothing.
Future<String> _contractIdFor(
  DesignContractStore contractStore,
  String workItemId,
) async => (await DesignContractProvisioner(
  contractStore: contractStore,
).provisionForWorkItem(workItemId: workItemId, productId: 'prod-1')).contractId;

Future<void> itemAtDesignRequired(
  DurableWorkflowEngine engine,
  WorkflowStore store,
  DesignContractStore contractStore, {
  String workItemId = 'wi-1',
}) async {
  await engine.createWorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'Design the calculator',
    description: 'Produce a design revision.',
    // The guard reads this COLUMN and confirms it against a store, so the
    // transition below carries no `designContractId` in context at all.
    designContractId: await _contractIdFor(contractStore, workItemId),
    qaContractId: 'qa-1',
    featureRef: 'feature/calc',
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: const {'featureRef': 'f-1'},
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.designRequired,
    trigger: TransitionTrigger.systemEvent,
  );
  expect(
    (await store.readWorkItem(workItemId)).state,
    WorkItemState.designRequired,
  );
}

/// Parks an item at `agentExecuting`, which asserts an execution is running.
/// Used to reach a hop whose guard depends on a result the scheduler cannot
/// have.
Future<void> itemAtAgentExecuting(
  DurableWorkflowEngine engine,
  WorkflowStore store, {
  String workItemId = 'wi-1',
}) async {
  await engine.createWorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'Implement the calculator',
    description: 'An execution is running for this item.',
    qaContractId: 'qa-1',
    featureRef: 'feature/calc',
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: const {'featureRef': 'f-1'},
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.designNotRequired,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  expect(
    (await store.readWorkItem(workItemId)).state,
    WorkItemState.agentExecuting,
  );
}

/// Parks an item at `designRejected`: a state with exactly one out-edge in the
/// table, and no path to an executing state from where a design revision job
/// could dispatch.
Future<void> itemAtDesignRejected(
  DurableWorkflowEngine engine,
  WorkflowStore store,
  DesignContractStore contractStore, {
  String workItemId = 'wi-1',
}) async {
  await engine.createWorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'Design the calculator',
    description: 'A design was produced and a human rejected it.',
    designContractId: await _contractIdFor(contractStore, workItemId),
    qaContractId: 'qa-1',
    featureRef: 'feature/calc',
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: const {'featureRef': 'f-1'},
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.designRequired,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: workItemId,
    to: WorkItemState.designInReview,
    trigger: TransitionTrigger.systemEvent,
    context: const {'designContractStatus': DesignContractStatus.underReview},
  );
  final decision = await engine.requestHumanDecision(
    workItemId: workItemId,
    decisionType: HumanDecisionType.designApproval,
    blocking: true,
  );
  await engine.resolveHumanDecision(
    decisionId: decision.decisionId,
    choice: HumanDecisionChoice.reject,
    decider: 'hum@shipit.platform',
    rationale: 'the layout is wrong',
    signature: _signature,
  );
  expect(
    (await store.readWorkItem(workItemId)).state,
    WorkItemState.designRejected,
  );
}

final _signature = DecisionSignature(
  algorithm: 'ed25519',
  publicKey: 'test-public-key',
  signature: 'sig-test',
  signedAt: DateTime.utc(2026, 1, 1),
);

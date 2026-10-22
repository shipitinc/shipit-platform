import 'package:control_plane_server/src/design/design_revision_producer.dart';
import 'package:control_plane_server/src/triage/lane_i_tick_hook.dart';
import 'package:control_plane_server/src/triage/stalled_work_item_gate.dart';
import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:scheduler/scheduler.dart'
    show InMemoryJobStore, SchedulerTickResult;
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// THE PROOF for F-222 / decision `e2c7a05b` (design step 8).
///
/// ## WHAT WAS BROKEN
///
/// `DesignRevisionProducer.processCompletedDesignRevisionJob` reports a refusal
/// as a NORMAL return. The tick drain registered the producer and counted the
/// job `handedOff`, the job was terminal, the item stayed at `agentCompleted`
/// (not an entry state of `designRevisionDefinition`), and no operator ever saw
/// the refusal. The only trace was a `design_revision.refused` log line.
///
/// ## WHAT THIS FILE DRIVES
///
/// The real `drainTriageOutcomesFromTick`, the real producer, the real
/// `raiseDesignProducerRefusalDecision`, and the real [DurableWorkflowEngine] and
/// in-memory stores. The producer refuses at `P1` because the item names a design
/// contract that does not exist. The refusal is then turned into the same
/// blocking human decision the scheduler stall gate raises.
///
/// The `agentCompleted -> reviewInProgress` edge is guarded by
/// `agentResultValid()`, so a completed execution AND its result are seeded —
/// otherwise the gate correctly refuses to fabricate the evidence and the test
/// would be asserting on the guard instead of the mechanism.
const String _workItemId = 'wi-design-refusal';
const String _jobId = 'job-design-refusal';
const String _executionId = 'agx-design-refusal';
const String _missingContractId = 'contract-that-does-not-exist';

void main() {
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine engine;
  late InMemoryExecutionStore executionStore;
  late InMemoryJobStore jobStore;
  late InMemoryDesignContractStore contractStore;
  late InMemoryDesignGovernanceStore governanceStore;
  late DesignRevisionProducer producer;
  late Job job;
  final now = DateTime.utc(2026, 1, 1);

  setUp(() async {
    workflowStore = InMemoryWorkflowStore();
    engine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    jobStore = InMemoryJobStore();
    contractStore = InMemoryDesignContractStore();
    governanceStore = InMemoryDesignGovernanceStore();

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: _workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'A design that cannot be produced',
        state: WorkItemState.agentCompleted,
        designContractId: _missingContractId,
        metadata: const {'producerActorId': _executionId},
        createdAt: now,
        updatedAt: now,
      ),
    );

    await executionStore.saveExecution(
      AgentExecution(
        executionId: _executionId,
        workItemId: _workItemId,
        requestId: 'req-1',
        runtimeTypeId: 'opencode',
        role: AgentRole.designAgent,
        status: AgentSessionStatus.completed,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-1',
          path: '/tmp/design-workspace',
        ),
        startedAt: now,
        completedAt: now,
      ),
    );
    await executionStore.saveResult(
      _executionId,
      AgentResult(
        resultId: 'res-1',
        sessionId: 'sess-1',
        workItemId: _workItemId,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 1,
          toolCalls: 0,
          errors: [],
          warnings: [],
        ),
        structuredResult: const <String, dynamic>{},
        executionId: _executionId,
        role: AgentRole.designAgent,
        completedAt: now,
      ),
    );

    job = Job(
      jobId: _jobId,
      workItemId: _workItemId,
      jobType: JobType.designRevision,
      requiredRole: AgentRole.designAgent,
      requiredCapabilities: const {
        WorkerCapability.penpotWrite,
        WorkerCapability.visualDesign,
      },
      priority: JobPriority.normal,
      state: JobState.succeeded,
      dedupeKey: '$_workItemId:${JobType.designRevision.wire}',
      createdAt: now,
      instruction: 'Produce a design revision',
      attempt: 1,
      maxAttempts: 3,
      version: 1,
      executionReference: JobExecutionReference(
        workerExecutionId: 'wx-1',
        agentExecutionId: _executionId,
        createdAt: now,
      ),
    );
    await jobStore.saveJob(job);

    producer = DesignRevisionProducer(
      workflowStore: workflowStore,
      workflowEngine: engine,
      executionStore: executionStore,
      jobStore: jobStore,
      designRevisionStore: governanceStore,
      designContractStore: contractStore,
      defectStore: _FakeDefectStore(),
      clock: () => DateTime.utc(2026, 2, 1),
      logger: (_, _) {},
    );
  });

  SchedulerTickResult tick(List<String> ids) => SchedulerTickResult(
    dispatched: ids,
    terminal: const [],
    reconciled: const [],
    cancelledQueued: const [],
    deferred: const [],
    enqueued: const [],
  );

  Future<List<Map<String, dynamic>>> drainWithSink({String? suffix}) async {
    final events = <Map<String, dynamic>>[];
    await drainTriageOutcomesFromTick(
      tickResult: tick([_jobId]),
      jobStore: jobStore,
      designRevisionProducer: producer,
      designRevisionOutcomeSink: (job, result) async {
        if (!result.isRefused) return;
        events.add({
          'jobId': job.jobId,
          'refusalCode': result.refusalCode,
        });
        await raiseDesignProducerRefusalDecision(
          workflowEngine: engine,
          executionStore: executionStore,
          job: job,
          refusal: result,
          logger: (event, data) => events.add({'event': event, ...data}),
        );
      },
      logger: (_, _) {},
    );
    return events;
  }

  group('a named producer refusal reaches a human', () {
    test(
      'the refusal raises exactly one blocking decision and parks the item',
      () async {
        final events = await drainWithSink();

        // The sink really saw the refusal, and the producer's own code is the one
        // under test — not a hand-built result.
        expect(events.first['refusalCode'], 'p1.design-contract-unresolved');
        expect(
          events.where((e) => e['event'] == 'design.refusal.parked'),
          hasLength(1),
        );

        final item = await engine.loadWorkItem(_workItemId);
        expect(item.state, WorkItemState.waitingForHumanDecision);

        final decisions = await workflowStore.readHumanDecisionsForWorkItem(
          _workItemId,
        );
        expect(decisions, hasLength(1));
        final decision = decisions.single;
        expect(decision.blocking, isTrue);
        expect(decision.status, HumanDecisionStatus.pending);
        expect(decision.question, contains('p1.design-contract-unresolved'));
        expect(decision.question, contains(_missingContractId));
        expect(decision.question, contains(_workItemId));
        expect(
          decision.options!.map((o) => o.optionId),
          containsAll(<String>['rework', 'cancel']),
        );

        // The question is keyed to the refused run, not to a lane-wide counter.
        final metadata =
            decision.metadata![designProducerRefusalMetadataKey]
                as Map<String, dynamic>;
        expect(metadata['jobId'], _jobId);
        expect(metadata['executionId'], _executionId);
        expect(metadata['refusalCode'], 'p1.design-contract-unresolved');
        expect(metadata['dedupeKey'], '$_jobId:$_executionId');
        expect(
          decision.metadata!.containsKey(stalledWorkItemMetadataKey),
          isFalse,
          reason:
              'a refusal is not a supersession stall; reusing the stall key '
              'would make an operator read it as one',
        );
      },
    );

    test(
      're-draining the same refused job does not mint a second decision',
      () async {
        await drainWithSink();
        final second = await drainWithSink();

        expect(
          second.where((e) => e['event'] == 'design.refusal.already-parked'),
          hasLength(1),
          reason: 'the item state is the idempotence key for a re-drain',
        );
        expect(
          await workflowStore.readHumanDecisionsForWorkItem(_workItemId),
          hasLength(1),
        );
      },
    );

    test(
      'a caller-supplied designRevision handler is refused at construction',
      () async {
        // The drain registers the ONLY handler that reads the producer's verdict.
        // `...?handlers` used to spread last, so a caller could replace it and a
        // refusal would again be counted as handled with no decision. The assert
        // is the guard; this test keeps it from being deleted.
        expect(
          () => drainTriageOutcomesFromTick(
            tickResult: tick(const []),
            jobStore: jobStore,
            designRevisionProducer: producer,
            handlers: {
              JobType.designRevision: (_) async {},
            },
            logger: (_, _) {},
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );
  });
}

class _FakeDefectStore implements DefectStore {
  @override
  Future<Defect> readDefect(String defectId) async =>
      throw UnimplementedError('no defect is read by these cases');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used');
}

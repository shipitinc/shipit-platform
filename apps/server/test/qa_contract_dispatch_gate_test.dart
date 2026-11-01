/// The F-242 regression suite: an item with no `qaContractId` is DEFERRED at
/// dispatch on every producer lane, never dispatched a job whose only edge
/// out of the agent run — `agentExecuting -> agentCompleted`, guarded by
/// `GuardConditions.qaContractExists()` — refuses after the work has run and
/// the attempt has been spent.
///
/// ## Why this file sits in `test/` while the probe's own suite does not
///
/// The declared per-execution gate is `dart run tool/run_unit_tests.dart`,
/// which enumerates `test/*.dart` at the top level only. A regression that
/// lives anywhere else is exercised by nothing the gate runs — so the
/// dispatch-level assertions live here, next to the suites the gate owns.
library;

import 'package:control_plane_server/src/implementation/implementation_readiness_probe.dart';
import 'package:control_plane_server/src/qa/qa_contract_dispatch_gate.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show
        AgentRole,
        DurableWorkspaceDescriptor,
        Job,
        JobPriority,
        JobState,
        JobType,
        OnboardingRecord,
        OnboardingWorkspace,
        ProductState,
        WorkItem,
        WorkItemCategory,
        WorkItemState,
        WorkerExecutionRequest,
        WorkerExecutionResult;
import 'package:scheduler/scheduler.dart'
    show
        InMemoryJobStore,
        Scheduler,
        SchedulerWorkload,
        WorkerDispatch,
        implementFeatureDedupeKey,
        implementFeatureDefinition,
        implementFeatureInstruction,
        implementFeatureRequest,
        triageDefectDedupeKey,
        triageDefectDefinition,
        triageDefectInstruction,
        triageDefectRequest;
import 'package:worker_protocol/worker_protocol.dart' show WorkerSelection;
import 'package:worker_runtime/worker_runtime.dart' show InMemoryWorkerStore;
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore, WorkflowStore;
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

void main() {
  WorkItem item({
    String workItemId = 'wi-gate',
    String productId = 'product-a',
    WorkItemState state = WorkItemState.implementationReady,
    String? qaContractId = 'qa-contract-wi-gate',
  }) {
    final now = DateTime.utc(2026);
    return WorkItem(
      workItemId: workItemId,
      productId: productId,
      category: WorkItemCategory.feature,
      title: 'A fixture item',
      description: 'Used to ask about the QA-contract dispatch precondition.',
      state: state,
      qaContractId: qaContractId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Job job({String jobId = 'jb-1', String workItemId = 'wi-gate'}) => Job(
    jobId: jobId,
    workItemId: workItemId,
    jobType: JobType.implementFeature,
    requiredRole: AgentRole.implementer,
    requiredCapabilities: const {},
    priority: JobPriority.normal,
    state: JobState.queued,
    dedupeKey: '$workItemId:implement_feature',
    createdAt: DateTime.utc(2026),
    instruction: 'implement it',
    attempt: 1,
    maxAttempts: 2,
    version: 1,
  );

  const workload = SchedulerWorkload(
    repositoryPath: '/a/lane/repository',
    startingRevision: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    timeoutSeconds: 1800,
    runtimeTypeId: 'gate-runtime',
  );

  group('workItemCarriesQaContract', () {
    test('a null qaContractId is contractless', () {
      expect(workItemCarriesQaContract(item(qaContractId: null)), isFalse);
    });
    test('a blank qaContractId is contractless, not a contract', () {
      // `GuardConditions.qaContractExists()` checks `!= null`, so whitespace
      // would pass while naming no contract — the worse contractless shape.
      expect(workItemCarriesQaContract(item(qaContractId: '   ')), isFalse);
    });
    test('a present qaContractId is a carried contract', () {
      expect(workItemCarriesQaContract(item()), isTrue);
    });
  });

  group('qaContractGatedWorkloadResolver', () {
    test('a contracted item resolves to the lane\'s static workload', () async {
      final resolve = qaContractGatedWorkloadResolver(
        workload: workload,
        deferralEvent: 'lane.deferred.qa_contract_missing',
      );
      expect(await resolve(job(), item()), same(workload));
    });

    test(
      'a contractless item resolves to null and emits the lane\'s event',
      () async {
        final events = <Map<String, dynamic>>[];
        final resolve = qaContractGatedWorkloadResolver(
          workload: workload,
          deferralEvent: 'lane.deferred.qa_contract_missing',
          log: (event, data) => events.add({'event': event, ...data}),
        );

        expect(
          await resolve(job(), item(qaContractId: null)),
          isNull,
          reason:
              'null is what stops the dispatch: the scheduler builds no '
              'request, claims nothing, and leaves the job queued with its '
              'attempt untouched',
        );
        expect(events, hasLength(1));
        expect(events.single['event'], 'lane.deferred.qa_contract_missing');
        expect(events.single['workItemId'], 'wi-gate');
        expect(events.single['jobId'], 'jb-1');
      },
    );

    test('a throwing log does not convert the deferral into a crash', () async {
      // The composition root's sink is `stdout.writeln`, which raises on a
      // closed pipe. A throw from inside the deferral would leave `tick()`
      // and cost every OTHER job in the pass — the same escape the probe's
      // own `_deferred` guards.
      final resolve = qaContractGatedWorkloadResolver(
        workload: workload,
        deferralEvent: 'lane.deferred.qa_contract_missing',
        log: (event, data) => throw StateError('closed pipe'),
      );
      expect(await resolve(job(), item(qaContractId: null)), isNull);
    });
  });

  group('the implementation readiness probe', () {
    test(
      'a contractless item defers with `implementation.deferred'
      '.qa_contract_missing` before any workspace question is asked',
      () async {
        var onboardingRead = false;
        final events = <String>[];
        final probe = ImplementationReadinessProbe(
          readProductState: (_) async => ProductState.governed,
          readOnboarding: (_) async {
            onboardingRead = true;
            return null;
          },
          runtimeTypeId: 'probe-runtime',
          timeoutSeconds: 1800,
          log: (event, data) => events.add(event),
        );

        final readiness = await probe.probe(item(qaContractId: null));

        expect(readiness, isA<ImplementationWorkspaceDeferred>());
        expect(
          (readiness as ImplementationWorkspaceDeferred).reason,
          contains('no QA contract id'),
        );
        expect(events, ['implementation.deferred.qa_contract_missing']);
        expect(
          onboardingRead,
          isFalse,
          reason:
              'the gate is asked before the onboarding read — a field on the '
              'item already in hand answers it, and no store round-trip is '
              'spent on an item that cannot complete anyway',
        );
      },
    );

    test('a contracted item passes the gate — the next refusal is a different '
        'gate entirely', () async {
      final probe = ImplementationReadinessProbe(
        readProductState: (_) async => ProductState.governed,
        readOnboarding: (_) async => null,
        runtimeTypeId: 'probe-runtime',
        timeoutSeconds: 1800,
      );

      final deferred =
          (await probe.probe(item())) as ImplementationWorkspaceDeferred;
      expect(
        deferred.reason,
        contains('no onboarding record'),
        reason:
            'reaching the record gate proves the contract gate let the item '
            'through — a deferral here is about the workspace, not the '
            'contract',
      );
    });
  });

  group(
    'end to end — a contractless item is never dispatched an implement job',
    () {
      test('the contractless job is deferred while the contracted job in the '
          'same tick is dispatched', () async {
        const contractless = 'wi-contractless';
        const contracted = 'wi-contracted';

        final workflowStore = InMemoryWorkflowStore();
        final jobStore = InMemoryJobStore();
        final engine = DurableWorkflowEngine(store: workflowStore);

        await engine.createWorkItem(
          workItemId: contractless,
          productId: 'product-a',
          category: WorkItemCategory.feature,
          title: 'An item with no QA contract',
          description: 'F-242: this item must never reach an agent.',
        );
        await engine.createWorkItem(
          workItemId: contracted,
          productId: 'product-a',
          category: WorkItemCategory.feature,
          title: 'An item with a QA contract',
          description: 'The control: it must dispatch normally.',
          qaContractId: 'qa-contract-$contracted',
        );
        for (final id in [contractless, contracted]) {
          await _parkAt(workflowStore, id, WorkItemState.implementationReady);
        }

        // The production probe over injected ports: a governed product, a
        // durable record that resolves — so NOTHING except the contract
        // gate distinguishes the two items.
        final events = <String>[];
        final resolver = toWorkloadResolver(
          ImplementationReadinessProbe(
            readProductState: (_) async => ProductState.governed,
            readOnboarding: (productId) async => OnboardingRecord(
              onboardingId: 'onb-$productId',
              productId: productId,
              pinnedRevision: 'b' * 40,
              workspace: OnboardingWorkspace.durable(
                DurableWorkspaceDescriptor(
                  workspaceId: 'dws-$productId',
                  productId: productId,
                  repositoryPath: '/a/clone/at/its/pin',
                  startingRevision: 'b' * 40,
                  createdAt: DateTime.utc(2026),
                ),
              ),
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
            repositoryExists: (_) => true,
            resolveCommit: (path, revision) => (commit: revision, output: null),
            runtimeTypeId: 'probe-runtime',
            timeoutSeconds: 1800,
            log: (event, data) => events.add(event),
          ),
        );

        final attempted = <String>[];
        final requests = <WorkerExecutionRequest>[];

        final result = await Scheduler(
          schedulerId: 'sched-impl',
          workflowStore: workflowStore,
          jobStore: jobStore,
          workerStore: InMemoryWorkerStore(),
          dispatch: _RecordingDispatch(requests),
          definition: implementFeatureDefinition,
          dedupeKeyBuilder: implementFeatureDedupeKey,
          instructionBuilder: implementFeatureInstruction,
          requestBuilder: implementFeatureRequest,
          workloadResolver: (job, item) {
            attempted.add(item.workItemId);
            return resolver(job, item);
          },
          workload: workload,
          clock: () => DateTime.utc(2026, 1, 1),
        ).tick();

        expect(
          attempted,
          containsAll([contractless, contracted]),
          reason:
              'NON-VACUITY: both jobs must have been dispatch-attempted, or '
              'the assertion below proves nothing',
        );

        // THE REGRESSION ASSERTION: no implement job was ever dispatched —
        // and none ever had a request built — for the contractless item.
        expect(requests.map((r) => r.workItemId), [contracted]);

        // The deferral is durable-visible, is exactly one job's worth, and
        // costs nothing: queued, attempt untouched, no retry consumed.
        expect(result.blockedArtifactMissing, hasLength(1));
        final stranded = (await jobStore.listJobsForWorkItem(
          contractless,
        )).single;
        expect(stranded.state, JobState.queued);
        expect(
          stranded.attempt,
          1,
          reason:
              'the F-242 burn was an attempt spent per retry on a gate that '
              'could never pass; a deferral spends none',
        );

        expect(events, contains('implementation.deferred.qa_contract_missing'));
      });
    },
  );

  group(
    'end to end — a contractless item is never dispatched a triage job',
    () {
      test('the gated resolver defers the contractless item while the '
          'contracted one is dispatched', () async {
        const contractless = 'wi-triage-contractless';
        const contracted = 'wi-triage-contracted';

        final workflowStore = InMemoryWorkflowStore();
        final jobStore = InMemoryJobStore();
        final engine = DurableWorkflowEngine(store: workflowStore);

        await engine.createWorkItem(
          workItemId: contractless,
          productId: 'product-a',
          category: WorkItemCategory.feature,
          title: 'A defect item with no QA contract',
          description: 'F-242: this item must never reach an agent.',
        );
        await engine.createWorkItem(
          workItemId: contracted,
          productId: 'product-a',
          category: WorkItemCategory.feature,
          title: 'A defect item with a QA contract',
          description: 'The control: it must dispatch normally.',
          qaContractId: 'qa-contract-$contracted',
        );
        for (final id in [contractless, contracted]) {
          await _parkAt(workflowStore, id, WorkItemState.designNotRequired);
        }

        final events = <String>[];
        final requests = <WorkerExecutionRequest>[];

        final result = await Scheduler(
          schedulerId: 'sched-triage',
          workflowStore: workflowStore,
          jobStore: jobStore,
          workerStore: InMemoryWorkerStore(),
          dispatch: _RecordingDispatch(requests),
          definition: triageDefectDefinition,
          dedupeKeyBuilder: triageDefectDedupeKey,
          instructionBuilder: triageDefectInstruction,
          requestBuilder: triageDefectRequest,
          // The production wiring: the static triage workload wrapped in the
          // contract gate, exactly as the composition root builds it.
          workloadResolver: qaContractGatedWorkloadResolver(
            workload: workload,
            deferralEvent: 'triage.deferred.qa_contract_missing',
            log: (event, data) => events.add(event),
          ),
          workload: workload,
          clock: () => DateTime.utc(2026, 1, 1),
        ).tick();

        expect(requests.map((r) => r.workItemId), [contracted]);
        expect(result.blockedArtifactMissing, hasLength(1));

        final stranded = (await jobStore.listJobsForWorkItem(
          contractless,
        )).single;
        expect(stranded.state, JobState.queued);
        expect(stranded.attempt, 1);
        expect(events, contains('triage.deferred.qa_contract_missing'));
      });
    },
  );
}

/// Writes [workItemId] into [state] directly, exactly as the scheduler
/// package's own fixtures do: the property under test is what the dispatch
/// seam does with an item AT that state, so the row is put there rather than
/// walked.
Future<void> _parkAt(
  WorkflowStore store,
  String workItemId,
  WorkItemState state,
) async {
  final current = await store.readWorkItem(workItemId);
  await store.saveWorkItem(
    current.copyWith(
      state: state,
      version: current.version + 1,
      updatedAt: DateTime.utc(2026),
    ),
    expectedVersion: current.version,
  );
}

/// A [WorkerDispatch] that records every request it was asked about and
/// selects no worker.
///
/// A request reaching `select` proves the dispatch got as far as building it;
/// selecting nothing keeps the job unclaimed, so the tick remains observable.
class _RecordingDispatch implements WorkerDispatch {
  _RecordingDispatch(this.requests);

  final List<WorkerExecutionRequest> requests;

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    requests.add(request);
    return WorkerSelection.noCompatibleWorker();
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    throw StateError('run() is not reachable: no worker is ever selected here');
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

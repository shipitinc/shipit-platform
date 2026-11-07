import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, InMemoryExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart'
    show implementFeatureDedupeKey, implementFeatureDefinition;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart'
    show InMemoryWorkerStore, WorkerStore;
import 'package:workflow_engine/workflow_engine.dart'
    show WorkItemTransitions, operatorRerouteContextKey;
import 'package:workflow_store/workflow_store.dart'
    show
        DurableWorkflowEngine,
        InMemoryWorkflowStore,
        OperatorActionRecord,
        WorkflowStore;

/// The reroute: an operator path that moves a `deployed` item back to
/// `implementation_ready` — F-261.
///
/// ## THE DEFECT THIS FILE HOLDS CLOSED
///
/// `deployed` had exactly one exit — `deployed -> completed` — so an item
/// whose re-land refuses (its producer left no commit, so there is nothing
/// honest to merge) was parked forever: completing it would record work
/// never produced as shipped. The `deployed -> implementationReady` edge
/// plus `rerouteToImplementation` is the rework path: the item re-enters
/// the implementation lane's own entry state, the `reroute` audit row
/// names the human who asked, and the `triageAttempt` bump keeps the
/// re-run's `implement_feature` dedupe key from colliding with the key the
/// stranded run already consumed.
///
/// ## WHAT IS ASSERTED
///
///   1. a `deployed` item reroutes: state moves, one `reroute` audit row,
///      and `triageAttempt` advances so the dedupe key is provably fresh;
///   2. a STAMPED deployed item reroutes too — the owed test is the state,
///      not the stamp;
///   3. a replayed `requestId` reports the completed intent — one row;
///   4. a job holding `:a3` moves the floor — the bump lands above it;
///   5. wrong-state, blank-reason, blank-requester and live-job refusals
///      write NOTHING;
///   6. the edge is real and the marker guard refuses a bare orchestrator
///      transition — the edge is not free.
///
/// ## WHY THE REAL ENGINE
///
/// Same rule as `deploy_reland_test.dart`: the move under test is the
/// production `DurableWorkflowEngine.transition` — guard evaluations,
/// transition record, audit row and CAS included. Only the persistence
/// substrate is substituted, never a refusal.
void main() {
  late _Harness harness;
  late _TestEndpoints endpoints;
  late Session session;

  setUp(() {
    harness = _Harness();
    endpoints = _TestEndpoints(harness);
    session = _FakeSession();
  });

  group('a deployed item reroutes to implementation entry', () {
    test(
      'moves deployed -> implementation_ready, writes one reroute row, '
      'and freshens the implement dedupe key',
      () async {
        final id = await harness.seedDeployed();
        // The consumed key: a TERMINAL implement job already holds
        // `<id>:implement_feature`, so an unbumped reroute would enqueue
        // nothing while looking dispatched.
        endpoints.jobs = [_implementJob(id, dedupe: '$id:implement_feature')];

        final result = await endpoints.rerouteToImplementation(
          session,
          workItemId: id,
          requestId: 'req-reroute-1',
          requestedBy: 'dana',
          reason: 'the re-land refused: the producer left no commit',
        );

        expect(result.outcome, 'accepted');
        final item = await harness.store.readWorkItem(id);
        expect(item.state, WorkItemState.implementationReady);
        expect(
          item.metadata?[DurableWorkflowEngine.triageAttemptMetadataKey],
          1,
          reason:
              'the bump is what makes the re-run\'s dedupe key fresh — '
              'without it the reroute is a silent no-op',
        );
        expect(
          implementFeatureDedupeKey(item, implementFeatureDefinition),
          '$id:implement_feature:a1',
          reason:
              'a key the terminal job does NOT hold — the rerouted item '
              'is dispatchable on the ordinary tick',
        );

        final rows = await harness.ledger(id);
        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row.action, 'reroute');
        expect(row.fromState, WorkItemState.deployed.wire);
        expect(row.toState, WorkItemState.implementationReady.wire);
        expect(row.requestedBy, 'dana');
        expect(row.reason, 'the re-land refused: the producer left no commit');
        expect(row.requestId, 'req-reroute-1');
        expect(row.attemptNumber, isNull);
      },
    );

    test(
      'a STAMPED deployed item reroutes too — the owed test is the state',
      () async {
        final id = await harness.seedDeployed(stamped: true);

        final result = await endpoints.rerouteToImplementation(
          session,
          workItemId: id,
          requestId: 'req-reroute-stamped',
          requestedBy: 'dana',
          reason: 'deployed work needs rework',
        );

        expect(result.outcome, 'accepted');
        final item = await harness.store.readWorkItem(id);
        expect(item.state, WorkItemState.implementationReady);
        expect(await harness.ledger(id), hasLength(1));
      },
    );

    test(
      'a replayed requestId reports the completed intent — one row, one '
      'bump',
      () async {
        final id = await harness.seedDeployed();

        final first = await endpoints.rerouteToImplementation(
          session,
          workItemId: id,
          requestId: 'req-replay',
          requestedBy: 'dana',
          reason: 'send it back',
        );
        final replay = await endpoints.rerouteToImplementation(
          session,
          workItemId: id,
          requestId: 'req-replay',
          requestedBy: 'dana',
          reason: 'send it back',
        );

        expect(first.outcome, 'accepted');
        expect(replay.outcome, 'accepted');
        expect(await harness.ledger(id), hasLength(1));
        expect(
          (await harness.store.readWorkItem(id)).state,
          WorkItemState.implementationReady,
        );
      },
    );

    test(
      'the consumed implement attempts set the floor — a job holding :a3 '
      'moves the bump to 4',
      () async {
        final id = await harness.seedDeployed(
          extraMetadata: const {'triageAttempt': 2},
        );
        endpoints.jobs = [
          _implementJob(id, dedupe: '$id:implement_feature:a3'),
        ];

        final result = await endpoints.rerouteToImplementation(
          session,
          workItemId: id,
          requestId: 'req-floor',
          requestedBy: 'dana',
          reason: 'send it back',
        );

        expect(result.outcome, 'accepted');
        final item = await harness.store.readWorkItem(id);
        expect(
          item.metadata?[DurableWorkflowEngine.triageAttemptMetadataKey],
          4,
          reason:
              'the floor is the highest attempt this item\'s own '
              'implement_feature jobs consumed — the same second-watermark '
              'rule the review repair applies',
        );
        expect(
          implementFeatureDedupeKey(item, implementFeatureDefinition),
          '$id:implement_feature:a4',
        );
      },
    );
  });

  group('honest refusals — nothing written', () {
    test('a non-deployed item is notApplicable', () async {
      await harness.store.saveWorkItem(
        WorkItem(
          workItemId: 'w-failed',
          productId: 'shipit',
          category: WorkItemCategory.bugfix,
          title: 'Failed, not deployed',
          description: 'belongs to the retry surface',
          state: WorkItemState.agentFailed,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          version: 1,
        ),
      );

      final result = await endpoints.rerouteToImplementation(
        session,
        workItemId: 'w-failed',
        requestId: 'req-wrong',
        requestedBy: 'dana',
        reason: 'send it back',
      );

      expect(result.outcome, 'notApplicable');
      expect(await harness.ledger('w-failed'), isEmpty);
      expect(
        (await harness.store.readWorkItem('w-failed')).state,
        WorkItemState.agentFailed,
      );
      expect(
        (await harness.store.readWorkItem(
          'w-failed',
        )).metadata?[DurableWorkflowEngine.triageAttemptMetadataKey],
        isNull,
        reason: 'a refusal writes no discriminator bump either',
      );
    });

    test('a blank reason or requester is invalidRequest', () async {
      final id = await harness.seedDeployed();

      final blankReason = await endpoints.rerouteToImplementation(
        session,
        workItemId: id,
        requestId: 'req-blank',
        requestedBy: 'dana',
        reason: '   ',
      );
      expect(blankReason.outcome, 'invalidRequest');

      final blankBy = await endpoints.rerouteToImplementation(
        session,
        workItemId: id,
        requestId: 'req-blankby',
        requestedBy: '  ',
        reason: 'send it back',
      );
      expect(blankBy.outcome, 'invalidRequest');

      expect(await harness.ledger(id), isEmpty);
      expect(
        (await harness.store.readWorkItem(id)).state,
        WorkItemState.deployed,
      );
    });

    test('a live job on the item refuses alreadyRunning', () async {
      final id = await harness.seedDeployed();
      endpoints.jobs = [_implementJob(id, active: true)];

      final result = await endpoints.rerouteToImplementation(
        session,
        workItemId: id,
        requestId: 'req-live',
        requestedBy: 'dana',
        reason: 'send it back',
      );

      expect(result.outcome, 'alreadyRunning');
      expect(await harness.ledger(id), isEmpty);
      expect(
        (await harness.store.readWorkItem(id)).state,
        WorkItemState.deployed,
      );
    });
  });

  group('the edge is real and not free', () {
    test(
      'deployed -> implementationReady is legal, and the marker guard '
      'refuses a bare orchestrator transition',
      () {
        const actor = WorkflowActor(
          actorId: 'some-sweep',
          actorType: ActorType.orchestrator,
        );
        expect(
          WorkItemTransitions.isLegalTransition(
            WorkItemState.deployed,
            WorkItemState.implementationReady,
          ),
          isTrue,
          reason: 'the EDGE exists — the guard is what narrows it',
        );
        expect(
          WorkItemTransitions.validate(
            WorkItemState.deployed,
            WorkItemState.implementationReady,
            TransitionTrigger.systemEvent,
            actor,
            const {},
          ).isValid,
          isFalse,
          reason:
              'an orchestrator actor alone is NOT admitted: the edge is '
              'the audited reroute action\'s, and a sweep holding an '
              'orchestrator actor must not walk a deployed item backwards',
        );
        expect(
          WorkItemTransitions.validate(
            WorkItemState.deployed,
            WorkItemState.implementationReady,
            TransitionTrigger.systemEvent,
            actor,
            const {operatorRerouteContextKey: true},
          ).isValid,
          isTrue,
          reason: 'the marker the action sets is what the second guard reads',
        );
      },
    );
  });
}

const _itemId = 'WI-reroute-1';

/// An `implement_feature` job row — terminal by default so it holds its
/// dedupe key without tripping the live-attempt refusal.
Job _implementJob(
  String workItemId, {
  String? dedupe,
  bool active = false,
}) => Job(
  jobId: 'jb-$workItemId-${dedupe ?? 'base'}',
  workItemId: workItemId,
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {},
  priority: JobPriority.normal,
  state: active ? JobState.running : JobState.failed,
  dedupeKey: dedupe ?? '$workItemId:implement_feature',
  createdAt: DateTime.utc(2026),
  instruction: 'implement it',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

/// One stranded item's worth of wiring: real stores, real endpoint — the
/// same seam `deploy_reland_test.dart` drives, minus the git.
class _Harness {
  final InMemoryWorkflowStore store = InMemoryWorkflowStore();
  final InMemoryExecutionStore executionStore = InMemoryExecutionStore();
  final InMemoryWorkerStore workerStore = InMemoryWorkerStore();

  Future<List<OperatorActionRecord>> ledger(String id) =>
      store.readOperatorActionsForWorkItem(id);

  /// A `deployed` item — the parked shape F-261 names. [stamped] pre-writes
  /// the `deployed*` evidence for the reroutes-anyway arm.
  Future<String> seedDeployed({
    String id = _itemId,
    bool stamped = false,
    Map<String, dynamic>? extraMetadata,
  }) async {
    await store.saveWorkItem(
      WorkItem(
        workItemId: id,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A deployed work item with no path back',
        description: 'Its re-land refused: the producer left no commit.',
        state: WorkItemState.deployed,
        metadata: {
          'producerActorId': 'ex-prod',
          if (stamped) ...const {
            'deployedCommit': 'c0ffee-stamped',
            'deployedInto': '/durable/clone#main',
            'deployedCommitBasis': 'producedCommit',
            'deployedAt': '2026-10-20T00:00:00.000Z',
            'deployedBy': 'deploy_landing',
          },
          ...?extraMetadata,
        },
        createdAt: DateTime.utc(2026, 10, 21),
        updatedAt: DateTime.utc(2026, 10, 21),
        version: 1,
      ),
    );
    return id;
  }
}

/// Drives the REAL endpoint methods over in-memory stores — the same seam
/// `work_item_action_endpoints_test.dart` uses: the store is substituted,
/// never the refusal.
class _TestEndpoints extends WorkItemActionEndpoints {
  _TestEndpoints(this._harness);

  final _Harness _harness;

  /// The jobs `listJobsForWorkItem` reports.
  List<Job> jobs = const [];

  @override
  ControlPlaneService serviceFor(Session session) =>
      _TestService(session, _harness, this);
}

/// The real service, with its Postgres-backed stores replaced by in-memory
/// ones and its job reads answered from a list.
class _TestService extends ControlPlaneService {
  _TestService(super.session, this._harness, this._owner);

  final _Harness _harness;
  final _TestEndpoints _owner;

  @override
  WorkflowStore get workflowStore => _harness.store;

  @override
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: _harness.store);

  @override
  Future<List<Job>> listJobs() async => _owner.jobs;

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) async =>
      _owner.jobs.where((j) => j.workItemId == workItemId).toList();

  @override
  ExecutionStore get executionStore => _harness.executionStore;

  @override
  WorkerStore get workerStore => _harness.workerStore;
}

/// A [Session] that records log lines and never touches a database.
class _FakeSession implements Session {
  final List<String> logs = [];

  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    logs.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Session.${invocation.memberName} is not used here',
  );
}

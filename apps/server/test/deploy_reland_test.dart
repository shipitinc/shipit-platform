import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/deploy/deploy_landing.dart';
import 'package:control_plane_server/src/deploy/deploy_push.dart';
import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, InMemoryExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart'
    show InMemoryWorkerStore, WorkerStore;
import 'package:workflow_store/workflow_store.dart'
    show
        DurableWorkflowEngine,
        InMemoryWorkflowStore,
        OperatorActionRecord,
        WorkflowStore;

/// The re-land: an operator path for a `deployed` item that was never made
/// true — F-259.
///
/// ## THE DEFECT THIS FILE HOLDS CLOSED
///
/// Items whose `deployment_approval` resolved under the pre-deploy artifact
/// — before `deploy_landing` existed — sit at `deployed` as a bare LABEL:
/// `deployedCommit` NULL and nothing merged into the recorded checkout. The
/// land arm fires only on a PENDING `deployment_approval` resolution and
/// `deployed` has no edge back, so there was no re-land path at all.
/// `relandDeployedWorkItem` is that path: the same verified merge the
/// approve path dispatches, triggered by the operator, owed iff the item is
/// `deployed` AND carries no `deployedCommit` stamp.
///
/// ## WHAT IS ASSERTED — against a REAL scratch git repository
///
///   1. a `deployed` item without the stamp re-lands: the produced commit is
///      merged into the checkout's target branch, proven an ancestor of its
///      HEAD, and the `deployed*` evidence is stamped;
///   2. a replayed `requestId` reports the completed intent — no second
///      audit row, no second merge;
///   3. a STAMPED `deployed` item refuses `notApplicable` and merges
///      nothing — the owed test, not luck;
///   4. a commit that is already merged but unstamped (the crash window)
///      finishes through the already-landed arm without re-merging;
///   5. a no-producer item and a no-commit producer refuse honestly —
///      `notApplicable`, nothing merged, nothing written;
///   6. the ordinary guards hold: wrong state, blank reason, blank
///      requester;
///   7. [deployRelandIsOwed] is the stated predicate and nothing else.
///
/// ## WHY REAL GIT AND THE REAL ENDPOINT
///
/// Same rule as `deploy_landing_test.dart`: the merge is the claim being
/// made true, so it runs against a scratch repository the test itself
/// creates and destroys. The stores are the real in-memory ones and the
/// endpoint is the production class — only the persistence substrate is
/// substituted, never a refusal.
void main() {
  late _Harness harness;
  late Directory repo;
  late String base;
  late String produced;
  late Session session;

  setUp(() async {
    harness = _Harness();
    session = _FakeSession();
    repo = await Directory.systemTemp.createTemp('deploy_reland_test_');
    base = await _git(repo.path, ['init', '-b', 'main']).then(
      (_) => _initBase(repo.path),
    );
    produced = await _produceCommit(repo.path, _itemId);
  });

  tearDown(() async {
    if (repo.existsSync()) await repo.delete(recursive: true);
  });

  group('a deployed item without the stamp', () {
    test(
      're-lands: the produced commit is merged, verified, and the '
      'deployed* evidence is stamped',
      () async {
        final id = await harness.seedDeployedLabelOnly(
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );

        final result = await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-reland-1',
          requestedBy: 'dana',
          reason: 'the deploy resolved before the land existed',
        );

        expect(result.outcome, 'accepted');

        // The deploy is REAL: the produced commit is reachable from the
        // target branch's HEAD.
        expect(
          await _exit(repo.path, [
            'merge-base',
            '--is-ancestor',
            produced,
            'HEAD',
          ]),
          0,
          reason:
              're-landed must mean the produced commit is on the branch, '
              'not merely claimed',
        );

        // The item did not move — `deployed` was already the label — but it
        // now carries the evidence that made it true.
        final item = await harness.store.readWorkItem(id);
        expect(item.state, WorkItemState.deployed);
        expect(item.metadata?['deployedCommit'], produced);
        expect(item.metadata?['deployedInto'], '${repo.path}#main');
        expect(item.metadata?['deployedCommitBasis'], 'producedCommit');
        expect(item.metadata?['deployedBy'], deployRelandMechanismName);
        expect(item.metadata?['deployedAt'], isNotNull);

        // One audit row, naming the human, honestly recording deployed ->
        // deployed: the stamp is the change, not a state move.
        final rows = await harness.ledger(id);
        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row.action, 'reland');
        expect(row.fromState, WorkItemState.deployed.wire);
        expect(row.toState, WorkItemState.deployed.wire);
        expect(row.requestedBy, 'dana');
        expect(row.reason, 'the deploy resolved before the land existed');
        expect(row.requestId, 'req-reland-1');
        expect(row.attemptNumber, isNull);
      },
    );

    test(
      'a replayed requestId reports the completed intent — no second row, '
      'no second merge',
      () async {
        final id = await harness.seedDeployedLabelOnly(
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );

        final first = await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-replay',
          requestedBy: 'dana',
          reason: 'land it',
        );
        final headAfterFirst = await _git(repo.path, ['rev-parse', 'HEAD']);

        final replay = await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-replay',
          requestedBy: 'dana',
          reason: 'land it',
        );

        expect(first.outcome, 'accepted');
        expect(replay.outcome, 'accepted');
        expect(await harness.ledger(id), hasLength(1));
        expect(
          await _git(repo.path, ['rev-parse', 'HEAD']),
          headAfterFirst,
          reason: 'a replay finds its own row and merges nothing again',
        );
      },
    );

    test(
      'a STAMPED deployed item is notApplicable and merges nothing',
      () async {
        final id = await harness.seedDeployedLabelOnly(
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
          stamped: true,
        );
        final headBefore = await _git(repo.path, ['rev-parse', 'HEAD']);

        final result = await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-stamped',
          requestedBy: 'dana',
          reason: 'land it again',
        );

        expect(result.outcome, 'notApplicable');
        expect(
          await _git(repo.path, ['rev-parse', 'HEAD']),
          headBefore,
          reason:
              'a stamped item owes nothing — the owed test refuses BEFORE '
              'the land, or the produced commit would have merged',
        );
        expect(await harness.ledger(id), isEmpty);
        // The seed's own stamp is untouched — a re-land must not overwrite
        // the evidence it claims to supply.
        expect(
          (await harness.store.readWorkItem(id)).metadata?['deployedCommit'],
          'c0ffee-stamped',
        );
      },
    );

    test(
      'a fresh intent on an item a first re-land already stamped refuses — '
      'idempotent across requestIds',
      () async {
        final id = await harness.seedDeployedLabelOnly(
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );

        await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-first',
          requestedBy: 'dana',
          reason: 'land it',
        );
        final headAfterFirst = await _git(repo.path, ['rev-parse', 'HEAD']);

        final second = await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-second',
          requestedBy: 'dana',
          reason: 'land it again',
        );

        expect(second.outcome, 'notApplicable');
        expect(await harness.ledger(id), hasLength(1));
        expect(await _git(repo.path, ['rev-parse', 'HEAD']), headAfterFirst);
      },
    );

    test(
      'a commit already merged but unstamped — the crash window — finishes '
      'through the already-landed arm',
      () async {
        final id = await harness.seedDeployedLabelOnly(
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );
        final item = await harness.store.readWorkItem(id);

        // The crash shape: the merge committed, the stamp write never ran.
        // `landApprovedDeployment` is the same land the endpoint dispatches;
        // it performs no durable write.
        final crashed = await landApprovedDeployment(
          executionStore: harness.executionStore,
          workerStore: harness.workerStore,
          item: item,
          deployPush: harness.pusher,
        );
        expect(crashed.alreadyLanded, isFalse);
        expect(
          (await harness.store.readWorkItem(id)).metadata?['deployedCommit'],
          isNull,
          reason: 'the stamp was never written — that is the crash',
        );
        final headAfterCrash = await _git(repo.path, ['rev-parse', 'HEAD']);

        final result = await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-finish',
          requestedBy: 'dana',
          reason: 'finish the interrupted land',
        );

        expect(result.outcome, 'accepted');
        expect(
          await _git(repo.path, ['rev-parse', 'HEAD']),
          headAfterCrash,
          reason:
              'the already-landed arm verifies the ancestry and merges '
              'nothing — the interrupted intent is finished, not repeated',
        );
        final stamped = await harness.store.readWorkItem(id);
        expect(stamped.metadata?['deployedCommit'], produced);
        expect(await harness.ledger(id), hasLength(1));
      },
    );
  });

  group('honest refusals — nothing merged, nothing written', () {
    test('a no-producer deployed item refuses notApplicable', () async {
      final id = await harness.seedDeployedLabelOnly(withProducer: false);
      final headBefore = await _git(repo.path, ['rev-parse', 'HEAD']);

      final result = await harness.endpoints.relandDeployedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-noprod',
        requestedBy: 'dana',
        reason: 'land it',
      );

      expect(result.outcome, 'notApplicable');
      expect(await _git(repo.path, ['rev-parse', 'HEAD']), headBefore);
      expect(await harness.ledger(id), isEmpty);
      expect(
        (await harness.store.readWorkItem(id)).metadata?['deployedCommit'],
        isNull,
      );
    });

    test(
      'a producer that left no commit and no starting revision refuses '
      'honestly — nothing invented',
      () async {
        final id = await harness.seedDeployedLabelOnly(
          repositoryPath: repo.path,
          startingRevision: null,
          endingRevision: null,
        );
        final headBefore = await _git(repo.path, ['rev-parse', 'HEAD']);

        final result = await harness.endpoints.relandDeployedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-nocommit',
          requestedBy: 'dana',
          reason: 'land it',
        );

        expect(result.outcome, 'notApplicable');
        expect(await _git(repo.path, ['rev-parse', 'HEAD']), headBefore);
        expect(await harness.ledger(id), isEmpty);
      },
    );

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

      final result = await harness.endpoints.relandDeployedWorkItem(
        session,
        workItemId: 'w-failed',
        requestId: 'req-wrong',
        requestedBy: 'dana',
        reason: 'land it',
      );

      expect(result.outcome, 'notApplicable');
      expect(await harness.ledger('w-failed'), isEmpty);
    });

    test('a blank reason or requester is invalidRequest', () async {
      final id = await harness.seedDeployedLabelOnly(
        repositoryPath: repo.path,
        startingRevision: base,
        endingRevision: produced,
      );

      final blankReason = await harness.endpoints.relandDeployedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-blank',
        requestedBy: 'dana',
        reason: '   ',
      );
      expect(blankReason.outcome, 'invalidRequest');

      final blankBy = await harness.endpoints.relandDeployedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-blankby',
        requestedBy: '  ',
        reason: 'land it',
      );
      expect(blankBy.outcome, 'invalidRequest');

      expect(await harness.ledger(id), isEmpty);
      expect(
        (await harness.store.readWorkItem(id)).metadata?['deployedCommit'],
        isNull,
      );
    });

    test('a live job on the item refuses alreadyRunning', () async {
      final id = await harness.seedDeployedLabelOnly(
        repositoryPath: repo.path,
        startingRevision: base,
        endingRevision: produced,
      );
      harness.endpoints.jobs = [_job(id)];

      final result = await harness.endpoints.relandDeployedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-live',
        requestedBy: 'dana',
        reason: 'land it',
      );

      expect(result.outcome, 'alreadyRunning');
      expect(await harness.ledger(id), isEmpty);
    });
  });

  group('deployRelandIsOwed', () {
    test(
      'is true only for a deployed item with no usable deployedCommit',
      () async {
        final unstamped = await harness.seedDeployedLabelOnly(
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );
        final stamped = await harness.seedDeployedLabelOnly(
          id: 'wi-stamped',
          stamped: true,
        );
        final emptyStamp = await harness.seedDeployedLabelOnly(
          id: 'wi-empty',
          extraMetadata: const {'deployedCommit': ''},
        );

        expect(
          deployRelandIsOwed(await harness.store.readWorkItem(unstamped)),
          isTrue,
          reason: 'deployed label-only is exactly the stranded shape',
        );
        expect(
          deployRelandIsOwed(await harness.store.readWorkItem(stamped)),
          isFalse,
          reason: 'a stamped item owes nothing — the evidence exists',
        );
        expect(
          deployRelandIsOwed(await harness.store.readWorkItem(emptyStamp)),
          isTrue,
          reason: 'an empty stamp is no stamp at all',
        );
      },
    );
  });
}

const _itemId = 'WI-reland-1';

Future<String> _git(String dir, List<String> args) async {
  final result = await Process.run(
    'git',
    [
      '-C',
      dir,
      ...args,
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} in $dir exited ${result.exitCode}: '
      '${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

Future<int> _exit(String dir, List<String> args) async {
  final result = await Process.run(
    'git',
    [
      '-C',
      dir,
      ...args,
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return result.exitCode;
}

Future<String> _initBase(String dir) async {
  await File('$dir/file.txt').writeAsString('base\n');
  await _git(dir, ['add', 'file.txt']);
  await _git(dir, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@test',
    'commit',
    '-m',
    'init',
  ]);
  return _git(dir, ['rev-parse', 'HEAD']);
}

/// A produced implementation commit on `shipit/impl/<workItemId>` — the
/// shape `ArtifactCommitter` leaves behind.
Future<String> _produceCommit(String dir, String workItemId) async {
  await _git(dir, ['checkout', '-b', 'shipit/impl/$workItemId']);
  await File('$dir/feature.txt').writeAsString('the produced change\n');
  await _git(dir, ['add', 'feature.txt']);
  await _git(dir, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@test',
    'commit',
    '-m',
    'implement $workItemId',
  ]);
  final produced = await _git(dir, ['rev-parse', 'HEAD']);
  await _git(dir, ['checkout', 'main']);
  return produced;
}

Job _job(String workItemId) => Job(
  jobId: 'jb-$workItemId',
  workItemId: workItemId,
  jobType: JobType.triageDefect,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {},
  priority: JobPriority.normal,
  state: JobState.running,
  dedupeKey: '$workItemId:triage_defect',
  createdAt: DateTime.utc(2026),
  instruction: 'triage this defect',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

/// One stranded item's worth of wiring: real stores, real endpoint, real
/// git — the same seam `work_item_action_endpoints_test.dart` drives, with
/// the deploy-landing fixture shape on top.
class _Harness {
  final InMemoryWorkflowStore store = InMemoryWorkflowStore();
  final InMemoryExecutionStore executionStore = InMemoryExecutionStore();
  final InMemoryWorkerStore workerStore = InMemoryWorkerStore();
  final _FakeDeployPusher pusher = _FakeDeployPusher();

  late final _TestEndpoints endpoints = _TestEndpoints(this);

  Future<List<OperatorActionRecord>> ledger(String id) =>
      store.readOperatorActionsForWorkItem(id);

  /// A `deployed` item missing its landed stamp — the stranded shape F-259
  /// names — with the producer and worker executions the land resolves.
  ///
  /// [repositoryPath], [startingRevision] and [endingRevision] are the REAL
  /// values the test's scratch repository produced, exactly as
  /// `deploy_landing_test.dart` seeds them: `producedCommitFor` reads the
  /// worker execution, the agent execution's workspace records
  /// [startingRevision] as the fallback.
  ///
  /// [stamped] pre-writes the `deployed*` stamp for the not-owed arms.
  Future<String> seedDeployedLabelOnly({
    String id = _itemId,
    bool withProducer = true,
    bool stamped = false,
    String? repositoryPath,
    String? startingRevision,
    String? endingRevision,
    Map<String, dynamic>? extraMetadata,
  }) async {
    await store.saveWorkItem(
      WorkItem(
        workItemId: id,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A deployed-label-only work item',
        description: 'Its approval resolved before the land existed.',
        state: WorkItemState.deployed,
        metadata: {
          if (withProducer) 'producerActorId': 'ex-prod',
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
    if (!withProducer) return id;

    await executionStore.saveExecution(
      AgentExecution(
        executionId: 'ex-prod',
        workItemId: id,
        requestId: 'req-prod',
        runtimeTypeId: 'local',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        workspace: AgentWorkspace(
          workspaceId: 'ws-1',
          path: '/tmp/ws',
          startingRevision: startingRevision,
        ),
        startedAt: DateTime.utc(2026),
      ),
    );
    await executionStore.saveResult(
      'ex-prod',
      AgentResult(
        resultId: 'res-prod',
        sessionId: 'sess-prod',
        workItemId: id,
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
        completedAt: DateTime.utc(2026),
      ),
    );
    if (repositoryPath != null) {
      await workerStore.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: 'wx-prod',
          workItemId: id,
          repositoryPath: repositoryPath,
          requestedStartingRevision: startingRevision ?? '',
          requiredCapabilities: const {
            WorkerCapability.linux,
            WorkerCapability.git,
          },
          agentExecutionId: 'ex-prod',
          endingRevision: endingRevision,
          status: WorkerExecutionStatus.executedPass,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        ),
      );
    }
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
///
/// `ControlPlaneService._db` is `late final` and is never touched here,
/// because every accessor this surface uses is overridden below.
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

  @override
  DeployPusher get deployPusher => _harness.pusher;
}

/// A [DeployPusher] that records its calls and reports the branch pushed —
/// the same seam `deploy_landing_test.dart` drives. The push's own
/// transport and credential resolution are exercised for real in
/// `deploy_push_test.dart`; here the merge and the stamp are the subject.
class _FakeDeployPusher implements DeployPusher {
  final List<({String repositoryPath, String targetBranch, String localHead})>
  calls = [];

  @override
  Future<DeployPush> pushLandedBranch({
    required WorkItem item,
    required String repositoryPath,
    required String targetBranch,
    required String localHead,
  }) async {
    calls.add((
      repositoryPath: repositoryPath,
      targetBranch: targetBranch,
      localHead: localHead,
    ));
    return DeployPush(
      state: DeployPushState.pushed,
      remoteUrl: 'ssh://git@remote.test:22/org/repo.git',
      branch: targetBranch,
      remoteHead: localHead,
    );
  }
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

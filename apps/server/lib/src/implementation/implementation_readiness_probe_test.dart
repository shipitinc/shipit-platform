import 'dart:io'
    show Directory, File, Platform, Process, ProcessException, ProcessResult;

import 'package:control_plane_server/src/implementation/implementation_readiness_probe.dart';
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
        WorkerExecutionResult,
        WorkspaceDescriptor;
import 'package:scheduler/scheduler.dart'
    show
        InMemoryJobStore,
        Scheduler,
        SchedulerWorkload,
        WorkerDispatch,
        implementFeatureDedupeKey,
        implementFeatureDefinition,
        implementFeatureInstruction,
        implementFeatureRequest;
import 'package:worker_protocol/worker_protocol.dart' show WorkerSelection;
import 'package:worker_runtime/worker_runtime.dart' show InMemoryWorkerStore;
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore, WorkflowStore;
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// The readiness probe, gate by gate.
///
/// ## Why these tests exist rather than a single happy path
///
/// The probe's whole job is to say NO in four different situations, and the four
/// are not interchangeable. Three of them are ordinary (a product still being
/// set up) and one is a broken record (a clone that is gone or at the wrong
/// commit). A probe that conflated them would either block a product forever or
/// dispatch into a repository it cannot vouch for — and the second is the one
/// this repository has already been damaged by once.
///
/// So each gate gets its own test, each with the operator-facing reason
/// asserted, because the reason is the only thing a human gets.
void main() {
  late Directory repoRoot;
  late String realCommit;
  const pin = '0123456789abcdef0123456789abcdef01234567';

  setUpAll(() {
    repoRoot = Directory.systemTemp.createTempSync('impl-probe-repo');

    ProcessResult git(List<String> args) => Process.runSync(
      'git',
      args,
      workingDirectory: repoRoot.path,
      environment: {
        ...Platform.environment,
        'GIT_AUTHOR_NAME': 't',
        'GIT_AUTHOR_EMAIL': 't@e.test',
        'GIT_COMMITTER_NAME': 't',
        'GIT_COMMITTER_EMAIL': 't@e.test',
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
      },
    );

    git(['init', '-q', '-b', 'main']);
    File('${repoRoot.path}/README.md').writeAsStringSync('fixture\n');
    git(['add', '.']);
    git(['commit', '-q', '-m', 'x']);
    realCommit = git(['rev-parse', 'HEAD']).stdout.toString().trim();
  });

  tearDownAll(() {
    if (repoRoot.existsSync()) repoRoot.deleteSync(recursive: true);
  });

  WorkItem item() {
    final now = DateTime.utc(2026);
    return WorkItem(
      workItemId: 'wi-probe',
      productId: 'product-a',
      category: WorkItemCategory.feature,
      title: 'A fixture item used only to ask the probe about a product',
      description: 'The probe reads the product and its onboarding record.',
      state: WorkItemState.implementationReady,
      createdAt: now,
      updatedAt: now,
    );
  }

  OnboardingRecord durableRecord({
    String repositoryPath = '',
    String pinnedRevision = pin,
    String workspaceId = 'dws-product-a',
  }) => OnboardingRecord(
    onboardingId: 'onb-1',
    productId: 'product-a',
    pinnedRevision: pinnedRevision,
    workspace: OnboardingWorkspace.durable(
      DurableWorkspaceDescriptor(
        workspaceId: workspaceId,
        productId: 'product-a',
        repositoryPath: repositoryPath,
        startingRevision: pinnedRevision,
        createdAt: DateTime.utc(2026),
      ),
    ),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  /// A record with a pin and NO workspace at all — the ordinary state of a
  /// product whose onboarding is incomplete.
  OnboardingRecord recordWithoutWorkspace() => OnboardingRecord(
    onboardingId: 'onb-0',
    productId: 'product-a',
    pinnedRevision: pin,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  /// An `OnboardingRecord` holding the PER-EXECUTION shape instead of the
  /// durable one.
  ///
  /// Constructed on purpose: this is the shape that answers `true` to the
  /// deprecated, shape-blind `hasDurableWorkspace`, so a probe that gated on it
  /// would read a worker execution's worktree as the product's clone and dispatch
  /// there without a word. The gate is `hasDurableProductClone`, and this
  /// fixture is what proves it.
  OnboardingRecord perExecutionRecord() => OnboardingRecord(
    onboardingId: 'onb-2',
    productId: 'product-a',
    pinnedRevision: pin,
    workspace: OnboardingWorkspace.execution(
      WorkspaceDescriptor(
        workspaceId: 'ws-exec',
        worktreePath: '/some/execution/worktree',
        workerExecutionId: 'wx-1',
        workerId: 'w-1',
        repositoryPath: '/some/execution/worktree',
        startingRevision: pin,
        createdAt: DateTime.utc(2026),
      ),
    ),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  /// Collects the event names the probe emits, in order.
  ///
  /// A sink rather than a return value so a caller can hand the same list to
  /// several probes and read one ordered sequence — which is what proves each
  /// gate emits a DISTINCT name rather than all three reusing one.
  final emitted = <String>[];

  ImplementationReadinessProbe probeFor({
    ProductState? state = ProductState.governed,
    OnboardingRecord? record,
    bool durableRuntimeAvailable = true,
    String? unavailableReason,
    List<String>? log,
  }) => ImplementationReadinessProbe(
    readProductState: (productId) async => state,
    readOnboarding: (productId) async => record,
    runtimeTypeId: 'probe-runtime',
    timeoutSeconds: 1800,
    durableRuntimeAvailable: durableRuntimeAvailable,
    durableRuntimeUnavailableReason: unavailableReason,
    log: (event, data) => (log ?? emitted).add(event),
  );

  group('gate 0 — the runtime itself', () {
    test(
      'an unavailable runtime defers for EVERY item, with the reason',
      () async {
        final readiness = await probeFor(
          // Even a governed product with a perfect record: if the runtime that
          // creates clones does not exist, nothing can be created later either.
          record: durableRecord(repositoryPath: repoRoot.path),
          durableRuntimeAvailable: false,
          unavailableReason: 'no custody substrate is configured',
        ).probe(item());

        final deferred = readiness as ImplementationWorkspaceDeferred;
        expect(deferred.reason, contains('no custody substrate is configured'));
      },
    );

    test(
      'a throwing product read defers rather than crashing the tick',
      () async {
        final probe = ImplementationReadinessProbe(
          readProductState: (productId) async => throw StateError('store down'),
          readOnboarding: (productId) async => null,
          runtimeTypeId: 'probe-runtime',
          timeoutSeconds: 1800,
        );
        final readiness = await probe.probe(item());
        expect(readiness, isA<ImplementationWorkspaceDeferred>());
        expect(
          (readiness as ImplementationWorkspaceDeferred).reason,
          contains('could not be read'),
        );
      },
    );
  });

  group('gate 1 — the product must be governed', () {
    test('an unknown product defers', () async {
      final readiness = await probeFor(state: null).probe(item());
      expect(readiness, isA<ImplementationWorkspaceDeferred>());
      expect(
        (readiness as ImplementationWorkspaceDeferred).reason,
        contains('does not exist'),
      );
    });

    for (final state in const [
      ProductState.registered,
      ProductState.baselinePending,
      ProductState.baselineBlocked,
      ProductState.baselineReview,
      ProductState.paused,
      ProductState.archived,
    ]) {
      test('${state.wire} defers with the state named', () async {
        final readiness = await probeFor(state: state).probe(item());
        final deferred = readiness as ImplementationWorkspaceDeferred;
        expect(deferred.reason, contains(state.wire));
        expect(
          deferred.reason,
          contains('Not a failure'),
          reason:
              'the reason must say this is a pause, not a defect. An operator '
              'reading "product is paused" and an operator reading "something '
              'broke" act completely differently',
        );
      });
    }
  });

  group('gate 2 — the record must name the product\'s DURABLE clone', () {
    test('no record at all defers', () async {
      final readiness = await probeFor().probe(item());
      expect(
        (readiness as ImplementationWorkspaceDeferred).reason,
        contains('no onboarding record'),
      );
    });

    test(
      'a PER-EXECUTION workspace is refused, not used as a fallback',
      () async {
        final readiness = await probeFor(
          record: perExecutionRecord(),
        ).probe(item());
        final deferred = readiness as ImplementationWorkspaceDeferred;
        expect(
          deferred.reason,
          contains('no live durable product clone'),
          reason:
              'the deprecated `hasDurableWorkspace` predicate answers TRUE for '
              'this record — it only asks whether a pin and a live workspace '
              'exist, not which shape the workspace is. Gating on it would hand '
              'the implementer a worker execution\'s worktree and call it the '
              'product\'s clone',
        );
      },
    );

    test('an unpinned durable clone is refused', () async {
      final record = durableRecord(repositoryPath: repoRoot.path).copyWith(
        pinnedRevision: null,
      );
      final readiness = await probeFor(record: record).probe(item());
      expect(readiness, isA<ImplementationWorkspaceDeferred>());
    });
  });

  group('gate 3 — the clone must be on disk and at its pin', () {
    test(
      'a recorded path that does not exist defers and names the path',
      () async {
        final readiness = await probeFor(
          record: durableRecord(repositoryPath: '/a/path/that/is/not/there'),
        ).probe(item());
        final deferred = readiness as ImplementationWorkspaceDeferred;
        expect(deferred.reason, contains('not on disk'));
        expect(deferred.reason, contains('/a/path/that/is/not/there'));
        expect(
          deferred.reason,
          contains('Not substituting'),
          reason:
              'the refusal must say what it is NOT doing. A deferral that could '
              'silently have fallen back to another repository is the exact '
              'hazard this probe exists to close',
        );
      },
    );

    test('a pin the clone does not contain defers with git\'s own output', () async {
      final readiness = await probeFor(
        record: durableRecord(
          repositoryPath: repoRoot.path,
          pinnedRevision: pin,
        ),
      ).probe(item());
      final deferred = readiness as ImplementationWorkspaceDeferred;
      expect(deferred.reason, contains('does not resolve commit $pin'));
      expect(
        deferred.reason,
        contains('Not substituting HEAD'),
        reason:
            '`HEAD` is a carve-out a sweep performs when it has to resolve an '
            'unpinned snapshot; it is never a pin a lane accepts. A probe that '
            'accepted it would make "verified" mean nothing',
      );
      expect(
        deferred.gitOutput,
        isNotNull,
        reason:
            'git said something specific — unknown revision, ambiguous '
            'argument, unreadable object database — and an operator needs that '
            'sentence, not a paraphrase of it',
      );
    });

    test('a real clone at its real pin resolves', () async {
      final record = durableRecord(
        repositoryPath: repoRoot.path,
        pinnedRevision: realCommit,
      );
      final readiness = await probeFor(record: record).probe(item());

      final ready = readiness as ImplementationWorkspaceReady;
      expect(ready.workspace.repositoryPath, repoRoot.path);
      expect(ready.workspace.startingRevision, realCommit);
      expect(ready.workspace.timeoutSeconds, 1800);
      expect(ready.workspace.runtimeTypeId, 'probe-runtime');
      expect(ready.descriptor.workspaceId, 'dws-product-a');
    });

    test('the resolved workload carries the PIN, never HEAD', () async {
      final record = durableRecord(
        repositoryPath: repoRoot.path,
        pinnedRevision: realCommit,
      );
      final ready =
          (await probeFor(record: record).probe(item()))
              as ImplementationWorkspaceReady;
      expect(ready.workspace.startingRevision, isNot('HEAD'));
      expect(ready.workspace.startingRevision, realCommit);
    });
  });

  group('every deferral is visible to an operator', () {
    test('each one emits its own named log event', () async {
      final events = <String>[];
      // ignore: unnecessary_lambdas
      Future<void> probeOne(ImplementationReadinessProbe p) => p.probe(item());

      await probeOne(
        probeFor(state: ProductState.paused, log: events),
      );
      await probeOne(
        probeFor(record: recordWithoutWorkspace(), log: events),
      );
      await probeOne(
        probeFor(
          record: durableRecord(repositoryPath: '/not/there'),
          log: events,
        ),
      );

      expect(events, [
        'implementation.deferred.product_not_governed',
        'implementation.deferred.no_durable_workspace',
        'implementation.deferred.workspace_missing',
      ]);
    });

    test('a deferral names the work item and what will happen next', () async {
      final seen = <Map<String, dynamic>>[];
      final probe = ImplementationReadinessProbe(
        readProductState: (productId) async => ProductState.paused,
        readOnboarding: (productId) async => null,
        runtimeTypeId: 'probe-runtime',
        timeoutSeconds: 1800,
        log: (event, data) => seen.add(data),
      );
      await probe.probe(item());

      expect(seen, hasLength(1));
      expect(seen.single['workItemId'], 'wi-probe');
      expect(seen.single['productId'], 'product-a');
      expect(seen.single['action'], contains('Not dispatched, not failed'));
    });

    test('the resolver maps ready to a workload and deferred to null', () async {
      final resolve = toWorkloadResolver(
        probeFor(
          record: durableRecord(
            repositoryPath: repoRoot.path,
            pinnedRevision: realCommit,
          ),
        ),
      );
      expect(await resolve(_job(), item()), isNotNull);

      final deferring = toWorkloadResolver(
        probeFor(state: ProductState.paused),
      );
      expect(
        await deferring(_job(), item()),
        isNull,
        reason:
            'null is what stops the dispatch. Which channel the scheduler then '
            'reports it on is `OD-4`; that it does not dispatch at all is not',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TOTALITY: no injected port may throw out of the probe.
  //
  // `probe` is documented as "it never throws — a probe that throws would abort
  // the scheduler's tick for one bad item". That contract is only worth
  // something if it is EXERCISED, and the port that most obviously could break
  // it is the one that was missing a guard: `_gitRevParse` runs
  // `Process.runSync`, which THROWS `ProcessException` when the process cannot
  // start at all (git not installed, PATH broken, fork denied). Nothing
  // between that throw and `implScheduler.tick()` catches it — `toWorkloadResolver`
  // awaits `probe` bare, and `_dispatchOne` awaits the resolver bare — so one
  // product's broken clone would abort the dispatch pass for EVERY job in that
  // tick. These tests are the contract, and the last one is the contract's whole
  // point: a bad clone must cost exactly ONE job, not the tick.
  // ---------------------------------------------------------------------------
  group('no injected port can throw out of the probe', () {
    test(
      'a throwing readOnboarding defers rather than crashing the tick',
      () async {
        // The asymmetry this closes: `readProductState` had a guard and a test,
        // `readOnboarding` had a guard and NO test. A guard nobody exercises is
        // a guard one edit away from being deleted.
        final events = <String>[];
        final probe = ImplementationReadinessProbe(
          readProductState: (_) async => ProductState.governed,
          readOnboarding: (_) async =>
              throw StateError('onboarding store down'),
          runtimeTypeId: 'probe-runtime',
          timeoutSeconds: 1800,
          log: (event, data) => events.add(event),
        );

        final readiness = await probe.probe(item());

        expect(readiness, isA<ImplementationWorkspaceDeferred>());
        final deferred = readiness as ImplementationWorkspaceDeferred;
        expect(deferred.reason, contains('could not be read'));
        expect(
          deferred.reason,
          contains('onboarding store down'),
          reason:
              'the exception\'s own text is the only thing that says WHICH store '
              'is down. "could not be read" alone sends the operator to the '
              'wrong system',
        );
        expect(
          events,
          ['implementation.deferred.onboarding_unreadable'],
          reason:
              'a refusal that is logged nowhere looks like an idle scheduler',
        );
      },
    );

    test(
      'a commit resolver that THROWS defers instead of escaping the probe',
      () async {
        // The exact failure `_gitRevParse` produces when the process cannot
        // start — `Process.runSync` throws rather than returning a non-zero
        // exit code — raised here through the same port the composition root
        // leaves at its default.
        final events = <String>[];
        final probe = ImplementationReadinessProbe(
          readProductState: (_) async => ProductState.governed,
          readOnboarding: (_) async => durableRecord(
            repositoryPath: repoRoot.path,
          ),
          repositoryExists: (_) => true,
          resolveCommit: (path, revision) => throw ProcessException(
            'git',
            ['-C', path, 'rev-parse', '--verify', '$revision^{commit}'],
            'No such file or directory',
          ),
          runtimeTypeId: 'probe-runtime',
          timeoutSeconds: 1800,
          log: (event, data) => events.add(event),
        );

        final readiness = await probe.probe(item());

        expect(
          readiness,
          isA<ImplementationWorkspaceDeferred>(),
          reason:
              'a throw here does not merely fail one probe: `toWorkloadResolver` '
              'and `_dispatchOne` both await this bare, so it leaves `tick()` '
              'and aborts the dispatch pass for every OTHER job in the tick',
        );
        final deferred = readiness as ImplementationWorkspaceDeferred;
        expect(deferred.reason, contains(pin));
        expect(
          deferred.gitOutput,
          contains('No such file or directory'),
          reason:
              'the operator needs the sentence git could not give them. A '
              'deferral that says only "could not resolve" reads as "the pin is '
              'wrong", and the fix is in the wrong place — the pin is fine; the '
              'binary is missing',
        );
        expect(events, ['implementation.deferred.pin_unresolvable']);
      },
    );

    test(
      'one job\'s broken clone costs that job ALONE — the next job in the same '
      'tick still dispatches',
      () async {
        // The end-to-end form of the same property, through a REAL `Scheduler`
        // over real in-memory stores and the REAL `toWorkloadResolver`
        // adapter. Asserting on `probe()` alone would pass while the tick still
        // died, because the tick's behaviour is a property of the chain, not of
        // the probe.
        final workflowStore = InMemoryWorkflowStore();
        final jobStore = InMemoryJobStore();
        final engine = DurableWorkflowEngine(store: workflowStore);

        for (final id in [badCloneItem, goodCloneItem]) {
          await engine.createWorkItem(
            workItemId: id,
            productId: 'product-$id',
            category: WorkItemCategory.feature,
            title: 'Fixture item $id',
            description: 'A fixture used to ask what one bad clone costs',
          );
          await _parkAtImplementationReady(workflowStore, id);
        }

        const badClonePath = '/a/clone/whose/git/cannot/start';
        const goodClonePath = '/a/clone/at/its/pin';
        final goodPin = 'c' * 40;

        // The production adapter, unmodified, over a probe whose commit port
        // raises for ONE product's clone and answers for the other's.
        final inner = toWorkloadResolver(
          ImplementationReadinessProbe(
            readProductState: (_) async => ProductState.governed,
            readOnboarding: (productId) async => OnboardingRecord(
              onboardingId: 'onb-$productId',
              productId: productId,
              pinnedRevision: goodPin,
              workspace: OnboardingWorkspace.durable(
                DurableWorkspaceDescriptor(
                  workspaceId: 'dws-$productId',
                  productId: productId,
                  repositoryPath: productId == 'product-$badCloneItem'
                      ? badClonePath
                      : goodClonePath,
                  startingRevision: goodPin,
                  createdAt: DateTime.utc(2026),
                ),
              ),
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
            repositoryExists: (_) => true,
            resolveCommit: (path, revision) {
              if (path == badClonePath) {
                throw ProcessException(
                  'git',
                  const ['rev-parse'],
                  'No such file or directory',
                );
              }
              return (commit: revision, output: null);
            },
            runtimeTypeId: 'probe-runtime',
            timeoutSeconds: 1800,
          ),
        );

        // Records the ORDER jobs were dispatched-attempted in. Without this the
        // test could pass vacuously — e.g. if the broken job were never reached
        // at all, "the healthy job dispatched" would prove nothing.
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
            return inner(job, item);
          },
          // INERT. Named so a request carrying it is identifiable: nothing may
          // ever fall through to it.
          workload: SchedulerWorkload(
            repositoryPath: 'a-triage-only-checkout',
            startingRevision: 'a' * 40,
            timeoutSeconds: 1800,
            runtimeTypeId: 'fake-runtime',
          ),
          clock: () => DateTime.utc(2026, 1, 1),
        ).tick();

        expect(
          attempted,
          containsAll([badCloneItem, goodCloneItem]),
          reason:
              'NON-VACUITY. Both jobs must have been dispatch-attempted in THIS '
              'tick. If the broken one was never reached, the assertion below '
              'says nothing about whether one bad clone can take the others '
              'down with it. Order is not asserted and does not need to be: a '
              'throw from EITHER position aborts the pass equally',
        );

        expect(
          requests.map((r) => r.workItemId),
          [goodCloneItem],
          reason:
              'this is the finding. The healthy job must have had its request '
              'BUILT in the same tick that the other job\'s commit resolver '
              'threw. Before the probe caught the throw, this exception '
              'propagated through `toWorkloadResolver` and the unguarded '
              '`await _workloadResolver(...)` in `_dispatchOne`, out of '
              '`tick()`, and no job after the bad one was ever looked at',
        );
        expect(requests.single.repositoryPath, goodClonePath);
        expect(requests.single.repositoryPath, isNot('a-triage-only-checkout'));
        expect(
          result.blockedArtifactMissing,
          hasLength(1),
          reason:
              'the broken job\'s refusal must be VISIBLE on the tick, and must '
              'be exactly one job\'s worth',
        );
        expect(result.terminal, isEmpty);
        expect(result.cancelledQueued, isEmpty);

        // A deferral is not a failure: the broken job is still queued, with its
        // retry budget untouched, so the next tick asks again.
        final stranded = (await jobStore.listJobsForWorkItem(
          badCloneItem,
        )).single;
        expect(stranded.state, JobState.queued);
        expect(
          stranded.attempt,
          1,
          reason: 'a bad clone must not burn the job\'s retry budget',
        );
      },
    );
  });
}

/// Puts [workItemId] at `implementationReady` by writing the row.
///
/// Same honesty note as the scheduler package's own fixtures: no production
/// route reaches the entry state yet (`OD-3` is open), so the only way to ask
/// the scheduler what it does with an item AT that state is to put one there.
/// The property under test is what happens AFTER the entry state, which is the
/// only part this file has anything to say about.
Future<void> _parkAtImplementationReady(
  WorkflowStore store,
  String workItemId,
) async {
  final current = await store.readWorkItem(workItemId);
  await store.saveWorkItem(
    current.copyWith(
      state: WorkItemState.implementationReady,
      version: current.version + 1,
      updatedAt: DateTime.utc(2026),
    ),
    expectedVersion: current.version,
  );
}

/// The two work items in the "one bad clone costs one job" test. Named so the
/// assertions below read as prose and so a failure names which side broke.
const badCloneItem = 'wi-broken-clone';
const goodCloneItem = 'wi-healthy-clone';

/// A [WorkerDispatch] that records every request it was asked about and selects
/// no worker.
///
/// No worker is registered, so a request is built and then refused at selection.
/// That ordering is the point: "the healthy job's request was BUILT" is
/// observable here, before any placement happens.
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
    requests.add(request);
    throw StateError('run() is not reachable: no worker is ever selected here');
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

/// A minimal job. Only its id is read by the resolver adapter.
Job _job() => Job(
  jobId: 'jb-impl-1',
  workItemId: 'wi-probe',
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {},
  priority: JobPriority.normal,
  state: JobState.queued,
  dedupeKey: 'wi-probe:implement_feature',
  createdAt: DateTime.utc(2026),
  instruction: 'implement it',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

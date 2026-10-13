import 'dart:io' show Directory, File, Platform, Process, ProcessResult;

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
        WorkspaceDescriptor;
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

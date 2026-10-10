// These tests drive the REAL composition in `baseline_runtime.dart` — the
// acquirer, the sweep, the lane, the runner adapter and the product-scoped
// dispatcher — over in-memory stores. `apps/server/test/**` belongs to a
// concurrent lane, so the tests are co-located here like every other test of
// this work item.
import 'package:control_plane_server/src/baseline/baseline_lane_runner.dart';
import 'package:control_plane_server/src/baseline/baseline_onboarding_sweep.dart';
import 'package:control_plane_server/src/baseline/baseline_runtime.dart';
import 'package:control_plane_server/src/credentials/repository_access_verifier.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart'
    show SecretProvider;
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:scheduler/scheduler.dart';

// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here rather than
// under `test/`.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

import 'baseline_test_fixtures.dart';

/// Everything one composition needs, and the answers it gave.
class _Harness {
  _Harness._(
    this.registry,
    this.runtime,
    this.jobStore,
    this.materializer,
    this.events,
  );

  /// Builds the production composition with its three documented seams
  /// substituted, so the wiring under test is the real one and only the
  /// substrate is not: no git host ([accessVerifier] and [materializer]) and no
  /// secret manager ([custodyProvider]).
  ///
  /// The composition receives ONE [jobStore], and the harness reads that same
  /// instance — a test that read a second store would be reading a different
  /// durable record from the one the composition wrote, and would pass against
  /// a composition that wrote nothing at all.
  factory _Harness.build(
    RegistryFixture registry,
    List<(String, Map<String, dynamic>)> events,
    void Function(String event, Map<String, dynamic> data) log, {
    RepositorySnapshotMaterializer? materializer,
    RecordingSecretProvider? secrets,
    RepositoryAccessVerifier? accessVerifier,
    SecretProvider? custodyProvider,
  }) {
    final scripted = ScriptedSnapshotMaterializer();
    final store = InMemoryJobStore();
    final runtime = BaselineProductionRuntime.resolve(
      engine: registry.engine,
      baselineStore: registry.store,
      jobStore: store,
      log: log,
      custodyProvider: custodyProvider ?? secrets ?? RecordingSecretProvider(),
      accessVerifier:
          accessVerifier ??
          ScriptedAccessVerifier(committedRevision: kTestRevision),
      materializer: materializer ?? scripted,
    );
    return _Harness._(registry, runtime, store, scripted, events);
  }

  final RegistryFixture registry;
  final BaselineProductionRuntime runtime;
  final InMemoryJobStore jobStore;

  final ScriptedSnapshotMaterializer materializer;

  /// `(event, data)` pairs, in order.
  final List<(String, Map<String, dynamic>)> events;

  List<String> eventNames() => events.map((e) => e.$1).toList();

  List<Map<String, dynamic>> withEvent(String name) =>
      events.where((e) => e.$1 == name).map((e) => e.$2).toList();

  Future<BaselineRuntimePassResult> pass() => runtime.runOnce();

  Future<Job?> job(String jobId) => jobStore.readJob(jobId);
}

void main() {
  late RegistryFixture registry;
  late _Harness harness;
  final events = <(String, Map<String, dynamic>)>[];

  setUp(() {
    registry = RegistryFixture();
    events.clear();
    harness = _Harness.build(
      registry,
      events,
      (event, data) => events.add((event, data)),
    );
  });

  /// A registered product with a repository, a deploy key and a host key a
  /// human confirmed out of band — every conjunct the sweep requires.
  Future<void> onboardableProduct(
    String productId, {
    String repositoryId = 'repo',
    String uri = 'git@remote.test:org/repository.git',
    bool confirmedHostKey = true,
  }) async {
    await registry.registerProduct(
      productId: productId,
      repositoryId: repositoryId,
      uri: uri,
    );
    await seedCredential(
      registry.engine,
      productId: productId,
      repositoryId: repositoryId,
      host: uri,
      confirmed: confirmedHostKey,
      // `recordCredentialCheck` refuses a check against a credential whose host
      // key nobody confirmed, so "not confirmed" necessarily means "not usable
      // either" — which is exactly the conjunction the sweep requires.
      usable: confirmedHostKey,
    );
  }

  group('the baseline worker is ACTUALLY INVOKED', () {
    test(
      'a dispatched onboardProduct job runs the lane and leaves a baseline '
      'awaiting human approval',
      () async {
        // THE CLAIM THIS FILE EXISTS TO PROVE. `JobType.onboardProduct` was
        // enqueued, stored, displayed and never run: no construction of the
        // lane anywhere in the server, no dispatcher, no sweep on the tick. An
        // assertion that the wiring "exists" would have passed against that
        // state. So this asserts on the DURABLE RESULT of a pass: a baseline
        // exists, it is independently verified, a human decision is pending and
        // unresolved, and the product moved to review.
        await onboardableProduct('product-a');

        final pass = await harness.pass();

        // The sweep decided to onboard it...
        expect(pass.sweep!.enqueued, hasLength(1));
        final jobId = pass.sweep!.enqueued.single.jobId;
        expect(pass.sweep!.skipped, isEmpty);

        // ...the dispatcher claimed and ran it...
        expect(pass.dispatch.dispatched, [jobId]);
        expect(pass.dispatch.awaitingApproval, [jobId]);
        expect(pass.dispatch.refused, isEmpty);
        expect(pass.dispatch.failed, isEmpty);

        // ...the lane really acquired and really derived.
        expect(
          harness.materializer.materializations,
          greaterThanOrEqualTo(2),
          reason:
              'the sweep resolves a pinned revision by acquiring once, and '
              'the lane acquires the pinned tree it derives from',
        );
        expect(
          harness.materializer.created.every((d) => !d.existsSync()),
          isTrue,
          reason: 'every acquired tree must be released, on every path',
        );

        // ...and the record shows a baseline and an open gate.
        final baselines = await registry.engine.readBaselines('product-a');
        expect(baselines, hasLength(1));
        final baseline = baselines.single;
        expect(baseline.status, ProductBaselineStatus.proposed);
        expect(
          baseline.isIndependentlyVerified,
          isTrue,
          reason:
              'the gate at baselineReview requires platform-verified evidence, '
              'not an agent claim about its own work',
        );
        expect(baseline.verificationKind?.wire, 'platform_verified_evidence');
        expect(baseline.facts, isNotEmpty);

        final product = await registry.engine.readProduct('product-a');
        expect(product.state.canonical, ProductState.baselineReview);

        final decisions = await registry.decisions.readHumanDecisionsForScope(
          BaselineApprovalBinding.scopeFor('product-a'),
        );
        expect(decisions, hasLength(1));
        final decision = decisions.single;
        expect(decision.status, HumanDecisionStatus.pending);
        expect(
          decision.status.isResolved,
          isFalse,
          reason: 'automation stops at "verified and awaiting approval"',
        );

        // ...and the job says it succeeded, for the reason it did.
        final job = await harness.job(jobId);
        expect(job!.state, JobState.succeeded);
        expect(job.jobType, JobType.onboardProduct);
        expect(
          job.maxAttempts,
          onboardProductDefinition.maxAttempts,
          reason:
              'the operator trigger and the sweep must write the SAME job shape; '
              'a narrower bound here would deny one of them the bounded retry',
        );
        expect(
          job.executionReference,
          isNull,
          reason:
              'the lane runs in this process; a synthetic worker execution id '
              'would leave a reference a reader could follow to nothing',
        );
      },
    );

    test('the decision carries no automation as its actor', () async {
      // §12: automation stops at *verified and awaiting approval*, and no
      // automation may satisfy `decisionActorIsHuman`. Asserted structurally:
      // the only decision on the scope is pending, and nothing this composition
      // produced resolved it.
      await onboardableProduct('product-a');
      await harness.pass();

      final decisions = await registry.decisions.readHumanDecisionsForScope(
        BaselineApprovalBinding.scopeFor('product-a'),
      );
      expect(decisions.every((d) => !d.status.isResolved), isTrue);
      expect(
        events.where(
          (e) =>
              e.$1 == 'baseline.dispatch.awaiting_approval' &&
              e.$2['decisionId'] == decisions.single.decisionId,
        ),
        hasLength(1),
      );
    });
  });

  group('idempotency and restart safety', () {
    test('a second pass enqueues nothing and runs nothing', () async {
      await onboardableProduct('product-a');
      await harness.pass();

      final second = await harness.pass();
      final third = await harness.pass();

      for (final pass in [second, third]) {
        expect(pass.sweep!.enqueued, isEmpty);
        expect(pass.dispatch.dispatched, isEmpty);
        // The product has left the sweep's state set entirely: it is now in
        // `baselineReview`, waiting on a human, and enqueueing behind that
        // human would be arguing with a gate. So the sweep does not even
        // consider it — which is a stronger statement than "considered and
        // declined", and the right one.
        expect(pass.sweep!.considered, 0);
        expect(pass.sweep!.skipped, isEmpty);
        expect(pass.sweep!.incidents, isEmpty);
      }

      final baselines = await registry.engine.readBaselines('product-a');
      expect(baselines, hasLength(1), reason: 'no revision spam');
      final decisions = await registry.decisions.readHumanDecisionsForScope(
        BaselineApprovalBinding.scopeFor('product-a'),
      );
      expect(decisions, hasLength(1), reason: 'one open gate, not several');
      expect(
        (await harness.jobStore.listJobs()).where(
          (j) => j.jobType == JobType.onboardProduct,
        ),
        hasLength(1),
        reason: 'no duplicate jobs',
      );
    });

    test(
      'a crash between the claim and the recorded outcome re-runs the lane and '
      'still leaves exactly one baseline and one gate',
      () async {
        // THE CRASH WINDOW. The dispatcher holds a lease, runs the lane, and
        // only then records the verdict. A process that dies between the two
        // leaves a `running` job whose outcome nobody wrote — and the next pass
        // requeues it and runs the lane again. The claim that this is safe is
        // that the lane is idempotent; this asserts the consequence rather than
        // the intent.
        await onboardableProduct('product-a');
        final enqueued = (await harness.pass()).sweep!.enqueued.single;
        final jobId = enqueued.jobId;

        // Simulate the crash: the job ran, and then nothing was recorded.
        final claimed = await harness.job(jobId);
        expect(claimed!.state, JobState.succeeded);
        final crashed = claimed.copyWith(
          state: JobState.running,
          completedAt: null,
          version: claimed.version + 1,
        );
        await harness.jobStore.saveJob(
          crashed,
          expectedVersion: claimed.version,
        );
        await harness.jobStore.deleteClaim(jobId);

        // Well past the lease, so the claim counts as expired.
        final recovered = BaselineProductDispatcher(
          jobStore: harness.jobStore,
          runner: harness.runtime.dispatcher.runner,
          clock: () => DateTime.now().toUtc().add(const Duration(hours: 2)),
          log: (event, data) => events.add((event, data)),
        );
        final result = await recovered.dispatch();

        expect(
          result.reconciled,
          [jobId],
          reason: 'the expired claim must be recovered, not left stuck',
        );
        expect(result.dispatched, [
          jobId,
        ], reason: 'and the lane must actually run again');

        final after = await harness.job(jobId);
        expect(after!.state, JobState.succeeded);
        expect(
          await registry.engine.readBaselines('product-a'),
          hasLength(1),
          reason: 're-running reuses the baseline; it does not supersede it',
        );
        expect(
          await registry.decisions.readHumanDecisionsForScope(
            BaselineApprovalBinding.scopeFor('product-a'),
          ),
          hasLength(1),
          reason:
              'the approval request is idempotent for the same revision '
              'and content hash',
        );
      },
    );

    test('an unexpired claim is left alone', () async {
      await onboardableProduct('product-a');
      final jobId = (await harness.pass()).sweep!.enqueued.single.jobId;
      final claimed = (await harness.job(jobId))!;
      await harness.jobStore.saveJob(
        claimed.copyWith(
          state: JobState.running,
          completedAt: null,
          version: claimed.version + 1,
        ),
        expectedVersion: claimed.version,
      );
      // A claim that is genuinely held. A `running` job with NO claim record
      // counts as recoverable — the same rule the triage scheduler applies — so
      // this test has to actually hold one to be testing what it says.
      await harness.jobStore.saveClaim(
        JobClaim(
          claimId: 'cl-held',
          jobId: jobId,
          ownerId: 'sched-baseline',
          leasedUntil: DateTime.now().toUtc().add(const Duration(minutes: 20)),
          createdAt: DateTime.now().toUtc(),
        ),
      );

      final pass = await harness.pass();
      expect(pass.dispatch.reconciled, isEmpty);
      expect(pass.dispatch.dispatched, isEmpty);
      expect((await harness.job(jobId))!.state, JobState.running);
    });
  });

  group('the external-dependency state', () {
    test(
      'a product with no independently-confirmed host key is never enqueued, '
      'and an operator-requested job stops at EXTERNAL_BASELINE_SOURCE_DEPENDENCY',
      () async {
        // THE §3.2 CASE. The deploy key's public-key fingerprint is NOT a host
        // key fingerprint. With no host key a human confirmed out of band there
        // is no value to enforce, and the sweep must not enqueue at all — so
        // the second half drives the job directly, which is the shape the
        // operator trigger produces.
        await onboardableProduct(
          'product-a',
          confirmedHostKey: false,
        );

        final swept = await harness.pass();
        expect(swept.sweep!.enqueued, isEmpty);
        expect(
          swept.sweep!.skipped.single.code,
          BaselineSweepSkipped.noUsableCredentialCode,
        );
        expect(swept.dispatch.dispatched, isEmpty);

        // An operator request is not gated on the sweep's predicate, so the job
        // exists and the dispatcher has to answer for it.
        await harness.jobStore.saveJob(
          onboardingJob(
            jobId: 'jb-operator-requested',
            productId: 'product-a',
            repositoryId: 'repo',
            startingRevision: kTestRevision,
            now: DateTime.utc(2026, 3, 1),
          ),
        );

        final dispatched = await harness.pass();
        expect(dispatched.dispatch.refused, ['jb-operator-requested']);

        final job = await harness.job('jb-operator-requested');
        expect(job!.state, JobState.failed);
        expect(
          job.failure!.reason,
          contains(BaselineSourceUnavailableException.terminalCode),
        );
        expect(
          job.failure!.reason,
          isNot(contains(kTestCredentialFingerprint)),
          reason:
              'a deploy key fingerprint is not a host key fingerprint, '
              'and neither belongs in a job record',
        );

        // NO GATE, and nothing that reads as a human having declined.
        expect(await registry.engine.readBaselines('product-a'), isEmpty);
        expect(
          await registry.decisions.readHumanDecisionsForScope(
            BaselineApprovalBinding.scopeFor('product-a'),
          ),
          isEmpty,
        );
        expect(
          (await registry.engine.readProduct('product-a')).state.canonical,
          ProductState.registered,
          reason: 'the product stays exactly where it was',
        );

        // Whichever of the two named refusals fired — "no credential at all"
        // or "the host key is not independently confirmed" — both terminate the
        // job at the same external-dependency code, and both must say
        // explicitly that nobody declined anything.
        final refusals = harness.events
            .where(
              (e) =>
                  e.$1 == 'baseline.dispatch.source_unavailable' ||
                  e.$1 == 'baseline.dispatch.host_key_not_confirmed',
            )
            .toList();
        expect(refusals, hasLength(1));
        expect(refusals.single.$2['operatorDeclined'], isFalse);
        expect(
          refusals.single.$2['code'],
          BaselineSourceUnavailableException.terminalCode,
        );
        expect(
          refusals.single.$2['reason'],
          contains('external dependency'),
          reason:
              'the reason an operator reads must name the missing fact, not a '
              'person who failed to act on it',
        );
      },
    );

    test(
      'a job that names HEAD rather than a commit is refused before acquisition',
      () async {
        // `HEAD` resolves rather than pins, and the sweep uses it to learn what
        // a remote is at before keying the job to the commit. A job that still
        // names HEAD would derive a baseline from a moving ref — and the
        // re-derivation that follows would be comparing against a different
        // tree, which is either permanent divergence or, worse, a match by
        // accident.
        // Registered but with no credential, so the sweep has nothing to
        // onboard: the ONLY job in this pass is the hand-made HEAD one, and
        // any baseline that appeared would have come from it.
        await registry.registerProduct(productId: 'product-a');
        await harness.jobStore.saveJob(
          onboardingJob(
            jobId: 'jb-head',
            productId: 'product-a',
            repositoryId: 'repo',
            startingRevision: kRepositoryHeadRef,
            now: DateTime.utc(2026, 3, 1),
          ),
        );

        final pass = await harness.pass();
        // The sweep's own resolution is exempt by design, so this asserts on
        // the DISPATCH of the hand-made job, not on materializer counts.
        final dispatched = pass.dispatch.refused.contains('jb-head');
        expect(dispatched, isTrue, reason: 'the job must not be run');
        final job = await harness.job('jb-head');
        expect(job!.state, JobState.failed);
        expect(job.failure!.reason, contains(onboardingTargetNotPinnedCode));
        expect(
          await registry.engine.readBaselines('product-a'),
          isEmpty,
          reason: 'nothing was derived from a moving source',
        );
      },
    );

    test(
      'the credential fingerprint is never offered as the host key fingerprint',
      () async {
        // Whatever else happens, the two values are never confused: the sweep's
        // resolver acquires against the CONFIRMED host key, and a scripted
        // verifier records what it was actually asked to enforce.
        await onboardableProduct('product-a');
        await harness.pass();
        expect(
          harness.materializer.demandedHostKeyFingerprints,
          everyElement(kTestHostKeyFingerprint),
        );
        expect(
          harness.materializer.demandedHostKeyFingerprints,
          isNot(contains(kTestCredentialFingerprint)),
        );
      },
    );
  });

  group('honest failure reporting', () {
    test(
      "one product's snapshot cleanup failure does not swallow another's "
      'onboarding',
      () async {
        // The reviewer's finding: `run()` had no per-product guard, so one
        // cleanup incident aborted the whole pass. The guard exists on both
        // halves now — the sweep, and the dispatcher's per-job loop — and this
        // drives a product whose acquirer refuses with the incident.
        await onboardableProduct('product-a');
        await onboardableProduct(
          'product-b',
          repositoryId: 'repo-b',
          uri: 'git@remote.test:org/other.git',
        );

        // Rebuild with a materializer that refuses for product-a only.
        final refusing = _RefusingOnlyMaterializer(
          delegate: ScriptedSnapshotMaterializer(),
          failFor: 'product-a',
          failure: const BaselineSnapshotCleanupException(
            'scratch-tree-this-process-could-not-remove',
          ),
        );
        final subject = _Harness.build(
          registry,
          events,
          (event, data) => events.add((event, data)),
          materializer: refusing,
        );

        final pass = await subject.pass();

        // product-a: an incident, on a record, not a quiet skip.
        final failed = pass.sweep!.incidents.where(
          (i) => i.productId == 'product-a',
        );
        expect(failed, hasLength(1));
        expect(
          failed.single.code,
          BaselineSweepIncidentCodes.snapshotCleanupFailed,
        );
        expect(
          pass.sweep!.skipped.where((s) => s.productId == 'product-a'),
          isEmpty,
          reason: 'an incident must not be laundered into a routine skip',
        );
        expect(
          pass.sweep!.accountedFor,
          pass.sweep!.considered,
          reason: 'every product the pass looked at is accounted for',
        );

        // product-b: onboarded anyway, in the same pass.
        final enqueuedForB = pass.sweep!.enqueued
            .where((e) => e.productId == 'product-b')
            .toList();
        expect(enqueuedForB, hasLength(1));
        expect(pass.dispatch.awaitingApproval, [enqueuedForB.single.jobId]);
        expect(
          await registry.engine.readBaselines('product-b'),
          hasLength(1),
          reason: 'one product failing must not cost another its onboarding',
        );
        expect(await registry.engine.readBaselines('product-a'), isEmpty);
      },
    );

    test(
      'an operator-requested job whose cleanup failed is an INCIDENT on the '
      'job, with the path an operator needs',
      () async {
        final refusing = _RefusingOnlyMaterializer(
          delegate: ScriptedSnapshotMaterializer(),
          failFor: 'product-a',
          failure: const BaselineSnapshotCleanupException(
            'scratch-tree-this-process-could-not-remove',
          ),
        );
        final subject = _Harness.build(
          registry,
          events,
          (event, data) => events.add((event, data)),
          materializer: refusing,
        );
        await onboardableProduct('product-a');
        await subject.jobStore.saveJob(
          onboardingJob(
            jobId: 'jb-leaked-tree',
            productId: 'product-a',
            repositoryId: 'repo',
            startingRevision: kTestRevision,
            now: DateTime.utc(2026, 3, 1),
          ),
        );

        await subject.pass();

        final job = await subject.job('jb-leaked-tree');
        expect(
          job!.state,
          JobState.failed,
          reason: 'an incident is a failure, never a succeeded job',
        );
        expect(job.failure!.reason, contains('SNAPSHOT_CLEANUP_FAILED'));
        expect(
          job.failure!.reason,
          contains('scratch-tree-this-process-could-not-remove'),
          reason:
              'an operator cannot remove a leaked tree they were not told '
              'the path of; the path carries no key material',
        );
        final incident = harness.withEvent(
          'baseline.dispatch.snapshot_cleanup_failed',
        );
        expect(incident.single['severity'], 'incident');
      },
    );

    test('a raised lane error is isolated per job and never retried', () async {
      // A raise carries no claim about whether the same call would succeed, so
      // guessing "retry, it is probably a blip" would turn every defect into two
      // attempts. The lane's own `transient` classification is the only thing
      // that authorises a retry, and the bound is the job's own `maxAttempts`.
      await onboardableProduct('product-a');
      final jobId = (await harness.pass()).sweep!.enqueued.single.jobId;
      final done = (await harness.job(jobId))!;

      await harness.jobStore.saveJob(
        done.copyWith(state: JobState.queued, version: done.version + 1),
        expectedVersion: done.version,
      );

      final raising = BaselineProductDispatcher(
        jobStore: harness.jobStore,
        runner: (_) async => throw StateError('the lane broke'),
        log: (event, data) => events.add((event, data)),
      );
      final result = await raising.dispatch();

      expect(result.dispatched, [jobId]);
      expect(result.failed, [jobId]);
      expect(result.retried, isEmpty);
      final job = await harness.job(jobId);
      expect(job!.state, JobState.failed);
      expect(
        job.attempt,
        done.attempt,
        reason: 'a permanent fault consumes no retry budget',
      );
      expect(job.failure!.kind, JobFailureKind.permanent);
      expect(
        job.failure!.reason,
        contains(BaselineProductDispatcher.laneThrewCode),
      );
    });

    test(
      'a transient fault retries once and then stops, within maxAttempts',
      () async {
        await onboardableProduct('product-a');
        final jobId = (await harness.pass()).sweep!.enqueued.single.jobId;
        final done = (await harness.job(jobId))!;

        var calls = 0;
        final transient = BaselineProductDispatcher(
          jobStore: harness.jobStore,
          runner: (_) async {
            calls++;
            return OnboardingFaulted(
              code: 'PINNED_REVISION_NOT_ACQUIRED',
              reason: 'the remote moved out from under the pin',
              transient: true,
            );
          },
          clock: () => DateTime.utc(2026, 4, 1),
          log: (event, data) => events.add((event, data)),
        );

        // Back to queued so the dispatcher's retry path is the one under test.
        await harness.jobStore.saveJob(
          done.copyWith(state: JobState.queued, version: done.version + 1),
          expectedVersion: done.version,
        );
        final first = await transient.dispatch();
        expect(first.retried, [jobId]);
        expect(
          (await harness.job(jobId))!.state,
          JobState.retryWaiting,
          reason: 'a transient fault backs off rather than terminating',
        );

        // The backoff window opens.
        await harness.jobStore.saveJob(
          (await harness.job(jobId))!.copyWith(availableAt: null),
        );
        final second = await transient.dispatch();
        expect(second.failed, [
          jobId,
        ], reason: 'maxAttempts is a hard bound, not a suggestion');
        expect((await harness.job(jobId))!.state, JobState.failed);
        expect(calls, 2);
      },
    );
  });

  group('the honest unavailable-runtime posture', () {
    test(
      'with no custody substrate the runtime says so and every job stops at '
      'EXTERNAL_BASELINE_CREDENTIAL_CUSTODY_DEPENDENCY',
      () async {
        // Constructed the way the server constructs it when the environment
        // names no substrate. The point is that it is a REFUSAL on a durable
        // record, not a null lane producing a TypeError from inside the loop,
        // and not a lane that appears to verify something.
        final store = InMemoryJobStore();
        final empty = RegistryFixture();
        final events = <(String, Map<String, dynamic>)>[];
        final runtime = BaselineProductionRuntime.resolve(
          engine: empty.engine,
          baselineStore: empty.store,
          jobStore: store,
          log: (event, data) => events.add((event, data)),
          custodyProvider: null,
        );

        // The environment this process would actually be in has no substrate
        // configured, which is the state under test; make the resolver say so.
        expect(
          runtime.isAvailable,
          isFalse,
          reason: 'the test process configures no custody substrate',
        );
        expect(
          runtime.custodyRuntimeState,
          baselineCredentialCustodyUnavailable,
        );
        expect(
          runtime.sweep,
          isNull,
          reason:
              'with no acquisition there is no pinned revision, and a '
              'sweep that could only ever skip would be the silent no-op',
        );
        expect(
          runtime.describe()['note'],
          contains(externalBaselineCredentialCustodyDependency),
        );

        await runtime.dispatcher.jobStore.saveJob(
          onboardingJob(
            jobId: 'jb-unavailable',
            productId: 'product-a',
            repositoryId: 'repo',
            startingRevision: kTestRevision,
            now: DateTime.utc(2026, 3, 1),
          ),
        );
        final pass = await runtime.runOnce();

        expect(pass.dispatch.refused, ['jb-unavailable']);
        final job = await runtime.dispatcher.jobStore.readJob(
          'jb-unavailable',
        );
        expect(job!.state, JobState.failed);
        expect(
          job.failure!.reason,
          contains(externalBaselineCredentialCustodyDependency),
        );
        expect(
          events
              .where((e) => e.$1 == 'baseline.runtime.unavailable')
              .expand((e) => e.$2.entries)
              .where((entry) => entry.key == 'operatorDeclined')
              .map((entry) => entry.value),
          everyElement(isFalse),
          reason:
              'unavailable means the runtime does not exist here — not that '
              'a human declined to run anything',
        );
        expect(await empty.engine.readBaselines('product-a'), isEmpty);
      },
    );

    test(
      'the unavailable code is not the per-product source-unavailable code',
      () async {
        // Collapsing them would let a deployment-wide misconfiguration present
        // as a per-product problem and send whoever is on call to the wrong
        // place: one is fixed by onboarding a product, the other by configuring
        // this process.
        expect(
          externalBaselineCredentialCustodyDependency,
          isNot(BaselineSourceUnavailableException.terminalCode),
        );
      },
    );
  });
}

/// A materializer that delegates, except for one product.
class _RefusingOnlyMaterializer implements RepositorySnapshotMaterializer {
  _RefusingOnlyMaterializer({
    required RepositorySnapshotMaterializer delegate,
    required this.failFor,
    required this.failure,
  }) : delegate = delegate as ScriptedSnapshotMaterializer;

  final ScriptedSnapshotMaterializer delegate;
  final String failFor;
  final Object failure;

  @override
  Future<RepositorySnapshot> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
  }) {
    if (productId == failFor) return Future<RepositorySnapshot>.error(failure);
    return delegate.materialize(
      productId: productId,
      repositoryId: repositoryId,
      remote: remote,
      privateKeyPem: privateKeyPem,
      confirmedHostKeyFingerprint: confirmedHostKeyFingerprint,
      pinnedRevision: pinnedRevision,
    );
  }
}

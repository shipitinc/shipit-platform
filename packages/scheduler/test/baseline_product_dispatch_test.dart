// Tests for the PRODUCT-SCOPED dispatcher that runs `JobType.onboardProduct`.
//
// Deliberately separate from the end-to-end lane tests under
// `apps/server/lib/src/baseline/`: this file is about the dispatcher's own
// durable mechanics — claim, lease, recovery, retry, and the refusal to touch
// anything that is not an onboarding job.
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

const String _product = 'product-a';
const String _repository = 'repo';
const String _revision = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

/// A clock the test drives, so "expired" is a fact rather than a wait.
class _Clock {
  DateTime now = DateTime.utc(2026, 6, 1);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

/// Every request the dispatcher made, in order.
class _RecordingRunner {
  _RecordingRunner([this.answers = const []]);

  final List<OnboardingLaneOutcome> answers;
  final List<OnboardingLaneRequest> requests = [];

  Future<OnboardingLaneOutcome> run(OnboardingLaneRequest request) async {
    requests.add(request);
    if (answers.isEmpty) return _awaiting();
    return answers.removeAt(0);
  }
}

OnboardingRefused _refused({
  String code = 'BASELINE_BLOCKED_ON_CLARIFICATION',
}) => OnboardingRefused(
  code: code,
  reason: 'the product is blocked on a question',
);

OnboardingAwaitingApproval _awaiting({String decisionId = 'd-1'}) =>
    OnboardingAwaitingApproval(
      baselineId: 'bl-1',
      revision: 1,
      sourceRevision: _revision,
      decisionId: decisionId,
      factCount: 3,
      alreadyVerified: false,
    );

OnboardingFaulted _faulted({required bool transient}) => OnboardingFaulted(
  code: 'SNAPSHOT_MATERIALIZATION_FAILED',
  reason: 'git refused',
  transient: transient,
);

Job _onboardingJob({
  String jobId = 'jb-1',
  String? dedupeKey,
  JobState state = JobState.queued,
  int attempt = 1,
  int? maxAttempts,
  int version = 1,
  DateTime? availableAt,
}) => Job(
  jobId: jobId,
  workItemId: onboardingWorkItemId(_product),
  jobType: JobType.onboardProduct,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {WorkerCapability.linux, WorkerCapability.git},
  priority: JobPriority.high,
  state: state,
  dedupeKey:
      dedupeKey ??
      onboardingDedupeKey(
        productId: _product,
        repositoryId: _repository,
        startingRevision: _revision,
      ),
  availableAt: availableAt,
  createdAt: DateTime.utc(2026, 6, 1),
  instruction: 'onboard',
  attempt: attempt,
  maxAttempts: maxAttempts ?? onboardProductDefinition.maxAttempts,
  version: version,
);

void main() {
  late InMemoryJobStore store;
  late _Clock clock;
  late _RecordingRunner runner;
  late BaselineProductDispatcher dispatcher;

  setUp(() {
    store = InMemoryJobStore();
    clock = _Clock();
    runner = _RecordingRunner();
    dispatcher = BaselineProductDispatcher(
      jobStore: store,
      runner: runner.run,
      clock: clock.call,
      claimLease: const Duration(minutes: 30),
      log: (_, _) {},
    );
  });

  group('the target is recovered from the durable record, not guessed', () {
    test('a well-formed key round-trips to the same three components', () {
      final key = onboardingDedupeKey(
        productId: _product,
        repositoryId: _repository,
        startingRevision: _revision,
      );
      final target = tryDecodeOnboardingDedupeKey(key);
      expect(target, isNotNull);
      expect(target!.productId, _product);
      expect(target.repositoryId, _repository);
      expect(target.pinnedRevision, _revision);
      expect(target.workItemId, onboardingWorkItemId(_product));
    });

    test('a key that does not decode is refused, never repaired', () {
      // Guessing which field an extra colon belongs to would clone the wrong
      // repository, or the wrong revision of the right one, and produce a
      // baseline whose facts do not correspond to the job claiming to have
      // produced them.
      for (final key in <String>[
        'onboarding:',
        'onboarding:product-a',
        'onboarding:product-a:repo',
        'onboarding:product-a:repo:rev:extra',
        'onboarding::repo:rev',
        'onboarding:product-a::rev',
        'onboarding:product-a:repo:',
        'triageDefect:product-a:repo:rev',
      ]) {
        expect(
          tryDecodeOnboardingDedupeKey(key),
          isNull,
          reason: '"$key" is not decodable and must not be repaired',
        );
      }
    });

    test('an undecodable target terminates the job loudly', () async {
      await store.saveJob(
        _onboardingJob(dedupeKey: 'onboarding:product-a:repo'),
      );
      final result = await dispatcher.dispatch();

      expect(result.dispatched, ['jb-1']);
      expect(result.failed, ['jb-1']);
      expect(runner.requests, isEmpty, reason: 'nothing may be acquired');
      final job = await store.readJob('jb-1');
      expect(job!.state, JobState.failed);
      expect(
        job.failure!.reason,
        contains(BaselineProductDispatcher.undecodableTargetCode),
      );
    });

    test(
      'a record that disagrees with its own key about the product is refused',
      () async {
        // Acting on either half would either derive a baseline for the wrong
        // product or skip a job that was enqueued for a real one.
        final misfiled = Job(
          jobId: 'jb-1',
          workItemId: onboardingWorkItemId('product-b'),
          jobType: JobType.onboardProduct,
          requiredRole: AgentRole.implementer,
          requiredCapabilities: const {WorkerCapability.linux},
          priority: JobPriority.high,
          state: JobState.queued,
          dedupeKey: onboardingDedupeKey(
            productId: _product,
            repositoryId: _repository,
            startingRevision: _revision,
          ),
          createdAt: DateTime.utc(2026, 6, 1),
          instruction: 'onboard',
          attempt: 1,
          maxAttempts: 2,
          version: 1,
        );
        await store.saveJob(misfiled);

        final result = await dispatcher.dispatch();
        expect(result.failed, ['jb-1']);
        expect(runner.requests, isEmpty);
        expect(
          (await store.readJob('jb-1'))!.failure!.reason,
          contains('ONBOARDING_TARGET_MISMATCH'),
        );
      },
    );
  });

  group('the dispatcher claims onboarding jobs and nothing else', () {
    test('it runs the lane with the target the key names', () async {
      await store.saveJob(_onboardingJob());
      await dispatcher.dispatch();

      expect(runner.requests, hasLength(1));
      final request = runner.requests.single;
      expect(request.productId, _product);
      expect(request.repositoryId, _repository);
      expect(request.pinnedRevision, _revision);
      expect(request.jobId, 'jb-1');
      expect(request.attempt, 1);
    });

    test('a triageDefect job is NEVER claimed', () async {
      // B1, made mechanical. The WorkItem-scoped `Scheduler` owns defect
      // triage; this dispatcher is product-scoped onboarding. If onboarding
      // could claim a triage job, the two paths would race for the same
      // durable record and one of them would drive a lane the other never
      // intended to run.
      await store.saveJob(
        Job(
          jobId: 'jb-triage',
          workItemId: 'work-item-1',
          jobType: JobType.triageDefect,
          requiredRole: AgentRole.triageDefect,
          requiredCapabilities: const {WorkerCapability.linux},
          priority: JobPriority.high,
          state: JobState.queued,
          dedupeKey: 'work-item-1:designRequired:triage',
          createdAt: DateTime.utc(2026, 6, 1),
          instruction: 'triage',
          attempt: 1,
          maxAttempts: 2,
          version: 1,
        ),
      );
      await store.saveJob(_onboardingJob());

      final result = await dispatcher.dispatch();

      expect(result.dispatched, ['jb-1']);
      expect(
        runner.requests.map((r) => r.jobId),
        ['jb-1'],
        reason: 'no triage job may be claimed by a product-scoped dispatcher',
      );
      expect((await store.readJob('jb-triage'))!.state, JobState.queued);
      expect(await store.readClaimForJob('jb-triage'), isNull);
    });

    test('the dispatcher reads its job type from the definition', () {
      expect(BaselineProductDispatcher.jobType, JobType.onboardProduct);
      expect(
        BaselineProductDispatcher.jobType,
        onboardProductDefinition.jobType,
      );
    });
  });

  group('outcomes are recorded on the job, and each one distinctly', () {
    test('awaiting approval succeeds the job', () async {
      await store.saveJob(_onboardingJob());
      final result = await dispatcher.dispatch();

      expect(result.awaitingApproval, ['jb-1']);
      expect(result.refused, isEmpty);
      final job = await store.readJob('jb-1');
      expect(job!.state, JobState.succeeded);
      expect(job.completedAt, isNotNull);
      expect(job.failure, isNull);
    });

    test('a refusal TERMINATES as failed, never as succeeded', () async {
      // `getOnboardingStatus` reads `state == succeeded` to decide that an
      // onboarding ran. A refusal recorded as succeeded would tell an
      // operator a product has a baseline it does not have.
      await store.saveJob(_onboardingJob());
      runner = _RecordingRunner([_refused()]);
      dispatcher = BaselineProductDispatcher(
        jobStore: store,
        runner: runner.run,
        clock: clock.call,
        log: (_, _) {},
      );
      final result = await dispatcher.dispatch();

      expect(result.refused, ['jb-1']);
      final job = await store.readJob('jb-1');
      expect(job!.state, JobState.failed);
      expect(
        job.failure!.reason,
        contains('BASELINE_BLOCKED_ON_CLARIFICATION'),
      );
      expect(job.failure!.kind, JobFailureKind.permanent);
    });

    test('a permanent fault terminates and consumes no retry', () async {
      await store.saveJob(_onboardingJob());
      runner = _RecordingRunner([_faulted(transient: false)]);
      dispatcher = BaselineProductDispatcher(
        jobStore: store,
        runner: runner.run,
        clock: clock.call,
        log: (_, _) {},
      );

      final result = await dispatcher.dispatch();
      expect(result.failed, ['jb-1']);
      expect(result.retried, isEmpty);
      final job = await store.readJob('jb-1');
      expect(job!.state, JobState.failed);
      expect(job.attempt, 1);
    });

    test('a transient fault backs off, then stops at maxAttempts', () async {
      await store.saveJob(_onboardingJob());
      runner = _RecordingRunner([
        _faulted(transient: true),
        _faulted(transient: true),
      ]);
      dispatcher = BaselineProductDispatcher(
        jobStore: store,
        runner: runner.run,
        clock: clock.call,
        retryDelay: const Duration(minutes: 5),
        log: (_, _) {},
      );

      final first = await dispatcher.dispatch();
      expect(first.retried, ['jb-1']);
      expect((await store.readJob('jb-1'))!.state, JobState.retryWaiting);
      expect((await store.readJob('jb-1'))!.attempt, 2);

      // Inside the backoff window the job is not eligible at all.
      expect((await dispatcher.dispatch()).deferred, isEmpty);
      expect(runner.requests, hasLength(1));

      clock.advance(const Duration(minutes: 6));
      final second = await dispatcher.dispatch();
      expect(second.failed, ['jb-1']);
      expect((await store.readJob('jb-1'))!.state, JobState.failed);
      expect(runner.requests, hasLength(2));
    });

    test('a raised lane error is a permanent fault, not a crash', () async {
      // An exception carries no claim about whether the same call would
      // succeed. Guessing "retry, it is probably a blip" would turn every
      // defect into two attempts and every blip into a terminal failure.
      await store.saveJob(_onboardingJob());
      final raising = BaselineProductDispatcher(
        jobStore: store,
        runner: (_) async => throw StateError('the lane broke'),
        clock: clock.call,
        log: (_, _) {},
      );

      final result = await raising.dispatch();
      expect(result.failed, ['jb-1']);
      final job = await store.readJob('jb-1');
      expect(job!.state, JobState.failed);
      expect(
        job.failure!.reason,
        contains(BaselineProductDispatcher.laneThrewCode),
      );
      expect(job.failure!.kind, JobFailureKind.permanent);
    });

    test(
      'a raised store compare-and-swap loss is transient, not permanent',
      () async {
        // A CAS loss DOES carry a claim about whether the same call would
        // succeed: another writer already advanced the row, so the lane's
        // attempt raced rather than failed. That is the F-241 shape the
        // agent lanes settle through `storeContentionMarker`, and the
        // baseline lane classifies it the same way — retried within the
        // attempt bound, never terminal on a race it lost correctly.
        await store.saveJob(_onboardingJob());
        final raising = BaselineProductDispatcher(
          jobStore: store,
          runner: (_) async => throw ConcurrentJobModificationException(
            jobId: 'jb-1',
            expectedVersion: 2,
            actualVersion: 3,
          ),
          clock: clock.call,
          log: (_, _) {},
        );

        final result = await raising.dispatch();
        expect(result.retried, ['jb-1']);
        final job = await store.readJob('jb-1');
        expect(job!.state, JobState.retryWaiting);
        expect(job.failure!.kind, JobFailureKind.transient);
      },
    );
  });

  group('the durable record never names a worker execution', () {
    test('a dispatched job holds no execution reference', () async {
      // There is no worker and no worker execution behind an onboarding job, so
      // a synthetic id would leave a reference a reader could follow to
      // nothing — which `Scheduler._executionReference` already calls a dangling
      // link and refuses to persist.
      await store.saveJob(_onboardingJob());
      await dispatcher.dispatch();

      final job = await store.readJob('jb-1');
      expect(job!.executionReference, isNull);
      expect(job.workerId, isNull);
      expect(
        (await store.readEvents('jb-1'))
            .where((e) => e.type == SchedulerEventType.jobDispatched)
            .single
            .payload?['note'],
        contains('no worker execution'),
      );
    });
  });

  group('restart safety', () {
    test('an expired claim is recovered and the job re-runs', () async {
      await store.saveJob(_onboardingJob(state: JobState.running, version: 2));
      await store.saveClaim(
        JobClaim(
          claimId: 'cl-1',
          jobId: 'jb-1',
          ownerId: 'sched-baseline',
          leasedUntil: clock.call().subtract(const Duration(minutes: 1)),
          createdAt: clock.call().subtract(const Duration(hours: 1)),
        ),
      );

      final result = await dispatcher.dispatch();
      expect(result.reconciled, ['jb-1']);
      expect(result.dispatched, ['jb-1']);
      expect((await store.readJob('jb-1'))!.state, JobState.succeeded);
    });

    test('a MISSING claim record is recovered too', () async {
      // The same rule the triage scheduler applies: a job held in `running`
      // with no lease behind it is a process that died before it could write
      // one, and treating it as live would strand the job for ever.
      await store.saveJob(_onboardingJob(state: JobState.running, version: 2));
      expect(await store.readClaimForJob('jb-1'), isNull);

      expect((await dispatcher.dispatch()).reconciled, ['jb-1']);
    });

    test('a claim inside its lease is left alone', () async {
      await store.saveJob(_onboardingJob(state: JobState.claimed, version: 2));
      await store.saveClaim(
        JobClaim(
          claimId: 'cl-1',
          jobId: 'jb-1',
          ownerId: 'sched-baseline',
          leasedUntil: clock.call().add(const Duration(minutes: 10)),
          createdAt: clock.call(),
        ),
      );

      final result = await dispatcher.dispatch();
      expect(result.reconciled, isEmpty);
      expect(result.dispatched, isEmpty);
      expect((await store.readJob('jb-1'))!.state, JobState.claimed);
    });

    test('a terminal job is never dispatched again', () async {
      await store.saveJob(_onboardingJob(state: JobState.failed, version: 3));
      final result = await dispatcher.dispatch();
      expect(result.dispatched, isEmpty);
      expect(runner.requests, isEmpty);
    });
  });

  group('one product never swallows another', () {
    test('a job whose bookkeeping throws does not abort the pass', () async {
      // The jobs already dispatched in this pass have their outcomes
      // recorded; a reader told only "the pass failed" would have to guess how
      // far it got.
      await store.saveJob(_onboardingJob(jobId: 'jb-a'));
      await store.saveJob(_onboardingJob(jobId: 'jb-b'));

      final logged = <String>[];
      final isolating = BaselineProductDispatcher(
        jobStore: _UnreadableJobStore(delegate: store, failFor: 'jb-a'),
        runner: runner.run,
        clock: clock.call,
        log: (event, _) => logged.add(event),
      );

      final result = await isolating.dispatch();

      // The other product is unaffected: its job ran to a verdict.
      expect(result.dispatched, ['jb-b']);
      expect(runner.requests.map((r) => r.jobId), ['jb-b']);
      expect((await store.readJob('jb-b'))!.state, JobState.succeeded);

      // And the one that could not be read is reported, not swallowed and not
      // counted as work that happened.
      expect(result.deferred, ['jb-a']);
      expect(logged, contains('baseline.dispatch.pass_job_failed'));
    });

    test('every eligible job gets at most one attempt per pass', () async {
      await store.saveJob(_onboardingJob(jobId: 'jb-a'));
      await store.saveJob(_onboardingJob(jobId: 'jb-b'));
      final result = await dispatcher.dispatch();
      expect(result.dispatched, ['jb-a', 'jb-b']);
      expect(runner.requests.map((r) => r.jobId), ['jb-a', 'jb-b']);
    });
  });
}

/// A store that cannot read ONE job, to drive the dispatcher's per-job
/// isolation rather than the lane's own error handling.
///
/// Scoped to a single job on purpose: a store that is entirely down is a
/// different failure, and it should fail the PASS rather than be quietly
/// reduced to zero work done.
class _UnreadableJobStore implements JobStore {
  _UnreadableJobStore({required this.delegate, required this.failFor});

  final JobStore delegate;
  final String failFor;

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) =>
      delegate.saveJob(job, expectedVersion: expectedVersion);

  @override
  Future<Job?> readJob(String jobId) {
    if (jobId == failFor) return Future<Job?>.error(StateError('cannot read'));
    return delegate.readJob(jobId);
  }

  @override
  Future<List<Job>> listJobs() => delegate.listJobs();

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) =>
      delegate.listJobsForWorkItem(workItemId);

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) =>
      delegate.findLatestByDedupeKey(dedupeKey);

  @override
  Future<void> saveClaim(JobClaim claim) => delegate.saveClaim(claim);

  @override
  Future<JobClaim?> readClaimForJob(String jobId) =>
      delegate.readClaimForJob(jobId);

  @override
  Future<List<JobClaim>> listClaims() => delegate.listClaims();

  @override
  Future<void> deleteClaim(String jobId) => delegate.deleteClaim(jobId);

  @override
  Future<void> appendEvent(SchedulerEventRecord event) =>
      delegate.appendEvent(event);

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) =>
      delegate.readEvents(jobId);

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) =>
      delegate.inTransaction(body);
}

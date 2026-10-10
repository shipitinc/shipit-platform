// These tests exercise `lib/src/triage/lane_i_tick_hook.dart` from under
// `baseline/`, because `apps/server/test/**` belongs to a concurrent lane and
// this change may not write there. The mismatch is recorded here rather than
// worked around by writing outside the owned path.
import 'package:control_plane_server/src/triage/lane_i_tick_hook.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

SchedulerTickResult _tick(List<String> ids) => SchedulerTickResult(
  dispatched: ids,
  terminal: const [],
  reconciled: const [],
  cancelledQueued: const [],
  deferred: const [],
  enqueued: const [],
);

Job _job({
  required String jobId,
  required JobType jobType,
  JobState state = JobState.succeeded,
}) => Job(
  jobId: jobId,
  workItemId: 'onboarding-product-a',
  jobType: jobType,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {WorkerCapability.git},
  priority: JobPriority.high,
  state: state,
  dedupeKey: 'k-$jobId',
  createdAt: DateTime.utc(2026, 1, 1),
  instruction: 'do the thing',
  attempt: 1,
  maxAttempts: 1,
  version: 1,
);

/// Job ids the triage handler saw. Stand-in for a real `TriageProcessor`, which
/// needs a `PersistenceDatabase`, a workflow engine and an execution
/// coordinator — none of which exist without a database, and none of which is
/// what this file is about.
final List<String> triageSeen = <String>[];

Future<void> _triageHandler(Job job) async => triageSeen.add(job.jobId);

Map<JobType, TickJobHandler> triageTable() => {
  JobType.triageDefect: _triageHandler,
};

void main() {
  late InMemoryJobStore jobStore;

  setUp(() {
    jobStore = InMemoryJobStore();
    triageSeen.clear();
  });

  group('tick hook dispatch', () {
    test(
      'N-9: an unregistered job type THROWS instead of being skipped',
      () async {
        // THE N-9 CASE. A job type with no handler is the ABSENCE of a decision,
        // not a decision to skip — and `JobType.onboardProduct` sitting `queued`
        // for ever is what that absence cost.
        await jobStore.saveJob(
          _job(jobId: 'jb-1', jobType: JobType.onboardProduct),
        );

        expect(
          () => drainTriageOutcomesFromTick(
            tickResult: _tick(['jb-1']),
            jobStore: jobStore,
            handlers: triageTable(),
            logger: (_, _) {},
          ),
          throwsA(
            isA<UnhandledJobTypeException>()
                .having((e) => e.jobType, 'jobType', JobType.onboardProduct)
                .having((e) => e.jobId, 'jobId', 'jb-1')
                .having(
                  (e) => e.toString(),
                  'message',
                  contains('configuration error, not a no-op'),
                ),
          ),
        );
      },
    );

    test(
      'a registered handler is REACHED for a type the old filter dropped',
      () async {
        // The positive half: onboarding jobs are no longer invisible.
        await jobStore.saveJob(
          _job(jobId: 'jb-1', jobType: JobType.onboardProduct),
        );
        final handled = <String>[];

        final result = await drainTriageOutcomesFromTick(
          tickResult: _tick(['jb-1']),
          jobStore: jobStore,
          handlers: {
            ...triageTable(),
            JobType.onboardProduct: (job) async => handled.add(job.jobId),
          },
          logger: (_, _) {},
        );

        expect(handled, ['jb-1']);
        expect(result.considered, 1);
        expect(result.skipped, 0);
        expect(result.handedOff, 1);
        expect(result.succeededJobIds, ['jb-1']);
      },
    );

    test('two handlers can coexist in one table', () async {
      // A caller opting a new type IN must not have to choose between it and the
      // one triage already had. Adding a handler is additive.
      await jobStore.saveJob(
        _job(jobId: 'jb-t', jobType: JobType.triageDefect),
      );
      await jobStore.saveJob(
        _job(jobId: 'jb-1', jobType: JobType.onboardProduct),
      );

      final result = await drainTriageOutcomesFromTick(
        tickResult: _tick(['jb-t', 'jb-1']),
        jobStore: jobStore,
        handlers: {
          ...triageTable(),
          JobType.onboardProduct: (_) async {},
        },
        logger: (_, _) {},
      );

      expect(result.handedOff, 2);
      expect(triageSeen, ['jb-t']);
    });

    test(
      'a non-terminal job is still skipped, before its handler runs',
      () async {
        await jobStore.saveJob(
          _job(
            jobId: 'jb-1',
            jobType: JobType.onboardProduct,
            state: JobState.queued,
          ),
        );
        final handled = <String>[];

        final result = await drainTriageOutcomesFromTick(
          tickResult: _tick(['jb-1']),
          jobStore: jobStore,
          handlers: {
            ...triageTable(),
            JobType.onboardProduct: (job) async => handled.add(job.jobId),
          },
          logger: (_, _) {},
        );

        expect(handled, isEmpty);
        expect(result.skipped, 1);
        expect(result.handedOff, 0);
      },
    );

    test('an unreadable job id is skipped, not thrown', () async {
      final result = await drainTriageOutcomesFromTick(
        tickResult: _tick(['jb-missing']),
        jobStore: jobStore,
        handlers: triageTable(),
        logger: (_, _) {},
      );
      expect(result.considered, 1);
      expect(result.skipped, 1);
      expect(result.handedOff, 0);
    });

    test('a handler that throws is isolated and logged, not propagated', () async {
      // The per-job isolation the file has always had, and it must survive the
      // move to a dispatch table: one handler failing must not drop every other
      // job the tick touched.
      await jobStore.saveJob(
        _job(jobId: 'jb-1', jobType: JobType.onboardProduct),
      );
      await jobStore.saveJob(
        _job(jobId: 'jb-t', jobType: JobType.triageDefect),
      );
      final logged = <String>[];

      final result = await drainTriageOutcomesFromTick(
        tickResult: _tick(['jb-1', 'jb-t']),
        jobStore: jobStore,
        handlers: {
          ...triageTable(),
          JobType.onboardProduct: (_) async => throw StateError('boom'),
        },
        logger: (event, _) => logged.add(event),
      );

      expect(result.considered, 2);
      expect(result.handedOff, 2);
      expect(result.failedJobIds, ['jb-1']);
      expect(result.succeededJobIds, ['jb-t']);
      expect(triageSeen, ['jb-t']);
      expect(logged, ['triage.tick.job_failed']);
    });

    test('the accounting identity holds for the mixed batch', () async {
      await jobStore.saveJob(
        _job(jobId: 'jb-t', jobType: JobType.triageDefect),
      );
      await jobStore.saveJob(
        _job(
          jobId: 'jb-queued',
          jobType: JobType.onboardProduct,
          state: JobState.queued,
        ),
      );
      await jobStore.saveJob(
        _job(jobId: 'jb-2', jobType: JobType.onboardProduct),
      );

      final result = await drainTriageOutcomesFromTick(
        tickResult: _tick(['jb-t', 'jb-queued', 'jb-2', 'jb-gone']),
        jobStore: jobStore,
        handlers: {
          ...triageTable(),
          JobType.onboardProduct: (_) async {},
        },
        logger: (_, _) {},
      );

      expect(result.considered, 4);
      expect(result.skipped + result.handedOff, result.considered);
      expect(result.skipped, 2);
      expect(result.handedOff, 2);
    });
  });
}

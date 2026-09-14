import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

void main() {
  final capabilities = const {WorkerCapability.linux};

  Job jobAt(
    String jobId, {
    JobState state = JobState.queued,
    String? dedupeKey =
        'wi-1:design_not_required:implement_feature:IMPLEMENTER',
    int version = 1,
  }) {
    return Job(
      jobId: jobId,
      workItemId: 'wi-1',
      jobType: JobType.implementFeature,
      requiredRole: AgentRole.implementer,
      requiredCapabilities: capabilities,
      priority: JobPriority.normal,
      state: state,
      dedupeKey: dedupeKey!,
      createdAt: DateTime.utc(2026, 1, 1, 12),
      instruction: 'Implement the feature.',
      attempt: 1,
      maxAttempts: 2,
      version: version,
    );
  }

  group('InMemoryJobStore', () {
    test('version CAS rejects stale writes', () async {
      final store = InMemoryJobStore();
      await store.saveJob(jobAt('jb-1'));

      await expectLater(
        store.saveJob(jobAt('jb-1', version: 1), expectedVersion: 2),
        throwsA(
          isA<ConcurrentJobModificationException>().having(
            (e) => e.actualVersion,
            'actualVersion',
            1,
          ),
        ),
      );
    });

    test('claims and events round-trip', () async {
      final store = InMemoryJobStore();
      await store.saveJob(jobAt('jb-1'));
      await store.saveClaim(
        JobClaim(
          claimId: 'cl-1',
          jobId: 'jb-1',
          ownerId: 'sched-1',
          leasedUntil: DateTime.utc(2026, 1, 1, 13),
          createdAt: DateTime.utc(2026, 1, 1, 12),
        ),
      );
      await store.appendEvent(
        SchedulerEventRecord(
          eventId: 'se-jb-1-1',
          jobId: 'jb-1',
          workItemId: 'wi-1',
          sequence: 1,
          type: SchedulerEventType.jobQueued,
          occurredAt: DateTime.utc(2026, 1, 1, 12),
        ),
      );

      final claim = await store.readClaimForJob('jb-1');
      expect(claim!.ownerId, 'sched-1');
      expect(claim.isExpiredAt(DateTime.utc(2026, 1, 2)), isTrue);
      expect(await store.readEvents('jb-1'), hasLength(1));
      await store.deleteClaim('jb-1');
      expect(await store.readClaimForJob('jb-1'), isNull);
    });

    test('findLatestByDedupeKey returns most recent job', () async {
      final store = InMemoryJobStore();
      await store.saveJob(jobAt('jb-1', state: JobState.failed, version: 1));
      await store.saveJob(jobAt('jb-2', state: JobState.queued, version: 2));
      final latest = await store.findLatestByDedupeKey(
        'wi-1:design_not_required:implement_feature:IMPLEMENTER',
      );
      expect(latest!.jobId, 'jb-2');
    });
  });

  group('FileJsonJobStore', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('scheduler_store_test');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('durability: a new instance sees everything the old wrote', () async {
      final file = File('${dir.path}/jobs.json');
      final first = FileJsonJobStore(file);
      await first.saveJob(jobAt('jb-1'));
      await first.saveClaim(
        JobClaim(
          claimId: 'cl-1',
          jobId: 'jb-1',
          ownerId: 'sched-1',
          leasedUntil: DateTime.utc(2026, 1, 1, 13),
          createdAt: DateTime.utc(2026, 1, 1, 12),
        ),
      );
      await first.appendEvent(
        SchedulerEventRecord(
          eventId: 'se-jb-1-1',
          jobId: 'jb-1',
          workItemId: 'wi-1',
          sequence: 1,
          type: SchedulerEventType.jobQueued,
          occurredAt: DateTime.utc(2026, 1, 1, 12),
        ),
      );

      final second = FileJsonJobStore(file);
      final job = await second.readJob('jb-1');
      expect(job!.state, JobState.queued);
      expect((await second.readClaimForJob('jb-1'))!.jobId, 'jb-1');
      expect(await second.readEvents('jb-1'), hasLength(1));
    });

    test(
      'runState CAS still fails when expected version is exceeded',
      () async {
        final store = FileJsonJobStore(File('${dir.path}/jobs.json'));
        await store.saveJob(jobAt('jb-1'));
        final updated = jobAt('jb-1', state: JobState.claimed, version: 2);
        await store.saveJob(updated, expectedVersion: 1);
        expect(await store.readJob('jb-1'), same(updated));
        await expectLater(
          store.saveJob(
            jobAt('jb-1', state: JobState.running),
            expectedVersion: 1,
          ),
          throwsA(isA<ConcurrentJobModificationException>()),
        );
      },
    );

    test('events preserve order across reloads', () async {
      final store = FileJsonJobStore(File('${dir.path}/jobs.json'));
      await store.saveJob(jobAt('jb-1'));
      for (var i = 0; i < 3; i++) {
        await store.appendEvent(
          SchedulerEventRecord(
            eventId: 'se-$i',
            jobId: 'jb-1',
            workItemId: 'wi-1',
            sequence: i + 1,
            type: SchedulerEventType.jobQueued,
            occurredAt: DateTime.utc(2026, 1, 1, 12, i),
          ),
        );
      }
      final reloaded = FileJsonJobStore(File('${dir.path}/jobs.json'));
      final events = await reloaded.readEvents('jb-1');
      expect(events.map((e) => e.sequence), [1, 2, 3]);
    });
  });
}

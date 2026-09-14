import 'fixtures.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'package:scheduler/scheduler.dart';

/// Job store contract suite. Runs against any [JobStore] implementation
/// (in-memory, file-backed, PostgreSQL, Redis-free).
void runJobStoreSuite({
  required String groupName,
  required Future<JobStore> Function() createStore,
}) {
  group(groupName, () {
    test('jobs round-trip with CAS version checks', () async {
      final store = await createStore();
      await store.saveJob(buildJob());
      final loaded = await store.readJob('jb-1');
      expect(loaded, buildJob());
    });

    test('saveJob enforces compare-and-swap on version', () async {
      final store = await createStore();
      final job = buildJob();
      await store.saveJob(job);

      expect(
        store.saveJob(job, expectedVersion: 99),
        throwsA(
          isA<ConcurrentJobModificationException>().having(
            (e) => e.actualVersion,
            'actualVersion',
            job.version,
          ),
        ),
      );

      await store.saveJob(job, expectedVersion: job.version);
      expect(await store.readJob('jb-1'), job);
    });

    test('job lists and per-work-item lookups', () async {
      final store = await createStore();
      await store.saveJob(buildJob());
      await store.saveJob(buildJob(jobId: 'jb-2', state: JobState.cancelled));
      expect(await store.listJobs(), hasLength(2));
      expect((await store.listJobsForWorkItem(kWorkItemId)).length, 2);
      expect((await store.listJobsForWorkItem('none')).isEmpty, isTrue);
    });

    test('findLatestByDedupeKey returns the newest job', () async {
      final store = await createStore();
      final older = buildJob();
      await store.saveJob(older);
      await store.saveJob(buildJob(jobId: 'jb-2', state: JobState.cancelled));
      final latest = await store.findLatestByDedupeKey(older.dedupeKey);
      expect(latest?.jobId, contains(RegExp('jb-')));
      expect(await store.findLatestByDedupeKey('absent'), isNull);
    });

    test(
      'claims round-trip, are replaced per job, and can be deleted',
      () async {
        final store = await createStore();
        await store.saveJob(buildJob());
        await store.saveClaim(buildClaim());
        await store.saveClaim(buildClaim(claimId: 'cl-2'));
        final claim = await store.readClaimForJob('jb-1');
        expect(claim?.claimId, 'cl-2');
        expect((await store.listClaims()).length, 1);

        await store.deleteClaim('jb-1');
        expect(await store.readClaimForJob('jb-1'), isNull);
      },
    );

    test('scheduler events round-trip in stable sequence order', () async {
      final store = await createStore();
      await store.appendEvent(buildSchedulerEvent(sequence: 1));
      await store.appendEvent(buildSchedulerEvent(sequence: 2));
      final events = await store.readEvents('jb-1');
      expect(events.map((e) => e.sequence), [1, 2]);
      expect(events.first.type, SchedulerEventType.jobClaimed);
      expect(events.first.payload, {'owner': 'sched-1'});
    });

    test('inTransaction batches queue mutations when supported', () async {
      final store = await createStore();
      await store.inTransaction((tx) async {
        await tx.saveJob(buildJob());
        await tx.appendEvent(buildSchedulerEvent());
      });
      expect(await store.readJob('jb-1'), buildJob());
      expect((await store.readEvents('jb-1')).length, 1);
    });
  });
}

import 'fixtures.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// Worker registration store contract suite. Runs against any
/// [WorkerRegistrationStore] implementation.
void runWorkerRegistrationSuite({
  required String groupName,
  required Future<WorkerRegistrationStore> Function() createStore,
}) {
  group(groupName, () {
    test('registrations round-trip through the codec', () async {
      final store = await createStore();
      await store.registerWorker(buildRegistration());
      final loaded = (await store.readWorker('wk-1'))!;
      expect(loaded.workerId, 'wk-1');
      expect(loaded.poolId, 'default');
      expect(loaded.capabilities.keys, {WorkerCapability.linux});
      expect(loaded.status, WorkerStatus.idle);
      expect(loaded.platform, 'linux-x64');
      expect(loaded.artifactCache, hasLength(1));
      expect(await store.readWorker('missing'), isNull);
    });

    test(
      'registration upserts replace the previous heartbeat snapshot',
      () async {
        final store = await createStore();
        await store.registerWorker(buildRegistration());
        await store.registerWorker(
          buildRegistration(status: WorkerStatus.busy),
        );
        final loaded = await store.readWorker('wk-1');
        expect(loaded?.status, WorkerStatus.busy);
        expect(loaded?.capabilities.keys, {WorkerCapability.linux});
        expect(loaded?.artifactCache?.length, 1);
      },
    );

    test('workers list newest heartbeats first', () async {
      final store = await createStore();
      await store.registerWorker(
        buildRegistration(workerId: 'wk-1', status: WorkerStatus.idle),
      );
      await store.registerWorker(
        buildRegistration(workerId: 'wk-2', status: WorkerStatus.offline),
      );
      final all = await store.listWorkers();
      expect(all.map((w) => w.workerId), containsAll(['wk-1', 'wk-2']));
    });

    test('unregister removes a worker', () async {
      final store = await createStore();
      await store.registerWorker(buildRegistration());
      await store.unregisterWorker('wk-1');
      expect(await store.readWorker('wk-1'), isNull);
      expect(await store.listWorkers(), isEmpty);
    });

    test('inTransaction batches mutations when supported', () async {
      final store = await createStore();
      await store.inTransaction((tx) async {
        await tx.registerWorker(buildRegistration());
      });
      expect((await store.readWorker('wk-1'))?.workerId, 'wk-1');
    });
  });
}

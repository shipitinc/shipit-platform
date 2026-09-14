import 'package:worker_protocol/worker_protocol.dart';
import 'package:test/test.dart';

WorkerRegistration _worker({
  required String id,
  Set<WorkerCapability> capabilities = const {WorkerCapability.linux},
  WorkerStatus status = WorkerStatus.idle,
  int currentLoad = 0,
  int maxConcurrency = 1,
  String? platform,
}) => WorkerRegistration(
  workerId: id,
  poolId: 'test-pool',
  capabilities: {
    for (final c in capabilities)
      c: CapabilitySpec(capability: c, version: '1.0'),
  },
  status: status,
  currentLoad: currentLoad,
  maxConcurrency: maxConcurrency,
  lastHeartbeat: DateTime.now(),
  platform: platform,
);

void main() {
  group('WorkerSelector', () {
    test('dispatches deterministically to first idle compatible worker', () {
      const selector = WorkerSelector();
      final selection = selector.select(
        requirements: const TaskRequirements(
          requiredCapabilities: {WorkerCapability.linux},
        ),
        pool: [
          _worker(id: 'a'),
          _worker(
            id: 'b',
            capabilities: const {
              WorkerCapability.linux,
              WorkerCapability.docker,
            },
          ),
        ],
      );

      expect(selection.isDispatched, isTrue);
      expect(selection.outcome, WorkerDispatchOutcome.dispatched);
      expect(selection.candidate!.workerId, 'a');
    });

    test(
      'ignores availability for the compatible set but not for dispatch',
      () {
        const selector = WorkerSelector();
        final selection = selector.select(
          requirements: const TaskRequirements(
            requiredCapabilities: {WorkerCapability.linux},
          ),
          pool: [_worker(id: 'busy', currentLoad: 1, maxConcurrency: 1)],
        );

        expect(selection.outcome, WorkerDispatchOutcome.workerBusy);
        expect(selection.compatibleWorkers.single.workerId, 'busy');
        expect(selection.candidate, isNull);
      },
    );

    test('noCompatibleWorker when nothing in the pool has the capability', () {
      const selector = WorkerSelector();
      final selection = selector.select(
        requirements: const TaskRequirements(
          requiredCapabilities: {WorkerCapability.gpu},
        ),
        pool: [
          _worker(id: 'a'),
          _worker(id: 'b'),
        ],
      );

      expect(selection.outcome, WorkerDispatchOutcome.noCompatibleWorker);
      expect(selection.compatibleWorkers, isEmpty);
    });

    test('version requirement still rules a candidate out', () {
      const selector = WorkerSelector();
      final selection = selector.select(
        requirements: const TaskRequirements(
          requiredCapabilities: {WorkerCapability.linux},
          minVersions: {WorkerCapability.linux: '2.0'},
        ),
        pool: [_worker(id: 'old')],
      );

      expect(selection.outcome, WorkerDispatchOutcome.noCompatibleWorker);
    });

    test('offline and draining workers cannot be dispatched', () {
      const selector = WorkerSelector();
      final selection = selector.select(
        requirements: const TaskRequirements(
          requiredCapabilities: {WorkerCapability.linux},
        ),
        pool: [
          _worker(id: 'down', status: WorkerStatus.offline),
          _worker(id: 'draining', status: WorkerStatus.draining),
        ],
      );

      expect(selection.outcome, WorkerDispatchOutcome.workerBusy);
      expect(selection.compatibleWorkers, hasLength(2));
    });

    test('registers a platform descriptor without affecting matching', () {
      const selector = WorkerSelector();
      final selection = selector.select(
        requirements: const TaskRequirements(
          requiredCapabilities: {WorkerCapability.macos},
        ),
        pool: [
          _worker(
            id: 'mac',
            capabilities: const {WorkerCapability.macos},
            platform: 'macos-14',
          ),
        ],
      );

      expect(selection.isDispatched, isTrue);
      expect(selection.candidate!.platform, 'macos-14');
    });
  });
}

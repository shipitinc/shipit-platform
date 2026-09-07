import 'package:worker_protocol/worker_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('CapabilityMatcher', () {
    late CapabilityMatcher matcher;

    setUp(() {
      matcher = const CapabilityMatcher();
    });

    test('matches worker with all required capabilities', () {
      final worker = WorkerRegistration(
        workerId: 'worker-1',
        poolId: 'linux-pool',
        capabilities: {
          WorkerCapability.linux: CapabilitySpec(
            capability: WorkerCapability.linux,
            version: '3.22',
          ),
          WorkerCapability.docker: CapabilitySpec(
            capability: WorkerCapability.docker,
            version: '24.0',
          ),
          WorkerCapability.flutter: CapabilitySpec(
            capability: WorkerCapability.flutter,
            version: '3.22',
          ),
        },
        status: WorkerStatus.idle,
        currentLoad: 0,
        maxConcurrency: 4,
        lastHeartbeat: DateTime.now(),
      );

      final requirements = TaskRequirements(
        requiredCapabilities: {
          WorkerCapability.linux,
          WorkerCapability.flutter,
        },
      );

      final matched = matcher.match(requirements, [worker]);
      expect(matched.length, equals(1));
      expect(matched.first.workerId, equals('worker-1'));
    });

    test('rejects worker missing required capability', () {
      final worker = WorkerRegistration(
        workerId: 'worker-1',
        poolId: 'linux-pool',
        capabilities: {
          WorkerCapability.linux: CapabilitySpec(
            capability: WorkerCapability.linux,
            version: '3.22',
          ),
        },
        status: WorkerStatus.idle,
        currentLoad: 0,
        maxConcurrency: 4,
        lastHeartbeat: DateTime.now(),
      );

      final requirements = TaskRequirements(
        requiredCapabilities: {
          WorkerCapability.linux,
          WorkerCapability.flutter,
        },
      );

      final matched = matcher.match(requirements, [worker]);
      expect(matched, isEmpty);
    });

    test('rejects worker with insufficient version', () {
      final worker = WorkerRegistration(
        workerId: 'worker-1',
        poolId: 'linux-pool',
        capabilities: {
          WorkerCapability.flutter: CapabilitySpec(
            capability: WorkerCapability.flutter,
            version: '3.19',
          ),
        },
        status: WorkerStatus.idle,
        currentLoad: 0,
        maxConcurrency: 4,
        lastHeartbeat: DateTime.now(),
      );

      final requirements = TaskRequirements(
        requiredCapabilities: {WorkerCapability.flutter},
        minVersions: {WorkerCapability.flutter: '3.22'},
      );

      final matched = matcher.match(requirements, [worker]);
      expect(matched, isEmpty);
    });

    test('accepts worker with higher version', () {
      final worker = WorkerRegistration(
        workerId: 'worker-1',
        poolId: 'linux-pool',
        capabilities: {
          WorkerCapability.flutter: CapabilitySpec(
            capability: WorkerCapability.flutter,
            version: '3.24',
          ),
        },
        status: WorkerStatus.idle,
        currentLoad: 0,
        maxConcurrency: 4,
        lastHeartbeat: DateTime.now(),
      );

      final requirements = TaskRequirements(
        requiredCapabilities: {WorkerCapability.flutter},
        minVersions: {WorkerCapability.flutter: '3.22'},
      );

      final matched = matcher.match(requirements, [worker]);
      expect(matched.length, equals(1));
    });

    test('matches multiple workers', () {
      final workers = [
        WorkerRegistration(
          workerId: 'worker-1',
          poolId: 'linux-pool',
          capabilities: {
            WorkerCapability.linux: CapabilitySpec(
              capability: WorkerCapability.linux,
              version: '3.22',
            ),
          },
          status: WorkerStatus.idle,
          currentLoad: 2,
          maxConcurrency: 4,
          lastHeartbeat: DateTime.now(),
        ),
        WorkerRegistration(
          workerId: 'worker-2',
          poolId: 'linux-pool',
          capabilities: {
            WorkerCapability.linux: CapabilitySpec(
              capability: WorkerCapability.linux,
              version: '3.22',
            ),
          },
          status: WorkerStatus.idle,
          currentLoad: 0,
          maxConcurrency: 4,
          lastHeartbeat: DateTime.now(),
        ),
      ];

      final requirements = TaskRequirements(
        requiredCapabilities: {WorkerCapability.linux},
      );

      final matched = matcher.match(requirements, workers);
      expect(matched.length, equals(2));
    });

    test('excludes offline workers', () {
      final worker = WorkerRegistration(
        workerId: 'worker-1',
        poolId: 'linux-pool',
        capabilities: {
          WorkerCapability.linux: CapabilitySpec(
            capability: WorkerCapability.linux,
            version: '3.22',
          ),
        },
        status: WorkerStatus.offline,
        currentLoad: 0,
        maxConcurrency: 4,
        lastHeartbeat: DateTime.now(),
      );

      final requirements = TaskRequirements(
        requiredCapabilities: {WorkerCapability.linux},
      );

      final matched = matcher.match(requirements, [worker]);
      expect(matched, isEmpty);
    });
  });

  group('WorkerProtocol dispatch strategies', () {
    test('leastLoaded selects worker with lowest load', () {
      const protocol = WorkerProtocol(strategy: DispatchStrategy.leastLoaded);

      final workers = [
        WorkerRegistration(
          workerId: 'worker-1',
          poolId: 'linux-pool',
          capabilities: {
            WorkerCapability.linux: CapabilitySpec(
              capability: WorkerCapability.linux,
              version: '3.22',
            ),
          },
          status: WorkerStatus.idle,
          currentLoad: 3,
          maxConcurrency: 4,
          lastHeartbeat: DateTime.now(),
        ),
        WorkerRegistration(
          workerId: 'worker-2',
          poolId: 'linux-pool',
          capabilities: {
            WorkerCapability.linux: CapabilitySpec(
              capability: WorkerCapability.linux,
              version: '3.22',
            ),
          },
          status: WorkerStatus.idle,
          currentLoad: 1,
          maxConcurrency: 4,
          lastHeartbeat: DateTime.now(),
        ),
      ];

      final requirements = TaskRequirements(
        requiredCapabilities: {WorkerCapability.linux},
      );

      final selected = protocol.selectWorker(requirements, workers);
      expect(selected?.workerId, equals('worker-2'));
    });

    test('returns null when no workers match', () {
      const protocol = WorkerProtocol();

      final workers = [
        WorkerRegistration(
          workerId: 'worker-1',
          poolId: 'linux-pool',
          capabilities: {
            WorkerCapability.macos: CapabilitySpec(
              capability: WorkerCapability.macos,
              version: '14.0',
            ),
          },
          status: WorkerStatus.idle,
          currentLoad: 0,
          maxConcurrency: 4,
          lastHeartbeat: DateTime.now(),
        ),
      ];

      final requirements = TaskRequirements(
        requiredCapabilities: {WorkerCapability.linux},
      );

      final selected = protocol.selectWorker(requirements, workers);
      expect(selected, isNull);
    });
  });
}

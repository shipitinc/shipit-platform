import '../worker/worker_registration.dart';
import '../worker/worker_status.dart';
import 'capability_requirements.dart';

class CapabilityMatcher {
  const CapabilityMatcher();

  List<WorkerRegistration> match(
    TaskRequirements requirements,
    List<WorkerRegistration> availableWorkers,
  ) {
    return availableWorkers.where((worker) {
      if (!_matchesCapabilities(worker, requirements)) return false;
      return worker.status == WorkerStatus.idle ||
          worker.status == WorkerStatus.busy;
    }).toList();
  }

  /// Capability-and-version matching only; availability and status are
  /// ignored so a caller can distinguish "no compatible worker exists" from
  /// "a compatible worker exists but is not currently acquirable".
  List<WorkerRegistration> matchIgnoreAvailability(
    TaskRequirements requirements,
    List<WorkerRegistration> pool,
  ) {
    return pool
        .where((worker) => _matchesCapabilities(worker, requirements))
        .toList();
  }

  bool matchesCapabilities(
    WorkerRegistration worker,
    TaskRequirements requirements,
  ) => _matchesCapabilities(worker, requirements);

  bool _matchesCapabilities(
    WorkerRegistration worker,
    TaskRequirements requirements,
  ) {
    for (final capability in requirements.requiredCapabilities) {
      final spec = worker.capabilities[capability];
      if (spec == null) return false;

      final minVersion = requirements.minVersions?[capability];
      if (minVersion != null && !_versionSatisfies(spec.version, minVersion)) {
        return false;
      }
    }
    return true;
  }

  bool _versionSatisfies(String current, String minimum) {
    final currentParts = current.split('.').map(int.tryParse).toList();
    final minParts = minimum.split('.').map(int.tryParse).toList();

    for (int i = 0; i < minParts.length; i++) {
      final currentVal = i < currentParts.length ? (currentParts[i] ?? 0) : 0;
      final minVal = minParts[i] ?? 0;
      if (currentVal > minVal) return true;
      if (currentVal < minVal) return false;
    }
    return true;
  }
}

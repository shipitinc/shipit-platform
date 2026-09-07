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
      return _workerMatchesRequirements(worker, requirements);
    }).toList();
  }

  bool _workerMatchesRequirements(
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

    return worker.status == WorkerStatus.idle ||
        worker.status == WorkerStatus.busy;
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

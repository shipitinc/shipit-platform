import 'capabilities/capability_matcher.dart';
import 'capabilities/capability_requirements.dart';
import 'dispatch/task_dispatch.dart';
import 'worker/worker_registration.dart';

export 'capabilities/capability_matcher.dart';
export 'capabilities/capability_requirements.dart';
export 'capabilities/capability_spec.dart';
export 'dispatch/task_dispatch.dart';
export 'dispatch/worker_selector.dart';
export 'worker/worker_registration.dart';
export 'worker/worker_status.dart';
export 'worker/worker_heartbeat.dart';

class WorkerProtocol {
  const WorkerProtocol({
    CapabilityMatcher? matcher,
    DispatchStrategy strategy = DispatchStrategy.leastLoaded,
  }) : _matcher = matcher ?? const CapabilityMatcher(),
       _strategy = strategy;

  final CapabilityMatcher _matcher;
  final DispatchStrategy _strategy;

  List<WorkerRegistration> findWorkers(
    TaskRequirements requirements,
    List<WorkerRegistration> pool,
  ) {
    return _matcher.match(requirements, pool);
  }

  WorkerRegistration? selectWorker(
    TaskRequirements requirements,
    List<WorkerRegistration> pool,
  ) {
    final candidates = findWorkers(requirements, pool);
    if (candidates.isEmpty) return null;

    return switch (_strategy) {
      DispatchStrategy.leastLoaded => candidates.reduce(
        (a, b) => a.currentLoad < b.currentLoad ? a : b,
      ),
      DispatchStrategy.affinity => _selectByAffinity(candidates, requirements),
    };
  }

  WorkerRegistration? _selectByAffinity(
    List<WorkerRegistration> candidates,
    TaskRequirements requirements,
  ) {
    // Prefer worker with cached artifacts for this task
    for (final candidate in candidates) {
      final cache = candidate.artifactCache;
      if (cache != null && cache.isNotEmpty) {
        return candidate;
      }
    }
    return candidates.first;
  }
}

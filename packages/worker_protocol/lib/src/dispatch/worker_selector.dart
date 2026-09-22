import 'package:meta/meta.dart';

import '../capabilities/capability_matcher.dart';
import '../capabilities/capability_requirements.dart';
import '../worker/worker_registration.dart';

/// Deterministic outcome of asking "can this request run on this pool?".
/// Distributed scheduling, fairness and backlog are explicitly NOT part of
/// this layer (ADR 0015); these outcomes are pure capability/runtime facts.
enum WorkerDispatchOutcome { dispatched, noCompatibleWorker, workerBusy }

@immutable
class WorkerSelection {
  const WorkerSelection._({
    required this.outcome,
    this.candidate,
    this.compatibleWorkers = const [],
  });

  /// The request was matched to a worker that is ready to be acquired.
  factory WorkerSelection.dispatched(WorkerRegistration worker) =>
      WorkerSelection._(
        outcome: WorkerDispatchOutcome.dispatched,
        candidate: worker,
        compatibleWorkers: const [],
      );

  /// No worker in the pool has the mandatory capabilities.
  factory WorkerSelection.noCompatibleWorker({
    List<WorkerRegistration> matchedPartial = const [],
  }) => WorkerSelection._(
    outcome: WorkerDispatchOutcome.noCompatibleWorker,
    compatibleWorkers: matchedPartial,
  );

  /// Compatible workers exist, but none is currently idle/acquirable.
  factory WorkerSelection.busy({
    required List<WorkerRegistration> compatibleWorkers,
  }) => WorkerSelection._(
    outcome: WorkerDispatchOutcome.workerBusy,
    compatibleWorkers: compatibleWorkers,
  );

  final WorkerDispatchOutcome outcome;

  /// The single deterministic choice when [outcome] == dispatched.
  final WorkerRegistration? candidate;

  /// All capability-compatible workers, regardless of availability.
  final List<WorkerRegistration> compatibleWorkers;

  bool get isDispatched => outcome == WorkerDispatchOutcome.dispatched;
}

/// Pure, deterministic capability-based selection. See [CapabilityMatcher]:
/// a worker without every mandatory capability can never be selected, and the
/// selection among compatible workers is order-stable (never host-dependent).
class WorkerSelector {
  const WorkerSelector({this.matcher = const CapabilityMatcher()});

  final CapabilityMatcher matcher;

  WorkerSelection select({
    required TaskRequirements requirements,
    required List<WorkerRegistration> pool,
  }) {
    final compatible = matcher.matchIgnoreAvailability(requirements, pool);
    if (compatible.isEmpty) {
      return WorkerSelection.noCompatibleWorker();
    }
    final acquirable = compatible
        .where((worker) =>
            worker.isAcquirable &&
            worker.isAvailable &&
            (worker.currentExecutionId == null ||
                !requirements.excludedExecutionIds.contains(worker.currentExecutionId!)))
        .toList();
    if (acquirable.isEmpty) {
      return WorkerSelection.busy(compatibleWorkers: compatible);
    }
    // Order-stable: the pool's first fully-compatible idle worker wins.
    return WorkerSelection.dispatched(acquirable.first);
  }
}

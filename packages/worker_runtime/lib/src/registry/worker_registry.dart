import 'package:worker_protocol/worker_protocol.dart';

import '../worker/worker.dart';

/// Holds the pool of [Worker]s a host knows about. Registration is additive;
/// unregistering returns the worker so the host can durably hand it off.
class WorkerRegistry {
  final Map<String, Worker> _byId = {};

  void register(Worker worker) {
    _byId[worker.workerId] = worker;
  }

  bool unregister(String workerId) => _byId.remove(workerId) != null;

  Worker? byId(String workerId) => _byId[workerId];

  List<Worker> get workers => List.unmodifiable(_byId.values);

  List<WorkerRegistration> registrations() =>
      _byId.values.map((w) => _registrationOf(w)).toList();

  /// The pool never mirrors lease state into [WorkerRegistration] snapshots;
  /// the dispatcher asks the worker directly for availability.
  WorkerRegistration _registrationOf(Worker worker) => worker.toRegistration();
}

extension WorkerRegistrationSnapshot on WorkerRegistration {
  bool get snapshotAcquirable => isAcquirable && isAvailable;
}

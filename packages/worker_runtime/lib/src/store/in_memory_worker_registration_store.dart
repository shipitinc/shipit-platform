import 'package:worker_protocol/worker_protocol.dart';

import 'worker_registration_store.dart';

/// An in-memory [WorkerRegistrationStore] used for unit tests and ephemeral
/// runs. State is not durable across restarts by design.
class InMemoryWorkerRegistrationStore implements WorkerRegistrationStore {
  final Map<String, WorkerRegistration> _registrations = {};

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) async => body(this);

  @override
  Future<void> registerWorker(WorkerRegistration registration) async {
    _registrations[registration.workerId] = registration;
  }

  @override
  Future<WorkerRegistration?> readWorker(String workerId) async =>
      _registrations[workerId];

  @override
  Future<List<WorkerRegistration>> listWorkers() async =>
      _registrations.values.toList();

  @override
  Future<void> unregisterWorker(String workerId) async {
    _registrations.remove(workerId);
  }
}

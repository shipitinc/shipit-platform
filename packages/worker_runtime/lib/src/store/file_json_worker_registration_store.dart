import 'dart:convert';
import 'dart:io';

import 'package:worker_protocol/worker_protocol.dart';

import 'worker_registration_store.dart';

/// A durable [WorkerRegistrationStore] backed by a single JSON document on
/// disk. Every mutation is written to a temp file and atomically renamed over
/// the target so a crash never leaves a truncated document.
class FileJsonWorkerRegistrationStore implements WorkerRegistrationStore {
  FileJsonWorkerRegistrationStore(this._file) {
    _load();
  }

  final File _file;

  final Map<String, WorkerRegistration> _registrations = {};

  Future<void> _pendingWrite = Future<void>.value();

  Future<void> _load() {
    if (!_file.existsSync()) return Future<void>.value();
    try {
      final document =
          jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      final workers = document['workers'] as Map<String, dynamic>? ?? {};
      workers.forEach((id, json) {
        _registrations[id] = WorkerRegistrationCodec.fromJson(
          json as Map<String, dynamic>,
        );
      });
    } catch (e) {
      throw StateError('Corrupt worker registration file: $e');
    }
    return Future<void>.value();
  }

  Future<void> _persist() {
    final write = _pendingWrite.then((_) => _writeDocument());
    _pendingWrite = write.then((_) {}, onError: (_) {});
    return write;
  }

  Future<void> _writeDocument() async {
    final document = <String, dynamic>{
      'workers': _registrations.map(
        (id, registration) =>
            MapEntry(id, WorkerRegistrationCodec.toJson(registration)),
      ),
    };
    final target = _file.absolute;
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(document), flush: true);
    await temp.rename(target.path);
  }

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) async => body(this);

  @override
  Future<void> registerWorker(WorkerRegistration registration) async {
    _registrations[registration.workerId] = registration;
    await _persist();
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
    await _persist();
  }
}

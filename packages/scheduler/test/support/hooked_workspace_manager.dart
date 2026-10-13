import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// A [WorkspaceManager] that runs a hook in the window between preparing a
/// workspace and the coordinator being asked to start the execution.
///
/// It DECORATES the real manager rather than replacing it: the worktree is a
/// real git worktree, the descriptor is the real one, and only the hook is
/// added. That matters because the hook exists to reproduce a timing the
/// production stack already has — `LocalWorker` prepares the workspace
/// (local_worker.dart:152) and only then calls the execution driver (:186) —
/// and a fake workspace manager would remove the very window it reproduces.
///
/// The hook may move the work item, which is what a human decision landing
/// during that window really does. It must not throw: `LocalWorker` treats a
/// throwing `prepare` as `prepareFailed`, which is a different outcome entirely
/// and would test nothing about supersession.
class HookedWorkspaceManager implements WorkspaceManager {
  HookedWorkspaceManager(this._base, {required this.afterPrepared});

  final WorkspaceManager _base;

  /// Called with the prepared request and the descriptor the base manager
  /// actually produced, between prepare and the execution driver.
  final Future<void> Function(
    WorkerExecutionRequest request,
    WorkspaceDescriptor descriptor,
  )
  afterPrepared;

  @override
  Future<WorkspaceDescriptor> prepare(
    WorkerExecutionRequest request, {
    String workerId = '',
  }) async {
    final descriptor = await _base.prepare(request, workerId: workerId);
    await afterPrepared(request, descriptor);
    return descriptor;
  }

  @override
  Future<WorkerCleanupStatus> cleanup(WorkspaceDescriptor descriptor) =>
      _base.cleanup(descriptor);

  @override
  Future<List<WorkspaceDescriptor>> discoverAll() => _base.discoverAll();
}

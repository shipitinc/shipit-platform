import 'package:platform_contracts/platform_contracts.dart';

/// Owns one execution workspace's full lifecycle: creation under platform
/// ownership metadata, inspection, and removal. Only directories proven by a
/// [WorkspaceDescriptor] are ever touched; reconciliation never guesses based
/// on directory naming.
abstract interface class WorkspaceManager {
  /// Creates a fresh worktree pinned to [WorkerExecutionRequest.startingRevision].
  /// The descriptor is persisted OUTSIDE the worktree (ownership metadata).
  Future<WorkspaceDescriptor> prepare(
    WorkerExecutionRequest request, {
    String workerId = '',
  });

  /// Removes the workspace this descriptor owns and marks it cleaned.
  /// Safe to call twice for the same descriptor.
  Future<WorkerCleanupStatus> cleanup(WorkspaceDescriptor descriptor);

  /// All workspace descriptors this manager has ever recorded, including ones
  /// whose execution has since vanished (the reconcile input set).
  Future<List<WorkspaceDescriptor>> discoverAll();
}

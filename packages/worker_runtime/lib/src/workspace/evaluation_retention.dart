import 'package:platform_contracts/platform_contracts.dart';

import 'workspace_manager.dart';

/// A [WorkspaceManager] whose removal can be DEFERRED past the end of the run
/// that created the workspace, so that a later evaluation can still read it.
///
/// ## WHY THIS IS A SEPARATE INTERFACE AND NOT A NEW METHOD ON
/// [WorkspaceManager]
///
/// Adding a method to [WorkspaceManager] would break every class that
/// `implements` it — and one of those lives outside the paths this change owns
/// (`packages/scheduler/test/support/hooked_workspace_manager.dart`). A
/// separate interface leaves [WorkspaceManager] exactly as it was, so a
/// scheduler test double keeps compiling and keeps meaning what it meant.
///
/// ## WHY THE REMOVAL IS DEFERRED RATHER THAN SUPPRESSED
///
/// The retention is a change of MOMENT, never of WHETHER. The workspace that
/// this manager holds is removed by [release] as soon as the thing that reads
/// it has finished reading it, and the durable record of the deferral is
/// [WorkerCleanupStatus.pending] — the platform's own vocabulary for "this
/// workspace is still on disk and its removal has not happened yet".
abstract interface class EvaluationRetainingWorkspaceManager
    implements WorkspaceManager {
  /// Removes the workspace NOW, and marks it cleaned.
  ///
  /// This is the removal the deferred [cleanup] owed. It is safe to call
  /// twice for the same descriptor: the second call finds it already cleaned.
  Future<WorkerCleanupStatus> release(WorkspaceDescriptor descriptor);
}

/// A [WorkspaceManager] that DEFERS the removal of the workspaces it hands
/// out, and performs that removal when [release] is called.
///
/// ## WHAT IT DOES, IN ONE LINE
///
/// `prepare` is the base manager's; `cleanup` does NOT remove — it records
/// that the removal is still owed; `release` removes. That is the whole
/// mechanism.
///
/// ## WHY `cleanup` DEFERS INSTEAD OF REMOVING
///
/// The workspace a worker runs in is the checkout the QA gates re-read. If
/// the removal happened when the run ended, the gate that re-reads it would
/// find nothing there and could say nothing about the artefact it was asked
/// about — a fail-closed outcome that carries no signal about the work. So
/// the removal waits for the reader.
///
/// ## WHY DEFERRING IS NOT A LEAK
///
/// Deferring moves the removal; it does not cancel it, and this class cannot
/// be used to make a workspace outlive its reader:
///  * the deferral is durable — the worker's row records
///    [WorkerCleanupStatus.pending], which is exactly what the platform means
///    by "this workspace is still there";
///  * the release is owned by the QA lane, which releases the workspace as
///    soon as the evaluation that reads it has finished — on a pass and on a
///    failing verdict alike. An evaluation that FAULTED never finished, so it
///    keeps the workspace until the retention's stall window reclaims it;
///  * a release that is interrupted is retried: the release path is a sweep,
///    it runs on every tick, and it is idempotent.
///
/// ## THE RESIDUAL, STATED
///
/// A workspace whose platform process never runs again stays on disk. There
/// is no timer outside the process and no external reaper, so the sweep that
/// performs the release is the only thing that can perform it. What bounds
/// the residual is that the worktree lives under ONE platform-owned
/// workspace root, that the ownership metadata beside it proves the platform
/// created it, and that the first tick of the next process releases it. What
/// does not bound it is a platform that is never started again.
class RetainingWorkspaceManager implements EvaluationRetainingWorkspaceManager {
  RetainingWorkspaceManager(this._base);

  /// The manager that actually creates and removes the workspaces.
  final WorkspaceManager _base;

  @override
  Future<WorkspaceDescriptor> prepare(
    WorkerExecutionRequest request, {
    String workerId = '',
  }) => _base.prepare(request, workerId: workerId);

  /// DEFERS the removal. The workspace stays exactly where it is, so that the
  /// gate that re-reads it can still read it.
  ///
  /// The returned status is [WorkerCleanupStatus.pending] — "the removal has
  /// not happened yet" — and NOT [WorkerCleanupStatus.removed], because
  /// nothing was removed. A caller that needs the workspace gone calls
  /// [release].
  @override
  Future<WorkerCleanupStatus> cleanup(WorkspaceDescriptor descriptor) async {
    if (descriptor.isCleaned) return WorkerCleanupStatus.removed;
    return WorkerCleanupStatus.pending;
  }

  @override
  Future<WorkerCleanupStatus> release(WorkspaceDescriptor descriptor) =>
      _base.cleanup(descriptor);

  @override
  Future<List<WorkspaceDescriptor>> discoverAll() => _base.discoverAll();
}

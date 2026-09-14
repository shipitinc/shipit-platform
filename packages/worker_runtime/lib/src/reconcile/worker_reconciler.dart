import 'package:platform_contracts/platform_contracts.dart';

import '../store/worker_store.dart';
import '../workspace/workspace_manager.dart';

/// Recovers executions stranded by a process exit. Only workspaces proven by
/// platform ownership metadata ([WorkspaceDescriptor]) are ever touched;
/// unknown directories are never deleted.
///
/// Idempotent by construction: terminal executions are skipped, cleaned
/// workspaces report as already handled, and a second pass over the same store
/// finds nothing to do.
class WorkerReconciler {
  WorkerReconciler({required this.workerStore, required this.workspaceManager});

  final WorkerStore workerStore;
  final WorkspaceManager workspaceManager;

  Future<List<WorkerExecution>> reconcileOrphans() async {
    final orphans = <WorkerExecution>[];
    final executions = await workerStore.listWorkerExecutions();
    final descriptors = await workspaceManager.discoverAll();

    for (final execution in executions) {
      if (execution.isTerminal) continue;

      WorkspaceDescriptor? descriptor;
      for (final candidate in descriptors) {
        if (candidate.workerExecutionId == execution.workerExecutionId) {
          descriptor = candidate;
          break;
        }
      }

      WorkerCleanupStatus cleanupStatus;
      if (descriptor == null) {
        // No platform-owned workspace exists for this execution.
        cleanupStatus = WorkerCleanupStatus.notApplicable;
      } else if (descriptor.isCleaned) {
        cleanupStatus = WorkerCleanupStatus.removed;
      } else {
        cleanupStatus = await workspaceManager.cleanup(descriptor);
      }

      final orphaned = _orphanedRecord(execution, cleanupStatus);
      await workerStore.saveWorkerExecution(
        orphaned,
        expectedVersion: execution.version,
      );

      final result = WorkerExecutionResult(
        workerExecutionId: execution.workerExecutionId,
        workItemId: execution.workItemId,
        status: WorkerExecutionStatus.orphaned,
        startingRevision: execution.requestedStartingRevision,
        workerId: execution.workerId ?? '',
        workspaceId: descriptor?.workspaceId ?? '',
        cleanupStatus: cleanupStatus,
        failureCode: WorkerFailureCode.agentFailed,
        failureDetail: 'orphaned by worker process exit',
        startedAt: execution.startedAt ?? DateTime.now().toUtc(),
        endedAt: DateTime.now().toUtc(),
      );
      await workerStore.saveResult(result);
      orphans.add(orphaned);
    }
    return orphans;
  }

  WorkerExecution _orphanedRecord(
    WorkerExecution execution,
    WorkerCleanupStatus cleanupStatus,
  ) {
    return execution.copyWith(
      status: WorkerExecutionStatus.orphaned,
      cleanupStatus: cleanupStatus,
      failureCode: execution.failureCode ?? WorkerFailureCode.agentFailed,
      reason: 'orphaned by worker process exit',
      endedAt: DateTime.now().toUtc(),
      version: execution.version + 1,
    );
  }
}

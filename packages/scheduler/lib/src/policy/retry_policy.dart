import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// Bounded, conservative retry policy. Only transient INFRASTRUCTURE
/// failures may ever be retried (bounded by the job's `maxAttempts`); a
/// failed coding RESULT is [JobFailureKind.permanent] and routes through the
/// workflow's correction/review gate instead of an automatic LLM re-run.
@immutable
class RetryPolicy {
  const RetryPolicy({this.retryDelay = const Duration(minutes: 1)});

  final Duration retryDelay;

  /// Maps a terminal worker outcome to the job's bounded failure record.
  /// `succeeded` maps to a non-failure; `cancelled` is an explicit cancel;
  /// interruption classes are transient; coding/preparation failures are
  /// permanent.
  JobFailure? classify(WorkerExecutionStatus status, String? detail) {
    switch (status) {
      case WorkerExecutionStatus.executedPass:
        return null;
      case WorkerExecutionStatus.cancelled:
        return JobFailure(
          code: JobFailureCode.cancelled,
          kind: JobFailureKind.cancelled,
          reason: detail,
        );
      case WorkerExecutionStatus.timedOut || WorkerExecutionStatus.orphaned:
        return JobFailure(
          code: JobFailureCode.executionInterrupted,
          kind: JobFailureKind.transient,
          reason: detail,
        );
      case WorkerExecutionStatus.prepareFailed:
        return JobFailure(
          code: JobFailureCode.workspacePrepareFailed,
          kind: JobFailureKind.permanent,
          reason: detail,
        );
      case WorkerExecutionStatus.executedFail ||
          WorkerExecutionStatus.acquiring ||
          WorkerExecutionStatus.workspacePreparing ||
          WorkerExecutionStatus.agentExecuting ||
          WorkerExecutionStatus.finalizing:
        // A store compare-and-swap loss is not a coding result: another
        // writer already advanced the durable row, which is exactly the
        // infrastructure race `transient` exists for. The exception TYPE
        // cannot cross the worker boundary — `LocalWorker` flattens it to a
        // string — so the worker marks the detail with
        // [storeContentionMarker] and the marker, never prose matching, is
        // what is checked. F-241: an unmarked CAS detail classified
        // PERMANENT and jobs died on races they had already lost correctly.
        if (isStoreContentionDetail(detail)) {
          return JobFailure(
            code: JobFailureCode.executionInterrupted,
            kind: JobFailureKind.transient,
            reason: detail,
          );
        }
        return JobFailure(
          code: JobFailureCode.executionFailed,
          kind: JobFailureKind.permanent,
          reason: detail,
        );
    }
  }

  bool canRetry(Job job) => job.attempt < job.maxAttempts;
}

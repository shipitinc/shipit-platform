import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

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
        return JobFailure(
          code: JobFailureCode.executionFailed,
          kind: JobFailureKind.permanent,
          reason: detail,
        );
    }
  }

  bool canRetry(Job job) => job.attempt < job.maxAttempts;
}

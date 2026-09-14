/// Bounded terminal failure classification for a [Job], kept parallel to (but
/// distinct from) the worker and agent failure codes. A workflow-level
/// outcome (agent produced code that failed review) is never encoded here:
/// that is a WORKFLOW decision owned by the workflow engine.
enum JobFailureCode {
  none,
  workspacePrepareFailed,
  executionFailed,
  executionInterrupted,
  cancelled;

  bool get isFailure => this != none;
}

/// Retry affordance of a [JobFailureCode]. Only [transient] failures can ever
/// be retried, and only up to the job's bounded `maxAttempts`. A failed
/// coding *result* is [permanent]: the platform routes it through workflow
/// correction/review instead of calling an LLM repeatedly for the same wrong
/// implementation.
enum JobFailureKind {
  none,
  permanent,
  transient,
  cancelled;

  const JobFailureKind();

  bool get isRetryable => this == transient;
}

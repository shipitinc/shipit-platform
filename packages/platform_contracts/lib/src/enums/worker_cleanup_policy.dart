/// How the worker layer treats an execution workspace after the terminal
/// outcome. Successful runs always capture evidence and then remove the
/// worktree; failures may opt to preserve the worktree for debugging.
enum WorkerCleanupPolicy {
  removeAlways,
  preserveOnFailure;

  const WorkerCleanupPolicy();

  bool get alwaysRemoves => this == removeAlways;

  bool get preservesOnFailure => this == preserveOnFailure;
}

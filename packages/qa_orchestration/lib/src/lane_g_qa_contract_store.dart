import 'package:platform_contracts/platform_contracts.dart';

/// Durable container for [QAContract].
///
/// `WorkItem.qaContractId` is a persisted `String?` on every work item, and
/// `GuardConditions.qaContractExists()` on the
/// `agentExecuting -> agentCompleted` edge refuses the transition unless that
/// column is non-null. Until this interface existed the column had exactly one
/// writer — the optional `DurableWorkflowEngine.createWorkItem(qaContractId:)`
/// passthrough — and no production caller passed a value, so the guard could
/// never pass for any work item the platform provisions itself.
///
/// The reason it could never pass is the important half: a non-null string
/// satisfies the guard, and that is *all* the guard checks. An id that
/// resolves to no row is indistinguishable from a real contract at the
/// transition boundary while being worthless to every reader, auditor and
/// gate evaluator above it. This interface therefore makes the resolved
/// [QAContract] the return value of the write path, so a caller holding a
/// `qaContractId` can only obtain it by way of a contract it has read back.
///
/// This package owns QA contracts, gates and evidence (AGENTS.md §3), so the
/// abstraction lives here and the PostgreSQL implementation is hosted in
/// `apps/server` alongside the other `Postgres*Store`s. The interface carries
/// no I/O, no SQL and no driver types, so nothing here is
/// `apps/`-specific.
abstract interface class QAContractStore {
  /// Writes [contract], replacing any existing row with the same
  /// [QAContract.contractId].
  ///
  /// Idempotent on `contractId`: re-running a provisioner converges on one row
  /// instead of accumulating duplicates. A contract is a versioned declaration
  /// rather than an append-only record, so the last write wins and
  /// [QAContract.updatedAt] is the caller's assertion of when that happened.
  Future<void> saveQAContract(QAContract contract);

  /// Writes [contract] and then reads the row back, returning what the
  /// database actually holds.
  ///
  /// This is the write path a provisioner should use. It exists so that
  /// `WorkItem.qaContractId` can only ever be stamped with an id that
  /// provably resolves: a caller that has not seen the round-tripped contract
  /// has no id to hand to `createWorkItem`.
  Future<QAContract> provisionQAContract(QAContract contract);

  /// The contract with this id, or `null` when no such row exists.
  ///
  /// `null` is the honest answer for an id that was never written. It is not an
  /// error: callers legitimately probe for a contract before creating one.
  Future<QAContract?> readQAContract(String contractId);

  /// Whether a contract with this id exists. Cheaper than
  /// [readQAContract] and used to keep the "the id resolves" assertion in a
  /// hot provision path off the deserializer.
  Future<bool> hasQAContract(String contractId);

  /// Every contract provisioned for the work item [workItemId], oldest first.
  ///
  /// [QAContract] has no `workItemId` field: it is a reusable declaration, and
  /// the same contract may be attached to more than one work item. The
  /// link is the `workItemId` recorded under
  /// [QAContract.metadata] by the provisioner that owns it, which is what this
  /// queries.
  Future<List<QAContract>> listQAContractsForWorkItem(String workItemId);

  /// Every contract declared for [category], oldest first.
  Future<List<QAContract>> listQAContractsByCategory(WorkItemCategory category);
}

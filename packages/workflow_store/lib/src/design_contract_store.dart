import 'package:platform_contracts/platform_contracts.dart';

/// A durable container for [DesignContract].
///
/// ## Why this interface exists
///
/// `WorkItem.designContractId` is a persisted `String?` on every work item, and
/// `GuardConditions.designContractExists()` on `planned -> designRequired` and
/// on the R2.3 release edge `designParked -> designRequired` refuses the
/// transition unless that column is non-null. Until this interface existed the
/// column had **no writer at all**: there was no `design_contract` table, no
/// store, and no builder, so the guard could only be satisfied by a caller
/// passing a string in transition context — which
/// `DurableWorkflowEngine.transition` then discards. That is the fabrication
/// lane E refused rather than perform (see
/// `apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart`).
///
/// ## Why the write path returns the contract
///
/// The reason this matters is not that the column is nullable. It is that a
/// non-null string satisfies `designContractExists()` and **that is all the
/// guard checks**: an id resolving to no row is indistinguishable from a real
/// contract at the transition boundary while being worthless to every reader,
/// auditor and gate evaluator above it. So [provisionDesignContract] makes the
/// resolved [DesignContract] the return value of the write, and a caller holding
/// a `designContractId` can only obtain it by way of a contract it has read
/// back.
///
/// ## Where the two halves live
///
/// This interface carries no I/O, no SQL and no driver types, so nothing here
/// is `apps/`-specific; it lives in `workflow_store` because that is the
/// package that owns the durable workflow record and already depends on
/// `platform_contracts`, where `DesignContract` and `DesignContractStatus` are
/// declared. The PostgreSQL implementation is hosted in `apps/server` alongside
/// the other `Postgres*Store`s.
///
/// ## What it deliberately does NOT do
///
/// It does not decide when a contract is written, and it does not decide
/// whether one may be. Both belong to the lanes that own them: the builder that
/// provisions the draft contract, and `designContractExists()` itself, which
/// must read the durable column rather than caller-supplied context before this
/// store can be the thing that settles the question.
abstract interface class DesignContractStore {
  /// Writes [contract], replacing any existing row with the same
  /// [DesignContract.contractId].
  ///
  /// Idempotent on `contractId`: re-running a builder converges on one row
  /// instead of accumulating duplicates. A contract is a declaration rather than
  /// an append-only record, so the last write wins and
  /// [DesignContract.updatedAt] is the caller's assertion of when that happened.
  Future<void> saveDesignContract(DesignContract contract);

  /// Writes [contract] and then reads the row back, returning what the store
  /// actually holds.
  ///
  /// This is the write path a builder should use, and it exists for the reason
  /// [DesignContractStore]'s own doc names: the value returned from here is
  /// what gets stamped on a work item, so a caller that has not seen the
  /// round-tripped contract has no id to hand to
  /// `DurableWorkflowEngine.createWorkItem(designContractId:)`.
  ///
  /// Implementations MUST raise rather than return a contract they did not read
  /// back, for the same reason `PostgresQAContractStore.provisionQAContract`
  /// does.
  Future<DesignContract> provisionDesignContract(DesignContract contract);

  /// The contract with this id, or `null` when no such row exists.
  ///
  /// `null` is the honest answer for an id that was never written. It is not an
  /// error: callers legitimately probe for a contract before creating one, and
  /// the probe is what distinguishes a real contract from a fabricated string.
  Future<DesignContract?> readDesignContract(String contractId);

  /// Whether a contract with this id exists. Cheaper than
  /// [readDesignContract], and used to keep the "the id resolves" assertion in
  /// a hot provisioning path off the deserializer.
  Future<bool> hasDesignContract(String contractId);

  /// Every contract recorded for [workItemId], **oldest first**: ascending
  /// [DesignContract.createdAt], with ascending [DesignContract.contractId]
  /// breaking a tie.
  ///
  /// `DesignContract.workItemId` is a column rather than a metadata key
  /// precisely so this read is an indexed lookup; see
  /// `apps/server/lib/src/database/design_contract.spy.yaml`.
  ///
  /// One per work item is the shape the builder produces, but the interface does
  /// not require it: a read that returned only the newest row would hide a
  /// second contract rather than surface it.
  ///
  /// ## The order is specified, not incidental (F-146)
  ///
  /// This method once read "oldest first" while every implementation returned
  /// whatever order its storage happened to produce — a Dart `Map`'s insertion
  /// order in the in-memory store, `"createdAt" ASC` in SQL. That is not a
  /// cosmetic difference: two implementations disagreeing about which of a
  /// work item's contracts comes FIRST is a caller that gets one answer in a
  /// unit test and another in production, and the disagreement is invisible in
  /// every artifact a reviewer reads.
  ///
  /// The tie-break is therefore part of the contract, not tidiness.
  /// [DesignContract.createdAt] is the CALLER's assertion of when a contract
  /// was written, so two contracts carrying the same instant is a normal state
  /// rather than a malformed row; without a total order an implementation is
  /// free to return those two in either order and still be "oldest first".
  Future<List<DesignContract>> listDesignContractsForWorkItem(
    String workItemId,
  );
}

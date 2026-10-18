import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import 'design_contract_store.dart';

/// The `DesignContract.contractId` a remediation work item is governed by.
///
/// A PURE FUNCTION of the work item id, for the reason
/// `productQAContractIdForWorkItem` is: two calls for one item address the same
/// primary key, so `saveDesignContract`'s `ON CONFLICT ("contractId") DO UPDATE`
/// converges on ONE row and a replay of a crashed provisioning step cannot
/// produce a second contract for one item. Two items address two rows.
///
/// The `design-contract-` prefix namespaces this away from the QA contract ids
/// (`qa-triage-…`, `qa-product-…`). That separation is not cosmetic: lane E
/// already records why a defect-scoped QA id under a remediation item would have
/// repointed the triage contract the same defect owns. Design contracts and QA
/// contracts are different objects with different approvers, so they get
/// different id spaces.
String designContractIdForWorkItem(String workItemId) =>
    'design-contract-$workItemId';

/// `RequiredArtifact.artifactType` of the artifact a design-remediation contract
/// requires.
///
/// `DesignContract` is a REQUIREMENT contract — "which artifacts must be
/// submitted, which reviewers, approval threshold" (checkpoint 003 §1) — and the
/// artifact it requires is the `design_revision` record, because that record is
/// the only thing that answers "what exactly is implementation authorized to
/// build?" (checkpoint 003 §5.1). It is a named constant rather than a literal
/// at the construction site so that a later lane adding a second required
/// artifact has to decide the vocabulary deliberately instead of appending a
/// string.
const String designRevisionArtifactType = 'design_revision';

/// Metadata key: the product whose design authority governs this contract.
///
/// Present on every contract this module builds, so an auditor reading the row
/// can tell whose promise it is without following the work item back.
const String designContractProductIdMetadataKey = 'productId';

/// Metadata key: the design defect this contract exists to remediate.
///
/// `null` for a contract that does not come from a design defect. Present when
/// it is, because a contract with no recorded provenance is a contract whose
/// scope nobody can reconstruct later.
const String designContractDefectIdMetadataKey = 'defectId';

/// Metadata key: the triage result that classified the defect as a design flaw.
const String designContractTriageResultIdMetadataKey = 'triageResultId';

/// Metadata key: whether the contract declares a `RequiredArtifact.validationSchema`
/// for the artifacts it requires.
///
/// The value is [requiredArtifactSchemasAbsent]. It exists because
/// `validationSchema: null` is ambiguous on its own: it reads equally as "there
/// is no schema to check this artifact against" and as "nothing needs checking",
/// and those are different claims. The first is the truth today — the fidelity
/// anchor, which is what would make a schema checkable, does not exist yet — and
/// a reader who cannot tell which one they are looking at will read a gate that
/// does not exist as a gate that passed.
const String requiredArtifactSchemasMetadataKey = 'requiredArtifactSchemas';

/// Value of [requiredArtifactSchemasMetadataKey] while the fidelity anchor is
/// absent.
const String requiredArtifactSchemasAbsent = 'absent';

/// Builds the [DesignContract] a design-remediation work item is governed by.
///
/// ## What this declares, and what it refuses to declare
///
/// Per checkpoint 003 §1 a `DesignContract` says *what must be submitted and who
/// approves*. So this builds exactly that and nothing more:
///
///   * `requiredArtifacts` — one entry, the `design_revision` record, with
///     `validationSchema: null`. The null is a NAMED absence, not a claim that
///     nothing needs checking: the fidelity anchor that would give a column of
///     `design_revision` a machine-checkable schema has not been built, so a
///     schema here would be a gate no validator runs — the `92d567e3` lesson,
///     one layer down.
///   * `reviewers` — [AgentRole.designReviewer]'s wire token, which is the ROLE
///     the platform requires, not an identity. Reviewer identity is not knowable
///     when a work item is created and inventing one would put a fabricated
///     actor on a durable governance record.
///   * `approvalThreshold` — [designContractApprovalThreshold]. One independent
///     approval. This is deliberately NOT the `designApproval` human gate: that
///     gate is a separate authority taken over the resolved risk tier, and the
///     risk tier cannot be resolved while `DesignRiskPolicy` does not exist.
///     Folding an unresolvable tier into this number would record a decision
///     nobody took.
///   * `submittedArtifacts` and `decisions` — `null`, not `[]`. An empty list
///     says "nothing was submitted" / "nothing was decided" as a fact; `null`
///     says "there has been no submission yet", which is what a `draft` contract
///     actually knows.
///   * `expiresAt` — `null`. No expiry rule exists to encode, and a duration
///     invented here would be a policy this lane has no authority to set.
///
/// Every one of those is a refusal to fabricate, stated so a reviewer can check
/// the refusal rather than infer it from the absence of code.
@immutable
class DesignContractBuilder {
  const DesignContractBuilder();

  /// Builds the draft contract governing [workItemId].
  ///
  /// [productId] is the product whose design authority governs the contract and
  /// is recorded on it. [defectId] and [triageResultId] are the provenance of a
  /// design-remediation contract and are `null` for any other kind.
  ///
  /// [now] is threaded into both timestamps so a replay with the same instant is
  /// a byte-identical write — the same discipline
  /// `DesignRemediationWorkItemProvisioner` uses for its QA contract, and the
  /// reason a replay of a crashed provisioning step converges rather than
  /// churning the row.
  ///
  /// This is a PURE function. It performs no I/O; persisting the result is
  /// [DesignContractProvisioner]'s job, and the separation is what lets the
  /// declaration be asserted without a store and without a database.
  DesignContract buildDraftContract({
    required String workItemId,
    required String productId,
    required DateTime now,
    String? defectId,
    String? triageResultId,
  }) {
    return DesignContract(
      contractId: designContractIdForWorkItem(workItemId),
      workItemId: workItemId,
      requiredArtifacts: const [
        RequiredArtifact(
          artifactType: designRevisionArtifactType,
          description:
              'The durable design revision record this contract requires: the '
              'only artifact that states what implementation is authorized to '
              'build.',
          required: true,
        ),
      ],
      reviewers: [AgentRole.designReviewer.wire],
      approvalThreshold: designContractApprovalThreshold,
      status: DesignContractStatus.draft,
      createdAt: now,
      updatedAt: now,
      metadata: {
        designContractProductIdMetadataKey: productId,
        designContractDefectIdMetadataKey: defectId,
        designContractTriageResultIdMetadataKey: triageResultId,
        requiredArtifactSchemasMetadataKey: requiredArtifactSchemasAbsent,
      },
    );
  }
}

/// One independent approval of a submitted design artifact.
///
/// The threshold is a declaration about ARTIFACT approval, which is what
/// `DesignContract` governs. It is not the `designApproval` human gate, which is
/// a separate authority over the resolved risk tier and which cannot be resolved
/// today: `DesignRiskPolicy` does not exist, so the interim default is that every
/// revision is HIGH. A threshold of `0` would assert that no approval is required
/// for a design artifact, which is false, so `1` is the only value this builder
/// can state without inventing policy.
const int designContractApprovalThreshold = 1;

/// Provisions the [DesignContract] a work item is governed by, and hands back the
/// id of the row that was actually read back.
///
/// ## Why this exists rather than a bare `build` + `save`
///
/// It performs the write, reads the row back, and returns the resolved contract —
/// in that order — so a caller cannot stamp a work item with an id it has not
/// seen resolve. `GuardConditions.designContractExists()` reads the durable
/// `designContractId` column and confirms it against a [DesignContractStore],
/// so an id that resolves to nothing is refused at the transition; before that
/// confirmation existed the same id was worth exactly as much as a real one at
/// that boundary and nothing at all above it. The read-back is the whole point;
/// [buildDraftContract] without it would reproduce the fabrication this exists
/// to remove.
///
/// ## Idempotence
///
/// [designContractIdForWorkItem] is a pure function of the work item id, so two
/// calls for one item address the same primary key and the store's
/// `ON CONFLICT … DO UPDATE` converges on ONE row. There is no path through this
/// class that produces a second contract for one item.
@immutable
class DesignContractProvisioner {
  const DesignContractProvisioner({
    required this.contractStore,
    this.builder = const DesignContractBuilder(),
  });

  final DesignContractStore contractStore;
  final DesignContractBuilder builder;

  /// Returns the contract governing [workItemId], having persisted it and read it
  /// back.
  ///
  /// Throws rather than returning `null`. A `String?` return would make "the
  /// store could not be written" indistinguishable from "there is no contract",
  /// and both would produce a work item whose `designContractId` names nothing.
  /// The two failures this can raise are named in the failure itself:
  ///
  ///   * [StateError] — the store returned a contract addressed differently from
  ///     the one submitted, or could not read back what it was just handed. Both
  ///     mean the store is not honouring [DesignContractStore]'s own contract.
  ///   * any exception the store raises — surfaced, never swallowed.
  ///
  /// [now] is threaded into the built contract's timestamps so a replay with the
  /// same instant is a byte-identical write.
  ///
  /// ## WHY THE METHOD IS NAMED `provisionForWorkItem`
  ///
  /// `apps/server/test/durable_workspace_provision_trigger_test.dart` holds a
  /// repo-wide, call-shaped gate that refuses a `.provision(` on any receiver
  /// other than `trigger`, because `DurableWorkspaceRuntime.provision()` is a
  /// DESTRUCTIVE capability with five guards in front of it. This method
  /// persists a design contract and materialises nothing, so it is named for
  /// what it does — the same reasoning, and the same name, as
  /// `ProductQAContractProvisioner.provisionForWorkItem`.
  Future<DesignContract> provisionForWorkItem({
    required String workItemId,
    required String productId,
    DateTime? now,
    String? defectId,
    String? triageResultId,
  }) async {
    final addressed = designContractIdForWorkItem(workItemId);
    final stored = await contractStore.provisionDesignContract(
      builder.buildDraftContract(
        workItemId: workItemId,
        productId: productId,
        defectId: defectId,
        triageResultId: triageResultId,
        now: now ?? DateTime.now(),
      ),
    );
    // The store is handed one id and handed back the row it addressed, so a
    // mismatch is only reachable if the store is not honouring its own contract.
    // It is checked anyway, for the same reason
    // `ProductQAContractProvisioner` checks it: the value returned from here is
    // what gets stamped on a work item, and an unchecked mismatch would stamp
    // the wrong one silently.
    if (stored.contractId != addressed) {
      throw StateError(
        'DesignContract store returned ${stored.contractId} for a contract '
        'addressed as $addressed',
      );
    }
    if (stored.workItemId != workItemId) {
      throw StateError(
        'DesignContract $addressed records work item ${stored.workItemId}, '
        'not $workItemId',
      );
    }
    if (!await contractStore.hasDesignContract(stored.contractId)) {
      throw StateError(
        'DesignContract $addressed is not readable after being written',
      );
    }
    return stored;
  }
}

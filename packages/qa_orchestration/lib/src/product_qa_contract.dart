import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import 'lane_g_qa_contract_store.dart';
import 'lane_g_triage_qa_contract.dart';
import 'product_qa_contract_spec_store.dart';

/// Revision of the gate set a contract provisioned from a product's declared
/// spec carries.
///
/// This versions the DERIVATION, not the product's declaration: the product's
/// own `manifestVersion` is recorded alongside it in
/// [QAContract.metadata], so a change to what a product declared and a change
/// to how a declaration is turned into a contract are two separately visible
/// facts. Bumping this string changes only the second.
///
/// The [QAContract.contractId] deliberately does NOT encode it, for the same
/// reason `advisoryTriageQAContractVersion` does not: a re-provisioned work
/// item converges on one row instead of forking a second contract.
const String productQAContractDeclarationVersion = '1.0.0';

/// Deterministic identity of the QA contract provisioned for [workItemId] from
/// a product's declared spec.
///
/// ## WHY THIS IS WORK-ITEM-SCOPED, AND WHY THAT IS NOT A DETAIL
///
/// `QAContractStore.saveQAContract` is `ON CONFLICT ("contractId") DO UPDATE`
/// (`PostgresQAContractStore`), so a `contractId` is not a name — it is the
/// primary key of a row that a second write REPLACES. Every column of the
/// victim's row is then overwritten by the writer's, including
/// `metadataJson`, which is where the `workItemId` link lives
/// (`qaContractWorkItemIdMetadataKey`). Reusing a defect-scoped id therefore
/// does not "share a contract": it silently re-points the triage parent's
/// contract at a different work item, and `listQAContractsForWorkItem` starts
/// answering for a contract that now belongs to somebody else.
///
/// The triage provisioner yields `qa-triage-$defectId`. This yields
/// `qa-product-$workItemId`. The two prefixes are disjoint, so:
///
///   * two provisioner calls for one work item address ONE row and converge
///     (which is what makes replay idempotent rather than duplicating), and
///   * a design-remediation item — whose id is
///     `design-remediation-$defectId`, and therefore CONTAINS the defect id
///     that a triage contract is keyed on — addresses a row of its own and
///     cannot overwrite its own triage parent's.
///
/// The second point is not hypothetical: `design-remediation-DEF-1791685264570406`
/// and `defect-DEF-1791685264570406` share a defect. A defect-scoped id here
/// would have been the single most damaging thing this change could do.
String productQAContractIdForWorkItem(String workItemId) =>
    'qa-product-$workItemId';

/// Metadata key: the product whose declared spec the contract was built from.
///
/// Present on every contract this module builds, so an auditor reading the row
/// can tell which product's promise the gates are, without having to look the
/// work item up and follow it back.
const String qaContractProductIdMetadataKey = 'productId';

/// Metadata key: the `ProductManifest.manifestVersion` the gates were read from.
const String qaContractManifestVersionMetadataKey = 'manifestVersion';

/// Key under [QAContract.metadata]'s `config` that carries a declared gate's
/// `evidenceTypes`.
///
/// `QAGateSpec` (the declaration shape in `platform_contracts`) has no
/// `evidenceTypes` field, while `QAGateDefinition` (the contract shape) has no
/// other constructor and requires it. Reading it out of `config` is the only
/// derivation available without changing a type in `platform_contracts` — and
/// `config` is the field on that type for gate parameters the schema does not
/// name. An absent key means `[]`, which reads as "no evidence type is
/// declared", the same thing the triage contract says when it means it.
const String declaredGateEvidenceTypesConfigKey = 'evidenceTypes';

/// Turns a product's declaration into the [QAContract] one work item is
/// governed by.
///
/// Every field is supplied by the caller because none of them is a property of
/// the product: `contractId` names the WORK ITEM (see
/// [productQAContractIdForWorkItem]), `workItemCategory` is a fact about the
/// persisted work-item row rather than about the product, and the timestamps
/// are the caller's assertion of when the provisioning happened. Passing
/// [now] makes two calls with the same instant byte-identical, which is what
/// makes a replay converge on one row rather than churn it.
///
/// ## On [QAPassCriteria], which the declaration does not carry
///
/// `QAContractSpec` declares gates and nothing else — there is no place in it
/// for a pass rule, and inventing one per product would be a policy decision
/// nobody made. The rule below is therefore DERIVED from the gates rather than
/// chosen:
///
///   * `allRequiredGatesMustPass: true` — the ordinary meaning of "required".
///     A declared gate marked required and then allowed to fail is not a
///     requirement.
///   * `optionalGateFailuresAllowed: <the number of optional gates>` — which is
///     "every optional gate may be unmet without blocking", the same rule the
///     advisory triage contract uses and the same as requiring an optional gate
///     never to fail. Deriving the count from the gates is what keeps the two
///     consistent when a product declares a different number of optional gates.
///   * `waiverRequiresHumanDecision: true` — a waiver is a human decision in
///     this platform, and a contract that let a contract provisioner waive its
///     own gates would make the gate a suggestion.
///
/// This is a DERIVATION and it is stated as one so a future reader who needs a
/// per-product pass rule has to make that a decision rather than assume it was
/// already made.
QAContract buildProductQAContract({
  required QAContractSpec spec,
  required String productId,
  required WorkItemCategory workItemCategory,
  required String workItemId,
  String? manifestVersion,
  DateTime? now,
}) {
  final timestamp = (now ?? DateTime.now()).toUtc();
  final gates = spec.gates
      .map(
        (gate) => QAGateDefinition(
          gateId: gate.gateId,
          type: gate.type,
          required: gate.required,
          config: gate.config,
          evidenceTypes: _declaredEvidenceTypes(gate),
        ),
      )
      .toList(growable: false);
  final optionalCount = gates.where((gate) => !gate.required).length;

  return QAContract(
    contractId: productQAContractIdForWorkItem(workItemId),
    workItemCategory: workItemCategory,
    version: productQAContractDeclarationVersion,
    createdAt: timestamp,
    updatedAt: timestamp,
    gates: gates,
    passCriteria: QAPassCriteria(
      allRequiredGatesMustPass: true,
      optionalGateFailuresAllowed: optionalCount,
      waiverRequiresHumanDecision: true,
    ),
    evidenceRows: const [],
    metadata: <String, dynamic>{
      qaContractWorkItemIdMetadataKey: workItemId,
      qaContractProductIdMetadataKey: productId,
      if (manifestVersion != null)
        qaContractManifestVersionMetadataKey: manifestVersion,
      'authoring': 'product_qa_contract_provisioner',
      // Stated, not implied: no gate evaluator runtime exists for a
      // product-declared gate type. `QAOrchestration.evaluate` returns
      // `QAGateStatus.notExecuted` for an unknown type and
      // `isGateSatisfied(notExecuted)` is false, so this is not a silent pass —
      // it is a durable declaration of what must be true, whose enforcement
      // runtime has yet to be written. See `lane_g_triage_qa_contract.dart` for
      // the same statement made about the triage contract.
      'evaluatorRuntime': 'absent',
    },
  );
}

/// Reads a declared gate's `evidenceTypes` out of its `config`, or `[]`.
///
/// A malformed value is not silently dropped: a `config` whose
/// `evidenceTypes` is present but is not a list of strings would otherwise
/// produce a gate whose evidence requirement quietly differs from the one that
/// was declared, and the row would read as a faithful copy of a declaration it
/// is not. It throws [FormatException] naming the gate instead.
List<String> _declaredEvidenceTypes(QAGateSpec gate) {
  if (!gate.config.containsKey(declaredGateEvidenceTypesConfigKey)) {
    return const [];
  }
  final declared = gate.config[declaredGateEvidenceTypesConfigKey];
  if (declared is! List) {
    throw FormatException(
      'gate ${gate.gateId} declares '
      '"$declaredGateEvidenceTypesConfigKey" as ${declared.runtimeType}; a '
      'JSON array of evidence type names is the only shape that can be read '
      'as one',
    );
  }
  return List<String>.unmodifiable(
    declared.map((e) {
      if (e is! String) {
        throw FormatException(
          'gate ${gate.gateId} declares a non-string evidence type ($e); the '
          'declared list is not a list of names',
        );
      }
      return e;
    }),
  );
}

/// Provisions the QA contract a work item is governed by, from the product's
/// own declaration.
///
/// ## Why this is a provisioner and not a helper
///
/// It reads the product's DECLARATION, turns it into a [QAContract], persists
/// that, and reads the row back — in that order — and it hands back the
/// `contractId` of the row that was actually read back. A caller therefore
/// cannot stamp a work item with an id it has not seen resolve, which is the
/// property that makes `WorkItem.qaContractId` mean something at
/// `GuardConditions.qaContractExists()`, where the only check is
/// `context['qaContractId'] != null`.
///
/// ## Why it throws rather than returning null
///
/// See [ProductQAContractSpecUnavailable]. A `String?` return would make
/// "this product declared nothing" indistinguishable from "this store was not
/// wired", and both would produce a work item with no contract whose refusal at
/// completion names neither. [provisionForWorkItem] throws with a named reason instead.
///
/// ## Idempotence
///
/// [productQAContractIdForWorkItem] is a pure function of the work item id, so
/// two calls for one work item address the same primary key and
/// `saveQAContract`'s `ON CONFLICT … DO UPDATE` converges on ONE row. Two calls
/// for two work items address two rows. There is no path through this class that
/// produces a second row for one work item.
@immutable
class ProductQAContractProvisioner {
  const ProductQAContractProvisioner({
    required this.contractStore,
    required this.specStore,
  });

  final QAContractStore contractStore;
  final ProductQAContractSpecStore specStore;

  /// Returns the contract governing [workItemId], having persisted it and read
  /// it back.
  ///
  /// Throws [ProductQAContractSpecUnavailable] — never returns `null` — when
  /// the product has declared no QA contract, or has declared one with no gates.
  /// No contract row is written in either case, because the refusal happens
  /// before the store is touched.
  ///
  /// [now] is threaded into both the built contract's timestamps so a replay
  /// with the same instant is a byte-identical write.
  ///
  /// ## WHY THE METHOD IS NAMED `provisionForWorkItem` AND NOT `provision`
  ///
  /// `apps/server/test/durable_workspace_provision_trigger_test.dart` holds a
  /// repo-wide, call-shaped gate that refuses a `.provision(` on any receiver
  /// other than `trigger`, because `DurableWorkspaceRuntime.provision()` is a
  /// DESTRUCTIVE capability with five guards in front of it and a direct call
  /// re-materialises a clone and rewrites an onboarding row. The gate is
  /// deliberately call-shaped rather than a block-list of names, and its own
  /// failure message says what to do when the receiver is an unrelated API:
  /// rename it.
  ///
  /// This is that case — this method persists a QA contract and cannot
  /// materialise anything — so it is named for what it does, which is also more
  /// accurate than `provision` was. Renaming here loses the gate nothing: it
  /// still catches every call on `DurableWorkspaceRuntime`. Putting it back is
  /// not a tidy-up; it would fail a gate that is protecting something else, and
  /// the fix would then be to weaken the gate, which is worse than either.
  Future<QAContract> provisionForWorkItem({
    required String productId,
    required WorkItemCategory workItemCategory,
    required String workItemId,
    String? manifestVersion,
    DateTime? now,
  }) async {
    final declaration = await specStore.readQAContractSpec(productId);
    if (declaration == null) {
      throw ProductQAContractSpecUnavailable(
        productId: productId,
        refusal: ProductQAContractSpecRefusal.notDeclared,
        workItemId: workItemId,
      );
    }
    if (!declaration.declaresQAContract) {
      throw ProductQAContractSpecUnavailable(
        productId: productId,
        refusal: ProductQAContractSpecRefusal.declaresNoGates,
        workItemId: workItemId,
      );
    }

    final addressed = productQAContractIdForWorkItem(workItemId);
    final stored = await contractStore.provisionQAContract(
      buildProductQAContract(
        spec: QAContractSpec(gates: declaration.gates),
        productId: productId,
        workItemCategory: workItemCategory,
        workItemId: workItemId,
        manifestVersion: manifestVersion ?? declaration.manifestVersion,
        now: now,
      ),
    );
    // The store is handed one id and handed back the row it addressed, so a
    // mismatch is only reachable if the store is not honouring its own
    // contract. It is checked anyway, for the same reason lane A checks it: the
    // value returned from here is what gets stamped on a work item, and an
    // unchecked mismatch would stamp the wrong one silently.
    if (stored.contractId != addressed) {
      throw StateError(
        'QAContract store returned ${stored.contractId} for a contract '
        'addressed as $addressed',
      );
    }
    if (!await contractStore.hasQAContract(stored.contractId)) {
      throw StateError(
        'QAContract $addressed is not readable after being written',
      );
    }
    return stored;
  }
}

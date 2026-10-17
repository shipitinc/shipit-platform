import 'package:platform_contracts/platform_contracts.dart';

/// Durable home of the QA contract a PRODUCT DECLARES.
///
/// ## Why this exists at all
///
/// `GuardConditions.qaContractExists()` refuses
/// `agentExecuting -> agentCompleted` unless the work item carries a
/// `qaContractId`, and it refuses on a NULL CHECK — so a work item with no
/// contract can be dispatched, can run a real agent, and can never be recorded.
/// That is not a narrow defect: it is every work item the defect-triage lane
/// did not create.
///
/// For the 14 work items measured on 2026-10-17 the correlation was perfect:
///
/// ```text
///     origin                        has qaContractId   total
///     defect-DEF-* (triage lane)                   10      10
///     design-remediation-*, WI-feature-*            0       4
/// ```
///
/// The triage lane works because `buildAdvisoryTriageQAContract` exists. The
/// other two lanes have nothing, because stamping the TRIAGE gates
/// (`triage-classification-structure`, `triage-evidence-grounding`,
/// `requiredRole: AgentRole.triageDefect`) onto a feature item would declare
/// `defect_evidence_reference` gates against a work item that has no defect.
/// That is the fiction this interface exists to avoid taking a shortcut around.
///
/// ## What a declaration is, and is not
///
/// A [ProductQAContractDeclaration] is what `ProductManifest.contracts.qaContract`
/// says — the per-product DEFAULTS for work filed under this product. It is a
/// declaration, not a [QAContract]: it carries no `contractId`, no
/// `workItemCategory`, no `createdAt` and no provenance, because none of those
/// is a property of the product. A [QAContract] is what ONE work item is governed
/// by, and is derived from a declaration at provision time
/// (`ProductQAContractProvisioner`, `product_qa_contract.dart`).
///
/// Keeping the two apart is the whole point. The defect-scoped contract's gates
/// are facts about triage; a product's declared gates are facts about the
/// product. Merging them into one shape is how a feature work item ends up
/// governed by a rule about defect evidence.
class ProductQAContractDeclaration {
  const ProductQAContractDeclaration({
    required this.productId,
    required this.gates,
    this.manifestVersion,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// The product this declaration governs. Carried in the row rather than
  /// derived, so a read is self-describing.
  final String productId;

  /// The declared gates, verbatim, in the order they were declared.
  ///
  /// A declaration whose list is EMPTY is the absence of a declaration, not a
  /// declaration of nothing: see [ProductQAContractSpecUnavailable].
  final List<QAGateSpec> gates;

  /// The `ProductManifest.manifestVersion` this was read from, recorded so a
  /// later change to a product's manifest can be traced back to the manifest
  /// version the gates came from. Null when the gates were supplied without one.
  final String? manifestVersion;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optimistic-concurrency column, the same convention every other store in
  /// this repository uses.
  final int version;

  ProductQAContractDeclaration copyWith({
    List<QAGateSpec>? gates,
    String? manifestVersion,
    DateTime? updatedAt,
    int? version,
  }) {
    return ProductQAContractDeclaration(
      productId: productId,
      gates: gates ?? this.gates,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  /// Whether this row actually declares anything.
  ///
  /// The single definition of "declared", so the store's write decision, the
  /// provisioner's refusal and the test that pins non-vacuity all answer from
  /// one place rather than from three restatements of `gates.isEmpty`.
  bool get declaresQAContract => gates.isNotEmpty;

  /// Value equality over every field.
  ///
  /// Written out rather than inherited from `Equatable`, because this package
  /// does not depend on it — and it matters more than usual here: the one
  /// assertion this type exists to support is "the product's declared contract
  /// survives save to load", and with reference equality that assertion compares
  /// two objects that are never the same object, so it passes or fails for a
  /// reason that has nothing to do with the data.
  ///
  /// `QAGateSpec` and `DateTime` both have value equality, so this is a field
  /// comparison all the way down and does not need a deep-walk of its own.
  @override
  bool operator ==(Object other) =>
      other is ProductQAContractDeclaration &&
      other.productId == productId &&
      other.manifestVersion == manifestVersion &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.version == version &&
      _listEquals(other.gates, gates);

  @override
  int get hashCode => Object.hash(
    productId,
    manifestVersion,
    createdAt,
    updatedAt,
    version,
    Object.hashAll(gates),
  );

  @override
  String toString() =>
      'ProductQAContractDeclaration(productId: $productId, '
      'gates: ${gates.length}, manifestVersion: $manifestVersion)';
}

/// `List` equality by element, because `package:collection`'s `DeepCollectionEquality`
/// is not a dependency of this package and a hand-rolled `listEquals` is not a
/// thing worth getting subtly wrong.
bool _listEquals(List<QAGateSpec> a, List<QAGateSpec> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The persistence boundary for [ProductQAContractDeclaration].
///
/// ## Why the interface lives here and not in `product_registry`
///
/// The declaration is part of `ProductManifest`, whose type lives in
/// `platform_contracts` — but what this interface stores is the QA CONTRACT a
/// product declares, and this package is the one that owns QA contracts,
/// gates and evidence. `QAContractStore` is already split exactly this way for
/// exactly this reason, and keeping the two declaration stores in one package
/// means the whole "what does a product promise about QA" question is answered
/// from one directory.
///
/// The interface carries no I/O, no SQL and no driver types, so nothing here is
/// `apps/`-specific. The PostgreSQL implementation is hosted in `apps/server`
/// alongside the other `Postgres*Store`s.
abstract interface class ProductQAContractSpecStore {
  /// Writes [declaration], replacing any existing row for the same
  /// [ProductQAContractDeclaration.productId].
  ///
  /// Idempotent on `productId`: re-saving converges on one row rather than
  /// accumulating duplicates, because a product's declared QA contract is a
  /// versioned declaration rather than an append-only record.
  ///
  /// This does NOT decide whether an empty declaration is worth storing. That
  /// decision belongs to the caller that holds the manifest, and this store
  /// records what it is given — see
  /// [ProductQAContractDeclaration.declaresQAContract] for why the two are
  /// different questions.
  Future<void> saveQAContractSpec(ProductQAContractDeclaration declaration);

  /// The declaration for [productId], or `null` when the product has never
  /// declared one.
  ///
  /// `null` is the honest answer for a product that declared nothing. It is NOT
  /// an error, and it is NOT something a caller is permitted to paper over: the
  /// provisioner turns exactly this `null` into a named refusal rather than
  /// minting a contract nobody declared.
  Future<ProductQAContractDeclaration?> readQAContractSpec(String productId);
}

/// Why a product cannot produce a QA contract.
///
/// These are NAMES, not a boolean. A provisioner that answers `false` for both
/// "the product never declared one" and "the product declared one with nothing
/// in it" tells an operator nothing about which of the two happened, and the
/// two need different remedies: one is "register a contract for this product",
/// the other is "the manifest you registered has an empty `contracts.qaContract`
/// — did you mean to write gates?".
enum ProductQAContractSpecRefusal {
  /// No declaration row exists for the product. Either the product was
  /// registered before QA contracts were persistable, or it was registered
  /// without a manifest at all.
  notDeclared,

  /// A declaration row exists but declares no gates. A gate list that is empty
  /// cannot admit or refuse anything, so a contract built from it would satisfy
  /// `qaContractExists()` while constraining nothing — the exact fiction this
  /// route exists to avoid.
  declaresNoGates,
}

/// The refusal raised when a product's declared QA contract cannot be turned
/// into a [QAContract].
///
/// This is a THROWN failure, not a returned `null`, and that distinction is the
/// acceptance criterion rather than a style preference. A provisioner returning
/// `null` has nothing to remove and nothing to report: a caller that checks for
/// `null` gets the same answer whether the product declared a contract, declared
/// an empty one, or the store was never wired at all, and the work item is then
/// created with a `qaContractId` of `null` and is refused at completion with a
/// guard error that names none of those three things.
///
/// Throwing forces the refusal to be handled, and carrying [refusal] makes the
/// reason something a caller can record on the work item, assert against in a
/// test, or escalate. It is `implements Exception` rather than `extends
/// StateError` so that it is caught deliberately by name and does not
/// accidentally join a broad `catch (e)` that treats every internal fault as
/// "the product has no contract".
class ProductQAContractSpecUnavailable implements Exception {
  const ProductQAContractSpecUnavailable({
    required this.productId,
    required this.refusal,
    this.workItemId,
  });

  final String productId;

  /// Which of the named reasons applies. Never null and never a catch-all.
  final ProductQAContractSpecRefusal refusal;

  /// The work item the contract was being provisioned for, when the caller knows
  /// it. Recorded so a log line and a work-item metadata key can both name the
  /// item that cannot complete, rather than only the product.
  final String? workItemId;

  @override
  String toString() {
    final item = workItemId == null ? '' : ' for work item $workItemId';
    final detail = switch (refusal) {
      ProductQAContractSpecRefusal.notDeclared =>
        'no declared QA contract: this product has never registered a '
            'contracts.qaContract, so there is nothing to provision from',
      ProductQAContractSpecRefusal.declaresNoGates =>
        'the declared QA contract names no gates, which constrains nothing and '
            'would satisfy qaContractExists() without admitting anything',
    };
    return 'ProductQAContractSpecUnavailable: product $productId$item cannot '
        'produce a QA contract because $detail';
  }
}

import 'package:meta/meta.dart';

/// The context key `GuardConditions.designContractExists()` reads its answer
/// from.
///
/// ## WHY A KEY, AND NOT A PARAMETER
///
/// The guard this type exists for is constructed at exactly one site,
/// `work_item_transitions.dart`:
/// `GuardConditions.designContractExists()` — no arguments, because the
/// transition table is a `static final` built from pure rule lists and nothing
/// that carries a database handle may be handed to it at construction. That
/// rules out injecting a store into the guard itself, and it is why the store
/// lookup happens in `DurableWorkflowEngine.transition` instead: the durable
/// engine is the one component that holds BOTH facts the guard needs — the
/// `WorkItem` it has just read, and a `DesignContractStore` — and it is the one
/// component whose rejection is not merely advisory, because it refuses the
/// write.
///
/// ## WHY PLANTING THIS KEY IS INERT
///
/// The key is public, so a caller *can* plant it. It changes nothing, and the
/// reason is ordering rather than secrecy: `DurableWorkflowEngine.transition`
/// writes this key **after** spreading the caller's map, so the engine's own
/// value is the one that survives. A caller that plants
/// `{designContractResolutionContextKey: <confirmed>}` gets its value discarded
/// and the guard reads the column and the store instead.
///
/// That is the whole of the fix for the falsifier `design-revision.md` §4.3
/// names — a caller passing `context: {'designContractId': 'anything'}` on an
/// item whose column is NULL. Before, the guard read that string and passed.
/// Now the string is not read at all.
const String designContractResolutionContextKey =
    'durableDesignContractResolution';

/// The durable, store-confirmed answer to "does this work item have a design
/// contract?", carried into the guards through
/// [designContractResolutionContextKey].
///
/// ## WHAT IT IS NOT
///
/// It is not a `String?` id. `context['designContractId']` being non-null was
/// the defect: a `designContractId` names a row, and a name is not a row. The
/// distinction this type carries is precisely that one — [contractId] is what
/// the work item says, [storeConfirmed] is whether anything behind it
/// answered — and [isConfirmed] refuses to collapse them.
///
/// ## FAIL-CLOSED BY CONSTRUCTION
///
/// [isConfirmed] is a conjunction, not a disjunction, and neither field is
/// defaulted in a way that can make it true. A [DesignContractResolution] that
/// was never built at all — the pure `WorkflowEngine` path, which has no store
/// and no item — is `null` in the context, which the guard treats as a refusal
/// and names as one. "Cannot confirm" and "confirmed" are different verdicts,
/// and only one of them opens the edge.
@immutable
class DesignContractResolution {
  const DesignContractResolution({
    required this.contractId,
    required this.storeConfirmed,
  });

  /// The work item's `designContractId` column is NULL: there is nothing to
  /// confirm and nothing was asked.
  const DesignContractResolution.noContract()
    : contractId = null,
      storeConfirmed = false;

  /// `WorkItem.designContractId`, verbatim — including when it is null.
  final String? contractId;

  /// Whether a [DesignContractStore.hasDesignContract] lookup for [contractId]
  /// returned true. `false` covers BOTH "no store is mounted to ask" and "the
  /// store was asked and holds no such row", because a caller that cannot
  /// distinguish them must not be able to act on the difference.
  final bool storeConfirmed;

  /// The only value the guard treats as a design contract existing.
  bool get isConfirmed => contractId != null && storeConfirmed;

  @override
  String toString() =>
      'DesignContractResolution(contractId: $contractId, '
      'storeConfirmed: $storeConfirmed)';
}

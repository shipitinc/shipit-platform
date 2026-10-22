/// THE DESIGN SCOPE GRANT — the per-lane owned-path grant, recorded at the
/// design/plan acceptance.
///
/// ## WHAT THIS IS
///
/// Decision `7d2a81f0` (`.decisions/f2-grant-origin.md`) settled WHERE a
/// lane's owned-path grant comes from: *"the work item's planner or designer
/// records the owned globs when the item is scoped"*, and the grant *"is
/// recorded as a durable fact of the work item and read at dispatch — never
/// reconstructed from the diff, and never the work's own claim about what it
/// will touch"*.
///
/// The dispatch-time half of that already exists: the implementation lane's
/// request builder reads the work item's metadata
/// (`implementation_path_ownership.dart:49`) and the coordinator captures the
/// grant into the durable execution record (`execution_coordinator.dart:613`).
/// What did not exist was a PRODUCER. Every F2 evaluation in production
/// refused, because nothing ever wrote a grant to read — ledger F-215.
///
/// ## THE TWO RECORDS, AND WHY THEY ARE NOT ONE
///
/// The grant travels through two durable records on its way from the designer
/// to the QA gate, and they are deliberately different:
///
///  1. the DESIGN DECISION's metadata — the **declaration**: what the scoping
///     lane proposed, written when the plan was submitted for approval. It is
///     a proposal, and a proposal is not yet a fact about the work item.
///  2. the WORK ITEM's metadata — the **grant**: the declaration, recorded as a
///     fact, at the moment the plan was accepted.
///
/// The promotion from (1) to (2) is the acceptance, and it happens once. That
/// ordering is what makes the grant a grant rather than a claim: the copy is
/// made by the human-governed step, not by the lane whose scope it is.
///
/// ## WHY THE GRANT IS NOT A NEW KEY
///
/// The grant itself is written under the SHARED key
/// (`declaredOwnedPathsMetadataKey`, `'declaredOwnedPaths'`) that the dispatch
/// reader and the QA gate's production source already spell the same way. A
/// second key would need a second reader, and a second reader is a second
/// place for the two ends to disagree — which is the exact failure the shared
/// key exists to prevent (`lane_path_ownership.dart:17-25`).
///
/// The provenance of the grant — who scoped it, under which decision, when —
/// is kept under a SEPARATE key ([designScopeGrantProvenanceKey]), because
/// provenance is not the grant and must never be read as one.
///
/// ## WHY AN EMPTY DECLARATION IS NOT A GRANT
///
/// A declaration of zero paths is not a grant of zero paths; it is the absence
/// of a grant. The gate refuses an empty owned set either way, so recording it
/// as a grant would put a key on the work item that reads as a grant while
/// granting nothing. Decision `7d2a81f0` says it plainly:
/// *"An item with no recorded grant stays refused."* So an empty declaration
/// records an EMPTY scope and NO grant provenance.
///
/// It does still record the empty scope, because the design/plan acceptance is
/// where the scope is authored and its value is the authoritative one — see
/// [designScopeGrantMetadata].
///
/// ## WHAT IS NOT HERE
///
/// No default globs. No per-category fallback. No widening at dispatch. Those
/// are the three ways this gate becomes a tautology, and decision `7d2a81f0`
/// refused all three: *"A per-category default wide enough to cover most work
/// is a default that confines nothing"*, and *"Do not add a fallback that
/// widens the grant at dispatch time."*
library;

import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart' show HumanDecisionRouting;

// ---------------------------------------------------------------------------
// THE PROVENANCE KEYS
// ---------------------------------------------------------------------------

/// The metadata key under which a DESIGN/PLAN SUBMISSION records who scoped
/// the work.
///
/// On the decision record this is a DECLARATION — a proposal, pending
/// approval. On the work item it is a GRANT — a fact, accepted. The two live
/// under different keys ([designScopeDeclarationProvenanceKey] here,
/// [designScopeGrantProvenanceKey] there) so a reader can tell a proposal from
/// an accepted fact by the key alone, without having to know which record it
/// is holding.
const String designScopeDeclarationProvenanceKey = 'designScopeDeclaration';

/// The metadata key under which the WORK ITEM records the provenance of the
/// grant it carries.
///
/// Deliberately not the grant: the grant is under the shared
/// `declaredOwnedPathsMetadataKey`, and this key answers a different question
/// — *who said so, and when*.
const String designScopeGrantProvenanceKey = 'designScopeGrant';

// ---------------------------------------------------------------------------
// THE ACCEPTANCE
// ---------------------------------------------------------------------------

/// Whether resolving a [decisionType] with a [choice] is a DESIGN/PLAN
/// ACCEPTANCE.
///
/// ## WHY IT ASKS THE ROUTING TABLE
///
/// The acceptance is the state the item LANDS on, not a property of the
/// decision type: `designApproval/approve` and `designReviewRequest/approve`
/// both land on [WorkItemState.designApproved], and every other pair lands
/// somewhere else. Naming the two types here would be a second copy of the
/// routing table, and a second copy is a second place for the two to disagree.
///
/// So this asks [HumanDecisionRouting.targetFor] — the same function the engine
/// uses to decide where the item goes. If the routing table moves, this moves
/// with it, and the grant can never be recorded at a resolution that does not
/// release the item, nor missed at one that does.
///
/// ## WHAT IT IS NOT
///
/// It is not "the design lane's decision". A `designApproval` REJECTED is not
/// an acceptance, and a `qaWaiver` approved is not an acceptance. Only the
/// pair that routes to [WorkItemState.designApproved] qualifies.
bool isDesignPlanAcceptance({
  required HumanDecisionType decisionType,
  required HumanDecisionChoice choice,
}) {
  return HumanDecisionRouting.targetFor(decisionType, choice) ==
      WorkItemState.designApproved;
}

/// The menu a design/plan approval offers by default.
///
/// Two answers, and their `optionId`s are the WIRE values of the choices the
/// routing table understands — `approve` lands on [WorkItemState.designApproved]
/// and `reject` lands on [WorkItemState.designRejected] — so the option the
/// operator picks and the state the item lands on cannot drift apart.
///
/// `rework` is deliberately NOT offered here. It routes back to
/// [WorkItemState.designInReview], which no `JobDefinition` dispatches, so
/// offering it would put a button on a screen that leads nowhere. The
/// `designReviewRequest` type carries the wider park menu, and a caller that
/// wants that menu passes its own options.
const List<HumanDecisionOption> designApprovalOptions = [
  HumanDecisionOption(
    optionId: 'approve',
    label: 'Approve this plan',
    description:
        'The plan is scoped and the declared owned paths are recorded as the '
        "lane's grant. The work item may be implemented within them.",
  ),
  HumanDecisionOption(
    optionId: 'reject',
    label: 'Send the plan back',
    description:
        'The plan is not accepted. The work item is sent back to design and no '
        'grant is recorded.',
  ),
];

// ---------------------------------------------------------------------------
// THE DECLARATION (the design decision's side)
// ---------------------------------------------------------------------------

/// The paths a scoping lane DECLARED, read out of a design decision's own
/// metadata.
///
/// Reads the shared key through the shared reader
/// ([declaredOwnedPathsFromMetadata]), so a declaration that is absent, empty,
/// or malformed reads as NO DECLARATION — never as a partial one, and never as
/// a wider one. A malformed declaration is a fact about the record, and the
/// honest reading of it is "this names no paths".
List<String> declaredOwnedPathsFromDesignDecision(HumanDecision decision) {
  return declaredOwnedPathsFromMetadata(decision.metadata);
}

/// The metadata a design/plan SUBMISSION carries.
///
/// Carries the declaration under the shared key, so the promotion reads it
/// with the same reader that reads the grant, and the provenance under
/// [designScopeDeclarationProvenanceKey], so an auditor can see who scoped the
/// work without having to infer it.
///
/// [declaredBy] is required and is NOT defaulted: a grant whose author is
/// unknown is a grant nobody is accountable for, and the platform has no
/// business inventing an author for it. An empty string is refused by the
/// caller rather than recorded here.
Map<String, dynamic> designScopeDeclarationMetadata({
  required List<String> declaredOwnedPaths,
  required HumanDecisionType decisionType,
  required String declaredBy,
  required DateTime declaredAt,
}) {
  return <String, dynamic>{
    ...declaredOwnedPathsMetadata(declaredOwnedPaths),
    designScopeDeclarationProvenanceKey: <String, dynamic>{
      'declaredOwnedPaths': List<String>.unmodifiable(declaredOwnedPaths),
      'decisionType': decisionType.wire,
      'declaredBy': declaredBy,
      'declaredAt': declaredAt.toUtc().toIso8601String(),
    },
  };
}

// ---------------------------------------------------------------------------
// THE GRANT (the work item's side)
// ---------------------------------------------------------------------------

/// The metadata recorded on the WORK ITEM when a design/plan is accepted.
///
/// Carries the grant under the shared key — the key the dispatch reader and
/// the QA gate's production source already read — and the provenance of the
/// acceptance under [designScopeGrantProvenanceKey].
///
/// ## THE OWNED-PATHS KEY IS WRITTEN WHATEVER THE DECLARATION SAYS
///
/// Always, including when the declaration is empty. The design/plan
/// acceptance is where the scope is AUTHORED, so its value is the
/// authoritative one: an item that arrived carrying a scope from some earlier
/// step has that scope REPLACED here, not merely supplemented.
///
/// That direction matters. An earlier step that guessed a wide scope — the
/// intake form, whose requester does not know the path layout — must not
/// survive the acceptance, or the effective grant would originate at intake
/// and decision `7d2a81f0` would not have been implemented at all. Replacing
/// a wide scope with a narrow one cannot widen anything; leaving it would.
///
/// ## THE PROVENANCE IS WRITTEN ONLY WHEN A GRANT WAS MADE
///
/// An empty declaration is the ABSENCE of a grant, not a grant of nothing, so
/// there is no grant for a provenance to describe. The item then carries an
/// empty owned set and no [designScopeGrantProvenanceKey] — which the gate
/// refuses, which is the fail-closed direction the decision preserved.
Map<String, dynamic> designScopeGrantMetadata({
  required List<String> declaredOwnedPaths,
  required HumanDecisionType decisionType,
  required String decisionId,
  required String declaredBy,
  required DateTime grantedAt,
}) {
  final metadata = <String, dynamic>{
    ...declaredOwnedPathsMetadata(declaredOwnedPaths),
  };
  if (declaredOwnedPaths.isEmpty) return metadata;
  metadata[designScopeGrantProvenanceKey] = <String, dynamic>{
    'declaredOwnedPaths': List<String>.unmodifiable(declaredOwnedPaths),
    'decisionType': decisionType.wire,
    'decisionId': decisionId,
    'declaredBy': declaredBy,
    'grantedAt': grantedAt.toUtc().toIso8601String(),
  };
  return metadata;
}

/// Merges [grant] into the work item's existing [metadata].
///
/// MERGED, never replacing: the work item's metadata carries the plan
/// (`acceptanceCriteria`), the producer identity (`producerActorId`), the
/// triage marker and the escalation index, and a promotion that replaced the
/// map would erase the plan the implementation lane is about to be given. The
/// grant's own keys win over the ones already present, because the grant is
/// the later, more specific fact.
Map<String, dynamic> mergeDesignScopeGrant(
  Map<String, dynamic>? metadata,
  Map<String, dynamic> grant,
) {
  final merged = Map<String, dynamic>.from(metadata ?? const {});
  merged.addAll(grant);
  return merged;
}

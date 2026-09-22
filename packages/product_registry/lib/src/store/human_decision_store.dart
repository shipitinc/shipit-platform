import 'package:platform_contracts/platform_contracts.dart';

/// Narrow persistence port to the **authoritative** [HumanDecision] record.
///
/// This is deliberately *not* a second authority model: it is a two-method view
/// onto the single durable HumanDecision store already owned by
/// `workflow_store` / `apps/server` (the `human_decision` table). Product
/// baseline acceptance reuses the same decision identity, choice, decider,
/// rationale, signature, and resolution-timestamp semantics as every other
/// governed human gate — it does not invent a parallel authorization scheme.
///
/// [scopeId] is the durable owning-scope key recorded in the decision's
/// `workItemId` column. Product onboarding decisions use a deterministic
/// `product-baseline:<productId>` scope because they gate a Product, not a
/// WorkItem.
abstract interface class HumanDecisionStore {
  Future<void> saveHumanDecision(HumanDecision decision);

  /// Returns null when no decision exists (rather than throwing), so callers
  /// can translate absence into a domain error.
  Future<HumanDecision?> readHumanDecision(String decisionId);

  Future<List<HumanDecision>> readHumanDecisionsForScope(String scopeId);
}

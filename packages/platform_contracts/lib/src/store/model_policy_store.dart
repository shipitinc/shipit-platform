import 'package:platform_contracts/platform_contracts.dart';

/// Durable store for [ModelPolicy] entries.
abstract interface class ModelPolicyStore {
  Future<ModelPolicy?> getPolicy(AgentRole role);

  Future<void> upsertPolicy(ModelPolicy policy);

  Future<List<ModelPolicy>> getAllPolicies();
}
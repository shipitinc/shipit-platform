import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show ModelPolicyStore, ModelPolicy, AgentRole;

/// Result of a model selection for a given role and escalation index.
@immutable
class ModelSelection {
  const ModelSelection({
    required this.modelId,
    required this.provider,
    required this.escalationIndex,
    required this.isFallback,
  });

  final String modelId;
  final String provider;
  final int escalationIndex;
  final bool isFallback;

  static ModelSelection fallback(AgentRole role) => ModelSelection(
    modelId: _fallbackModel(role),
    provider: _fallbackProvider(role),
    escalationIndex: 0,
    isFallback: true,
  );

  static String _fallbackModel(AgentRole role) => switch (role) {
    AgentRole.designAgent => 'mimo-v2.6-flash-free',
    AgentRole.designReviewer => 'mimo-v2.6-flash-free',
    AgentRole.engineeringReviewer => 'opencode/big-pickle',
    AgentRole.qaArchitect => 'opencode/big-pickle',
    AgentRole.qaExecutor => 'opencode/big-pickle',
    AgentRole.triageDefect => 'opencode/big-pickle',
    AgentRole.implementer => 'opencode/big-pickle',
    AgentRole.correctionImplementer => 'opencode/big-pickle',
    AgentRole.focusedReviewer => 'opencode/big-pickle',
    AgentRole.integrator => 'opencode/big-pickle',
    AgentRole.releaseEngineer => 'opencode/big-pickle',
    AgentRole.deploymentAuthority => 'opencode/big-pickle',
  };

  static String _fallbackProvider(AgentRole role) => switch (role) {
    AgentRole.designAgent => 'opencode',
    AgentRole.designReviewer => 'opencode',
    _ => 'opencode',
  };
}

/// Service that selects a model for a given agent role and escalation index.
class ModelSelectionService {
  ModelSelectionService(this._store);
  final ModelPolicyStore _store;
  final _cache = <AgentRole, ModelPolicy>{};

  Future<ModelSelection> select({
    required AgentRole role,
    required int escalationIndex,
  }) async {
    final policy = await _getPolicy(role);
    if (policy == null || policy.chain.isEmpty) {
      return ModelSelection.fallback(role);
    }
    final idx = escalationIndex.clamp(0, policy.chain.length - 1);
    final step = policy.chain[idx];
    return ModelSelection(
      modelId: step.modelId,
      provider: step.provider,
      escalationIndex: idx,
      isFallback: false,
    );
  }

  Future<ModelPolicy?> _getPolicy(AgentRole role) async {
    if (_cache.containsKey(role)) return _cache[role];
    final policy = await _store.getPolicy(role);
    if (policy != null) _cache[role] = policy;
    return policy;
  }

  void invalidateCache(AgentRole role) => _cache.remove(role);
}

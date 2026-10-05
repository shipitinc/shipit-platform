import 'package:platform_contracts/platform_contracts.dart';

/// In-memory implementation of [ModelPolicyStore] for testing.
class InMemoryModelPolicyStore implements ModelPolicyStore {
  InMemoryModelPolicyStore() {
    _policies[AgentRole.designAgent] = ModelPolicy(
      role: AgentRole.designAgent,
      chain: const [
        ModelStep(modelId: 'mimo-v2.6-flash-free', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.designReviewer] = ModelPolicy(
      role: AgentRole.designReviewer,
      chain: const [
        ModelStep(modelId: 'mimo-v2.6-flash-free', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.implementer] = ModelPolicy(
      role: AgentRole.implementer,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.engineeringReviewer] = ModelPolicy(
      role: AgentRole.engineeringReviewer,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.qaArchitect] = ModelPolicy(
      role: AgentRole.qaArchitect,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.qaExecutor] = ModelPolicy(
      role: AgentRole.qaExecutor,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.triageDefect] = ModelPolicy(
      role: AgentRole.triageDefect,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.correctionImplementer] = ModelPolicy(
      role: AgentRole.correctionImplementer,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.focusedReviewer] = ModelPolicy(
      role: AgentRole.focusedReviewer,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.integrator] = ModelPolicy(
      role: AgentRole.integrator,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.releaseEngineer] = ModelPolicy(
      role: AgentRole.releaseEngineer,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
    _policies[AgentRole.deploymentAuthority] = ModelPolicy(
      role: AgentRole.deploymentAuthority,
      chain: const [
        ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
      ],
      version: 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedByDecisionId: 'test-decision',
    );
  }

  final _policies = <AgentRole, ModelPolicy>{};

  @override
  Future<ModelPolicy?> getPolicy(AgentRole role) async => _policies[role];

  @override
  Future<void> upsertPolicy(ModelPolicy policy) async => _policies[policy.role] = policy;

  @override
  Future<List<ModelPolicy>> getAllPolicies() async => _policies.values.toList(growable: false);

  void addPolicy(ModelPolicy policy) => _policies[policy.role] = policy;
  void clear() => _policies.clear();
}

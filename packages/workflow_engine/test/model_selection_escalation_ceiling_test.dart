import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// [ModelSelectionService.escalationCeilingFor] — the bound for AUTOMATIC
/// provider-failure escalation. It is the chain length minus one, never the
/// decision-type guard, and a role with no policy (single configured
/// default step) has a ceiling of zero: nothing to escalate TO.
void main() {
  test('ceiling is chain length minus one', () async {
    final store = InMemoryModelPolicyStore();
    store.addPolicy(
      ModelPolicy(
        role: AgentRole.implementer,
        chain: const [
          ModelStep(modelId: 'a/free', provider: 'opencode'),
          ModelStep(modelId: 'a/paid', provider: 'opencode'),
          ModelStep(modelId: 'a/premium', provider: 'opencode'),
        ],
        version: 1,
        updatedAt: DateTime.utc(2026, 1, 1),
        updatedByDecisionId: 'test',
      ),
    );
    expect(
      await ModelSelectionService(
        store,
      ).escalationCeilingFor(AgentRole.implementer),
      2,
    );
  });

  test(
    'a single-step chain has ceiling zero — nothing to escalate to',
    () async {
      final store = InMemoryModelPolicyStore();
      expect(
        await ModelSelectionService(
          store,
        ).escalationCeilingFor(AgentRole.implementer),
        0,
      );
    },
  );

  test('no policy at all has ceiling zero', () async {
    final store = InMemoryModelPolicyStore()..clear();
    expect(
      await ModelSelectionService(
        store,
      ).escalationCeilingFor(AgentRole.implementer),
      0,
    );
  });
}

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// `model_policy` was empty, so every role silently inherited a hardcoded
/// fallback: `mimo-v2.6-flash-free` for design roles and `opencode/big-pickle`
/// for everything else. Decision `2fe73e11` replaced that guess with one
/// operator-configured default, `opencode/space-bunny-free`, applied for every
/// role.
void main() {
  group('the configured default is the operator-configured model', () {
    test('every agent role selects it when no policy row exists', () async {
      final service = ModelSelectionService(_EmptyModelPolicyStore());

      for (final role in AgentRole.values) {
        final selection = await service.select(role: role, escalationIndex: 0);
        expect(
          selection.modelId,
          'opencode/space-bunny-free',
          reason: 'role $role',
        );
        expect(selection.provider, 'opencode');
      }
    });

    test(
      'the id is provider-qualified, which is the form the runtime requires',
      () async {
        // The opencode adapter sends this string verbatim as the `value` of
        // `session/set_config_option` with `configId: 'model'`, whose contract
        // is `<provider>/<model>`. An unqualified id is rejected by the runtime
        // with -32602 "model not found", so this is a wire contract and not a
        // naming preference.
        final service = ModelSelectionService(_EmptyModelPolicyStore());
        final selection = await service.select(
          role: AgentRole.implementer,
          escalationIndex: 0,
        );

        expect(selection.modelId, contains('/'));
        final parts = selection.modelId.split('/');
        expect(
          parts,
          hasLength(2),
          reason: 'expected exactly <provider>/<model>',
        );
        expect(parts.first, isNotEmpty);
        expect(parts.last, isNotEmpty);
      },
    );

    test('the unqualified id the operator named is NOT what ships, because the '
        'runtime cannot resolve it', () async {
      final service = ModelSelectionService(_EmptyModelPolicyStore());
      final selection = await service.select(
        role: AgentRole.designAgent,
        escalationIndex: 0,
      );

      expect(selection.modelId, isNot('space-bunny-free'));
      expect(selection.modelId, 'opencode/space-bunny-free');
    });

    test('the design roles no longer diverge from the rest', () async {
      final service = ModelSelectionService(_EmptyModelPolicyStore());

      final design = await service.select(
        role: AgentRole.designAgent,
        escalationIndex: 0,
      );
      final implementer = await service.select(
        role: AgentRole.implementer,
        escalationIndex: 0,
      );

      expect(design.modelId, implementer.modelId);
    });

    test('the default is reported as a default, not as a decision', () async {
      final service = ModelSelectionService(_EmptyModelPolicyStore());
      final selection = await service.select(
        role: AgentRole.implementer,
        escalationIndex: 0,
      );

      expect(selection.isFallback, isTrue);
      expect(selection.source, ModelSelectionSource.configuredDefault);
    });

    test(
      'the default carries the decision that produced it, so the constant is '
      'not an unattributed guess',
      () {
        expect(kConfiguredDefaultDecisionId, contains('2fe73e11'));
        expect(kConfiguredDefaultModelId, 'opencode/space-bunny-free');
      },
    );
  });

  group('a durable policy row overrides the default', () {
    test('the row wins and is reported as a policy, not a fallback', () async {
      final store = _EmptyModelPolicyStore();
      await store.upsertPolicy(
        ModelPolicy(
          role: AgentRole.implementer,
          chain: const [
            ModelStep(modelId: 'opencode/big-pickle', provider: 'opencode'),
          ],
          version: 7,
          updatedAt: DateTime.utc(2026, 1, 1),
          updatedByDecisionId: 'other-decision',
        ),
      );
      final service = ModelSelectionService(store);

      final selection = await service.select(
        role: AgentRole.implementer,
        escalationIndex: 0,
      );

      expect(selection.modelId, 'opencode/big-pickle');
      expect(selection.isFallback, isFalse);
      expect(selection.source, ModelSelectionSource.policy);
    });

    test(
      'the override is per role, so tuning one role does not move others',
      () async {
        final store = _EmptyModelPolicyStore();
        await store.upsertPolicy(
          ModelPolicy(
            role: AgentRole.qaExecutor,
            chain: const [
              ModelStep(
                modelId: 'opencode/step-5-preview-free',
                provider: 'opencode',
              ),
            ],
            version: 1,
            updatedAt: DateTime.utc(2026, 1, 1),
            updatedByDecisionId: 'other-decision',
          ),
        );
        final service = ModelSelectionService(store);

        final qa = await service.select(
          role: AgentRole.qaExecutor,
          escalationIndex: 0,
        );
        final impl = await service.select(
          role: AgentRole.implementer,
          escalationIndex: 0,
        );

        expect(qa.modelId, 'opencode/step-5-preview-free');
        expect(impl.modelId, 'opencode/space-bunny-free');
      },
    );
  });

  group('seeding makes the default durable without a migration', () {
    test(
      'it populates every role, after which nothing is a fallback',
      () async {
        final store = _EmptyModelPolicyStore();
        final service = ModelSelectionService(store);

        final written = await service.seedConfiguredDefault(
          now: DateTime.utc(2026, 1, 1),
        );

        expect(written.toSet(), AgentRole.values.toSet());
        expect(
          await store.getAllPolicies(),
          hasLength(AgentRole.values.length),
        );

        // A fresh service reads the durable rows, so this is no longer a guess
        // made at runtime.
        final reread = ModelSelectionService(store);
        final selection = await reread.select(
          role: AgentRole.implementer,
          escalationIndex: 0,
        );
        expect(selection.modelId, 'opencode/space-bunny-free');
        expect(selection.isFallback, isFalse);
        expect(selection.source, ModelSelectionSource.policy);
      },
    );

    test('every seeded row records the decision that authorised it', () async {
      final store = _EmptyModelPolicyStore();
      await ModelSelectionService(
        store,
      ).seedConfiguredDefault(now: DateTime.utc(2026, 1, 1));

      for (final policy in await store.getAllPolicies()) {
        expect(policy.updatedByDecisionId, contains('2fe73e11'));
        expect(policy.chain.single.modelId, 'opencode/space-bunny-free');
        expect(policy.chain.single.provider, 'opencode');
      }
    });

    test(
      'it never overwrites an existing policy, so tuning survives a restart',
      () async {
        final store = _EmptyModelPolicyStore();
        await store.upsertPolicy(
          ModelPolicy(
            role: AgentRole.implementer,
            chain: const [
              ModelStep(
                modelId: 'anthropic/claude-sonnet-5',
                provider: 'anthropic',
              ),
            ],
            version: 3,
            updatedAt: DateTime.utc(2026, 1, 1),
            updatedByDecisionId: 'operator-tuning',
          ),
        );

        final written = await ModelSelectionService(
          store,
        ).seedConfiguredDefault(now: DateTime.utc(2026, 1, 1));

        expect(written, isNot(contains(AgentRole.implementer)));
        final kept = await store.getPolicy(AgentRole.implementer);
        expect(kept!.chain.single.modelId, 'anthropic/claude-sonnet-5');
        expect(kept.version, 3);
      },
    );

    test('it is idempotent: a second call writes nothing new', () async {
      final store = _EmptyModelPolicyStore();
      final service = ModelSelectionService(store);

      final first = await service.seedConfiguredDefault(
        now: DateTime.utc(2026, 1, 1),
      );
      final second = await service.seedConfiguredDefault(
        now: DateTime.utc(2026, 2, 1),
      );

      expect(first, hasLength(AgentRole.values.length));
      expect(second, isEmpty);
      expect(await store.getAllPolicies(), hasLength(AgentRole.values.length));
    });
  });
}

/// A policy store that models the production state this fix was written
/// against: `model_policy` with zero rows.
class _EmptyModelPolicyStore implements ModelPolicyStore {
  final _policies = <AgentRole, ModelPolicy>{};

  @override
  Future<ModelPolicy?> getPolicy(AgentRole role) async => _policies[role];

  @override
  Future<void> upsertPolicy(ModelPolicy policy) async =>
      _policies[policy.role] = policy;

  @override
  Future<List<ModelPolicy>> getAllPolicies() async => _policies.values.toList();
}

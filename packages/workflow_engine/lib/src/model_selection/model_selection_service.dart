import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show ModelPolicyStore, ModelPolicy, ModelStep, AgentRole;

/// The operator-configured default model, decided in human decision
/// `2fe73e11-6c3d-4bb8-98c5-90fd5c303847` ("Fix the class - timeout, liveness,
/// model policy") and applied here because `model_policy` is empty.
///
/// It is fully qualified as `opencode/space-bunny-free` because that is the
/// form the runtime requires, not a stylistic choice. The opencode adapter
/// sends this string verbatim as the `value` of the `session/set_config_option`
/// request with `configId: 'model'`, whose contract is `<provider>/<model>`; an
/// id that is not in that form is rejected by the runtime with `-32602 "model
/// not found"`. The bare `space-bunny-free` is therefore NOT a valid value,
/// and the previous per-role fallback for design roles (`mimo-v2.6-flash-free`,
/// unqualified) was in that broken form and would have been rejected the same
/// way.
///
/// Verified against the runtime that will execute it rather than assumed:
/// `opencode models` on the QA server's opencode 1.18.35 lists
/// `opencode/space-bunny-free`, and the adapter only reports a model as in
/// force when the runtime echoes that exact value back in `configOptions`.
///
/// This constant is a DEFAULT, not the policy. A `model_policy` row for the
/// role overrides it with no redeploy and no schema change; that is the
/// operator's stated reason for preferring an explicit policy over a silent
/// hardcoded guess.
const String kConfiguredDefaultModelId = 'opencode/space-bunny-free';

/// The provider half of [kConfiguredDefaultModelId]. Kept beside the model id
/// rather than derived from it so the two cannot drift apart by accident.
const String kConfiguredDefaultModelProvider = 'opencode';

/// The decision that fixed [kConfiguredDefaultModelId] as the platform default.
/// Persisted onto seeded `model_policy` rows so an auditor can find the
/// provenance from the row itself rather than from this source file.
const String kConfiguredDefaultDecisionId =
    '2fe73e11-6c3d-4bb8-98c5-90fd5c303847';

/// Where a [ModelSelection] came from, so a default is never mistaken for a
/// decision the operator made about that role.
enum ModelSelectionSource {
  /// A durable `model_policy` row for the role was used.
  policy,

  /// No `model_policy` row existed, so [kConfiguredDefaultModelId] was used.
  configuredDefault,
}

/// Result of a model selection for a given role and escalation index.
@immutable
class ModelSelection {
  const ModelSelection({
    required this.modelId,
    required this.provider,
    required this.escalationIndex,
    required this.isFallback,
    this.source = ModelSelectionSource.policy,
  });

  final String modelId;
  final String provider;
  final int escalationIndex;
  final bool isFallback;

  /// Whether this selection came from a durable policy row or from the
  /// operator-configured default. Carried on the selection itself so the
  /// distinction survives into the dispatch runtime config and the audit tail.
  final ModelSelectionSource source;

  /// The selection used when no `model_policy` row exists for [role].
  ///
  /// One model for every role, deliberately. The decision recorded
  /// `space-bunny-free` for every agent role, and the per-role split this
  /// replaces was itself part of the defect: it was a guess made silently at
  /// runtime, it could not be tuned without a redeploy, and its design-role
  /// entry was not a model id the runtime could resolve.
  static ModelSelection fallback(AgentRole role) => ModelSelection(
    modelId: kConfiguredDefaultModelId,
    provider: kConfiguredDefaultModelProvider,
    escalationIndex: 0,
    isFallback: true,
    source: ModelSelectionSource.configuredDefault,
  );
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

  /// The largest escalation index [role]'s chain can serve:
  /// `chain.length - 1`, or 0 when no policy exists (the configured default
  /// is a single step, so there is nothing to escalate TO).
  ///
  /// Read by the scheduler's automatic provider-failure escalation, whose
  /// bound is the chain itself — deliberately NOT the
  /// `escalationIndexWithinLimit` decision-type guard, which bounds the
  /// human-decision escalation path. An index already at this ceiling is at
  /// the top of the chain, which is where automatic escalation stops.
  Future<int> escalationCeilingFor(AgentRole role) async {
    final policy = await _getPolicy(role);
    if (policy == null || policy.chain.isEmpty) return 0;
    return policy.chain.length - 1;
  }

  /// Writes the operator-configured default into `model_policy` for every
  /// agent role, so the default becomes durable, auditable and tunable through
  /// the table rather than living only as a constant.
  ///
  /// Deliberately NOT a migration: this changes no schema, and a role that
  /// already has a policy row is left alone so an operator's later tuning is
  /// never overwritten by a restart. Safe to call repeatedly.
  ///
  /// Returns the roles this call actually wrote.
  Future<List<AgentRole>> seedConfiguredDefault({
    DateTime? now,
    int version = 1,
  }) async {
    final at = now ?? DateTime.now().toUtc();
    final written = <AgentRole>[];
    for (final role in AgentRole.values) {
      if (await _store.getPolicy(role) != null) continue;
      await _store.upsertPolicy(
        ModelPolicy(
          role: role,
          chain: const [
            ModelStep(
              modelId: kConfiguredDefaultModelId,
              provider: kConfiguredDefaultModelProvider,
            ),
          ],
          version: version,
          updatedAt: at,
          updatedByDecisionId: kConfiguredDefaultDecisionId,
        ),
      );
      written.add(role);
    }
    return written;
  }

  Future<ModelPolicy?> _getPolicy(AgentRole role) async {
    if (_cache.containsKey(role)) return _cache[role];
    final policy = await _store.getPolicy(role);
    if (policy != null) _cache[role] = policy;
    return policy;
  }

  void invalidateCache(AgentRole role) => _cache.remove(role);
}

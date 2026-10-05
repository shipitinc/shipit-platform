import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show
        ModelPolicyStore,
        ModelPolicy,
        AgentRole,
        HumanDecision,
        HumanDecisionType,
        HumanDecisionStatus,
        HumanDecisionOption,
        DecisionContext;
import 'package:workflow_store/workflow_store.dart';

/// Periodically probes providers from model policies and raises human decisions
/// when providers are unavailable or when all providers for a role are down.
class ProviderHealthMonitor {
  ProviderHealthMonitor({
    required ModelPolicyStore modelPolicyStore,
    required WorkflowStore workflowStore,
    required HumanDecisionStore humanDecisionStore,
    this.checkInterval = const Duration(minutes: 5),
    this.probeTimeout = const Duration(seconds: 30),
  }) : _modelPolicyStore = modelPolicyStore,
       _workflowStore = workflowStore,
       _humanDecisionStore = humanDecisionStore;

  final ModelPolicyStore _modelPolicyStore;
  final WorkflowStore _workflowStore;
  final HumanDecisionStore _humanDecisionStore;
  final Duration checkInterval;
  final Duration probeTimeout;

  final Map<String, ProviderHealth> _providerHealth = {};
  final Map<AgentRole, AllProvidersDownTicket> _allProvidersDownTickets = {};

  Timer? _timer;

  /// Starts periodic health checks.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(checkInterval, (_) => checkAll());
    // Run immediately on start
    unawaited(checkAll());
  }

  /// Stops periodic health checks.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Checks all providers from all model policies.
  Future<void> checkAll() async {
    final policies = await _modelPolicyStore.getAllPolicies();
    final providers = <String>{};
    for (final p in policies) {
      for (final step in p.chain) {
        providers.add(step.provider);
      }
    }

    for (final provider in providers) {
      final healthy = await _probeProvider(provider);
      _providerHealth[provider] = ProviderHealth(
        provider: provider,
        healthy: healthy,
        lastChecked: DateTime.now().toUtc(),
      );
      if (!healthy) {
        await _createProviderTicket(provider);
      }
    }

    await _checkAllProvidersDown(policies);
  }

  /// Returns current health status for all known providers.
  Map<String, ProviderHealth> getProviderHealth() {
    return Map.unmodifiable(_providerHealth);
  }

  /// Returns active AllProvidersDown tickets.
  Map<AgentRole, AllProvidersDownTicket> getAllProvidersDownTickets() {
    return Map.unmodifiable(_allProvidersDownTickets);
  }

  /// Checks if a task type (role) has an active AllProvidersDown ticket.
  bool hasAllProvidersDown(AgentRole role) {
    return _allProvidersDownTickets.containsKey(role);
  }

  Future<bool> _probeProvider(String provider) async {
    final apiKey =
        Platform.environment['OPENCODE_${provider.toUpperCase()}_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return false;
    }

    final process = await Process.start(
      'opencode',
      ['--provider', provider, 'models'],
      environment: {...Platform.environment, 'OPENCODE_API_KEY': apiKey},
      runInShell: true,
    );

    try {
      final result = await process.exitCode.timeout(
        probeTimeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigterm);
          throw TimeoutException('Provider probe timed out', probeTimeout);
        },
      );
      return result == 0;
    } on TimeoutException {
      return false;
    } on Object {
      return false;
    }
  }

  Future<void> _createProviderTicket(String provider) async {
    final existing = await _findExistingProviderTicket(provider);
    if (existing != null && existing.status == HumanDecisionStatus.pending) {
      return;
    }

    final decision = HumanDecision(
      decisionId:
          'hd-provider-$provider-${DateTime.now().microsecondsSinceEpoch}',
      workItemId: 'system:provider-health',
      decisionType: HumanDecisionType.infrastructureDecision,
      status: HumanDecisionStatus.pending,
      question: 'Provider $provider is unavailable',
      context: DecisionContext(
        workflowState: 'provider_unavailable',
        availableOptions: const ['acknowledge', 'investigate'],
      ),
      options: const [
        HumanDecisionOption(
          optionId: 'acknowledge',
          label: 'Acknowledge',
          description: 'Mark as acknowledged, will re-check on next cycle',
          recommended: true,
        ),
        HumanDecisionOption(
          optionId: 'investigate',
          label: 'Investigate',
          description: 'Open investigation into provider failure',
        ),
      ],
      recommendation: 'acknowledge',
      blocking: false,
      requestedAt: DateTime.now().toUtc(),
      metadata: {
        'provider': provider,
        'error': 'Probe failed: 401/403/credit error/timeout',
        'dismissible': true,
      },
      updatedAt: DateTime.now().toUtc(),
    );

    await _humanDecisionStore.saveHumanDecision(decision);
  }

  Future<HumanDecision?> _findExistingProviderTicket(String provider) async {
    try {
      final decisions = await _workflowStore.readHumanDecisionsForWorkItem(
        'system:provider-health',
      );
      return decisions.firstWhere(
        (d) =>
            d.decisionType == HumanDecisionType.infrastructureDecision &&
            d.metadata?['provider'] == provider &&
            d.status == HumanDecisionStatus.pending,
        orElse: () => throw StateError('not found'),
      );
    } on StateError {
      return null;
    }
  }

  Future<void> _checkAllProvidersDown(List<ModelPolicy> policies) async {
    for (final policy in policies) {
      final allDown = policy.chain.every(
        (step) => _providerHealth[step.provider]?.healthy == false,
      );

      if (allDown && policy.chain.isNotEmpty) {
        final existing = _allProvidersDownTickets[policy.role];
        if (existing != null && !existing.resolved) {
          continue;
        }

        final downProviders = policy.chain.map((s) => s.provider).toList();

        final decision = HumanDecision(
          decisionId:
              'hd-all-down-${policy.role.wire}-${DateTime.now().microsecondsSinceEpoch}',
          workItemId: 'system:provider-health',
          decisionType: HumanDecisionType.infrastructureDecision,
          status: HumanDecisionStatus.pending,
          question: 'All providers for ${policy.role.wire} are unavailable',
          context: DecisionContext(
            workflowState: 'all_providers_down',
            availableOptions: const ['acknowledge', 'escalate'],
          ),
          options: const [
            HumanDecisionOption(
              optionId: 'acknowledge',
              label: 'Acknowledge',
              description:
                  'Pause dispatch for this role until providers recover',
              recommended: true,
            ),
            HumanDecisionOption(
              optionId: 'escalate',
              label: 'Escalate',
              description: 'Escalate to on-call for immediate attention',
            ),
          ],
          recommendation: 'acknowledge',
          blocking: true,
          requestedAt: DateTime.now().toUtc(),
          metadata: {
            'role': policy.role.wire,
            'downProviders': downProviders,
            'dismissible': false,
          },
          updatedAt: DateTime.now().toUtc(),
        );

        await _humanDecisionStore.saveHumanDecision(decision);

        _allProvidersDownTickets[policy.role] = AllProvidersDownTicket(
          role: policy.role,
          decisionId: decision.decisionId,
          downProviders: downProviders,
          createdAt: decision.requestedAt!,
          resolved: false,
        );
      } else if (!allDown) {
        _allProvidersDownTickets.remove(policy.role);
      }
    }
  }
}

/// Current health status of a provider.
@immutable
class ProviderHealth {
  const ProviderHealth({
    required this.provider,
    required this.healthy,
    required this.lastChecked,
  });

  final String provider;
  final bool healthy;
  final DateTime lastChecked;
}

/// Active AllProvidersDown ticket for a role.
@immutable
class AllProvidersDownTicket {
  const AllProvidersDownTicket({
    required this.role,
    required this.decisionId,
    required this.downProviders,
    required this.createdAt,
    required this.resolved,
  });

  final AgentRole role;
  final String decisionId;
  final List<String> downProviders;
  final DateTime createdAt;
  final bool resolved;
}

/// Interface for human decision store.
abstract interface class HumanDecisionStore {
  Future<void> saveHumanDecision(HumanDecision decision);
}

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

/// The executable the agent runtime launches. Matches the default in
/// `defaultAcpTransport` (`agent_runtime/lib/src/adapters/opencode/
/// opencode_session.dart`), so the probe names the same binary the dispatch
/// path runs.
const String defaultProbeExecutable = 'opencode';

/// What one probe attempt concluded.
///
/// The distinction between [unhealthy] and [unknown] is the whole point of
/// this type and it is not cosmetic. A probe that never ran produced NO
/// evidence about the provider: it says something about the probe, not about
/// the provider. Collapsing the two is what let an absent environment variable
/// mark a working provider down and silently strand every job for its role.
enum ProviderProbeVerdict {
  /// The probe ran and the provider answered. Evidence of health.
  healthy,

  /// The probe ran and the provider failed. Evidence of an outage.
  unhealthy,

  /// The probe could not run. NOT evidence of anything.
  unknown,
}

/// The result of one probe attempt: a verdict and the reason behind it.
@immutable
class ProviderProbeResult {
  const ProviderProbeResult(this.verdict, this.reason);

  const ProviderProbeResult.healthy([this.reason = 'probe exited 0'])
    : verdict = ProviderProbeVerdict.healthy;

  const ProviderProbeResult.unhealthy(this.reason)
    : verdict = ProviderProbeVerdict.unhealthy;

  const ProviderProbeResult.unknown(this.reason)
    : verdict = ProviderProbeVerdict.unknown;

  final ProviderProbeVerdict verdict;
  final String reason;

  bool get isHealthy => verdict == ProviderProbeVerdict.healthy;
  bool get isUnhealthy => verdict == ProviderProbeVerdict.unhealthy;
  bool get isUnknown => verdict == ProviderProbeVerdict.unknown;

  @override
  String toString() => 'ProviderProbeResult(${verdict.name}: $reason)';
}

/// Observes one provider. Injected so the monitor's DECISION — what a missing
/// observation means — is testable without spawning a real process.
typedef ProviderProbe = Future<ProviderProbeResult> Function(String provider);

/// The monitor's operator log. Same `(event, data)` shape the rest of the
/// platform uses (`apps/server`'s `_log`, `baseline_dispatch`'s `log`), so one
/// grep pattern covers the whole process.
typedef ProviderHealthLog =
    void Function(String event, Map<String, dynamic> data);

/// Default sink: stderr, in the platform's `[$event] $data` format.
///
/// A default rather than `null` on purpose. The composition root constructs
/// this monitor without a logger, so "no logger" must not mean "no output" —
/// that is precisely how 48 infrastructure tickets were created with an empty
/// log. stderr is chosen over stdout because this is the failure path; the
/// line format is identical either way, so an operator's existing grep works.
void defaultProviderHealthLog(String event, Map<String, dynamic> data) {
  stderr.writeln('[$event] $data');
}

/// Probes a provider the way the DISPATCH PATH authenticates.
///
/// ## Why this does not look for an API key
///
/// The runtime the scheduler dispatches into is `opencode acp`
/// (`OpenCodeProcessTransport._spawn`), and it spawns with
/// `includeParentEnvironment: true` and NO injected credential: the worker's
/// `EnvironmentPolicy` carries only allowlisted, non-secret literals
/// (ADR 0015, `AgentSessionConfig.environment`: "Never secrets"). opencode
/// resolves its own credentials — its own config and its own auth store under
/// `$HOME` — and inherits the provider keys the container already exports
/// (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, …).
///
/// The old probe gated on `OPENCODE_<PROVIDER>_API_KEY`, a variable the
/// platform never sets. For the `opencode` provider that made the lookup
/// `OPENCODE_OPENCODE_API_KEY`, which is absent in the QA container, so the
/// probe NEVER RAN — and the monitor reported the absence as an outage. This
/// function therefore probes with the runtime's own mechanism: same
/// executable, same parent-environment inheritance, no credential of its own.
/// The probe now tests the same thing the dispatch path uses.
///
/// ## The three outcomes
///
///  * [Process.start] throws (the executable is missing or not executable):
///    [ProviderProbeResult.unknown] — the probe could not run.
///  * exit 0: [ProviderProbeResult.healthy].
///  * any other exit, or the probe hanging past [timeout]:
///    [ProviderProbeResult.unhealthy] — it ran, and it failed. That is
///    evidence, and only evidence may mark a provider down.
Future<ProviderProbeResult> runOpencodeProviderProbe(
  String provider, {
  String executable = defaultProbeExecutable,
  Duration timeout = const Duration(seconds: 30),
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
}) async {
  final Process process;
  try {
    process = await Process.start(
      executable,
      ['--provider', provider, 'models'],
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );
  } on ProcessException catch (e) {
    // The probe could not run at all. This says nothing about the provider.
    return ProviderProbeResult.unknown(
      'probe could not start "$executable": ${e.message}',
    );
  } on Object catch (e) {
    return ProviderProbeResult.unknown('probe could not start: $e');
  }

  // Drain both pipes. An unread child blocks on a full pipe buffer, which
  // would turn a successful probe into a timeout — evidence manufactured by
  // the observer.
  final stderrTail = _drainTail(process.stderr);
  unawaited(_drainTail(process.stdout));

  try {
    final code = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill(ProcessSignal.sigterm);
        return -1;
      },
    );
    if (code == -1) {
      return ProviderProbeResult.unhealthy(
        'probe did not finish within ${timeout.inSeconds}s',
      );
    }
    if (code == 0) {
      return const ProviderProbeResult.healthy();
    }
    final detail = await stderrTail;
    return ProviderProbeResult.unhealthy(
      'probe exited $code${detail.isEmpty ? '' : ': $detail'}',
    );
  } on Object catch (e) {
    // The process started, so a failure from here is a real failure of the
    // thing under test rather than an absent observation.
    return ProviderProbeResult.unhealthy('probe failed: $e');
  }
}

Future<String> _drainTail(Stream<List<int>> stream) async {
  final buffer = StringBuffer();
  await for (final chunk in stream.transform(const SystemEncoding().decoder)) {
    buffer.write(chunk);
    if (buffer.length > 2000) {
      buffer.write('…(truncated)');
      break;
    }
  }
  return buffer.toString().trim();
}

/// Periodically probes providers from model policies and raises human decisions
/// when providers are unavailable or when all providers for a role are down.
///
/// ## The failure direction
///
/// This monitor gates DISPATCH. `_eligibleRunnableJobs` in `scheduler.dart`
/// silently skips every job whose role currently reads as all-providers-down,
/// so a wrong verdict here does not degrade — it stops the platform doing any
/// work at all, with no error anywhere.
///
/// Therefore: **only evidence of an outage may mark a provider down.** A probe
/// that could not run is [ProviderProbeVerdict.unknown] and changes nothing;
/// it never fails closed on availability. The prior code inverted this by
/// returning "down" whenever `OPENCODE_<PROVIDER>_API_KEY` was absent — an
/// observation about the monitor's own configuration, reported as an outage.
class ProviderHealthMonitor {
  ProviderHealthMonitor({
    required ModelPolicyStore modelPolicyStore,
    required WorkflowStore workflowStore,
    required HumanDecisionStore humanDecisionStore,
    this.checkInterval = const Duration(minutes: 5),
    this.probeTimeout = const Duration(seconds: 30),

    /// Consecutive failing probes required before a provider counts as down.
    ///
    /// One 30-second timeout is not an outage, and a monitor that halts every
    /// dispatch in the platform on a single blip has the wrong blast radius.
    /// Two consecutive failures (10 minutes at the default interval) is the
    /// line: long enough to ignore a hiccup, short enough to notice a real
    /// outage. A recovery resets the counter.
    this.failureThreshold = 2,

    /// Overrides the probe. Injected so the decision rules above are testable
    /// without spawning a real agent runtime.
    ProviderProbe? probe,
    this.probeExecutable = defaultProbeExecutable,
    ProviderHealthLog log = defaultProviderHealthLog,
  }) : _modelPolicyStore = modelPolicyStore,
       _workflowStore = workflowStore,
       _humanDecisionStore = humanDecisionStore,
       _probe = probe,
       _log = log;

  final ModelPolicyStore _modelPolicyStore;
  final WorkflowStore _workflowStore;
  final HumanDecisionStore _humanDecisionStore;
  final Duration checkInterval;
  final Duration probeTimeout;

  /// Consecutive failing probes before a provider is treated as down.
  final int failureThreshold;

  /// The executable [runOpencodeProviderProbe] launches.
  final String probeExecutable;

  final ProviderProbe? _probe;
  final ProviderHealthLog _log;

  final Map<String, ProviderHealth> _providerHealth = {};
  final Map<String, int> _consecutiveFailures = {};
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
      final previous = _providerHealth[provider];
      final result = await _runProbe(provider);

      // Accumulation rule: a failing probe is evidence and adds to the count;
      // a healthy probe erases it; an unknown probe does NEITHER, because it
      // neither confirms nor refutes. `isDown` still requires a failing
      // verdict, so an unknown verdict can never leave a provider marked down.
      final failures = result.isUnhealthy
          ? (_consecutiveFailures[provider] ?? 0) + 1
          : result.isHealthy
          ? 0
          : (_consecutiveFailures[provider] ?? 0);
      _consecutiveFailures[provider] = failures;

      final health = ProviderHealth(
        provider: provider,
        verdict: result.verdict,
        reason: result.reason,
        consecutiveFailures: failures,
        downAfterConsecutiveFailures: failureThreshold,
        lastChecked: DateTime.now().toUtc(),
      );
      _providerHealth[provider] = health;

      _logVerdictTransition(previous: previous, current: health);

      // A ticket requires evidence. An unknown probe never reaches this.
      if (health.isDown) {
        await _createProviderTicket(provider, health);
      }
    }

    await _checkAllProvidersDown(policies);
  }

  Future<ProviderProbeResult> _runProbe(String provider) async {
    final injected = _probe;
    if (injected != null) return injected(provider);
    return runOpencodeProviderProbe(
      provider,
      executable: probeExecutable,
      timeout: probeTimeout,
    );
  }

  /// Emits one line per STATE CHANGE, not per cycle.
  ///
  /// The incident this fixes produced 48 infrastructure tickets and nothing
  /// else: the state was recorded in the database and never in the log, so
  /// the only way to learn that dispatch had stopped was to count pending
  /// decisions. Logging every cycle would trade silence for spam, and the
  /// transitions are what an operator actually reads.
  void _logVerdictTransition({
    required ProviderHealth? previous,
    required ProviderHealth current,
  }) {
    final wasDown = previous?.isDown ?? false;
    final isDown = current.isDown;

    if (current.isUnknown &&
        previous?.verdict != ProviderProbeVerdict.unknown) {
      _log('provider_health.probe_unknown', {
        'provider': current.provider,
        'reason': current.reason,
        'action':
            'no verdict; provider NOT marked down and dispatch NOT blocked',
      });
      return;
    }

    if (isDown && !wasDown) {
      _log('provider_health.provider_down', {
        'provider': current.provider,
        'reason': current.reason,
        'consecutiveFailures': current.consecutiveFailures,
        'threshold': current.downAfterConsecutiveFailures,
        'action':
            'infrastructure decision will be raised; roles relying '
            'solely on this provider stop dispatching',
      });
      return;
    }

    if (!isDown && wasDown) {
      _log('provider_health.provider_recovered', {
        'provider': current.provider,
        'reason': current.reason,
        'previousConsecutiveFailures': previous?.consecutiveFailures,
        'action': 'down state cleared; blocked roles may dispatch again',
      });
    }
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

  Future<void> _createProviderTicket(
    String provider,
    ProviderHealth health,
  ) async {
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
        // The observed reason, not a guess at a class of failure. The old
        // literal ("401/403/credit error/timeout") named four possible causes
        // without knowing which one happened.
        'error': health.reason,
        'consecutiveFailures': health.consecutiveFailures,
        'dismissible': true,
      },
      updatedAt: DateTime.now().toUtc(),
    );

    await _humanDecisionStore.saveHumanDecision(decision);
  }

  Future<HumanDecision?> _findExistingProviderTicket(String provider) async {
    return _findPendingTicket((d) => d.metadata?['provider'] == provider);
  }

  Future<HumanDecision?> _findPendingTicket(
    bool Function(HumanDecision) matches,
  ) async {
    try {
      final decisions = await _workflowStore.readHumanDecisionsForWorkItem(
        'system:provider-health',
      );
      return decisions.firstWhere(
        (d) =>
            d.decisionType == HumanDecisionType.infrastructureDecision &&
            matches(d) &&
            d.status == HumanDecisionStatus.pending,
        orElse: () => throw StateError('not found'),
      );
    } on StateError {
      return null;
    }
  }

  Future<void> _checkAllProvidersDown(List<ModelPolicy> policies) async {
    for (final policy in policies) {
      if (policy.chain.isEmpty) continue;

      // Every step must be DOWN ON EVIDENCE. A provider that was never probed,
      // or whose probe could not run, is `unknown` — and `unknown` is not
      // `down`, so absence of evidence can never silence a whole role.
      final downProviders = policy.chain
          .where((s) => _providerHealth[s.provider]?.isDown ?? false)
          .map((s) => s.provider)
          .toList();
      final allDown = downProviders.length == policy.chain.length;

      if (allDown) {
        await _raiseAllProvidersDown(policy, downProviders);
      } else {
        final cleared = _allProvidersDownTickets.remove(policy.role);
        if (cleared != null) {
          // Recovery is logged, not silent: an operator who saw a role go
          // dark needs to see it come back without having to diff two tables.
          _log('provider_health.all_providers_recovered', {
            'role': policy.role.wire,
            'decisionId': cleared.decisionId,
            'recoveredProviders': policy.chain
                .map((s) => s.provider)
                .where((p) => !downProviders.contains(p))
                .toList(),
            'action':
                'dispatch resumed for this role; no human acknowledgement '
                'is required to unblock it',
          });
        }
      }
    }
  }

  Future<void> _raiseAllProvidersDown(
    ModelPolicy policy,
    List<String> downProviders,
  ) async {
    // Look for an existing PENDING decision for this role before writing one.
    // The in-memory map is empty after every restart, so the previous
    // behaviour minted a fresh blocking ticket on each boot — which is how one
    // outage accumulated dozens of them for the same role. Re-adopting the
    // open ticket keeps dispatch blocked by evidence alone: a stale durable
    // ticket is inert until the providers are actually down again.
    final existing = await _findPendingTicket(
      (d) => d.metadata?['role'] == policy.role.wire,
    );

    if (existing != null && existing.status == HumanDecisionStatus.pending) {
      _allProvidersDownTickets[policy.role] = AllProvidersDownTicket(
        role: policy.role,
        decisionId: existing.decisionId,
        downProviders: downProviders,
        createdAt: existing.requestedAt ?? DateTime.now().toUtc(),
        resolved: false,
      );
      return;
    }

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
          description: 'Pause dispatch for this role until providers recover',
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

    _log('provider_health.all_providers_down', {
      'role': policy.role.wire,
      'decisionId': decision.decisionId,
      'downProviders': downProviders,
      'evidence': {
        for (final p in downProviders)
          p: _providerHealth[p]?.reason ?? 'no observation recorded',
      },
      'action': 'dispatch for this role is suspended until a probe succeeds',
    });
  }
}

/// Current health status of a provider.
@immutable
class ProviderHealth {
  const ProviderHealth({
    required this.provider,
    required this.verdict,
    required this.reason,
    required this.consecutiveFailures,
    required this.downAfterConsecutiveFailures,
    required this.lastChecked,
  });

  final String provider;

  /// What the last probe attempt concluded.
  final ProviderProbeVerdict verdict;

  /// Why. Carried into the log line and the ticket metadata so an operator
  /// reads the observation rather than a guess at a category.
  final String reason;

  /// Consecutive failing probes observed so far.
  final int consecutiveFailures;

  /// How many consecutive failures are required before this provider counts
  /// as down. Recorded per observation so a log line states the rule in force.
  final int downAfterConsecutiveFailures;

  final DateTime lastChecked;

  /// Whether the monitor treats this provider as DOWN.
  ///
  /// Requires a FAILING probe, not merely a missing one, and enough of them
  /// in a row. Both halves matter: the first is why an unrunnable probe can
  /// never close the platform's dispatch, the second is why a single timeout
  /// cannot.
  bool get isDown =>
      verdict == ProviderProbeVerdict.unhealthy &&
      consecutiveFailures >= downAfterConsecutiveFailures;

  /// Whether the last probe could not run. Never down, never blocks.
  bool get isUnknown => verdict == ProviderProbeVerdict.unknown;

  @override
  String toString() =>
      'ProviderHealth($provider, ${verdict.name}, failures: '
      '$consecutiveFailures/$downAfterConsecutiveFailures, down: $isDown, '
      'reason: $reason)';
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

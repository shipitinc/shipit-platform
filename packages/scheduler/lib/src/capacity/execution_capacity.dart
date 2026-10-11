import 'package:meta/meta.dart';

/// The single environment variable that governs how many agent executions may
/// be in flight at once.
///
/// This is the ONLY environment lookup in the scheduler. It exists because a
/// cap that requires a code change to raise is a cap nobody raises, and the
/// decided value is an operator decision (`C`), not a constant this package is
/// entitled to bake in.
const String executionCapacityEnvVar = 'SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS';

/// The name of the capacity budget guarded by [ExecutionCapacity].
///
/// GLOBAL, deliberately and not per-product (§3.3). The cap exists to bound the
/// host, and the host is shared. A per-product budget would let nine queued
/// defects for one product still occupy nine slots, which is precisely the
/// burst this budget was created to bound; scoping the budget to a product
/// bounds nothing at the host while reading as if it did.
const String agentExecutionBudget = 'agent_executions';

/// A resolved, usable global concurrency cap for agent executions.
///
/// This type has a private constructor, so the only way to obtain one is
/// through [ExecutionCapacityResolution.fromEnvironment] having succeeded.
/// There is deliberately no named constant and no static default: a caller
/// cannot accidentally hand the scheduler "unlimited", and cannot hand it a
/// guessed number while logging the guess as fact.
@immutable
class ExecutionCapacity {
  const ExecutionCapacity._({
    required this.budget,
    required this.maxConcurrentExecutions,
  });

  /// The budget this cap governs; also the advisory-lock name. See
  /// [agentExecutionBudget].
  final String budget;

  /// The operator-decided value `C`: the maximum number of agent executions
  /// that may hold a slot simultaneously across every scheduler process.
  final int maxConcurrentExecutions;

  /// The advisory-lock key for [budget], as a PostgreSQL `bigint`.
  ///
  /// STABLE by construction, not by hash: `String.hashCode` is explicitly not
  /// guaranteed stable across Dart versions or isolates, and a lock key that
  /// moves between releases would let two processes take "the same" lock on two
  /// different keys — the overshoot this whole mechanism exists to prevent.
  /// FNV-1a/64 is deterministic, well-distributed, and identical in every
  /// process that computes it.
  ///
  /// The result is the unsigned 64-bit FNV digest reinterpreted as a signed
  /// 64-bit integer, so it is frequently NEGATIVE. That is correct:
  /// `pg_advisory_xact_lock(bigint)` accepts the whole signed range, and two
  /// processes deriving the same negative number take the same lock.
  int get advisoryLockKey => _fnv1a64(budget);

  /// One line naming the resolved value, for the startup log.
  ///
  /// Stated in the success direction as well as the failure direction: an
  /// operator who cannot see the cap in force cannot tell a saturated queue
  /// from an unbounded one.
  String get startupSummary =>
      'execution capacity resolved: budget=$budget '
      '$executionCapacityEnvVar=$maxConcurrentExecutions '
      '(max concurrent agent executions, global)';

  static int _fnv1a64(String value) {
    // 64-bit FNV-1a, masked explicitly so the result is identical on every
    // target regardless of how that target represents `int`.
    const int offsetBasis = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    const int mask = 0xFFFFFFFFFFFFFFFF;
    var hash = offsetBasis;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & mask;
    }
    return hash;
  }

  @override
  String toString() => 'ExecutionCapacity($budget, C=$maxConcurrentExecutions)';
}

/// The outcome of reading [executionCapacityEnvVar]: either a usable
/// [ExecutionCapacity], or a named reason why there is none.
///
/// The failure cases are the point. A cap that defaults to "unlimited"
/// re-creates the host exhaustion it was built to prevent; a cap that defaults
/// to a guessed number puts a fiction in a log line that an operator will later
/// trust. So the only honest default is to resolve nothing and say why.
@immutable
class ExecutionCapacityResolution {
  const ExecutionCapacityResolution._({
    required ExecutionCapacity? capacity,
    required this.diagnostic,
  }) : _capacity = capacity;

  const ExecutionCapacityResolution.unresolved(this.diagnostic)
    : _capacity = null;

  /// The resolved cap, or null when the configuration is unusable. Never a
  /// fallback value.
  final ExecutionCapacity? _capacity;

  /// A human-readable, log-line-safe statement naming the variable and what
  /// was wrong with it (or, on success, what was resolved). Safe to log
  /// verbatim: it never contains a credential, only the variable name and the
  /// offending value.
  final String diagnostic;

  ExecutionCapacity? get capacity => _capacity;

  bool get isResolved => _capacity != null;

  /// Reads the cap out of [environment] ([Platform.environment] in production;
  /// a literal map in tests, so the resolution is pure and the environment
  /// process cannot be mutated into a bad state mid-test).
  ///
  /// FAILS CLOSED. Every one of these resolves to null, never to a default:
  /// the variable is absent; it is empty or whitespace; it does not parse as an
  /// integer; it parses to less than 1 (0 would deny all work forever and a
  /// negative cap is nonsense rather than a limit).
  factory ExecutionCapacityResolution.fromEnvironment(
    Map<String, String> environment, {
    String budget = agentExecutionBudget,
  }) {
    final raw = environment[executionCapacityEnvVar];
    if (raw == null) {
      return ExecutionCapacityResolution.unresolved(
        'execution capacity NOT resolved: $executionCapacityEnvVar is unset. '
        'Refusing to dispatch agent executions unbounded. Set '
        '$executionCapacityEnvVar to an integer >= 1 before starting the '
        'scheduler.',
      );
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return ExecutionCapacityResolution.unresolved(
        'execution capacity NOT resolved: $executionCapacityEnvVar is empty. '
        'Refusing to dispatch agent executions unbounded. Set '
        '$executionCapacityEnvVar to an integer >= 1 before starting the '
        'scheduler.',
      );
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return ExecutionCapacityResolution.unresolved(
        'execution capacity NOT resolved: $executionCapacityEnvVar="$raw" is '
        'not an integer. Refusing to dispatch agent executions unbounded. Set '
        '$executionCapacityEnvVar to an integer >= 1 before starting the '
        'scheduler.',
      );
    }
    if (parsed < 1) {
      return ExecutionCapacityResolution.unresolved(
        'execution capacity NOT resolved: $executionCapacityEnvVar=$parsed is '
        'below the minimum of 1. A cap of 0 would deny all work forever and a '
        'negative cap is not a limit, so neither is honoured. Refusing to '
        'dispatch agent executions unbounded; set $executionCapacityEnvVar to '
        'an integer >= 1 before starting the scheduler.',
      );
    }
    final capacity = ExecutionCapacity._(
      budget: budget,
      maxConcurrentExecutions: parsed,
    );
    return ExecutionCapacityResolution._(
      capacity: capacity,
      diagnostic: capacity.startupSummary,
    );
  }
}

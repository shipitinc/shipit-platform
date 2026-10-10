import 'package:product_registry/product_registry.dart';
import 'package:scheduler/scheduler.dart'
    show BaselineDispatchResult, BaselineProductDispatcher, JobStore;

import '../credentials/credential_key_service.dart';
import '../credentials/repository_access_verifier.dart';
import '../credentials/repository_snapshot_acquirer.dart';
import '../credentials/secret_provider.dart' show SecretProvider;
import '../credentials/secret_provider_resolver.dart';
import 'baseline_derivation.dart' show BaselinePrincipals;
import 'baseline_lane_runner.dart';
import 'baseline_onboarding_sweep.dart';
import 'baseline_production_lane.dart';

/// The baseline-production runtime, or an honest account of why there is none.
///
/// ## What this composes, and why it is a separate object
///
/// The lane, the sweep, the acquirer and the dispatcher already existed and
/// were wired to nothing: `server.dart` registered no handlers and constructed
/// none of them, so `JobType.onboardProduct` jobs were enqueued, stored,
/// displayed by `getOnboardingStatus`, and never run. That is the silent no-op
/// this work item exists to close, and it is invisible from any single file —
/// every piece is correct and the composition is what is missing.
///
/// Composition is also where the honest-unavailable posture belongs. There is
/// exactly one place in this platform that can say "the baseline runtime does
/// not exist in this deployment", and burying that decision inside a `try` in
/// the server entry point would make it un-testable and easy to delete.
class BaselineProductionRuntime {
  const BaselineProductionRuntime._({
    required this.dispatcher,
    required this.sweep,
    required this.custodyRuntimeState,
    required this.availableReason,
    required this.log,
  });

  /// Builds the runtime over [engine] and [jobStore], or records that it could
  /// not be built.
  ///
  /// The ONLY thing that can be missing is the custody substrate the acquirer
  /// reads a deploy key's private half through, and it is resolved here rather
  /// than assumed. Everything else the lane needs exists in this repository:
  /// `SshPinnedSnapshotMaterializer` clones over SSH, `ReadOnlyRepositoryReader`
  /// and `MaturityClassifier` derive facts, and [engine] proposes, verifies and
  /// requests approval. Recording an external dependency for any of those would
  /// be the dishonest-terminal-state defect in a new place.
  ///
  /// [log] receives every event the composed pieces emit, including the refusals
  /// — a runtime that cannot run says so on every job rather than once at
  /// startup.
  ///
  /// [custodyProvider], [accessVerifier] and [materializer] are the
  /// composition's three seams, all defaulting to the production choice. They
  /// exist because this is a composition ROOT, and a root whose only inputs are
  /// a database and the process environment can only be exercised by standing
  /// up both. Passing any of them is never a way to weaken the lane: the
  /// acquirer enforces the confirmed host key on whatever it is handed, and a
  /// caller that supplies a materializer which does not enforce it, or a
  /// verifier which does not really clone, is supplying a broken lane.
  factory BaselineProductionRuntime.resolve({
    required ProductRegistryEngine engine,
    required ProductRegistryStore baselineStore,
    required JobStore jobStore,
    required void Function(String event, Map<String, dynamic> data) log,
    SecretProvider? custodyProvider,
    RepositoryAccessVerifier? accessVerifier,
    RepositorySnapshotMaterializer? materializer,
    Map<String, String>? environment,
  }) {
    final SecretProviderSelection? custody = custodyProvider == null
        ? _resolveCustody(log: log, environment: environment)
        : _explicitCustody(custodyProvider, log: log);
    if (custody == null) {
      return BaselineProductionRuntime._(
        dispatcher: BaselineProductDispatcher(
          jobStore: jobStore,
          runner: UnavailableBaselineLaneRunner(
            reason: _custodyUnavailableReason,
            log: log,
          ).run,
          log: log,
        ),
        // No sweep. The sweep's own resolver resolves a pinned revision by
        // acquiring a snapshot, so with no custody substrate it could only ever
        // return "unresolvable" for every product — a pass that examined
        // everything and enqueued nothing, which is exactly the shape of the
        // silent no-op this replaced. Operator-requested jobs are still
        // dispatched and terminally refused with a named reason, so the gap is
        // visible on a record rather than only here.
        sweep: null,
        custodyRuntimeState: baselineCredentialCustodyUnavailable,
        availableReason: _custodyUnavailableReason,
        log: log,
      );
    }

    final credentialKeyService = CredentialKeyService(
      engine: engine,
      secretProvider: custody.provider,
      // The real clone by default. Supplied so a composition can be exercised
      // without a git host; `CredentialKeyService` still records the outcome on
      // the credential row either way, so substituting the probe does not
      // bypass the trust decision — it only replaces the socket it runs over.
      verifier: accessVerifier ?? const RepositoryAccessVerifier(),
    );
    final acquirer = RepositorySnapshotAcquirer(
      engine: engine,
      credentialKeyService: credentialKeyService,
      materializer: materializer ?? const SshPinnedSnapshotMaterializer(),
    );
    final lane = BaselineProductionLane(
      engine: engine,
      acquirer: acquirer,
      principals: baselineLanePrincipals,
      baselineStore: baselineStore,
      log: log,
    );
    return BaselineProductionRuntime._(
      dispatcher: BaselineProductDispatcher(
        jobStore: jobStore,
        runner: BaselineLaneRunnerAdapter(lane: lane, log: log).run,
        log: log,
      ),
      sweep: BaselineOnboardingSweep(
        engine: engine,
        jobStore: jobStore,
        revisionResolver: SnapshotPinnedRevisionResolver(acquirer),
        log: log,
      ),
      custodyRuntimeState: 'configured',
      availableReason: null,
      log: log,
    );
  }

  /// Claims and runs onboarding jobs, outside the WorkItem-scoped scheduler.
  final BaselineProductDispatcher dispatcher;

  /// Enqueues onboarding for products nobody has built a baseline from.
  ///
  /// `null` when the runtime is unavailable; see the factory.
  final BaselineOnboardingSweep? sweep;

  /// `configured`, or `unavailable`.
  ///
  /// `unavailable` means the runtime does not exist in this deployment, not
  /// that a human declined to run it. Same wording, same meaning, as
  /// `designGovernanceRuntimeUnavailable`.
  final String custodyRuntimeState;

  /// Why, when [custodyRuntimeState] is not `configured`.
  final String? availableReason;

  /// Where this runtime's own failures go. The same sink the composed pieces
  /// are given, so one process has one operator log for all of them.
  final void Function(String event, Map<String, dynamic> data) log;

  /// Whether onboarding can actually run.
  bool get isAvailable => custodyRuntimeState == 'configured';

  /// One pass: decide what should be onboarded, then run what was.
  ///
  /// ## Why the sweep runs FIRST
  ///
  /// Because the dispatcher's whole input is the durable job set, and a sweep
  /// that ran after it would enqueue a job this pass could not have run — the
  /// product would wait a full interval for work that was already decided.
  /// Cheap to do nothing and expensive to do nothing in the wrong order.
  ///
  /// ## Why a sweep failure does not stop the dispatch
  ///
  /// They are independent pieces of work over independent products. A sweep
  /// that throws has enqueued nothing; the jobs an earlier pass enqueued are
  /// still queued and still runnable, and running them is the whole reason the
  /// dispatcher exists. Swallowing the sweep's failure to reach the dispatcher
  /// would reproduce the "nothing ran and nothing said why" outcome in a new
  /// place.
  Future<BaselineRuntimePassResult> runOnce() async {
    BaselineSweepResult? sweepResult;
    if (sweep != null) {
      try {
        sweepResult = await sweep!.run();
      } on Object catch (error, stackTrace) {
        // The sweep guards each product individually, so reaching here means
        // the pass failed OUTSIDE a product decision — most plausibly
        // `readAllProducts`. Recorded rather than propagated: the dispatch
        // below is unaffected and the durable jobs it runs are real.
        sweepResult = null;
        _reportSweepFailure(error, stackTrace);
      }
    }
    final dispatch = await dispatcher.dispatch();
    return BaselineRuntimePassResult(
      sweep: sweepResult,
      dispatch: dispatch,
    );
  }

  /// The operator-facing state of the whole runtime, for the startup banner.
  ///
  /// A single fact an operator can read without knowing the composition: either
  /// onboarding works, or it does not and here is why.
  Map<String, dynamic> describe() => <String, dynamic>{
    'custodyRuntimeKey': baselineCredentialCustodyRuntimeKey,
    'custodyRuntimeState': custodyRuntimeState,
    if (availableReason != null) 'unavailableReason': availableReason,
    'dispatcherId': dispatcher.dispatcherId,
    'sweepEnabled': sweep != null,
    'producer': baselineLanePrincipals.producer,
    'reDerivation': baselineLanePrincipals.verifier,
    if (!isAvailable)
      'note':
          'onboarding jobs are still dispatched and are terminated with '
          '$externalBaselineCredentialCustodyDependency; no gate is opened and '
          'no baseline is written',
  };

  void _reportSweepFailure(Object error, StackTrace stackTrace) {
    // Routed to the same sink the composed pieces use rather than swallowed:
    // the pass produced no decisions and something has to say so.
    log('baseline.runtime.sweep_pass_failed', {
      'code': 'SWEEP_PASS_ABORTED',
      'error': error.toString(),
      'stack': stackTrace.toString(),
      'action':
          'the dispatch half of this pass still ran; onboarding jobs already '
          'enqueued are unaffected',
    });
  }

  /// The reason recorded when no custody substrate could be selected.
  ///
  /// Kept as a single named string so the value on every job, in the startup
  /// banner and in any test is the same one, and so changing the wording does
  /// not require finding three spellings of it.
  static const String _custodyUnavailableReason =
      'No credential custody substrate is configured, so no product repository '
      'can be acquired and no baseline can be produced. Select one with '
      '$kSecretProviderEnv (see ADR 0018: fallback selection is a recorded '
      'precondition, not a silent default). This is not a declined run — the '
      'runtime does not exist in this deployment.';

  /// A custody substrate supplied by the caller rather than selected from the
  /// environment.
  ///
  /// Wrapped in the same selection type so there is ONE code path afterwards:
  /// a caller that supplies custody has not opted out of anything, and cannot
  /// leave the runtime in a shape the environment-selected branch does not
  /// also produce.
  static SecretProviderSelection _explicitCustody(
    SecretProvider provider, {
    required void Function(String event, Map<String, dynamic> data) log,
  }) {
    log('baseline.custody.configured', {
      'providerId': provider.providerId,
      'isDocumentedFallback': provider.isDocumentedFallback,
      'selectedBy':
          'the caller, rather than the configured environment variable',
    });
    return SecretProviderSelection(provider: provider, loggedFields: const {});
  }

  /// Resolves the custody substrate, or records that none is configured.
  ///
  /// The resolver fails closed by design — unset, blank and unrecognised all
  /// raise — so a refusal here is a configuration fact and not a defect. It is
  /// caught because refusing to start would be worse: this process also serves
  /// triage, and a missing secret manager is no reason to take defect
  /// classification down with it. The baseline lane answers every job it is
  /// given with a named refusal instead.
  static SecretProviderSelection? _resolveCustody({
    required void Function(String event, Map<String, dynamic> data) log,
    Map<String, String>? environment,
  }) {
    try {
      final selection = resolveSecretProvider(
        environment: environment,
        log: (event, fields) {
          log('baseline.$event', fields);
        },
      );
      log('baseline.custody.configured', {
        'providerId': selection.provider.providerId,
        'isDocumentedFallback': selection.provider.isDocumentedFallback,
      });
      return selection;
    } on Object catch (error, stackTrace) {
      log('baseline.custody.unavailable', {
        'runtimeKey': baselineCredentialCustodyRuntimeKey,
        'runtimeState': baselineCredentialCustodyUnavailable,
        'code': externalBaselineCredentialCustodyDependency,
        'error': error.toString(),
        'stack': stackTrace.toString(),
        'operatorDeclined': false,
        'action':
            'onboarding jobs will be terminated with this code; no baseline is '
            'written and no gate is opened',
      });
      return null;
    }
  }
}

/// The two principals every derivation in this platform is attributed to.
///
/// Named for what they ARE rather than for what the framework would like them
/// to be. The verifier here is a RE-DERIVATION: it recomputes the content hash
/// from a fresh read of the pinned source and compares, which establishes
/// correspondence between the stored facts and that source. It is not an
/// independent second opinion — both acquisitions happen in this process, over
/// the same credential, against the same host, and AGENTS.md §12 states that
/// residual hole. Naming it `independent-verifier` would imply a guarantee the
/// code does not provide, and the human approval gate remains the final
/// authority for exactly that reason.
final BaselinePrincipals baselineLanePrincipals = BaselinePrincipals(
  producer: 'baseline-lane:producer',
  verifier: 'baseline-lane:re-derivation',
);

/// What one [BaselineProductionRuntime.runOnce] did.
class BaselineRuntimePassResult {
  const BaselineRuntimePassResult({
    required this.sweep,
    required this.dispatch,
  });

  /// `null` when the sweep is disabled, or when the pass itself threw.
  final BaselineSweepResult? sweep;

  final BaselineDispatchResult dispatch;

  @override
  String toString() =>
      'BaselineRuntimePassResult(sweep: ${sweep ?? 'none'}, dispatch: $dispatch)';
}

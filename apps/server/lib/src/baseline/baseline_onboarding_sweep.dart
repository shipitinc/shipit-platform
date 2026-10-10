import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:scheduler/scheduler.dart'
    show DuplicateActiveJobException, JobStore;

// `onboardingDedupeKey` and `onboardingJob` are defined in
// `packages/scheduler/lib/src/baseline_product.dart`, which is new in this
// change and is NOT yet exported from that package's `lib/scheduler.dart`
// barrel — adding the export means editing a file this lane does not own. The
// two must stay in lockstep: the operator-requested trigger
// (`ControlPlaneService.triggerOnboarding`) builds the same key inline, and if
// the two ever disagree the sweep and the operator can each enqueue a job for
// one derivation, which is exactly the duplicate the key exists to prevent.
// `onboarding_dedupe_key_contract_test.dart` pins the literal so a change to
// either side fails rather than diverging silently.
// ignore: implementation_imports
import 'package:scheduler/src/baseline_product.dart';

import '../credentials/repository_snapshot_acquirer.dart';

/// Resolves the revision a product's repository should be pinned at for the
/// next onboarding attempt.
///
/// A port, and not an inline `git ls-remote`, for two reasons. It has to
/// authenticate with the product's own credential over SSH — a resolver that
/// could read a remote anonymously would be a path to a product's source that
/// bypasses the host-key confirmation entirely. And it has to be substitutable,
/// because the sweep's job is to decide *whether* to enqueue, and a test that
/// had to reach a git host to check that would be testing the network.
abstract interface class PinnedRevisionResolver {
  /// The revision to pin, or `null` when it cannot be resolved — in which case
  /// the sweep enqueues nothing, because a job keyed on "whatever HEAD is now"
  /// would be un-dedupeable and would mint a fresh job on every pass.
  Future<String?> resolve({
    required String productId,
    required String repositoryId,
  });
}

/// The production resolver: acquire the snapshot the lane would acquire anyway,
/// read its committed revision, release it.
///
/// This costs a clone, and the cost is acknowledged rather than hidden. A
/// cheaper resolver would have to authenticate somehow, and the only credential
/// this platform has for a repository is the deploy key behind a confirmed host
/// key — so "cheaper" would mean "reads the remote over a path that skips the
/// trust decision", which is the ADR 0018 A2 gap. The clone is the price of not
/// reopening it.
class SnapshotPinnedRevisionResolver implements PinnedRevisionResolver {
  const SnapshotPinnedRevisionResolver(this.acquirer);

  final RepositorySnapshotAcquirer acquirer;

  @override
  Future<String?> resolve({
    required String productId,
    required String repositoryId,
  }) async {
    // `HEAD` is what git resolves when a clone has no explicit revision; it is
    // a fetch target, not a pin, and the acquirer is what turns it into an
    // actual committed revision to compare against.
    RepositorySnapshot snapshot;
    try {
      snapshot = await acquirer.acquire(
        productId: productId,
        repositoryId: repositoryId,
        pinnedRevision: _headRef,
      );
    } on Object {
      // Unresolvable is a legitimate answer, not a crash: no credential, no
      // confirmed host key, an unreachable host. The sweep's job is to leave
      // that product alone and say nothing loud about it on every pass.
      return null;
    }
    try {
      return snapshot.revision;
    } finally {
      snapshot.release();
    }
  }

  static const String _headRef = 'HEAD';
}

/// One product the sweep decided about.
sealed class BaselineSweepDecision {
  const BaselineSweepDecision({required this.productId});

  final String productId;
}

/// An onboarding job was enqueued.
final class BaselineSweepEnqueued extends BaselineSweepDecision {
  const BaselineSweepEnqueued({
    required super.productId,
    required this.jobId,
    required this.repositoryId,
    required this.dedupeKey,
    required this.revision,
  });

  final String jobId;
  final String repositoryId;
  final String dedupeKey;
  final String revision;

  @override
  String toString() =>
      'enqueued $jobId for $productId ($repositoryId@$revision)';
}

/// The sweep looked at this product and did nothing. Each reason is named, so
/// "the sweep ran" and "the sweep ran and found nothing to do" are
/// distinguishable in a log — the difference between those two is exactly what
/// this work item keeps finding.
final class BaselineSweepSkipped extends BaselineSweepDecision {
  const BaselineSweepSkipped({
    required super.productId,
    required this.code,
    required this.reason,
  });

  final String code;
  final String reason;

  /// The product already has a baseline of any revision or status. The sweep
  /// produces a FIRST baseline; re-baselining a governed product is a different
  /// flow with its own gate, and guessing at it here would be inventing policy.
  static const String hasBaselineCode = 'BASELINE_EXISTS';

  /// The product's lifecycle state is outside the sweep's scope.
  static const String stateCode = 'STATE_OUT_OF_SCOPE';

  /// No repository reference, so no source.
  static const String noRepositoryCode = 'NO_REPOSITORY_REFERENCE';

  /// A repository exists but none of them has a usable, host-confirmed
  /// credential — the product's onboarding cost has not been paid yet.
  static const String noUsableCredentialCode = 'NO_USABLE_CONFIRMED_CREDENTIAL';

  /// No pinned revision could be resolved, so no dedupe key can be built.
  static const String unresolvableRevisionCode = 'PINNED_REVISION_UNRESOLVABLE';

  /// A job with this dedupe key is already in flight.
  static const String alreadyQueuedCode = 'DEDUPE_KEY_ALREADY_ACTIVE';

  @override
  String toString() => 'skipped $productId ($code): $reason';
}

/// What one sweep pass did.
class BaselineSweepResult {
  const BaselineSweepResult({
    required this.considered,
    required this.enqueued,
    required this.skipped,
  });

  /// Products whose state was in scope.
  final int considered;

  final List<BaselineSweepEnqueued> enqueued;
  final List<BaselineSweepSkipped> skipped;

  @override
  String toString() =>
      'BaselineSweepResult(considered: $considered, enqueued: '
      '${enqueued.length}, skipped: ${skipped.length})';
}

/// Enqueues onboarding for products that have a repository nobody has built a
/// baseline from.
///
/// ## Why a sweep at all
///
/// The operator's question — "how would another product become governed?" — has
/// the answer "someone remembers to run a dev script". That is a missing
/// capability, and a capability is not supplied by documenting it. A sweep is
/// what makes registration of a repository reference sufficient on its own.
///
/// ## The predicate, and every conjunct of it
///
/// ```text
///   enqueue onboarding  ⟺  product.state ∈ {registered, baselinePending,
///                                         baselineBlocked}
///                      ∧  ∄ row in product_baseline for productId
///                      ∧  ∃ repositoryReference with a usable, confirmed
///                         credential
///                      ∧  ∄ non-terminal job with this dedupeKey
/// ```
///
/// Every conjunct is load-bearing, and three of them exist to stop the sweep
/// from doing something it has no business doing:
///
/// * **The state set.** A governed product already has what this produces.
///   A `baselineReview` product is waiting on a human, and enqueueing behind
///   that human would be arguing with a gate.
/// * **`∄ baseline row`.** The sweep produces a FIRST baseline. Any row at
///   all — proposed, superseded, whatever — means baseline work has happened
///   and this is not where the sweep belongs.
/// * **A usable, confirmed credential.** `canReachRepository` requires a
///   credential proven to work AND a host key a human confirmed; either alone
///   is insufficient. Without this conjunct the sweep would enqueue a job for
///   every registered product on earth and let each one discover it has no
///   source.
///
/// ## `baselineBlocked` is in the state set, on purpose
///
/// A product blocked on a clarification still has **no baseline**, so
/// excluding it would hide that gap permanently — nothing on the record would
/// ever say a baseline was never produced. The lane refuses it, and that
/// refusal lands on the job. The sweep decides *whether to look*; the lane
/// decides *whether to act*, and both leave a trace. Collapsing them — by
/// dropping `baselineBlocked` from the sweep — converts an observable refusal
/// into an invisible absence, which is the defect class this work item exists
/// to close.
class BaselineOnboardingSweep {
  BaselineOnboardingSweep({
    required this.engine,
    required this.jobStore,
    required this.revisionResolver,
    DateTime Function()? clock,
    this.log,
  }) : _clock = clock ?? DateTime.now;

  final ProductRegistryEngine engine;
  final JobStore jobStore;
  final PinnedRevisionResolver revisionResolver;
  final DateTime Function() _clock;

  /// Optional observer. Every decision this sweep takes is logged, including the
  /// ones where it deliberately did nothing — a sweep that is silent when it
  /// finds nothing is indistinguishable from a sweep that is not running.
  final void Function(String event, Map<String, dynamic> data)? log;

  /// The states this sweep acts in. Read through `ProductState.canonical`, so a
  /// row persisted as the legacy `draft` — which the enum documents as
  /// parse-only and read as `registered` — is treated as what it means rather
  /// than excluded for carrying a spelling the contract calls legacy.
  static const Set<ProductState> sweepStates = {
    ProductState.registered,
    ProductState.baselinePending,
    ProductState.baselineBlocked,
  };

  /// Runs one pass.
  ///
  /// Idempotent: a second pass over unchanged state enqueues nothing, because
  /// the job it would enqueue is found by [JobStore.findLatestByDedupeKey] and
  /// is already non-terminal.
  Future<BaselineSweepResult> run() async {
    final enqueued = <BaselineSweepEnqueued>[];
    final skipped = <BaselineSweepSkipped>[];
    var considered = 0;

    for (final product in await engine.readAllProducts()) {
      if (!sweepStates.contains(product.state.canonical)) continue;
      considered++;
      final decision = await _consider(product);
      switch (decision) {
        case BaselineSweepEnqueued():
          enqueued.add(decision);
        case BaselineSweepSkipped():
          skipped.add(decision);
      }
    }

    log?.call('baseline.sweep.completed', {
      'considered': considered,
      'enqueued': enqueued.length,
      'skipped': skipped.length,
    });
    return BaselineSweepResult(
      considered: considered,
      enqueued: List.unmodifiable(enqueued),
      skipped: List.unmodifiable(skipped),
    );
  }

  Future<BaselineSweepDecision> _consider(Product product) async {
    if ((await engine.readBaselines(product.productId)).isNotEmpty) {
      return BaselineSweepSkipped(
        productId: product.productId,
        code: BaselineSweepSkipped.hasBaselineCode,
        reason:
            'the product already has at least one baseline revision; the sweep '
            'produces a first baseline, and re-baselining goes through its own '
            'gate.',
      );
    }

    final repositories = await engine.readRepositories(product.productId);
    if (repositories.isEmpty) {
      return BaselineSweepSkipped(
        productId: product.productId,
        code: BaselineSweepSkipped.noRepositoryCode,
        reason: 'the product has no repository reference to acquire.',
      );
    }

    // "A usable, confirmed credential", evaluated through the credential type's
    // own two-part predicate rather than a re-statement of it. `canReachRepository`
    // requires a credential proven to work AND a host key a human confirmed;
    // `isHostConfirmed` additionally requires that the confirmation name
    // somebody and carry a time, so a half-written confirmation row does not
    // read as a decision.
    RepositoryReference? usable;
    for (final repository in repositories) {
      final credential = await engine.readActiveCredential(
        product.productId,
        repository.repositoryId,
      );
      if (credential != null &&
          credential.canReachRepository &&
          credential.isHostConfirmed) {
        usable = repository;
        break;
      }
    }
    if (usable == null) {
      return BaselineSweepSkipped(
        productId: product.productId,
        code: BaselineSweepSkipped.noUsableCredentialCode,
        reason:
            'no repository of this product has both a proven credential and a '
            'host key a human confirmed. Onboarding costs a credential '
            'reference and a confirmed host key; until both exist there is no '
            'source to read.',
      );
    }

    final revision = await revisionResolver.resolve(
      productId: product.productId,
      repositoryId: usable.repositoryId,
    );
    if (revision == null || revision.trim().isEmpty) {
      return BaselineSweepSkipped(
        productId: product.productId,
        code: BaselineSweepSkipped.unresolvableRevisionCode,
        reason:
            'no revision could be pinned for ${usable.repositoryId}, so no '
            'dedupe key could be built. A job keyed on "whatever HEAD is now" '
            'would be a new job on every pass.',
      );
    }

    final dedupeKey = onboardingDedupeKey(
      productId: product.productId,
      repositoryId: usable.repositoryId,
      startingRevision: revision,
    );
    final existing = await jobStore.findLatestByDedupeKey(dedupeKey);
    if (existing != null && !existing.isTerminal) {
      return BaselineSweepSkipped(
        productId: product.productId,
        code: BaselineSweepSkipped.alreadyQueuedCode,
        reason:
            'job ${existing.jobId} with this dedupe key is still '
            '${existing.state.wire}.',
      );
    }

    final now = _clock().toUtc();
    final jobId = _jobId(product.productId, now);
    try {
      await jobStore.saveJob(
        onboardingJob(
          jobId: jobId,
          productId: product.productId,
          repositoryId: usable.repositoryId,
          startingRevision: revision,
          now: now,
        ),
      );
    } on DuplicateActiveJobException {
      // Two sweeps, or a sweep and an operator request, reached this key at the
      // same moment. The store's active-state dedupe constraint decided, and it
      // decided correctly: the second enqueue is a no-op rather than a
      // duplicate.
      return BaselineSweepSkipped(
        productId: product.productId,
        code: BaselineSweepSkipped.alreadyQueuedCode,
        reason:
            'a job with this dedupe key was enqueued concurrently and the store '
            'refused the duplicate.',
      );
    }

    log?.call('baseline.sweep.enqueued', {
      'productId': product.productId,
      'repositoryId': usable.repositoryId,
      'jobId': jobId,
      'revision': revision,
      'dedupeKey': dedupeKey,
    });
    return BaselineSweepEnqueued(
      productId: product.productId,
      jobId: jobId,
      repositoryId: usable.repositoryId,
      dedupeKey: dedupeKey,
      revision: revision,
    );
  }

  /// Ids are the store's to allocate in principle; in practice it takes what it
  /// is given, so they are made unique by product, revision and time rather
  /// than by product alone. Time alone would collide for two repositories of
  /// one product within the same millisecond, which is a real possibility for a
  /// sweep that runs over a list.
  static String _jobId(String productId, DateTime now) =>
      'jb-baseline-$productId-${now.microsecondsSinceEpoch}';
}

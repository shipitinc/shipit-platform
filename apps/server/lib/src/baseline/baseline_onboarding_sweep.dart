import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:scheduler/scheduler.dart'
    show
        DuplicateActiveJobException,
        JobStore,
        onboardingDedupeKey,
        onboardingJob,
        onboardingWorkItemId;

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
    // `HEAD` is what git resolves when a clone has no explicit revision. It is
    // a fetch target, not a pin — and it is the ONE ref the acquirer will
    // resolve rather than enforce, so this call returns the committed
    // revision the remote actually pointed at instead of raising "not the
    // revision you asked for". See `kRepositoryHeadRef` for why that carve-out
    // exists and why the lane must never take it.
    RepositorySnapshot snapshot;
    try {
      snapshot = await acquirer.acquire(
        productId: productId,
        repositoryId: repositoryId,
        pinnedRevision: kRepositoryHeadRef,
      );
    } on BaselineSourceUnavailableException {
      // Unresolvable is a legitimate answer, not a crash: no credential, no
      // confirmed host key, an unusable credential. The sweep's job is to leave
      // that product alone and say nothing loud about it on every pass.
      //
      // Only the AVAILABILITY refusals are caught here, and each is named. A
      // blanket `on Object` also swallowed
      // `BaselineSnapshotCleanupException` — a scratch tree holding the deploy
      // key's identity file that this process could not remove — and laundered a
      // leaked /tmp tree containing a private key into an
      // `PINNED_REVISION_UNRESOLVABLE` skip, which the sweep deliberately
      // declines to log loudly. The acquirer's own contract says a tree it
      // could not remove is an incident and never a result
      // (`repository_snapshot_acquirer.dart`), so it is deliberately absent from
      // this list and propagates.
      return null;
    } on HostKeyNotIndependentlyConfirmedException {
      return null;
    } on PinnedRevisionNotAcquiredException {
      return null;
    } on BaselineSnapshotMaterializationException {
      // git refused or timed out. Same answer as an unreachable host.
      return null;
    }
    try {
      return snapshot.revision;
    } finally {
      snapshot.release();
    }
  }
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

  /// The product already has a non-terminal onboarding job, so the sweep
  /// stopped **before** resolving a revision.
  ///
  /// Deliberately NOT [alreadyQueuedCode]. That code says "a revision was
  /// resolved, it built this key, and the key was already taken" — a fact
  /// that costs an acquisition to learn. This one says "an attempt is already
  /// in flight, so no acquisition happened at all". Collapsing the two would
  /// hide the difference between a sweep that is cheap-idle and a sweep that
  /// is re-acquiring every pass, which is the exact distinction this whole
  /// change exists to make visible.
  static const String activeJobForProductCode = 'ACTIVE_ONBOARDING_JOB_EXISTS';

  @override
  String toString() => 'skipped $productId ($code): $reason';
}

/// What one sweep pass did.
class BaselineSweepResult {
  const BaselineSweepResult({
    required this.considered,
    required this.enqueued,
    required this.skipped,
    this.incidents = const [],
    this.overlappedPasses = 0,
  });

  /// Products whose state was in scope.
  final int considered;

  final List<BaselineSweepEnqueued> enqueued;
  final List<BaselineSweepSkipped> skipped;

  /// Products whose evaluation **threw**.
  ///
  /// Deliberately not a [BaselineSweepSkipped]. "Looked and deliberately did
  /// nothing" and "crashed before deciding" are different facts, and folding
  /// them together is how one product's failure becomes invisible behind a
  /// count of quiet skips — which is the failure class this lane exists to
  /// close, one level up.
  final List<BaselineSweepIncident> incidents;

  /// Ticks that arrived while a pass was already running, and were therefore
  /// NOT run.
  ///
  /// Always present in the log line rather than only when non-zero. A dropped
  /// tick and a pass that found nothing to do both produce
  /// `considered: 0, enqueued: 0, skipped: 0, incidents: 0` — the exact shape
  /// of "the sweep is not running", which this lane exists to stop being
  /// indistinguishable from anything else. Reporting the count is what tells
  /// the two apart, so it is reported even when it is zero.
  ///
  /// A count and not a decision list: a dropped tick has no product. It is
  /// neither an enqueue nor a skip nor an incident, because none of those is a
  /// claim about a product — folding it into any of them would invent one.
  final int overlappedPasses;

  /// `considered` accounted for: everything the pass decided, plus everything
  /// it failed to decide.
  int get accountedFor => enqueued.length + skipped.length + incidents.length;

  @override
  String toString() =>
      'BaselineSweepResult(considered: $considered, enqueued: '
      '${enqueued.length}, skipped: ${skipped.length}, incidents: '
      '${incidents.length}, overlappedPasses: $overlappedPasses)';
}

/// A product the sweep could not decide about.
final class BaselineSweepIncident {
  const BaselineSweepIncident({
    required this.productId,
    required this.code,
    required this.reason,
  });

  final String productId;

  /// Stable, greppable. See [BaselineSweepIncidentCodes].
  final String code;
  final String reason;

  @override
  String toString() => 'incident $productId ($code): $reason';
}

/// Incident codes a sweep pass records when a product's evaluation threw.
abstract final class BaselineSweepIncidentCodes {
  /// A snapshot scratch tree this process could not remove.
  ///
  /// Named separately from [BaselineSweepIncidentCodes.evaluationFailed]
  /// because it is the one that carries a deploy key's identity file, and
  /// because `SnapshotPinnedRevisionResolver` deliberately lets it propagate
  /// for exactly that reason. It is an incident and not a routine skip — see
  /// that method for why it is caught here rather than there.
  static const String snapshotCleanupFailed = 'SNAPSHOT_CLEANUP_FAILED';

  /// Anything else the evaluation raised.
  ///
  /// Recorded, logged and stepped over. A store read that failed for one
  /// product says nothing about the next one, and a pass that aborted on it
  /// would leave every product after it un-enqueued with nothing on the record
  /// to explain why.
  static const String evaluationFailed = 'SWEEP_PRODUCT_EVALUATION_FAILED';
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
///                      ∧  ∄ non-terminal onboarding job for productId
/// ```
///
/// Every conjunct is load-bearing, and four of them exist to stop the sweep
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
/// * **`∄ non-terminal onboarding job`.** This one is evaluated BEFORE the
///   revision is resolved, and the ordering is the fix rather than an
///   optimisation: the pinned revision is expensive to learn (a real clone) and
///   the acquisition that learns it writes to the credential row, so asking the
///   question on the cheap durable record first is what stops the sweep from
///   re-acquiring every pass for a product it was always going to skip. It is
///   product-scoped rather than key-scoped for the same reason — see
///   [_activeOnboardingJob].
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

  /// Whether a pass is running right now.
  ///
  /// Taken and released by [run] in the CALLER's turn — which is why [run] is
  /// not `async`. An `async` body does not begin executing until it is
  /// scheduled, so an `async` guard could let two overlapping callers both read
  /// `false` before either wrote `true`, and the guard would be exactly as
  /// reliable as the accident it replaces.
  bool _running = false;

  /// Runs one pass, or records that one is already running.
  ///
  /// ## Why a pass may not overlap another
  ///
  /// The server drives this from `Timer.periodic`, which does **not** await its
  /// callback: the next tick starts whether or not the previous pass has
  /// finished. One pass performs a real SSH clone — about a minute — against a
  /// thirty-second interval, so pass N+1 was reliably starting while pass N was
  /// mid-clone. That used to be "safe by accident of the claim CAS and the
  /// database dedupe index", and the accident has been observed failing in
  /// production: 41 passes produced 22 incidents, 19 skips, zero enqueues and
  /// zero baselines, nearly all of them `Concurrent modification of cred-…`
  /// raised from inside the acquisition both passes were performing at once.
  ///
  /// So the second tick does not run, and says so. Dropping it silently would
  /// be indistinguishable from a tick that found nothing to do, and a pass that
  /// dropped ticks without saying so is the defect class this lane exists to
  /// close. [BaselineSweepResult.overlappedPasses] and the
  /// `baseline.sweep.completed` line carry the count.
  ///
  /// ## PER-PRODUCT ISOLATION lives in [_runPass]
  ///
  /// One product's evaluation throwing does not abort the pass. See that
  /// method for why the failing product is an incident rather than a skip.
  Future<BaselineSweepResult> run() {
    if (_running) {
      final dropped = const BaselineSweepResult(
        considered: 0,
        enqueued: [],
        skipped: [],
        overlappedPasses: 1,
      );
      log?.call('baseline.sweep.completed', {
        'considered': 0,
        'enqueued': 0,
        'skipped': 0,
        'incidents': 0,
        'overlappedPasses': 1,
        'code': 'SWEEP_PASS_OVERLAPPED',
        'action':
            'this tick did not run because a pass was already in flight; no '
            'product was evaluated and nothing was enqueued. The pass already '
            'running will report its own decisions.',
      });
      return Future<BaselineSweepResult>.value(dropped);
    }
    _running = true;
    // `whenComplete` releases the guard on the success path AND on the failure
    // path, and passes the original error through untouched — a guard that was
    // only released on success would wedge the sweep shut after the first
    // `readAllProducts` failure, and every later tick would be "overlapping"
    // against a pass that ended minutes ago.
    return _runPass().whenComplete(() {
      _running = false;
    });
  }

  /// One actual pass. Reached only through [run], which holds the guard.
  ///
  /// Idempotent: a second pass over unchanged state enqueues nothing, because
  /// the job it would enqueue is found by [JobStore.findLatestByDedupeKey] and
  /// is already non-terminal.
  ///
  /// ## PER-PRODUCT ISOLATION
  ///
  /// One product's evaluation throwing does not abort the pass. Without the
  /// guard below, a single repository whose snapshot scratch tree could not be
  /// removed would abandon every product after it in the list — none enqueued,
  /// nothing logged about them, and the next pass to hit the same failure
  /// abandoning the same set again. A failure that silently deletes the rest of
  /// the work is the same defect class as the silent no-op this lane was opened
  /// to end, so the failing product is recorded as an incident, the pass
  /// continues, and the count reconciles.
  ///
  /// The incident is NOT a skip, and `BaselineSweepIncidentCodes` gives the
  /// cleanup failure its own code rather than folding it into a generic one:
  /// [SnapshotPinnedRevisionResolver] lets
  /// [BaselineSnapshotCleanupException] propagate precisely because the tree it
  /// could not delete may hold a deploy key, and laundering it into a quiet
  /// `PINNED_REVISION_UNRESOLVABLE` would make a leaked private key unfindable.
  /// Catching it here does not make it quiet — it is in `incidents`, it is
  /// logged, and it is not a code any skip can carry.
  Future<BaselineSweepResult> _runPass() async {
    final enqueued = <BaselineSweepEnqueued>[];
    final skipped = <BaselineSweepSkipped>[];
    final incidents = <BaselineSweepIncident>[];
    var considered = 0;

    for (final product in await engine.readAllProducts()) {
      if (!sweepStates.contains(product.state.canonical)) continue;
      considered++;
      final BaselineSweepDecision decision;
      try {
        decision = await _consider(product);
      } on BaselineSnapshotCleanupException catch (error) {
        incidents.add(
          _incident(
            product,
            BaselineSweepIncidentCodes.snapshotCleanupFailed,
            error.toString(),
            action:
                'a scratch tree this process could not remove still exists and '
                'may contain a deploy key identity file; remove it manually',
            severity: 'incident',
          ),
        );
        continue;
      } on Object catch (error, stackTrace) {
        incidents.add(
          _incident(
            product,
            BaselineSweepIncidentCodes.evaluationFailed,
            error.toString(),
            action: 'this product is untouched; the rest of the pass continued',
            stack: stackTrace.toString(),
          ),
        );
        continue;
      }
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
      'incidents': incidents.length,
      'overlappedPasses': 0,
    });
    return BaselineSweepResult(
      considered: considered,
      enqueued: List.unmodifiable(enqueued),
      skipped: List.unmodifiable(skipped),
      incidents: List.unmodifiable(incidents),
    );
  }

  /// Records a product the pass failed to decide about, and says so loudly.
  ///
  /// The log line is the point of the method: the return value is a summary a
  /// caller may not print, and a summary that says "2 incidents" without saying
  /// which products or why is the quiet outcome this guard exists to prevent.
  BaselineSweepIncident _incident(
    Product product,
    String code,
    String reason, {
    required String action,
    String? stack,
    String severity = 'failure',
  }) {
    log?.call('baseline.sweep.product_incident', {
      'productId': product.productId,
      'code': code,
      'reason': reason,
      'severity': severity,
      'action': action,
      if (stack != null) 'stack': stack,
    });
    return BaselineSweepIncident(
      productId: product.productId,
      code: code,
      reason: reason,
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

    // THE PRODUCT-SCOPED GUARD, BEFORE THE ACQUISITION.
    //
    // `resolve()` is not free. It performs a real SSH clone — about a minute in
    // production — and on the way it runs `CredentialKeyService.verifyAccess`,
    // which writes the credential row twice: a `confirmHostKey` and a
    // `recordCredentialCheck`. Every one of those is a compare-and-swap that
    // bumps `version`.
    //
    // So a sweep that reached this point on every pass, while a job for the
    // product was already in flight, was writing to the credential on every
    // pass purely to learn a revision string it was about to discard — and
    // each write bumped the version the NEXT pass's `verifyAccess` was going
    // to assert. That is not a race two writers lost: the sweep guaranteed its
    // own conflict, every pass, and never reached the enqueue. It was observed
    // exactly that way in production — the credential climbed from version 1
    // to 59 across 41 passes while the product state never moved, and the
    // failures were the CAS the write had itself made stale.
    //
    // So "is this product already being onboarded?" is decided FIRST, from the
    // durable job set, and a revision is resolved only when a job would
    // actually be enqueued. Reading the revision is no longer how the sweep
    // finds out whether it has anything to do — reading it is the thing that
    // costs.
    //
    // The invariant the reason below states is unchanged and still load
    // bearing: a job is never keyed on "whatever HEAD is now". A second attempt
    // built from a freshly read HEAD would be a different key, and therefore a
    // different job, on every single pass.
    final inFlight = await _activeOnboardingJob(product.productId);
    if (inFlight != null) {
      return BaselineSweepSkipped(
        productId: product.productId,
        code: BaselineSweepSkipped.activeJobForProductCode,
        reason:
            'job ${inFlight.jobId} for this product is still '
            '${inFlight.state.wire}, so no revision was resolved and nothing '
            'was enqueued. A second attempt would be a new job keyed on '
            'whatever HEAD is now.',
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
    // The EXACT guard, and now the second of two rather than the only one.
    //
    // [BaselineSweepSkipped.activeJobForProductCode] above has already
    // established that no non-terminal onboarding job exists for this product,
    // so this read cannot report one on the ordinary path — it is narrower and
    // later, which is what makes it the right second line: it is keyed on the
    // exact derivation, so it still catches a non-terminal row for this key that
    // the product-scoped scan did not see (an id or work item written by an
    // older build), and it narrows to nothing the minute after [resolve] — which
    // can take a minute — rather than leaving the store's active-state
    // constraint to discover the race on its own.
    //
    // It is also, unlike the scan above, keyed on a value that only exists once
    // a revision has been resolved — so it can only ever run on a pass that was
    // going to acquire anyway. Its cost is never paid by a pass that has
    // nothing to do.
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

  /// The newest non-terminal onboarding job for [productId], or `null`.
  ///
  /// Scoped to the PRODUCT, not to one dedupe key, and that is the whole point.
  /// The dedupe key carries the pinned revision, so a key-scoped lookup is only
  /// possible *after* the revision has been resolved — which is the ordering
  /// this method exists to invert. [onboardingWorkItemId] is how an onboarding
  /// job is filed, both triggers file it the same way, and one indexed read
  /// therefore answers "is this product already being onboarded?" without a
  /// clone and without a credential write.
  ///
  /// Newest on [Job.createdAt] wins, with the same tie-break
  /// [JobStore.findLatestByDedupeKey] uses, so the reason an operator reads
  /// names the attempt they would look for.
  ///
  /// Filtered to [JobType.onboardProduct] even though the synthetic work-item
  /// id cannot collide with a real `WorkItem` by construction. The filter costs
  /// nothing and it is what makes the answer mean "an ONBOARDING attempt is in
  /// flight" rather than "something is filed under a string shaped like a
  /// work-item id" — so a future job type written under it is ignored instead of
  /// silently blocking onboarding for ever.
  ///
  /// Terminal jobs are excluded, and that is what lets a failed or succeeded
  /// attempt be re-derived at the same revision rather than stranding the
  /// product on a decision nothing is going to come back from.
  Future<Job?> _activeOnboardingJob(String productId) async {
    Job? active;
    for (final job in await jobStore.listJobsForWorkItem(
      onboardingWorkItemId(productId),
    )) {
      if (job.jobType != JobType.onboardProduct) continue;
      if (job.isTerminal) continue;
      if (active == null || !job.createdAt.isBefore(active.createdAt)) {
        active = job;
      }
    }
    return active;
  }

  /// Ids are the store's to allocate in principle; in practice it takes what it
  /// is given, so they are made unique by product, revision and time rather
  /// than by product alone. Time alone would collide for two repositories of
  /// one product within the same millisecond, which is a real possibility for a
  /// sweep that runs over a list.
  static String _jobId(String productId, DateTime now) =>
      'jb-baseline-$productId-${now.microsecondsSinceEpoch}';
}

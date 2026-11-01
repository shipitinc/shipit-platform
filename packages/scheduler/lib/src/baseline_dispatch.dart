// `claimLease` and `retryDelay` take named initializers rather than
// `this.claimLease` formals only because their defaults are named constants;
// the formals would have to repeat them.
// ignore_for_file: prefer_initializing_formals

import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'baseline_product.dart';
import 'queue/job_queue.dart';
import 'store/job_store.dart';

/// Runs the baseline lane for one onboarding job and reports what it concluded.
///
/// A PORT, and the whole reason this file can live in `packages/scheduler`
/// while the lane it drives lives in `apps/server`. The scheduler package
/// already refuses to depend on the server, and a "product-scoped dispatcher"
/// that imported `BaselineProductionLane` would invert that in order to save
/// one `typedef`.
///
/// What crosses the boundary is a conclusion, never a fact: this type can
/// express "a baseline was produced and a human was asked to approve it", "the
/// lane examined this and declined", and "the lane could not be run to a
/// verdict". It cannot express anything about *content*, because nothing here
/// derived any.
typedef OnboardingLaneRunner =
    Future<OnboardingLaneOutcome> Function(OnboardingLaneRequest request);

/// Everything the lane needs to run for one job, and nothing else.
///
/// [attempt] is the job's 1-based attempt count as it stood when the claim was
/// taken, so a lane that reports its own progress cannot disagree with the
/// retry bookkeeping that decided to run it again.
class OnboardingLaneRequest {
  const OnboardingLaneRequest({
    required this.jobId,
    required this.productId,
    required this.repositoryId,
    required this.pinnedRevision,
    required this.attempt,
  });

  final String jobId;
  final String productId;
  final String repositoryId;

  /// The committed revision to clone and derive from. Never `HEAD`.
  final String pinnedRevision;
  final int attempt;

  @override
  String toString() =>
      'OnboardingLaneRequest(job $jobId, $productId, $repositoryId@'
      '$pinnedRevision, attempt $attempt)';
}

/// What the lane concluded.
///
/// Sealed, for the reason [OnboardingLaneRunner] is a port and not a `Map`:
/// every terminal state is named here, so a caller cannot infer one from an
/// absence. `JobType.onboardProduct` sat `queued` for ever precisely because
/// nothing reported what happened to it, and a dispatcher whose return type can
/// also mean "nothing happened" would reintroduce that at the next boundary up.
sealed class OnboardingLaneOutcome {
  const OnboardingLaneOutcome();
}

/// The lane produced a baseline, the platform re-derived it, and a human was
/// asked to approve it. The only outcome that opens a gate.
///
/// [alreadyVerified] distinguishes a baseline verified for the first time from
/// one whose existing platform attestation was re-checked and still holds. Both
/// produce the same durable state; recording the difference is what lets an
/// operator reading the job record tell them apart.
final class OnboardingAwaitingApproval extends OnboardingLaneOutcome {
  const OnboardingAwaitingApproval({
    required this.baselineId,
    required this.revision,
    required this.sourceRevision,
    required this.decisionId,
    required this.factCount,
    required this.alreadyVerified,
  });

  final String baselineId;
  final int revision;

  /// The pinned revision both the proposal and the re-derivation read.
  final String sourceRevision;

  /// The pending human decision. Its presence is the gate; nothing here
  /// resolves it.
  final String decisionId;
  final int factCount;
  final bool alreadyVerified;
}

/// The lane examined the product and declined to act, and says why.
///
/// A refusal is a legitimate terminal state and never an error: a product
/// blocked on a clarification is waiting for a human, not failing. It
/// terminates the job as `failed` rather than `succeeded`, because `succeeded`
/// on this record means "a baseline exists and a human was asked about it",
/// and no code path may let a refusal read as though it had produced one.
final class OnboardingRefused extends OnboardingLaneOutcome {
  const OnboardingRefused({required this.code, required this.reason});

  /// Stable and greppable.
  final String code;

  /// Operator-facing. Carries no credential material and no fingerprint.
  final String reason;

  @override
  String toString() => 'refused ($code): $reason';
}

/// The lane could not be run to a verdict.
///
/// [transient] is the lane's own classification and is the only thing that may
/// authorise a retry. The dispatcher does not second-guess it: an exception
/// escaping [OnboardingLaneRunner] is a `transient: false` fault, because an
/// exception carries no claim about whether the same call would succeed, and
/// guessing "retry, it is probably a blip" would turn every defect into two
/// attempts and every blip into a terminal failure.
final class OnboardingFaulted extends OnboardingLaneOutcome {
  const OnboardingFaulted({
    required this.code,
    required this.reason,
    required this.transient,
  });

  final String code;
  final String reason;
  final bool transient;

  @override
  String toString() =>
      'faulted ($code, ${transient ? 'transient' : 'permanent'}): $reason';
}

/// What one [BaselineProductDispatcher.dispatch] pass did.
///
/// `dispatched` counts jobs whose lane actually ran — a job that lost its claim
/// to another process is in [deferred] instead, so the two together account for
/// every job the pass attempted and neither claims work that did not happen.
@immutable
class BaselineDispatchResult {
  const BaselineDispatchResult({
    required this.reconciled,
    required this.dispatched,
    required this.awaitingApproval,
    required this.refused,
    required this.retried,
    required this.failed,
    required this.deferred,
  });

  /// Claims recovered from an expired lease and requeued. See
  /// [BaselineProductDispatcher] for why re-running is safe here.
  final List<String> reconciled;

  /// Jobs the lane ran this pass.
  final List<String> dispatched;

  final List<String> awaitingApproval;
  final List<String> refused;
  final List<String> retried;
  final List<String> failed;

  /// Eligible jobs this pass did not attempt: another process won the claim, or
  /// the job stopped being eligible between the scan and the attempt.
  final List<String> deferred;

  @override
  String toString() =>
      'BaselineDispatchResult(dispatched: ${dispatched.length}, '
      'awaitingApproval: ${awaitingApproval.length}, refused: '
      '${refused.length}, retried: ${retried.length}, failed: ${failed.length}, '
      'reconciled: ${reconciled.length}, deferred: ${deferred.length})';
}

/// Dispatches `JobType.onboardProduct` jobs to the baseline lane, outside the
/// WorkItem-scoped [Scheduler].
///
/// ## Why this is not `Scheduler`, and why that is not a workaround
///
/// `Scheduler` derives what may run by asking the workflow policy about a
/// `WorkItem`. An onboarding job has no `WorkItem`: it is filed under the
/// synthetic `onboarding-<productId>`, and
/// `Scheduler._eligibleRunnableJobs` skips any job whose `workItemId` does not
/// resolve to a real item — correctly, because a job filed under a
/// non-existent work item has no workflow state authorising it. Putting
/// onboarding on that path would mean either inventing a `WorkItem` for it or
/// making the eligibility check tolerate a missing one, and both put a
/// product-scoped concern on defect triage's critical path.
///
/// Onboarding IS product-scoped work. It asks "does this registered product
/// have a baseline anyone approved?", which is a different question from "may
/// this defect's work item advance?", and it is answered from the product
/// registry rather than from the transition graph. So it gets its own
/// dispatcher here, and the WorkItem-scoped [Scheduler] is left exactly as it
/// was.
///
/// Everything else is borrowed rather than reinvented: the [JobDefinition] and
/// the job shape from `baseline_product.dart`, the dedupe key from the same
/// file, and [JobQueue] for the durable operations — claim with a lease,
/// version-CAS transitions, bounded retry, terminal states, and lease
/// reconciliation. Nothing here decides *policy*; the lane does, and the
/// dispatcher records what it said.
///
/// ## RESTART SAFETY
///
/// A pass that dies between two steps leaves one of three durable states, and
/// each is picked up rather than resumed:
///
/// * **Before the claim.** The job is `queued`; the next pass sees it as
///   eligible and takes it.
/// * **After the claim, before the lane finished.** The job is `running` with a
///   claim. When the lease expires the next pass requeues it — see
///   [_reconcile] for why re-running is safe rather than duplicating work.
/// * **After the lane finished, before the outcome was recorded.** The job is
///   still `running`, and the same reconciliation requeues it, so the lane runs
///   a second time.
///
/// That last case is the one worth being explicit about, because it is the one
/// `Scheduler` refuses to allow for its own jobs. The lane is idempotent by
/// construction: it reuses a baseline whose content already asserts what this
/// run derived instead of superseding it with an identical copy, merges
/// human-authored claims rather than restarting from scratch, and the approval
/// request it opens is idempotent for the same revision and content hash. So a
/// re-run produces no second baseline revision and no second pending decision.
/// There is no `WorkerExecution` to consult and no duplicate execution to
/// avoid — the unit of work is a pure function of a pinned source revision, and
/// it is safe to call twice.
///
/// ## The claim is still worth taking
///
/// Not for correctness of the derivation — for the two things the record is
/// read for. A `running` job is visible as in-flight rather than as a job that
/// never ran, and the lease is what makes a crashed process's job recoverable
/// at all rather than stuck for ever.
class BaselineProductDispatcher {
  BaselineProductDispatcher({
    required this.jobStore,
    required this.runner,
    this.dispatcherId = 'sched-baseline',
    DateTime Function()? clock,
    this.claimLease = const Duration(minutes: 30),
    this.retryDelay = const Duration(minutes: 5),
    this.log,
  }) : _clock = clock ?? DateTime.now;

  final JobStore jobStore;
  final OnboardingLaneRunner runner;

  /// Recorded as the claim owner. Distinct from the triage scheduler's id, so a
  /// claim in the store names which loop is holding it.
  final String dispatcherId;

  /// How long a claim is held before a later pass may recover it.
  ///
  /// Thirty minutes by default because the work behind it is a real git clone
  /// over SSH with a five-minute bound of its own, plus a derivation and a
  /// re-derivation over the acquired tree. A lease shorter than the work would
  /// let a second pass claim the same job while the first is still running,
  /// which the idempotence above makes harmless but wasteful.
  final Duration claimLease;

  final Duration retryDelay;
  final DateTime Function() _clock;

  /// Optional observer. Every pass reports what it did, including nothing.
  final void Function(String event, Map<String, dynamic> data)? log;

  /// The only job type this dispatcher will ever claim.
  ///
  /// Read from the definition rather than spelled as a literal, so the
  /// dispatcher cannot claim triage jobs the way it cannot claim a product it
  /// has no baseline for.
  static final JobType jobType = onboardProductDefinition.jobType;

  /// A job whose dedupe key does not decode into a target.
  ///
  /// Terminal rather than retried: the key is what the job was enqueued under,
  /// and re-reading it will decode exactly as badly next time.
  static const String undecodableTargetCode = 'UNDECODABLE_ONBOARDING_TARGET';

  /// The lane raised rather than returning a verdict.
  static const String laneThrewCode = 'BASELINE_LANE_RAISED';

  JobQueue get _queue => JobQueue(store: jobStore, clock: _clock);

  /// One full, synchronous pass.
  ///
  /// Idempotent: a pass over unchanged state dispatches nothing, because every
  /// eligible job it would dispatch is already terminal.
  Future<BaselineDispatchResult> dispatch() async {
    final now = _clock().toUtc();
    final reconciled = <String>[];
    final dispatched = <String>[];
    final awaitingApproval = <String>[];
    final refused = <String>[];
    final retried = <String>[];
    final failed = <String>[];
    final deferred = <String>[];

    reconciled.addAll(await _reconcile(now));

    final eligible = await _eligibleJobs(now);
    for (final job in eligible) {
      // At most one attempt per job per pass, and PER-JOB ISOLATION: one
      // product's failure must not abort the pass and leave every other product
      // in it un-dispatched. The same argument `drainTriageOutcomesFromTick`
      // makes, for the same reason — the jobs this loop has not reached yet are
      // still queued and WILL be reached next pass, but the jobs already
      // dispatched in this pass would have their outcomes recorded while the
      // pass as a whole reported a failure, and a reader would have to guess
      // how far it got.
      try {
        final outcome = await _dispatchOne(job, now);
        switch (outcome) {
          case null:
            deferred.add(job.jobId);
          case OnboardingAwaitingApproval():
            dispatched.add(job.jobId);
            awaitingApproval.add(job.jobId);
          case OnboardingRefused():
            dispatched.add(job.jobId);
            refused.add(job.jobId);
          case OnboardingFaulted():
            dispatched.add(job.jobId);
            final settled = await jobStore.readJob(job.jobId);
            if (settled?.state == JobState.retryWaiting) {
              retried.add(job.jobId);
            } else {
              failed.add(job.jobId);
            }
        }
      } on Object catch (error, stackTrace) {
        // A throw here is in the DISPATCHER's own bookkeeping, not in the lane
        // — `_dispatchOne` catches what the lane raises. The job keeps whatever
        // durable state it had; a claim that was already taken expires and is
        // recovered by `_reconcile` on the next pass. Recording the pass as
        // failed here is honest; swallowing it would not be.
        deferred.add(job.jobId);
        log?.call('baseline.dispatch.pass_job_failed', {
          'jobId': job.jobId,
          'productId': job.workItemId,
          'error': error.toString(),
          'stack': stackTrace.toString(),
          'action':
              'this job keeps its durable state; an expired claim is recovered '
              'by the next pass',
        });
      }
    }

    final result = BaselineDispatchResult(
      reconciled: List.unmodifiable(reconciled),
      dispatched: List.unmodifiable(dispatched),
      awaitingApproval: List.unmodifiable(awaitingApproval),
      refused: List.unmodifiable(refused),
      retried: List.unmodifiable(retried),
      failed: List.unmodifiable(failed),
      deferred: List.unmodifiable(deferred),
    );
    log?.call('baseline.dispatch.completed', {
      'dispatcherId': dispatcherId,
      'reconciled': result.reconciled.length,
      'dispatched': result.dispatched.length,
      'awaitingApproval': result.awaitingApproval.length,
      'refused': result.refused.length,
      'retried': result.retried.length,
      'failed': result.failed.length,
      'deferred': result.deferred.length,
    });
    return result;
  }

  /// Recovers claims whose lease outlived the process that took them.
  ///
  /// Requeued, not adopted from a worker store: there is no worker execution
  /// behind an onboarding job, so there is no outcome to adopt and no live
  /// execution to avoid duplicating. See the class doc for why re-running the
  /// lane is safe.
  Future<List<String>> _reconcile(DateTime now) async {
    final reconciled = <String>[];
    for (final job in await _onboardingJobs()) {
      if (job.state != JobState.claimed && job.state != JobState.running) {
        continue;
      }
      final claim = await jobStore.readClaimForJob(job.jobId);
      if (claim != null && !claim.isExpiredAt(now)) continue;
      await _queue.requeueFromStaleClaim(
        job: job,
        reason: claim == null
            ? 'claim record missing'
            : 'claim expired before the baseline outcome was recorded',
      );
      log?.call('baseline.dispatch.reclaimed', {
        'jobId': job.jobId,
        'workItemId': job.workItemId,
        'previousState': job.state.wire,
        'action':
            'requeued; the lane is idempotent, so re-running produces no second '
            'baseline revision and no second approval request',
      });
      reconciled.add(job.jobId);
    }
    return reconciled;
  }

  Future<List<Job>> _eligibleJobs(DateTime now) async {
    final eligible = <Job>[];
    for (final job in await _onboardingJobs()) {
      if (job.isTerminal) continue;
      if (!_queue.isEligibleAt(job, now)) continue;
      eligible.add(job);
    }
    // The same deterministic ordering the triage scheduler uses, so a pass is
    // reproducible from the durable record alone.
    eligible.sort(JobQueue.orderEligible);
    return eligible;
  }

  Future<List<Job>> _onboardingJobs() async => (await jobStore.listJobs())
      .where((job) => job.jobType == jobType)
      .toList();

  /// Claims one job, runs the lane, records the verdict. `null` means this
  /// process did not get the claim and the job stays where it was.
  Future<OnboardingLaneOutcome?> _dispatchOne(
    Job candidate,
    DateTime now,
  ) async {
    final current = (await jobStore.readJob(candidate.jobId)) ?? candidate;
    if (current.isTerminal || !_queue.isEligibleAt(current, now)) return null;

    final claim = await _queue.claim(
      job: current,
      ownerId: dispatcherId,
      now: now,
      lease: claimLease,
    );
    if (claim == null) return null;

    final claimed = (await jobStore.readJob(candidate.jobId)) ?? current;
    final running = await _markRunning(claimed, now);

    final target = tryDecodeOnboardingDedupeKey(claimed.dedupeKey);
    if (target == null) {
      // Claimed first, on purpose: an undecodable key is a fact about a durable
      // record, and the claim is what stops two passes from reaching that same
      // conclusion twice. Refusing before the claim would leave the job queued
      // and eligible for ever, which is the failure class this whole lane was
      // opened to end.
      log?.call('baseline.dispatch.target_undecodable', {
        'jobId': claimed.jobId,
        'action':
            'the dedupe key does not name a product, repository and pinned '
            'revision; the job is failed rather than guessed at',
      });
      return _adopt(
        running ?? claimed,
        OnboardingFaulted(
          code: undecodableTargetCode,
          reason:
              'the dedupe key on this job does not decode into a product, a '
              'repository and a pinned revision, so there is nothing to acquire '
              'and nothing may be guessed at. It was written by something other '
              'than onboardingDedupeKey.',
          transient: false,
        ),
        now,
      );
    }

    if (running != null && running.workItemId != target.workItemId) {
      // The durable record disagrees with the key about which product this job
      // is for. Refusing is the only safe reading: acting on either half would
      // either derive a baseline for the wrong product or skip a job that was
      // enqueued for a real one.
      return _adopt(
        running,
        OnboardingFaulted(
          code: 'ONBOARDING_TARGET_MISMATCH',
          reason:
              'the job is filed under ${running.workItemId} while its dedupe '
              'key names ${target.productId}. Refusing to act on a record that '
              'disagrees with itself.',
          transient: false,
        ),
        now,
      );
    }

    log?.call('baseline.dispatch.claimed', {
      'jobId': claimed.jobId,
      'productId': target.productId,
      'repositoryId': target.repositoryId,
      'pinnedRevision': target.pinnedRevision,
      'attempt': running?.attempt ?? claimed.attempt,
      'leaseMinutes': claimLease.inMinutes,
    });

    final outcome = await _run(target, running ?? claimed);
    return _adopt(running ?? claimed, outcome, now);
  }

  /// Marks the claimed job as in flight.
  ///
  /// ## Why this is not `JobQueue.markRunning`
  ///
  /// That method takes a `workerId` and a `workerExecutionId` and writes them
  /// into a [JobExecutionReference]. An onboarding job runs on no worker and
  /// starts no execution, so there is no execution id to write and writing a
  /// synthetic one would leave a reference a reader could follow to nothing —
  /// which `Scheduler._executionReference` already calls a dangling link and
  /// refuses to persist on principle. So the state transition is done here
  /// against the same version-CAS the queue uses, with no execution reference.
  ///
  /// The scheduler event is appended here too rather than skipped, because the
  /// event tail is how a reader tells "claimed and about to run" from "claimed
  /// and nothing more happened", and a pass that silently skipped it would look
  /// identical to one that had not run.
  Future<Job?> _markRunning(Job job, DateTime now) async {
    return jobStore.inTransaction((tx) async {
      final current = await tx.readJob(job.jobId);
      if (current == null || current.state != JobState.claimed) return null;
      final updated = current.copyWith(
        state: JobState.running,
        startedAt: current.startedAt ?? now,
        version: current.version + 1,
      );
      try {
        await tx.saveJob(updated, expectedVersion: current.version);
      } on ConcurrentJobModificationException {
        return null;
      }
      final prior = await tx.readEvents(current.jobId);
      await tx.appendEvent(
        SchedulerEventRecord(
          eventId: 'se-${current.jobId}-${prior.length + 1}',
          jobId: current.jobId,
          workItemId: current.workItemId,
          sequence: prior.length + 1,
          type: SchedulerEventType.jobDispatched,
          occurredAt: now,
          payload: const {
            'dispatcher': 'baseline-product',
            'note': 'no worker execution: the baseline lane runs in-process',
          },
        ),
      );
      return updated;
    });
  }

  /// Runs the lane, converting anything it raises into a named fault.
  ///
  /// A raise is never allowed to escape: the caller is a loop over other
  /// products, and an exception that aborts the pass would leave them
  /// un-dispatched while reporting a failure that names only one of them.
  Future<OnboardingLaneOutcome> _run(OnboardingTarget target, Job job) async {
    try {
      return await runner(
        OnboardingLaneRequest(
          jobId: job.jobId,
          productId: target.productId,
          repositoryId: target.repositoryId,
          pinnedRevision: target.pinnedRevision,
          attempt: job.attempt,
        ),
      );
    } on Object catch (error, stackTrace) {
      // A store compare-and-swap loss DOES carry a claim about whether the
      // same call would succeed: it means another writer already advanced
      // the row, so the lane's attempt raced rather than failed. That is
      // transient by construction — F-241's `Concurrent modification of
      // <item|execution>` classified permanent on the agent lanes for the
      // same reason this branch exists for the baseline lane. Every OTHER
      // exception keeps the permanent verdict: it still carries no claim.
      final contention =
          isStoreContentionError(error) ||
          error is ConcurrentJobModificationException;
      log?.call('baseline.dispatch.lane_raised', {
        'jobId': job.jobId,
        'productId': target.productId,
        'repositoryId': target.repositoryId,
        'error': error.toString(),
        'stack': stackTrace.toString(),
        'retry': contention,
        'action': contention
            ? 'transient: a store compare-and-swap loss means another writer '
                  'already advanced the row; the job retries within its '
                  'attempt bound'
            : 'permanent: an exception carries no claim about whether the '
                  'same call would succeed, so it is not retried '
                  'automatically',
      });
      return OnboardingFaulted(
        code: laneThrewCode,
        reason: error.toString(),
        transient: contention,
      );
    }
  }

  /// Records the lane's verdict on the job.
  ///
  /// ## Why a refusal terminates as `failed`, not `succeeded`
  ///
  /// `succeeded` on an onboarding job means "a baseline exists, and a human was
  /// asked about it". `getOnboardingStatus` reads exactly that to decide an
  /// onboarding ran, and a refusal recorded as `succeeded` would tell an
  /// operator a product has a baseline it does not have. The refusal is not
  /// hidden by being folded into a success — it is in the failure reason, and
  /// it is counted in [BaselineDispatchResult.refused] and logged under its own
  /// code.
  ///
  /// ## Why a permanent fault is terminal and a transient one retries
  ///
  /// The bounded retry is the job's own `maxAttempts` and it is consulted here,
  /// exactly as `RetryPolicy.canRetry` consults it: a retry consumes an attempt
  /// and nothing may exceed the bound. [OnboardingFaulted.transient] is the
  /// lane's call and this method does not second-guess it.
  Future<OnboardingLaneOutcome> _adopt(
    Job prior,
    OnboardingLaneOutcome outcome,
    DateTime now,
  ) async {
    final current = (await jobStore.readJob(prior.jobId)) ?? prior;
    if (current.isTerminal) return outcome;
    final queue = _queue;

    switch (outcome) {
      case OnboardingAwaitingApproval():
        await queue.complete(
          job: current,
          terminal: JobState.succeeded,
          now: now,
        );
        log?.call('baseline.dispatch.awaiting_approval', {
          'jobId': current.jobId,
          'workItemId': current.workItemId,
          'baselineId': outcome.baselineId,
          'baselineRevision': outcome.revision,
          'sourceRevision': outcome.sourceRevision,
          'decisionId': outcome.decisionId,
          'factCount': outcome.factCount,
          'alreadyVerified': outcome.alreadyVerified,
          'gate': 'awaiting human approval; no automation resolves this',
        });

      case OnboardingRefused():
        final settled = await queue.complete(
          job: current,
          terminal: JobState.failed,
          failure: JobFailure(
            code: JobFailureCode.executionFailed,
            kind: JobFailureKind.permanent,
            reason: '${outcome.code}: ${outcome.reason}',
          ),
          now: now,
        );
        log?.call('baseline.dispatch.refused', {
          'jobId': current.jobId,
          'workItemId': current.workItemId,
          'code': outcome.code,
          'reason': outcome.reason,
          'state': settled.state.wire,
          'note': 'no baseline was produced and no gate was opened',
        });

      case OnboardingFaulted():
        final failure = JobFailure(
          code: JobFailureCode.executionFailed,
          kind: outcome.transient
              ? JobFailureKind.transient
              : JobFailureKind.permanent,
          reason: '${outcome.code}: ${outcome.reason}',
        );
        if (outcome.transient && current.attempt < current.maxAttempts) {
          await queue.scheduleRetry(
            job: current,
            failure: failure,
            now: now,
            retryDelay: retryDelay,
          );
        } else {
          await queue.complete(
            job: current,
            terminal: JobState.failed,
            failure: failure,
            now: now,
          );
        }
    }
    return outcome;
  }
}

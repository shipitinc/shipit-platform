import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import '../queue/job_queue.dart';
import '../store/job_store.dart';
import 'capacity_lockable_store.dart';
import 'execution_capacity.dart';

/// The verdict for one claim attempt against the global execution-capacity
/// budget.
///
/// Denial is a normal, expected outcome under load — it is what "queued" means
/// — so it is a value, not an exception, and never an error on the job.
@immutable
sealed class CapacityAdmission {
  const CapacityAdmission();

  /// Whether this attempt consumed a slot. Only [CapacityAdmitted] did.
  bool get isAdmitted => this is CapacityAdmitted;

  /// Whether the job was refused a slot because the budget was full. Such a
  /// job was never claimed and never written: it remains exactly as it was.
  bool get isDenied => this is CapacityDenied;
}

/// A slot was taken. [claim] is the durable lease; its presence is the proof
/// that the slot is held, which is why the admission and the reservation are
/// the same fact rather than two facts that can disagree.
final class CapacityAdmitted extends CapacityAdmission {
  const CapacityAdmitted({
    required this.claim,
    required this.inFlightBefore,
    required this.capacity,
  });

  final JobClaim claim;

  /// In-flight executions observed immediately before this one was admitted.
  final int inFlightBefore;

  final int capacity;
}

/// The budget was full. No claim was attempted and nothing was written: the
/// job stays `queued`/`retryWaiting` and is retried by a later tick.
///
/// This is the shape a job denied a slot takes. It is explicitly NOT a failure,
/// NOT a cancellation, and NOT a drop — see the retry contract on
/// [Scheduler]'s dispatch loop, which is what keeps it that way.
final class CapacityDenied extends CapacityAdmission {
  const CapacityDenied({
    required this.jobId,
    required this.inFlight,
    required this.capacity,
    required this.budget,
  });

  /// The job that was refused a slot.
  final String jobId;

  /// In-flight executions observed while the budget lock was held.
  final int inFlight;

  final int capacity;

  final String budget;

  /// One greppable payload naming the job, the budget, the observed count and
  /// the cap, so a saturated queue is diagnosable from the audit log instead of
  /// only from a host that fell over.
  Map<String, Object?> toEventPayload() => {
    'outcome': 'capacityDenied',
    'jobId': jobId,
    'budget': budget,
    'inFlight': inFlight,
    'cap': capacity,
  };

  @override
  String toString() =>
      'capacity denied for job $jobId: budget=$budget inFlight=$inFlight '
      'cap=$capacity';
}

/// The slot was available but the claim CAS lost to a concurrent writer. The
/// job was not admitted by this attempt; a later tick retries it. Distinct from
/// [CapacityDenied] because the budget was not the reason.
final class CapacityClaimLost extends CapacityAdmission {
  const CapacityClaimLost();
}

/// Enforces the global execution-capacity budget AT CLAIM TIME.
///
/// ## Where the check lives, and why
///
/// Inside the very transaction that claims the job, under an exclusive lock on
/// the budget, counting in-flight executions from durable `job.state`.
///
/// Three properties fall out of that placement, and each is lost if the check
/// is moved anywhere else:
///
///  * **Atomic with the reservation.** "A slot was taken" and "the capacity was
///    checked" are one commit, so there is no window in which the scheduler
///    believes it admitted work it did not, or vice versa.
///  * **Correct under more than one replica.** The lock is what makes the
///    count-then-claim pair indivisible; the job CAS alone cannot, because each
///    replica contends for a DIFFERENT job while counting the same budget.
///  * **Survives restart.** In-flight work is read from `job.state`, not from a
///    counter in this process. After a crash, jobs left `claimed`/`running`
///    still occupy their slots until reconciliation reclaims them — the
///    opposite of an in-process semaphore, which resets to zero exactly when
///    executions are still running.
///
/// ## Global, not per-product
///
/// The budget is one budget for the whole cluster (§3.3). Nine queued defects
/// for a single product are nine slots of one budget, not nine separate
/// budgets. Scoping the budget to a product bounds nothing at the host while
/// appearing to.
class JobCapacityGuard {
  JobCapacityGuard({
    required JobStore store,
    required this.capacity,
    JobQueue? queue,
  }) : _store = store,
       _queue = queue ?? JobQueue(store: store);

  final JobStore _store;
  final JobQueue _queue;

  /// The resolved cap. Cannot be constructed without a successful parse — see
  /// [ExecutionCapacityResolution.fromEnvironment].
  final ExecutionCapacity capacity;

  /// Attempts to admit [job] into the budget.
  ///
  /// On [CapacityAdmitted] the job holds a slot and a durable claim. On
  /// [CapacityDenied] nothing was written at all — not the job, not the claim,
  /// not a failure — so the job is exactly as it was and remains eligible for a
  /// later tick.
  ///
  /// Throws [CapacityLockUnavailable] when the store cannot make count-then-
  /// claim atomic. Denying silently would be the failure mode this whole
  /// mechanism exists to prevent: a cap that cannot be enforced must be loud,
  /// not absent.
  Future<CapacityAdmission> tryAdmit({
    required Job job,
    required String ownerId,
    required DateTime now,
    required Duration lease,
  }) async {
    final locking = _store;
    // Dart does not type-promote to an `interface class`, so the narrowing is
    // an explicit cast. The null check above is the whole safety argument: a
    // store that cannot serialise count-then-claim cannot enforce the budget,
    // and pretending otherwise is the failure this guard exists to prevent.
    if (locking is! CapacityLockingJobStore) {
      throw CapacityLockUnavailable(locking.runtimeType.toString());
    }
    final cap = capacity.maxConcurrentExecutions;

    return (locking as CapacityLockingJobStore).inCapacityLockedTransaction(
      capacity.advisoryLockKey,
      (tx) async {
        // Counted while the budget lock is held, from durable state, over
        // EVERY job — not this job's siblings, not one product, not one
        // worker. The budget is global, so the count is global.
        //
        // The job being claimed here is `queued` at this moment, so it cannot
        // count itself; the count is always "other work already in flight".
        final inFlight = await _countInFlight(tx);

        if (inFlight >= cap) {
          return CapacityDenied(
            jobId: job.jobId,
            inFlight: inFlight,
            capacity: cap,
            budget: capacity.budget,
          );
        }

        final claim = await _queue.claimWithin(
          tx,
          job: job,
          ownerId: ownerId,
          now: now,
          lease: lease,
        );
        if (claim == null) return const CapacityClaimLost();
        return CapacityAdmitted(
          claim: claim,
          inFlightBefore: inFlight,
          capacity: cap,
        );
      },
    );
  }

  /// In-flight = a slot is held: the job is `claimed` (a lease exists but
  /// dispatch has not started) or `running` (an execution exists).
  ///
  /// `claimed` counts deliberately. The slot is taken at claim time, so it must
  /// be counted from claim time; counting only `running` would free a slot in
  /// the window between claim and dispatch and let the cap be exceeded by
  /// exactly the number of jobs in that window.
  Future<int> _countInFlight(JobStore tx) async {
    final jobs = await tx.listJobs();
    var count = 0;
    for (final job in jobs) {
      if (job.state == JobState.claimed || job.state == JobState.running) {
        count++;
      }
    }
    return count;
  }
}

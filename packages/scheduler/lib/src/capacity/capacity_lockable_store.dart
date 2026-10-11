import 'package:meta/meta.dart';

import '../store/job_store.dart';

/// The capability a [JobStore] must provide for the global execution-capacity
/// guard to be enforceable ACROSS PROCESSES.
///
/// ## Why this is a capability and not a method on [JobStore]
///
/// The guard's correctness rests on one thing: between "count the in-flight
/// executions" and "claim one", no other scheduler may do the same. Without
/// that mutual exclusion, two replicas both read `inFlight = C-1`, both admit,
/// and the cap is exceeded by exactly one per replica — silently, on every
/// tick, under exactly the burst load the cap exists to stop.
///
/// On PostgreSQL that exclusion is `pg_advisory_xact_lock`, which is held until
/// the enclosing transaction ends and is therefore released by COMMIT, ROLLBACK
/// and connection loss alike. Nothing in the [JobStore] surface can express it,
/// because [JobStore.inTransaction] opens a transaction but does not say
/// anything about locks.
///
/// This interface is therefore declared in the scheduler package and
/// IMPLEMENTED by whichever store is durable. A store that cannot honour it
/// cannot enforce a cluster-wide cap, and [JobCapacityGuard] refuses to admit
/// anything rather than pretending a per-process lock is the same thing.
///
/// ## Contract for implementers
///
/// An implementation must:
///
///  1. run [body] inside a single store transaction, exactly as
///     [JobStore.inTransaction] does, so the count and the claim commit or roll
///     back together;
///  2. acquire the exclusive lock for [lockKey] BEFORE [body] observes any
///     state, and hold it until the transaction has ended — two concurrent
///     callers must be serialized, not merely both delayed;
///  3. release the lock on every exit path, including failure. A
///     transaction-scoped lock gives this for free; a session-scoped one must
///     release in a `finally`, or one thrown error wedges the budget forever;
///  4. pass [body] a [JobStore] handle bound to the open transaction.
///
/// The key is derived by [ExecutionCapacity.advisoryLockKey] so every process
/// computes the same number from the same budget name.
abstract interface class CapacityLockingJobStore {
  /// Runs [body] inside a transaction that first takes the exclusive,
  /// cross-connection lock for [lockKey].
  Future<T> inCapacityLockedTransaction<T>(
    int lockKey,
    Future<T> Function(JobStore store) body,
  );
}

/// Whether [store] can enforce a capacity budget across processes.
///
/// A store that cannot is not merely degraded — it is unable to make the
/// count-then-claim pair atomic, so a cap enforced on it would be advisory
/// only. [JobCapacityGuard] treats that as UNSATISFIABLE and denies.
bool storeCanLockCapacity(JobStore store) => store is CapacityLockingJobStore;

/// A named, log-safe statement of why a store cannot enforce the cap. Never
/// silently swallowed by callers.
@immutable
class CapacityLockUnavailable implements Exception {
  const CapacityLockUnavailable(this.storeType);

  final String storeType;

  @override
  String toString() =>
      'capacity guard unavailable: $storeType does not implement '
      'CapacityLockingJobStore, so the in-flight count and the claim cannot be '
      'made atomic across processes. Denying dispatch rather than running '
      'unbounded or pretending a per-process lock is a cluster-wide one.';
}

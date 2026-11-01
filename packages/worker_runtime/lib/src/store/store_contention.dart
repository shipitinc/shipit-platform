import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:workflow_store/workflow_store.dart';

import 'worker_store.dart';

/// Fixed prefix a worker puts on `WorkerExecutionResult.failureDetail` — and
/// on the `WorkerExecution.reason` persisted beside it — when the run's
/// settle was ended by losing a store compare-and-swap rather than by an
/// outcome the execution actually produced.
///
/// ## WHY A MARKER AT ALL
///
/// The classification of a worker outcome crosses a package boundary.
/// `LocalWorker._drive` catches a thrown store exception as a plain `Object`
/// and flattens it to a string, so by the time `packages/scheduler`'s
/// `RetryPolicy.classify` sees the result the exception TYPE is gone — only
/// the detail survives. A lost compare-and-swap is inherently TRANSIENT:
/// another writer already advanced the row, so the correct job verdict is a
/// bounded retry, never a terminal `executionFailed`. QA confirmed six jobs
/// failed exactly that way (F-241) when the detached-dispatch topology
/// (F-237) made the detached continuation, the tick and the reconcile pass
/// write the same entities concurrently — races the old in-tick dispatch
/// never produced.
///
/// The compare-and-swap itself is CORRECT protection and is deliberately not
/// touched: the defect is the classification of LOSING it.
///
/// ## WHY THE MARKER LIVES HERE AND NOT IN THE SCHEDULER
///
/// `supersededExecutionMarker` needed the literal pinned on BOTH sides of the
/// boundary because its producer (`execution_coordinator`) cannot be a
/// dependency of its consumer (`scheduler`). This marker has no such
/// constraint: `scheduler` already depends on `worker_runtime`, so both sides
/// reference THIS constant at compile time. One literal, no drift — a rename
/// breaks the build instead of silently reverting to the permanent
/// classification.
const String storeContentionMarker = 'store_contention:';

/// Whether [error] is a store compare-and-swap loss — the typed half of the
/// marker contract, checked by the worker BEFORE the exception is flattened
/// to a string.
///
/// The family is deliberately the three compare-and-swap exceptions the
/// platform's stores throw, matched by TYPE so a reworded `toString()` cannot
/// change the classification:
///
///  * [ConcurrentWorkerModificationException] — the `worker_execution` row
///    itself was advanced by another writer (a scheduler zombie reclaim, the
///    worker reconciler). The winner's verdict owns that row.
///  * [ConcurrentExecutionModificationException] — the `agent_execution`
///    row was advanced by a concurrent coordinator writer (a budget expiry,
///    `reconcileOrphans`, a racing finalize).
///  * [ConcurrentModificationException] — the `work_item` row was advanced
///    by whoever moved the item (a tick's reconcile, an orphan reclaim, a
///    racing completion).
///
/// A CAS exception type this predicate does not know fails CLOSED — it
/// classifies permanent exactly as before — and the test asserting this
/// predicate on all three types is what keeps the family enumerable.
bool isStoreContentionError(Object error) =>
    error is ConcurrentWorkerModificationException ||
    error is ConcurrentExecutionModificationException ||
    error is ConcurrentModificationException;

/// Whether [detail] — the `failureDetail` a worker execution reported, or the
/// `reason` persisted on its terminal row — records a store compare-and-swap
/// loss. The consumer is `RetryPolicy.classify` in `packages/scheduler`,
/// which reclassifies the outcome `transient` so the job retries instead of
/// failing terminally.
///
/// Only a failure detail can carry this: the marker is written beside
/// `WorkerExecutionStatus.executedFail`, never a pass.
bool isStoreContentionDetail(String? detail) =>
    detail != null && detail.startsWith(storeContentionMarker);

import 'package:platform_contracts/platform_contracts.dart';

/// Machine-readable prefix a supersession puts on the failure detail it hands
/// back to the scheduler.
///
/// ## Why this exists
///
/// `WorkItemSupersededException` (packages/execution_coordinator) is raised
/// BEFORE the execution row and the agent session exist — nothing ran and
/// nothing was produced. Live QA on 2026-10-13 showed what the scheduler did
/// with that fact: it classified the resulting `executedFail` as a permanent
/// failure, so the job went terminally `failed`, consumed its retry budget,
/// and the work item was left with nothing queued against it until a human
/// intervened.
///
/// A terminal `failed` is a lie in that case. It asserts an execution that
/// never happened, and the consequence of believing it is a stranded item.
///
/// ## Why it is a marker and not just the prose
///
/// The failure crosses a package boundary the scheduler does not own.
/// `WorkerDispatch.run` throws, `LocalWorker` catches it as a plain `Object`
/// and flattens `toString()` into `WorkerExecutionResult.failureDetail` under a
/// generic `agentFailed` / `executedFail`. By the time the scheduler adopts the
/// outcome, the exception TYPE is gone; only the string survives. The only
/// positively-identifying signal left is a fixed prefix, because every other
/// field is either shared with genuine failures or absent:
///
///  * `failureCode` is `agentFailed` for a real agent failure too, and
///    `WorkerFailureCode` lives in `platform_contracts`, which this lane may
///    not change;
///  * `agentResultStatus == null` is ALSO true for an orphaned session and for
///    a session that never reached a terminal state, so it cannot separate
///    "nothing ran" from "something ran and died";
///  * `agentExecutionId` is minted by the worker before it calls the driver,
///    so it is present even when the coordinator refused before writing an
///    execution row.
///
/// A structural "nothing ran" signature therefore cannot be used, and a prefix
/// is what is actually available.
///
/// ## The cost, stated plainly
///
/// The marker is matched literally on both sides of a package boundary neither
/// package's author controls at compile time. If they diverge, supersession
/// detection silently reverts to the terminal-failure behaviour above — no
/// exception, no failed test, just the old defect back. The mitigation is that
/// BOTH ends pin the literal: `stale_completion_test.dart` in
/// `execution_coordinator` asserts `toString()` starts with
/// `WorkItemSupersededException.marker`, and `supersession_requeue_test.dart`
/// here asserts a captured detail still satisfies
/// [isSupersededExecution]. Either side changing alone breaks a test.
///
/// The durable fix is a typed signal — a `WorkerFailureCode` value, or a typed
/// catch in `worker_runtime`'s `LocalWorker` (which already depends on
/// `execution_coordinator`) — and that needs `platform_contracts` /
/// `worker_runtime` opened to a lane that owns them.
const String supersededExecutionMarker = 'work_item_superseded:';

/// Whether [detail] — the `failureDetail` a worker execution reported —
/// records a supersession: the work item moved before the execution started,
/// so nothing ran and nothing was produced.
///
/// Only a genuinely failed outcome can carry this. A marker on a
/// [WorkerExecutionStatus.executedPass] result would be a contradiction, and
/// treating it as a deferral would requeue a job that actually succeeded.
bool isSupersededExecution(
  String? detail, {
  required WorkerExecutionStatus status,
}) {
  if (status == WorkerExecutionStatus.executedPass) return false;
  final text = detail;
  if (text == null) return false;
  return text.startsWith(supersededExecutionMarker);
}

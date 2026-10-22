import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart'
    show SchedulerWorkload, implementFeatureRequest;
import 'package:workflow_engine/workflow_engine.dart'
    show ModelSelectionService;

/// The implementation lane's request builder, with the lane's path-ownership
/// grant attached.
///
/// ## WHAT IT ADDS, AND WHY IT IS HERE
///
/// The grant is the set of repository-relative path globs the implementation
/// lane may touch. It is recorded on the WORK ITEM's metadata — authored
/// before the work is known, by whoever scoped the feature — and it is
/// captured into the durable EXECUTION record at dispatch, so the QA gate can
/// judge the change against what the lane was dispatched with.
///
/// The capture happens at dispatch, and this function is the dispatch-time
/// boundary for the implementation lane: it is the last place where the work
/// item and the request are both in hand.
///
/// ## WHY IT WRAPS AND DOES NOT REPLACE THE SCHEDULER'S BUILDER
///
/// `packages/scheduler/**` is not the implementation lane's to edit, and the
/// scheduler's builder knows nothing about path ownership. Wrapping keeps ONE
/// builder of the request — the scheduler's — and adds exactly one field to
/// it. The wrapper copies the request rather than rebuilding it field by
/// field, so a field added to the request later cannot be silently dropped
/// here.
///
/// ## WHY AN EMPTY GRANT LEAVES THE REQUEST ALONE
///
/// A work item with no grant produces a request with no grant, and the gate
/// that judges it refuses an empty owned set. That is the fail-closed
/// direction, and it is reached by doing nothing here rather than by inventing
/// a set.
Future<WorkerExecutionRequest> implementationRequestWithPathOwnership(
  Job job,
  SchedulerWorkload workload,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  final request = await implementFeatureRequest(
    job,
    workload,
    item,
    modelSelection,
  );
  final granted = declaredOwnedPathsFromMetadata(item.metadata);
  if (granted.isEmpty) return request;
  return request.copyWith(declaredOwnedPaths: granted);
}

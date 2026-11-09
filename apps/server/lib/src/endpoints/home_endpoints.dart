import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/decision_view.dart';
import '../generated/overview.dart';
import '../generated/work_item_view.dart';
import '../services/control_plane_service.dart';
import '../services/ui_view_mappers.dart';

/// Endpoints for the Home dashboard overview.
class HomeEndpoints extends Endpoint {
  /// Test/override seam for the service this endpoint builds.
  ///
  /// `@doNotGenerate` is REQUIRED and is not decoration. Serverpod treats
  /// every public, non-`@doNotGenerate`, `Session`-first method on an
  /// `Endpoint` as a wire endpoint and fails generation unless it returns
  /// `Future` or `Stream`; this returns a plain `ControlPlaneService`, so
  /// without the annotation `serverpod generate` exits 1. The same seam
  /// exists on `WorkItemActionEndpoints` for the same reason: it is what lets
  /// a unit test drive the REAL endpoint methods over in-memory stores.
  @doNotGenerate
  ControlPlaneService serviceFor(Session session) =>
      ControlPlaneService(session);

  /// Returns summary counts plus the supporting detail the Overview screen
  /// renders: the finished pass/fail split, a server-stamped freshness marker,
  /// and the queue/capacity strip.
  ///
  /// Everything here is derived from durable records only — no estimates. The
  /// screen states "Every number on this page comes straight from the system's
  /// own records", so a value that cannot be read is reported as zero/absent
  /// rather than inferred.
  Future<Overview> overview(Session session) async {
    final service = serviceFor(session);
    final allItems = await service.readAllWorkItems();

    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(hours: 24));

    // Running: only actively executing states. This intentionally mirrors
    // PlainStatus.workingOnIt in apps/control_plane/lib/core/plain_language.dart
    // so the Overview metric and the row STATUS agree.
    final running = allItems
        .where(
          (item) =>
              item.blockingHumanDecisionId == null &&
              (item.state == WorkItemState.planning ||
                  item.state == WorkItemState.agentExecuting ||
                  item.state == WorkItemState.qaInProgress ||
                  item.state == WorkItemState.deploying),
        )
        .length;

    // Waiting on you: items whose blocking decision still awaits an answer.
    //
    // A work item can retain a `blockingHumanDecisionId` after that decision
    // has been answered, so the pointer alone overstates the queue. Counting
    // it would disagree with the Needs you screen, which reads the decisions
    // themselves. The decision record is the authority.
    //
    // `isOpen`, not `!isResolved`: a `cancelled` decision is terminal without
    // having been answered, so an item whose pointer names a voided decision
    // is stuck-but-not-awaiting-an-answer — and `pendingDecisions` below will
    // not surface it. Counting it here would put a number on the card strip
    // that no card can satisfy. A missing decision row still counts: the
    // pointer asserts the item IS blocked, and an unverifiable row is not a
    // reason to clear it.
    var waitingOnYou = 0;
    for (final item in allItems) {
      if (item.blockingHumanDecisionId == null || item.state.isTerminal) {
        continue;
      }
      final decisions = await service.readDecisionsForWorkItem(
        item.workItemId,
      );
      final blocking = decisions
          .where((d) => d.decisionId == item.blockingHumanDecisionId)
          .firstOrNull;
      if (blocking == null || blocking.status.isOpen) waitingOnYou++;
    }

    // Recently finished: terminal states in last 24h
    final finishedRecently = allItems
        .where(
          (item) =>
              item.state.isTerminal &&
              item.completedAt != null &&
              item.completedAt!.isAfter(oneDayAgo),
        )
        .toList();

    // "passed" is the successful terminal state; cancelled/terminated are the
    // unsuccessful ones. `WorkItemState.isTerminal` covers both, so split on
    // the successful member explicitly rather than by exclusion.
    final finishedPassed = finishedRecently
        .where(
          (item) =>
              item.state == WorkItemState.completed ||
              // ignore: deprecated_member_use
              item.state == WorkItemState.done,
        )
        .length;

    final blockedWorkItemIds = allItems
        .where((item) => item.blockingHumanDecisionId != null)
        .map((item) => item.workItemId)
        .toSet();

    // Only pending work belongs on the strip; finished jobs are history.
    final jobs =
        (await service.listJobs())
            .where(
              (job) =>
                  job.state == JobState.queued ||
                  job.state == JobState.claimed ||
                  job.state == JobState.running ||
                  job.state == JobState.retryWaiting,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final workers = await service.listWorkers();
    final executions = await service.listWorkerExecutions();
    // A worker counts as busy while it holds a non-terminal execution.
    final busyWorkerIds = executions
        .where(
          (execution) =>
              !execution.status.isTerminal && execution.workerId != null,
        )
        .map((execution) => execution.workerId!)
        .toSet();

    return Overview(
      running: running,
      waitingOnYou: waitingOnYou,
      recentlyFinished: finishedRecently.length,
      finishedPassed: finishedPassed,
      finishedFailed: finishedRecently.length - finishedPassed,
      generatedAt: now,
      jobs: jobs
          .map(
            (job) => UiViewMappers.jobSummaryView(
              job,
              blockedOnDecision: blockedWorkItemIds.contains(job.workItemId),
            ),
          )
          .toList(),
      machinesBusy: busyWorkerIds.length,
      // A worker running an execution is a machine even when its
      // registration is missing or stale, so busy can never exceed total.
      machinesTotal: {
        ...workers.map((worker) => worker.workerId),
        ...busyWorkerIds,
      }.length,
    );
  }

  /// Lists work items with optional filters.
  ///
  /// [productId] narrows the list to one product's work, which is how the
  /// report-a-bug form keeps "affected work item" short enough to pick from
  /// once a product has been chosen.
  Future<List<WorkItemView>> listWorkItems(
    Session session, {
    String? state,
    String? productId,
    int? limit,
  }) async {
    final service = serviceFor(session);
    var items = await service.readAllWorkItems();

    if (state != null) {
      items = items.where((item) => item.state.wire == state).toList();
    }
    if (productId != null) {
      items = items.where((item) => item.productId == productId).toList();
    }

    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final maxResults = limit ?? 50;
    if (items.length > maxResults) {
      items = items.sublist(0, maxResults);
    }

    return items.map(UiViewMappers.workItemView).toList();
  }

  /// Lists decisions that already carry a durable outcome, newest first.
  ///
  /// Once a decision is resolved its work item is no longer blocked, so it
  /// drops out of [pendingDecisions] entirely. The operator surface still has
  /// to show what was decided ("Already decided"), which needs its own read.
  /// [offset] skips the newest N, so the caller can page as it scrolls. The
  /// ordering is stable (resolution time, newest first) which is what makes
  /// offset paging safe to use here.
  Future<List<DecisionView>> recentDecisions(
    Session session, {
    int? limit,
    int? offset,
  }) async {
    final service = serviceFor(session);
    final allItems = await service.readAllWorkItems();

    // `isResolved` stays the membership test even though `cancelled` is also
    // terminal. The 'Already decided' ledger's client splits rows on
    // `choice != null`, and a voided decision carries no choice — admitting
    // `cancelled` here would file a decision nobody answered under "decided"
    // on the server and under "pending" on the client. A voided decision's
    // audit home is the per-item decision list (`listDecisions`), not this
    // ledger.
    final decided = <(HumanDecision, WorkItem)>[];
    for (final item in allItems) {
      final decisions = await service.readDecisionsForWorkItem(
        item.workItemId,
      );
      for (final decision in decisions.where((d) => d.isResolved)) {
        decided.add((decision, item));
      }
    }

    // Newest first; decisions without a timestamp sort last.
    decided.sort((a, b) {
      final left = a.$1.timestamp;
      final right = b.$1.timestamp;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });

    final start = (offset ?? 0).clamp(0, decided.length);
    final maxResults = limit ?? 10;
    final end = (start + maxResults).clamp(start, decided.length);
    final page = decided.sublist(start, end);

    return page
        .map(
          (pair) => UiViewMappers.decisionView(
            decision: pair.$1,
            workItem: pair.$2,
          ),
        )
        .toList();
  }

  /// Lists pending blocking human decisions.
  ///
  /// Each card is the decision the work item says it is blocked on — the row
  /// named by [WorkItem.blockingHumanDecisionId] — surfaced only while that
  /// decision is still open. The item itself names its blocker, so this never
  /// has to pick among an item's decisions at all.
  Future<List<DecisionView>> pendingDecisions(
    Session session, {
    int? limit,
  }) async {
    final service = serviceFor(session);
    final allItems = await service.readAllWorkItems();

    // Get work items with pending blocking decisions
    final blockedItems = allItems
        .where(
          (item) =>
              item.blockingHumanDecisionId != null && !item.state.isTerminal,
        )
        .toList();

    // Fetch the actual decisions
    final decisions = <DecisionView>[];
    for (final item in blockedItems) {
      final itemDecisions = await service.readDecisionsForWorkItem(
        item.workItemId,
      );
      // The decision the item is ACTUALLY blocked on, and only while it is
      // still awaiting an answer.
      //
      // This used to take the FIRST `!isResolved && blocking` row — two
      // independent defects in one expression:
      //
      //  * `!isResolved` includes `cancelled`. A voided decision is terminal
      //    without having been answered (migration 20261014210000000 voided
      //    one such on QA), so it counted as "pending" and this list served
      //    it to the 'Needs your approval' card — which then linked to a
      //    decision nobody could ever open for an answer.
      //  * `firstOrNull` over `updatedAt ASC` picked the OLDEST matching row,
      //    not the item's current blocker. When a voided decision and a live
      //    one coexist, the voided one sorts first.
      //
      // The item's own `blockingHumanDecisionId` is the authority: it names
      // the decision holding the item, so there is nothing to order by and
      // no other row to mistake it for. `isOpen` is "still awaiting an
      // answer" — it surfaces pending/inProgress/escalated/deferred and
      // skips both answered and voided decisions. A stale pointer naming a
      // terminal decision surfaces NOTHING rather than guessing a different
      // row: a pointer that no longer names a live blocker is a data-repair
      // finding, not a card.
      final pendingDecision = itemDecisions
          .where(
            (d) =>
                d.decisionId == item.blockingHumanDecisionId && d.status.isOpen,
          )
          .firstOrNull;

      if (pendingDecision != null) {
        decisions.add(
          UiViewMappers.decisionView(
            decision: pendingDecision,
            workItem: item,
          ),
        );
      }
    }

    final maxResults = limit ?? 20;
    if (decisions.length > maxResults) {
      decisions.removeRange(maxResults, decisions.length);
    }

    return decisions;
  }
}

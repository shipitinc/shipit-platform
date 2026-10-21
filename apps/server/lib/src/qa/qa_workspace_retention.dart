import 'package:platform_contracts/platform_contracts.dart'
    show WorkItem, WorkItemState, WorkerCleanupStatus, WorkerExecution;
import 'package:worker_runtime/worker_runtime.dart'
    show EvaluationRetainingWorkspaceManager, WorkerStore;
import 'package:workflow_store/workflow_store.dart'
    show WorkItemNotFoundException, WorkflowStore;

/// The work-item states in which a retained workspace is still OWED to a gate
/// evaluation, and must therefore survive.
///
/// ## WHY THIS SET IS EXPLICIT
///
/// The retention exists because the QA gates re-read the producer's checkout
/// unconditionally. A workspace that is released while the item can still be
/// evaluated turns a quality question into an infrastructure one — which is
/// the exact outcome decision `9b7e4c31` was made to prevent. A workspace
/// that is held after the item can no longer be evaluated is a leak. So the
/// boundary between the two is stated, here, rather than implied by
/// whichever code path happens to run.
///
/// Every member is a state in which the item has ALREADY produced the
/// artefact the gates will read, and has not yet been evaluated:
///  * [WorkItemState.agentCompleted] — the implementation finished; the
///    review lane and then the QA lane are still to come.
///  * [WorkItemState.reviewInProgress] — the reviewer is looking at the
///    commit the implementation produced.
///  * [WorkItemState.reviewApproved] — a human approved the review; the QA
///    drain takes the item on its next tick.
///  * [WorkItemState.qaInProgress] — the drain took the item and is
///    evaluating it (or is about to, on the next tick).
///  * [WorkItemState.waitingForHumanDecision] — a human owes an answer. The
///    item has left the machine's hands, and the workspace is still owed to
///    the evaluation that follows the answer.
///  * [WorkItemState.qaFailed] — the evaluation FAULTED. A faulted evaluation
///    never completed, so the workspace is still owed to it, exactly as the
///    decision requires ("retained until gate evaluation completes"). A
///    faulted item at `qaFailed` carries NO durable `qaEvaluation` record —
///    the drain could not settle it — so the release rule below does not
///    fire and the workspace is held until the stall window reclaims it.
///
/// `qaPassed` is NOT here: it carries a durable `qaEvaluation` record, and
/// the evaluation being over is what releases the workspace (see
/// [QaWorkspaceRetention]).
///
/// ## WHY `qaFailed` IS HERE BUT `qaPassed` IS NOT
///
/// The two look like they should be treated alike and are not. A `qaFailed`
/// item that was SETTLED carries the durable `qaEvaluation` record, and the
/// release rule fires on that record before any state is consulted — so a
/// settled failure releases its workspace immediately, exactly like a pass.
/// The only `qaFailed` item that reaches this set is one whose evaluation
/// FAULTED: the drain could not record a verdict, the item cannot move, and a
/// human has to look at it. Releasing the workspace that human needs would
/// turn the fault into an infrastructure failure.
const Set<WorkItemState> qaWorkspaceBoundStates = {
  WorkItemState.agentCompleted,
  WorkItemState.reviewInProgress,
  WorkItemState.reviewApproved,
  WorkItemState.qaInProgress,
  WorkItemState.waitingForHumanDecision,
  WorkItemState.qaFailed,
};

/// The states in which the platform is waiting for a HUMAN, and therefore
/// paced by a person rather than by a tick.
///
/// ## WHY THESE HAVE NO STALL WINDOW
///
/// A stall window is a claim that "nothing is happening here any more". That
/// claim is safe in a machine-paced state and unsafe in a human-paced one: a
/// human who takes two weeks to answer a question is slow, not stuck, and a
/// window that expires their workspace would turn their answer into an
/// infrastructure failure — the failure mode this whole mechanism exists to
/// remove. So the window applies only to the states below's complement, and a
/// human-held workspace is released when the human's answer moves the item.
const Set<WorkItemState> qaWorkspaceHumanPacedStates = {
  WorkItemState.waitingForHumanDecision,
};

/// How long a machine-paced work item may sit in a QA-bound state before its
/// retained workspace is reclaimed.
///
/// ## WHY A WEEK
///
/// A week is longer than any tick-paced step in this pipeline takes by
/// orders of magnitude, and longer than a platform outage that would strand
/// an item mid-evaluation. It is short enough that an abandoned item's
/// worktree does not sit on disk indefinitely. The expiry is FAIL-CLOSED: the
/// gates that would have re-read the workspace find it gone and fail, which
/// surfaces the item to a human rather than letting it pass on evidence
/// nobody could re-derive.
const Duration kDefaultQaWorkspaceStallWindow = Duration(days: 7);

/// What one reclaim pass did.
class QaWorkspaceRetentionReport {
  const QaWorkspaceRetentionReport({
    required this.released,
    required this.kept,
    required this.failed,
    this.releasedWorkspaceIds = const [],
    this.reasons = const [],
  });

  /// Workspaces removed by this pass.
  final int released;

  /// Workspaces kept because the item can still be evaluated.
  final int kept;

  /// Workspaces this pass tried to release and could not.
  final int failed;

  /// The ids of the workspaces this pass released.
  final List<String> releasedWorkspaceIds;

  /// One sentence per decision this pass made that changed something, safe to
  /// log.
  final List<String> reasons;

  /// Whether this pass changed anything.
  bool get releasedAnything => released > 0;
}

/// Releases the QA workspaces whose evaluation is over.
///
/// ## WHAT IT OWNS
///
/// Decision `9b7e4c31` (`.decisions/qa-workspace-retention-until-evaluation.md`)
/// keeps the producer's checkout alive until the gate evaluation that reads
/// it has finished, and requires the checkout to be removed afterwards —
/// unconditionally, on a pass, on a failing verdict and on a fault alike.
///
/// This class is the "afterwards". It is a SWEEP, not a hook: it runs on
/// every tick, it is idempotent, and it finds the retained workspaces from the
/// durable record rather than from a queue that a crash could lose.
///
/// ## HOW IT KNOWS A WORKSPACE IS RETAINED
///
/// A worker's row records [WorkerCleanupStatus.pending] when its cleanup was
/// deferred. That is the platform's own word for "this workspace is still on
/// disk and its removal has not happened yet" — the same word the
/// `cleanupMissing` predicate reads. Nothing else in this repository consumes
/// that predicate, so the deferral is visible to the sweep and invisible to
/// every other reader.
///
/// ## WHAT HAPPENS ON AN INTERRUPT — AND THE RESIDUAL, STATED
///
/// The removal is unconditional, and the sweep is what makes it so:
///
///  * a run that FAILED or was INTERRUPTED still ends its run, so its row is
///    terminal and its cleanup status is `pending` — the sweep releases it on
///    the next tick, whatever the run's verdict was;
///  * a run whose PROCESS died mid-flight never reached its cleanup stage, so
///    its row says nothing about a cleanup at all. The scheduler's zombie
///    reclaim marks that row terminal (`orphaned`) and — deliberately — leaves
///    the cleanup status alone. This sweep is what finishes the job: it
///    releases the workspace once the row is terminal and the removal is
///    still outstanding;
///  * a release that was interrupted half-way is simply released by the next
///    pass. The sweep is idempotent.
///
/// THE RESIDUAL, PLAINLY: **a retained workspace whose platform process never
/// runs again stays on disk.** There is no timer outside the process, no
/// external reaper, and — by a decision recorded in this repository — no
/// in-process shutdown hook to hang a last release on. What bounds it is:
/// the worktree lives under ONE platform-owned workspace root rather than
/// wherever the agent happened to write; the ownership metadata beside it
/// proves the platform created it; the execution row records that a removal
/// is outstanding; and the FIRST tick of the next process releases it. What
/// does NOT bound it is a platform that is never started again — and that is
/// a machine-level outage, not a property of this policy.
class QaWorkspaceRetention {
  QaWorkspaceRetention({
    required this.workerStore,
    required this.workflowStore,
    required this.workspaceManager,
    DateTime Function()? clock,
    this.stallWindow = kDefaultQaWorkspaceStallWindow,
  }) : clock = clock ?? _utcNow;

  /// The durable record of what the workers did.
  final WorkerStore workerStore;

  /// The durable record of where the work items are.
  final WorkflowStore workflowStore;

  /// The manager that holds the retained workspaces, and can release them.
  final EvaluationRetainingWorkspaceManager workspaceManager;

  /// This sweep's clock. A test injects one so the stall window is exact
  /// rather than raced.
  final DateTime Function() clock;

  /// How long a machine-paced item may sit in a QA-bound state before its
  /// workspace is reclaimed. See [kDefaultQaWorkspaceStallWindow].
  final Duration stallWindow;

  /// Releases every retained workspace whose item can no longer be evaluated.
  ///
  /// Four rules, and only four:
  ///  1. the item carries a durable `qaEvaluation` record — the evaluation
  ///     that read the workspace is over, whatever its verdict was;
  ///  2. the item's state is not in [qaWorkspaceBoundStates] — the item left
  ///     the pipeline, so no evaluation will read the workspace;
  ///  3. the item is machine-paced, is QA-bound, and has not moved for
  ///     longer than [stallWindow] — it is stuck, and holding a worktree for
  ///     a stuck item is the leak this rule exists to bound.
  ///  4. the item cannot be read — kept, because an unreadable store is not
  ///     a verdict (see below).
  ///
  /// A workspace that none of the rules releases is KEPT. A workspace whose
  /// item cannot be read is KEPT as well: a store that cannot be read is not
  /// evidence that the item is gone, and a wrongly-released workspace breaks
  /// the evaluation that is about to read it.
  Future<QaWorkspaceRetentionReport> reclaim() async {
    final executions = await workerStore.listWorkerExecutions();
    final descriptors = await workspaceManager.discoverAll();
    // MATCHED BY EXECUTION, NOT BY `WorkerExecution.workspaceId`.
    //
    // The row's own `workspaceId` column is NOT a usable join key: the worker
    // layer never populates it. `LocalWorker._finish` writes
    // `workspaceId: current.workspaceId ?? ''`, and nothing ever sets
    // `current.workspaceId`, so every finished execution carries an EMPTY
    // string there — a join on it matches nothing, and the sweep would then
    // decide that every retained workspace had vanished while leaving the
    // worktree on disk.
    //
    // `WorkspaceDescriptor.workerExecutionId` IS the join key: the workspace
    // manager writes it from the execution request it prepared for, and it is
    // the same key `WorkerReconciler` already joins on.
    final byExecutionId = {
      for (final descriptor in descriptors)
        descriptor.workerExecutionId: descriptor,
    };

    var released = 0;
    var kept = 0;
    var failed = 0;
    final releasedIds = <String>[];
    final reasons = <String>[];

    for (final execution in executions) {
      if (!execution.isTerminal) continue;
      // `cleanupMissing` — the platform's own predicate for "a removal is
      // still outstanding" — rather than a comparison against one status.
      // It covers BOTH shapes that means:
      //  * `pending`: the run finished and its removal was DEFERRED (the
      //    retention), and
      //  * `null`: the run never reached its cleanup stage at all, because
      //    the process died mid-flight. A row that says nothing about a
      //    cleanup is exactly the row this sweep exists to finish.
      if (!execution.cleanupMissing) continue;

      final descriptor = byExecutionId[execution.workerExecutionId];
      if (descriptor == null) {
        // The workspace is not on disk any more — it was released, or it was
        // never created, or the ownership metadata is gone. Either way there
        // is nothing to remove, and the row must stop claiming that a
        // removal is outstanding.
        await _markRemoved(
          execution,
          execution.cleanupStatus == WorkerCleanupStatus.pending
              // A removal WAS owed and the workspace is gone: the row says
              // `removed`, because the removal happened.
              ? WorkerCleanupStatus.removed
              // The run never reached its cleanup stage and there is no
              // workspace: the row says `notApplicable`, because there was
              // never anything to remove. Writing `removed` there would
              // claim a removal that never happened.
              : WorkerCleanupStatus.notApplicable,
        );
        reasons.add(
          'the execution ${execution.workerExecutionId} has no workspace on '
          'disk, so the row stopped claiming an outstanding removal',
        );
        continue;
      }

      WorkItem? item;
      var itemIsGone = false;
      try {
        item = await workflowStore.readWorkItem(execution.workItemId);
      } on WorkItemNotFoundException {
        // The item does not exist. That is an ANSWER, not a failure: nothing
        // will ever evaluate this workspace, so it is released.
        item = null;
        itemIsGone = true;
      } on Object {
        // The item could not be READ. Keep the workspace: an unreadable
        // store is not a verdict, and the next pass will try again. A
        // wrongly-released workspace breaks the evaluation that is about to
        // read it, and a wrongly-kept one is released by the next pass.
        kept++;
        continue;
      }

      final decision = _releaseDecision(item, itemIsGone: itemIsGone);
      if (decision == null) {
        kept++;
        continue;
      }

      final status = await workspaceManager.release(descriptor);
      if (status != WorkerCleanupStatus.removed) {
        failed++;
        reasons.add(
          'the workspace ${descriptor.workspaceId} could not be removed '
          '($status): $decision',
        );
        continue;
      }
      await _markRemoved(execution, WorkerCleanupStatus.removed);
      released++;
      releasedIds.add(descriptor.workspaceId);
      reasons.add(
        'the workspace ${descriptor.workspaceId} was removed: $decision',
      );
    }

    return QaWorkspaceRetentionReport(
      released: released,
      kept: kept,
      failed: failed,
      releasedWorkspaceIds: releasedIds,
      reasons: reasons,
    );
  }

  /// Why this workspace may be released now, or `null` when it may not.
  String? _releaseDecision(WorkItem? item, {required bool itemIsGone}) {
    if (itemIsGone) {
      return 'the work item no longer exists, so no evaluation will read this '
          'workspace';
    }
    if (item == null) return null;
    if (item.metadata?['qaEvaluation'] != null) {
      return 'the item ${item.workItemId} carries a durable qaEvaluation '
          'record, so the evaluation that read this workspace is over';
    }
    if (!qaWorkspaceBoundStates.contains(item.state)) {
      return 'the item ${item.workItemId} is at ${item.state.wire}, which no '
          'longer leads to a QA evaluation of this workspace';
    }
    if (qaWorkspaceHumanPacedStates.contains(item.state)) {
      // A human owes an answer. Their pace is not a leak, and a timer that
      // expired their workspace would turn their answer into a failure.
      return null;
    }
    final stalledFor = clock().difference(item.updatedAt);
    if (stalledFor > stallWindow) {
      return 'the item ${item.workItemId} has been at ${item.state.wire} for '
          '${stalledFor.inDays}d without moving, so it is stuck and its '
          'workspace is reclaimed';
    }
    return null;
  }

  /// Records that the removal is no longer outstanding, so the row stops
  /// claiming that it is.
  ///
  /// The recorded status distinguishes two different histories that a single
  /// value would flatten: a removal that WAS owed and has now happened says
  /// `removed`, and a run that never had a workspace to remove says
  /// `notApplicable`.
  Future<void> _markRemoved(
    WorkerExecution execution,
    WorkerCleanupStatus status,
  ) async {
    try {
      await workerStore.saveWorkerExecution(
        execution.copyWith(
          cleanupStatus: status,
          version: execution.version + 1,
        ),
        expectedVersion: execution.version,
      );
    } on Object {
      // Another writer moved the row. Its verdict stands; the next pass
      // re-reads it.
    }
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

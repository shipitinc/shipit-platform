import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, resolveProducerExecution;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart'
    show CommitProduced, producedCommitFor;
import 'package:worker_runtime/worker_runtime.dart' show WorkerStore;
import 'package:workflow_store/workflow_store.dart' show WorkflowStore;

import '../credentials/secretless_error.dart' show secretlessText;
import 'deploy_push.dart' show DeployPush, DeployPusher;

/// Raised when an approved deployment cannot be made true.
///
/// The reason is safe to surface to the operator who approved the deploy:
/// every interpolated value is a work item id, an execution id, a git
/// revision, a repository path or a git exit report — never a credential.
///
/// ## WHAT A THROW MEANS, EXACTLY
///
/// Nothing durable was written: no resolved decision, no moved work item.
/// The `deploymentApproval` decision stays PENDING and the item stays
/// parked at `waiting_for_human_decision`, so the human's approve is not
/// consumed by a platform failure — they can retry the same approve after
/// the cause is fixed, or reject and reach `deployment_failed` through the
/// edge that already exists.
class DeployLandingException implements Exception {
  const DeployLandingException(this.reason);

  final String reason;

  @override
  String toString() => 'DeployLandingException: $reason';
}

/// The work item metadata keys that record what an approved deploy landed.
///
/// Written by [maybeLandApprovedDeployment] BEFORE the engine moves the
/// item to `deployed`, so the item carries the evidence that made the state
/// true rather than `deployed` being a bare label.
const deployedCommitMetadataKey = 'deployedCommit';
const deployedIntoMetadataKey = 'deployedInto';
const deployedAtMetadataKey = 'deployedAt';
const deployedCommitBasisMetadataKey = 'deployedCommitBasis';
const deployedByMetadataKey = 'deployedBy';

/// The product remote the landed branch was pushed to — `url#branch`
/// (F-258). An address, never a credential: it records WHERE the deploy
/// reached, paired with [deployedIntoMetadataKey]'s record of where it
/// merged.
const deployedRemoteMetadataKey = 'deployedRemote';

/// The mechanism name stamped into [deployedByMetadataKey] and the log.
const deployLandingMechanismName = 'deploy_landing';

/// The mechanism name stamped into [deployedByMetadataKey] by a RE-LAND —
/// the operator action that lands a `deployed` item the approval arm could
/// never reach (F-259).
///
/// Distinct from [deployLandingMechanismName] on purpose. The merge is the
/// same mechanism, but "which path made `deployed` true" is a question the
/// item's own metadata must answer: the stranded items this was built for
/// were stamped by nothing at all, and a re-landed one says so. The
/// `operator_action` ledger row names the human who asked; this names the
/// path.
const deployRelandMechanismName = 'deploy_landing_reland';

/// What one verified land concluded.
///
/// Returned only when the produced commit is PROVABLY reachable from the
/// target branch of the product's recorded checkout — either the merge
/// just created that ancestry, or the commit was already reachable (the
/// replay shape of a retry, which must never merge twice).
class DeployLanding {
  const DeployLanding({
    required this.commit,
    required this.repositoryPath,
    required this.targetBranch,
    required this.headAfter,
    required this.alreadyLanded,
    required this.commitBasis,
    required this.push,
  });

  /// The revision that was landed.
  final String commit;

  /// The product's recorded repo checkout — `WorkerExecution.repositoryPath`,
  /// the clone the producing execution was dispatched against. This is where
  /// the produced commit already lived, which is what makes it the place a
  /// merge can actually reach it.
  final String repositoryPath;

  /// The product's DEFAULT branch — the target the deploy landed into.
  ///
  /// Resolved by [_resolveDefaultBranch] from the clone's own record
  /// (`refs/remotes/origin/HEAD`, then the recorded `main` convention), never
  /// from whichever branch the checkout happened to have checked out: that
  /// was the F-261 defect — the durable clone sits on the lane branch the
  /// last produced commit was made on, so seven deploys merged
  /// `--no-ff` into `shipit/impl/<workItemId>` instead of `main`.
  final String targetBranch;

  /// `HEAD` of the target branch after the land.
  final String headAfter;

  /// True when the commit was already reachable from the target branch —
  /// a replayed approve, or a producer whose base revision is the land.
  /// No merge was run for it.
  final bool alreadyLanded;

  /// `producedCommit` or `workspaceStartingRevision` — the same basis the
  /// deployment artifact records, so the artifact's `version` and the landed
  /// commit cannot silently name different revisions.
  final String commitBasis;

  /// What the push to the product remote established (F-258): which branch
  /// the remote now carries the landed head on, and the verified remote
  /// tip. `deployed` is only claimed AFTER this exists — a land that
  /// merges but cannot push throws before returning.
  final DeployPush push;
}

/// Whether resolving [decision] with [choice] is a deployment approval that
/// will move [item] — the one resolution that owes a verified land FIRST.
///
/// The conditions mirror `DurableWorkflowEngine.resolveHumanDecision`'s own
/// `isBlocking` test plus the routing table's
/// `(deploymentApproval, approve) -> deployed` arm, so this predicate is
/// true exactly when the engine is about to write `deployed`. Reading the
/// effective choice the same way the engine does — the stored choice when
/// the decision is already resolved — is what makes a REPLAY of an
/// interrupted resolution owe the same land: a crash between the engine's
/// `saveHumanDecision` and its transition write leaves a resolved approve
/// parked at the gate, and the replay must still land before it deploys.
bool deployLandingIsOwed({
  required HumanDecision decision,
  required HumanDecisionChoice choice,
  required WorkItem item,
}) {
  if (decision.decisionType != HumanDecisionType.deploymentApproval) {
    return false;
  }
  if (decision.blocking == false) return false;
  if (item.state != WorkItemState.waitingForHumanDecision) return false;
  if (item.blockingHumanDecisionId != decision.decisionId) return false;
  final effective = decision.status.isResolved && decision.choice != null
      ? decision.choice!
      : choice;
  return effective == HumanDecisionChoice.approve;
}

/// Whether [item] is a `deployed` item that was never made true — the
/// stranded, label-only shape a re-land exists for (F-259).
///
/// The owed test is `deployed` AND [deployedCommitMetadataKey] absent, and
/// the commit key alone is the right predicate. The five `deployed*` keys
/// are written in ONE `saveWorkItem` — see
/// [maybeLandApprovedDeployment] — so they cannot be half-present: the
/// commit's presence is the stamp's presence, and `deployedBy`/
/// `deployedInto` add no second fact to test against.
///
/// A `deployed` item WITH the stamp is NOT owed, deliberately: nothing is
/// missing, and re-landing it would overwrite the evidence it already
/// carries. A stamped item whose commit is somehow not on the branch is a
/// fabricated stamp — a different repair, not a re-land.
bool deployRelandIsOwed(WorkItem item) {
  if (item.state != WorkItemState.deployed) return false;
  final stamp = item.metadata?[deployedCommitMetadataKey];
  return stamp is! String || stamp.isEmpty;
}

/// Lands the approved deploy for [item], or returns `null` when this
/// resolution is not an approved deployment.
///
/// This is the deploy EXECUTION the resolution path dispatches: called from
/// `ControlPlaneService.resolveHumanDecision` after the verdict guards and
/// BEFORE `DurableWorkflowEngine.resolveHumanDecision`, so the engine's
/// `waiting_for_human_decision -> deployed` write happens only after the
/// produced commit is provably in the product's target branch.
///
/// On success the landed commit is recorded on the work item's own metadata
/// (the `deployed*` keys above) through the same compare-and-swap
/// `saveWorkItem` the design scope grant write uses — a concurrent move
/// fails the write and the whole resolution, which is the honest order: a
/// stale item is not recorded as landed.
///
/// A [DeployLandingException] propagates with NOTHING written. The merge is
/// git-idempotent — an already-merged commit verifies as already-landed
/// without merging again — so a retry of the same approve completes the
/// interrupted sequence rather than merging twice.
///
/// [deployPush] is REQUIRED (F-258): `deployed` now means the landed branch
/// reached the product remote, and a caller that cannot wire the push must
/// not be able to claim it. A pusher that throws is rendered as a
/// [DeployLandingException] — nothing durable written, the decision stays
/// pending, and a retried approve finishes the interrupted push through the
/// already-landed arm.
Future<DeployLanding?> maybeLandApprovedDeployment({
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required WorkflowStore workflowStore,
  required HumanDecision decision,
  required HumanDecisionChoice choice,
  required DeployPusher deployPush,
  DateTime Function() clock = DateTime.now,
  String git = 'git',
  Duration gitTimeout = const Duration(seconds: 60),
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  if (decision.decisionType != HumanDecisionType.deploymentApproval) {
    return null;
  }
  final item = await workflowStore.readWorkItem(decision.workItemId);
  if (!deployLandingIsOwed(
    decision: decision,
    choice: choice,
    item: item,
  )) {
    return null;
  }

  final landing = await landApprovedDeployment(
    executionStore: executionStore,
    workerStore: workerStore,
    item: item,
    deployPush: deployPush,
    git: git,
    gitTimeout: gitTimeout,
    log: log,
  );

  // The durable evidence that made `deployed` true, written BEFORE the
  // engine's transition. Compare-and-swap on the item's own version: a
  // concurrent move is a refusal, not a silent overwrite — the resolution
  // aborts, and the retry re-reads the item it actually is.
  await workflowStore.saveWorkItem(
    deployLandingStampedItem(
      item,
      landing: landing,
      mechanism: deployLandingMechanismName,
      at: clock(),
    ),
    expectedVersion: item.version,
  );

  log?.call('deploy.landing.recorded', {
    'workItemId': item.workItemId,
    'decisionId': decision.decisionId,
    'commit': landing.commit,
    'repositoryPath': landing.repositoryPath,
    'targetBranch': landing.targetBranch,
    'headAfter': landing.headAfter,
    'alreadyLanded': landing.alreadyLanded,
    'commitBasis': landing.commitBasis,
  });
  return landing;
}

/// Resolves what [item]'s producer left and merges it into the product's
/// recorded checkout, verifying the result.
///
/// ## THE RESOLUTION RULE IS THE ARTIFACT'S OWN
///
/// The commit is resolved exactly as `deploy_advance.dart` resolves the
/// artifact's `gitCommit`: `producedCommitFor` first — the platform's own
/// answer to "what did this producer leave" — then the producing
/// execution's `workspace.startingRevision`. The repository is the
/// producer's recorded checkout: `CommitProduced.repositoryPath`, or the
/// producing worker execution's `repositoryPath` on the fallback arm. The
/// worktree from `agent_execution.workspaceJson` is deliberately NOT
/// merged into: it is a detached worktree of that checkout, it may already
/// be reaped by workspace retention, and the object store — where the
/// produced commit lives — is the checkout's.
///
/// A [DeployLandingException] is a refusal, not a verdict on the work:
/// missing producer, no commit to land, commit absent from the recorded
/// checkout, a default branch that cannot be resolved or selected, a merge
/// that failed or could not be verified, or a push to the product remote
/// that was refused (F-258). On a failed merge the checkout is aborted back
/// to clean before the throw, so the next attempt starts from the same
/// state.
///
/// ## THE PUSH IS PART OF THE LAND (F-258)
///
/// The merge used to be where the deploy ended: the commit landed in the
/// recorded checkout's default branch and the item was stamped `deployed`
/// — while the product's origin remote never received anything. `deployed`
/// now means the branch reached the remote: after the land is verified —
/// on BOTH arms, the merge and the already-landed replay — the landed head
/// is pushed to the checkout's `origin` via the product's verified deploy
/// key. A push that is refused throws a [DeployLandingException] like every
/// other refusal here: nothing durable was written, the approve is not
/// consumed, and a retry completes the interrupted sequence — the
/// already-landed arm re-verifies the local merge and the push's own
/// idempotency turns a partially-completed push into `alreadyCurrent`.
Future<DeployLanding> landApprovedDeployment({
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required WorkItem item,
  required DeployPusher deployPush,
  String git = 'git',
  Duration gitTimeout = const Duration(seconds: 60),
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  // (1) THE PRODUCER — resolved by the platform's own rule, the same one the
  // deployment artifact is built from. An approved deploy of a result that
  // does not exist is nothing honest to land.
  final producer = await resolveProducerExecution(
    store: executionStore,
    workItemId: item.workItemId,
    producerActorId: item.metadata?['producerActorId'],
  );
  final result = producer.result;
  if (!producer.isResolved ||
      result == null ||
      result.status != AgentResultStatus.completed) {
    log?.call('deploy.landing.no_producer', {
      'workItemId': item.workItemId,
      'producer': producer.note,
    });
    throw DeployLandingException(
      'the approved deploy of work item ${item.workItemId} has no completed '
      'producer result to land (${producer.note}). Nothing was merged; the '
      'approval decision stays pending and can be retried or rejected.',
    );
  }

  // (2) THE COMMIT AND THE CHECKOUT.
  final produced = await producedCommitFor(workerStore, item);
  final String? commit;
  final String? repositoryPath;
  final String commitBasis;
  if (produced is CommitProduced) {
    commit = produced.commit;
    repositoryPath = produced.repositoryPath;
    commitBasis = 'producedCommit';
  } else {
    commitBasis = 'workspaceStartingRevision';
    final execution = producer.executionId == null
        ? null
        : await executionStore.readExecutionOrNull(producer.executionId!);
    commit = execution?.workspace.startingRevision;
    repositoryPath = await _producerRepositoryPath(
      workerStore: workerStore,
      item: item,
      producerExecutionId: producer.executionId,
    );
    log?.call('deploy.landing.commit_fallback', {
      'workItemId': item.workItemId,
      'producerExecutionId': producer.executionId,
      'producedCommit': '$produced',
    });
  }
  if (commit == null || commit.isEmpty) {
    throw DeployLandingException(
      'the approved deploy of work item ${item.workItemId} resolves to no '
      'commit — the producer left no produced commit and recorded no '
      'starting revision ($produced). Nothing was merged; the approval '
      'decision stays pending.',
    );
  }
  if (repositoryPath == null || repositoryPath.isEmpty) {
    throw DeployLandingException(
      'the approved deploy of work item ${item.workItemId} names commit '
      '$commit but no recorded checkout could be resolved for the '
      'producing execution (${producer.executionId}), so there is nowhere '
      'honest to land it. Nothing was merged.',
    );
  }

  // (3) THE COMMIT MUST EXIST IN THE RECORDED CHECKOUT. A revision that
  // resolves but is not an object in that repository cannot be merged and
  // must not read as landed.
  await _gitMust(
    git,
    ['-C', repositoryPath, 'rev-parse', '--verify', '$commit^{commit}'],
    gitTimeout,
    failure:
        'the commit the deploy resolves to ($commit) is not an object in '
        'the recorded checkout $repositoryPath, so it cannot be landed. '
        'Nothing was merged.',
  );

  // (4) THE TARGET BRANCH — the product's DEFAULT branch, resolved honestly,
  // then checked out so the merge below lands into it for real.
  //
  // The old rule merged into whatever branch the recorded checkout happened
  // to be sitting on, and that is F-261: the durable clone is left on the
  // lane branch the produced commit was made on, so seven deploys merged
  // `--no-ff` into `shipit/impl/<workItemId>` — into the work's own branch —
  // instead of the product's `main`. A deploy lands where the product
  // releases from, not where a worker last left HEAD.
  final targetBranch = await _resolveDefaultBranch(
    git,
    repositoryPath,
    commit,
    gitTimeout,
    log: log,
    workItemId: item.workItemId,
  );

  // `git merge` lands into HEAD, so HEAD must BE the resolved branch.
  // `git checkout` also materializes a local tracking branch from
  // `origin/<target>` when only the remote-tracking ref exists; a checkout
  // git cannot perform — a dirty tree, a branch held by another worktree —
  // is a refusal, not a place to invent one.
  final checkout = await _gitRun(git, [
    '-C',
    repositoryPath,
    'checkout',
    targetBranch,
  ], gitTimeout);
  if (checkout.exitCode != 0) {
    log?.call('deploy.landing.checkout_failed', {
      'workItemId': item.workItemId,
      'commit': commit,
      'repositoryPath': repositoryPath,
      'targetBranch': targetBranch,
      'exitCode': checkout.exitCode,
      'stderr': _stderr(checkout),
    });
    throw DeployLandingException(
      'the recorded checkout $repositoryPath resolved its default branch to '
      '$targetBranch but would not check it out (exit ${checkout.exitCode}: '
      '${_stderr(checkout)}), so there is no branch to merge $commit into. '
      'Nothing was merged; the approval decision stays pending.',
    );
  }

  // (5) ALREADY LANDED IS A VERIFIED ANSWER. `merge-base --is-ancestor` is
  // the same check the post-merge verification below runs — a replayed
  // approve takes this arm and merges nothing.
  final alreadyAncestor = await _gitExitCode(git, [
    '-C',
    repositoryPath,
    'merge-base',
    '--is-ancestor',
    commit,
    'HEAD',
  ], gitTimeout);
  if (alreadyAncestor != 0 && alreadyAncestor != 1) {
    throw DeployLandingException(
      'git merge-base --is-ancestor could not be evaluated in '
      '$repositoryPath (exit $alreadyAncestor); the land cannot be '
      'verified and was not attempted. Nothing was merged.',
    );
  }
  if (alreadyAncestor == 0) {
    final headAfter = (await _gitMust(git, [
      '-C',
      repositoryPath,
      'rev-parse',
      'HEAD',
    ], gitTimeout)).trim();
    log?.call('deploy.landing.already_landed', {
      'workItemId': item.workItemId,
      'commit': commit,
      'repositoryPath': repositoryPath,
      'targetBranch': targetBranch,
    });
    // The push runs on the already-landed arm too: a crash between merge
    // and push is exactly the retry shape this arm exists for, and the
    // push's own idempotency makes "remote already contains the head" a
    // success rather than a failure.
    final push = await _pushLandedBranch(
      deployPush: deployPush,
      item: item,
      repositoryPath: repositoryPath,
      targetBranch: targetBranch,
      localHead: headAfter,
      log: log,
    );
    return DeployLanding(
      commit: commit,
      repositoryPath: repositoryPath,
      targetBranch: targetBranch,
      headAfter: headAfter,
      alreadyLanded: true,
      commitBasis: commitBasis,
      push: push,
    );
  }

  // (6) THE MERGE. Authored as the platform, unsigned, deterministic
  // message — the same discipline `ArtifactCommitter` applies so the land
  // does not depend on ambient git configuration. `--no-ff` makes the land
  // a deliberate record in the target branch's history.
  final mergeArgs = [
    '-c',
    'user.name=shipit-deploy',
    '-c',
    'user.email=shipit-deploy@localhost',
    '-c',
    'commit.gpgsign=false',
    '-C',
    repositoryPath,
    'merge',
    '--no-ff',
    '-m',
    'deploy: land $commit for work item ${item.workItemId}',
    commit,
  ];
  final merge = await _gitRun(git, mergeArgs, gitTimeout);
  if (merge.exitCode != 0) {
    // Leave the checkout clean for the next attempt. A failed abort is
    // reported in the refusal, not swallowed — the operator must know the
    // checkout may be mid-merge.
    final abort = await _gitRun(git, [
      '-C',
      repositoryPath,
      'merge',
      '--abort',
    ], gitTimeout);
    final abortNote = abort.exitCode == 0
        ? 'the checkout was aborted back to clean'
        : 'git merge --abort ALSO failed (exit ${abort.exitCode}: '
              '${_stderr(abort)}), so the checkout may still be mid-merge '
              'and needs an operator';
    log?.call('deploy.landing.merge_failed', {
      'workItemId': item.workItemId,
      'commit': commit,
      'repositoryPath': repositoryPath,
      'targetBranch': targetBranch,
      'exitCode': merge.exitCode,
      'stderr': _stderr(merge),
      'abort': abortNote,
    });
    throw DeployLandingException(
      'merging $commit into $targetBranch of $repositoryPath failed '
      '(exit ${merge.exitCode}): ${_stderr(merge)}; $abortNote. The '
      'approval decision stays pending and can be retried or rejected.',
    );
  }

  // (7) VERIFY — a reported success is not proof. The commit must be
  // reachable from the target branch's HEAD, checked the same way the
  // already-landed arm checks it.
  final verified = await _gitExitCode(git, [
    '-C',
    repositoryPath,
    'merge-base',
    '--is-ancestor',
    commit,
    'HEAD',
  ], gitTimeout);
  if (verified != 0) {
    throw DeployLandingException(
      'git merge of $commit into $targetBranch of $repositoryPath reported '
      'success, but the commit is not reachable from the branch HEAD '
      '(merge-base --is-ancestor exited $verified). The deploy is NOT '
      'claimed; the approval decision stays pending and the checkout needs '
      'an operator.',
    );
  }
  final headAfter = (await _gitMust(git, [
    '-C',
    repositoryPath,
    'rev-parse',
    'HEAD',
  ], gitTimeout)).trim();
  log?.call('deploy.landing.merged', {
    'workItemId': item.workItemId,
    'commit': commit,
    'repositoryPath': repositoryPath,
    'targetBranch': targetBranch,
    'headAfter': headAfter,
  });

  // (8) THE PUSH (F-258) — the land is not claimed until the product remote
  // carries the landed head. A refused push throws like every other
  // refusal above: the merge stays local, nothing durable was written, and
  // the approval decision stays pending — a retried approve takes the
  // already-landed arm and completes the push rather than merging twice.
  final push = await _pushLandedBranch(
    deployPush: deployPush,
    item: item,
    repositoryPath: repositoryPath,
    targetBranch: targetBranch,
    localHead: headAfter,
    log: log,
  );
  return DeployLanding(
    commit: commit,
    repositoryPath: repositoryPath,
    targetBranch: targetBranch,
    headAfter: headAfter,
    alreadyLanded: false,
    commitBasis: commitBasis,
    push: push,
  );
}

/// Runs [deployPush] and renders ANY refusal as a [DeployLandingException].
///
/// The pusher's own refusal type is `DeployPushRefusedException`, and the
/// credential path underneath it can raise any of the audited failures; all
/// of them are rendered through `secretlessText` — an audited failure
/// supplies its own description and anything else is suppressed to a type
/// name — so a refusal reason that reaches the durable record can never
/// carry key material.
///
/// The honesty point worth stating: a throw here comes AFTER the merge.
/// That is the honest order — the merge is local and idempotent, the push
/// is what reaches the product, and the state model stays truthful about
/// "merged locally, push failed" precisely because the decision stays
/// pending and the stamp is never written.
Future<DeployPush> _pushLandedBranch({
  required DeployPusher deployPush,
  required WorkItem item,
  required String repositoryPath,
  required String targetBranch,
  required String localHead,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  try {
    final push = await deployPush.pushLandedBranch(
      item: item,
      repositoryPath: repositoryPath,
      targetBranch: targetBranch,
      localHead: localHead,
    );
    log?.call('deploy.push.${push.state.name}', {
      'workItemId': item.workItemId,
      'repositoryPath': repositoryPath,
      'targetBranch': targetBranch,
      'remoteUrl': push.remoteUrl,
      'remoteHead': push.remoteHead,
    });
    return push;
  } on Object catch (error) {
    log?.call('deploy.push.refused', {
      'workItemId': item.workItemId,
      'repositoryPath': repositoryPath,
      'targetBranch': targetBranch,
      'reason': secretlessText(error),
    });
    throw DeployLandingException(
      'the land merged into $targetBranch of $repositoryPath but the push '
      'to the product remote was refused — ${secretlessText(error)}. The '
      'merge stays local; nothing durable was written; the approval '
      'decision stays pending and a retried approve completes the '
      'interrupted push through the already-landed arm.',
    );
  }
}

/// The item with one verified land stamped on it.
///
/// A PURE transform — the durable write is the caller's
/// (`saveWorkItem` compare-and-swap), which is the same discipline both
/// writers keep. Shared between [maybeLandApprovedDeployment] and the
/// operator re-land so "what made `deployed` true" is ONE definition the two
/// stamp writers cannot drift apart on: same five keys, same shapes, and
/// [mechanism] is the only thing that differs — [deployLandingMechanismName]
/// on the approval path, [deployRelandMechanismName] on the re-land.
WorkItem deployLandingStampedItem(
  WorkItem item, {
  required DeployLanding landing,
  required String mechanism,
  required DateTime at,
}) => item.copyWith(
  metadata: {
    ...?item.metadata,
    deployedCommitMetadataKey: landing.commit,
    deployedIntoMetadataKey:
        '${landing.repositoryPath}#${landing.targetBranch}',
    deployedRemoteMetadataKey:
        '${landing.push.remoteUrl}#${landing.push.branch}',
    deployedCommitBasisMetadataKey: landing.commitBasis,
    deployedAtMetadataKey: at.toUtc().toIso8601String(),
    deployedByMetadataKey: mechanism,
  },
  updatedAt: at,
  version: item.version + 1,
);

/// Lands the produced commit for a `deployed` item that was never stamped —
/// the re-land path (F-259).
///
/// The land itself IS [landApprovedDeployment], unchanged: same producer
/// resolution, same commit resolution, same verify-not-remerge merge, same
/// refusals. What differs is the TRIGGER and the owed test —
/// [deployRelandIsOwed] instead of [deployLandingIsOwed] — so this is the
/// arm for an item whose `deployment_approval` already resolved (under the
/// pre-deploy artifact, before the land existed) and can never fire the
/// approval path again.
///
/// The owed test is re-asserted HERE and not only in the calling endpoint,
/// for the same reason the endpoint checks it there: a re-land over an
/// existing stamp would overwrite the evidence the stamp carries, and an
/// item that is not `deployed` at all has a different path. A refusal —
/// either this guard's or the land's own — is a [DeployLandingException]
/// with NOTHING written: no merge the land could not verify, and no stamp.
/// Stamping is deliberately left to the caller, which commits the stamp and
/// its audit row in one transaction.
///
/// [deployPush] is required for the same reason it is on
/// [maybeLandApprovedDeployment] (F-258): a re-land that merges but cannot
/// push re-creates the exact stranded shape it exists to repair — a
/// `deployed` label the product remote never received.
Future<DeployLanding> relandDeployedItem({
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required WorkItem item,
  required DeployPusher deployPush,
  String git = 'git',
  Duration gitTimeout = const Duration(seconds: 60),
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  if (!deployRelandIsOwed(item)) {
    throw DeployLandingException(
      'work item ${item.workItemId} is not a deployed item missing its '
      'landed stamp (state ${item.state.wire}, deployedCommit '
      '${item.metadata?[deployedCommitMetadataKey] ?? 'absent'}), so no '
      're-land is owed. Nothing was merged and nothing was written.',
    );
  }
  return landApprovedDeployment(
    executionStore: executionStore,
    workerStore: workerStore,
    item: item,
    deployPush: deployPush,
    git: git,
    gitTimeout: gitTimeout,
    log: log,
  );
}

/// The product's DEFAULT branch in [repositoryPath], resolved honestly — or
/// a [DeployLandingException] when it cannot be.
///
/// ## THE LADDER, IN ORDER
///
///  1. `symbolic-ref refs/remotes/origin/HEAD` — the clone's own record of
///     which branch the remote declares default. Read rather than guessed:
///     a clone that tracks `origin/trunk` lands on `trunk`, not on a
///     hardcoded `main`.
///  2. `main`, verified to exist — the platform's recorded convention for a
///     checkout with no remote HEAD (`init.defaultBranch=main` is what every
///     clone this platform makes is seeded with). `refs/heads/main` counts,
///     and so does `refs/remotes/origin/main` alone: `git checkout main`
///     materializes the local tracking branch from it.
///  3. refuse — a checkout whose default cannot be resolved gets NOTHING
///     merged, and the refusal names both arms that were tried. Falling back
///     to the checkout's current branch here is exactly the F-261 defect
///     this resolution exists to remove.
///
/// The merge itself still lands into HEAD — this function only answers the
/// NAME — so the caller checks the resolved branch out before merging.
/// A name is resolved honestly and a merge still fails honestly; neither is
/// the other's business.
Future<String> _resolveDefaultBranch(
  String git,
  String repositoryPath,
  String commit,
  Duration gitTimeout, {
  void Function(String event, Map<String, dynamic> data)? log,
  required String workItemId,
}) async {
  // Arm 1 — the clone's own record of the remote's default. With `--short`
  // this prints `origin/<name>`; the remote-name prefix is stripped by the
  // first '/', so a remote default with a '/' in the branch name survives.
  final remoteHead = await _gitRun(git, [
    '-C',
    repositoryPath,
    'symbolic-ref',
    '--short',
    '-q',
    'refs/remotes/origin/HEAD',
  ], gitTimeout);
  final remoteRef = (remoteHead.stdout as String).trim();
  if (remoteHead.exitCode == 0 && remoteRef.isNotEmpty) {
    final slash = remoteRef.indexOf('/');
    if (slash > 0 && slash < remoteRef.length - 1) {
      final branch = remoteRef.substring(slash + 1);
      log?.call('deploy.landing.default_branch', {
        'workItemId': workItemId,
        'repositoryPath': repositoryPath,
        'targetBranch': branch,
        'resolvedBy': 'origin/HEAD',
      });
      return branch;
    }
  }

  // Arm 2 — the recorded convention for a checkout with no remote HEAD.
  // The branch must actually EXIST somewhere `git checkout` can reach it:
  // a missing `main` is not silently promoted to "the default".
  final mainHead = await _gitExitCode(git, [
    '-C',
    repositoryPath,
    'rev-parse',
    '--verify',
    '-q',
    'refs/heads/main',
  ], gitTimeout);
  if (mainHead == 0) {
    log?.call('deploy.landing.default_branch', {
      'workItemId': workItemId,
      'repositoryPath': repositoryPath,
      'targetBranch': 'main',
      'resolvedBy': 'refs/heads/main',
    });
    return 'main';
  }
  final originMain = await _gitExitCode(git, [
    '-C',
    repositoryPath,
    'rev-parse',
    '--verify',
    '-q',
    'refs/remotes/origin/main',
  ], gitTimeout);
  if (originMain == 0) {
    log?.call('deploy.landing.default_branch', {
      'workItemId': workItemId,
      'repositoryPath': repositoryPath,
      'targetBranch': 'main',
      'resolvedBy': 'refs/remotes/origin/main',
    });
    return 'main';
  }

  log?.call('deploy.landing.no_default_branch', {
    'workItemId': workItemId,
    'repositoryPath': repositoryPath,
  });
  throw DeployLandingException(
    'the recorded checkout $repositoryPath names no default branch: '
    'refs/remotes/origin/HEAD does not resolve and no local or remote-'
    'tracking `main` branch exists, so there is no honest target to land '
    '$commit into — landing it on whatever branch the checkout happens to '
    'be sitting on is exactly what this resolution refuses. Nothing was '
    'merged; the approval decision stays pending.',
  );
}

/// The `repositoryPath` of the producing WORKER execution — the fallback
/// arm's checkout, where [producedCommitFor] already reads
/// `CommitProduced.repositoryPath` from on the produced arm.
///
/// The match is the same shape `producedCommitFor` applies to the stamped
/// identity, bound to the producer `resolveProducerExecution` resolved:
/// the item's own work, the producing agent execution, and never a
/// reviewer's run. Zero or more-than-one matches answer `null` — guessing
/// a checkout would land work into a repository it was not recorded
/// against.
Future<String?> _producerRepositoryPath({
  required WorkerStore workerStore,
  required WorkItem item,
  required String? producerExecutionId,
}) async {
  if (producerExecutionId == null || producerExecutionId.isEmpty) {
    return null;
  }
  final matches = <WorkerExecution>[];
  for (final execution in await workerStore.listWorkerExecutions()) {
    if (execution.workItemId != item.workItemId) continue;
    if (execution.agentExecutionId != producerExecutionId) continue;
    if (execution.requiredCapabilities.contains(
      WorkerCapability.engineeringReview,
    )) {
      continue;
    }
    matches.add(execution);
  }
  if (matches.length != 1) return null;
  return matches.single.repositoryPath;
}

/// A git invocation whose non-zero exit is a [DeployLandingException].
Future<String> _gitMust(
  String git,
  List<String> args,
  Duration timeout, {
  String failure = 'a required git read failed',
}) async {
  final result = await _gitRun(git, args, timeout);
  if (result.exitCode != 0) {
    throw DeployLandingException(
      '$failure git ${args.join(' ')} exited ${result.exitCode}: '
      '${_stderr(result)}',
    );
  }
  return result.stdout as String;
}

/// A git invocation whose exit code is the answer (0/1 semantics).
Future<int> _gitExitCode(String git, List<String> args, Duration timeout) =>
    _gitRun(git, args, timeout).then((r) => r.exitCode);

/// Runs git with a hard timeout, mirroring `ArtifactCommitter`'s
/// discipline: a tool failure is a typed refusal, never a caller crash.
Future<ProcessResult> _gitRun(
  String git,
  List<String> args,
  Duration timeout,
) async {
  try {
    return await Process.run(
      git,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(timeout);
  } on TimeoutException {
    throw DeployLandingException(
      'git ${args.join(' ')} exceeded $timeout; the land is unfinished and '
      'the approval decision stays pending — retry it after the cause is '
      'cleared.',
    );
  } on ProcessException catch (e) {
    throw DeployLandingException(
      'git could not be run ($e); the land was not attempted and the '
      'approval decision stays pending.',
    );
  }
}

String _stderr(ProcessResult result) {
  final stderr = result.stderr.toString().trim();
  return stderr.isEmpty ? '(no stderr)' : stderr;
}

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, resolveProducerExecution;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart'
    show CommitProduced, producedCommitFor;
import 'package:worker_runtime/worker_runtime.dart' show WorkerStore;
import 'package:workflow_store/workflow_store.dart'
    show
        DurableWorkflowEngine,
        WorkflowStore,
        WorkflowTransitionRejectedException;

/// The deploy advance's two shared halves: build the artifact the
/// `artifactBuilt()` guard requires, then raise the `deploymentApproval`
/// decision that parks the item at `waiting_for_human_decision`.
///
/// ## WHY THIS FILE EXISTS
///
/// The honest deploy sequence was written once, for the operator surface
/// (`work_item_action_endpoints.dart` `advanceToDeploy`): transition
/// `qaPassed -> deploying` with a [DeploymentArtifact] built from the
/// producer's own durable `AgentResult`, then
/// `requestHumanDecision(deploymentApproval)`. The deploy-gate sweep
/// (`deploy_gate_sweep.dart`) now fires the same advance for every
/// `qa_passed` item, and the two callers must not drift apart: an artifact
/// built two different ways is two different answers to "what is being
/// deployed", and a decision raised two different ways is two different
/// gates. Both callers share this file — the sweep reuses the operator
/// path's verified construction rather than re-deriving it.
///
/// ## WHY THE DEPENDENCIES ARE PARAMETERS
///
/// The endpoint holds its stores behind `ControlPlaneService`; the sweep is
/// wired straight from the composition root. The three stores the logic
/// actually reads are taken explicitly — the execution store (who produced
/// the item), the worker store (what commit it left) and the workflow
/// engine/store pair (the durable write) — so one function serves both
/// callers without a service-shaped seam that exists only to be faked.
///
/// ## WHAT THE EVENT NAMES DELIBERATELY DO NOT SAY
///
/// The log events below are named for the shared mechanism
/// (`deploy.advance.*`), not for whichever caller invoked it. Who minted the
/// artifact or raised the decision is carried on the durable rows
/// themselves — [raisedBy] on the artifact's labels and the decision's
/// metadata — because the record is what a later reader has.

/// Builds the [DeploymentArtifact] `artifactBuilt()` requires, from the
/// producer's own durable `AgentResult`.
///
/// Returns `null` when there is no honest artifact to build: no resolvable
/// producer, a result that is not completed, or no revision the artifact can
/// name (`producedCommitFor` — the platform's own answer to "what did this
/// producer leave" — first, then the workspace base it was built against).
/// Nothing here invents a revision or a file.
///
/// [advanceId] names the intent this artifact was minted for — the
/// operator's request id, or the sweep's per-residence key — and makes the
/// artifact id deterministic in it. [builtBy] and [raisedBy] name the
/// caller on the artifact and in the log: a human's handle for the operator
/// path, the sweep's own name for the machine path.
Future<DeploymentArtifact?> deploymentArtifactFor({
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required WorkItem item,
  required String advanceId,
  required String builtBy,
  required String raisedBy,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  final producer = await resolveProducerExecution(
    store: executionStore,
    workItemId: item.workItemId,
    producerActorId: item.metadata?['producerActorId'],
  );
  final result = producer.result;
  if (result == null || result.status != AgentResultStatus.completed) {
    log?.call('deploy.advance.no_producer', {
      'workItemId': item.workItemId,
      'producer': producer.note,
      'raisedBy': raisedBy,
    });
    return null;
  }

  final produced = await producedCommitFor(workerStore, item);
  final execution = producer.executionId == null
      ? null
      : await executionStore.readExecutionOrNull(producer.executionId!);
  final (gitCommit, basis) = switch (produced) {
    CommitProduced(:final commit) => (commit, 'producedCommit'),
    _ => (execution?.workspace.startingRevision, 'workspaceStartingRevision'),
  };
  if (gitCommit == null || gitCommit.isEmpty) {
    log?.call('deploy.advance.no_revision', {
      'workItemId': item.workItemId,
      'producerExecutionId': producer.executionId,
      'raisedBy': raisedBy,
    });
    return null;
  }

  final manifest = ArtifactManifest(
    name: item.productId,
    version: gitCommit,
    gitCommit: gitCommit,
    files: [
      for (final a in result.artifacts)
        ArtifactFile(
          path: a.path,
          sha256: a.sha256,
          sizeBytes: a.sizeBytes,
          mediaType: a.mediaType,
        ),
    ],
    sbom: const SoftwareBillOfMaterials(
      format: 'CycloneDX',
      version: '1.5',
      components: [],
    ),
    metadata: {
      'workItemId': item.workItemId,
      'producerExecutionId': producer.executionId ?? '',
      'commitBasis': basis,
    },
  );
  return DeploymentArtifact(
    // Deterministic in the advance id: the artifact record one intent built.
    artifactId: 'artifact-deploy-${item.workItemId}-$advanceId',
    contentHash: crypto.sha256
        .convert(utf8.encode(jsonEncode(manifest.toJson())))
        .toString(),
    manifest: manifest,
    builtAt: DateTime.now().toUtc(),
    builtBy: builtBy,
    labels: {
      'raisedBy': raisedBy,
      'producerExecutionId': producer.executionId ?? '',
      'commitBasis': basis,
    },
  );
}

/// Raises the blocking `deploymentApproval` decision, parking the item at
/// `waiting_for_human_decision`.
///
/// A refusal — the item moved concurrently — is logged and swallowed: the
/// caller returns the item's current state either way, and the durable rows
/// still record the rejected attempt.
Future<WorkItem> raiseDeploymentApproval({
  required DurableWorkflowEngine workflowEngine,
  required WorkflowStore workflowStore,
  required WorkItem item,
  required WorkflowActor actor,
  required String raisedBy,
  String? artifactId,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  try {
    await workflowEngine.requestHumanDecision(
      workItemId: item.workItemId,
      decisionType: HumanDecisionType.deploymentApproval,
      question:
          'This work passed QA. Approve deploying it to its target '
          'environment?',
      options: const [
        HumanDecisionOption(
          optionId: 'approve',
          label: 'Deploy it',
          description: 'The work item moves to deployed.',
        ),
        HumanDecisionOption(
          optionId: 'reject',
          label: 'Do not deploy',
          description: 'The work item is marked deployment_failed.',
        ),
      ],
      blocking: true,
      metadata: {
        'raisedBy': raisedBy,
        if (artifactId != null) 'deploymentArtifactId': artifactId,
      },
      actor: actor,
    );
  } on WorkflowTransitionRejectedException catch (error) {
    log?.call('deploy.advance.decision_refused', {
      'workItemId': item.workItemId,
      'raisedBy': raisedBy,
      'reason': error.record.reason ?? error.record.outcome.wire,
    });
  }
  return workflowStore.readWorkItem(item.workItemId);
}

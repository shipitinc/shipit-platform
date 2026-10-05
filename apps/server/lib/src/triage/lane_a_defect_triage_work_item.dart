import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:workflow_store/workflow_store.dart';

/// Product id used as the triage bucket for a defect that is NOT linked to a
/// registered work item.
///
/// [Defect] carries no `productId` and the `defect` table has no such column.
/// The only authoritative link from a defect to a product is
/// `defect.affectedWorkItemId -> work_item.productId`. When a human reports a
/// defect from a surface that carries no work item (bug report form, inbox
/// triage, an e-mail-to-defect bridge) there is no such link, so the triage
/// work item is filed under this shared bucket. It is a TRIAGE BUCKET, not a
/// product, and no product id is invented for it.
const String defectTriageBucketProductId = 'defects';

/// Stable work item identity for the triage of [defectId].
///
/// The `defect-{defectId}` shape is load-bearing in three places and must not
/// drift: the scheduler's job `workItemId`, the triage dedupe key
/// (`'{workItemId}:{jobType}'`), and `TriageProcessor._extractDefectId` which
/// recovers the `Defect.defectId` by stripping the `defect-` prefix.
String defectTriageWorkItemId(String defectId) => 'defect-$defectId';

/// Idempotency keys for the fixed triage walk-up through the workflow graph.
/// A crash between any two hops leaves the durable record consistent: the
/// replay observes the same key and returns the already-accepted outcome
/// instead of re-running the transition.
const String _planningKey = 'triage-intake:planning';
const String _plannedKey = 'triage-intake:planned';
const String _designNotRequiredKey = 'triage-intake:designNotRequired';

/// Durably provisions the `WorkItem` that carries AI triage for a defect.
///
/// Defect intake used to build this `WorkItem` in memory only, derive a dedupe
/// key and an instruction from it, and enqueue a job referencing it. Nothing
/// was ever written to `work_item`, so `Scheduler.tick` could not resolve the
/// item (`_eligibleRunnableJobs` skips any job whose work item is missing) and
/// the triage job stayed `queued` forever. This class is the fix: the item is
/// persisted, and driven through the workflow graph to a state the
/// `triageDefectDefinition` accepts as an entry state, BEFORE the job is
/// enqueued.
///
/// ## The QA contract is provisioned here, not invented downstream
///
/// `GuardConditions.qaContractExists()` refuses
/// `agentExecuting -> agentCompleted` unless the work item carries a
/// `qaContractId`, and `ExecutionCoordinator._completeSuccess` puts the work
/// item's own id into the transition context. No production caller ever passed
/// one, so a durably enqueued triage job dispatched, executed, was refused at
/// the last transition, and was recorded as `JobFailureKind.permanent` with
/// the work item stranded in `agentExecuting`.
///
/// The repair belongs at the work item's creation because that is where the
/// contract becomes true: [buildAdvisoryTriageQAContract] produces a real
/// [QAContract], [QAContractStore.provisionQAContract] persists it and reads it
/// back, and only the id of the row that was actually read back is stamped on
/// the work item. No string is minted to satisfy the guard — see
/// [_provisionQAContract].
///
/// Nothing here decides workflow policy. Every state change goes through
/// [DurableWorkflowEngine.transition], so the transition graph in
/// `workflow_engine` remains the only authority (AGENTS.md §1).
class DefectTriageWorkItemProvisioner {
  DefectTriageWorkItemProvisioner({
    required this.workflowStore,
    required this.workflowEngine,
    this.qaContractStore,
    this.log,
  });

  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;

  /// Where the QA contract is persisted.
  ///
  /// Nullable because the provisioner is constructed in more than one place
  /// and only some of them can supply a store. When it is absent this class
  /// does NOT invent a `qaContractId` and does NOT skip the work item: it
  /// creates the item exactly as it did before, without a contract, and logs
  /// `triage.qa_contract.store_unavailable` so the gap is greppable. A
  /// fabricated id would satisfy the guard and satisfy nothing else, which is
  /// the failure this work item exists to close.
  final QAContractStore? qaContractStore;
  final void Function(String event, Map<String, Object?> fields)? log;

  /// The defect-triage bucket is a human-report surface, not an autonomous
  /// planner, so the walk-up is performed by the orchestrator.
  static const WorkflowActor _actor = WorkflowActor(
    actorId: 'defect-intake',
    actorType: ActorType.orchestrator,
  );

  /// Returns the durable triage work item for [defect], creating and advancing
  /// it if this is the first time it is requested.
  ///
  /// Idempotent by construction: an existing `defect-{defectId}` row is read
  /// and returned, never re-created, so replaying defect intake cannot produce
  /// a duplicate work item (and therefore cannot produce a second dedupe key).
  ///
  /// [evidenceJson] is the JSON array of already-persisted evidence
  /// descriptors; it is stored on the work item metadata so
  /// `triageDefectInstruction` renders the real evidence instead of a
  /// placeholder.
  Future<WorkItem> ensurePersisted({
    required Defect defect,
    String? evidenceJson,
  }) async {
    final workItemId = defectTriageWorkItemId(defect.defectId);
    final existing = await _readOrNull(workItemId);

    if (existing != null) {
      log?.call('triage.work_item.replayed', {
        'workItemId': workItemId,
        'state': existing.state.wire,
        'version': existing.version,
      });
      return _advanceToTriageable(await _attachQAContract(existing, defect));
    }

    final productId = await _resolveProductId(defect);
    final created = await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: productId,
      // Unchanged from the previous in-memory value. `WorkItemCategory` has no
      // `bug` variant and nothing in the scheduler/worker/execution path
      // consumes `category`; changing it is a domain decision, not wiring.
      // `triageWorkItemCategory` is the same value, named once so the QA
      // contract's `workItemCategory` cannot drift from the row it is
      // attached to.
      category: triageWorkItemCategory,
      title: defect.title,
      description: _workItemDescription(defect),
      // The id of a QA contract that was persisted and read back, or null
      // when no store was supplied. Never a placeholder.
      qaContractId: await _provisionQAContract(defect),
      // Traceability for the `planning_evidence_provided` guard on
      // planning -> planned. The defect IS the requirement reference.
      featureRef: defect.defectId,
      metadata: _metadata(defect, evidenceJson),
      createdAt: defect.createdAt,
    );

    log?.call('triage.work_item.created', {
      'workItemId': workItemId,
      'defectId': defect.defectId,
      'productId': productId,
      'qaContractId': created.qaContractId,
    });

    return _advanceToTriageable(created);
  }

  /// Persists the advisory triage QA contract for [defect] and returns the id
  /// of the row that was read back, or `null` when there is no store to
  /// persist it into.
  ///
  /// The id is not derived here and is not trusted from the argument: it is
  /// read back out of PostgreSQL by
  /// [QAContractStore.provisionQAContract], so the value handed to
  /// `createWorkItem` provably resolves. A [QAContract] built but not stored
  /// would leave the guard satisfied and every reader of the work item
  /// looking at an id with nothing behind it.
  ///
  /// Idempotent, twice over. The `contractId` is a pure function of
  /// `defectId`, so a replay addresses the same primary key; and the contract
  /// is built with the defect's own intake instant as both `createdAt` and
  /// `updatedAt`, so a replay is a byte-identical write rather than a row that
  /// churns on every pass.
  Future<String?> _provisionQAContract(Defect defect) async {
    final store = qaContractStore;
    if (store == null) {
      log?.call('triage.qa_contract.store_unavailable', {
        'defectId': defect.defectId,
        'workItemId': defectTriageWorkItemId(defect.defectId),
        'reason':
            'no QAContractStore was supplied, so the agentExecuting -> '
            'agentCompleted guard cannot pass for this work item',
      });
      return null;
    }

    final contractId = triageQAContractIdForDefect(defect.defectId);
    final stored = await store.provisionQAContract(
      buildAdvisoryTriageQAContract(
        defectId: defect.defectId,
        workItemId: defectTriageWorkItemId(defect.defectId),
        now: defect.createdAt,
      ),
    );
    if (stored.contractId != contractId) {
      throw StateError(
        'QA contract store returned ${stored.contractId} for a contract '
        'addressed as $contractId',
      );
    }
    if (!await store.hasQAContract(stored.contractId)) {
      throw StateError(
        'QA contract $contractId is not readable after being written',
      );
    }

    log?.call('triage.qa_contract.provisioned', {
      'defectId': defect.defectId,
      'workItemId':
          stored.metadata?[qaContractWorkItemIdMetadataKey] as Object?,
      'contractId': stored.contractId,
      'version': stored.version,
      'gateCount': stored.gates.length,
      'readBack': true,
    });
    return stored.contractId;
  }

  /// Backfills `qaContractId` on an already-provisioned work item that has
  /// none.
  ///
  /// Work items created before the QA contract existed are permanently stuck:
  /// they sit at `designNotRequired` with `qaContractId IS NULL`, so the
  /// completion transition is refused for every future execution and nothing
  /// ever repairs it. The write goes through the store's CAS path rather than
  /// mutating state, and only runs when the column is actually null, so a
  /// replay is a read.
  Future<WorkItem> _attachQAContract(WorkItem item, Defect defect) async {
    if (item.qaContractId != null) return item;
    final contractId = await _provisionQAContract(defect);
    if (contractId == null) return item;

    log?.call('triage.qa_contract.backfilled', {
      'workItemId': item.workItemId,
      'defectId': defect.defectId,
      'contractId': contractId,
      'fromVersion': item.version,
    });
    // `saveWorkItem` returns nothing, and its CAS path raises
    // `ConcurrentModificationException` rather than silently skipping, so the
    // only thing left to confirm is that the id really landed on the row.
    await workflowStore.saveWorkItem(
      item.copyWith(qaContractId: contractId),
      expectedVersion: item.version,
    );
    final updated = await workflowStore.readWorkItem(item.workItemId);
    if (updated.qaContractId != contractId) {
      throw StateError(
        'work item ${item.workItemId} did not retain the QA contract id '
        '$contractId after the CAS write',
      );
    }
    return updated;
  }

  /// Resolves the product a defect belongs to.
  ///
  /// Prefers the authoritative link `defect.affectedWorkItemId ->
  /// work_item.productId`. A report may name a work item that has since been
  /// deleted, or name one at all; neither case invents a product id, both fall
  /// back to the triage bucket. Any other store failure propagates.
  Future<String> _resolveProductId(Defect defect) async {
    final affected = defect.affectedWorkItemId;
    if (affected == null || affected.isEmpty) {
      return defectTriageBucketProductId;
    }
    try {
      final affectedItem = await workflowStore.readWorkItem(affected);
      return affectedItem.productId;
    } on WorkItemNotFoundException {
      log?.call('triage.product.unresolved_affected_work_item', {
        'defectId': defect.defectId,
        'affectedWorkItemId': affected,
        'fallbackProductId': defectTriageBucketProductId,
      });
      return defectTriageBucketProductId;
    }
  }

  /// Walks the item to a state `triageDefectDefinition` accepts
  /// (`designNotRequired` / `designApproved`), resuming from wherever a prior
  /// partial run left it.
  Future<WorkItem> _advanceToTriageable(WorkItem item) async {
    var current = item;

    if (current.state == WorkItemState.draft) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _actor,
        context: {'featureRef': current.featureRef, 'defectIntake': true},
        idempotencyKey: _planningKey,
      );
    }

    if (current.state == WorkItemState.planning) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _actor,
        context: {'featureRef': current.featureRef, 'defectIntake': true},
        idempotencyKey: _plannedKey,
      );
    }

    if (current.state == WorkItemState.planned) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: _actor,
        context: {'featureRef': current.featureRef, 'defectIntake': true},
        idempotencyKey: _designNotRequiredKey,
      );
    }

    if (current.state != WorkItemState.designNotRequired &&
        current.state != WorkItemState.designApproved) {
      // Someone else owns this item's lifecycle. The workflow graph is the
      // authority and the scheduler's `RunnableWorkEvaluator` will classify
      // this as `noAction`, so the queued job is left untouched rather than
      // forced. Surfaced loudly because it means the defect will not be
      // triaged until a human moves the item.
      log?.call('triage.work_item.not_triageable', {
        'workItemId': current.workItemId,
        'state': current.state.wire,
      });
    }

    return current;
  }

  Future<WorkItem?> _readOrNull(String workItemId) async {
    try {
      return await workflowStore.readWorkItem(workItemId);
    } on WorkItemNotFoundException {
      return null;
    }
  }

  /// Composed prose rather than the raw human report: `createWorkItem`
  /// enforces the human-facing description contract (PL-6, a bare technical
  /// identifier is rejected), and the triage work item is shown in the
  /// control-plane "All work" surface where the reporter's words alone are not
  /// enough context.
  String _workItemDescription(Defect defect) {
    final buffer = StringBuffer(
      'Human-reported defect awaiting AI triage. Reported by '
      '${defect.reporter} at ${defect.createdAt.toIso8601String()}.',
    );
    buffer.write('\nReported behaviour: ${defect.description}');
    if (defect.expectedBehavior != null &&
        defect.expectedBehavior!.trim().isNotEmpty) {
      buffer.write('\nExpected behaviour: ${defect.expectedBehavior}');
    }
    if (defect.reproductionSteps != null &&
        defect.reproductionSteps!.trim().isNotEmpty) {
      buffer.write('\nReproduction steps: ${defect.reproductionSteps}');
    }
    return buffer.toString();
  }

  /// Metadata consumed by `triageDefectInstruction`. Without these the
  /// instruction silently falls back to `workItemId` (which still carries the
  /// `defect-` prefix) and to a hard-coded `medium` severity, so the triage
  /// agent would reason about a defect it cannot identify.
  Map<String, dynamic> _metadata(Defect defect, String? evidenceJson) {
    return <String, dynamic>{
      'defectId': defect.defectId,
      'defectTitle': defect.title,
      'defectDescription': defect.description,
      'defectSeverity': defect.severity,
      'defectExpectedBehavior': defect.expectedBehavior,
      'defectReproductionSteps': defect.reproductionSteps,
      'defectEvidence': evidenceJson ?? jsonEncode(const <Object>[]),
      'defectReporter': defect.reporter,
    };
  }
}

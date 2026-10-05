import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

import 'lane_a_defect_triage_work_item.dart' show defectTriageBucketProductId;

/// Metadata key: this work item exists because triage classified the defect as
/// a design flaw, and nothing has converted that classification into a
/// `DesignRevision` yet.
const String designRemediationRequiredKey = 'designRemediationRequired';

/// Metadata key: the design governance runtime that would have to produce the
/// `DesignRevision`. `unavailable` means the runtime does not exist in
/// shipit-platform, not that a human declined to run it.
const String designGovernanceRuntimeKey = 'designGovernanceRuntime';

/// Metadata key: why this item cannot progress past `planned`.
const String blockedByKey = 'blockedBy';

/// The honest terminal state of this flow until the design governance runtime
/// exists (ADR 0021, `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`).
const String externalDesignGovernanceDependency =
    'EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY';

/// Value recorded under [designGovernanceRuntimeKey].
const String designGovernanceRuntimeUnavailable = 'unavailable';

/// Idempotency keys for the `draft -> planning -> planned` walk-up. A crash
/// between any two hops leaves the durable record consistent: the replay
/// observes the same key and returns the already-accepted outcome instead of
/// re-running the transition.
const String _planningKey = 'design-remediation:planning';
const String _plannedKey = 'design-remediation:planned';

/// Stable work item identity for the remediation of [defectId].
///
/// The `design-remediation-{defectId}` shape is load-bearing: it is what makes
/// [DesignRemediationWorkItemProvisioner.ensurePersisted] idempotent, and it is
/// the id the integration suite reads the remediation work item by.
String designRemediationWorkItemId(String defectId) =>
    'design-remediation-$defectId';

/// Resolves the product a design remediation item for [defect] belongs to.
///
/// This is deliberately the SAME resolution `DefectTriageWorkItemProvisioner`
/// applies to the defect's own triage work item, so a remediation item is
/// never filed under a different product from its triage parent. [Defect]
/// carries no `productId` and the `defect` table has no such column; the only
/// authoritative link is `defect.affectedWorkItemId -> work_item.productId`,
/// which is the same join `PostgresDefectStore.listDefects` filters on.
///
/// Returns `null` — meaning "create nothing" — only when the link resolves to a
/// blank product id. `work_item."productId"` is `text NOT NULL`, so a blank
/// string would be accepted by the database and then silently mis-file the
/// item; that is a failure to resolve, not a resolution. Any other store
/// failure propagates, exactly as it does for the triage parent.
Future<String?> resolveDesignRemediationProductId({
  required Defect defect,
  required WorkflowStore workflowStore,
  void Function(String event, Map<String, dynamic> data)? log,
}) async {
  final affected = defect.affectedWorkItemId;
  if (affected == null || affected.isEmpty) {
    return defectTriageBucketProductId;
  }
  try {
    final affectedItem = await workflowStore.readWorkItem(affected);
    final productId = affectedItem.productId;
    if (productId.trim().isEmpty) {
      return null;
    }
    return productId;
  } on WorkItemNotFoundException {
    log?.call('design_remediation.product_triage_bucket', {
      'defectId': defect.defectId,
      'affectedWorkItemId': affected,
      'fallbackProductId': defectTriageBucketProductId,
      'reason': 'affected work item no longer exists',
    });
    return defectTriageBucketProductId;
  }
}

/// Durably provisions the `WorkItem` that carries design remediation for a
/// defect that AI triage classified as `DESIGN_DEFECT`.
///
/// ## Why it stops at `planned`
///
/// This item used to be walked `draft -> planning -> planned ->
/// designRequired`, with `context: {'designContractId': 'auto'}` supplied
/// purely to satisfy `GuardConditions.designContractExists()`. That guard only
/// null-checks the key, and `DurableWorkflowEngine.transition` discards it, so
/// the item persisted at `designRequired` with `designContractId == NULL`: a
/// state that asserts design work is routed while no design artifact exists.
///
/// There is no honest way to obtain a real design contract here — no
/// `design_contract` table, no `DesignContractStore`, and ADR 0021 rejects
/// triage producing design artifacts directly:
///
/// > **AI triage directly creates DesignRevision:** Rejected — triage is
/// > advisory; design production requires design agent + independent review
///
/// ADR 0021 is explicit about what happens until that runtime exists:
///
/// > **If `DESIGN_GOVERNANCE_AUTOMATION_001` is not yet implemented in
/// > shipit-platform**, the boundary stops at WorkItem creation. The defect
/// > remains in `remediationPlanned` with a linked WorkItem that cannot progress
/// > until the design governance runtime exists. This is reported as
/// > `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`.
///
/// So the walk stops at `planned` — the last state reachable without a design
/// artifact — and the dependency is recorded in the work item's metadata
/// ([designRemediationRequiredKey], [designGovernanceRuntimeKey],
/// [blockedByKey]) rather than in a fabricated id or an unreachable state.
/// `designNotRequired` is not a substitute: it asserts the opposite of the
/// truth, that no design work is needed.
///
/// Nothing here decides workflow policy. Every state change goes through
/// [DurableWorkflowEngine.transition], so the transition graph in
/// `workflow_engine` remains the only authority (AGENTS.md §1).
class DesignRemediationWorkItemProvisioner {
  DesignRemediationWorkItemProvisioner({
    required this.workflowStore,
    required this.workflowEngine,
    this.log,
  });

  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final void Function(String event, Map<String, dynamic> data)? log;

  /// Routing a human-reported design flaw to the design lane is an orchestrator
  /// decision, so the walk-up is performed by the orchestrator. The distinct
  /// `actorId` keeps this actor separable in the transition history from the
  /// `defect-intake` actor that provisions the triage work item.
  static const WorkflowActor _actor = WorkflowActor(
    actorId: 'defect-remediation',
    actorType: ActorType.orchestrator,
  );

  /// Returns the durable remediation work item for [defect], creating and
  /// advancing it if this is the first time it is requested.
  ///
  /// Idempotent by construction: an existing `design-remediation-{defectId}`
  /// row is read and advanced, never re-created. That matters because
  /// `WorkflowStore.saveWorkItem` without an expected version is an
  /// unconditional upsert, so re-running `createWorkItem` on a retry would
  /// clobber the item back to `draft`/`version 1`.
  ///
  /// Returns `null` — after logging `design_remediation.product_unresolved` —
  /// when [defect] resolves to no product at all. Nothing is fabricated: no id
  /// is derived from the defect id, and the caller treats a `null` result as
  /// "triage is durable, remediation was not created".
  Future<WorkItem?> ensurePersisted({
    required TriageResult triageResult,
    required Defect defect,
  }) async {
    final productId = await resolveDesignRemediationProductId(
      defect: defect,
      workflowStore: workflowStore,
      log: log,
    );
    if (productId == null) {
      log?.call('design_remediation.product_unresolved', {
        'defectId': defect.defectId,
        'triageResultId': triageResult.resultId,
        'affectedWorkItemId': defect.affectedWorkItemId,
        'reason': 'affected work item resolves to a blank product id',
      });
      return null;
    }

    final workItemId = designRemediationWorkItemId(defect.defectId);
    final existing = await _readOrNull(workItemId);
    if (existing != null) {
      log?.call('design_remediation.replayed', {
        'workItemId': workItemId,
        'defectId': defect.defectId,
        'state': existing.state.wire,
        'version': existing.version,
      });
      return _advanceToPlanned(
        existing,
        defectId: defect.defectId,
        featureRef: defect.defectId,
      );
    }

    final now = DateTime.now().toUtc();
    final request = DesignRemediationRequest(
      defectId: defect.defectId,
      productId: productId,
      // The defect's own title, not the agent's category guess. The agent's
      // `suspectedCategory` belongs in `designFlawDescription`, where it is
      // read as a hypothesis rather than as the name of the defect.
      defectTitle: defect.title,
      triageSummary: triageResult.summary,
      evidenceRefs: triageResult.evidenceUsed,
      designFlawDescription: _designFlawDescription(triageResult),
      classification: DefectClassification.designDefect,
      triageResultId: triageResult.resultId,
      createdAt: now,
    );

    final created = await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: productId,
      category: WorkItemCategory.feature,
      title: 'Design remediation: ${defect.title}',
      description: _description(request, defect),
      // Traceability for the `planning_evidence_provided` guard on
      // planning -> planned. The defect IS the requirement reference.
      featureRef: defect.defectId,
      metadata: _metadata(request),
      createdAt: now,
    );

    log?.call('design_remediation.created', {
      'workItemId': workItemId,
      'defectId': request.defectId,
      'productId': productId,
      'triageResultId': request.triageResultId,
    });

    return _advanceToPlanned(
      created,
      defectId: defect.defectId,
      featureRef: defect.defectId,
    );
  }

  /// Walks the item as far as the workflow graph legally allows without a
  /// design artifact, resuming from wherever a prior partial run left it.
  Future<WorkItem> _advanceToPlanned(
    WorkItem item, {
    required String defectId,
    required String featureRef,
  }) async {
    var current = item;

    if (current.state == WorkItemState.draft) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _actor,
        context: {'featureRef': featureRef, 'designRemediation': true},
        idempotencyKey: _planningKey,
      );
    }

    if (current.state == WorkItemState.planning) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _actor,
        context: {'featureRef': featureRef, 'designRemediation': true},
        idempotencyKey: _plannedKey,
      );
    }

    if (current.state != WorkItemState.planned) {
      // Someone else owns this item's lifecycle — a replay of an item an
      // earlier revision already parked at `designRequired`, or a human. The
      // workflow graph is the authority, so nothing is forced. Surfaced loudly
      // because the remediation cannot progress from where it stands.
      log?.call('design_remediation.not_at_planned', {
        'workItemId': current.workItemId,
        'defectId': defectId,
        'state': current.state.wire,
        'blockedBy': externalDesignGovernanceDependency,
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

  /// The agent's category guess, read as a hypothesis, with the components it
  /// pointed at. An empty component list must not leave a dangling separator.
  String _designFlawDescription(TriageResult triageResult) {
    final components = triageResult.suspectedComponents
        .where((component) => component.trim().isNotEmpty)
        .join(', ');
    return components.isEmpty
        ? triageResult.suspectedCategory
        : '${triageResult.suspectedCategory}: $components';
  }

  /// Human-facing prose (PL-6) that also states plainly where this item stops,
  /// so nobody reads `planned` as "waiting on a scheduler".
  String _description(DesignRemediationRequest request, Defect defect) {
    final buffer = StringBuffer(
      'AI triage classified human-reported defect ${request.defectId} '
      '("${defect.title}") as a design flaw. The reported behaviour was: '
      '${defect.description}',
    );
    buffer.write('\nSuspected area: ${request.designFlawDescription}');
    if (request.evidenceRefs.isNotEmpty) {
      buffer.write('\nEvidence: ${request.evidenceRefs.join(', ')}');
    }
    buffer.write('\nTriage summary: ${request.triageSummary}');
    buffer.write('\nTriageResult: ${request.triageResultId}');
    buffer.write(
      '\nThis item stops at planned. Producing the DesignRevision that would '
      'unblock it belongs to the design governance runtime '
      '(DESIGN_GOVERNATION_AUTOMATION_001), which does not exist in '
      'shipit-platform; triage is advisory and must not produce design '
      'artifacts. Until that runtime exists this work item is reported as '
      '$externalDesignGovernanceDependency (ADR 0021).',
    );
    return buffer.toString();
  }

  /// The durable provenance of the item: what it was opened from, plus the
  /// external-runtime dependency that currently stops it.
  Map<String, dynamic> _metadata(DesignRemediationRequest request) {
    return <String, dynamic>{
      'designRemediationRequest': request.toJson(),
      'defectId': request.defectId,
      'defectTitle': request.defectTitle,
      designRemediationRequiredKey: true,
      designGovernanceRuntimeKey: designGovernanceRuntimeUnavailable,
      blockedByKey: externalDesignGovernanceDependency,
    };
  }
}

import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
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

/// Metadata key under which this work item records WHY it has no QA contract.
///
/// Two independent reasons park a remediation item now, and they are not the
/// same one: the design governance runtime does not exist (recorded under
/// [blockedByKey] as [externalDesignGovernanceDependency]), and the product has
/// no QA contract to provision from. Recording only the first would leave an
/// operator reading `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` and concluding the
/// QA contract was handled, when it is precisely what will refuse the
/// completion transition. So the second reason gets its own key rather than
/// overloading [blockedByKey], which means the two can both be read off one row.
///
/// The VALUE is one of the three names below. Never a free-text "it failed",
/// because this value is now a durable record on a work item.
const String productQAContractSpecUnavailableKey =
    'productQAContractSpecUnavailable';

/// No `product_qa_contract_spec` row exists for this item's product.
const String productQAContractSpecUndeclared = 'notDeclared';

/// A row exists but declares no gates, so it cannot constrain anything.
const String productQAContractSpecDeclaresNoGates = 'declaresNoGates';

/// No provisioner was supplied to this provisioner at all.
///
/// A third condition, deliberately not folded into either of the other two:
/// it is a missing dependency rather than a missing declaration, and the fix is
/// to pass the provisioner rather than to register a manifest.
const String productQAContractProvisionerUnavailable = 'provisionerUnavailable';

/// Metadata key naming that no [DesignContractProvisioner] was supplied, so no
/// design contract was written for this item.
///
/// It is a separate key from [productQAContractSpecUnavailableKey] for the same
/// reason that one is: two independent strands park a remediation item, and one
/// key holding both would leave an operator unable to tell which is missing.
/// Here the ONLY reason is a missing dependency — the design contract store is
/// never asked and never answers — so this key's presence is the whole reason.
const String designContractProvisionerUnavailableKey =
    'designContractProvisionerUnavailable';

/// The value under [designContractProvisionerUnavailableKey]. Named once, and
/// asserted against, for the reason [_refusalName] gives for the QA side: this
/// string is now a durable record on a work item.
const String designContractProvisionerUnavailable = 'provisionerUnavailable';

/// Idempotency keys for the `draft -> planning -> planned` walk-up. A crash
/// between any two hops leaves the durable record consistent: the replay
/// observes the same key and returns the already-accepted outcome instead of
/// re-running the transition.
const String _planningKey = 'design-remediation:planning';
const String _plannedKey = 'design-remediation:planned';

/// Idempotency key for the `planned -> designParked` hop into the design park.
///
/// A crash between the walk-up and the park leaves the durable record
/// consistent, on the same terms as the two above it: the replay observes the
/// same key and returns the already-accepted outcome.
const String _designParkedKey = 'design-remediation:designParked';

/// Log values naming WHICH INPUT resolved the product that governs an existing
/// remediation row. Read on `design_remediation.replayed` so a divergence
/// between the row's product and the defect-derived one is legible from a log
/// line rather than only inferred from a refusal.
const String _productIdSourceExistingRow = 'existingWorkItem';
const String _productIdSourceDefectDerived = 'defectDerived';

/// Stable work item identity for the remediation of [defectId].
///
/// The `design-remediation-{defectId}` shape is load-bearing: it is what makes
/// [DesignRemediationWorkItemProvisioner.ensurePersisted] idempotent, and it is
/// the id the integration suite reads the remediation work item by.
String designRemediationWorkItemId(String defectId) =>
    'design-remediation-$defectId';

/// Resolves the product a design remediation item for [defect] belongs to.
///
/// ## This is the CREATION-TIME resolution, and it is deliberately left alone
///
/// Every statement below describes the defect-derived resolution, and all of it
/// still holds for creating an item. It is NOT how an item that already exists
/// is resolved: on the replay/backfill branch — where there is a row to read —
/// the row's own `productId` governs, via
/// `_governingProductIdOfExistingRow`. There is nothing to read at creation
/// time, so the defect remains the only input available then.
///
/// The split exists because a defect with no `affectedWorkItemId` resolves to
/// the `defects` ROUTING BUCKET, which has no `product` row and no declared QA
/// contract, so a gate sought there can never be provisioned. That is the right
/// input for FIling a defect — there is genuinely no product — and the wrong one
/// for governing a work item that already records the product it belongs to.
/// Changing the resolution below would change the filing of every orphan defect
/// ever triaged; the replay branch is where that disagreement is corrected.
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
/// ## Why it parks at `designParked`
///
/// This item used to be walked `draft -> planning -> planned ->
/// designRequired`, with `context: {'designContractId': 'auto'}` supplied
/// purely to satisfy `GuardConditions.designContractExists()`. That guard only
/// null-checks the key, and `DurableWorkflowEngine.transition` discards it, so
/// the item persisted at `designRequired` with `designContractId == NULL`: a
/// state that asserts design work is routed while no design artifact exists.
///
/// There is no honest way to obtain a real design contract from TRIAGE — ADR
/// 0021 rejects triage producing design artifacts directly:
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
/// So the walk stops at `designParked` — a state in no lane's `entryStates`,
/// which is what makes it a holding state rather than a waypoint — and the
/// dependency is recorded in the work item's metadata
/// ([designRemediationRequiredKey], [designGovernanceRuntimeKey],
/// [blockedByKey]) rather than in a fabricated id or an unreachable state.
/// `designNotRequired` is not a substitute: it asserts the opposite of the
/// truth, that no design work is needed. `planned` is not one either: it is a
/// triage entry state, and the triage lane takes a design-remediation item back
/// out of it and re-dispatches for ever.
///
/// ## What this lane DOES write, and why
///
/// One `draft` [DesignContract] per remediation item, at creation, through
/// [designContractProvisioner]. That is a REQUIREMENT contract — which artifact
/// must be submitted, which reviewers, what approval threshold — and building it
/// is not producing design: it asserts nothing about what the design says. It is
/// what gives the `designParked -> designRequired` release something durable to
/// be released against, instead of a string a caller passed. The id stamped on
/// the item is the id of the row that was READ BACK, never a placeholder.
///
/// ## Why the QA contract is provisioned here, too
///
/// The stop above is not the only thing that can strand this item, and the
/// second reason is the one this change is about. `WorkEntryTrigger` walks
/// `planned -> designNotRequired`, that state is an entry state of
/// `triageDefectDefinition`, and `agentExecuting -> agentCompleted` carries
/// `GuardConditions.qaContractExists()`. An item with no `qaContractId` runs a
/// real agent and is then refused, which is what stranded every
/// `design-remediation-*` work item measured on 2026-10-17 (0 of 4 carried one,
/// against 10 of 10 for the triage lane).
///
/// So the contract comes from the PRODUCT's declared QA spec, at the item's
/// creation, exactly as lane A's comes from the triage contract builder. The id
/// stamped is `productQAContractIdForWorkItem(design-remediation-$defectId)` —
/// work-item-scoped, so it cannot collide with, overwrite or re-point the triage
/// contract that the same defect already owns under
/// `triageQAContractIdForDefect($defectId)`. That collision is not hypothetical:
/// `design-remediation-DEF-X` and `defect-DEF-X` name the same defect, and
/// `saveQAContract` is `ON CONFLICT ("contractId") DO UPDATE`, so a
/// defect-scoped id here would have silently repointed the triage parent's
/// `metadata.workItemId` at this item.
///
/// ## Why a missing declaration does not refuse the work item
///
/// [ProductQAContractProvisioner] fails CLOSED with a named reason
/// ([productQAContractSpecUndeclared] or
/// [productQAContractSpecDeclaresNoGates]) and writes no contract. This class
/// does not then refuse to create the item: a design defect is a fact that was
/// reported and classified, and refusing to record it because the platform has
/// no QA contract configured would lose the report — the same reasoning that
/// keeps this item at `planned` rather than at a state asserting design work is
/// routed. The item is created and the reason is on it, so the two things that
/// park it are both visible on the row instead of one being inferred from the
/// other.
///
/// Nothing here decides workflow policy. Every state change goes through
/// [DurableWorkflowEngine.transition], so the transition graph in
/// `workflow_engine` remains the only authority (AGENTS.md §1).
class DesignRemediationWorkItemProvisioner {
  DesignRemediationWorkItemProvisioner({
    required this.workflowStore,
    required this.workflowEngine,
    this.qaContractProvisioner,
    this.designContractProvisioner,
    this.log,
  });

  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;

  /// Where the QA contract is built from the product's declared spec and
  /// persisted.
  ///
  /// Nullable for the same reason lane A's [QAContractStore] is nullable: this
  /// class is constructed in more than one place and not all of them can supply
  /// a store. When it is absent, this class does NOT invent a `qaContractId` and
  /// does NOT skip the work item — it creates the item exactly as it did before
  /// this change, without a contract, and records
  /// [productQAContractProvisionerUnavailable] under
  /// [productQAContractSpecUnavailableKey] on it, so the gap is greppable on the
  /// row rather than only in a log.
  final ProductQAContractProvisioner? qaContractProvisioner;

  /// Where the design contract is built and persisted, read back, for this item.
  ///
  /// This is the production caller [DesignContractBuilder] lacked: without one,
  /// `DesignContractStore` is a table nobody fills and
  /// `designContractExists()` refuses every release for a reason that looks
  /// identical to "the operator forgot to provision one".
  ///
  /// The [DesignContractProvisioner] is taken rather than a bare
  /// `DesignContractStore` because the id this lane stamps on the work item
  /// must name a row that was READ BACK, not one that was merely written — the
  /// discipline §4.2(b) names, and the same one
  /// [_provisionQAContract] uses for the QA contract. Provisioning the store
  /// directly would put that half back within reach of a future edit.
  ///
  /// Nullable for the same reason [qaContractProvisioner] is: this class is
  /// constructed in more than one place. When absent this class does NOT invent
  /// a `designContractId` and does NOT skip the work item — it records
  /// [designContractProvisionerUnavailableKey] on the item, so the gap is
  /// greppable on the row rather than only in a log.
  final DesignContractProvisioner? designContractProvisioner;
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
      // On this branch there IS a row, so there is something to read, and the
      // row's own recorded product governs it. `productId` above is still the
      // DEFECT-derived resolution and stays the creation-time input below.
      final governing = _governingProductIdOfExistingRow(
        existing,
        defectDerivedProductId: productId,
      );
      log?.call('design_remediation.replayed', {
        'workItemId': workItemId,
        'defectId': defect.defectId,
        'state': existing.state.wire,
        'version': existing.version,
        // Which product governs this row and which input it came from. The two
        // can differ — that divergence is the defect this branch exists to stop
        // — so the source is recorded rather than left to be inferred.
        'productId': governing.productId,
        'productIdSource': governing.source,
        'defectDerivedProductId': productId,
      });
      return _advanceToDesignParked(
        await _attachDesignContract(
          await _attachQAContract(existing, governing.productId),
          productId: governing.productId,
          defectId: defect.defectId,
          triageResultId:
              existing.metadata?['triageResultId'] as String? ??
              triageResult.resultId,
        ),
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

    final qaContract = await _provisionQAContract(productId, workItemId, now);

    final designContract = await _provisionDesignContract(
      productId: productId,
      workItemId: workItemId,
      defectId: defect.defectId,
      triageResultId: triageResult.resultId,
      now: now,
    );

    final created = await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: productId,
      category: WorkItemCategory.feature,
      title: 'Design remediation: ${defect.title}',
      description: _description(request, defect),
      // The id of a QA contract that was persisted and read back, or null when
      // the product has declared none — in which case the metadata below names
      // which of the two reasons applies. Never a placeholder.
      qaContractId: qaContract.contractId,
      // The id of a design contract that was persisted and read back, or null
      // when no provisioner was supplied — in which case the metadata below
      // names that reason. `designParked -> designRequired` is guarded on this
      // column AND a store confirmation, so a null here is a correct refusal at
      // release time rather than a broken row.
      designContractId: designContract.contractId,
      // Traceability for the `planning_evidence_provided` guard on
      // planning -> planned. The defect IS the requirement reference.
      featureRef: defect.defectId,
      metadata: _metadata(
        request,
        qaContract.refusal,
        designContract.refusal,
      ),
      createdAt: now,
    );

    log?.call('design_remediation.created', {
      'workItemId': workItemId,
      'defectId': request.defectId,
      'productId': productId,
      'triageResultId': request.triageResultId,
      'qaContractId': created.qaContractId,
      'productQAContractSpecUnavailable': qaContract.refusal,
      'designContractId': created.designContractId,
      'designContractProvisionerUnavailable': designContract.refusal,
    });

    return _advanceToDesignParked(
      created,
      defectId: defect.defectId,
      featureRef: defect.defectId,
    );
  }

  /// Builds and persists the QA contract for [workItemId] from [productId]'s
  /// declared spec, and returns it read back.
  ///
  /// The two refusal cases are collapsed into ONE result carrying a name, never
  /// into a bare `null`. A bare `null` on this path is indistinguishable from
  /// "the store was not wired", from "the product declared nothing" and from
  /// "the product declared something empty", and all three leave the work item
  /// exactly as stranded as it was before this change while saying nothing about
  /// why. The name is written onto the work item's own metadata, so the row an
  /// operator meets names the reason it cannot complete.
  Future<_RemediationQAContract> _provisionQAContract(
    String productId,
    String workItemId,
    DateTime now,
  ) async {
    final provisioner = qaContractProvisioner;
    if (provisioner == null) {
      log?.call('design_remediation.qa_contract.provisioner_unavailable', {
        'workItemId': workItemId,
        'productId': productId,
        'reason':
            'no ProductQAContractProvisioner was supplied, so the '
            'agentExecuting -> agentCompleted guard cannot pass for this work '
            'item',
      });
      return const _RemediationQAContract.refused(
        productQAContractProvisionerUnavailable,
      );
    }
    try {
      final contract = await provisioner.provisionForWorkItem(
        productId: productId,
        workItemCategory: WorkItemCategory.feature,
        workItemId: workItemId,
        // The remediation item's own creation instant, so a replay that
        // re-provisions writes the same bytes rather than churning the row.
        now: now,
      );
      log?.call('design_remediation.qa_contract.provisioned', {
        'workItemId': workItemId,
        'productId': productId,
        'contractId': contract.contractId,
        'version': contract.version,
        'gateCount': contract.gates.length,
        'readBack': true,
      });
      return _RemediationQAContract.provisioned(contract.contractId);
    } on ProductQAContractSpecUnavailable catch (refusal) {
      log?.call('design_remediation.qa_contract.not_provisioned', {
        'workItemId': workItemId,
        'productId': productId,
        'refusal': refusal.refusal.name,
        'reason': refusal.toString(),
      });
      return _RemediationQAContract.refused(
        _refusalName(refusal.refusal),
      );
    }
  }

  /// Builds and persists the [DesignContract] this remediation item is governed
  /// by, and returns the row read back.
  ///
  /// ## WHY THIS IS AT CREATION AND NOT AT RELEASE
  ///
  /// The release edge (`designParked -> designRequired`) is guarded by
  /// `designContractExists()`, which reads the work item's durable
  /// `designContractId` column AND confirms it against a `DesignContractStore`.
  /// A contract written but not stamped on the column satisfies neither half,
  /// so the contract has to exist before the row that names it.
  ///
  /// ## WHY A FAILURE PROPAGATES RATHER THAN BECOMING A REFUSAL
  ///
  /// The only refusal this records is [designContractProvisionerUnavailable],
  /// which means the store was never asked. `DesignContractProvisioner`
  /// documents that it THROWS rather than returning a contract it did not read
  /// back, and a store that cannot be reached is an outage — recording that as
  /// "this item has no design contract" would file an infrastructure failure as
  /// a missing artifact, which is the confusion
  /// `DurableWorkflowEngine._resolveDesignContract` names for exactly the same
  /// reason. So a throw propagates and the item is not created.
  Future<_RemediationDesignContract> _provisionDesignContract({
    required String productId,
    required String workItemId,
    required String defectId,
    required String triageResultId,
    required DateTime now,
  }) async {
    final provisioner = designContractProvisioner;
    if (provisioner == null) {
      log?.call('design_remediation.design_contract.provisioner_unavailable', {
        'workItemId': workItemId,
        'productId': productId,
        'reason':
            'no DesignContractProvisioner was supplied, so no design contract '
            'row backs this item and designParked -> designRequired will '
            'refuse until one does',
      });
      return const _RemediationDesignContract.refused(
        designContractProvisionerUnavailable,
      );
    }
    final contract = await provisioner.provisionForWorkItem(
      workItemId: workItemId,
      productId: productId,
      // The defect this contract remediates, so an auditor reading the row can
      // reconstruct its scope without following the work item back.
      defectId: defectId,
      triageResultId: triageResultId,
      // The remediation item's own creation instant, so a replay that
      // re-provisions writes the same bytes rather than churning the row.
      now: now,
    );
    log?.call('design_remediation.design_contract.provisioned', {
      'workItemId': workItemId,
      'productId': productId,
      'contractId': contract.contractId,
      'status': contract.status.name,
      'readBack': true,
    });
    return _RemediationDesignContract.provisioned(contract.contractId);
  }

  /// The one place a `ProductQAContractSpecRefusal` becomes a stored value.
  ///
  /// `enum.name` alone would have been shorter and is deliberately not used:
  /// the two names are now part of a durable record on a work item, and a
  /// stored value is not something to take from a rename away in `platform_contracts`
  /// or `qa_orchestration`. They are named here, once, and asserted against.
  static String _refusalName(ProductQAContractSpecRefusal refusal) =>
      switch (refusal) {
        ProductQAContractSpecRefusal.notDeclared =>
          productQAContractSpecUndeclared,
        ProductQAContractSpecRefusal.declaresNoGates =>
          productQAContractSpecDeclaresNoGates,
      };

  /// Which product governs an ALREADY-PERSISTED remediation row, and which
  /// input that answer came from.
  ///
  /// [resolveDesignRemediationProductId] can only reach a product through
  /// `defect.affectedWorkItemId -> work_item.productId`, because [Defect]
  /// carries no `productId` and the `defect` table has no such column. A defect
  /// reported from a surface that carries no work item therefore resolves to the
  /// triage bucket ([defectTriageBucketProductId]) — a ROUTING BUCKET, which
  /// has no `product` row and no `product_qa_contract_spec` row, so the QA gate
  /// for that item can never be provisioned from it.
  ///
  /// The remediation ROW is not derived from the defect: it records the product
  /// the item was filed under, and that is the product whose declared spec
  /// governs its gates. Measured on 2026-10-17, two `design-remediation-*` rows
  /// recorded `shipit-platform` while their own gate was sought under `defects`,
  /// and both refused with `ProductQAContractSpecUnavailable(notDeclared)`
  /// although the contract for their own product was registered. So on the
  /// branch where the row exists, its own `productId` is the answer.
  ///
  /// A blank or whitespace-only `productId` falls back to the defect-derived
  /// value rather than being provisioned under: an empty id names no product and
  /// matches no declaration, so provisioning under it would fail closed with a
  /// refusal about a product that does not exist. The defect-derived value is
  /// at least a real id. This is the ONLY case in which the defect-derived
  /// resolution still governs an existing row.
  ///
  /// The row's product is used verbatim — not trimmed on the way through —
  /// because that is the value the row records and the sibling resolution
  /// returns its value verbatim too.
  ({String productId, String source}) _governingProductIdOfExistingRow(
    WorkItem row, {
    required String defectDerivedProductId,
  }) {
    if (row.productId.trim().isNotEmpty) {
      return (
        productId: row.productId,
        source: _productIdSourceExistingRow,
      );
    }
    return (
      productId: defectDerivedProductId,
      source: _productIdSourceDefectDerived,
    );
  }

  /// Backfills `qaContractId` on an already-provisioned remediation item that
  /// has none.
  ///
  /// THIS IS THE ONLY RECOVERY HOOK ON THIS LANE, and it is why the three items
  /// stranded in `agentExecuting` on 2026-10-17 can be repaired at all.
  /// `ensurePersisted` reads the row first, so re-running it for a defect whose
  /// remediation item already exists takes this branch instead of re-creating
  /// anything, and this branch attaches a contract to the row that exists.
  /// (`createFeatureWorkItem` has no equivalent: it mints a fresh
  /// `WI-feature-${now.microsecondsSinceEpoch}` every call and never reads an
  /// existing row, so a stranded feature item cannot be reached this way at all.)
  ///
  /// [productId] is the product that governs THIS row, so
  /// `_governingProductIdOfExistingRow` has already resolved it from the row —
  /// not from the defect — before this is called. Provisioning the gate under
  /// anything other than the row's own product would leave the row and its gate
  /// governed by different products, which is the state this was repaired from.
  ///
  /// The write goes through the store's CAS path rather than mutating state, and
  /// only runs when the column is actually null, so a replay of an already-stamped
  /// item is a read and two concurrent repairs cannot both win.
  ///
  /// It attaches the contract and NOT the refusal: a refusal writes nothing, so
  /// there is nothing to backfill and the item simply stays as it was. What it
  /// does not do is overwrite a contract that is already there — see the first
  /// line of the body.
  Future<WorkItem> _attachQAContract(WorkItem item, String productId) async {
    if (item.qaContractId != null) return item;
    final provisioned = await _provisionQAContract(
      productId,
      item.workItemId,
      // Read out of the row rather than taken from the clock, so a backfill
      // writes the same bytes no matter how many times it is attempted.
      item.createdAt.toUtc(),
    );
    final contractId = provisioned.contractId;
    if (contractId == null) return item;

    log?.call('design_remediation.qa_contract.backfilled', {
      'workItemId': item.workItemId,
      'defectId': item.metadata?['defectId'],
      'contractId': contractId,
      'fromVersion': item.version,
    });
    // `saveWorkItem` returns nothing and its CAS path raises
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

  /// Backfills the design contract on a remediation row that was created
  /// BEFORE the row named one.
  ///
  /// ## WHY A REPLAY IS THE ONLY PLACE THIS CAN BE FIXED
  ///
  /// Rows created by the pre-F-170 lane carry `designContractId = NULL`; the
  /// contract was never provisioned, so `designParked -> designRequired` — which
  /// is guarded on that column AND a store confirmation — refuses to release
  /// them for ever. The creation path below already provisions a contract, but
  /// the replay path took the early return above and never reached it. Retrying
  /// the SAME operation is what a replayed remediation request is, so it is also
  /// the only moment at which the missing row can be supplied without inventing
  /// a second operation.
  ///
  /// ## SCOPE, DELIBERATELY NARROW
  ///
  /// Runs ONLY when [WorkItem.designContractId] is null. A stamped row is left
  /// byte-identical: re-provisioning it would churn `updatedAt` and could
  /// overwrite a contract an operator is already reviewing. It uses the SAME
  /// `_provisionDesignContract` helper the creation path uses, so the id is a
  /// pure function of the work item id and a replay converges on the one row
  /// rather than minting a second. No new state, disposition or disposition-like
  /// flag is introduced — the item simply acquires the contract it should have
  /// had.
  ///
  /// A missing provisioner is a REFUSAL, not a throw: `_provisionDesignContract`
  /// records that reason and writes nothing, exactly as it does on creation, and
  /// the item is returned as it was. A store outage still propagates, because a
  /// store that cannot be reached is not "no contract".
  Future<WorkItem> _attachDesignContract(
    WorkItem item, {
    required String productId,
    required String defectId,
    required String triageResultId,
  }) async {
    if (item.designContractId != null) return item;
    final provisioned = await _provisionDesignContract(
      productId: productId,
      workItemId: item.workItemId,
      defectId: defectId,
      triageResultId: triageResultId,
      // Read out of the row, not the clock: a replay writes the same bytes and
      // does not re-date a contract that was due at creation time.
      now: item.createdAt.toUtc(),
    );
    final contractId = provisioned.contractId;
    if (contractId == null) return item;

    log?.call('design_remediation.design_contract.backfilled', {
      'workItemId': item.workItemId,
      'defectId': defectId,
      'contractId': contractId,
      'fromVersion': item.version,
    });
    // The same CAS discipline as the QA backfill beside it: the row's version is
    // the concurrency token, and the read-back confirms the id landed rather
    // than trusting a write that returns nothing.
    await workflowStore.saveWorkItem(
      item.copyWith(designContractId: contractId),
      expectedVersion: item.version,
    );
    final updated = await workflowStore.readWorkItem(item.workItemId);
    if (updated.designContractId != contractId) {
      throw StateError(
        'work item ${item.workItemId} did not retain the design contract id '
        '$contractId after the CAS write',
      );
    }
    return updated;
  }

  /// Walks the item as far as the workflow graph legally allows without a design
  /// artifact, resuming from wherever a prior partial run left it.
  ///
  /// ## WHY IT PARKS AT `designParked` AND NOT AT `planned`
  ///
  /// It used to stop at `planned`. That is not a holding state:
  /// `triageDefectDefinition.entryStates` contains `planned`, and
  /// `planned -> designNotRequired` is guarded by `actorAllowed([orchestrator])`
  /// ALONE — it fires whether or not design work is needed. The category-blind
  /// triage scheduler therefore takes a design-remediation item back OUT of
  /// `planned` and re-dispatches it, for ever.
  ///
  /// `designParked` is in the `entryStates` of NO definition, so no scheduler
  /// can see, probe or hop an item resting there. That is a structural closure
  /// rather than a race the lane hopes to win: while the item is parked it is
  /// invisible, so there is no competing write and no window. The release is
  /// `designParked -> designRequired`, guarded by `designContractExists()`.
  Future<WorkItem> _advanceToDesignParked(
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

    if (current.state == WorkItemState.planned) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.designParked,
        trigger: TransitionTrigger.systemEvent,
        actor: _actor,
        context: {'featureRef': featureRef, 'designRemediation': true},
        idempotencyKey: _designParkedKey,
      );
    }

    if (current.state != WorkItemState.designParked) {
      // Someone else owns this item's lifecycle — a replay of an item an
      // earlier revision already released into `designRequired`, or a human.
      // The workflow graph is the authority, so nothing is forced. Surfaced
      // loudly because the remediation cannot progress from where it stands.
      log?.call('design_remediation.not_at_design_parked', {
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
      '\nThis item parks at designParked. Producing the DesignRevision that '
      'would unblock it belongs to the design governance runtime '
      '(DESIGN_GOVERNATION_AUTOMATION_001), which does not exist in '
      'shipit-platform; triage is advisory and must not produce design '
      'artifacts. designParked is in no lane\'s entry states, so nothing '
      'dispatches this item while it waits. Until that runtime exists this work '
      'item is reported as $externalDesignGovernanceDependency (ADR 0021).',
    );
    return buffer.toString();
  }

  /// The durable provenance of the item: what it was opened from, the
  /// external-runtime dependency that currently stops it, and — when the
  /// product has no QA contract to provision, or no design contract could be
  /// provisioned — WHICH named reason that is.
  ///
  /// [qaContractRefusal] and [designContractRefusal] are null on every item
  /// that DID get a contract, so the keys are absent rather than
  /// present-and-null: absent is what
  /// `item.metadata?[productQAContractSpecUnavailableKey]` reads as, and a key
  /// set to null would read as "known to be unknown", which is a different claim
  /// and an unanswerable one.
  Map<String, dynamic> _metadata(
    DesignRemediationRequest request,
    String? qaContractRefusal,
    String? designContractRefusal,
  ) {
    return <String, dynamic>{
      'designRemediationRequest': request.toJson(),
      'defectId': request.defectId,
      'defectTitle': request.defectTitle,
      designRemediationRequiredKey: true,
      designGovernanceRuntimeKey: designGovernanceRuntimeUnavailable,
      blockedByKey: externalDesignGovernanceDependency,
      if (qaContractRefusal != null)
        productQAContractSpecUnavailableKey: qaContractRefusal,
      if (designContractRefusal != null)
        designContractProvisionerUnavailableKey: designContractRefusal,
    };
  }
}

/// What [DesignRemediationWorkItemProvisioner._provisionDesignContract] got.
///
/// The same two-armed shape as [_RemediationQAContract], for the same reason:
/// a caller that drops a `null` cannot then tell "no contract" from "no
/// provisioner to build one with", and the two leave the row looking identical.
class _RemediationDesignContract {
  const _RemediationDesignContract._(this.contractId, this.refusal);

  const _RemediationDesignContract.provisioned(String contractId)
    : this._(contractId, null);

  const _RemediationDesignContract.refused(String refusal)
    : this._(null, refusal);

  /// The id of a row that was persisted and read back, or null. Never a
  /// placeholder.
  final String? contractId;

  /// [designContractProvisionerUnavailable] — recorded as the value of
  /// [designContractProvisionerUnavailableKey] — or null when a contract WAS
  /// provisioned.
  final String? refusal;
}

/// What [_DesignRemediationWorkItemProvisioner._provisionQAContract] got.
///
/// A two-armed value rather than a `String?`, so the contract id and the reason
/// it is absent cannot be confused by a caller that drops a null: the only way
/// to build the refused arm is to say why.
class _RemediationQAContract {
  const _RemediationQAContract._(this.contractId, this.refusal);

  const _RemediationQAContract.provisioned(String contractId)
    : this._(contractId, null);

  const _RemediationQAContract.refused(String refusal) : this._(null, refusal);

  /// The id of a row that was persisted and read back, or null. Never a
  /// placeholder.
  final String? contractId;

  /// One of [productQAContractSpecUndeclared],
  /// [productQAContractSpecDeclaresNoGates] or
  /// [productQAContractProvisionerUnavailable] — recorded as the value of
  /// [productQAContractSpecUnavailableKey] — or null when a contract WAS
  /// provisioned.
  final String? refusal;
}

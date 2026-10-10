import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show ProductNotFoundException, ProductRegistryEngine;
import 'package:scheduler/scheduler.dart'
    show
        JobQueue,
        JobStore,
        triageDefectDefinition,
        triageDefectDedupeKey,
        triageDefectInstruction;
import 'package:workflow_store/workflow_store.dart'
    show ConcurrentModificationException, DurableWorkflowEngine, WorkflowStore;

import 'lane_a_defect_triage_work_item.dart' show defectTriageWorkItemId;

// ---------------------------------------------------------------------------
// The dependency that does not exist yet.
//
// `unavailable` means the runtime does not exist in THIS platform, NOT that a
// human declined to run it. It must never be rendered as "this request failed",
// and it must never be rendered as "waiting for a human": no human is waiting.
// Mirrors `lane_e_design_remediation_work_item.dart`'s
// `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` deliberately — an honestly recorded
// dependency is a fact; a stub that appears to work while dispatching nothing
// is the silent no-op this whole work item exists to close.
// ---------------------------------------------------------------------------

/// Metadata key: which consumer runtime would have to exist for this item's
/// work to be executed.
const String workEntryConsumerKey = 'workEntryConsumer';

/// Metadata key: which intake opened this work item's file.
///
/// Recorded so the routing decision is greppable. It is the durable answer to
/// "why was this item parked?", and it is what a reader checks before assuming
/// a missing job was an oversight.
const String workEntryFeatureIntakeKey = 'featureIntake';

/// Metadata key: why this item cannot progress. Same key lane E uses; the two
/// never share a row (a design-remediation item and a feature-intake item are
/// different work items), and the value is the dependency itself.
const String workEntryBlockedByKey = 'blockedBy';

/// Metadata key: the dispatch gate that is currently closed for this item, if
/// any. Recorded even when the item is parked for the dependency, because "this
/// would dispatch if the product were governed" and "this cannot dispatch under
/// any product state" are different facts and an operator needs both.
const String workEntryDispatchGateKey = 'workEntryDispatchGate';

/// Metadata key: the product state the gate was evaluated against, so a
/// recorded `PRODUCT_NOT_GOVERNED` can be re-checked without re-running.
const String workEntryProductStateKey = 'workEntryProductState';

/// Metadata key: the operator-facing sentence explaining the park, in prose.
///
/// Deliberately a *record on the item*, not only a log line: a log line is
/// gone by the time somebody opens the feature request and asks why it is
/// sitting still.
const String workEntryParkedReasonKey = 'workEntryParkedReason';

/// The honest terminal state of the feature path until a feature consumer
/// exists.
const String externalWorkEntryConsumerDependency =
    'EXTERNAL_WORK_ENTRY_CONSUMER_DEPENDENCY';

/// Value recorded under [workEntryConsumerKey]. See the note above: this is a
/// missing runtime, not a declined run.
const String workEntryConsumerUnavailable = 'unavailable';

/// The dependency metadata every parked feature carries.
///
/// A function rather than a constant because the map is mutable and a shared
/// const map is one `putIfAbsent` away from being corrupted by a caller.
Map<String, dynamic> workEntryExternalDependencyMetadata() => <String, dynamic>{
  workEntryConsumerKey: workEntryConsumerUnavailable,
  workEntryFeatureIntakeKey: 'featureIntake',
  workEntryBlockedByKey: externalWorkEntryConsumerDependency,
};

/// Which intake opened a work item. NOT `WorkItemCategory`.
///
/// ## `category` cannot answer this question, and it cannot even come close
///
/// `triageWorkItemCategory` — the category a DEFECT's triage work item is
/// created with — is defined as `WorkItemCategory.feature`
/// (`qa_orchestration/lib/src/lane_g_triage_qa_contract.dart:27`). So a
/// defect's triage item and a feature request's item carry the **same**
/// category value.
///
/// That makes any category-keyed routing table wrong in both directions at
/// once: keying "feature goes to the feature branch" would park every defect
/// un-triaged, and keying "feature goes to the defect lane" would enqueue
/// triage for every feature — producing a job that parses a `TriageResult`,
/// discards it at `readDefect`, and reports `succeeded` having done nothing.
///
/// Reconciling the two categories is a domain decision nobody has made
/// (`lane_a_defect_triage_work_item.dart` says so in its own comment), so this
/// lane neither relies on nor repairs the disagreement. The intake that
/// created the file knows which lane owns it; that is knowable, stable, and
/// supplied by the caller rather than inferred from a row that was never
/// written to be an inference.
enum WorkEntryKind {
  /// `DefectTriageWorkItemProvisioner` opened `defect-{defectId}`.
  defectTriage,

  /// Feature intake opened `WI-feature-{...}`.
  featureIntake,
}

/// One decision about one piece of work, by the trigger that made it.
///
/// Every outcome is a value, never a silent return. A caller that ignores a
/// [WorkEntrySkipped] is ignoring a named reason, which is the difference
/// between "the sweep ran and found nothing" and "the sweep is not running".
sealed class WorkEntryDecision {
  const WorkEntryDecision();

  /// Greppable reason code, or null for [WorkEntryEnqueued].
  ///
  /// A getter rather than a field so [WorkEntrySkipped] can narrow it to
  /// `String` without overriding a field. `decision.code` is a total function
  /// on the decision, so a caller logging one decision does not have to know
  /// which of the two it holds.
  String? get code => null;

  /// Operator-facing prose. Never carries credential material or a product
  /// source path.
  String? get reason => null;

  /// Every decision prints its reason. A decision with no code has none to
  /// print, so the shape of the value carries it: `WorkEntryEnqueued` names a
  /// job, `WorkEntrySkipped` names a code.
  @override
  String toString() => 'work entry decision (no code)';
}

/// A triage job exists for this work item.
final class WorkEntryEnqueued extends WorkEntryDecision {
  const WorkEntryEnqueued(this.jobId);

  final String jobId;

  @override
  String toString() => 'enqueued $jobId';
}

/// The trigger looked and deliberately did nothing. Each reason is named, so
/// "the trigger ran" and "the trigger ran and decided nothing to do" are
/// distinguishable in a log.
final class WorkEntrySkipped extends WorkEntryDecision {
  const WorkEntrySkipped(this.skipCode, this.skipReason);

  final String skipCode;
  final String skipReason;

  @override
  String get code => skipCode;

  @override
  String get reason => skipReason;

  @override
  String toString() => 'skipped ($skipCode): $skipReason';
}

/// Reason codes [WorkEntryTrigger] produces.
///
/// Every one of these is a decision someone can grep for, which is the entire
/// point: the counts "nothing to do" and "nothing ran" are identical, and only
/// the codes tell them apart.
abstract final class WorkEntrySkipCodes {
  /// A non-terminal triage job already exists for this work item.
  static const String triageAlreadyActive = 'TRIAGE_ALREADY_ACTIVE';

  /// The work item's product is not `governed`, so `ProductState` forbids
  /// dispatching work for it. The request is neither rejected nor failed; the
  /// next pass dispatches it when the product becomes governed.
  static const String productNotGoverned = 'PRODUCT_NOT_GOVERNED';

  /// The product id has no registry row, so whether work may be dispatched for
  /// it cannot be established at all.
  ///
  /// Named separately from [productNotGoverned] on purpose: "not governed" is
  /// a state a product can leave, and "no such product" is an absence this
  /// trigger does not know how to resolve. Collapsing them would report a
  /// permanent condition as a temporary wait.
  static const String productNotInRegistry = 'PRODUCT_NOT_IN_REGISTRY';

  /// No consumer runtime exists for this work item's lane, so nothing would
  /// read the outcome. See [externalWorkEntryConsumerDependency].
  static const String noConsumerForWorkEntryKind =
      externalWorkEntryConsumerDependency;

  /// The design's §4 table named this by category. Kept so a caller written
  /// against the design still resolves, and deliberately given the SAME value
  /// as [noConsumerForWorkEntryKind]: one code, one meaning. The decision is
  /// about the intake KIND, and it CANNOT be about `WorkItemCategory`: a
  /// defect's triage item carries `triageWorkItemCategory`, which is itself
  /// `WorkItemCategory.feature` (`lane_g_triage_qa_contract.dart:27`), so a
  /// category-keyed table would route features to the defect lane and defects
  /// to the feature branch simultaneously. See [WorkEntryKind].
  static const String noConsumerForCategory = noConsumerForWorkEntryKind;

  /// The item is in a state no triage lane claims. The workflow graph is the
  /// authority and nothing is forced.
  static const String notTriagableState = 'NOT_TRIAGABLE_STATE';

  /// The item carries neither `featureRef` nor `requirementRef`, so the
  /// workflow graph's own `planning_evidence_provided` guard refuses
  /// `planning -> planned`. Reported rather than thrown, because a thrown
  /// transition is an incident that hides the reason.
  static const String noPlanningEvidence = 'NO_PLANNING_EVIDENCE';

  /// No work item at the id the sweep derived. Produced by the sweep (which
  /// looks a defect up by a derived id) rather than by the trigger, which is
  /// handed the item and therefore cannot observe its absence. Declared here so
  /// there is exactly one place where work-entry codes live.
  static const String workItemMissing = 'WORK_ITEM_MISSING';

  /// The dedupe key is already held by a job that FINISHED, so no new job can
  /// be created for this work item without changing the key format.
  ///
  /// Distinct from [triageAlreadyActive] because the two mean opposite things
  /// and the honest answer is the one a reader needs: "something is in flight"
  /// says wait; this says the key is spent. A defect triaged once can never be
  /// triaged again on this key, because re-keying would orphan every job
  /// already persisted under the current format — a decision this lane does not
  /// make on its own.
  static const String dedupeKeyAlreadyConsumed = 'DEDUPE_KEY_ALREADY_CONSUMED';

  /// Declared by the design's §4 route table; **not produced** by this trigger.
  ///
  /// Recorded rather than omitted so a reader does not infer a missing case.
  /// A non-terminal job of a DIFFERENT type on this work item is a condition
  /// this trigger cannot honestly interpret: it routes only defect-triage and
  /// feature-intake items, and neither shares a work item with another lane, so
  /// reading one as "another lane owns this" would be a guess dressed as a code.
  static const String otherLaneOwnsItem = 'OTHER_LANE_OWNS_ITEM';
}

/// Idempotency keys for the walk-up, one per hop, constant per work item.
///
/// Distinct from lane A's `triage-intake:*` keys on purpose: the same work item
/// can be walked by both this trigger and the provisioner, and two keys means
/// two independently auditable transition records rather than one actor's
/// history being attributed to the other.
const String _planningKey = 'work-entry:planning';
const String _plannedKey = 'work-entry:planned';
const String _designNotRequiredKey = 'work-entry:designNotRequired';

/// How many compare-and-swap attempts the parked-feature annotation gets
/// before it gives up.
///
/// A conflict means another writer moved the item between the read and the
/// write. Re-reading and retrying is what makes "call this N times" converge on
/// ONE recorded outcome rather than N outcomes or an exception.
const int _annotationAttempts = 3;

/// The one operation both triggers call: intake and the sweep.
///
/// ## Why one operation and not one per trigger
///
/// `createDefect` already enqueues at intake (`enqueueIfAbsent`), and that path
/// has no recovery: an exception, a race, or anything filed before the
/// provisioner existed leaves the work with no job and nothing to retry it. The
/// sweep covers the gap, but two callers writing their own enqueue would have
/// to agree on the dedupe key by convention, and the one artefact that must
/// never drift is the key itself — every job ever persisted carries
/// `'{workItemId}:triage_defect'`.
///
/// So idempotency is a property of THIS function, not of its two callers, and
/// the key is imported from `packages/scheduler` rather than re-spelled.
///
/// ## Why routing lives here and not in the scheduler
///
/// `RunnableWorkEvaluator.evaluate` never reads `item.category` and never
/// resolves `item.productId`. The WorkItem-scoped `Scheduler` is
/// category-blind AND product-state-blind: any work item at a state in
/// `triageDefectDefinition.entryStates` is classified `runnable` and receives a
/// `triage_defect` job.
///
/// Two consequences, and this class is shaped by both:
///
/// * **Routing is done by NOT WALKING an item into an entry state.** There is
///   no filter at dispatch to install, because dispatch does not filter. The
///   feature walk therefore stops at `planned`, which is one hop short of
///   `designNotRequired` and inert to the scheduler.
/// * **The `governed` gate must be evaluated BEFORE the walk.** Walking first
///   and gating afterwards would leave the item at an entry state, where the
///   scheduler's own enqueue step would dispatch it regardless of what this
///   class decided. The gate is only real while it runs first.
///
/// ## What this class does NOT enforce
///
/// It gates the path that goes through it. It cannot gate `createDefect`'s own
/// `enqueueIfAbsent`, nor `Scheduler.tick`'s enqueue step, nor the provisioner
/// that walks a defect's work item to `designNotRequired` at intake
/// regardless of product state. Those are other files and other lanes; the
/// residual is recorded rather than papered over.
class WorkEntryTrigger {
  WorkEntryTrigger({
    required this.workflowStore,
    required this.workflowEngine,
    required this.productRegistryEngine,
    required this.jobStore,
    this.log,
  }) : _queue = JobQueue(store: jobStore);

  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final ProductRegistryEngine productRegistryEngine;
  final JobStore jobStore;

  final JobQueue _queue;
  final void Function(String event, Map<String, dynamic> data)? log;

  /// The work-item identity the defect lane files triage under.
  ///
  /// Delegates to [defectTriageWorkItemId] rather than re-spelling
  /// `'defect-$defectId'`. The shape is load-bearing in three places already —
  /// the scheduler's job `workItemId`, the dedupe key, and
  /// `TriageProcessor._extractDefectId` — and a second literal is a fourth
  /// place for it to drift.
  static String triageWorkItemIdForDefect(String defectId) =>
      defectTriageWorkItemId(defectId);

  /// The work-item walk is an orchestration decision on both lanes, so it is
  /// performed by the orchestrator. `actorId` is distinct from lane A's
  /// `defect-intake` so the transition history keeps the two separable.
  static const WorkflowActor _orchestrator = WorkflowActor(
    actorId: 'work-entry',
    actorType: ActorType.orchestrator,
  );

  /// Ensures [item] has a triage job — or records, by name, why it has none.
  ///
  /// Idempotent in the strong sense. Calling it N times against an unchanged
  /// durable record produces exactly one job and one recorded reason; calling
  /// it after a partial run resumes rather than restarts, because every hop
  /// carries a fixed idempotency key and the enqueue is one transaction guarded
  /// by the store's active-dedupe constraint.
  ///
  /// The order of the gates is load-bearing and is: **active job, then product
  /// gate, then routing, then walk, then enqueue.** The active-job read is one
  /// indexed lookup and answers cheaply, so nothing below it — including the
  /// product read — runs while a question it would not change is still open.
  Future<WorkEntryDecision> ensureWorkEntry({
    required WorkItem item,
    required WorkEntryKind kind,
  }) async {
    final workItemId = item.workItemId;

    // --- 1. CHEAP GUARD FIRST ------------------------------------------------
    // One indexed read. Nothing below it is written until this returns null,
    // which is the same ordering `BaselineOnboardingSweep` applies to
    // `_activeOnboardingJob`: the expensive question is never asked while the
    // cheap one already answers it.
    //
    // This is also the restart guard. `isTerminal` is false for `claimed` and
    // `running`, so a job that was dispatched before the crash is found here
    // and no second job is minted.
    final active = await _activeTriageJob(workItemId);
    if (active != null) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.triageAlreadyActive,
        'job ${active.jobId} is still ${active.state.wire}; nothing was '
        'written and no second triage job exists.',
      );
    }

    // --- 2. PRODUCT GATE ----------------------------------------------------
    // `canonical`, never the raw value: a row persisted as the parse-only
    // legacy `draft` must be READ as `registered`, which is what
    // `BaselineOnboardingSweep.sweepStates` does and why.
    //
    // The read happens once and is shared by both routes, because both need it.
    final gate = await _readProductGate(item.productId);

    // --- 3. ROUTING ---------------------------------------------------------
    // A feature never reaches the defect triage lane. Not "is filtered at
    // dispatch" — dispatch does not filter — but "is never walked into a state
    // dispatch would pick it up from".
    //
    // This branch is first and unconditional, so a feature cannot acquire a
    // `triage_defect` job even if every later check passes. `TriageResult`
    // would parse, `readDefect` would raise, the processor would return early
    // and the job would sit `succeeded` with the outcome discarded: a healthy
    // looking job and no work done.
    if (kind == WorkEntryKind.featureIntake) {
      return _parkFeature(item, gate: gate);
    }

    if (!gate.allowsDispatch) {
      final gateCode = gate.absent
          ? WorkEntrySkipCodes.productNotInRegistry
          : WorkEntrySkipCodes.productNotGoverned;
      // A gated defect must leave a trace, exactly as a parked feature does.
      //
      // Without this the defect branch produced only a returned value, and the
      // counts "nothing to do" and "nothing ran" are identical — which is
      // precisely what `WorkEntrySkipCodes` exists to make distinguishable. The
      // returned decision is a real record, but it reaches whoever holds the
      // future; `log` is where the fact survives when nobody is holding it.
      //
      // Same three fields the feature park records, for the same reason: the
      // item id, the product it belongs to, and the state it is sitting in.
      // `productState` is what an operator re-checks the gate against, so
      // `PRODUCT_NOT_GOVERNED` can be resolved without re-running the trigger.
      //
      // No credential material and no product-specific literal: every value is
      // read from the item or the registry row this call already had to read.
      log?.call('work_entry.gated', {
        'workItemId': item.workItemId,
        'productId': item.productId,
        'state': item.state.wire,
        'productState': gate.stateWire,
        'skipCode': gateCode,
      });
      return WorkEntrySkipped(
        gateCode,
        gate.reasonFor('No triage job was enqueued'),
      );
    }

    // --- 4. WALK TO AN ENTRY STATE -----------------------------------------
    if (_planningEvidenceOf(item) == null) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.noPlanningEvidence,
        'work item ${item.workItemId} carries neither featureRef nor '
        'requirementRef, so the workflow graph itself refuses '
        'planning -> planned. Nothing was written and nothing was forced; '
        'a human or the intake that opened it must supply the reference.',
      );
    }

    final ready = await _walkToDesignNotRequired(item);

    if (!triageDefectDefinition.entryStates.contains(ready.state)) {
      // Someone else owns this item's lifecycle — a human moved it, or an
      // earlier revision parked it somewhere the graph does not route from
      // here. `RunnableWorkEvaluator` would classify it `noAction`, so a job
      // enqueued now would sit `queued` for ever: precisely the 18-job orphan
      // class this work item exists to close. Report it and enqueue nothing.
      return WorkEntrySkipped(
        WorkEntrySkipCodes.notTriagableState,
        'work item ${ready.workItemId} is ${ready.state.wire}, which is not an '
        'entry state of triageDefectDefinition '
        '(${triageDefectDefinition.entryStates.map((s) => s.wire).join(', ')}). '
        'Nothing was enqueued: a job here could never be dispatched. The '
        'item stays where it is until a human moves it.',
      );
    }

    // --- 5. ENQUEUE ---------------------------------------------------------
    // The key and the instruction are the canonical builders, imported. Never
    // re-spelled: the format is persisted on every historical job, and the
    // already-written `defect-{id}:triage_defect` keys are what the sweep
    // matches on. Re-spelling it would orphan every job already on disk.
    final result = await _queue.enqueueIfAbsent(
      workItemId: ready.workItemId,
      definition: triageDefectDefinition,
      dedupeKey: triageDefectDedupeKey(ready, triageDefectDefinition),
      instruction: triageDefectInstruction(ready, triageDefectDefinition),
    );
    if (result.created) {
      log?.call('work_entry.enqueued', {
        'workItemId': ready.workItemId,
        'jobId': result.job.jobId,
        'dedupeKey': result.job.dedupeKey,
      });
      return WorkEntryEnqueued(result.job.jobId);
    }

    // A concurrent caller won this key inside the store transaction. Resolved
    // to the winner, never to a duplicate — the second caller names WHICH job
    // won, because "I did nothing" and "I did nothing because jb-… already
    // exists" are different operator questions.
    //
    // A job that has already FINISHED holds the key just as firmly, and it
    // means the opposite thing: nothing is in flight, and nothing will be. So
    // it is reported under its own code rather than dressed up as a race.
    final existing = result.job;
    if (existing.isTerminal) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.dedupeKeyAlreadyConsumed,
        'job ${existing.jobId} already holds dedupe key '
        '${existing.dedupeKey} and is ${existing.state.wire}, so no new job '
        'can be created for this work item. Nothing was enqueued and '
        'nothing failed; re-triaging this work item would require a new '
        'dedupe key format, which would orphan every job already persisted '
        'under the current one, so this trigger does not invent one.',
      );
    }
    return WorkEntrySkipped(
      WorkEntrySkipCodes.triageAlreadyActive,
      'a concurrent caller won this dedupe key; job ${existing.jobId} is '
      'the one that exists.',
    );
  }

  /// Walks a feature to `planned` and records, on the item, why it stops there.
  ///
  /// ## The park is visible, and it is honest about being temporary
  ///
  /// Two independent facts block a feature, and they are recorded separately
  /// because an operator needs to tell them apart:
  ///
  /// * `EXTERNAL_WORK_ENTRY_CONSUMER_DEPENDENCY` — even on a governed product,
  ///   nothing would read a feature triage result. This one does not resolve
  ///   by waiting; it resolves when the runtime is built.
  /// * `PRODUCT_NOT_GOVERNED` — this one does resolve by waiting, and the
  ///   product will reach `governed`.
  ///
  /// Reporting only the first would read as "waiting for a human"; reporting
  /// only the second would read as "waiting for the platform", which is false
  /// for the dependency. Both go on the item, plus a prose sentence
  /// ([workEntryParkedReasonKey]) so the answer to "why is my request sitting
  /// here?" does not require reading this file.
  ///
  /// ## Why `planned` and not one hop further
  ///
  /// `planned -> designNotRequired` needs no design artifact — only
  /// `actorAllowed([orchestrator])` — which is exactly why walking it would be
  /// the tempting, dishonest move. `designNotRequired` is an ENTRY STATE of
  /// `triageDefectDefinition` and the scheduler is category-blind, so a feature
  /// parked there would be picked up and triaged as a defect. `planned` is the
  /// last state on this path that dispatch cannot see.
  Future<WorkEntryDecision> _parkFeature(
    WorkItem item, {
    required _ProductGate gate,
  }) async {
    if (_planningEvidenceOf(item) == null) {
      return WorkEntrySkipped(
        WorkEntrySkipCodes.noPlanningEvidence,
        'work item ${item.workItemId} carries neither featureRef nor '
        'requirementRef, so the workflow graph itself refuses '
        'planning -> planned. The request is NOT refused and NOT failed; '
        'it stays at ${item.state.wire} until the reference is supplied.',
      );
    }

    final parked = await _walkToPlanned(item);
    await _annotateParked(parked, gate: gate);

    // The gate that is closed RIGHT NOW, named. Same three-way choice the
    // defect route makes, for the same reason: folding "absent" into "not
    // governed" would tell an operator to wait for a product that does not
    // exist.
    final closedGate = gate.allowsDispatch
        ? null
        : gate.absent
        ? WorkEntrySkipCodes.productNotInRegistry
        : WorkEntrySkipCodes.productNotGoverned;

    log?.call('work_entry.feature_parked', {
      'workItemId': parked.workItemId,
      'productId': parked.productId,
      'state': parked.state.wire,
      'productState': gate.stateWire,
      'blockedBy': externalWorkEntryConsumerDependency,
      if (closedGate != null) 'dispatchGate': closedGate,
    });

    return WorkEntrySkipped(
      closedGate ?? WorkEntrySkipCodes.noConsumerForWorkEntryKind,
      closedGate == null
          ? 'No triage job was enqueued. No consumer runtime exists for a '
                'feature work item; recorded as '
                '$externalWorkEntryConsumerDependency. The request is accepted '
                'and parked at ${parked.state.wire} — not refused, not failed. '
                '`$workEntryConsumerUnavailable` means the runtime does not '
                'exist in this platform, not that a human refused.'
          : 'No triage job was enqueued, for two independent reasons and both '
                'are recorded on the work item. First: '
                '${gate.reasonFor('Dispatch is not permitted')}. Second: no '
                'consumer runtime exists for a feature work item, recorded as '
                '$externalWorkEntryConsumerDependency. The request is accepted '
                'and parked at ${parked.state.wire} — not refused, not failed. '
                '`$workEntryConsumerUnavailable` means the runtime does not '
                'exist in this platform, not that a human refused.',
    );
  }

  /// Walks a defect's work item to an entry state of
  /// [triageDefectDefinition], resuming from wherever a prior partial run left
  /// it.
  ///
  /// Never restarts: each hop is guarded by the item's current state, so a
  /// crash between two hops leaves the next call resuming rather than
  /// re-running, and a crash *inside* a hop replays to the accepted outcome
  /// under its fixed idempotency key.
  Future<WorkItem> _walkToDesignNotRequired(WorkItem item) async {
    var current = await _walkToPlanned(item);
    if (current.state == WorkItemState.planned) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: _orchestrator,
        context: _walkContext(current),
        idempotencyKey: _designNotRequiredKey,
      );
    }
    return current;
  }

  /// `draft -> planning -> planned`, stopping there.
  Future<WorkItem> _walkToPlanned(WorkItem item) async {
    var current = item;
    if (current.state == WorkItemState.draft) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _orchestrator,
        context: _walkContext(current),
        idempotencyKey: _planningKey,
      );
    }
    if (current.state == WorkItemState.planning) {
      current = await workflowEngine.transition(
        workItemId: current.workItemId,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _orchestrator,
        context: _walkContext(current),
        idempotencyKey: _plannedKey,
      );
    }
    return current;
  }

  /// Records the park on the work item, idempotently.
  ///
  /// A replay is a READ, not a byte-identical write: the compare below is
  /// against the values wanted, so a sweep that runs every thirty seconds does
  /// not churn a version number on an item nobody is looking at.
  ///
  /// Re-reads on a compare-and-swap conflict, so two callers parking the same
  /// feature converge on ONE recorded outcome. A conflict here is not an
  /// incident — it is two writers agreeing — so it is retried and only
  /// reported if it persists across [_annotationAttempts].
  Future<void> _annotateParked(
    WorkItem item, {
    required _ProductGate gate,
  }) async {
    final wanted = <String, dynamic>{
      ...workEntryExternalDependencyMetadata(),
      workEntryProductStateKey: gate.stateWire,
      workEntryParkedReasonKey: gate.parkedReasonFor(item.workItemId),
      // Named explicitly in BOTH arms rather than conditionally. A merge that
      // merely stops writing the key would leave the previous pass's
      // `PRODUCT_NOT_GOVERNED` on the row for ever, which would tell an
      // operator the gate is still closed after it opened. A gate that lifted
      // but still reads closed is worse than one that never opened.
      workEntryDispatchGateKey: gate.allowsDispatch
          ? null
          : gate.absent
          ? WorkEntrySkipCodes.productNotInRegistry
          : WorkEntrySkipCodes.productNotGoverned,
    };

    for (var attempt = 0; attempt < _annotationAttempts; attempt++) {
      final current = await workflowStore.readWorkItem(item.workItemId);
      if (_recordedAs(current, wanted)) return;
      try {
        await workflowStore.saveWorkItem(
          current.copyWith(
            metadata: <String, dynamic>{...?current.metadata, ...wanted},
          ),
          expectedVersion: current.version,
        );
        return;
      } on ConcurrentModificationException {
        // Someone moved the item under us. Re-read and re-evaluate rather than
        // force: the graph is the authority, and this write is a note on top of
        // it, not a state change.
        continue;
      }
    }
    log?.call('work_entry.annotation_contended', {
      'workItemId': item.workItemId,
      'attempts': _annotationAttempts,
      'action':
          'the park is recorded on the work item by state; this note will be '
          're-attempted on the next pass',
    });
  }

  /// Whether every key in [wanted] already carries the wanted value.
  static bool _recordedAs(WorkItem item, Map<String, dynamic> wanted) {
    final metadata = item.metadata;
    if (metadata == null) return false;
    return wanted.entries.every((entry) => metadata[entry.key] == entry.value);
  }

  /// The transition context the graph needs, built only from values the item
  /// already carries.
  ///
  /// The `planning -> planned` guard accepts `featureRef` OR `requirementRef`;
  /// neither is invented, because a fabricated requirement reference satisfies
  /// the guard and satisfies nothing else.
  static Map<String, dynamic> _walkContext(WorkItem item) => <String, dynamic>{
    if (item.featureRef != null) 'featureRef': item.featureRef,
    if (item.requirementRef != null) 'requirementRef': item.requirementRef,
    'workEntry': true,
  };

  /// The evidence the walk's guard needs, or null when the item has none.
  static String? _planningEvidenceOf(WorkItem item) =>
      item.featureRef ?? item.requirementRef;

  /// Reads the product's dispatch state once, for both routes.
  ///
  /// A missing registry row is NOT treated as "ungoverned". It is reported
  /// under its own code because it is a different fact with a different
  /// consequence, and because inventing a lifecycle for a product id that has
  /// no row would be inventing a product.
  ///
  /// ## The `defects` bucket is the case this sentence exists for
  ///
  /// `defectTriageBucketProductId` (`lane_a_defect_triage_work_item.dart`) is a
  /// synthetic triage bucket, not a product, and it has no registry row — so
  /// every defect filed under it reads as
  /// [WorkEntrySkipCodes.productNotInRegistry] here and is never dispatched.
  /// That is the *correct* output of this method and it is deliberately not
  /// special-cased: a bucket that reached `governed` would be claiming a
  /// baseline it does not have.
  ///
  /// The open question — exempt the bucket, or give it a lifecycle — was
  /// escalated rather than answered here, and human decision `b366bba0`
  /// (`decisions/b366bba0-bd53-4090-932e-39e231819777.yaml`) chose
  /// **OPTION_B: give the bucket a lifecycle**. A carve-out was rejected
  /// because it would leave a whole class of defect permanently outside
  /// governance, which is the property this work item exists to eliminate.
  ///
  /// So this method changes nothing for the bucket: it keeps reporting the
  /// honest fact, and the decision that gives the bucket a row — with a human
  /// approving its baseline, as any other product's must — is what will make
  /// these defects dispatch. A reader who finds `PRODUCT_NOT_IN_REGISTRY` on a
  /// bucket-filed defect is seeing the gate work, not a defect in it.
  Future<_ProductGate> _readProductGate(String productId) async {
    try {
      final product = await productRegistryEngine.readProduct(productId);
      return _ProductGate.resolved(productId, product.state.canonical);
    } on ProductNotFoundException {
      return _ProductGate.unresolved(productId);
    }
  }

  /// Scoped to the WORK ITEM, not to one dedupe key — the onboarding lane's
  /// lesson applied.
  ///
  /// Filtered by [JobType.triageDefect] so a future job type written under the
  /// same work item id does not silently block triage for ever, and
  /// non-terminal only, so a job that finished and is retried on a NEW key is
  /// not mistaken for one in flight.
  Future<Job?> _activeTriageJob(String workItemId) async {
    Job? active;
    for (final job in await jobStore.listJobsForWorkItem(workItemId)) {
      if (job.jobType != JobType.triageDefect) continue;
      if (job.isTerminal) continue;
      if (active == null || !job.createdAt.isBefore(active.createdAt)) {
        active = job;
      }
    }
    return active;
  }
}

/// What the product gate found, resolved once and read by both routes.
final class _ProductGate {
  const _ProductGate.resolved(this.productId, this.state) : absent = false;

  /// A product id with no registry row. The lifecycle is unknown, not
  /// ungoverned, and the two are reported separately.
  const _ProductGate.unresolved(this.productId) : state = null, absent = true;

  final String productId;

  /// The canonical state, or null when the registry has no row.
  final ProductState? state;

  final bool absent;

  /// `canonical` because a row persisted as the parse-only legacy `draft` must
  /// be read as what it means. `ProductState.governed` is the only state that
  /// allows dispatch — `paused` and `archived` deliberately do not.
  bool get allowsDispatch => state == ProductState.governed;

  String get stateWire => state?.wire ?? 'absent';

  String reasonFor(String consequence) {
    if (absent) {
      return '$consequence. The product id `$productId` has no registry row, '
          'so whether work may be dispatched for it cannot be established from '
          'ProductState at all. This is recorded, not invented: the trigger '
          'does not manufacture a lifecycle for a product that does not '
          'exist, and it does not assume the item is dispatchable because '
          'nobody could check.';
    }
    return '$consequence. Product `$productId` is $stateWire, not governed, '
        'so ProductState forbids dispatching work for it. The request is NOT '
        'rejected and the job is NOT failed: the next pass dispatches it when '
        'the product becomes governed.';
  }

  /// The operator-facing sentence recorded on a parked feature.
  String parkedReasonFor(String workItemId) {
    final gate = absent
        ? 'Product `$productId` has no registry row, so the dispatch gate '
              'cannot be evaluated ($WorkEntrySkipCodes.productNotInRegistry).'
        : 'Product `$productId` is $stateWire, not governed, so '
              'ProductState forbids dispatching work for it '
              '($WorkEntrySkipCodes.productNotGoverned).';
    return 'This request was accepted and is parked at planned, not refused '
        'and not failed. No triage job is enqueued because '
        '$externalWorkEntryConsumerDependency: no consumer runtime exists in '
        'this platform that would read a feature work item\'s triage result '
        '(the recorded value is `$workEntryConsumerUnavailable`, which means '
        'the runtime does not exist here — it does NOT mean a human declined '
        'to run it). $gate Work item `$workItemId`.';
  }
}

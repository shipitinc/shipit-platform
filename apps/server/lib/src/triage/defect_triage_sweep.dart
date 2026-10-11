import 'package:platform_contracts/platform_contracts.dart'
    show Defect, DefectStatus, WorkItem;
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:workflow_store/workflow_store.dart'
    show WorkItemNotFoundException;

import 'work_entry.dart'
    show
        WorkEntryDecision,
        WorkEntryEnqueued,
        WorkEntryKind,
        WorkEntrySkipped,
        WorkEntrySkipCodes,
        WorkEntryTrigger;

/// The code carried by a dropped tick.
///
/// Declared rather than inlined so the log line, the result value and the test
/// cannot disagree about its spelling.
const String sweepPassOverlappedCode = 'SWEEP_PASS_OVERLAPPED';

/// One defect the sweep decided about.
sealed class DefectTriageSweepDecision {
  const DefectTriageSweepDecision({required this.defectId});

  final String defectId;
}

/// A triage job exists for this defect's work item.
final class DefectTriageSweepEnqueued extends DefectTriageSweepDecision {
  const DefectTriageSweepEnqueued({
    required super.defectId,
    required this.workItemId,
    required this.jobId,
  });

  final String workItemId;
  final String jobId;

  @override
  String toString() => 'enqueued $jobId for $defectId ($workItemId)';
}

/// The sweep looked at this defect and deliberately did nothing.
///
/// Each reason is named and carries the defect id, because "the sweep ran" and
/// "the sweep ran and found nothing to do for THIS defect" must be
/// distinguishable in a log — the difference between those two is exactly what
/// this work item keeps finding.
final class DefectTriageSweepSkipped extends DefectTriageSweepDecision {
  const DefectTriageSweepSkipped({
    required super.defectId,
    required this.code,
    required this.reason,
  });

  /// Stable and greppable. Every value is a [WorkEntrySkipCodes] constant — the
  /// trigger's own codes, plus the one the sweep itself produces because it is
  /// the only caller that can observe a MISSING work item.
  final String code;

  final String reason;

  @override
  String toString() => 'skipped $defectId ($code): $reason';
}

/// A defect the sweep could not decide about.
///
/// Deliberately not a [DefectTriageSweepSkipped]. "Looked and deliberately did
/// nothing" and "threw before deciding" are different facts, and folding them
/// together is how one defect's failure becomes invisible behind a count of
/// quiet skips — the failure class this work item exists to close, one level up.
final class DefectTriageSweepIncident {
  const DefectTriageSweepIncident({
    required this.defectId,
    required this.code,
    required this.reason,
  });

  final String defectId;
  final String code;
  final String reason;

  @override
  String toString() => 'incident $defectId ($code): $reason';
}

/// Incident codes a sweep pass records when one defect's evaluation threw.
abstract final class DefectTriageSweepIncidentCodes {
  /// Anything the per-defect evaluation raised.
  ///
  /// Recorded, logged and stepped over. A work-item read that failed for one
  /// defect says nothing about the next one, and a pass that aborted on it would
  /// leave every defect after it un-enqueued with nothing on the record to
  /// explain why — a failure that silently deletes the rest of the work, which
  /// is structurally the silent no-op this work item was opened to end.
  static const String evaluationFailed = 'SWEEP_DEFECT_EVALUATION_FAILED';
}

/// What one sweep pass did.
class DefectTriageSweepResult {
  const DefectTriageSweepResult({
    required this.considered,
    required this.enqueued,
    required this.skipped,
    this.incidents = const [],
    this.overlappedPasses = 0,
  });

  /// Defects whose status was in scope.
  final int considered;

  final List<DefectTriageSweepEnqueued> enqueued;
  final List<DefectTriageSweepSkipped> skipped;

  /// Defects whose evaluation **threw**.
  final List<DefectTriageSweepIncident> incidents;

  /// Ticks that arrived while a pass was already running, and were therefore
  /// NOT run.
  ///
  /// Always present in the log line rather than only when non-zero. A dropped
  /// tick and a pass that found nothing to do both produce
  /// `considered: 0, enqueued: 0, skipped: 0, incidents: 0` — the exact shape
  /// of "the sweep is not running", which this work item exists to stop being
  /// indistinguishable from anything else. Reporting the count is what tells
  /// the two apart, so it is reported even when it is zero.
  ///
  /// A count and not a decision list: a dropped tick has no DEFECT, exactly as
  /// the baseline lane's dropped tick has no PRODUCT. It is neither an enqueue,
  /// a skip nor an incident, because none of those is a claim about a defect —
  /// filing it under any of them would invent one.
  final int overlappedPasses;

  /// [considered] accounted for: everything the pass decided, plus everything
  /// it failed to decide.
  int get accountedFor => enqueued.length + skipped.length + incidents.length;

  @override
  String toString() =>
      'DefectTriageSweepResult(considered: $considered, enqueued: '
      '${enqueued.length}, skipped: ${skipped.length}, incidents: '
      '${incidents.length}, overlappedPasses: $overlappedPasses)';
}

/// Enqueues triage for defects whose intake-time enqueue did not happen.
///
/// ## Why a sweep, and what it recovers FROM
///
/// `createDefect` already enqueues at intake. That path has no recovery: it
/// performs several durable writes before the enqueue, any of them can throw,
/// and nothing ever retries. A defect reported against a product that is not
/// `governed` is accepted, gated, and left where it is with no job and no
/// retry — correct, and permanently stuck. This sweep is what makes the gate
/// temporary instead of final: it notices when the product becomes governed.
///
/// ## WHY THIS SWEEP CANNOT LIVELOCK AGAINST ITSELF
///
/// `BaselineOnboardingSweep` livelocked in production: 41 passes, 22 incidents,
/// 19 skips, zero enqueued, and a credential whose `version` climbed from 1 to
/// 59 while the product state never moved. Nearly every failure was a
/// `ConcurrentModificationException` raised out of the acquisition — a pass
/// conflicting with the pass before it, over a row the pass had written itself.
///
/// The cause is structural, and it is named exactly so it cannot be
/// reintroduced by accident: that sweep had to resolve a PINNED REVISION, and
/// resolving one costs a real SSH clone whose `CredentialKeyService
/// .verifyAccess` WRITES the credential row twice. Every pass therefore bumped
/// the version the next pass's compare-and-swap asserted, so the sweep
/// guaranteed its own conflict on every pass and never reached the enqueue.
///
/// **THIS SWEEP HAS NO ACQUISITION.** It reads defect rows, work items and
/// product rows. Its only write is a conditional enqueue, whose idempotency is
/// the store's own dedupe constraint rather than a read that mutates the thing
/// it reads. It cannot invalidate its own precondition, so it cannot livelock.
///
/// The prohibition is on the SHAPE, not on the current lines: no clone, no
/// credential read that writes, no network-bound call, no source resolution, no
/// environment lookup. `defect_triage_sweep_test.dart` guards that structurally
/// rather than by convention — the sweep is constructed with a defect store and
/// a trigger, and the test counts credential reads at the only object through
/// which they could ever happen.
///
/// ## THE PREDICATE, AND EVERY CONJUNCT
///
/// ```text
///   enqueue triage  ⟺  defect.status ∈ triagableStatuses
///                   ∧  no non-terminal triageDefect job for defect-{defectId}
///                   ∧  the defect's product is `governed`
/// ```
///
/// The first conjunct is evaluated HERE, from the defect's own status — the
/// sweep's only contribution to the predicate, and it is a status set rather
/// than a product id, so it stays product-agnostic. The other two belong to
/// [WorkEntryTrigger] and are evaluated there, for one reason: they are already
/// evaluated on the intake path against the same durable rows, and a second
/// implementation in this file could disagree with the first. One predicate, one
/// implementation, two triggers.
///
/// The governance gate is not a limitation of this sweep; it is the design. A
/// defect on an ungoverned product is NOT refused and NOT failed — it waits, and
/// this file is what it waits for.
class DefectTriageSweep {
  DefectTriageSweep({
    required this.defectStore,
    required this.trigger,
    this.log,
  });

  final DefectStore defectStore;
  final WorkEntryTrigger trigger;

  /// Optional observer. Every decision this sweep takes is logged, including the
  /// ones where it deliberately did nothing — a sweep that is silent when it
  /// finds nothing is indistinguishable from a sweep that is not running.
  final void Function(String event, Map<String, dynamic> data)? log;

  /// The defect statuses this sweep acts in.
  ///
  /// Product-agnostic by construction: statuses, never product names or ids.
  /// Everything outside this set describes a defect whose triage is already
  /// decided — `confirmed`, `fix_in_progress`, `resolved` and the rest — and
  /// re-enqueueing one would be arguing with a decision that was made.
  static const Set<DefectStatus> triagableStatuses = {
    DefectStatus.reported,
    DefectStatus.triaging,
    DefectStatus.needsClarification,
  };

  /// Whether a pass is running right now.
  ///
  /// Taken and released by [run] in the CALLER's turn, which is why [run] is
  /// not `async` — but the honest reason is not the one
  /// `BaselineOnboardingSweep` gives, and repeating that reason here would put
  /// a false claim into a second file.
  ///
  /// It claims that an `async` body "does not begin executing until it is
  /// scheduled", so that two callers could both read `false`. That is not how
  /// Dart works: an `async` function's body starts SYNCHRONOUSLY, in the
  /// caller's turn, up to its first `await`. Verified directly — with an
  /// `async` guard, two back-to-back calls in one turn yield one pass and one
  /// skip, exactly as the non-`async` form does.
  ///
  /// What the non-`async` signature actually buys is a COMPILE-TIME guarantee
  /// rather than a behavioural one: an `await` is illegal in a non-`async`
  /// function, so nothing can ever be inserted above the guard that would defer
  /// it. In an `async` body that insertion compiles, reads correctly in
  /// isolation, and silently converts a sound guard into an unsound one. The
  /// signature makes "the guard is taken before anything is awaited" a property
  /// the compiler enforces instead of a property a reviewer has to notice.
  ///
  /// `Timer.periodic` does not await its callback, so "two overlapping
  /// callers" is the ordinary case here, not a race that has to be arranged.
  bool _running = false;

  /// Runs one pass, or records that one is already running.
  ///
  /// ## Why a pass may not overlap another
  ///
  /// The server drives this from `Timer.periodic`, which does **not** await its
  /// callback: the next tick starts whether or not the previous pass has
  /// finished. So the second tick does not run, and says so.
  ///
  /// Dropping it silently would be indistinguishable from a tick that found
  /// nothing to do, and a pass that dropped ticks without saying so is the
  /// defect class this work item exists to close.
  Future<DefectTriageSweepResult> run() {
    if (_running) {
      const dropped = DefectTriageSweepResult(
        considered: 0,
        enqueued: [],
        skipped: [],
        incidents: [],
        overlappedPasses: 1,
      );
      // A dedicated event, IN ADDITION TO the `completed` line.
      //
      // The `completed` line is there so every pass leaves the same shape — one
      // line, `overlappedPasses` always present, including zero. This one is
      // there so the drop is greppable on its OWN: an operator asking "is this
      // sweep wedged?" should not have to know that the answer lives in a field
      // of a line which otherwise describes a pass that did real work.
      log?.call('work_entry.sweep.pass_overlapped', {
        'considered': 0,
        'enqueued': 0,
        'skipped': 0,
        'incidents': 0,
        'overlappedPasses': 1,
        'code': sweepPassOverlappedCode,
        'action':
            'this tick did not run because a pass was already in flight; no '
            'defect was evaluated and nothing was enqueued. The pass already '
            'running will report its own decisions.',
      });
      log?.call('work_entry.sweep.completed', {
        'considered': 0,
        'enqueued': 0,
        'skipped': 0,
        'incidents': 0,
        'overlappedPasses': 1,
        'code': sweepPassOverlappedCode,
      });
      return Future<DefectTriageSweepResult>.value(dropped);
    }
    _running = true;
    // `whenComplete` releases the guard on the success path AND on the failure
    // path, and passes the original error through untouched. A guard released
    // only on success would wedge the sweep shut after the first
    // `listDefects` failure, and every later tick would report itself as
    // "overlapping" against a pass that ended minutes ago — a sweep that looks
    // busy and is permanently stopped.
    return _runPass().whenComplete(() {
      _running = false;
    });
  }

  /// One actual pass. Reached only through [run], which holds the guard.
  ///
  /// Idempotent: a second pass over unchanged state enqueues nothing, because
  /// the trigger finds the job the first pass created and reports it under
  /// [WorkEntrySkipCodes.triageAlreadyActive].
  ///
  /// ## PER-DEFECT ISOLATION
  ///
  /// One defect's evaluation throwing does not abort the pass. Without the guard
  /// below, a single defect whose work item read failed would abandon every
  /// defect after it in the list — none enqueued, nothing logged about them, and
  /// the next pass to hit the same failure abandoning the same set again. A
  /// failure that silently deletes the rest of the work is the same defect class
  /// as the silent no-op this work item was opened to end, so the failing defect
  /// is recorded as an incident, the pass continues, and the count reconciles.
  Future<DefectTriageSweepResult> _runPass() async {
    final enqueued = <DefectTriageSweepEnqueued>[];
    final skipped = <DefectTriageSweepSkipped>[];
    final incidents = <DefectTriageSweepIncident>[];
    var considered = 0;

    for (final defect in await defectStore.listDefects()) {
      if (!triagableStatuses.contains(defect.status)) continue;
      considered++;
      final DefectTriageSweepDecision decision;
      try {
        decision = await _consider(defect);
      } on Object catch (error, stackTrace) {
        incidents.add(_incident(defect, error, stackTrace));
        continue;
      }
      switch (decision) {
        case DefectTriageSweepEnqueued():
          enqueued.add(decision);
        case DefectTriageSweepSkipped():
          skipped.add(decision);
      }
    }

    log?.call('work_entry.sweep.completed', {
      'considered': considered,
      'enqueued': enqueued.length,
      'skipped': skipped.length,
      'incidents': incidents.length,
      'overlappedPasses': 0,
    });
    return DefectTriageSweepResult(
      considered: considered,
      enqueued: List.unmodifiable(enqueued),
      skipped: List.unmodifiable(skipped),
      incidents: List.unmodifiable(incidents),
    );
  }

  /// What the sweep decides about one defect.
  ///
  /// Everything here is a READ until [WorkEntryTrigger.ensureWorkEntry] is
  /// called, and that call's only write is the trigger's own conditional
  /// enqueue. Nothing in this method acquires, clones, resolves a source or
  /// touches a credential — see the class doc for why that is the load-bearing
  /// property and not a detail.
  Future<DefectTriageSweepDecision> _consider(Defect defect) async {
    final workItemId = WorkEntryTrigger.triageWorkItemIdForDefect(
      defect.defectId,
    );

    final WorkItem item;
    try {
      item = await trigger.workflowStore.readWorkItem(workItemId);
    } on WorkItemNotFoundException {
      log?.call('work_entry.sweep.work_item_missing', {
        'defectId': defect.defectId,
        'workItemId': workItemId,
        'code': WorkEntrySkipCodes.workItemMissing,
        'action':
            'nothing was created. DefectTriageWorkItemProvisioner owns the '
            'construction of this work item and must run for this defect; the '
            'sweep does not synthesise one, because every field it would have '
            'to invent would then read as a fact on the record.',
      });
      return DefectTriageSweepSkipped(
        defectId: defect.defectId,
        code: WorkEntrySkipCodes.workItemMissing,
        reason:
            'no work item at $workItemId, so there is nothing to enqueue triage '
            'for. DefectTriageWorkItemProvisioner owns the construction of that '
            'item and must run for defect ${defect.defectId}; this is NOT '
            'repaired here by guessing at a product, a category or a reference.',
      );
    }

    // The remaining two conjuncts of the predicate — "no non-terminal
    // triageDefect job" and "the product is governed" — are decided by the
    // trigger, in that order, against the same durable rows the intake path
    // reads. Re-implementing either here is how two gates start disagreeing.
    final decision = await trigger.ensureWorkEntry(
      item: item,
      kind: WorkEntryKind.defectTriage,
    );
    return _attach(defect.defectId, workItemId, decision);
  }

  /// Attaches the sweep's own facts — which defect, which work item — to the
  /// trigger's decision.
  ///
  /// The trigger cannot supply either: it is handed the item and knows nothing
  /// about the defect that owns it. Merging them here is what makes an
  /// operator-facing line answer "which defect?" and not merely "which code?".
  static DefectTriageSweepDecision _attach(
    String defectId,
    String workItemId,
    WorkEntryDecision decision,
  ) {
    switch (decision) {
      case WorkEntryEnqueued(:final jobId):
        return DefectTriageSweepEnqueued(
          defectId: defectId,
          workItemId: workItemId,
          jobId: jobId,
        );
      case WorkEntrySkipped(:final skipCode, :final skipReason):
        return DefectTriageSweepSkipped(
          defectId: defectId,
          code: skipCode,
          reason: skipReason,
        );
    }
  }

  /// Records a defect the pass failed to decide about, and says so loudly.
  ///
  /// The log line is the point: the return value is a summary a caller may not
  /// print, and a summary that says "1 incident" without saying which defect or
  /// why is the quiet outcome this guard exists to prevent. Carries the defect
  /// id, the error, the stack and the action, so the line answers "what
  /// happened, to what, and what was done about it" without a second lookup.
  ///
  /// Never carries credential material or a credential reference name, because
  /// nothing on this path can reach one — and that is asserted, not assumed:
  /// see the class doc.
  DefectTriageSweepIncident _incident(
    Defect defect,
    Object error,
    StackTrace stackTrace,
  ) {
    final code = DefectTriageSweepIncidentCodes.evaluationFailed;
    log?.call('work_entry.sweep.defect_incident', {
      'defectId': defect.defectId,
      'status': defect.status.wire,
      'code': code,
      'error': error.toString(),
      'stack': stackTrace.toString(),
      'action': 'this defect is untouched; the rest of the pass continued',
    });
    return DefectTriageSweepIncident(
      defectId: defect.defectId,
      code: code,
      reason: error.toString(),
    );
  }
}

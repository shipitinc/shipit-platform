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

// ---------------------------------------------------------------------------
// THE GATE
//
// This sweep is BUILT and WIRING-COMPOSED, but it is not enabled on the live
// tick. Design-revision.md §15 states the gate verbatim:
//
//   "do not enable the sweep on the live tick until P-2 and P-5 pass — the
//    sweep is the first thing that will touch the 18 orphans."
//
// P-2 and P-5 are INTEGRATION-layer cases owned by lane L4, and the evidence
// that would lift this gate does not exist in this repository yet. The unit
// suite proves single-enqueue against an in-memory job store; it cannot prove
// the PostgreSQL `enqueueIfAbsent` path and its `DuplicateActiveJobException`
// resolution, which design §8 names as the THIRD idempotency layer and which
// is the mechanism that actually prevents duplicate dispatch in production.
//
// So the default is OFF, and it is OFF because the evidence is missing — not
// because the sweep is unfinished. The operator turns it on; the code never
// does.
// ---------------------------------------------------------------------------

/// Whether the sweep runs on the live tick, and — always — why.
///
/// Both facts travel together. A gate that can report "on" without saying what
/// would turn it off is the silent-no-op shape this work item exists to end,
/// one level up: an operator who cannot tell OFF from WEDGED learns about it
/// from a defect nobody triaged.
final class WorkEntrySweepGate {
  const WorkEntrySweepGate.enabled({this.variableName})
    : _enabled = true,
      _reason = null,
      rejectedValue = null;

  const WorkEntrySweepGate.disabled({
    String? reason,
    this.variableName,
    this.rejectedValue,
  }) : _enabled = false,
       _reason = reason ?? workEntrySweepGateReason;

  final bool _enabled;

  /// Why the sweep is off. Never null when [enabled] is false.
  final String? _reason;

  /// The value the environment carried, when it was present but NOT one of the
  /// recognised enablement spellings.
  ///
  /// Reported rather than swallowed, and public so the composition root and the
  /// operator-facing rendering cannot each hold their own copy: a typo that
  /// silently means OFF is an operational surprise even though it is the safe
  /// direction to fail in, and the operator can only act on it if they are told
  /// what they actually typed.
  final String? rejectedValue;

  /// The variable an operator sets to turn this on, when the caller named it.
  ///
  /// Supplied by the composition root rather than hard-coded here so this file
  /// stays free of environment lookups — its product-agnosticism gate forbids
  /// them, and that gate is correct.
  final String? variableName;

  bool get enabled => _enabled;

  String get reason => _reason ?? '';

  /// The `enableWith` spelling an operator can copy.
  String get enableWith => variableName == null
      ? 'the composition root\'s enablement variable'
      : '$variableName=<one of $workEntrySweepEnablementValues>';

  /// What has to be true before this gate is lifted. Named, so "we will turn it
  /// on soon" is not a plan — it is two test cases and a command.
  static const String liftingRequires = workEntrySweepGateEvidence;

  /// The operator-facing rendering, for the startup log and the composition
  /// line. Both are printed on EVERY start, in both states: the enabled case is
  /// one field, and the disabled case is a state an operator must never have to
  /// infer from the absence of something.
  Map<String, dynamic> describe() => <String, dynamic>{
    'enabled': _enabled,
    'enableWith': enableWith,
    if (_reason != null) 'reason': _oneLine(_reason),
    // Sanitised HERE rather than at construction, because this constructor is
    // public and a caller that supplies a raw value directly would otherwise
    // put a newline into a one-line log. The value is operator input; a log
    // line is a security boundary, not a string builder. `reason` is sanitised
    // for the same reason: it is equally caller-supplied, and an earlier
    // revision sanitised `rejectedValue` here while leaving `reason` raw —
    // which the comment above then contradicted.
    if (rejectedValue != null) 'rejectedValue': _oneLine(rejectedValue!),
    'liftingRequires': liftingRequires,
  };

  @override
  String toString() =>
      'WorkEntrySweepGate(enabled: $_enabled, reason: ${_reason ?? '-'})';
}

/// The values that turn the sweep on. Case-insensitive, whitespace-trimmed.
///
/// Deliberately NOT "any non-empty value is true": that spelling makes
/// `SOMETHING=false` read as ON, which is the one direction a feature gate must
/// never fail in by accident.
const List<String> workEntrySweepEnablementValues = ['1', 'true', 'yes', 'on'];

/// The sweep is OFF unless the environment says otherwise.
const bool workEntrySweepEnabledByDefault = false;

/// Why it is off, stated at startup in the operator's own terms.
const String workEntrySweepGateReason =
    'This sweep is composed and wired, but not enabled on the live tick. '
    'Design-revision.md section 15 gates it: P-2 and P-5 have not been proven '
    'by lane L4, and this sweep would be the first thing to touch the 18 '
    'historically orphaned triage jobs. The operator enables it; the code does '
    'not enable itself, and no absence is silent — this line is printed on '
    'every start.';

/// The evidence that lifts the gate. Two named integration cases, and the
/// command that produces them.
const String workEntrySweepGateEvidence =
    'Lane L4 integration evidence, both cases, via `make test-integration` '
    'against a real PostgreSQL job store: P-2 — a defect whose intake enqueue '
    'never ran yields EXACTLY ONE job under the existing dedupe key, through '
    'the durable `enqueueIfAbsent` transaction and its '
    'DuplicateActiveJobException resolution, not only through an in-memory '
    'store. P-5 — the 18 historically orphaned jobs are found by the sweep and '
    'are either repaired or reported under WORK_ITEM_MISSING, and are never '
    'guessed at.';

/// Resolves the gate from a RAW environment value.
///
/// Takes the value as a parameter rather than reading the environment itself,
/// for two reasons: the composition root is where environment belongs, and this
/// file's product-agnosticism gate forbids an environment lookup — a gate that
/// forbids the thing it should enforce would be worse than no gate.
///
/// [rawValue] is what the environment carried, or null when it carried
/// nothing. Fails CLOSED on anything it does not recognise, and reports the
/// value it rejected, because a typo is an operational fact even when the safe
/// direction to fail in is the one it already fails in.
WorkEntrySweepGate workEntrySweepGateFor(
  String? rawValue, {
  String? variableName,
}) {
  if (rawValue == null) {
    return WorkEntrySweepGate.disabled(variableName: variableName);
  }
  final value = rawValue.trim().toLowerCase();
  if (value.isEmpty) {
    return WorkEntrySweepGate.disabled(variableName: variableName);
  }
  if (workEntrySweepEnablementValues.contains(value)) {
    return WorkEntrySweepGate.enabled(variableName: variableName);
  }
  return WorkEntrySweepGate.disabled(
    variableName: variableName,
    rejectedValue: rawValue,
    reason:
        'The enablement value ${_quoted(rawValue)} is not one of '
        '$workEntrySweepEnablementValues. The sweep stays OFF. This fails '
        'closed deliberately: a value that is not recognised is not treated as '
        'consent to run the first thing that would touch the 18 orphaned jobs.',
  );
}

/// [value] quoted for a log line, with hostile control characters escaped.
///
/// The value comes from the environment, which is operator input, and a raw
/// newline in a one-line log is a forgeable log line: an operator who could set
/// the variable could otherwise manufacture the NEXT event on the log, in the
/// operator's own name, saying the sweep is enabled.
String _quoted(String value) => "'${_oneLine(value)}'";

/// [value] with every control character that could break a one-line log
/// replaced by its escape.
///
/// Newline and carriage return are the ones that create a second event. Tab is
/// included because it silently reflows a log that a human is reading to decide
/// whether triage ran.
String _oneLine(String value) => value
    .replaceAll('\r', r'\r')
    .replaceAll('\n', r'\n')
    .replaceAll('\t', r'\t');

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
///
/// ## THIS SWEEP IS NOT ENABLED ON THE LIVE TICK
///
/// Constructing one and calling [run] are separate decisions, and this class is
/// deliberately not currently the second one. Design-revision.md §15 gates it
/// on P-2 and P-5, which lane L4 owns and which do not yet exist. See
/// [WorkEntrySweepGate] for the gate, why it is off, what lifts it, and why the
/// absence of it is stated at startup rather than merely implied.
class DefectTriageSweep {
  DefectTriageSweep({
    required this.defectStore,
    required this.trigger,
    this.pageSize = defectPageSize,
    this.log,
  }) : assert(
         pageSize > 0,
         'pageSize must be positive. A page of zero never satisfies the '
         '"shorter than a page" end condition, so the walk would never end — '
         'this is the one value that turns a bound into a hang.',
       );

  final DefectStore defectStore;
  final WorkEntryTrigger trigger;

  /// How many defects one `listDefects` statement returns.
  ///
  /// [defectPageSize] in production. Settable so the paging walk is testable
  /// at a size that does not require a live-sized table — the property under
  /// test is "the walk reaches every page", which is better shown at pageSize 3
  /// over ten rows than at 200 over seven hundred.
  final int pageSize;

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

  /// How many defects one `listDefects` statement returns.
  ///
  /// A bound on the STATEMENT, never on the pass — see [_readDefectsInPages]
  /// for why a cap that is not walked to the end is not a cap at all.
  ///
  /// Sized for the memory of a few hundred small rows, not for throughput. The
  /// number of statements a pass costs is not the thing being optimised: the
  /// thing being avoided is an unbounded result set over a table that only
  /// grows. A pass over ten thousand defects is ten thousand decisions against
  /// durable stores, and the alternative to that is ten thousand defects never
  /// swept.
  ///
  /// A bound, never a cap: the walk continues past it. See
  /// [_readDefectsInPages].
  static const int defectPageSize = 200;

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

    for (final defect in await _readDefectsInPages()) {
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

  /// Every defect, read in BOUNDED pages.
  ///
  /// ## Why this is not one unbounded call
  ///
  /// `DefectStore.listDefects()` with no `limit` is `SELECT * FROM defect
  /// ORDER BY "updatedAt" DESC` with no bound — an unbounded result set and an
  /// unbounded in-memory list, growing for as long as the table exists, on the
  /// first tick after a deploy and on every tick after that.
  ///
  /// ## And why it is NOT a plain `limit`
  ///
  /// A `limit` without a cursor would be worse than unbounded, and much
  /// quieter. `ORDER BY "updatedAt" DESC` returns the MOST RECENTLY UPDATED
  /// rows first, so a capped read would consider the head of the table for
  /// ever and the tail would never be swept at all — a permanent silent
  /// no-op wearing the costume of a performance fix. The cap has to come with
  /// the walk, or not at all.
  ///
  /// So the pass pages until a short page ends it: every STATEMENT is bounded
  /// (one page), and the PASS is complete. Nothing starves.
  ///
  /// ## The one thing paging costs, stated rather than hidden
  ///
  /// The page walk is not a snapshot. A defect that is UPDATED between two
  /// pages moves in the ordering, and `OFFSET` paging can step over it. That
  /// is a transient miss, not a lost one: nothing is marked processed, the
  /// next pass sees it, and the operation is idempotent — so the sweep
  /// converges. It is recorded here rather than papered over with a
  /// keyset cursor, because a cursor over a mutable `updatedAt` has its own
  /// starvation (a row updated past the cursor is never revisited) and would
  /// trade a transient miss for a permanent one.
  Future<List<Defect>> _readDefectsInPages() async {
    final all = <Defect>[];
    var offset = 0;
    while (true) {
      final page = await defectStore.listDefects(
        limit: pageSize,
        offset: offset,
      );
      // The bound is LOAD-BEARING, not an optimisation, so its violation is a
      // real check rather than an `assert`.
      //
      // The end condition below is "a page shorter than the one I asked for".
      // A store that ignores `limit` makes it unreachable, and the pass then
      // spins — forever, because the loop's only await is already resolved, so
      // it never yields to the timer queue and a test timeout cannot even fire.
      // A wedged, spinning, silently-never-ending pass is the worst outcome
      // this class could have.
      //
      // Throwing instead turns that into what it should be: one visible,
      // retryable failure. The tick's own catch logs it, and `run`'s
      // `whenComplete` releases the guard, so the next tick is a real pass
      // rather than a permanent "overlapping" report.
      if (page.length > pageSize) {
        throw StateError(
          'the defect store returned ${page.length} rows for a page of '
          '$pageSize. The page bound is load-bearing: without it this walk can '
          'never end. The sweep enqueued nothing from this pass and will retry '
          'on the next tick.',
        );
      }
      all.addAll(page);
      if (page.length < pageSize) return all;
      offset += pageSize;
    }
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

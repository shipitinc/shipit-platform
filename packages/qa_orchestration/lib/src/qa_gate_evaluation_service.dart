import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';

import 'gates/declared_owned_paths_source.dart';
import 'gates/evaluators/change_scope_confinement_gate.dart';
import 'gates/source_provenance.dart';
import 'lane_g_qa_contract_store.dart';
import 'qa_orchestration.dart';

/// A fault in the evaluation itself, as opposed to a gate verdict.
///
/// ## WHY THIS IS A SEPARATE TYPE
///
/// §3.3 of the design requires that a contract which cannot be read "surfaces
/// as a fault rather than as a pass". A *failure* and a *fault* are different
/// things, and a caller that cannot tell them apart will handle them the same
/// way — which is how an infrastructure failure becomes a durable "the gates
/// failed" record.
///
/// * A **verdict** is what the gates say. It is a `QAGateResult`, it has
///   evidence, and it is persisted.
/// * A **fault** is the evaluation not happening: the contract does not
///   resolve, the store cannot be read, the record cannot be encoded. It has
///   no verdict, and it must never be recorded as one.
///
/// The drain turns a fault into `qaFailed` with a reason that says "the
/// evaluation could not be completed" — which is the same state a failing gate
/// produces and a *different* record, because the reason names the cause. The
/// distinction is preserved in the persisted record's `outcomeKind`.
class QAGateEvaluationFault implements Exception {
  QAGateEvaluationFault(this.reason, {this.cause});

  /// A human-readable statement of what could not be done.
  final String reason;

  /// The underlying error, when there was one.
  final Object? cause;

  @override
  String toString() =>
      'QAGateEvaluationFault: $reason${cause == null ? '' : ' (cause: $cause)'}';
}

/// The outcome of evaluating one work item's QA contract.
///
/// It carries the three things the workflow needs and the one thing a reader
/// needs later: the contract that was evaluated, the results, the two
/// determinations the design requires (`isOverallPass` and
/// `requiresFormalDetermination`), and the durable record.
class QAGateEvaluationOutcome {
  const QAGateEvaluationOutcome({
    required this.contract,
    required this.results,
    required this.isOverallPass,
    required this.requiresFormalDetermination,
    required this.evaluatedAt,
    this.lanePathOwnership,
  });

  /// The contract that was evaluated.
  final QAContract contract;

  /// One result per gate the contract declares, in declaration order.
  final List<QAGateResult> results;

  /// Whether the results constitute an overall pass under the contract.
  final bool isOverallPass;

  /// The required gates that are not satisfied and therefore need a formal
  /// determination rather than being left latent.
  final List<String> requiresFormalDetermination;

  /// When the evaluation ran.
  final DateTime evaluatedAt;

  /// The lane path-ownership declaration this evaluation judged, and where it
  /// came from — null when no declaration source was wired, which is the
  /// shape of a service assembled without one.
  ///
  /// ## WHY IT IS IN THE RECORD
  ///
  /// A record that says "the change-scope gate passed" but not "against which
  /// owned set" cannot be audited later: the set is the thing that decides
  /// whether a path was allowed. The record therefore carries the set the gate
  /// judged and the provenance of the reader that supplied it, so "was this
  /// produced by the platform, and against what?" has one answer at the top
  /// of the record.
  ///
  /// An EMPTY set is recorded as an empty set, not omitted: "the lane
  /// declared nothing" is a fact about the run, and the gate's refusal of it
  /// is the fail-closed direction.
  final Map<String, dynamic>? lanePathOwnership;

  /// The transition context the `qaPassed` edge's guard reads.
  ///
  /// ## BOTH KEYS, ALWAYS
  ///
  /// `_AllRequiredGatesPassedGuard` reads `context['gateResults']` and
  /// `context['qaContract']`, and fails closed when either is absent:
  /// *"Without it no required gate can be evaluated, and an empty gate set must
  /// not read as an overall pass."* A context carrying only one of the two
  /// cannot reach a vacuous pass, but it also cannot reach a real one — so
  /// this method always produces both, and a caller that builds a context by
  /// hand is on its own.
  ///
  /// The values are the LIVE objects, not their JSON: the guard casts to
  /// `List<QAGateResult>?` and `QAContract?`, so a JSON list of maps would be
  /// a type error rather than a verdict.
  Map<String, dynamic> toTransitionContext() => {
    'qaContract': contract,
    'gateResults': results,
  };

  /// The durable record of this evaluation.
  ///
  /// ## WHY THIS EXISTS AND THE CONTEXT DOES NOT
  ///
  /// The transition context is the guard's working material: it is read,
  /// evaluated and discarded. The design requires the results to be persisted
  /// **durably**, and "context-only is not acceptable" — a record that lives
  /// only in the arguments of a transition is not a record.
  ///
  /// This is the shape written into the work item's own durable metadata. It
  /// is JSON-safe by construction, and the service verifies that before
  /// returning (see [QAGateEvaluationService.evaluateForWorkItem]).
  ///
  /// ## WHY THE PROVENANCE IS SUMMARISED HERE
  ///
  /// Each gate result carries the provenance of the source that answered it,
  /// in its own metadata. That is enough to answer "which source produced
  /// THIS result", but it leaves a reader of the record itself to collect the
  /// answer from several places. The record therefore also carries the
  /// DISTINCT set of sources that answered, so the question "was any of this
  /// produced by a stand-in rather than by the platform?" has one answer at
  /// the top of the record (F-204).
  Map<String, dynamic> toDurableRecord() => {
    'qaContractId': contract.contractId,
    'evaluatedAt': evaluatedAt.toUtc().toIso8601String(),
    'isOverallPass': isOverallPass,
    'requiresFormalDetermination': requiresFormalDetermination,
    'outcomeKind': isOverallPass ? 'pass' : 'not_pass',
    'sourceProvenance': sourceProvenance,
    if (lanePathOwnership != null) 'lanePathOwnership': lanePathOwnership,
    'gateResults': [for (final result in results) result.toJson()],
  };

  /// The distinct sources that answered the gates, in a stable order.
  ///
  /// A source-free gate (R3) contributes nothing — it read the agent's own
  /// structured result, and there is no reader to name.
  List<Map<String, dynamic>> get sourceProvenance {
    final seen = <String, Map<String, dynamic>>{};
    for (final result in results) {
      final raw = result.metadata?[qaSourceProvenanceMetadataKey];
      if (raw is! Map) continue;
      final kind = raw['kind'];
      final sourceId = raw['sourceId'];
      if (kind is! String || sourceId is! String) continue;
      seen['$kind/$sourceId'] = {'kind': kind, 'sourceId': sourceId};
    }
    final keys = seen.keys.toList()..sort();
    return [for (final key in keys) seen[key]!];
  }
}

/// Evaluates a work item's QA contract and turns the evaluation into both a
/// transition context and a durable record.
///
/// ## WHAT IT DOES NOT DO
///
/// It does not decide the work item's fate. It does not transition anything,
/// it does not persist anything, and it does not raise a human decision. Those
/// belong to the drain, which owns the workflow; this service owns the
/// evaluation and the shape of its output.
///
/// Keeping the split is what lets the same evaluation be driven by a test
/// without a workflow engine, and it is why the service takes a
/// [QAContractStore] rather than reaching for a global one.
class QAGateEvaluationService {
  QAGateEvaluationService({
    required this.orchestration,
    required this.contractStore,
    this.declaredOwnedPathsSource,
  });

  /// The evaluation path. Its registry decides which reader answers each gate.
  final QAOrchestration orchestration;

  /// Where the contract is read from.
  final QAContractStore contractStore;

  /// Where the lane's declared owned paths are read from, when the platform
  /// has a durable record of them.
  ///
  /// ## WHY IT IS OPTIONAL
  ///
  /// It is optional so that a service assembled without one behaves EXACTLY as
  /// it behaved before this lane existed: the contract's own declaration is
  /// judged, and a contract whose owned set is empty is refused by the gate
  /// that reads it. That refusal is the shipped behaviour and it is measured
  /// by a test that must keep passing
  /// (`apps/server/test/product_contract_f2_ownership_glob_test.dart`).
  ///
  /// A service with a source wired is the production shape: the source reads
  /// the dispatch-time capture of the lane's grant, and the gate judges the
  /// change against what the lane was dispatched with.
  final DeclaredOwnedPathsSource? declaredOwnedPathsSource;

  /// Evaluates the contract named by [qaContractId] against [agentResult].
  ///
  /// ## THE CONTRACT IS READ FIRST, AND ITS ABSENCE IS A FAULT
  ///
  /// A contract id that resolves to no row is a **store fault**, not a gate
  /// failure. A gate failure says "the platform looked and the answer was no";
  /// a fault says "the platform could not look". The difference matters because
  /// the two are recorded differently and routed differently, and because a
  /// contract that cannot be read leaves nothing to evaluate — there is no
  /// declared gate set to fail.
  ///
  /// ## THE EVALUATION IS THE ORCHESTRATION'S, VERBATIM
  ///
  /// [QAOrchestration.evaluate] is called with no adaptation, and its results
  /// are the results. The two determinations are the orchestration's own
  /// ([QAOrchestration.isOverallPass] and
  /// [QAOrchestration.requiresFormalDetermination]) — this service does not
  /// re-derive them, because a second derivation is a second answer to the
  /// same question, and the two would drift.
  ///
  /// ## A RECORD THAT CANNOT BE ENCODED IS A FAULT
  ///
  /// The durable record is written as JSON. If it cannot be encoded, the
  /// evaluation produced something that cannot be persisted — which means it
  /// did not happen, as far as the workflow is concerned. Reporting it as a
  /// verdict would persist a claim the platform cannot honour.
  Future<QAGateEvaluationOutcome> evaluateForWorkItem({
    required String workItemId,
    required String qaContractId,
    required AgentResult agentResult,
  }) async {
    final QAContract? contract;
    try {
      contract = await contractStore.readQAContract(qaContractId);
    } catch (error) {
      throw QAGateEvaluationFault(
        'the QA contract "$qaContractId" could not be read for work item '
        '"$workItemId"',
        cause: error,
      );
    }

    if (contract == null) {
      throw QAGateEvaluationFault(
        'no QA contract resolves for id "$qaContractId" (work item '
        '"$workItemId"); there is no declared gate set to evaluate',
      );
    }

    // THE LANE'S PATH-OWNERSHIP DECLARATION — the input the change-scope
    // gate was missing, read from the durable record the lane was dispatched
    // with. It is read BEFORE the evaluation and supplied to the gate that
    // judges it; the gate's own semantics, config schema and fail-closed
    // direction are untouched.
    final declaration = await _readDeclaredOwnedPaths(workItemId);
    final evaluatedContract = _withDeclaredOwnedPaths(contract, declaration);

    final List<QAGateResult> results;
    try {
      results = await orchestration.evaluate(
        workItemId,
        agentResult,
        evaluatedContract,
      );
    } catch (error) {
      // A gate evaluator that REFUSES its own declaration (a
      // `FormatException` from the config parse) lands here. That is a
      // fault, not a verdict: the shipped F2 declaration carries an empty
      // `ownedPathGlobs`, which is refused by design, and the refusal must
      // not be recorded as "the change scope gate failed".
      //
      // When a declaration source WAS wired and the lane declared nothing,
      // the reason says so: the two refusals are different facts — a lane
      // that was dispatched and granted nothing, and a contract nobody
      // supplied a declaration for — and a reader who cannot tell them apart
      // cannot tell whether the platform is wired.
      throw QAGateEvaluationFault(
        'the QA evaluation for work item "$workItemId" could not be completed '
        'against contract "${contract.contractId}"'
        '${declaration != null && declaration.globs.isEmpty ? ' — the lane '
                  'that produced this item declared no owned paths, and the '
                  'change-scope gate refuses an empty owned set' : ''}',
        cause: error,
      );
    }

    final outcome = QAGateEvaluationOutcome(
      contract: evaluatedContract,
      results: results,
      isOverallPass: orchestration.isOverallPass(results, evaluatedContract),
      requiresFormalDetermination: orchestration.requiresFormalDetermination(
        results,
        evaluatedContract,
      ),
      evaluatedAt: DateTime.now(),
      lanePathOwnership: declaration?.toJson(),
    );

    _assertEncodable(outcome, workItemId);

    return outcome;
  }

  /// Reads the lane's declared owned paths, when a source is wired.
  ///
  /// A source that FAILS is a fault, not an empty declaration: the platform
  /// could not look, and "could not look" is not the same answer as "the lane
  /// declared nothing". Both refuse the gate, but only one of them is a
  /// statement about the lane, and the record has to be able to tell them
  /// apart.
  Future<_LanePathOwnership?> _readDeclaredOwnedPaths(String workItemId) async {
    final source = declaredOwnedPathsSource;
    if (source == null) return null;

    final List<String> globs;
    try {
      globs = await source.readDeclaredOwnedPaths(workItemId);
    } catch (error) {
      throw QAGateEvaluationFault(
        'the lane path-ownership declaration for work item "$workItemId" could '
        'not be read, so the change-scope gate has no declared owned set to '
        'judge the change against',
        cause: error,
      );
    }

    return _LanePathOwnership(globs: globs, source: source.provenance);
  }

  /// Supplies the lane's declaration to the gate that judges it.
  ///
  /// ## WHAT IT CHANGES, AND WHAT IT DOES NOT
  ///
  /// It supplies ONE value — the owned set the change-scope gate compares the
  /// diff's paths against — and it changes nothing else: the gate's
  /// comparison, its config schema, its forbidden half and its refusal of an
  /// empty owned set are all exactly as they were.
  ///
  /// ## WHICH GATE IT SUPPLIES
  ///
  /// The gate that is REGISTERED as the change-scope evaluator, found through
  /// the same registry the evaluation itself uses. Asking the registry — rather
  /// than matching a gate id or a type string — means the value goes to the
  /// gate that will actually judge it, and a contract that declares some
  /// other gate with a similar name is left alone.
  ///
  /// ## THE LANE'S DECLARATION REPLACES THE CONTRACT'S OWN
  ///
  /// The owned half of the gate's declaration is the PER-LANE half: the
  /// contract's copy is empty because the input was missing, and supplying the
  /// input fills it. When the lane declared nothing, the contract's own
  /// declaration stands — and the shipped contract declares none, so the gate
  /// refuses, which is the fail-closed direction the decision preserved.
  QAContract _withDeclaredOwnedPaths(
    QAContract contract,
    _LanePathOwnership? declaration,
  ) {
    if (declaration == null || declaration.globs.isEmpty) return contract;

    var supplied = false;
    final gates = <QAGateDefinition>[];
    for (final gate in contract.gates) {
      final evaluator = orchestration.registry.get(gate.type);
      if (evaluator is! ChangeScopeConfinementGate) {
        gates.add(gate);
        continue;
      }
      supplied = true;
      gates.add(
        QAGateDefinition(
          gateId: gate.gateId,
          type: gate.type,
          required: gate.required,
          config: <String, dynamic>{
            ...gate.config,
            ownedPathGlobsConfigKey: List<String>.unmodifiable(
              declaration.globs,
            ),
          },
          evidenceTypes: gate.evidenceTypes,
          workerCapabilities: gate.workerCapabilities,
        ),
      );
    }
    if (!supplied) return contract;

    return QAContract(
      contractId: contract.contractId,
      workItemCategory: contract.workItemCategory,
      gates: gates,
      version: contract.version,
      passCriteria: contract.passCriteria,
      createdAt: contract.createdAt,
      updatedAt: contract.updatedAt,
      evidenceRows: contract.evidenceRows,
      metadata: contract.metadata,
    );
  }

  /// Proves the durable record can be written as JSON.
  ///
  /// `QAGateResult.toJson()` converts dates and enums, but `metadata` and
  /// `QAEvidence.content` pass through untouched — so a gate that put a
  /// `DateTime` in its metadata would produce a record the store cannot hold.
  /// Checking here means the failure is a fault at evaluation time, where the
  /// reason can be named, rather than an opaque write error later.
  void _assertEncodable(QAGateEvaluationOutcome outcome, String workItemId) {
    try {
      jsonEncode(outcome.toDurableRecord());
    } catch (error) {
      throw QAGateEvaluationFault(
        'the QA evaluation record for work item "$workItemId" cannot be '
        'encoded as JSON, so it cannot be persisted durably',
        cause: error,
      );
    }
  }
}

/// The lane's declared owned paths, and the reader that supplied them.
///
/// Private to this library: it is the service's own working material, and the
/// durable shape it produces is a plain JSON map rather than a type other
/// packages would have to understand.
class _LanePathOwnership {
  _LanePathOwnership({required this.globs, required this.source});

  /// The globs the lane was granted. Empty when the lane declared nothing.
  final List<String> globs;

  /// What the reader says about itself, recorded so a reader of the durable
  /// record can tell the platform's reader from a stand-in (F-204).
  final QASourceProvenance source;

  /// The JSON-safe shape written into the durable record.
  Map<String, dynamic> toJson() => {
    'declaredOwnedPaths': globs,
    'source': source.toJson(),
  };
}

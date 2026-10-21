import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';

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
  });

  /// The evaluation path. Its registry decides which reader answers each gate.
  final QAOrchestration orchestration;

  /// Where the contract is read from.
  final QAContractStore contractStore;

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

    final List<QAGateResult> results;
    try {
      results = await orchestration.evaluate(workItemId, agentResult, contract);
    } catch (error) {
      // A gate evaluator that REFUSES its own declaration (a
      // `FormatException` from the config parse) lands here. That is a
      // fault, not a verdict: the shipped F2 declaration carries an empty
      // `ownedPathGlobs`, which is refused by design, and the refusal must
      // not be recorded as "the change scope gate failed".
      throw QAGateEvaluationFault(
        'the QA evaluation for work item "$workItemId" could not be completed '
        'against contract "${contract.contractId}"',
        cause: error,
      );
    }

    final outcome = QAGateEvaluationOutcome(
      contract: contract,
      results: results,
      isOverallPass: orchestration.isOverallPass(results, contract),
      requiresFormalDetermination: orchestration.requiresFormalDetermination(
        results,
        contract,
      ),
      evaluatedAt: DateTime.now(),
    );

    _assertEncodable(outcome, workItemId);

    return outcome;
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

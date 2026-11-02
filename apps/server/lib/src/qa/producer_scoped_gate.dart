import 'package:platform_contracts/platform_contracts.dart'
    show
        AgentResult,
        AgentRole,
        QAEvidence,
        QAGateDefinition,
        QAGateResult,
        QAGateStatus;
import 'package:qa_orchestration/qa_orchestration.dart'
    show GateEvaluator, QASourceProvenanceAware, qaSourceProvenanceMetadataKey;

/// Reads the [AgentRole] of the execution that PRODUCED a work item.
///
/// ## WHY A SEAM AND NOT THE RESOLVER ITSELF
///
/// The gate that consumes this ([ProducerRoleScopedGate]) needs one fact —
/// "which role produced this item" — and the platform's rule for answering it
/// lives in `ProducerWorkspaceResolver` (`production_qa_sources.dart`), the
/// same rule the QA drain resolves the producer's result through. Naming the
/// answer as a seam keeps the gate testable against a role that is known,
/// instead of against a store populated well enough for the resolution rule
/// to find something.
///
/// `null` is a value, not an error: it means the producer could not be
/// identified, and the gate treats it as "applicability cannot be
/// established" — the fail-closed direction, which is to evaluate.
abstract interface class ProducerRoleSource implements QASourceProvenanceAware {
  /// The [AgentExecution.role] of the producing execution, or `null` when no
  /// producer resolves for [workItemId].
  Future<AgentRole?> producerRoleFor(String workItemId);
}

/// Scopes [inner] to the producer roles it honestly applies to.
///
/// ## THE DEFECT THIS CLOSES — F-246
///
/// The shipped product manifest declares `intake-structured-result-admitted`
/// (type `triage-classification-structure`) on the product's global QA gate
/// set, so every `qa-product-*` contract demands `classification`, `status`,
/// `confidence` and `suspectedCategory` — fields only a triage execution's
/// `structuredResult` carries. A feature or design-remediation item can never
/// satisfy it: the implementer's result has no such fields, so the required
/// gate failed for every non-triage producer, permanently, and the item was
/// undrainable except by human waiver.
///
/// The assertion itself is honest — it is the same one
/// `triage-classification-admitted` makes on `qa-triage-*` contracts — but it
/// is an assertion ABOUT TRIAGE OUTPUT. Applied to an implementer's result it
/// is a category error: it does not measure the implementer's work, it
/// measures whether the implementer happened to emit triage's schema. The fix
/// is not to weaken the gate (a triage contract that stopped checking
/// classification shape would assert nothing) and not to drop it silently
/// (the contract still declares it); it is to make applicability a fact about
/// the PRODUCER, which is what the gate's own type already says.
///
/// ## WHAT IT RETURNS, AND WHY `not_applicable`
///
/// When the producing execution's role is not in [appliesToRoles] the gate
/// does not apply, and the result says so: `QAGateStatus.notApplicable`, with
/// an evidence row naming the role that was read and the source that read it.
/// That is a real verdict the durable record can carry — not a fabricated
/// pass, not a `skipped` (which requires a recorded authority), and not the
/// absence of a result. `QAOrchestration.isGateSatisfied` and the
/// `all_required_gates_passed` guard both treat `not_applicable` as
/// satisfied, so a required gate that genuinely does not apply stops blocking
/// — while remaining visible in the record for exactly what it was.
///
/// ## THE FAIL-CLOSED DIRECTIONS, EACH DELIBERATE
///
///  * **Producer unresolvable** (`roleSource` answers `null`): the gate
///    evaluates anyway. "Could not establish who produced this" is not "the
///    producer was not triage", and a null answer must not n/a a gate that
///    might apply. In the drain this is unreachable — a work item whose
///    producer cannot be resolved is faulted before evaluation — but the
///    evaluator must still be correct standing alone.
///  * **The role read throws**: the exception propagates and the evaluation
///    service records a FAULT — "the platform could not look" — rather than a
///    verdict. Same rule the other evaluators' source failures follow.
///  * **Producer is in [appliesToRoles]**: [inner] runs verbatim — a malformed
///    triage classification still fails, and a triage producer gains no
///    exemption from the structure its own contract demands.
///
/// ## WHY THE REGISTRY, AND NOT THE CONTRACT OR THE DRAIN
///
/// The gate set is declared; changing the declaration cannot retro-fix the
/// `qa-product-*` rows already minted, and a per-contract spec edit leaves the
/// same mis-application in every persisted row. The drain cannot filter the
/// contract — `QAGateEvaluationService` reads the row itself, and the
/// `qaPassed` guard requires a satisfied result for every required gate the
/// contract declares. The evaluator is therefore the one place a producer
/// fact can change the verdict for every contract, persisted or not — and the
/// production registry (`buildProductionGateRegistry`) is where it is
/// registered, wrapping the same `TriageClassificationAdmittedGate` the
/// package registers, so there is still exactly one evaluator implementation
/// of the assertion itself.
class ProducerRoleScopedGate implements GateEvaluator {
  const ProducerRoleScopedGate({
    required this.inner,
    required this.roleSource,
    required this.appliesToRoles,
  });

  /// The evaluator that runs when the gate applies.
  ///
  /// Held rather than reimplemented: `TriageClassificationAdmittedGate` is the
  /// one implementation of the classification-structure assertion, and a copy
  /// here would be a second statement of it that can drift.
  final GateEvaluator inner;

  /// Where the producing execution's role is read from.
  final ProducerRoleSource roleSource;

  /// The producer roles the gate applies to. For the triage-structure gate
  /// this is `{AgentRole.triageDefect}` — the only execution whose output is
  /// a triage classification.
  final Set<AgentRole> appliesToRoles;

  /// Registered under [inner]'s type so the decorator cannot drift from the
  /// evaluator it scopes: `GateRegistry` keys on `gateType`, and this gate IS
  /// that evaluator with an applicability precondition, not a new assertion.
  @override
  String get gateType => inner.gateType;

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final role = await roleSource.producerRoleFor(workItemId);

    // The gate applies when the producer's role is in scope — and when no
    // producer resolves at all, because "cannot tell whether it applies" is
    // not a reason to declare it inapplicable. Delegating on the null case
    // preserves the gate's unscoped verdict exactly.
    if (role == null || appliesToRoles.contains(role)) {
      return inner.evaluate(workItemId, agentResult, gate);
    }

    final evaluatedAt = DateTime.now();
    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: QAGateStatus.notApplicable,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:producer_scope:'
              '${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'producer_role',
          // Names the durable column the answer was read from
          // (`agent_execution.role`), in the same way the other gates name
          // the column their declaration points at — a label, never a query.
          artifactRef: 'agent_execution.role',
          content: <String, dynamic>{
            'producerRole': role.wire,
            'appliesToRoles': appliesToRoles.map((r) => r.wire).toList(),
            'reason':
                'the producing execution\'s role is ${role.wire}, which this '
                'gate does not apply to; the gate asserts the structure of a '
                'triage classification and is evaluated only for producers in '
                '${appliesToRoles.map((r) => r.wire).join(', ')}',
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      // `passedAt` stays null: not_applicable is satisfied, not passed — the
      // record must not claim the structure check ran.
      metadata: <String, dynamic>{
        qaSourceProvenanceMetadataKey: roleSource.provenance.toJson(),
        'producerRole': role.wire,
        'reason':
            'gate does not apply to producer role ${role.wire}; evaluated as '
            'not_applicable rather than failed or skipped',
      },
    );
  }
}

import 'package:platform_contracts/platform_contracts.dart';

/// Metadata key: the work item this contract was provisioned for.
///
/// [QAContract] has no `workItemId` field on purpose — a contract is a
/// reusable declaration, not a work item. The provisioner records the link
/// here, and `QAContractStore.listQAContractsForWorkItem` is the only thing
/// that reads it back, so the two cannot drift apart.
const String qaContractWorkItemIdMetadataKey = 'workItemId';

/// Metadata key: the human-reported defect the work item was opened from.
const String qaContractDefectIdMetadataKey = 'defectId';

/// The [WorkItemCategory] a defect-triage work item is filed under.
///
/// This is a single shared constant rather than a literal in two files
/// because the QA contract and the work item it is attached to MUST agree:
/// the contract's `workItemCategory` is a fact about the persisted work item,
/// and a contract that claims `bugfix` for a work item the row files as
/// `feature` is a contract nobody can check.
///
/// `WorkItemCategory` has no `defect` variant. Introducing one — or moving
/// triage to the existing `bugfix` — is a domain decision about work item
/// classification, not a wiring detail, and is deliberately not smuggled in
/// here. Until it is made as a recorded decision, triage reports are filed as
/// `feature` and this contract says so.
const WorkItemCategory triageWorkItemCategory = WorkItemCategory.feature;

/// Revision of the ADVISORY TRIAGE QA contract gate set.
///
/// This versions the *contract* — the set of gates below and what each one
/// demands — not the platform contract schema, not the `qa_contract` table and
/// not the database migration. Changing a gate, a `required` flag, an
/// evidence type or a pass criterion is a change to this string, because that
/// is the only place the revision of the declaration is recorded; the
/// `contractId` deliberately does not encode it so a re-provisioned defect
/// updates its single row in place rather than forking a second contract.
const String advisoryTriageQAContractVersion = '1.0.0';

/// Deterministic identity of the QA contract for the triage of [defectId].
///
/// Derived from the defect, not from the work item, because `defect-{defectId}`
/// is a routing convention (`triageDefectDedupeKey`,
/// `TriageProcessor._extractDefectId`) while the defect id is the actual
/// subject of the classification. One defect gets one triage work item, so one
/// defect gets one contract, and re-running the provisioner converges on the
/// same row instead of creating a second contract.
String triageQAContractIdForDefect(String defectId) => 'qa-triage-$defectId';

/// Builds the QA contract that governs ADVISORY defect triage.
///
/// ## Why this contract exists at all
///
/// `GuardConditions.qaContractExists()` refuses
/// `agentExecuting -> agentCompleted` unless the work item carries a
/// `qaContractId`. No production code path ever set one, so a durably enqueued
/// triage job dispatched, executed, and was then refused at the last
/// transition — recorded as `JobFailureKind.permanent` with the work item
/// stranded in `agentExecuting`. The honest repair is a real contract, not a
/// string that merely satisfies `!= null`: this is a persisted [QAContract]
/// whose gates can be read, audited and later evaluated.
///
/// ## Why the gates are the ones below and not build/test/security gates
///
/// Triage here is ADVISORY. Per ADR 0021 the triage agent produces a
/// classification, a status recommendation, a confidence signal, a suspected
/// area and a set of cited evidence — and nothing else. It changes no
/// repository file, runs no build, produces no artifact and is not an
/// implementation that a security scan or a coverage threshold could say
/// anything true about. A contract that declared `test-coverage` or
/// `security-scan` for this work item would be asserting a check nobody runs
/// against anything triage produced, which is exactly the fiction this change
/// exists to remove.
///
/// So the gates describe what genuinely decides whether a triage classification
/// is admissible:
///
///  * [structuredClassificationAdmitted] — the output has to be a
///    classification at all. This is already the processor's hard
///    requirement: an empty, malformed or unrecognised `classification` /
///    `status` / `confidence` / `suspectedCategory` yields no `TriageResult`
///    today. The contract records that as an obligation rather than leaving it
///    as an accident of a `FormatException` handler.
///  * [evidenceGrounded] — a classification that cites evidence which does not
///    exist, or exists against a different defect, is not a classification of
///    this defect. This is the single most load-bearing thing to validate for
///    an advisory output, and it is currently NOT enforced anywhere:
///    `TriageProcessor._parseTriageResult` copies `evidenceUsed` verbatim and
///    the `PRODUCTION DEFECT: evidenceUsed is persisted without checking it
///    against the defect` case in `triage_execution_test.dart` pins the gap.
///  * [clarificationRouted] — an ambiguous report must be clarified, not
///    guessed. Deliberately NOT required: a well-formed report legitimately
///    raises no clarification, and a required gate that is expected to fail is
///    a gate that trains everyone to waive it.
///
/// ## On `workerCapabilities`
///
/// All three gates declare `workerCapabilities: null`, which reads as "no
/// worker capability is required to satisfy this". That is the honest
/// statement today. AGENTS.md §12 requires QA evidence to be collected by
/// `qa_orchestration` workers rather than by agents, and the evidence these
/// gates name is (a) the triage agent's own structured output and (b) records
/// the defect already owns in `defect_evidence` / `defect_clarification`.
/// Claiming a worker capability for any of them would name a worker that does
/// not exist.
///
/// ## On `gate.type`
///
/// These gate types have no entry in `GateRegistry` — the four registered
/// evaluators are all implementation gates, and none of them can say anything
/// about a classification. That is deliberate and it is not silently passing:
/// `QAOrchestration.evaluate` returns `QAGateStatus.notExecuted` for an
/// unknown type, `isGateSatisfied(notExecuted)` is `false`, and
/// `QAOrchestration.requiresFormalDetermination` names both required gates as
/// needing a formal determination. The contract is a durable declaration of
/// what must be true; the evaluator runtime that will enforce it does not exist
/// yet, and the contract says `evaluatorRuntime: absent` in its metadata
/// rather than implying otherwise.
QAContract buildAdvisoryTriageQAContract({
  required String defectId,
  required String workItemId,
  DateTime? now,
}) {
  final timestamp = (now ?? DateTime.now()).toUtc();
  return QAContract(
    contractId: triageQAContractIdForDefect(defectId),
    workItemCategory: triageWorkItemCategory,
    version: advisoryTriageQAContractVersion,
    createdAt: timestamp,
    updatedAt: timestamp,
    gates: const [
      structuredClassificationAdmitted,
      evidenceGrounded,
      clarificationRouted,
    ],
    // `allRequiredGatesMustPass` is the default and is the right rule: an
    // inadmissible classification must not be presented as admissible.
    // `optionalGateFailuresAllowed: 1` is exactly the number of optional gates
    // in this contract, so the single non-required gate can be unmet without
    // blocking — which is the same as requiring it never to fail, and is
    // satisfiable by any triage run at all.
    passCriteria: const QAPassCriteria(
      allRequiredGatesMustPass: true,
      optionalGateFailuresAllowed: 1,
      waiverRequiresHumanDecision: true,
    ),
    evidenceRows: const [],
    metadata: <String, dynamic>{
      qaContractWorkItemIdMetadataKey: workItemId,
      qaContractDefectIdMetadataKey: defectId,
      'requiredRole': AgentRole.triageDefect.wire,
      // Triage is advisory: this contract governs whether a classification may
      // be recorded, never whether code may ship.
      'advisory': true,
      'authoring': 'lane_g_triage_qa_contract',
      'evaluatorRuntime': 'absent',
    },
  );
}

/// The agent's output has to be a well-formed triage classification.
///
/// Evidence: the `structuredResult` document carried by the terminal
/// `AgentResult`, as persisted in `agent_result.structuredResultJson`. It is
/// the same document `TriageProcessor._parseTriageResult` reads, so this gate
/// and the processor agree by construction: `classification`, `status`,
/// `confidence` and `suspectedCategory` must all be present, and
/// `classification` must be a known `DefectClassification`.
///
/// Required, because without it there is no classification — there is a log
/// line.
const QAGateDefinition structuredClassificationAdmitted = QAGateDefinition(
  gateId: 'triage-classification-admitted',
  type: 'triage-classification-structure',
  required: true,
  evidenceTypes: ['triage_structured_result'],
  config: <String, dynamic>{
    'sourceColumn': 'agent_result.structuredResultJson',
    'requiredFields': [
      'classification',
      'status',
      'confidence',
      'suspectedCategory',
    ],
    'classificationEnum': 'DefectClassification',
    'statusEnum': 'DefectStatus',
  },
);

/// Every id the classification cites must name evidence that really exists
/// against this defect.
///
/// Evidence: the `DefectEvidence` rows in `defect_evidence` for this defect,
/// each referenced by id.
///
/// Required. This is the gate that makes a triage classification a statement
/// ABOUT THE REPORTED DEFECT rather than an unfalsifiable assertion, and it is
/// the one the platform does not currently enforce.
const QAGateDefinition evidenceGrounded = QAGateDefinition(
  gateId: 'triage-evidence-grounded',
  type: 'triage-evidence-grounding',
  required: true,
  evidenceTypes: ['defect_evidence_reference'],
  config: <String, dynamic>{
    'sourceColumn': 'defect_evidence.evidenceId',
    'everyCitedEvidenceMustExist': true,
    'mustBelongToReportedDefect': true,
  },
);

/// An ambiguous report is clarified, not guessed at.
///
/// Evidence: the `DefectClarification` rows in `defect_clarification` raised
/// for this defect, each carrying its question and reason.
///
/// Not required. It is conditional on ambiguity, which is a property of the
/// report rather than of the run, so a required flag here would mark every
/// well-formed triage as a gate failure.
const QAGateDefinition clarificationRouted = QAGateDefinition(
  gateId: 'triage-clarification-routing',
  type: 'triage-clarification-routing',
  required: false,
  evidenceTypes: ['defect_clarification_request'],
  config: <String, dynamic>{
    'sourceColumn': 'defect_clarification.clarificationId',
    'requiredWhen':
        'expected behaviour, reproduction or suspected area '
        'cannot be determined from the report and the cited evidence',
  },
);

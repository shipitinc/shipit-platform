import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';

/// Reads the durability row for one defect id.
///
/// `DefectStore.readDefect` throws `DefectNotFoundException` when no row
/// resolves (`apps/server/lib/src/persistence/postgres_defect_store.dart`),
/// while "the row is missing" is exactly the condition this gate records. The
/// production adapter therefore maps that exception to `null` — the same
/// distinction `triage_processor.dart` makes when it catches
/// `DefectNotFoundException`, logs `triage.processed.defect_missing` and
/// continues. That mapping belongs in the adapter (slice 3c) because the
/// exception type lives in `apps/server`, which this package must not depend
/// on; this interface states the semantic the adapter is required to provide.
///
/// A reader that throws any other exception propagates it: "I could not look"
/// is not "the row is missing", and a gate must not turn an infrastructure
/// failure into a triage finding.
abstract interface class DefectRowReader {
  Future<Defect?> readDefect(String defectId);
}

/// The feature lane's R1 gate: the defect row the remediation work item
/// references exists before triage may proceed.
///
/// This is the read-side twin of the live path in
/// `apps/server/lib/src/triage/triage_processor.dart`, which catches
/// `DefectNotFoundException`, logs `triage.processed.defect_missing`, and
/// **returns success with its classification discarded**. The parked work item
/// `design-remediation-DEF-1791686085546076` is the row that path can drop.
///
/// ## The id source is fixed, and is not read from the row
///
/// The only supported `idSource` is `'workItemDefectReference'`: the defect id
/// is derived from the work item id's documented
/// `design-remediation-<defectId>` shape (`product_qa_contract.dart`). Reading
/// it from the defect row would make the row its own evidence, so the reader is
/// called with the id derived from the work item and nothing else.
///
/// `sourceColumn` is a **label**. It is recorded in the evidence so a person can
/// tell which column the reference came from, and it is never passed to the
/// reader — a hostile value cannot become a query.
class RemediationDefectExistenceGate implements GateEvaluator {
  RemediationDefectExistenceGate({required this.defectReader});

  final DefectRowReader defectReader;

  /// The documented work-item id prefix (`product_qa_contract.dart:42-47`).
  static const String workItemIdPrefix = 'design-remediation-';

  @override
  String get gateType => 'triage-defect-existence';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final config = _RemediationDefectConfig.from(gate);
    final evaluatedAt = DateTime.now();

    final referencedDefectId = _referencedDefectId(workItemId);

    final failures = <String>[];
    Defect? defect;
    String? resolutionFailure;

    if (referencedDefectId == null) {
      resolutionFailure =
          'work item "$workItemId" does not carry the "$workItemIdPrefix" '
          'prefix, so idSource "${config.idSource}" names no defect';
    } else {
      defect = await defectReader.readDefect(referencedDefectId);
      if (defect == null) {
        resolutionFailure =
            'no defect row resolves for "$referencedDefectId" referenced by '
            '"$workItemId"; this is the condition triage_processor catches and '
            'logs as triage.processed.defect_missing';
      } else if (defect.defectId != referencedDefectId) {
        resolutionFailure =
            'the defect reader returned "${defect.defectId}" for '
            '"$referencedDefectId"; a row for another defect is not the row '
            'the work item references';
      }
    }

    if (resolutionFailure != null) failures.add(resolutionFailure);
    final passed = failures.isEmpty;

    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:defect_row:'
              '${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'defect_row',
          // The label from the contract, not the id: the source column is what
          // a reader of the evidence needs, and it never reaches the reader.
          artifactRef: config.sourceColumn,
          content: <String, dynamic>{
            'referencedDefectId': referencedDefectId,
            'sourceColumn': config.sourceColumn,
            'idSource': config.idSource,
            'resolved': passed,
            'resolvedDefectId': defect?.defectId,
            if (resolutionFailure != null) 'reason': resolutionFailure,
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{
        'referencedDefectId': referencedDefectId,
        'sourceColumn': config.sourceColumn,
        if (!passed) 'reason': failures.join('; '),
      },
    );
  }

  /// `design-remediation-DEF-1791686085546076` -> `DEF-1791686085546076`.
  ///
  /// Returns `null` for an id that does not carry the prefix, carries only the
  /// prefix, or carries nothing after it. The remainder is not validated
  /// further: an id that does not exist is the reader's finding, not the
  /// parser's.
  static String? _referencedDefectId(String workItemId) {
    if (!workItemId.startsWith(workItemIdPrefix)) return null;
    final remainder = workItemId.substring(workItemIdPrefix.length);
    if (remainder.isEmpty) return null;
    return remainder;
  }
}

/// R1's declared half. Every field is required: a missing `idSource` or
/// `requireResolvable` would leave the gate reading a default it was never
/// given.
class _RemediationDefectConfig {
  const _RemediationDefectConfig({
    required this.idSource,
    required this.sourceColumn,
  });

  static const String supportedIdSource = 'workItemDefectReference';
  static const String defaultSourceColumn = 'defect.defectId';

  final String idSource;
  final String sourceColumn;

  static _RemediationDefectConfig from(QAGateDefinition gate) {
    final idSource = gate.config['idSource'];
    if (idSource != supportedIdSource) {
      throw FormatException(
        'gate ${gate.gateId} declares "idSource" as $idSource; the only '
        'supported value is "$supportedIdSource"',
      );
    }

    if (gate.config['requireResolvable'] != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "requireResolvable": true; a gate '
        'that does not require the row to resolve asserts nothing',
      );
    }

    final sourceColumn = gate.config['sourceColumn'] ?? defaultSourceColumn;
    if (sourceColumn is! String || sourceColumn.trim().isEmpty) {
      throw FormatException(
        'gate ${gate.gateId} declares "sourceColumn" as $sourceColumn; it is a '
        'non-empty label, not a query',
      );
    }

    return _RemediationDefectConfig(
      idSource: supportedIdSource,
      sourceColumn: sourceColumn,
    );
  }
}

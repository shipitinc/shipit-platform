import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';

/// Reads defect evidence rows for a given defect id.
abstract interface class DefectEvidenceReader {
  Future<List<DefectEvidence>> readDefectEvidence(String defectId);
}

/// Gate R2: triage-evidence-grounded (type: triage-evidence-grounding)
class TriageEvidenceGroundingGate implements GateEvaluator {
  TriageEvidenceGroundingGate({required this.defectEvidenceReader});

  final DefectEvidenceReader defectEvidenceReader;

  @override
  String get gateType => 'triage-evidence-grounding';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final config = _TriageEvidenceGroundingConfig.from(gate);
    final evaluatedAt = DateTime.now();
    final defectId = _extractDefectId(agentResult, workItemId);

    final failures = <String>[];
    var citedEvidenceIds = <String>[];
    var defectEvidenceRows = <DefectEvidence>[];

    // Extract cited evidence from the structured result.
    // `AgentResult.structuredResult` is a non-nullable `Map<String, dynamic>`
    // (platform_contracts `types/agent_result.dart:43`), so there is no "not a
    // map" state to defend against.
    final evidenceUsed = agentResult.structuredResult['evidenceUsed'];
    if (evidenceUsed is List) {
      citedEvidenceIds = evidenceUsed.whereType<String>().toList();
    }

    // Enforce >= 1 citation as per requirement (non-vacuity)
    if (citedEvidenceIds.isEmpty) {
      failures.add(
        'classification cites no evidence (empty evidenceUsed); '
        'non-vacuity requires >= 1 citation',
      );
    }

    if (defectId != null) {
      defectEvidenceRows = await defectEvidenceReader.readDefectEvidence(
        defectId,
      );
    } else {
      failures.add('cannot determine defect id from agent result or work item');
    }

    // Both flags are required `true` at provision (see
    // `_TriageEvidenceGroundingConfig.from`), so both checks below always run.
    //
    // Every returned row is re-verified HERE — `row.defectId == defectId` —
    // exactly as `remediation_defect_existence_gate.dart:81-86` re-verifies
    // the defect row the reader returned. A reader that ignores its defect
    // argument (reviewer falsifier F1) must not be able to hand this gate
    // another defect's row and have it count as this defect's evidence; that
    // row identity is the gate's own check, not a courtesy of the reader.
    final existingEvidenceIds = <String>{};
    for (final row in defectEvidenceRows) {
      if (row.defectId != defectId) {
        failures.add(
          'evidence row "${row.evidenceId}" belongs to defect '
          '"${row.defectId}" rather than the reported defect "$defectId"; a '
          'row for another defect is not evidence about this one',
        );
        continue;
      }
      existingEvidenceIds.add(row.evidenceId);
    }

    // `everyCitedEvidenceMustExist`: each cited id must resolve to a row that
    // both exists and belongs to the reported defect.
    for (final citedId in citedEvidenceIds) {
      if (!existingEvidenceIds.contains(citedId)) {
        failures.add(
          'cited evidence "$citedId" does not exist for defect "$defectId"',
        );
      }
    }

    final passed = failures.isEmpty;

    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:evidence_check:${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'defect_evidence_reference',
          artifactRef: config.sourceColumn, // label only
          content: <String, dynamic>{
            'sourceColumn': config.sourceColumn,
            'everyCitedEvidenceMustExist': config.everyCitedEvidenceMustExist,
            'mustBelongToReportedDefect': config.mustBelongToReportedDefect,
            'defectId': defectId,
            'citedEvidenceIds': citedEvidenceIds,
            'existingEvidenceCount': defectEvidenceRows.length,
            'existingEvidenceIds': defectEvidenceRows
                .map((e) => e.evidenceId)
                .toList(),
            'resolved': passed,
            if (!passed) 'reasons': failures,
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{
        'defectId': defectId,
        'citedCount': citedEvidenceIds.length,
        if (!passed) 'reason': failures.join('; '),
      },
    );
  }

  String? _extractDefectId(AgentResult agentResult, String workItemId) {
    final defectId = agentResult.structuredResult['defectId'];
    if (defectId is String && defectId.isNotEmpty) return defectId;
    if (workItemId.contains('DEF-')) {
      final match = RegExp(r'DEF-\d+').firstMatch(workItemId);
      if (match != null) return match.group(0);
    }
    return null;
  }
}

/// The declared half of R2, read once and validated.
///
/// Both flags are **required `true`**: a gate that does not require every
/// citation to resolve asserts nothing, and a gate that does not require the
/// row to belong to the reported defect silently degrades into the mere
/// existence gate that the contract's own second falsifier row exists to
/// forbid. A missing or `false` flag is therefore a [FormatException] naming
/// the gate — the same refusal `_RemediationDefectConfig` makes for a missing
/// `requireResolvable` — never a weaker gate.
class _TriageEvidenceGroundingConfig {
  const _TriageEvidenceGroundingConfig({
    required this.sourceColumn,
    required this.everyCitedEvidenceMustExist,
    required this.mustBelongToReportedDefect,
  });

  final String sourceColumn;
  final bool everyCitedEvidenceMustExist;
  final bool mustBelongToReportedDefect;

  static _TriageEvidenceGroundingConfig from(QAGateDefinition gate) {
    final sourceColumn = gate.config['sourceColumn'];
    if (sourceColumn is! String || sourceColumn.trim().isEmpty) {
      throw FormatException(
        'gate ${gate.gateId} declares "sourceColumn" as $sourceColumn; it is a '
        'non-empty label, not a query',
      );
    }
    if (gate.config['everyCitedEvidenceMustExist'] != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "everyCitedEvidenceMustExist": '
        'true; a gate that may accept a citation naming no row asserts '
        'nothing',
      );
    }
    if (gate.config['mustBelongToReportedDefect'] != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "mustBelongToReportedDefect": '
        'true; a gate that does not require the row to belong to the reported '
        'defect degrades to a mere existence gate, which the contract\'s own '
        'second falsifier forbids',
      );
    }
    return _TriageEvidenceGroundingConfig(
      sourceColumn: sourceColumn,
      everyCitedEvidenceMustExist: true,
      mustBelongToReportedDefect: true,
    );
  }
}

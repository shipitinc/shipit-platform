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

    // Extract cited evidence from structured result
    final structured = agentResult.structuredResult;
    if (structured is Map<String, dynamic>) {
      final evidenceUsed = structured['evidenceUsed'];
      if (evidenceUsed is List) {
        citedEvidenceIds = evidenceUsed.whereType<String>().toList();
      }
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

    // Build lookup of evidence ids that exist and belong to this defect
    final existingEvidenceIds = <String>{};
    for (final row in defectEvidenceRows) {
      existingEvidenceIds.add(row.evidenceId);
    }

    // Check each cited evidence
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
    final structured = agentResult.structuredResult;
    if (structured is Map<String, dynamic>) {
      final defectId = structured['defectId'];
      if (defectId is String && defectId.isNotEmpty) return defectId;
    }
    if (workItemId.contains('DEF-')) {
      final match = RegExp(r'DEF-\d+').firstMatch(workItemId);
      if (match != null) return match.group(0);
    }
    return null;
  }
}

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
        'gate ${gate.gateId} declares "sourceColumn" as $sourceColumn; it is a non-empty label',
      );
    }
    final every = gate.config['everyCitedEvidenceMustExist'];
    final mustBelong = gate.config['mustBelongToReportedDefect'];
    return _TriageEvidenceGroundingConfig(
      sourceColumn: sourceColumn,
      everyCitedEvidenceMustExist: every == true,
      mustBelongToReportedDefect: mustBelong == true,
    );
  }
}

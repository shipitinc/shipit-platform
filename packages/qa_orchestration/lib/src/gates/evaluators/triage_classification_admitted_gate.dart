import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';

/// Gate R3: triage-classification-admitted (type: triage-classification-structure)
/// Gate ID must be 'triage-classification-admitted'
class TriageClassificationAdmittedGate implements GateEvaluator {
  TriageClassificationAdmittedGate();

  @override
  String get gateType => 'triage-classification-structure';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final config = _TriageClassificationConfig.from(gate);
    final evaluatedAt = DateTime.now();

    final failures = <String>[];
    // `AgentResult.structuredResult` is a non-nullable `Map<String, dynamic>`
    // (platform_contracts `types/agent_result.dart:43`), so there is no "not a
    // map" state to defend against; the previous `is Map` guard and its
    // `hasStructuredResult` evidence key were unreachable fiction.
    final structured = agentResult.structuredResult;

    for (final field in config.requiredFields) {
      if (!structured.containsKey(field)) {
        failures.add('missing required field: $field');
      } else if (structured[field] == null) {
        failures.add('required field is null: $field');
      }
    }

    // Fail closed: a `classification` that is not a known wire string fails —
    // whether it is a non-string (reviewer falsifier F7: `classification: 42`),
    // absent/null, or a string outside the enum — and the reason names the
    // key. The previous `classification is String` guard with no else branch
    // let every non-string through unvalidated.
    final classification = structured['classification'];
    if (classification is String) {
      try {
        DefectClassification.fromWire(classification);
      } on FormatException {
        failures.add(
          'classification is outside DefectClassification: $classification',
        );
      }
    } else {
      failures.add(
        'classification is not a wire string of DefectClassification: '
        '$classification',
      );
    }

    // `statusEnum: 'DefectStatus'` is declared in the config and echoed into
    // the evidence, so the status it names is validated here too — the key is
    // not decoration. Same fail-closed rule as `classification`.
    final status = structured['status'];
    if (status is String) {
      try {
        DefectStatus.fromWire(status);
      } on FormatException {
        failures.add('status is outside DefectStatus: $status');
      }
    } else {
      failures.add('status is not a wire string of DefectStatus: $status');
    }

    final passed = failures.isEmpty;

    return QAGateResult(
      gateId: gate.gateId, // must remain as declared
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:classification_check:${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'triage_structured_result',
          artifactRef: config.sourceColumn,
          content: <String, dynamic>{
            'sourceColumn': config.sourceColumn,
            'requiredFields': config.requiredFields,
            'classificationEnum': config.classificationEnum,
            'statusEnum': config.statusEnum,
            'structuredResult': structured,
            'resolved': passed,
            if (!passed) 'reasons': failures,
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{if (!passed) 'reason': failures.join('; ')},
    );
  }
}

/// The declared half of R3, read once and validated.
///
/// Every field is required: a missing key that silently fell back to a default
/// would let a gate run on a declaration it was never given. The
/// [FormatException] names the gate, matching `_DeclaredValidationConfig` and
/// `_RemediationDefectConfig`.
class _TriageClassificationConfig {
  const _TriageClassificationConfig({
    required this.sourceColumn,
    required this.requiredFields,
    required this.classificationEnum,
    required this.statusEnum,
  });

  final String sourceColumn;
  final List<String> requiredFields;
  final String classificationEnum;
  final String statusEnum;

  static _TriageClassificationConfig from(QAGateDefinition gate) {
    final sourceColumn = gate.config['sourceColumn'];
    if (sourceColumn is! String || sourceColumn.trim().isEmpty) {
      throw FormatException(
        'gate ${gate.gateId} declares "sourceColumn" as $sourceColumn; it is a '
        'non-empty label, not a query',
      );
    }

    final requiredFields = _stringList(gate, 'requiredFields');
    if (requiredFields.isEmpty) {
      throw FormatException(
        'gate ${gate.gateId} declares an empty "requiredFields"; a gate that '
        'requires no field asserts nothing',
      );
    }

    return _TriageClassificationConfig(
      sourceColumn: sourceColumn,
      requiredFields: requiredFields,
      classificationEnum: _requiredString(gate, 'classificationEnum'),
      statusEnum: _requiredString(gate, 'statusEnum'),
    );
  }

  static String _requiredString(QAGateDefinition gate, String key) {
    if (!gate.config.containsKey(key)) {
      throw FormatException(
        'gate ${gate.gateId} does not declare "$key", which is required',
      );
    }
    final value = gate.config[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'gate ${gate.gateId} declares "$key" as $value; a non-empty string is '
        'the only shape that can be read',
      );
    }
    return value;
  }

  static List<String> _stringList(QAGateDefinition gate, String key) {
    if (!gate.config.containsKey(key)) {
      throw FormatException(
        'gate ${gate.gateId} does not declare "$key", which is required',
      );
    }
    final value = gate.config[key];
    if (value is! List) {
      throw FormatException(
        'gate ${gate.gateId} declares "$key" as ${value.runtimeType}; a JSON '
        'array of strings is the only shape that can be read as one',
      );
    }
    return value
        .map((entry) {
          if (entry is! String || entry.trim().isEmpty) {
            throw FormatException(
              'gate ${gate.gateId} declares a non-string or empty entry in '
              '"$key" ($entry)',
            );
          }
          return entry;
        })
        .toList(growable: false);
  }
}

/// Drift guard for the triage defect prompt contract.
///
/// `triageDefectInstruction` is the only statement of the triage payload's
/// shape that the triage agent ever sees, and
/// `TriageProcessor._parseTriageResult` in `apps/server` feeds the emitted
/// strings straight into `DefectClassification.fromWire` /
/// `DefectStatus.fromWire`, both of which throw on an unknown token. A prompt
/// that documents a spelling the contracts do not serialise therefore yields
/// a `null` `TriageResult` end to end.
///
/// This test reads the documented values back out of the *generated* prompt
/// string (not out of a copy of it) and asserts they equal the live enum
/// tokens, so an added, renamed or reordered enum value fails here instead of
/// silently un-parsing agent output.
library;

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

/// The field names `TriageProcessor._parseTriageResult` reads out of the
/// agent's structured payload. Read-only mirror of that parser: if the prompt
/// drops or renames one of these, the triage result loses data.
const List<String> parserReadFieldNames = [
  'classification',
  'status',
  'confidence',
  'suspectedCategory',
  'suspectedComponents',
  'reproductionSupported',
  'evidenceUsed',
  'clarificationRequired',
  'recommendedNextAction',
  'possibleDuplicateDefectId',
  'recommendedWorkItemCategory',
  'summary',
];

WorkItem _defectWorkItem() {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: 'defect-D-0001',
    productId: 'p-1',
    category: WorkItemCategory.bugfix,
    title: 'Login button does nothing',
    description: 'Pressing Login does nothing on the staging build.',
    state: WorkItemState.designNotRequired,
    createdAt: now,
    updatedAt: now,
    metadata: {
      'defectId': 'D-0001',
      'defectTitle': 'Login button does nothing',
      'defectSeverity': 'major',
    },
  );
}

String _prompt() =>
    triageDefectInstruction(_defectWorkItem(), triageDefectDefinition);

/// The line of the documented payload that declares `field`, or null.
String? _fieldLine(String prompt, String field) {
  for (final line in prompt.split('\n')) {
    if (line.trimLeft().startsWith('"$field":')) return line;
  }
  return null;
}

/// Every `"..."` token in a payload line's *value* (i.e. after the first
/// colon, so the field name itself is not counted), in declaration order.
List<String> _quotedTokens(String? line) {
  if (line == null) return const [];
  final value = line.substring(line.indexOf(':') + 1);
  return RegExp(
    r'"([^"]*)"',
  ).allMatches(value).map((m) => m.group(1)!).toList();
}

void main() {
  group('lane M: triage prompt documents real wire tokens', () {
    test('classification documents every DefectClassification wire token', () {
      final prompt = _prompt();
      final documented = _quotedTokens(_fieldLine(prompt, 'classification'));

      expect(
        documented,
        DefectClassification.values.map((c) => c.wire).toList(),
        reason:
            'The prompt must document exactly the DefectClassification '
            'wire tokens, in enum order. The old prompt documented '
            'UPPER_SNAKE display names, which DefectClassification.fromWire '
            'rejects.',
      );
    });

    test('classification does not document display names or upper case', () {
      final documented = _quotedTokens(_fieldLine(_prompt(), 'classification'));

      for (final classification in DefectClassification.values) {
        expect(
          documented,
          isNot(contains(classification.wire.toUpperCase())),
          reason: '${classification.wire.toUpperCase()} is not a wire token.',
        );
        expect(
          documented,
          isNot(contains(classification.name)),
          reason:
              '${classification.name} is a Dart member name, not the '
              'serialised token.',
        );
      }
    });

    test('the default-classification rule names the wire token too', () {
      final prompt = _prompt();
      final rule = prompt
          .split('\n')
          .firstWhere(
            (line) => line.contains('cannot determine classification'),
          );

      expect(
        _quotedTokens(rule),
        contains(DefectClassification.implementationDefect.wire),
        reason:
            'The fallback rule is the value a model is most likely to '
            'copy verbatim, so it must carry the wire token as well.',
      );
    });

    test('every documented status is a real DefectStatus wire token', () {
      final documented = _quotedTokens(_fieldLine(_prompt(), 'status'));

      expect(documented, isNotEmpty, reason: 'status must be documented');
      final wires = DefectStatus.values.map((s) => s.wire).toSet();
      for (final token in documented) {
        expect(
          wires,
          contains(token),
          reason:
              '"$token" is not a DefectStatus wire token. DefectStatus has '
              'no "triaged" member; the triage-stage token is "triaging".',
        );
      }
    });

    test('status documents the triage-stage token, not a non-existent one', () {
      expect(_quotedTokens(_fieldLine(_prompt(), 'status')), ['triaging']);
      expect(
        () => DefectStatus.fromWire('triaged'),
        throwsFormatException,
        reason:
            'Guard the premise: "triaged" must remain non-parseable, so '
            'the prompt must never document it.',
      );
    });

    test('recommendedWorkItemCategory documents WorkItemCategory names', () {
      final documented = _quotedTokens(
        _fieldLine(_prompt(), 'recommendedWorkItemCategory'),
      );

      expect(
        documented,
        WorkItemCategory.values.map((c) => c.name).toList(),
        reason:
            'WorkItemCategory has no wire field, so it serialises by name. '
            'The old prompt documented "bug" and "design", which are not '
            'members, and omitted refactor/security/performance.',
      );
    });

    test('recommendedNextAction keeps the parser default available', () {
      final documented = _quotedTokens(
        _fieldLine(_prompt(), 'recommendedNextAction'),
      );

      expect(
        documented,
        contains('investigate'),
        reason:
            'investigate is the value TriageProcessor._parseTriageResult '
            'falls back to when the field is absent.',
      );
    });
  });

  group('lane M: triage prompt still does its actual job', () {
    test('requires a single structured JSON object with no prose', () {
      final prompt = _prompt();

      expect(prompt, contains('STRUCTURED JSON'));
      expect(prompt, contains('Do NOT include any prose outside the JSON'));
    });

    test('documents every field name the parser reads', () {
      final prompt = _prompt();

      for (final field in parserReadFieldNames) {
        expect(
          _fieldLine(prompt, field),
          isNotNull,
          reason: 'The parser reads "$field"; the prompt must document it.',
        );
      }
    });

    test('keeps the structured payload as the whole output', () {
      final prompt = _prompt();

      expect(prompt, contains('"clarificationRequired": ['));
      expect(prompt, contains('{"question":'));
      expect(prompt, contains('"reason":'));
      // Nothing after the RULES section may reintroduce prose after the JSON.
      expect(prompt, contains('RULES:'));
    });

    test('still inlines the defect details the agent needs', () {
      final prompt = _prompt();

      expect(prompt, contains('D-0001'));
      expect(prompt, contains('Login button does nothing'));
      expect(prompt, contains('DEFECT DETAILS:'));
      expect(prompt, contains('EVIDENCE:'));
      expect(prompt, contains('YOUR TASK:'));
    });
  });
}

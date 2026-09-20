import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/shared/decision_choice.dart';

void main() {
  group('decisionChoiceLabel', () {
    test('maps every known wire value to human-facing copy', () {
      // The design speaks in plain language: a choice is never labelled with
      // its wire value or with workflow jargon.
      expect(decisionChoiceLabel('approve'), 'Approve');
      expect(decisionChoiceLabel('reject'), 'Reject');
      expect(decisionChoiceLabel('waive'), 'Skip the check');
      expect(decisionChoiceLabel('rework'), 'Request changes');
      expect(decisionChoiceLabel('cancel'), 'Stop this work');
      expect(decisionChoiceLabel('defer'), 'Defer');

      // No known value may leak its raw wire form.
      for (final value in knownDecisionChoices) {
        expect(decisionChoiceLabel(value), isNot(value), reason: value);
      }
    });

    test('phrases the same choice per decision type', () {
      // An escalation approves by resuming; a design gate approves a design.
      expect(
        decisionChoiceLabel('approve', decisionType: 'escalation'),
        'Resume',
      );
      expect(
        decisionChoiceLabel('cancel', decisionType: 'escalation'),
        'Stop this work',
      );
      expect(
        decisionChoiceLabel('approve', decisionType: 'design_approval'),
        'Approve',
      );
    });

    test('returns unknown values verbatim (never fabricated)', () {
      expect(decisionChoiceLabel('escalate'), 'escalate');
    });

    test('falls back to the caller-provided label for unknown values', () {
      expect(
        decisionChoiceLabel('escalate', fallback: 'Escalate to owner'),
        'Escalate to owner',
      );
    });
  });

  group('isKnownDecisionChoice', () {
    test('accepts all wire enum values and rejects everything else', () {
      for (final value in [
        'approve',
        'reject',
        'waive',
        'rework',
        'cancel',
        'defer',
      ]) {
        expect(isKnownDecisionChoice(value), isTrue, reason: value);
      }
      expect(isKnownDecisionChoice('Approve'), isFalse);
      expect(isKnownDecisionChoice('opt-1'), isFalse);
      expect(isKnownDecisionChoice(''), isFalse);
    });
  });

  test('DecisionChoiceOption carries the value submitted to the wire', () {
    const option = DecisionChoiceOption(
      value: 'approve',
      label: 'Approve',
      description: 'Proceed',
      recommended: true,
    );
    expect(option.value, 'approve');
    expect(option.label, 'Approve');
    expect(option.description, 'Proceed');
    expect(option.recommended, isTrue);
    const defaulted = DecisionChoiceOption(value: 'defer', label: 'Defer');
    expect(defaulted.recommended, isFalse);
  });
}

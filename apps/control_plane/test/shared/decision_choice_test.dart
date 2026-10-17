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
      expect(decisionChoiceLabel('re_triage'), 'Re-triage');

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

    group('the re-triage choice is LABELLED, not merely routable', () {
      // Routing `re_triage` correctly and rendering it are different
      // properties, and only the second one is this file's. Without the
      // `knownDecisionChoices` entry the label lookup is skipped entirely and
      // the operator is handed caller prose; without the default-arm entry the
      // fallback shows the raw wire. Both fail the loop above, which is why
      // `re_triage` has to be in BOTH places rather than either.
      test('it is a known choice, so the label lookup is not skipped', () {
        expect(isKnownDecisionChoice('re_triage'), isTrue);
        expect(knownDecisionChoices, contains('re_triage'));
      });

      test('the generic arm maps it even with no decision type', () {
        expect(decisionChoiceLabel('re_triage'), 'Re-triage');
        expect(
          decisionChoiceLabel(
            're_triage',
            fallback: 'whatever the caller wrote',
          ),
          'Re-triage',
          reason:
              'a caller label is a FALLBACK, for values this file does not '
              'know. It must not override a known wire.',
        );
      });

      test('the park phrases its own four answers', () {
        // The per-type layer exists so the same wire means different words on
        // different gates — `approve` resumes an escalation and IS the design
        // review here. The park's wording is the design's, and it is asserted
        // rather than left to a reader to infer from the enum.
        expect(
          decisionChoiceLabel('approve', decisionType: 'design_review_request'),
          'Do the design review',
        );
        expect(
          decisionChoiceLabel('rework', decisionType: 'design_review_request'),
          'Put it back in the lane',
        );
        expect(
          decisionChoiceLabel(
            're_triage',
            decisionType: 'design_review_request',
          ),
          'Re-triage',
        );
        expect(
          decisionChoiceLabel('cancel', decisionType: 'design_review_request'),
          'Stop',
        );
      });

      test('the park does not relabel answers it was not offered', () {
        // The per-type arm is a lookup, not a menu. It must not invent
        // phrasing for a wire the park does not raise, and it must not change
        // what another gate shows for the same wire.
        expect(
          decisionChoiceLabel('waive', decisionType: 'design_review_request'),
          'Skip the check',
          reason: 'falls through to the generic arm, unchanged',
        );
        expect(
          decisionChoiceLabel('approve', decisionType: 'design_approval'),
          'Approve',
          reason:
              'the park is a DIFFERENT gate from design_approval. Re-labelling '
              'one relabels the other, which is exactly why this is per-type.',
        );
        expect(
          decisionChoiceLabel('approve', decisionType: 'escalation'),
          'Resume',
        );
      });

      test(
        'non-vacuity: an unregistered value still falls back to the wire',
        () {
          // The control for the whole group. If this changed to a mapped label,
          // the "no raw wire leaks" loop above would be satisfied by a table
          // that fabricates copy for values it does not know — which the file's
          // own contract forbids.
          expect(decisionChoiceLabel('escalate'), 'escalate');
        },
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
        're_triage',
      ]) {
        expect(isKnownDecisionChoice(value), isTrue, reason: value);
      }
      expect(isKnownDecisionChoice('Approve'), isFalse);
      expect(isKnownDecisionChoice('opt-1'), isFalse);
      expect(isKnownDecisionChoice(''), isFalse);
    });

    test('the set is LABELLED COPY, not the set of choices on offer', () {
      // Worth pinning because the two used to read as the same thing and the
      // file's own doc comment said so. A choice is offered wherever a
      // decision's own option list names it, so this set says nothing about
      // what any operator is shown — it says which wires have a mapped label.
      // `still_broken` and `partially_fixed` are the standing counter-example:
      // real wires, not in this set, and `decision_choice.dart` is not where
      // that gets decided.
      expect(
        knownDecisionChoices,
        hasLength(7),
        reason: 'six pre-existing wires plus re_triage',
      );
      expect(knownDecisionChoices, isNot(contains('still_broken')));
      expect(knownDecisionChoices, isNot(contains('partially_fixed')));
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

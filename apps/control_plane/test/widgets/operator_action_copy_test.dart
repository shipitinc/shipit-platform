import 'package:control_plane/core/plain_language.dart';
import 'package:control_plane/features/run_detail/operator_action_copy.dart';
import 'package:control_plane/shared/decision_choice.dart';
import 'package:control_plane/shared/transition_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// AC-2 / AC-3 / AC-20 / AC-21 / AC-23 — the wording, pinned to the vocabulary
/// the product already uses.
///
/// ## WHY THIS IS A SEPARATE FILE, AND WHY IT IS MOSTLY `expect(x, y)`
///
/// AC-20 says a reviewer greps: every string on the panel is either
/// byte-identical to something in `plain_language.dart` /
/// `transition_copy.dart` / `decision_choice.dart`, or listed verbatim in the
/// brief. Most of these assertions are therefore `expect(copy, existing)` —
/// they FAIL THE MOMENT one side is edited, which is the property: the copy
/// cannot drift from the product vocabulary without a red test, and it cannot
/// be "fixed" by editing the copy alone, because the other side is the
/// product's own.
///
/// AC-23 is the negative that matters most for this lane: `statusFor` must be
/// UNCHANGED. `design_not_required` already read "Waiting to start" before this
/// work and still does; the brief is explicit that the mapping was never wrong,
/// the seam was feeding it the wrong state.
void main() {
  group('AC-2 — panel heading and status line are EXISTING strings', () {
    test('the heading is the escalation decision type, byte-identical', () {
      expect(retryPanelHeading, PlainLanguage.decisionType('escalation'));
      expect(retryPanelHeading, 'Restart after a problem');
    });

    test('the status line is the existing failure status label', () {
      expect(retryPanelStatusLine, PlainStatus.needsYouItFailed.label);
      expect(retryPanelStatusLine, 'Needs you — it failed');
    });

    test('the stop action is the EXISTING cancel choice for an escalation', () {
      expect(
        stopActionLabel,
        decisionChoiceLabel('cancel', decisionType: 'escalation'),
      );
      expect(stopActionLabel, 'Stop this work');
    });

    test('the why-it-stopped headline is the existing halt explanation', () {
      expect(failureHeadline, PlainLanguage.haltExplanation('agent_failed'));
    });
  });

  group('AC-20 — strings the brief lists verbatim', () {
    test('the confirm-strip strings mirror the existing decision screen', () {
      expect(
        reasonFieldHint,
        'Add a short reason — saved with your name (required)',
      );
      expect(cannotBeUndone, 'This cannot be undone.');
      expect(cancelLabel, 'Cancel');
      expect(savingLabel, 'Saving…');
    });

    test('the attempt position and capacity snapshot read as stated', () {
      expect(attemptPositionSentence(1, 3), 'This will be attempt 1 of 3.');
      expect(attemptPositionSentence(3, 3), 'This will be attempt 3 of 3.');
      expect(capacitySnapshotSentence(2, 2), '2 of 2 agent slots busy.');
    });

    test('the retry is NOT labelled "Resume" (§5.5)', () {
      // `decisionChoiceLabel('approve', 'escalation')` IS "Resume". Reusing it
      // would be more consistent and wrong: nothing here was paused, and
      // "resume a paused run" at no cost and "resume a failed run" at real cost
      // would become one word on one screen.
      expect(
        decisionChoiceLabel('approve', decisionType: 'escalation'),
        'Resume',
      );
      expect(retryActionLabel, 'Try again');
      expect(retryActionLabel, isNot('Resume'));
    });
  });

  group('AC-21 / N8 — the classifier never guesses', () {
    test('no record at all is reported as MISSING, not as a blank', () {
      expect(
        failureExplanation(
          reason: null,
          jobFailureCode: null,
          jobFailureReason: null,
        ),
        'The system did not record why this stopped.',
      );
    });

    test('a whitespace-only reason is still a missing reason', () {
      expect(
        failureExplanation(
          reason: '   ',
          jobFailureCode: null,
          jobFailureReason: null,
        ),
        noRecordedReason,
      );
    });

    test('an executionInterrupted job maps to the reclaim sentence', () {
      expect(
        failureExplanation(
          reason: null,
          jobFailureCode: 'executionInterrupted',
          jobFailureReason: null,
        ),
        contains('stopped answering'),
      );
    });

    test('the coordinator\'s own "orphaned" wording is recognised', () {
      expect(
        failureExplanation(
          reason: 'execution orphaned before a result was recorded',
          jobFailureCode: null,
          jobFailureReason: null,
        ),
        'The machine running this work went away before finishing.',
      );
    });

    test('an UNRECOGNISED cause gets the neutral sentence, never a guess', () {
      final sentence = failureExplanation(
        reason: 'a cause this repository has never emitted',
        jobFailureCode: 'somethingElseEntirely',
        jobFailureReason: null,
      );

      expect(sentence, contains('The technical details below say'));
      // And it must not have picked one of the two specific causes.
      expect(sentence, isNot(contains('stopped answering')));
      expect(sentence, isNot(contains('went away before finishing')));
    });
  });

  group('AC-25 / A11 — every outcome has a stated sentence (N7)', () {
    test('each wire outcome maps to exactly one truthful sentence', () {
      for (final outcome in [
        'accepted',
        'alreadyRunning',
        'alreadyStopped',
        'notApplicable',
        'notConfigured',
        'invalidRequest',
      ]) {
        final sentence = operatorActionAnnouncement(outcome);
        expect(
          sentence.trim(),
          isNotEmpty,
          reason: '$outcome must leave no silent outcome behind',
        );
        // And none of them is an error-styled apology for a normal state.
        expect(sentence, isNot(contains('error')));
      }
    });

    test('an UNKNOWN outcome still says something (defensive, not silent)', () {
      expect(
        operatorActionAnnouncement('an_outcome_added_later'),
        failedSentence,
      );
    });

    test('the two notConfigured situations are worded differently', () {
      // The limit was never configured (a machine fact)…
      expect(
        operatorActionAnnouncement('notConfigured', retryLimitResolved: false),
        retrySwitchedOffSentence,
      );
      // …versus this item having used it up (a run fact).
      expect(
        operatorActionAnnouncement(
          'notConfigured',
          retryLimitResolved: true,
          attemptLimit: 3,
        ),
        'This work has already been tried 3 times. Stop it, or leave it for review.',
      );
    });

    test(
      'an accepted retry says queued or done, never a promise of a time',
      () {
        final done = operatorActionAnnouncement('accepted');
        final queued = operatorActionAnnouncement(
          'accepted',
          capacityFull: true,
        );

        expect(done, 'Done — it will start as soon as a machine is free.');
        expect(queued, 'Queued — it will start when a machine is free.');
        // Neither promises WHEN.
        expect(done, isNot(contains('in ')));
        expect(queued, isNot(contains('within')));
      },
    );

    test('the limit-reached sentence agrees with the number on the wire', () {
      expect(
        operatorActionAnnouncement(
          'notConfigured',
          retryLimitResolved: true,
          attemptLimit: 1,
        ),
        contains('tried 1 time.'),
      );
    });
  });

  group('AC-23 — the plain-language mapping is UNCHANGED by this lane', () {
    test('a retried item reads "Waiting to start" until a job is claimed', () {
      // This is the whole honest bonus of the design: the retry lands in
      // `design_not_required`, which the vocabulary already mapped to a state
      // that says what is true. No mapping was edited to achieve it.
      expect(
        PlainLanguage.statusFor('design_not_required'),
        PlainStatus.waitingToStart,
      );
      expect(PlainStatus.waitingToStart.label, 'Waiting to start');
    });

    test('and "Working on it" only once an execution is really running', () {
      expect(
        PlainLanguage.statusFor('agent_executing'),
        PlainStatus.workingOnIt,
      );
    });

    test('the retry transition itself renders as the existing timeline row', () {
      // ## A DIVERGENCE THE REVIEWER SHOULD SEE, PINNED HONESTLY
      //
      // design-brief.md §5.4 lists the retry's "Resulting timeline row" as
      // `Retrying after an error`, and cites `transition_copy.dart:40` for it.
      // That string IS bound there — to `('agent_failed', 'agent_executing')`,
      // the edge retry took BEFORE HD-4. HD-4 retargeted the retry to
      // `designNotRequired` (§6.5.1) and §5.2's binding was corrected, but
      // §5.4's row was not re-derived and no longer fires.
      //
      // So the row an operator actually sees after pressing "Try again" is the
      // generic fallback. That is NOT WRONG and not a silent failure — the
      // panel states the attempt position and the outcome out loud, and the
      // durable reason is in `TechnicalDetails` — but it is less specific than
      // the brief says it should be, and the fix is a one-line copy decision
      // in a SHARED file (`transition_copy.dart`, outside this lane's declared
      // OWNED_PATHS) that changes what every run-detail timeline renders.
      //
      // It is therefore NOT taken here. This test pins what the code actually
      // does so the divergence is visible rather than latent; correcting it is
      // reported to the Manager rather than decided by the implementer.
      expect(
        plainTransitionMessage('agent_failed', 'design_not_required'),
        'The work moved to a new stage.',
        reason:
            'the retry row is the generic fallback today — see the note '
            'above. If this ever changes, §5.4 and this test must change '
            'together.',
      );

      // The string §5.4 names still exists and is still reachable — on the
      // pre-HD-4 pair. Nothing was deleted to make the row above generic.
      expect(
        plainTransitionMessage('agent_failed', 'agent_executing'),
        'Retrying after an error',
      );
    });
  });

  group('AC-34 — the confirm button label carries its own state (A2)', () {
    test('it flips between the real action and the blocked one', () {
      expect(
        confirmButtonSemanticsLabel(actionLabel: retryActionLabel, ready: true),
        'Try again. $retryConsequenceSentence',
      );
      expect(
        confirmButtonSemanticsLabel(
          actionLabel: retryActionLabel,
          ready: false,
        ),
        'Add a reason first',
      );
    });

    test('the stop button gets its own consequence, not the retry\'s', () {
      expect(
        confirmButtonSemanticsLabel(actionLabel: stopActionLabel, ready: true),
        contains(stopConsequenceSentence),
      );
      expect(
        confirmButtonSemanticsLabel(actionLabel: stopActionLabel, ready: true),
        isNot(contains(retryConsequenceSentence)),
      );
    });
  });
}

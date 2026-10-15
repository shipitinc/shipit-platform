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

    test('an UNCUNTED attempt position states no budget at all (B1)', () {
      // `attemptLimit` is a non-nullable `int` on a frozen wire model, so
      // "uncounted" and "zero" share the value `0` — and `0` is the DEFAULT
      // since the 2026-10-12 reversal. The clause is therefore gated on a real
      // count. This is the sentence the panel rendered as "attempt 5 of 0".
      expect(attemptPositionSentence(5, 0), 'This will be attempt 5.');
      expect(attemptPositionSentence(1, 0), 'This will be attempt 1.');

      // The negative, on every shape: no "of 0" may survive anywhere.
      for (final attempt in [1, 2, 5, 17]) {
        expect(attemptPositionSentence(attempt, 0), isNot(contains('of ')));
      }

      // …and the bounded case is untouched, so this is a gate and not a
      // deletion. The existing assertions above pin "of 3"; this pins the
      // whole positive range explicitly.
      for (final limit in [1, 2, 3, 10]) {
        expect(
          attemptPositionSentence(1, limit),
          'This will be attempt 1 of $limit.',
        );
      }
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

    test('a count of ZERO is "switched off", never "tried 0 times" (L2)', () {
      // REACHABLE, and proven so rather than assumed. The server returns
      // `outcome: 'notConfigured'` with `retryLimitResolved: true` and
      // `attemptLimit: 0` for an explicit `SHIPIT_OPERATOR_MAX_RETRIES=0`
      // — `work_item_action_endpoints_test.dart` asserts exactly that triple
      // ("a disabled retry writes nothing"). The old interpolation turned
      // that into "This work has already been tried 0 times", which asserts a
      // spent budget on a machine that deliberately has none.
      expect(
        operatorActionAnnouncement(
          'notConfigured',
          retryLimitResolved: true,
          attemptLimit: 0,
        ),
        retrySwitchedOffSentence,
      );

      // The helper itself, driven directly — it is exported, so a future
      // caller must not be handed the "0 times" reading either.
      expect(retryLimitReachedSentence(0), retrySwitchedOffSentence);
      expect(retryLimitReachedSentence(0), isNot(contains('0 times')));
      expect(retryLimitReachedSentence(0), isNot(contains('0 time')));

      // PRE-EXISTING, not a regression: this interpolation is byte-identical
      // at the base commit. What the 2026-10-12 reversal changed is that `0`
      // became the COMMON value rather than the disabled one, which is what
      // made the wrong reading visible on the default path.
      //
      // A positive count is still stated as a spent budget, unchanged.
      expect(retryLimitReachedSentence(1), contains('tried 1 time.'));
      expect(retryLimitReachedSentence(3), contains('tried 3 times.'));
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

    test('the retry transition renders its own row, not the fallback', () {
      // ## A DIVERGENCE THAT WAS REPORTED, AND IS NOW CLOSED
      //
      // design-brief.md §5.4 lists the retry's "Resulting timeline row" as
      // `Retrying after an error`, and cites `transition_copy.dart:40` for it.
      // That string IS bound there — to `('agent_failed', 'agent_executing')`,
      // the edge retry took BEFORE HD-4. HD-4 retargeted the retry to
      // `designNotRequired` (§6.5.1) and §5.2's binding was corrected, but
      // §5.4's row was not re-derived and the pair had no copy of its own, so
      // an operator pressing "Try again" saw the generic fallback:
      // "The work moved to a new stage."
      //
      // The lane that made the retry land on `design_not_required` did not own
      // `transition_copy.dart`, so it could not close this and pinned the
      // fallback deliberately instead, reporting it to the Manager. This lane
      // owns that file, so the divergence is CLOSED here and the row now says
      // what actually happened.
      expect(
        plainTransitionMessage('agent_failed', 'design_not_required'),
        'Trying again after an error',
        reason:
            'the retry pair must carry its own copy. §5.4 names the retry row; '
            'if this string changes, §5.4 and this test change together.',
      );

      // The pre-HD-4 string is untouched and still reachable on its own pair.
      // Nothing was re-bound to make the row above specific.
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

  group('the review repair — the refusal sentence is the product', () {
    // Every value the endpoint can return other than `accepted` is a refusal.
    // These are all of them, from `review_repair_result.yaml`, so the set is
    // closed and a value the server adds later lands on this path too rather
    // than on a generic string.
    const refusals = [
      'notApplicable',
      'reviewerProducedVerdict',
      'reviewerProducedProse',
      'reviewerOutputUnreadable',
      'alreadyDecided',
      'alreadyRunning',
      'concurrentWrite',
      'invalidRequest',
    ];

    test('every refusal reads as the SERVER\'s own sentence', () {
      for (final outcome in refusals) {
        expect(
          repairOutcomeSentence(outcome, detail: 'server says so'),
          'server says so',
          reason: '$outcome must reach the operator as the server worded it',
        );
      }
    });

    test(
      'NON-VACUITY: substituting the generic failure for any refusal goes red',
      () {
        // The mutation this pins: replacing `detail` with `failedSentence`
        // makes every one of these fail, because "We could not do that. Nothing
        // changed." is exactly what an operator must NOT be told instead.
        for (final outcome in refusals) {
          expect(
            repairOutcomeSentence(outcome, detail: 'server says so'),
            isNot(failedSentence),
          );
        }
      },
    );

    test('an accepted repair is worded by the client, not by the server', () {
      // The one outcome that is not a refusal. The server's `detail` is
      // diagnostic and is deliberately NOT what the success state reads,
      // because the three facts that must be visible afterwards are the
      // client's to state and the server does not know about the receipt.
      expect(
        repairOutcomeSentence('accepted', detail: 'ok'),
        reviewRepairedSentence,
      );
      expect(reviewRepairedSentence, isNot('ok'));
    });

    test('an absent or blank detail never renders an empty region', () {
      // AC-21, applied to the new surface: "nothing to say" must still say
      // something true rather than leaving a hole.
      for (final outcome in refusals) {
        expect(repairOutcomeSentence(outcome), failedSentence);
        expect(repairOutcomeSentence(outcome, detail: '   '), failedSentence);
      }
    });

    test('the success sentence never reads as an approval', () {
      // The specific false state: a repair that leaves the screen looking like
      // the work moved forward.
      expect(reviewRepairedSentence.toLowerCase(), isNot(contains('approved')));
      expect(
        reviewRepairedDecisionFact.toLowerCase(),
        contains('not approved'),
      );
      expect(reviewRepairedReviewFact.toLowerCase(), contains('not finished'));
      expect(
        reviewRepairedRecordFact.toLowerCase(),
        contains('kept on record'),
      );
    });

    test('the offer never borrows a failed-work verb', () {
      const offerWords = [reviewRepairActionLabel, reviewRepairHeading];
      for (final word in offerWords) {
        expect(word, isNot(contains('Try again')));
        expect(word, isNot(contains('Start it again')));
        expect(word, isNot(contains('Stop this work')));
      }
    });
  });
}

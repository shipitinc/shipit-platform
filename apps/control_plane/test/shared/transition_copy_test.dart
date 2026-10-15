import 'dart:io';

import 'package:control_plane/shared/transition_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// The engine's accepted-pair table, enumerated LIVE from its source.
///
/// `control_plane` cannot depend on `workflow_engine` — it is a Flutter app
/// and the engine is a pure Dart package below it — so this cannot call
/// `WorkItemTransitions.isLegalTransition`. Reading the table as text is the
/// same trick `apps/server/test/baseline_verification_wire_test.dart` uses to
/// read a sibling package's source, and it is enough: the pairs are written
/// as `(WorkItemState.a, WorkItemState.b): [` and the engine's own state enum
/// converts them to wire values, so no hand-written snake_case can drift.
///
/// The previous version of this test carried a HARDCODED list "enumerated
/// from source this session". It passed while `agentFailed ->
/// designNotRequired`, `reviewRejected -> designNotRequired`,
/// `waitingForHumanDecision -> designNotRequired` and
/// `waitingForHumanDecision -> planning` were all live edges with no copy —
/// because the list and the table were edited independently. A list that has
/// to be maintained by hand cannot guard a table that has to be maintained by
/// hand; this one is derived.
const _engineTransitionsSource =
    '../../packages/workflow_engine/lib/src/transitions/'
    'work_item_transitions.dart';

/// Every `(from, to)` entry of `_legalTransitions`, in wire values.
Set<(String, String)> _liveEnginePairs() {
  final source = File(_engineTransitionsSource);
  expect(
    source.existsSync(),
    isTrue,
    reason:
        'cannot read the engine transition table at '
        '$_engineTransitionsSource — the drift guard is now worthless if it '
        'silently enumerates nothing',
  );

  final wire = {
    for (final state in WorkItemState.values) state.name: state.wire,
  };
  final entry = RegExp(r'\(WorkItemState\.(\w+), WorkItemState\.(\w+)\):\s*\[');

  final pairs = <(String, String)>{};
  for (final match in entry.allMatches(source.readAsStringSync())) {
    final from = wire[match.group(1)!];
    final to = wire[match.group(2)!];
    expect(
      from,
      isNotNull,
      reason: 'unknown WorkItemState member ${match.group(1)}',
    );
    expect(
      to,
      isNotNull,
      reason: 'unknown WorkItemState member ${match.group(2)}',
    );
    pairs.add((from!, to!));
  }

  expect(
    pairs,
    isNotEmpty,
    reason: 'the regex matched no table entries — it has gone stale',
  );
  return pairs;
}

void main() {
  group('plainTransitionMessage', () {
    test('every engine-accepted pair has dedicated plain copy', () {
      final pairs = _liveEnginePairs();
      final unmatched =
          pairs
              .where((p) => knownTransitionMessage(p.$1, p.$2) == null)
              .toList()
            ..sort((a, b) => '${a.$1}->${a.$2}'.compareTo('${b.$1}->${b.$2}'));
      expect(
        unmatched,
        isEmpty,
        reason:
            'pairs produced by the engine must never hit the neutral '
            'default. Add copy for each in '
            'lib/shared/transition_copy.dart: $unmatched',
      );
    });

    test('the guard actually enumerates the table', () {
      // A guard that silently matches nothing is the failure mode this file
      // replaced. Pin a few pairs that exist, and the count, so a regex that
      // stops matching fails loudly instead of passing on an empty set.
      final pairs = _liveEnginePairs();

      expect(pairs, contains(('draft', 'planning')));
      expect(pairs, contains(('design_not_required', 'agent_executing')));
      expect(pairs, contains(('deployed', 'completed')));
      expect(
        pairs.length,
        greaterThanOrEqualTo(40),
        reason: 'the engine table has ~46 explicit entries',
      );
    });

    test('generic escapes are covered by the wildcard arms', () {
      // `(_, 'cancelled')` and `(_, 'terminated')` cover these without being
      // enumerated, so they are asserted directly rather than via the table.
      for (final state in WorkItemState.values.where((s) => !s.isTerminal)) {
        expect(knownTransitionMessage(state.wire, 'cancelled'), isNotNull);
        expect(knownTransitionMessage(state.wire, 'terminated'), isNotNull);
      }
    });

    test('default copy is plain, not a raw pair', () {
      expect(
        plainTransitionMessage('pending', 'running'),
        'The work moved to a new stage.',
      );
      expect(
        plainTransitionMessage('pending', 'running'),
        isNot('pending -> running'),
      );
    });

    test('known mappings use human copy, never the raw pair', () {
      expect(plainTransitionMessage('draft', 'planning'), 'Work created');
      expect(
        plainTransitionMessage('waiting_for_human_decision', 'deployed'),
        'Deploy approved',
      );
      expect(
        plainTransitionMessage('agent_executing', 'agent_completed'),
        'Agent finished its work',
      );
    });

    test('neutral default does not fabricate semantics for unknown pairs', () {
      expect(
        plainTransitionMessage('weirdFuture', 'alsoFuture'),
        'The work moved to a new stage.',
      );
    });
  });

  group('the rework landings an operator will now see', () {
    // These four pairs are the ones this change put on screen. They are
    // spelled out so a later edit that drops one of them is a named failure
    // rather than something only the table-enumeration test would notice.
    test('a rejected review queues the work instead of resuming it', () {
      expect(
        knownTransitionMessage('review_rejected', 'design_not_required'),
        'Review not approved, work queued to start again',
      );
    });

    test('a human rejection at any gate queues the work', () {
      expect(
        knownTransitionMessage(
          'waiting_for_human_decision',
          'design_not_required',
        ),
        'Changes asked for, work queued to start again',
      );
    });

    test('the operator retry queues the work', () {
      expect(
        knownTransitionMessage('agent_failed', 'design_not_required'),
        'Trying again after an error',
      );
    });

    test('sending an escalation back re-plans it', () {
      expect(
        knownTransitionMessage('waiting_for_human_decision', 'planning'),
        'Sent back to be re-planned',
      );
    });

    test('no copy promises a resume on a state that cannot dispatch', () {
      // `review_rejected -> agent_executing` was deleted with its edge; copy
      // for an impossible pair is a promise the engine will never keep.
      expect(
        knownTransitionMessage('review_rejected', 'agent_executing'),
        isNull,
      );
    });
  });

  group('every DISPATCHABLE state has copy for every visible transition', () {
    // `review_rejected` became dispatchable on 2026-10-12: a human chose to keep
    // the state (rather than collapse a rejected review into
    // `design_not_required`) and to make it dispatchable, so a rejected
    // engineering review re-enters triage instead of being a dead end.
    //
    // Dispatchable means the scheduler will now put work on an item sitting in
    // that state, so every transition an operator can see leaving it has to say
    // something true. The table-enumeration test above already proves no
    // accepted pair falls through to the neutral default; this pins the two
    // pairs a rejected review can actually take, by name, so an edit to either
    // string is a named failure rather than something only a regex noticed.
    test('both ways out of a rejected review carry their own copy', () {
      expect(
        plainTransitionMessage('review_rejected', 'design_not_required'),
        'Review not approved, work queued to start again',
        reason:
            'the item is queued to start again — this is what "dispatchable" '
            'means, and the copy is what tells the operator their rejection '
            'did not stop the work',
      );
      expect(
        plainTransitionMessage('review_rejected', 'design_in_review'),
        'Changes asked for, design updated',
      );
    });

    test('the rejection itself is still visible as its own event', () {
      // The reason option B was chosen: the operator can see "you rejected
      // this" rather than a state that reads like a design decision.
      expect(
        plainTransitionMessage('waiting_for_human_decision', 'review_rejected'),
        'Review not approved',
      );
    });

    test('the copy for a dispatchable rejected review promises no immediate '
        'execution', () {
      // `agent_executing` asserts an execution is ALREADY running, which is
      // exactly what `review_rejected -> agent_executing` used to (wrongly)
      // claim. If that edge is ever restored, this row is where the operator
      // would be told something untrue, and there must be copy for it before
      // it is.
      expect(
        knownTransitionMessage('review_rejected', 'agent_executing'),
        isNull,
        reason:
            'copy for this pair does not exist and must not be added while '
            'the edge does not exist',
      );
      expect(
        plainTransitionMessage('review_rejected', 'design_not_required'),
        isNot(contains('Agent started work')),
        reason:
            '"Agent started work" is the `-> agent_executing` copy. Reusing it '
            'for a queued item would claim a running execution that has not '
            'happened yet.',
      );
    });
  });

  group('technical truth preservation', () {
    test('raw pair is always retrievable for known transitions', () {
      expect(
        rawTransitionPair('waiting_for_human_decision', 'deployed'),
        'waiting_for_human_decision -> deployed',
      );
    });

    test('raw pair is always retrievable for unknown transitions', () {
      expect(rawTransitionPair('pending', 'running'), 'pending -> running');
    });
  });
}

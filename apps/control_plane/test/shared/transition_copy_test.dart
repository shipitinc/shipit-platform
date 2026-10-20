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
  // `\s` between every token and an OPTIONAL trailing comma: entries whose
  // key is too long for one line are reflowed by `dart format` into the
  // three-line `(\n  WorkItemState.a,\n  WorkItemState.b,\n): [` form, and
  // the previous single-line-only pattern silently dropped every pair that
  // happened — `featureIntakeParked -> waitingForHumanDecision` vanished
  // from the enumeration in exactly that way (the reflow is recorded in
  // `packages/workflow_engine/test/feature_park_way_out_test.dart`), and a
  // pair with no copy stayed invisible to this guard for as long as the
  // format held. A guard whose coverage depends on line width guards
  // nothing.
  final entry = RegExp(
    r'\(\s*WorkItemState\.(\w+)\s*,\s*WorkItemState\.(\w+)\s*,?\s*\)\s*:\s*\[',
  );

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

const _copySource = 'lib/shared/transition_copy.dart';

/// Every explicit `('from', 'to') =>` key of the copy table, parsed from
/// source for the same reason the engine table is: a hand-maintained mirror
/// of either side cannot guard the pair. The wildcard arms
/// `(_, 'cancelled')` / `(_, 'terminated')` are deliberately NOT keys — they
/// are the generic escapes, asserted directly in their own test below.
Set<(String, String)> _liveCopyKeys() {
  final source = File(_copySource);
  expect(
    source.existsSync(),
    isTrue,
    reason:
        'cannot read the copy table at $_copySource — the separation '
        'guard is worthless if it silently enumerates nothing',
  );

  final keys = <(String, String)>{
    for (final match in RegExp(
      r"\(\s*'(\w+)'\s*,\s*'(\w+)'\s*\)\s*=>",
    ).allMatches(source.readAsStringSync()))
      (match.group(1)!, match.group(2)!),
  };

  expect(
    keys,
    isNotEmpty,
    reason: 'the copy-key regex matched no arms — it has gone stale',
  );
  return keys;
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
      // The longest key in the engine table, and the one a format run
      // reflowed onto three lines — the pair the old single-line regex
      // stopped watching without a sound. Pinned by name so a regex edit
      // that only ever sees one-line keys fails here first.
      expect(
        pairs,
        contains(('feature_intake_parked', 'waiting_for_human_decision')),
        reason:
            'multi-line table entries must be enumerated — this pair was '
            'silently lost to a format reflow once already',
      );
      expect(
        pairs.length,
        greaterThanOrEqualTo(57),
        reason:
            'the engine table has 57 explicit entries; the count is a FLOOR '
            'so a regex that stops matching (a reflow, a pattern edit) fails '
            'loudly, not a ceiling — an edge added without copy is named by '
            'the enumeration test above, never by a count pin',
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

  group('copy and the transition table stay separate', () {
    // Adding a MESSAGE must never be able to look like adding an EDGE. The
    // table-enumeration test above pins engine ⊆ copy; this pins the other
    // direction — a copy key for a pair the engine does not accept is a
    // promise the engine will never keep, which is the same defect the
    // `review_rejected -> agent_executing` assertions in the rework group
    // name from the other side. One direction without the other is how
    // `('planned', 'design_in_review')` survived: copy for a pair no engine
    // table has ever contained, carried since the file's first commit.
    test('no copy key claims an edge the engine does not accept', () {
      final engine = _liveEnginePairs();
      final copyKeys = _liveCopyKeys();
      final impossible = copyKeys.difference(engine).toList()
        ..sort((a, b) => '${a.$1}->${a.$2}'.compareTo('${b.$1}->${b.$2}'));

      expect(
        impossible,
        isEmpty,
        reason:
            'copy may only describe transitions the engine already accepts — '
            'a key here never makes a transition legal. Remove the key or '
            'the impossible pair: $impossible',
      );
    });
  });

  group('the parks an operator will now see', () {
    // The six park edges — feature intake (ddfbfff) and design (44c8d0b) —
    // arrived in the engine table without any copy, which is the red this
    // change closes. Each string is pinned so a later edit is a named
    // failure rather than something only the table-enumeration test notices.
    test('a feature intake request is accepted, never refused', () {
      expect(
        knownTransitionMessage('planned', 'feature_intake_parked'),
        'Feature accepted and parked — not refused, not failed',
        reason:
            'no consumer runtime exists for feature work; the operator must '
            'read "parked on purpose", not "something refused this"',
      );
    });

    test('a feature recovered from the wrong lane says so', () {
      expect(
        knownTransitionMessage('agent_executing', 'feature_intake_parked'),
        'Wrong lane — feature returned to its intake park',
        reason:
            'the interrupted run was a defect-lane dispatch of a feature — '
            'the copy must not read as a build that finished or failed',
      );
    });

    test('a design remediation parks instead of progressing', () {
      expect(
        knownTransitionMessage('planned', 'design_parked'),
        'Design remediation parked — cannot start yet',
      );
    });

    test(
      'the release from the design park names the contract that freed it',
      () {
        expect(
          knownTransitionMessage('design_parked', 'design_required'),
          'Design contract in place, released from parking',
          reason:
              'the guard on this edge is designContractExists() over the '
              'durable column and a store — the copy says why the item '
              'moved without promising a design run that has not started',
        );
      },
    );

    test('both parks reach the human gate with their own copy', () {
      expect(
        knownTransitionMessage(
          'feature_intake_parked',
          'waiting_for_human_decision',
        ),
        'Parked feature sent to you for a decision',
      );
      expect(
        knownTransitionMessage('design_parked', 'waiting_for_human_decision'),
        'Parked design sent to you for a decision',
        reason:
            'the park is in no entry state, so this gate is the parks only '
            'non-cancel exit — it must be visible on the timeline, not the '
            'neutral default',
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

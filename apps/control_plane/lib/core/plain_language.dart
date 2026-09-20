import 'package:flutter/material.dart';

import '../shared/detail_sections.dart';
import 'design_tokens.dart';

/// How a durable state is presented to a human operator.
///
/// The Penpot design is explicit about this: the surface never prints a raw
/// state enum. `agent_executing` reads "Working on it";
/// `waiting_for_human_decision` reads "Needs your approval". The raw wire value
/// is only ever shown inside the collapsed "Show technical details" block.
///
/// The five labels, their text tones and their 2px tick colours are transcribed
/// from the `BP · All work · Light` / `· Dark` boards:
///
/// | label                 | text tone     | tick     |
/// |-----------------------|---------------|----------|
/// | Working on it         | inkSecondary  | accent   |
/// | Needs your approval   | attention     | amber    |
/// | Needs you — it failed | negative      | red      |
/// | Finished              | positive      | green    |
/// | Waiting to start      | inkSecondary  | accent   |
enum PlainStatus {
  /// The system is actively doing the work.
  workingOnIt('Working on it'),

  /// Blocked on a human decision — the operator is the next actor.
  needsYourApproval('Needs your approval'),

  /// Blocked on a human decision *because something failed*.
  needsYouItFailed('Needs you — it failed'),

  /// Reached a terminal, successful end.
  finished('Finished'),

  /// Accepted but not yet picked up.
  waitingToStart('Waiting to start'),

  /// Terminal but not successful, and not awaiting the operator.
  stopped('Stopped');

  const PlainStatus(this.label);

  /// The exact string the design prints.
  final String label;

  /// Text tone for the status cell.
  Color textColor(ShipItPalette palette) => switch (this) {
    PlainStatus.workingOnIt => palette.inkSecondary,
    PlainStatus.waitingToStart => palette.inkSecondary,
    PlainStatus.needsYourApproval => palette.attention,
    PlainStatus.needsYouItFailed => palette.negative,
    PlainStatus.finished => palette.positive,
    PlainStatus.stopped => palette.inkTertiary,
  };

  /// Colour of the 2px leading tick on the row.
  Color tickColor(ShipItPalette palette) => switch (this) {
    PlainStatus.workingOnIt => palette.accentTick,
    PlainStatus.waitingToStart => palette.accentTick,
    PlainStatus.needsYourApproval => palette.attentionTick,
    PlainStatus.needsYouItFailed => palette.negative,
    PlainStatus.finished => palette.positive,
    PlainStatus.stopped => palette.inkTertiary,
  };

  /// True when this row is the operator's turn to act.
  bool get isOperatorTurn =>
      this == PlainStatus.needsYourApproval ||
      this == PlainStatus.needsYouItFailed;
}

/// Translates durable system vocabulary into the operator-facing wording the
/// design mandates.
class PlainLanguage {
  PlainLanguage._();

  /// Maps a durable `WorkItemState` wire value to its operator-facing status.
  ///
  /// [blocked] indicates the work item currently carries a blocking human
  /// decision. The design distinguishes "Needs your approval" from
  /// "Needs you — it failed" by *why* the operator was pulled in, which is a
  /// function of the state the run halted in — not of the decision itself.
  static PlainStatus statusFor(String stateWire, {bool blocked = false}) {
    // A failure that has been escalated to the operator reads differently from
    // a clean approval gate, per `BP · All work` row 3.
    const failureStates = {
      'agent_failed',
      'qa_failed',
      'deployment_failed',
      'review_rejected',
      'design_rejected',
    };

    if (stateWire == 'waiting_for_human_decision' || blocked) {
      return failureStates.contains(stateWire)
          ? PlainStatus.needsYouItFailed
          : PlainStatus.needsYourApproval;
    }

    return switch (stateWire) {
      'draft' ||
      'planned' ||
      'design_not_required' => PlainStatus.waitingToStart,
      'planning' ||
      'design_required' ||
      'design_in_review' ||
      'design_approved' ||
      'agent_executing' ||
      'agent_completed' ||
      'review_in_progress' ||
      'review_approved' ||
      'qa_in_progress' ||
      'qa_passed' ||
      'deploying' ||
      'deployed' => PlainStatus.workingOnIt,
      'completed' || 'done' => PlainStatus.finished,
      'cancelled' || 'terminated' => PlainStatus.stopped,
      // An un-escalated failure is still the system's problem, not the
      // operator's turn — it reads as stopped until a decision is raised.
      'agent_failed' ||
      'qa_failed' ||
      'deployment_failed' ||
      'review_rejected' ||
      'design_rejected' => PlainStatus.needsYouItFailed,
      _ => PlainStatus.workingOnIt,
    };
  }

  /// Human phrasing for a decision type (`Gate Type` in the design).
  ///
  /// Covers every member of `HumanDecisionType`, so an unmapped value can only
  /// mean the domain enum grew — [_humanise] then degrades gracefully instead
  /// of printing a raw wire value to an operator.
  static String decisionType(String wire) => switch (wire) {
    'design_approval' => 'Design approval',
    'design_rejection' => 'Design rejection',
    'qa_waiver' => 'Skip a check',
    'qa_rework' => 'Redo the checks',
    'deployment_approval' => 'Approve going live',
    'deployment_rejection' => 'Block going live',
    'rollback_approval' => 'Approve a rollback',
    // The design's "Restart after a problem" card: a failure handed to a human.
    'escalation' => 'Restart after a problem',
    'policy_exception' => 'Policy exception',
    'product_decision' => 'Product decision',
    'architecture_decision' => 'Architecture decision',
    'engineering_review' => 'Engineering review',
    'human_qa_approval' => 'Your QA approval',
    'destructive_migration_approval' => 'Approve a risky data change',
    'security_decision' => 'Security decision',
    'infrastructure_decision' => 'Infrastructure decision',
    'other_consequential' => 'Needs your call',
    _ => _humanise(wire),
  };

  /// Renders a ref the way the design does: a dim `ref` prefix followed by the
  /// short identifier. Callers pair this with [ShipItType.ref].
  static String refLabel(String id) => 'ref $id';

  /// `42m`, `3h 12m`, or `—` when there is nothing to measure.
  ///
  /// Matches `Row Age` in the design: minutes below an hour, `Xh MMm` above,
  /// zero-padded minutes.
  static String elapsed(Duration? d) {
    if (d == null || d.isNegative) return '—';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  /// `waiting 3h 12m` — the `Gate Expiry` phrasing.
  static String waitingFor(Duration? d) => 'waiting ${elapsed(d)}';

  /// `updated 12 seconds ago` — the `Live Sub` phrasing.
  ///
  /// A snapshot can carry a server clock slightly ahead of the browser's, so a
  /// negative age is reported as "just now" rather than as a negative number.
  static String updatedAgo(Duration d) {
    if (d.isNegative || d.inSeconds < 1) return 'updated just now';
    if (d.inSeconds < 60) return 'updated ${d.inSeconds} seconds ago';
    if (d.inMinutes < 60) {
      final m = d.inMinutes;
      return 'updated $m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    final h = d.inHours;
    return 'updated $h ${h == 1 ? 'hour' : 'hours'} ago';
  }

  /// `today at 10:12` / `yesterday at 17:52` / `on 14 Sep at 09:03`.
  ///
  /// The design speaks in relative days rather than dates, which only reads
  /// correctly when measured against a supplied [now].
  static String timeOfDay(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final day = DateTime(when.year, when.month, when.day);
    final today = DateTime(reference.year, reference.month, reference.day);
    final delta = today.difference(day).inDays;
    final clock = timeOnly(when);
    if (delta == 0) return 'today at $clock';
    if (delta == 1) return 'yesterday at $clock';
    return 'on ${when.day} ${_month(when.month)} at $clock';
  }

  /// `09:41`, zero-padded 24h.
  static String timeOnly(DateTime when) =>
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';

  static String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  /// The Overview headline sub: "2 things need your approval."
  static String overviewSubtitle(int waitingOnYou) {
    if (waitingOnYou == 0) return 'Nothing needs your approval.';
    if (waitingOnYou == 1) return '1 thing needs your approval.';
    return '$waitingOnYou things need your approval.';
  }

  /// `in the last day · 4 passed, 1 failed` — the FINISHED metric description.
  static String finishedDescription({
    required int passed,
    required int failed,
  }) {
    return 'in the last day · $passed passed, $failed failed';
  }

  /// What a work item is called on screen.
  ///
  /// The design leads with the plain-language description and shows the
  /// technical title only under "Show technical details" — on the board, H1
  /// reads "Stop duplicate jobs running twice" while
  /// `title: Scheduler claim-CAS dedupe patch` appears in the technical
  /// block. Items with no description fall back to the title so the row is
  /// never blank.
  static String headline({required String title, String? description}) {
    final plain = description?.trim() ?? '';
    return plain.isEmpty ? title : plain;
  }

  /// True when [headline] fell back to the technical title.
  static bool headlineIsTechnical({String? description}) =>
      (description?.trim() ?? '').isEmpty;

  /// Why the run is parked, phrased for an operator, derived from the state
  /// it halted in.
  static String haltExplanation(String stateWire) => switch (stateWire) {
    'design_in_review' =>
      'The design must be checked before the code is written',
    'waiting_for_human_decision' => 'The system needs your decision to go on',
    'review_in_progress' => 'An engineering review is still open',
    'qa_in_progress' => 'The checks are still running',
    'qa_failed' => 'A check did not pass',
    'agent_failed' => 'The work stopped with an error',
    'deployment_failed' => 'Going live did not succeed',
    _ => 'The system needs your decision to go on',
  };

  /// Whether a choice moves work forward, sends it back, or ends it.
  ///
  /// Read from the choice vocabulary the workflow accepts, so the colour of an
  /// option always matches its real effect.
  static OutcomeSentiment sentimentFor(String choice) {
    final value = choice.toLowerCase();
    if (value.contains('approve') ||
        value.contains('resume') ||
        value.contains('proceed') ||
        value.contains('allow')) {
      return OutcomeSentiment.proceed;
    }
    if (value.contains('reject') ||
        value.contains('stop') ||
        value.contains('cancel') ||
        value.contains('turn_down') ||
        value.contains('terminate')) {
      return OutcomeSentiment.stop;
    }
    return OutcomeSentiment.revise;
  }

  /// Turns `snake_case` wire vocabulary into sentence case as a last resort.
  /// Used only for values the design does not enumerate.
  static String _humanise(String wire) {
    if (wire.isEmpty) return wire;
    final words = wire.replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }
}

import 'package:control_plane/core/plain_language.dart';
import 'package:control_plane/features/home/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the operator-facing status mapping in [PlainLanguage.statusFor] and the
/// display helpers on [PlainStatus].
///
/// The durable `WorkItemState` vocabulary is deliberately wider than the seven
/// statuses the design prints; these tests lock the exact mapping so a state
/// can never quietly slide into the wrong bucket.
void main() {
  group('PlainLanguage.statusFor — state buckets', () {
    test('accepted-but-not-started states read as waitingToStart', () {
      for (final state in ['draft', 'planned', 'design_not_required']) {
        expect(
          PlainLanguage.statusFor(state),
          PlainStatus.waitingToStart,
          reason: state,
        );
      }
    });

    test('only the actively-executing states read as workingOnIt', () {
      for (final state in [
        'planning',
        'agent_executing',
        'qa_in_progress',
        'deploying',
      ]) {
        expect(
          PlainLanguage.statusFor(state),
          PlainStatus.workingOnIt,
          reason: state,
        );
      }
    });

    test('hand-off / review states read as awaitingReview', () {
      for (final state in [
        'design_required',
        'design_in_review',
        'design_approved',
        'agent_completed',
        'review_in_progress',
        'review_approved',
        'qa_passed',
        'deployed',
      ]) {
        expect(
          PlainLanguage.statusFor(state),
          PlainStatus.awaitingReview,
          reason: state,
        );
      }
    });

    test('terminal-success states read as finished', () {
      for (final state in ['completed', 'done']) {
        expect(
          PlainLanguage.statusFor(state),
          PlainStatus.finished,
          reason: state,
        );
      }
    });

    test('terminal-without-success states read as stopped', () {
      for (final state in ['cancelled', 'terminated']) {
        expect(
          PlainLanguage.statusFor(state),
          PlainStatus.stopped,
          reason: state,
        );
      }
    });

    test('un-escalated failure states read as needsYouItFailed', () {
      for (final state in [
        'agent_failed',
        'qa_failed',
        'deployment_failed',
        'review_rejected',
        'design_rejected',
      ]) {
        expect(
          PlainLanguage.statusFor(state),
          PlainStatus.needsYouItFailed,
          reason: state,
        );
      }
    });

    test('an unknown state falls back to awaitingReview', () {
      expect(
        PlainLanguage.statusFor('a_state_the_domain_has_not_defined_yet'),
        PlainStatus.awaitingReview,
      );
      expect(PlainLanguage.statusFor(''), PlainStatus.awaitingReview);
    });
  });

  group('PlainLanguage.statusFor — blocked preamble', () {
    test('blocked + non-failure reads as needsYourApproval', () {
      for (final state in [
        'planning',
        'agent_executing',
        'design_in_review',
        'qa_passed',
        'deployed',
      ]) {
        expect(
          PlainLanguage.statusFor(state, blocked: true),
          PlainStatus.needsYourApproval,
          reason: state,
        );
      }
    });

    test('blocked + failure reads as needsYouItFailed', () {
      for (final state in [
        'agent_failed',
        'qa_failed',
        'deployment_failed',
        'review_rejected',
        'design_rejected',
      ]) {
        expect(
          PlainLanguage.statusFor(state, blocked: true),
          PlainStatus.needsYouItFailed,
          reason: state,
        );
      }
    });

    test('waiting_for_human_decision enters the preamble without blocked', () {
      // The state itself means "a human is on the hook", so an unknown-failure
      // state parked there still reads as an approval gate.
      expect(
        PlainLanguage.statusFor('waiting_for_human_decision'),
        PlainStatus.needsYourApproval,
      );
      expect(
        PlainLanguage.statusFor('waiting_for_human_decision', blocked: true),
        PlainStatus.needsYourApproval,
      );
    });
  });

  group('PlainStatus — presentation', () {
    test('awaitingReview prints "Awaiting review"', () {
      expect(PlainStatus.awaitingReview.label, 'Awaiting review');
    });

    test('elapsedVerb is pinned for every status', () {
      const expectedVerbs = <PlainStatus, String>{
        PlainStatus.workingOnIt: 'running',
        PlainStatus.finished: 'took',
        PlainStatus.stopped: 'took',
        PlainStatus.waitingToStart: 'waiting',
        PlainStatus.awaitingReview: 'waiting',
        PlainStatus.needsYourApproval: 'waiting',
        PlainStatus.needsYouItFailed: 'waiting',
      };
      for (final entry in expectedVerbs.entries) {
        expect(entry.key.elapsedVerb, entry.value, reason: entry.key.name);
      }
      // Guard against a new enum member silently inheriting a verb.
      expect(expectedVerbs.keys.toSet(), PlainStatus.values.toSet());
    });

    test('isOperatorTurn is false for awaitingReview and workingOnIt', () {
      expect(PlainStatus.awaitingReview.isOperatorTurn, isFalse);
      expect(PlainStatus.workingOnIt.isOperatorTurn, isFalse);
    });

    test('only the two human-decision statuses are the operator turn', () {
      final operatorTurn = PlainStatus.values
          .where((status) => status.isOperatorTurn)
          .toSet();
      expect(operatorTurn, {
        PlainStatus.needsYourApproval,
        PlainStatus.needsYouItFailed,
      });
    });
  });

  // Regression: `agent_completed` used to render as a system-failure/terminal
  // bucket; the design now surfaces it as a review hand-off. This exercises the
  // same value through the UI-facing `RunSummary` seam (the Overview "What's
  // happening now" row) rather than adding a golden image.
  group('regression — agent_completed surfaces as Awaiting review', () {
    test(
      'RunSummary.status.label is "Awaiting review" for agent_completed',
      () {
        final row = RunSummary(
          id: 'wi-agent-done',
          title: 'Stop duplicate jobs running twice',
          stateWire: 'agent_completed',
          blocked: false,
          startedAt: DateTime(2026, 1, 1),
          elapsed: const Duration(minutes: 12),
        );

        expect(row.status, PlainStatus.awaitingReview);
        expect(row.status.label, 'Awaiting review');
        expect(row.status.isOperatorTurn, isFalse);
      },
    );
  });
}

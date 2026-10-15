import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../shared/design_primitives.dart';
import 'failed_work_item_action_panel.dart' show mintOperatorRequestId;
import 'operator_action_copy.dart';
import 'run_detail_bloc.dart' show ReviewRepairReport;

/// The repair affordance for a work item parked behind a decision that no
/// reviewer ever backed.
///
/// ## WHAT IT IS, AND WHY IT IS NOT ANOTHER BUTTON ON THE PANEL
///
/// A work item can sit in `waiting_for_human_decision` behind a decision the
/// engineering-review gate never actually produced a verdict for. The operator
/// arriving at the run sees "Needs your approval" and an approval button, and
/// answering is the only thing the screen offers — but the question behind that
/// approval is one no reviewer ever answered. So this block offers the other
/// move: retire the decision and put the work back in the queue for a review
/// that actually happens.
///
/// It is deliberately NOT a sibling of "Review and decide". That button is a
/// peer of approving work and this is not a peer of anything: it is a repair for
/// a state that should not exist, so it sits BELOW a rule, after the approval
/// call to action, in the warning tone rather than the primary one, and it is
/// an outline rather than a filled button. Everything about its placement says
/// "after you have looked at the decision", because that is the order in which
/// the operator has to think about it.
///
/// ## THE UI IS NOT THE GUARDRAIL — AND THAT IS WHY THIS IS SAFE
///
/// It would be easy to read "the control only appears when a blocking decision
/// exists" as the safety property. It is not, and this widget does not claim it
/// is. The offer condition is a question ("is there something here that looks
/// parked?"), and the durable answer to "is this actually repairable?" is
/// derived by the SERVER from the reviewer's own durable result. A decision's
/// own `reviewVerdict` is never taken as evidence that anyone reviewed
/// anything.
///
/// So the control can be offered on an item that turns out to be unrepairable,
/// and the server will refuse it. What makes that safe rather than sloppy is
/// what happens next: the refusal's own sentence reaches the operator, verbatim
/// and readable, instead of the request disappearing. "A reviewer really did
/// return a verdict for this" is an answer; a silent no-op is not. An affordance
/// that is wrong about a real review therefore costs the operator a sentence,
/// never a review.
///
/// The reason field works the same way. The button stays disabled until one is
/// typed — a control that spends durable state on a blank intent is a bad
/// control, and the endpoint refuses a blank reason anyway — but that gate is
/// CONVENIENCE, not enforcement, and the copy never implies otherwise. The
/// enforcement lives on the server, where it cannot be skipped by a UI that is
/// wrong.
class ReviewRepairAffordance extends StatelessWidget {
  const ReviewRepairAffordance({
    super.key,
    required this.decisionId,
    this.report,
    this.stripOpen = false,
    this.submitting = false,
    this.onOpen,
    this.onSubmit,
    this.onCancel,
  });

  /// The item's blocking decision, or null when nothing is parked.
  ///
  /// ## THE OFFER CONDITION, IN ONE FIELD
  ///
  /// The whole gate is this parameter being non-null. There is no state
  /// combination, no hidden flag and no "close enough" path into the offer, so
  /// a run with nothing parked renders no control at all — not a disabled one,
  /// not a greyed-out one. A repair control with nothing to repair is the
  /// precise false affordance this whole surface exists to avoid.
  final String? decisionId;

  /// What the last attempt did, or null while none has resolved.
  ///
  /// ## WHY THE RECEIPT IS NOT GATED ON [decisionId]
  ///
  /// A successful repair RETIRES the decision, so `decisionId` is null by the
  /// time the operator needs to read what happened. Gating the receipt on the
  /// offer condition would erase the receipt the instant it became the most
  /// important thing on the screen. The receipt therefore renders on its own
  /// condition — an attempt has resolved — and is a statement about the past,
  /// not an offer of a future action.
  final ReviewRepairReport? report;

  /// True once the operator has opened the confirm strip.
  final bool stripOpen;

  final bool submitting;

  /// Open the confirm strip. Nothing is written yet.
  final VoidCallback? onOpen;

  /// Commit the repair. [reason] is the operator's own words, verbatim.
  final void Function(String reason, String requestId)? onSubmit;

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final resolved = report;
    if (resolved != null) return _RepairReceipt(report: resolved);

    final id = decisionId;
    if (id == null) return const SizedBox.shrink();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: reviewRepairSemanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const ContentRule(),
          const SizedBox(height: 20),
          const MicroLabel(reviewRepairLabel),
          const SizedBox(height: 6),
          Text(
            reviewRepairHeading,
            style: ShipItType.sectionTitle.copyWith(
              color: context.palette.attention,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reviewRepairExplanation,
            style: ShipItType.bodySmall.copyWith(
              color: context.palette.inkSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            reviewRepairGuardrailSentence,
            style: ShipItType.bodyMicro.copyWith(
              color: context.palette.inkTertiary,
            ),
          ),
          const SizedBox(height: 16),
          if (stripOpen)
            _RepairConfirmStrip(
              submitting: submitting,
              onSubmit: onSubmit,
              onCancel: onCancel,
            )
          else
            _RepairOpenButton(onOpen: onOpen),
        ],
      ),
    );
  }
}

/// The offer itself: one outlined, warning-tinted button.
class _RepairOpenButton extends StatelessWidget {
  const _RepairOpenButton({this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        AccentTick(color: palette.attention, height: 28),
        const SizedBox(width: 10),
        // Outlined, never filled. On this screen a filled button IS the
        // approval; an outline keeps the repair visibly subordinate to it, so
        // the two can never be misread as the same class of action.
        OutlinedButton(
          onPressed: onOpen,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.attention,
            side: BorderSide(color: palette.attention),
          ),
          child: const Text(reviewRepairActionLabel),
        ),
      ],
    );
  }
}

/// The confirm strip: a reason, then a button that names its consequence.
class _RepairConfirmStrip extends StatefulWidget {
  const _RepairConfirmStrip({
    required this.submitting,
    this.onSubmit,
    this.onCancel,
  });

  final bool submitting;
  final void Function(String reason, String requestId)? onSubmit;
  final VoidCallback? onCancel;

  @override
  State<_RepairConfirmStrip> createState() => _RepairConfirmStripState();
}

class _RepairConfirmStripState extends State<_RepairConfirmStrip> {
  final TextEditingController _reason = TextEditingController();

  /// Minted ONCE per confirmation and reused for every later submit of the
  /// SAME confirmation — the same rule the retry strip follows, and it is the
  /// load-bearing one here: the server's replay check finds its own audit row
  /// by this key and returns what that request DID without writing again. A
  /// double-click therefore cannot queue a second review. A fresh confirm after
  /// a fresh deliberate choice mints a new id, which is correct — a second
  /// deliberate confirm is a second deliberate spend.
  String? _requestId;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reason = _reason.text.trim();
    final ready = reason.isNotEmpty && !widget.submitting;

    return Focus(
      autofocus: true,
      // Escape cancels, exactly as it does on the retry strip (§9 A5 /
      // AC-26). A destructive-adjacent strip that cannot be walked away from
      // with the keyboard is a WCAG 2.1.1 gap, and this one voids a decision.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AccentTick(color: palette.attention, height: 12),
              const SizedBox(width: 8),
              Text(
                reviewRepairStripHeading,
                style: ShipItType.status.copyWith(color: palette.attention),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reviewRepairConsequenceSentence,
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 10),
          const MicroLabel(whyAreYouDoingThisLabel),
          const SizedBox(height: 6),
          Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: _reason,
              autofocus: true,
              maxLines: 3,
              enabled: !widget.submitting,
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
              decoration: const InputDecoration(hintText: reasonFieldHint),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => ready ? _submit() : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Semantics(
                button: true,
                enabled: ready,
                label: repairConfirmSemanticsLabel(ready: ready),
                child: SizedBox(
                  width: 260,
                  height: 28,
                  child: OutlinedButton(
                    onPressed: ready ? _submit : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.attention,
                      side: BorderSide(color: palette.attention),
                    ),
                    child: Text(
                      widget.submitting
                          ? savingLabel
                          : reviewRepairConfirmLabel,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!widget.submitting)
                InlineLink(label: cancelLabel, onTap: widget.onCancel),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final callback = widget.onSubmit;
    if (callback == null) return;
    // The reason is forwarded VERBATIM. The strip gates on it being non-empty
    // so the operator is not offered a spend they have not described, but the
    // value itself is not inspected, rewritten or trimmed here: the endpoint is
    // the thing that refuses a blank reason, and a client-side second opinion
    // about what counts as a reason would be a rule nothing else in this
    // repository enforces.
    callback(_reason.text.trim(), _requestId ??= mintOperatorRequestId());
  }
}

/// The receipt: what the last attempt actually did.
///
/// ## WHY THE THREE FACTS ARE THREE ROWS
///
/// "Done!" after a repair is a false state in miniature — the decision was
/// retired and not approved, the review is re-queued and not finished, and the
/// old decision still exists as evidence. Those are three separate truths, and
/// folding them into one sentence is how a re-queued review gets read as a
/// finished one. So each gets its own labelled row, which also means a test can
/// assert all three independently.
class _RepairReceipt extends StatelessWidget {
  const _RepairReceipt({required this.report});

  final ReviewRepairReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // A refusal renders the server's own sentence and NOTHING ELSE. There is no
    // "done" headline, no tick and no three-fact list on a refusal, because a
    // refusal wrote nothing — not the decision, not the work item, not an audit
    // row. Dressing one up as progress is precisely the false state this
    // receipt exists to prevent.
    //
    // Note the label is the refusal's own, not the offer's: the sentence below
    // is usually the OPPOSITE of the offer's premise, and stacking "IF NOBODY
    // REVIEWED THIS" over "a reviewer really did return a verdict" would print
    // the claim and its own refutation together.
    if (!report.accepted) {
      return Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const ContentRule(),
            const SizedBox(height: 20),
            const MicroLabel(reviewRepairRefusedLabel),
            const SizedBox(height: 6),
            Text(
              report.sentence,
              style: ShipItType.sectionTitle.copyWith(color: palette.negative),
            ),
          ],
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const ContentRule(),
          const SizedBox(height: 20),
          // The receipt is ONE-WAY on purpose, and that is not an oversight.
          //
          // Every refusal this endpoint returns is a statement about durable
          // state that cannot change under the operator's feet: a reviewer
          // really returned a verdict, a human already answered, nothing is
          // parked. Asking again would be refused again, identically, and an
          // offer that lets someone re-ask a question the server has already
          // answered on the record is an affordance to doubt the answer. So
          // once an attempt has resolved, the receipt stands until the run is
          // left. An ACCEPTED repair is likewise terminal — it retired the
          // decision, so there is nothing left to offer.
          const MicroLabel(reviewRepairLabel),
          const SizedBox(height: 6),
          Text(
            reviewRepairedHeadline,
            style: ShipItType.sectionTitle.copyWith(color: palette.attention),
          ),
          const SizedBox(height: 6),
          Text(
            reviewRepairedSentence,
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 4),
          const DefinitionList(
            entries: [
              DefinitionEntry(
                label: reviewRepairedDecisionLabel,
                value: reviewRepairedDecisionFact,
                prose: true,
              ),
              DefinitionEntry(
                label: reviewRepairedReviewLabel,
                value: reviewRepairedReviewFact,
                prose: true,
              ),
              DefinitionEntry(
                label: reviewRepairedRecordLabel,
                value: reviewRepairedRecordFact,
                prose: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

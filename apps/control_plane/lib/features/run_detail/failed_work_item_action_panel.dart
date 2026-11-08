import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart';
import 'operator_action_copy.dart';

/// Mint one `requestId` for ONE operator intent.
///
/// Called when the operator CONFIRMS, never on page load and never per HTTP
/// attempt. The confirm strip holds the result and re-sends the same value for
/// every network retry of that confirmation, which is what makes a double-click
/// or a lost response unable to spend twice (AC-9, AC-12, §8.3).
///
/// The counter is there because two confirmations inside the same microsecond
/// must still be two ids: a second deliberate confirm is a second deliberate
/// spend, and an id that collided would silently collapse them into one.
int _requestSequence = 0;

String mintOperatorRequestId() {
  _requestSequence += 1;
  return 'op-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '-${_requestSequence.toRadixString(36)}';
}

/// The operator screen for a work item parked in a failure state.
///
/// ## WHAT IT IS FOR
///
/// `agent_failed` is routed to a human on purpose — `RunnableWorkEvaluator`
/// returns `noAction` for it because it is in no `JobDefinition`'s
/// `entryStates` — but the run detail page then rendered "Nothing needs you
/// here" for any item with no blocking decision, which is exactly the item in
/// front of us. So the screen said *"Needs you — it failed"* and *"Nothing
/// needs you here"* in the same view: an actionable screen indistinguishable
/// from a dead one.
///
/// This panel replaces that branch **when, and only when, the server says an
/// action is legal**. The action list is computed server-side from
/// `WorkItemTransitions`; this widget renders what it is given and renders
/// NOTHING for an action id it does not recognise, so an unknown action is
/// inert rather than dangerous (§10 N4).
///
/// ## THE RULES IT ENFORCES, AND WHY EACH IS NOT OPTIONAL
///
///  * **The cost is on the surface, before the commit** (AC-4, N3). A retry
///    starts a real agent execution that spends real model credits, and the
///    panel says what this attempt is out of *and* that it starts from the
///    beginning, before anyone presses anything.
///  * **Nothing commits without an explicit confirm** (AC-5, AC-6, N11). Both
///    actions go through the same inline strip, `stop` as well as `retry`: a
///    terminal, irreversible move is exactly the one that must not be the
///    quicker path.
///  * **The unset limit is VISIBLE, not silently absent** (AC-15d, A11). A
///    missing environment variable is an operator-configuration fact, so it is
///    worded as information and *Stop this work* is still offered — a
///    configuration must never remove the only exit left (HD-1).
///  * **A missing reason is reported as missing** (AC-21). Not an empty
///    region, and not a substituted generic sentence.
class FailedWorkItemActionPanel extends StatelessWidget {
  const FailedWorkItemActionPanel({
    super.key,
    required this.actionContext,
    required this.haltCount,
    required this.now,
    this.pendingAction,
    this.submitting = false,
    this.outcomeAnnouncement,
    this.onRetryPressed,
    this.onStopPressed,
    this.onSubmit,
    this.onCancel,
  });

  final WorkItemActionContextResponse actionContext;

  /// How many times this item has entered the failure state, from its durable
  /// transition history. Drives "stopped N times since it started".
  final int haltCount;
  final DateTime now;

  /// Set once the operator has picked an action; the confirm strip replaces
  /// the button row in place, so the action they pressed is the action that
  /// gets recorded.
  final String? pendingAction;

  final bool submitting;

  /// The live-region sentence for the resolved action, or null while nothing
  /// has resolved yet.
  final String? outcomeAnnouncement;

  final VoidCallback? onRetryPressed;
  final VoidCallback? onStopPressed;
  final void Function(String action, String reason, String requestId)? onSubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final retry = _actionOf('retry');
    final stop = _actionOf('stop');

    return Semantics(
      container: true,
      // The exact pattern and the exact reason `_GateCard` documents: without
      // this the buttons' tap actions merge upward into this node and the whole
      // panel becomes one tappable region, with no cursor change to advertise
      // it. The children keep their own nodes and their own hit areas.
      explicitChildNodes: true,
      label: retryPanelSemanticsLabel,
      child: DesignPanel(
        // The 3px negative edge is the same token as the "Needs you — it failed"
        // row tick, so the panel edge and the row tick agree by construction.
        edgeColor: palette.negative,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The resolved OUTCOME only. The unset-limit sentence is not
            // repeated here: it is already rendered in the body below, and a
            // live region wrapping body text would print it twice on screen
            // while announcing it once. It carries its own live region where it
            // is actually drawn (A11).
            _LiveRegion(message: outcomeAnnouncement),
            Text(
              retryPanelHeading,
              style: ShipItType.sectionTitle.copyWith(
                color: palette.inkPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              retryPanelStatusLine,
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Nothing moves forward until you decide. There is no time '
              'pressure beyond the limits shown.',
              style: ShipItType.bodyMicro.copyWith(color: palette.inkTertiary),
            ),
            const SizedBox(height: 16),
            const MicroLabel(whyItStoppedLabel),
            const SizedBox(height: 6),
            Text(
              failureHeadline,
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              failureExplanation(
                reason: actionContext.failure?.reason,
                jobFailureCode: actionContext.failure?.jobFailureCode,
                jobFailureReason: actionContext.failure?.jobFailureReason,
              ),
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            if (actionContext.failure?.at != null) ...[
              const SizedBox(height: 6),
              Text(
                'Stopped ${PlainLanguage.timeOfDay(actionContext.failure!.at!, now: now)} · stopped $haltCount '
                '${haltCount == 1 ? 'time' : 'times'} since it started.',
                style: ShipItType.bodyMicro.copyWith(
                  color: palette.inkTertiary,
                ),
              ),
            ],
            if (actionContext.priorActions.isNotEmpty) ...[
              const SizedBox(height: 16),
              DefinitionList(
                entries: [
                  for (final prior in actionContext.priorActions)
                    DefinitionEntry(
                      // The label and the verb are the action's own — a
                      // 'reland' or 'reroute' row is not "STARTED AGAIN" and
                      // never was (F-260/F-262).
                      label: priorActionLabelFor(prior.action),
                      value: priorActionSentence(
                        prior.action,
                        prior.requestedBy,
                        PlainLanguage.timeOfDay(prior.at, now: now),
                        prior.reason,
                      ),
                      prose: true,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            const ContentRule(),
            const SizedBox(height: 14),
            const MicroLabel(beforeYouStartLabel),
            const SizedBox(height: 6),
            if (actionContext.capacity.resolved)
              Text(
                capacitySnapshotSentence(
                  actionContext.capacity.inFlight,
                  actionContext.capacity.cap,
                ),
                style: ShipItType.monoMeta.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
            const SizedBox(height: 4),
            if (retry != null)
              Text(
                attemptPositionSentence(
                  retry.attemptNumber ?? 1,
                  retry.attemptLimit,
                ),
                style: ShipItType.status.copyWith(color: palette.attention),
              )
            else
              // AC-15d / A11 — the existing vocabulary, and deliberately NOT
              // styled as an error. A red panel here would misread as "this work
              // is broken". It IS the live region: the absence is announced,
              // not merely seen, because a screen-reader user must not conclude
              // the screen is broken when an environment variable is unset —
              // which is exactly the misreading §6.6.1 exists to prevent.
              Semantics(
                liveRegion: true,
                child: Text(
                  retrySwitchedOffSentence,
                  style: ShipItType.bodyMicro.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            const ContentRule(),
            const SizedBox(height: 14),
            if (pendingAction == null)
              _ActionRow(
                retry: retry,
                stop: stop,
                compact: isMobile(context),
                onRetry: onRetryPressed,
                onStop: onStopPressed,
              )
            else
              _RetryConfirmStrip(
                action: pendingAction!,
                submitting: submitting,
                compact: isMobile(context),
                onSubmit: onSubmit,
                onCancel: onCancel,
              ),
            if (retry != null) ...[
              const SizedBox(height: 10),
              Text(
                retryCostSentence,
                style: ShipItType.bodyMicro.copyWith(
                  color: palette.inkTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  WorkItemActionResponse? _actionOf(String wire) {
    for (final action in actionContext.actions) {
      if (action.action == wire) return action;
    }
    return null;
  }
}

/// Escape cancels the confirm strip.
///
/// §9 A5 / AC-26. The existing `_ConfirmStrip` offers only a tap `InlineLink`,
/// which is a WCAG 2.1.1 gap; this surface closes it for the NEW confirm strip
/// rather than copying the gap. The binding lives on a `Focus` that wraps the
/// strip, so it fires while the autofocused reason field has keyboard focus —
/// which is exactly when a keyboard user is most likely to reach for it.
class _RetryConfirmStrip extends StatefulWidget {
  const _RetryConfirmStrip({
    required this.action,
    required this.submitting,
    required this.onSubmit,
    required this.onCancel,
    this.compact = false,
  });

  final String action;
  final bool submitting;
  final void Function(String action, String reason, String requestId)? onSubmit;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  State<_RetryConfirmStrip> createState() => _RetryConfirmStripState();
}

class _RetryConfirmStripState extends State<_RetryConfirmStrip> {
  final TextEditingController _reason = TextEditingController();

  /// Minted on the FIRST submit of this confirmation and reused for every
  /// later submit of the SAME confirmation, so a double-click, a retry after a
  /// lost response and a retry after a network error all carry one intent and
  /// can spend once. A fresh confirm after a fresh deliberate choice mints a
  /// NEW id, which is correct: a second deliberate confirm is a second
  /// deliberate spend.
  String? _requestId;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isRetry = widget.action == 'retry';
    final label = isRetry ? retryActionLabel : stopActionLabel;
    final accent = isRetry ? palette.attention : palette.negative;
    final ready = _reason.text.trim().isNotEmpty && !widget.submitting;

    return Focus(
      autofocus: true,
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
              AccentTick(color: accent, height: 12),
              const SizedBox(width: 8),
              Text(
                'You chose: $label',
                style: ShipItType.status.copyWith(color: accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isRetry ? retryConsequenceSentence : stopConsequenceSentence,
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
              // The same compromise `_GateCard(compact: true)` already makes
              // and documents: a phone column cannot carry a field and a button
              // row at desktop height.
              maxLines: widget.compact ? 2 : 3,
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
                label: confirmButtonSemanticsLabel(
                  actionLabel: label,
                  ready: ready,
                ),
                child: SizedBox(
                  width: 190,
                  height: 28,
                  child: FilledButton(
                    onPressed: ready ? _submit : null,
                    child: Text(
                      widget.submitting ? savingLabel : 'Save: $label',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!widget.submitting)
                InlineLink(label: cancelLabel, onTap: widget.onCancel),
              const Spacer(),
              Text(
                cannotBeUndone,
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final callback = widget.onSubmit;
    if (callback == null) return;
    callback(
      widget.action,
      _reason.text.trim(),
      _requestId ??= mintOperatorRequestId(),
    );
  }
}

/// The actions, in the server's order, with no action the server did not offer.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.retry,
    required this.stop,
    required this.onRetry,
    required this.onStop,
    this.compact = false,
  });

  final WorkItemActionResponse? retry;
  final WorkItemActionResponse? stop;
  final VoidCallback? onRetry;
  final VoidCallback? onStop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (retry == null && stop == null) return const SizedBox.shrink();

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (retry != null)
            MobilePrimaryButton(
              label: retryActionLabel,
              onPressed: onRetry ?? () {},
            ),
          if (retry != null && stop != null) const SizedBox(height: 8),
          if (stop != null)
            OutlinedButton(onPressed: onStop, child: Text(stopActionLabel)),
        ],
      );
    }

    return Row(
      children: [
        if (retry != null)
          SizedBox(
            width: 150,
            height: 28,
            child: FilledButton(
              onPressed: onRetry,
              child: const Text(retryActionLabel),
            ),
          ),
        if (retry != null && stop != null) const SizedBox(width: 10),
        if (stop != null)
          SizedBox(
            width: 150,
            height: 28,
            child: OutlinedButton(
              onPressed: onStop,
              // A negative edge AND the word "Stop" — never colour alone (A6).
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.negative,
                side: BorderSide(color: palette.negative),
              ),
              child: Text(stopActionLabel),
            ),
          ),
      ],
    );
  }
}

/// The outcome announcement (§9 A3, AC-25).
///
/// `liveRegion` has NO precedent anywhere in this app, which is why it is being
/// introduced here and why the semantics test exists rather than a golden: a
/// golden cannot see a semantics tree at all (AC-34).
class _LiveRegion extends StatelessWidget {
  const _LiveRegion({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: ShipItType.bodyMicro.copyWith(
          color: context.palette.inkSecondary,
        ),
      ),
    );
  }
}

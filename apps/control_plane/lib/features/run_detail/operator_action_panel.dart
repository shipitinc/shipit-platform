import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart';
import 'failed_work_item_action_panel.dart' show mintOperatorRequestId;
import 'operator_action_copy.dart';

/// The operator surface for the two non-failure actions: `deploy` on a
/// QA-passed (or gate-interrupted) item, and `reclaim` on a stranded
/// `agent_executing` item.
///
/// Deliberately a separate widget from [FailedWorkItemActionPanel]: that
/// panel's whole copy is "it failed", which is false for both of these — a
/// `qa_passed` item PASSED, and a stranded item never recorded a failure.
/// What they share is the machinery: the server-computed action list, the
/// confirm strip, and the once-per-intent request id.
class OperatorActionPanel extends StatelessWidget {
  const OperatorActionPanel({
    super.key,
    required this.actionContext,
    required this.pendingAction,
    required this.submitting,
    this.outcomeAnnouncement,
    this.onActionPressed,
    this.onSubmit,
    this.onCancel,
  });

  final WorkItemActionContextResponse actionContext;
  final String? pendingAction;
  final bool submitting;
  final String? outcomeAnnouncement;
  final void Function(String action)? onActionPressed;
  final void Function(String action, String reason, String requestId)? onSubmit;
  final VoidCallback? onCancel;

  bool get _isDeploy => actionContext.actions.any((a) => a.action == 'deploy');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDeploy = _isDeploy;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: isDeploy
          ? 'This work passed its checks. You can move it forward to a '
                'deployment decision.'
          : 'This work says it is running, but nothing is running it. You '
                'can hand it back so it can be tried again.',
      child: DesignPanel(
        edgeColor: isDeploy ? palette.attention : palette.negative,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (outcomeAnnouncement != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  outcomeAnnouncement!,
                  style: ShipItType.bodyMicro.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
              ),
            Text(
              isDeploy ? deployPanelHeading : reclaimPanelHeading,
              style: ShipItType.sectionTitle.copyWith(
                color: palette.inkPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isDeploy ? deployPanelExplanation : reclaimPanelExplanation,
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            const SizedBox(height: 14),
            const ContentRule(),
            const SizedBox(height: 14),
            if (pendingAction == null)
              _ActionRow(
                actionContext: actionContext,
                compact: isMobile(context),
                onPressed: onActionPressed,
              )
            else
              _ConfirmStrip(
                action: pendingAction!,
                submitting: submitting,
                compact: isMobile(context),
                onSubmit: onSubmit,
                onCancel: onCancel,
              ),
          ],
        ),
      ),
    );
  }
}

/// The actions, in the server's order, with nothing the server did not offer.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.actionContext,
    required this.onPressed,
    this.compact = false,
  });

  final WorkItemActionContextResponse actionContext;
  final void Function(String action)? onPressed;
  final bool compact;

  String _labelFor(String action) => switch (action) {
    'deploy' => deployActionLabel,
    'reclaim' => reclaimActionLabel,
    _ => action,
  };

  @override
  Widget build(BuildContext context) {
    final buttons = [
      for (final action in actionContext.actions)
        SizedBox(
          width: compact ? double.infinity : 190,
          height: 28,
          child: FilledButton(
            onPressed: () => onPressed?.call(action.action),
            child: Text(_labelFor(action.action)),
          ),
        ),
    ];
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          buttons[i],
        ],
      ],
    );
  }
}

/// Escape cancels the confirm strip — the same rule the retry strip keeps.
class _ConfirmStrip extends StatefulWidget {
  const _ConfirmStrip({
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
  State<_ConfirmStrip> createState() => _ConfirmStripState();
}

class _ConfirmStripState extends State<_ConfirmStrip> {
  final TextEditingController _reason = TextEditingController();

  /// Minted on the FIRST submit of this confirmation, reused for every retry
  /// of the SAME one — one intent, one id, one durable write.
  String? _requestId;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _label =>
      widget.action == 'deploy' ? deployActionLabel : reclaimActionLabel;

  String get _consequence => widget.action == 'deploy'
      ? deployConsequenceSentence
      : reclaimConsequenceSentence;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = widget.action == 'deploy'
        ? palette.attention
        : palette.negative;
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
                'You chose: $_label',
                style: ShipItType.status.copyWith(color: accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _consequence,
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
                label: ready ? '$_label. $_consequence' : 'Add a reason first',
                child: SizedBox(
                  width: 190,
                  height: 28,
                  child: FilledButton(
                    onPressed: ready ? _submit : null,
                    child: Text(
                      widget.submitting ? savingLabel : 'Save: $_label',
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
    callback(
      widget.action,
      _reason.text.trim(),
      _requestId ??= mintOperatorRequestId(),
    );
  }
}

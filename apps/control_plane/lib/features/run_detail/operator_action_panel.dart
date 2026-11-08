import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart';
import 'failed_work_item_action_panel.dart' show mintOperatorRequestId;
import 'operator_action_copy.dart';

/// The operator surface for the non-failure actions: `deploy` on a
/// QA-passed (or gate-interrupted) item, `reclaim` on a stranded
/// `agent_executing` item, and the deployed pair — `reland` on a
/// label-only deploy, `reroute` on any deployed item.
///
/// Deliberately a separate widget from [FailedWorkItemActionPanel]: that
/// panel's whole copy is "it failed", which is false for all of these — a
/// `qa_passed` item PASSED, a stranded item never recorded a failure, and a
/// `deployed` item is at the far end of the pipeline. What they share is
/// the machinery: the server-computed action list, the confirm strip, and
/// the once-per-intent request id.
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

  /// True when the offered set is the deployed pair — 'reland' and/or
  /// 'reroute'. The reland offer is the stamp test: present means the item
  /// is a label-only deploy, absent means it was really landed.
  bool get _isDeployedItem => actionContext.actions.any(
    (a) => a.action == 'reland' || a.action == 'reroute',
  );

  bool get _relandOffered =>
      actionContext.actions.any((a) => a.action == 'reland');

  /// The heading is keyed on the offered actions, not the item's state:
  /// 'reland' offered means the deploy is only a label; 'reroute' alone
  /// means the landing is real.
  String get _heading {
    if (_isDeploy) return deployPanelHeading;
    if (_isDeployedItem) {
      return _relandOffered ? relandPanelHeading : reroutePanelHeading;
    }
    return reclaimPanelHeading;
  }

  String get _explanation {
    if (_isDeploy) return deployPanelExplanation;
    if (_isDeployedItem) {
      return _relandOffered ? relandPanelExplanation : reroutePanelExplanation;
    }
    return reclaimPanelExplanation;
  }

  String get _semantics {
    if (_isDeploy) {
      return 'This work passed its checks. You can move it forward to a '
          'deployment decision.';
    }
    if (_isDeployedItem) {
      return _relandOffered
          ? 'This work says it is deployed, but nothing was landed. You can '
                'land the produced commit or send it back to be built again.'
          : 'This work is deployed. You can send it back to be built again.';
    }
    return 'This work says it is running, but nothing is running it. You '
        'can hand it back so it can be tried again.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDeploy = _isDeploy;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _semantics,
      child: DesignPanel(
        // The reclaim gets the negative edge because a stranded item is a
        // broken record. The deployed pair is not a breakage — a decision an
        // operator may take — so it keeps the attention edge the deploy
        // carries.
        edgeColor: isDeploy || _isDeployedItem
            ? palette.attention
            : palette.negative,
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
              _heading,
              style: ShipItType.sectionTitle.copyWith(
                color: palette.inkPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _explanation,
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
    'reland' => relandActionLabel,
    'reroute' => rerouteActionLabel,
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

  String get _label => switch (widget.action) {
    'deploy' => deployActionLabel,
    'reland' => relandActionLabel,
    'reroute' => rerouteActionLabel,
    _ => reclaimActionLabel,
  };

  String get _consequence => switch (widget.action) {
    'deploy' => deployConsequenceSentence,
    'reland' => relandConsequenceSentence,
    'reroute' => rerouteConsequenceSentence,
    _ => reclaimConsequenceSentence,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The reclaim alone is the broken-record accent; every other action on
    // this panel is an operator decision, so it keeps the attention tick.
    final accent = widget.action == 'reclaim'
        ? palette.negative
        : palette.attention;
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

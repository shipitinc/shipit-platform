import 'package:flutter/material.dart';
import 'package:platform_contracts/platform_contracts.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';

/// Maps a [DefectStatus] to its operator-facing presentation: label, text tone,
/// and 2px tick colour.
///
/// The design never prints the raw wire value — this class is the single seam.
class DefectStatusBadge {
  const DefectStatusBadge._();

  static const _labels = {
    DefectStatus.reported: 'Reported',
    DefectStatus.triaging: 'Triaging',
    DefectStatus.needsClarification: 'Needs clarification',
    DefectStatus.confirmed: 'Confirmed',
    DefectStatus.notReproducible: 'Not reproducible',
    DefectStatus.duplicate: 'Duplicate',
    DefectStatus.remediationPlanned: 'Remediation planned',
    DefectStatus.fixInProgress: 'Fix in progress',
    DefectStatus.fixReadyForVerification: 'Fix ready for verification',
    DefectStatus.resolved: 'Resolved',
    DefectStatus.closed: 'Closed',
  };

  /// The exact string the design prints for this status.
  static String label(DefectStatus status) => _labels[status] ?? status.wire;

  /// Text tone for the status cell.
  static Color textColor(DefectStatus status, ShipItPalette palette) {
    return switch (status) {
      DefectStatus.reported ||
      DefectStatus.triaging ||
      DefectStatus.remediationPlanned ||
      DefectStatus.fixInProgress => palette.inkSecondary,
      DefectStatus.needsClarification => palette.attention,
      DefectStatus.confirmed => palette.positive,
      DefectStatus.notReproducible ||
      DefectStatus.duplicate => palette.inkTertiary,
      DefectStatus.fixReadyForVerification => palette.attention,
      DefectStatus.resolved => palette.positive,
      DefectStatus.closed => palette.inkTertiary,
    };
  }

  /// Single tone for list rows, where the 2px tick and the status text share
  /// one colour (`BP · Defect List` — `Row Tick n` equals `Row Status n`).
  ///
  /// Differs from [textColor]/[tickColor], which use the vivid tick tones for
  /// the detail screen's pill.
  static Color listTone(DefectStatus status, ShipItPalette palette) {
    return switch (status) {
      DefectStatus.reported => palette.inkSecondary,
      DefectStatus.triaging ||
      DefectStatus.confirmed ||
      DefectStatus.remediationPlanned ||
      DefectStatus.fixInProgress => palette.accent,
      DefectStatus.needsClarification ||
      DefectStatus.fixReadyForVerification => palette.attention,
      DefectStatus.resolved => palette.positive,
      DefectStatus.notReproducible ||
      DefectStatus.duplicate ||
      DefectStatus.closed => palette.inkQuiet,
    };
  }

  /// Colour of the 2px leading tick.
  static Color tickColor(DefectStatus status, ShipItPalette palette) {
    return switch (status) {
      DefectStatus.reported ||
      DefectStatus.triaging ||
      DefectStatus.remediationPlanned ||
      DefectStatus.fixInProgress => palette.accentTick,
      DefectStatus.needsClarification ||
      DefectStatus.fixReadyForVerification => palette.attentionTick,
      DefectStatus.confirmed || DefectStatus.resolved => palette.positive,
      DefectStatus.notReproducible ||
      DefectStatus.duplicate ||
      DefectStatus.closed => palette.inkTertiary,
    };
  }

  /// Whether the operator has an action on this defect.
  static bool isOperatorAction(DefectStatus status) => switch (status) {
    DefectStatus.needsClarification ||
    DefectStatus.fixReadyForVerification => true,
    _ => false,
  };
}

/// Convenience widget rendering a status badge with tick + label.
class DefectStatusChip extends StatelessWidget {
  const DefectStatusChip({
    super.key,
    required this.status,
    this.showTick = true,
  });

  final DefectStatus status;
  final bool showTick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = DefectStatusBadge.label(status);
    final textClr = DefectStatusBadge.textColor(status, palette);
    final tickClr = DefectStatusBadge.tickColor(status, palette);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: textClr.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textClr.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTick)
              ExcludeSemantics(
                child: Container(
                  width: ShipItMetrics.tickWidth,
                  height: 10,
                  color: tickClr,
                ),
              ),
            if (showTick) const SizedBox(width: 6),
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textClr,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

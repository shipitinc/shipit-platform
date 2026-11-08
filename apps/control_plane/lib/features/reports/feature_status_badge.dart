import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';

/// Maps a feature request's `WorkflowState` to its operator-facing
/// presentation: label and the single tone the 2px tick and the text share in
/// a list row.
///
/// The counterpart of the defect register's `DefectStatusBadge`, so the two
/// tabs name and colour their states from one seam each rather than printing
/// raw wire values.
class FeatureStatusBadge {
  const FeatureStatusBadge._();

  static const _labels = {
    'draft': 'Waiting for review',
    'needs_clarification': 'Needs clarification',
    'ready': 'Ready to plan',
    'in_progress': 'In progress',
    'blocked': 'Blocked',
    'done': 'Accepted',
    'cancelled': 'Closed',
  };

  /// The exact string the register prints for this state.
  static String label(String wire) =>
      _labels[wire] ?? wire.replaceAll('_', ' ');

  /// Single tone for list rows, where the 2px tick and the state text share
  /// one colour — the feature tab's counterpart to `DefectStatusBadge.listTone`.
  static Color listTone(String wire, ShipItPalette palette) {
    return switch (wire) {
      'draft' => palette.inkSecondary,
      'needs_clarification' => palette.attention,
      'ready' || 'in_progress' => palette.accent,
      'blocked' => palette.negative,
      'done' => palette.positive,
      'cancelled' => palette.inkQuiet,
      _ => palette.inkPrimary,
    };
  }
}

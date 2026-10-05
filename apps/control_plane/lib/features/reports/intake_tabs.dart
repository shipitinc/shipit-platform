import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/design_primitives.dart';
import 'reports_state.dart';

/// `Bug` / `Feature` — the intake forms' tab row.
///
/// The same choice the register tabs make, one step earlier: a reporter who is
/// on the wrong form gets one tap to the right one instead of a back-and-forth
/// through navigation. It is a navigation control, not a filter, so selecting
/// the other tab leaves this screen.
///
/// Placed between the page header and the fields on both forms, and styled with
/// [TabUnderlineRow] so it cannot drift from the register tabs it leads back to.
class IntakeTabs extends StatelessWidget {
  const IntakeTabs({super.key, required this.active});

  /// Which form is open. Underlined, not bolded-and-greyed: the two forms are
  /// peers, and the active one is the one being filled in.
  final IntakeKind active;

  /// Where each form lives.
  static const _routes = {
    IntakeKind.bug: '/reports/new-bug',
    IntakeKind.feature: '/reports/new-feature',
  };

  @override
  Widget build(BuildContext context) {
    return TabUnderlineRow(
      labels: [for (final kind in IntakeKind.values) kind.label],
      activeIndex: IntakeKind.values.indexOf(active),
      onSelected: (i) {
        final kind = IntakeKind.values[i];
        if (kind == active) return;
        context.go(_routes[kind]!);
      },
    );
  }
}

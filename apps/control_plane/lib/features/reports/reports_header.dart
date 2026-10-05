import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart';
import 'reports_state.dart';

/// The Reports page header and its register tab row.
///
/// Transcribed from `BPM/BP · Reports List · Populated / Loading / Empty /
/// Error`: `H1` "Reports" at y=72, `H1 Sub` at y=114, `Tab Group` at y=150, and
/// the register's own filter control at y=194. The tab row is therefore part of
/// the header, above each register's filters, and it is shared rather than
/// duplicated per register so the underline can only ever be in one place.
class ReportsHeader extends StatelessWidget {
  const ReportsHeader({
    super.key,
    required this.tab,
    required this.onTabSelected,
    required this.subtitle,
    this.freshness,
    this.liveLabel,
    this.trailing,
  });

  /// The register currently being shown.
  final ReportsTab tab;

  final ValueChanged<ReportsTab> onTabSelected;

  /// What the register currently holds — a loading, empty, failed or populated
  /// reading, in the reader's own words.
  final String subtitle;

  final String? freshness;
  final String? liveLabel;

  /// Non-live status stamp — `LOADING` / `NO CONTACT`.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports',
            style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: ShipItType.pageSubtitle.copyWith(
              color: palette.inkSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ReportsTabRow(tab: tab, onSelected: onTabSelected),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Reports',
          subtitle: subtitle,
          liveLabel: liveLabel,
          freshness: freshness,
          trailing: trailing,
        ),
        const SizedBox(height: 40),
        ReportsTabRow(tab: tab, onSelected: onTabSelected),
      ],
    );
  }
}

/// `Tab Group` — the two register tabs, 32px below the header rule on desktop.
///
/// The treatment lives in [TabUnderlineRow], shared with the intake forms.
class ReportsTabRow extends StatelessWidget {
  const ReportsTabRow({super.key, required this.tab, required this.onSelected});

  final ReportsTab tab;
  final ValueChanged<ReportsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return TabUnderlineRow(
      labels: [for (final t in ReportsTab.values) t.label],
      activeIndex: ReportsTab.values.indexOf(tab),
      onSelected: (i) => onSelected(ReportsTab.values[i]),
    );
  }
}

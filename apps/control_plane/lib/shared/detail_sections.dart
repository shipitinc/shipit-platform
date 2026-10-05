import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../core/plain_language.dart';
import '../core/theme.dart';
import 'design_primitives.dart';

/// One row of the "What's happened so far" table.
///
/// Deliberately neutral: a run event and a defect event are both just a
/// timestamp, an operator-facing sentence, and whether the row handed control
/// to the human.
class TimelineEntry {
  const TimelineEntry({
    required this.timestamp,
    required this.message,
    this.needsOperator = false,
  });

  final DateTime timestamp;
  final String message;
  final bool needsOperator;
}

/// The "What's happened so far" table (Penpot `Act When` / `Act What`).
///
/// A 24px-pitch mono table with a 2px tick per row; rows where the operator
/// became the next actor are tinted with the attention tone, matching the
/// board's amber entries.
class TimelineTable extends StatelessWidget {
  const TimelineTable({
    super.key,
    required this.events,
    this.emptyMessage,
    this.compact = false,
  });

  final List<TimelineEntry> events;

  /// Shown when the record carries no events yet.
  final String? emptyMessage;

  /// `BPM · Defect Detail` draws the timeline as bare rows: no head rule, no
  /// `WHEN`/`WHAT HAPPENED` column headers and no separators between rows,
  /// on a 26px pitch instead of the desktop 24+1.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          emptyMessage ?? 'Nothing has been recorded for this run yet.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
        ),
      );
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final event in events) _TimelineRow(event: event, compact: true),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        const ContentRule(strong: true),
        const SizedBox(height: 7),
        const Row(
          children: [
            SizedBox(width: 170, child: MicroLabel('WHEN')),
            Expanded(child: MicroLabel('WHAT HAPPENED')),
          ],
        ),
        const SizedBox(height: 8),
        for (final event in events) _TimelineRow(event: event),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, this.compact = false});

  final TimelineEntry event;

  /// Mobile rows are 26px tall with no trailing rule (Penpot `Ev When` pitch).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = event.needsOperator ? palette.attention : null;
    return Column(
      children: [
        SizedBox(
          height: compact ? 26 : 24,
          child: Row(
            children: [
              SizedBox(
                width: 170,
                child: Row(
                  children: [
                    AccentTick(
                      color: event.needsOperator
                          ? palette.attentionTick
                          : palette.rule,
                      height: ShipItMetrics.metricTickHeight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      PlainLanguage.timeOnly(event.timestamp),
                      style: ShipItType.duration.copyWith(
                        color: tone ?? palette.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  event.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.status.copyWith(
                    color: tone ?? palette.inkPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!compact) const ContentRule(),
      ],
    );
  }
}

/// The evidence panel (Penpot `Ev Bg` + `Thumb Frame` + `Art *` + `Ev K/V`).
///
/// Rendered only when the record actually carries an artifact; the board's
/// thumbnail is a placeholder skeleton, so a skeleton is what is drawn rather
/// than a fabricated preview.
class EvidencePanel extends StatelessWidget {
  const EvidencePanel({
    super.key,
    required this.title,
    required this.artifactTitle,
    this.artifactSubtitle,
    this.links = const [],
    this.facts = const [],
    this.compact = false,
  });

  /// Uppercase mono panel label, e.g. "WHAT YOU'RE APPROVING".
  final String title;
  final String artifactTitle;
  final String? artifactSubtitle;

  /// Label/URI pairs rendered as accent links.
  final List<(String, String)> links;

  /// Key/value pairs along the bottom, e.g. "Automated tests" / "Passed".
  /// Unused in [compact] mode — `BPM · Defect Detail` draws no `Ev K/V` row.
  final List<(String, String)> facts;

  /// `BPM · Defect Detail` mobile panel: 96×64 thumbnail, 14/12 padding and
  /// no facts row (`Art Bg` is 358×116).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.accentTick,
      padding: compact
          ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
          : const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(title),
          SizedBox(height: compact ? 9 : 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ThumbnailSkeleton(compact: compact),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artifactTitle,
                      style: ShipItType.rowTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.inkPrimary,
                      ),
                    ),
                    if (artifactSubtitle != null) ...[
                      SizedBox(height: compact ? 4 : 6),
                      Text(
                        artifactSubtitle!,
                        style: ShipItType.bodySmall.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                    SizedBox(height: compact ? 6 : 8),
                    for (final link in links)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InlineLink(label: '${link.$1} ↗'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (facts.isNotEmpty && !compact) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (final fact in facts) ...[
                  Text(
                    fact.$1,
                    style: ShipItType.bodySmall.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    fact.$2,
                    style: ShipItType.status.copyWith(
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(width: 34),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The board's placeholder preview: a framed box with grey bars.
class _ThumbnailSkeleton extends StatelessWidget {
  const _ThumbnailSkeleton({this.compact = false});

  /// Mobile renders the board's 96×64 `Thumb`, desktop its 140×88 frame.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = compact ? 96.0 : 140.0;
    final height = compact ? 64.0 : 88.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border.all(color: palette.rule),
      ),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 36 : 44,
            height: compact ? 4 : 5,
            color: palette.ruleStrong,
          ),
          SizedBox(height: compact ? 4 : 7),
          Container(
            width: width - 36,
            height: compact ? 2 : 3,
            color: palette.rule,
          ),
          SizedBox(height: compact ? 4 : 5),
          Container(
            width: width - 56,
            height: compact ? 2 : 3,
            color: palette.rule,
          ),
          SizedBox(height: compact ? 6 : 9),
          Container(
            width: width - 32,
            height: compact ? 14 : 20,
            color: palette.rule,
          ),
        ],
      ),
    );
  }
}

/// A three-column consequence table (Penpot `Cons *`).
///
/// "AND THEN" is only rendered when the record supplies it; the durable
/// decision contract currently has no downstream-effect field, so that column
/// is omitted rather than invented.
class OutcomeTable extends StatelessWidget {
  const OutcomeTable({super.key, required this.rows});

  final List<OutcomeRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasEffect = rows.any((r) => r.effect != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        const ContentRule(strong: true),
        const SizedBox(height: 7),
        Row(
          children: [
            const SizedBox(width: 170, child: MicroLabel('IF YOU CHOOSE')),
            const Expanded(child: MicroLabel('WHAT HAPPENS')),
            if (hasEffect)
              const SizedBox(width: 216, child: MicroLabel('AND THEN')),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in rows)
          Column(
            children: [
              SizedBox(
                height: 26,
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Row(
                        children: [
                          AccentTick(
                            color: row.tone(palette),
                            height: ShipItMetrics.metricTickHeight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              row.choice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ShipItType.status.copyWith(
                                color: row.tone(palette),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.happens,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShipItType.status.copyWith(
                          color: palette.inkPrimary,
                        ),
                      ),
                    ),
                    if (hasEffect)
                      SizedBox(
                        width: 216,
                        child: Text(
                          row.effect ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShipItType.status.copyWith(
                            color: palette.inkSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const ContentRule(),
            ],
          ),
      ],
    );
  }
}

/// One row of an [OutcomeTable].
class OutcomeRow {
  const OutcomeRow({
    required this.choice,
    required this.happens,
    this.effect,
    required this.sentiment,
  });

  final String choice;
  final String happens;
  final String? effect;
  final OutcomeSentiment sentiment;

  Color tone(ShipItPalette palette) => switch (sentiment) {
    OutcomeSentiment.proceed => palette.positive,
    OutcomeSentiment.revise => palette.attention,
    OutcomeSentiment.stop => palette.negative,
  };
}

/// Whether a choice moves work forward, sends it back, or ends it.
enum OutcomeSentiment { proceed, revise, stop }

/// Shared failure state for the detail screens, with a breadcrumb out.
class DetailErrorState extends StatelessWidget {
  const DetailErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.parentLabel,
    required this.onParentTap,
  });

  final String title;
  final String message;
  final String parentLabel;
  final VoidCallback onParentTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShipItMetrics.contentGutter,
        26,
        ShipItMetrics.contentGutter,
        23,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineLink(label: parentLabel, onTap: onParentTap, micro: true),
          const SizedBox(height: 24),
          Text(
            title,
            style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing has been changed.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 20),
          TechnicalDetails(lines: [message]),
        ],
      ),
    );
  }
}

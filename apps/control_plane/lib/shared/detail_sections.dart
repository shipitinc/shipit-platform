import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../core/plain_language.dart';
import '../core/theme.dart';
import '../features/run_detail/run_detail_bloc.dart';
import 'design_primitives.dart';

/// The "What's happened so far" table (Penpot `Act When` / `Act What`).
///
/// A 24px-pitch mono table with a 2px tick per row; rows where the operator
/// became the next actor are tinted with the attention tone, matching the
/// board's amber entries.
class TimelineTable extends StatelessWidget {
  const TimelineTable({super.key, required this.events});

  final List<RunEvent> events;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nothing has been recorded for this run yet.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
        ),
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
  const _TimelineRow({required this.event});

  final RunEvent event;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = event.needsOperator ? palette.attention : null;
    return Column(
      children: [
        SizedBox(
          height: 24,
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
        const ContentRule(),
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
  });

  /// Uppercase mono panel label, e.g. "WHAT YOU'RE APPROVING".
  final String title;
  final String artifactTitle;
  final String? artifactSubtitle;

  /// Label/URI pairs rendered as accent links.
  final List<(String, String)> links;

  /// Key/value pairs along the bottom, e.g. "Automated tests" / "Passed".
  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.accentTick,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(title),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ThumbnailSkeleton(),
              const SizedBox(width: 16),
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
                      const SizedBox(height: 6),
                      Text(
                        artifactSubtitle!,
                        style: ShipItType.bodySmall.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
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
          if (facts.isNotEmpty) ...[
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
  const _ThumbnailSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 140,
      height: 88,
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border.all(color: palette.rule),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 44, height: 5, color: palette.ruleStrong),
          const SizedBox(height: 7),
          Container(width: 104, height: 3, color: palette.rule),
          const SizedBox(height: 5),
          Container(width: 84, height: 3, color: palette.rule),
          const SizedBox(height: 9),
          Container(width: 108, height: 20, color: palette.rule),
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

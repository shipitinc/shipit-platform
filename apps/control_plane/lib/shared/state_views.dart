import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../core/theme.dart';
import 'design_primitives.dart';
import 'mobile_chrome.dart';

/// The loading, empty and error states, from the Penpot `S ·` / `SM ·` boards.
///
/// These were the last places the product fell back to Material defaults. The
/// design's position is that a surface which cannot show data should still
/// show its own shape and say plainly what it does and does not know.

/// Skeleton rows on the table's own grid (`S · Loading`).
///
/// The column headers stay: the shape of the answer is known before it
/// arrives, and keeping them stops the page reflowing when data lands.
class DesignLoadingSkeleton extends StatelessWidget {
  const DesignLoadingSkeleton({
    super.key,
    required this.title,
    this.rows = 6,
    this.showColumns = true,
  });

  final String title;
  final int rows;

  /// List screens keep their column headers; detail screens have none.
  final bool showColumns;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mobile = isMobile(context);
    final gutter = mobile
        ? ShipItMetrics.mobileGutter
        : ShipItMetrics.contentGutter;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, mobile ? 16 : 30, gutter, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mobile) ...[
              Text(
                title,
                style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Reading the system\u2019s records\u2026',
                style: ShipItType.pageSubtitle.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
              const SizedBox(height: 20),
            ] else
              PageHeader(
                title: title,
                subtitle: 'Reading the system\u2019s records\u2026',
                liveLabel: 'LOADING',
              ),
            if (!mobile) const SizedBox(height: 21),
            if (showColumns && !mobile) ...[
              const Row(
                children: [
                  SizedBox(
                    width: ShipItMetrics.colWhat,
                    child: MicroLabel('REF'),
                  ),
                  Expanded(child: MicroLabel('WHAT IT IS')),
                  SizedBox(width: 200, child: MicroLabel('STATUS')),
                  SizedBox(
                    width: ShipItMetrics.colElapsedWidth,
                    child: MicroLabel('RUNNING FOR'),
                  ),
                  SizedBox(width: 140),
                ],
              ),
              const SizedBox(height: 7),
              const ContentRule(strong: true),
            ],
            for (var i = 0; i < rows; i++)
              _SkeletonRow(index: i, mobile: mobile),
            const SizedBox(height: 18),
            Semantics(
              liveRegion: true,
              child: Text(
                'Nothing is shown until it has been read from the durable '
                'record.',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.index, required this.mobile});

  final int index;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Varying the title width stops the skeleton reading as a table of empty
    // boxes and suggests real, differently sized content.
    final titleWidth = 300.0 - (index % 3) * 40;

    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: palette.rule,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    if (mobile) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 2, height: 16, color: palette.rule),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(titleWidth.clamp(120, 240), 12),
                      const SizedBox(height: 8),
                      bar(150, 10),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: bar(44, 10),
                ),
              ],
            ),
          ),
          const ContentRule(),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: ShipItMetrics.rowPitch - ShipItMetrics.hairline,
          child: Row(
            children: [
              SizedBox(
                width: ShipItMetrics.colWhat,
                child: Row(
                  children: [
                    Container(width: 2, height: 18, color: palette.rule),
                    const SizedBox(width: 10),
                    bar(72, 10),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: bar(titleWidth, 12),
                ),
              ),
              SizedBox(width: 200, child: bar(110, 10)),
              SizedBox(
                width: ShipItMetrics.colElapsedWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: bar(70, 10),
                ),
              ),
              const SizedBox(width: 140),
            ],
          ),
        ),
        const ContentRule(),
      ],
    );
  }
}

/// An empty state: a bordered panel with a tone edge, a plain statement of
/// what is absent, and why that is normal (`S · Empty …`).
class DesignEmptyState extends StatelessWidget {
  const DesignEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.tone = EmptyTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final EmptyTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final edge = switch (tone) {
      EmptyTone.settled => palette.positive,
      EmptyTone.neutral => palette.ruleStrong,
    };

    return DesignPanel(
      edgeColor: edge,
      padding: EdgeInsets.fromLTRB(
        isMobile(context) ? 16 : 24,
        20,
        isMobile(context) ? 16 : 24,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ShipItType.question.copyWith(
              fontSize: isMobile(context) ? 14 : 16,
              color: palette.inkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            InlineLink(label: actionLabel!, onTap: onAction),
          ],
        ],
      ),
    );
  }
}

/// Whether an empty state is a settled good outcome or simply nothing yet.
enum EmptyTone { settled, neutral }

/// The failure state (`S · Error`).
///
/// Leads with the fact an operator needs first — that nothing changed —
/// before the cause, which stays under the usual disclosure.
class DesignErrorState extends StatelessWidget {
  const DesignErrorState({
    super.key,
    required this.title,
    required this.detail,
    this.onRetry,
    this.lastSuccess,
  });

  final String title;

  /// Raw cause, shown only inside technical details.
  final String detail;
  final VoidCallback? onRetry;

  /// e.g. "last successful reading 2m ago".
  final String? lastSuccess;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mobile = isMobile(context);
    final gutter = mobile
        ? ShipItMetrics.mobileGutter
        : ShipItMetrics.contentGutter;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, mobile ? 16 : 30, gutter, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignPanel(
              edgeColor: palette.negative,
              padding: EdgeInsets.fromLTRB(mobile ? 16 : 24, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ShipItType.question.copyWith(
                      fontSize: mobile ? 15 : 16,
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nothing has been changed. No decision was recorded and '
                    'no work was started or stopped by this failure.',
                    style: ShipItType.bodySmall.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (mobile)
                    MobilePrimaryButton(label: 'Try again', onPressed: onRetry)
                  else
                    Row(
                      children: [
                        SizedBox(
                          width: 128,
                          height: 24,
                          child: OutlinedButton(
                            onPressed: onRetry,
                            child: const Text('Try again'),
                          ),
                        ),
                        if (lastSuccess != null) ...[
                          const SizedBox(width: 20),
                          Text(
                            lastSuccess!,
                            style: ShipItType.monoMeta.copyWith(
                              color: palette.inkTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (mobile && lastSuccess != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      lastSuccess!,
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 26),
            TechnicalDetails(lines: [detail]),
          ],
        ),
      ),
    );
  }
}

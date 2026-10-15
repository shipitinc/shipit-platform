import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart' show isMobile;
import '../../shared/state_views.dart';
import 'model_stats_bloc.dart';
import 'run_duration_panel.dart';

/// ## WHAT THIS PAGE MAY NOT DO
///
/// Render a number it did not read. Every figure below comes from
/// `ModelStatsResponse`, whose fields are exactly the keys `ModelStatsView`
/// sends plus two getters derived from them. There is no default, no
/// placeholder, and no "— if unavailable" standing in for a zero.
///
/// And a card whose data failed to read must say so. A card that renders
/// `0.0%` when the query threw is the most dangerous form of this bug, because
/// it is indistinguishable from a real measurement — so [readError] blanks every
/// card on the screen rather than letting a stale or absent value stand in.
class ModelStatsPage extends StatelessWidget {
  const ModelStatsPage({super.key, this.bloc});

  final ModelStatsBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<ModelStatsBloc>.value(
            value: provided,
            child: const _ModelStatsView(),
          )
        : BlocProvider<ModelStatsBloc>(
            create: (_) =>
                ModelStatsBloc(repository: ClientProvider.repository)
                  ..add(const ModelStatsLoaded()),
            child: const _ModelStatsView(),
          );
  }
}

class _ModelStatsView extends StatefulWidget {
  const _ModelStatsView();

  @override
  State<_ModelStatsView> createState() => _ModelStatsViewState();
}

class _ModelStatsViewState extends State<_ModelStatsView> {
  _TimeRange _timeRange = _TimeRange.last7Days;
  DateTimeRange? _customRange;
  _GroupBy _groupBy = _GroupBy.modelId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelStatsBloc, ModelStatsState>(
      builder: (context, state) {
        if (state.isLoading && state.stats == null) {
          return const DesignLoadingSkeleton(
            title: 'Model Stats',
            showColumns: false,
          );
        }
        if (state.errorMessage != null && state.stats == null) {
          return DesignErrorState(
            title: "We could not reach the system's records.",
            detail: state.errorMessage!,
            onRetry: () =>
                context.read<ModelStatsBloc>().add(const ModelStatsLoaded()),
          );
        }

        final stats = state.stats;
        if (stats == null) {
          return const Center(child: Text('No data available'));
        }

        // THE THIRD LAYER OF THE ORIGINAL DEFECT.
        //
        // A refresh that fails while earlier data is still on screen used to
        // leave that data on screen with no indication that the numbers on it
        // are no longer current. Every card below takes this and refuses to
        // draw a figure when it is set.
        final readError = state.errorMessage;

        if (isMobile(context)) {
          return _MobileModelStats(
            stats: stats,
            readError: readError,
            timeRange: _timeRange,
            customRange: _customRange,
            groupBy: _groupBy,
            onTimeRangeChanged: (r) => setState(() => _timeRange = r),
            onCustomRangeChanged: (r) => setState(() => _customRange = r),
            onGroupByChanged: (g) => setState(() => _groupBy = g),
            onRefresh: () => _loadStats(context),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ShipItMetrics.contentGutter,
              30,
              ShipItMetrics.contentGutter,
              23,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Model Cost & Usage Stats',
                  subtitle: _buildSubtitle(stats, readError),
                  liveLabel: readError == null ? 'LIVE' : 'READ FAILED',
                ),
                if (readError != null) ...[
                  const SizedBox(height: 16),
                  _ReadFailureBanner(message: readError),
                ],
                const SizedBox(height: 25),
                _ControlBar(
                  timeRange: _timeRange,
                  customRange: _customRange,
                  groupBy: _groupBy,
                  onTimeRangeChanged: (r) {
                    setState(() => _timeRange = r);
                    _loadStats(context);
                  },
                  onCustomRangeChanged: (r) {
                    setState(() => _customRange = r);
                    _loadStats(context);
                  },
                  onGroupByChanged: (g) {
                    setState(() => _groupBy = g);
                    _loadStats(context);
                  },
                ),
                const SizedBox(height: 24),
                _SummaryCards(stats: stats, readError: readError),
                const SizedBox(height: 24),
                _ChartsSection(
                  stats: stats,
                  groupBy: _groupBy,
                  readError: readError,
                ),
                const SizedBox(height: 24),
                _NotMeasuredHerePanel(),
                const SizedBox(height: 24),
                // The budgets an operator is about to tune live on this page,
                // so the measurement that should replace them lives here too.
                RunDurationPanel(
                  stats: state.durations,
                  unmeasuredRuns: state.unmeasuredRuns,
                  durationErrorMessage: state.durationErrorMessage,
                ),
                const SizedBox(height: 46),
                TechnicalDetails(
                  note:
                      'Stats are aggregated from durable execution records. Costs in USD.',
                  lines: [
                    'range=${_timeRange.label}${_customRange != null ? ' (${_customRange!.start.toIso8601String()}..${_customRange!.end.toIso8601String()})' : ''}',
                    'groupBy=${_groupBy.name}',
                    'totalCost=\$${stats.totalCostUsd.toStringAsFixed(2)}',
                    'totalTokens=${stats.totalTokens}',
                    'totalExecutions=${stats.totalExecutions}',
                    'successRate=${_formatRate(stats.successRate)}',
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// `null` success rate reads "no executions in range", NOT "0% success".
  String _buildSubtitle(ModelStatsResponse stats, String? readError) {
    if (readError != null) {
      return 'These figures could not be re-read. Nothing on this screen is '
          'current, and nothing below claims to be.';
    }
    final rate = _formatRate(stats.successRate);
    return '\$${stats.totalCostUsd.toStringAsFixed(2)} · ${_formatTokens(stats.totalTokens)} tokens · ${stats.totalExecutions} ${stats.totalExecutions == 1 ? 'execution' : 'executions'} · $rate';
  }

  void _loadStats(BuildContext context) {
    DateTime? from;
    DateTime? to;
    final now = DateTime.now();

    switch (_timeRange) {
      case _TimeRange.last24Hours:
        from = now.subtract(const Duration(hours: 24));
        to = now;
      case _TimeRange.last7Days:
        from = now.subtract(const Duration(days: 7));
        to = now;
      case _TimeRange.last30Days:
        from = now.subtract(const Duration(days: 30));
        to = now;
      case _TimeRange.custom:
        from = _customRange?.start;
        to = _customRange?.end;
    }

    context.read<ModelStatsBloc>().add(
      ModelStatsLoaded(from: from, to: to, groupBy: _groupBy.apiValue),
    );
  }
}

/// An em dash, not a zero.
///
/// It is the only glyph this screen uses to mean "there is no figure here",
/// and it is never produced by a number that failed to arrive.
const _noFigure = '—';

String _formatRate(double? rate) =>
    rate == null ? 'no runs in range' : '${(rate * 100).toStringAsFixed(1)}%';

String _formatTokens(int tokens) {
  if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
  if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
  return tokens.toString();
}

/// Says plainly that the numbers on the screen are not current.
class _ReadFailureBanner extends StatelessWidget {
  const _ReadFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.negative,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The figures below are NOT current.',
            style: ShipItType.sectionTitle.copyWith(color: palette.negative),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: ShipItType.monoMeta.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Each card shows an em dash rather than a figure it failed to read. '
            'A stale total and a zero look identical on a card, so neither is '
            'drawn.',
            style: ShipItType.bodySmall.copyWith(color: palette.attention),
          ),
        ],
      ),
    );
  }
}

enum _TimeRange {
  last24Hours('Last 24h'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  custom('Custom');

  const _TimeRange(this.label);
  final String label;
}

enum _GroupBy {
  modelId('Model'),
  provider('Provider'),
  taskType('Task Type'),
  role('Role');

  const _GroupBy(this.label);
  final String label;

  String get apiValue => switch (this) {
    _GroupBy.modelId => 'modelId',
    _GroupBy.provider => 'provider',
    _GroupBy.taskType => 'taskType',
    _GroupBy.role => 'role',
  };
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.timeRange,
    required this.customRange,
    required this.groupBy,
    required this.onTimeRangeChanged,
    required this.onCustomRangeChanged,
    required this.onGroupByChanged,
  });

  final _TimeRange timeRange;
  final DateTimeRange? customRange;
  final _GroupBy groupBy;
  final ValueChanged<_TimeRange> onTimeRangeChanged;
  final ValueChanged<DateTimeRange?> onCustomRangeChanged;
  final ValueChanged<_GroupBy> onGroupByChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Controls',
                style: ShipItType.sectionTitle.copyWith(
                  color: palette.inkPrimary,
                ),
              ),
              const Spacer(),
              if (timeRange == _TimeRange.custom && customRange != null)
                TextButton.icon(
                  onPressed: () => onCustomRangeChanged(null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear custom range'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const MicroLabel('TIME RANGE'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in _TimeRange.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(r.label),
                          selected: timeRange == r,
                          onSelected: (_) => onTimeRangeChanged(r),
                        ),
                      ),
                  ],
                ),
              ),
              if (timeRange == _TimeRange.custom) ...[
                const SizedBox(width: 24),
                const MicroLabel('CUSTOM RANGE'),
                _DateRangePicker(
                  value: customRange,
                  onChanged: onCustomRangeChanged,
                ),
              ],
              const SizedBox(width: 24),
              const MicroLabel('GROUP BY'),
              DropdownMenu<_GroupBy>(
                initialSelection: groupBy,
                dropdownMenuEntries: _GroupBy.values
                    .map((g) => DropdownMenuEntry(value: g, label: g.label))
                    .toList(),
                onSelected: (g) => onGroupByChanged(g!),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  const _DateRangePicker({required this.value, required this.onChanged});

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        InkWell(
          onTap: () => _pickDate(context, true),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'From',
              labelStyle: ShipItType.ref.copyWith(color: palette.inkTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ShipItMetrics.radius),
                borderSide: BorderSide(color: palette.cardBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            child: Text(
              value?.start != null
                  ? '${value!.start.year}-${value!.start.month.toString().padLeft(2, '0')}-${value!.start.day.toString().padLeft(2, '0')}'
                  : 'Select',
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () => _pickDate(context, false),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'To',
              labelStyle: ShipItType.ref.copyWith(color: palette.inkTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ShipItMetrics.radius),
                borderSide: BorderSide(color: palette.cardBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            child: Text(
              value?.end != null
                  ? '${value!.end.year}-${value!.end.month.toString().padLeft(2, '0')}-${value!.end.day.toString().padLeft(2, '0')}'
                  : 'Select',
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? value?.start : value?.end;
    final firstDate = isStart
        ? DateTime(2020)
        : (value?.start ?? DateTime(2020));
    final lastDate = isStart ? (value?.end ?? now) : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      final newRange = DateTimeRange(
        start: isStart ? picked : (value?.start ?? picked),
        end: isStart ? (value?.end ?? picked) : picked,
      );
      onChanged(newRange);
    }
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.stats, required this.readError});

  final ModelStatsResponse stats;

  /// Non-null when the read these cards describe FAILED. Each card then shows
  /// the em dash (see [_noFigure]); none of them falls back to a stale or zero
  /// value.
  final String? readError;

  @override
  Widget build(BuildContext context) {
    final failed = readError != null;
    final palette = context.palette;
    final rate = stats.successRate;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total Cost',
            value: failed
                ? _noFigure
                : '\$${stats.totalCostUsd.toStringAsFixed(2)}',
            color: failed ? palette.negative : palette.accent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            label: 'Total Tokens',
            value: failed ? _noFigure : _formatTokens(stats.totalTokens),
            color: failed ? palette.negative : palette.positive,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            label: 'Executions',
            value: failed ? _noFigure : '${stats.totalExecutions}',
            color: failed ? palette.negative : palette.inkSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            label: 'Success Rate',
            // Three distinct answers, and the middle one used to be
            // unreachable: a real rate, the literal string "no runs in range"
            // when nothing ran, and $noFigure when the read failed.
            value: failed ? _noFigure : _formatRate(rate),
            color: failed
                ? palette.negative
                : rate == null
                ? palette.inkTertiary
                : rate >= 0.95
                ? palette.positive
                : palette.attention,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DesignPanel(
      edgeColor: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(label),
          const SizedBox(height: 4),
          Text(value, style: ShipItType.pageTitle.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// The three per-dimension charts this read CAN produce, driven by the
/// GROUP BY control that was previously wired to the server and then ignored.
///
/// The four charts that used to sit here — Cost Over Time, Tokens by Provider,
/// Success Rate by Model, Escalation Frequency, Cost by Task Type — read five
/// keys `ModelStatsView` never sent, so all five drew "No data" from the first
/// day. Three of them are exactly what `byGroup` holds, and the GROUP BY
/// selector already chose which dimension; the other two have no source at all
/// and are now named as such in [_NotMeasuredHerePanel].
class _ChartsSection extends StatelessWidget {
  const _ChartsSection({
    required this.stats,
    required this.groupBy,
    required this.readError,
  });

  final ModelStatsResponse stats;
  final _GroupBy groupBy;
  final String? readError;

  @override
  Widget build(BuildContext context) {
    final failed = readError != null;
    final dimension = groupBy.label.toLowerCase();
    final groups = failed ? const <ModelStatsGroupResponse>[] : stats.byGroup;

    final tokens = <_BarDatum>[
      for (final g in groups)
        _BarDatum(label: g.key, value: g.totalTokens.toDouble()),
    ];
    // A group with no runs has no rate. It is dropped here rather than drawn
    // as a zero-height bar, which would read as "this model always fails".
    final rates = <_BarDatum>[
      for (final g in groups)
        if (g.successRate case final r?) _BarDatum(label: g.key, value: r),
    ];
    final costs = <_BarDatum>[
      for (final g in groups) _BarDatum(label: g.key, value: g.totalCostUsd),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: 'Tokens by $dimension',
          subtitle:
              'One bar per $dimension, from the grouped aggregate. Summed: '
              '${failed ? _noFigure : '${stats.totalTokens} total'}',
          child: _GroupBarChart(
            data: tokens,
            formatValue: (v) => _formatTokens(v.round()),
            emptyLabel: failed
                ? 'Token counts could not be read. Nothing is claimed here.'
                : 'No executions in this range, so there are no $dimension '
                      'tokens to show.',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ChartCard(
                title: 'Success Rate by $dimension',
                subtitle: 'successCount / count, per group.',
                child: _GroupBarChart(
                  data: rates,
                  formatValue: (v) => '${(v * 100).toStringAsFixed(1)}%',
                  emptyLabel: failed
                      ? 'Success rates could not be read. Nothing is claimed '
                            'here.'
                      : 'No $dimension with runs in this range.',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ChartCard(
                title: 'Cost by $dimension',
                subtitle: 'totalCostUsd, per group.',
                child: _GroupBarChart(
                  data: costs,
                  formatValue: (v) => '\$${v.toStringAsFixed(2)}',
                  emptyLabel: failed
                      ? 'Costs could not be read. Nothing is claimed here.'
                      : 'No executions in this range, so there are no $dimension '
                            'costs to show.',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The two figures this screen used to claim it was showing and never did.
///
/// Naming them is the point. An operator who used to read an empty "Cost Over
/// Time" chart had no way to tell a feature that had never worked from a range
/// with no spend; a sentence saying the measurement is not taken is a
/// different thing to see.
class _NotMeasuredHerePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not measured on this screen',
            style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Two charts that used to sit here are gone rather than blank. They '
            'are not hidden because the data is uninteresting — it is not '
            'collected by this read at all.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
          ),
          const SizedBox(height: 14),
          Text(
            '· Cost over time — `getModelStats` returns ONE aggregate for the '
            'whole range. It has no time buckets, so no per-day or per-hour '
            'figure exists to plot, and none is interpolated here.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '· Escalation frequency — `model_execution_record` records an '
            '`escalationIndex` per execution, but `getModelStats` offers no '
            'grouping by it, so the distribution is not available through this '
            'read.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(height: 300, child: child),
        ],
      ),
    );
  }
}

/// One bar: a label and the figure it stands for.
///
/// Built from [ModelStatsGroupResponse] fields by the caller rather than
/// accepting a pre-shaped record, so a metric that is undefined for a group
/// (see `successRate`) can be left out instead of being passed as `0`.
class _BarDatum {
  const _BarDatum({required this.label, required this.value});

  final String label;
  final double value;
}

class _GroupBarChart extends StatelessWidget {
  const _GroupBarChart({
    required this.data,
    required this.formatValue,
    required this.emptyLabel,
  });

  final List<_BarDatum> data;
  final String Function(double) formatValue;

  /// Spoken, not drawn as an empty axis. Distinguishes "nothing to plot" from
  /// "plotted, and every bar is zero".
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _ChartEmpty(message: emptyLabel);
    }

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) {
      // Every group really did read zero. Bars of zero height are an empty
      // chart with no explanation, which is indistinguishable from a chart that
      // failed to draw — so the actual figures are printed instead.
      return _ChartEmpty(
        message:
            'Every ${data.length} ${data.length == 1 ? 'group reads' : 'groups read'} '
            '${formatValue(0)} exactly. These are real measurements of zero, '
            'not missing data.',
      );
    }

    final palette = context.palette;
    return Semantics(
      // The bars are painted, so their labels and values exist only as canvas
      // operations — invisible to a screen reader, which is how the figures on
      // this screen were unreachable to anyone not looking at the pixels. The
      // summary below is the same data as text.
      label: data.map((d) => '${d.label}: ${formatValue(d.value)}').join(', '),
      container: true,
      excludeSemantics: true,
      child: CustomPaint(
        painter: _BarChartPainter(
          data: data,
          maxValue: maxValue,
          color: palette.accent,
          ruleColor: palette.rule,
          labelColor: palette.inkTertiary,
          formatValue: formatValue,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: ShipItType.bodySmall.copyWith(
            color: context.palette.inkTertiary,
          ),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
    required this.ruleColor,
    required this.labelColor,
    required this.formatValue,
  });

  final List<_BarDatum> data;
  final double maxValue;
  final Color color;
  final Color ruleColor;
  final Color labelColor;
  final String Function(double) formatValue;

  /// Model ids are long (`claude-sonnet-4-20250514`) and a centred label has
  /// no width budget, so they are clipped rather than allowed to run over
  /// their neighbours.
  static const _maxLabelChars = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padding = 40.0;
    final chartWidth = size.width - 2 * padding;
    final chartHeight = size.height - 2 * padding;

    // Draw axes
    final axisPaint = Paint()
      ..color = ruleColor
      ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw bars
    final barPaint = Paint()..color = color;
    final textStyle = ShipItType.monoMeta.copyWith(
      color: labelColor,
      fontSize: 10,
    );

    final slot = chartWidth / data.length;
    final barWidth = slot * 0.6;
    final spacing = slot * 0.4;

    for (var i = 0; i < data.length; i++) {
      final x = padding + i * slot + spacing / 2;
      final barHeight = (data[i].value / maxValue) * chartHeight;
      final y = size.height - padding - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      final valueText = TextPainter(
        text: TextSpan(text: formatValue(data[i].value), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      valueText.paint(
        canvas,
        Offset(
          x + barWidth / 2 - valueText.width / 2,
          y - valueText.height - 4,
        ),
      );

      final keyText = TextPainter(
        text: TextSpan(text: _clip(data[i].label), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      keyText.paint(
        canvas,
        Offset(x + barWidth / 2 - keyText.width / 2, size.height - padding + 4),
      );
    }
  }

  static String _clip(String label) => label.length <= _maxLabelChars
      ? label
      : '${label.substring(0, _maxLabelChars - 1)}…';

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class _MobileModelStats extends StatelessWidget {
  const _MobileModelStats({
    required this.stats,
    required this.readError,
    required this.timeRange,
    required this.customRange,
    required this.groupBy,
    required this.onTimeRangeChanged,
    required this.onCustomRangeChanged,
    required this.onGroupByChanged,
    required this.onRefresh,
  });

  final ModelStatsResponse stats;
  final String? readError;
  final _TimeRange timeRange;
  final DateTimeRange? customRange;
  final _GroupBy groupBy;
  final ValueChanged<_TimeRange> onTimeRangeChanged;
  final ValueChanged<DateTimeRange?> onCustomRangeChanged;
  final ValueChanged<_GroupBy> onGroupByChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ShipItMetrics.mobileGutter,
          16,
          ShipItMetrics.mobileGutter,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model Stats',
              style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _buildSubtitle(stats, readError),
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            if (readError != null) ...[
              const SizedBox(height: 14),
              _ReadFailureBanner(message: readError!),
            ],
            const SizedBox(height: 18),
            const ContentRule(strong: true),
            _SummaryCards(stats: stats, readError: readError),
            const SizedBox(height: 16),
            const ContentRule(),
            const SizedBox(height: 16),
            _MobileControlBar(
              timeRange: timeRange,
              customRange: customRange,
              groupBy: groupBy,
              onTimeRangeChanged: onTimeRangeChanged,
              onCustomRangeChanged: onCustomRangeChanged,
              onGroupByChanged: onGroupByChanged,
              onRefresh: onRefresh,
            ),
            const SizedBox(height: 16),
            const ContentRule(),
            const SizedBox(height: 16),
            _MobileChartsSection(
              stats: stats,
              groupBy: groupBy,
              readError: readError,
            ),
            const SizedBox(height: 16),
            const ContentRule(),
            const SizedBox(height: 16),
            _NotMeasuredHerePanel(),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(ModelStatsResponse stats, String? readError) {
    if (readError != null) {
      return 'These figures could not be re-read.';
    }
    return '\$${stats.totalCostUsd.toStringAsFixed(2)} · ${_formatTokens(stats.totalTokens)} tokens · ${stats.totalExecutions} ${stats.totalExecutions == 1 ? 'execution' : 'executions'} · ${_formatRate(stats.successRate)}';
  }
}

class _MobileControlBar extends StatelessWidget {
  const _MobileControlBar({
    required this.timeRange,
    required this.customRange,
    required this.groupBy,
    required this.onTimeRangeChanged,
    required this.onCustomRangeChanged,
    required this.onGroupByChanged,
    required this.onRefresh,
  });

  final _TimeRange timeRange;
  final DateTimeRange? customRange;
  final _GroupBy groupBy;
  final ValueChanged<_TimeRange> onTimeRangeChanged;
  final ValueChanged<DateTimeRange?> onCustomRangeChanged;
  final ValueChanged<_GroupBy> onGroupByChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Controls',
              style: ShipItType.sectionTitle.copyWith(
                color: palette.inkPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const MicroLabel('TIME RANGE'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in _TimeRange.values)
              ChoiceChip(
                label: Text(r.label),
                selected: timeRange == r,
                onSelected: (_) => onTimeRangeChanged(r),
              ),
          ],
        ),
        if (timeRange == _TimeRange.custom) ...[
          const SizedBox(height: 16),
          const MicroLabel('CUSTOM RANGE'),
          const SizedBox(height: 8),
          _DateRangePicker(value: customRange, onChanged: onCustomRangeChanged),
        ],
        const SizedBox(height: 16),
        const MicroLabel('GROUP BY'),
        const SizedBox(height: 8),
        DropdownMenu<_GroupBy>(
          initialSelection: groupBy,
          dropdownMenuEntries: _GroupBy.values
              .map((g) => DropdownMenuEntry(value: g, label: g.label))
              .toList(),
          onSelected: (g) => onGroupByChanged(g!),
        ),
      ],
    );
  }
}

class _MobileChartsSection extends StatelessWidget {
  const _MobileChartsSection({
    required this.stats,
    required this.groupBy,
    required this.readError,
  });

  final ModelStatsResponse stats;
  final _GroupBy groupBy;
  final String? readError;

  @override
  Widget build(BuildContext context) {
    final failed = readError != null;
    final dimension = groupBy.label.toLowerCase();
    final groups = failed ? const <ModelStatsGroupResponse>[] : stats.byGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileChartCard(
          title: 'Tokens by $dimension',
          child: _GroupBarChart(
            data: [
              for (final g in groups)
                _BarDatum(label: g.key, value: g.totalTokens.toDouble()),
            ],
            formatValue: (v) => _formatTokens(v.round()),
            emptyLabel: failed
                ? 'Token counts could not be read. Nothing is claimed here.'
                : 'No executions in this range, so there are no $dimension '
                      'tokens to show.',
          ),
        ),
        const SizedBox(height: 16),
        _MobileChartCard(
          title: 'Success Rate by $dimension',
          child: _GroupBarChart(
            data: [
              for (final g in groups)
                if (g.successRate case final r?)
                  _BarDatum(label: g.key, value: r),
            ],
            formatValue: (v) => '${(v * 100).toStringAsFixed(1)}%',
            emptyLabel: failed
                ? 'Success rates could not be read. Nothing is claimed here.'
                : 'No $dimension with runs in this range.',
          ),
        ),
        const SizedBox(height: 16),
        _MobileChartCard(
          title: 'Cost by $dimension',
          child: _GroupBarChart(
            data: [
              for (final g in groups)
                _BarDatum(label: g.key, value: g.totalCostUsd),
            ],
            formatValue: (v) => '\$${v.toStringAsFixed(2)}',
            emptyLabel: failed
                ? 'Costs could not be read. Nothing is claimed here.'
                : 'No executions in this range, so there are no $dimension '
                      'costs to show.',
          ),
        ),
      ],
    );
  }
}

class _MobileChartCard extends StatelessWidget {
  const _MobileChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 250, child: child),
        const SizedBox(height: 8),
        const ContentRule(),
      ],
    );
  }
}

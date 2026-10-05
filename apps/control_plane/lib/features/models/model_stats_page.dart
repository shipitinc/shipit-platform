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

        if (isMobile(context)) {
          return _MobileModelStats(
            stats: stats,
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
                  subtitle: _buildSubtitle(stats),
                  liveLabel: 'LIVE',
                ),
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
                _SummaryCards(stats: stats),
                const SizedBox(height: 24),
                _ChartsSection(stats: stats, groupBy: _groupBy),
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
                    'successRate=${(stats.successRate * 100).toStringAsFixed(1)}%',
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildSubtitle(ModelStatsResponse stats) {
    return '\$${stats.totalCostUsd.toStringAsFixed(2)} · ${_formatTokens(stats.totalTokens)} tokens · ${stats.totalExecutions} executions · ${(stats.successRate * 100).toStringAsFixed(1)}% success';
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

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
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
  const _SummaryCards({required this.stats});

  final ModelStatsResponse stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total Cost',
            value: '\$${stats.totalCostUsd.toStringAsFixed(2)}',
            color: palette.accent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            label: 'Total Tokens',
            value: _formatTokens(stats.totalTokens),
            color: palette.positive,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            label: 'Executions',
            value: stats.totalExecutions.toString(),
            color: palette.inkSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            label: 'Success Rate',
            value: '${(stats.successRate * 100).toStringAsFixed(1)}%',
            color: stats.successRate >= 0.95
                ? palette.positive
                : palette.attention,
          ),
        ),
      ],
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
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

class _ChartsSection extends StatelessWidget {
  const _ChartsSection({required this.stats, required this.groupBy});

  final ModelStatsResponse stats;
  final _GroupBy groupBy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: 'Cost Over Time',
          child: _CostOverTimeChart(points: stats.costOverTime),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ChartCard(
                title: 'Tokens by Provider',
                child: _BarChart(data: stats.tokensByProvider),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ChartCard(
                title: 'Success Rate by Model',
                child: _BarChart(
                  data: stats.successRateByModel,
                  formatValue: (v) => '${(v * 100).toStringAsFixed(1)}%',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ChartCard(
                title: 'Escalation Frequency',
                child: _EscalationChart(data: stats.escalationFrequency),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ChartCard(
                title: 'Cost by Task Type',
                child: _BarChart(
                  data: stats.costByTaskType,
                  formatValue: (v) => '\$${v.toStringAsFixed(2)}',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
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
          const SizedBox(height: 16),
          SizedBox(height: 300, child: child),
        ],
      ),
    );
  }
}

class _CostOverTimeChart extends StatelessWidget {
  const _CostOverTimeChart({required this.points});

  final List<TimeSeriesPointResponse> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: ShipItType.bodySmall.copyWith(
            color: context.palette.inkTertiary,
          ),
        ),
      );
    }

    final palette = context.palette;
    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final minValue = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);

    return CustomPaint(
      painter: _LineChartPainter(
        points: points,
        maxValue: maxValue,
        minValue: minValue,
        color: palette.accent,
        ruleColor: palette.rule,
        labelColor: palette.inkTertiary,
        formatValue: (v) => '\$${v.toStringAsFixed(2)}',
      ),
      size: Size.infinite,
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data, this.formatValue});

  final List<GroupedStatResponse> data;
  final String Function(double)? formatValue;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: ShipItType.bodySmall.copyWith(
            color: context.palette.inkTertiary,
          ),
        ),
      );
    }

    final palette = context.palette;
    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);

    return CustomPaint(
      painter: _BarChartPainter(
        data: data,
        maxValue: maxValue,
        color: palette.accent,
        ruleColor: palette.rule,
        labelColor: palette.inkTertiary,
        formatValue: formatValue ?? ((v) => v.toStringAsFixed(0)),
      ),
      size: Size.infinite,
    );
  }
}

class _EscalationChart extends StatelessWidget {
  const _EscalationChart({required this.data});

  final List<EscalationStatResponse> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: ShipItType.bodySmall.copyWith(
            color: context.palette.inkTertiary,
          ),
        ),
      );
    }

    final palette = context.palette;
    final maxValue = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return CustomPaint(
      painter: _BarChartPainter(
        data: data
            .map(
              (d) => GroupedStatResponse(
                key: 'Esc ${d.escalationIndex}',
                value: d.count.toDouble(),
                count: d.count,
              ),
            )
            .toList(),
        maxValue: maxValue.toDouble(),
        color: palette.attention,
        ruleColor: palette.rule,
        labelColor: palette.inkTertiary,
        formatValue: (v) => v.toInt().toString(),
      ),
      size: Size.infinite,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.maxValue,
    required this.minValue,
    required this.color,
    required this.ruleColor,
    required this.labelColor,
    required this.formatValue,
  });

  final List<TimeSeriesPointResponse> points;
  final double maxValue;
  final double minValue;
  final Color color;
  final Color ruleColor;
  final Color labelColor;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final padding = 40.0;
    final chartWidth = size.width - 2 * padding;
    final chartHeight = size.height - 2 * padding;

    final xScale = chartWidth / (points.length - 1).clamp(1, double.infinity);
    final yScale =
        chartHeight / (maxValue - minValue).clamp(0.001, double.infinity);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = padding + i * xScale;
      final y = size.height - padding - (points[i].value - minValue) * yScale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = ruleColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Draw points
    final pointPaint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final x = padding + i * xScale;
      final y = size.height - padding - (points[i].value - minValue) * yScale;
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    // Draw labels
    final textStyle = ShipItType.monoMeta.copyWith(
      color: labelColor,
      fontSize: 10,
    );
    final maxText = TextPainter(
      text: TextSpan(text: formatValue(maxValue), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxText.paint(
      canvas,
      Offset(padding - maxText.width - 8, padding - maxText.height / 2),
    );
    final minText = TextPainter(
      text: TextSpan(text: formatValue(minValue), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    minText.paint(
      canvas,
      Offset(
        padding - minText.width - 8,
        size.height - padding - minText.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
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

  final List<GroupedStatResponse> data;
  final double maxValue;
  final Color color;
  final Color ruleColor;
  final Color labelColor;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final padding = 40.0;
    final chartWidth = size.width - 2 * padding;
    final chartHeight = size.height - 2 * padding;
    final barWidth = chartWidth / data.length * 0.6;
    final spacing = chartWidth / data.length * 0.4;

    // Draw axes
    final axisPaint = Paint()
      ..color = ruleColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(padding, padding),
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

    for (var i = 0; i < data.length; i++) {
      final x = padding + i * (barWidth + spacing) + spacing / 2;
      final barHeight = (data[i].value / maxValue) * chartHeight;
      final y = size.height - padding - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      // Draw value on top
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

      // Draw key below
      final keyText = TextPainter(
        text: TextSpan(text: data[i].key, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      keyText.paint(
        canvas,
        Offset(x + barWidth / 2 - keyText.width / 2, size.height - padding + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class _MobileModelStats extends StatelessWidget {
  const _MobileModelStats({
    required this.stats,
    required this.timeRange,
    required this.customRange,
    required this.groupBy,
    required this.onTimeRangeChanged,
    required this.onCustomRangeChanged,
    required this.onGroupByChanged,
    required this.onRefresh,
  });

  final ModelStatsResponse stats;
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
              _buildSubtitle(stats),
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            const SizedBox(height: 18),
            const ContentRule(strong: true),
            _SummaryCards(stats: stats),
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
            _MobileChartsSection(stats: stats, groupBy: groupBy),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(ModelStatsResponse stats) {
    return '\$${stats.totalCostUsd.toStringAsFixed(2)} · ${_formatTokens(stats.totalTokens)} tokens · ${stats.totalExecutions} executions · ${(stats.successRate * 100).toStringAsFixed(1)}% success';
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
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
  const _MobileChartsSection({required this.stats, required this.groupBy});

  final ModelStatsResponse stats;
  final _GroupBy groupBy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileChartCard(
          title: 'Cost Over Time',
          child: _CostOverTimeChart(points: stats.costOverTime),
        ),
        const SizedBox(height: 16),
        _MobileChartCard(
          title: 'Tokens by Provider',
          child: _BarChart(data: stats.tokensByProvider),
        ),
        const SizedBox(height: 16),
        _MobileChartCard(
          title: 'Success Rate by Model',
          child: _BarChart(
            data: stats.successRateByModel,
            formatValue: (v) => '${(v * 100).toStringAsFixed(1)}%',
          ),
        ),
        const SizedBox(height: 16),
        _MobileChartCard(
          title: 'Escalation Frequency',
          child: _EscalationChart(data: stats.escalationFrequency),
        ),
        const SizedBox(height: 16),
        _MobileChartCard(
          title: 'Cost by Task Type',
          child: _BarChart(
            data: stats.costByTaskType,
            formatValue: (v) => '\$${v.toStringAsFixed(2)}',
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

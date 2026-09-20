import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../shared/design_primitives.dart';
import '../../shared/state_views.dart';
import '../../shared/mobile_chrome.dart';
import 'runs_bloc.dart';
import 'runs_event.dart';

/// The "All work" screen.
///
/// Transcribed from the Penpot board `BP · All work` (light/dark): header,
/// mono filter tabs with a 2px active underline, a count plus sort control,
/// then the same REF/WHAT IT IS/STATUS/RUNNING FOR table used on Overview.
///
/// The board carries hidden metric columns left over from duplicating the
/// Overview board; they are not part of this screen.
class RunsPage extends StatelessWidget {
  const RunsPage({super.key, this.bloc, this.clock});

  /// Test-only dependency seam. When null, the page constructs its own bloc
  /// from `ClientProvider.repository` (production path).
  final RunsBloc? bloc;

  /// Supplies "now" for elapsed times; injectable for deterministic goldens.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<RunsBloc>.value(
            value: provided,
            child: _RunsView(clock: clock),
          )
        : BlocProvider<RunsBloc>(
            create: (_) =>
                RunsBloc(repository: ClientProvider.repository)
                  ..add(RunsLoaded()),
            child: _RunsView(clock: clock),
          );
  }
}

/// The filters the design exposes, in board order.
enum WorkFilter {
  all('All work'),
  workingOnIt('Working on it'),
  needsYou('Needs you'),
  finished('Finished'),
  failed('Failed');

  const WorkFilter(this.label);

  final String label;

  /// True when a row belongs under this filter.
  bool matches(PlainStatus status) => switch (this) {
    WorkFilter.all => true,
    WorkFilter.workingOnIt =>
      status == PlainStatus.workingOnIt || status == PlainStatus.waitingToStart,
    WorkFilter.needsYou => status.isOperatorTurn,
    WorkFilter.finished => status == PlainStatus.finished,
    WorkFilter.failed =>
      status == PlainStatus.needsYouItFailed || status == PlainStatus.stopped,
  };
}

class _RunsView extends StatefulWidget {
  const _RunsView({this.clock});

  final DateTime Function()? clock;

  @override
  State<_RunsView> createState() => _RunsViewState();
}

class _RunsViewState extends State<_RunsView> {
  WorkFilter _filter = WorkFilter.all;
  bool _newestFirst = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunsBloc, RunsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const DesignLoadingSkeleton(
            title: 'All work',
            showColumns: true,
          );
        }
        if (state.errorMessage != null) {
          return DesignErrorState(
            title: "We could not reach the system's records.",
            detail: state.errorMessage!,
            onRetry: () => context.read<RunsBloc>().add(RunsLoaded()),
          );
        }

        final now = (widget.clock ?? DateTime.now)();
        final rows =
            state.runs
                .map(
                  (run) => _WorkRow(
                    id: run.id,
                    // Plain description leads; the technical title is kept for
                    // the technical-details block only.
                    title: run.plainName,
                    technicalTitle: run.name,
                    stateWire: run.state,
                    blocked: run.blockingHumanDecisionId != null,
                    // A finished item reports how long it took; an open one
                    // reports how long it has been going.
                    elapsed: (run.completedAt ?? now).difference(run.startedAt),
                  ),
                )
                .where((row) => _filter.matches(row.status))
                .toList()
              ..sort(
                (a, b) => _newestFirst
                    ? (a.elapsed ?? Duration.zero).compareTo(
                        b.elapsed ?? Duration.zero,
                      )
                    : (b.elapsed ?? Duration.zero).compareTo(
                        a.elapsed ?? Duration.zero,
                      ),
              );

        if (isMobile(context)) {
          return _MobileAllWork(
            rows: rows,
            total: state.runs.length,
            filter: _filter,
            newestFirst: _newestFirst,
            onFilter: (f) => setState(() => _filter = f),
            onToggleSort: () => setState(() => _newestFirst = !_newestFirst),
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
                  title: 'All work',
                  subtitle: _subtitle(state.runs.length),
                  liveLabel: 'LIVE',
                  freshness: PlainLanguage.updatedAgo(Duration.zero),
                ),
                const SizedBox(height: 25),
                FilterTabs(
                  labels: WorkFilter.values.map((f) => f.label).toList(),
                  activeIndex: WorkFilter.values.indexOf(_filter),
                  onSelected: (i) =>
                      setState(() => _filter = WorkFilter.values[i]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rows.length} ${rows.length == 1 ? 'item' : 'items'}',
                        style: ShipItType.sectionTitle.copyWith(
                          color: context.palette.inkPrimary,
                        ),
                      ),
                    ),
                    InlineLink(
                      label: _newestFirst ? 'Newest first' : 'Oldest first',
                      caret: CaretDirection.down,
                      onTap: () => setState(() => _newestFirst = !_newestFirst),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                WorkTable(
                  rows: rows,
                  emptyMessage: _filter == WorkFilter.all
                      ? 'No work has been recorded yet.'
                      : 'Nothing is ${_filter.label.toLowerCase()} right now.',
                ),
                const SizedBox(height: 46),
                TechnicalDetails(
                  note:
                      "Every row comes straight from the system's own records.",
                  lines: [
                    'filter=${_filter.name} · sort='
                        '${_newestFirst ? 'newest' : 'oldest'} · '
                        'shown=${rows.length}/${state.runs.length}',
                    for (final row in rows)
                      '${row.id} WorkItem.state=${row.stateWire}'
                          '${row.blocked ? ' · blocked on decision' : ''}'
                          '${row.technicalTitle == null ? '' : ' · title: ${row.technicalTitle}'}',
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _subtitle(int total) {
    if (total == 0) return 'Nothing has been recorded yet.';
    return '$total ${total == 1 ? 'item' : 'items'} in the last 30 days.';
  }
}

/// One row of the work table.
class _WorkRow {
  const _WorkRow({
    required this.id,
    required this.title,
    this.technicalTitle,
    required this.stateWire,
    required this.blocked,
    required this.elapsed,
  });

  final String id;
  final String title;
  final String? technicalTitle;
  final String stateWire;
  final bool blocked;
  final Duration? elapsed;

  PlainStatus get status =>
      PlainLanguage.statusFor(stateWire, blocked: blocked);
}

/// The REF / WHAT IT IS / STATUS / RUNNING FOR table.
class WorkTable extends StatelessWidget {
  const WorkTable({super.key, required this.rows, required this.emptyMessage});

  final List<Object> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typed = rows.cast<_WorkRow>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 7),
          child: Row(
            children: [
              SizedBox(width: ShipItMetrics.colWhat, child: MicroLabel('REF')),
              Expanded(child: MicroLabel('WHAT IT IS')),
              SizedBox(width: 200, child: MicroLabel('STATUS')),
              SizedBox(
                width: ShipItMetrics.colElapsedWidth,
                child: MicroLabel('RUNNING FOR'),
              ),
              SizedBox(width: 140),
            ],
          ),
        ),
        const ContentRule(strong: true),
        if (typed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              emptyMessage,
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          )
        else
          for (final row in typed) _WorkTableRow(row: row),
      ],
    );
  }
}

class _WorkTableRow extends StatelessWidget {
  const _WorkTableRow({required this.row});

  final _WorkRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = row.status;
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
                    AccentTick(
                      color: status.tickColor(palette),
                      height: ShipItMetrics.rowTickHeight,
                    ),
                    const SizedBox(width: ShipItMetrics.colRefInset - 2),
                    Expanded(
                      child: Text(
                        PlainLanguage.refLabel(row.id),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: ShipItType.ref.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.rowTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: Text(
                  status.label,
                  style: ShipItType.status.copyWith(
                    color: status.textColor(palette),
                  ),
                ),
              ),
              SizedBox(
                width: ShipItMetrics.colElapsedWidth,
                child: Text(
                  PlainLanguage.elapsed(row.elapsed),
                  textAlign: TextAlign.right,
                  style: ShipItType.duration.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InlineLink(
                    label: 'See details',
                    onTap: () => context.go('/runs/${row.id}'),
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

class _MobileAllWork extends StatelessWidget {
  const _MobileAllWork({
    required this.rows,
    required this.total,
    required this.filter,
    required this.newestFirst,
    required this.onFilter,
    required this.onToggleSort,
  });

  final List<_WorkRow> rows;
  final int total;
  final WorkFilter filter;
  final bool newestFirst;
  final ValueChanged<WorkFilter> onFilter;
  final VoidCallback onToggleSort;

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
              'All work',
              style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _RunsViewState._subtitle(total),
              style: ShipItType.pageSubtitle.copyWith(
                color: palette.inkSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: palette.controlBorder),
                      borderRadius: BorderRadius.circular(ShipItMetrics.radius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<WorkFilter>(
                          value: filter,
                          isDense: true,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(
                            ShipItMetrics.radius,
                          ),
                          dropdownColor: palette.card,
                          style: ShipItType.rowTitle.copyWith(
                            color: palette.inkPrimary,
                          ),
                          items: [
                            for (final option in WorkFilter.values)
                              DropdownMenuItem(
                                value: option,
                                child: Text('Showing: ${option.label}'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) onFilter(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InlineLink(
                  label: newestFirst ? 'Newest first' : 'Oldest first',
                  caret: CaretDirection.down,
                  onTap: onToggleSort,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ContentRule(),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Nothing to show under this filter.',
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              )
            else
              for (final row in rows)
                MobileWorkRow(
                  id: row.id,
                  title: row.title,
                  status: row.status,
                  elapsed: row.elapsed,
                  showChevron: true,
                  onTap: () => context.go('/runs/${row.id}'),
                ),
            const SizedBox(height: 18),
            TechnicalDetails(
              lines: [
                'filter=${filter.name} · '
                    'sort=${newestFirst ? 'newest' : 'oldest'} · '
                    'shown=${rows.length}/$total',
                for (final row in rows)
                  '${row.id} WorkItem.state=${row.stateWire}',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

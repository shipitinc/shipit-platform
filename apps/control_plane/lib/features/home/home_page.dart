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
import 'home_bloc.dart';
import 'home_event.dart';

/// The Overview screen.
///
/// Transcribed from the Penpot boards `BP · Home · Light` / `· Dark`. Band
/// order and vertical rhythm follow the board geometry: header (y=30) → rule
/// (90) → metrics (112–204) → rule (220) → "What's happening now" (240) →
/// gates (500) → "Machines and next steps" (756) → footer (848).
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.bloc, this.clock});

  /// Test-only dependency seam. When null, the page constructs its own bloc
  /// from `ClientProvider.repository` (production path).
  final HomeBloc? bloc;

  /// Supplies "now" for the freshness stamp. Injectable so goldens are
  /// deterministic instead of drifting with wall-clock time.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<HomeBloc>.value(
            value: provided,
            child: _HomeView(clock: clock),
          )
        : BlocProvider<HomeBloc>(
            create: (_) =>
                HomeBloc(repository: ClientProvider.repository)
                  ..add(HomeLoaded()),
            child: _HomeView(clock: clock),
          );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state.isLoading && state.generatedAt == null) {
          return const DesignLoadingSkeleton(
            title: 'Overview',
            showColumns: true,
          );
        }
        if (state.errorMessage != null) {
          return DesignErrorState(
            title: "We could not reach the system's records.",
            detail: state.errorMessage!,
            onRetry: () => context.read<HomeBloc>().add(HomeLoaded()),
          );
        }
        return isMobile(context)
            ? _OverviewBodyMobile(state: state)
            : _OverviewBody(state: state, clock: clock);
      },
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.state, this.clock});

  final HomeState state;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final now = (clock ?? DateTime.now)();
    final freshness = state.generatedAt == null
        ? null
        : PlainLanguage.updatedAgo(now.difference(state.generatedAt!));

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
              title: 'Overview',
              subtitle: PlainLanguage.overviewSubtitle(state.waitingCount),
              liveLabel: 'LIVE',
              freshness: freshness,
            ),
            const SizedBox(height: 21),
            _MetricBand(state: state),
            const SizedBox(height: 16),
            const ContentRule(),
            const SizedBox(height: 19),
            SectionHeading(
              title: "What's happening now",
              actionLabel: 'See all work →',
              onAction: () => context.go('/runs'),
            ),
            const SizedBox(height: 9),
            _HappeningTable(runs: state.recentRuns),
            const SizedBox(height: 25),
            _GateBand(gates: state.gates),
            const SizedBox(height: 14),
            const ContentRule(),
            const SizedBox(height: 16),
            _MachineBand(state: state),
            const SizedBox(height: 46),
            TechnicalDetails(
              note:
                  "Every number on this page comes straight from the system's "
                  'own records. Nothing here is guessed.',
              lines: _technicalLines(state),
            ),
          ],
        ),
      ),
    );
  }

  /// The only place raw system vocabulary is allowed to surface.
  static List<String> _technicalLines(HomeState state) {
    return [
      'running=${state.runningCount} · waitingOnYou=${state.waitingCount} · '
          'recentlyFinished=${state.recentCount} '
          '(passed=${state.finishedPassed}, failed=${state.finishedFailed})',
      if (state.generatedAt != null)
        'snapshot generatedAt=${state.generatedAt!.toIso8601String()}',
      'workers busy=${state.machinesBusy}/${state.machinesTotal} · '
          'pending jobs=${state.jobs.length}',
      for (final run in state.recentRuns)
        '${run.id} WorkItem.state=${run.stateWire}'
            '${run.blocked ? ' · blocked on decision' : ''}'
            '${run.technicalTitle == null ? '' : ' · title: ${run.technicalTitle}'}',
      for (final gate in state.gates)
        '${gate.decisionId} ${gate.decisionTypeWire} on ${gate.workItemId}',
      for (final job in state.jobs)
        '${job.jobId} JobState=${job.stateWire} '
            'attempt=${job.attempt}/${job.maxAttempts}',
    ];
  }
}

/// Three metric columns separated by vertical hairlines. No cards — the design
/// uses whitespace and 1px dividers only.
class _MetricBand extends StatelessWidget {
  const _MetricBand({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The board's band is 92px tall; that height is a consequence of the
    // content, so it is derived rather than hard-coded — a hard 92 overflows
    // as soon as text metrics differ from the design environment.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Metric(
              label: 'WORKING ON IT',
              value: state.runningCount,
              description: 'being built right now',
              tick: palette.accentTick,
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _Metric(
              label: 'NEEDS YOU',
              value: state.waitingCount,
              description: 'waiting for your approval',
              tick: palette.attentionTick,
              indent: true,
            ),
          ),
          const _MetricDivider(),
          Expanded(
            child: _Metric(
              label: 'FINISHED',
              value: state.recentCount,
              description: PlainLanguage.finishedDescription(
                passed: state.finishedPassed,
                failed: state.finishedFailed,
              ),
              tick: palette.positive,
              indent: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ShipItMetrics.hairline,
      color: context.palette.rule,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.description,
    required this.tick,
    this.indent = false,
  });

  final String label;
  final int value;
  final String description;
  final Color tick;

  /// Columns after the first sit 28px inside their divider.
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The design presents these as bare columns, so the grouping that a card
    // would imply has to be supplied to assistive tech explicitly.
    return Semantics(
      container: true,
      label: '$label: $value, $description',
      child: ExcludeSemantics(child: _metricColumn(palette)),
    );
  }

  Widget _metricColumn(ShipItPalette palette) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 28 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Board offsets inside the 92px band: key row at +4 (h14),
          // value at +22 (h48), description at +74.
          const SizedBox(height: 4),
          SizedBox(
            height: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccentTick(color: tick, height: ShipItMetrics.metricTickHeight),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: MicroLabel(label, color: palette.inkSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: ShipItType.metricValue.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
          ),
        ],
      ),
    );
  }
}

/// "What's happening now": mono column headers over 46px rows, each led by a
/// 2px status tick and closed by a "See details" link.
class _HappeningTable extends StatelessWidget {
  const _HappeningTable({required this.runs});

  final List<RunSummary> runs;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
        if (runs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nothing is running right now.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
            ),
          )
        else
          for (final run in runs) _HappeningRow(run: run),
      ],
    );
  }
}

class _HappeningRow extends StatelessWidget {
  const _HappeningRow({required this.run});

  final RunSummary run;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = run.status;
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
                        PlainLanguage.refLabel(run.id),
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
                  run.title,
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
                  PlainLanguage.elapsed(run.elapsed),
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
                    onTap: () => context.go('/runs/${run.id}'),
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

/// "Waiting for your approval" — the gate cards.
class _GateBand extends StatelessWidget {
  const _GateBand({required this.gates});

  final List<GateSummary> gates;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'Waiting for your approval'),
        const SizedBox(height: 6),
        Text(
          'Nothing moves forward until you decide. There is no time pressure '
          'beyond the limits shown.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
        ),
        const SizedBox(height: 12),
        if (gates.isEmpty)
          DesignPanel(
            child: Text(
              'Nothing needs your approval right now.',
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
          )
        else
          for (final gate in gates)
            Padding(
              padding: EdgeInsets.only(bottom: gate == gates.last ? 0 : 14),
              child: _GateCard(gate: gate),
            ),
      ],
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({required this.gate});

  final GateSummary gate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Board rhythm for `Gate Bg` (total 90px): 16 top, id row 16, 6, question
    // 21, 3, recommendation 16, 12 bottom.
    return DesignPanel(
      edgeColor: palette.attentionTick,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                PlainLanguage.refLabel(gate.decisionId),
                style: ShipItType.refStrong.copyWith(color: palette.inkPrimary),
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Text(
                  gate.typeLabel,
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
              if (gate.waiting != null)
                Text(
                  PlainLanguage.waitingFor(gate.waiting),
                  style: ShipItType.status.copyWith(color: palette.attention),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gate.question,
                      style: ShipItType.question.copyWith(
                        color: palette.inkPrimary,
                      ),
                    ),
                    if (gate.recommendation != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'We suggest: ${gate.recommendation}',
                        style: ShipItType.bodySmall.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Padding(
                // `Gate Btn` sits 18px below the top of this row on the board.
                padding: const EdgeInsets.only(top: 18),
                child: SizedBox(
                  width: 128,
                  height: 24,
                  child: OutlinedButton(
                    onPressed: () =>
                        context.go('/needs-you/${gate.decisionId}'),
                    child: const Text('Review and decide'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Machines and next steps": the queue strip with right-aligned capacity.
class _MachineBand extends StatelessWidget {
  const _MachineBand({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final jobs = state.jobs.take(2).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 184,
          child: SectionHeading(title: 'Machines and next steps', small: true),
        ),
        for (final job in jobs)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AccentTick(
                      color: job.isAttention
                          ? palette.attentionTick
                          : palette.accentTick,
                      height: ShipItMetrics.metricTickHeight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              PlainLanguage.refLabel(job.jobId),
                              style: ShipItType.status.copyWith(
                                color: palette.inkPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              job.stateLabel,
                              style: ShipItType.status.copyWith(
                                color: job.isAttention
                                    ? palette.attention
                                    : palette.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (job.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            job.description!,
                            style: ShipItType.bodyMicro.copyWith(
                              color: palette.inkTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (jobs.isEmpty)
          Expanded(
            child: Text(
              'No work is queued.',
              style: ShipItType.bodyMicro.copyWith(color: palette.inkTertiary),
            ),
          ),
        SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${state.machinesBusy} of ${state.machinesTotal} '
                '${state.machinesTotal == 1 ? 'machine' : 'machines'} busy',
                style: ShipItType.status.copyWith(color: palette.inkSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'running on this computer',
                style: ShipItType.bodyMicro.copyWith(
                  color: palette.inkTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewBodyMobile extends StatelessWidget {
  const _OverviewBodyMobile({required this.state});

  final HomeState state;

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
              'Overview',
              style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              PlainLanguage.overviewSubtitle(state.waitingCount),
              style: ShipItType.pageSubtitle.copyWith(
                color: palette.inkSecondary,
              ),
            ),
            const SizedBox(height: 22),
            _MobileMetrics(state: state),
            const SizedBox(height: 16),
            const ContentRule(),
            const SizedBox(height: 15),
            Text(
              'Waiting for your approval',
              style: ShipItType.sectionTitle.copyWith(
                color: palette.inkPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (state.gates.isEmpty)
              DesignPanel(
                child: Text(
                  'Nothing needs your approval right now.',
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
              )
            else
              for (final gate in state.gates)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: gate == state.gates.last ? 0 : 10,
                  ),
                  child: _MobileGateCard(gate: gate),
                ),
            const SizedBox(height: 20),
            const ContentRule(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "What's happening now",
                    style: ShipItType.sectionTitle.copyWith(
                      color: palette.inkPrimary,
                    ),
                  ),
                ),
                InlineLink(
                  label: 'See all →',
                  onTap: () => context.go('/runs'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final run in state.recentRuns)
              MobileWorkRow(
                id: run.id,
                title: run.title,
                status: run.status,
                elapsed: run.elapsed,
                onTap: () => context.go('/runs/${run.id}'),
                showRef: false,
              ),
            const SizedBox(height: 18),
            TechnicalDetails(lines: _OverviewBody._technicalLines(state)),
          ],
        ),
      ),
    );
  }
}

/// Three compact metric columns (`Met Key/Val/Desc`).
class _MobileMetrics extends StatelessWidget {
  const _MobileMetrics({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final metrics = <(String, int, String, Color)>[
      ('WORKING ON IT', state.runningCount, 'in progress', palette.accentTick),
      (
        'NEEDS YOU',
        state.waitingCount,
        'waiting on you',
        palette.attentionTick,
      ),
      ('FINISHED', state.recentCount, 'last day', palette.positive),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final metric in metrics)
          Expanded(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: '${metric.$1}: ${metric.$2}, ${metric.$3}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AccentTick(
                          color: metric.$4,
                          height: ShipItMetrics.metricTickHeight,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: MicroLabel(
                              metric.$1,
                              color: palette.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${metric.$2}',
                    style: ShipItType.metricValueMobile.copyWith(
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.$3,
                    style: ShipItType.bodyMicro.copyWith(
                      color: palette.inkTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A gate card reduced to what fits a phone: reference, wait, the question,
/// the artifact link and a single call to action.
class _MobileGateCard extends StatelessWidget {
  const _MobileGateCard({required this.gate});

  final GateSummary gate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.attentionTick,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                PlainLanguage.refLabel(gate.decisionId),
                style: ShipItType.refStrong.copyWith(color: palette.inkPrimary),
              ),
              const Spacer(),
              if (gate.waiting != null)
                Text(
                  PlainLanguage.waitingFor(gate.waiting),
                  style: ShipItType.status.copyWith(color: palette.attention),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            gate.question,
            style: ShipItType.question.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 12),
          MobilePrimaryButton(
            label: 'Review and decide',
            fullWidth: false,
            onPressed: () => context.go('/needs-you/${gate.decisionId}'),
          ),
        ],
      ),
    );
  }
}

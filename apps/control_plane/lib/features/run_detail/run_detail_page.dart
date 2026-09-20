import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../shared/design_primitives.dart';
import '../../shared/state_views.dart';
import '../../shared/detail_sections.dart';
import '../../shared/mobile_chrome.dart';
import 'run_detail_bloc.dart';
import 'run_detail_event.dart';

/// The Run detail screen.
///
/// Transcribed from the Penpot board `BP · Run Detail` (light/dark):
/// breadcrumb + title + meta strip, then a two-column body — explanation,
/// definition rows, evidence panel and the "What's happened so far" timeline
/// on the left; a decision call-to-action panel on the right.
///
/// Navigation back to the list is the breadcrumb, not a history pop: routes
/// are entered with `go`, which replaces the stack, so popping would leave an
/// empty navigator.
class RunDetailPage extends StatelessWidget {
  const RunDetailPage({super.key, required this.runId, this.bloc, this.clock});

  final String runId;

  /// Test-only dependency seam.
  final RunDetailBloc? bloc;

  /// Supplies "now" for elapsed values; injectable for deterministic goldens.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<RunDetailBloc>.value(
            value: provided,
            child: _RunDetailView(clock: clock),
          )
        : BlocProvider<RunDetailBloc>(
            create: (_) => RunDetailBloc(
              runId: runId,
              repository: ClientProvider.repository,
            )..add(RunDetailLoaded()),
            child: _RunDetailView(clock: clock),
          );
  }
}

class _RunDetailView extends StatelessWidget {
  const _RunDetailView({this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BlocBuilder<RunDetailBloc, RunDetailState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const DesignLoadingSkeleton(
            title: 'Loading',
            rows: 4,
            showColumns: false,
          );
        }
        if (state.errorMessage != null) {
          return DetailErrorState(
            title: 'We could not open this run.',
            message: state.errorMessage!,
            parentLabel: 'All work',
            onParentTap: () => context.go('/runs'),
          );
        }

        final now = (clock ?? DateTime.now)();
        final status = PlainLanguage.statusFor(
          state.state,
          blocked: state.blockingHumanDecisionId != null,
        );
        final elapsed = state.startedAt == null
            ? null
            : now.difference(state.startedAt!);

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile(context)
                  ? ShipItMetrics.mobileGutter
                  : ShipItMetrics.contentGutter,
              isMobile(context) ? 16 : 26,
              isMobile(context)
                  ? ShipItMetrics.mobileGutter
                  : ShipItMetrics.contentGutter,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailHeader(
                  showBreadcrumb: !isMobile(context),
                  compact: isMobile(context),
                  parentLabel: 'All work',
                  parentRef: PlainLanguage.refLabel(state.runId),
                  onParentTap: () => context.go('/runs'),
                  title: PlainLanguage.headline(
                    title: state.name,
                    description: state.description,
                  ),
                  titleKey: const Key('run-detail-title'),
                  statusLabel: status.isOperatorTurn
                      ? 'WAITING FOR YOU'
                      : status.label.toUpperCase(),
                  statusColor: status.textColor(palette),
                  facts: [
                    if (state.startedAt != null)
                      (
                        'started ${PlainLanguage.timeOfDay(state.startedAt!)}',
                        null,
                      ),
                    (
                      '${status == PlainStatus.finished ? 'took' : 'running'} '
                          '${PlainLanguage.elapsed(elapsed)}',
                      status.isOperatorTurn ? palette.attention : null,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (isMobile(context)) ...[
                  // One column on a phone: the call to action follows the
                  // record rather than sitting beside it.
                  _LeftColumn(state: state, status: status),
                  const SizedBox(height: 20),
                  if (state.blockingHumanDecisionId != null)
                    MobilePrimaryButton(
                      label: 'Review and decide',
                      onPressed: () => context.go(
                        '/needs-you/${state.blockingHumanDecisionId}'
                        '?wi=${state.runId}',
                      ),
                    ),
                ] else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Stack when the pane is too narrow to carry the panel
                      // beside the record.
                      final stacked =
                          constraints.maxWidth -
                              ShipItMetrics.sidePanelWidth -
                              ShipItMetrics.sidePanelGap <
                          ShipItMetrics.sidePanelMinContent;
                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LeftColumn(state: state, status: status),
                            const SizedBox(height: 24),
                            _RightColumn(state: state, status: status),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _LeftColumn(state: state, status: status),
                          ),
                          const SizedBox(width: 32),
                          SizedBox(
                            width: 392,
                            child: _RightColumn(state: state, status: status),
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 40),
                TechnicalDetails(
                  lines: [
                    'WorkItem.state = ${state.state}'
                        '${state.blockingHumanDecisionId == null ? '' : ' · blocked by ${state.blockingHumanDecisionId}'}',
                    'title: ${state.name} · category: ${state.category}',
                    for (final event in state.events)
                      '${event.timestamp.toIso8601String()} ${event.raw}',
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.state, required this.status});

  final RunDetailState state;
  final PlainStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Where this run got to',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          status.isOperatorTurn
              ? 'This run stopped because it needs a decision from you.'
              : 'This is the durable record of what the system has done.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 18),
        DefinitionList(entries: _entries(state, status)),
        if (state.artifacts.isNotEmpty) ...[
          const SizedBox(height: 20),
          EvidencePanel(
            title: 'DESIGN AND CHECKS',
            artifactTitle:
                state.artifacts.first.description?.trim().isNotEmpty == true
                ? state.artifacts.first.description!.trim()
                : state.artifacts.first.artifactType,
            artifactSubtitle: 'Recorded against this run',
            links: [
              for (final artifact in state.artifacts.take(2))
                (artifact.artifactType, artifact.uri),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          "What's happened so far",
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 6),
        TimelineTable(events: state.events),
      ],
    );
  }

  /// Only rows that can be substantiated from the durable record are shown.
  static List<DefinitionEntry> _entries(
    RunDetailState state,
    PlainStatus status,
  ) {
    return [
      DefinitionEntry(
        label: 'WHAT THIS IS ABOUT',
        value: PlainLanguage.headline(
          title: state.name,
          description: state.description,
        ),
        ref: PlainLanguage.refLabel(state.runId),
      ),
      DefinitionEntry(label: 'STATUS', value: status.label),
      if (state.blockingHumanDecisionId != null)
        DefinitionEntry(
          label: "WHAT'S NEEDED",
          value: 'Your decision before this can continue',
          ref: PlainLanguage.refLabel(state.blockingHumanDecisionId!),
        ),
      if (state.blockingHumanDecisionId != null)
        DefinitionEntry(
          label: "WHY IT'S WAITING",
          // The state the run halted in explains the wait; the parked state
          // ("waiting_for_human_decision") only restates it.
          value: PlainLanguage.haltExplanation(
            state.haltedState ?? state.state,
          ),
        ),
      if (state.heldUpJobs.isNotEmpty)
        DefinitionEntry(
          label: "WHAT'S HELD UP",
          value:
              '${state.heldUpJobs.length} build '
              '${state.heldUpJobs.length == 1 ? 'step is' : 'steps are'} '
              'waiting to start',
          ref: PlainLanguage.refLabel(state.heldUpJobs.first),
        ),
    ];
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({required this.state, required this.status});

  final RunDetailState state;
  final PlainStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // The board's right panel exists to hand the operator to the decision.
    // With nothing to decide there is nothing truthful to put here.
    if (state.blockingHumanDecisionId == null) {
      return SidePanel(
        children: [
          Text(
            'Nothing needs you here',
            style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            status == PlainStatus.finished
                ? 'This run has finished. Its record is kept for audit.'
                : 'The system is still working on this run.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
        ],
      );
    }

    return SidePanel(
      children: [
        Text(
          'Needs your approval',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'You can review the full decision and approve it from here.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 14),
        const ContentRule(),
        const SizedBox(height: 15),
        if (state.recommendation != null) ...[
          const MicroLabel('WHAT WE SUGGEST'),
          const SizedBox(height: 4),
          Text(
            state.recommendation!,
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          height: 36,
          child: FilledButton(
            onPressed: () => context.go(
              '/needs-you/${state.blockingHumanDecisionId}?wi=${state.runId}',
            ),
            child: const Text('Review and decide'),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Opens the approval screen',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ),
      ],
    );
  }
}

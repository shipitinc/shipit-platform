import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/state_views.dart';
import '../../shared/detail_sections.dart';
import '../../shared/mobile_chrome.dart';
import 'failed_work_item_action_panel.dart';
import 'operator_action_copy.dart';
import 'operator_action_panel.dart';
import 'review_repair_affordance.dart';
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
                      '${status.elapsedVerb} '
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
                // THE REPAIR, BELOW EVERYTHING ELSE ON THE PAGE.
                //
                // Not a peer of "Review and decide" and deliberately not beside
                // it: that button asks the operator to approve work, this offers
                // to set aside a decision that may never have been reviewed at
                // all. One call site, below the two-column body, so it cannot
                // drift into a second call site beside the approval CTA on one
                // layout and not the other — and so it survives the repair it
                // performs, which retires the very decision whose presence
                // gates it.
                //
                // It contributes NO spacing of its own when it renders nothing:
                // it returns `SizedBox.shrink()` on an item that is not parked,
                // so a run with nothing to repair is laid out exactly as it was
                // before this block existed. The run-detail goldens pin that.
                ReviewRepairAffordance(
                  decisionId: state.blockingHumanDecisionId,
                  report: state.repairReport,
                  stripOpen: state.isRepairStripOpen,
                  submitting: state.isSubmittingRepair,
                  onOpen: () => context.read<RunDetailBloc>().add(
                    RunDetailReviewRepairStarted(),
                  ),
                  onSubmit: (reason, requestId) =>
                      context.read<RunDetailBloc>().add(
                        RunDetailReviewRepairSubmitted(
                          reason: reason,
                          requestId: requestId,
                        ),
                      ),
                  onCancel: () => context.read<RunDetailBloc>().add(
                    RunDetailReviewRepairCancelled(),
                  ),
                ),
                const SizedBox(height: 40),
                TechnicalDetails(
                  lines: [
                    'WorkItem.state = ${state.state}'
                        '${state.blockingHumanDecisionId == null ? '' : ' · blocked by ${state.blockingHumanDecisionId}'}',
                    'title: ${state.name} · category: ${state.category}',
                    for (final event in state.events)
                      '${event.timestamp.toIso8601String()} ${event.raw}',
                    // AC-22: the raw reason and the job's failure JSON appear
                    // verbatim here, one disclosure away. The panel shows a
                    // plain sentence; this keeps the engineer's record intact
                    // rather than translating it away.
                    if (state.actionContext?.failure?.reason case final r?)
                      'failure reason: $r',
                    if (state.actionContext?.failure?.jobFailureJson
                        case final j?)
                      'failure json: $j',
                    if (state.actionContext case final a?)
                      'operator actions: ${a.priorActions.length}'
                          '${a.retryLimitResolved ? '' : ' · SHIPIT_OPERATOR_MAX_RETRIES not resolved'}'
                          '${a.capacity.resolved ? ' · capacity ${a.capacity.inFlight}/${a.capacity.cap} (snapshot only)' : ''}',
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
        if (state.modelExecutions.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ModelExecutionsSection(executions: state.modelExecutions),
        ],
        const SizedBox(height: 20),
        Text(
          "What's happened so far",
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 6),
        TimelineTable(
          events: [
            for (final event in state.events)
              TimelineEntry(
                timestamp: event.timestamp,
                message: event.message,
                needsOperator: event.needsOperator,
              ),
          ],
        ),
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
      if (state.actionContext case final a? when a.actions.isNotEmpty)
        DefinitionEntry(
          label: 'WHAT YOU CAN DO',
          // Stated from the offered actions, not the failed-work pair's
          // words: a 'reland'/'reroute' offer is not "start it again", and
          // neither is a deploy or a reclaim.
          value: whatYouCanDoSentence(a.actions.map((x) => x.action)),
          prose: true,
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

class _ModelExecutionsSection extends StatelessWidget {
  const _ModelExecutionsSection({required this.executions});

  final List<ModelExecutionRecordResponse> executions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final production = _getProductionExecution();
    final reviews = _getReviewExecutions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Executions',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Models used for production and review steps in this run.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 16),
        if (production != null) ...[
          _ModelExecutionCard(
            title: 'Production Model',
            execution: production,
            isPrimary: true,
          ),
          const SizedBox(height: 12),
        ],
        if (reviews.isNotEmpty) ...[
          Text(
            'Review Models',
            style: ShipItType.sectionTitleSmall.copyWith(
              color: palette.inkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final review in reviews) ...[
            _ModelExecutionCard(
              title: _formatRole(review.role),
              execution: review,
              isPrimary: false,
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (production == null && reviews.isEmpty) ...[
          _ModelExecutionCard(
            title: 'No Model Executions',
            execution: executions.first,
            isPrimary: false,
            showAll: true,
          ),
        ],
        const SizedBox(height: 8),
        if (executions.any((e) => e.escalationIndex > 0))
          _EscalationHistory(executions: executions),
      ],
    );
  }

  ModelExecutionRecordResponse? _getProductionExecution() {
    // First execution with escalationIndex 0 for implementer role, or first execution overall
    try {
      return executions
          .where((e) => e.escalationIndex == 0 && e.role == 'IMPLEMENTER')
          .first;
    } catch (_) {
      return executions.isNotEmpty ? executions.first : null;
    }
  }

  List<ModelExecutionRecordResponse> _getReviewExecutions() {
    return executions
        .where((e) => e.role != 'IMPLEMENTER' || e.escalationIndex > 0)
        .toList()
      ..sort((a, b) => a.escalationIndex.compareTo(b.escalationIndex));
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

class _ModelExecutionCard extends StatelessWidget {
  const _ModelExecutionCard({
    required this.title,
    required this.execution,
    required this.isPrimary,
    this.showAll = false,
  });

  final String title;
  final ModelExecutionRecordResponse execution;
  final bool isPrimary;
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: isPrimary ? palette.positive : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPrimary) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.positive,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: ShipItType.ref.copyWith(
                  color: palette.inkPrimary,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: execution.success
                      ? palette.positive.withValues(alpha: 0.1)
                      : palette.negative.withValues(alpha: 0.1),
                  border: Border.all(
                    color: execution.success
                        ? palette.positive.withValues(alpha: 0.5)
                        : palette.negative.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  execution.success ? 'SUCCESS' : 'FAILED',
                  style: ShipItType.microLabel.copyWith(
                    color: execution.success
                        ? palette.positive
                        : palette.negative,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      execution.modelId,
                      style: ShipItType.rowTitle.copyWith(
                        color: palette.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      execution.provider,
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${execution.costUsd.toStringAsFixed(4)}',
                    style: ShipItType.duration.copyWith(
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${execution.totalTokens} tokens',
                    style: ShipItType.monoMeta.copyWith(
                      color: palette.inkTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (execution.escalationIndex > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.attention,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Escalation step ${execution.escalationIndex}',
                  style: ShipItType.monoMeta.copyWith(color: palette.attention),
                ),
              ],
            ),
          ],
          if (execution.error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Error: ${execution.error}',
              style: ShipItType.bodySmall.copyWith(color: palette.negative),
            ),
          ],
        ],
      ),
    );
  }
}

class _EscalationHistory extends StatelessWidget {
  const _EscalationHistory({required this.executions});

  final List<ModelExecutionRecordResponse> executions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final escalations = executions.where((e) => e.escalationIndex > 0).toList()
      ..sort((a, b) => a.escalationIndex.compareTo(b.escalationIndex));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ContentRule(),
        const SizedBox(height: 8),
        Text(
          'Escalation History',
          style: ShipItType.sectionTitleSmall.copyWith(
            color: palette.inkPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final esc in escalations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: esc.success
                        ? palette.positive.withValues(alpha: 0.1)
                        : palette.negative.withValues(alpha: 0.1),
                    border: Border.all(
                      color: esc.success ? palette.positive : palette.negative,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      esc.escalationIndex.toString(),
                      style: ShipItType.ref.copyWith(
                        color: esc.success
                            ? palette.positive
                            : palette.negative,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${esc.modelId} (${esc.provider})',
                        style: ShipItType.monoMeta.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                      Text(
                        '${_formatRole(esc.role)} · \$${esc.costUsd.toStringAsFixed(4)} · ${esc.totalTokens} tokens',
                        style: ShipItType.monoMeta.copyWith(
                          color: palette.inkTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  esc.success ? 'OK' : 'FAILED',
                  style: ShipItType.status.copyWith(
                    color: esc.success ? palette.positive : palette.negative,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({required this.state, required this.status});

  final RunDetailState state;
  final PlainStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = (DateTime.now)();

    // The action panel REPLACES the "Nothing needs you here" branch, and does
    // so only when the server says an action is legal.
    //
    // That condition matters in both directions. Without it the screen would
    // say "Nothing needs you here" under a heading promising a restart, which
    // is worse than a dead button because it is a panel that promises one.
    // And an empty action list is the signal for today's existing text — a
    // finished run still says "This run has finished. Its record is kept for
    // audit." (AC-2, §8.4).
    final actionContext = state.actionContext;
    if (actionContext case final a? when a.actions.isNotEmpty) {
      // The deploy advance and the stranded reclaim are not failure-panel
      // actions — the copy there is "it failed", which is false for both.
      // They get their own panel; the action sets are state-exclusive so at
      // most one of the two surfaces can ever be offered.
      if (a.actions.any(
        (x) =>
            x.action == 'deploy' ||
            x.action == 'reclaim' ||
            x.action == 'reland' ||
            x.action == 'reroute',
      )) {
        return OperatorActionPanel(
          actionContext: a,
          pendingAction: state.pendingAction,
          submitting: state.isSubmittingAction,
          outcomeAnnouncement: state.actionAnnouncement,
          onActionPressed: (action) =>
              context.read<RunDetailBloc>().add(RunDetailActionStarted(action)),
          onSubmit: (action, reason, requestId) =>
              context.read<RunDetailBloc>().add(
                RunDetailActionSubmitted(
                  action: action,
                  reason: reason,
                  requestId: requestId,
                ),
              ),
          onCancel: () =>
              context.read<RunDetailBloc>().add(RunDetailActionCancelled()),
        );
      }
      return FailedWorkItemActionPanel(
        actionContext: a,
        haltCount: state.events.where((e) => e.type == 'agent_failed').length,
        now: now,
        pendingAction: state.pendingAction,
        submitting: state.isSubmittingAction,
        outcomeAnnouncement: state.actionAnnouncement,
        onRetryPressed: () =>
            context.read<RunDetailBloc>().add(RunDetailActionStarted('retry')),
        onStopPressed: () =>
            context.read<RunDetailBloc>().add(RunDetailActionStarted('stop')),
        onSubmit: (action, reason, requestId) =>
            context.read<RunDetailBloc>().add(
              RunDetailActionSubmitted(
                action: action,
                reason: reason,
                requestId: requestId,
              ),
            ),
        onCancel: () =>
            context.read<RunDetailBloc>().add(RunDetailActionCancelled()),
      );
    }

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
          // A read failure is stated rather than hidden. Rendering the
          // reassuring "nothing needs you" text when in fact the actions
          // could not be READ is the exact quiet-screen dishonesty this panel
          // exists to close, one layer up.
          if (state.actionContextError != null) ...[
            const SizedBox(height: 10),
            Text(
              state.actionContextError!,
              style: ShipItType.bodyMicro.copyWith(color: palette.inkTertiary),
            ),
          ],
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

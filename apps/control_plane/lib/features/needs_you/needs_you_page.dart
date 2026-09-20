import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../shared/decision_choice.dart';
import '../../shared/design_primitives.dart';
import '../../shared/state_views.dart';
import '../../shared/mobile_chrome.dart';
import '../../shared/detail_sections.dart';
import 'needs_you_bloc.dart';
import 'needs_you_event.dart';

/// The "Needs you" screen.
///
/// Transcribed from the Penpot board `BP · Needs You` (light/dark): one tall
/// card per pending decision — header strip (ref · type · run · waiting), the
/// question, a four-column fact grid, the suggestion, and the decision's own
/// actions — followed by the "Already decided" history table.
///
/// Action labels come from the decision's real options, so an escalation
/// offers "Resume / Stop this work" while a design gate offers
/// "Approve / Request changes / Reject", exactly as the board shows.
class NeedsYouPage extends StatelessWidget {
  const NeedsYouPage({super.key, this.bloc, this.clock});

  /// Test-only dependency seam.
  final NeedsYouBloc? bloc;

  /// Supplies "now"; injectable for deterministic goldens.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<NeedsYouBloc>.value(
            value: provided,
            child: _NeedsYouView(clock: clock),
          )
        : BlocProvider<NeedsYouBloc>(
            create: (_) =>
                NeedsYouBloc(repository: ClientProvider.repository)
                  ..add(NeedsYouLoaded()),
            child: _NeedsYouView(clock: clock),
          );
  }
}

class _NeedsYouView extends StatelessWidget {
  const _NeedsYouView({this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BlocBuilder<NeedsYouBloc, NeedsYouState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const DesignLoadingSkeleton(
            title: 'Needs you',
            showColumns: false,
          );
        }
        if (state.errorMessage != null) {
          return DetailErrorState(
            title: "We could not reach the system's records.",
            message: state.errorMessage!,
            parentLabel: 'Overview',
            onParentTap: () => context.go('/'),
          );
        }

        final now = (clock ?? DateTime.now)();
        final pending = state.decisions;

        return NotificationListener<ScrollNotification>(
          // Page the ledger as its end comes into view, rather than making
          // the operator hunt for a "load more" control.
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 240 &&
                state.hasMoreHistory &&
                !state.isLoadingMoreHistory) {
              context.read<NeedsYouBloc>().add(NeedsYouHistoryRequested());
            }
            return false;
          },
          child: SingleChildScrollView(
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
                    title: 'Needs you',
                    subtitle: _subtitle(pending.length),
                    trailing: pending.isEmpty
                        ? null
                        : Row(
                            children: [
                              AccentTick(
                                color: palette.attentionTick,
                                height: ShipItMetrics.metricTickHeight,
                              ),
                              const SizedBox(width: 8),
                              MicroLabel(
                                '${pending.length} WAITING',
                                color: palette.attention,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 25),
                  if (pending.isEmpty)
                    DesignEmptyState(
                      tone: EmptyTone.settled,
                      title: 'Nothing needs your approval.',
                      body:
                          'When the system reaches a point it cannot decide on '
                          'its own, it stops and asks you here. Nothing moves '
                          'forward until you answer.',
                      actionLabel: 'See all work →',
                      onAction: () => context.go('/runs'),
                    )
                  else
                    for (final decision in pending)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: decision == pending.last ? 0 : 24,
                        ),
                        child: _GateCard(
                          decision: decision,
                          now: now,
                          compact: isMobile(context),
                          pendingChoice:
                              state.pendingAction?.decisionId == decision.id
                              ? decision.options
                                    .where(
                                      (o) =>
                                          o.value ==
                                          state.pendingAction!.choice,
                                    )
                                    .firstOrNull
                              : null,
                          submitting: state.submittingDecisionId == decision.id,
                        ),
                      ),
                  const SizedBox(height: 38),
                  _AlreadyDecided(
                    entries: state.resolved,
                    now: now,
                    compact: isMobile(context),
                    hasMore: state.hasMoreHistory,
                    loadingMore: state.isLoadingMoreHistory,
                  ),
                  const SizedBox(height: 30),
                  TechnicalDetails(
                    lines: [
                      'pending=${pending.length} · '
                          'resolved shown=${state.resolved.length}',
                      for (final d in pending)
                        '${d.id} ${d.decisionTypeWire} on ${d.runId} '
                            '· options: ${d.options.map((o) => o.value).join(', ')}',
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _subtitle(int count) {
    if (count == 0) return 'You are all caught up.';
    if (count == 1) return '1 decision is waiting on you.';
    return '$count decisions are waiting on you.';
  }
}

/// One pending decision (Penpot `Gate Bg n`).
class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.decision,
    required this.now,
    this.pendingChoice,
    this.submitting = false,
    this.compact = false,
  });

  final PendingDecision decision;
  final DateTime now;

  /// Set once the operator has picked an action on this card.
  final DecisionChoiceOption? pendingChoice;
  final bool submitting;

  /// Mobile composition: facts stack, and the card offers a single call to
  /// action instead of one button per choice — a phone column cannot carry
  /// three actions plus an inline reason field.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      container: true,
      // Without this, the buttons' tap actions merge upward into this node and
      // the whole card becomes one tappable region - with no cursor change to
      // advertise it. Children keep their own nodes and their own hit areas.
      explicitChildNodes: true,
      label: 'Decision for ${decision.runTitle}: ${decision.question}',
      child: _card(context, palette),
    );
  }

  Widget _card(BuildContext context, ShipItPalette palette) {
    return DesignPanel(
      edgeColor: palette.attentionTick,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header strip: ref · type · run, with the wait on the right.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(
                  PlainLanguage.refLabel(decision.id),
                  style: ShipItType.refStrong.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
                if (!compact) ...[
                  const _Sep(),
                  Text(
                    PlainLanguage.decisionType(decision.decisionTypeWire),
                    style: ShipItType.monoMeta.copyWith(
                      color: palette.inkTertiary,
                    ),
                  ),
                  const _Sep(),
                  Flexible(
                    child: Text(
                      PlainLanguage.refLabel(decision.runId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (decision.requestedAt != null)
                  Text(
                    PlainLanguage.waitingFor(
                      now.difference(decision.requestedAt!),
                    ),
                    style: ShipItType.status.copyWith(color: palette.attention),
                  ),
              ],
            ),
          ),
          const ContentRule(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  decision.question,
                  style: ShipItType.question.copyWith(
                    fontSize: 16,
                    color: palette.inkPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _FactGrid(decision: decision, now: now, stacked: compact),
                const SizedBox(height: 12),
                const ContentRule(),
                if (decision.recommendation != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AccentTick(color: palette.accentTick, height: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MicroLabel(
                              'WHAT WE SUGGEST',
                              color: palette.accent,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              decision.recommendation!,
                              style: ShipItType.bodySmall.copyWith(
                                color: palette.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (compact)
                  MobilePrimaryButton(
                    label: 'Review and decide',
                    onPressed: () => _open(context),
                  )
                else if (pendingChoice == null)
                  Row(
                    children: [
                      for (final option in decision.options) ...[
                        SizedBox(
                          width: 150,
                          height: 28,
                          child: option.recommended
                              ? FilledButton(
                                  onPressed: () => _start(context, option),
                                  child: Text(option.label),
                                )
                              : OutlinedButton(
                                  onPressed: () => _start(context, option),
                                  child: Text(option.label),
                                ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      const Spacer(),
                      InlineLink(
                        label: 'See full details',
                        onTap: () => _open(context),
                      ),
                    ],
                  )
                else
                  _ConfirmStrip(
                    decision: decision,
                    choice: pendingChoice!,
                    submitting: submitting,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A button named "Approve" approves. It opens an inline reason strip on
  /// this card rather than navigating, so the action the operator pressed is
  /// the action that gets recorded.
  void _start(BuildContext context, DecisionChoiceOption option) {
    context.read<NeedsYouBloc>().add(
      NeedsYouActionStarted(decisionId: decision.id, choice: option.value),
    );
  }

  /// "See full details" is the only control that leaves the list.
  void _open(BuildContext context) =>
      context.go('/needs-you/${decision.id}?wi=${decision.runId}');
}

/// Inline reason capture for an action taken on a card.
///
/// Appears in place of the button row once an action is chosen, so the
/// operator stays on the list and the button they pressed is the outcome that
/// gets written. The reason is required here for the same purpose it serves on
/// the decision screen: the record should say why, not just what.
class _ConfirmStrip extends StatefulWidget {
  const _ConfirmStrip({
    required this.decision,
    required this.choice,
    required this.submitting,
  });

  final PendingDecision decision;
  final DecisionChoiceOption choice;
  final bool submitting;

  @override
  State<_ConfirmStrip> createState() => _ConfirmStripState();
}

class _ConfirmStripState extends State<_ConfirmStrip> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sentiment = PlainLanguage.sentimentFor(widget.choice.value);
    final accent = switch (sentiment) {
      OutcomeSentiment.proceed => palette.positive,
      OutcomeSentiment.revise => palette.attention,
      OutcomeSentiment.stop => palette.negative,
    };
    final ready = _reason.text.trim().isNotEmpty && !widget.submitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AccentTick(color: accent, height: 12),
            const SizedBox(width: 8),
            Text(
              'You chose: ${widget.choice.label}',
              style: ShipItType.status.copyWith(color: accent),
            ),
            const SizedBox(width: 12),
            if (widget.choice.description != null)
              Expanded(
                child: Text(
                  widget.choice.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const MicroLabel('WHY DID YOU DECIDE THIS?'),
        const SizedBox(height: 6),
        Material(
          type: MaterialType.transparency,
          child: TextField(
            controller: _reason,
            autofocus: true,
            maxLines: 2,
            enabled: !widget.submitting,
            style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            decoration: const InputDecoration(
              hintText: 'Add a short reason — saved with your name (required)',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => ready ? _submit(context) : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Semantics(
              button: true,
              enabled: ready,
              label: ready
                  ? 'Save decision: ${widget.choice.label}'
                  : 'Save decision, add a reason first',
              child: SizedBox(
                width: 190,
                height: 28,
                child: FilledButton(
                  onPressed: ready ? () => _submit(context) : null,
                  child: Text(
                    widget.submitting
                        ? 'Saving…'
                        : 'Save: ${widget.choice.label}',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!widget.submitting)
              InlineLink(
                label: 'Cancel',
                onTap: () => context.read<NeedsYouBloc>().add(
                  NeedsYouActionCancelled(decisionId: widget.decision.id),
                ),
              ),
            const Spacer(),
            Text(
              'This cannot be undone.',
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ],
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    context.read<NeedsYouBloc>().add(
      NeedsYouActionSubmitted(
        decisionId: widget.decision.id,
        choice: widget.choice.value,
        rationale: _reason.text.trim(),
      ),
    );
  }
}

/// The four-column fact grid (Penpot `Ev K/V n`).
class _FactGrid extends StatelessWidget {
  const _FactGrid({
    required this.decision,
    required this.now,
    this.stacked = false,
  });

  final PendingDecision decision;
  final DateTime now;

  /// Stack the facts vertically instead of across four columns.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = PlainLanguage.statusFor(
      decision.haltedState ?? 'waiting_for_human_decision',
      blocked: true,
    );

    final facts = <(String, String, Color?)>[
      ('WHAT IT IS', decision.runTitle, null),
      ('STATUS', status.label, status.textColor(palette)),
      if (decision.requestedAt != null)
        (
          'ASKED',
          PlainLanguage.timeOfDay(decision.requestedAt!, now: now),
          null,
        ),
      if (decision.artifactLabel != null)
        ('UNDER REVIEW', decision.artifactLabel!, palette.accent),
    ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final fact in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MicroLabel(fact.$1),
                  const SizedBox(height: 4),
                  Text(
                    fact.$2,
                    style: ShipItType.bodySmall.copyWith(
                      color: fact.$3 ?? palette.inkPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final fact in facts)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MicroLabel(fact.$1),
                  const SizedBox(height: 4),
                  Text(
                    fact.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShipItType.bodySmall.copyWith(
                      color: fact.$3 ?? palette.inkPrimary,
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

/// 1px vertical separator used in the card header strip.
class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(width: 1, height: 12, color: context.palette.rule),
    );
  }
}

/// The "Already decided" history table.
class _AlreadyDecided extends StatefulWidget {
  const _AlreadyDecided({
    required this.entries,
    required this.now,
    this.compact = false,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<ResolvedDecision> entries;
  final DateTime now;

  /// Mobile shows a heading and a "See all" link, per the `BPM · Needs you`
  /// board. The five-column desktop table needs ~580px and cannot be made to
  /// fit a 390px column without becoming unreadable.
  final bool compact;

  /// More decided items exist behind the current page.
  final bool hasMore;
  final bool loadingMore;

  @override
  State<_AlreadyDecided> createState() => _AlreadyDecidedState();
}

class _AlreadyDecidedState extends State<_AlreadyDecided> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entries = widget.entries;
    final now = widget.now;
    final hasMore = widget.hasMore;
    final loadingMore = widget.loadingMore;

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Already decided',
                  style: ShipItType.sectionTitleSmall.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              if (entries.isEmpty)
                Text(
                  'None yet',
                  style: ShipItType.bodyMicro.copyWith(
                    color: palette.inkTertiary,
                  ),
                )
              else
                InlineLink(
                  micro: true,
                  label: _expanded ? 'Hide' : 'See all →',
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            const ContentRule(),
            for (final entry in entries)
              _ResolvedRowMobile(entry: entry, now: now),
            if (loadingMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Reading more…',
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Already decided',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Text(
            'Nothing has been decided yet.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
          )
        else ...[
          const Row(
            children: [
              SizedBox(width: ShipItMetrics.colWhat, child: MicroLabel('REF')),
              Expanded(child: MicroLabel('WHAT WAS DECIDED')),
              SizedBox(width: 140, child: MicroLabel('YOUR CHOICE')),
              SizedBox(width: 220, child: MicroLabel('WHAT CARRIED ON')),
              SizedBox(width: 120, child: MicroLabel('WHEN')),
            ],
          ),
          const SizedBox(height: 8),
          const ContentRule(strong: true),
          for (final entry in entries) _ResolvedRow(entry: entry, now: now),
          if (loadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Reading more…',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            )
          else if (!hasMore && entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'That is every decision on record.',
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ),
        ],
      ],
    );
  }
}

class _ResolvedRow extends StatelessWidget {
  const _ResolvedRow({required this.entry, required this.now});

  final ResolvedDecision entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sentiment = PlainLanguage.sentimentFor(entry.choice);
    final tone = switch (sentiment) {
      OutcomeSentiment.proceed => palette.positive,
      OutcomeSentiment.revise => palette.attention,
      OutcomeSentiment.stop => palette.negative,
    };

    return Column(
      children: [
        SizedBox(
          height: 34,
          child: Row(
            children: [
              SizedBox(
                width: ShipItMetrics.colWhat,
                child: Text(
                  PlainLanguage.refLabel(entry.decisionId),
                  style: ShipItType.ref.copyWith(color: palette.inkSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  entry.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.rowTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    AccentTick(
                      color: tone,
                      height: ShipItMetrics.metricTickHeight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.choiceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShipItType.status.copyWith(color: tone),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 220,
                child: Text(
                  '${PlainLanguage.refLabel(entry.runId)} carried on',
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  entry.resolvedAt == null
                      ? '—'
                      : PlainLanguage.timeOfDay(
                          entry.resolvedAt!,
                          now: now,
                        ).replaceAll(' at ', ' '),
                  textAlign: TextAlign.right,
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
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

/// A resolved decision in the mobile two-line idiom.
class _ResolvedRowMobile extends StatelessWidget {
  const _ResolvedRowMobile({required this.entry, required this.now});

  final ResolvedDecision entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = switch (PlainLanguage.sentimentFor(entry.choice)) {
      OutcomeSentiment.proceed => palette.positive,
      OutcomeSentiment.revise => palette.attention,
      OutcomeSentiment.stop => palette.negative,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AccentTick(color: tone, height: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.rowTitleMobile.copyWith(
                        color: palette.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          PlainLanguage.refLabel(entry.decisionId),
                          style: ShipItType.status.copyWith(
                            color: palette.inkTertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            entry.choiceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ShipItType.status.copyWith(color: tone),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  entry.resolvedAt == null
                      ? '—'
                      : PlainLanguage.timeOfDay(
                          entry.resolvedAt!,
                          now: now,
                        ).replaceAll(' at ', ' '),
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../shared/design_primitives.dart';
import '../../shared/state_views.dart';
import '../../shared/decision_choice.dart';
import '../../shared/detail_sections.dart';
import '../../shared/mobile_chrome.dart';
import 'decision_detail_bloc.dart';
import 'decision_detail_event.dart';

/// The Decision detail screen — where the operator actually decides.
///
/// Transcribed from the Penpot board `BP · Decision Detail` (light/dark):
/// breadcrumb + question + meta strip; a left column explaining why the system
/// stopped, with definition rows, evidence and the consequence table; and a
/// right "Your call" panel holding the options, a required rationale and the
/// submit action.
///
/// Navigation out is the breadcrumb, not a history pop.
class DecisionDetailPage extends StatelessWidget {
  const DecisionDetailPage({
    super.key,
    required this.decisionId,
    this.workItemId,
    this.bloc,
    this.clock,
  });

  final String decisionId;

  /// The run this decision belongs to, passed as `?wi=` so the screen can be
  /// deep-linked without a second lookup.
  final String? workItemId;

  /// Test-only dependency seam.
  final DecisionDetailBloc? bloc;

  /// Supplies "now"; injectable for deterministic goldens.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<DecisionDetailBloc>.value(
            value: provided,
            child: _DecisionView(clock: clock),
          )
        : BlocProvider<DecisionDetailBloc>(
            create: (_) => DecisionDetailBloc(
              decisionId: decisionId,
              runId: workItemId ?? decisionId,
              repository: ClientProvider.repository,
            )..add(DecisionDetailLoaded()),
            child: _DecisionView(clock: clock),
          );
  }
}

class _DecisionView extends StatelessWidget {
  const _DecisionView({this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BlocBuilder<DecisionDetailBloc, DecisionDetailState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const DesignLoadingSkeleton(
            title: 'Loading',
            rows: 4,
            showColumns: false,
          );
        }
        if (state.errorMessage != null && state.choices.isEmpty) {
          return DetailErrorState(
            title: 'We could not open this decision.',
            message: state.errorMessage!,
            parentLabel: 'Needs you',
            onParentTap: () => context.go('/needs-you'),
          );
        }

        final now = (clock ?? DateTime.now)();
        final waiting = state.createdAt == null
            ? null
            : now.difference(state.createdAt!);
        final settled = state.isSubmitted || state.alreadyResolved;

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
                  parentLabel: 'Needs you',
                  parentRef: PlainLanguage.refLabel(state.decisionId),
                  onParentTap: () => context.go('/needs-you'),
                  title: state.question,
                  statusLabel: settled ? 'DECIDED' : 'WAITING FOR YOU',
                  statusColor: settled ? palette.positive : palette.attention,
                  facts: [
                    if (state.createdAt != null)
                      (
                        'asked ${PlainLanguage.timeOfDay(state.createdAt!, now: now)}',
                        null,
                      ),
                    if (!settled)
                      (PlainLanguage.waitingFor(waiting), palette.attention),
                  ],
                ),
                const SizedBox(height: 22),
                if (isMobile(context)) ...[
                  _LeftColumn(state: state, settled: settled),
                  const SizedBox(height: 20),
                  _YourCall(state: state, compact: true),
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
                            _LeftColumn(state: state, settled: settled),
                            const SizedBox(height: 24),
                            _YourCall(state: state),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _LeftColumn(state: state, settled: settled),
                          ),
                          const SizedBox(width: 32),
                          SizedBox(width: 392, child: _YourCall(state: state)),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 40),
                TechnicalDetails(
                  lines: [
                    'WorkItem.state = ${state.haltedState ?? 'unknown'}'
                        '${state.haltedState == null ? '' : ' · halted in: ${state.haltedState}'}',
                    '${state.decisionId} ${state.decisionTypeWire} '
                        'on ${state.runId}',
                    'options: '
                        '${state.choices.map((c) => c.value).join(', ')}',
                    if (state.resolvedChoice != null)
                      'resolved choice: ${state.resolvedChoice}',
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
  const _LeftColumn({required this.state, required this.settled});

  final DecisionDetailState state;

  /// True once a durable outcome exists.
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          settled ? 'Why ShipIt stopped' : 'Why ShipIt stopped',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          settled
              ? 'This is the record of what was decided and why.'
              : 'This work cannot continue until you decide.',
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
        const SizedBox(height: 18),
        DefinitionList(
          entries: [
            DefinitionEntry(
              label: 'WHAT THIS IS ABOUT',
              value: state.runName,
              ref: PlainLanguage.refLabel(state.runId),
            ),
            DefinitionEntry(
              label: 'STATUS',
              value: settled
                  ? 'Decided — recorded against this run'
                  : 'Waiting for your approval',
            ),
            DefinitionEntry(
              label: "WHAT'S NEEDED",
              value: PlainLanguage.decisionType(state.decisionTypeWire),
              ref: PlainLanguage.refLabel(state.decisionId),
            ),
            if (state.haltedState != null)
              DefinitionEntry(
                label: "WHY IT'S WAITING",
                value: PlainLanguage.haltExplanation(state.haltedState!),
              ),
          ],
        ),
        if (state.artifacts.isNotEmpty) ...[
          const SizedBox(height: 20),
          EvidencePanel(
            title: "WHAT YOU'RE APPROVING",
            artifactTitle:
                state.artifacts.first.description?.trim().isNotEmpty == true
                ? state.artifacts.first.description!.trim()
                : state.artifacts.first.artifactType,
            artifactSubtitle: state.artifacts.length > 1
                ? state.artifacts[1].description
                : null,
            links: [
              for (final artifact in state.artifacts.take(2))
                (_artifactLinkLabel(artifact.artifactType), artifact.uri),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'What happens after you decide',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 6),
        OutcomeTable(
          rows: [
            for (final choice in state.choices)
              OutcomeRow(
                choice: choice.label,
                // The option's own description is the durable statement of
                // what the choice does; nothing is inferred beyond it.
                happens: choice.description ?? 'Records your decision',
                sentiment: PlainLanguage.sentimentFor(choice.value),
              ),
          ],
        ),
      ],
    );
  }
}

/// The right-hand "Your call" panel: options, rationale, submit.
class _YourCall extends StatefulWidget {
  const _YourCall({required this.state, this.compact = false});

  final DecisionDetailState state;

  /// Mobile drops the surrounding panel: the column is already the panel.
  final bool compact;

  @override
  State<_YourCall> createState() => _YourCallState();
}

class _YourCallState extends State<_YourCall> {
  final TextEditingController _rationale = TextEditingController();

  @override
  void dispose() {
    _rationale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = widget.state;
    final settled = state.isSubmitted || state.alreadyResolved;

    if (settled) {
      return _wrap(
        children: [
          Text(
            'Decision recorded',
            style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Your call has been saved to the system\'s durable record.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 14),
          const ContentRule(),
          const SizedBox(height: 15),
          const MicroLabel('YOUR CHOICE'),
          const SizedBox(height: 4),
          Text(
            state.resolvedChoice == null
                ? 'Recorded'
                : decisionChoiceDisplay(state.resolvedChoice!, state.choices),
            style: ShipItType.status.copyWith(color: palette.positive),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Saved as you, on this device',
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ),
        ],
      );
    }

    final canSubmit =
        state.selectedChoice != null &&
        _rationale.text.trim().isNotEmpty &&
        !state.isSubmitting;

    return _wrap(
      children: [
        Text(
          'Your call',
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 14),
        const ContentRule(),
        if (state.recommendation != null) ...[
          const SizedBox(height: 15),
          const MicroLabel('WHAT WE SUGGEST'),
          const SizedBox(height: 4),
          Text(
            state.recommendation!,
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
        ],
        const SizedBox(height: 18),
        const MicroLabel('YOUR OPTIONS'),
        const SizedBox(height: 8),
        for (final choice in state.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionCard(
              choice: choice,
              selected: state.selectedChoice == choice.value,
              onTap: () => context.read<DecisionDetailBloc>().add(
                DecisionChoiceSelected(choice: choice.value),
              ),
            ),
          ),
        const SizedBox(height: 10),
        const MicroLabel('WHY DID YOU DECIDE THIS?'),
        const SizedBox(height: 6),
        // Material ancestor supplied locally so the panel does not depend on
        // its host providing one.
        Material(
          type: MaterialType.transparency,
          child: TextField(
            controller: _rationale,
            maxLines: 3,
            style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            decoration: const InputDecoration(
              hintText: 'Add a short reason — saved with your name (required)',
            ),
            onChanged: (value) {
              context.read<DecisionDetailBloc>().add(
                DecisionRationaleChanged(rationale: value),
              );
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          enabled: canSubmit,
          label: state.selectedChoice == null
              ? 'Save my decision, choose an option first'
              : _rationale.text.trim().isEmpty
              ? 'Save my decision, add a reason first'
              : 'Save my decision',
          child: SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: canSubmit
                  ? () => context.read<DecisionDetailBloc>().add(
                      DecisionSubmitted(),
                    )
                  : null,
              child: Text(state.isSubmitting ? 'Saving…' : 'Save my decision'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'This cannot be undone.',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ),
        const SizedBox(height: 14),
        const ContentRule(),
        const SizedBox(height: 13),
        Center(
          child: Text(
            'Saved as you, on this device',
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ),
      ],
    );
  }

  /// On mobile the page column already provides the surface, so the panel
  /// border is dropped rather than nesting a card inside a card.
  Widget _wrap({required List<Widget> children}) {
    if (!widget.compact) return SidePanel(children: children);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// A selectable option (Penpot `C Bg` / `C Radio` / `C L` / `C S`).
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final DecisionChoiceOption choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sentiment = PlainLanguage.sentimentFor(choice.value);
    final accent = switch (sentiment) {
      OutcomeSentiment.proceed => palette.positive,
      OutcomeSentiment.revise => palette.attention,
      OutcomeSentiment.stop => palette.negative,
    };

    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.label}. ${choice.description ?? ''}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // The board tints the chosen option with its own sentiment and
              // leaves the rest on the panel surface.
              color: selected ? accent.withValues(alpha: 0.06) : palette.canvas,
              border: Border.all(
                color: selected ? accent : palette.cardBorder,
                width: selected ? 1.5 : ShipItMetrics.hairline,
              ),
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Radio(selected: selected, accent: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          choice.label,
                          style: ShipItType.rowTitle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: palette.inkPrimary,
                          ),
                        ),
                        if (choice.description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            choice.description!,
                            style: ShipItType.bodySmall.copyWith(
                              color: palette.inkSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (choice.recommended)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: MicroLabel(
                        'SUGGESTED',
                        color: palette.inkTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : palette.controlBorder,
          width: selected ? 2 : 1,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// Human label for a resolved choice value.
String decisionChoiceDisplay(String value, List<DecisionChoiceOption> choices) {
  for (final choice in choices) {
    if (choice.value == value) return choice.label;
  }
  return value;
}

/// Link wording per artifact kind, so the operator knows where it goes.
String _artifactLinkLabel(String artifactType) => switch (artifactType) {
  'design_revision' || 'design_contract' => 'Open the design',
  'qa_evidence' => 'See the checks',
  'code_diff' => 'See the change',
  'build_artifact' => 'Open the build',
  'deployment_record' => 'Open the deployment',
  _ => 'Open it',
};

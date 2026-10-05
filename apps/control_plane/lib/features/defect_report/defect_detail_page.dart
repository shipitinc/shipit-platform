import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:platform_contracts/platform_contracts.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';
import '../../shared/detail_sections.dart';
import '../../shared/mobile_chrome.dart' show isMobile;
import '../../shared/state_views.dart';
import 'defect_detail_bloc.dart';
import 'defect_detail_event.dart';
import 'defect_detail_state.dart';
import 'defect_status_badge.dart';

/// The Defect Detail screen.
///
/// Transcribed from the Penpot boards `BP · Defect Detail` and
/// `BPM · Defect Detail` (light): a `DetailHeader`, a left column of facts /
/// evidence / timeline, a right-hand gate panel that carries the operator
/// action for the current state, and a disclosure footer.
///
/// Route: /defects/:defectId
class DefectDetailPage extends StatelessWidget {
  const DefectDetailPage({
    super.key,
    required this.defectId,
    this.bloc,
    this.clock,
  });

  final String defectId;

  /// Test-only dependency seam.
  final DefectDetailBloc? bloc;

  /// Supplies "now"; injectable for deterministic goldens.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<DefectDetailBloc>.value(
            value: provided,
            child: _DefectDetailView(defectId: defectId, clock: clock),
          )
        : BlocProvider<DefectDetailBloc>(
            create: (_) => DefectDetailBloc(
              repository: ClientProvider.repository,
              defectId: defectId,
            )..add(DefectDetailLoaded()),
            child: _DefectDetailView(defectId: defectId, clock: clock),
          );
  }
}

class _DefectDetailView extends StatelessWidget {
  const _DefectDetailView({required this.defectId, this.clock});

  final String defectId;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DefectDetailBloc, DefectDetailState>(
      builder: (context, state) {
        if (state.isLoading && state.defect == null) {
          return const DesignLoadingSkeleton(
            title: 'Defect',
            rows: 4,
            showColumns: false,
          );
        }
        if (state.errorMessage != null && state.defect == null) {
          return DesignErrorState(
            title: 'We could not open this defect.',
            detail: state.errorMessage!,
            onRetry: () =>
                context.read<DefectDetailBloc>().add(DefectDetailRefreshed()),
          );
        }
        if (state.defect == null) {
          return const DesignEmptyState(
            title: 'Defect not found',
            body: 'The defect you requested does not exist.',
          );
        }

        final defect = state.defect!;
        final status = DefectStatus.fromWire(defect.status);
        final mobile = isMobile(context);
        final now = clock?.call() ?? DateTime.now();
        final age = now.difference(defect.createdAt);
        final operatorTurn = DefectStatusBadge.isOperatorAction(status);

        final left = _LeftColumn(
          state: state,
          status: status,
          mobile: mobile,
          now: now,
        );
        final right = _RightColumn(
          state: state,
          status: status,
          mobile: mobile,
        );

        final children = <Widget>[
          DetailHeader(
            showBreadcrumb: !mobile,
            compact: mobile,
            titleStyle: mobile ? ShipItType.pageTitleMobile : null,
            parentLabel: 'Defects',
            parentRef: PlainLanguage.refLabel(defect.defectId),
            onParentTap: () => context.go('/reports'),
            middleLabel: defect.productName ?? 'Unassigned product',
            onMiddleTap: null,
            title: defect.title,
            titleKey: const Key('defect-detail-title'),
            statusLabel: operatorTurn
                ? 'WAITING FOR YOU'
                : DefectStatusBadge.label(status).toUpperCase(),
            statusColor: operatorTurn
                ? context.palette.attention
                : DefectStatusBadge.textColor(status, context.palette),
            facts: [
              (
                'reported ${PlainLanguage.timeOfDay(defect.createdAt, now: now)}',
                null,
              ),
              (
                // The board's age slot reads `running 3h 12m`; for a defect
                // the same span is how long the report has been open.
                mobile
                    ? '${defect.productName ?? 'Unassigned product'}  ·  open ${PlainLanguage.elapsed(age)}'
                    : 'open ${PlainLanguage.elapsed(age)}',
                operatorTurn ? context.palette.attention : null,
              ),
            ],
          ),
          SizedBox(height: mobile ? 11 : 18),
        ];

        if (mobile) {
          children.add(left);
          if (right.hasAction) {
            children.add(const SizedBox(height: 30));
            children.add(right);
          }
          children.add(const SizedBox(height: 22));
        } else {
          children.add(
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth -
                        ShipItMetrics.sidePanelWidth -
                        ShipItMetrics.sidePanelGap <
                    ShipItMetrics.sidePanelMinContent;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [left, const SizedBox(height: 24), right],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: ShipItMetrics.sidePanelGap),
                    SizedBox(width: ShipItMetrics.sidePanelWidth, child: right),
                  ],
                );
              },
            ),
          );
          children.add(const SizedBox(height: 14));
        }

        children.add(
          _DetailFooter(mobile: mobile, lines: _techLines(defect, state)),
        );

        return SingleChildScrollView(
          child: Padding(
            // `BP · Defect Detail` insets its content to x236..1256 (36 left,
            // 24 right); `BPM ·` uses the 16px mobile gutter.
            padding: mobile
                ? const EdgeInsets.fromLTRB(
                    ShipItMetrics.mobileGutter,
                    16,
                    ShipItMetrics.mobileGutter,
                    24,
                  )
                : const EdgeInsets.fromLTRB(
                    ShipItMetrics.contentGutter,
                    26,
                    24,
                    23,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        );
      },
    );
  }

  static List<String> _techLines(
    DefectSummaryResponse defect,
    DefectDetailState state,
  ) {
    return [
      'Defect.status = ${defect.status}',
      '${defect.defectId}  ·  ${defect.classification ?? 'unclassified'}  ·  '
          'severity: ${defect.severity}',
      if (defect.affectedWorkItemId != null)
        'affected work: ${defect.affectedWorkItemId}',
      if (defect.affectedRunId != null) 'affected run: ${defect.affectedRunId}',
      if (defect.remediationWorkItemId != null)
        'remediation: ${defect.remediationWorkItemId}',
      if (state.evidenceError != null) 'evidence: ${state.evidenceError}',
    ];
  }
}

// ----------------------------------------------------------------- left column

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.state,
    required this.status,
    required this.mobile,
    required this.now,
  });

  final DefectDetailState state;
  final DefectStatus status;
  final bool mobile;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final evidence = state.evidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!mobile) ...[
          Text(
            'Where this defect got to',
            style: ShipItType.detailTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            DefectStatusBadge.isOperatorAction(status)
                ? 'This defect is waiting on an answer from you.'
                : 'This is the durable record of what has happened to this '
                      'defect.',
            style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
          ),
          const SizedBox(height: 18),
        ],
        DefinitionList(entries: _entries(state, status, mobile: mobile)),
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 18),
          _EvidenceBlock(evidence: evidence, mobile: mobile, now: now),
        ],
        SizedBox(height: mobile ? 18 : 20),
        Text(
          "What's happened so far",
          style: ShipItType.sectionTitle.copyWith(color: palette.inkPrimary),
        ),
        SizedBox(height: mobile ? 9 : 6),
        TimelineTable(
          compact: mobile,
          emptyMessage: 'Nothing has been recorded for this defect yet.',
          events: [
            for (final event in state.events)
              TimelineEntry(
                timestamp: event.occurredAt,
                message: _eventLabel(event),
                needsOperator: _eventHandsOverToHuman(event),
              ),
          ],
        ),
      ],
    );
  }

  /// Only rows the durable record can substantiate are shown. Mobile carries
  /// the board's two rows; desktop its five.
  static List<DefinitionEntry> _entries(
    DefectDetailState state,
    DefectStatus status, {
    required bool mobile,
  }) {
    final defect = state.defect!;
    final heldUp = _heldUp(state);

    if (mobile) {
      return [
        DefinitionEntry(
          label: 'WHY IT STOPPED',
          value: _waitExplanation(status),
          prose: true,
        ),
        DefinitionEntry(label: "WHAT'S HELD UP", value: heldUp.$1, prose: true),
      ];
    }

    final pending = _pendingClarification(state);
    final needed = _needed(status, pending);
    return [
      DefinitionEntry(
        label: 'WHAT THIS IS ABOUT',
        value: defect.title,
        ref: PlainLanguage.refLabel(defect.defectId),
      ),
      DefinitionEntry(label: 'STATUS', value: _statusValue(status)),
      DefinitionEntry(label: "WHAT'S NEEDED", value: needed.$1, ref: needed.$2),
      DefinitionEntry(
        label: "WHY IT'S WAITING",
        value: _waitExplanation(status),
        prose: true,
      ),
      DefinitionEntry(
        label: "WHAT'S HELD UP",
        value: heldUp.$1,
        ref: heldUp.$2,
      ),
    ];
  }

  static String _statusValue(DefectStatus status) {
    return switch (status) {
      DefectStatus.needsClarification => 'Waiting for your answer',
      DefectStatus.fixReadyForVerification => 'Waiting for your check',
      _ => DefectStatusBadge.label(status),
    };
  }

  /// `(value, ref)` — what this state is asking of the operator.
  static (String, String?) _needed(
    DefectStatus status,
    DefectClarificationResponse? pending,
  ) {
    return switch (status) {
      DefectStatus.needsClarification =>
        pending == null
            ? ('Nothing from you yet', null)
            : ('Your answer', PlainLanguage.refLabel(pending.clarificationId)),
      DefectStatus.fixReadyForVerification => ('Your check of the fix', null),
      _ => ('Nothing from you yet', null),
    };
  }

  static DefectClarificationResponse? _pendingClarification(
    DefectDetailState state,
  ) {
    for (final clarification in state.clarifications) {
      if (ClarificationStatus.fromWire(clarification.status) ==
          ClarificationStatus.needsAnswer) {
        return clarification;
      }
    }
    return null;
  }

  static String _waitExplanation(DefectStatus status) {
    return switch (status) {
      DefectStatus.reported => 'Nothing has happened to this defect yet.',
      DefectStatus.triaging =>
        'An agent is reading this defect and deciding what it is.',
      DefectStatus.needsClarification =>
        'We asked you a question and stopped until you answer it.',
      DefectStatus.confirmed =>
        'The defect is confirmed and is waiting for a fix to be planned.',
      DefectStatus.remediationPlanned || DefectStatus.fixInProgress =>
        'A work item is fixing this defect right now.',
      DefectStatus.fixReadyForVerification =>
        'The fix is built. It is waiting for you to check it.',
      DefectStatus.notReproducible =>
        'The report was closed out without a fix.',
      DefectStatus.duplicate => 'Another defect already tracks this problem.',
      DefectStatus.resolved || DefectStatus.closed =>
        'This defect is finished. Nothing is waiting on it.',
    };
  }

  /// `(sentence, ref)` — the item the defect is holding up, or an explicit
  /// "nothing" so the row never goes blank.
  static (String, String?) _heldUp(DefectDetailState state) {
    final defect = state.defect!;
    final remediation = defect.remediationWorkItemId;
    if (remediation != null) {
      return (
        '1 work item is fixing this defect',
        PlainLanguage.refLabel(remediation),
      );
    }
    if (defect.affectedWorkItemId != null) {
      return (
        '1 work item is waiting on this defect',
        PlainLanguage.refLabel(defect.affectedWorkItemId!),
      );
    }
    if (defect.affectedRunId != null) {
      return (
        '1 run is waiting on this defect',
        PlainLanguage.refLabel(defect.affectedRunId!),
      );
    }
    return ('Nothing is waiting on this defect', null);
  }
}

/// One `EVIDENCE` panel for the record's first artifact (`Ev Bg`), plus the
/// count of everything else on file.
class _EvidenceBlock extends StatelessWidget {
  const _EvidenceBlock({
    required this.evidence,
    required this.mobile,
    required this.now,
  });

  final List<DefectEvidenceResponse> evidence;
  final bool mobile;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final first = evidence.first;
    final screenshots = evidence.where((e) => e.kind == 'screenshot').length;
    return EvidencePanel(
      title: 'EVIDENCE',
      artifactTitle: _humaniseWire(first.kind),
      artifactSubtitle: first.description,
      compact: mobile,
      links: [
        ('Open the evidence', ''),
        if (screenshots > 0)
          ('See $screenshots screenshot${screenshots == 1 ? '' : 's'}', ''),
      ],
      facts: [
        ('Captured by', first.sourceRef ?? 'reporter'),
        ('Items on file', '${evidence.length}'),
      ],
    );
  }
}

String _humaniseWire(String wire) => wire
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

bool _eventHandsOverToHuman(DefectEventResponse event) {
  if (event.type == 'clarification_requested' ||
      event.type == 'verification_requested') {
    return true;
  }
  return event.toStatus == 'needs_clarification' ||
      event.toStatus == 'fix_ready_for_verification';
}

String _eventLabel(DefectEventResponse event) {
  final type = DefectEventType.fromWire(event.type);
  return switch (type) {
    DefectEventType.created => 'Defect created',
    DefectEventType.triageStarted => 'Triage started',
    DefectEventType.triageCompleted => 'Triage completed',
    DefectEventType.clarificationRequested => 'Clarification requested',
    DefectEventType.clarificationAnswered => 'Clarification answered',
    DefectEventType.statusChanged =>
      'Status changed: ${event.fromStatus ?? '—'} → ${event.toStatus ?? '—'}',
    DefectEventType.evidenceAdded => 'Evidence added',
    DefectEventType.remediationCreated => 'Remediation work item created',
    DefectEventType.remediationStarted => 'Remediation started',
    DefectEventType.remediationCompleted => 'Remediation completed',
    DefectEventType.verificationRequested => 'Verification requested',
    DefectEventType.verificationCompleted => 'Verification completed',
    DefectEventType.reopened => 'Defect reopened',
    DefectEventType.closed => 'Defect closed',
    DefectEventType.duplicateLinked => 'Duplicate linked',
    DefectEventType.manualAction => 'Manual action',
  };
}

// ---------------------------------------------------------------- right column

/// The board's right-hand gate (`R Panel`): the copy that explains what the
/// system is waiting for, plus the operator's action for this state.
///
/// On mobile the panel itself is not drawn — `BPM · Defect Detail` collapses
/// the gate to a full-width action under the timeline.
class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.state,
    required this.status,
    required this.mobile,
  });

  final DefectDetailState state;
  final DefectStatus status;
  final bool mobile;

  /// Whether this state has something for the operator to do.
  bool get hasAction => switch (status) {
    DefectStatus.needsClarification => _pending != null,
    DefectStatus.fixReadyForVerification => true,
    DefectStatus.remediationPlanned ||
    DefectStatus.fixInProgress => _remediationId != null,
    _ => false,
  };

  DefectClarificationResponse? get _pending {
    for (final clarification in state.clarifications) {
      if (ClarificationStatus.fromWire(clarification.status) ==
          ClarificationStatus.needsAnswer) {
        return clarification;
      }
    }
    return null;
  }

  String? get _remediationId =>
      state.defect?.remediationWorkItemId ??
      state.remediationWorkItem?.workItemId;

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      // `BPM · Defect Detail` draws no panel card and no gate copy: the
      // screen collapses to the operator's action alone. The two states whose
      // action *is* a form keep the prompt the form answers, because a field
      // with no question is not answerable.
      final body = _mobileBody(context);
      if (body.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: body,
      );
    }
    return SidePanel(children: _body(context));
  }

  List<Widget> _mobileBody(BuildContext context) {
    final palette = context.palette;
    switch (status) {
      case DefectStatus.needsClarification:
        final pending = _pending;
        if (pending == null) return const [];
        return [
          _MobileGate(
            label: 'Answer the question',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MicroLabel('WHAT WE ASKED', color: palette.inkTertiary),
                const SizedBox(height: 4),
                Text(
                  pending.question,
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                _AnswerClarificationForm(
                  clarificationId: pending.clarificationId,
                  submitting: state.isSubmittingClarification,
                ),
              ],
            ),
          ),
        ];
      case DefectStatus.fixReadyForVerification:
        return [
          _MobileGate(
            label: 'Review and decide',
            child: _VerificationForm(
              submitting: state.isSubmittingVerification,
            ),
          ),
        ];
      case DefectStatus.remediationPlanned:
      case DefectStatus.fixInProgress:
        final id = _remediationId;
        if (id == null) return const [];
        return [
          _MobileAction(
            label: 'Open the work item',
            onPressed: () => context.go('/runs/$id'),
          ),
        ];
      default:
        return const [];
    }
  }

  /// The panel body for this state.
  List<Widget> _body(BuildContext context) {
    final palette = context.palette;

    switch (status) {
      case DefectStatus.reported:
      case DefectStatus.triaging:
        return _standard(
          palette,
          title: 'Waiting for triage',
          sub: 'An agent reads this defect and proposes what to do about it.',
          label: 'WHAT WE LOOK AT',
          value: 'The report, the evidence attached, and the work it touches.',
        );
      case DefectStatus.needsClarification:
        final pending = _pending;
        if (pending == null) return const [];
        return _standard(
          palette,
          title: 'We need one detail',
          sub: 'Answer the question and triage picks straight back up.',
          label: 'WHAT WE ASKED',
          value: pending.question,
          second: ('WHY WE ASKED', pending.reason),
          form: _AnswerClarificationForm(
            clarificationId: pending.clarificationId,
            submitting: state.isSubmittingClarification,
          ),
        );
      case DefectStatus.confirmed:
        return _standard(
          palette,
          title: 'Confirmed and classified',
          sub: 'Triage finished. This defect is ready to be fixed.',
          label: 'WHAT WE DECIDED',
          value: state.defect?.classification == null
              ? 'Not classified yet'
              : _humaniseWire(state.defect!.classification!),
        );
      case DefectStatus.remediationPlanned:
      case DefectStatus.fixInProgress:
        final remediation = state.remediationWorkItem;
        return _standard(
          palette,
          title: 'Fix in progress',
          sub: 'A work item is building the fix for this defect.',
          label: 'WHAT IS BEING FIXED',
          value:
              remediation?.title ?? 'A work item was planned for this defect.',
          ref: _remediationId,
          action: _GateAction(
            label: 'Open the work item',
            sub: 'Opens the work item',
            onPressed: () => context.go('/runs/$_remediationId'),
          ),
        );
      case DefectStatus.fixReadyForVerification:
        final remediation = state.remediationWorkItem;
        return _standard(
          palette,
          title: 'Ready to verify',
          sub: 'The fix is built. Check it and record what you found.',
          label: 'WHAT TO CHECK',
          value: remediation?.title ?? 'The fix prepared for this defect.',
          ref: _remediationId,
          form: _VerificationForm(submitting: state.isSubmittingVerification),
        );
      case DefectStatus.notReproducible:
        return _standard(
          palette,
          title: 'Not reproducible',
          sub: 'The report could not be reproduced, so no fix was made.',
          label: 'WHAT WE TRIED',
          value: 'Reproduced the steps from the report. It did not occur.',
        );
      case DefectStatus.duplicate:
        return _standard(
          palette,
          title: 'Duplicate',
          sub: 'This defect already has a record of its own.',
          label: 'WHAT WE FOUND',
          value: 'Another defect tracks the same problem.',
        );
      case DefectStatus.resolved:
      case DefectStatus.closed:
        return _standard(
          palette,
          title: 'Resolved',
          sub: 'This defect is finished. Nothing is waiting on you.',
          label: 'WHAT CHANGED',
          value: 'Verified and recorded against the test plan.',
        );
    }
  }

  List<Widget> _standard(
    ShipItPalette palette, {
    required String title,
    required String sub,
    required String label,
    required String value,
    (String, String)? second,
    String? ref,
    Widget? form,
    Widget? action,
  }) {
    return [
      Text(
        title,
        style: ShipItType.detailTitle.copyWith(color: palette.inkPrimary),
      ),
      const SizedBox(height: 6),
      Text(
        sub,
        style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
      ),
      const SizedBox(height: 8),
      const ContentRule(),
      const SizedBox(height: 15),
      MicroLabel(label, color: palette.inkTertiary),
      const SizedBox(height: 4),
      if (ref != null)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              value,
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
            Text(
              PlainLanguage.refLabel(ref),
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ],
        )
      else
        Text(
          value,
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
      if (second != null) ...[
        const SizedBox(height: 14),
        MicroLabel(second.$1, color: palette.inkTertiary),
        const SizedBox(height: 4),
        Text(
          second.$2,
          style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
        ),
      ],
      if (form != null) ...[
        const SizedBox(height: 14),
        form,
      ] else if (action != null) ...[
        const SizedBox(height: 34),
        action,
      ],
    ];
  }
}

/// The board's `R Submit`: a 36px accent action with a mono caption beneath
/// it (`R Submit` / `R Submit L` / `R Submit Sub`).
class _GateAction extends StatelessWidget {
  const _GateAction({required this.label, this.sub, required this.onPressed});

  final String label;
  final String? sub;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 36,
          child: FilledButton(
            onPressed: onPressed,
            child: Text(
              label,
              style: ShipItType.sectionTitleSmall.copyWith(
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 10),
          Text(
            sub!,
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ],
      ],
    );
  }
}

/// The board's mobile CTA (`CTA` / `CTA L`): full width, 34px, 13/600.
class _MobileAction extends StatelessWidget {
  const _MobileAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: ShipItType.sectionTitle.copyWith(
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// `CTA` on `BPM · Defect Detail`: the mobile board draws the gate collapsed
/// to a single full-width action and shows no expanded form at all, so the
/// form opens under that action rather than sitting on the screen from the
/// start.
class _MobileGate extends StatefulWidget {
  const _MobileGate({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  State<_MobileGate> createState() => _MobileGateState();
}

class _MobileGateState extends State<_MobileGate> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return _MobileAction(
        label: widget.label,
        onPressed: () => setState(() => _open = true),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InlineLink(
            micro: true,
            label: 'Hide',
            caret: CaretDirection.down,
            onTap: () => setState(() => _open = false),
          ),
        ),
        const SizedBox(height: 8),
        widget.child,
      ],
    );
  }
}

// ---------------------------------------------------------------------- forms

/// `YOUR ANSWER` + a 64px box + a submit (`R Rat Box` shape reused for the
/// clarification the board does not draw).
class _AnswerClarificationForm extends StatefulWidget {
  const _AnswerClarificationForm({
    required this.clarificationId,
    required this.submitting,
  });

  final String clarificationId;
  final bool submitting;

  @override
  State<_AnswerClarificationForm> createState() =>
      _AnswerClarificationFormState();
}

class _AnswerClarificationFormState extends State<_AnswerClarificationForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSubmit = !widget.submitting && _controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MicroLabel('YOUR ANSWER', color: palette.inkTertiary),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
          decoration: InputDecoration(
            hintText: 'Type your answer…',
            hintStyle: ShipItType.bodyMicro.copyWith(
              color: palette.inkTertiary,
            ),
            filled: true,
            fillColor: palette.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
              borderSide: BorderSide(color: palette.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: FilledButton(
            onPressed: !canSubmit
                ? null
                : () => context.read<DefectDetailBloc>().add(
                    DefectDetailClarificationAnswered(
                      clarificationId: widget.clarificationId,
                      answer: _controller.text.trim(),
                      answeredBy: 'operator', // TODO: authenticated user
                    ),
                  ),
            child: Text(
              'Send the answer',
              style: ShipItType.sectionTitleSmall.copyWith(
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Triage picks straight back up',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
      ],
    );
  }
}

/// The board's expanded gate: `YOUR OPTIONS` choice cards (`C Bg` / `C Radio`
/// / `C L` / `C S`), a rationale box (`R Rat Box`) and the signature caption
/// (`R Sig`).
class _VerificationForm extends StatefulWidget {
  const _VerificationForm({required this.submitting});

  final bool submitting;

  @override
  State<_VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends State<_VerificationForm> {
  static const _choices = [
    ('fixed', 'Fixed', 'The defect is gone.'),
    ('partially_fixed', 'Partially fixed', 'It is better but not gone.'),
    ('still_broken', 'Still broken', 'The defect is still there.'),
  ];

  final _rationale = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _rationale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSubmit =
        !widget.submitting &&
        _selected != null &&
        _rationale.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MicroLabel('YOUR CHOICE', color: palette.inkTertiary),
        const SizedBox(height: 6),
        for (var i = 0; i < _choices.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ChoiceCard(
            label: _choices[i].$2,
            sub: _choices[i].$3,
            selected: _selected == _choices[i].$1,
            onTap: () => setState(() => _selected = _choices[i].$1),
          ),
        ],
        const SizedBox(height: 18),
        MicroLabel('WHY DID YOU DECIDE THIS?', color: palette.inkTertiary),
        const SizedBox(height: 6),
        TextField(
          controller: _rationale,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
          decoration: InputDecoration(
            hintText: 'Add a short reason — saved with your name (required)',
            hintStyle: ShipItType.bodySmall.copyWith(
              color: palette.inkTertiary,
            ),
            filled: true,
            fillColor: palette.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
              borderSide: BorderSide(color: palette.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
              borderSide: BorderSide(color: palette.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 36,
          child: FilledButton(
            onPressed: !canSubmit
                ? null
                : () => context.read<DefectDetailBloc>().add(
                    DefectDetailFixVerified(
                      choice: _selected!,
                      rationale: _rationale.text.trim(),
                      decider: 'operator', // TODO: authenticated user
                      signature:
                          'operator-sig-${DateTime.now().millisecondsSinceEpoch}',
                      publicKey: 'operator-pub-key',
                      algorithm: 'ed25519',
                      signedAt: DateTime.now(),
                    ),
                  ),
            child: Text(
              'Submit verification',
              style: ShipItType.sectionTitleSmall.copyWith(
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const ContentRule(),
        const SizedBox(height: 13),
        Text(
          'Saved as you, on this device',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
      ],
    );
  }
}

/// One `C Bg` choice row: a 54px card with a 14px radio and two lines of copy.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  /// `C Bg 0` fill. The palette has no slot for it, so light uses the board's
  /// literal and dark falls back to the nearest existing surface (the dark
  /// board does not draw this variant).
  static Color surface(ShipItPalette palette) =>
      palette.card == const Color(0xFFFFFFFF)
      ? const Color(0xFFEAEAE6)
      : palette.rail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $sub',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ShipItMetrics.radius),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: selected ? surface(palette) : null,
            border: Border.all(
              color: selected ? palette.positive : palette.rule,
            ),
            borderRadius: BorderRadius.circular(ShipItMetrics.radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 19),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.card,
                    border: Border.all(
                      color: selected ? palette.positive : palette.ruleStrong,
                      width: selected ? 4 : 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ShipItType.sectionTitleSmall.copyWith(
                        color: palette.inkPrimary,
                      ),
                    ),
                    Text(
                      sub,
                      style: ShipItType.bodyMicro.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- footer

/// `Footer Rule` + `Disclose` + the hidden `Tech K/0/1` block they open.
///
/// The board draws no footer note on this screen (its `Footer` shape is
/// hidden), and on mobile it draws no rule above the disclosure at all.
class _DetailFooter extends StatefulWidget {
  const _DetailFooter({required this.mobile, required this.lines});

  final bool mobile;
  final List<String> lines;

  @override
  State<_DetailFooter> createState() => _DetailFooterState();
}

class _DetailFooterState extends State<_DetailFooter> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_open) ...[
          MicroLabel('TECHNICAL DETAILS', color: palette.inkTertiary),
          const SizedBox(height: 6),
          for (final line in widget.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (!widget.mobile) ...[
          const ContentRule(),
          const SizedBox(height: 13),
        ],
        InlineLink(
          micro: true,
          label: _open ? 'Hide technical details' : 'Show technical details',
          caret: _open ? CaretDirection.down : CaretDirection.right,
          onTap: () => setState(() => _open = !_open),
        ),
      ],
    );
  }
}

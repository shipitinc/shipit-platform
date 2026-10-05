import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../shared/design_primitives.dart';
import '../../shared/form_primitives.dart';
import '../../shared/mobile_chrome.dart' show isMobile;
import '../../shared/state_views.dart';
import 'create_defect_bloc.dart';
import 'create_defect_event.dart';
import 'create_defect_state.dart';
import '../reports/intake_tabs.dart';
import '../reports/reports_state.dart';

/// The Create Defect screen — `BP · Create Defect` and `BPM · Create Defect`.
///
/// Route: /defects/new
class CreateDefectPage extends StatelessWidget {
  const CreateDefectPage({
    super.key,
    this.bloc,
    this.prefilledWorkItemId,
    this.prefilledRunId,
  });

  /// Test-only dependency seam.
  final CreateDefectBloc? bloc;

  /// Optional prefilled context from a work item or run. Both are handed to
  /// the bloc, which folds them into the report on submit.
  final String? prefilledWorkItemId;
  final String? prefilledRunId;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<CreateDefectBloc>.value(
            value: provided,
            child: const _CreateDefectView(),
          )
        : BlocProvider<CreateDefectBloc>(
            create: (_) =>
                CreateDefectBloc(
                  repository: ClientProvider.repository,
                  reporter: 'operator',
                  prefilledWorkItemId: prefilledWorkItemId,
                  prefilledRunId: prefilledRunId,
                )..add(
                  CreateDefectClientContextCaptured(
                    '{"userAgent": "Flutter Web", "timestamp": "${DateTime.now().toIso8601String()}"}',
                  ),
                ),
            child: const _CreateDefectView(),
          );
  }
}

// Board measurements live in `FormMetrics` (shared/form_primitives.dart):
// both intake forms are the same drawing at two widths.

class _CreateDefectView extends StatefulWidget {
  const _CreateDefectView();

  @override
  State<_CreateDefectView> createState() => _CreateDefectViewState();
}

class _CreateDefectViewState extends State<_CreateDefectView> {
  bool _techOpen = false;

  void _toggleTech() => setState(() => _techOpen = !_techOpen);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateDefectBloc, CreateDefectState>(
      builder: (context, state) {
        final mobile = isMobile(context);
        return Scaffold(
          body: SafeArea(
            child: state.success && state.createdDefectId != null
                ? _SuccessInline(
                    message: 'Defect ${state.createdDefectId} created',
                    detail: state.errorMessage,
                    onAction: () =>
                        context.go('/reports/${state.createdDefectId}'),
                    actionLabel: 'View defect',
                  )
                : SingleChildScrollView(
                    // `BP · Create Defect` insets its content to x236..1256
                    // (36 left of the rail, 24 right) with `Crumb` at y26;
                    // `BPM ·` uses the 16px mobile gutter under the back bar.
                    padding: mobile
                        ? const EdgeInsets.fromLTRB(
                            ShipItMetrics.mobileGutter,
                            16,
                            ShipItMetrics.mobileGutter,
                            16,
                          )
                        : const EdgeInsets.fromLTRB(
                            ShipItMetrics.contentGutter,
                            26,
                            24,
                            23,
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.errorMessage != null && !state.success)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DesignErrorState(
                              title: 'Could not create defect',
                              detail: state.errorMessage!,
                              onRetry: () => context
                                  .read<CreateDefectBloc>()
                                  .add(CreateDefectSubmitted()),
                            ),
                          ),
                        if (mobile)
                          _MobileBody(
                            state: state,
                            techOpen: _techOpen,
                            onToggleTech: _toggleTech,
                          )
                        else
                          _DesktopBody(
                            state: state,
                            techOpen: _techOpen,
                            onToggleTech: _toggleTech,
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------- desktop

class _DesktopBody extends StatelessWidget {
  const _DesktopBody({
    required this.state,
    required this.techOpen,
    required this.onToggleTech,
  });

  final CreateDefectState state;
  final bool techOpen;
  final VoidCallback onToggleTech;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeader(
          parentLabel: 'Defects',
          parentRef: 'Report a bug',
          onParentTap: () => context.go('/reports'),
          title: 'Report Bug',
          titleKey: const Key('create-defect-title'),
          // The board carries no status row yet still lands `Header Rule` on
          // y110, so the strip keeps its 14px slot and the gap above it is
          // tightened to absorb the missing tick and facts.
          headerGap: 10,
        ),
        const SizedBox(height: 18),
        const IntakeTabs(active: IntakeKind.bug),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormSectionTitle(title: "What you're reporting"),
                  const SizedBox(height: 1),
                  SizedBox(
                    height: 30,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Describe what went wrong and what you expected. '
                        'The chosen product filters the work items you can '
                        'attach.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ShipItType.bodySmall.copyWith(
                          color: context.palette.inkSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FormFields(state: state, mobile: false),
                ],
              ),
            ),
            const SizedBox(width: 32),
            SizedBox(width: 392, child: _RightPanel(state: state)),
          ],
        ),
        const SizedBox(height: 42),
        _DesktopTech(
          lines: _techLines(state),
          open: techOpen,
          onToggle: onToggleTech,
        ),
      ],
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.state});

  final CreateDefectState state;

  static const _steps = [
    '1   Your report is recorded with a stable DEF- reference',
    '2   Triage investigates and proposes a classification',
    '3   If it needs more from you, it asks — and stops',
    '4   Design and requirement calls come back to you',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final submitting = state.isSubmitting;
    return SidePanel(
      children: [
        const FormSectionTitle(title: 'What happens next'),
        const SizedBox(height: 1),
        SizedBox(
          height: 30,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              'Your report is recorded immediately. Triage runs as a durable '
              'job, so it survives a restart.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const ContentRule(),
        const SizedBox(height: 19),
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          SizedBox(
            height: 14,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _steps[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 36,
          child: FilledButton(
            onPressed: submitting
                ? null
                : () => context.read<CreateDefectBloc>().add(
                    CreateDefectSubmitted(),
                  ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Submit report',
                    style: ShipItType.sectionTitleSmall.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Triage starts automatically after you submit',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- mobile

class _MobileBody extends StatelessWidget {
  const _MobileBody({
    required this.state,
    required this.techOpen,
    required this.onToggleTech,
  });

  final CreateDefectState state;
  final bool techOpen;
  final VoidCallback onToggleTech;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Report Bug',
          key: const Key('create-defect-title'),
          style: ShipItType.pageTitleMobile.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 12),
        const IntakeTabs(active: IntakeKind.bug),
        const SizedBox(height: 18),
        SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Describe what went wrong and what you expected.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShipItType.pageSubtitle.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.inkSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _FormFields(state: state, mobile: true),
        const SizedBox(height: 30),
        SizedBox(
          height: 36,
          child: FilledButton(
            onPressed: state.isSubmitting
                ? null
                : () => context.read<CreateDefectBloc>().add(
                    CreateDefectSubmitted(),
                  ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Submit report',
                    style: ShipItType.navActive.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 15,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Triage starts automatically after you submit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShipItType.bodyMicro.copyWith(color: palette.inkTertiary),
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (techOpen) ...[
          for (final line in _techLines(state))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ),
          const SizedBox(height: 9),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: InlineLink(
            micro: true,
            label: techOpen
                ? 'Hide technical details'
                : 'Show technical details',
            caret: techOpen ? CaretDirection.down : CaretDirection.right,
            onTap: onToggleTech,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- form

/// The nine board fields in board order. Mobile stacks all of them full
/// width; desktop pairs `SEVERITY`/`INTAKE CATEGORY` and `PRODUCT`/
/// `AFFECTED WORK ITEM` into 288px columns with a 20px gutter.
class _FormFields extends StatelessWidget {
  const _FormFields({required this.state, required this.mobile});

  final CreateDefectState state;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CreateDefectBloc>();

    final title = FormFieldSlot(
      label: 'TITLE',
      control: SingleLineInput(
        hintText: 'Short summary of what went wrong',
        errorText: state.title.trim().isEmpty && state.isSubmitting
            ? 'Title is required'
            : null,
        onChanged: (v) => bloc.add(CreateDefectTitleChanged(v)),
      ),
    );
    final whatHappened = FormFieldSlot(
      label: 'WHAT HAPPENED?',
      control: TextAreaBox(
        hintText: 'What you did, and what the system did',
        onChanged: (v) => bloc.add(CreateDefectDescriptionChanged(v)),
      ),
    );
    final expected = FormFieldSlot(
      label: 'WHAT DID YOU EXPECT?',
      control: TextAreaBox(
        hintText: 'What you expected the system to do',
        onChanged: (v) => bloc.add(CreateDefectExpectedBehaviorChanged(v)),
      ),
    );
    final repro = FormFieldSlot(
      label: 'REPRODUCTION STEPS (OPTIONAL)',
      control: TextAreaBox(
        hintText: '1. Go to…\n2. Click…\n3. See…',
        onChanged: (v) => bloc.add(CreateDefectReproductionStepsChanged(v)),
      ),
    );
    final severity = FormFieldSlot(
      label: 'SEVERITY',
      control: FormSelect(
        hint: 'Choose severity',
        value: state.severity,
        options: CreateDefectState.severityOptions,
        errorText: state.severity == null && state.isSubmitting
            ? 'Required'
            : null,
        onChanged: (v) => bloc.add(CreateDefectSeverityChanged(v ?? '')),
      ),
    );
    final category = FormFieldSlot(
      label: 'INTAKE CATEGORY (OPTIONAL)',
      control: FormSelect(
        hint: 'Choose a category',
        value: state.intakeCategory,
        options: CreateDefectState.intakeCategoryOptions,
        onChanged: (v) => bloc.add(CreateDefectIntakeCategoryChanged(v)),
      ),
    );
    final product = FormFieldSlot(
      label: 'PRODUCT',
      control: FormSelect(
        hint: 'Choose a product',
        value: state.productId,
        options: state.products,
        onChanged: (v) => bloc.add(CreateDefectProductChanged(v)),
      ),
    );
    final workItem = FormFieldSlot(
      label: 'AFFECTED WORK ITEM (OPTIONAL)',
      control: FormSelect(
        hint: 'Choose a work item',
        value: state.effectiveWorkItemId,
        options: state.workItems,
        onChanged: (v) => bloc.add(CreateDefectAffectedWorkItemChanged(v)),
      ),
    );
    final evidence = FormFieldSlot(
      label: 'EVIDENCE (OPTIONAL)',
      control: _EvidenceBox(state: state),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in [
            title,
            whatHappened,
            expected,
            repro,
            severity,
            category,
            product,
            workItem,
            evidence,
          ]) ...[if (field != title) const SizedBox(height: 14), field],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: FormMetrics.fieldGapFirst),
        whatHappened,
        const SizedBox(height: FormMetrics.fieldGap),
        expected,
        const SizedBox(height: FormMetrics.fieldGap),
        repro,
        const SizedBox(height: FormMetrics.fieldGap),
        FieldPair(left: severity, right: category),
        const SizedBox(height: FormMetrics.fieldGap),
        FieldPair(left: product, right: workItem),
        const SizedBox(height: FormMetrics.fieldGap),
        evidence,
      ],
    );
  }
}

/// `Fld Box 8` — the board's drop target. The platform has no artifact store,
/// so picking records the file's name, size and SHA-256 as evidence metadata.
class _EvidenceBox extends StatelessWidget {
  const _EvidenceBox({required this.state});

  final CreateDefectState state;

  Future<void> _pick(BuildContext context) async {
    final bloc = context.read<CreateDefectBloc>();
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return;
    final files = <CreateDefectEvidenceFile>[];
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      files.add(
        CreateDefectEvidenceFile(
          name: file.name,
          size: bytes.length,
          sha256: sha256.convert(bytes).toString(),
        ),
      );
    }
    if (files.isEmpty || !context.mounted) return;
    bloc.add(CreateDefectEvidenceAdded(files));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final evidence = state.evidence;
    return Semantics(
      button: true,
      label: 'Attach evidence',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _pick(context),
          child: Container(
            height: FormMetrics.boxMulti,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            decoration: BoxDecoration(
              color: palette.card,
              border: Border.all(color: palette.cardBorder),
              borderRadius: BorderRadius.circular(ShipItMetrics.radius),
            ),
            child: evidence.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Drop a screenshot, or choose a file',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.bodySmall.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < evidence.length; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                evidence[i].description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ShipItType.bodySmall.copyWith(
                                  color: palette.inkPrimary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.read<CreateDefectBloc>().add(
                                CreateDefectEvidenceRemoved(i),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: palette.inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Desktop footer: `Footer Rule` + `Show technical details ▸`, in the shape
/// `TechnicalDetails` already uses on the other screens.
class _DesktopTech extends StatelessWidget {
  const _DesktopTech({
    required this.lines,
    required this.open,
    required this.onToggle,
  });

  final List<String> lines;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (open) ...[
          const MicroLabel('TECHNICAL DETAILS'),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: ShipItType.monoMeta.copyWith(
                  color: context.palette.inkTertiary,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        const ContentRule(),
        const SizedBox(height: 13),
        Row(
          children: [
            const Spacer(),
            InlineLink(
              micro: true,
              label: open ? 'Hide technical details' : 'Show technical details',
              caret: open ? CaretDirection.down : CaretDirection.right,
              onTap: onToggle,
            ),
          ],
        ),
      ],
    );
  }
}

class _SuccessInline extends StatelessWidget {
  const _SuccessInline({
    required this.message,
    required this.onAction,
    required this.actionLabel,
    this.detail,
  });

  final String message;
  final String? detail;
  final VoidCallback onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return DesignEmptyState(
      title: message,
      body: detail ?? '',
      tone: EmptyTone.settled,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

List<String> _techLines(CreateDefectState state) => [
  'view = create_defect',
  'productId = ${state.productId ?? "unset"}',
  'affectedWorkItemId = ${state.effectiveWorkItemId ?? "unset"}',
  'severity = ${state.severity ?? "unset"}',
  'intakeCategory = ${state.intakeCategory ?? "unset"}',
  'evidence = ${state.evidence.length}',
];

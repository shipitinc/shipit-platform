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
import 'create_feature_request_bloc.dart';
import 'create_feature_request_event.dart';
import 'create_feature_request_state.dart';
import 'intake_tabs.dart';
import 'reports_state.dart';

/// The Create Feature Request screen — `BP/BPM · Request Feature`.
///
/// Route: /reports/new-feature
///
/// The board is a three-field form: a title, the use case in the reporter's own
/// words, and the product it is for. There is no severity, no reproduction
/// steps and no evidence drop, because none of those are what a product owner
/// needs in order to decide whether to take a request on — and a form that asks
/// for more than the decision needs is a form that gets abandoned.
///
/// The request is filed as a draft work item and stops there. Nothing is
/// scheduled, no code changes, and no agent acts on it. The panel on the right
/// says so, because "send feature request" otherwise reads like an order.
class CreateFeatureRequestPage extends StatelessWidget {
  const CreateFeatureRequestPage({
    super.key,
    this.bloc,
    this.reporter = 'operator',
  });

  /// Test-only dependency seam.
  final CreateFeatureRequestBloc? bloc;

  final String reporter;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<CreateFeatureRequestBloc>.value(
            value: provided,
            child: const _CreateFeatureRequestView(),
          )
        : BlocProvider<CreateFeatureRequestBloc>(
            create: (_) => CreateFeatureRequestBloc(
              repository: ClientProvider.repository,
              reporter: reporter,
            ),
            child: const _CreateFeatureRequestView(),
          );
  }
}

/// `Request Feature` spaces its labels 8px above their boxes and 32px between
/// fields — a wider rhythm than the bug form's 4/18, and the reason the
/// three-field form reads as three deliberate questions rather than a stack.
const double _labelGap = 8;
const double _fieldGap = 32;

class _CreateFeatureRequestView extends StatelessWidget {
  const _CreateFeatureRequestView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateFeatureRequestBloc, CreateFeatureRequestState>(
      builder: (context, state) {
        final mobile = isMobile(context);
        return Scaffold(
          body: SafeArea(
            child: state.success && state.createdWorkItemId != null
                ? _Filed(
                    ref: state.createdRef,
                    title: state.createdTitle ?? '',
                    onAction: () => context.go(
                      '/reports?tab=${IntakeKind.feature.tabParamValue}',
                    ),
                  )
                : SingleChildScrollView(
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
                        if (state.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DesignErrorState(
                              title: 'Could not file the request',
                              detail: state.errorMessage!,
                              onRetry: () => context
                                  .read<CreateFeatureRequestBloc>()
                                  .add(const CreateFeatureRequestSubmitted()),
                            ),
                          ),
                        if (mobile)
                          _MobileBody(state: state)
                        else
                          _DesktopBody(state: state),
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
  const _DesktopBody({required this.state});

  final CreateFeatureRequestState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormSectionTitle(title: "What you're asking for"),
                  const SizedBox(height: 1),
                  SizedBox(
                    height: 30,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Say what you would like to happen and who it is for. '
                        'A product owner reads this before anything is built.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ShipItType.bodySmall.copyWith(
                          color: context.palette.inkSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _Fields(),
                ],
              ),
            ),
            const SizedBox(width: 32),
            SizedBox(width: 392, child: _NextPanel(state: state)),
          ],
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailHeader(
          parentLabel: 'Reports',
          parentRef: 'Request a feature',
          onParentTap: () => context.go('/reports'),
          title: 'Request Feature',
          titleKey: const Key('create-feature-request-title'),
          headerGap: 10,
        ),
        const SizedBox(height: 18),
        const IntakeTabs(active: IntakeKind.feature),
      ],
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CreateFeatureRequestBloc>();
    return BlocBuilder<CreateFeatureRequestBloc, CreateFeatureRequestState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormFieldSlot(
            label: 'TITLE',
            labelGap: _labelGap,
            control: SingleLineInput(
              hintText: 'What would you like to build?',
              errorText: state.titleError,
              onChanged: (v) => bloc.add(CreateFeatureRequestTitleChanged(v)),
            ),
          ),
          const SizedBox(height: _fieldGap),
          FormFieldSlot(
            label: 'USE CASE',
            labelGap: _labelGap,
            control: TextAreaBox(
              hintText: 'Who needs this, and what would it change for them?',
              onChanged: (v) =>
                  bloc.add(CreateFeatureRequestDescriptionChanged(v)),
            ),
          ),
          const SizedBox(height: _fieldGap),
          FormFieldSlot(
            label: 'PRODUCT',
            labelGap: _labelGap,
            control: FormSelect(
              hint: state.optionsLoading
                  ? 'Loading products…'
                  : 'Choose a product',
              value: state.productId,
              options: state.products,
              errorText: state.productError,
              onChanged: (v) =>
                  bloc.add(CreateFeatureRequestProductChanged(v ?? '')),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextPanel extends StatelessWidget {
  const _NextPanel({required this.state});

  final CreateFeatureRequestState state;

  static const _steps = [
    '1   Your request is recorded as a draft, with a stable reference',
    '2   The product owner reviews it',
    '3   If they need more, they ask you — and wait',
    '4   It is scheduled, or closed with a reason',
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
              'Nothing is scheduled and no code changes when you send this. A '
              'person decides what happens to it.',
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
                : () => context.read<CreateFeatureRequestBloc>().add(
                    const CreateFeatureRequestSubmitted(),
                  ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Send request',
                    style: ShipItType.sectionTitleSmall.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Reviewed by a person, not an agent',
          style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- mobile

class _MobileBody extends StatelessWidget {
  const _MobileBody({required this.state});

  final CreateFeatureRequestState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Request Feature',
          key: const Key('create-feature-request-title'),
          style: ShipItType.pageTitleMobile.copyWith(color: palette.inkPrimary),
        ),
        const SizedBox(height: 12),
        const IntakeTabs(active: IntakeKind.feature),
        const SizedBox(height: 18),
        SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Say what you would like to happen and who it is for.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShipItType.pageSubtitle.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.inkSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _Fields(),
        const SizedBox(height: 30),
        SizedBox(
          height: 36,
          child: FilledButton(
            onPressed: state.isSubmitting
                ? null
                : () => context.read<CreateFeatureRequestBloc>().add(
                    const CreateFeatureRequestSubmitted(),
                  ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Send request',
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
              'Reviewed by a person, not an agent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShipItType.bodyMicro.copyWith(color: palette.inkTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

/// The filed state. It says what now exists — a draft with a reference — and
/// points at the register the request will appear in.
class _Filed extends StatelessWidget {
  const _Filed({
    required this.ref,
    required this.title,
    required this.onAction,
  });

  final String ref;
  final String title;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return DesignEmptyState(
      title: '$title is filed as a draft',
      body:
          'Reference $ref. It is waiting for a product owner to review it — '
          'nothing is scheduled and no code changes yet.',
      tone: EmptyTone.settled,
      actionLabel: 'View feature requests',
      onAction: onAction,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/plain_language.dart';
import '../../core/theme.dart';
import '../../data/client_provider.dart';
import '../../shared/design_primitives.dart';
import '../../shared/mobile_chrome.dart';
import '../../shared/state_views.dart';
import 'feature_request.dart';
import 'feature_request_list_bloc.dart';
import 'feature_request_list_event.dart';
import 'feature_request_list_state.dart';

/// The Reports screen's `Feature requests` register.
///
/// Composed in the same language as the defect register it sits beside: the
/// same column grid, the same rules, the same plain statement of what is
/// absent, the same "nothing was changed" failure copy. A request that is
/// filed here becomes a draft work item, so a row that is merely `draft` is
/// working as intended — not a stalled one.
class FeatureRequestListPage extends StatelessWidget {
  const FeatureRequestListPage({super.key, this.bloc, this.header, this.clock});

  /// Test-only dependency seam.
  final FeatureRequestListBloc? bloc;

  /// The Reports header and tab row, supplied by [ReportsPage] so the register
  /// renders below them rather than repeating them.
  final Widget? header;

  /// Supplies "now" for freshness stamps. Injectable for deterministic goldens.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<FeatureRequestListBloc>.value(
            value: provided,
            child: _FeatureRequestListView(header: header, clock: clock),
          )
        : BlocProvider<FeatureRequestListBloc>(
            create: (_) =>
                FeatureRequestListBloc(repository: ClientProvider.repository)
                  ..add(const FeatureRequestListRequested()),
            child: _FeatureRequestListView(header: header, clock: clock),
          );
  }
}

class _FeatureRequestListView extends StatelessWidget {
  const _FeatureRequestListView({this.header, this.clock});

  final Widget? header;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureRequestListBloc, FeatureRequestListState>(
      builder: (context, state) =>
          _Register(state: state, header: header, clock: clock),
    );
  }
}

/// Column grid. `tick(2) + gap(10) + these == 1020`, matching the defect
/// register so both tabs share one left and right edge.
const double _colRef = 96;
const double _colTitle = 386;
const double _colState = 156;
const double _colProduct = 190;
const double _colReported = 180;

/// `H1 Sub` copy per state, transcribed from the Reports boards.
const String _emptyTitle = 'No feature requests yet';
const String _emptyBody =
    'A request appears here the moment you file it. It waits as a draft for a '
    'product owner to review — nothing is scheduled, and no code changes until '
    'a person decides.';
const String _errorTitle = 'We could not reach the system’s records.';
const String _footerNote =
    'Every request here is a draft work item. Nothing on this page has started '
    'work on its own.';

/// `WorkflowState` as the register names it. A request is filed as `draft` and
/// leaves that state only when a human moves it, so the register can say
/// plainly what each row is waiting for.
String _stateLabel(String wire) => switch (wire) {
  'draft' => 'Waiting for review',
  'needs_clarification' => 'Needs clarification',
  'ready' => 'Ready to plan',
  'in_progress' => 'In progress',
  'blocked' => 'Blocked',
  'done' => 'Accepted',
  'cancelled' => 'Closed',
  _ => wire.replaceAll('_', ' '),
};

class _Register extends StatefulWidget {
  const _Register({required this.state, this.header, this.clock});

  final FeatureRequestListState state;
  final Widget? header;
  final DateTime Function()? clock;

  @override
  State<_Register> createState() => _RegisterState();
}

class _RegisterState extends State<_Register> {
  late bool _techOpen;

  @override
  void initState() {
    super.initState();
    _techOpen = widget.state.isErrorScreen;
  }

  @override
  void didUpdateWidget(covariant _Register oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isErrorScreen && !oldWidget.state.isErrorScreen) {
      _techOpen = true;
    }
  }

  String get _sinceStamp {
    final at = widget.state.lastSuccessAt;
    if (at == null) return '';
    final now = widget.clock?.call() ?? DateTime.now();
    return 'last successful reading '
        '${PlainLanguage.elapsed(now.difference(at))} ago';
  }

  void _reload() => context.read<FeatureRequestListBloc>().add(
    FeatureRequestListRequested(productId: widget.state.productId),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mobile = isMobile(context);
    final s = widget.state;

    if (s.isErrorScreen) {
      return DesignErrorState(
        title: _errorTitle,
        detail: s.errorMessage!,
        lastSuccess: s.lastSuccessAt == null ? null : _sinceStamp,
        onRetry: _reload,
      );
    }

    if (s.isLoadingScreen) {
      return const DesignLoadingSkeleton(
        title: 'Reports',
        rows: 6,
        showColumns: false,
      );
    }

    final body = mobile
        ? _mobileBody(context, palette, header: widget.header)
        : _desktopBody(context, palette, header: widget.header);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: mobile
                  ? const EdgeInsets.fromLTRB(
                      ShipItMetrics.mobileGutter,
                      16,
                      ShipItMetrics.mobileGutter,
                      0,
                    )
                  : const EdgeInsets.fromLTRB(
                      ShipItMetrics.contentGutter,
                      30,
                      24,
                      0,
                    ),
              child: body,
            ),
          ),
        ),
        if (!s.isEmpty)
          Padding(
            padding: mobile
                ? const EdgeInsets.fromLTRB(
                    ShipItMetrics.mobileGutter,
                    0,
                    ShipItMetrics.mobileGutter,
                    4,
                  )
                : const EdgeInsets.fromLTRB(
                    ShipItMetrics.contentGutter,
                    0,
                    24,
                    23,
                  ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ContentRule(),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _footerNote,
                        style: ShipItType.monoMeta.copyWith(
                          color: palette.inkTertiary,
                        ),
                      ),
                    ),
                    if (!mobile)
                      SizedBox(
                        width: 220,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InlineLink(
                            micro: true,
                            label: _techOpen
                                ? 'Hide technical details'
                                : 'Show technical details',
                            caret: _techOpen
                                ? CaretDirection.down
                                : CaretDirection.right,
                            onTap: () => setState(() => _techOpen = !_techOpen),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- desktop

  Widget _desktopBody(
    BuildContext context,
    ShipItPalette palette, {
    Widget? header,
  }) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[header, const SizedBox(height: 22)],
        if (s.isEmpty) ...[
          const SizedBox(height: 24),
          _desktopEmpty(context, palette),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Feature requests',
                  style: ShipItType.sectionTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              ProductFilterLink(
                label: s.productFilterLabel,
                products: s.products,
                onChanged: (productId) =>
                    context.read<FeatureRequestListBloc>().add(
                      FeatureRequestListRequested(
                        productId: productId.isEmpty ? null : productId,
                      ),
                    ),
              ),
              const SizedBox(width: 24),
              const SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InlineLink(
                    label: 'Newest first',
                    caret: CaretDirection.down,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _TableHeader(),
          const SizedBox(height: 5),
          const ContentRule(strong: true),
          const SizedBox(height: 22),
          for (var i = 0; i < s.requests.length; i++)
            _DesktopRow(
              request: s.requests[i],
              last: i == s.requests.length - 1,
              clock: widget.clock,
            ),
          const SizedBox(height: 27),
          const _RequestFeatureLink(),
        ],
      ],
    );
  }

  Widget _desktopEmpty(BuildContext context, ShipItPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        DesignEmptyState(
          title: _emptyTitle,
          body: _emptyBody,
          actionLabel: 'Request a feature',
          onAction: () => context.go('/reports/new-feature'),
        ),
        const SizedBox(height: 27),
        const _RequestFeatureLink(),
      ],
    );
  }

  // ----------------------------------------------------------------- mobile

  Widget _mobileBody(
    BuildContext context,
    ShipItPalette palette, {
    Widget? header,
  }) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[header, const SizedBox(height: 18)],
        if (s.isEmpty) ...[
          DesignEmptyState(
            title: _emptyTitle,
            body: _emptyBody,
            actionLabel: 'Request a feature',
            onAction: () => context.go('/reports/new-feature'),
          ),
          const SizedBox(height: 24),
          const _RequestFeatureLink(),
        ] else ...[
          for (var i = 0; i < s.requests.length; i++)
            _MobileRow(
              request: s.requests[i],
              last: i == s.requests.length - 1,
              clock: widget.clock,
            ),
          const SizedBox(height: 24),
          const _RequestFeatureLink(),
        ],
      ],
    );
  }
}

/// `Col · REF … REPORTED` — the defect register's grid, re-cut for what a
/// request actually carries: no severity and no classification, and a
/// `REPORTED` column where the defect register spends that width on `REF`.
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: ShipItMetrics.colRefInset),
        SizedBox(width: _colRef, child: MicroLabel('REF')),
        SizedBox(width: _colTitle, child: MicroLabel('TITLE')),
        SizedBox(width: _colState, child: MicroLabel('STATE')),
        SizedBox(width: _colProduct, child: MicroLabel('PRODUCT')),
        SizedBox(width: _colReported, child: MicroLabel('REPORTED')),
      ],
    );
  }
}

/// One request, on the table's 46px pitch: an 18px tick, the ref, the title,
/// then the state, product and age. The rule closes the row.
class _DesktopRow extends StatelessWidget {
  const _DesktopRow({required this.request, required this.last, this.clock});

  final FeatureRequest request;
  final bool last;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = (clock ?? DateTime.now)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: ShipItMetrics.rowPitch - ShipItMetrics.hairline,
          child: Row(
            children: [
              SizedBox(
                width: ShipItMetrics.colRefInset,
                child: AccentTick(
                  color: palette.inkQuiet,
                  height: ShipItMetrics.rowTickHeight,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: _colRef,
                child: Text(
                  request.workItemId,
                  style: ShipItType.ref.copyWith(color: palette.inkTertiary),
                ),
              ),
              SizedBox(
                width: _colTitle,
                child: Text(
                  request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.rowTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: _colState,
                child: Text(
                  _stateLabel(request.state),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: _colProduct,
                child: Text(
                  request.productLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShipItType.bodySmall.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: _colReported,
                child: Text(
                  PlainLanguage.elapsed(now.difference(request.createdAt)),
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ContentRule(strong: last),
      ],
    );
  }
}

/// `Row Title n` + `Row State n` / `Row Product n`, 52px pitch, with a trailing
/// chevron. A request has no detail screen of its own yet, so the row is not
/// tappable — it would otherwise imply a destination that does not exist.
class _MobileRow extends StatelessWidget {
  const _MobileRow({required this.request, required this.last, this.clock});

  final FeatureRequest request;
  final bool last;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = (clock ?? DateTime.now)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccentTick(
                color: palette.inkQuiet,
                height: ShipItMetrics.rowTickHeight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.rowTitleMobile.copyWith(
                        color: palette.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_stateLabel(request.state)} · '
                      '${request.productLabel} · '
                      '${PlainLanguage.elapsed(now.difference(request.createdAt))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.monoMeta.copyWith(
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ContentRule(strong: last),
      ],
    );
  }
}

/// `Request a feature` — the register's own call to action, paired with the
/// defect register's `Report a bug`.
class _RequestFeatureLink extends StatelessWidget {
  const _RequestFeatureLink();

  @override
  Widget build(BuildContext context) {
    return InlineLink(
      label: 'Request a feature',
      caret: CaretDirection.right,
      onTap: () => context.go('/reports/new-feature'),
    );
  }
}

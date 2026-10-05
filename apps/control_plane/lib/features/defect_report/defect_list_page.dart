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
import '../../shared/mobile_chrome.dart';
import 'defect_list_bloc.dart';
import 'defect_list_event.dart';
import 'defect_list_state.dart';
import 'defect_status_badge.dart';

/// The Defects list screen.
///
/// Route: /reports (the `Defects` tab)
///
/// Every coordinate, label and tone in this file is transcribed from
/// `BP · Defect List · Populated / Loading / Empty / Error` and their
/// `BPM ·` (390px) counterparts. Where a board says a control exists but the
/// data cannot back it (see [_sortLabel]) the control is rendered as the
/// board draws it and reported as a known deviation.
///
/// [header] replaces this screen's own page header. The Reports surface passes
/// one so the `Defects` and `Feature requests` tabs share a single header and
/// a single place the active underline can be; left null, the screen still
/// stands alone with its own `Defects` title.
class DefectListPage extends StatelessWidget {
  const DefectListPage({super.key, this.bloc, this.clock, this.header});

  /// Test-only dependency seam.
  final DefectListBloc? bloc;

  /// Supplies "now" for freshness stamps. Injectable for deterministic goldens.
  final DateTime Function()? clock;

  /// Page header supplied by the surface hosting this register.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final provided = bloc;
    return provided != null
        ? BlocProvider<DefectListBloc>.value(
            value: provided,
            child: _DefectListView(clock: clock, header: header),
          )
        : BlocProvider<DefectListBloc>(
            create: (_) =>
                DefectListBloc(repository: ClientProvider.repository)
                  ..add(DefectListLoaded()),
            child: _DefectListView(clock: clock, header: header),
          );
  }
}

class _DefectListView extends StatelessWidget {
  const _DefectListView({this.clock, this.header});

  final DateTime Function()? clock;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DefectListBloc, DefectListState>(
      builder: (context, state) =>
          _DefectScreen(state: state, clock: clock, header: header),
    );
  }
}

/// `Chip 0..5` on `BP · Defect List` — six status filters, transcribed
/// literally. The board carries no classification filter row.
const List<(String, String?)> _statusFilters = [
  ('All', null),
  ('Reported', 'reported'),
  ('Triaging', 'triaging'),
  ('Needs clarification', 'needs_clarification'),
  ('Confirmed', 'confirmed'),
  ('Resolved', 'resolved'),
];

/// Desktop table column widths. `tick(2) + gap(10) + these == 1020`.
const double _colRef = 88;
const double _colTitle = 300;
const double _colSeverity = 88;
const double _colStatus = 156;
const double _colClassification = 122;
const double _colProduct = 138;
const double _colAffected = 116;

/// Gap from `Header Rule` down to the first element that follows it.
const double _afterHeaderRule = 40;
const double _headersFromRule = 114;

const String _errorTitle = 'We could not reach the system’s records.';
const String _errorBody =
    'Nothing has been changed. No decision was recorded and no work '
    'was started or stopped by this failure.';
const String _emptyTitle = 'No defects reported';
const String _emptyBody =
    'A defect appears here the moment you report it. Triage starts '
    'automatically and proposes a classification — design and requirement '
    'decisions still come back to you.';
const String _emptyBodyMobile =
    'A defect appears here the moment you report it. Triage starts '
    'automatically and proposes a classification.';
const String _loadingNote =
    'Nothing is shown until it has been read from the durable record.';
const String _footerNote =
    'Every number on this page comes straight from the system’s own '
    'records. Nothing here is guessed.';

/// Board shows `Product: All  ▾` as a filter. A defect summary carries no
/// product, so the control is drawn as designed and cannot yet narrow results.
/// The board's content box runs x=236..1256 — 1020 wide — so the right gutter
/// is 24 while the left stays 36. Transcribed literally rather than matched to
/// the 1008 the other surfaces render.
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(
  ShipItMetrics.contentGutter,
  30,
  24,
  0,
);

/// Board shows `Newest first  ▾`. The list is served newest-first already.
const String _sortLabel = 'Newest first';

String _severityLabel(String wire) => switch (wire) {
  'blocking' => 'Blocking',
  'annoying' => 'Annoying',
  'cosmetic' => 'Cosmetic',
  'data_loss' => 'Data-loss',
  _ => wire,
};

Color _severityTone(String wire, ShipItPalette palette) => switch (wire) {
  'blocking' => palette.attention,
  'annoying' => palette.inkSecondary,
  'cosmetic' => palette.inkQuiet,
  'data_loss' => palette.negative,
  _ => palette.inkPrimary,
};

String _classificationLabel(String? wire) {
  if (wire == null) return '—';
  try {
    return switch (DefectClassification.fromWire(wire)) {
      DefectClassification.implementationDefect => 'Implementation',
      DefectClassification.designDefect => 'Design',
      DefectClassification.requirementGap => 'Requirement gap',
      DefectClassification.environmentDefect => 'Environment',
    };
  } on FormatException {
    return wire;
  }
}

class _DefectScreen extends StatefulWidget {
  const _DefectScreen({required this.state, this.clock, this.header});

  final DefectListState state;
  final DateTime Function()? clock;
  final Widget? header;

  @override
  State<_DefectScreen> createState() => _DefectScreenState();
}

class _DefectScreenState extends State<_DefectScreen> {
  late bool _techOpen;

  bool get _error =>
      widget.state.errorMessage != null && widget.state.defects.isEmpty;

  bool get _loading => widget.state.isLoading && widget.state.defects.isEmpty;

  bool get _populated => widget.state.defects.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _techOpen = _error;
  }

  @override
  void didUpdateWidget(covariant _DefectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_error && oldWidget.state.errorMessage == null) _techOpen = true;
  }

  List<String> get _techLines {
    final s = widget.state;
    if (_error) return [s.errorMessage!];
    return [
      'filters: status=${s.statusFilter ?? 'none'} '
          'classification=${s.classificationFilter ?? 'none'}',
      'displayed=${s.displayedCount} total=${s.totalCount}',
    ];
  }

  /// `Err Since` — "last successful reading 2m ago". Only a real read stamps
  /// it, so the first load failing shows nothing rather than a made-up date.
  String? get _sinceStamp {
    final at = widget.state.lastSuccessAt;
    if (at == null) return null;
    final now = widget.clock?.call() ?? DateTime.now();
    return 'last successful reading '
        '${PlainLanguage.elapsed(now.difference(at))} ago';
  }

  void _toggleTech() => setState(() => _techOpen = !_techOpen);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mobile = isMobile(context);
    final s = widget.state;

    final String subtitle;
    if (_loading) {
      subtitle = 'Reading the system’s records…';
    } else if (_error) {
      subtitle = 'The last reading failed.';
    } else if (_populated) {
      subtitle = mobile
          ? '${s.totalCount > 0 ? s.totalCount : s.defects.length} items in '
                'the last 30 days.'
          : 'Reported issues awaiting triage, remediation, and verification';
    } else {
      subtitle = 'Nothing has been recorded yet.';
    }

    final now = (widget.clock ?? DateTime.now)();
    final freshness = _populated && !mobile
        ? PlainLanguage.updatedAgo(now.difference(s.defects.first.updatedAt))
        : null;

    final body = mobile
        ? _mobileBody(context, palette, subtitle)
        : _desktopBody(context, palette, subtitle, freshness);
    final footer = mobile ? _mobileFooter(palette) : _desktopFooter(palette);

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
                  : _bodyPadding,
              child: body,
            ),
          ),
        ),
        if (footer != null) footer,
      ],
    );
  }

  // ---------------------------------------------------------------- desktop

  Widget _desktopBody(
    BuildContext context,
    ShipItPalette palette,
    String subtitle,
    String? freshness,
  ) {
    final s = widget.state;
    final header = widget.header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          header
        else
          PageHeader(
            title: 'Defects',
            subtitle: subtitle,
            liveLabel: _populated ? 'LIVE' : null,
            freshness: freshness,
            trailing: _loading
                ? _LiveStamp(
                    label: 'LOADING',
                    dotColor: palette.ruleStrong,
                    labelColor: palette.inkTertiary,
                  )
                : _error
                ? _LiveStamp(
                    label: 'NO CONTACT',
                    dotColor: palette.negative,
                    labelColor: palette.negative,
                  )
                : null,
          ),
        if (_populated) ...[
          const SizedBox(height: _afterHeaderRule),
          _StatusFilterRow(
            activeIndex: _activeStatusIndex,
            onSelected: _selectStatus,
            productLabel: s.productFilterLabel,
            products: s.products,
            onProductChanged: _selectProduct,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Defects',
                  style: ShipItType.sectionTitle.copyWith(
                    color: palette.inkPrimary,
                  ),
                ),
              ),
              const SizedBox(
                width: 160,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InlineLink(
                    label: _sortLabel,
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
          for (var i = 0; i < s.defects.length; i++)
            _DesktopDefectRow(
              defect: s.defects[i],
              last: i == s.defects.length - 1,
            ),
          const SizedBox(height: 27),
          const _ReportBugLink(),
        ],
        if (_loading) ...[
          const SizedBox(height: _headersFromRule),
          const _TableHeader(),
          const SizedBox(height: 5),
          const ContentRule(strong: true),
          const SizedBox(height: 22),
          for (var i = 0; i < 6; i++)
            _DesktopSkeletonRow(index: i, last: i == 5),
          const SizedBox(height: 26),
          Text(
            _loadingNote,
            style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
          ),
        ],
        if (!_populated && !_loading && !_error) ...[
          const SizedBox(height: _afterHeaderRule),
          _StatusFilterRow(
            activeIndex: _activeStatusIndex,
            onSelected: _selectStatus,
            productLabel: s.productFilterLabel,
            products: s.products,
            onProductChanged: _selectProduct,
          ),
          const SizedBox(height: 46),
          const _DesktopEmptyPanel(),
        ],
        if (_error) ...[
          const SizedBox(height: _afterHeaderRule),
          _DesktopErrorPanel(since: _sinceStamp),
          if (_techOpen) ...[
            const SizedBox(height: 30),
            _TechLines(lines: _techLines),
          ],
        ],
      ],
    );
  }

  Widget _mobileBody(
    BuildContext context,
    ShipItPalette palette,
    String subtitle,
  ) {
    final s = widget.state;
    final header = widget.header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          header
        else ...[
          Text(
            'Defects',
            style: ShipItType.pageTitle.copyWith(color: palette.inkPrimary),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: ShipItType.pageSubtitle.copyWith(
              color: palette.inkSecondary,
            ),
          ),
        ],
        if (_populated) ...[
          const SizedBox(height: 18),
          _MobileControls(
            filterLabel: _mobileFilterLabel,
            onFilterTap: _cycleStatus,
            productLabel: s.productFilterLabel,
            products: s.products,
            onProductChanged: _selectProduct,
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < s.defects.length; i++)
            _MobileDefectRow(
              defect: s.defects[i],
              last: i == s.defects.length - 1,
              onTap: () => context.go('/reports/${s.defects[i].defectId}'),
            ),
          const SizedBox(height: 27),
          const _ReportBugLink(),
        ],
        if (_loading) ...[
          const SizedBox(height: 30),
          for (var i = 0; i < 7; i++)
            _MobileSkeletonRow(index: i, last: i == 6),
        ],
        if (!_populated && !_loading && !_error) ...[
          const SizedBox(height: 18),
          _MobileControls(
            filterLabel: 'Showing: All defects',
            boxHeight: 34,
            boxWidth: 250,
            labelStyle: ShipItType.pageSubtitle,
            sortStyle: ShipItType.linkMicro,
            onFilterTap: _cycleStatus,
            productLabel: s.productFilterLabel,
            products: s.products,
            onProductChanged: _selectProduct,
          ),
          const SizedBox(height: 16),
          const ContentRule(),
          const SizedBox(height: 21),
          const _MobileEmptyPanel(),
        ],
        if (_error) ...[
          const SizedBox(height: 30),
          const _MobileErrorPanel(),
          if (_sinceStamp != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 16,
              child: Text(
                _sinceStamp!,
                style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 20),
          _TechLines(lines: _techLines, mobile: true),
        ],
      ],
    );
  }

  // ----------------------------------------------------------------- footers

  Widget? _desktopFooter(ShipItPalette palette) {
    if (!_populated && !_loading && !_error) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
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
                child: _populated
                    ? Text(
                        _footerNote,
                        style: ShipItType.monoMeta.copyWith(
                          color: palette.inkTertiary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
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
                    onTap: _toggleTech,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _mobileFooter(ShipItPalette palette) {
    if (!_populated) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShipItMetrics.mobileGutter,
        0,
        ShipItMetrics.mobileGutter,
        4,
      ),
      child: Row(
        children: [
          InlineLink(
            micro: true,
            label: _techOpen
                ? 'Hide technical details'
                : 'Show technical details',
            caret: _techOpen ? CaretDirection.down : CaretDirection.right,
            onTap: _toggleTech,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- filters

  int get _activeStatusIndex {
    final status = widget.state.statusFilter;
    if (status == null) return 0;
    final index = _statusFilters.indexWhere((f) => f.$2 == status);
    return index < 0 ? 0 : index;
  }

  String get _mobileFilterLabel {
    final index = _activeStatusIndex;
    final label = _statusFilters[index].$1;
    return index == 0 ? 'Showing: All defects' : 'Showing: $label';
  }

  void _selectStatus(int index) {
    final filter = _statusFilters[index];
    if (filter.$2 == widget.state.statusFilter) return;
    context.read<DefectListBloc>().add(
      DefectListFilterChanged(
        status: filter.$2,
        classification: widget.state.classificationFilter,
        productId: widget.state.productFilter,
      ),
    );
  }

  /// The product filter is sent to the server rather than applied to the rows
  /// already loaded, so `totalCount` keeps reporting the whole register while
  /// the visible rows are the ones that match.
  void _selectProduct(String productId) {
    if (productId == (widget.state.productFilter ?? '')) return;
    context.read<DefectListBloc>().add(
      DefectListFilterChanged(
        status: widget.state.statusFilter,
        classification: widget.state.classificationFilter,
        productId: productId.isEmpty ? null : productId,
      ),
    );
  }

  void _cycleStatus() =>
      _selectStatus((_activeStatusIndex + 1) % _statusFilters.length);
}

/// `Live` + `Live Dot` for the non-live states, where the tone changes.
class _LiveStamp extends StatelessWidget {
  const _LiveStamp({
    required this.label,
    required this.dotColor,
    required this.labelColor,
  });

  final String label;
  final Color dotColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 5, height: 5, color: dotColor),
        const SizedBox(width: 7),
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: ShipItType.microLabel.copyWith(color: labelColor),
          ),
        ),
      ],
    );
  }
}

/// `Chip 0..5` — mono 11, ls 1.1, active 600/inkPrimary, inactive 400/
/// inkTertiary, with a 2px accent rule under the active chip only.
class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({
    required this.activeIndex,
    required this.onSelected,
    required this.productLabel,
    required this.products,
    required this.onProductChanged,
  });

  final int activeIndex;
  final ValueChanged<int> onSelected;

  /// What the product filter currently reads, e.g. `Product: All`.
  final String productLabel;

  /// Every product, so the filter keeps offering them all while one is applied.
  final List<(String, String)> products;

  /// Empty string means "all products".
  final ValueChanged<String> onProductChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        for (var i = 0; i < _statusFilters.length; i++) ...[
          if (i > 0) const SizedBox(width: 20),
          Semantics(
            button: true,
            selected: i == activeIndex,
            label: _statusFilters[i].$1,
            child: GestureDetector(
              onTap: () => onSelected(i),
              behavior: HitTestBehavior.opaque,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: i == activeIndex
                          ? palette.accent
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _statusFilters[i].$1,
                    style: ShipItType.ref.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: i == activeIndex
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i == activeIndex
                          ? palette.inkPrimary
                          : palette.inkTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        SizedBox(
          width: 160,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ProductFilterLink(
              label: productLabel,
              products: products,
              onChanged: onProductChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// `Col · REF … AFFECTED WORK` — mono 9/600/ls 1.1, y-gap 12 above the rule.
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: ShipItMetrics.colRefInset),
        SizedBox(width: _colRef, child: MicroLabel('REF')),
        SizedBox(width: _colTitle, child: MicroLabel('TITLE')),
        SizedBox(width: _colSeverity, child: MicroLabel('SEVERITY')),
        SizedBox(width: _colStatus, child: MicroLabel('STATUS')),
        SizedBox(
          width: _colClassification,
          child: MicroLabel('CLASSIFICATION'),
        ),
        SizedBox(width: _colProduct, child: MicroLabel('PRODUCT')),
        SizedBox(width: _colAffected, child: MicroLabel('AFFECTED WORK')),
      ],
    );
  }
}

/// `Row Tick n … Row Affected n` — 18px of content, 13px, the row rule,
/// then 14px to the next row (46px pitch).
class _DesktopDefectRow extends StatelessWidget {
  const _DesktopDefectRow({required this.defect, required this.last});

  final DefectSummaryResponse defect;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = DefectStatus.fromWire(defect.status);
    final tone = DefectStatusBadge.listTone(status, palette);
    final classification = defect.classification;
    final affected = defect.affectedWorkItemId ?? defect.affectedRunId ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: '${defect.title}, ${DefectStatusBadge.label(status)}',
          child: GestureDetector(
            onTap: () => context.go('/reports/${defect.defectId}'),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: ShipItMetrics.rowTickHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AccentTick(color: tone, height: ShipItMetrics.rowTickHeight),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: _colRef,
                    child: Text(
                      defect.defectId,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: ShipItType.ref.copyWith(
                        color: palette.inkSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _colTitle,
                    child: Text(
                      defect.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.rowTitle.copyWith(
                        color: palette.inkPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _colSeverity,
                    child: Text(
                      _severityLabel(defect.severity),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.rowTitle.copyWith(
                        color: _severityTone(defect.severity, palette),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _colStatus,
                    child: Text(
                      DefectStatusBadge.label(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.rowTitle.copyWith(color: tone),
                    ),
                  ),
                  SizedBox(
                    width: _colClassification,
                    child: Text(
                      _classificationLabel(classification),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShipItType.rowTitle.copyWith(
                        color: classification == null
                            ? palette.inkQuiet
                            : palette.inkPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _colProduct,
                    child: Text(
                      '—',
                      maxLines: 1,
                      style: ShipItType.rowTitle.copyWith(
                        color: palette.inkQuiet,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _colAffected,
                    child: Text(
                      affected,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: ShipItType.ref.copyWith(
                        color: affected == '—'
                            ? palette.inkQuiet
                            : palette.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        const ContentRule(),
        if (!last) const SizedBox(height: 14),
      ],
    );
  }
}

class _DesktopSkeletonRow extends StatelessWidget {
  const _DesktopSkeletonRow({required this.index, required this.last});

  final int index;
  final bool last;

  static const _titleWidths = <double>[280, 240, 200, 270, 230, 190];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = palette.rule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: ShipItMetrics.rowTickHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 2, height: 18, color: color),
              const SizedBox(width: 10),
              Container(width: 72, height: 10, color: color),
              const SizedBox(width: 16),
              SizedBox(
                width: _colTitle,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: _titleWidths[index % _titleWidths.length],
                    height: 12,
                    color: color,
                  ),
                ),
              ),
              Container(width: 56, height: 10, color: color),
              const SizedBox(width: 32),
              Container(width: 110, height: 10, color: color),
              const SizedBox(width: 46),
              Container(width: 90, height: 10, color: color),
              const SizedBox(width: 32),
              Container(width: 100, height: 10, color: color),
              const SizedBox(width: 38),
              Container(width: 72, height: 10, color: color),
            ],
          ),
        ),
        const SizedBox(height: 13),
        const ContentRule(),
        if (!last) const SizedBox(height: 14),
      ],
    );
  }
}

class _ReportBugLink extends StatelessWidget {
  const _ReportBugLink();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.go('/reports/new-bug'),
        behavior: HitTestBehavior.opaque,
        child: Text(
          '+ Report a bug',
          style: ShipItType.reportBug.copyWith(color: palette.accent),
        ),
      ),
    );
  }
}

class _DesktopEmptyPanel extends StatelessWidget {
  const _DesktopEmptyPanel();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.ruleStrong,
      padding: const EdgeInsets.fromLTRB(23, 27, 23, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            child: Text(
              _emptyTitle,
              style: ShipItType.bodyCallout.copyWith(color: palette.inkPrimary),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Text(
                _emptyBody,
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _ReportBugLink(),
        ],
      ),
    );
  }
}

class _DesktopErrorPanel extends StatelessWidget {
  const _DesktopErrorPanel({this.since});

  /// `Err Since` — mono stamp beside the retry button. Absent when no read
  /// has succeeded yet, in which case there is nothing to date.
  final String? since;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.negative,
      padding: const EdgeInsets.fromLTRB(23, 27, 23, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            child: Text(
              _errorTitle,
              style: ShipItType.bodyCallout.copyWith(color: palette.inkPrimary),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Text(
                _errorBody,
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const _RetryButton(),
              if (since != null) ...[
                const SizedBox(width: 20),
                Text(
                  since!,
                  style: ShipItType.monoMeta.copyWith(
                    color: palette.inkTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.read<DefectListBloc>().add(DefectListRefreshed()),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 128,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: palette.controlBorder),
            borderRadius: BorderRadius.circular(ShipItMetrics.radius),
          ),
          alignment: Alignment.center,
          child: Text(
            'Try again',
            style: ShipItType.link.copyWith(color: palette.inkPrimary),
          ),
        ),
      ),
    );
  }
}

class _MobileEmptyPanel extends StatelessWidget {
  const _MobileEmptyPanel();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.ruleStrong,
      padding: const EdgeInsets.fromLTRB(13, 21, 13, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            child: Text(
              _emptyTitle,
              style: ShipItType.question.copyWith(color: palette.inkPrimary),
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 48,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 326),
              child: Text(
                _emptyBodyMobile,
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _ReportBugLink(),
        ],
      ),
    );
  }
}

class _MobileErrorPanel extends StatelessWidget {
  const _MobileErrorPanel();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DesignPanel(
      edgeColor: palette.negative,
      padding: const EdgeInsets.fromLTRB(13, 21, 13, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: Text(
              _errorTitle,
              style: ShipItType.question.copyWith(
                fontSize: 15,
                color: palette.inkPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 48,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 326),
              child: Text(
                _errorBody,
                style: ShipItType.bodySmall.copyWith(
                  color: palette.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const _MobileRetryButton(),
        ],
      ),
    );
  }
}

class _MobileRetryButton extends StatelessWidget {
  const _MobileRetryButton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.read<DefectListBloc>().add(DefectListRefreshed()),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 326,
          height: 34,
          color: palette.accent,
          alignment: Alignment.center,
          child: Text(
            'Try again',
            style: ShipItType.buttonLabelMobile.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// `Tech K` / `Tech 0…` — mono 9/600 label, then 16px-pitched mono lines.
class _TechLines extends StatelessWidget {
  const _TechLines({required this.lines, this.mobile = false});

  final List<String> lines;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 16,
          child: Text(
            'TECHNICAL DETAILS',
            style: ShipItType.microLabel.copyWith(color: palette.inkTertiary),
          ),
        ),
        const SizedBox(height: 2),
        for (final line in lines)
          SizedBox(
            height: mobile ? null : 16,
            child: Text(
              line,
              style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------- mobile

/// `Filter Ctrl` / `Product Ctrl` — a 4px-radius stroked box with a left inset
/// of 12, plus the right-aligned `Sort L`.
class _MobileControls extends StatelessWidget {
  const _MobileControls({
    required this.filterLabel,
    required this.onFilterTap,
    required this.productLabel,
    required this.products,
    required this.onProductChanged,
    this.boxWidth = 176,
    this.boxHeight = 30,
    this.labelStyle = ShipItType.link,
    this.sortStyle = ShipItType.link,
  });

  final String filterLabel;
  final VoidCallback onFilterTap;

  /// What the product control currently reads, e.g. `Product: All`.
  final String productLabel;

  final List<(String, String)> products;
  final ValueChanged<String> onProductChanged;

  final double boxWidth;
  final double boxHeight;
  final TextStyle labelStyle;
  final TextStyle sortStyle;

  /// The board types `▾` inside these labels; IBM Plex has no such glyph, so
  /// the marker is the app's drawn triangle in the label's own tone.
  Widget _label(
    ShipItPalette palette,
    String text,
    TextStyle style, {
    CaretDirection? caret,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: style.copyWith(color: color),
          ),
        ),
        if (caret != null) ...[
          const SizedBox(width: 4),
          DesignCaret(direction: caret, color: color),
        ],
      ],
    );
  }

  Future<void> _openProductMenu(
    BuildContext context,
    ShipItPalette palette,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final selected = await showMenu<String>(
      context: context,
      color: palette.card,
      position: RelativeRect.fromLTRB(
        0,
        (box?.size.height ?? 0) + 8,
        (box?.size.width ?? 0),
        -(box?.size.height ?? 0) - 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShipItMetrics.radius),
        side: BorderSide(color: palette.cardBorder),
      ),
      items: [
        for (final (id, name) in [('all', 'All products'), ...products])
          PopupMenuItem<String>(
            value: id == 'all' ? '' : id,
            child: Text(
              name,
              style: ShipItType.bodySmall.copyWith(color: palette.inkPrimary),
            ),
          ),
      ],
    );
    if (selected != null) onProductChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onFilterTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: boxWidth,
                  height: boxHeight,
                  padding: const EdgeInsets.only(left: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.controlBorder),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _label(
                    palette,
                    filterLabel,
                    labelStyle,
                    color: palette.inkPrimary,
                    caret: CaretDirection.down,
                  ),
                ),
              ),
            ),
            const Spacer(),
            _label(
              palette,
              _sortLabel,
              sortStyle,
              color: palette.accent,
              caret: CaretDirection.down,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: () => _openProductMenu(context, palette),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: boxWidth,
              height: boxHeight,
              padding: const EdgeInsets.only(left: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border.all(color: palette.controlBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _label(
                palette,
                productLabel,
                labelStyle,
                color: palette.inkPrimary,
                caret: CaretDirection.down,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `Row Title n` + `Row Ref / Row Sev / Row State n`, 52px pitch, with a
/// trailing `Row Go` chevron.
class _MobileDefectRow extends StatelessWidget {
  const _MobileDefectRow({
    required this.defect,
    required this.last,
    required this.onTap,
  });

  final DefectSummaryResponse defect;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = DefectStatus.fromWire(defect.status);
    final tone = DefectStatusBadge.listTone(status, palette);

    return Semantics(
      button: true,
      label: '${defect.title}, ${DefectStatusBadge.label(status)}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AccentTick(color: tone, height: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        defect.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShipItType.rowTitleMobile.copyWith(
                          color: palette.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(
                              defect.defectId,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: ShipItType.monoMeta.copyWith(
                                color: palette.inkTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 72,
                            child: Text(
                              _severityLabel(defect.severity),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ShipItType.status.copyWith(
                                color: _severityTone(defect.severity, palette),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              DefectStatusBadge.label(status),
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
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 12,
                    child: Text(
                      '›',
                      textAlign: TextAlign.right,
                      style: ShipItType.chevron.copyWith(color: palette.accent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ContentRule(),
            if (!last) const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }
}

class _MobileSkeletonRow extends StatelessWidget {
  const _MobileSkeletonRow({required this.index, required this.last});

  final int index;
  final bool last;

  static const _titleWidths = <double>[240, 200, 160, 240, 200, 160, 240];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = palette.rule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(width: 2, height: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _titleWidths[index % _titleWidths.length],
                    height: 12,
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(width: 88, height: 10, color: color),
                      const SizedBox(width: 8),
                      Container(width: 56, height: 10, color: color),
                      const SizedBox(width: 20),
                      Container(width: 100, height: 10, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const ContentRule(),
        if (!last) const SizedBox(height: 15),
      ],
    );
  }
}

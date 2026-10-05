import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/plain_language.dart';
import '../../data/client_provider.dart';
import '../../data/control_plane_repository.dart';
import '../defect_report/defect_list_bloc.dart';
import '../defect_report/defect_list_event.dart';
import '../defect_report/defect_list_page.dart';
import '../defect_report/defect_list_state.dart';
import 'feature_request_list_bloc.dart';
import 'feature_request_list_event.dart';
import 'feature_request_list_page.dart';
import 'feature_request_list_state.dart';
import 'reports_header.dart';
import 'reports_state.dart';

/// The Reports surface: one page, two registers.
///
/// `Defects` and `Feature requests` are tabs rather than separate destinations
/// because the fifth nav slot is `Reports` and a sixth would have to be either
/// hidden or redundant. Both registers are filed against the same products and
/// reviewed by the same people, so they belong in one place.
///
/// The tab lives in the URL (`?tab=`) rather than in local state, so a link to
/// a specific register survives a reload and can be pasted into a decision
/// record. Switching tabs does not reload the register being left, so coming
/// back to it does not re-read.
class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    this.initialTab,
    this.clock,
    this.repository,
    this.defectBloc,
    this.featureRequestBloc,
  });

  /// Which register to open on. Read from `?tab=` by the router; defaults to
  /// Defects.
  final ReportsTab? initialTab;

  /// Supplies "now" for freshness stamps. Injectable for deterministic goldens.
  final DateTime Function()? clock;

  /// Injectable for tests; falls back to the app-wide repository.
  final ControlPlaneRepository? repository;

  final DefectListBloc? defectBloc;
  final FeatureRequestListBloc? featureRequestBloc;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late ReportsTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ?? ReportsTab.defects;
  }

  @override
  void didUpdateWidget(covariant ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A deep link that lands on a different tab — the operator coming back
    // through history, say — has to move the surface with it.
    final next = widget.initialTab;
    if (next != null && next != oldWidget.initialTab && next != _tab) {
      _tab = next;
    }
  }

  void _selectTab(ReportsTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    // The tab is addressable, so the URL is the source of truth for which
    // register a link names. `replace` keeps it out of the back stack: moving
    // between registers is browsing, not a step forward.
    context.replace('/reports?tab=${tab.paramValue}');
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository ?? ClientProvider.repository;

    // Both registers are provided at all times, even though only one is on
    // screen: a `BlocProvider` disposes what it creates, so a tab built on
    // demand would drop the other register's rows and re-read them on the way
    // back. Providing both keeps a tab switch free.
    return MultiBlocProvider(
      providers: [
        if (widget.defectBloc == null)
          BlocProvider<DefectListBloc>(
            create: (_) =>
                DefectListBloc(repository: repository)..add(DefectListLoaded()),
          )
        else
          BlocProvider<DefectListBloc>.value(value: widget.defectBloc!),
        if (widget.featureRequestBloc == null)
          BlocProvider<FeatureRequestListBloc>(
            create: (_) =>
                FeatureRequestListBloc(repository: repository)
                  ..add(const FeatureRequestListRequested()),
          )
        else
          BlocProvider<FeatureRequestListBloc>.value(
            value: widget.featureRequestBloc!,
          ),
      ],
      child: Builder(
        builder: (context) => switch (_tab) {
          ReportsTab.defects => _DefectsRegister(
            bloc: context.read<DefectListBloc>(),
            clock: widget.clock,
            onTabSelected: _selectTab,
          ),
          ReportsTab.featureRequests => _FeatureRegister(
            bloc: context.read<FeatureRequestListBloc>(),
            clock: widget.clock,
            onTabSelected: _selectTab,
          ),
        },
      ),
    );
  }
}

/// The `Defects` tab. The header and tab row are supplied by this file so the
/// two registers cannot drift apart on where the underline sits.
class _DefectsRegister extends StatelessWidget {
  const _DefectsRegister({
    required this.bloc,
    required this.onTabSelected,
    this.clock,
  });

  final DefectListBloc bloc;
  final ValueChanged<ReportsTab> onTabSelected;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DefectListBloc, DefectListState>(
      builder: (context, state) => DefectListPage(
        bloc: bloc,
        clock: clock,
        header: ReportsHeader(
          tab: ReportsTab.defects,
          onTabSelected: onTabSelected,
          subtitle: _defectSubtitle(state),
          freshness: _defectFreshness(state, clock),
        ),
      ),
    );
  }
}

/// The `Feature requests` tab.
class _FeatureRegister extends StatelessWidget {
  const _FeatureRegister({
    required this.bloc,
    required this.onTabSelected,
    this.clock,
  });

  final FeatureRequestListBloc bloc;
  final ValueChanged<ReportsTab> onTabSelected;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureRequestListBloc, FeatureRequestListState>(
      builder: (context, state) => FeatureRequestListPage(
        bloc: bloc,
        clock: clock,
        header: ReportsHeader(
          tab: ReportsTab.featureRequests,
          onTabSelected: onTabSelected,
          subtitle: _featureSubtitle(state),
          freshness: _featureFreshness(state, clock),
        ),
      ),
    );
  }
}

String _defectSubtitle(DefectListState state) {
  if (state.isLoading && state.defects.isEmpty) {
    return 'Reading the system’s records…';
  }
  if (state.errorMessage != null && state.defects.isEmpty) {
    return 'The last reading failed.';
  }
  if (state.defects.isEmpty) return 'Nothing has been recorded yet.';
  return 'Reported issues awaiting triage, remediation, and verification';
}

String? _defectFreshness(DefectListState state, DateTime Function()? clock) {
  if (state.defects.isEmpty) return null;
  final now = (clock ?? DateTime.now)();
  return PlainLanguage.updatedAgo(
    now.difference(state.defects.first.updatedAt),
  );
}

String _featureSubtitle(FeatureRequestListState state) {
  if (state.isLoading && state.isEmpty) return 'Reading the system’s records…';
  if (state.isErrorScreen) return 'The last reading failed.';
  if (state.isEmpty) return 'Nothing has been recorded yet.';
  return 'Requests waiting on a product owner to review and prioritise';
}

String? _featureFreshness(
  FeatureRequestListState state,
  DateTime Function()? clock,
) {
  if (state.isEmpty) return null;
  final now = (clock ?? DateTime.now)();
  return PlainLanguage.updatedAgo(
    now.difference(state.requests.first.updatedAt),
  );
}

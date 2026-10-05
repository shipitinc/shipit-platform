import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/client_provider.dart';
import '../data/control_plane_repository.dart';
import 'mobile_chrome.dart';
import 'sidebar.dart';

/// Chrome around every screen.
///
/// On the desktop breakpoint this is the design's 200px rail plus the content
/// pane. Below it the rail collapses to a 56px brand bar over an 80px
/// bottom navigation bar, exactly as the `BPM ·` boards compose it.
///
/// Which of the two top bars shows is decided by the route: a *root* screen
/// (Overview, All work, Needs you, Products, Defects) carries the `Top Bg`
/// brand + LIVE bar, and a *child* screen carries the `Back` bar alone — the
/// design never stacks the two, and the back link is the only way home.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child, this.repository});

  final Widget child;

  /// Injectable for tests; falls back to the app-wide client.
  final ControlPlaneRepository? repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// The rail shows a count against "All work" and "Needs you" on every
  /// screen, so the shell owns that small read rather than each page pushing
  /// counts upward.
  int? _allWorkCount;
  int? _productCount;
  int? _needsYouCount;
  int? _reportsCount;

  /// Location the counts were last read for.
  String? _countsLocation;

  ControlPlaneRepository? _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ClientProvider.repository;
    _repository!.revision.addListener(_loadCounts);
    _loadCounts();
  }

  @override
  void dispose() {
    _repository?.revision.removeListener(_loadCounts);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Counts change as a side effect of what the operator does on the pages
    // (resolving a decision unblocks work), so re-read them whenever the
    // route changes rather than once at startup.
    final location = GoRouterState.of(context).uri.path;
    if (location != _countsLocation) {
      _countsLocation = location;
      _loadCounts();
    }
  }

  Future<void> _loadCounts() async {
    final repository = _repository ?? ClientProvider.repository;

    // Each count is read on its own so one unreachable register cannot take the
    // rest of the rail down with it. The two registers under Reports are read
    // separately for the same reason: a feature register that is not yet
    // deployed must not blank the count next to "All work".
    //
    // The two overview figures share one read — they are two fields of the same
    // document, not two documents.
    final overview = _overview(repository);
    final results = await Future.wait([
      _overviewCount(overview, (o) => o.running + o.waitingOnYou),
      _overviewCount(overview, (o) => o.waitingOnYou),
      _count(() => repository.listProductSummaries().then((p) => p.length)),
      // The rail's Reports count is the size of the surface the nav item
      // opens, not one register inside it: both the defect register and the
      // feature-request register are things filed under Reports, so a count
      // that named only the bugs would understate what is waiting.
      _count(() => repository.listDefects().then((d) => d.totalCount)),
      _count(() => repository.listFeatureRequests().then((f) => f.length)),
    ]);
    if (!mounted) return;
    setState(() {
      _allWorkCount = results[0];
      _needsYouCount = results[1];
      _productCount = results[2];
      // A null on either register leaves the Reports count unread rather than
      // reporting a total that silently omits one of its halves.
      _reportsCount = results[3] == null || results[4] == null
          ? null
          : results[3]! + results[4]!;
    });
  }

  /// The overview, fetched once and shared by both of its counts. A failed read
  /// resolves to null, which each dependent count reports as unknown rather
  /// than as zero.
  static Future<OverviewResponse?> _overview(
    ControlPlaneRepository repository,
  ) async {
    try {
      return await repository.getOverview();
    } on Object {
      return null;
    }
  }

  /// One figure derived from the shared overview read. A null overview yields
  /// null — the rail omits the number instead of claiming a zero.
  static Future<int?> _overviewCount(
    Future<OverviewResponse?> overview,
    int Function(OverviewResponse) derive,
  ) async {
    final o = await overview;
    return o == null ? null : derive(o);
  }

  /// A count, or null when that read failed. Null means "not known", which the
  /// rail renders by omitting the number rather than by showing a zero.
  static Future<int?> _count(Future<int> Function() read) async {
    try {
      return await read();
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return _mobileLayout(context);
        }
        return _desktopLayout(context);
      },
    );
  }

  Widget _desktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            allWorkCount: _allWorkCount,
            needsYouCount: _needsYouCount,
            productCount: _productCount,
            reportsCount: _reportsCount,
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    // Detail screens replace the brand bar with a back link, because on
    // mobile that link is the only way back to the list.
    final path = GoRouterState.of(context).uri.path;
    final detail = _detailParent(path);

    return Scaffold(
      body: Column(
        children: [
          if (detail == null)
            const MobileTopBar()
          else
            MobileBackBar(label: detail.$1, onTap: () => context.go(detail.$2)),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: MobileNavBar(needsYouCount: _needsYouCount),
    );
  }

  /// Label and destination for the back link, or null on a root screen.
  ///
  /// Every child screen links back to the root of its own surface — the board
  /// for a defect screen reads `‹  Defects`, which is the Defects root, not
  /// the page the operator came from.
  static (String, String)? _detailParent(String path) {
    if (RegExp(r'^/runs/.+').hasMatch(path)) return ('All work', '/runs');
    if (RegExp(r'^/needs-you/.+').hasMatch(path)) {
      return ('Needs you', '/needs-you');
    }
    if (RegExp(r'^/products/.+').hasMatch(path)) {
      return ('Products', '/products');
    }
    if (RegExp(r'^/reports/.+').hasMatch(path) ||
        RegExp(r'^/defects/.+').hasMatch(path)) {
      return ('Reports', '/reports');
    }
    if (RegExp(r'^/models/.+').hasMatch(path)) {
      return ('Models', '/models/policies');
    }
    return null;
  }
}

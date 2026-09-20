import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/client_provider.dart';
import '../data/control_plane_repository.dart';
import 'mobile_chrome.dart';
import 'sidebar.dart';

/// Chrome around every screen.
///
/// On the desktop breakpoint this is the design's 200px rail plus the content
/// pane. Below it, the rail collapses to a bottom bar — the design's `BPM ·`
/// mobile boards are a separate pass, so the existing bottom bar is retained
/// rather than guessed at.
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
    try {
      final repository = _repository ?? ClientProvider.repository;
      final overview = await repository.getOverview();
      // The rail's Products count is the registry size. Fetched alongside the
      // overview so a failure degrades the whole rail consistently rather
      // than leaving one count stale.
      final products = await repository.listProductSummaries();
      if (!mounted) return;
      setState(() {
        _allWorkCount = overview.running + overview.waitingOnYou;
        _needsYouCount = overview.waitingOnYou;
        _productCount = products.length;
      });
    } on Object {
      // The rail degrades to no counts; the page itself reports the failure.
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

  /// Label and destination for the back link, or null on a list screen.
  static (String, String)? _detailParent(String path) {
    if (RegExp(r'^/runs/.+').hasMatch(path)) return ('All work', '/runs');
    if (RegExp(r'^/needs-you/.+').hasMatch(path)) {
      return ('Needs you', '/needs-you');
    }
    return null;
  }
}

import 'dart:async';

import 'package:flutter/widgets.dart';

/// How often a live page re-reads its records.
///
/// Every root and detail screen that carries the `LIVE` stamp re-reads on this
/// interval, so the stamp stays honest instead of ageing behind the operator's
/// back. One constant so the cadence cannot drift between screens.
const Duration kLiveRefreshInterval = Duration(seconds: 30);

/// Re-runs [onRefresh] on a fixed interval for as long as it is mounted.
///
/// This is the single mechanism behind every `LIVE` screen. It is deliberately
/// dumb: it owns the timer and nothing else, and it never reads a bloc itself.
/// Each page supplies the reload its own bloc understands, so a screen whose
/// reload needs an argument (a product id, a run id) can still use it.
///
/// The timer is cancelled on [dispose], so leaving a screen stops its reads
/// immediately rather than leaving a background poll running against a bloc
/// that is being torn down.
class PeriodicRefresh extends StatefulWidget {
  const PeriodicRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.interval = kLiveRefreshInterval,
  });

  /// Called on every tick, with this widget's own [BuildContext].
  ///
  /// The context is the widget's, not the page's: [PeriodicRefresh] sits below
  /// the page's `BlocProvider`, so `context.read<SomeBloc>()` inside the
  /// callback resolves against the provider that owns the page's bloc. The
  /// first read is the page's own initial load, so nothing fires before the
  /// first [interval] has elapsed.
  final void Function(BuildContext context) onRefresh;

  /// The refresh cadence. Overridable so a test can drive it without waiting
  /// out the real interval.
  final Duration interval;

  final Widget child;

  @override
  State<PeriodicRefresh> createState() => _PeriodicRefreshState();
}

class _PeriodicRefreshState extends State<PeriodicRefresh> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant PeriodicRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (widget.interval <= Duration.zero) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      widget.onRefresh(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

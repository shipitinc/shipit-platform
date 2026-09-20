import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'router.dart';
import 'shared/sidebar.dart';

/// Application root.
///
/// The design defines both a light and a dark board for every screen, so the
/// platform preference decides by default ([ThemeMode.system]) and the
/// operator can override it from the rail.
class ShipItApp extends StatefulWidget {
  const ShipItApp({super.key, this.themeController});

  /// Injectable for tests; otherwise the app owns one.
  final ThemeController? themeController;

  @override
  State<ShipItApp> createState() => _ShipItAppState();
}

class _ShipItAppState extends State<ShipItApp> {
  late final ThemeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.themeController ?? ThemeController();
    // Fire-and-forget: the UI renders on the platform default until any stored
    // override arrives.
    _controller.load();
  }

  @override
  void dispose() {
    if (widget.themeController == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      notifier: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'ShipIt Control Plane',
            debugShowCheckedModeBanner: false,
            theme: ShipItTheme.light(),
            darkTheme: ShipItTheme.dark(),
            themeMode: _controller.mode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

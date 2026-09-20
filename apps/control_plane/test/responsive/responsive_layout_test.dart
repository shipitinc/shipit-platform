import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:control_plane/shared/app_shell.dart';
import 'package:control_plane/shared/mobile_chrome.dart';
import 'package:control_plane/shared/sidebar.dart';

void main() {
  Widget buildAppShell() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('home'))),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  group('Responsive Layout', () {
    testWidgets('shows the design rail at width >= 840', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildAppShell());
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsOneWidget);
    });

    testWidgets('shows the mobile nav bar at width < 840', (tester) async {
      tester.view.physicalSize = const Size(600, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildAppShell());
      await tester.pumpAndSettle();

      expect(find.byType(MobileNavBar), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);
    });

    testWidgets('sidebar and bottom bar are never visible simultaneously', (
      tester,
    ) async {
      // Test at desktop width
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildAppShell());
      await tester.pumpAndSettle();

      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byType(MobileNavBar), findsNothing);

      // Shrink to mobile width
      tester.view.physicalSize = const Size(600, 1024);
      await tester.pumpWidget(buildAppShell());
      await tester.pumpAndSettle();

      expect(find.byType(MobileNavBar), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);
    });
  });
}

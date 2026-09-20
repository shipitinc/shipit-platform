import 'package:control_plane/core/theme.dart';
import 'package:control_plane/shared/mobile_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The outstanding-decision badge must sit in the same place whether or not
/// "Needs you" is the current destination. Anchoring it inside a stack that
/// only gains the active pill when selected made it jump sideways on
/// selection.
void main() {
  Future<Rect> badgeRectAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: location,
      routes: [
        for (final path in const ['/', '/runs', '/needs-you'])
          GoRoute(
            path: path,
            builder: (context, state) => const Scaffold(
              body: SizedBox.shrink(),
              bottomNavigationBar: MobileNavBar(needsYouCount: 2),
            ),
          ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: ShipItTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    // The badge is the only Text showing the count inside the nav bar.
    final badge = find.descendant(
      of: find.byType(MobileNavBar),
      matching: find.text('2'),
    );
    expect(badge, findsOneWidget);

    final topLeft = tester.getTopLeft(badge);
    final size = tester.getSize(badge);
    return topLeft & size;
  }

  testWidgets('the badge does not move when Needs you is selected', (
    tester,
  ) async {
    final unselected = await badgeRectAt(tester, '/');
    final selected = await badgeRectAt(tester, '/needs-you');

    expect(selected, unselected);
  });

  testWidgets('the badge stays put across every destination', (tester) async {
    final onOverview = await badgeRectAt(tester, '/');
    final onAllWork = await badgeRectAt(tester, '/runs');
    final onNeedsYou = await badgeRectAt(tester, '/needs-you');

    expect(onAllWork, onOverview);
    expect(onNeedsYou, onOverview);
  });
}

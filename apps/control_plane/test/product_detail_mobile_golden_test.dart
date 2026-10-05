import 'dart:async';

import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/product_detail/product_detail_bloc.dart';
import 'package:control_plane/features/product_detail/product_detail_page.dart';
import 'package:control_plane/shared/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/app_fixtures.dart';
import 'helpers/design_fonts.dart';
import 'helpers/golden_tolerance.dart';

/// Renders Product Detail at the mobile board viewport so the golden covers the
/// Products back link in `MobileBackBar`.
///
/// This is a CANDIDATE for human review. No board reference is resolved in this
/// pass, so the golden records what the app renders and the human reviewer
/// decides whether that is right.
void main() {
  setUpAll(() async {
    await loadDesignFonts();
    useTolerantGoldens();
  });

  final asOf = DateTime(2026, 3, 1, 9, 0);

  CredentialResponse credential() => CredentialResponse(
    credentialId: 'cred-1',
    repositoryId: 'repo-1',
    referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
    fingerprint: 'SHA256:0Hq7…Kt4',
    algorithm: 'ed25519',
    status: 'verified',
    hostKeyStatus: 'confirmed',
    host: 'github.com',
    canReachRepository: true,
    lastVerifiedAt: asOf,
    lastVerifiedBy: 'operator',
    hostConfirmedAt: asOf,
    hostConfirmedBy: 'operator',
  );

  ProductDetailResponse detail() => ProductDetailResponse(
    productId: 'shipit',
    name: 'ShipIt Platform',
    description: 'The platform itself',
    state: 'governed',
    allowsDispatch: true,
    updatedAt: asOf,
    repositories: const [
      ProductRepositoryResponse(
        repositoryId: 'repo-1',
        uri: 'git@github.com:acme/shipit-platform.git',
        kind: 'monorepo',
        provider: 'github',
      ),
    ],
    credentials: [credential()],
    activeBaselineId: 'bl-shipit-7',
    activeBaselineRevision: 7,
    activeBaselineAcceptedAt: asOf,
    activeBaselineAcceptedBy: 'operator',
    activeBaselineFactCount: 12,
    pendingBaselineVerified: false,
    openClarifications: const [],
    policies: const [],
  );

  for (final themeMode in ['light', 'dark']) {
    final suffix = themeMode == 'light' ? '' : '_dark';
    testWidgets('Product detail · mobile back link to Products $themeMode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockRepository()..productDetail = detail();

      final bloc = ProductDetailBloc(repository: repo)
        ..add(const ProductDetailLoaded('shipit'));
      addTearDown(() => unawaited(bloc.close()));

      final router = GoRouter(
        initialLocation: '/products/shipit',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                AppShell(repository: repo, child: child),
            routes: [
              GoRoute(
                path: '/products/:productId',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: ProductDetailPage(productId: 'shipit', bloc: bloc),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: themeMode == 'light'
              ? ShipItTheme.light()
              : ShipItTheme.dark(),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();

      // Objective check: the back link the candidate is about must be present and
      // must name Products. The board draws it as one node — `‹` then two
      // spaces then the label (`BPM · …` `Back`).
      expect(find.text('‹  Products'), findsWidgets);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/product_detail_mobile_back_link$suffix.png'),
      );
    });
  }
}

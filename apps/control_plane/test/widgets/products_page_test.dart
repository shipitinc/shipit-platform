import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/products/products_bloc.dart';
import 'package:control_plane/features/products/products_page.dart';
import 'package:control_plane/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app_fixtures.dart';

ProductSummaryResponse _summary({
  String productId = 'shipit',
  String name = 'ShipIt Platform',
  String state = 'governed',
  bool allowsDispatch = true,
  String? activeBaselineId,
  int? activeBaselineRevision,
  String? pendingBaselineId,
  int? pendingBaselineRevision,
  bool pendingBaselineVerified = false,
  int factCount = 12,
  int repositoryCount = 1,
  int reachableRepositoryCount = 1,
}) => ProductSummaryResponse(
  productId: productId,
  name: name,
  state: state,
  allowsDispatch: allowsDispatch,
  activeBaselineId: activeBaselineId,
  activeBaselineRevision: activeBaselineRevision,
  pendingBaselineId: pendingBaselineId,
  pendingBaselineRevision: pendingBaselineRevision,
  pendingBaselineVerified: pendingBaselineVerified,
  baselineFactCount: factCount,
  openClarifications: 0,
  repositoryCount: repositoryCount,
  reachableRepositoryCount: reachableRepositoryCount,
  updatedAt: DateTime.utc(2026, 3, 1),
);

Future<void> _pump(
  WidgetTester tester,
  List<ProductSummaryResponse> products, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = MockRepository()..productSummaries = products;
  final bloc = ProductsBloc(repository: repo)..add(const ProductsLoaded());
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: ShipItTheme.light(),
      home: Scaffold(body: ProductsPage(bloc: bloc)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Products list reports durable state', () {
    testWidgets('a governed product names its accepted baseline', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(activeBaselineId: 'bl-shipit-7', activeBaselineRevision: 7),
      ]);
      // Named once in the table and once under Access.
      expect(find.text('ShipIt Platform'), findsNWidgets(2));
      expect(find.text('ref shipit'), findsOneWidget);
      expect(find.text('bl-shipit-7 · r7'), findsWidgets);
      expect(find.text('Governed · active'), findsOneWidget);
    });

    testWidgets('a product with no baseline says so rather than implying one', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(
          productId: 'partner',
          name: 'PartnerHub',
          state: 'registered',
          allowsDispatch: false,
          factCount: 0,
        ),
      ]);
      expect(find.text('none yet'), findsWidgets);
      expect(find.text('Registered'), findsOneWidget);
      // No fabricated count.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('a candidate under review is marked proposed, never agreed', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(
          productId: 'team',
          name: 'TeamHub',
          state: 'baseline_review',
          allowsDispatch: false,
          pendingBaselineId: 'bl-team-1',
          pendingBaselineRevision: 1,
          pendingBaselineVerified: true,
        ),
      ]);
      expect(find.text('bl-team-1 · r1 · proposed'), findsWidgets);
      expect(find.text('Needs your approval'), findsOneWidget);
    });

    testWidgets('an unverified candidate is called out as blocked', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(
          productId: 'team',
          name: 'TeamHub',
          state: 'baseline_review',
          allowsDispatch: false,
          pendingBaselineId: 'bl-team-1',
          pendingBaselineRevision: 1,
          pendingBaselineVerified: false,
        ),
      ]);
      // The gate cannot open without a worker attestation (AGENTS.md §12), so
      // the row says so instead of offering an action that would refuse.
      expect(
        find.text('bl-team-1 · r1 · proposed, not verified'),
        findsOneWidget,
      );
    });

    testWidgets('FACTS is labelled as claims, not files', (tester) async {
      await _pump(tester, [_summary(activeBaselineId: 'bl-shipit-7')]);
      expect(find.text('FACTS'), findsOneWidget);
      expect(find.text('FILES'), findsNothing);
    });
  });

  group('filters', () {
    testWidgets('archived products are hidden from the default view', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(activeBaselineId: 'bl-shipit-7'),
        _summary(
          productId: 'legacy',
          name: 'LegacyPortal',
          state: 'archived',
          allowsDispatch: false,
        ),
      ]);
      expect(find.text('LegacyPortal'), findsNothing);
      expect(find.text('1 product'), findsOneWidget);
    });

    testWidgets('the Archived filter reveals them', (tester) async {
      await _pump(tester, [
        _summary(activeBaselineId: 'bl-shipit-7'),
        _summary(
          productId: 'legacy',
          name: 'LegacyPortal',
          state: 'archived',
          allowsDispatch: false,
        ),
      ]);
      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      expect(find.text('LegacyPortal'), findsNWidgets(2));
      expect(find.text('ShipIt Platform'), findsNothing);
    });

    testWidgets('Needs you shows only products awaiting the operator', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(activeBaselineId: 'bl-shipit-7'),
        _summary(
          productId: 'team',
          name: 'TeamHub',
          state: 'baseline_review',
          allowsDispatch: false,
          pendingBaselineId: 'bl-team-1',
        ),
      ]);
      await tester.tap(find.text('Needs you'));
      await tester.pumpAndSettle();
      expect(find.text('TeamHub'), findsNWidgets(2));
      expect(find.text('ShipIt Platform'), findsNothing);
    });

    testWidgets('an empty filter explains itself', (tester) async {
      await _pump(tester, [_summary(activeBaselineId: 'bl-shipit-7')]);
      await tester.tap(find.text('Paused'));
      await tester.pumpAndSettle();
      expect(find.text('No product is paused.'), findsOneWidget);
    });
  });

  group('access', () {
    testWidgets('an unreachable repository is stated, not softened', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(
          productId: 'partner',
          name: 'PartnerHub',
          state: 'registered',
          allowsDispatch: false,
          repositoryCount: 1,
          reachableRepositoryCount: 0,
        ),
      ]);
      expect(find.text('not reachable'), findsOneWidget);
    });

    testWidgets('a product with no repository says none attributed', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(repositoryCount: 0, reachableRepositoryCount: 0),
      ]);
      expect(find.text('none attributed'), findsOneWidget);
      expect(find.text('no repository'), findsOneWidget);
    });

    testWidgets('partial reachability reports the real ratio', (tester) async {
      await _pump(tester, [
        _summary(repositoryCount: 3, reachableRepositoryCount: 2),
      ]);
      expect(find.text('2 of 3 reachable'), findsOneWidget);
    });
  });

  group('empty and mobile', () {
    testWidgets('an empty registry does not pretend otherwise', (tester) async {
      await _pump(tester, const []);
      expect(find.text('No products are registered yet.'), findsWidgets);
    });

    testWidgets('mobile stacks rows and keeps the status visible', (
      tester,
    ) async {
      await _pump(tester, [
        _summary(activeBaselineId: 'bl-shipit-7', activeBaselineRevision: 7),
      ], size: const Size(390, 844));
      expect(find.text('ShipIt Platform'), findsOneWidget);
      expect(find.text('Governed · active'), findsOneWidget);
      expect(find.textContaining('access:'), findsOneWidget);
    });
  });
}

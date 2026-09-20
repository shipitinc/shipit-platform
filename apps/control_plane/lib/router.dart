import 'package:go_router/go_router.dart';

import 'features/decision_detail/decision_detail_page.dart';
import 'features/home/home_page.dart';
import 'features/needs_you/needs_you_page.dart';
import 'features/product_detail/product_detail_page.dart';
import 'features/products/products_page.dart';
import 'features/run_detail/run_detail_page.dart';
import 'features/runs/runs_page.dart';
import 'shared/app_shell.dart';

/// Routes for the operator UI.
///
/// Every route uses [NoTransitionPage]. The default Material page transition
/// cross-fades, which composites the outgoing and incoming screens on top of
/// each other; against this design's flat surfaces the two sets of text and
/// rules visibly blend mid-animation. The screens share one persistent rail
/// and differ only in the content pane, so an instant, fully opaque swap is
/// both correct and what the design implies.
final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: '/runs',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: RunsPage()),
        ),
        GoRoute(
          path: '/runs/:runId',
          pageBuilder: (context, state) => NoTransitionPage(
            child: RunDetailPage(runId: state.pathParameters['runId']!),
          ),
        ),
        GoRoute(
          path: '/products',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProductsPage()),
        ),
        GoRoute(
          path: '/products/:productId',
          pageBuilder: (context, state) => NoTransitionPage(
            child: ProductDetailPage(
              productId: state.pathParameters['productId']!,
            ),
          ),
        ),
        GoRoute(
          path: '/needs-you',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: NeedsYouPage()),
        ),
        GoRoute(
          path: '/needs-you/:decisionId',
          pageBuilder: (context, state) => NoTransitionPage(
            child: DecisionDetailPage(
              decisionId: state.pathParameters['decisionId']!,
              workItemId: state.uri.queryParameters['wi'],
            ),
          ),
        ),
      ],
    ),
  ],
);

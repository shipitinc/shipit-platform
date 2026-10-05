import 'package:go_router/go_router.dart';

import 'features/decision_detail/decision_detail_page.dart';
import 'features/defect_report/create_defect_page.dart';
import 'features/defect_report/defect_detail_page.dart';
import 'features/home/home_page.dart';
import 'features/models/model_executions_page.dart';
import 'features/models/model_policies_page.dart';
import 'features/models/model_stats_page.dart';
import 'features/needs_you/needs_you_page.dart';
import 'features/product_detail/product_detail_page.dart';
import 'features/products/add_product_page.dart';
import 'features/products/products_page.dart';
import 'features/reports/create_feature_request_page.dart';
import 'features/reports/reports_page.dart';
import 'features/reports/reports_state.dart';
import 'features/runs/runs_page.dart';
import 'features/run_detail/run_detail_page.dart';
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
          path: '/products/new',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AddProductPage()),
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
        GoRoute(
          path: '/reports',
          pageBuilder: (context, state) => NoTransitionPage(
            // The register lives in the query string so a link to a specific
            // register survives a reload and can be pasted into a decision.
            // An unrecognised value falls back to Defects rather than failing.
            child: ReportsPage(
              initialTab: ReportsTab.fromParam(
                state.uri.queryParameters['tab'],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/reports/new-bug',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CreateDefectPage()),
        ),
        GoRoute(
          path: '/reports/new-feature',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CreateFeatureRequestPage()),
        ),
        GoRoute(
          path: '/reports/:defectId',
          pageBuilder: (context, state) => NoTransitionPage(
            child: DefectDetailPage(
              defectId: state.pathParameters['defectId']!,
            ),
          ),
        ),
        // Models section
        GoRoute(
          path: '/models/policies',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ModelPoliciesPage()),
        ),
        GoRoute(
          path: '/models/executions',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ModelExecutionsPage()),
        ),
        GoRoute(
          path: '/models/stats',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ModelStatsPage()),
        ),
        // Aliases for historical /defects deep-links. The register query is
        // carried across, so an old `?tab=` link still names the same register.
        GoRoute(
          path: '/defects',
          redirect: (context, state) {
            final tab = state.uri.queryParameters['tab'];
            return tab == null ? '/reports' : '/reports?tab=$tab';
          },
        ),
        GoRoute(
          path: '/defects/new',
          redirect: (context, state) => '/reports/new-bug',
        ),
        GoRoute(
          path: '/defects/:defectId',
          redirect: (context, state) =>
              '/reports/${state.pathParameters['defectId']}',
        ),
      ],
    ),
  ],
);

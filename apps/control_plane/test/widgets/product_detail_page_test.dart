import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/product_detail/product_detail_bloc.dart';
import 'package:control_plane/features/product_detail/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app_fixtures.dart';

CredentialResponse _credential({
  String status = 'verified',
  String hostKeyStatus = 'confirmed',
  bool canReach = true,
  String? failureReason,
}) => CredentialResponse(
  credentialId: 'cred-1',
  repositoryId: 'repo-1',
  referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
  fingerprint: 'SHA256:0Hq7…Kt4',
  algorithm: 'ed25519',
  status: status,
  hostKeyStatus: hostKeyStatus,
  host: 'github.com',
  canReachRepository: canReach,
  lastVerifiedAt: DateTime.utc(2026, 3, 1),
  lastVerifiedBy: 'operator',
  lastFailureReason: failureReason,
  hostConfirmedAt: DateTime.utc(2026, 3, 1),
  hostConfirmedBy: 'operator',
);

ProductDetailResponse _detail({
  String state = 'governed',
  bool allowsDispatch = true,
  String? activeBaselineId = 'bl-shipit-7',
  int? activeRevision = 7,
  String? pendingBaselineId,
  bool pendingVerified = false,
  List<CredentialResponse>? credentials,
  List<PolicyResponse> policies = const [],
  List<ClarificationSummary> clarifications = const [],
  bool withRepository = true,
}) => ProductDetailResponse(
  productId: 'shipit',
  name: 'ShipIt Platform',
  description: 'The platform itself',
  state: state,
  allowsDispatch: allowsDispatch,
  updatedAt: DateTime.utc(2026, 3, 1),
  repositories: withRepository
      ? const [
          ProductRepositoryResponse(
            repositoryId: 'repo-1',
            uri: 'git@github.com:acme/shipit-platform.git',
            kind: 'monorepo',
            provider: 'github',
          ),
        ]
      : const [],
  credentials: credentials ?? [if (withRepository) _credential()],
  activeBaselineId: activeBaselineId,
  activeBaselineRevision: activeRevision,
  activeBaselineHash: 'c98397cb',
  activeBaselineAcceptedAt: DateTime.utc(2026, 3, 1),
  activeBaselineAcceptedBy: 'operator',
  activeBaselineFactCount: 12,
  pendingBaselineId: pendingBaselineId,
  pendingBaselineRevision: pendingBaselineId == null ? null : 8,
  pendingBaselineVerified: pendingVerified,
  openClarifications: clarifications,
  policies: policies,
);

PolicyResponse _policy({bool revoked = false}) => PolicyResponse(
  policyId: 'pol-1',
  actions: const ['push', 'merge'],
  authorisingDecisionId: 'gd-p001',
  authorisedBy: 'operator',
  rationale: 'Approved 31 of 31 unchanged',
  authorisedAt: DateTime.utc(2026, 3, 1),
  isRevoked: revoked,
  revokedBy: revoked ? 'operator' : null,
  revocationReason: revoked ? 'revoked_by_human' : null,
);

Future<void> _pump(
  WidgetTester tester,
  ProductDetailResponse detail, {
  Size size = const Size(1400, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = MockRepository()..productDetail = detail;
  final bloc = ProductDetailBloc(repository: repo)
    ..add(const ProductDetailLoaded('shipit'));
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: ShipItTheme.light(),
      home: Scaffold(
        body: ProductDetailPage(productId: 'shipit', bloc: bloc),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('governance panel states what is true', () {
    testWidgets('a governed product names its baseline and key', (
      tester,
    ) async {
      await _pump(tester, _detail());
      expect(find.text('ShipIt Platform'), findsOneWidget);
      expect(find.text('GOVERNED · ACTIVE'), findsOneWidget);
      expect(find.textContaining('bl-shipit-7'), findsWidgets);
      expect(find.textContaining('SHA256:0Hq7…Kt4'), findsWidgets);
    });

    testWidgets('no standing policy says every push waits for you', (
      tester,
    ) async {
      await _pump(tester, _detail());
      expect(find.text('None — every push waits for you'), findsOneWidget);
    });

    testWidgets('a live policy cites the decision that authorised it', (
      tester,
    ) async {
      await _pump(tester, _detail(policies: [_policy()]));
      expect(find.textContaining('ref gd-p001'), findsOneWidget);
      expect(find.textContaining('authorised by operator'), findsOneWidget);
    });

    testWidgets('a revoked policy does not count as live', (tester) async {
      await _pump(tester, _detail(policies: [_policy(revoked: true)]));
      expect(find.text('None — every push waits for you'), findsOneWidget);
      expect(find.text('Revoke the standing policy'), findsNothing);
    });

    testWidgets('an ungoverned product cannot carry a policy', (tester) async {
      await _pump(
        tester,
        _detail(
          state: 'registered',
          allowsDispatch: false,
          activeBaselineId: null,
          activeRevision: null,
        ),
      );
      expect(
        find.text('None — available once this product is governed'),
        findsOneWidget,
      );
    });
  });

  group('actions reflect what the engine would allow', () {
    testWidgets('governed offers pause, not resume', (tester) async {
      await _pump(tester, _detail());
      expect(find.text('Pause work for this product'), findsOneWidget);
      expect(find.text('Resume work'), findsNothing);
      expect(find.text('Propose a new baseline'), findsOneWidget);
    });

    testWidgets('paused offers resume, not pause', (tester) async {
      await _pump(tester, _detail(state: 'paused', allowsDispatch: false));
      expect(find.text('Resume work'), findsOneWidget);
      expect(find.text('Pause work for this product'), findsNothing);
    });

    testWidgets('archived is terminal and offers nothing', (tester) async {
      await _pump(tester, _detail(state: 'archived', allowsDispatch: false));
      expect(find.text('Offboard this product'), findsNothing);
      expect(find.text('Resume work'), findsNothing);
      expect(
        find.textContaining('keep every decision, run and piece of evidence'),
        findsOneWidget,
      );
    });

    testWidgets('revoke appears only when a policy is live', (tester) async {
      await _pump(tester, _detail(policies: [_policy()]));
      expect(find.text('Revoke the standing policy'), findsOneWidget);
    });

    testWidgets('review is offered only with a pending baseline', (
      tester,
    ) async {
      await _pump(
        tester,
        _detail(
          state: 'baseline_review',
          allowsDispatch: false,
          activeBaselineId: null,
          activeRevision: null,
          pendingBaselineId: 'bl-shipit-8',
          pendingVerified: true,
        ),
      );
      expect(find.text('Review and approve the baseline'), findsOneWidget);
    });
  });

  group('access is reported honestly', () {
    testWidgets('a verified credential reads verified', (tester) async {
      await _pump(tester, _detail());
      expect(find.text('verified'), findsOneWidget);
    });

    testWidgets('an unconfirmed host blocks use and says so', (tester) async {
      await _pump(
        tester,
        _detail(
          credentials: [_credential(hostKeyStatus: 'unknown', canReach: false)],
        ),
      );
      expect(find.text('host not confirmed'), findsOneWidget);
    });

    testWidgets('a changed host key is called out, not softened', (
      tester,
    ) async {
      await _pump(
        tester,
        _detail(
          credentials: [_credential(hostKeyStatus: 'changed', canReach: false)],
        ),
      );
      expect(find.text('host key CHANGED'), findsOneWidget);
    });

    testWidgets('a failing credential surfaces the real reason', (
      tester,
    ) async {
      await _pump(
        tester,
        _detail(
          credentials: [
            _credential(
              status: 'failing',
              canReach: false,
              failureReason: 'permission denied (publickey)',
            ),
          ],
        ),
      );
      expect(find.text('permission denied (publickey)'), findsOneWidget);
    });

    testWidgets('a repository with no key says no key', (tester) async {
      await _pump(tester, _detail(credentials: const []));
      expect(find.text('no key'), findsOneWidget);
      expect(find.text('no key generated'), findsOneWidget);
    });

    testWidgets('no repository at all is stated plainly', (tester) async {
      await _pump(
        tester,
        _detail(withRepository: false, credentials: const []),
      );
      expect(
        find.text('No repository is attributed to this product.'),
        findsOneWidget,
      );
      expect(
        find.text('None — this product cannot be reached'),
        findsOneWidget,
      );
    });
  });

  group('baseline facts', () {
    testWidgets('no accepted baseline explains why nothing is governed', (
      tester,
    ) async {
      await _pump(
        tester,
        _detail(
          state: 'registered',
          allowsDispatch: false,
          activeBaselineId: null,
          activeRevision: null,
        ),
      );
      expect(
        find.text('None accepted — nothing is governed yet'),
        findsOneWidget,
      );
    });

    testWidgets('an unverified pending baseline says the gate cannot open', (
      tester,
    ) async {
      await _pump(
        tester,
        _detail(
          state: 'baseline_review',
          allowsDispatch: false,
          activeBaselineId: null,
          activeRevision: null,
          pendingBaselineId: 'bl-shipit-8',
        ),
      );
      expect(
        find.textContaining('NOT verified — the gate cannot open'),
        findsOneWidget,
      );
    });

    testWidgets('counts are labelled as facts, never files', (tester) async {
      await _pump(tester, _detail());
      expect(find.textContaining('12 recorded facts'), findsOneWidget);
      // No count may be presented as a file count — the registry never
      // measures files. The disclaimer text mentions the word deliberately.
      expect(find.textContaining(RegExp(r'\d+\s+files')), findsNothing);
    });
  });

  group('clarifications', () {
    testWidgets('an open question is surfaced with its section', (
      tester,
    ) async {
      await _pump(
        tester,
        _detail(
          state: 'baseline_blocked',
          allowsDispatch: false,
          clarifications: const [
            ClarificationSummary(
              clarificationId: 'clar-1',
              question: 'Which authentication provider does this use?',
              section: 'architecture',
            ),
          ],
        ),
      );
      expect(
        find.text('Which authentication provider does this use?'),
        findsOneWidget,
      );
      expect(find.text('architecture'), findsOneWidget);
    });
  });
}

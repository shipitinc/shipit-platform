import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/product_detail/product_detail_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app_fixtures.dart';

/// What the fake records when the operator resolves a baseline gate.
class _RecordedResolution {
  const _RecordedResolution({
    required this.decisionId,
    required this.choice,
    required this.decider,
    required this.rationale,
  });

  final String decisionId;
  final String choice;
  final String decider;
  final String rationale;
}

class _BaselineRepository extends MockRepository {
  _BaselineRepository({required this.detail});

  ProductDetailResponse detail;

  /// Resolution detail after a refetch, so the bloc can assert it re-read.
  ProductDetailResponse? detailAfterResolution;

  final List<_RecordedResolution> resolutions = [];
  Object? throwOnResolve;

  @override
  Future<ProductDetailResponse> getProductDetail(String productId) async =>
      detail;

  @override
  Future<DecisionResponse> resolveBaselineApproval({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    if (throwOnResolve != null) throw throwOnResolve!;
    resolutions.add(
      _RecordedResolution(
        decisionId: decisionId,
        choice: choice,
        decider: decider,
        rationale: rationale,
      ),
    );
    detail = detailAfterResolution ?? detail;
    return makeDecision(
      id: decisionId,
      workItemId: 'product-baseline:shipit',
      workItemTitle: 'Product Baseline Approval',
    );
  }
}

ProductDetailResponse _detail({
  String productId = 'shipit',
  String state = 'baseline_pending',
  String? pendingBaselineId = 'bl-shipit-3',
  bool verified = true,
  String? pendingDecisionId = 'blappr-bl-shipit-3',
  bool allowsDispatch = false,
}) => ProductDetailResponse(
  productId: productId,
  name: 'ShipIt',
  state: state,
  allowsDispatch: allowsDispatch,
  updatedAt: DateTime(2026, 10, 2, 14, 26),
  repositories: const [],
  credentials: const [],
  activeBaselineFactCount: 0,
  pendingBaselineId: pendingBaselineId,
  pendingBaselineRevision: 3,
  pendingBaselineVerified: verified,
  pendingBaselineDecisionId: pendingDecisionId,
  openClarifications: const [],
  policies: const [],
);

ProductDetailBloc _bloc(_BaselineRepository repository) =>
    ProductDetailBloc(repository: repository)
      ..add(const ProductDetailLoaded('shipit'));

void main() {
  group('baseline approval gate availability', () {
    /// Loads, then reports whether the gate is offered.
    Future<bool> gateOffered(_BaselineRepository repository) async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      final loaded = await bloc.stream
          .firstWhere((s) => s.detail != null)
          .timeout(const Duration(seconds: 5));
      return loaded.canApproveBaseline;
    }

    test('is offered only when a verified candidate has an open decision', () async {
      expect(await gateOffered(_BaselineRepository(detail: _detail())), isTrue);
    });

    test('is withheld when no worker attestation exists', () async {
      // AGENTS.md §12: the gate cannot open without independent verification.
      expect(
        await gateOffered(_BaselineRepository(detail: _detail(verified: false))),
        isFalse,
      );
    });

    test('is withheld when no decision is bound to the candidate', () async {
      // A verified baseline whose approval was never requested still has
      // nothing to resolve, so the action must not appear.
      expect(
        await gateOffered(
          _BaselineRepository(detail: _detail(pendingDecisionId: null)),
        ),
        isFalse,
      );
    });

    test('is withheld when there is no pending baseline at all', () async {
      expect(
        await gateOffered(
          _BaselineRepository(detail: _detail(pendingBaselineId: null)),
        ),
        isFalse,
      );
    });
  });

  group('resolving the gate', () {
    test('sends the bound decision id, the choice and the rationale', () async {
      final repository = _BaselineRepository(detail: _detail());
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.detail != null);
      bloc.add(
        const BaselineApprovalResolved(
          productId: 'shipit',
          choice: 'approve',
          rationale: 'Baseline matches how the platform actually behaves.',
        ),
      );
      await bloc.stream.firstWhere((s) => !s.isResolvingBaseline && s.detail != null)
          .timeout(const Duration(seconds: 5));

      expect(repository.resolutions, hasLength(1));
      final recorded = repository.resolutions.single;
      expect(recorded.decisionId, 'blappr-bl-shipit-3');
      expect(recorded.choice, 'approve');
      expect(
        recorded.rationale,
        'Baseline matches how the platform actually behaves.',
      );
    });

    test('re-reads durable state so acceptance is reflected', () async {
      // Approving moves the product to governed and clears the pending
      // baseline. The screen must show that, not a locally-assumed state.
      final governed = _detail(
        state: 'governed',
        pendingBaselineId: null,
        pendingDecisionId: null,
        allowsDispatch: true,
      );
      final repository = _BaselineRepository(detail: _detail())
        ..detailAfterResolution = governed;
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.detail != null);
      bloc.add(
        const BaselineApprovalResolved(
          productId: 'shipit',
          choice: 'approve',
          rationale: 'Accepted.',
        ),
      );
      final settled = await bloc.stream
          .firstWhere((s) => s.detail?.state == 'governed')
          .timeout(const Duration(seconds: 5));

      expect(settled.detail!.allowsDispatch, isTrue);
      expect(settled.canApproveBaseline, isFalse);
    });

    test('records a non-approving outcome without accepting', () async {
      final repository = _BaselineRepository(detail: _detail());
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.detail != null);
      bloc.add(
        const BaselineApprovalResolved(
          productId: 'shipit',
          choice: 'request_correction',
          rationale: 'Missing the deployment targets.',
        ),
      );
      await bloc.stream
          .firstWhere((s) => s.detail != null && !s.isResolvingBaseline)
          .timeout(const Duration(seconds: 5));

      expect(repository.resolutions.single.choice, 'request_correction');
      // Nothing was accepted, so the product still cannot dispatch.
      expect(repository.detail.allowsDispatch, isFalse);
    });

    test('refuses to resolve when no gate is open', () async {
      final repository = _BaselineRepository(
        detail: _detail(pendingDecisionId: null),
      );
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.detail != null);
      bloc.add(
        const BaselineApprovalResolved(
          productId: 'shipit',
          choice: 'approve',
          rationale: 'Should not reach the server.',
        ),
      );
      final failed = await bloc.stream
          .firstWhere((s) => s.errorMessage != null)
          .timeout(const Duration(seconds: 5));

      expect(repository.resolutions, isEmpty);
      expect(failed.errorMessage, contains('No baseline-approval gate is open'));
    });

    test('surfaces a server refusal instead of claiming approval', () async {
      final repository = _BaselineRepository(detail: _detail())
        ..throwOnResolve = StateError('baseline binding does not match');
      final bloc = _bloc(repository);
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((s) => s.detail != null);
      bloc.add(
        const BaselineApprovalResolved(
          productId: 'shipit',
          choice: 'approve',
          rationale: 'Accepted.',
        ),
      );
      final failed = await bloc.stream
          .firstWhere((s) => s.errorMessage != null)
          .timeout(const Duration(seconds: 5));

      expect(failed.errorMessage, contains('binding does not match'));
      expect(failed.isResolvingBaseline, isFalse);
    });
  });
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/product_language.dart';
import '../../data/control_plane_repository.dart';

sealed class ProductDetailEvent {
  const ProductDetailEvent();
}

class ProductDetailLoaded extends ProductDetailEvent {
  const ProductDetailLoaded(this.productId);

  final String productId;
}

/// The operator asked for a governance action.
///
/// Raising the gate is itself proposed (never performed invisibly): the
/// engine answers with the decision that must be resolved for the transition
/// to actually happen. [productId] is threaded through explicitly so the bloc
/// never guesses which product a caller meant.
class GovernanceActionRequested extends ProductDetailEvent {
  const GovernanceActionRequested(this.action, this.productId);

  final GovernanceAction action;
  final String productId;
}

class ProductDetailBloc extends Bloc<ProductDetailEvent, ProductDetailState> {
  ProductDetailBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const ProductDetailState()) {
    on<ProductDetailLoaded>(_onLoaded);
    on<GovernanceActionRequested>(_onGovernanceActionRequested);
  }

  final ControlPlaneRepository _repository;

  Future<void> _onGovernanceActionRequested(
    GovernanceActionRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(state.copyWith(isRaisingGate: true, clearError: true));
    try {
      final decision = switch (event.action) {
        // Baseline work is proposed by the operator; the gate opens on
        // review. These are the two durable lifecycle gates.
        GovernanceAction.proposeBaseline => _decisionFor(
          event.productId,
          await _gate(GovernanceAction.proposeBaseline, event.productId),
        ),
        GovernanceAction.reviewBaseline => _decisionFor(
          event.productId,
          await _gate(GovernanceAction.reviewBaseline, event.productId),
        ),
        _ => null,
      };
      emit(
        state.copyWith(
          isRaisingGate: false,
          pendingDecision: decision,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isRaisingGate: false,
          clearError: true,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// The gang of durable gate raises this screen understands.
  Future<DecisionResponse> _gate(GovernanceAction a, String productId) {
    final repository = _repository;
    return switch (a) {
      // These two are the baseline governance cycle. Every other action —
      // pause, resume, offboard, revocation — is a lifecycle decision.
      GovernanceAction.proposeBaseline ||
      GovernanceAction.reviewBaseline => repository.requestPolicyAuthorisation(
        productId: productId,
        actions: const ['propose', 'review'],
      ),
      GovernanceAction.pause => repository.requestLifecycleDecision(
        productId: productId,
        action: 'pause',
      ),
      GovernanceAction.resume => repository.requestLifecycleDecision(
        productId: productId,
        action: 'resume',
      ),
      GovernanceAction.offboard => repository.requestLifecycleDecision(
        productId: productId,
        action: 'offboard',
      ),
      GovernanceAction.revokePolicy =>
        throw UnimplementedError('revocation needs productId + policyId'),
    };
  }

  Future<void> _onLoaded(
    ProductDetailLoaded event,
    Emitter<ProductDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final detail = await _repository.getProductDetail(event.productId);
      emit(ProductDetailState(isLoading: false, detail: detail));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}

class ProductDetailState {
  const ProductDetailState({
    this.isLoading = false,
    this.detail,
    this.errorMessage,
    this.isRaisingGate = false,
    this.pendingDecision,
  });

  final bool isLoading;
  final ProductDetailResponse? detail;
  final String? errorMessage;

  /// Non-null only while a governance gate the operator raised is waiting
  /// for its durable decision. The UI routes to the needs-you surface with
  /// this id.
  final bool isRaisingGate;

  /// The decision the operator must resolve after raising a gate.
  final DecisionResponse? pendingDecision;

  ProductStatus get status => detail == null
      ? ProductStatus.unknown
      : ProductLanguage.statusFor(detail!.state);

  ProductDetailState copyWith({
    bool? isLoading,
    ProductDetailResponse? detail,
    String? errorMessage,
    bool? isRaisingGate,
    DecisionResponse? pendingDecision,
    bool clearError = false,
  }) => ProductDetailState(
    isLoading: isLoading ?? this.isLoading,
    detail: detail ?? this.detail,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    isRaisingGate: isRaisingGate ?? this.isRaisingGate,
    pendingDecision: pendingDecision ?? this.pendingDecision,
  );
}

  DecisionResponse _decisionFor(
    String productId,
    DecisionResponse decision,
  ) => decision;

/// Governance actions the screen offers.
///
/// Availability is derived from durable state rather than always shown and
/// then refused: an action that cannot succeed is not presented as if it
/// could.
enum GovernanceAction {
  proposeBaseline('Propose a new baseline'),
  reviewBaseline('Review and approve the baseline'),
  pause('Pause work for this product'),
  resume('Resume work'),
  offboard('Offboard this product'),
  revokePolicy('Revoke the standing policy');

  const GovernanceAction(this.label);

  final String label;

  /// Which actions make sense for [status], given whether a policy is live.
  static List<GovernanceAction> availableFor(
    ProductStatus status, {
    required bool hasLivePolicy,
    required bool hasPendingBaseline,
  }) => switch (status) {
    ProductStatus.governed => [
      GovernanceAction.proposeBaseline,
      GovernanceAction.pause,
      GovernanceAction.offboard,
      if (hasLivePolicy) GovernanceAction.revokePolicy,
    ],
    ProductStatus.paused => [
      GovernanceAction.resume,
      GovernanceAction.offboard,
      if (hasLivePolicy) GovernanceAction.revokePolicy,
    ],
    ProductStatus.baselineReview => [
      if (hasPendingBaseline) GovernanceAction.reviewBaseline,
      GovernanceAction.offboard,
    ],
    ProductStatus.registered ||
    ProductStatus.baselinePending ||
    ProductStatus.baselineBlocked => [GovernanceAction.offboard],
    // Archived is terminal, and an unrecognised state gets no actions rather
    // than a guess.
    ProductStatus.archived || ProductStatus.unknown => const [],
  };
}

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

/// The operator dismissed the in-place refusal message.
///
/// This only clears the message. It deliberately does not re-run the action
/// that was refused: dismissing a refusal is not consent to press the button
/// again.
class GovernanceErrorDismissed extends ProductDetailEvent {
  const GovernanceErrorDismissed();
}

/// The operator asked for a governance action.
///
/// Raising the gate is itself proposed (never performed invisibly): the engine
/// answers with the decision that must be resolved for the transition to
/// actually happen. [productId] is threaded through explicitly so the bloc
/// never guesses which product a caller meant.
class GovernanceActionRequested extends ProductDetailEvent {
  const GovernanceActionRequested(this.action, this.productId);

  final GovernanceAction action;
  final String productId;
}

/// The operator resolved the pending baseline-approval gate.
///
/// [choice] is the wire value of a `HumanDecisionChoice` — 'approve',
/// 'rework' (the engine's "send it back" choice, `requestCorrectionOptionId`)
/// or 'reject'. It is deliberately NOT the human phrase 'request_correction':
/// `HumanDecisionChoice.fromWire` knows no such value and throws
/// `FormatException`, which used to make that button a guaranteed 500.
/// [rationale] is the operator's own words: the click is the human act, and
/// the decision must record why (AGENTS.md §11).
class BaselineApprovalResolved extends ProductDetailEvent {
  const BaselineApprovalResolved({
    required this.productId,
    required this.choice,
    required this.rationale,
  });

  final String productId;
  final String choice;
  final String rationale;
}

/// The operator resolved a lifecycle gate this product has open.
///
/// Lifecycle decisions hang off the synthetic scope
/// `product-lifecycle:<productId>`, which is not a WorkItem row, so they are
/// resolved here and never routed to the needs-you decision surface.
///
/// [choice] is 'approve' (the transition happens) or 'reject' (the decision is
/// recorded, nothing changes).
///
/// [attestsNoWorkInFlight] is the operator's own statement, not a client
/// inference. `(governed|paused) -> archived` requires
/// `ProductGuard.noWorkInFlight`, and the engine trusts the guard set it is
/// handed rather than checking it — so the only honest way to satisfy it is for
/// a person to say it out loud, here, in the same act as the rationale.
class LifecycleDecisionResolved extends ProductDetailEvent {
  const LifecycleDecisionResolved({
    required this.productId,
    required this.decisionId,
    required this.choice,
    required this.rationale,
    this.attestsNoWorkInFlight = false,
  });

  final String productId;
  final String decisionId;
  final String choice;
  final String rationale;
  final bool attestsNoWorkInFlight;
}

class ProductDetailBloc extends Bloc<ProductDetailEvent, ProductDetailState> {
  ProductDetailBloc({required this._repository})
    : super(const ProductDetailState()) {
    on<ProductDetailLoaded>(_onLoaded);
    on<GovernanceErrorDismissed>(_onGovernanceErrorDismissed);
    on<GovernanceActionRequested>(_onGovernanceActionRequested);
    on<BaselineApprovalResolved>(_onBaselineApprovalResolved);
    on<LifecycleDecisionResolved>(_onLifecycleDecisionResolved);
  }

  final ControlPlaneRepository _repository;

  void _onGovernanceErrorDismissed(
    GovernanceErrorDismissed event,
    Emitter<ProductDetailState> emit,
  ) {
    emit(state.copyWith(clearGovernanceError: true));
  }

  /// Every action the panel offers performs a real server call, and the
  /// outcome — including a refusal — is what the screen then shows.
  Future<void> _onGovernanceActionRequested(
    GovernanceActionRequested event,
    Emitter<ProductDetailState> emit,
  ) async {
    // A double tap must not fire two durable writes. `isRaisingGate` is the
    // honest affordance for that, so it is enforced here as well as rendered.
    if (state.isRaisingGate) return;
    emit(state.copyWith(isRaisingGate: true, clearGovernanceError: true));
    try {
      switch (event.action) {
        // Baseline work is proposed by a worker or the onboarding CLI, not by
        // this screen: the engine refuses an empty baseline and then refuses to
        // open an approval gate on one no worker has independently verified.
        // The call is still made and its real refusal is shown in place.
        case GovernanceAction.proposeBaseline:
          await _repository.proposeBaseline(
            productId: event.productId,
            facts: const [], // TODO: collect baseline facts from UI
          );
        // Requests the durable approval gate for the current candidate and
        // moves the product into `baselineReview`.
        case GovernanceAction.reviewBaseline:
          await _repository.requestBaselineApproval(
            productId: event.productId,
            baselineId: _pendingBaselineId(event.productId),
          );
        // The lifecycle gates. Each raises a `blocking: true` decision bound to
        // the scope `product-lifecycle:<productId>`.
        //
        // The response is deliberately NOT kept. The gate is re-read from
        // durable state on the load below, so what the screen shows is what the
        // registry holds — not what this one screen remembers having asked for.
        case GovernanceAction.pause:
        case GovernanceAction.resume:
        case GovernanceAction.offboard:
          await _repository.requestLifecycleDecision(
            productId: event.productId,
            // Non-null for exactly these three arms; the switch is the proof,
            // so the assertion is a type-narrowing cast, not a guess.
            action: event.action.lifecycleWire!,
          );
          final detail = await _repository.getProductDetail(event.productId);
          emit(ProductDetailState(isLoading: false, detail: detail));
          return;
        // Revocation is an attributed write, not a decision gate, so it never
        // goes through a switch arm that raises a HumanDecision.
        case GovernanceAction.revokePolicy:
          await _repository.revokeStandingPolicy(
            productId: event.productId,
            policyId: _livePolicyId(event.productId),
            revokedBy: 'operator',
          );
      }
      // Baseline and policy actions do not change state directly: they change
      // it by leaving a durable decision or revocation behind. Re-read so the
      // panel shows what the registry now holds rather than what was assumed.
      final detail = await _repository.getProductDetail(event.productId);
      emit(ProductDetailState(isLoading: false, detail: detail));
    } catch (e) {
      // Deliberately NOT the page-level `errorMessage`. That field means "we
      // could not read the registry" and renders as a whole-page takeover whose
      // copy ("No decision was recorded and no work was started") describes the
      // opposite of a refusal. A refusal belongs beside the action that caused
      // it, inside the Governance panel.
      emit(state.copyWith(isRaisingGate: false, governanceError: e.toString()));
    }
  }

  Future<void> _onLifecycleDecisionResolved(
    LifecycleDecisionResolved event,
    Emitter<ProductDetailState> emit,
  ) async {
    final gate = state.openLifecycleGate;
    if (gate == null || gate.decisionId != event.decisionId) {
      emit(
        state.copyWith(
          governanceError:
              'No lifecycle gate is open for ${event.productId} to resolve.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(isResolvingLifecycle: true, clearGovernanceError: true),
    );
    try {
      await _repository.resolveLifecycleDecision(
        decisionId: event.decisionId,
        choice: event.choice,
        decider: 'operator',
        rationale: event.rationale,
        noWorkInFlight: event.attestsNoWorkInFlight,
      );
      // The transition happened server-side (or deliberately did not). Re-read
      // rather than assume, exactly as the baseline gate does.
      final detail = await _repository.getProductDetail(event.productId);
      emit(ProductDetailState(isLoading: false, detail: detail));
    } catch (e) {
      emit(
        state.copyWith(
          isResolvingLifecycle: false,
          governanceError: e.toString(),
        ),
      );
    }
  }

  Future<void> _onBaselineApprovalResolved(
    BaselineApprovalResolved event,
    Emitter<ProductDetailState> emit,
  ) async {
    final decisionId = state.detail?.pendingBaselineDecisionId;
    if (decisionId == null) {
      emit(
        state.copyWith(
          errorMessage:
              'No baseline-approval gate is open for ${event.productId}.',
        ),
      );
      return;
    }
    emit(state.copyWith(isResolvingBaseline: true, clearError: true));
    try {
      await _repository.resolveBaselineApproval(
        decisionId: decisionId,
        choice: event.choice,
        decider: 'operator',
        rationale: event.rationale,
      );
      // Re-read durable state: acceptance moves the product to `governed` and
      // clears the pending baseline, so the screen reflects the registry
      // rather than assuming the transition succeeded.
      final detail = await _repository.getProductDetail(event.productId);
      emit(ProductDetailState(isLoading: false, detail: detail));
    } catch (e) {
      emit(
        state.copyWith(isResolvingBaseline: false, errorMessage: e.toString()),
      );
    }
  }

  /// Returns the pending baseline ID for the product, if any.
  /// Used by reviewBaseline to request approval for the correct baseline.
  String _pendingBaselineId(String productId) {
    // Read from durable state. Baseline ids are minted by the registry as
    // `bl-<productId>-<revision>`, so a synthesised id would either miss or,
    // worse, address some other revision's baseline.
    final id = state.detail?.pendingBaselineId;
    if (id == null || id.isEmpty) {
      throw StateError(
        'No pending baseline for $productId; nothing to review.',
      );
    }
    return id;
  }

  /// The policy to revoke: the live one. Revocation names a specific policy, so
  /// it is read from the registry rather than guessed at.
  String _livePolicyId(String productId) {
    final id = state.detail?.policies
        .where((p) => !p.isRevoked)
        .firstOrNull
        ?.policyId;
    if (id == null || id.isEmpty) {
      throw StateError(
        'No standing policy is live for $productId; there is nothing to revoke.',
      );
    }
    return id;
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
    this.isResolvingBaseline = false,
    this.isResolvingLifecycle = false,
    this.governanceError,
  });

  final bool isLoading;
  final ProductDetailResponse? detail;

  /// The registry could not be read. Rendered as a whole-page failure, because
  /// that is what it means. Action failures use [governanceError] instead.
  final String? errorMessage;

  /// True while a governance action's server call is in flight. Actions are
  /// disabled while it holds, so a double tap cannot fire two durable writes.
  final bool isRaisingGate;

  /// True while a baseline-approval resolution is in flight.
  final bool isResolvingBaseline;

  /// True while a lifecycle resolution is in flight.
  final bool isResolvingLifecycle;

  /// An action-scoped failure, shown inside the Governance panel next to the
  /// actions that caused it. Carries the server's own reason verbatim.
  final String? governanceError;

  /// The lifecycle gate that is open RIGHT NOW, or null.
  ///
  /// Derived from durable state on every load rather than held as a field set by
  /// the raise call, and that is the entire point. A lifecycle decision hangs
  /// off the synthetic scope `product-lifecycle:<productId>`, not a WorkItem row,
  /// so no listing surface can find it: if the screen only remembers the gate it
  /// just raised, leaving the route erases it, and the `blocking: true`
  /// decision it stands for is then left with nothing able to raise it again,
  /// list it, or resolve it. `_baselineGate` has always been driven this way.
  LifecycleGateResponse? get openLifecycleGate => detail?.pendingLifecycleGate;

  /// Whether a lifecycle gate is open. Durable, not a memory of a call.
  bool get lifecycleGateOpen => openLifecycleGate != null;

  ProductStatus get status => detail == null
      ? ProductStatus.unknown
      : ProductLanguage.statusFor(detail!.state);

  /// Whether the operator can resolve a baseline-approval gate right now.
  ///
  /// All three conditions are durable: the candidate exists, a worker attested
  /// to it (AGENTS.md §12), and an unresolved decision is bound to it. The
  /// action is hidden rather than offered-and-refused when any is missing.
  bool get canApproveBaseline {
    final d = detail;
    if (d == null) return false;
    return d.pendingBaselineId != null &&
        d.pendingBaselineVerified &&
        d.pendingBaselineDecisionId != null;
  }

  /// Whether the offboard guard applies to the gate now open.
  ///
  /// `(governed|paused) -> archived` requires `noWorkInFlight`;
  /// `(registered|baselineBlocked) -> archived` deliberately waives it, because
  /// there is nothing running to strand. Asking a person to attest in the
  /// second case would be a gate on an irreversible action with no work at
  /// stake, which is exactly what the recorded decision of 2026-10-09 says not
  /// to do.
  ///
  /// Read from the gate's own durable action, not from what this screen last
  /// tapped. That matters in both directions: an operator returning to a screen
  /// with an open offboard gate must still be asked to state it (otherwise the
  /// guard is satisfied by nobody saying it), and an operator returning to an
  /// open pause gate must not be asked to attest about work that is not being
  /// archived.
  bool get lifecycleOffboardNeedsWorkInFlightAssertion =>
      openLifecycleGate?.action == GovernanceAction.offboard.lifecycleWire &&
      (status == ProductStatus.governed || status == ProductStatus.paused);

  ProductDetailState copyWith({
    bool? isLoading,
    ProductDetailResponse? detail,
    String? errorMessage,
    bool? isRaisingGate,
    bool? isResolvingBaseline,
    bool? isResolvingLifecycle,
    String? governanceError,
    bool clearError = false,
    bool clearGovernanceError = false,
  }) => ProductDetailState(
    isLoading: isLoading ?? this.isLoading,
    detail: detail ?? this.detail,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    isRaisingGate: isRaisingGate ?? this.isRaisingGate,
    isResolvingBaseline: isResolvingBaseline ?? this.isResolvingBaseline,
    isResolvingLifecycle: isResolvingLifecycle ?? this.isResolvingLifecycle,
    governanceError: clearGovernanceError
        ? null
        : (governanceError ?? this.governanceError),
  );
}

/// Governance actions the screen offers.
///
/// Availability is derived from durable state rather than always shown and
/// then refused: an action that cannot succeed is not presented as if it
/// could.
///
/// Every entry below was checked against `ProductTransitions`, not assumed:
///
/// * `offboard` is legal from `governed`, `paused`, `registered` and
///   `baselineBlocked` only. `baselinePending -> archived` and
///   `baselineReview -> archived` are NOT edges, so those two states are
///   offered nothing rather than a refusal.
/// * `reviewBaseline` moves `baselinePending -> baselineReview`, which the
///   engine refuses unless the candidate is independently verified
///   (`BaselineNotVerifiedException`). It is offered only when a worker has
///   attested, which is the one reachable way to open a baseline gate from the
///   UI.
/// * `proposeBaseline` is offered for `governed` because the engine supports
///   re-baselining, but it cannot succeed from this screen: the client has no
///   baseline facts to propose, `EmptyBaselineException` refuses the empty set,
///   and the approval half refuses anything no worker verified. The action is
///   kept because the capability is real and the refusal is now reported in
///   place rather than swallowed; collecting baseline facts is its own piece of
///   work.
enum GovernanceAction {
  proposeBaseline('Propose a new baseline'),
  reviewBaseline('Review and approve the baseline'),
  pause('Pause work for this product'),
  resume('Resume work'),
  offboard('Offboard this product'),
  revokePolicy('Revoke the standing policy');

  const GovernanceAction(this.label);

  final String label;

  /// The `ProductLifecycleAction` wire value for the three lifecycle actions,
  /// or null for the rest. Held here rather than derived from [name] so a
  /// rename cannot silently stop matching the server's `fromWire`.
  String? get lifecycleWire => switch (this) {
    GovernanceAction.pause => 'pause',
    GovernanceAction.resume => 'resume',
    GovernanceAction.offboard => 'offboard',
    _ => null,
  };

  /// Which actions make sense for [status], given whether a policy is live and
  /// whether a worker has independently verified the pending baseline.
  static List<GovernanceAction> availableFor(
    ProductStatus status, {
    required bool hasLivePolicy,
    required bool hasVerifiedPendingBaseline,
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
    // Both states can only reach `baselineReview` through this one edge, and
    // the engine requires the candidate to be independently verified first.
    ProductStatus.baselineReview || ProductStatus.baselinePending => [
      if (hasVerifiedPendingBaseline) GovernanceAction.reviewBaseline,
    ],
    // Onboarding abandoned before anything was governed. The transition table
    // waives `noWorkInFlight` here, so there is nothing running to strand.
    ProductStatus.registered ||
    ProductStatus.baselineBlocked => [GovernanceAction.offboard],
    // Archived is terminal, and an unrecognised state gets no actions rather
    // than a guess.
    ProductStatus.archived || ProductStatus.unknown => const [],
  };
}

import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// A product lifecycle action that requires a durable human decision.
///
/// Each action names exactly one target [ProductState] and the guard the
/// resolved decision establishes. The mapping lives here so no caller can
/// invent a transition the table does not allow.
enum ProductLifecycleAction {
  /// Stop dispatching new work. Reversible; the baseline is untouched.
  pause('pause', ProductState.paused, ProductGuard.pauseDecisionRecorded),

  /// Resume dispatch for a paused product.
  resume('resume', ProductState.governed, ProductGuard.resumeDecisionRecorded),

  /// Archive the product. Never a delete.
  offboard(
    'offboard',
    ProductState.archived,
    ProductGuard.offboardDecisionRecorded,
  ),

  /// Bring an archived product back — through a fresh baseline review, not
  /// straight to governed.
  reinstate(
    'reinstate',
    ProductState.baselineReview,
    ProductGuard.reinstateDecisionRecorded,
  );

  const ProductLifecycleAction(this.wire, this.target, this.guard);

  final String wire;

  /// The [ProductState] a successful decision moves the product to.
  final ProductState target;

  /// The guard that the resolved, signed decision establishes.
  final ProductGuard guard;

  static ProductLifecycleAction fromWire(String value) => values.firstWhere(
    (a) => a.wire == value,
    orElse: () =>
        throw FormatException('Unknown product lifecycle action: $value'),
  );
}

/// What a product lifecycle decision authorises, recorded in
/// [HumanDecision.metadata].
///
/// Mirrors `BaselineApprovalBinding`: the authorisation is re-checked against
/// live state at resolution time, so a decision cannot be replayed against a
/// product it was not written for.
@immutable
class LifecycleDecisionBinding {
  const LifecycleDecisionBinding({
    required this.productId,
    required this.action,
    required this.fromState,
    this.drainInFlight = true,
  });

  final String productId;
  final ProductLifecycleAction action;

  /// The state the product was in when the decision was raised. If it has
  /// moved since, the decision is stale and must fail closed.
  final ProductState fromState;

  /// Whether work already running is allowed to finish.
  ///
  /// `true` drains (nothing new starts, in-flight completes); `false` halts
  /// immediately. Recorded on the decision so the durable record says which
  /// the human actually chose, rather than leaving it implied.
  final bool drainInFlight;

  static const String routingValue = 'product_lifecycle_decision';

  static const String _routingKey = 'routing';
  static const String _productIdKey = 'productId';
  static const String _actionKey = 'action';
  static const String _fromStateKey = 'fromState';
  static const String _drainKey = 'drainInFlight';

  /// Deterministic owning scope recorded in `HumanDecision.workItemId`.
  static String scopeFor(String productId) => 'product-lifecycle:$productId';

  Map<String, dynamic> toMetadata() => <String, dynamic>{
    _routingKey: routingValue,
    _productIdKey: productId,
    _actionKey: action.wire,
    _fromStateKey: fromState.wire,
    _drainKey: drainInFlight,
  };

  /// Parses a binding from decision metadata, or null when the metadata is not
  /// a product lifecycle binding.
  static LifecycleDecisionBinding? tryFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return null;
    if (metadata[_routingKey] != routingValue) return null;
    final productId = metadata[_productIdKey];
    final action = metadata[_actionKey];
    final fromState = metadata[_fromStateKey];
    if (productId is! String || action is! String || fromState is! String) {
      return null;
    }
    return LifecycleDecisionBinding(
      productId: productId,
      action: ProductLifecycleAction.fromWire(action),
      fromState: ProductState.fromWire(fromState),
      drainInFlight: metadata[_drainKey] as bool? ?? true,
    );
  }

  bool matches({required String productId, required ProductState fromState}) =>
      this.productId == productId && this.fromState == fromState.canonical;
}

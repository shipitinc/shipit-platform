/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'decision_context_view.dart' as _i2;
import 'decision_option_view.dart' as _i3;
import 'package:control_plane_server/src/generated/protocol.dart' as _i4;

/// The unresolved lifecycle human gate for a product, when one is open.
///
/// A lifecycle decision hangs off the synthetic scope
/// `product-lifecycle:<productId>` rather than a WorkItem row, so no listing
/// endpoint can discover one: `pendingDecisions()` and `recentDecisions()`
/// enumerate WorkItems, and a synthetic scope is not one. This read is
/// therefore the ONLY place the product detail screen can learn that a gate it
/// raised earlier is still open — and without it the gate is invisible the
/// moment the operator leaves the route, which strands a `blocking: true`
/// decision that nothing is then able to resolve.
///
/// The whole decision is carried rather than just its id, so the screen can
/// re-render the full gate on return — the question, the engine-declared
/// outcomes, the blocking flag — without a second endpoint. Every field is
/// read from the durable decision record, never from the response of the call
/// that raised it.
abstract class ProductLifecycleGateView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ProductLifecycleGateView._({
    required this.decisionId,
    required this.action,
    required this.status,
    this.question,
    this.context,
    this.options,
    required this.blocking,
    this.requestedAt,
  });

  factory ProductLifecycleGateView({
    required String decisionId,
    required String action,
    required String status,
    String? question,
    _i2.DecisionContextView? context,
    List<_i3.DecisionOptionView>? options,
    required bool blocking,
    DateTime? requestedAt,
  }) = _ProductLifecycleGateViewImpl;

  factory ProductLifecycleGateView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ProductLifecycleGateView(
      decisionId: jsonSerialization['decisionId'] as String,
      action: jsonSerialization['action'] as String,
      status: jsonSerialization['status'] as String,
      question: jsonSerialization['question'] as String?,
      context: jsonSerialization['context'] == null
          ? null
          : _i4.Protocol().deserialize<_i2.DecisionContextView>(
              jsonSerialization['context'],
            ),
      options: jsonSerialization['options'] == null
          ? null
          : _i4.Protocol().deserialize<List<_i3.DecisionOptionView>>(
              jsonSerialization['options'],
            ),
      blocking: _i1.BoolJsonExtension.fromJson(jsonSerialization['blocking']),
      requestedAt: jsonSerialization['requestedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['requestedAt'],
            ),
    );
  }

  String decisionId;

  /// The `ProductLifecycleAction.wire` this decision authorises:
  /// pause | resume | offboard | reinstate. Read from the decision's own
  /// `LifecycleDecisionBinding` metadata, because the screen must still know
  /// which guard the gate was raised under after the route is left and re-entered.
  String action;

  String status;

  String? question;

  _i2.DecisionContextView? context;

  List<_i3.DecisionOptionView>? options;

  bool blocking;

  DateTime? requestedAt;

  /// Returns a shallow copy of this [ProductLifecycleGateView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductLifecycleGateView copyWith({
    String? decisionId,
    String? action,
    String? status,
    String? question,
    _i2.DecisionContextView? context,
    List<_i3.DecisionOptionView>? options,
    bool? blocking,
    DateTime? requestedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductLifecycleGateView',
      'decisionId': decisionId,
      'action': action,
      'status': status,
      if (question != null) 'question': question,
      if (context != null) 'context': context?.toJson(),
      if (options != null)
        'options': options?.toJson(valueToJson: (v) => v.toJson()),
      'blocking': blocking,
      if (requestedAt != null) 'requestedAt': requestedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProductLifecycleGateView',
      'decisionId': decisionId,
      'action': action,
      'status': status,
      if (question != null) 'question': question,
      if (context != null) 'context': context?.toJsonForProtocol(),
      if (options != null)
        'options': options?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'blocking': blocking,
      if (requestedAt != null) 'requestedAt': requestedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductLifecycleGateViewImpl extends ProductLifecycleGateView {
  _ProductLifecycleGateViewImpl({
    required String decisionId,
    required String action,
    required String status,
    String? question,
    _i2.DecisionContextView? context,
    List<_i3.DecisionOptionView>? options,
    required bool blocking,
    DateTime? requestedAt,
  }) : super._(
         decisionId: decisionId,
         action: action,
         status: status,
         question: question,
         context: context,
         options: options,
         blocking: blocking,
         requestedAt: requestedAt,
       );

  /// Returns a shallow copy of this [ProductLifecycleGateView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductLifecycleGateView copyWith({
    String? decisionId,
    String? action,
    String? status,
    Object? question = _Undefined,
    Object? context = _Undefined,
    Object? options = _Undefined,
    bool? blocking,
    Object? requestedAt = _Undefined,
  }) {
    return ProductLifecycleGateView(
      decisionId: decisionId ?? this.decisionId,
      action: action ?? this.action,
      status: status ?? this.status,
      question: question is String? ? question : this.question,
      context: context is _i2.DecisionContextView?
          ? context
          : this.context?.copyWith(),
      options: options is List<_i3.DecisionOptionView>?
          ? options
          : this.options?.map((e0) => e0.copyWith()).toList(),
      blocking: blocking ?? this.blocking,
      requestedAt: requestedAt is DateTime? ? requestedAt : this.requestedAt,
    );
  }
}

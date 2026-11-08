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

/// One legal operator action on a failed work item.
///
/// Offered only when `WorkItemTransitions.isLegalTransition(from, to)` says the
/// edge exists. The server never offers `terminated`: it has the same effect
/// from an operator's point of view as `stop` under a word nobody can act on,
/// and two buttons for one effect is worse than one (design-brief.md §5.2,
/// HD-1).
abstract class WorkItemActionView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkItemActionView._({
    required this.action,
    required this.toState,
    required this.confirmRequired,
    required this.destructive,
    this.attemptNumber,
    required this.attemptLimit,
  });

  factory WorkItemActionView({
    required String action,
    required String toState,
    required bool confirmRequired,
    required bool destructive,
    int? attemptNumber,
    required int attemptLimit,
  }) = _WorkItemActionViewImpl;

  factory WorkItemActionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkItemActionView(
      action: jsonSerialization['action'] as String,
      toState: jsonSerialization['toState'] as String,
      confirmRequired: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['confirmRequired'],
      ),
      destructive: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['destructive'],
      ),
      attemptNumber: jsonSerialization['attemptNumber'] as int?,
      attemptLimit: jsonSerialization['attemptLimit'] as int,
    );
  }

  /// 'retry' | 'stop' | 'deploy' | 'reclaim' | 'reland' | 'reroute'. The
  /// first two are the closed set of OperatorActionKind; the other four are
  /// the endpoint's own wire tokens (operatorDeployActionWire and friends in
  /// work_item_action_endpoints.dart), offered here as plain strings — the
  /// wire carries no enum. The client renders NOTHING for an action id it
  /// does not recognise, so an unknown value is inert rather than dangerous
  /// (§10 N4).
  String action;

  /// The state this edge lands in, as a durable wire value.
  String toState;

  bool confirmRequired;

  bool destructive;

  /// This work item's 1-based retry count AFTER this action. null when the
  /// action is not a retry.
  int? attemptNumber;

  /// The resolved per-work-item maximum; 0 means "not configured", which is a
  /// valid configuration meaning permanently disabled — not a failure
  /// (AC-15c).
  int attemptLimit;

  /// Returns a shallow copy of this [WorkItemActionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemActionView copyWith({
    String? action,
    String? toState,
    bool? confirmRequired,
    bool? destructive,
    int? attemptNumber,
    int? attemptLimit,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemActionView',
      'action': action,
      'toState': toState,
      'confirmRequired': confirmRequired,
      'destructive': destructive,
      if (attemptNumber != null) 'attemptNumber': attemptNumber,
      'attemptLimit': attemptLimit,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkItemActionView',
      'action': action,
      'toState': toState,
      'confirmRequired': confirmRequired,
      'destructive': destructive,
      if (attemptNumber != null) 'attemptNumber': attemptNumber,
      'attemptLimit': attemptLimit,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkItemActionViewImpl extends WorkItemActionView {
  _WorkItemActionViewImpl({
    required String action,
    required String toState,
    required bool confirmRequired,
    required bool destructive,
    int? attemptNumber,
    required int attemptLimit,
  }) : super._(
         action: action,
         toState: toState,
         confirmRequired: confirmRequired,
         destructive: destructive,
         attemptNumber: attemptNumber,
         attemptLimit: attemptLimit,
       );

  /// Returns a shallow copy of this [WorkItemActionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemActionView copyWith({
    String? action,
    String? toState,
    bool? confirmRequired,
    bool? destructive,
    Object? attemptNumber = _Undefined,
    int? attemptLimit,
  }) {
    return WorkItemActionView(
      action: action ?? this.action,
      toState: toState ?? this.toState,
      confirmRequired: confirmRequired ?? this.confirmRequired,
      destructive: destructive ?? this.destructive,
      attemptNumber: attemptNumber is int? ? attemptNumber : this.attemptNumber,
      attemptLimit: attemptLimit ?? this.attemptLimit,
    );
  }
}

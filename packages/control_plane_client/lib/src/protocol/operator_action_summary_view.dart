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

import 'package:serverpod_client/serverpod_client.dart' as _i1;

/// One row of the append-only `operator_action` audit ledger, for the panel.
///
/// `requestedBy` is the HUMAN — the one place in this repository where a
/// workflow action records the person rather than the path the engine acted by
/// (`work_item_transition.actorId` deliberately holds `operator-retry`, not a
/// name; see design-brief.md P-4 and OQ-1).
abstract class OperatorActionSummaryView implements _i1.SerializableModel {
  OperatorActionSummaryView._({
    required this.action,
    required this.requestedBy,
    required this.reason,
    required this.at,
    this.attemptNumber,
  });

  factory OperatorActionSummaryView({
    required String action,
    required String requestedBy,
    required String reason,
    required DateTime at,
    int? attemptNumber,
  }) = _OperatorActionSummaryViewImpl;

  factory OperatorActionSummaryView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OperatorActionSummaryView(
      action: jsonSerialization['action'] as String,
      requestedBy: jsonSerialization['requestedBy'] as String,
      reason: jsonSerialization['reason'] as String,
      at: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
      attemptNumber: jsonSerialization['attemptNumber'] as int?,
    );
  }

  /// 'retry' | 'stop'.
  String action;

  String requestedBy;

  String reason;

  DateTime at;

  /// 1-based position among this item's retries. Null for a `stop`, which
  /// consumes no attempt.
  int? attemptNumber;

  /// Returns a shallow copy of this [OperatorActionSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  OperatorActionSummaryView copyWith({
    String? action,
    String? requestedBy,
    String? reason,
    DateTime? at,
    int? attemptNumber,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'OperatorActionSummaryView',
      'action': action,
      'requestedBy': requestedBy,
      'reason': reason,
      'at': at.toJson(),
      if (attemptNumber != null) 'attemptNumber': attemptNumber,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OperatorActionSummaryViewImpl extends OperatorActionSummaryView {
  _OperatorActionSummaryViewImpl({
    required String action,
    required String requestedBy,
    required String reason,
    required DateTime at,
    int? attemptNumber,
  }) : super._(
         action: action,
         requestedBy: requestedBy,
         reason: reason,
         at: at,
         attemptNumber: attemptNumber,
       );

  /// Returns a shallow copy of this [OperatorActionSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  OperatorActionSummaryView copyWith({
    String? action,
    String? requestedBy,
    String? reason,
    DateTime? at,
    Object? attemptNumber = _Undefined,
  }) {
    return OperatorActionSummaryView(
      action: action ?? this.action,
      requestedBy: requestedBy ?? this.requestedBy,
      reason: reason ?? this.reason,
      at: at ?? this.at,
      attemptNumber: attemptNumber is int? ? attemptNumber : this.attemptNumber,
    );
  }
}

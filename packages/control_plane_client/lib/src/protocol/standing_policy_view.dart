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
import 'package:control_plane_client/src/protocol/protocol.dart' as _i2;

/// A signed decision authorising a class of future actions (ADR 0019).
///
/// Bounded to one product. Production promotion, baseline approval and
/// offboarding are non-delegable and cannot appear in `actions`.
abstract class StandingPolicyView implements _i1.SerializableModel {
  StandingPolicyView._({
    required this.policyId,
    required this.actions,
    required this.authorisingDecisionId,
    required this.authorisedBy,
    required this.rationale,
    required this.authorisedAt,
    required this.isRevoked,
    this.revokedAt,
    this.revokedBy,
    this.revocationReason,
  });

  factory StandingPolicyView({
    required String policyId,
    required List<String> actions,
    required String authorisingDecisionId,
    required String authorisedBy,
    required String rationale,
    required DateTime authorisedAt,
    required bool isRevoked,
    DateTime? revokedAt,
    String? revokedBy,
    String? revocationReason,
  }) = _StandingPolicyViewImpl;

  factory StandingPolicyView.fromJson(Map<String, dynamic> jsonSerialization) {
    return StandingPolicyView(
      policyId: jsonSerialization['policyId'] as String,
      actions: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['actions'],
      ),
      authorisingDecisionId:
          jsonSerialization['authorisingDecisionId'] as String,
      authorisedBy: jsonSerialization['authorisedBy'] as String,
      rationale: jsonSerialization['rationale'] as String,
      authorisedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['authorisedAt'],
      ),
      isRevoked: _i1.BoolJsonExtension.fromJson(jsonSerialization['isRevoked']),
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
      revokedBy: jsonSerialization['revokedBy'] as String?,
      revocationReason: jsonSerialization['revocationReason'] as String?,
    );
  }

  String policyId;

  /// push | merge
  List<String> actions;

  /// The gated HumanDecision that created this policy.
  String authorisingDecisionId;

  String authorisedBy;

  String rationale;

  DateTime authorisedAt;

  bool isRevoked;

  DateTime? revokedAt;

  String? revokedBy;

  String? revocationReason;

  /// Returns a shallow copy of this [StandingPolicyView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  StandingPolicyView copyWith({
    String? policyId,
    List<String>? actions,
    String? authorisingDecisionId,
    String? authorisedBy,
    String? rationale,
    DateTime? authorisedAt,
    bool? isRevoked,
    DateTime? revokedAt,
    String? revokedBy,
    String? revocationReason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StandingPolicyView',
      'policyId': policyId,
      'actions': actions.toJson(),
      'authorisingDecisionId': authorisingDecisionId,
      'authorisedBy': authorisedBy,
      'rationale': rationale,
      'authorisedAt': authorisedAt.toJson(),
      'isRevoked': isRevoked,
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
      if (revokedBy != null) 'revokedBy': revokedBy,
      if (revocationReason != null) 'revocationReason': revocationReason,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StandingPolicyViewImpl extends StandingPolicyView {
  _StandingPolicyViewImpl({
    required String policyId,
    required List<String> actions,
    required String authorisingDecisionId,
    required String authorisedBy,
    required String rationale,
    required DateTime authorisedAt,
    required bool isRevoked,
    DateTime? revokedAt,
    String? revokedBy,
    String? revocationReason,
  }) : super._(
         policyId: policyId,
         actions: actions,
         authorisingDecisionId: authorisingDecisionId,
         authorisedBy: authorisedBy,
         rationale: rationale,
         authorisedAt: authorisedAt,
         isRevoked: isRevoked,
         revokedAt: revokedAt,
         revokedBy: revokedBy,
         revocationReason: revocationReason,
       );

  /// Returns a shallow copy of this [StandingPolicyView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  StandingPolicyView copyWith({
    String? policyId,
    List<String>? actions,
    String? authorisingDecisionId,
    String? authorisedBy,
    String? rationale,
    DateTime? authorisedAt,
    bool? isRevoked,
    Object? revokedAt = _Undefined,
    Object? revokedBy = _Undefined,
    Object? revocationReason = _Undefined,
  }) {
    return StandingPolicyView(
      policyId: policyId ?? this.policyId,
      actions: actions ?? this.actions.map((e0) => e0).toList(),
      authorisingDecisionId:
          authorisingDecisionId ?? this.authorisingDecisionId,
      authorisedBy: authorisedBy ?? this.authorisedBy,
      rationale: rationale ?? this.rationale,
      authorisedAt: authorisedAt ?? this.authorisedAt,
      isRevoked: isRevoked ?? this.isRevoked,
      revokedAt: revokedAt is DateTime? ? revokedAt : this.revokedAt,
      revokedBy: revokedBy is String? ? revokedBy : this.revokedBy,
      revocationReason: revocationReason is String?
          ? revocationReason
          : this.revocationReason,
    );
  }
}

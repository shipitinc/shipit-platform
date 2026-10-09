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
import 'model_step_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// `ModelPolicy` as it travels. `role` and every enum on the chain travel as
/// their wire text, matching every other view in this directory.
abstract class ModelPolicyView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ModelPolicyView._({
    required this.role,
    required this.chain,
    required this.version,
    required this.updatedAt,
    required this.updatedByDecisionId,
  });

  factory ModelPolicyView({
    required String role,
    required List<_i2.ModelStepView> chain,
    required int version,
    required DateTime updatedAt,
    required String updatedByDecisionId,
  }) = _ModelPolicyViewImpl;

  factory ModelPolicyView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ModelPolicyView(
      role: jsonSerialization['role'] as String,
      chain: _i3.Protocol().deserialize<List<_i2.ModelStepView>>(
        jsonSerialization['chain'],
      ),
      version: jsonSerialization['version'] as int,
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      updatedByDecisionId: jsonSerialization['updatedByDecisionId'] as String,
    );
  }

  /// Durable `AgentRole` wire value.
  String role;

  List<_i2.ModelStepView> chain;

  int version;

  DateTime updatedAt;

  String updatedByDecisionId;

  /// Returns a shallow copy of this [ModelPolicyView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelPolicyView copyWith({
    String? role,
    List<_i2.ModelStepView>? chain,
    int? version,
    DateTime? updatedAt,
    String? updatedByDecisionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelPolicyView',
      'role': role,
      'chain': chain.toJson(valueToJson: (v) => v.toJson()),
      'version': version,
      'updatedAt': updatedAt.toJson(),
      'updatedByDecisionId': updatedByDecisionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ModelPolicyView',
      'role': role,
      'chain': chain.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'version': version,
      'updatedAt': updatedAt.toJson(),
      'updatedByDecisionId': updatedByDecisionId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ModelPolicyViewImpl extends ModelPolicyView {
  _ModelPolicyViewImpl({
    required String role,
    required List<_i2.ModelStepView> chain,
    required int version,
    required DateTime updatedAt,
    required String updatedByDecisionId,
  }) : super._(
         role: role,
         chain: chain,
         version: version,
         updatedAt: updatedAt,
         updatedByDecisionId: updatedByDecisionId,
       );

  /// Returns a shallow copy of this [ModelPolicyView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelPolicyView copyWith({
    String? role,
    List<_i2.ModelStepView>? chain,
    int? version,
    DateTime? updatedAt,
    String? updatedByDecisionId,
  }) {
    return ModelPolicyView(
      role: role ?? this.role,
      chain: chain ?? this.chain.map((e0) => e0.copyWith()).toList(),
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByDecisionId: updatedByDecisionId ?? this.updatedByDecisionId,
    );
  }
}

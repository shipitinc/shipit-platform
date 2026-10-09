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

/// One step of a model policy chain (`ModelStep`).
abstract class ModelStepView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ModelStepView._({
    required this.modelId,
    required this.provider,
  });

  factory ModelStepView({
    required String modelId,
    required String provider,
  }) = _ModelStepViewImpl;

  factory ModelStepView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ModelStepView(
      modelId: jsonSerialization['modelId'] as String,
      provider: jsonSerialization['provider'] as String,
    );
  }

  String modelId;

  String provider;

  /// Returns a shallow copy of this [ModelStepView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelStepView copyWith({
    String? modelId,
    String? provider,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelStepView',
      'modelId': modelId,
      'provider': provider,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ModelStepView',
      'modelId': modelId,
      'provider': provider,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ModelStepViewImpl extends ModelStepView {
  _ModelStepViewImpl({
    required String modelId,
    required String provider,
  }) : super._(
         modelId: modelId,
         provider: provider,
       );

  /// Returns a shallow copy of this [ModelStepView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelStepView copyWith({
    String? modelId,
    String? provider,
  }) {
    return ModelStepView(
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
    );
  }
}

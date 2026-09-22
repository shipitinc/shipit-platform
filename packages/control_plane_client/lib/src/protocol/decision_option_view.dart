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

abstract class DecisionOptionView implements _i1.SerializableModel {
  DecisionOptionView._({
    required this.optionId,
    required this.label,
    this.description,
    required this.recommended,
  });

  factory DecisionOptionView({
    required String optionId,
    required String label,
    String? description,
    required bool recommended,
  }) = _DecisionOptionViewImpl;

  factory DecisionOptionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DecisionOptionView(
      optionId: jsonSerialization['optionId'] as String,
      label: jsonSerialization['label'] as String,
      description: jsonSerialization['description'] as String?,
      recommended: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['recommended'],
      ),
    );
  }

  String optionId;

  String label;

  String? description;

  bool recommended;

  /// Returns a shallow copy of this [DecisionOptionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DecisionOptionView copyWith({
    String? optionId,
    String? label,
    String? description,
    bool? recommended,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DecisionOptionView',
      'optionId': optionId,
      'label': label,
      if (description != null) 'description': description,
      'recommended': recommended,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DecisionOptionViewImpl extends DecisionOptionView {
  _DecisionOptionViewImpl({
    required String optionId,
    required String label,
    String? description,
    required bool recommended,
  }) : super._(
         optionId: optionId,
         label: label,
         description: description,
         recommended: recommended,
       );

  /// Returns a shallow copy of this [DecisionOptionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DecisionOptionView copyWith({
    String? optionId,
    String? label,
    Object? description = _Undefined,
    bool? recommended,
  }) {
    return DecisionOptionView(
      optionId: optionId ?? this.optionId,
      label: label ?? this.label,
      description: description is String? ? description : this.description,
      recommended: recommended ?? this.recommended,
    );
  }
}

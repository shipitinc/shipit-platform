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
import 'package:control_plane_server/src/generated/protocol.dart' as _i2;

abstract class DecisionContextView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DecisionContextView._({
    required this.workflowState,
    required this.availableOptions,
  });

  factory DecisionContextView({
    required String workflowState,
    required List<String> availableOptions,
  }) = _DecisionContextViewImpl;

  factory DecisionContextView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DecisionContextView(
      workflowState: jsonSerialization['workflowState'] as String,
      availableOptions: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['availableOptions'],
      ),
    );
  }

  String workflowState;

  List<String> availableOptions;

  /// Returns a shallow copy of this [DecisionContextView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DecisionContextView copyWith({
    String? workflowState,
    List<String>? availableOptions,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DecisionContextView',
      'workflowState': workflowState,
      'availableOptions': availableOptions.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DecisionContextView',
      'workflowState': workflowState,
      'availableOptions': availableOptions.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DecisionContextViewImpl extends DecisionContextView {
  _DecisionContextViewImpl({
    required String workflowState,
    required List<String> availableOptions,
  }) : super._(
         workflowState: workflowState,
         availableOptions: availableOptions,
       );

  /// Returns a shallow copy of this [DecisionContextView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DecisionContextView copyWith({
    String? workflowState,
    List<String>? availableOptions,
  }) {
    return DecisionContextView(
      workflowState: workflowState ?? this.workflowState,
      availableOptions:
          availableOptions ?? this.availableOptions.map((e0) => e0).toList(),
    );
  }
}

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

abstract class HumanDirectionAttachmentView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  HumanDirectionAttachmentView._({
    required this.artifactId,
    required this.artifactType,
    this.description,
  });

  factory HumanDirectionAttachmentView({
    required String artifactId,
    required String artifactType,
    String? description,
  }) = _HumanDirectionAttachmentViewImpl;

  factory HumanDirectionAttachmentView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return HumanDirectionAttachmentView(
      artifactId: jsonSerialization['artifactId'] as String,
      artifactType: jsonSerialization['artifactType'] as String,
      description: jsonSerialization['description'] as String?,
    );
  }

  String artifactId;

  String artifactType;

  String? description;

  /// Returns a shallow copy of this [HumanDirectionAttachmentView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  HumanDirectionAttachmentView copyWith({
    String? artifactId,
    String? artifactType,
    String? description,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HumanDirectionAttachmentView',
      'artifactId': artifactId,
      'artifactType': artifactType,
      if (description != null) 'description': description,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HumanDirectionAttachmentView',
      'artifactId': artifactId,
      'artifactType': artifactType,
      if (description != null) 'description': description,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HumanDirectionAttachmentViewImpl extends HumanDirectionAttachmentView {
  _HumanDirectionAttachmentViewImpl({
    required String artifactId,
    required String artifactType,
    String? description,
  }) : super._(
         artifactId: artifactId,
         artifactType: artifactType,
         description: description,
       );

  /// Returns a shallow copy of this [HumanDirectionAttachmentView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  HumanDirectionAttachmentView copyWith({
    String? artifactId,
    String? artifactType,
    Object? description = _Undefined,
  }) {
    return HumanDirectionAttachmentView(
      artifactId: artifactId ?? this.artifactId,
      artifactType: artifactType ?? this.artifactType,
      description: description is String? ? description : this.description,
    );
  }
}

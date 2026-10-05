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
import 'human_direction_attachment_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

abstract class HumanDirectionPayloadView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  HumanDirectionPayloadView._({
    required this.title,
    required this.description,
    this.contextJson,
    this.attachments,
  });

  factory HumanDirectionPayloadView({
    required String title,
    required String description,
    String? contextJson,
    List<_i2.HumanDirectionAttachmentView>? attachments,
  }) = _HumanDirectionPayloadViewImpl;

  factory HumanDirectionPayloadView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return HumanDirectionPayloadView(
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String,
      contextJson: jsonSerialization['contextJson'] as String?,
      attachments: jsonSerialization['attachments'] == null
          ? null
          : _i3.Protocol().deserialize<List<_i2.HumanDirectionAttachmentView>>(
              jsonSerialization['attachments'],
            ),
    );
  }

  String title;

  String description;

  String? contextJson;

  List<_i2.HumanDirectionAttachmentView>? attachments;

  /// Returns a shallow copy of this [HumanDirectionPayloadView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  HumanDirectionPayloadView copyWith({
    String? title,
    String? description,
    String? contextJson,
    List<_i2.HumanDirectionAttachmentView>? attachments,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HumanDirectionPayloadView',
      'title': title,
      'description': description,
      if (contextJson != null) 'contextJson': contextJson,
      if (attachments != null)
        'attachments': attachments?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HumanDirectionPayloadView',
      'title': title,
      'description': description,
      if (contextJson != null) 'contextJson': contextJson,
      if (attachments != null)
        'attachments': attachments?.toJson(
          valueToJson: (v) => v.toJsonForProtocol(),
        ),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HumanDirectionPayloadViewImpl extends HumanDirectionPayloadView {
  _HumanDirectionPayloadViewImpl({
    required String title,
    required String description,
    String? contextJson,
    List<_i2.HumanDirectionAttachmentView>? attachments,
  }) : super._(
         title: title,
         description: description,
         contextJson: contextJson,
         attachments: attachments,
       );

  /// Returns a shallow copy of this [HumanDirectionPayloadView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  HumanDirectionPayloadView copyWith({
    String? title,
    String? description,
    Object? contextJson = _Undefined,
    Object? attachments = _Undefined,
  }) {
    return HumanDirectionPayloadView(
      title: title ?? this.title,
      description: description ?? this.description,
      contextJson: contextJson is String? ? contextJson : this.contextJson,
      attachments: attachments is List<_i2.HumanDirectionAttachmentView>?
          ? attachments
          : this.attachments?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

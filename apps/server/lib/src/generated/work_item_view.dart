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
import 'artifact_reference_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

abstract class WorkItemView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkItemView._({
    required this.workItemId,
    required this.title,
    this.description,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.blockingHumanDecisionId,
    this.artifactRefs,
  });

  factory WorkItemView({
    required String workItemId,
    required String title,
    String? description,
    required String state,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
    String? blockingHumanDecisionId,
    List<_i2.ArtifactReferenceView>? artifactRefs,
  }) = _WorkItemViewImpl;

  factory WorkItemView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkItemView(
      workItemId: jsonSerialization['workItemId'] as String,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String?,
      state: jsonSerialization['state'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      blockingHumanDecisionId:
          jsonSerialization['blockingHumanDecisionId'] as String?,
      artifactRefs: jsonSerialization['artifactRefs'] == null
          ? null
          : _i3.Protocol().deserialize<List<_i2.ArtifactReferenceView>>(
              jsonSerialization['artifactRefs'],
            ),
    );
  }

  String workItemId;

  String title;

  String? description;

  String state;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? completedAt;

  String? blockingHumanDecisionId;

  List<_i2.ArtifactReferenceView>? artifactRefs;

  /// Returns a shallow copy of this [WorkItemView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemView copyWith({
    String? workItemId,
    String? title,
    String? description,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? blockingHumanDecisionId,
    List<_i2.ArtifactReferenceView>? artifactRefs,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemView',
      'workItemId': workItemId,
      'title': title,
      if (description != null) 'description': description,
      'state': state,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (blockingHumanDecisionId != null)
        'blockingHumanDecisionId': blockingHumanDecisionId,
      if (artifactRefs != null)
        'artifactRefs': artifactRefs?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkItemView',
      'workItemId': workItemId,
      'title': title,
      if (description != null) 'description': description,
      'state': state,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (blockingHumanDecisionId != null)
        'blockingHumanDecisionId': blockingHumanDecisionId,
      if (artifactRefs != null)
        'artifactRefs': artifactRefs?.toJson(
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

class _WorkItemViewImpl extends WorkItemView {
  _WorkItemViewImpl({
    required String workItemId,
    required String title,
    String? description,
    required String state,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
    String? blockingHumanDecisionId,
    List<_i2.ArtifactReferenceView>? artifactRefs,
  }) : super._(
         workItemId: workItemId,
         title: title,
         description: description,
         state: state,
         createdAt: createdAt,
         updatedAt: updatedAt,
         completedAt: completedAt,
         blockingHumanDecisionId: blockingHumanDecisionId,
         artifactRefs: artifactRefs,
       );

  /// Returns a shallow copy of this [WorkItemView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemView copyWith({
    String? workItemId,
    String? title,
    Object? description = _Undefined,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _Undefined,
    Object? blockingHumanDecisionId = _Undefined,
    Object? artifactRefs = _Undefined,
  }) {
    return WorkItemView(
      workItemId: workItemId ?? this.workItemId,
      title: title ?? this.title,
      description: description is String? ? description : this.description,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      blockingHumanDecisionId: blockingHumanDecisionId is String?
          ? blockingHumanDecisionId
          : this.blockingHumanDecisionId,
      artifactRefs: artifactRefs is List<_i2.ArtifactReferenceView>?
          ? artifactRefs
          : this.artifactRefs?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

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

/// The checkout an agent execution was given.
abstract class AgentWorkspaceView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  AgentWorkspaceView._({
    required this.workspaceId,
    required this.path,
    this.startingRevision,
    this.allowedPaths,
  });

  factory AgentWorkspaceView({
    required String workspaceId,
    required String path,
    String? startingRevision,
    List<String>? allowedPaths,
  }) = _AgentWorkspaceViewImpl;

  factory AgentWorkspaceView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentWorkspaceView(
      workspaceId: jsonSerialization['workspaceId'] as String,
      path: jsonSerialization['path'] as String,
      startingRevision: jsonSerialization['startingRevision'] as String?,
      allowedPaths: jsonSerialization['allowedPaths'] == null
          ? null
          : _i2.Protocol().deserialize<List<String>>(
              jsonSerialization['allowedPaths'],
            ),
    );
  }

  String workspaceId;

  String path;

  String? startingRevision;

  List<String>? allowedPaths;

  /// Returns a shallow copy of this [AgentWorkspaceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentWorkspaceView copyWith({
    String? workspaceId,
    String? path,
    String? startingRevision,
    List<String>? allowedPaths,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentWorkspaceView',
      'workspaceId': workspaceId,
      'path': path,
      if (startingRevision != null) 'startingRevision': startingRevision,
      if (allowedPaths != null) 'allowedPaths': allowedPaths?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentWorkspaceView',
      'workspaceId': workspaceId,
      'path': path,
      if (startingRevision != null) 'startingRevision': startingRevision,
      if (allowedPaths != null) 'allowedPaths': allowedPaths?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentWorkspaceViewImpl extends AgentWorkspaceView {
  _AgentWorkspaceViewImpl({
    required String workspaceId,
    required String path,
    String? startingRevision,
    List<String>? allowedPaths,
  }) : super._(
         workspaceId: workspaceId,
         path: path,
         startingRevision: startingRevision,
         allowedPaths: allowedPaths,
       );

  /// Returns a shallow copy of this [AgentWorkspaceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentWorkspaceView copyWith({
    String? workspaceId,
    String? path,
    Object? startingRevision = _Undefined,
    Object? allowedPaths = _Undefined,
  }) {
    return AgentWorkspaceView(
      workspaceId: workspaceId ?? this.workspaceId,
      path: path ?? this.path,
      startingRevision: startingRevision is String?
          ? startingRevision
          : this.startingRevision,
      allowedPaths: allowedPaths is List<String>?
          ? allowedPaths
          : this.allowedPaths?.map((e0) => e0).toList(),
    );
  }
}

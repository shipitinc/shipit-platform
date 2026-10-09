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

/// One capability a registered worker advertises.
abstract class CapabilitySpecView implements _i1.SerializableModel {
  CapabilitySpecView._({
    required this.capability,
    required this.version,
    this.metadata,
    this.providedTools,
  });

  factory CapabilitySpecView({
    required String capability,
    required String version,
    Map<String, String>? metadata,
    List<String>? providedTools,
  }) = _CapabilitySpecViewImpl;

  factory CapabilitySpecView.fromJson(Map<String, dynamic> jsonSerialization) {
    return CapabilitySpecView(
      capability: jsonSerialization['capability'] as String,
      version: jsonSerialization['version'] as String,
      metadata: jsonSerialization['metadata'] == null
          ? null
          : _i2.Protocol().deserialize<Map<String, String>>(
              jsonSerialization['metadata'],
            ),
      providedTools: jsonSerialization['providedTools'] == null
          ? null
          : _i2.Protocol().deserialize<List<String>>(
              jsonSerialization['providedTools'],
            ),
    );
  }

  /// Durable `WorkerCapability` name — also the key it is filed under.
  String capability;

  String version;

  Map<String, String>? metadata;

  List<String>? providedTools;

  /// Returns a shallow copy of this [CapabilitySpecView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CapabilitySpecView copyWith({
    String? capability,
    String? version,
    Map<String, String>? metadata,
    List<String>? providedTools,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CapabilitySpecView',
      'capability': capability,
      'version': version,
      if (metadata != null) 'metadata': metadata?.toJson(),
      if (providedTools != null) 'providedTools': providedTools?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CapabilitySpecViewImpl extends CapabilitySpecView {
  _CapabilitySpecViewImpl({
    required String capability,
    required String version,
    Map<String, String>? metadata,
    List<String>? providedTools,
  }) : super._(
         capability: capability,
         version: version,
         metadata: metadata,
         providedTools: providedTools,
       );

  /// Returns a shallow copy of this [CapabilitySpecView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CapabilitySpecView copyWith({
    String? capability,
    String? version,
    Object? metadata = _Undefined,
    Object? providedTools = _Undefined,
  }) {
    return CapabilitySpecView(
      capability: capability ?? this.capability,
      version: version ?? this.version,
      metadata: metadata is Map<String, String>?
          ? metadata
          : this.metadata?.map(
              (
                key0,
                value0,
              ) => MapEntry(
                key0,
                value0,
              ),
            ),
      providedTools: providedTools is List<String>?
          ? providedTools
          : this.providedTools?.map((e0) => e0).toList(),
    );
  }
}

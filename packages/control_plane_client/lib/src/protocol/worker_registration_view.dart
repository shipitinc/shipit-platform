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
import 'capability_spec_view.dart' as _i2;
import 'artifact_cache_entry_view.dart' as _i3;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i4;

/// One registered worker.
abstract class WorkerRegistrationView implements _i1.SerializableModel {
  WorkerRegistrationView._({
    required this.workerId,
    required this.poolId,
    required this.capabilities,
    required this.status,
    required this.currentLoad,
    required this.maxConcurrency,
    required this.lastHeartbeat,
    this.artifactCache,
    this.platform,
  });

  factory WorkerRegistrationView({
    required String workerId,
    required String poolId,
    required Map<String, _i2.CapabilitySpecView> capabilities,
    required String status,
    required int currentLoad,
    required int maxConcurrency,
    required DateTime lastHeartbeat,
    Map<String, _i3.ArtifactCacheEntryView>? artifactCache,
    String? platform,
  }) = _WorkerRegistrationViewImpl;

  factory WorkerRegistrationView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkerRegistrationView(
      workerId: jsonSerialization['workerId'] as String,
      poolId: jsonSerialization['poolId'] as String,
      capabilities: _i4.Protocol()
          .deserialize<Map<String, _i2.CapabilitySpecView>>(
            jsonSerialization['capabilities'],
          ),
      status: jsonSerialization['status'] as String,
      currentLoad: jsonSerialization['currentLoad'] as int,
      maxConcurrency: jsonSerialization['maxConcurrency'] as int,
      lastHeartbeat: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastHeartbeat'],
      ),
      artifactCache: jsonSerialization['artifactCache'] == null
          ? null
          : _i4.Protocol().deserialize<Map<String, _i3.ArtifactCacheEntryView>>(
              jsonSerialization['artifactCache'],
            ),
      platform: jsonSerialization['platform'] as String?,
    );
  }

  String workerId;

  String poolId;

  /// Capability name -> the spec it advertises. A `Map<String, …>` keyed by the
  /// capability's wire name, because the domain type keys it by the enum and
  /// JSON object keys are strings.
  Map<String, _i2.CapabilitySpecView> capabilities;

  /// Durable `WorkerStatus` name.
  String status;

  int currentLoad;

  int maxConcurrency;

  DateTime lastHeartbeat;

  /// Artifact hash -> the cached entry.
  Map<String, _i3.ArtifactCacheEntryView>? artifactCache;

  String? platform;

  /// Returns a shallow copy of this [WorkerRegistrationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerRegistrationView copyWith({
    String? workerId,
    String? poolId,
    Map<String, _i2.CapabilitySpecView>? capabilities,
    String? status,
    int? currentLoad,
    int? maxConcurrency,
    DateTime? lastHeartbeat,
    Map<String, _i3.ArtifactCacheEntryView>? artifactCache,
    String? platform,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerRegistrationView',
      'workerId': workerId,
      'poolId': poolId,
      'capabilities': capabilities.toJson(valueToJson: (v) => v.toJson()),
      'status': status,
      'currentLoad': currentLoad,
      'maxConcurrency': maxConcurrency,
      'lastHeartbeat': lastHeartbeat.toJson(),
      if (artifactCache != null)
        'artifactCache': artifactCache?.toJson(valueToJson: (v) => v.toJson()),
      if (platform != null) 'platform': platform,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerRegistrationViewImpl extends WorkerRegistrationView {
  _WorkerRegistrationViewImpl({
    required String workerId,
    required String poolId,
    required Map<String, _i2.CapabilitySpecView> capabilities,
    required String status,
    required int currentLoad,
    required int maxConcurrency,
    required DateTime lastHeartbeat,
    Map<String, _i3.ArtifactCacheEntryView>? artifactCache,
    String? platform,
  }) : super._(
         workerId: workerId,
         poolId: poolId,
         capabilities: capabilities,
         status: status,
         currentLoad: currentLoad,
         maxConcurrency: maxConcurrency,
         lastHeartbeat: lastHeartbeat,
         artifactCache: artifactCache,
         platform: platform,
       );

  /// Returns a shallow copy of this [WorkerRegistrationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerRegistrationView copyWith({
    String? workerId,
    String? poolId,
    Map<String, _i2.CapabilitySpecView>? capabilities,
    String? status,
    int? currentLoad,
    int? maxConcurrency,
    DateTime? lastHeartbeat,
    Object? artifactCache = _Undefined,
    Object? platform = _Undefined,
  }) {
    return WorkerRegistrationView(
      workerId: workerId ?? this.workerId,
      poolId: poolId ?? this.poolId,
      capabilities:
          capabilities ??
          this.capabilities.map(
            (
              key0,
              value0,
            ) => MapEntry(
              key0,
              value0.copyWith(),
            ),
          ),
      status: status ?? this.status,
      currentLoad: currentLoad ?? this.currentLoad,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      artifactCache: artifactCache is Map<String, _i3.ArtifactCacheEntryView>?
          ? artifactCache
          : this.artifactCache?.map(
              (
                key0,
                value0,
              ) => MapEntry(
                key0,
                value0.copyWith(),
              ),
            ),
      platform: platform is String? ? platform : this.platform,
    );
  }
}

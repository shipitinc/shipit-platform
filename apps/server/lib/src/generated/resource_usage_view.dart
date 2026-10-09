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

/// Resource consumption measured for an agent run.
abstract class ResourceUsageView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ResourceUsageView._({
    this.peakMemoryMb,
    this.cpuSeconds,
    this.networkBytes,
  });

  factory ResourceUsageView({
    int? peakMemoryMb,
    double? cpuSeconds,
    int? networkBytes,
  }) = _ResourceUsageViewImpl;

  factory ResourceUsageView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ResourceUsageView(
      peakMemoryMb: jsonSerialization['peakMemoryMb'] as int?,
      cpuSeconds: (jsonSerialization['cpuSeconds'] as num?)?.toDouble(),
      networkBytes: jsonSerialization['networkBytes'] as int?,
    );
  }

  int? peakMemoryMb;

  double? cpuSeconds;

  int? networkBytes;

  /// Returns a shallow copy of this [ResourceUsageView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ResourceUsageView copyWith({
    int? peakMemoryMb,
    double? cpuSeconds,
    int? networkBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ResourceUsageView',
      if (peakMemoryMb != null) 'peakMemoryMb': peakMemoryMb,
      if (cpuSeconds != null) 'cpuSeconds': cpuSeconds,
      if (networkBytes != null) 'networkBytes': networkBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ResourceUsageView',
      if (peakMemoryMb != null) 'peakMemoryMb': peakMemoryMb,
      if (cpuSeconds != null) 'cpuSeconds': cpuSeconds,
      if (networkBytes != null) 'networkBytes': networkBytes,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ResourceUsageViewImpl extends ResourceUsageView {
  _ResourceUsageViewImpl({
    int? peakMemoryMb,
    double? cpuSeconds,
    int? networkBytes,
  }) : super._(
         peakMemoryMb: peakMemoryMb,
         cpuSeconds: cpuSeconds,
         networkBytes: networkBytes,
       );

  /// Returns a shallow copy of this [ResourceUsageView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ResourceUsageView copyWith({
    Object? peakMemoryMb = _Undefined,
    Object? cpuSeconds = _Undefined,
    Object? networkBytes = _Undefined,
  }) {
    return ResourceUsageView(
      peakMemoryMb: peakMemoryMb is int? ? peakMemoryMb : this.peakMemoryMb,
      cpuSeconds: cpuSeconds is double? ? cpuSeconds : this.cpuSeconds,
      networkBytes: networkBytes is int? ? networkBytes : this.networkBytes,
    );
  }
}

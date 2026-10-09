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

/// One provider's health row. `healthy` is null until a health monitor exists —
/// the endpoint has always reported "known", not "checked".
abstract class ProviderStatusView implements _i1.SerializableModel {
  ProviderStatusView._({
    required this.provider,
    this.healthy,
  });

  factory ProviderStatusView({
    required String provider,
    bool? healthy,
  }) = _ProviderStatusViewImpl;

  factory ProviderStatusView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProviderStatusView(
      provider: jsonSerialization['provider'] as String,
      healthy: jsonSerialization['healthy'] == null
          ? null
          : _i1.BoolJsonExtension.fromJson(jsonSerialization['healthy']),
    );
  }

  String provider;

  bool? healthy;

  /// Returns a shallow copy of this [ProviderStatusView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProviderStatusView copyWith({
    String? provider,
    bool? healthy,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProviderStatusView',
      'provider': provider,
      if (healthy != null) 'healthy': healthy,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProviderStatusViewImpl extends ProviderStatusView {
  _ProviderStatusViewImpl({
    required String provider,
    bool? healthy,
  }) : super._(
         provider: provider,
         healthy: healthy,
       );

  /// Returns a shallow copy of this [ProviderStatusView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProviderStatusView copyWith({
    String? provider,
    Object? healthy = _Undefined,
  }) {
    return ProviderStatusView(
      provider: provider ?? this.provider,
      healthy: healthy is bool? ? healthy : this.healthy,
    );
  }
}

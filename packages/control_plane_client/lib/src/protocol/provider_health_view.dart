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
import 'provider_status_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// `providerHealthEndpoints.getProviderHealth` returned a raw map. Typed.
abstract class ProviderHealthView implements _i1.SerializableModel {
  ProviderHealthView._({
    required this.providers,
    required this.allProvidersDown,
  });

  factory ProviderHealthView({
    required List<_i2.ProviderStatusView> providers,
    required List<_i2.ProviderStatusView> allProvidersDown,
  }) = _ProviderHealthViewImpl;

  factory ProviderHealthView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProviderHealthView(
      providers: _i3.Protocol().deserialize<List<_i2.ProviderStatusView>>(
        jsonSerialization['providers'],
      ),
      allProvidersDown: _i3.Protocol()
          .deserialize<List<_i2.ProviderStatusView>>(
            jsonSerialization['allProvidersDown'],
          ),
    );
  }

  List<_i2.ProviderStatusView> providers;

  /// Always empty: no provider has been observed down yet. Kept so the shape
  /// does not change when one can be.
  List<_i2.ProviderStatusView> allProvidersDown;

  /// Returns a shallow copy of this [ProviderHealthView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProviderHealthView copyWith({
    List<_i2.ProviderStatusView>? providers,
    List<_i2.ProviderStatusView>? allProvidersDown,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProviderHealthView',
      'providers': providers.toJson(valueToJson: (v) => v.toJson()),
      'allProvidersDown': allProvidersDown.toJson(
        valueToJson: (v) => v.toJson(),
      ),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ProviderHealthViewImpl extends ProviderHealthView {
  _ProviderHealthViewImpl({
    required List<_i2.ProviderStatusView> providers,
    required List<_i2.ProviderStatusView> allProvidersDown,
  }) : super._(
         providers: providers,
         allProvidersDown: allProvidersDown,
       );

  /// Returns a shallow copy of this [ProviderHealthView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProviderHealthView copyWith({
    List<_i2.ProviderStatusView>? providers,
    List<_i2.ProviderStatusView>? allProvidersDown,
  }) {
    return ProviderHealthView(
      providers:
          providers ?? this.providers.map((e0) => e0.copyWith()).toList(),
      allProvidersDown:
          allProvidersDown ??
          this.allProvidersDown.map((e0) => e0.copyWith()).toList(),
    );
  }
}

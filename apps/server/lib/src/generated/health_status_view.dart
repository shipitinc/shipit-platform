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

/// `healthEndpoints.health` returned a raw map. Typed so the generated client
/// can read it at all.
abstract class HealthStatusView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  HealthStatusView._({
    required this.status,
    required this.timestamp,
  });

  factory HealthStatusView({
    required String status,
    required DateTime timestamp,
  }) = _HealthStatusViewImpl;

  factory HealthStatusView.fromJson(Map<String, dynamic> jsonSerialization) {
    return HealthStatusView(
      status: jsonSerialization['status'] as String,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
    );
  }

  /// `ok`.
  String status;

  /// Server clock, UTC.
  DateTime timestamp;

  /// Returns a shallow copy of this [HealthStatusView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  HealthStatusView copyWith({
    String? status,
    DateTime? timestamp,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HealthStatusView',
      'status': status,
      'timestamp': timestamp.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HealthStatusView',
      'status': status,
      'timestamp': timestamp.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _HealthStatusViewImpl extends HealthStatusView {
  _HealthStatusViewImpl({
    required String status,
    required DateTime timestamp,
  }) : super._(
         status: status,
         timestamp: timestamp,
       );

  /// Returns a shallow copy of this [HealthStatusView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  HealthStatusView copyWith({
    String? status,
    DateTime? timestamp,
  }) {
    return HealthStatusView(
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

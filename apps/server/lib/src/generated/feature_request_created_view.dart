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

/// `intakeEndpoints.createFeatureRequest` returned a raw map. Typed.
abstract class FeatureRequestCreatedView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  FeatureRequestCreatedView._({
    required this.workItemId,
    required this.title,
    required this.state,
    required this.createdAt,
  });

  factory FeatureRequestCreatedView({
    required String workItemId,
    required String title,
    required String state,
    required DateTime createdAt,
  }) = _FeatureRequestCreatedViewImpl;

  factory FeatureRequestCreatedView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FeatureRequestCreatedView(
      workItemId: jsonSerialization['workItemId'] as String,
      title: jsonSerialization['title'] as String,
      state: jsonSerialization['state'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String workItemId;

  String title;

  /// Durable work-item wire state.
  String state;

  DateTime createdAt;

  /// Returns a shallow copy of this [FeatureRequestCreatedView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FeatureRequestCreatedView copyWith({
    String? workItemId,
    String? title,
    String? state,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FeatureRequestCreatedView',
      'workItemId': workItemId,
      'title': title,
      'state': state,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FeatureRequestCreatedView',
      'workItemId': workItemId,
      'title': title,
      'state': state,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _FeatureRequestCreatedViewImpl extends FeatureRequestCreatedView {
  _FeatureRequestCreatedViewImpl({
    required String workItemId,
    required String title,
    required String state,
    required DateTime createdAt,
  }) : super._(
         workItemId: workItemId,
         title: title,
         state: state,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [FeatureRequestCreatedView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FeatureRequestCreatedView copyWith({
    String? workItemId,
    String? title,
    String? state,
    DateTime? createdAt,
  }) {
    return FeatureRequestCreatedView(
      workItemId: workItemId ?? this.workItemId,
      title: title ?? this.title,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

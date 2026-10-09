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

/// `defectEndpoints.create` returned a raw map. Typed.
abstract class DefectCreatedView implements _i1.SerializableModel {
  DefectCreatedView._({
    required this.defectId,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  factory DefectCreatedView({
    required String defectId,
    required String title,
    required String status,
    required DateTime createdAt,
  }) = _DefectCreatedViewImpl;

  factory DefectCreatedView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectCreatedView(
      defectId: jsonSerialization['defectId'] as String,
      title: jsonSerialization['title'] as String,
      status: jsonSerialization['status'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String defectId;

  String title;

  /// Durable `DefectStatus` wire value.
  String status;

  DateTime createdAt;

  /// Returns a shallow copy of this [DefectCreatedView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectCreatedView copyWith({
    String? defectId,
    String? title,
    String? status,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectCreatedView',
      'defectId': defectId,
      'title': title,
      'status': status,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DefectCreatedViewImpl extends DefectCreatedView {
  _DefectCreatedViewImpl({
    required String defectId,
    required String title,
    required String status,
    required DateTime createdAt,
  }) : super._(
         defectId: defectId,
         title: title,
         status: status,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DefectCreatedView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectCreatedView copyWith({
    String? defectId,
    String? title,
    String? status,
    DateTime? createdAt,
  }) {
    return DefectCreatedView(
      defectId: defectId ?? this.defectId,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

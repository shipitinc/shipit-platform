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

/// One file an agent changed. Shared by the agent result and the worker result.
abstract class ChangedFileView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ChangedFileView._({
    required this.path,
    required this.operation,
    this.beforeSha,
    this.afterSha,
  });

  factory ChangedFileView({
    required String path,
    required String operation,
    String? beforeSha,
    String? afterSha,
  }) = _ChangedFileViewImpl;

  factory ChangedFileView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChangedFileView(
      path: jsonSerialization['path'] as String,
      operation: jsonSerialization['operation'] as String,
      beforeSha: jsonSerialization['beforeSha'] as String?,
      afterSha: jsonSerialization['afterSha'] as String?,
    );
  }

  String path;

  /// Durable `ChangedFileOperation` wire value.
  String operation;

  String? beforeSha;

  String? afterSha;

  /// Returns a shallow copy of this [ChangedFileView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ChangedFileView copyWith({
    String? path,
    String? operation,
    String? beforeSha,
    String? afterSha,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChangedFileView',
      'path': path,
      'operation': operation,
      if (beforeSha != null) 'beforeSha': beforeSha,
      if (afterSha != null) 'afterSha': afterSha,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChangedFileView',
      'path': path,
      'operation': operation,
      if (beforeSha != null) 'beforeSha': beforeSha,
      if (afterSha != null) 'afterSha': afterSha,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChangedFileViewImpl extends ChangedFileView {
  _ChangedFileViewImpl({
    required String path,
    required String operation,
    String? beforeSha,
    String? afterSha,
  }) : super._(
         path: path,
         operation: operation,
         beforeSha: beforeSha,
         afterSha: afterSha,
       );

  /// Returns a shallow copy of this [ChangedFileView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ChangedFileView copyWith({
    String? path,
    String? operation,
    Object? beforeSha = _Undefined,
    Object? afterSha = _Undefined,
  }) {
    return ChangedFileView(
      path: path ?? this.path,
      operation: operation ?? this.operation,
      beforeSha: beforeSha is String? ? beforeSha : this.beforeSha,
      afterSha: afterSha is String? ? afterSha : this.afterSha,
    );
  }
}

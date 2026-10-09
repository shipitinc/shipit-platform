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

/// WHY THIS MODEL EXISTS — and why it is the FIRST one.
///
/// `productRegistryEndpoints.addRepositoryReference` returned
/// `Future<Map<String, dynamic>>` carrying the non-empty body
/// `{'success': true, 'repositoryId': …}` and the Add Product flow calls it
/// immediately BEFORE `credentialEndpoints.generate`
/// (`add_product_page.dart:143 -> _ensureProductAndRepository:281`, then `:147`).
/// A non-empty map response makes the generated client's
/// `Protocol.deserialize<Map<String, dynamic>>` call `deserialize<dynamic>` on
/// each value, for which Serverpod registers nothing, so the browser dies with
/// `No deserialization found for type dynamic` at THAT call and the deploy key
/// is never minted. An EMPTY map deserialises fine — which is why the defect
/// presents as intermittent and gets blamed on the wrong endpoint.
abstract class RepositoryReferenceAddedView implements _i1.SerializableModel {
  RepositoryReferenceAddedView._({
    required this.success,
    required this.repositoryId,
  });

  factory RepositoryReferenceAddedView({
    required bool success,
    required String repositoryId,
  }) = _RepositoryReferenceAddedViewImpl;

  factory RepositoryReferenceAddedView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RepositoryReferenceAddedView(
      success: _i1.BoolJsonExtension.fromJson(jsonSerialization['success']),
      repositoryId: jsonSerialization['repositoryId'] as String,
    );
  }

  /// Always true. The endpoint either returns this view or rethrows.
  bool success;

  /// The repository reference that was written. `repositoryId`, not the URI:
  /// the durable identifier the mint is later scoped by.
  String repositoryId;

  /// Returns a shallow copy of this [RepositoryReferenceAddedView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RepositoryReferenceAddedView copyWith({
    bool? success,
    String? repositoryId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RepositoryReferenceAddedView',
      'success': success,
      'repositoryId': repositoryId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _RepositoryReferenceAddedViewImpl extends RepositoryReferenceAddedView {
  _RepositoryReferenceAddedViewImpl({
    required bool success,
    required String repositoryId,
  }) : super._(
         success: success,
         repositoryId: repositoryId,
       );

  /// Returns a shallow copy of this [RepositoryReferenceAddedView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RepositoryReferenceAddedView copyWith({
    bool? success,
    String? repositoryId,
  }) {
    return RepositoryReferenceAddedView(
      success: success ?? this.success,
      repositoryId: repositoryId ?? this.repositoryId,
    );
  }
}

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

/// One `groupBy` bucket of `getModelStats`.
abstract class ModelStatsGroupView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ModelStatsGroupView._({
    required this.groupKey,
    required this.count,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalTokens,
    required this.totalCachedReadTokens,
    required this.totalCostUsd,
    required this.avgCostUsd,
    required this.successCount,
    required this.failureCount,
  });

  factory ModelStatsGroupView({
    required String groupKey,
    required int count,
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalTokens,
    required int totalCachedReadTokens,
    required double totalCostUsd,
    required double avgCostUsd,
    required int successCount,
    required int failureCount,
  }) = _ModelStatsGroupViewImpl;

  factory ModelStatsGroupView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ModelStatsGroupView(
      groupKey: jsonSerialization['groupKey'] as String,
      count: jsonSerialization['count'] as int,
      totalInputTokens: jsonSerialization['totalInputTokens'] as int,
      totalOutputTokens: jsonSerialization['totalOutputTokens'] as int,
      totalTokens: jsonSerialization['totalTokens'] as int,
      totalCachedReadTokens: jsonSerialization['totalCachedReadTokens'] as int,
      totalCostUsd: (jsonSerialization['totalCostUsd'] as num).toDouble(),
      avgCostUsd: (jsonSerialization['avgCostUsd'] as num).toDouble(),
      successCount: jsonSerialization['successCount'] as int,
      failureCount: jsonSerialization['failureCount'] as int,
    );
  }

  String groupKey;

  int count;

  int totalInputTokens;

  int totalOutputTokens;

  int totalTokens;

  int totalCachedReadTokens;

  double totalCostUsd;

  double avgCostUsd;

  int successCount;

  int failureCount;

  /// Returns a shallow copy of this [ModelStatsGroupView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelStatsGroupView copyWith({
    String? groupKey,
    int? count,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalTokens,
    int? totalCachedReadTokens,
    double? totalCostUsd,
    double? avgCostUsd,
    int? successCount,
    int? failureCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelStatsGroupView',
      'groupKey': groupKey,
      'count': count,
      'totalInputTokens': totalInputTokens,
      'totalOutputTokens': totalOutputTokens,
      'totalTokens': totalTokens,
      'totalCachedReadTokens': totalCachedReadTokens,
      'totalCostUsd': totalCostUsd,
      'avgCostUsd': avgCostUsd,
      'successCount': successCount,
      'failureCount': failureCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ModelStatsGroupView',
      'groupKey': groupKey,
      'count': count,
      'totalInputTokens': totalInputTokens,
      'totalOutputTokens': totalOutputTokens,
      'totalTokens': totalTokens,
      'totalCachedReadTokens': totalCachedReadTokens,
      'totalCostUsd': totalCostUsd,
      'avgCostUsd': avgCostUsd,
      'successCount': successCount,
      'failureCount': failureCount,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ModelStatsGroupViewImpl extends ModelStatsGroupView {
  _ModelStatsGroupViewImpl({
    required String groupKey,
    required int count,
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalTokens,
    required int totalCachedReadTokens,
    required double totalCostUsd,
    required double avgCostUsd,
    required int successCount,
    required int failureCount,
  }) : super._(
         groupKey: groupKey,
         count: count,
         totalInputTokens: totalInputTokens,
         totalOutputTokens: totalOutputTokens,
         totalTokens: totalTokens,
         totalCachedReadTokens: totalCachedReadTokens,
         totalCostUsd: totalCostUsd,
         avgCostUsd: avgCostUsd,
         successCount: successCount,
         failureCount: failureCount,
       );

  /// Returns a shallow copy of this [ModelStatsGroupView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelStatsGroupView copyWith({
    String? groupKey,
    int? count,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalTokens,
    int? totalCachedReadTokens,
    double? totalCostUsd,
    double? avgCostUsd,
    int? successCount,
    int? failureCount,
  }) {
    return ModelStatsGroupView(
      groupKey: groupKey ?? this.groupKey,
      count: count ?? this.count,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      totalCachedReadTokens:
          totalCachedReadTokens ?? this.totalCachedReadTokens,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      avgCostUsd: avgCostUsd ?? this.avgCostUsd,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
    );
  }
}

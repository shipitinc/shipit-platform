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
import 'model_stats_group_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// `providerHealthEndpoints.getModelStats` returned a raw map. Typed.
abstract class ModelStatsView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ModelStatsView._({
    required this.count,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalTokens,
    required this.totalCachedReadTokens,
    required this.totalCostUsd,
    required this.avgCostUsd,
    required this.successCount,
    required this.failureCount,
    required this.byGroup,
  });

  factory ModelStatsView({
    required int count,
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalTokens,
    required int totalCachedReadTokens,
    required double totalCostUsd,
    required double avgCostUsd,
    required int successCount,
    required int failureCount,
    required List<_i2.ModelStatsGroupView> byGroup,
  }) = _ModelStatsViewImpl;

  factory ModelStatsView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ModelStatsView(
      count: jsonSerialization['count'] as int,
      totalInputTokens: jsonSerialization['totalInputTokens'] as int,
      totalOutputTokens: jsonSerialization['totalOutputTokens'] as int,
      totalTokens: jsonSerialization['totalTokens'] as int,
      totalCachedReadTokens: jsonSerialization['totalCachedReadTokens'] as int,
      totalCostUsd: (jsonSerialization['totalCostUsd'] as num).toDouble(),
      avgCostUsd: (jsonSerialization['avgCostUsd'] as num).toDouble(),
      successCount: jsonSerialization['successCount'] as int,
      failureCount: jsonSerialization['failureCount'] as int,
      byGroup: _i3.Protocol().deserialize<List<_i2.ModelStatsGroupView>>(
        jsonSerialization['byGroup'],
      ),
    );
  }

  int count;

  int totalInputTokens;

  int totalOutputTokens;

  int totalTokens;

  int totalCachedReadTokens;

  double totalCostUsd;

  double avgCostUsd;

  int successCount;

  int failureCount;

  List<_i2.ModelStatsGroupView> byGroup;

  /// Returns a shallow copy of this [ModelStatsView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelStatsView copyWith({
    int? count,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalTokens,
    int? totalCachedReadTokens,
    double? totalCostUsd,
    double? avgCostUsd,
    int? successCount,
    int? failureCount,
    List<_i2.ModelStatsGroupView>? byGroup,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelStatsView',
      'count': count,
      'totalInputTokens': totalInputTokens,
      'totalOutputTokens': totalOutputTokens,
      'totalTokens': totalTokens,
      'totalCachedReadTokens': totalCachedReadTokens,
      'totalCostUsd': totalCostUsd,
      'avgCostUsd': avgCostUsd,
      'successCount': successCount,
      'failureCount': failureCount,
      'byGroup': byGroup.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ModelStatsView',
      'count': count,
      'totalInputTokens': totalInputTokens,
      'totalOutputTokens': totalOutputTokens,
      'totalTokens': totalTokens,
      'totalCachedReadTokens': totalCachedReadTokens,
      'totalCostUsd': totalCostUsd,
      'avgCostUsd': avgCostUsd,
      'successCount': successCount,
      'failureCount': failureCount,
      'byGroup': byGroup.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ModelStatsViewImpl extends ModelStatsView {
  _ModelStatsViewImpl({
    required int count,
    required int totalInputTokens,
    required int totalOutputTokens,
    required int totalTokens,
    required int totalCachedReadTokens,
    required double totalCostUsd,
    required double avgCostUsd,
    required int successCount,
    required int failureCount,
    required List<_i2.ModelStatsGroupView> byGroup,
  }) : super._(
         count: count,
         totalInputTokens: totalInputTokens,
         totalOutputTokens: totalOutputTokens,
         totalTokens: totalTokens,
         totalCachedReadTokens: totalCachedReadTokens,
         totalCostUsd: totalCostUsd,
         avgCostUsd: avgCostUsd,
         successCount: successCount,
         failureCount: failureCount,
         byGroup: byGroup,
       );

  /// Returns a shallow copy of this [ModelStatsView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelStatsView copyWith({
    int? count,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalTokens,
    int? totalCachedReadTokens,
    double? totalCostUsd,
    double? avgCostUsd,
    int? successCount,
    int? failureCount,
    List<_i2.ModelStatsGroupView>? byGroup,
  }) {
    return ModelStatsView(
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
      byGroup: byGroup ?? this.byGroup.map((e0) => e0.copyWith()).toList(),
    );
  }
}

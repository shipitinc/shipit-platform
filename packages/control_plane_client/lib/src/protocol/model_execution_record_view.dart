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

/// `ModelExecutionRecord` as it travels.
abstract class ModelExecutionRecordView implements _i1.SerializableModel {
  ModelExecutionRecordView._({
    required this.workItemId,
    required this.jobId,
    required this.agentExecutionId,
    required this.role,
    required this.modelId,
    required this.provider,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.cachedReadTokens,
    required this.costUsd,
    required this.currency,
    required this.startedAt,
    required this.finishedAt,
    required this.success,
    this.error,
    required this.escalationIndex,
    required this.taskType,
  });

  factory ModelExecutionRecordView({
    required String workItemId,
    required String jobId,
    required String agentExecutionId,
    required String role,
    required String modelId,
    required String provider,
    required int inputTokens,
    required int outputTokens,
    required int totalTokens,
    required int cachedReadTokens,
    required double costUsd,
    required String currency,
    required DateTime startedAt,
    required DateTime finishedAt,
    required bool success,
    String? error,
    required int escalationIndex,
    required String taskType,
  }) = _ModelExecutionRecordViewImpl;

  factory ModelExecutionRecordView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ModelExecutionRecordView(
      workItemId: jsonSerialization['workItemId'] as String,
      jobId: jsonSerialization['jobId'] as String,
      agentExecutionId: jsonSerialization['agentExecutionId'] as String,
      role: jsonSerialization['role'] as String,
      modelId: jsonSerialization['modelId'] as String,
      provider: jsonSerialization['provider'] as String,
      inputTokens: jsonSerialization['inputTokens'] as int,
      outputTokens: jsonSerialization['outputTokens'] as int,
      totalTokens: jsonSerialization['totalTokens'] as int,
      cachedReadTokens: jsonSerialization['cachedReadTokens'] as int,
      costUsd: (jsonSerialization['costUsd'] as num).toDouble(),
      currency: jsonSerialization['currency'] as String,
      startedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startedAt'],
      ),
      finishedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['finishedAt'],
      ),
      success: _i1.BoolJsonExtension.fromJson(jsonSerialization['success']),
      error: jsonSerialization['error'] as String?,
      escalationIndex: jsonSerialization['escalationIndex'] as int,
      taskType: jsonSerialization['taskType'] as String,
    );
  }

  String workItemId;

  String jobId;

  String agentExecutionId;

  /// Durable `AgentRole` wire value.
  String role;

  String modelId;

  String provider;

  int inputTokens;

  int outputTokens;

  int totalTokens;

  int cachedReadTokens;

  double costUsd;

  String currency;

  DateTime startedAt;

  DateTime finishedAt;

  bool success;

  String? error;

  int escalationIndex;

  String taskType;

  /// Returns a shallow copy of this [ModelExecutionRecordView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelExecutionRecordView copyWith({
    String? workItemId,
    String? jobId,
    String? agentExecutionId,
    String? role,
    String? modelId,
    String? provider,
    int? inputTokens,
    int? outputTokens,
    int? totalTokens,
    int? cachedReadTokens,
    double? costUsd,
    String? currency,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? success,
    String? error,
    int? escalationIndex,
    String? taskType,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelExecutionRecordView',
      'workItemId': workItemId,
      'jobId': jobId,
      'agentExecutionId': agentExecutionId,
      'role': role,
      'modelId': modelId,
      'provider': provider,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'totalTokens': totalTokens,
      'cachedReadTokens': cachedReadTokens,
      'costUsd': costUsd,
      'currency': currency,
      'startedAt': startedAt.toJson(),
      'finishedAt': finishedAt.toJson(),
      'success': success,
      if (error != null) 'error': error,
      'escalationIndex': escalationIndex,
      'taskType': taskType,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ModelExecutionRecordViewImpl extends ModelExecutionRecordView {
  _ModelExecutionRecordViewImpl({
    required String workItemId,
    required String jobId,
    required String agentExecutionId,
    required String role,
    required String modelId,
    required String provider,
    required int inputTokens,
    required int outputTokens,
    required int totalTokens,
    required int cachedReadTokens,
    required double costUsd,
    required String currency,
    required DateTime startedAt,
    required DateTime finishedAt,
    required bool success,
    String? error,
    required int escalationIndex,
    required String taskType,
  }) : super._(
         workItemId: workItemId,
         jobId: jobId,
         agentExecutionId: agentExecutionId,
         role: role,
         modelId: modelId,
         provider: provider,
         inputTokens: inputTokens,
         outputTokens: outputTokens,
         totalTokens: totalTokens,
         cachedReadTokens: cachedReadTokens,
         costUsd: costUsd,
         currency: currency,
         startedAt: startedAt,
         finishedAt: finishedAt,
         success: success,
         error: error,
         escalationIndex: escalationIndex,
         taskType: taskType,
       );

  /// Returns a shallow copy of this [ModelExecutionRecordView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelExecutionRecordView copyWith({
    String? workItemId,
    String? jobId,
    String? agentExecutionId,
    String? role,
    String? modelId,
    String? provider,
    int? inputTokens,
    int? outputTokens,
    int? totalTokens,
    int? cachedReadTokens,
    double? costUsd,
    String? currency,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? success,
    Object? error = _Undefined,
    int? escalationIndex,
    String? taskType,
  }) {
    return ModelExecutionRecordView(
      workItemId: workItemId ?? this.workItemId,
      jobId: jobId ?? this.jobId,
      agentExecutionId: agentExecutionId ?? this.agentExecutionId,
      role: role ?? this.role,
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      cachedReadTokens: cachedReadTokens ?? this.cachedReadTokens,
      costUsd: costUsd ?? this.costUsd,
      currency: currency ?? this.currency,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      success: success ?? this.success,
      error: error is String? ? error : this.error,
      escalationIndex: escalationIndex ?? this.escalationIndex,
      taskType: taskType ?? this.taskType,
    );
  }
}

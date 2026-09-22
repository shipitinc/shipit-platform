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
import 'decision_context_view.dart' as _i2;
import 'decision_option_view.dart' as _i3;
import 'artifact_reference_view.dart' as _i4;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i5;

abstract class DecisionView implements _i1.SerializableModel {
  DecisionView._({
    required this.decisionId,
    required this.workItemId,
    required this.workItemTitle,
    this.workItemDescription,
    required this.decisionType,
    required this.status,
    this.question,
    this.context,
    this.options,
    this.recommendation,
    required this.blocking,
    this.requestedAt,
    this.expiration,
    this.artifactRefs,
    this.choice,
    this.decider,
    this.rationale,
    this.resolvedAt,
    this.signature,
  });

  factory DecisionView({
    required String decisionId,
    required String workItemId,
    required String workItemTitle,
    String? workItemDescription,
    required String decisionType,
    required String status,
    String? question,
    _i2.DecisionContextView? context,
    List<_i3.DecisionOptionView>? options,
    String? recommendation,
    required bool blocking,
    DateTime? requestedAt,
    DateTime? expiration,
    List<_i4.ArtifactReferenceView>? artifactRefs,
    String? choice,
    String? decider,
    String? rationale,
    DateTime? resolvedAt,
    String? signature,
  }) = _DecisionViewImpl;

  factory DecisionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DecisionView(
      decisionId: jsonSerialization['decisionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      workItemTitle: jsonSerialization['workItemTitle'] as String,
      workItemDescription: jsonSerialization['workItemDescription'] as String?,
      decisionType: jsonSerialization['decisionType'] as String,
      status: jsonSerialization['status'] as String,
      question: jsonSerialization['question'] as String?,
      context: jsonSerialization['context'] == null
          ? null
          : _i5.Protocol().deserialize<_i2.DecisionContextView>(
              jsonSerialization['context'],
            ),
      options: jsonSerialization['options'] == null
          ? null
          : _i5.Protocol().deserialize<List<_i3.DecisionOptionView>>(
              jsonSerialization['options'],
            ),
      recommendation: jsonSerialization['recommendation'] as String?,
      blocking: _i1.BoolJsonExtension.fromJson(jsonSerialization['blocking']),
      requestedAt: jsonSerialization['requestedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['requestedAt'],
            ),
      expiration: jsonSerialization['expiration'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['expiration']),
      artifactRefs: jsonSerialization['artifactRefs'] == null
          ? null
          : _i5.Protocol().deserialize<List<_i4.ArtifactReferenceView>>(
              jsonSerialization['artifactRefs'],
            ),
      choice: jsonSerialization['choice'] as String?,
      decider: jsonSerialization['decider'] as String?,
      rationale: jsonSerialization['rationale'] as String?,
      resolvedAt: jsonSerialization['resolvedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['resolvedAt']),
      signature: jsonSerialization['signature'] as String?,
    );
  }

  String decisionId;

  String workItemId;

  String workItemTitle;

  /// Plain-language description of the gated work item. The operator surface
  /// leads with this and keeps [workItemTitle] for technical details.
  String? workItemDescription;

  String decisionType;

  String status;

  String? question;

  _i2.DecisionContextView? context;

  List<_i3.DecisionOptionView>? options;

  String? recommendation;

  bool blocking;

  DateTime? requestedAt;

  DateTime? expiration;

  List<_i4.ArtifactReferenceView>? artifactRefs;

  String? choice;

  String? decider;

  String? rationale;

  DateTime? resolvedAt;

  String? signature;

  /// Returns a shallow copy of this [DecisionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DecisionView copyWith({
    String? decisionId,
    String? workItemId,
    String? workItemTitle,
    String? workItemDescription,
    String? decisionType,
    String? status,
    String? question,
    _i2.DecisionContextView? context,
    List<_i3.DecisionOptionView>? options,
    String? recommendation,
    bool? blocking,
    DateTime? requestedAt,
    DateTime? expiration,
    List<_i4.ArtifactReferenceView>? artifactRefs,
    String? choice,
    String? decider,
    String? rationale,
    DateTime? resolvedAt,
    String? signature,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DecisionView',
      'decisionId': decisionId,
      'workItemId': workItemId,
      'workItemTitle': workItemTitle,
      if (workItemDescription != null)
        'workItemDescription': workItemDescription,
      'decisionType': decisionType,
      'status': status,
      if (question != null) 'question': question,
      if (context != null) 'context': context?.toJson(),
      if (options != null)
        'options': options?.toJson(valueToJson: (v) => v.toJson()),
      if (recommendation != null) 'recommendation': recommendation,
      'blocking': blocking,
      if (requestedAt != null) 'requestedAt': requestedAt?.toJson(),
      if (expiration != null) 'expiration': expiration?.toJson(),
      if (artifactRefs != null)
        'artifactRefs': artifactRefs?.toJson(valueToJson: (v) => v.toJson()),
      if (choice != null) 'choice': choice,
      if (decider != null) 'decider': decider,
      if (rationale != null) 'rationale': rationale,
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (signature != null) 'signature': signature,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DecisionViewImpl extends DecisionView {
  _DecisionViewImpl({
    required String decisionId,
    required String workItemId,
    required String workItemTitle,
    String? workItemDescription,
    required String decisionType,
    required String status,
    String? question,
    _i2.DecisionContextView? context,
    List<_i3.DecisionOptionView>? options,
    String? recommendation,
    required bool blocking,
    DateTime? requestedAt,
    DateTime? expiration,
    List<_i4.ArtifactReferenceView>? artifactRefs,
    String? choice,
    String? decider,
    String? rationale,
    DateTime? resolvedAt,
    String? signature,
  }) : super._(
         decisionId: decisionId,
         workItemId: workItemId,
         workItemTitle: workItemTitle,
         workItemDescription: workItemDescription,
         decisionType: decisionType,
         status: status,
         question: question,
         context: context,
         options: options,
         recommendation: recommendation,
         blocking: blocking,
         requestedAt: requestedAt,
         expiration: expiration,
         artifactRefs: artifactRefs,
         choice: choice,
         decider: decider,
         rationale: rationale,
         resolvedAt: resolvedAt,
         signature: signature,
       );

  /// Returns a shallow copy of this [DecisionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DecisionView copyWith({
    String? decisionId,
    String? workItemId,
    String? workItemTitle,
    Object? workItemDescription = _Undefined,
    String? decisionType,
    String? status,
    Object? question = _Undefined,
    Object? context = _Undefined,
    Object? options = _Undefined,
    Object? recommendation = _Undefined,
    bool? blocking,
    Object? requestedAt = _Undefined,
    Object? expiration = _Undefined,
    Object? artifactRefs = _Undefined,
    Object? choice = _Undefined,
    Object? decider = _Undefined,
    Object? rationale = _Undefined,
    Object? resolvedAt = _Undefined,
    Object? signature = _Undefined,
  }) {
    return DecisionView(
      decisionId: decisionId ?? this.decisionId,
      workItemId: workItemId ?? this.workItemId,
      workItemTitle: workItemTitle ?? this.workItemTitle,
      workItemDescription: workItemDescription is String?
          ? workItemDescription
          : this.workItemDescription,
      decisionType: decisionType ?? this.decisionType,
      status: status ?? this.status,
      question: question is String? ? question : this.question,
      context: context is _i2.DecisionContextView?
          ? context
          : this.context?.copyWith(),
      options: options is List<_i3.DecisionOptionView>?
          ? options
          : this.options?.map((e0) => e0.copyWith()).toList(),
      recommendation: recommendation is String?
          ? recommendation
          : this.recommendation,
      blocking: blocking ?? this.blocking,
      requestedAt: requestedAt is DateTime? ? requestedAt : this.requestedAt,
      expiration: expiration is DateTime? ? expiration : this.expiration,
      artifactRefs: artifactRefs is List<_i4.ArtifactReferenceView>?
          ? artifactRefs
          : this.artifactRefs?.map((e0) => e0.copyWith()).toList(),
      choice: choice is String? ? choice : this.choice,
      decider: decider is String? ? decider : this.decider,
      rationale: rationale is String? ? rationale : this.rationale,
      resolvedAt: resolvedAt is DateTime? ? resolvedAt : this.resolvedAt,
      signature: signature is String? ? signature : this.signature,
    );
  }
}

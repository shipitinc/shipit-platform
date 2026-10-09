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
import 'artifact_reference_view.dart' as _i2;
import 'baseline_fact_view.dart' as _i3;
import 'clarification_view.dart' as _i4;
import 'credential_access_verification_view.dart' as _i5;
import 'decision_context_view.dart' as _i6;
import 'decision_option_view.dart' as _i7;
import 'decision_view.dart' as _i8;
import 'feature_request_summary_view.dart' as _i9;
import 'human_direction_attachment_view.dart' as _i10;
import 'human_direction_payload_view.dart' as _i11;
import 'human_direction_view.dart' as _i12;
import 'job_summary_view.dart' as _i13;
import 'minted_credential_view.dart' as _i14;
import 'overview.dart' as _i15;
import 'product_baseline_view.dart' as _i16;
import 'product_context_view.dart' as _i17;
import 'product_detail_view.dart' as _i18;
import 'product_summary_view.dart' as _i19;
import 'product_view.dart' as _i20;
import 'repository_credential_view.dart' as _i21;
import 'repository_reference_view.dart' as _i22;
import 'resolve_decision_view.dart' as _i23;
import 'standing_policy_view.dart' as _i24;
import 'transition_view.dart' as _i25;
import 'work_item_detail_view.dart' as _i26;
import 'work_item_view.dart' as _i27;
import 'package:control_plane_client/src/protocol/work_item_view.dart' as _i28;
import 'package:control_plane_client/src/protocol/decision_view.dart' as _i29;
import 'package:control_plane_client/src/protocol/human_direction_attachment_view.dart'
    as _i30;
import 'package:control_plane_client/src/protocol/human_direction_view.dart'
    as _i31;
import 'package:control_plane_client/src/protocol/feature_request_summary_view.dart'
    as _i32;
import 'package:control_plane_client/src/protocol/product_view.dart' as _i33;
import 'package:control_plane_client/src/protocol/product_summary_view.dart'
    as _i34;
import 'package:platform_contracts/src/types/baseline_fact.dart' as _i35;
import 'package:control_plane_client/src/protocol/job_summary_view.dart'
    as _i36;
export 'artifact_reference_view.dart';
export 'baseline_fact_view.dart';
export 'clarification_view.dart';
export 'credential_access_verification_view.dart';
export 'decision_context_view.dart';
export 'decision_option_view.dart';
export 'decision_view.dart';
export 'feature_request_summary_view.dart';
export 'human_direction_attachment_view.dart';
export 'human_direction_payload_view.dart';
export 'human_direction_view.dart';
export 'job_summary_view.dart';
export 'minted_credential_view.dart';
export 'overview.dart';
export 'product_baseline_view.dart';
export 'product_context_view.dart';
export 'product_detail_view.dart';
export 'product_summary_view.dart';
export 'product_view.dart';
export 'repository_credential_view.dart';
export 'repository_reference_view.dart';
export 'resolve_decision_view.dart';
export 'standing_policy_view.dart';
export 'transition_view.dart';
export 'work_item_detail_view.dart';
export 'work_item_view.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i2.ArtifactReferenceView) {
      return _i2.ArtifactReferenceView.fromJson(data) as T;
    }
    if (t == _i3.BaselineFactView) {
      return _i3.BaselineFactView.fromJson(data) as T;
    }
    if (t == _i4.ClarificationView) {
      return _i4.ClarificationView.fromJson(data) as T;
    }
    if (t == _i5.CredentialAccessVerificationView) {
      return _i5.CredentialAccessVerificationView.fromJson(data) as T;
    }
    if (t == _i6.DecisionContextView) {
      return _i6.DecisionContextView.fromJson(data) as T;
    }
    if (t == _i7.DecisionOptionView) {
      return _i7.DecisionOptionView.fromJson(data) as T;
    }
    if (t == _i8.DecisionView) {
      return _i8.DecisionView.fromJson(data) as T;
    }
    if (t == _i9.FeatureRequestSummaryView) {
      return _i9.FeatureRequestSummaryView.fromJson(data) as T;
    }
    if (t == _i10.HumanDirectionAttachmentView) {
      return _i10.HumanDirectionAttachmentView.fromJson(data) as T;
    }
    if (t == _i11.HumanDirectionPayloadView) {
      return _i11.HumanDirectionPayloadView.fromJson(data) as T;
    }
    if (t == _i12.HumanDirectionView) {
      return _i12.HumanDirectionView.fromJson(data) as T;
    }
    if (t == _i13.JobSummaryView) {
      return _i13.JobSummaryView.fromJson(data) as T;
    }
    if (t == _i14.MintedCredentialView) {
      return _i14.MintedCredentialView.fromJson(data) as T;
    }
    if (t == _i15.Overview) {
      return _i15.Overview.fromJson(data) as T;
    }
    if (t == _i16.ProductBaselineView) {
      return _i16.ProductBaselineView.fromJson(data) as T;
    }
    if (t == _i17.ProductContextView) {
      return _i17.ProductContextView.fromJson(data) as T;
    }
    if (t == _i18.ProductDetailView) {
      return _i18.ProductDetailView.fromJson(data) as T;
    }
    if (t == _i19.ProductSummaryView) {
      return _i19.ProductSummaryView.fromJson(data) as T;
    }
    if (t == _i20.ProductView) {
      return _i20.ProductView.fromJson(data) as T;
    }
    if (t == _i21.RepositoryCredentialView) {
      return _i21.RepositoryCredentialView.fromJson(data) as T;
    }
    if (t == _i22.RepositoryReferenceView) {
      return _i22.RepositoryReferenceView.fromJson(data) as T;
    }
    if (t == _i23.ResolveDecisionView) {
      return _i23.ResolveDecisionView.fromJson(data) as T;
    }
    if (t == _i24.StandingPolicyView) {
      return _i24.StandingPolicyView.fromJson(data) as T;
    }
    if (t == _i25.TransitionView) {
      return _i25.TransitionView.fromJson(data) as T;
    }
    if (t == _i26.WorkItemDetailView) {
      return _i26.WorkItemDetailView.fromJson(data) as T;
    }
    if (t == _i27.WorkItemView) {
      return _i27.WorkItemView.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.ArtifactReferenceView?>()) {
      return (data != null ? _i2.ArtifactReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i3.BaselineFactView?>()) {
      return (data != null ? _i3.BaselineFactView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.ClarificationView?>()) {
      return (data != null ? _i4.ClarificationView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.CredentialAccessVerificationView?>()) {
      return (data != null
              ? _i5.CredentialAccessVerificationView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i6.DecisionContextView?>()) {
      return (data != null ? _i6.DecisionContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i7.DecisionOptionView?>()) {
      return (data != null ? _i7.DecisionOptionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.DecisionView?>()) {
      return (data != null ? _i8.DecisionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.FeatureRequestSummaryView?>()) {
      return (data != null
              ? _i9.FeatureRequestSummaryView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i10.HumanDirectionAttachmentView?>()) {
      return (data != null
              ? _i10.HumanDirectionAttachmentView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i11.HumanDirectionPayloadView?>()) {
      return (data != null
              ? _i11.HumanDirectionPayloadView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i12.HumanDirectionView?>()) {
      return (data != null ? _i12.HumanDirectionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i13.JobSummaryView?>()) {
      return (data != null ? _i13.JobSummaryView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.MintedCredentialView?>()) {
      return (data != null ? _i14.MintedCredentialView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i15.Overview?>()) {
      return (data != null ? _i15.Overview.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.ProductBaselineView?>()) {
      return (data != null ? _i16.ProductBaselineView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i17.ProductContextView?>()) {
      return (data != null ? _i17.ProductContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i18.ProductDetailView?>()) {
      return (data != null ? _i18.ProductDetailView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i19.ProductSummaryView?>()) {
      return (data != null ? _i19.ProductSummaryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i20.ProductView?>()) {
      return (data != null ? _i20.ProductView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i21.RepositoryCredentialView?>()) {
      return (data != null
              ? _i21.RepositoryCredentialView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i22.RepositoryReferenceView?>()) {
      return (data != null ? _i22.RepositoryReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i23.ResolveDecisionView?>()) {
      return (data != null ? _i23.ResolveDecisionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i24.StandingPolicyView?>()) {
      return (data != null ? _i24.StandingPolicyView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i25.TransitionView?>()) {
      return (data != null ? _i25.TransitionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i26.WorkItemDetailView?>()) {
      return (data != null ? _i26.WorkItemDetailView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i27.WorkItemView?>()) {
      return (data != null ? _i27.WorkItemView.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i7.DecisionOptionView>) {
      return (data as List)
              .map((e) => deserialize<_i7.DecisionOptionView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i7.DecisionOptionView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i7.DecisionOptionView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i2.ArtifactReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i2.ArtifactReferenceView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i2.ArtifactReferenceView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i2.ArtifactReferenceView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i10.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i10.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i10.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i10.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i13.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i13.JobSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i3.BaselineFactView>) {
      return (data as List)
              .map((e) => deserialize<_i3.BaselineFactView>(e))
              .toList()
          as T;
    }
    if (t == List<_i22.RepositoryReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i22.RepositoryReferenceView>(e))
              .toList()
          as T;
    }
    if (t == List<_i16.ProductBaselineView>) {
      return (data as List)
              .map((e) => deserialize<_i16.ProductBaselineView>(e))
              .toList()
          as T;
    }
    if (t == List<_i4.ClarificationView>) {
      return (data as List)
              .map((e) => deserialize<_i4.ClarificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i21.RepositoryCredentialView>) {
      return (data as List)
              .map((e) => deserialize<_i21.RepositoryCredentialView>(e))
              .toList()
          as T;
    }
    if (t == List<_i24.StandingPolicyView>) {
      return (data as List)
              .map((e) => deserialize<_i24.StandingPolicyView>(e))
              .toList()
          as T;
    }
    if (t == List<_i25.TransitionView>) {
      return (data as List)
              .map((e) => deserialize<_i25.TransitionView>(e))
              .toList()
          as T;
    }
    if (t == Map<String, dynamic>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)),
          )
          as T;
    }
    if (t == List<_i28.WorkItemView>) {
      return (data as List)
              .map((e) => deserialize<_i28.WorkItemView>(e))
              .toList()
          as T;
    }
    if (t == List<_i29.DecisionView>) {
      return (data as List)
              .map((e) => deserialize<_i29.DecisionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i30.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i30.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i30.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i30.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i31.HumanDirectionView>) {
      return (data as List)
              .map((e) => deserialize<_i31.HumanDirectionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i32.FeatureRequestSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i32.FeatureRequestSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i33.ProductView>) {
      return (data as List)
              .map((e) => deserialize<_i33.ProductView>(e))
              .toList()
          as T;
    }
    if (t == List<_i34.ProductSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i34.ProductSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i35.BaselineFact>) {
      return (data as List)
              .map((e) => deserialize<_i35.BaselineFact>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == _i1.getType<List<String>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<String>(e)).toList()
              : null)
          as T;
    }
    if (t == List<_i36.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i36.JobSummaryView>(e))
              .toList()
          as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.ArtifactReferenceView => 'ArtifactReferenceView',
      _i3.BaselineFactView => 'BaselineFactView',
      _i4.ClarificationView => 'ClarificationView',
      _i5.CredentialAccessVerificationView =>
        'CredentialAccessVerificationView',
      _i6.DecisionContextView => 'DecisionContextView',
      _i7.DecisionOptionView => 'DecisionOptionView',
      _i8.DecisionView => 'DecisionView',
      _i9.FeatureRequestSummaryView => 'FeatureRequestSummaryView',
      _i10.HumanDirectionAttachmentView => 'HumanDirectionAttachmentView',
      _i11.HumanDirectionPayloadView => 'HumanDirectionPayloadView',
      _i12.HumanDirectionView => 'HumanDirectionView',
      _i13.JobSummaryView => 'JobSummaryView',
      _i14.MintedCredentialView => 'MintedCredentialView',
      _i15.Overview => 'Overview',
      _i16.ProductBaselineView => 'ProductBaselineView',
      _i17.ProductContextView => 'ProductContextView',
      _i18.ProductDetailView => 'ProductDetailView',
      _i19.ProductSummaryView => 'ProductSummaryView',
      _i20.ProductView => 'ProductView',
      _i21.RepositoryCredentialView => 'RepositoryCredentialView',
      _i22.RepositoryReferenceView => 'RepositoryReferenceView',
      _i23.ResolveDecisionView => 'ResolveDecisionView',
      _i24.StandingPolicyView => 'StandingPolicyView',
      _i25.TransitionView => 'TransitionView',
      _i26.WorkItemDetailView => 'WorkItemDetailView',
      _i27.WorkItemView => 'WorkItemView',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'control_plane.',
        '',
      );
    }

    switch (data) {
      case _i2.ArtifactReferenceView():
        return 'ArtifactReferenceView';
      case _i3.BaselineFactView():
        return 'BaselineFactView';
      case _i4.ClarificationView():
        return 'ClarificationView';
      case _i5.CredentialAccessVerificationView():
        return 'CredentialAccessVerificationView';
      case _i6.DecisionContextView():
        return 'DecisionContextView';
      case _i7.DecisionOptionView():
        return 'DecisionOptionView';
      case _i8.DecisionView():
        return 'DecisionView';
      case _i9.FeatureRequestSummaryView():
        return 'FeatureRequestSummaryView';
      case _i10.HumanDirectionAttachmentView():
        return 'HumanDirectionAttachmentView';
      case _i11.HumanDirectionPayloadView():
        return 'HumanDirectionPayloadView';
      case _i12.HumanDirectionView():
        return 'HumanDirectionView';
      case _i13.JobSummaryView():
        return 'JobSummaryView';
      case _i14.MintedCredentialView():
        return 'MintedCredentialView';
      case _i15.Overview():
        return 'Overview';
      case _i16.ProductBaselineView():
        return 'ProductBaselineView';
      case _i17.ProductContextView():
        return 'ProductContextView';
      case _i18.ProductDetailView():
        return 'ProductDetailView';
      case _i19.ProductSummaryView():
        return 'ProductSummaryView';
      case _i20.ProductView():
        return 'ProductView';
      case _i21.RepositoryCredentialView():
        return 'RepositoryCredentialView';
      case _i22.RepositoryReferenceView():
        return 'RepositoryReferenceView';
      case _i23.ResolveDecisionView():
        return 'ResolveDecisionView';
      case _i24.StandingPolicyView():
        return 'StandingPolicyView';
      case _i25.TransitionView():
        return 'TransitionView';
      case _i26.WorkItemDetailView():
        return 'WorkItemDetailView';
      case _i27.WorkItemView():
        return 'WorkItemView';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'ArtifactReferenceView') {
      return deserialize<_i2.ArtifactReferenceView>(data['data']);
    }
    if (dataClassName == 'BaselineFactView') {
      return deserialize<_i3.BaselineFactView>(data['data']);
    }
    if (dataClassName == 'ClarificationView') {
      return deserialize<_i4.ClarificationView>(data['data']);
    }
    if (dataClassName == 'CredentialAccessVerificationView') {
      return deserialize<_i5.CredentialAccessVerificationView>(data['data']);
    }
    if (dataClassName == 'DecisionContextView') {
      return deserialize<_i6.DecisionContextView>(data['data']);
    }
    if (dataClassName == 'DecisionOptionView') {
      return deserialize<_i7.DecisionOptionView>(data['data']);
    }
    if (dataClassName == 'DecisionView') {
      return deserialize<_i8.DecisionView>(data['data']);
    }
    if (dataClassName == 'FeatureRequestSummaryView') {
      return deserialize<_i9.FeatureRequestSummaryView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionAttachmentView') {
      return deserialize<_i10.HumanDirectionAttachmentView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionPayloadView') {
      return deserialize<_i11.HumanDirectionPayloadView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionView') {
      return deserialize<_i12.HumanDirectionView>(data['data']);
    }
    if (dataClassName == 'JobSummaryView') {
      return deserialize<_i13.JobSummaryView>(data['data']);
    }
    if (dataClassName == 'MintedCredentialView') {
      return deserialize<_i14.MintedCredentialView>(data['data']);
    }
    if (dataClassName == 'Overview') {
      return deserialize<_i15.Overview>(data['data']);
    }
    if (dataClassName == 'ProductBaselineView') {
      return deserialize<_i16.ProductBaselineView>(data['data']);
    }
    if (dataClassName == 'ProductContextView') {
      return deserialize<_i17.ProductContextView>(data['data']);
    }
    if (dataClassName == 'ProductDetailView') {
      return deserialize<_i18.ProductDetailView>(data['data']);
    }
    if (dataClassName == 'ProductSummaryView') {
      return deserialize<_i19.ProductSummaryView>(data['data']);
    }
    if (dataClassName == 'ProductView') {
      return deserialize<_i20.ProductView>(data['data']);
    }
    if (dataClassName == 'RepositoryCredentialView') {
      return deserialize<_i21.RepositoryCredentialView>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceView') {
      return deserialize<_i22.RepositoryReferenceView>(data['data']);
    }
    if (dataClassName == 'ResolveDecisionView') {
      return deserialize<_i23.ResolveDecisionView>(data['data']);
    }
    if (dataClassName == 'StandingPolicyView') {
      return deserialize<_i24.StandingPolicyView>(data['data']);
    }
    if (dataClassName == 'TransitionView') {
      return deserialize<_i25.TransitionView>(data['data']);
    }
    if (dataClassName == 'WorkItemDetailView') {
      return deserialize<_i26.WorkItemDetailView>(data['data']);
    }
    if (dataClassName == 'WorkItemView') {
      return deserialize<_i27.WorkItemView>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}

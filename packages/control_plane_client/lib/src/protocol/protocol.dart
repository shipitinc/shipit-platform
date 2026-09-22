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
import 'decision_context_view.dart' as _i5;
import 'decision_option_view.dart' as _i6;
import 'decision_view.dart' as _i7;
import 'job_summary_view.dart' as _i8;
import 'overview.dart' as _i9;
import 'product_baseline_view.dart' as _i10;
import 'product_context_view.dart' as _i11;
import 'product_detail_view.dart' as _i12;
import 'product_summary_view.dart' as _i13;
import 'product_view.dart' as _i14;
import 'repository_credential_view.dart' as _i15;
import 'repository_reference_view.dart' as _i16;
import 'resolve_decision_view.dart' as _i17;
import 'standing_policy_view.dart' as _i18;
import 'transition_view.dart' as _i19;
import 'work_item_detail_view.dart' as _i20;
import 'work_item_view.dart' as _i21;
import 'package:control_plane_client/src/protocol/work_item_view.dart' as _i22;
import 'package:control_plane_client/src/protocol/decision_view.dart' as _i23;
import 'package:control_plane_client/src/protocol/product_view.dart' as _i24;
import 'package:control_plane_client/src/protocol/product_summary_view.dart'
    as _i25;
import 'package:control_plane_client/src/protocol/job_summary_view.dart'
    as _i26;
export 'artifact_reference_view.dart';
export 'baseline_fact_view.dart';
export 'clarification_view.dart';
export 'decision_context_view.dart';
export 'decision_option_view.dart';
export 'decision_view.dart';
export 'job_summary_view.dart';
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
    if (t == _i5.DecisionContextView) {
      return _i5.DecisionContextView.fromJson(data) as T;
    }
    if (t == _i6.DecisionOptionView) {
      return _i6.DecisionOptionView.fromJson(data) as T;
    }
    if (t == _i7.DecisionView) {
      return _i7.DecisionView.fromJson(data) as T;
    }
    if (t == _i8.JobSummaryView) {
      return _i8.JobSummaryView.fromJson(data) as T;
    }
    if (t == _i9.Overview) {
      return _i9.Overview.fromJson(data) as T;
    }
    if (t == _i10.ProductBaselineView) {
      return _i10.ProductBaselineView.fromJson(data) as T;
    }
    if (t == _i11.ProductContextView) {
      return _i11.ProductContextView.fromJson(data) as T;
    }
    if (t == _i12.ProductDetailView) {
      return _i12.ProductDetailView.fromJson(data) as T;
    }
    if (t == _i13.ProductSummaryView) {
      return _i13.ProductSummaryView.fromJson(data) as T;
    }
    if (t == _i14.ProductView) {
      return _i14.ProductView.fromJson(data) as T;
    }
    if (t == _i15.RepositoryCredentialView) {
      return _i15.RepositoryCredentialView.fromJson(data) as T;
    }
    if (t == _i16.RepositoryReferenceView) {
      return _i16.RepositoryReferenceView.fromJson(data) as T;
    }
    if (t == _i17.ResolveDecisionView) {
      return _i17.ResolveDecisionView.fromJson(data) as T;
    }
    if (t == _i18.StandingPolicyView) {
      return _i18.StandingPolicyView.fromJson(data) as T;
    }
    if (t == _i19.TransitionView) {
      return _i19.TransitionView.fromJson(data) as T;
    }
    if (t == _i20.WorkItemDetailView) {
      return _i20.WorkItemDetailView.fromJson(data) as T;
    }
    if (t == _i21.WorkItemView) {
      return _i21.WorkItemView.fromJson(data) as T;
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
    if (t == _i1.getType<_i5.DecisionContextView?>()) {
      return (data != null ? _i5.DecisionContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i6.DecisionOptionView?>()) {
      return (data != null ? _i6.DecisionOptionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.DecisionView?>()) {
      return (data != null ? _i7.DecisionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.JobSummaryView?>()) {
      return (data != null ? _i8.JobSummaryView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.Overview?>()) {
      return (data != null ? _i9.Overview.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.ProductBaselineView?>()) {
      return (data != null ? _i10.ProductBaselineView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i11.ProductContextView?>()) {
      return (data != null ? _i11.ProductContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i12.ProductDetailView?>()) {
      return (data != null ? _i12.ProductDetailView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.ProductSummaryView?>()) {
      return (data != null ? _i13.ProductSummaryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i14.ProductView?>()) {
      return (data != null ? _i14.ProductView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.RepositoryCredentialView?>()) {
      return (data != null
              ? _i15.RepositoryCredentialView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i16.RepositoryReferenceView?>()) {
      return (data != null ? _i16.RepositoryReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i17.ResolveDecisionView?>()) {
      return (data != null ? _i17.ResolveDecisionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i18.StandingPolicyView?>()) {
      return (data != null ? _i18.StandingPolicyView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i19.TransitionView?>()) {
      return (data != null ? _i19.TransitionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i20.WorkItemDetailView?>()) {
      return (data != null ? _i20.WorkItemDetailView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i21.WorkItemView?>()) {
      return (data != null ? _i21.WorkItemView.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i6.DecisionOptionView>) {
      return (data as List)
              .map((e) => deserialize<_i6.DecisionOptionView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i6.DecisionOptionView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i6.DecisionOptionView>(e))
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
    if (t == List<_i8.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i8.JobSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i3.BaselineFactView>) {
      return (data as List)
              .map((e) => deserialize<_i3.BaselineFactView>(e))
              .toList()
          as T;
    }
    if (t == List<_i16.RepositoryReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i16.RepositoryReferenceView>(e))
              .toList()
          as T;
    }
    if (t == List<_i10.ProductBaselineView>) {
      return (data as List)
              .map((e) => deserialize<_i10.ProductBaselineView>(e))
              .toList()
          as T;
    }
    if (t == List<_i4.ClarificationView>) {
      return (data as List)
              .map((e) => deserialize<_i4.ClarificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i15.RepositoryCredentialView>) {
      return (data as List)
              .map((e) => deserialize<_i15.RepositoryCredentialView>(e))
              .toList()
          as T;
    }
    if (t == List<_i18.StandingPolicyView>) {
      return (data as List)
              .map((e) => deserialize<_i18.StandingPolicyView>(e))
              .toList()
          as T;
    }
    if (t == List<_i19.TransitionView>) {
      return (data as List)
              .map((e) => deserialize<_i19.TransitionView>(e))
              .toList()
          as T;
    }
    if (t == Map<String, dynamic>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)),
          )
          as T;
    }
    if (t == List<_i22.WorkItemView>) {
      return (data as List)
              .map((e) => deserialize<_i22.WorkItemView>(e))
              .toList()
          as T;
    }
    if (t == List<_i23.DecisionView>) {
      return (data as List)
              .map((e) => deserialize<_i23.DecisionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i24.ProductView>) {
      return (data as List)
              .map((e) => deserialize<_i24.ProductView>(e))
              .toList()
          as T;
    }
    if (t == List<_i25.ProductSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i25.ProductSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i26.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i26.JobSummaryView>(e))
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
      _i5.DecisionContextView => 'DecisionContextView',
      _i6.DecisionOptionView => 'DecisionOptionView',
      _i7.DecisionView => 'DecisionView',
      _i8.JobSummaryView => 'JobSummaryView',
      _i9.Overview => 'Overview',
      _i10.ProductBaselineView => 'ProductBaselineView',
      _i11.ProductContextView => 'ProductContextView',
      _i12.ProductDetailView => 'ProductDetailView',
      _i13.ProductSummaryView => 'ProductSummaryView',
      _i14.ProductView => 'ProductView',
      _i15.RepositoryCredentialView => 'RepositoryCredentialView',
      _i16.RepositoryReferenceView => 'RepositoryReferenceView',
      _i17.ResolveDecisionView => 'ResolveDecisionView',
      _i18.StandingPolicyView => 'StandingPolicyView',
      _i19.TransitionView => 'TransitionView',
      _i20.WorkItemDetailView => 'WorkItemDetailView',
      _i21.WorkItemView => 'WorkItemView',
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
      case _i5.DecisionContextView():
        return 'DecisionContextView';
      case _i6.DecisionOptionView():
        return 'DecisionOptionView';
      case _i7.DecisionView():
        return 'DecisionView';
      case _i8.JobSummaryView():
        return 'JobSummaryView';
      case _i9.Overview():
        return 'Overview';
      case _i10.ProductBaselineView():
        return 'ProductBaselineView';
      case _i11.ProductContextView():
        return 'ProductContextView';
      case _i12.ProductDetailView():
        return 'ProductDetailView';
      case _i13.ProductSummaryView():
        return 'ProductSummaryView';
      case _i14.ProductView():
        return 'ProductView';
      case _i15.RepositoryCredentialView():
        return 'RepositoryCredentialView';
      case _i16.RepositoryReferenceView():
        return 'RepositoryReferenceView';
      case _i17.ResolveDecisionView():
        return 'ResolveDecisionView';
      case _i18.StandingPolicyView():
        return 'StandingPolicyView';
      case _i19.TransitionView():
        return 'TransitionView';
      case _i20.WorkItemDetailView():
        return 'WorkItemDetailView';
      case _i21.WorkItemView():
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
    if (dataClassName == 'DecisionContextView') {
      return deserialize<_i5.DecisionContextView>(data['data']);
    }
    if (dataClassName == 'DecisionOptionView') {
      return deserialize<_i6.DecisionOptionView>(data['data']);
    }
    if (dataClassName == 'DecisionView') {
      return deserialize<_i7.DecisionView>(data['data']);
    }
    if (dataClassName == 'JobSummaryView') {
      return deserialize<_i8.JobSummaryView>(data['data']);
    }
    if (dataClassName == 'Overview') {
      return deserialize<_i9.Overview>(data['data']);
    }
    if (dataClassName == 'ProductBaselineView') {
      return deserialize<_i10.ProductBaselineView>(data['data']);
    }
    if (dataClassName == 'ProductContextView') {
      return deserialize<_i11.ProductContextView>(data['data']);
    }
    if (dataClassName == 'ProductDetailView') {
      return deserialize<_i12.ProductDetailView>(data['data']);
    }
    if (dataClassName == 'ProductSummaryView') {
      return deserialize<_i13.ProductSummaryView>(data['data']);
    }
    if (dataClassName == 'ProductView') {
      return deserialize<_i14.ProductView>(data['data']);
    }
    if (dataClassName == 'RepositoryCredentialView') {
      return deserialize<_i15.RepositoryCredentialView>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceView') {
      return deserialize<_i16.RepositoryReferenceView>(data['data']);
    }
    if (dataClassName == 'ResolveDecisionView') {
      return deserialize<_i17.ResolveDecisionView>(data['data']);
    }
    if (dataClassName == 'StandingPolicyView') {
      return deserialize<_i18.StandingPolicyView>(data['data']);
    }
    if (dataClassName == 'TransitionView') {
      return deserialize<_i19.TransitionView>(data['data']);
    }
    if (dataClassName == 'WorkItemDetailView') {
      return deserialize<_i20.WorkItemDetailView>(data['data']);
    }
    if (dataClassName == 'WorkItemView') {
      return deserialize<_i21.WorkItemView>(data['data']);
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

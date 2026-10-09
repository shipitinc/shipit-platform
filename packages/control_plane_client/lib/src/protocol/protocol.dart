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
import 'agent_artifact_view.dart' as _i2;
import 'agent_claimed_check_view.dart' as _i3;
import 'agent_diagnostics_view.dart' as _i4;
import 'agent_event_view.dart' as _i5;
import 'agent_execution_inspection_view.dart' as _i6;
import 'agent_execution_list_view.dart' as _i7;
import 'agent_execution_record_view.dart' as _i8;
import 'agent_result_view.dart' as _i9;
import 'agent_workspace_view.dart' as _i10;
import 'artifact_cache_entry_view.dart' as _i11;
import 'artifact_reference_view.dart' as _i12;
import 'baseline_fact_view.dart' as _i13;
import 'capability_spec_view.dart' as _i14;
import 'changed_file_view.dart' as _i15;
import 'clarification_view.dart' as _i16;
import 'credential_access_verification_view.dart' as _i17;
import 'decision_context_view.dart' as _i18;
import 'decision_option_view.dart' as _i19;
import 'decision_view.dart' as _i20;
import 'defect_clarification_request_view.dart' as _i21;
import 'defect_clarification_view.dart' as _i22;
import 'defect_created_view.dart' as _i23;
import 'defect_detail_view.dart' as _i24;
import 'defect_event_view.dart' as _i25;
import 'defect_evidence_view.dart' as _i26;
import 'defect_inspection_view.dart' as _i27;
import 'defect_list_view.dart' as _i28;
import 'defect_summary_view.dart' as _i29;
import 'diagnostic_entry_view.dart' as _i30;
import 'feature_request_created_view.dart' as _i31;
import 'feature_request_summary_view.dart' as _i32;
import 'fix_verification_view.dart' as _i33;
import 'health_status_view.dart' as _i34;
import 'human_direction_attachment_view.dart' as _i35;
import 'human_direction_payload_view.dart' as _i36;
import 'human_direction_view.dart' as _i37;
import 'job_claim_view.dart' as _i38;
import 'job_inspection_view.dart' as _i39;
import 'job_list_view.dart' as _i40;
import 'job_record_view.dart' as _i41;
import 'job_summary_view.dart' as _i42;
import 'minted_credential_view.dart' as _i43;
import 'model_execution_list_view.dart' as _i44;
import 'model_execution_record_view.dart' as _i45;
import 'model_policy_list_view.dart' as _i46;
import 'model_policy_view.dart' as _i47;
import 'model_stats_group_view.dart' as _i48;
import 'model_stats_view.dart' as _i49;
import 'model_step_view.dart' as _i50;
import 'overview.dart' as _i51;
import 'platform_verification_view.dart' as _i52;
import 'product_baseline_view.dart' as _i53;
import 'product_context_view.dart' as _i54;
import 'product_detail_view.dart' as _i55;
import 'product_summary_view.dart' as _i56;
import 'product_view.dart' as _i57;
import 'provider_health_view.dart' as _i58;
import 'provider_status_view.dart' as _i59;
import 'repository_credential_view.dart' as _i60;
import 'repository_reference_added_view.dart' as _i61;
import 'repository_reference_view.dart' as _i62;
import 'resolve_decision_view.dart' as _i63;
import 'resource_usage_view.dart' as _i64;
import 'scheduler_event_view.dart' as _i65;
import 'standing_policy_view.dart' as _i66;
import 'transition_view.dart' as _i67;
import 'triage_result_view.dart' as _i68;
import 'work_item_detail_view.dart' as _i69;
import 'work_item_view.dart' as _i70;
import 'worker_event_view.dart' as _i71;
import 'worker_execution_inspection_view.dart' as _i72;
import 'worker_execution_list_view.dart' as _i73;
import 'worker_execution_result_view.dart' as _i74;
import 'worker_execution_view.dart' as _i75;
import 'worker_list_view.dart' as _i76;
import 'worker_registration_view.dart' as _i77;
import 'package:control_plane_client/src/protocol/work_item_view.dart' as _i78;
import 'package:control_plane_client/src/protocol/decision_view.dart' as _i79;
import 'package:control_plane_client/src/protocol/human_direction_attachment_view.dart'
    as _i80;
import 'package:control_plane_client/src/protocol/human_direction_view.dart'
    as _i81;
import 'package:control_plane_client/src/protocol/feature_request_summary_view.dart'
    as _i82;
import 'package:control_plane_client/src/protocol/product_view.dart' as _i83;
import 'package:control_plane_client/src/protocol/product_summary_view.dart'
    as _i84;
import 'package:platform_contracts/src/types/baseline_fact.dart' as _i85;
import 'package:control_plane_client/src/protocol/job_summary_view.dart'
    as _i86;
export 'agent_artifact_view.dart';
export 'agent_claimed_check_view.dart';
export 'agent_diagnostics_view.dart';
export 'agent_event_view.dart';
export 'agent_execution_inspection_view.dart';
export 'agent_execution_list_view.dart';
export 'agent_execution_record_view.dart';
export 'agent_result_view.dart';
export 'agent_workspace_view.dart';
export 'artifact_cache_entry_view.dart';
export 'artifact_reference_view.dart';
export 'baseline_fact_view.dart';
export 'capability_spec_view.dart';
export 'changed_file_view.dart';
export 'clarification_view.dart';
export 'credential_access_verification_view.dart';
export 'decision_context_view.dart';
export 'decision_option_view.dart';
export 'decision_view.dart';
export 'defect_clarification_request_view.dart';
export 'defect_clarification_view.dart';
export 'defect_created_view.dart';
export 'defect_detail_view.dart';
export 'defect_event_view.dart';
export 'defect_evidence_view.dart';
export 'defect_inspection_view.dart';
export 'defect_list_view.dart';
export 'defect_summary_view.dart';
export 'diagnostic_entry_view.dart';
export 'feature_request_created_view.dart';
export 'feature_request_summary_view.dart';
export 'fix_verification_view.dart';
export 'health_status_view.dart';
export 'human_direction_attachment_view.dart';
export 'human_direction_payload_view.dart';
export 'human_direction_view.dart';
export 'job_claim_view.dart';
export 'job_inspection_view.dart';
export 'job_list_view.dart';
export 'job_record_view.dart';
export 'job_summary_view.dart';
export 'minted_credential_view.dart';
export 'model_execution_list_view.dart';
export 'model_execution_record_view.dart';
export 'model_policy_list_view.dart';
export 'model_policy_view.dart';
export 'model_stats_group_view.dart';
export 'model_stats_view.dart';
export 'model_step_view.dart';
export 'overview.dart';
export 'platform_verification_view.dart';
export 'product_baseline_view.dart';
export 'product_context_view.dart';
export 'product_detail_view.dart';
export 'product_summary_view.dart';
export 'product_view.dart';
export 'provider_health_view.dart';
export 'provider_status_view.dart';
export 'repository_credential_view.dart';
export 'repository_reference_added_view.dart';
export 'repository_reference_view.dart';
export 'resolve_decision_view.dart';
export 'resource_usage_view.dart';
export 'scheduler_event_view.dart';
export 'standing_policy_view.dart';
export 'transition_view.dart';
export 'triage_result_view.dart';
export 'work_item_detail_view.dart';
export 'work_item_view.dart';
export 'worker_event_view.dart';
export 'worker_execution_inspection_view.dart';
export 'worker_execution_list_view.dart';
export 'worker_execution_result_view.dart';
export 'worker_execution_view.dart';
export 'worker_list_view.dart';
export 'worker_registration_view.dart';
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

    if (t == _i2.AgentArtifactView) {
      return _i2.AgentArtifactView.fromJson(data) as T;
    }
    if (t == _i3.AgentClaimedCheckView) {
      return _i3.AgentClaimedCheckView.fromJson(data) as T;
    }
    if (t == _i4.AgentDiagnosticsView) {
      return _i4.AgentDiagnosticsView.fromJson(data) as T;
    }
    if (t == _i5.AgentEventView) {
      return _i5.AgentEventView.fromJson(data) as T;
    }
    if (t == _i6.AgentExecutionInspectionView) {
      return _i6.AgentExecutionInspectionView.fromJson(data) as T;
    }
    if (t == _i7.AgentExecutionListView) {
      return _i7.AgentExecutionListView.fromJson(data) as T;
    }
    if (t == _i8.AgentExecutionRecordView) {
      return _i8.AgentExecutionRecordView.fromJson(data) as T;
    }
    if (t == _i9.AgentResultView) {
      return _i9.AgentResultView.fromJson(data) as T;
    }
    if (t == _i10.AgentWorkspaceView) {
      return _i10.AgentWorkspaceView.fromJson(data) as T;
    }
    if (t == _i11.ArtifactCacheEntryView) {
      return _i11.ArtifactCacheEntryView.fromJson(data) as T;
    }
    if (t == _i12.ArtifactReferenceView) {
      return _i12.ArtifactReferenceView.fromJson(data) as T;
    }
    if (t == _i13.BaselineFactView) {
      return _i13.BaselineFactView.fromJson(data) as T;
    }
    if (t == _i14.CapabilitySpecView) {
      return _i14.CapabilitySpecView.fromJson(data) as T;
    }
    if (t == _i15.ChangedFileView) {
      return _i15.ChangedFileView.fromJson(data) as T;
    }
    if (t == _i16.ClarificationView) {
      return _i16.ClarificationView.fromJson(data) as T;
    }
    if (t == _i17.CredentialAccessVerificationView) {
      return _i17.CredentialAccessVerificationView.fromJson(data) as T;
    }
    if (t == _i18.DecisionContextView) {
      return _i18.DecisionContextView.fromJson(data) as T;
    }
    if (t == _i19.DecisionOptionView) {
      return _i19.DecisionOptionView.fromJson(data) as T;
    }
    if (t == _i20.DecisionView) {
      return _i20.DecisionView.fromJson(data) as T;
    }
    if (t == _i21.DefectClarificationRequestView) {
      return _i21.DefectClarificationRequestView.fromJson(data) as T;
    }
    if (t == _i22.DefectClarificationView) {
      return _i22.DefectClarificationView.fromJson(data) as T;
    }
    if (t == _i23.DefectCreatedView) {
      return _i23.DefectCreatedView.fromJson(data) as T;
    }
    if (t == _i24.DefectDetailView) {
      return _i24.DefectDetailView.fromJson(data) as T;
    }
    if (t == _i25.DefectEventView) {
      return _i25.DefectEventView.fromJson(data) as T;
    }
    if (t == _i26.DefectEvidenceView) {
      return _i26.DefectEvidenceView.fromJson(data) as T;
    }
    if (t == _i27.DefectInspectionView) {
      return _i27.DefectInspectionView.fromJson(data) as T;
    }
    if (t == _i28.DefectListView) {
      return _i28.DefectListView.fromJson(data) as T;
    }
    if (t == _i29.DefectSummaryView) {
      return _i29.DefectSummaryView.fromJson(data) as T;
    }
    if (t == _i30.DiagnosticEntryView) {
      return _i30.DiagnosticEntryView.fromJson(data) as T;
    }
    if (t == _i31.FeatureRequestCreatedView) {
      return _i31.FeatureRequestCreatedView.fromJson(data) as T;
    }
    if (t == _i32.FeatureRequestSummaryView) {
      return _i32.FeatureRequestSummaryView.fromJson(data) as T;
    }
    if (t == _i33.FixVerificationView) {
      return _i33.FixVerificationView.fromJson(data) as T;
    }
    if (t == _i34.HealthStatusView) {
      return _i34.HealthStatusView.fromJson(data) as T;
    }
    if (t == _i35.HumanDirectionAttachmentView) {
      return _i35.HumanDirectionAttachmentView.fromJson(data) as T;
    }
    if (t == _i36.HumanDirectionPayloadView) {
      return _i36.HumanDirectionPayloadView.fromJson(data) as T;
    }
    if (t == _i37.HumanDirectionView) {
      return _i37.HumanDirectionView.fromJson(data) as T;
    }
    if (t == _i38.JobClaimView) {
      return _i38.JobClaimView.fromJson(data) as T;
    }
    if (t == _i39.JobInspectionView) {
      return _i39.JobInspectionView.fromJson(data) as T;
    }
    if (t == _i40.JobListView) {
      return _i40.JobListView.fromJson(data) as T;
    }
    if (t == _i41.JobRecordView) {
      return _i41.JobRecordView.fromJson(data) as T;
    }
    if (t == _i42.JobSummaryView) {
      return _i42.JobSummaryView.fromJson(data) as T;
    }
    if (t == _i43.MintedCredentialView) {
      return _i43.MintedCredentialView.fromJson(data) as T;
    }
    if (t == _i44.ModelExecutionListView) {
      return _i44.ModelExecutionListView.fromJson(data) as T;
    }
    if (t == _i45.ModelExecutionRecordView) {
      return _i45.ModelExecutionRecordView.fromJson(data) as T;
    }
    if (t == _i46.ModelPolicyListView) {
      return _i46.ModelPolicyListView.fromJson(data) as T;
    }
    if (t == _i47.ModelPolicyView) {
      return _i47.ModelPolicyView.fromJson(data) as T;
    }
    if (t == _i48.ModelStatsGroupView) {
      return _i48.ModelStatsGroupView.fromJson(data) as T;
    }
    if (t == _i49.ModelStatsView) {
      return _i49.ModelStatsView.fromJson(data) as T;
    }
    if (t == _i50.ModelStepView) {
      return _i50.ModelStepView.fromJson(data) as T;
    }
    if (t == _i51.Overview) {
      return _i51.Overview.fromJson(data) as T;
    }
    if (t == _i52.PlatformVerificationView) {
      return _i52.PlatformVerificationView.fromJson(data) as T;
    }
    if (t == _i53.ProductBaselineView) {
      return _i53.ProductBaselineView.fromJson(data) as T;
    }
    if (t == _i54.ProductContextView) {
      return _i54.ProductContextView.fromJson(data) as T;
    }
    if (t == _i55.ProductDetailView) {
      return _i55.ProductDetailView.fromJson(data) as T;
    }
    if (t == _i56.ProductSummaryView) {
      return _i56.ProductSummaryView.fromJson(data) as T;
    }
    if (t == _i57.ProductView) {
      return _i57.ProductView.fromJson(data) as T;
    }
    if (t == _i58.ProviderHealthView) {
      return _i58.ProviderHealthView.fromJson(data) as T;
    }
    if (t == _i59.ProviderStatusView) {
      return _i59.ProviderStatusView.fromJson(data) as T;
    }
    if (t == _i60.RepositoryCredentialView) {
      return _i60.RepositoryCredentialView.fromJson(data) as T;
    }
    if (t == _i61.RepositoryReferenceAddedView) {
      return _i61.RepositoryReferenceAddedView.fromJson(data) as T;
    }
    if (t == _i62.RepositoryReferenceView) {
      return _i62.RepositoryReferenceView.fromJson(data) as T;
    }
    if (t == _i63.ResolveDecisionView) {
      return _i63.ResolveDecisionView.fromJson(data) as T;
    }
    if (t == _i64.ResourceUsageView) {
      return _i64.ResourceUsageView.fromJson(data) as T;
    }
    if (t == _i65.SchedulerEventView) {
      return _i65.SchedulerEventView.fromJson(data) as T;
    }
    if (t == _i66.StandingPolicyView) {
      return _i66.StandingPolicyView.fromJson(data) as T;
    }
    if (t == _i67.TransitionView) {
      return _i67.TransitionView.fromJson(data) as T;
    }
    if (t == _i68.TriageResultView) {
      return _i68.TriageResultView.fromJson(data) as T;
    }
    if (t == _i69.WorkItemDetailView) {
      return _i69.WorkItemDetailView.fromJson(data) as T;
    }
    if (t == _i70.WorkItemView) {
      return _i70.WorkItemView.fromJson(data) as T;
    }
    if (t == _i71.WorkerEventView) {
      return _i71.WorkerEventView.fromJson(data) as T;
    }
    if (t == _i72.WorkerExecutionInspectionView) {
      return _i72.WorkerExecutionInspectionView.fromJson(data) as T;
    }
    if (t == _i73.WorkerExecutionListView) {
      return _i73.WorkerExecutionListView.fromJson(data) as T;
    }
    if (t == _i74.WorkerExecutionResultView) {
      return _i74.WorkerExecutionResultView.fromJson(data) as T;
    }
    if (t == _i75.WorkerExecutionView) {
      return _i75.WorkerExecutionView.fromJson(data) as T;
    }
    if (t == _i76.WorkerListView) {
      return _i76.WorkerListView.fromJson(data) as T;
    }
    if (t == _i77.WorkerRegistrationView) {
      return _i77.WorkerRegistrationView.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.AgentArtifactView?>()) {
      return (data != null ? _i2.AgentArtifactView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.AgentClaimedCheckView?>()) {
      return (data != null ? _i3.AgentClaimedCheckView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i4.AgentDiagnosticsView?>()) {
      return (data != null ? _i4.AgentDiagnosticsView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i5.AgentEventView?>()) {
      return (data != null ? _i5.AgentEventView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.AgentExecutionInspectionView?>()) {
      return (data != null
              ? _i6.AgentExecutionInspectionView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i7.AgentExecutionListView?>()) {
      return (data != null ? _i7.AgentExecutionListView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i8.AgentExecutionRecordView?>()) {
      return (data != null ? _i8.AgentExecutionRecordView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i9.AgentResultView?>()) {
      return (data != null ? _i9.AgentResultView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.AgentWorkspaceView?>()) {
      return (data != null ? _i10.AgentWorkspaceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i11.ArtifactCacheEntryView?>()) {
      return (data != null ? _i11.ArtifactCacheEntryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i12.ArtifactReferenceView?>()) {
      return (data != null ? _i12.ArtifactReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i13.BaselineFactView?>()) {
      return (data != null ? _i13.BaselineFactView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.CapabilitySpecView?>()) {
      return (data != null ? _i14.CapabilitySpecView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i15.ChangedFileView?>()) {
      return (data != null ? _i15.ChangedFileView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.ClarificationView?>()) {
      return (data != null ? _i16.ClarificationView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i17.CredentialAccessVerificationView?>()) {
      return (data != null
              ? _i17.CredentialAccessVerificationView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i18.DecisionContextView?>()) {
      return (data != null ? _i18.DecisionContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i19.DecisionOptionView?>()) {
      return (data != null ? _i19.DecisionOptionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i20.DecisionView?>()) {
      return (data != null ? _i20.DecisionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i21.DefectClarificationRequestView?>()) {
      return (data != null
              ? _i21.DefectClarificationRequestView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i22.DefectClarificationView?>()) {
      return (data != null ? _i22.DefectClarificationView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i23.DefectCreatedView?>()) {
      return (data != null ? _i23.DefectCreatedView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i24.DefectDetailView?>()) {
      return (data != null ? _i24.DefectDetailView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i25.DefectEventView?>()) {
      return (data != null ? _i25.DefectEventView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i26.DefectEvidenceView?>()) {
      return (data != null ? _i26.DefectEvidenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i27.DefectInspectionView?>()) {
      return (data != null ? _i27.DefectInspectionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i28.DefectListView?>()) {
      return (data != null ? _i28.DefectListView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i29.DefectSummaryView?>()) {
      return (data != null ? _i29.DefectSummaryView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i30.DiagnosticEntryView?>()) {
      return (data != null ? _i30.DiagnosticEntryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i31.FeatureRequestCreatedView?>()) {
      return (data != null
              ? _i31.FeatureRequestCreatedView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i32.FeatureRequestSummaryView?>()) {
      return (data != null
              ? _i32.FeatureRequestSummaryView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i33.FixVerificationView?>()) {
      return (data != null ? _i33.FixVerificationView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i34.HealthStatusView?>()) {
      return (data != null ? _i34.HealthStatusView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i35.HumanDirectionAttachmentView?>()) {
      return (data != null
              ? _i35.HumanDirectionAttachmentView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i36.HumanDirectionPayloadView?>()) {
      return (data != null
              ? _i36.HumanDirectionPayloadView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i37.HumanDirectionView?>()) {
      return (data != null ? _i37.HumanDirectionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i38.JobClaimView?>()) {
      return (data != null ? _i38.JobClaimView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i39.JobInspectionView?>()) {
      return (data != null ? _i39.JobInspectionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i40.JobListView?>()) {
      return (data != null ? _i40.JobListView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i41.JobRecordView?>()) {
      return (data != null ? _i41.JobRecordView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i42.JobSummaryView?>()) {
      return (data != null ? _i42.JobSummaryView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i43.MintedCredentialView?>()) {
      return (data != null ? _i43.MintedCredentialView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i44.ModelExecutionListView?>()) {
      return (data != null ? _i44.ModelExecutionListView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i45.ModelExecutionRecordView?>()) {
      return (data != null
              ? _i45.ModelExecutionRecordView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i46.ModelPolicyListView?>()) {
      return (data != null ? _i46.ModelPolicyListView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i47.ModelPolicyView?>()) {
      return (data != null ? _i47.ModelPolicyView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i48.ModelStatsGroupView?>()) {
      return (data != null ? _i48.ModelStatsGroupView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i49.ModelStatsView?>()) {
      return (data != null ? _i49.ModelStatsView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i50.ModelStepView?>()) {
      return (data != null ? _i50.ModelStepView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i51.Overview?>()) {
      return (data != null ? _i51.Overview.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i52.PlatformVerificationView?>()) {
      return (data != null
              ? _i52.PlatformVerificationView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i53.ProductBaselineView?>()) {
      return (data != null ? _i53.ProductBaselineView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i54.ProductContextView?>()) {
      return (data != null ? _i54.ProductContextView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i55.ProductDetailView?>()) {
      return (data != null ? _i55.ProductDetailView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i56.ProductSummaryView?>()) {
      return (data != null ? _i56.ProductSummaryView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i57.ProductView?>()) {
      return (data != null ? _i57.ProductView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i58.ProviderHealthView?>()) {
      return (data != null ? _i58.ProviderHealthView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i59.ProviderStatusView?>()) {
      return (data != null ? _i59.ProviderStatusView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i60.RepositoryCredentialView?>()) {
      return (data != null
              ? _i60.RepositoryCredentialView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i61.RepositoryReferenceAddedView?>()) {
      return (data != null
              ? _i61.RepositoryReferenceAddedView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i62.RepositoryReferenceView?>()) {
      return (data != null ? _i62.RepositoryReferenceView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i63.ResolveDecisionView?>()) {
      return (data != null ? _i63.ResolveDecisionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i64.ResourceUsageView?>()) {
      return (data != null ? _i64.ResourceUsageView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i65.SchedulerEventView?>()) {
      return (data != null ? _i65.SchedulerEventView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i66.StandingPolicyView?>()) {
      return (data != null ? _i66.StandingPolicyView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i67.TransitionView?>()) {
      return (data != null ? _i67.TransitionView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i68.TriageResultView?>()) {
      return (data != null ? _i68.TriageResultView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i69.WorkItemDetailView?>()) {
      return (data != null ? _i69.WorkItemDetailView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i70.WorkItemView?>()) {
      return (data != null ? _i70.WorkItemView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i71.WorkerEventView?>()) {
      return (data != null ? _i71.WorkerEventView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i72.WorkerExecutionInspectionView?>()) {
      return (data != null
              ? _i72.WorkerExecutionInspectionView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i73.WorkerExecutionListView?>()) {
      return (data != null ? _i73.WorkerExecutionListView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i74.WorkerExecutionResultView?>()) {
      return (data != null
              ? _i74.WorkerExecutionResultView.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i75.WorkerExecutionView?>()) {
      return (data != null ? _i75.WorkerExecutionView.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i76.WorkerListView?>()) {
      return (data != null ? _i76.WorkerListView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i77.WorkerRegistrationView?>()) {
      return (data != null ? _i77.WorkerRegistrationView.fromJson(data) : null)
          as T;
    }
    if (t == List<_i30.DiagnosticEntryView>) {
      return (data as List)
              .map((e) => deserialize<_i30.DiagnosticEntryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i5.AgentEventView>) {
      return (data as List)
              .map((e) => deserialize<_i5.AgentEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i52.PlatformVerificationView>) {
      return (data as List)
              .map((e) => deserialize<_i52.PlatformVerificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i8.AgentExecutionRecordView>) {
      return (data as List)
              .map((e) => deserialize<_i8.AgentExecutionRecordView>(e))
              .toList()
          as T;
    }
    if (t == List<_i2.AgentArtifactView>) {
      return (data as List)
              .map((e) => deserialize<_i2.AgentArtifactView>(e))
              .toList()
          as T;
    }
    if (t == List<_i15.ChangedFileView>) {
      return (data as List)
              .map((e) => deserialize<_i15.ChangedFileView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i15.ChangedFileView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i15.ChangedFileView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i3.AgentClaimedCheckView>) {
      return (data as List)
              .map((e) => deserialize<_i3.AgentClaimedCheckView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i3.AgentClaimedCheckView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i3.AgentClaimedCheckView>(e))
                    .toList()
              : null)
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
    if (t == Map<String, String>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<String>(v)),
          )
          as T;
    }
    if (t == _i1.getType<Map<String, String>?>()) {
      return (data != null
              ? (data as Map).map(
                  (k, v) =>
                      MapEntry(deserialize<String>(k), deserialize<String>(v)),
                )
              : null)
          as T;
    }
    if (t == List<_i19.DecisionOptionView>) {
      return (data as List)
              .map((e) => deserialize<_i19.DecisionOptionView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i19.DecisionOptionView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i19.DecisionOptionView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i12.ArtifactReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i12.ArtifactReferenceView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i12.ArtifactReferenceView>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i12.ArtifactReferenceView>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i26.DefectEvidenceView>) {
      return (data as List)
              .map((e) => deserialize<_i26.DefectEvidenceView>(e))
              .toList()
          as T;
    }
    if (t == List<_i22.DefectClarificationView>) {
      return (data as List)
              .map((e) => deserialize<_i22.DefectClarificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i25.DefectEventView>) {
      return (data as List)
              .map((e) => deserialize<_i25.DefectEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i29.DefectSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i29.DefectSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i35.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i35.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i35.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i35.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i65.SchedulerEventView>) {
      return (data as List)
              .map((e) => deserialize<_i65.SchedulerEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i41.JobRecordView>) {
      return (data as List)
              .map((e) => deserialize<_i41.JobRecordView>(e))
              .toList()
          as T;
    }
    if (t == List<_i45.ModelExecutionRecordView>) {
      return (data as List)
              .map((e) => deserialize<_i45.ModelExecutionRecordView>(e))
              .toList()
          as T;
    }
    if (t == List<_i47.ModelPolicyView>) {
      return (data as List)
              .map((e) => deserialize<_i47.ModelPolicyView>(e))
              .toList()
          as T;
    }
    if (t == List<_i50.ModelStepView>) {
      return (data as List)
              .map((e) => deserialize<_i50.ModelStepView>(e))
              .toList()
          as T;
    }
    if (t == List<_i48.ModelStatsGroupView>) {
      return (data as List)
              .map((e) => deserialize<_i48.ModelStatsGroupView>(e))
              .toList()
          as T;
    }
    if (t == List<_i42.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i42.JobSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i13.BaselineFactView>) {
      return (data as List)
              .map((e) => deserialize<_i13.BaselineFactView>(e))
              .toList()
          as T;
    }
    if (t == List<_i62.RepositoryReferenceView>) {
      return (data as List)
              .map((e) => deserialize<_i62.RepositoryReferenceView>(e))
              .toList()
          as T;
    }
    if (t == List<_i53.ProductBaselineView>) {
      return (data as List)
              .map((e) => deserialize<_i53.ProductBaselineView>(e))
              .toList()
          as T;
    }
    if (t == List<_i16.ClarificationView>) {
      return (data as List)
              .map((e) => deserialize<_i16.ClarificationView>(e))
              .toList()
          as T;
    }
    if (t == List<_i60.RepositoryCredentialView>) {
      return (data as List)
              .map((e) => deserialize<_i60.RepositoryCredentialView>(e))
              .toList()
          as T;
    }
    if (t == List<_i66.StandingPolicyView>) {
      return (data as List)
              .map((e) => deserialize<_i66.StandingPolicyView>(e))
              .toList()
          as T;
    }
    if (t == List<_i59.ProviderStatusView>) {
      return (data as List)
              .map((e) => deserialize<_i59.ProviderStatusView>(e))
              .toList()
          as T;
    }
    if (t == List<_i21.DefectClarificationRequestView>) {
      return (data as List)
              .map((e) => deserialize<_i21.DefectClarificationRequestView>(e))
              .toList()
          as T;
    }
    if (t == List<_i67.TransitionView>) {
      return (data as List)
              .map((e) => deserialize<_i67.TransitionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i71.WorkerEventView>) {
      return (data as List)
              .map((e) => deserialize<_i71.WorkerEventView>(e))
              .toList()
          as T;
    }
    if (t == List<_i75.WorkerExecutionView>) {
      return (data as List)
              .map((e) => deserialize<_i75.WorkerExecutionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i77.WorkerRegistrationView>) {
      return (data as List)
              .map((e) => deserialize<_i77.WorkerRegistrationView>(e))
              .toList()
          as T;
    }
    if (t == Map<String, _i14.CapabilitySpecView>) {
      return (data as Map).map(
            (k, v) => MapEntry(
              deserialize<String>(k),
              deserialize<_i14.CapabilitySpecView>(v),
            ),
          )
          as T;
    }
    if (t == Map<String, _i11.ArtifactCacheEntryView>) {
      return (data as Map).map(
            (k, v) => MapEntry(
              deserialize<String>(k),
              deserialize<_i11.ArtifactCacheEntryView>(v),
            ),
          )
          as T;
    }
    if (t == _i1.getType<Map<String, _i11.ArtifactCacheEntryView>?>()) {
      return (data != null
              ? (data as Map).map(
                  (k, v) => MapEntry(
                    deserialize<String>(k),
                    deserialize<_i11.ArtifactCacheEntryView>(v),
                  ),
                )
              : null)
          as T;
    }
    if (t == List<_i78.WorkItemView>) {
      return (data as List)
              .map((e) => deserialize<_i78.WorkItemView>(e))
              .toList()
          as T;
    }
    if (t == List<_i79.DecisionView>) {
      return (data as List)
              .map((e) => deserialize<_i79.DecisionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i80.HumanDirectionAttachmentView>) {
      return (data as List)
              .map((e) => deserialize<_i80.HumanDirectionAttachmentView>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i80.HumanDirectionAttachmentView>?>()) {
      return (data != null
              ? (data as List)
                    .map(
                      (e) => deserialize<_i80.HumanDirectionAttachmentView>(e),
                    )
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i81.HumanDirectionView>) {
      return (data as List)
              .map((e) => deserialize<_i81.HumanDirectionView>(e))
              .toList()
          as T;
    }
    if (t == List<_i82.FeatureRequestSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i82.FeatureRequestSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i83.ProductView>) {
      return (data as List)
              .map((e) => deserialize<_i83.ProductView>(e))
              .toList()
          as T;
    }
    if (t == List<_i84.ProductSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i84.ProductSummaryView>(e))
              .toList()
          as T;
    }
    if (t == List<_i85.BaselineFact>) {
      return (data as List)
              .map((e) => deserialize<_i85.BaselineFact>(e))
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
    if (t == List<_i86.JobSummaryView>) {
      return (data as List)
              .map((e) => deserialize<_i86.JobSummaryView>(e))
              .toList()
          as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.AgentArtifactView => 'AgentArtifactView',
      _i3.AgentClaimedCheckView => 'AgentClaimedCheckView',
      _i4.AgentDiagnosticsView => 'AgentDiagnosticsView',
      _i5.AgentEventView => 'AgentEventView',
      _i6.AgentExecutionInspectionView => 'AgentExecutionInspectionView',
      _i7.AgentExecutionListView => 'AgentExecutionListView',
      _i8.AgentExecutionRecordView => 'AgentExecutionRecordView',
      _i9.AgentResultView => 'AgentResultView',
      _i10.AgentWorkspaceView => 'AgentWorkspaceView',
      _i11.ArtifactCacheEntryView => 'ArtifactCacheEntryView',
      _i12.ArtifactReferenceView => 'ArtifactReferenceView',
      _i13.BaselineFactView => 'BaselineFactView',
      _i14.CapabilitySpecView => 'CapabilitySpecView',
      _i15.ChangedFileView => 'ChangedFileView',
      _i16.ClarificationView => 'ClarificationView',
      _i17.CredentialAccessVerificationView =>
        'CredentialAccessVerificationView',
      _i18.DecisionContextView => 'DecisionContextView',
      _i19.DecisionOptionView => 'DecisionOptionView',
      _i20.DecisionView => 'DecisionView',
      _i21.DefectClarificationRequestView => 'DefectClarificationRequestView',
      _i22.DefectClarificationView => 'DefectClarificationView',
      _i23.DefectCreatedView => 'DefectCreatedView',
      _i24.DefectDetailView => 'DefectDetailView',
      _i25.DefectEventView => 'DefectEventView',
      _i26.DefectEvidenceView => 'DefectEvidenceView',
      _i27.DefectInspectionView => 'DefectInspectionView',
      _i28.DefectListView => 'DefectListView',
      _i29.DefectSummaryView => 'DefectSummaryView',
      _i30.DiagnosticEntryView => 'DiagnosticEntryView',
      _i31.FeatureRequestCreatedView => 'FeatureRequestCreatedView',
      _i32.FeatureRequestSummaryView => 'FeatureRequestSummaryView',
      _i33.FixVerificationView => 'FixVerificationView',
      _i34.HealthStatusView => 'HealthStatusView',
      _i35.HumanDirectionAttachmentView => 'HumanDirectionAttachmentView',
      _i36.HumanDirectionPayloadView => 'HumanDirectionPayloadView',
      _i37.HumanDirectionView => 'HumanDirectionView',
      _i38.JobClaimView => 'JobClaimView',
      _i39.JobInspectionView => 'JobInspectionView',
      _i40.JobListView => 'JobListView',
      _i41.JobRecordView => 'JobRecordView',
      _i42.JobSummaryView => 'JobSummaryView',
      _i43.MintedCredentialView => 'MintedCredentialView',
      _i44.ModelExecutionListView => 'ModelExecutionListView',
      _i45.ModelExecutionRecordView => 'ModelExecutionRecordView',
      _i46.ModelPolicyListView => 'ModelPolicyListView',
      _i47.ModelPolicyView => 'ModelPolicyView',
      _i48.ModelStatsGroupView => 'ModelStatsGroupView',
      _i49.ModelStatsView => 'ModelStatsView',
      _i50.ModelStepView => 'ModelStepView',
      _i51.Overview => 'Overview',
      _i52.PlatformVerificationView => 'PlatformVerificationView',
      _i53.ProductBaselineView => 'ProductBaselineView',
      _i54.ProductContextView => 'ProductContextView',
      _i55.ProductDetailView => 'ProductDetailView',
      _i56.ProductSummaryView => 'ProductSummaryView',
      _i57.ProductView => 'ProductView',
      _i58.ProviderHealthView => 'ProviderHealthView',
      _i59.ProviderStatusView => 'ProviderStatusView',
      _i60.RepositoryCredentialView => 'RepositoryCredentialView',
      _i61.RepositoryReferenceAddedView => 'RepositoryReferenceAddedView',
      _i62.RepositoryReferenceView => 'RepositoryReferenceView',
      _i63.ResolveDecisionView => 'ResolveDecisionView',
      _i64.ResourceUsageView => 'ResourceUsageView',
      _i65.SchedulerEventView => 'SchedulerEventView',
      _i66.StandingPolicyView => 'StandingPolicyView',
      _i67.TransitionView => 'TransitionView',
      _i68.TriageResultView => 'TriageResultView',
      _i69.WorkItemDetailView => 'WorkItemDetailView',
      _i70.WorkItemView => 'WorkItemView',
      _i71.WorkerEventView => 'WorkerEventView',
      _i72.WorkerExecutionInspectionView => 'WorkerExecutionInspectionView',
      _i73.WorkerExecutionListView => 'WorkerExecutionListView',
      _i74.WorkerExecutionResultView => 'WorkerExecutionResultView',
      _i75.WorkerExecutionView => 'WorkerExecutionView',
      _i76.WorkerListView => 'WorkerListView',
      _i77.WorkerRegistrationView => 'WorkerRegistrationView',
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
      case _i2.AgentArtifactView():
        return 'AgentArtifactView';
      case _i3.AgentClaimedCheckView():
        return 'AgentClaimedCheckView';
      case _i4.AgentDiagnosticsView():
        return 'AgentDiagnosticsView';
      case _i5.AgentEventView():
        return 'AgentEventView';
      case _i6.AgentExecutionInspectionView():
        return 'AgentExecutionInspectionView';
      case _i7.AgentExecutionListView():
        return 'AgentExecutionListView';
      case _i8.AgentExecutionRecordView():
        return 'AgentExecutionRecordView';
      case _i9.AgentResultView():
        return 'AgentResultView';
      case _i10.AgentWorkspaceView():
        return 'AgentWorkspaceView';
      case _i11.ArtifactCacheEntryView():
        return 'ArtifactCacheEntryView';
      case _i12.ArtifactReferenceView():
        return 'ArtifactReferenceView';
      case _i13.BaselineFactView():
        return 'BaselineFactView';
      case _i14.CapabilitySpecView():
        return 'CapabilitySpecView';
      case _i15.ChangedFileView():
        return 'ChangedFileView';
      case _i16.ClarificationView():
        return 'ClarificationView';
      case _i17.CredentialAccessVerificationView():
        return 'CredentialAccessVerificationView';
      case _i18.DecisionContextView():
        return 'DecisionContextView';
      case _i19.DecisionOptionView():
        return 'DecisionOptionView';
      case _i20.DecisionView():
        return 'DecisionView';
      case _i21.DefectClarificationRequestView():
        return 'DefectClarificationRequestView';
      case _i22.DefectClarificationView():
        return 'DefectClarificationView';
      case _i23.DefectCreatedView():
        return 'DefectCreatedView';
      case _i24.DefectDetailView():
        return 'DefectDetailView';
      case _i25.DefectEventView():
        return 'DefectEventView';
      case _i26.DefectEvidenceView():
        return 'DefectEvidenceView';
      case _i27.DefectInspectionView():
        return 'DefectInspectionView';
      case _i28.DefectListView():
        return 'DefectListView';
      case _i29.DefectSummaryView():
        return 'DefectSummaryView';
      case _i30.DiagnosticEntryView():
        return 'DiagnosticEntryView';
      case _i31.FeatureRequestCreatedView():
        return 'FeatureRequestCreatedView';
      case _i32.FeatureRequestSummaryView():
        return 'FeatureRequestSummaryView';
      case _i33.FixVerificationView():
        return 'FixVerificationView';
      case _i34.HealthStatusView():
        return 'HealthStatusView';
      case _i35.HumanDirectionAttachmentView():
        return 'HumanDirectionAttachmentView';
      case _i36.HumanDirectionPayloadView():
        return 'HumanDirectionPayloadView';
      case _i37.HumanDirectionView():
        return 'HumanDirectionView';
      case _i38.JobClaimView():
        return 'JobClaimView';
      case _i39.JobInspectionView():
        return 'JobInspectionView';
      case _i40.JobListView():
        return 'JobListView';
      case _i41.JobRecordView():
        return 'JobRecordView';
      case _i42.JobSummaryView():
        return 'JobSummaryView';
      case _i43.MintedCredentialView():
        return 'MintedCredentialView';
      case _i44.ModelExecutionListView():
        return 'ModelExecutionListView';
      case _i45.ModelExecutionRecordView():
        return 'ModelExecutionRecordView';
      case _i46.ModelPolicyListView():
        return 'ModelPolicyListView';
      case _i47.ModelPolicyView():
        return 'ModelPolicyView';
      case _i48.ModelStatsGroupView():
        return 'ModelStatsGroupView';
      case _i49.ModelStatsView():
        return 'ModelStatsView';
      case _i50.ModelStepView():
        return 'ModelStepView';
      case _i51.Overview():
        return 'Overview';
      case _i52.PlatformVerificationView():
        return 'PlatformVerificationView';
      case _i53.ProductBaselineView():
        return 'ProductBaselineView';
      case _i54.ProductContextView():
        return 'ProductContextView';
      case _i55.ProductDetailView():
        return 'ProductDetailView';
      case _i56.ProductSummaryView():
        return 'ProductSummaryView';
      case _i57.ProductView():
        return 'ProductView';
      case _i58.ProviderHealthView():
        return 'ProviderHealthView';
      case _i59.ProviderStatusView():
        return 'ProviderStatusView';
      case _i60.RepositoryCredentialView():
        return 'RepositoryCredentialView';
      case _i61.RepositoryReferenceAddedView():
        return 'RepositoryReferenceAddedView';
      case _i62.RepositoryReferenceView():
        return 'RepositoryReferenceView';
      case _i63.ResolveDecisionView():
        return 'ResolveDecisionView';
      case _i64.ResourceUsageView():
        return 'ResourceUsageView';
      case _i65.SchedulerEventView():
        return 'SchedulerEventView';
      case _i66.StandingPolicyView():
        return 'StandingPolicyView';
      case _i67.TransitionView():
        return 'TransitionView';
      case _i68.TriageResultView():
        return 'TriageResultView';
      case _i69.WorkItemDetailView():
        return 'WorkItemDetailView';
      case _i70.WorkItemView():
        return 'WorkItemView';
      case _i71.WorkerEventView():
        return 'WorkerEventView';
      case _i72.WorkerExecutionInspectionView():
        return 'WorkerExecutionInspectionView';
      case _i73.WorkerExecutionListView():
        return 'WorkerExecutionListView';
      case _i74.WorkerExecutionResultView():
        return 'WorkerExecutionResultView';
      case _i75.WorkerExecutionView():
        return 'WorkerExecutionView';
      case _i76.WorkerListView():
        return 'WorkerListView';
      case _i77.WorkerRegistrationView():
        return 'WorkerRegistrationView';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AgentArtifactView') {
      return deserialize<_i2.AgentArtifactView>(data['data']);
    }
    if (dataClassName == 'AgentClaimedCheckView') {
      return deserialize<_i3.AgentClaimedCheckView>(data['data']);
    }
    if (dataClassName == 'AgentDiagnosticsView') {
      return deserialize<_i4.AgentDiagnosticsView>(data['data']);
    }
    if (dataClassName == 'AgentEventView') {
      return deserialize<_i5.AgentEventView>(data['data']);
    }
    if (dataClassName == 'AgentExecutionInspectionView') {
      return deserialize<_i6.AgentExecutionInspectionView>(data['data']);
    }
    if (dataClassName == 'AgentExecutionListView') {
      return deserialize<_i7.AgentExecutionListView>(data['data']);
    }
    if (dataClassName == 'AgentExecutionRecordView') {
      return deserialize<_i8.AgentExecutionRecordView>(data['data']);
    }
    if (dataClassName == 'AgentResultView') {
      return deserialize<_i9.AgentResultView>(data['data']);
    }
    if (dataClassName == 'AgentWorkspaceView') {
      return deserialize<_i10.AgentWorkspaceView>(data['data']);
    }
    if (dataClassName == 'ArtifactCacheEntryView') {
      return deserialize<_i11.ArtifactCacheEntryView>(data['data']);
    }
    if (dataClassName == 'ArtifactReferenceView') {
      return deserialize<_i12.ArtifactReferenceView>(data['data']);
    }
    if (dataClassName == 'BaselineFactView') {
      return deserialize<_i13.BaselineFactView>(data['data']);
    }
    if (dataClassName == 'CapabilitySpecView') {
      return deserialize<_i14.CapabilitySpecView>(data['data']);
    }
    if (dataClassName == 'ChangedFileView') {
      return deserialize<_i15.ChangedFileView>(data['data']);
    }
    if (dataClassName == 'ClarificationView') {
      return deserialize<_i16.ClarificationView>(data['data']);
    }
    if (dataClassName == 'CredentialAccessVerificationView') {
      return deserialize<_i17.CredentialAccessVerificationView>(data['data']);
    }
    if (dataClassName == 'DecisionContextView') {
      return deserialize<_i18.DecisionContextView>(data['data']);
    }
    if (dataClassName == 'DecisionOptionView') {
      return deserialize<_i19.DecisionOptionView>(data['data']);
    }
    if (dataClassName == 'DecisionView') {
      return deserialize<_i20.DecisionView>(data['data']);
    }
    if (dataClassName == 'DefectClarificationRequestView') {
      return deserialize<_i21.DefectClarificationRequestView>(data['data']);
    }
    if (dataClassName == 'DefectClarificationView') {
      return deserialize<_i22.DefectClarificationView>(data['data']);
    }
    if (dataClassName == 'DefectCreatedView') {
      return deserialize<_i23.DefectCreatedView>(data['data']);
    }
    if (dataClassName == 'DefectDetailView') {
      return deserialize<_i24.DefectDetailView>(data['data']);
    }
    if (dataClassName == 'DefectEventView') {
      return deserialize<_i25.DefectEventView>(data['data']);
    }
    if (dataClassName == 'DefectEvidenceView') {
      return deserialize<_i26.DefectEvidenceView>(data['data']);
    }
    if (dataClassName == 'DefectInspectionView') {
      return deserialize<_i27.DefectInspectionView>(data['data']);
    }
    if (dataClassName == 'DefectListView') {
      return deserialize<_i28.DefectListView>(data['data']);
    }
    if (dataClassName == 'DefectSummaryView') {
      return deserialize<_i29.DefectSummaryView>(data['data']);
    }
    if (dataClassName == 'DiagnosticEntryView') {
      return deserialize<_i30.DiagnosticEntryView>(data['data']);
    }
    if (dataClassName == 'FeatureRequestCreatedView') {
      return deserialize<_i31.FeatureRequestCreatedView>(data['data']);
    }
    if (dataClassName == 'FeatureRequestSummaryView') {
      return deserialize<_i32.FeatureRequestSummaryView>(data['data']);
    }
    if (dataClassName == 'FixVerificationView') {
      return deserialize<_i33.FixVerificationView>(data['data']);
    }
    if (dataClassName == 'HealthStatusView') {
      return deserialize<_i34.HealthStatusView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionAttachmentView') {
      return deserialize<_i35.HumanDirectionAttachmentView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionPayloadView') {
      return deserialize<_i36.HumanDirectionPayloadView>(data['data']);
    }
    if (dataClassName == 'HumanDirectionView') {
      return deserialize<_i37.HumanDirectionView>(data['data']);
    }
    if (dataClassName == 'JobClaimView') {
      return deserialize<_i38.JobClaimView>(data['data']);
    }
    if (dataClassName == 'JobInspectionView') {
      return deserialize<_i39.JobInspectionView>(data['data']);
    }
    if (dataClassName == 'JobListView') {
      return deserialize<_i40.JobListView>(data['data']);
    }
    if (dataClassName == 'JobRecordView') {
      return deserialize<_i41.JobRecordView>(data['data']);
    }
    if (dataClassName == 'JobSummaryView') {
      return deserialize<_i42.JobSummaryView>(data['data']);
    }
    if (dataClassName == 'MintedCredentialView') {
      return deserialize<_i43.MintedCredentialView>(data['data']);
    }
    if (dataClassName == 'ModelExecutionListView') {
      return deserialize<_i44.ModelExecutionListView>(data['data']);
    }
    if (dataClassName == 'ModelExecutionRecordView') {
      return deserialize<_i45.ModelExecutionRecordView>(data['data']);
    }
    if (dataClassName == 'ModelPolicyListView') {
      return deserialize<_i46.ModelPolicyListView>(data['data']);
    }
    if (dataClassName == 'ModelPolicyView') {
      return deserialize<_i47.ModelPolicyView>(data['data']);
    }
    if (dataClassName == 'ModelStatsGroupView') {
      return deserialize<_i48.ModelStatsGroupView>(data['data']);
    }
    if (dataClassName == 'ModelStatsView') {
      return deserialize<_i49.ModelStatsView>(data['data']);
    }
    if (dataClassName == 'ModelStepView') {
      return deserialize<_i50.ModelStepView>(data['data']);
    }
    if (dataClassName == 'Overview') {
      return deserialize<_i51.Overview>(data['data']);
    }
    if (dataClassName == 'PlatformVerificationView') {
      return deserialize<_i52.PlatformVerificationView>(data['data']);
    }
    if (dataClassName == 'ProductBaselineView') {
      return deserialize<_i53.ProductBaselineView>(data['data']);
    }
    if (dataClassName == 'ProductContextView') {
      return deserialize<_i54.ProductContextView>(data['data']);
    }
    if (dataClassName == 'ProductDetailView') {
      return deserialize<_i55.ProductDetailView>(data['data']);
    }
    if (dataClassName == 'ProductSummaryView') {
      return deserialize<_i56.ProductSummaryView>(data['data']);
    }
    if (dataClassName == 'ProductView') {
      return deserialize<_i57.ProductView>(data['data']);
    }
    if (dataClassName == 'ProviderHealthView') {
      return deserialize<_i58.ProviderHealthView>(data['data']);
    }
    if (dataClassName == 'ProviderStatusView') {
      return deserialize<_i59.ProviderStatusView>(data['data']);
    }
    if (dataClassName == 'RepositoryCredentialView') {
      return deserialize<_i60.RepositoryCredentialView>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceAddedView') {
      return deserialize<_i61.RepositoryReferenceAddedView>(data['data']);
    }
    if (dataClassName == 'RepositoryReferenceView') {
      return deserialize<_i62.RepositoryReferenceView>(data['data']);
    }
    if (dataClassName == 'ResolveDecisionView') {
      return deserialize<_i63.ResolveDecisionView>(data['data']);
    }
    if (dataClassName == 'ResourceUsageView') {
      return deserialize<_i64.ResourceUsageView>(data['data']);
    }
    if (dataClassName == 'SchedulerEventView') {
      return deserialize<_i65.SchedulerEventView>(data['data']);
    }
    if (dataClassName == 'StandingPolicyView') {
      return deserialize<_i66.StandingPolicyView>(data['data']);
    }
    if (dataClassName == 'TransitionView') {
      return deserialize<_i67.TransitionView>(data['data']);
    }
    if (dataClassName == 'TriageResultView') {
      return deserialize<_i68.TriageResultView>(data['data']);
    }
    if (dataClassName == 'WorkItemDetailView') {
      return deserialize<_i69.WorkItemDetailView>(data['data']);
    }
    if (dataClassName == 'WorkItemView') {
      return deserialize<_i70.WorkItemView>(data['data']);
    }
    if (dataClassName == 'WorkerEventView') {
      return deserialize<_i71.WorkerEventView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionInspectionView') {
      return deserialize<_i72.WorkerExecutionInspectionView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionListView') {
      return deserialize<_i73.WorkerExecutionListView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionResultView') {
      return deserialize<_i74.WorkerExecutionResultView>(data['data']);
    }
    if (dataClassName == 'WorkerExecutionView') {
      return deserialize<_i75.WorkerExecutionView>(data['data']);
    }
    if (dataClassName == 'WorkerListView') {
      return deserialize<_i76.WorkerListView>(data['data']);
    }
    if (dataClassName == 'WorkerRegistrationView') {
      return deserialize<_i77.WorkerRegistrationView>(data['data']);
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

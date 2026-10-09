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
import 'defect_detail_view.dart' as _i2;
import 'defect_evidence_view.dart' as _i3;
import 'defect_clarification_view.dart' as _i4;
import 'defect_event_view.dart' as _i5;
import 'triage_result_view.dart' as _i6;
import 'work_item_view.dart' as _i7;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i8;

/// `defectEndpoints.inspect` returned a raw map. Typed.
abstract class DefectInspectionView implements _i1.SerializableModel {
  DefectInspectionView._({
    required this.defect,
    required this.evidence,
    required this.clarifications,
    required this.events,
    this.triageResult,
    this.remediationWorkItem,
  });

  factory DefectInspectionView({
    required _i2.DefectDetailView defect,
    required List<_i3.DefectEvidenceView> evidence,
    required List<_i4.DefectClarificationView> clarifications,
    required List<_i5.DefectEventView> events,
    _i6.TriageResultView? triageResult,
    _i7.WorkItemView? remediationWorkItem,
  }) = _DefectInspectionViewImpl;

  factory DefectInspectionView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DefectInspectionView(
      defect: _i8.Protocol().deserialize<_i2.DefectDetailView>(
        jsonSerialization['defect'],
      ),
      evidence: _i8.Protocol().deserialize<List<_i3.DefectEvidenceView>>(
        jsonSerialization['evidence'],
      ),
      clarifications: _i8.Protocol()
          .deserialize<List<_i4.DefectClarificationView>>(
            jsonSerialization['clarifications'],
          ),
      events: _i8.Protocol().deserialize<List<_i5.DefectEventView>>(
        jsonSerialization['events'],
      ),
      triageResult: jsonSerialization['triageResult'] == null
          ? null
          : _i8.Protocol().deserialize<_i6.TriageResultView>(
              jsonSerialization['triageResult'],
            ),
      remediationWorkItem: jsonSerialization['remediationWorkItem'] == null
          ? null
          : _i8.Protocol().deserialize<_i7.WorkItemView>(
              jsonSerialization['remediationWorkItem'],
            ),
    );
  }

  _i2.DefectDetailView defect;

  List<_i3.DefectEvidenceView> evidence;

  List<_i4.DefectClarificationView> clarifications;

  List<_i5.DefectEventView> events;

  _i6.TriageResultView? triageResult;

  /// The remediation work item once one is linked. Null until then — the
  /// endpoint has never emitted one.
  _i7.WorkItemView? remediationWorkItem;

  /// Returns a shallow copy of this [DefectInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectInspectionView copyWith({
    _i2.DefectDetailView? defect,
    List<_i3.DefectEvidenceView>? evidence,
    List<_i4.DefectClarificationView>? clarifications,
    List<_i5.DefectEventView>? events,
    _i6.TriageResultView? triageResult,
    _i7.WorkItemView? remediationWorkItem,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectInspectionView',
      'defect': defect.toJson(),
      'evidence': evidence.toJson(valueToJson: (v) => v.toJson()),
      'clarifications': clarifications.toJson(valueToJson: (v) => v.toJson()),
      'events': events.toJson(valueToJson: (v) => v.toJson()),
      if (triageResult != null) 'triageResult': triageResult?.toJson(),
      if (remediationWorkItem != null)
        'remediationWorkItem': remediationWorkItem?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectInspectionViewImpl extends DefectInspectionView {
  _DefectInspectionViewImpl({
    required _i2.DefectDetailView defect,
    required List<_i3.DefectEvidenceView> evidence,
    required List<_i4.DefectClarificationView> clarifications,
    required List<_i5.DefectEventView> events,
    _i6.TriageResultView? triageResult,
    _i7.WorkItemView? remediationWorkItem,
  }) : super._(
         defect: defect,
         evidence: evidence,
         clarifications: clarifications,
         events: events,
         triageResult: triageResult,
         remediationWorkItem: remediationWorkItem,
       );

  /// Returns a shallow copy of this [DefectInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectInspectionView copyWith({
    _i2.DefectDetailView? defect,
    List<_i3.DefectEvidenceView>? evidence,
    List<_i4.DefectClarificationView>? clarifications,
    List<_i5.DefectEventView>? events,
    Object? triageResult = _Undefined,
    Object? remediationWorkItem = _Undefined,
  }) {
    return DefectInspectionView(
      defect: defect ?? this.defect.copyWith(),
      evidence: evidence ?? this.evidence.map((e0) => e0.copyWith()).toList(),
      clarifications:
          clarifications ??
          this.clarifications.map((e0) => e0.copyWith()).toList(),
      events: events ?? this.events.map((e0) => e0.copyWith()).toList(),
      triageResult: triageResult is _i6.TriageResultView?
          ? triageResult
          : this.triageResult?.copyWith(),
      remediationWorkItem: remediationWorkItem is _i7.WorkItemView?
          ? remediationWorkItem
          : this.remediationWorkItem?.copyWith(),
    );
  }
}

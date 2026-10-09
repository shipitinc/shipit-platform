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
import 'agent_execution_record_view.dart' as _i2;
import 'agent_event_view.dart' as _i3;
import 'agent_result_view.dart' as _i4;
import 'platform_verification_view.dart' as _i5;
import 'package:control_plane_server/src/generated/protocol.dart' as _i6;

/// `executionEndpoints.inspect` returned a raw map. Typed.
abstract class AgentExecutionInspectionView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  AgentExecutionInspectionView._({
    required this.execution,
    required this.events,
    this.result,
    required this.verifications,
  });

  factory AgentExecutionInspectionView({
    required _i2.AgentExecutionRecordView execution,
    required List<_i3.AgentEventView> events,
    _i4.AgentResultView? result,
    required List<_i5.PlatformVerificationView> verifications,
  }) = _AgentExecutionInspectionViewImpl;

  factory AgentExecutionInspectionView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AgentExecutionInspectionView(
      execution: _i6.Protocol().deserialize<_i2.AgentExecutionRecordView>(
        jsonSerialization['execution'],
      ),
      events: _i6.Protocol().deserialize<List<_i3.AgentEventView>>(
        jsonSerialization['events'],
      ),
      result: jsonSerialization['result'] == null
          ? null
          : _i6.Protocol().deserialize<_i4.AgentResultView>(
              jsonSerialization['result'],
            ),
      verifications: _i6.Protocol()
          .deserialize<List<_i5.PlatformVerificationView>>(
            jsonSerialization['verifications'],
          ),
    );
  }

  _i2.AgentExecutionRecordView execution;

  List<_i3.AgentEventView> events;

  _i4.AgentResultView? result;

  List<_i5.PlatformVerificationView> verifications;

  /// Returns a shallow copy of this [AgentExecutionInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentExecutionInspectionView copyWith({
    _i2.AgentExecutionRecordView? execution,
    List<_i3.AgentEventView>? events,
    _i4.AgentResultView? result,
    List<_i5.PlatformVerificationView>? verifications,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentExecutionInspectionView',
      'execution': execution.toJson(),
      'events': events.toJson(valueToJson: (v) => v.toJson()),
      if (result != null) 'result': result?.toJson(),
      'verifications': verifications.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentExecutionInspectionView',
      'execution': execution.toJsonForProtocol(),
      'events': events.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (result != null) 'result': result?.toJsonForProtocol(),
      'verifications': verifications.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentExecutionInspectionViewImpl extends AgentExecutionInspectionView {
  _AgentExecutionInspectionViewImpl({
    required _i2.AgentExecutionRecordView execution,
    required List<_i3.AgentEventView> events,
    _i4.AgentResultView? result,
    required List<_i5.PlatformVerificationView> verifications,
  }) : super._(
         execution: execution,
         events: events,
         result: result,
         verifications: verifications,
       );

  /// Returns a shallow copy of this [AgentExecutionInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentExecutionInspectionView copyWith({
    _i2.AgentExecutionRecordView? execution,
    List<_i3.AgentEventView>? events,
    Object? result = _Undefined,
    List<_i5.PlatformVerificationView>? verifications,
  }) {
    return AgentExecutionInspectionView(
      execution: execution ?? this.execution.copyWith(),
      events: events ?? this.events.map((e0) => e0.copyWith()).toList(),
      result: result is _i4.AgentResultView? ? result : this.result?.copyWith(),
      verifications:
          verifications ??
          this.verifications.map((e0) => e0.copyWith()).toList(),
    );
  }
}

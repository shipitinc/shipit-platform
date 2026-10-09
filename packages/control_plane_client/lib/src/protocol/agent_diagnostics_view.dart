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
import 'diagnostic_entry_view.dart' as _i2;
import 'resource_usage_view.dart' as _i3;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i4;

/// The diagnostics block of an agent result.
abstract class AgentDiagnosticsView implements _i1.SerializableModel {
  AgentDiagnosticsView._({
    required this.exitCode,
    required this.durationMs,
    required this.toolCalls,
    required this.errors,
    required this.warnings,
    this.resourceUsage,
  });

  factory AgentDiagnosticsView({
    required int exitCode,
    required int durationMs,
    required int toolCalls,
    required List<_i2.DiagnosticEntryView> errors,
    required List<_i2.DiagnosticEntryView> warnings,
    _i3.ResourceUsageView? resourceUsage,
  }) = _AgentDiagnosticsViewImpl;

  factory AgentDiagnosticsView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AgentDiagnosticsView(
      exitCode: jsonSerialization['exitCode'] as int,
      durationMs: jsonSerialization['durationMs'] as int,
      toolCalls: jsonSerialization['toolCalls'] as int,
      errors: _i4.Protocol().deserialize<List<_i2.DiagnosticEntryView>>(
        jsonSerialization['errors'],
      ),
      warnings: _i4.Protocol().deserialize<List<_i2.DiagnosticEntryView>>(
        jsonSerialization['warnings'],
      ),
      resourceUsage: jsonSerialization['resourceUsage'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.ResourceUsageView>(
              jsonSerialization['resourceUsage'],
            ),
    );
  }

  int exitCode;

  int durationMs;

  int toolCalls;

  List<_i2.DiagnosticEntryView> errors;

  List<_i2.DiagnosticEntryView> warnings;

  _i3.ResourceUsageView? resourceUsage;

  /// Returns a shallow copy of this [AgentDiagnosticsView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentDiagnosticsView copyWith({
    int? exitCode,
    int? durationMs,
    int? toolCalls,
    List<_i2.DiagnosticEntryView>? errors,
    List<_i2.DiagnosticEntryView>? warnings,
    _i3.ResourceUsageView? resourceUsage,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentDiagnosticsView',
      'exitCode': exitCode,
      'durationMs': durationMs,
      'toolCalls': toolCalls,
      'errors': errors.toJson(valueToJson: (v) => v.toJson()),
      'warnings': warnings.toJson(valueToJson: (v) => v.toJson()),
      if (resourceUsage != null) 'resourceUsage': resourceUsage?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentDiagnosticsViewImpl extends AgentDiagnosticsView {
  _AgentDiagnosticsViewImpl({
    required int exitCode,
    required int durationMs,
    required int toolCalls,
    required List<_i2.DiagnosticEntryView> errors,
    required List<_i2.DiagnosticEntryView> warnings,
    _i3.ResourceUsageView? resourceUsage,
  }) : super._(
         exitCode: exitCode,
         durationMs: durationMs,
         toolCalls: toolCalls,
         errors: errors,
         warnings: warnings,
         resourceUsage: resourceUsage,
       );

  /// Returns a shallow copy of this [AgentDiagnosticsView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentDiagnosticsView copyWith({
    int? exitCode,
    int? durationMs,
    int? toolCalls,
    List<_i2.DiagnosticEntryView>? errors,
    List<_i2.DiagnosticEntryView>? warnings,
    Object? resourceUsage = _Undefined,
  }) {
    return AgentDiagnosticsView(
      exitCode: exitCode ?? this.exitCode,
      durationMs: durationMs ?? this.durationMs,
      toolCalls: toolCalls ?? this.toolCalls,
      errors: errors ?? this.errors.map((e0) => e0.copyWith()).toList(),
      warnings: warnings ?? this.warnings.map((e0) => e0.copyWith()).toList(),
      resourceUsage: resourceUsage is _i3.ResourceUsageView?
          ? resourceUsage
          : this.resourceUsage?.copyWith(),
    );
  }
}

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

/// One check the agent claimed it ran.
abstract class AgentClaimedCheckView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  AgentClaimedCheckView._({
    required this.checkName,
    required this.status,
    required this.evidenceKind,
    this.command,
    this.detail,
  });

  factory AgentClaimedCheckView({
    required String checkName,
    required String status,
    required String evidenceKind,
    String? command,
    String? detail,
  }) = _AgentClaimedCheckViewImpl;

  factory AgentClaimedCheckView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AgentClaimedCheckView(
      checkName: jsonSerialization['checkName'] as String,
      status: jsonSerialization['status'] as String,
      evidenceKind: jsonSerialization['evidenceKind'] as String,
      command: jsonSerialization['command'] as String?,
      detail: jsonSerialization['detail'] as String?,
    );
  }

  String checkName;

  /// Durable `AgentClaimStatus` wire value.
  String status;

  /// Durable `EvidenceKind` wire value.
  String evidenceKind;

  String? command;

  String? detail;

  /// Returns a shallow copy of this [AgentClaimedCheckView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentClaimedCheckView copyWith({
    String? checkName,
    String? status,
    String? evidenceKind,
    String? command,
    String? detail,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentClaimedCheckView',
      'checkName': checkName,
      'status': status,
      'evidenceKind': evidenceKind,
      if (command != null) 'command': command,
      if (detail != null) 'detail': detail,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentClaimedCheckView',
      'checkName': checkName,
      'status': status,
      'evidenceKind': evidenceKind,
      if (command != null) 'command': command,
      if (detail != null) 'detail': detail,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentClaimedCheckViewImpl extends AgentClaimedCheckView {
  _AgentClaimedCheckViewImpl({
    required String checkName,
    required String status,
    required String evidenceKind,
    String? command,
    String? detail,
  }) : super._(
         checkName: checkName,
         status: status,
         evidenceKind: evidenceKind,
         command: command,
         detail: detail,
       );

  /// Returns a shallow copy of this [AgentClaimedCheckView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentClaimedCheckView copyWith({
    String? checkName,
    String? status,
    String? evidenceKind,
    Object? command = _Undefined,
    Object? detail = _Undefined,
  }) {
    return AgentClaimedCheckView(
      checkName: checkName ?? this.checkName,
      status: status ?? this.status,
      evidenceKind: evidenceKind ?? this.evidenceKind,
      command: command is String? ? command : this.command,
      detail: detail is String? ? detail : this.detail,
    );
  }
}

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

/// One verification recorded against an agent execution.
abstract class PlatformVerificationView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  PlatformVerificationView._({
    required this.verificationId,
    required this.executionId,
    required this.workItemId,
    required this.checkName,
    required this.status,
    required this.mechanism,
    required this.command,
    required this.capturedAt,
    required this.evidenceKind,
    this.outputRef,
    this.detail,
    this.resultPath,
  });

  factory PlatformVerificationView({
    required String verificationId,
    required String executionId,
    required String workItemId,
    required String checkName,
    required String status,
    required String mechanism,
    required String command,
    required DateTime capturedAt,
    required String evidenceKind,
    String? outputRef,
    String? detail,
    String? resultPath,
  }) = _PlatformVerificationViewImpl;

  factory PlatformVerificationView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return PlatformVerificationView(
      verificationId: jsonSerialization['verificationId'] as String,
      executionId: jsonSerialization['executionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      checkName: jsonSerialization['checkName'] as String,
      status: jsonSerialization['status'] as String,
      mechanism: jsonSerialization['mechanism'] as String,
      command: jsonSerialization['command'] as String,
      capturedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['capturedAt'],
      ),
      evidenceKind: jsonSerialization['evidenceKind'] as String,
      outputRef: jsonSerialization['outputRef'] as String?,
      detail: jsonSerialization['detail'] as String?,
      resultPath: jsonSerialization['resultPath'] as String?,
    );
  }

  String verificationId;

  String executionId;

  String workItemId;

  String checkName;

  /// Durable `AgentClaimStatus` wire value.
  String status;

  String mechanism;

  String command;

  DateTime capturedAt;

  /// Durable `EvidenceKind` wire value.
  String evidenceKind;

  String? outputRef;

  String? detail;

  String? resultPath;

  /// Returns a shallow copy of this [PlatformVerificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  PlatformVerificationView copyWith({
    String? verificationId,
    String? executionId,
    String? workItemId,
    String? checkName,
    String? status,
    String? mechanism,
    String? command,
    DateTime? capturedAt,
    String? evidenceKind,
    String? outputRef,
    String? detail,
    String? resultPath,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PlatformVerificationView',
      'verificationId': verificationId,
      'executionId': executionId,
      'workItemId': workItemId,
      'checkName': checkName,
      'status': status,
      'mechanism': mechanism,
      'command': command,
      'capturedAt': capturedAt.toJson(),
      'evidenceKind': evidenceKind,
      if (outputRef != null) 'outputRef': outputRef,
      if (detail != null) 'detail': detail,
      if (resultPath != null) 'resultPath': resultPath,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PlatformVerificationView',
      'verificationId': verificationId,
      'executionId': executionId,
      'workItemId': workItemId,
      'checkName': checkName,
      'status': status,
      'mechanism': mechanism,
      'command': command,
      'capturedAt': capturedAt.toJson(),
      'evidenceKind': evidenceKind,
      if (outputRef != null) 'outputRef': outputRef,
      if (detail != null) 'detail': detail,
      if (resultPath != null) 'resultPath': resultPath,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PlatformVerificationViewImpl extends PlatformVerificationView {
  _PlatformVerificationViewImpl({
    required String verificationId,
    required String executionId,
    required String workItemId,
    required String checkName,
    required String status,
    required String mechanism,
    required String command,
    required DateTime capturedAt,
    required String evidenceKind,
    String? outputRef,
    String? detail,
    String? resultPath,
  }) : super._(
         verificationId: verificationId,
         executionId: executionId,
         workItemId: workItemId,
         checkName: checkName,
         status: status,
         mechanism: mechanism,
         command: command,
         capturedAt: capturedAt,
         evidenceKind: evidenceKind,
         outputRef: outputRef,
         detail: detail,
         resultPath: resultPath,
       );

  /// Returns a shallow copy of this [PlatformVerificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  PlatformVerificationView copyWith({
    String? verificationId,
    String? executionId,
    String? workItemId,
    String? checkName,
    String? status,
    String? mechanism,
    String? command,
    DateTime? capturedAt,
    String? evidenceKind,
    Object? outputRef = _Undefined,
    Object? detail = _Undefined,
    Object? resultPath = _Undefined,
  }) {
    return PlatformVerificationView(
      verificationId: verificationId ?? this.verificationId,
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      checkName: checkName ?? this.checkName,
      status: status ?? this.status,
      mechanism: mechanism ?? this.mechanism,
      command: command ?? this.command,
      capturedAt: capturedAt ?? this.capturedAt,
      evidenceKind: evidenceKind ?? this.evidenceKind,
      outputRef: outputRef is String? ? outputRef : this.outputRef,
      detail: detail is String? ? detail : this.detail,
      resultPath: resultPath is String? ? resultPath : this.resultPath,
    );
  }
}

import 'dart:convert';

import 'package:meta/meta.dart';

/// A minimal JSON-RPC 2.0 transport for ACP (Agent Client Protocol) servers
/// using newline-delimited JSON framing over stdio.
///
/// Implementations must surface server->client notifications on
/// [notifications] and resolve `request` once the response with the matching
/// `id` arrives (or throw [AcpRequestException] on the JSON-RPC error object).
abstract interface class AcpTransport {
  /// Starts the transport and performs the `initialize` handshake.
  Future<AcpInitializeResult> initialize();

  /// Sends a request and awaits its response.
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  );

  /// Server->client notifications (no `id`), including `session/update`.
  Stream<Map<String, dynamic>> get notifications;

  /// Whether the underlying transport (process pipe) is still open.
  bool get isOpen;

  /// Gracefully tears the transport down (best-effort; kills the child
  /// process if needed).
  Future<void> close();
}

@immutable
class AcpInitializeResult {
  const AcpInitializeResult({
    required this.protocolVersion,
    required this.agentCapabilities,
    required this.agentInfo,
    this.authMethods = const [],
  });

  final int protocolVersion;
  final Map<String, dynamic> agentCapabilities;

  /// e.g. {'name': 'OpenCode', 'version': '1.18.29'}.
  final Map<String, dynamic> agentInfo;
  final List<String> authMethods;

  bool get supportsSessions =>
      ((agentCapabilities['sessionCapabilities']
              as Map<String, dynamic>?)?['resume']
          as bool?) ??
      false;

  factory AcpInitializeResult.fromJson(Map<String, dynamic> json) {
    final agentCapabilities =
        (json['agentCapabilities'] as Map<String, dynamic>? ??
        <String, dynamic>{});
    return AcpInitializeResult(
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 1,
      agentCapabilities: agentCapabilities,
      agentInfo:
          (json['agentInfo'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      authMethods:
          (json['authMethods'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }
}

/// Thrown when the server responds with a JSON-RPC error object.
class AcpRequestException implements Exception {
  const AcpRequestException(this.code, this.message, [this.data]);

  final int code;
  final String message;
  final dynamic data;

  @override
  String toString() => 'AcpRequestException($code): $message $data';
}

const JsonEncoder _compactEncoder = JsonEncoder();

String encodeFrame(Map<String, dynamic> payload) {
  final raw = _compactEncoder.convert(payload);
  assert(!raw.contains('\n'), 'encoded ACP frame must be single-line');
  return '$raw\n';
}

Map<String, dynamic>? tryDecodeLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // Non-JSON frames (e.g. stray logs) are ignored by the transport.
  }
  return null;
}

import 'package:meta/meta.dart';

import 'agent_capability.dart';
import 'agent_session.dart';

/// Provider-neutral runtime adapter. Adapters know how to talk to a specific
/// agent runtime; they know nothing about workflow policy or QA.
abstract interface class AgentAdapter {
  String get providerId;
  String get displayName;
  RuntimeCapabilities get capabilities;

  Future<AgentSession> createSession(AgentSessionConfig config);

  /// Session resurrection from its durable [AgentSessionConfig.sessionId].
  Future<AgentSession> resumeSession(AgentSessionConfig config);

  Future<bool> canResume(String sessionId);
  Future<AdapterHealth> checkHealth();
  Future<void> shutdown();
}

@immutable
class AdapterHealth {
  const AdapterHealth({required this.healthy, this.version, this.details});

  final bool healthy;
  final String? version;
  final Map<String, dynamic>? details;
}

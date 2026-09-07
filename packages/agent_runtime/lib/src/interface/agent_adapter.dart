import 'package:meta/meta.dart';

import 'agent_capability.dart';
import 'agent_session.dart';

abstract interface class AgentAdapter {
  String get providerId;
  String get displayName;
  List<AgentCapability> get capabilities;

  Future<AgentSession> createSession(AgentSessionConfig config);
  Future<bool> canResume(String sessionId);
  Future<AgentSession> resumeSession(String sessionId);

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

import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import 'agent_event.dart';
import 'agent_instruction.dart';
import '../models/agent_session_state.dart';

abstract interface class AgentSession {
  String get sessionId;
  String get workItemId;
  AgentSessionState get state;

  Future<void> start(AgentSessionConfig config);
  Future<void> sendInstruction(AgentInstruction instruction);
  Stream<AgentEvent> get eventStream;
  Future<void> cancel(String reason);
  Future<void> resume(String sessionId);
  Future<AgentResult> getResult();
  Future<List<AgentArtifact>> getArtifacts();
}

@immutable
class AgentSessionConfig {
  const AgentSessionConfig({
    required this.workItemId,
    required this.designContract,
    this.workingDirectory,
    this.environment,
    this.timeout,
  });

  final String workItemId;
  final DesignContract designContract;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final Duration? timeout;
}

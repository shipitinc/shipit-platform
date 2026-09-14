import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import 'agent_event.dart';
import 'agent_instruction.dart';

/// A live (or resumable) agent runtime session. Sessions are transient; the
/// platform persists [AgentExecution] records and [AgentResult], never the
/// conversation.
abstract interface class AgentSession {
  String get sessionId;
  String get executionId;
  String get workItemId;
  AgentSessionStatus get status;

  Future<void> start(AgentSessionConfig config);
  Future<void> sendInstruction(AgentInstruction instruction);
  Stream<AgentEvent> get eventStream;
  Future<void> cancel(String reason);
  Future<AgentResult> getResult();
  Future<List<AgentArtifact>> getArtifacts();
  Future<void> close();
}

@immutable
class AgentSessionConfig {
  const AgentSessionConfig({
    required this.executionId,
    required this.workItemId,
    required this.workingDirectory,
    this.timeout = const Duration(minutes: 5),
    this.runtimeConfig = const {},
    this.allowedPaths,
    this.sessionId,
  });

  final String executionId;
  final String workItemId;

  /// Workspace directory the runtime process runs in.
  final String workingDirectory;
  final Duration timeout;

  /// Opaque runtime configuration (e.g. {'model': <id>, 'executable': <path>}).
  /// Values do not leak into workflow policy.
  final Map<String, String> runtimeConfig;

  /// Absolute path prefixes the agent may operate on. The runtime passes this
  /// through to the agent as its permitted scope.
  final List<String>? allowedPaths;

  /// When set, the session is a resumption of this existing ACP session.
  final String? sessionId;
}

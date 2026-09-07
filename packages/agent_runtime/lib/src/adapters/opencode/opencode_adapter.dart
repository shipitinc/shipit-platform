import 'dart:async';

import 'package:platform_contracts/platform_contracts.dart';

import '../../interface/agent_adapter.dart';
import '../../interface/agent_capability.dart';
import '../../interface/agent_event.dart';
import '../../interface/agent_instruction.dart';
import '../../interface/agent_session.dart';
import '../../models/agent_session_state.dart';

class OpencodeAdapter implements AgentAdapter {
  @override
  final String providerId = 'opencode';

  @override
  final String displayName = 'OpenCode ACP';

  @override
  final List<AgentCapability> capabilities = const [
    AgentCapability(
      name: 'code_generation',
      description: 'Generate source code',
      supported: true,
    ),
    AgentCapability(
      name: 'code_editing',
      description: 'Edit existing code',
      supported: true,
    ),
    AgentCapability(
      name: 'file_operations',
      description: 'Read/write files',
      supported: true,
    ),
    AgentCapability(
      name: 'shell_commands',
      description: 'Execute shell commands',
      supported: true,
    ),
    AgentCapability(
      name: 'git_operations',
      description: 'Git commands',
      supported: true,
    ),
    AgentCapability(name: 'testing', description: 'Run tests', supported: true),
    AgentCapability(
      name: 'resume_session',
      description: 'Resume interrupted session',
      supported: true,
    ),
  ];

  final OpencodeClient _client;

  OpencodeAdapter({OpencodeClient? client})
    : _client = client ?? OpencodeClient();

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    final session = OpencodeSession();
    await session.start(config);
    return session;
  }

  @override
  Future<bool> canResume(String sessionId) async {
    return await _client.canResume(sessionId);
  }

  @override
  Future<AgentSession> resumeSession(String sessionId) async {
    final session = OpencodeSession();
    await session.resume(sessionId);
    return session;
  }

  @override
  Future<AdapterHealth> checkHealth() async {
    try {
      final version = await _client.getVersion();
      return AdapterHealth(healthy: true, version: version);
    } catch (e) {
      return AdapterHealth(healthy: false, details: {'error': e.toString()});
    }
  }

  @override
  Future<void> shutdown() async {
    await _client.shutdown();
  }
}

class OpencodeClient {
  Future<String> getVersion() async => '1.0.0';
  Future<bool> canResume(String sessionId) async => true;
  Future<void> shutdown() async {}
}

class OpencodeSession implements AgentSession {
  @override
  String sessionId = '';

  @override
  String workItemId = '';

  AgentSessionState _state = AgentSessionState.starting;

  @override
  AgentSessionState get state => _state;

  final _eventController = StreamController<AgentEvent>.broadcast();

  @override
  Stream<AgentEvent> get eventStream => _eventController.stream;

  @override
  Future<void> start(AgentSessionConfig config) async {
    _state = AgentSessionState.running;
    sessionId = 'opencode-${DateTime.now().millisecondsSinceEpoch}';
    workItemId = config.workItemId;
    _eventController.add(
      SessionStarted(
        eventId: 'evt-1',
        timestamp: DateTime.now(),
        sessionId: sessionId,
        workItemId: workItemId,
      ),
    );
    // TODO: Start OpenCode process via ACP
  }

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {
    _eventController.add(
      InstructionSent(
        eventId: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        instructionId: instruction.instructionId,
        content: instruction.content,
      ),
    );
    // TODO: Send instruction via ACP
  }

  @override
  Future<void> cancel(String reason) async {
    _state = AgentSessionState.cancelled;
    _eventController.add(
      SessionCancelled(
        eventId: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );
    // TODO: Cancel via ACP
  }

  @override
  Future<void> resume(String sessionId) async {
    _state = AgentSessionState.running;
    this.sessionId = sessionId;
    _eventController.add(
      SessionStarted(
        eventId: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        sessionId: sessionId,
        workItemId: workItemId,
      ),
    );
    // TODO: Resume via ACP
  }

  @override
  Future<AgentResult> getResult() async {
    // TODO: Collect final result
    return AgentResult(
      resultId: 'result-$sessionId',
      sessionId: sessionId,
      workItemId: workItemId,
      status: AgentResultStatus.completed,
      artifacts: [],
      diagnostics: AgentDiagnostics(
        exitCode: 0,
        durationMs: 0,
        toolCalls: 0,
        errors: [],
        warnings: [],
      ),
      structuredResult: {},
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async {
    return [];
  }
}

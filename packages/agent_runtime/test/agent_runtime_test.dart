import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('AgentRuntime', () {
    late AgentRuntime runtime;

    setUp(() {
      runtime = AgentRuntime();
    });

    test('registers and retrieves adapters', () {
      final mockAdapter = MockAgentAdapter();
      final registry = AgentAdapterRegistry();
      registry.register(mockAdapter);
      runtime = AgentRuntime(registry: registry);

      expect(runtime.availableProviderIds, contains('mock'));
      expect(registry.get('mock'), equals(mockAdapter));
    });

    test('throws when adapter not found', () {
      expect(
        () => runtime.startSession(
          providerId: 'nonexistent',
          config: minimalConfig(),
        ),
        throwsA(isA<AgentAdapterNotFoundException>()),
      );
    });
  });

  group('AgentAdapterRegistry', () {
    test('registers multiple adapters', () {
      final registry = AgentAdapterRegistry();
      registry.register(MockAgentAdapter(providerId: 'adapter1'));
      registry.register(MockAgentAdapter(providerId: 'adapter2'));

      expect(registry.providerIds.length, equals(2));
      expect(registry.has('adapter1'), isTrue);
      expect(registry.has('adapter2'), isTrue);
    });
  });

  group('AgentEvent types', () {
    test('SessionStarted has correct fields', () {
      final event = SessionStarted(
        eventId: 'evt-1',
        timestamp: DateTime.now(),
        sessionId: 'session-1',
        workItemId: 'work-1',
      );

      expect(event.sessionId, equals('session-1'));
      expect(event.workItemId, equals('work-1'));
    });

    test('ToolCallStarted has correct fields', () {
      final event = ToolCallStarted(
        eventId: 'evt-2',
        timestamp: DateTime.now(),
        toolCallId: 'call-1',
        tool: 'write_file',
        arguments: {'path': 'test.dart', 'content': 'void main() {}'},
      );

      expect(event.tool, equals('write_file'));
      expect(event.arguments['path'], equals('test.dart'));
    });
  });

  group('OpencodeAdapter', () {
    late OpencodeAdapter adapter;

    setUp(() {
      adapter = OpencodeAdapter();
    });

    test('starts a session with session id and work item id', () async {
      final session = await adapter.createSession(minimalConfig());

      expect(session.sessionId, isNotEmpty);
      expect(session.workItemId, equals('work-1'));
      expect(session.state, equals(AgentSessionState.running));
    });

    test('resumes a session without throwing', () async {
      final session = await adapter.resumeSession('opencode-session-1');

      expect(session.sessionId, equals('opencode-session-1'));
      expect(session.state, equals(AgentSessionState.running));
    });

    test('reports healthy after health check', () async {
      final health = await adapter.checkHealth();

      expect(health.healthy, isTrue);
    });
  });
}

class MockAgentAdapter implements AgentAdapter {
  MockAgentAdapter({String? providerId}) : _providerId = providerId ?? 'mock';

  final String _providerId;

  @override
  String get providerId => _providerId;

  @override
  String get displayName => 'Mock Adapter';

  @override
  List<AgentCapability> get capabilities => [];

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    return MockAgentSession();
  }

  @override
  Future<bool> canResume(String sessionId) async => false;

  @override
  Future<AgentSession> resumeSession(String sessionId) async {
    return MockAgentSession();
  }

  @override
  Future<AdapterHealth> checkHealth() async =>
      const AdapterHealth(healthy: true);

  @override
  Future<void> shutdown() async {}
}

class MockAgentSession implements AgentSession {
  @override
  String get sessionId => 'mock-session';

  @override
  String get workItemId => 'mock-work';

  @override
  AgentSessionState get state => AgentSessionState.running;

  @override
  Future<void> start(AgentSessionConfig config) async {}

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {}

  @override
  Stream<AgentEvent> get eventStream => Stream.empty();

  @override
  Future<void> cancel(String reason) async {}

  @override
  Future<void> resume(String sessionId) async {}

  @override
  Future<AgentResult> getResult() async {
    return AgentResult(
      resultId: 'result-1',
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
  Future<List<AgentArtifact>> getArtifacts() async => [];
}

AgentSessionConfig minimalConfig() {
  return AgentSessionConfig(
    workItemId: 'work-1',
    designContract: DesignContract(
      contractId: 'contract-1',
      workItemId: 'work-1',
      requiredArtifacts: [],
      reviewers: [],
      approvalThreshold: 1,
      status: DesignContractStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );
}

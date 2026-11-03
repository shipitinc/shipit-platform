import 'dart:async';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// A budget long enough that no test double in this file is ever bounded by it.
///
/// `AgentSessionConfig.timeout` is REQUIRED since this lane: it used to default
/// to five minutes, which meant every one of these call sites had been running
/// on a silent fallback rather than on a value anybody chose. Naming it here
/// keeps that visible — these tests are about the session's behaviour, not its
/// budget, and the one test that IS about the budget
/// (`opencode_request_timeout_test.dart`) states its own.
const Duration _generousBudget = Duration(minutes: 30);

void main() {
  group('AgentRuntime', () {
    test('registers and retrieves adapters', () {
      final mockAdapter = MockAgentAdapter();
      final registry = AgentAdapterRegistry();
      registry.register(mockAdapter);

      expect(registry.providerIds, contains('mock'));
      expect(registry.get('mock'), equals(mockAdapter));
    });

    test('throws when adapter not found', () {
      final runtime = AgentRuntime(registry: AgentAdapterRegistry());
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

  group('RuntimeCapabilities', () {
    test('supports declared capabilities only', () {
      const capabilities = RuntimeCapabilities(
        supported: {RuntimeCapability.readFiles, RuntimeCapability.modifyFiles},
      );

      expect(capabilities.supports(RuntimeCapability.readFiles), isTrue);
      expect(capabilities.supports(RuntimeCapability.runShell), isFalse);
      expect(capabilities.supports(RuntimeCapability.cancellable), isFalse);
    });

    test('equality is set-based', () {
      const a = RuntimeCapabilities(
        supported: {RuntimeCapability.readFiles, RuntimeCapability.modifyFiles},
      );
      const b = RuntimeCapabilities(
        supported: {RuntimeCapability.modifyFiles, RuntimeCapability.readFiles},
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('wire round-trips', () {
      expect(
        RuntimeCapability.fromWire(RuntimeCapability.runTests.wire),
        equals(RuntimeCapability.runTests),
      );
      expect(
        () => RuntimeCapability.fromWire('unknown'),
        throwsFormatException,
      );
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

  group('OpenCodeSession (fake ACP transport)', () {
    test('starts, streams chunks and completes with an AgentResult', () async {
      final fake = FakeAcpTransport();
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'work-1',
        transportFactory: (_) async => fake,
      );

      final events = <AgentEvent>[];
      final sub = session.eventStream.listen(events.add);

      await session.start(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          timeout: _generousBudget,
        ),
      );
      expect(session.sessionId, startsWith('ses_'));
      expect(session.status, equals(AgentSessionStatus.running));

      await session.sendInstruction(
        const AgentInstruction(
          instructionId: 'instr-1',
          content: 'implement add',
        ),
      );

      expect(session.status, equals(AgentSessionStatus.completed));
      expect(fake.promptRequests, equals(1));
      expect(fake.promptTexts.single, equals('implement add'));

      final result = await session.getResult();
      expect(result.status, equals(AgentResultStatus.completed));
      expect(result.executionId, equals('exec-1'));
      expect(result.summary, contains('implemented'));
      expect(result.metadata?['chunkCount'], greaterThan(0));

      await _settleEvents();
      final kinds = events.map((e) => e.runtimeType).toList();
      expect(kinds, contains(SessionStarted));
      expect(kinds, contains(InstructionSent));
      expect(kinds, contains(AgentMessageChunk));
      expect(kinds, contains(ToolCallStarted));
      expect(kinds, contains(ToolCallCompleted));
      expect(kinds, contains(UsageUpdate));
      expect(kinds, contains(SessionCompleted));

      await session.close();
      await sub.cancel();
    });

    test('applies best-effort model configuration without failing', () async {
      final fake = FakeAcpTransport();
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'work-1',
        transportFactory: (_) async => fake,
      );

      await session.start(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          runtimeConfig: const {'model': 'opencode/big-pickle'},
          timeout: _generousBudget,
        ),
      );
      expect(fake.modelConfigCalls, equals(1));

      await session.sendInstruction(
        const AgentInstruction(instructionId: 'instr-1', content: 'ok'),
      );
      expect(session.status, equals(AgentSessionStatus.completed));
      await session.close();
    });

    test('times out and transitions to interrupted', () async {
      final fake = FakeAcpTransport(
        promptDelay: const Duration(milliseconds: 200),
      );
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'work-1',
        transportFactory: (_) async => fake,
      );

      await session.start(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          timeout: const Duration(milliseconds: 50),
        ),
      );

      await session.sendInstruction(
        const AgentInstruction(instructionId: 'instr-1', content: 'go'),
      );

      expect(session.status, equals(AgentSessionStatus.interrupted));
      final result = await session.getResult();
      expect(result.status, equals(AgentResultStatus.partial));
      await session.close();
    });

    test('cancel tears down the transport and marks cancelled', () async {
      final fake = FakeAcpTransport(promptHold: true);
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'work-1',
        transportFactory: (_) async => fake,
      );

      await session.start(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          timeout: _generousBudget,
        ),
      );

      final send = session.sendInstruction(
        const AgentInstruction(instructionId: 'instr-1', content: 'go'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await session.cancel('operator requested');
      await send;

      expect(session.status, equals(AgentSessionStatus.cancelled));
      expect(fake.closed, isTrue);
      await session.close();
    });

    test('records denied permission asks as a result diagnostic', () async {
      final fake = FakeAcpTransport(permissionAsks: 2);
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'work-1',
        transportFactory: (_) async => fake,
      );

      await session.start(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          timeout: _generousBudget,
        ),
      );
      await session.sendInstruction(
        const AgentInstruction(instructionId: 'instr-1', content: 'go'),
      );

      final result = await session.getResult();
      final warning = result.diagnostics.warnings
          .where((w) => w.code == 'permission_requests_denied')
          .toList();
      expect(warning, hasLength(1));
      expect(warning.single.message, contains('2'));
      await session.close();
    });

    test('records WHAT was denied, not only the count', () async {
      // F-247: every implementer missing-artifact run in QA ended `end_turn`
      // immediately after a denied ask, and the durable record could not say
      // whether the refusal was a doom-loop stop or an out-of-workspace
      // reach — the ask's content was discarded. This pins it surviving.
      final fake = FakeAcpTransport(
        permissionAsks: 2,
        deniedAskSummaries: const [
          {
            'title': 'external_directory',
            'kind': 'bash',
            'input': '{"command":"cat /etc/qa-contract.yaml"}',
          },
          {'title': 'doom_loop'},
        ],
      );
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'work-1',
        transportFactory: (_) async => fake,
      );

      await session.start(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          timeout: _generousBudget,
        ),
      );
      await session.sendInstruction(
        const AgentInstruction(instructionId: 'instr-1', content: 'go'),
      );

      final result = await session.getResult();
      final denials = result.metadata?['permissionDenials'] as List<dynamic>?;
      expect(denials, hasLength(2));
      expect(denials!.first['title'], equals('external_directory'));
      expect(denials.first['input'], contains('cat /etc/qa-contract.yaml'));
      expect(denials.last['title'], equals('doom_loop'));

      final warning = result.diagnostics.warnings.singleWhere(
        (w) => w.code == 'permission_requests_denied',
      );
      expect(warning.message, contains('external_directory'));
      expect(warning.message, contains('doom_loop'));
      await session.close();
    });

    test('resumes an existing session id when configured', () async {
      final fake = FakeAcpTransport();
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'work-1',
        transportFactory: (_) async => fake,
      );

      await session.start(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          sessionId: 'ses_preexisting',
          timeout: _generousBudget,
        ),
      );

      expect(session.sessionId, equals('ses_preexisting'));
      expect(fake.resumed, equals('ses_preexisting'));
      await session.close();
    });
  });

  group('OpencodeAdapter', () {
    test('advertises provider-neutral capabilities', () {
      final adapter = OpencodeAdapter(
        transportFactory: (_) async => FakeAcpTransport(),
      );

      expect(adapter.providerId, equals('opencode'));
      expect(
        adapter.capabilities.supports(RuntimeCapability.readFiles),
        isTrue,
      );
      expect(
        adapter.capabilities.supports(RuntimeCapability.resumeSession),
        isTrue,
      );
      expect(
        adapter.capabilities.supports(RuntimeCapability.cancellable),
        isTrue,
      );
    });

    test('createSession returns a running session', () async {
      final fake = FakeAcpTransport();
      final adapter = OpencodeAdapter(transportFactory: (_) async => fake);

      final session = await adapter.createSession(
        AgentSessionConfig(
          executionId: 'exec-1',
          workItemId: 'work-1',
          workingDirectory: '/tmp/ws',
          timeout: _generousBudget,
        ),
      );

      expect(session.sessionId, isNotEmpty);
      expect(session.status, equals(AgentSessionStatus.running));
      await session.close();
    });

    test('checkHealth reports runtime version from initialize', () async {
      final fake = FakeAcpTransport();
      final adapter = OpencodeAdapter(transportFactory: (_) async => fake);

      final health = await adapter.checkHealth();

      expect(health.healthy, isTrue);
      expect(health.version, equals('1.18.0-fake'));
    });

    test('checkHealth reports unhealthy when transport fails', () async {
      final adapter = OpencodeAdapter(
        transportFactory: (_) async => FakeAcpTransport(failInitialize: true),
      );

      final health = await adapter.checkHealth();

      expect(health.healthy, isFalse);
    });
  });

  _environmentSeamingTests();
}

class MockAgentAdapter implements AgentAdapter {
  MockAgentAdapter({String? providerId}) : _providerId = providerId ?? 'mock';

  final String _providerId;

  @override
  String get providerId => _providerId;

  @override
  String get displayName => 'Mock Adapter';

  @override
  RuntimeCapabilities get capabilities => const RuntimeCapabilities.none();

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    return MockAgentSession(workItemId: config.workItemId);
  }

  @override
  Future<AgentSession> resumeSession(AgentSessionConfig config) async {
    return MockAgentSession(workItemId: config.workItemId);
  }

  @override
  Future<bool> canResume(String sessionId) async => false;

  @override
  Future<AdapterHealth> checkHealth() async =>
      const AdapterHealth(healthy: true);

  @override
  Future<void> shutdown() async {}
}

class MockAgentSession implements AgentSession {
  MockAgentSession({required String workItemId}) : _workItemId = workItemId;

  final String _workItemId;

  @override
  String get sessionId => 'mock-session';

  @override
  String get workItemId => _workItemId;

  @override
  String get executionId => 'exec';

  @override
  AgentSessionStatus get status => AgentSessionStatus.completed;

  @override
  Future<void> start(AgentSessionConfig config) async {}

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {}

  @override
  Stream<AgentEvent> get eventStream => Stream.empty();

  @override
  Future<void> cancel(String reason) async {}

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

  @override
  Future<void> close() async {}
}

/// A scripted ACP server for tests. Mirrors the wire behavior observed against
/// the real `opencode acp` binary.
class FakeAcpTransport implements AcpTransport {
  FakeAcpTransport({
    this.promptDelay,
    this.promptHold = false,
    this.failInitialize = false,
    this.permissionAsks = 0,
    this.deniedAskSummaries = const [],
  });

  final Duration? promptDelay;
  final bool promptHold;
  final bool failInitialize;

  /// Emit this many `acp/permission_denied` signals during `session/prompt`,
  /// matching what `OpenCodeProcessTransport` adds when it answers a
  /// `session/request_permission` with a deny.
  final int permissionAsks;

  /// The `params.summary` carried on each emitted `acp/permission_denied`,
  /// indexed with the ask — the bounded record the transport builds from the
  /// denied `session/request_permission` params.
  final List<Map<String, dynamic>> deniedAskSummaries;

  final _notifications = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final List<String> promptTexts = [];
  int promptRequests = 0;
  int modelConfigCalls = 0;
  String? resumed;
  bool closed = false;
  bool isOpenValue = true;

  @override
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  @override
  bool get isOpen => isOpenValue;

  @override
  Future<AcpInitializeResult> initialize() async {
    if (failInitialize) {
      throw const AcpTransportException('failed to spawn');
    }
    return const AcpInitializeResult(
      protocolVersion: 1,
      agentCapabilities: {
        'loadSession': true,
        'sessionCapabilities': {'resume': true},
      },
      agentInfo: {'name': 'OpenCode', 'version': '1.18.0-fake'},
      authMethods: [],
    );
  }

  @override
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': 1,
          'agentCapabilities': {
            'loadSession': true,
            'sessionCapabilities': {'resume': true},
          },
          'agentInfo': {'name': 'OpenCode', 'version': '1.18.0-fake'},
        };
      case 'session/new':
        return {'sessionId': 'ses_$id', 'configOptions': []};
      case 'session/resume':
        resumed = params['sessionId'] as String?;
        return {'cwd': '/tmp/ws'};
      case 'setSessionConfigOption':
        modelConfigCalls += 1;
        return {};
      case 'session/prompt':
        promptRequests += 1;
        promptTexts.add(
          ((params['prompt'] as List<dynamic>).first
                  as Map<String, dynamic>)['text']
              as String,
        );
        for (var i = 0; i < permissionAsks; i++) {
          _notifications.add({
            'method': 'acp/permission_denied',
            'params': {
              'requestId': 90 + i,
              if (i < deniedAskSummaries.length)
                'summary': deniedAskSummaries[i],
            },
          });
        }
        _emitSessionUpdate('agent_message_chunk', text: 'implemented');
        _emitSessionUpdate(
          'agent_message',
          parts: [
            {
              'type': 'tool_call',
              'id': 'call-1',
              'toolName': 'write_file',
              'input': {'path': 'lib/calculator.dart'},
            },
            {'type': 'tool_call_output', 'id': 'call-1', 'content': 'done'},
            {'type': 'text', 'text': 'implemented calculator'},
          ],
        );
        _emitSessionUpdate(
          'usage_update',
          usage: {'used': 1.0, 'size': 100.0, 'cost': 0.001},
        );
        if (promptDelay != null) {
          await Future<void>.delayed(promptDelay!);
        }
        if (promptHold) {
          final completer = Completer<Map<String, dynamic>>();
          _pending[id] = completer;
          return completer.future;
        }
        return {'stopReason': 'end_turn'};
      default:
        throw AcpRequestException(-32601, 'method not found: $method');
    }
  }

  void _emitSessionUpdate(
    String type, {
    String? text,
    List<Object?>? parts,
    Map<String, dynamic>? usage,
  }) {
    final update = <String, dynamic>{'type': type};
    if (text != null && type == 'agent_message_chunk') {
      update['message'] = {
        'messageId': 'm1',
        'content': {'type': 'text', 'text': text},
      };
    } else if (parts != null) {
      update['message'] = {
        'messageId': 'm2',
        'content': {'type': 'text', 'parts': parts},
      };
    } else if (usage != null) {
      update['usage'] = usage;
    }
    _notifications.add({
      'method': 'session/update',
      'params': {
        'sessionId': 'ignored',
        'updates': [update],
      },
    });
  }

  @override
  Future<void> close() async {
    closed = true;
    isOpenValue = false;
    for (final completer in _pending.values) {
      completer.completeError(const AcpTransportException('transport closed'));
    }
    _pending.clear();
    await _notifications.close();
  }
}

AgentSessionConfig minimalConfig() {
  return AgentSessionConfig(
    executionId: 'exec-1',
    workItemId: 'work-1',
    workingDirectory: '/tmp/ws',
    timeout: _generousBudget,
  );
}

/// Broadcast-stream delivery is scheduled in microtasks that race with the
/// awaited sendInstruction; drain the queue before asserting on events.
Future<void> _settleEvents() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// Environment seaming: worker policy env reaches the spawned transport.
void _environmentSeamingTests() {
  test(
    'defaultAcpTransport passes AgentSessionConfig.environment through',
    () async {
      final transport = await defaultAcpTransport(
        AgentSessionConfig(
          executionId: 'e1',
          workItemId: 'w1',
          workingDirectory: '/tmp',
          environment: {'SHIPIT_POOL': 'linux-a', 'MAX_JOBS': '4'},
          timeout: _generousBudget,
        ),
      );
      final spawned = transport as dynamic;
      expect(spawned.environment, {'SHIPIT_POOL': 'linux-a', 'MAX_JOBS': '4'});
    },
  );

  test('absent environment stays null', () async {
    final transport = await defaultAcpTransport(
      AgentSessionConfig(
        executionId: 'e2',
        workItemId: 'w2',
        workingDirectory: '/tmp',
        timeout: _generousBudget,
      ),
    );
    expect((transport as dynamic).environment, isNull);
  });
}

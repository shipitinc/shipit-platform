import 'dart:async';
import 'dart:math';

import 'package:platform_contracts/platform_contracts.dart';

import '../../interface/agent_event.dart';
import '../../interface/agent_instruction.dart';
import '../../interface/agent_session.dart';
import '../../acp/acp_transport.dart';
import '../../acp/opencode_process_transport.dart';

typedef AcpTransportFactory =
    Future<AcpTransport> Function(AgentSessionConfig config);

/// Default transport factory: spawns `opencode acp` in the session workspace.
///
/// Runtime-specific knobs come from [AgentSessionConfig.runtimeConfig]
/// (`executable`, `model`, `pure`) so the workflow layer stays provider-neutral.
Future<AcpTransport> defaultAcpTransport(AgentSessionConfig config) async {
  final executable = config.runtimeConfig['executable'] ?? 'opencode';
  final pure = config.runtimeConfig['pure'] == 'true';
  final args = config.runtimeConfig['args'];
  return OpenCodeProcessTransport(
    executable: executable,
    cwd: config.workingDirectory,
    pure: pure,
    extraArgs: args == null ? const [] : args.split(' '),
  );
}

/// AgentSession implementation driving the OpenCode ACP server.
class OpenCodeSession implements AgentSession {
  OpenCodeSession({
    required this.executionId,
    required String workItemId,
    AcpTransportFactory? transportFactory,
  }) : _workItemId = workItemId,
       _transportFactory = transportFactory ?? defaultAcpTransport;

  final String executionId;
  @override
  String get workItemId => _workItemId;
  String _workItemId = '';

  final AcpTransportFactory _transportFactory;

  AcpTransport? _transport;
  final _eventController = StreamController<AgentEvent>.broadcast();
  AgentSessionStatus _status = AgentSessionStatus.starting;
  String _sessionId = '';
  String _resultReason = '';

  AgentResultStatus _resultStatus = AgentResultStatus.completed;
  final List<ToolCallStarted> _toolCalls = [];
  final List<String> _chunks = [];
  double _used = 0;
  double _size = 0;
  double _cost = 0;
  bool _cancelled = false;
  DateTime? _startedAt;
  String? _model;
  int _sequence = 0;
  Duration _timeout = const Duration(minutes: 5);

  @override
  String get sessionId => _sessionId;

  @override
  AgentSessionStatus get status => _status;

  @override
  Stream<AgentEvent> get eventStream => _eventController.stream;

  String _nextEventId() =>
      'evt-${_sequence++}-${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<void> start(AgentSessionConfig config) async {
    if (_status != AgentSessionStatus.starting) {
      throw StateError('session already started');
    }
    _workItemId = config.workItemId;
    _startedAt = DateTime.now();
    _model = config.runtimeConfig['model'];
    _timeout = config.timeout;

    final transport = await _transportFactory(config);
    _transport = transport;
    try {
      await transport.initialize().timeout(
        _timeout,
        onTimeout: () {
          throw TimeoutException(
            'transport initialize exceeded'
            ' ${_timeout.inSeconds}s',
          );
        },
      );
      await _applyRuntimeConfig(transport);

      final Map<String, dynamic> result;
      if (config.sessionId != null && config.sessionId!.isNotEmpty) {
        result = await transport
            .request(
              transport is OpenCodeProcessTransport
                  ? transport.nextRequestId
                  : 2,
              'session/resume',
              {'sessionId': config.sessionId},
            )
            .timeout(
              _timeout,
              onTimeout: () {
                throw TimeoutException(
                  'session/resume exceeded'
                  ' ${_timeout.inSeconds}s',
                );
              },
            );
        _sessionId = config.sessionId!;
      } else {
        result = await transport
            .request(
              transport is OpenCodeProcessTransport
                  ? transport.nextRequestId
                  : 2,
              'session/new',
              {'cwd': config.workingDirectory, 'mcpServers': []},
            )
            .timeout(
              _timeout,
              onTimeout: () {
                throw TimeoutException(
                  'session/new exceeded'
                  ' ${_timeout.inSeconds}s',
                );
              },
            );
        _sessionId = (result['sessionId'] as String?) ?? _generateSessionId();
      }
    } on TimeoutException {
      await transport.close();
      throw AcpTransportException(
        'opencode did not finish starting within ${_timeout.inSeconds}s',
      );
    }

    _status = AgentSessionStatus.running;
    _eventController.add(
      SessionStarted(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        sessionId: _sessionId,
        workItemId: _workItemId,
      ),
    );
  }

  Future<void> _applyRuntimeConfig(AcpTransport transport) async {
    if (_model == null || _model!.isEmpty) return;
    try {
      await transport.request(
        transport is OpenCodeProcessTransport ? transport.nextRequestId : 3,
        'setSessionConfigOption',
        {'configId': 'model', 'optionId': 'model', 'value': _model},
      );
    } catch (_) {
      // Best-effort model selection; falling back to the runtime default is
      // acceptable and never fails the execution.
    }
  }

  String _generateSessionId() =>
      'ses_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {
    final transport = _transport;
    if (transport == null) {
      throw StateError('session not started');
    }
    if (_status != AgentSessionStatus.running) {
      throw StateError('session not running (status: ${_status.name})');
    }

    _eventController.add(
      InstructionSent(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        instructionId: instruction.instructionId,
        content: instruction.content,
      ),
    );

    final sub = transport.notifications.listen(_onNotification);
    try {
      await transport
          .request(
            transport is OpenCodeProcessTransport ? transport.nextRequestId : 4,
            'session/prompt',
            {
              'sessionId': _sessionId,
              'prompt': [
                {'type': 'text', 'text': instruction.content},
              ],
            },
          )
          .timeout(
            _timeout,
            onTimeout: () => throw TimeoutException(
              'session/prompt exceeded ${_timeout.inSeconds}s',
            ),
          );
      _resultStatus = AgentResultStatus.completed;
      _resultReason = 'end_turn';
      _status = AgentSessionStatus.completed;
      _eventController.add(
        SessionCompleted(
          eventId: _nextEventId(),
          timestamp: DateTime.now(),
          result: await getResult(),
        ),
      );
    } on TimeoutException {
      _status = AgentSessionStatus.interrupted;
      _resultStatus = AgentResultStatus.partial;
      _resultReason = 'instruction timeout';
      _eventController.add(
        SessionInterrupted(
          eventId: _nextEventId(),
          timestamp: DateTime.now(),
          reason: 'instruction timeout after ${_timeout.inSeconds}s',
        ),
      );
      await transport.close();
    } on AcpTransportException catch (e) {
      await _handleTransportFailure(e.toString(), recoverable: true);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _handleTransportFailure(
    String error, {
    required bool recoverable,
  }) async {
    if (_cancelled) {
      _status = AgentSessionStatus.cancelled;
      _resultStatus = AgentResultStatus.cancelled;
      _resultReason = 'cancelled';
      _eventController.add(
        SessionCancelled(
          eventId: _nextEventId(),
          timestamp: DateTime.now(),
          reason: _resultReason,
        ),
      );
      return;
    }
    _status = AgentSessionStatus.failed;
    _resultStatus = AgentResultStatus.failed;
    _resultReason = error;
    _eventController.add(
      SessionFailed(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        error: error,
        recoverable: recoverable,
      ),
    );
  }

  void _onNotification(Map<String, dynamic> message) {
    if (message['method'] == 'transport/closed') {
      _handleTransportFailure(
        'transport closed: ${(message['params'] as Map<String, dynamic>?)?['reason']}',
        recoverable: true,
      );
      return;
    }
    if (message['method'] != 'session/update') return;
    final params = message['params'];
    if (params is! Map<String, dynamic>) return;
    final updates = params['updates'] as List<dynamic>? ?? const [];
    for (final raw in updates) {
      if (raw is! Map<String, dynamic>) continue;
      final type = raw['type'];
      switch (type) {
        case 'agent_message_chunk':
          final text = _extractText(raw['message']);
          if (text != null && text.isNotEmpty) {
            _chunks.add(text);
            _eventController.add(
              AgentMessageChunk(
                eventId: _nextEventId(),
                timestamp: DateTime.now(),
                messageId:
                    (raw['message'] as Map<String, dynamic>?)?['messageId']
                        as String? ??
                    'msg',
                text: text,
              ),
            );
          }
        case 'agent_message':
          final parts =
              ((raw['message'] as Map<String, dynamic>?)?['content']
                      as Map<String, dynamic>?)?['parts']
                  as List<dynamic>? ??
              const [];
          for (final part in parts) {
            if (part is! Map<String, dynamic>) continue;
            final partType = part['type'];
            if (partType == 'tool_call') {
              final toolCall = ToolCallStarted(
                eventId: _nextEventId(),
                timestamp: DateTime.now(),
                toolCallId: (part['id'] as String?) ?? 'call',
                tool: (part['toolName'] as String?) ?? 'tool',
                arguments: (part['input'] as Map<String, dynamic>?) ?? const {},
              );
              _toolCalls.add(toolCall);
              _eventController.add(toolCall);
            } else if (partType == 'tool_call_output') {
              _eventController.add(
                ToolCallCompleted(
                  eventId: _nextEventId(),
                  timestamp: DateTime.now(),
                  toolCallId: (part['id'] as String?) ?? 'call',
                  result: {'content': part['content']},
                ),
              );
            }
          }
        case 'usage_update':
          final usage = raw['usage'] as Map<String, dynamic>?;
          if (usage != null) {
            _used = (usage['used'] as num?)?.toDouble() ?? _used;
            _size = (usage['size'] as num?)?.toDouble() ?? _size;
            _cost = (usage['cost'] as num?)?.toDouble() ?? _cost;
            _eventController.add(
              UsageUpdate(
                eventId: _nextEventId(),
                timestamp: DateTime.now(),
                used: _used,
                size: _size,
                cost: _cost,
              ),
            );
          }
        default:
        // state_update, available_commands_update and friends are
        // informational for this slice.
      }
    }
  }

  String? _extractText(Object? message) {
    if (message is! Map<String, dynamic>) return null;
    final content = message['content'];
    if (content is Map<String, dynamic>) {
      final value = content['text'];
      if (value is String) return value;
      final parts = content['parts'];
      if (parts is List<dynamic>) {
        final buffer = StringBuffer();
        for (final part in parts) {
          if (part is Map<String, dynamic> && part['type'] == 'text') {
            buffer.write(part['text']);
          }
        }
        return buffer.toString();
      }
    }
    return null;
  }

  @override
  Future<void> cancel(String reason) async {
    _cancelled = true;
    final transport = _transport;
    if (transport != null) {
      await transport.close();
    }
    _status = AgentSessionStatus.cancelled;
    _resultStatus = AgentResultStatus.cancelled;
    _resultReason = reason;
    _eventController.add(
      SessionCancelled(
        eventId: _nextEventId(),
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );
  }

  @override
  Future<AgentResult> getResult() async {
    final text = _chunks.join();
    return AgentResult(
      resultId: 'result-$_sessionId',
      executionId: executionId,
      sessionId: _sessionId,
      workItemId: _workItemId,
      status: _resultStatus,
      artifacts: const [],
      diagnostics: AgentDiagnostics(
        exitCode: _resultStatus == AgentResultStatus.completed ? 0 : 1,
        durationMs: _startedAt == null
            ? 0
            : DateTime.now().difference(_startedAt!).inMilliseconds,
        toolCalls: _toolCalls.length,
        errors: _resultStatus == AgentResultStatus.completed
            ? []
            : [
                DiagnosticEntry(
                  code: 'agent_runtime_failure',
                  message: _resultReason,
                  severity: 'error',
                ),
              ],
        warnings: const [],
      ),
      structuredResult: const {},
      summary: text.isEmpty
          ? null
          : (text.length > 2000 ? text.substring(0, 2000) : text),
      completedAt: DateTime.now(),
      metadata: {
        'provider': 'opencode',
        if (_model != null) 'model': _model,
        'usage': {'used': _used, 'size': _size, 'cost': _cost},
        'chunkCount': _chunks.length,
      },
    );
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> close() async {
    await _transport?.close();
  }
}

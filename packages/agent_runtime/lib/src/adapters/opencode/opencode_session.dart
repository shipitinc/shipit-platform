import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:platform_contracts/platform_contracts.dart';

import '../../interface/agent_event.dart';
import '../../interface/agent_instruction.dart';
import '../../interface/agent_session.dart';
import '../../acp/acp_transport.dart';
import '../../acp/opencode_process_transport.dart';

typedef AcpTransportFactory =
    Future<AcpTransport> Function(AgentSessionConfig config);

/// JSON-RPC "Method not found", the only code that means the agent does not
/// implement a method name and so licenses trying the alternate spelling.
const int _methodNotFound = -32601;

/// Detects provider error type from an error message.
ProviderErrorType _detectProviderErrorType(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('credit balance') ||
      lower.contains('insufficient credits') ||
      lower.contains('billing') ||
      lower.contains('quota exceeded')) {
    return ProviderErrorType.creditExhausted;
  }
  if (lower.contains('rate limit') ||
      lower.contains('too many requests') ||
      lower.contains('429')) {
    return ProviderErrorType.rateLimited;
  }
  if (lower.contains('unavailable') ||
      lower.contains('service unavailable') ||
      lower.contains('503') ||
      lower.contains('timeout')) {
    return ProviderErrorType.unavailable;
  }
  if (lower.contains('authentication') ||
      lower.contains('invalid api key') ||
      lower.contains('401') ||
      lower.contains('unauthorized')) {
    return ProviderErrorType.authFailed;
  }
  return ProviderErrorType.unknown;
}

/// Creates a [ProviderError] from an exception and provider name.
ProviderError _providerErrorFromException(
  Object exception,
  String provider,
) {
  final message = exception.toString();
  return ProviderError(
    type: _detectProviderErrorType(message),
    provider: provider,
    message: message,
  );
}

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
    environment: config.environment,
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

  /// Text of each complete `agent_message` the runtime reported, used as a
  /// fallback source for the agent's final answer when nothing was streamed.
  final List<String> _fullMessages = [];
  String _stopReason = '';
  double _used = 0;
  double _size = 0;
  double _cost = 0;
  bool _cancelled = false;
  DateTime? _startedAt;

  /// The model configured for this execution, or null once it is known not to
  /// be in force. Never reported in metadata while unapplied.
  String? _model;
  String _modelConfigError = '';
  int _sequence = 0;
  Duration _timeout = const Duration(minutes: 5);

  /// Provider name for error attribution (e.g., 'opencode', 'anthropic', 'openai').
  String _provider = 'opencode';

  /// Escalation index incremented on provider errors to trigger re-dispatch.
  int _escalationIndex = 0;

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
      // The model can only be selected once a session exists: the config
      // request carries `sessionId`, so it must follow `session/new` or
      // `session/resume` rather than precede them.
      await _applyRuntimeConfig(transport);
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

  /// Selects the configured model through the method the runtime actually
  /// implements, `session/set_config_option`.
  ///
  /// Observed against `opencode` 1.18.33 on the wire: `setSessionConfigOption`
  /// is answered `-32601 "Method not found"`, while
  /// `session/set_config_option` with
  /// `{sessionId, configId: 'model', value: '<provider>/<model>'}` returns the
  /// resulting `configOptions` — whose `currentValue` changes to the requested
  /// model — and emits a `config_option_update` notification carrying the same
  /// value. An unknown model is rejected with `-32602 "model not found"` and an
  /// unknown option with `-32602 "unknown config option"`, so a wrong model is
  /// a real, visible failure rather than a silent no-op.
  ///
  /// The failure is therefore *not* swallowed: when the model cannot be
  /// applied, [_model] is cleared so `metadata.model` never names a model the
  /// runtime did not accept, and the reason is surfaced as a diagnostic and in
  /// `metadata.modelNotApplied`.
  Future<void> _applyRuntimeConfig(AcpTransport transport) async {
    final requested = _model;
    if (requested == null || requested.isEmpty) return;
    if (_sessionId.isEmpty) {
      _modelConfigError =
          'the model was not applied: no session existed to configure';
      _model = null;
      return;
    }
    try {
      final response = await _requestConfigOption(transport, {
        'sessionId': _sessionId,
        'configId': 'model',
        'value': requested,
      });
      // The setter's own answer is the only evidence that the model is in
      // force. When the runtime echoes the resulting config options and names a
      // different model, the request did not take and metadata must not claim
      // it.
      final current = _currentModelOf(response['configOptions']);
      if (current != null && current != requested) {
        _modelConfigError =
            'the model was not applied: the runtime reports model '
            '"$current" after the request for "$requested"';
        _model = null;
      }
    } on AcpRequestException catch (e) {
      _modelConfigError = 'the model was not applied: $e';
      _lastProviderError = _providerErrorFromException(e, _provider);
      _model = null;
    } on AcpTransportException catch (e) {
      _modelConfigError = 'the model was not applied: $e';
      _lastProviderError = _providerErrorFromException(e, _provider);
      _model = null;
    }
  }

  /// Issues the model-config request under the method name the runtime
  /// implements, falling back to the alternate spelling only when the runtime
  /// says it does not know the first one (`-32601`). Against `opencode` 1.18.33
  /// the first name is answered, so the fallback costs nothing on the wire.
  ///
  /// This is capability negotiation, not error suppression: any other failure,
  /// and a `-32601` on both spellings, propagate to [_applyRuntimeConfig] and
  /// end with the model reported as not applied.
  Future<Map<String, dynamic>> _requestConfigOption(
    AcpTransport transport,
    Map<String, dynamic> params,
  ) async {
    final ids = transport is OpenCodeProcessTransport
        ? transport.nextRequestId
        : 3;
    try {
      return await transport.request(ids, 'session/set_config_option', params);
    } on AcpRequestException catch (e) {
      if (e.code != _methodNotFound) rethrow;
      return transport.request(ids + 1, 'setSessionConfigOption', params);
    }
  }

  /// The `currentValue` the runtime reports for the `model` config option in a
  /// `session/set_config_option` / `config_option_update` payload, or null when
  /// the payload does not report one.
  static String? _currentModelOf(Object? configOptions) {
    if (configOptions is! List) return null;
    for (final entry in configOptions) {
      if (entry is Map<String, dynamic> && entry['id'] == 'model') {
        final value = entry['currentValue'];
        return value is String ? value : null;
      }
    }
    return null;
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
      final response = await transport
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
      _stopReason = (response['stopReason'] as String?) ?? 'end_turn';
      _resultReason = _stopReason;
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
    } on AcpRequestException catch (e) {
      await _handleTransportFailure(e.toString(), recoverable: true);
    } on AcpTransportException catch (e) {
      await _handleTransportFailure(e.toString(), recoverable: true);
    } finally {
      await sub.cancel();
    }
  }

  ProviderError? _lastProviderError;

  Future<void> _handleTransportFailure(
    String error, {
    required bool recoverable,
  }) async {
    _lastProviderError = _providerErrorFromException(
      Exception(error),
      _provider,
    );
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

  /// Increments the escalation index and returns the provider error that
  /// triggered this escalation, if any. Called by the coordinator when a
  /// provider error is detected to trigger re-dispatch with incremented
  /// escalation metadata.
  ProviderError? escalateOnProviderError() {
    if (_lastProviderError != null) {
      _escalationIndex++;
      return _lastProviderError;
    }
    return null;
  }

  int get escalationIndex => _escalationIndex;

  String get provider => _provider;

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
    for (final raw in _updatesOf(params)) {
      final type = raw['sessionUpdate'] ?? raw['type'];
      switch (type) {
        case 'agent_message_chunk':
          final text = _updateText(raw);
          if (text != null && text.isNotEmpty) {
            _chunks.add(text);
            _eventController.add(
              AgentMessageChunk(
                eventId: _nextEventId(),
                timestamp: DateTime.now(),
                messageId: _messageIdOf(raw),
                text: text,
              ),
            );
          }
        case 'agent_message':
          final fullText = _updateText(raw);
          if (fullText != null && fullText.trim().isNotEmpty) {
            _fullMessages.add(fullText);
          }
          // The runtime streams tool activity as its own `tool_call` and
          // `tool_call_update` updates, not as message parts; those are handled
          // below. Tool-call parts are still read here for a runtime that
          // reports them inside the message.
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
        case 'tool_call':
          final toolCall = ToolCallStarted(
            eventId: _nextEventId(),
            timestamp: DateTime.now(),
            toolCallId: (raw['toolCallId'] as String?) ?? 'call',
            tool:
                (raw['title'] as String?) ?? (raw['kind'] as String?) ?? 'tool',
            arguments: (raw['rawInput'] as Map<String, dynamic>?) ?? const {},
          );
          _toolCalls.add(toolCall);
          _eventController.add(toolCall);
        case 'tool_call_update':
          final toolCallId = (raw['toolCallId'] as String?) ?? 'call';
          final status = raw['status'];
          if (status == 'completed' || status == 'failed') {
            _eventController.add(
              status == 'completed'
                  ? ToolCallCompleted(
                      eventId: _nextEventId(),
                      timestamp: DateTime.now(),
                      toolCallId: toolCallId,
                      result: {'content': raw['content']},
                    )
                  : ToolCallFailed(
                      eventId: _nextEventId(),
                      timestamp: DateTime.now(),
                      toolCallId: toolCallId,
                      error: '${raw['content']}',
                    ),
            );
          }
        case 'usage_update':
          // On the real wire `used` and `size` are numbers on the update
          // itself and `cost` is a money object
          // `{"amount": <number>, "currency": "USD"}`; some runtimes nest the
          // three under `usage`. Each field is read through a coercion that
          // ignores a shape it does not recognise, so a variant cannot throw
          // inside the notification listener.
          final source = raw.containsKey('usage') ? raw['usage'] : raw;
          final usage = source is Map ? source : const {};
          final used = _asDouble(usage['used']);
          final size = _asDouble(usage['size']);
          final cost = _asCost(usage['cost']);
          if (used != null) _used = used;
          if (size != null) _size = size;
          if (cost != null) _cost = cost;
          if (used != null || size != null || cost != null) {
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
        // state_update, available_commands_update, config_option_update and
        // friends are informational for this slice.
      }
    }
  }

  /// The `session/update` payloads carried by one notification.
  ///
  /// The real runtime sends a single update object per notification, under the
  /// singular `update` key and discriminated by `sessionUpdate`. The
  /// `updates` list keyed by `type` is the shape earlier drafts used; both are
  /// accepted so neither silently drops the other's transcripts.
  static List<Map<String, dynamic>> _updatesOf(Map<String, dynamic> params) {
    final single = params['update'];
    if (single is Map<String, dynamic>) return [single];
    final list = params['updates'];
    if (list is! List) return const [];
    return [
      for (final entry in list)
        if (entry is Map<String, dynamic>) entry,
    ];
  }

  /// The assistant text carried by an update, whatever content layout the
  /// runtime used for it.
  ///
  /// The live shape is `content: {"type": "text", "text": ...}` on the update
  /// itself; a message envelope (`message.content.text` or
  /// `message.content.parts`) is read too.
  static String? _updateText(Map<String, dynamic> raw) {
    final direct = _contentText(raw['content']);
    if (direct != null) return direct;
    final message = raw['message'];
    if (message is Map<String, dynamic>) {
      return _contentText(message['content']);
    }
    return null;
  }

  /// Concatenates the text of a content block, a single-block object, or a
  /// list of either. A block that carries no text contributes nothing.
  static String? _contentText(Object? content) {
    if (content is String) return content;
    if (content is List) {
      final buffer = StringBuffer();
      var found = false;
      for (final entry in content) {
        final text = _contentText(entry);
        if (text != null) {
          buffer.write(text);
          found = true;
        }
      }
      return found ? buffer.toString() : null;
    }
    if (content is Map) {
      final value = content['text'];
      if (value is String) return value;
      final nested = _contentText(content['content']);
      if (nested != null) return nested;
      return _contentText(content['parts']);
    }
    return null;
  }

  static String _messageIdOf(Map<String, dynamic> raw) {
    final live = raw['messageId'];
    if (live is String) return live;
    final message = raw['message'];
    if (message is Map<String, dynamic>) {
      final nested = message['messageId'];
      if (nested is String) return nested;
    }
    return 'msg';
  }

  /// A usage number, or null when the value is absent or not a number.
  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// A usage cost. The live runtime sends a money object
  /// `{"amount": <number>, "currency": "USD"}`; a bare number is accepted
  /// because that is the shape the field carried before it became money, and
  /// any other shape leaves the cost unknown rather than throwing.
  static double? _asCost(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    if (value is Map) return _asDouble(value['amount']);
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
    final text = _finalText();
    final payload = _structuredPayload(text);
    final structured = payload.isEmpty
        ? const <String, dynamic>{}
        : _canonicaliseContractTokens(payload);
    final completed = _resultStatus == AgentResultStatus.completed;
    return AgentResult(
      resultId: 'result-$_sessionId',
      executionId: executionId,
      sessionId: _sessionId,
      workItemId: _workItemId,
      status: _resultStatus,
      artifacts: const [],
      diagnostics: AgentDiagnostics(
        exitCode: completed ? 0 : 1,
        durationMs: _startedAt == null
            ? 0
            : DateTime.now().difference(_startedAt!).inMilliseconds,
        toolCalls: _toolCalls.length,
        errors: completed
            ? []
            : [
                DiagnosticEntry(
                  code: 'agent_runtime_failure',
                  message: _resultReason,
                  severity: 'error',
                ),
              ],
        warnings: [
          if (completed && structured.isEmpty)
            DiagnosticEntry(
              code: 'structured_result_absent',
              message:
                  'the completed agent turn carried no JSON object in its '
                  'final message; structuredResult is empty and no '
                  'classification was recorded',
              severity: 'warning',
            ),
          if (_modelConfigError.isNotEmpty)
            DiagnosticEntry(
              code: 'model_not_applied',
              message: _modelConfigError,
              severity: 'warning',
            ),
        ],
      ),
      structuredResult: structured,
      summary: text.isEmpty
          ? null
          : (text.length > 2000 ? text.substring(0, 2000) : text),
      completedAt: DateTime.now(),
      metadata: {
        'provider': _provider,
        // Reported only when the runtime confirmed the model is in force; a
        // configured-but-unapplied model is reported as `modelNotApplied`
        // instead, never as `model`.
        if (_model != null) 'model': _model,
        if (_modelConfigError.isNotEmpty) 'modelNotApplied': _modelConfigError,
        if (_stopReason.isNotEmpty) 'stopReason': _stopReason,
        'structuredResultPresent': structured.isNotEmpty,
        'usage': {'used': _used, 'size': _size, 'cost': _cost},
        'chunkCount': _chunks.length,
        'escalationIndex': _escalationIndex,
        if (_lastProviderError != null) 'providerError': _lastProviderError!.toJson(),
      },
    );
  }

  /// The agent's final assistant text. Streamed `agent_message_chunk` deltas
  /// are authoritative; a complete `agent_message` is the fallback used when a
  /// runtime reports the finished message without streaming it.
  String _finalText() {
    final streamed = _chunks.join();
    if (streamed.trim().isNotEmpty) return streamed;
    for (final message in _fullMessages.reversed) {
      if (message.trim().isNotEmpty) return message;
    }
    return streamed;
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> close() async {
    await _transport?.close();
  }
}

// ---------------------------------------------------------------------------
// Structured result extraction
//
// The ACP surface this session consumes carries assistant output as *text*
// (`session/update` -> `agent_message_chunk` and `agent_message`). A task that
// wants a structured answer, such as the triage prompt, states so in the
// instruction and the model puts the JSON in that text. These helpers recover
// that object; they never invent one.
// ---------------------------------------------------------------------------

/// Guards against a JSON string that nests another JSON string without end.
const int _maxPayloadNesting = 3;

/// A fenced code block; the opening fence may be bare or tagged `json`.
final RegExp _fencedBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');

/// Prompt tokens that name a contract value under a non-wire spelling.
/// `triageDefectInstruction` in `packages/scheduler` documents `"status":
/// "triaged"`, which is not a [DefectStatus] wire value; `triaging` is the
/// canonical state for that stage. Kept to one entry, and only consulted once
/// the exact and separator-folded matches have both failed.
const Map<String, String> _statusAliases = {'triaged': 'triaging'};

/// Recovers the JSON object the agent emitted as its final answer.
///
/// Candidates are tried in order of authority: the whole message decoded as
/// JSON, a fenced block, then the first balanced object embedded in prose
/// (the triage prompt asks for "no prose outside the JSON output", but a model
/// may still wrap it). If nothing parses the result is empty — honest
/// emptiness, never a templated or guessed payload.
Map<String, dynamic> _structuredPayload(String text) {
  final direct = _asPayload(text);
  if (direct != null) return direct;

  for (final match in _fencedBlock.allMatches(text)) {
    final payload = _asPayload(match.group(1) ?? '');
    if (payload != null) return payload;
  }

  for (final candidate in _balancedObjects(text)) {
    final payload = _asPayload(candidate);
    if (payload != null) return payload;
  }
  return const {};
}

/// Decodes [source] as JSON and returns it when it is a JSON object. A JSON
/// *string* that itself contains a JSON object is unwrapped, which is what a
/// model that double-encodes its answer produces.
Map<String, dynamic>? _asPayload(String source, [int depth = 0]) {
  final trimmed = source.trim();
  if (trimmed.isEmpty || depth > _maxPayloadNesting) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is String) return _asPayload(decoded, depth + 1);
  return null;
}

/// Balanced `{...}` spans in [text], in order of appearance. Braces inside
/// JSON strings are ignored, so a `}` in a summary value cannot close the
/// object early.
List<String> _balancedObjects(String text) {
  final spans = <String>[];
  var depth = 0;
  var start = -1;
  var inString = false;
  var escaped = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      if (depth == 0) start = i;
      depth++;
    } else if (char == '}' && depth > 0) {
      depth--;
      if (depth == 0 && start >= 0) {
        spans.add(text.substring(start, i + 1));
      }
    }
  }
  return spans;
}

/// Rewrites the enum-valued fields of an agent payload into the canonical
/// `wire` tokens the contracts serialise. This re-encodes the token the agent
/// chose; it does not choose one. An unrecognised token is returned untouched
/// so the consumer — not the adapter — decides what it means.
Map<String, dynamic> _canonicaliseContractTokens(Map<String, dynamic> payload) {
  final canonical = Map<String, dynamic>.of(payload);
  final classification = canonical['classification'];
  if (classification is String) {
    canonical['classification'] = _canonicalWireToken(
      classification,
      DefectClassification.values.map((value) => value.wire).toList(),
    );
  }
  final status = canonical['status'];
  if (status is String) {
    canonical['status'] = _canonicalWireToken(
      status,
      DefectStatus.values.map((value) => value.wire).toList(),
      aliases: _statusAliases,
    );
  }
  return canonical;
}

String _canonicalWireToken(
  String raw,
  List<String> wires, {
  Map<String, String> aliases = const {},
}) {
  final trimmed = raw.trim();
  if (wires.contains(trimmed)) return trimmed;
  final folded = _foldToken(trimmed);
  for (final wire in wires) {
    if (_foldToken(wire) == folded) return wire;
  }
  return aliases[folded] ?? raw;
}

/// Lowercases and folds every non-alphanumeric run to `_`, splitting
/// camelCase, so `DESIGN_DEFECT`, `design-defect` and `designDefect` compare
/// equal.
String _foldToken(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match[1]}_${match[2]}',
    )
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

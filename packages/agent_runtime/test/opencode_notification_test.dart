import 'dart:async';
import 'dart:convert';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// Receiving-side coverage for the `session/update` notifications a live
/// `opencode acp` process emits.
///
/// Every frame in this file is copied from a capture of the real `opencode`
/// 1.18.33 binary (`initialize` -> `session/new` -> `session/prompt` ->
/// `session/close` over stdio), truncated and redacted only where noted. The
/// earlier tests in this package all built their frames by hand or drove the
/// transport, so nothing exercised `_onNotification` with a frame the runtime
/// had actually produced — which is how a `params['updates']` read against a
/// runtime that sends `params['update']`, and a `cost` read as a number
/// against a money object, both shipped.
///
/// The real shape, verbatim from the capture:
///
/// ```json
/// {"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_...","update":{"sessionUpdate":"agent_message_chunk","messageId":"msg_...","content":{"type":"text","text":"PONG"}}}}
/// {"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_...","update":{"sessionUpdate":"usage_update","used":22211,"size":200000,"cost":{"amount":0,"currency":"USD"}}}}
/// ```
class _LiveFrameTransport implements AcpTransport {
  _LiveFrameTransport({
    required this.frames,
    this.configOptionsResponse,
    this.configError,
  });

  /// Raw wire frames, decoded from the capture, replayed on `session/prompt`.
  final List<String> frames;

  /// `result.configOptions` returned by `session/set_config_option`.
  final List<Map<String, dynamic>>? configOptionsResponse;
  final AcpRequestException? configError;

  final _notifications = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );

  /// Every `session/set_config_option` call, with its exact params.
  final List<Map<String, dynamic>> configRequests = [];
  bool _open = true;

  @override
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<AcpInitializeResult> initialize() async {
    return const AcpInitializeResult(
      protocolVersion: 1,
      agentCapabilities: {
        'sessionCapabilities': {'resume': {}},
      },
      agentInfo: {'name': 'OpenCode', 'version': '1.18.33'},
      authMethods: const [],
    );
  }

  @override
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'session/new':
        return const {'sessionId': 'ses_capture'};
      case 'session/set_config_option':
        configRequests.add(params);
        final error = configError;
        if (error != null) throw error;
        return {'configOptions': configOptionsResponse ?? const []};
      case 'session/prompt':
        for (final frame in frames) {
          final decoded = jsonDecode(frame);
          if (decoded is Map<String, dynamic>) _notifications.add(decoded);
        }
        return _decodedPromptResult;
      default:
        throw AcpRequestException(-32601, 'method not found: $method');
    }
  }

  @override
  Future<void> close() async {
    _open = false;
    await _notifications.close();
  }
}

/// A `_LiveFrameTransport` that has already been handed to a session, plus the
/// events that session emitted and the result it reported.
class _Run {
  _Run(this.transport, this.events, this.result);

  final _LiveFrameTransport transport;
  final List<AgentEvent> events;
  final AgentResult result;

  List<AgentMessageChunk> get chunks => [
    for (final e in events)
      if (e is AgentMessageChunk) e,
  ];

  List<UsageUpdate> get usage => [
    for (final e in events)
      if (e is UsageUpdate) e,
  ];

  List<ToolCallStarted> get toolCallsStarted => [
    for (final e in events)
      if (e is ToolCallStarted) e,
  ];

  List<ToolCallCompleted> get toolCallsCompleted => [
    for (final e in events)
      if (e is ToolCallCompleted) e,
  ];

  List<ToolCallFailed> get toolCallsFailed => [
    for (final e in events)
      if (e is ToolCallFailed) e,
  ];
}

Future<_Run> _drive(
  _LiveFrameTransport transport, {
  Map<String, String> runtimeConfig = const {},
}) async {
  final session = OpenCodeSession(
    executionId: 'exec-1',
    workItemId: 'defect-42',
    transportFactory: (_) async => transport,
  );
  final events = <AgentEvent>[];
  final sub = session.eventStream.listen(events.add);
  await session.start(
    AgentSessionConfig(
      executionId: 'exec-1',
      workItemId: 'defect-42',
      workingDirectory: '/tmp/ws',
      runtimeConfig: runtimeConfig,
    ),
  );
  await session.sendInstruction(
    const AgentInstruction(
      instructionId: 'instr-1',
      content: 'Read README.md and answer as JSON.',
    ),
  );
  await Future<void>.delayed(Duration.zero);
  final result = await session.getResult();
  await sub.cancel();
  await session.close();
  return _Run(transport, events, result);
}

// ---------------------------------------------------------------------------
// Frames captured from the real binary.
//
// Only `sessionId`, `messageId` and `toolCallId` are edited: they are per-run
// opaque identifiers, not secrets. No credential, token or `authorization`
// value appeared in any captured frame.
// ---------------------------------------------------------------------------

/// `initialize` + `session/new` handshake as the real binary answered it.
const String _liveInitializeResponse = '''
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{"loadSession":true,"mcpCapabilities":{"http":true,"sse":true},"promptCapabilities":{"embeddedContext":true,"image":true},"sessionCapabilities":{"close":{},"fork":{},"list":{},"resume":{}}},"authMethods":[{"description":"Run `opencode auth login` in the terminal","name":"Login with opencode","id":"opencode-login"}],"agentInfo":{"name":"OpenCode","version":"1.18.33"}}}
''';

/// `session/new` result, reduced to the two fields this test reads. The real
/// frame carried a ~400-entry `configOptions[].options` catalogue.
Map<String, dynamic> _liveSessionNewResult() => {
  'sessionId': 'ses_capture',
  'configOptions': [
    {
      'id': 'model',
      'name': 'Model',
      'category': 'model',
      'type': 'select',
      'currentValue': 'opencode/big-pickle',
    },
  ],
};

/// The three streamed `agent_message_chunk` deltas of the JSON answer turn.
/// Text truncated to the leading characters of each delta.
const List<String> _liveChunkFrames = [
  '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"agent_message_chunk","messageId":"msg_0eae8f8c8001BdqMehlUvWo9a0","content":{"type":"text","text":"```"}}}}',
  '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"agent_message_chunk","messageId":"msg_0eae8f8c8001BdqMehlUvWo9a0","content":{"type":"text","text":"json\\n[\\n  {\\n    \\"tool\\": \\"read\\",\\n    \\"targ"}}}}',
  '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"agent_message_chunk","messageId":"msg_0eae8f8c8001BdqMehlUvWo9a0","content":{"type":"text","text":"ing\\"\\n  }\\n]\\n```"}}}}',
];

/// A single-delta turn: the binary's whole `PONG` reply arrived as one frame.
const String _livePongFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"agent_message_chunk","messageId":"msg_0ead4f2e1001MOW4X57riqU2zh","content":{"type":"text","text":"PONG"}}}}';

/// The real `usage_update`: `cost` is a money object, not a number.
const String _liveUsageFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"usage_update","used":22211,"size":200000,"cost":{"amount":0,"currency":"USD"}}}}';

/// A `usage_update` carrying a non-zero money amount, so a `cost` read that
/// silently yields 0 is distinguishable from one that reads the amount.
const String _liveUsageWithAmountFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"usage_update","used":21543,"size":200000,"cost":{"amount":1.25,"currency":"USD"}}}}';

/// The real `tool_call` and `tool_call_update` pair, absolute path rewritten.
const String _liveToolCallFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"tool_call","toolCallId":"call_function_qw9x18gg8t55_1","title":"read","kind":"read","status":"pending","locations":[],"rawInput":{}}}}';

const String _liveToolCallUpdateFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"tool_call_update","toolCallId":"call_function_qw9x18gg8t55_1","status":"in_progress","kind":"read","title":"read","locations":[{"path":"/private/var/folders/redacted/README.md"}],"rawInput":{"filePath":"/private/var/folders/redacted/README.md"}}}}';

const String _liveToolCallFailedFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"tool_call_update","toolCallId":"call_function_qw9x18gg8t55_1","status":"failed","title":"read","content":[{"type":"content","content":{"type":"text","text":"File not found"}}]}}}';

const String _liveToolCallCompletedFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"tool_call_update","toolCallId":"call_function_qw9x18gg8t55_1","status":"completed","title":"ls -la","content":[{"type":"content","content":{"type":"text","text":"total 1408"}}]}}}';

/// The informational update the runtime sends before the first prompt.
const String _liveAvailableCommandsFrame =
    '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"available_commands_update","availableCommands":[{"name":"init","description":"guided AGENTS.md setup"}]}}}';

/// The real `session/prompt` result.
const String _livePromptResponse =
    '{"jsonrpc":"2.0","id":20,"result":{"stopReason":"end_turn","usage":{"inputTokens":301,"outputTokens":134,"totalTokens":22345,"cachedReadTokens":21910},"_meta":{}}}';

/// The `result` object of [_livePromptResponse], which is what a transport
/// hands back to the session.
final Map<String, dynamic> _decodedPromptResult =
    (jsonDecode(_livePromptResponse) as Map<String, dynamic>)['result']
        as Map<String, dynamic>;

/// The verbatim `-32602` the binary returned for a model it does not know.
const String _liveInvalidModelError =
    '{"jsonrpc":"2.0","id":12,"error":{"code":-32602,"message":"Invalid params: model not found: nope/does-not-exist","data":{"providerId":"nope","modelId":"nope/does-not-exist"}}}';

void main() {
  group('live opencode acp session/update frames', () {
    test(
      'the captured initialize response advertises no model-config method',
      () {
        // Ground truth for the model-setting defect: the real initialize result
        // advertises session lifecycle capabilities and nothing about config
        // options, so the adapter cannot discover the setter from capabilities.
        final decoded = jsonDecode(_liveInitializeResponse);
        final result =
            (decoded as Map<String, dynamic>)['result'] as Map<String, dynamic>;
        final capabilities =
            result['agentCapabilities'] as Map<String, dynamic>;
        final sessionCapabilities =
            capabilities['sessionCapabilities'] as Map<String, dynamic>;
        expect(
          sessionCapabilities.keys,
          unorderedEquals(['close', 'fork', 'list', 'resume']),
        );
        expect(
          sessionCapabilities.containsKey('setConfigOption'),
          isFalse,
          reason: 'the model setter is not advertised as a capability',
        );
        expect(
          result['agentInfo'],
          equals({'name': 'OpenCode', 'version': '1.18.33'}),
        );
      },
    );

    test(
      'the captured session/new result reports the model as a config option',
      () {
        final options = _liveSessionNewResult()['configOptions'] as List;
        final model = (options.first as Map<String, dynamic>)['id'];
        expect(model, equals('model'));
      },
    );

    test('accumulates streamed agent_message_chunk text', () async {
      final transport = _LiveFrameTransport(frames: _liveChunkFrames);
      final run = await _drive(transport);

      // The real binary keys the discriminator `sessionUpdate` on a singular
      // `update` object; `params['updates']` never appears on the wire.
      expect(run.chunks, hasLength(3));
      expect(
        run.chunks.map((c) => c.text).join(),
        equals(
          '```json\n[\n  {\n    "tool": "read",\n    "targing"\n  }\n]\n```',
        ),
      );
      expect(
        run.chunks.every(
          (c) => c.messageId == 'msg_0eae8f8c8001BdqMehlUvWo9a0',
        ),
        isTrue,
        reason: 'the live messageId is a sibling of content, not nested',
      );
      expect(run.result.metadata?['chunkCount'], equals(3));
      expect(run.result.summary, contains('"tool": "read"'));
      // The captured turn answered with a JSON *array*, and extraction recovers
      // objects only. It stays empty rather than being coerced into a payload.
      expect(run.result.structuredResult, isEmpty);
      expect(run.result.metadata?['structuredResultPresent'], isFalse);
    });

    test('a single-delta turn still yields the text', () async {
      final run = await _drive(_LiveFrameTransport(frames: [_livePongFrame]));
      expect(run.chunks.single.text, equals('PONG'));
      expect(run.result.summary, equals('PONG'));
    });

    test('captures a complete agent_message when nothing was streamed', () async {
      // The 1.18.33 binary streamed deltas only — it emitted no
      // `agent_message` update in any observed run — so this frame is built
      // from the same `session/update` envelope the binary used, with the
      // full-message discriminator. The fallback path stays covered.
      const frame =
          '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"agent_message","messageId":"msg_full_1","content":{"type":"text","text":"{\\"classification\\":\\"implementation_defect\\",\\"status\\":\\"triaging\\",\\"confidence\\":0.9}"}}}}';
      final run = await _drive(_LiveFrameTransport(frames: [frame]));

      expect(run.chunks, isEmpty);
      expect(run.result.metadata?['chunkCount'], equals(0));
      expect(
        run.result.structuredResult['classification'],
        equals('implementation_defect'),
      );
      expect(run.result.summary, contains('implementation_defect'));
    });

    test(
      'reads usage_update without throwing and keeps the numbers sane',
      () async {
        final run = await _drive(
          _LiveFrameTransport(frames: [_livePongFrame, _liveUsageFrame]),
        );

        // The real frame's `cost` is `{"amount":0,"currency":"USD"}`; reading it
        // as a number threw `_Map<String, dynamic> is not a subtype of num?` and
        // killed the listener on the first usage update.
        expect(run.usage, hasLength(1));
        expect(run.usage.single.used, equals(22211));
        expect(run.usage.single.size, equals(200000));
        expect(run.usage.single.cost, equals(0));

        final usage = run.result.metadata?['usage'] as Map<String, dynamic>;
        expect(usage['used'], equals(22211));
        expect(usage['size'], equals(200000));
        expect(usage['cost'], equals(0));
      },
    );

    test('reads a non-zero money amount as the cost', () async {
      final run = await _drive(
        _LiveFrameTransport(frames: [_liveUsageWithAmountFrame]),
      );
      expect(run.usage.single.cost, equals(1.25));
      final usage = run.result.metadata?['usage'] as Map<String, dynamic>;
      expect(usage['cost'], equals(1.25));
    });

    test('a numeric cost is still read as a cost', () async {
      const frame =
          '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"usage_update","used":10,"size":100,"cost":0.5}}}';
      final run = await _drive(_LiveFrameTransport(frames: [frame]));
      expect(run.usage.single.cost, equals(0.5));
    });

    test(
      'an unrecognised usage shape leaves usage untouched, not crashing',
      () async {
        const frame =
            '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"ses_capture","update":{"sessionUpdate":"usage_update","used":"not-a-number","size":null,"cost":{"currency":"USD"}}}}';
        final run = await _drive(
          _LiveFrameTransport(frames: [_liveUsageFrame, frame]),
        );

        // The first update set the values; the unreadable second one changes
        // nothing and, critically, does not tear down the listener.
        expect(run.usage, hasLength(1));
        final usage = run.result.metadata?['usage'] as Map<String, dynamic>;
        expect(usage['used'], equals(22211));
        expect(usage['cost'], equals(0));
      },
    );

    test('records tool activity from tool_call and tool_call_update', () async {
      final run = await _drive(
        _LiveFrameTransport(
          frames: [
            _liveToolCallFrame,
            _liveToolCallUpdateFrame,
            _liveToolCallCompletedFrame,
          ],
        ),
      );

      expect(run.toolCallsStarted, hasLength(1));
      expect(
        run.toolCallsStarted.single.toolCallId,
        equals('call_function_qw9x18gg8t55_1'),
      );
      expect(run.toolCallsStarted.single.tool, equals('read'));
      expect(run.toolCallsCompleted, hasLength(1));
      // An in-progress update is progress, not completion.
      expect(run.toolCallsFailed, isEmpty);
      expect(run.result.diagnostics.toolCalls, equals(1));
    });

    test('surfaces a failed tool call as ToolCallFailed', () async {
      final run = await _drive(
        _LiveFrameTransport(
          frames: [_liveToolCallFrame, _liveToolCallFailedFrame],
        ),
      );
      expect(run.toolCallsFailed, hasLength(1));
      expect(
        run.toolCallsFailed.single.toolCallId,
        equals('call_function_qw9x18gg8t55_1'),
      );
      expect(run.toolCallsFailed.single.error, contains('File not found'));
    });

    test('ignores informational updates without inventing text', () async {
      final run = await _drive(
        _LiveFrameTransport(frames: [_liveAvailableCommandsFrame]),
      );
      expect(run.chunks, isEmpty);
      expect(run.result.summary, isNull);
      expect(run.result.structuredResult, isEmpty);
      expect(
        run.result.diagnostics.warnings.map((w) => w.code),
        contains('structured_result_absent'),
      );
    });

    test('a turn that streamed only prose stays honestly empty', () async {
      const proseFrame =
          '{"jsonrpc":"2.0","method":"session/update","params":'
          '{"sessionId":"ses_capture","update":'
          '{"sessionUpdate":"agent_message_chunk","messageId":"msg_0",'
          '"content":{"type":"text",'
          '"text":"I could not determine a classification."}}}}';
      final run = await _drive(_LiveFrameTransport(frames: [proseFrame]));

      expect(run.result.status, equals(AgentResultStatus.completed));
      expect(run.result.structuredResult, isEmpty);
      expect(run.result.metadata?['structuredResultPresent'], isFalse);
      expect(
        run.result.diagnostics.warnings.map((w) => w.code),
        contains('structured_result_absent'),
      );
      expect(
        run.result.diagnostics.errors,
        isEmpty,
        reason: 'a completed turn is not an error',
      );
      // The text the agent did produce is still visible.
      expect(run.result.summary, contains('could not determine'));
    });
  });

  group('model selection over the real ACP method', () {
    test(
      'applies the model with session/set_config_option and its exact params',
      () async {
        const model = 'devin/claude-sonnet-4-5';
        final transport = _LiveFrameTransport(
          frames: [_livePongFrame],
          // The binary answered with the resulting configOptions.
          configOptionsResponse: [
            {'id': 'model', 'currentValue': model, 'category': 'model'},
          ],
        );
        final run = await _drive(
          transport,
          runtimeConfig: const {'model': model},
        );

        expect(transport.configRequests, hasLength(1));
        final request = transport.configRequests.single;
        expect(request['configId'], equals('model'));
        expect(request['value'], equals(model));
        // The real method requires a live sessionId; the previous call omitted it
        // entirely and also used a method the binary does not implement.
        expect(request['sessionId'], equals('ses_capture'));
        expect(
          run.result.metadata?['model'],
          equals(model),
          reason: 'a confirmed model is reported',
        );
        expect(run.result.metadata?['modelNotApplied'], isNull);
        expect(
          run.result.diagnostics.warnings.map((w) => w.code),
          isNot(contains('model_not_applied')),
        );
      },
    );

    test('a rejected model is never reported as the model in force', () async {
      // The binary's verbatim -32602 for an unknown model, replayed as the
      // error the transport would surface.
      final error = jsonDecode(_liveInvalidModelError) as Map<String, dynamic>;
      final errorBody = error['error'] as Map<String, dynamic>;
      final transport = _LiveFrameTransport(
        frames: [_livePongFrame],
        configError: AcpRequestException(
          (errorBody['code'] as num).toInt(),
          errorBody['message'] as String,
          errorBody['data'],
        ),
      );
      final run = await _drive(
        transport,
        runtimeConfig: const {'model': 'nope/does-not-exist'},
      );

      // A failure that made metadata lie was previously swallowed by
      // `catch (_)`, so the execution reported a model it never set. This
      // assertion is deliberately first: it is the claim the defect made.
      expect(
        run.result.metadata?['model'],
        isNull,
        reason: 'a model that was never applied must not be claimed',
      );
      expect(
        run.result.metadata?['modelNotApplied'],
        contains('model not found: nope/does-not-exist'),
      );
      expect(transport.configRequests, hasLength(1));
      final warning = run.result.diagnostics.warnings.firstWhere(
        (w) => w.code == 'model_not_applied',
      );
      expect(warning.severity, equals('warning'));
    });

    test(
      'a model the runtime does not echo back is not reported as applied',
      () async {
        final transport = _LiveFrameTransport(
          frames: [_livePongFrame],
          configOptionsResponse: [
            {'id': 'model', 'currentValue': 'opencode/big-pickle'},
          ],
        );
        final run = await _drive(
          transport,
          runtimeConfig: const {'model': 'devin/claude-sonnet-4-5'},
        );

        expect(run.result.metadata?['model'], isNull);
        expect(
          run.result.metadata?['modelNotApplied'],
          contains('opencode/big-pickle'),
        );
      },
    );

    test('no configured model means no config request at all', () async {
      final transport = _LiveFrameTransport(frames: [_livePongFrame]);
      final run = await _drive(transport);
      expect(transport.configRequests, isEmpty);
      expect(run.result.metadata?['model'], isNull);
      expect(run.result.metadata?['modelNotApplied'], isNull);
      expect(
        run.result.diagnostics.warnings.map((w) => w.code),
        isNot(contains('model_not_applied')),
      );
    });
  });
}

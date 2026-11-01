import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// The provider-error surface the ACP wire does not carry.
///
/// ## WHY THIS FILE EXISTS
///
/// Verified live: opencode swallows `AI_APICallError: Free usage limit
/// reached` — `session/prompt` is never answered, no `session/update`
/// arrives, and the execution dies at its budget as a plain timeout. The
/// ONLY place the error existed was the child's stderr, which
/// `OpenCodeProcessTransport` already buffers but nothing read. These tests
/// pin the contract that closes that hole WITHOUT fabricating a wire event:
/// the session reads the tail the transport genuinely captured, and records
/// `providerError` in the result metadata only when the tail names a
/// provider-side failure it can classify.
void main() {
  /// Starts a session against a transport whose prompt hangs forever, then
  /// asks for the result — the shape the coordinator's manufactured
  /// terminal event actually produces: a session still `running`, never
  /// settled, never answered.
  Future<AgentResult> resultOfHangingPrompt({String stderr = ''}) async {
    final transport = _TailedTransport(stderr: stderr, hangPrompt: true);
    final session = OpenCodeSession(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      transportFactory: (_) async => transport,
    );
    await session.start(_config());
    unawaited(
      session.sendInstruction(
        const AgentInstruction(instructionId: 'i1', content: 'do the work'),
      ),
    );
    final result = await session.getResult();
    await session.close();
    return result;
  }

  /// Runs a prompt that dies on the wire (transport exception — nobody
  /// answered), then reads the result.
  Future<AgentResult> resultOfDeadWire({String stderr = ''}) async {
    final transport = _TailedTransport(
      stderr: stderr,
      promptFailure: const AcpTransportException(
        'ACP request timed out: session/prompt',
      ),
    );
    final session = OpenCodeSession(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      transportFactory: (_) async => transport,
    );
    await session.start(_config());
    await session.sendInstruction(
      const AgentInstruction(instructionId: 'i1', content: 'do the work'),
    );
    final result = await session.getResult();
    await session.close();
    return result;
  }

  group('stderr surfacing — the signal the wire never carried', () {
    test(
      'a quota error on the child stderr lands in the result metadata',
      () async {
        final result = await resultOfHangingPrompt(
          stderr: 'AI_APICallError: Free usage limit reached',
        );

        final providerError = result.metadata?['providerError'];
        expect(
          providerError,
          isA<Map>(),
          reason:
              'the runtime DID emit a provider error — on stderr, not on the '
              'wire. Reading it is the honest signal; the alternative is '
              'inferring an outage from silence.',
        );
        expect(
          (providerError! as Map)['type'],
          'creditExhausted',
          reason: '`Free usage limit reached` is a quota failure',
        );
      },
    );

    test(
      'a provider error read off the tail survives a dead wire too',
      () async {
        final result = await resultOfDeadWire(
          stderr: 'Error: rate limit exceeded, retry later',
        );

        final providerError = result.metadata?['providerError'] as Map?;
        expect(providerError, isNotNull);
        expect(providerError!['type'], 'rateLimited');
      },
    );

    test('stderr that names no provider error records NOTHING', () async {
      final result = await resultOfDeadWire(
        stderr: 'some unrelated startup warning\nno provider error here',
      );

      final providerError = result.metadata?['providerError'] as Map?;
      expect(
        providerError == null || providerError['type'] == 'unknown',
        isTrue,
        reason:
            'an unmatched tail adds NO classified provider error. The '
            'unclassified `unknown` stamp the wire failure already writes '
            'is honest; a fabricated quota/rate-limit type would not be.',
      );
    });

    test('an empty tail records nothing new', () async {
      final result = await resultOfDeadWire();
      final providerError = result.metadata?['providerError'] as Map?;
      expect(
        providerError == null || providerError['type'] == 'unknown',
        isTrue,
      );
    });
  });

  group('the never-settled result is honest', () {
    test(
      'a session that never answered reports partial, not completed',
      () async {
        final result = await resultOfHangingPrompt();

        expect(
          result.status,
          AgentResultStatus.partial,
          reason:
              'the coordinator asks for this result after its OWN timeout '
              'fires — the session never produced a terminal state, so the '
              'durable record must not claim a completed run.',
        );
        expect(result.metadata?['runtimeAnswered'], isFalse);
      },
    );
  });
}

AgentSessionConfig _config() => AgentSessionConfig(
  executionId: 'exec-1',
  workItemId: 'wi-1',
  workingDirectory: Directory.systemTemp.path,
  timeout: const Duration(minutes: 30),
);

/// A scripted transport that exposes an [StderrTail] — the capability the
/// real `OpenCodeProcessTransport` uses to carry the child's diagnostic
/// stream to the session.
class _TailedTransport implements AcpTransport, StderrTail {
  _TailedTransport({
    this.stderr = '',
    this.promptFailure,
    this.hangPrompt = false,
  });

  final String stderr;
  final Object? promptFailure;
  final bool hangPrompt;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = Completer<Map<String, dynamic>>();
  var _pendingInUse = false;
  bool _open = true;

  @override
  String get stderrTail => stderr;

  @override
  Stream<Map<String, dynamic>> get notifications => _controller.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<AcpInitializeResult> initialize() async => const AcpInitializeResult(
    protocolVersion: 1,
    agentCapabilities: {},
    agentInfo: {'name': 'scripted'},
  );

  @override
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) {
    if (method == 'session/prompt') {
      final failure = promptFailure;
      if (failure != null) {
        return Future.error(failure);
      }
      if (hangPrompt) {
        // The provider-dead shape: the request is simply never answered.
        // `close` completes it with a transport error, exactly as the real
        // transport completes its pending requests when it tears down.
        _pendingInUse = true;
        return _pending.future;
      }
      return Future.value({'stopReason': 'end_turn'});
    }
    return Future.value({'sessionId': 'ses_scripted'});
  }

  @override
  Future<void> close() async {
    _open = false;
    if (_pendingInUse && !_pending.isCompleted) {
      _pending.completeError(const AcpTransportException('transport closed'));
    }
    if (!_controller.isClosed) await _controller.close();
  }
}

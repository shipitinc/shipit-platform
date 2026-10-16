library;

import 'dart:async';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// A scripted ACP server, same shape as `opencode_structured_result_test.dart`:
/// it emits the `session/update` notifications the real `opencode acp` does, so
/// the session is exercised with no live binary, network or credentials.
class ScriptedAcpTransport implements AcpTransport {
  ScriptedAcpTransport({required this.updates});

  final List<Map<String, dynamic>> updates;

  final _notifications = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
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
        'sessionCapabilities': {'resume': true},
      },
      agentInfo: {'name': 'OpenCode', 'version': 'test'},
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
          'agentInfo': {'name': 'OpenCode', 'version': 'test'},
        };
      case 'session/new':
        return {'sessionId': 'ses_review'};
      case 'setSessionConfigOption':
        return {};
      case 'session/prompt':
        for (final update in updates) {
          _notifications.add({
            'method': 'session/update',
            'params': {
              'sessionId': 'ses_review',
              'updates': [update],
            },
          });
        }
        return const {'stopReason': 'end_turn'};
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

Map<String, dynamic> _chunk(String text) => {
  'type': 'agent_message_chunk',
  'message': {
    'messageId': 'm1',
    'content': {'type': 'text', 'text': text},
  },
};

Future<AgentResult> _runReviewTurn(String finalMessage) async {
  final session = OpenCodeSession(
    executionId: 'exec-review',
    workItemId: 'wi-1',
    transportFactory: (_) async =>
        ScriptedAcpTransport(updates: [_chunk(finalMessage)]),
  );
  await session.start(
    const AgentSessionConfig(
      executionId: 'exec-review',
      workItemId: 'wi-1',
      workingDirectory: '/tmp/ws',
      timeout: Duration(minutes: 30),
    ),
  );
  await session.sendInstruction(
    const AgentInstruction(
      instructionId: 'instr-1',
      content: 'Review the implementation.',
    ),
  );
  final result = await session.getResult();
  await session.close();
  return result;
}

/// A review whose prose runs well past the 2000-character summary bound, with
/// the verdict JSON at the very end — where a truncation of the SOURCE would
/// lose it.
const _verdict = '{"verdict":"changes_required"}';

void main() {
  group('the 2000-character summary truncation does not blind extraction', () {
    test('a verdict beyond byte 2000 is still extracted', () async {
      final prose =
          '## Engineering review\n\n'
          '${'The diff adds a retry loop with no bound. ' * 60}\n'
          'Verdict:\n$_verdict';

      expect(
        prose.length,
        greaterThan(2000),
        reason: 'guard the premise: this transcript must exceed the bound',
      );

      final result = await _runReviewTurn(prose);

      // THE ASSERTION. Extraction ran on the full text, so the verdict that
      // lives past the truncation point survived.
      expect(
        result.structuredResult['verdict'],
        'changes_required',
        reason:
            '`_structuredPayload` is called on `_finalText()` BEFORE the '
            '2000-character truncation that bounds `summary`. If those are '
            'ever swapped, this verdict is cut off and every completed review '
            'silently records {} — which is exactly the live QA symptom.',
      );
      expect(result.metadata?['structuredResultPresent'], isTrue);

      // And the truncation is still real, still doing its job, still bounded to
      // what a human reads.
      expect(result.summary!.length, 2000);
      expect(
        result.summary,
        isNot(contains('verdict')),
        reason:
            'the summary really is truncated — that is why the QA row showed '
            'summary_bytes=2000. It is a display bound, not a parse bound.',
      );
    });

    test(
      'a long message with no JSON still yields an honest empty payload',
      () async {
        // The converse, and the anti-fabrication direction: length must not be
        // able to conjure a verdict that was never written.
        final prose =
            '## Engineering review\n\n'
            '${'I looked at the retry loop and I think it needs a bound. ' * 60}\n'
            'I would call this CHANGES_REQUIRED but I did not emit JSON.';

        final result = await _runReviewTurn(prose);

        expect(result.structuredResult, isEmpty);
        expect(result.metadata?['structuredResultPresent'], isFalse);
        expect(
          result.diagnostics.warnings.map((w) => w.code),
          contains('structured_result_absent'),
        );
        // The prose is still readable by a human.
        expect(result.summary, contains('retry loop'));
      },
    );

    test('a verdict inside the bound is extracted the same way', () async {
      final result = await _runReviewTurn('$_verdict');
      expect(result.structuredResult['verdict'], 'changes_required');
      expect(result.summary, contains('changes_required'));
    });
  });
}

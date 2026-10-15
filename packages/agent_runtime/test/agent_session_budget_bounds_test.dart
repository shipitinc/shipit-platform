import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:test/test.dart';

/// There is exactly ONE time bound in the agent runtime, and it is the
/// execution budget. Proven at the source, because provenance is not
/// observable at runtime.
///
/// ## WHY A SOURCE-LEVEL GUARD AND NOT A VALUE ASSERTION
///
/// `apps/server/test/agent_execution_budgets_test.dart` exists because the
/// 300-second engineering-review budget was a typed-in literal with no
/// justification anywhere in the repository. The failure mode it guards is not
/// "someone picks a different number" — it is "someone picks a different number
/// and it reads like a finding", because nothing on the page said whether the
/// value was measured or guessed.
///
/// This file guards the same class of defect one layer further down. There were
/// THREE `Duration(minutes: 5)` literals between the role budget and the agent,
/// none of them reachable by anyone who intended to reach it:
///
///  1. `OpenCodeProcessTransport.requestTimeout` — the class default. Applied
///     to every request on the wire including `session/prompt`. This is what
///     killed two live reviews at 308s and 350s.
///  2. `AgentSessionConfig.timeout` — the constructor default. A caller that
///     forgot to pass one got five minutes and no error.
///  3. `OpenCodeSession._timeout` — the field default.
///
/// A behavioural test can prove that the transport bound behaves like the
/// budget (`opencode_request_timeout_test.dart` does, over a real child
/// process). It cannot prove that nobody has quietly put a literal back, because
/// a restored `Duration(minutes: 5)` is indistinguishable from any other
/// correct value at any budget a test can afford to wait for. So the literal is
/// pinned HERE, and the behaviour is pinned there — the same split
/// `agent_execution_budgets_test.dart` already uses for the same reason.
void main() {
  late String transportSource;
  late String sessionSource;
  late String configSource;
  late String healthProbeSource;

  /// [source] with every `//` and `///` line removed.
  ///
  /// Necessary, because the files being guarded EXPLAIN the defect in their own
  /// doc comments — they name `Duration(minutes: 5)` on purpose, so a reader who
  /// finds it later knows what it was and why it is gone. A guard that counted
  /// those would either fail on correct documentation or, worse, push the next
  /// author to delete the explanation instead of the literal.
  String code(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  setUpAll(() {
    final marker = Directory.current;
    var dir = marker;
    while (dir.parent.path != dir.path) {
      final transport = File(
        '${dir.path}/packages/agent_runtime/lib/src/acp/'
        'opencode_process_transport.dart',
      );
      if (transport.existsSync()) {
        transportSource = transport.readAsStringSync();
        sessionSource = File(
          '${dir.path}/packages/agent_runtime/lib/src/adapters/opencode/'
          'opencode_session.dart',
        ).readAsStringSync();
        configSource = File(
          '${dir.path}/packages/agent_runtime/lib/src/interface/'
          'agent_session.dart',
        ).readAsStringSync();
        healthProbeSource = configSource;
        return;
      }
      dir = dir.parent;
    }
    fail('could not locate packages/agent_runtime above ${marker.path}');
  });

  group('no bare time bound survives anywhere in the runtime', () {
    test('the five-minute literal is gone from every one of its three homes', () {
      for (final entry in {
        'opencode_process_transport.dart': transportSource,
        'opencode_session.dart': sessionSource,
        'agent_session.dart': configSource,
      }.entries) {
        expect(
          RegExp(r'Duration\(minutes:\s*5\)').hasMatch(code(entry.value)),
          isFalse,
          reason:
              '${entry.key} has a `Duration(minutes: 5)` again. This is the '
              'literal that killed two engineering reviews at 308s and 350s: a '
              'per-request ceiling of five minutes applied to a '
              '`session/prompt` that legitimately runs for a three-hour budget. '
              'If a bound is genuinely needed here, name it and derive it — do '
              'not re-type it.',
        );
      }
    });

    test('the transport parameter has no default value at all', () {
      expect(
        RegExp(r'this\.requestTimeout\s*=').hasMatch(code(transportSource)),
        isFalse,
        reason:
            '`requestTimeout` must be OPTIONAL-WITH-NO-DEFAULT, like '
            '`Duration? requestTimeout;`. A default here is how five minutes '
            'reached every request without anyone asking for it.',
      );
      expect(
        RegExp(r'final Duration\? requestTimeout;').hasMatch(transportSource),
        isTrue,
      );
    });

    test('the session config REQUIRES a timeout', () {
      expect(
        RegExp(r'required this\.timeout,').hasMatch(configSource),
        isTrue,
        reason:
            'required, not optional-with-a-default. An optional parameter puts '
            'a five-minute budget back in the file that every caller reads, and '
            'a caller that forgets it gets that budget silently.',
      );
      expect(RegExp(r'this\.timeout\s*=').hasMatch(configSource), isFalse);
    });

    test('the session field has no initialiser', () {
      expect(
        RegExp(r'late final Duration _timeout;').hasMatch(code(sessionSource)),
        isTrue,
        reason:
            '`late final` with no value. It used to read '
            '`Duration _timeout = const Duration(minutes: 5)` — unreachable '
            'through `start`, and still a budget-shaped number sitting in the '
            'file for the next reader to mistake for a live one.',
      );
      expect(
        RegExp(r'_timeout\s*=\s*const Duration').hasMatch(sessionSource),
        isFalse,
      );
    });

    test('the one bound that remains is PASSED IN, not invented', () {
      final factory = sessionSource.substring(
        sessionSource.indexOf('Future<AcpTransport> defaultAcpTransport'),
        sessionSource.indexOf('const String defaultOpencodeProviderId'),
      );
      expect(
        RegExp(r'requestTimeout:\s*config\.timeout').hasMatch(factory),
        isTrue,
        reason:
            '`defaultAcpTransport` must forward the CALLER\'s budget. This is '
            'the actual defect: it passed nothing, so the transport took the '
            'class default and applied it to every request on the wire.',
      );
      expect(
        RegExp(r'requestTimeout:[ \t]+(?!config\.)').hasMatch(factory),
        isFalse,
        reason:
            'the factory must not also pass a bound of its own. Two arguments '
            'to `requestTimeout` would mean two timeouts and one of them '
            'nobody re-derives.',
      );
    });
  });

  group('the health probe bound is named and carries its derivation', () {
    test('it exists as a named constant, not an inline literal', () {
      expect(healthProbeTimeout, isA<Duration>());
      expect(
        RegExp(
          r'const Duration healthProbeTimeout = Duration\(seconds: 30\);',
        ).hasMatch(healthProbeSource),
        isTrue,
      );
    });

    test('its comment says it is provisional and that no stated range exists', () {
      final start = healthProbeSource.indexOf('const Duration healthProbe');
      expect(start, greaterThan(-1));
      // Collapsed to one line: a marker that survives re-wrapping is the point.
      // `dart format` re-wraps comments, so a phrase asserted verbatim is a
      // phrase that fails the next time somebody edits a sentence above it —
      // which is how a guard gets switched off.
      final doc = healthProbeSource
          .substring(0, start)
          .split('\n')
          .map((line) => line.replaceFirst(RegExp(r'^\s*//+ ?'), ''))
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      expect(
        doc.contains('NO OPERATOR-STATED RANGE EXISTS'),
        isTrue,
        reason:
            'there is no measurement of a real `opencode acp` handshake on the '
            'slowest host this runs on. Saying so next to the number is the '
            'only thing that keeps the next reader from assuming somebody '
            'measured it — which is exactly how 300 got there.',
      );
      expect(doc.contains('PROVISIONAL'), isTrue);
      expect(
        doc.contains('THIS IS NOT A SECOND WIRE BOUND'),
        isTrue,
        reason:
            'a health probe asking `initialize` is a different question from '
            '"how long may a review take", and it needs a reader to know that '
            'before deciding this is the three-hour bound in miniature.',
      );
    });

    test('no adapter inlines its own probe budget', () {
      // Every `checkHealth` builds an AgentSessionConfig, and `timeout` is
      // required, so an inline literal here is exactly the shape this lane
      // removed.
      for (final adapter in [
        'lib/src/adapters/opencode/opencode_adapter.dart',
        'lib/src/adapters/design_agent_adapter.dart',
        'lib/src/adapters/design_reviewer_adapter.dart',
      ]) {
        final source = File(adapter).readAsStringSync();
        expect(
          RegExp(r'timeout:\s*const Duration').hasMatch(source),
          isFalse,
          reason:
              '$adapter inlines a timeout. Name it or take healthProbeTimeout.',
        );
        expect(
          RegExp(r'timeout:\s*healthProbeTimeout').hasMatch(source),
          isTrue,
          reason:
              '$adapter must state that its probe runs under the named bound',
        );
      }
    });
  });

  group('the classification rests on WHO raised the error, and that is pinned', () {
    test('AcpRequestException is constructed only from a RECEIVED error object', () {
      // This is the whole basis of "the wire went quiet" being distinguishable
      // from "the agent reported a failure". If a second construction site ever
      // appears, the distinction is a guess rather than a fact, and the
      // retryable classification below it becomes unfounded.
      final constructions = RegExp(
        r'AcpRequestException\(',
      ).allMatches(code(transportSource)).length;
      expect(
        constructions,
        1,
        reason:
            'the transport must construct AcpRequestException exactly once, '
            'inside `_onLine`, from a JSON-RPC `error` object the runtime SENT. '
            'Found $constructions.',
      );
      final stripped = code(transportSource);
      final at = stripped.indexOf('AcpRequestException(');
      final construction = stripped.substring(
        at - 400 < 0 ? 0 : at - 400,
        at + 120,
      );
      expect(
        construction.contains("message['error']"),
        isTrue,
        reason:
            'the one construction site must be inside the received-error '
            'branch. An exception built without a peer having answered is a '
            'transport failure wearing the wrong type.',
      );
    });

    test('every AcpTransportException is a LOCAL condition', () {
      // The complement: each one must be raised by this process, for a reason
      // that is about the wire or the child, never about an answer received.
      final raised = RegExp(
        r"(throw|completeError\()\s*(const\s+)?AcpTransportException\(\s*'([^']*)'",
      ).allMatches(code(transportSource)).map((m) => m.group(3)!).toList();
      expect(
        raised,
        isNotEmpty,
        reason: 'the transport must still raise transport failures at all',
      );
      for (final message in raised) {
        expect(
          message.contains('model') ||
              message.contains('review') ||
              message.contains('refus'),
          isFalse,
          reason:
              '"$message" describes something the RUNTIME said. That is an '
              'assessment and belongs in AcpRequestException, which is '
              'permanent.',
        );
      }
    });
  });
}

import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:test/test.dart';

/// Loopback ACP server: a real child process speaking the same
/// newline-delimited JSON-RPC framing as `opencode acp`, so the transport is
/// exercised over actual stdio without the `opencode` binary, network, or
/// credentials.
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('shipit-acp-loopback');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  group('OpenCodeProcessTransport response correlation', () {
    // Regression test. `_onLine` looked pending requests up by `id.hashCode`
    // while `request` stored them by `id`; in Dart `1.hashCode == 11601`, so
    // every response was decoded and then discarded and every ACP request
    // timed out.
    test('resolves a response whose id differs from its hashCode', () async {
      expect(
        1.hashCode,
        isNot(1),
        reason: 'the id/hashCode divergence this guards against must exist',
      );

      final transport = _loopback(workspace, _echoScript());

      final initialize = await transport.initialize();
      expect(initialize.protocolVersion, equals(1));
      expect(initialize.agentInfo['name'], equals('loopback-acp'));
      expect(transport.pendingRequestCount, isZero);

      // `initialize` uses id 1 without consuming the counter, so the first
      // `nextRequestId` is 1 as well. Every one of 1, 2 and 3 has a hashCode
      // that differs from the id.
      final first = transport.nextRequestId;
      expect(first, equals(1));
      expect(first.hashCode, isNot(first));

      final firstResponse = await transport.request(first, 'session/new', {
        'cwd': workspace.path,
      });
      expect(firstResponse['echoedId'], equals(1));

      final secondResponse = await transport.request(
        transport.nextRequestId,
        'session/prompt',
        {'sessionId': 'ses_loopback'},
      );
      expect(secondResponse['echoedId'], equals(2));

      final thirdResponse = await transport.request(
        transport.nextRequestId,
        'session/prompt',
        {'sessionId': 'ses_loopback'},
      );
      expect(thirdResponse['echoedId'], equals(3));

      // No completer is left behind by any resolved request.
      expect(transport.pendingRequestCount, isZero);
      expect(17.hashCode, isNot(17));

      await transport.close();
    });

    test('fails a pending request with the JSON-RPC error object', () async {
      final transport = _loopback(workspace, _echoScript(error: true));

      await transport.initialize();

      await expectLater(
        transport.request(transport.nextRequestId, 'session/prompt', const {}),
        throwsA(
          isA<AcpRequestException>()
              .having((e) => e.code, 'code', equals(-32000))
              .having(
                (e) => e.message,
                'message',
                contains('loopback failure'),
              ),
        ),
      );
      expect(transport.pendingRequestCount, isZero);

      await transport.close();
    });

    test('keeps serving after a response for an unrequested id', () async {
      final transport = _loopback(workspace, _echoScript());

      await transport.initialize();
      expect(transport.pendingRequestCount, isZero);

      // The loopback answers with an id nobody is waiting on, then the real
      // one: an unknown id must neither crash nor leave a completer behind.
      final response = await transport.request(
        transport.nextRequestId,
        'session/prompt',
        {'sessionId': 'ses_loopback'},
      );
      expect(response['echoedId'], equals(1));
      expect(transport.pendingRequestCount, isZero);

      await transport.close();
    });

    test(
      'correlates a string-encoded response id with the int request id',
      () async {
        final transport = _loopback(workspace, _echoScript(stringIds: true));

        final initialize = await transport.initialize();
        expect(initialize.agentInfo['name'], equals('loopback-acp'));

        final response = await transport.request(
          transport.nextRequestId,
          'session/new',
          {'cwd': workspace.path},
        );
        expect(response['echoedId'], equals(1));
        expect(transport.pendingRequestCount, isZero);

        await transport.close();
      },
    );

    test('close completes outstanding requests instead of hanging', () async {
      final transport = _loopback(workspace, _echoScript(hold: true));

      await transport.initialize();

      final pending = transport.request(
        transport.nextRequestId,
        'session/prompt',
        const {},
      );
      // Attach the expectation before closing so the rejection is handled.
      final rejected = expectLater(
        pending,
        throwsA(isA<AcpTransportException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(transport.pendingRequestCount, equals(1));

      await transport.close();
      await rejected;
      expect(transport.pendingRequestCount, isZero);
    });
  });

  group('server->client requests', () {
    // Regression test for the exec-194 stall: opencode sends
    // `session/request_permission` as a JSON-RPC REQUEST to the client, and
    // the old transport dropped every id-bearing message with no matching
    // pending request — the ask sat unacknowledged until the role budget
    // killed the turn.
    test(
      'answers session/request_permission with a deny and the turn proceeds',
      () async {
        final transport = _loopback(
          workspace,
          _serverRequestScript(
            serverMethod: 'session/request_permission',
            serverParams: _permissionParams,
          ),
        );
        final permissionSignals = <Map<String, dynamic>>[];
        final sub = transport.notifications.listen((message) {
          if (message['method'] == 'acp/permission_denied') {
            permissionSignals.add(message);
          }
        });

        await transport.initialize();

        // The loopback reuses the pending prompt id for its permission
        // request: the transport must answer the server request AND keep
        // the prompt pending — not complete it with the request payload.
        final response = await transport.request(
          transport.nextRequestId,
          'session/prompt',
          {'sessionId': 'ses_loopback'},
        );
        expect(response['serverAnswered'], isTrue);
        expect(response['serverOutcome'], equals('denied'));
        expect(
          permissionSignals,
          hasLength(1),
          reason: 'the denial must be signalled so the session can record it',
        );
        // The signal carries WHAT was refused, not only that a refusal
        // happened: `toolCall.title` names the permission kind and the
        // call's own input is summarised, bounded. This is the evidence a
        // missing-artifact record needs to say WHY the run ended.
        final summary =
            (permissionSignals.single['params']
                    as Map<String, dynamic>)['summary']
                as Map<String, dynamic>;
        expect(summary['title'], equals('external_directory'));
        expect(summary['input'], contains('/etc/passwd'));
        expect(transport.pendingRequestCount, isZero);

        await sub.cancel();
        await transport.close();
      },
    );

    test('answers an unimplemented server->client request with a JSON-RPC '
        'error instead of leaving it unacknowledged', () async {
      final transport = _loopback(
        workspace,
        _serverRequestScript(
          serverMethod: 'fs/read_text_file',
          serverParams: '{"sessionId":"ses_loopback","path":"/etc/passwd"}',
        ),
      );

      await transport.initialize();

      final response = await transport.request(
        transport.nextRequestId,
        'session/prompt',
        {'sessionId': 'ses_loopback'},
      );
      expect(response['serverAnswered'], isTrue);
      expect(response['serverOutcome'], equals('method_not_found'));
      expect(transport.pendingRequestCount, isZero);

      await transport.close();
    });
  });
}

/// Writes the loopback script into [workspace] and returns a transport that
/// spawns it.
OpenCodeProcessTransport _loopback(Directory workspace, String script) {
  final path = '${workspace.path}/acp-server.sh';
  File(path).writeAsStringSync(script);
  Process.runSync('chmod', ['+x', path]);
  return OpenCodeProcessTransport(
    executable: path,
    cwd: workspace.path,
    requestTimeout: const Duration(seconds: 15),
  );
}

/// Loopback source. `__ID__` is the correlation id as it appears on the wire
/// and `__DEFAULT_ARM__` is the `case` arm answering every non-`initialize`
/// request. Both printf format strings are double-quoted so the shell expands
/// `$id` while the JSON quotes stay escaped.
const String _loopbackTemplate = r'''#!/bin/sh
# Minimal ACP loopback used by agent_runtime tests.
while IFS= read -r line; do
  case "$line" in
    *'"method"'*) ;;
    *) continue ;;
  esac
  id=$(printf '%s' "$line" | sed -n 's/^{"jsonrpc":"2\.0","id":\([0-9][0-9]*\),.*/\1/p')
  [ -n "$id" ] || continue
  case "$line" in
    *'"method":"initialize"'*)
      printf "{\"jsonrpc\":\"2.0\",\"id\":__ID__,\"result\":{\"protocolVersion\":1,\"agentCapabilities\":{\"sessionCapabilities\":{\"resume\":true}},\"agentInfo\":{\"name\":\"loopback-acp\",\"version\":\"0.0.0-test\"}}}\n"
      ;;
__DEFAULT_ARM__
  esac
done
''';

/// Builds a POSIX-sh ACP loopback that answers every request it reads.
///
/// * [stringIds] echoes the id as a JSON string instead of a number, which is
///   the other id form JSON-RPC allows.
/// * [error] answers with a JSON-RPC error object instead of a result.
/// * [hold] swallows every non-`initialize` request without answering, so the
///   test can close the transport with a request still outstanding.
String _echoScript({
  bool stringIds = false,
  bool error = false,
  bool hold = false,
}) {
  final arm = hold
      ? '    *)\n      :\n'
      : error
      ? '    *)\n'
            '      printf "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":__ID__,'
            '\\"error\\":{\\"code\\":-32000,'
            '\\"message\\":\\"loopback failure\\"}}\\n"\n'
      : '    *)\n'
            '      printf "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":__ID__,'
            '\\"result\\":{\\"echoedId\\":\$id}}\\n"\n';
  return _loopbackTemplate
      .replaceAll('__DEFAULT_ARM__', arm)
      .replaceAll('__ID__', stringIds ? r'\"$id\"' : r'$id');
}

/// The options list opencode 1.18.x sends on `session/request_permission`:
/// allow-once, allow-always, reject. The honest deny is the offered
/// reject-kind option, not a fabricated id.
const String _permissionParams =
    '{"sessionId":"ses_loopback",'
    '"toolCall":{"toolCallId":"call_1","title":"external_directory",'
    '"kind":"other","status":"pending",'
    '"rawInput":{"filePath":"/etc/passwd"}},'
    '"options":['
    '{"optionId":"once","kind":"allow_once","name":"Allow once"},'
    '{"optionId":"always","kind":"allow_always","name":"Always allow"},'
    '{"optionId":"reject","kind":"reject_once","name":"Reject"}'
    ']}';

/// A loopback that, on `session/prompt`, first sends a SERVER->CLIENT
/// request ([serverMethod], [serverParams]) reusing the still-pending prompt
/// id, then blocks the turn until the client answers it, and only then
/// answers the prompt. The prompt result carries `serverAnswered`/`serverOutcome`
/// so the test can see exactly what the client wrote back — or, on a
/// regression, the turn simply stalls and the request timeout fails it,
/// which is the exec-194 defect reproduced.
String _serverRequestScript({
  required String serverMethod,
  required String serverParams,
}) {
  final arm =
      '    *\'"method":"session/prompt"\'*)\n'
      // Ask the client, reusing the pending prompt id: the collision is
      // deliberate — a server request id must not resolve a client request.
      '      printf "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":%s,'
      '\\"method\\":\\"%s\\",\\"params\\":%s}\\n"'
      ' "\$id" "$serverMethod" \'$serverParams\'\n'
      '      reply=""\n'
      '      while IFS= read -r reply; do\n'
      '        case "\$reply" in\n'
      '          *"\\"id\\":\$id"*) break ;;\n'
      '        esac\n'
      '      done\n'
      '      verdict="other"\n'
      '      case "\$reply" in\n'
      '        *\'"optionId":"reject"\'*) verdict="denied" ;;\n'
      '        *\'"outcome":"cancelled"\'*) verdict="cancelled" ;;\n'
      '        *\'"code":-32601\'*) verdict="method_not_found" ;;\n'
      '      esac\n'
      '      printf "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":%s,'
      '\\"result\\":{\\"serverAnswered\\":true,'
      '\\"serverOutcome\\":\\"%s\\"}}\\n" "\$id" "\$verdict"\n'
      '      ;;\n'
      '    *)\n'
      '      printf "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":__ID__,'
      '\\"result\\":{\\"echoedId\\":\$id}}\\n"\n'
      '      ;;\n';
  return _loopbackTemplate
      .replaceAll('__DEFAULT_ARM__', arm)
      .replaceAll('__ID__', r'$id');
}

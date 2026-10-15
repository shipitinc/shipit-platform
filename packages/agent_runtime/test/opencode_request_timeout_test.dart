import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// The ACP transport's per-request bound is the EXECUTION BUDGET, and nothing
/// shorter. This is the behavioural proof, over a real child process.
///
/// ## THE DEFECT THIS FILE EXISTS FOR
///
/// `defaultAcpTransport` never passed `requestTimeout`, so
/// `OpenCodeProcessTransport` took its class default — `Duration(minutes: 5)` —
/// and applied it to every request on the wire, `session/prompt` included.
/// `session/prompt` is the whole review. Two engineering reviews died live with
///
/// ```text
/// agx-wx-jb-hn8k1nc7pa-ul85i2  ENGINEERING_REVIEWER  failed  308s
/// agx-wx-jb-hn8k1n8ktg-mgxaf7  ENGINEERING_REVIEWER  failed  350s
/// reason: AcpTransportException: ACP request timed out: session/prompt
/// ```
///
/// A 3-hour budget, a 5-minute transport ceiling, and a 300s that had been
/// fixed one layer further out. Same defect class each time: a number nobody
/// measured, sitting between the budget and the work.
///
/// ## WHY THERE IS A REAL PROCESS AND A REAL CLOCK HERE
///
/// A test that asserts `transport.requestTimeout == config.timeout` proves
/// nothing about behaviour: it would pass with the factory passing the right
/// value into a transport whose timer is never consulted, or consulted but
/// never consulted at the request the bound is for. So the bound is exercised
/// where it bites — a `session/prompt` that stays on the wire for most of its
/// own budget, against a real POSIX-sh ACP loopback speaking real
/// newline-delimited JSON-RPC over real stdio.
///
/// Durations here are scaled down by ~6000x from production (3s budget, 2s
/// prompt, in place of 3h/2h) because the SHAPE is what is under test: a bound
/// that is shorter than the budget and shorter than the prompt's own runtime
/// kills it, and one that is not, does not. Scaling is stated per test and the
/// non-vacuity controls below run the same three cases with an explicitly
/// tightened or loosened transport bound so that the difference is observed,
/// not assumed.
///
/// The one thing wall clock cannot prove quickly is a literal `Duration(minutes:
/// 5)` specifically: distinguishing it from a 3-hour budget requires a budget
/// above five minutes, i.e. a test longer than five minutes. That half is pinned
/// at the source instead, by `agent_session_budget_bounds_test.dart`, which
/// fails if the literal is put back. This file proves the BEHAVIOUR the literal
/// broke.
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('shipit-acp-budget');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  /// Drives a real [OpenCodeSession] over a real child process and reports how
  /// long `session/prompt` was on the wire.
  Future<({AgentSessionStatus status, Duration elapsed, String reason})>
  runPrompt({
    required Duration budget,
    required Duration promptDelay,
    bool neverAnswers = false,
    Duration? transportBound,
  }) async {
    final executable = _writeLoopback(
      workspace,
      promptDelay: promptDelay,
      neverAnswers: neverAnswers,
    );
    // The factory under test. `transportBound` is null in the regression case,
    // which is what production does; the controls below inject one explicitly.
    final session = OpenCodeSession(
      executionId: 'exec-budget',
      workItemId: 'wi-budget',
      transportFactory: transportBound == null
          ? defaultAcpTransport
          : (config) async => OpenCodeProcessTransport(
              executable: executable,
              cwd: workspace.path,
              environment: config.environment,
              requestTimeout: transportBound,
            ),
    );

    final events = <AgentEvent>[];
    final sub = session.eventStream.listen(events.add);
    addTearDown(sub.cancel);

    await session.start(
      AgentSessionConfig(
        executionId: 'exec-budget',
        workItemId: 'wi-budget',
        workingDirectory: workspace.path,
        timeout: budget,
        // The REAL factory path, not a double: this is the argument
        // `defaultAcpTransport` reads the executable out of.
        runtimeConfig: {'executable': executable},
      ),
    );
    expect(session.sessionId, 'ses_loopback', reason: 'precondition: it ran');

    final started = DateTime.now();
    await session.sendInstruction(
      const AgentInstruction(
        instructionId: 'instr-1',
        content: 'Review the diff and return a verdict.',
      ),
    );
    final elapsed = DateTime.now().difference(started);
    // Drain the broadcast queue before reading the terminal event.
    await Future<void>.delayed(Duration.zero);

    final terminal = events.whereType<SessionInterrupted>().firstOrNull;
    final reason =
        terminal?.reason ??
        events.whereType<SessionFailed>().firstOrNull?.error ??
        session.getResult().toString();
    return (status: session.status, elapsed: elapsed, reason: reason);
  }

  group('a prompt that runs long is NOT cut short by a bound of its own', () {
    test('a session/prompt occupying two thirds of its budget completes', () async {
      // 2s of a 3s budget. The old defect, scaled: a prompt outliving anything
      // shorter than its own budget was aborted mid-review.
      final outcome = await runPrompt(
        budget: const Duration(seconds: 6),
        promptDelay: const Duration(seconds: 2),
      );

      expect(
        outcome.status,
        AgentSessionStatus.completed,
        reason:
            'the wire wait ran the full ${outcome.elapsed.inMilliseconds}ms and '
            'the runtime answered. The transport bound is the budget (6s), and '
            'the prompt (2s) is inside it.',
      );
      expect(
        outcome.elapsed,
        greaterThanOrEqualTo(const Duration(seconds: 2)),
        reason: 'the loopback really did hold the request open for its delay',
      );
      expect(outcome.elapsed, lessThan(const Duration(seconds: 6)));
    });
  });

  group('NON-VACUITY: the same three cases with the bound set deliberately', () {
    test(
      'a wire bound SHORTER than the prompt kills it — this is the bug',
      () async {
        // The structural shape of `Duration(minutes: 5)` against a 3-hour review:
        // a per-request ceiling shorter than the work. 600ms of a 4s prompt.
        final outcome = await runPrompt(
          budget: const Duration(seconds: 12),
          promptDelay: const Duration(seconds: 10),
          transportBound: const Duration(seconds: 2),
        );

        expect(
          outcome.status,
          AgentSessionStatus.interrupted,
          reason:
              'the transport gave up at 2s — well inside a 10s prompt — and the '
              'session reported an interruption. This is what production did to a '
              'review that was working perfectly.',
        );
        expect(
          outcome.elapsed,
          lessThan(const Duration(seconds: 6)),
          reason:
              'it died at the TRANSPORT bound, not at the 12s budget — so the '
              'test is genuinely reading the transport\'s timer and is not '
              'vacuous. If this ever passed at ~10s the bound was not applied.',
        );
      },
    );

    test('a wire bound LONGER than the budget changes nothing — it is dead '
        'code, which is why the old doc comment was wrong', () async {
      final outcome = await runPrompt(
        budget: const Duration(seconds: 6),
        promptDelay: const Duration(seconds: 1),
        transportBound: const Duration(seconds: 60),
      );

      expect(outcome.status, AgentSessionStatus.completed);
      expect(
        outcome.elapsed,
        lessThan(const Duration(seconds: 6)),
        reason:
            'the session\'s own budget ended the wait, not the 60s transport '
            'bound. That is the argument the design comment rests on: at any '
            'value at or above the budget this field cannot change an outcome, '
            'because the coordinator\'s budget clock starts earlier still.',
      );
    });
  });

  group('the protection is not REMOVED, it is moved to the budget', () {
    test(
      'a prompt the runtime never answers is still ended, at the budget',
      () async {
        final started = DateTime.now();
        final outcome = await runPrompt(
          budget: const Duration(seconds: 2),
          promptDelay: Duration.zero,
          neverAnswers: true,
        );
        final wallClock = DateTime.now().difference(started);

        expect(
          outcome.status,
          AgentSessionStatus.interrupted,
          reason:
              'a silent runtime still ends as an interruption. Losing the '
              'five-minute literal did not leave the wire unbounded.',
        );
        expect(
          outcome.elapsed,
          lessThan(const Duration(seconds: 4)),
          reason: 'and it ended at the budget, not after some other number',
        );
        expect(wallClock, lessThan(const Duration(seconds: 10)));
      },
    );
  });
}

/// Writes a POSIX-sh ACP loopback that behaves like `opencode acp` over stdio,
/// and returns its path.
///
/// It answers `initialize` and `session/new`, and holds `session/prompt` for
/// [promptDelay] before answering — or never answers it when [neverAnswers] is
/// set. No `sleep` is spawned in the `neverAnswers` case, so a test that ends
/// with the child mid-prompt leaves no orphaned process behind.
String _writeLoopback(
  Directory workspace, {
  required Duration promptDelay,
  required bool neverAnswers,
}) {
  final path = '${workspace.path}/acp-budget-loopback.sh';
  final hold = neverAnswers
      ? '      :'
      : '''
      sleep ${promptDelay.inMilliseconds / 1000}
      printf '{"jsonrpc":"2.0","id":%s,"result":{"stopReason":"end_turn"}}\\n' "\$id"''';
  File(path).writeAsStringSync('''
#!/bin/sh
# Minimal ACP loopback that holds `session/prompt` open, used by
# opencode_request_timeout_test.dart. See that file for why the delay matters.
while IFS= read -r line; do
  case "\$line" in
    *'"method"'*) ;;
    *) continue ;;
  esac
  id=\$(printf '%s' "\$line" | sed -n 's/^{"jsonrpc":"2\\.0","id":\\([0-9][0-9]*\\),.*/\\1/p')
  [ -n "\$id" ] || continue
  case "\$line" in
    *'"method":"initialize"'*)
      printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":1,"agentCapabilities":{"sessionCapabilities":{"resume":true}},"agentInfo":{"name":"loopback-acp","version":"0.0.0-test"}}}\\n' "\$id"
      ;;
    *'"method":"session/new"'*|*'"method":"session/resume"'*)
      printf '{"jsonrpc":"2.0","id":%s,"result":{"sessionId":"ses_loopback"}}\\n' "\$id"
      ;;
    *'"method":"session/prompt"'*)
$hold
      ;;
    *)
      printf '{"jsonrpc":"2.0","id":%s,"result":{}}\\n' "\$id"
      ;;
  esac
done
''');
  Process.runSync('chmod', ['+x', path]);
  return path;
}

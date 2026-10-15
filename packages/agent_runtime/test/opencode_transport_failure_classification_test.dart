import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// A wire failure is not an agent verdict, and this file is the seam where that
/// stops being true.
///
/// ## WHY THE DISTINCTION IS WORTH A FILE
///
/// Live QA lost two engineering reviews to
/// `AcpTransportException: ACP request timed out: session/prompt`. Both jobs
/// settled `failed` at attempt 1 of 2 — **spending zero attempts** — and both
/// work items were stranded at `review_in_progress` with no blocking decision.
/// The retry budget was sitting in the source, spendable, and unreachable.
///
/// The chain that made it unreachable has no discretion in it:
///
/// ```text
/// SessionFailed      -> AgentSessionStatus.failed     -> executedFail
///                    -> JobFailureKind.permanent      -> failed, 0 attempts
/// SessionInterrupted -> AgentSessionStatus.interrupted -> timedOut
///                    -> JobFailureKind.transient       -> scheduleRetry
/// ```
///
/// So `OpenCodeSession` routing an `AcpTransportException` to `SessionFailed`
/// classified "the runtime stopped answering" as "the agent returned a bad
/// review" — a verdict the system does not have and never had. That is the same
/// class of error as fabricating a review decision.
///
/// ## THE BOUNDARY IS STRUCTURAL
///
/// It is not a heuristic over message text. The two failure shapes are raised by
/// two different sides of the wire, and each exception type is constructed in
/// exactly one place:
///
///  * `AcpRequestException` — built in `OpenCodeProcessTransport._onLine` from a
///    JSON-RPC `error` object the runtime SENT. The agent answered.
///  * `AcpTransportException` — built only by the local transport (not open,
///    closed, child exited, request timed out). Nobody answered.
///
/// `agent_session_budget_bounds_test.dart` pins that construction-site property
/// at the source, because it is the property the whole classification rests on
/// and it is not observable at runtime.
void main() {
  late List<AgentEvent> events;

  setUp(() => events = <AgentEvent>[]);

  /// Runs one instruction against a transport scripted to fail in [onPrompt],
  /// and returns the events it emitted.
  Future<List<AgentEvent>> promptThatFails(
    Object failure, {
    void Function(ScriptedTransport transport)? duringPrompt,
  }) async {
    final transport = ScriptedTransport(
      onPrompt: (_) => throw failure,
      afterPrompt: duringPrompt,
    );
    final session = OpenCodeSession(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      transportFactory: (_) async => transport,
    );
    final sub = session.eventStream.listen(events.add);
    await session.start(_config());
    await session.sendInstruction(
      const AgentInstruction(instructionId: 'i1', content: 'review this'),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    await session.close();
    return events;
  }

  group('the wire went quiet — an interruption, not a verdict', () {
    test('a timed-out request settles interrupted, not failed', () async {
      await promptThatFails(
        const AcpTransportException('ACP request timed out: session/prompt'),
      );

      expect(
        events.whereType<SessionFailed>(),
        isEmpty,
        reason:
            'NOT `SessionFailed`. `failed` settles as JobFailureKind.permanent '
            'and spends zero attempts, which is how a review died at 308s with '
            'its retry budget untouched.',
      );
      expect(events.whereType<SessionInterrupted>(), hasLength(1));
    });

    test('a child that exited mid-prompt settles interrupted', () async {
      await promptThatFails(
        const AcpTransportException(
          'child process exited: opencode acp '
          'exited (code 1)',
        ),
      );

      expect(events.whereType<SessionFailed>(), isEmpty);
      expect(events.whereType<SessionInterrupted>(), hasLength(1));
    });

    test('a `transport/closed` notification settles interrupted', () async {
      await promptThatFails(
        const AcpTransportException('child process exited'),
        duringPrompt: (t) => t.announceClosed('opencode acp exited (code 1)'),
      );

      expect(
        events.whereType<SessionFailed>(),
        isEmpty,
        reason: 'the runtime went away; it did not return a verdict',
      );
      expect(events.whereType<SessionInterrupted>(), hasLength(1));
    });

    test('a dead child reports EXACTLY ONE terminal event', () async {
      // A crashed child produces TWO signals for one failure: `_handleChildExit`
      // completes the outstanding request with an AcpTransportException AND
      // emits `transport/closed`. Before the `_settled` guard both reached
      // `_handleTransportFailure`, so the coordinator was handed two terminal
      // events for a single interruption and the durable outcome depended on
      // which landed first.
      final emitted = await promptThatFails(
        const AcpTransportException('child process exited'),
        duringPrompt: (t) => t.announceClosed('opencode acp exited (code 1)'),
      );

      final terminal = emitted.where(
        (e) =>
            e is SessionCompleted ||
            e is SessionFailed ||
            e is SessionCancelled ||
            e is SessionInterrupted,
      );
      expect(
        terminal,
        hasLength(1),
        reason:
            'one failure, one terminal event. Two let the coordinator pick a '
            'winner by arrival order, which is not a verdict mechanism.',
      );
    });

    test('the result says the runtime never answered', () async {
      final transport = ScriptedTransport(
        onPrompt: (_) => throw const AcpTransportException(
          'ACP request timed out: '
          'session/prompt',
        ),
      );
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'wi-1',
        transportFactory: (_) async => transport,
      );
      await session.start(_config());
      await session.sendInstruction(
        const AgentInstruction(instructionId: 'i1', content: 'review this'),
      );

      final result = await session.getResult();
      expect(
        result.status,
        AgentResultStatus.partial,
        reason: 'a run cut short is not a run that produced a failure',
      );
      expect(result.metadata?['runtimeAnswered'], isFalse);
      expect(
        result.metadata?['interruptedBecause'],
        contains('returned no assessment'),
        reason:
            'the durable record has to carry WHY it was interrupted, or the '
            'next reader sees an interruption with no cause and infers one.',
      );
      await session.close();
    });
  });

  group('the agent answered — that IS a verdict, and stays permanent', () {
    test('a JSON-RPC error object settles failed', () async {
      await promptThatFails(
        const AcpRequestException(-32000, 'model refused the request'),
      );

      expect(
        events.whereType<SessionFailed>(),
        hasLength(1),
        reason:
            'The control. The runtime SENT this; it is an assessment, and it '
            'classifies as permanent and spends no attempt. Collapsing it into '
            'the transport case is what would turn a broken runtime into a '
            'retry loop.',
      );
      expect(events.whereType<SessionInterrupted>(), isEmpty);
    });

    test('and its result says the runtime did answer', () async {
      final transport = ScriptedTransport(
        onPrompt: (_) =>
            throw const AcpRequestException(-32000, 'model refused'),
      );
      final session = OpenCodeSession(
        executionId: 'exec-1',
        workItemId: 'wi-1',
        transportFactory: (_) async => transport,
      );
      await session.start(_config());
      await session.sendInstruction(
        const AgentInstruction(instructionId: 'i1', content: 'review this'),
      );

      final result = await session.getResult();
      expect(result.status, AgentResultStatus.failed);
      expect(result.metadata?['runtimeAnswered'], isTrue);
      await session.close();
    });
  });

  group('a start-timeout is a transport failure, and propagates as one', () {
    test(
      'start reports it as an AcpTransportException naming the budget',
      () async {
        final session = OpenCodeSession(
          executionId: 'exec-1',
          workItemId: 'wi-1',
          transportFactory: (_) async => ScriptedTransport(
            onInitialize: () => throw const AcpTransportException(
              'ACP request timed out: '
              'initialize',
            ),
          ),
        );

        await expectLater(
          session.start(_config()),
          throwsA(
            isA<AcpTransportException>().having(
              (e) => e.message,
              'message',
              contains('initialize'),
            ),
          ),
        );
        await session.close();
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

/// A transport whose every call is scripted, used to drive the two exception
/// shapes through the real session.
class ScriptedTransport implements AcpTransport {
  ScriptedTransport({this.onInitialize, this.onPrompt, this.afterPrompt});

  final void Function()? onInitialize;
  final Map<String, dynamic> Function(Map<String, dynamic> params)? onPrompt;

  /// Runs while the prompt request is outstanding — used to simulate the child
  /// dying underneath an in-flight request.
  final void Function(ScriptedTransport transport)? afterPrompt;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _open = true;

  @override
  Stream<Map<String, dynamic>> get notifications => _controller.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<AcpInitializeResult> initialize() async {
    onInitialize?.call();
    return const AcpInitializeResult(
      protocolVersion: 1,
      agentCapabilities: {},
      agentInfo: {'name': 'scripted'},
    );
  }

  /// Emits the `transport/closed` notification the real transport raises when
  /// the child process exits.
  void announceClosed(String reason) {
    _controller.add({
      'method': 'transport/closed',
      'params': {'reason': reason},
    });
  }

  @override
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    if (method == 'session/prompt') {
      final result = onPrompt?.call(params);
      afterPrompt?.call(this);
      return result ?? {'stopReason': 'end_turn'};
    }
    return {'sessionId': 'ses_scripted'};
  }

  @override
  Future<void> close() async {
    _open = false;
    if (!_controller.isClosed) await _controller.close();
  }
}

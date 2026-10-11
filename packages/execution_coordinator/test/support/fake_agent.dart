import 'dart:async';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// A scripted [AgentSession] for coordinator tests. Because the coordinator
///  /// subscribes to the stream after `start`, and because broadcast delivery must
///  /// be deterministic, the controller is synchronous: events are delivered
///  /// straight through during the adds.
class FakeAgentSession implements AgentSession {
  FakeAgentSession({
    required this.executionId,
    required this.workItemId,
    this.behavior = FakeBehavior.complete,
    this.sessionId = 'ses-fake',
    this.startGate,
    this.instructionGate,
  });

  final String executionId;
  final String workItemId;
  final String sessionId;
  final FakeBehavior behavior;

  final _events = StreamController<AgentEvent>.broadcast(sync: true);
  AgentSessionStatus _status = AgentSessionStatus.starting;
  var _cancelled = false;

  /// When non-null, `createSession` wedges until this gate is completed. Models
  /// a runtime that takes an unbounded time to bring a session up, and — because
  /// the wedge is RELEASABLE — one that eventually answers after the
  /// coordinator has already given up on it.
  final Completer<void>? startGate;

  /// When non-null, `sendInstruction` wedges until this gate is completed. Same
  /// purpose for the instruction round trip.
  final Completer<void>? instructionGate;

  @override
  AgentSessionStatus get status => _status;

  @override
  Stream<AgentEvent> get eventStream => _events.stream;

  /// Lets a wedged `start` answer, so a test can resume a drive path that the
  /// coordinator's budget already gave up on.
  void releaseStart() {
    final gate = startGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// Lets a wedged `sendInstruction` answer.
  void releaseInstruction() {
    final gate = instructionGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// Emits a completion as though the agent finished, for a session whose
  /// configured behaviour never does so on its own. Used to deliver a terminal
  /// event AFTER the coordinator stopped waiting for one.
  void emitLateCompletion() {
    if (_status == AgentSessionStatus.completed) return;
    _status = AgentSessionStatus.completed;
    unawaited(
      getResult().then(
        (result) => _events.add(
          SessionCompleted(
            eventId: 'evt-late-complete',
            timestamp: DateTime.now(),
            result: result,
          ),
        ),
      ),
    );
  }

  Future<void> start(AgentSessionConfig config) async {
    final gate = startGate;
    if (gate != null) await gate.future;
    _status = AgentSessionStatus.running;
    _events.add(
      SessionStarted(
        eventId: 'evt-start',
        timestamp: DateTime.now(),
        sessionId: sessionId,
        workItemId: workItemId,
      ),
    );
  }

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {
    final gate = instructionGate;
    if (gate != null) await gate.future;
    _events.add(
      AgentMessageChunk(
        eventId: 'evt-chunk',
        timestamp: DateTime.now(),
        messageId: 'm1',
        text: 'implementing the calculator',
      ),
    );
    _events.add(
      ToolCallStarted(
        eventId: 'evt-tool',
        timestamp: DateTime.now(),
        toolCallId: 'call-1',
        tool: 'write_file',
        arguments: const {'path': 'lib/calculator.dart'},
      ),
    );
    _events.add(
      ToolCallCompleted(
        eventId: 'evt-tool-out',
        timestamp: DateTime.now(),
        toolCallId: 'call-1',
        result: const {'content': 'done'},
      ),
    );

    switch (behavior) {
      case FakeBehavior.hangOnInstruction:
        // The instruction round trip never answers and never emits a terminal
        // event: the shape of a wedged agent process. Nothing here returns, so
        // the only thing that can end this execution is the budget.
        await Completer<void>().future;
      case FakeBehavior.neverTerminate:
        // The instruction is accepted and the session keeps talking, but no
        // terminal event is ever emitted - the shape of a session that stalls
        // after doing work. Only the coordinator's budget can end this.
        return;
      case FakeBehavior.complete:
        _status = AgentSessionStatus.completed;
        _events.add(
          SessionCompleted(
            eventId: 'evt-complete',
            timestamp: DateTime.now(),
            result: await getResult(),
          ),
        );
      case FakeBehavior.interrupt:
        _status = AgentSessionStatus.interrupted;
        _events.add(
          SessionInterrupted(
            eventId: 'evt-interrupt',
            timestamp: DateTime.now(),
            reason: 'instruction timeout',
          ),
        );
      case FakeBehavior.fail:
        _status = AgentSessionStatus.failed;
        _events.add(
          SessionFailed(
            eventId: 'evt-fail',
            timestamp: DateTime.now(),
            error: 'model errored',
            recoverable: true,
          ),
        );
      case FakeBehavior.cancelRequested:
        // Cancel is driven externally via [cancel]; nothing to emit here.
        break;
    }
  }

  @override
  Future<void> cancel(String reason) async {
    if (_cancelled) return;
    _cancelled = true;
    _status = AgentSessionStatus.cancelled;
    _events.add(
      SessionCancelled(
        eventId: 'evt-cancel',
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );
  }

  @override
  Future<AgentResult> getResult() async {
    final complete = _status == AgentSessionStatus.completed;
    return AgentResult(
      resultId: 'result-$sessionId',
      sessionId: sessionId,
      workItemId: workItemId,
      status: complete
          ? AgentResultStatus.completed
          : _cancelled
          ? AgentResultStatus.cancelled
          : AgentResultStatus.failed,
      artifacts: const [],
      diagnostics: AgentDiagnostics(
        exitCode: complete ? 0 : 1,
        durationMs: 10,
        toolCalls: 1,
        errors: complete
            ? const []
            : [
                const DiagnosticEntry(
                  code: 'behavior',
                  message: 'scripted non-complete behavior',
                  severity: 'error',
                ),
              ],
        warnings: const [],
      ),
      structuredResult: const {},
      summary: complete
          ? 'implemented and verified the calculator'
          : 'did not complete',
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> close() async {
    if (!_events.isClosed) {
      await _events.close();
    }
  }
}

enum FakeBehavior {
  complete,
  fail,
  interrupt,
  cancelRequested,

  /// Accepts the instruction, emits activity, and then never emits a terminal
  /// event.
  neverTerminate,

  /// Never answers the instruction at all.
  hangOnInstruction,
}

class FakeAgentAdapter implements AgentAdapter {
  FakeAgentAdapter(this._session);

  final FakeAgentSession _session;

  @override
  final String providerId = 'fake-runtime';

  @override
  final String displayName = 'Fake Runtime';

  @override
  final RuntimeCapabilities capabilities = RuntimeCapabilities(
    supported: {
      RuntimeCapability.readFiles,
      RuntimeCapability.modifyFiles,
      RuntimeCapability.runTests,
      RuntimeCapability.cancellable,
      RuntimeCapability.resumeSession,
    },
  );

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    await _session.start(config);
    return _session;
  }

  @override
  Future<AgentSession> resumeSession(AgentSessionConfig config) async {
    await _session.start(config);
    return _session;
  }

  @override
  Future<bool> canResume(String sessionId) async => true;

  @override
  Future<AdapterHealth> checkHealth() async =>
      const AdapterHealth(healthy: true, version: 'fake');

  @override
  Future<void> shutdown() async {}
}

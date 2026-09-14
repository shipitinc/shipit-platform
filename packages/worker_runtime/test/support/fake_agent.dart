import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// A scripted [AgentSession] that additionally WRITES the calculator
/// implementation into the session's [AgentSessionConfig.workingDirectory]
/// (the isolated worktree), so git-observed diff capture, cleanup and source
/// isolation can be asserted deterministically.
class WritingFakeAgentSession implements AgentSession {
  WritingFakeAgentSession({
    required this.executionId,
    required this.workItemId,
    this.behavior = WritingBehavior.writeImplementation,
    this.sessionId = 'ses-fake',
    this.writeTarget,
  });

  final String executionId;
  final String workItemId;
  final String sessionId;
  final WritingBehavior behavior;

  /// If set, the agent writes the correct implementation to this absolute
  /// path during execution. Defaults to `<cwd>/lib/calculator.dart`.
  File? writeTarget;

  final _events = StreamController<AgentEvent>.broadcast(sync: true);
  AgentSessionStatus _status = AgentSessionStatus.starting;
  var _cancelled = false;
  var _started = false;

  @override
  AgentSessionStatus get status => _status;

  @override
  Stream<AgentEvent> get eventStream => _events.stream;

  @override
  Future<void> start(AgentSessionConfig config) async {
    _started = true;
    if (writeTarget == null) {
      writeTarget = File('${config.workingDirectory}/lib/calculator.dart');
    }
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

  bool get wasStarted => _started;

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {
    writeTarget!.parent.createSync(recursive: true);
    if (behavior == WritingBehavior.writeImplementation) {
      writeTarget!.writeAsStringSync('int add(int a, int b) => a + b;\n');
      _status = AgentSessionStatus.completed;
      _events.add(
        SessionCompleted(
          eventId: 'evt-complete',
          timestamp: DateTime.now(),
          result: await getResult(),
        ),
      );
    } else {
      _status = AgentSessionStatus.failed;
      _events.add(
        SessionFailed(
          eventId: 'evt-fail',
          timestamp: DateTime.now(),
          error: 'scripted failure',
          recoverable: true,
        ),
      );
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
        durationMs: 1,
        toolCalls: 1,
        errors: complete
            ? const []
            : [
                const DiagnosticEntry(
                  code: 'scripted',
                  message: 'scripted behavior',
                  severity: 'error',
                ),
              ],
        warnings: const [],
      ),
      structuredResult: const {},
      summary: complete
          ? 'implemented the calculator in the worktree'
          : 'did not complete',
      completedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> close() async {
    if (!_events.isClosed) await _events.close();
  }
}

enum WritingBehavior { writeImplementation, fail }

class WritingFakeAgentAdapter implements AgentAdapter {
  WritingFakeAgentAdapter(this._session);

  final WritingFakeAgentSession _session;

  @override
  final String providerId = 'fake-runtime';

  @override
  final String displayName = 'Writing Fake Runtime';

  @override
  final RuntimeCapabilities capabilities = RuntimeCapabilities(
    supported: {
      RuntimeCapability.readFiles,
      RuntimeCapability.modifyFiles,
      RuntimeCapability.runTests,
      RuntimeCapability.cancellable,
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

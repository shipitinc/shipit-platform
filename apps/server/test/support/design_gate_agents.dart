import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// A scripted [AgentSession] that starts, then PAUSES until [release] (or
/// [cancel]) so a test can deterministically observe the scheduler holding one
/// worker execution in flight (capacity-1 behaviour) without any timers.
/// When released it writes the reference calculator implementation into the
/// session's working directory (the isolated worktree), so the verifier and
/// git-observed diff capture behave exactly like the scheduler slice's fake.
///
/// The session is REUSABLE: only the FIRST execution parks on the release
/// gate; each subsequent [start] targets the new execution's working directory
/// and auto-releases so one host can run multiple sequential executions.
class DesignGateAgentSession implements AgentSession {
  DesignGateAgentSession({
    required this.executionId,
    this.sessionId = 'ses-design-gate',
  });

  @override
  final String executionId;
  @override
  String workItemId = '';
  @override
  String sessionId;

  StreamController<AgentEvent> _events = StreamController<AgentEvent>.broadcast(
    sync: true,
  );
  AgentSessionStatus _status = AgentSessionStatus.starting;
  var _cancelled = false;
  var _started = false;
  var _awaitingGateStarted = false;
  var _firstExecutionConsumed = false;

  final _awaitingGate = Completer<void>();
  final _releaseGate = Completer<void>();

  @override
  AgentSessionStatus get status => _status;

  @override
  Stream<AgentEvent> get eventStream => _events.stream;

  AgentSessionConfig? _lastConfig;

  @override
  Future<void> start(AgentSessionConfig config) async {
    _lastConfig = config;
    workItemId = config.workItemId;
    _events = StreamController<AgentEvent>.broadcast(sync: true);
    _status = AgentSessionStatus.running;
    _cancelled = false;
    _started = true;
    _awaitingGateStarted = false;
    if (_firstExecutionConsumed) {
      if (!_releaseGate.isCompleted) _releaseGate.complete();
    } else {
      _firstExecutionConsumed = true;
    }
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

  /// Completes once [sendInstruction] has begun and the session is parked on
  /// the gate: at that moment the worker execution is durably in flight.
  Future<void> get awaitingGate => _awaitingGate.future;

  bool get isAwaitingGate => _awaitingGateStarted;

  File get _writeTarget =>
      File('${_lastConfig!.workingDirectory}/lib/calculator.dart');

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {
    _awaitingGateStarted = true;
    if (!_awaitingGate.isCompleted) _awaitingGate.complete();
    await _releaseGate.future;
    if (_cancelled) return;

    _writeTarget.parent.createSync(recursive: true);
    _writeTarget.writeAsStringSync('int add(int a, int b) => a + b;\n');
    _status = AgentSessionStatus.completed;
    _events.add(
      SessionCompleted(
        eventId: 'evt-complete',
        timestamp: DateTime.now(),
        result: await getResult(),
      ),
    );
  }

  bool get wasCancelled => _cancelled;

  /// Lets the blocked execution complete successfully.
  void release() {
    if (!_releaseGate.isCompleted) _releaseGate.complete();
  }

  @override
  Future<void> cancel(String reason) async {
    if (_cancelled) return;
    _cancelled = true;
    _status = AgentSessionStatus.cancelled;
    if (!_releaseGate.isCompleted) _releaseGate.complete();
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
        errors: complete ? const [] : const [],
        warnings: const [],
      ),
      structuredResult: const {},
      summary: complete
          ? 'produced the design revision in the worktree'
          : 'did not complete',
      completedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> close() async {
    // No-op: this session is a reusable scripted runner.
  }
}

/// Adapter exposing [DesignGateAgentSession] under a caller-chosen provider
/// id, so one host can mount the design agent and the review agent on the
/// same [AgentRuntime] with distinct runtime types.
class DesignGateAgentAdapter implements AgentAdapter {
  DesignGateAgentAdapter(this._session, {required this.providerId});

  final DesignGateAgentSession _session;

  @override
  final String providerId;

  @override
  String get displayName => 'Design Gate Agent ($providerId)';

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
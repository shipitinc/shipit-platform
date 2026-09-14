import 'dart:async';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

import '../store/execution_store.dart';
import '../verifier/workspace_verifier.dart';

/// Thrown when [ExecutionCoordinator.execute] is called for an execution that
/// already has a live, non-terminal record. Executions are single-shot; replay
/// is achieved by observing the terminal record, not by re-running the agent.
class ExecutionAlreadyActiveException implements Exception {
  const ExecutionAlreadyActiveException(this.executionId);

  final String executionId;

  @override
  String toString() => 'Execution is already active: $executionId';
}

/// Thrown when cancel/orchestrate targets an execution that is not currently
/// driven by this coordinator instance.
class ExecutionNotActiveException implements Exception {
  const ExecutionNotActiveException(this.executionId);

  final String executionId;

  @override
  String toString() =>
      'Execution is not active in this coordinator: $executionId';
}

/// How the platform independently verifies the agent's claimed result.
@immutable
class VerificationPlan {
  const VerificationPlan({
    this.command = const ['dart', 'test'],
    this.setupCommand,
    this.checkName = 'dart_test',
  });

  final List<String> command;

  /// e.g. ['dart', 'pub', 'get'] run once before [command].
  final List<String>? setupCommand;
  final String checkName;
}

/// Coordinates ONE durable agent execution per work item, glued to the durable
/// workflow engine:
///
///  1. Claims the execution (idempotent on the execution id).
///  2. Moves the work item into [WorkItemState.agentExecuting].
///  3. Starts a provider-neutral runtime session, persisting every state
///     change and normalized event as it happens.
///  4. On completion, stamps the requested [AgentRole] onto the result (the
///     agent can never assert its own role), runs the platform's independent
///     verifier in the workspace, persists the evidence as
///     [PlatformVerification], and pushes the work item out of execution.
///  5. Exposes [reconcileOrphans] for executions stranded by a process exit.
///
/// The coordinator is provider-agnostic: runtime selection is the request's
/// `runtimeTypeId`, never a hardcoded agent.
class ExecutionCoordinator {
  ExecutionCoordinator({
    required this.store,
    required this.workflowEngine,
    required this.runtime,
    this.verifier = const WorkspaceVerifier(),
    this.verificationPlan,
  });

  final ExecutionStore store;
  final DurableWorkflowEngine workflowEngine;
  final AgentRuntime runtime;
  final WorkspaceVerifier verifier;
  final VerificationPlan? verificationPlan;

  static const WorkflowActor _orchestrator = WorkflowActor(
    actorId: 'orchestrator',
    actorType: ActorType.orchestrator,
  );

  final Map<String, AgentSession> _liveSessions = {};
  final Map<String, Completer<AgentEvent>> _terminalContracts = {};
  final Map<String, Completer<AgentExecution>> _settledContracts = {};
  final Map<String, int> _eventSequences = {};

  bool get isBusy => _liveSessions.isNotEmpty;

  Future<AgentExecution?> latestExecutionFor(String workItemId) =>
      store.latestExecutionForWorkItem(workItemId);

  /// Runs the single execution described by [request]. Re-running the same
  /// execution id after a terminal outcome returns the durable record.
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final existing = await store.readExecutionOrNull(request.executionId);
    if (existing != null) {
      if (existing.isTerminal) return existing;
      throw ExecutionAlreadyActiveException(request.executionId);
    }

    final item = await workflowEngine.loadWorkItem(request.workItemId);
    if (item.state != WorkItemState.agentExecuting) {
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: _orchestrator,
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );
    }

    await store.saveRequest(request);
    final startedAt = DateTime.now();
    final execution = AgentExecution(
      executionId: request.executionId,
      workItemId: request.workItemId,
      requestId: request.executionId,
      runtimeTypeId: request.runtimeTypeId,
      role: request.role,
      status: AgentSessionStatus.starting,
      workspace: request.workspace,
      startedAt: startedAt,
      version: 1,
    );
    await store.saveExecution(execution);

    _eventSequences[request.executionId] = 0;
    await _appendEvent(
      executionId: request.executionId,
      workItemId: request.workItemId,
      type: AgentEventType.executionStarted,
      payload: {
        'role': request.role.wire,
        'runtimeTypeId': request.runtimeTypeId,
        'timeoutSeconds': request.timeoutSeconds,
      },
    );

    final terminal = Completer<AgentEvent>();
    _terminalContracts[request.executionId] = terminal;
    _settledContracts[request.executionId] = Completer<AgentExecution>();

    final AgentSession session;
    try {
      session = await runtime.startSession(
        providerId: request.runtimeTypeId,
        config: AgentSessionConfig(
          executionId: request.executionId,
          workItemId: request.workItemId,
          workingDirectory: request.workspace.path,
          timeout: Duration(seconds: request.timeoutSeconds),
          runtimeConfig: request.runtimeConfig ?? const {},
          allowedPaths: request.workspace.allowedPaths,
        ),
      );
    } on TimeoutException catch (e) {
      return _failWithoutSession(request, 'start timeout: $e');
    } catch (e) {
      return _failWithoutSession(request, 'start failure: $e');
    }

    _liveSessions[request.executionId] = session;
    session.eventStream.listen(
      (e) => _onSessionEvent(request.executionId, request.workItemId, e),
    );

    final running = await store.readExecution(request.executionId);
    await store.saveExecution(
      running.copyWith(
        status: AgentSessionStatus.running,
        sessionId: session.sessionId,
        version: running.version + 1,
      ),
      expectedVersion: running.version,
    );

    try {
      await session.sendInstruction(
        AgentInstruction(
          instructionId: 'instr-${request.executionId}',
          content: request.instruction,
        ),
      );
    } on TimeoutException {
      // The session recorded the interrupt and will emit SessionInterrupted.
    } on AcpTransportException {
      // The session recorded the transport failure.
    }

    return _finalize(request, terminal);
  }

  /// Cancels the live session for [executionId]; the driver loop finalizes the
  /// execution as cancelled and moves the work item out of execution.
  Future<AgentExecution> cancelExecution(
    String executionId,
    String reason,
  ) async {
    final execution = await store.readExecution(executionId);
    if (execution.isTerminal) return execution;
    final session = _liveSessions[executionId];
    final settled = _settledContracts[executionId];
    if (session == null || settled == null) {
      throw ExecutionNotActiveException(executionId);
    }
    await session.cancel(reason);
    return settled.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException(
        'Execution did not reach a terminal state after cancel: $executionId',
      ),
    );
  }

  /// Marks executions that are neither terminal nor driven by this coordinator
  /// as [AgentSessionStatus.orphaned] and exits the work item out of
  /// execution. This is the durable answer to process exits: the platform
  /// never resumes a conversation it cannot prove is still alive.
  Future<List<AgentExecution>> reconcileOrphans({
    String reason = 'Executor lost the session (orphaned execution)',
  }) async {
    final orphans = <AgentExecution>[];
    for (final execution in await store.listExecutions()) {
      if (execution.isTerminal ||
          _liveSessions.containsKey(execution.executionId)) {
        continue;
      }
      final item = await workflowEngine.loadWorkItem(execution.workItemId);

      final now = DateTime.now();
      final orphaned = execution.copyWith(
        status: AgentSessionStatus.orphaned,
        reason: reason,
        completedAt: now,
        version: execution.version + 1,
      );
      await store.saveExecution(orphaned, expectedVersion: execution.version);
      await _appendEvent(
        executionId: execution.executionId,
        workItemId: execution.workItemId,
        type: AgentEventType.executionFailed,
        payload: {'kind': 'orphaned', 'reason': reason},
      );

      if (item.state == WorkItemState.agentExecuting) {
        await workflowEngine.transition(
          workItemId: execution.workItemId,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
          actor: _orchestrator,
          context: {
            'orphanedExecutionId': execution.executionId,
            'reason': reason,
          },
        );
      }
      orphans.add(orphaned);
    }
    return orphans;
  }

  Future<AgentExecution> _finalize(
    AgentExecutionRequest request,
    Completer<AgentEvent> terminal,
  ) async {
    final executionId = request.executionId;
    final session = _liveSessions[executionId];
    try {
      final terminalEvent = await terminal.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => SessionFailed(
          eventId: 'timeout-$executionId',
          timestamp: DateTime.now(),
          error: 'session never emitted a terminal event',
          recoverable: true,
        ),
      );

      final results = await _complete(request, session, terminalEvent);

      await _appendEvent(
        executionId: executionId,
        workItemId: request.workItemId,
        type: results.eventType,
        payload: results.eventPayload,
      );

      await session?.close();

      final recorded = await store.readExecution(executionId);
      await store.saveExecution(
        recorded.copyWith(
          status: results.status,
          resultId: results.result.resultId,
          reason: results.reason,
          completedAt: DateTime.now(),
          version: recorded.version + 1,
        ),
        expectedVersion: recorded.version,
      );
      final finalRecord = await store.readExecution(executionId);
      _releaseExecution(executionId, record: finalRecord);
      return finalRecord;
    } catch (error) {
      await session?.close();
      _releaseExecution(executionId, error: error);
      try {
        await _appendEvent(
          executionId: executionId,
          workItemId: request.workItemId,
          type: AgentEventType.executionFailed,
          payload: {'error': error.toString()},
        );
        final stalled = await store.readExecutionOrNull(executionId);
        if (stalled != null && !stalled.isTerminal) {
          await store.saveExecution(
            stalled.copyWith(
              status: AgentSessionStatus.failed,
              reason: 'coordinator finalize error: $error',
              completedAt: DateTime.now(),
              version: stalled.version + 1,
            ),
            expectedVersion: stalled.version,
          );
        }
      } catch (_) {
        // Fail-sealed: the original error is the primary signal, and the
        // settled contract already carries it (see `_releaseExecution`).
      }
      rethrow;
    }
  }

  /// Persists the terminal [AgentResult] (role stamped from the request), runs
  /// independent verification, and advances the work item.
  Future<_Completion> _complete(
    AgentExecutionRequest request,
    AgentSession? session,
    AgentEvent terminalEvent,
  ) async {
    final result = await session?.getResult() ?? _fallbackResult(request);
    final stamped = result.copyWith(
      role: request.role,
      executionId: request.executionId,
    );
    await store.saveResult(request.executionId, stamped);

    return switch (terminalEvent) {
      SessionCompleted() => await _completeSuccess(request, stamped),
      _ => await _completeFailure(request, stamped, terminalEvent),
    };
  }

  Future<_Completion> _completeSuccess(
    AgentExecutionRequest request,
    AgentResult stamped,
  ) async {
    PlatformVerification? verification;
    final plan = verificationPlan;
    if (plan != null) {
      final outcome = await verifier.verify(
        workingDirectory: request.workspace.path,
        command: plan.command,
        setupCommand: plan.setupCommand,
      );
      verification = PlatformVerification(
        verificationId: 'ver-${request.executionId}',
        executionId: request.executionId,
        workItemId: request.workItemId,
        checkName: plan.checkName,
        status: outcome.passed
            ? AgentClaimStatus.passed
            : AgentClaimStatus.failed,
        mechanism: outcome.mechanism,
        command: outcome.command,
        capturedAt: DateTime.now(),
        detail:
            outcome.detail ??
            (outcome.passed ? 'Verification passed' : 'Verification failed'),
        outputRef: null,
        resultPath: request.workspace.path,
      );
      await store.saveVerification(verification);
    }

    final item = await workflowEngine.loadWorkItem(request.workItemId);
    await workflowEngine.transition(
      workItemId: request.workItemId,
      to: WorkItemState.agentCompleted,
      trigger: TransitionTrigger.agentResult,
      actor: _orchestrator,
      context: {
        'agentResult': stamped,
        if (item.qaContractId != null) 'qaContractId': item.qaContractId,
      },
    );

    return _Completion(
      status: AgentSessionStatus.completed,
      result: stamped,
      reason: stamped.status == AgentResultStatus.completed
          ? 'end_turn'
          : 'session ended without a completed result',
      eventType: stamped.status == AgentResultStatus.completed
          ? AgentEventType.executionCompleted
          : AgentEventType.executionFailed,
      eventPayload: {
        'role': request.role.wire,
        'verificationStatus': verification?.status.wire,
      },
    );
  }

  Future<_Completion> _completeFailure(
    AgentExecutionRequest request,
    AgentResult stamped,
    AgentEvent terminalEvent,
  ) async {
    final (status, eventType, reason) = switch (terminalEvent) {
      SessionCancelled(:final reason) => (
        AgentSessionStatus.cancelled,
        AgentEventType.executionCancelled,
        reason,
      ),
      SessionInterrupted(:final reason) => (
        AgentSessionStatus.interrupted,
        AgentEventType.executionFailed,
        reason,
      ),
      SessionFailed(:final error) => (
        AgentSessionStatus.failed,
        AgentEventType.executionFailed,
        error,
      ),
      _ => (
        AgentSessionStatus.failed,
        AgentEventType.executionFailed,
        'unknown',
      ),
    };

    await workflowEngine.transition(
      workItemId: request.workItemId,
      to: WorkItemState.agentFailed,
      trigger: TransitionTrigger.agentResult,
      actor: _orchestrator,
      context: {'agentResult': stamped, 'reason': reason},
    );
    return _Completion(
      status: status,
      result: stamped,
      reason: reason,
      eventType: eventType,
      eventPayload: {'role': request.role.wire, 'reason': reason},
    );
  }

  void _onSessionEvent(
    String executionId,
    String workItemId,
    AgentEvent event,
  ) {
    final normalized = _normalize(event);
    if (normalized != null) {
      final (type, payload) = normalized;
      store.appendEvent(
        AgentEventRecord(
          eventId: event.eventId,
          executionId: executionId,
          workItemId: workItemId,
          sequence: _nextSequence(executionId),
          type: type,
          occurredAt: event.timestamp,
          payload: payload,
        ),
      );
    }

    final terminal = _asTerminal(event);
    if (terminal != null) {
      final contract = _terminalContracts[executionId];
      if (contract != null && !contract.isCompleted) {
        contract.complete(terminal);
      }
    }
  }

  int _nextSequence(String executionId) {
    final next = (_eventSequences[executionId] ?? 0) + 1;
    _eventSequences[executionId] = next;
    return next;
  }

  (AgentEventType, Map<String, dynamic>)? _normalize(AgentEvent event) {
    return switch (event) {
      InstructionSent() => (
        AgentEventType.message,
        {'kind': 'instruction_sent'},
      ),
      AgentMessageChunk() => (
        AgentEventType.message,
        {'kind': 'agent_message_chunk'},
      ),
      ToolCallStarted(:final toolCallId, :final tool) => (
        AgentEventType.toolStarted,
        {'toolCallId': toolCallId, 'tool': tool},
      ),
      ToolCallCompleted(:final toolCallId) => (
        AgentEventType.toolCompleted,
        {'toolCallId': toolCallId},
      ),
      ToolCallFailed(:final toolCallId, :final error) => (
        AgentEventType.toolFailed,
        {'toolCallId': toolCallId, 'error': error},
      ),
      ArtifactProduced(:final artifactId, :final type, :final path) => (
        AgentEventType.artifactProduced,
        {'artifactId': artifactId, 'type': type, 'path': path},
      ),
      LogLine(:final level) => (
        AgentEventType.warning,
        {'kind': 'log_line', 'level': level},
      ),
      ProgressUpdate() => (AgentEventType.message, {'kind': 'progress'}),
      SessionCompleted(:final result) => (
        AgentEventType.executionCompleted,
        {'status': result.status.wire},
      ),
      SessionFailed(:final error) => (
        AgentEventType.executionFailed,
        {'error': error},
      ),
      SessionCancelled(:final reason) => (
        AgentEventType.executionCancelled,
        {'reason': reason},
      ),
      SessionInterrupted(:final reason) => (
        AgentEventType.executionFailed,
        {'kind': 'interrupted', 'reason': reason},
      ),
      SessionStarted() || UsageUpdate() => null,
    };
  }

  AgentEvent? _asTerminal(AgentEvent event) {
    return switch (event) {
      SessionCompleted() ||
      SessionFailed() ||
      SessionCancelled() ||
      SessionInterrupted() => event,
      _ => null,
    };
  }

  Future<AgentExecution> _failWithoutSession(
    AgentExecutionRequest request,
    String reason,
  ) async {
    final result = _fallbackResult(request, reason: reason);
    final stamped = result.copyWith(
      role: request.role,
      executionId: request.executionId,
    );
    await store.saveResult(request.executionId, stamped);
    await _appendEvent(
      executionId: request.executionId,
      workItemId: request.workItemId,
      type: AgentEventType.executionFailed,
      payload: {'error': reason},
    );

    try {
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        context: {'agentResult': stamped, 'reason': reason},
      );
    } on WorkflowTransitionRejectedException {
      // The work item may already be out of execution; the execution record
      // above is the durable source of truth.
    }

    final recorded = await store.readExecution(request.executionId);
    final status = AgentSessionStatus.failed;
    await store.saveExecution(
      recorded.copyWith(
        status: status,
        resultId: stamped.resultId,
        reason: reason,
        completedAt: DateTime.now(),
        version: recorded.version + 1,
      ),
      expectedVersion: recorded.version,
    );
    final finalRecord = await store.readExecution(request.executionId);
    _releaseExecution(request.executionId, record: finalRecord);
    return finalRecord;
  }

  /// Removes the per-execution bookkeeping once the durable record is settled
  /// ([[record]]) or the coordinator is abandoning it ([[error]]), completing
  /// the settled contract so `cancelExecution` never waits on a dead lock.
  void _releaseExecution(
    String executionId, {
    AgentExecution? record,
    Object? error,
  }) {
    _liveSessions.remove(executionId);
    _eventSequences.remove(executionId);
    _terminalContracts.remove(executionId);
    final settled = _settledContracts.remove(executionId);
    if (settled != null && !settled.isCompleted) {
      if (error != null) {
        settled.completeError(error);
      } else if (record != null) {
        settled.complete(record);
      }
    }
  }

  AgentResult _fallbackResult(
    AgentExecutionRequest request, {
    String reason = 'session failed before emitting a result',
  }) {
    return AgentResult(
      resultId: 'result-${request.executionId}',
      sessionId: '',
      workItemId: request.workItemId,
      status: AgentResultStatus.failed,
      artifacts: const [],
      diagnostics: AgentDiagnostics(
        exitCode: 1,
        durationMs: 0,
        toolCalls: 0,
        errors: [
          DiagnosticEntry(
            code: 'coordinator_failure',
            message: reason,
            severity: 'error',
          ),
        ],
        warnings: const [],
      ),
      structuredResult: const {},
      completedAt: DateTime.now(),
    );
  }

  Future<void> _appendEvent({
    required String executionId,
    required String workItemId,
    required AgentEventType type,
    Map<String, dynamic> payload = const {},
  }) {
    final sequence = _nextSequence(executionId);
    return store.appendEvent(
      AgentEventRecord(
        eventId: 'evt-$executionId-$type-$sequence',
        executionId: executionId,
        workItemId: workItemId,
        sequence: sequence,
        type: type,
        occurredAt: DateTime.now(),
        payload: payload,
      ),
    );
  }
}

class _Completion {
  const _Completion({
    required this.status,
    required this.result,
    required this.reason,
    required this.eventType,
    this.eventPayload = const {},
  });

  final AgentSessionStatus status;
  final AgentResult result;
  final String reason;
  final AgentEventType eventType;
  final Map<String, dynamic> eventPayload;
}

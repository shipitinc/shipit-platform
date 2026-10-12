import 'dart:async';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

import '../store/execution_store.dart';
import '../store/model_execution_record_store.dart';
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

/// Thrown when an execution is dispatched for a work item that has since LEFT
/// the state this role needs to run in.
///
/// ## Why this is its own type
///
/// The underlying cause is an ordinary [WorkflowTransitionRejectedException],
/// and letting that escape produced a genuinely misleading outcome. Live QA
/// caught it: a review job dispatched at 16:40 found its work item moved to
/// `agentExecuting` by an operator, then to `designNotRequired` by a repair
/// migration, and the attempt failed two hours later with
///
///     Workflow transition rejected: WorkItemState.designNotRequired ->
///     WorkItemState.reviewInProgress (Transition ... is not allowed)
///
/// as a `permanent` `executionFailed`. That reads as a platform fault in the
/// state machine. It is not: the state machine REFUSED correctly, and the
/// condition is ordinary staleness — a completion that arrived after its work
/// item moved on. Naming it makes the job's failure reason say what happened.
///
/// ## What it deliberately does NOT claim
///
/// Nothing was executed and nothing was produced, so there is no result to
/// preserve and no work item to un-strand: the transition is attempted BEFORE
/// the execution row and the session exist, and the work item belongs to
/// whoever moved it. This is a classification, not a recovery — and it never
/// relaxes the policy that rejected the transition.
class WorkItemSupersededException implements Exception {
  const WorkItemSupersededException({
    required this.workItemId,
    required this.observedState,
    required this.requiredState,
    required this.role,
  });

  final String workItemId;
  final WorkItemState observedState;
  final WorkItemState requiredState;
  final AgentRole role;

  @override
  String toString() =>
      'Superseded execution: work item $workItemId is '
      '${observedState.wire} and no longer accepts a '
      '${role.wire} run, which requires ${requiredState.wire}. '
      'The work item moved on before this execution started, so nothing ran '
      'and nothing was produced.';
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
///  5. Inserts a [ModelExecutionRecord] capturing model usage and cost.
///  6. Exposes [reconcileOrphans] for executions stranded by a process exit.
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
    this.modelExecutionRecordStore,
  });

  final ExecutionStore store;
  final DurableWorkflowEngine workflowEngine;
  final AgentRuntime runtime;
  final WorkspaceVerifier verifier;
  final VerificationPlan? verificationPlan;
  final ModelExecutionRecordStore? modelExecutionRecordStore;

  /// How long a timeout is allowed to wait for the agent process to confirm it
  /// is stopping. Short on purpose: it must not extend the execution's budget
  /// by an unbounded amount just to be polite to a process that may be the
  /// thing that is wedged.
  static const Duration _cancelGrace = Duration(seconds: 5);

  static const WorkflowActor _orchestrator = WorkflowActor(
    actorId: 'orchestrator',
    actorType: ActorType.orchestrator,
  );

  final Map<String, AgentSession> _liveSessions = {};
  final Map<String, StreamSubscription<AgentEvent>> _subscriptions = {};
  final Map<String, Completer<AgentEvent>> _terminalContracts = {};
  final Map<String, Completer<AgentExecution>> _settledContracts = {};
  final Map<String, int> _eventSequences = {};

  bool get isBusy => _liveSessions.isNotEmpty;

  /// How many agent sessions this coordinator currently holds.
  ///
  /// Read-only observability, and the number that must not grow across a
  /// timeout: a drive path that resumes after its execution was released would
  /// otherwise re-register a session nothing will ever take away again, leaking
  /// both the map entry and its event subscription — and, worse, reporting a
  /// dead execution as live.
  int get liveSessionCount => _liveSessions.length;

  /// Whether this process currently holds a LIVE agent session for
  /// [executionId].
  ///
  /// The one question durable state cannot answer. A worker execution row that
  /// is still `agentExecuting` is byte-for-byte identical whether a process is
  /// behind it or died an hour ago, which is why reconciliation cannot infer
  /// liveness from it. This is the live-session set answering directly, and it
  /// is what an [ExecutionLivenessProbe] asks.
  ///
  /// READ-ONLY and side-effect free: it observes, never registers, never
  /// creates and never fabricates a verdict. There is deliberately no way to
  /// mark an execution live from outside, so a `true` here means a session is
  /// genuinely in this process's hands.
  ///
  /// FALSE means "no live session in this coordinator", which is not quite the
  /// same as "provably dead": an execution id this coordinator has never seen
  /// also answers false. A caller that needs to tell those apart must not infer
  /// death from this alone — the scheduler's probe treats an unobservable
  /// execution as `unknown` rather than `dead` for exactly that reason.
  bool hasLiveSession(String executionId) =>
      _liveSessions.containsKey(executionId);

  Future<AgentExecution?> latestExecutionFor(String workItemId) =>
      store.latestExecutionForWorkItem(workItemId);

  /// The transition context for moving an item `agentCompleted -> reviewInProgress`.
  ///
  /// The edge is guarded by `agentResultValid()`, which requires the
  /// IMPLEMENTER's completed [AgentResult] under `context['agentResult']`. The
  /// reviewer has not run yet at entry, so the latest execution for the work
  /// item IS the implementer's, and this hands over the very result the
  /// completion path stamped ([_completeSuccess]) — never a synthesized one.
  /// If the implementer's result is genuinely absent the map omits the key and
  /// the engine rejects the transition, which is the honest outcome: the
  /// `agentCompleted` state is not true without a completed result.
  Future<Map<String, dynamic>> _reviewEntryTransitionContext(
    String workItemId,
  ) async {
    final implementerExecution = await store.latestExecutionForWorkItem(
      workItemId,
    );
    final implementerResult = implementerExecution == null
        ? null
        : await store.readResult(implementerExecution.executionId);
    return <String, dynamic>{
      'agentAvailable': true,
      'capabilitiesMatch': true,
      if (implementerResult != null) 'agentResult': implementerResult,
    };
  }

  /// Runs the single execution described by [request]. Re-running the same
  /// execution id after a terminal outcome returns the durable record.
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final existing = await store.readExecutionOrNull(request.executionId);
    if (existing != null) {
      if (existing.isTerminal) return existing;
      throw ExecutionAlreadyActiveException(request.executionId);
    }

    final item = await workflowEngine.loadWorkItem(request.workItemId);
    final isReviewer = request.role == AgentRole.engineeringReviewer;
    final runningState = isReviewer
        ? WorkItemState.reviewInProgress
        : WorkItemState.agentExecuting;
    if (item.state != runningState) {
      try {
        await workflowEngine.transition(
          workItemId: request.workItemId,
          to: runningState,
          trigger: TransitionTrigger.systemEvent,
          actor: _orchestrator,
          // The reviewer's `agentCompleted -> reviewInProgress` edge is guarded by
          // `agentResultValid()`, which reads the IMPLEMENTER's completed result
          // from `context['agentResult']`. The scheduler cannot supply it (which is
          // why `engineeringReviewDefinition.skipWorkflowPolicyCheck` is true), but
          // this transition runs against the durable engine, so it must. Every
          // non-reviewer role keeps the original context byte for byte.
          context: isReviewer
              ? await _reviewEntryTransitionContext(request.workItemId)
              : const {'agentAvailable': true, 'capabilitiesMatch': true},
        );
      } on WorkflowTransitionRejectedException {
        // The item moved between the load above and this write — an operator
        // action, a gate, a repair. That is staleness, not a platform fault, and
        // the engine's raw "transition rejected ... is not allowed" string
        // escapes into the job's permanent failure reason if it is allowed out
        // of here. Re-raise it under the name that says what happened. No audit
        // evidence is lost: the engine has already appended the rejected attempt
        // to the transition history, which is where this is explained in full.
        throw WorkItemSupersededException(
          workItemId: request.workItemId,
          observedState: item.state,
          requiredState: runningState,
          role: request.role,
        );
      }
    }

    await store.inTransaction((tx) async {
      await tx.saveRequest(request);
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
      await tx.saveExecution(execution);

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
        via: tx,
      );
    });

    final terminal = Completer<AgentEvent>();
    _terminalContracts[request.executionId] = terminal;
    _settledContracts[request.executionId] = Completer<AgentExecution>();

    // `request.timeoutSeconds` is the budget for the WHOLE dispatch path:
    // session start, the instruction round trip, the terminal-event wait,
    // result retrieval and independent verification. It used to travel no
    // further than `AgentSessionConfig`, where an adapter may apply it to a
    // single ACP call, and nothing here ever enforced it end to end. A session
    // that stalled between two phases therefore waited forever, and the only
    // two bounded waits in the file were 60s on cancel and a hard-coded 30s on
    // the terminal event - a bound that also contradicted a 300s budget by
    // failing healthy agents early. The budget is the authority now, and it
    // ends in a real terminal state rather than an abandoned future.
    final budget = Duration(seconds: request.timeoutSeconds);
    final dispatchStartedAt = DateTime.now();

    return _drive(
      request,
      terminal,
      budget,
      dispatchStartedAt,
    ).timeout(budget, onTimeout: () => _expireExecution(request, budget));
  }

  /// Drives one execution from session start to its durable terminal record.
  ///
  /// Runs under the caller's budget ([execute] applies it to this whole
  /// future), so an individual step that hangs is bounded by the budget rather
  /// than by nothing at all. The budget is passed down as well, because the
  /// terminal-event wait inside [_finalize] must not be allowed to outlive the
  /// execution it is waiting for.
  Future<AgentExecution> _drive(
    AgentExecutionRequest request,
    Completer<AgentEvent> terminal,
    Duration budget,
    DateTime dispatchStartedAt,
  ) async {
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
          environment: request.environment,
        ),
      );
    } on TimeoutException catch (e) {
      return _failWithoutSession(request, 'start timeout: $e');
    } catch (e) {
      return _failWithoutSession(request, 'start failure: $e');
    }

    // A drive path that resumes AFTER this execution was settled must not
    // reopen it.
    //
    // `_terminalContracts` is inserted before the drive begins and removed by
    // `_releaseExecution`, so its absence means this coordinator has already
    // reached a verdict for this id - normally, or by timeout. Registering the
    // session here anyway would do two lasting harm: the row below would be
    // rewritten from terminal back to `running`, and the entry plus its event
    // subscription would never be removed, because nothing is left driving.
    // The second is worse than it looks - a resurrected `_liveSessions` entry
    // makes `hasLiveSession` answer "alive" for an execution with nothing
    // behind it, which is precisely how a timed-out execution turns back into a
    // zombie that the lease renewal keeps alive forever.
    if (!_terminalContracts.containsKey(request.executionId)) {
      await session.close();
      return _abandonedRecord(request);
    }

    _liveSessions[request.executionId] = session;
    final subscription = session.eventStream.listen(
      (e) => _onSessionEvent(request.executionId, request.workItemId, e),
    );
    _subscriptions[request.executionId] = subscription;

    final running = await store.readExecution(request.executionId);
    if (running.isTerminal) {
      // Settled between the check above and this read. Writing `running` over
      // a terminal row would resurrect it, so stop here and keep the verdict.
      _forget(request.executionId);
      await session.close();
      return running;
    }
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

    return _finalize(request, terminal, budget, dispatchStartedAt);
  }

  /// The durable record for an execution this coordinator is no longer driving,
  /// or a synthetic terminal one if the row cannot be read.
  Future<AgentExecution> _abandonedRecord(AgentExecutionRequest request) async {
    final recorded = await store.readExecutionOrNull(request.executionId);
    if (recorded != null) return recorded;
    return _failWithoutSession(
      request,
      'execution was already settled before its session could be registered',
    );
  }

  /// Drops this coordinator's bookkeeping for [executionId] — the live-session
  /// entry AND its event subscription. Both are registered together in [_drive],
  /// so they are released together; leaving the subscription behind keeps the
  /// session object and its event stream reachable for the life of the process.
  void _forget(String executionId) {
    _liveSessions.remove(executionId);
    _subscriptions.remove(executionId)?.cancel();
  }

  /// The last-resort terminal state for an execution whose dispatch path did
  /// not settle inside its budget.
  ///
  /// This is deliberately not an abandoned future. The agent process is asked
  /// to stop, the execution is persisted as a real terminal `failed` record
  /// carrying an honest reason, an `executionFailed` event is appended, the
  /// work item leaves [WorkItemState.agentExecuting] for
  /// [WorkItemState.agentFailed], and a model execution record is written - so
  /// the job is never left running behind a durable status string.
  ///
  /// The drive path may still be wedged somewhere that is not the terminal
  /// wait, and can finish long after this returns.
  ///
  /// It cannot undo this verdict, and NOT because of the optimistic version
  /// guard: both late write sites re-read the row immediately before writing and
  /// CAS against that fresh version, so the version check would pass and the
  /// terminal row WOULD be overwritten. What actually holds the line is the
  /// explicit terminal check each of them makes on the row they just read, plus
  /// the fact that [_drive] refuses to register a session for an execution that
  /// has already been released. A reviewer should treat "the version guard
  /// saves us" as false here: it does not, and the tests assert on the write
  /// sequence rather than on the final row precisely because the final row can
  /// look correct while the row spent real time non-terminal.
  Future<AgentExecution> _expireExecution(
    AgentExecutionRequest request,
    Duration budget,
  ) async {
    await _stopSessionQuietly(
      request.executionId,
      'execution exceeded its ${budget.inSeconds}s budget',
    );
    return _failWithoutSession(
      request,
      'execution exceeded its ${budget.inSeconds}s timeout budget without '
      'reaching a terminal agent event',
    );
  }

  /// Best-effort stop of the live session. A wedged transport must not be able
  /// to hold the timeout path open, so the cancel wait is itself bounded, and a
  /// cancel that never answers is not an error: the durable terminal record
  /// written by the caller is the authority either way.
  Future<void> _stopSessionQuietly(String executionId, String reason) async {
    final session = _liveSessions[executionId];
    if (session == null) return;
    try {
      await session.cancel(reason).timeout(_cancelGrace);
    } catch (_) {
      // The session is abandoned; only the durable record survives, and it is
      // written regardless.
    }
  }

  /// The honest terminal event for a session that stopped answering without
  /// ever reporting one. Routed through the ordinary failure path, so it lands
  /// on `AgentSessionStatus.failed` with this reason rather than on nothing.
  SessionFailed _neverEmittedTerminalEvent(
    String executionId,
    Duration budget,
  ) => SessionFailed(
    eventId: 'timeout-$executionId',
    timestamp: DateTime.now(),
    error:
        'session never emitted a terminal event within the '
        '${budget.inSeconds}s execution budget',
    recoverable: true,
  );

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
      await store.inTransaction((tx) async {
        await tx.saveExecution(orphaned, expectedVersion: execution.version);
        await _appendEvent(
          executionId: execution.executionId,
          workItemId: execution.workItemId,
          type: AgentEventType.executionFailed,
          payload: {'kind': 'orphaned', 'reason': reason},
          via: tx,
        );
      });

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
    Duration budget,
    DateTime dispatchStartedAt,
  ) async {
    final executionId = request.executionId;
    final session = _liveSessions[executionId];
    try {
      // The terminal-event wait is bounded by what is LEFT of the execution
      // budget, so it composes with it instead of racing it: it can never
      // outlive the execution, and a slow-but-healthy agent is not failed early
      // by a constant that is unrelated to the configured timeout.
      final remaining = dispatchStartedAt
          .add(budget)
          .difference(DateTime.now());
      final terminalEvent = remaining <= Duration.zero
          ? _neverEmittedTerminalEvent(executionId, budget)
          : await terminal.future.timeout(
              remaining,
              onTimeout: () => _neverEmittedTerminalEvent(executionId, budget),
            );

      final results = await _complete(request, session, terminalEvent);

      // A completion that arrives after the execution was already settled must
      // not overwrite that verdict. This pre-check is an optimisation - it
      // avoids even building the write - and the authoritative check is the one
      // inside the transaction below, which is atomic with the read it guards.
      //
      // This is also what distinguishes a LATE result from a RESURRECTION: a
      // result that arrives while the execution is still open finds a
      // non-terminal row and lands normally, and nothing here discards it.
      final settled = await store.readExecution(executionId);
      if (settled.isTerminal) {
        await session?.close();
        _releaseExecution(executionId, record: settled);
        return settled;
      }

      await store.inTransaction((tx) async {
        await _appendEvent(
          executionId: executionId,
          workItemId: request.workItemId,
          type: results.eventType,
          payload: results.eventPayload,
          via: tx,
        );

        final recorded = await tx.readExecution(executionId);
        if (recorded.isTerminal) return; // Keep the verdict that already won.
        await tx.saveExecution(
          recorded.copyWith(
            status: results.status,
            resultId: results.result.resultId,
            reason: results.reason,
            completedAt: DateTime.now(),
            version: recorded.version + 1,
          ),
          expectedVersion: recorded.version,
        );
      });

      await session?.close();

      final finalRecord = await store.readExecution(executionId);
      _releaseExecution(executionId, record: finalRecord);
      return finalRecord;
    } catch (error) {
      await session?.close();
      _releaseExecution(executionId, error: error);
      // A completion that could not be applied because the work item moved on
      // is ordinary staleness, not a coordinator fault — but it still has to be
      // REPORTED, because the execution did not achieve what it was for. Only
      // the classification changes; the raw engine text is kept in the event
      // payload so the audit trail loses nothing.
      final stale = error is WorkflowTransitionRejectedException;
      final detail = stale
          ? 'late completion could not be applied: work item '
                '${request.workItemId} moved on before this outcome was '
                'recorded (${error.record.fromState.wire} -> '
                '${error.record.toState.wire}); the result and any verification '
                'are persisted under execution $executionId'
          : 'coordinator finalize error: $error';
      try {
        await store.inTransaction((tx) async {
          await _appendEvent(
            executionId: executionId,
            workItemId: request.workItemId,
            type: AgentEventType.executionFailed,
            payload: {
              if (stale) 'kind': 'staleCompletion',
              'error': error.toString(),
            },
            via: tx,
          );
          final stalled = await tx.readExecutionOrNull(executionId);
          if (stalled != null && !stalled.isTerminal) {
            await tx.saveExecution(
              stalled.copyWith(
                status: AgentSessionStatus.failed,
                reason: detail,
                completedAt: DateTime.now(),
                version: stalled.version + 1,
              ),
              expectedVersion: stalled.version,
            );
          }
        });
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

    // A terminal event can arrive after this execution was already declared
    // failed. The durable row, not the event, decides whether there is still an
    // execution to complete.
    final recorded = await store.readExecutionOrNull(request.executionId);
    final alreadySettled = recorded != null && recorded.isTerminal;

    return switch (terminalEvent) {
      SessionCompleted() => await _completeSuccess(
        request,
        stamped,
        alreadySettled: alreadySettled,
      ),
      _ => await _completeFailure(request, stamped, terminalEvent),
    };
  }

  Future<_Completion> _completeSuccess(
    AgentExecutionRequest request,
    AgentResult stamped, {
    required bool alreadySettled,
  }) async {
    PlatformVerification? verification;
    final plan = verificationPlan;
    // Verification spawns a real process in the workspace and runs BEFORE the
    // workflow transition. For an execution already declared failed, that is a
    // subprocess spawned to produce evidence nobody will read: the write that
    // would carry it is refused, and the transition is already decided.
    if (plan != null && !alreadySettled) {
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
    // The gate reads the PERSISTED [PlatformVerification] rather than a local
    // outcome flag, so the row a reviewer or operator can read is the same row
    // that decided the state. `null` — no plan configured, or `alreadySettled`,
    // where verification is deliberately skipped — is NOT a failure: a check
    // that never ran has no verdict, and inventing one would strand work items
    // on a failure nothing observed.
    final verificationFailed = verification?.status == AgentClaimStatus.failed;
    if (request.role == AgentRole.engineeringReviewer) {
      // For engineering reviewers, the coordinator must NOT transition out of
      // reviewInProgress; the tick handler will raise a human decision instead.
    } else if (verificationFailed) {
      // The platform's independent check ran and disagreed with the agent's
      // success report. Recording `agentCompleted` anyway advanced a work item
      // the platform had just refuted, and nothing downstream re-derived the
      // failure from the verification row — the item sat at `agentCompleted`
      // with a failed job behind it, and the operator affordance that can act
      // on it accepts only `agentFailed`. `agentExecuting -> agentFailed` is
      // legal for the orchestrator actor
      // (packages/workflow_engine/.../work_item_transitions.dart:105).
      //
      // No `metadataMerge` here, deliberately. `producerActorId` names the
      // execution whose result the engineering-review gate's `actorIsNotSelf()`
      // guard is checked against; a refuted result is not a producer, and an
      // operator retry re-runs triage and claims a fresh execution that stamps
      // the identity on its own success.
      final reason = verification?.detail ?? 'platform verification failed';
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        // The engine's own `reason` parameter, which is the field PERSISTED on
        // the transition record — `context` only reaches the guard evaluator.
        // Without it the item settles at `agentFailed` with nothing in its
        // history saying why, which is the "stranded with no signal" half of
        // the same defect. Supplying it cannot flip the outcome: the engine
        // derives `outcome` from the policy, never from the presence of a
        // reason.
        reason: reason,
        context: {
          'agentResult': stamped,
          // Same key `_completeFailure` uses, so a reader does not have to know
          // which of the two paths settled the item.
          'reason': reason,
        },
      );
    } else {
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentCompleted,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        context: {
          'agentResult': stamped,
          if (item.qaContractId != null) 'qaContractId': item.qaContractId,
        },
        // Record the producing execution as the work item's producer identity.
        // The engineering-review gate's `actorIsNotSelf()` guard compares the
        // reviewer's execution id against this, and WITHOUT a real producer the
        // guard has only a literal to fall back on — a check that can never
        // fail is not a check. `metadataMerge` is additive: it never replaces
        // the rest of the metadata (defect payload, retry attempt, …).
        metadataMerge: {'producerActorId': stamped.executionId},
      );
    }

    await _insertModelExecutionRecord(request, stamped, true, null);

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
    final (status, eventType, reason) = _failureDetails(terminalEvent);

    if (request.role == AgentRole.engineeringReviewer) {
      // Do not transition workflow state out of reviewInProgress for reviewer
      // terminal outcomes; tick handler will create the human decision.
    } else {
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        context: {'agentResult': stamped, 'reason': reason},
      );
    }

    await _insertModelExecutionRecord(request, stamped, false, reason);

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

  (AgentSessionStatus, AgentEventType, String) _failureDetails(
    AgentEvent terminalEvent,
  ) {
    return switch (terminalEvent) {
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
        'unknown terminal event',
      ),
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
      if (request.role == AgentRole.engineeringReviewer) {
        // Skip workflow transition for reviewer failures.
      } else {
        await workflowEngine.transition(
          workItemId: request.workItemId,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.agentResult,
          actor: _orchestrator,
          context: {'agentResult': stamped, 'reason': reason},
        );
      }
    } on WorkflowTransitionRejectedException {
      // The work item may already be out of execution; the execution record
      // above is the durable source of truth.
    }

    await _insertModelExecutionRecord(request, stamped, false, reason);

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
    _forget(executionId);
    _eventSequences.remove(executionId);
    _terminalContracts.remove(executionId);
    final settled = _settledContracts.remove(executionId);
    if (settled != null && !settled.isCompleted) {
      if (error != null) {
        // `cancelExecution` is the only reader of this contract, and on the
        // ordinary failure path nobody is calling it. Completing with an error
        // and no listener therefore reports the error to the ambient zone as
        // UNHANDLED, which poisons whatever ran the drive — and it happens on
        // exactly the late-completion path where the drive is already failing
        // for a benign reason. Registering a listener marks the error handled;
        // it does NOT consume it, so a `cancelExecution` awaiting the same
        // future still receives it and still rejects.
        unawaited(settled.future.then<void>((_) {}, onError: (Object _) {}));
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

  Future<void> _insertModelExecutionRecord(
    AgentExecutionRequest request,
    AgentResult result,
    bool success,
    String? error,
  ) async {
    final modelExecutionRecordStore = this.modelExecutionRecordStore;
    if (modelExecutionRecordStore == null) return;

    final metadata = result.metadata ?? {};
    final usage = metadata['usage'] as Map<String, dynamic>?;
    final used = (usage?['used'] as num?)?.toInt() ?? 0;
    final size = (usage?['size'] as num?)?.toInt() ?? 0;
    final cost = (usage?['cost'] as num?)?.toDouble() ?? 0.0;

    final modelId = (metadata['model'] as String?) ?? 'unknown';
    final provider = (metadata['provider'] as String?) ?? request.runtimeTypeId;
    final escalationIndex = (metadata['escalationIndex'] as int?) ?? 0;

    final taskType = _taskTypeFromRole(request.role);
    final startedAt = result.metadata?['startedAt'] != null
        ? DateTime.parse(result.metadata!['startedAt'] as String)
        : DateTime.now().subtract(const Duration(minutes: 5));
    final finishedAt = DateTime.now();

    final record = ModelExecutionRecord(
      workItemId: request.workItemId,
      jobId: request.workItemId,
      agentExecutionId: request.executionId,
      role: request.role,
      modelId: modelId,
      provider: provider,
      inputTokens: used,
      outputTokens: size - used,
      totalTokens: size,
      cachedReadTokens: 0,
      costUsd: cost,
      currency: 'USD',
      startedAt: startedAt,
      finishedAt: finishedAt,
      success: success,
      error: error,
      escalationIndex: escalationIndex,
      taskType: taskType,
    );

    await modelExecutionRecordStore.insert(record);
  }

  String _taskTypeFromRole(AgentRole role) {
    return switch (role) {
      AgentRole.triageDefect => 'production',
      AgentRole.implementer => 'production',
      AgentRole.correctionImplementer => 'production',
      AgentRole.integrator => 'production',
      AgentRole.designAgent => 'designReview',
      AgentRole.designReviewer => 'designReview',
      AgentRole.focusedReviewer => 'designReview',
      AgentRole.engineeringReviewer => 'engineeringReview',
      AgentRole.qaArchitect => 'architectureReview',
      AgentRole.qaExecutor => 'qaReview',
      AgentRole.releaseEngineer => 'production',
      AgentRole.deploymentAuthority => 'production',
    };
  }

  Future<void> _appendEvent({
    required String executionId,
    required String workItemId,
    required AgentEventType type,
    Map<String, dynamic> payload = const {},
    ExecutionStore? via,
  }) {
    final store = via ?? this.store;
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

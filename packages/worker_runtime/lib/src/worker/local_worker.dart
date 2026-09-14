import 'dart:async';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_protocol/worker_protocol.dart';

import '../env/environment_policy.dart';
import '../execution/agent_execution_driver.dart';
import '../store/worker_store.dart';
import '../workspace/git_workspace_inspector.dart';
import '../workspace/workspace_manager.dart';
import 'worker.dart';

/// Thrown when an execution tries to claim a slot that is already held.
class WorkerBusyException implements Exception {
  const WorkerBusyException(this.workerId);

  final String workerId;

  @override
  String toString() => 'Worker is busy: $workerId';
}

/// Default [Worker]: one durable execution per acquisition, isolated in a
/// platform-owned git worktree, driven through a provider-neutral
/// [AgentExecutionDriver], with the [EnvironmentPolicy] applied to the runtime
/// process. The worker captures the git-observed diff + ending revision before
/// applying the request's cleanup policy.
class LocalWorker implements Worker {
  LocalWorker({
    required this.workerId,
    required this.poolId,
    required Set<WorkerCapability> capabilities,
    required this.workspaceManager,
    required this.executionDriver,
    required this.workerStore,
    this.platform,
    this.environmentPolicy = const EnvironmentPolicy(),
    this.inspector = const GitWorkspaceInspector(),
    this.workerLeaseGrace = const Duration(seconds: 60),
    this.eventSink,
  }) : _capabilities = capabilities;

  final String workerId;
  final String poolId;
  final Set<WorkerCapability> _capabilities;
  final String? platform;
  final WorkspaceManager workspaceManager;
  final AgentExecutionDriver executionDriver;
  final WorkerStore workerStore;
  final EnvironmentPolicy environmentPolicy;
  final GitWorkspaceInspector inspector;
  final Duration workerLeaseGrace;

  /// Optional observer for normalized worker events (used by tests/audit).
  final void Function(WorkerEventRecord event)? eventSink;

  bool _leased = false;
  int _sequence = 0;
  String? _activeAgentExecutionId;

  @override
  Set<WorkerCapability> get capabilities => _capabilities;

  @override
  bool get isAcquirable => !_leased;

  @override
  Future<void> acquire() async {
    if (_leased) throw const WorkerBusyException('');
    _leased = true;
  }

  @override
  Future<void> release() async {
    _leased = false;
    _activeAgentExecutionId = null;
  }

  WorkerRegistration toRegistration({WorkerStatus status = WorkerStatus.idle}) {
    return WorkerRegistration(
      workerId: workerId,
      poolId: poolId,
      capabilities: {
        for (final capability in _capabilities)
          capability: CapabilitySpec(capability: capability, version: '1.0'),
      },
      status: status,
      currentLoad: _leased ? 1 : 0,
      maxConcurrency: 1,
      lastHeartbeat: DateTime.now().toUtc(),
      platform: platform,
    );
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    if (!_leased) await acquire();
    try {
      return await _drive(request);
    } finally {
      await release();
    }
  }

  Future<WorkerExecutionResult> _drive(WorkerExecutionRequest request) async {
    final startedAt = DateTime.now().toUtc();
    var execution = WorkerExecution(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      repositoryPath: request.repositoryPath,
      requestedStartingRevision: request.startingRevision,
      requiredCapabilities: request.requiredCapabilities,
      status: WorkerExecutionStatus.acquiring,
      cleanupPolicy: request.cleanupPolicy,
      workerId: workerId,
      createdAt: startedAt,
      startedAt: startedAt,
    );
    await workerStore.inTransaction((tx) async {
      await tx.saveWorkerExecution(execution);
      await _event(execution, WorkerEventType.workerAcquired, via: tx);
    });

    WorkspaceDescriptor? descriptor;
    var cleanupStatus = WorkerCleanupStatus.notApplicable;
    var failureCode = WorkerFailureCode.none;
    String? failureDetail;
    WorkerExecutionStatus finalStatus = WorkerExecutionStatus.executedFail;
    AgentResultStatus? agentResultStatus;
    bool? verificationPassed;
    String? verificationId;
    String? endingRevision;
    List<ChangedFile> changedFiles = const [];
    String? diffSummary;
    String? agentExecutionId;

    try {
      execution = await _transition(
        execution,
        WorkerExecutionStatus.workspacePreparing,
      );
      try {
        descriptor = await workspaceManager.prepare(
          request,
          workerId: workerId,
        );
      } on Object catch (e) {
        failureCode = WorkerFailureCode.prepareFailed;
        failureDetail = e.toString();
        finalStatus = WorkerExecutionStatus.prepareFailed;
        await _event(
          execution,
          WorkerEventType.prepareFailed,
          payload: {'detail': failureDetail},
        );
        return _finish(
          execution,
          finalStatus: finalStatus,
          cleanupStatus: cleanupStatus,
          failureCode: failureCode,
          failureDetail: failureDetail,
        );
      }

      await _event(execution, WorkerEventType.workspaceReady);
      execution = await _transition(
        execution,
        WorkerExecutionStatus.agentExecuting,
      );
      final agentRequest = _agentRequest(execution, request, descriptor);
      agentExecutionId = agentRequest.executionId;
      _activeAgentExecutionId = agentRequest.executionId;

      AgentExecution settled;
      try {
        await _event(execution, WorkerEventType.executionStarted);
        settled = await executionDriver
            .execute(agentRequest)
            .timeout(
              Duration(
                seconds: request.timeoutSeconds + workerLeaseGrace.inSeconds,
              ),
            );
      } on TimeoutException catch (e) {
        failureCode = WorkerFailureCode.timedOut;
        failureDetail = e.toString();
        await _cancelAgent(execution, agentRequest.executionId);
        finalStatus = WorkerExecutionStatus.timedOut;
        cleanupStatus = await _cleanupAfterFailure(
          execution,
          request,
          descriptor,
        );
        return _finish(
          execution,
          finalStatus: finalStatus,
          cleanupStatus: cleanupStatus,
          failureCode: failureCode,
          failureDetail: failureDetail,
          agentResultStatus: agentResultStatus,
          endingRevision: endingRevision,
          changedFiles: changedFiles,
          diffSummary: diffSummary,
        );
      }

      // Inspect git BEFORE cleanup: this is the platform's own evidence.
      final inspection = await inspector.inspect(
        descriptor.worktreePath,
        startingRevision: descriptor.startingRevision,
      );
      endingRevision = inspection.revision;
      changedFiles = inspection.changedFiles;
      diffSummary = inspection.diffSummary;

      agentResultStatus = _fromSessionStatus(settled.status);

      final verifications = await executionDriver.verificationsFor(
        agentRequest.executionId,
      );
      if (verifications.isNotEmpty) {
        await _event(execution, WorkerEventType.verificationStarted);
        verificationId = verifications.first.verificationId;
        verificationPassed = verifications.every(
          (v) => v.status == AgentClaimStatus.passed,
        );
      }

      switch (settled.status) {
        case AgentSessionStatus.completed:
          final passed =
              agentResultStatus == AgentResultStatus.completed &&
              (verificationPassed ?? true);
          finalStatus = passed
              ? WorkerExecutionStatus.executedPass
              : WorkerExecutionStatus.executedFail;
          if (!passed) {
            failureCode = WorkerFailureCode.agentFailed;
            failureDetail = verificationPassed == false
                ? 'verification ${verificationId ?? ''} failed'
                : 'agent completed without platform verification';
          }
        case AgentSessionStatus.failed:
          finalStatus = WorkerExecutionStatus.executedFail;
          failureCode = WorkerFailureCode.agentFailed;
          failureDetail = 'agent session failed';
        case AgentSessionStatus.interrupted:
          finalStatus = WorkerExecutionStatus.timedOut;
          failureCode = WorkerFailureCode.timedOut;
          failureDetail = 'agent session timed out';
        case AgentSessionStatus.cancelled:
          finalStatus = WorkerExecutionStatus.cancelled;
          failureCode = WorkerFailureCode.cancelled;
          failureDetail = 'agent session cancelled';
        case AgentSessionStatus.orphaned:
          finalStatus = WorkerExecutionStatus.orphaned;
          failureCode = WorkerFailureCode.agentFailed;
          failureDetail = 'agent session orphaned';
        case AgentSessionStatus.starting:
        case AgentSessionStatus.running:
          finalStatus = WorkerExecutionStatus.executedFail;
          failureCode = WorkerFailureCode.agentFailed;
          failureDetail = 'execution never reached a terminal state';
      }
    } on Object catch (e) {
      failureCode = failureCode == WorkerFailureCode.none
          ? WorkerFailureCode.agentFailed
          : failureCode;
      failureDetail ??= e.toString();
      finalStatus = WorkerExecutionStatus.executedFail;
      await _event(
        execution,
        WorkerEventType.executionFailed,
        payload: {'detail': e.toString()},
      );
    }

    cleanupStatus = await _finalCleanup(
      execution,
      request,
      descriptor,
      finalStatus: finalStatus,
    );
    return _finish(
      execution,
      finalStatus: finalStatus,
      cleanupStatus: cleanupStatus,
      failureCode: failureCode,
      failureDetail: failureDetail,
      agentResultStatus: agentResultStatus,
      verificationId: verificationId,
      verificationPassed: verificationPassed,
      agentExecutionId: agentExecutionId,
      endingRevision: endingRevision,
      changedFiles: changedFiles,
      diffSummary: diffSummary,
    );
  }

  AgentExecutionRequest _agentRequest(
    WorkerExecution execution,
    WorkerExecutionRequest request,
    WorkspaceDescriptor descriptor,
  ) {
    final agentExecutionId = 'agx-${request.workerExecutionId}';
    return AgentExecutionRequest(
      executionId: agentExecutionId,
      workItemId: request.workItemId,
      role: request.role,
      workspace: AgentWorkspace(
        workspaceId: descriptor.workspaceId,
        path: descriptor.worktreePath,
        startingRevision: descriptor.startingRevision,
        allowedPaths: [descriptor.worktreePath],
      ),
      instruction: request.instruction,
      timeoutSeconds: request.timeoutSeconds,
      runtimeTypeId: request.runtimeTypeId,
      expectedArtifacts: request.expectedArtifacts,
      runtimeConfig: request.runtimeConfig,
      environment: environmentPolicy.resolve(
        request,
        hostEnv: Platform.environment,
      ),
    );
  }

  Future<void> _cancelAgent(
    WorkerExecution execution,
    String agentExecutionId,
  ) async {
    try {
      await executionDriver.cancel(agentExecutionId, 'worker-level timeout');
    } on Object {
      // The coordinator may have already settled; never mask the timeout.
    }
  }

  AgentResultStatus? _fromSessionStatus(AgentSessionStatus status) {
    return switch (status) {
      AgentSessionStatus.completed => AgentResultStatus.completed,
      AgentSessionStatus.failed => AgentResultStatus.failed,
      AgentSessionStatus.cancelled => AgentResultStatus.cancelled,
      AgentSessionStatus.interrupted => AgentResultStatus.partial,
      _ => null,
    };
  }

  /// Cleanup on the happy path: agent passed and the platform verified.
  Future<WorkerCleanupStatus> _finalCleanup(
    WorkerExecution execution,
    WorkerExecutionRequest request,
    WorkspaceDescriptor? descriptor, {
    WorkerExecutionStatus finalStatus = WorkerExecutionStatus.executedFail,
  }) async {
    if (descriptor == null) return WorkerCleanupStatus.notApplicable;
    if (request.cleanupPolicy.preservesOnFailure &&
        finalStatus != WorkerExecutionStatus.executedPass) {
      await _setCleanup(execution, WorkerCleanupStatus.preservedPerPolicy);
      return WorkerCleanupStatus.preservedPerPolicy;
    }
    final status = await workspaceManager.cleanup(descriptor);
    await _setCleanup(execution, status);
    return status;
  }

  /// Cleanup on a failed/cancelled/timed-out execution, honoring the request's
  /// cleanup policy.
  Future<WorkerCleanupStatus> _cleanupAfterFailure(
    WorkerExecution execution,
    WorkerExecutionRequest request,
    WorkspaceDescriptor descriptor,
  ) async {
    if (request.cleanupPolicy.preservesOnFailure) {
      await _setCleanup(execution, WorkerCleanupStatus.preservedPerPolicy);
      return WorkerCleanupStatus.preservedPerPolicy;
    }
    final status = await workspaceManager.cleanup(descriptor);
    await _setCleanup(execution, status);
    return status;
  }

  Future<WorkerExecutionResult> _finish(
    WorkerExecution execution, {
    required WorkerExecutionStatus finalStatus,
    required WorkerCleanupStatus cleanupStatus,
    required WorkerFailureCode failureCode,
    String? failureDetail,
    AgentResultStatus? agentResultStatus,
    bool? verificationPassed,
    String? verificationId,
    String? agentExecutionId,
    List<ChangedFile> changedFiles = const [],
    String? diffSummary,
    String? endingRevision,
  }) async {
    // Re-read the canonical record so the terminal write's CAS compares
    // against the last persisted intermediate version.
    final current =
        await workerStore.readWorkerExecution(execution.workerExecutionId) ??
        execution;
    final terminal = current.copyWith(
      status: finalStatus,
      workspaceId: current.workspaceId ?? '',
      agentExecutionId: agentExecutionId ?? current.agentExecutionId,
      endingRevision: endingRevision,
      cleanupStatus: cleanupStatus,
      failureCode: failureCode,
      reason: failureDetail,
      endedAt: DateTime.now().toUtc(),
      version: current.version + 1,
    );
    late final WorkerExecutionResult result;

    await workerStore.inTransaction((tx) async {
      await tx.saveWorkerExecution(terminal, expectedVersion: current.version);

      result = WorkerExecutionResult(
        workerExecutionId: terminal.workerExecutionId,
        workItemId: terminal.workItemId,
        status: finalStatus,
        startingRevision: terminal.requestedStartingRevision,
        endingRevision: endingRevision,
        workerId: workerId,
        workspaceId: terminal.workspaceId ?? '',
        agentExecutionId: agentExecutionId,
        agentResultStatus: agentResultStatus,
        verificationId: verificationId,
        verificationPassed: verificationPassed,
        changedFiles: changedFiles,
        diffSummary: diffSummary,
        cleanupStatus: cleanupStatus,
        failureCode: failureCode,
        failureDetail: failureDetail,
        startedAt: terminal.startedAt ?? DateTime.now().toUtc(),
        endedAt: terminal.endedAt ?? DateTime.now().toUtc(),
      );
      await tx.saveResult(result);

      await _event(
        terminal,
        cleanupStatus == WorkerCleanupStatus.cleanupFailed
            ? WorkerEventType.cleanupFailed
            : finalStatus == WorkerExecutionStatus.executedPass
            ? WorkerEventType.workspaceCleaned
            : WorkerEventType.workerReleased,
        payload: {'status': finalStatus.name},
        via: tx,
      );
    });
    _leased = false;
    _activeAgentExecutionId = null;
    return result;
  }

  Future<WorkerExecution> _transition(
    WorkerExecution execution,
    WorkerExecutionStatus status,
  ) async {
    final next = execution.copyWith(
      status: status,
      version: execution.version + 1,
    );
    await workerStore.saveWorkerExecution(next);
    return next;
  }

  Future<void> _setCleanup(
    WorkerExecution execution,
    WorkerCleanupStatus status,
  ) async {
    final next = execution.copyWith(
      cleanupStatus: status,
      version: execution.version + 1,
    );
    await workerStore.saveWorkerExecution(next);
  }

  Future<void> _event(
    WorkerExecution execution,
    WorkerEventType type, {
    Map<String, dynamic>? payload,
    WorkerStore? via,
  }) async {
    final store = via ?? workerStore;
    final record = WorkerEventRecord(
      eventId: 'we-${execution.workerExecutionId}-${_sequence++}',
      workerExecutionId: execution.workerExecutionId,
      workItemId: execution.workItemId,
      sequence: _sequence,
      type: type,
      occurredAt: DateTime.now().toUtc(),
      payload: payload,
    );
    await store.appendEvent(record);
    eventSink?.call(record);
  }

  @override
  Future<void> cancel(String reason) async {
    final active = _activeAgentExecutionId;
    if (active == null) return;
    await executionDriver.cancel(active, reason);
  }
}

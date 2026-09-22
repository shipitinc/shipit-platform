import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart'
    show WorkerCleanupStatus, WorkerEventRecord, WorkerEventType, WorkerExecution, WorkerExecutionResult, WorkerExecutionStatus, WorkerFailureCode, WorkerExecutionRequest, WorkspaceDescriptor, ChangedFile, AgentRole, WorkerCleanupPolicy;
import 'package:worker_protocol/worker_protocol.dart';

import '../env/environment_policy.dart';
import '../store/worker_store.dart' show WorkerStore;
import '../workspace/git_workspace_inspector.dart';
import '../workspace/workspace_manager.dart';
import 'local_worker.dart'
    show WorkerBusyException;
import 'worker.dart';

/// Thrown when onboarding preparation fails (git clone, build, test).
class OnboardingPrepareException implements Exception {
  OnboardingPrepareException(this.detail);

  final String detail;

  @override
  String toString() => 'OnboardingPrepareException: $detail';
}

/// Worker that handles Product onboarding: clones a repository at a pinned
/// revision, runs baseline build + test commands, and writes a
/// [WorkspaceDescriptor] so the platform owns the execution environment.
///
/// This worker does NOT use the agent execution driver — onboarding is a
/// deterministic platform operation (git + build + test), not an LLM-driven
/// coding task.
class OnboardingWorker implements Worker {
  OnboardingWorker({
    required this.workerId,
    required this.poolId,
    required Set<WorkerCapability> capabilities,
    required this.workspaceManager,
    required this.workerStore,
    this.platform,
    this.environmentPolicy = const EnvironmentPolicy(),
    this.inspector = const GitWorkspaceInspector(),
    this.gitTimeout = const Duration(minutes: 5),
    this.buildTimeout = const Duration(minutes: 10),
    this.testTimeout = const Duration(minutes: 10),
    this.eventSink,
  }) : _capabilities = capabilities;

  final String workerId;
  final String poolId;
  final Set<WorkerCapability> _capabilities;
  final String? platform;
  final WorkspaceManager workspaceManager;
  final WorkerStore workerStore;
  final EnvironmentPolicy environmentPolicy;
  final GitWorkspaceInspector inspector;
  final Duration gitTimeout;
  final Duration buildTimeout;
  final Duration testTimeout;

  /// Optional observer for normalized worker events (used by tests/audit).
  final void Function(WorkerEventRecord event)? eventSink;

  bool _leased = false;
  int _sequence = 0;

  @override
  Set<WorkerCapability> get capabilities => _capabilities;

  @override
  bool get isAcquirable => !_leased;

  @override
  Future<void> acquire() async {
    if (_leased) throw WorkerBusyException(workerId);
    _leased = true;
  }

  @override
  Future<void> release() async {
    _leased = false;
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
      currentExecutionId: null,
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

  @override
  Future<void> cancel(String reason) async {
    // Onboarding worker has no agent session to cancel; the git process
    // will be killed by the timeout.
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
    String? endingRevision;
    List<ChangedFile> changedFiles = const [];
    String? diffSummary;

    try {
      execution = await _transition(
        execution,
        WorkerExecutionStatus.workspacePreparing,
      );

      // 1. Prepare workspace (clone at pinned revision via worktree)
      try {
        descriptor = await workspaceManager.prepare(
          request,
          workerId: workerId,
        );
      } on Object catch (e) {
        failureCode = WorkerFailureCode.prepareFailed;
        failureDetail = 'workspace prepare failed: $e';
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
        WorkerExecutionStatus.agentExecuting, // reuse status for "running commands"
      );

      // 2. Run baseline build
      await _event(execution, WorkerEventType.executionStarted);
      try {
        await _runCommand(
          execution,
          'build',
          _extractBuildCommand(request),
          buildTimeout,
          descriptor.worktreePath,
        );
      } on Object catch (e) {
        failureCode = WorkerFailureCode.agentFailed;
        failureDetail = 'build failed: $e';
        finalStatus = WorkerExecutionStatus.executedFail;
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
        );
      }

      // 3. Run baseline tests
      try {
        await _runCommand(
          execution,
          'test',
          _extractTestCommand(request),
          testTimeout,
          descriptor.worktreePath,
        );
      } on Object catch (e) {
        failureCode = WorkerFailureCode.agentFailed;
        failureDetail = 'test failed: $e';
        finalStatus = WorkerExecutionStatus.executedFail;
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
        );
      }

      // 4. Inspect git state (platform's own evidence)
      final inspection = await inspector.inspect(
        descriptor.worktreePath,
        startingRevision: descriptor.startingRevision,
      );
      endingRevision = inspection.revision;
      changedFiles = inspection.changedFiles;
      diffSummary = inspection.diffSummary;

      // 5. Success — the workspace is ready and verified
      finalStatus = WorkerExecutionStatus.executedPass;
      await _event(execution, WorkerEventType.workspaceReady);
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
      endingRevision: endingRevision,
      changedFiles: changedFiles,
      diffSummary: diffSummary,
    );
  }

  List<String> _extractBuildCommand(WorkerExecutionRequest request) {
    final config = request.runtimeConfig;
    if (config != null) {
      final buildCmd = config['buildCommand'];
      if (buildCmd != null) {
        // Try to parse as JSON list, fall back to space-split string
        try {
          final decoded = json.decode(buildCmd);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
        return buildCmd.split(' ');
      }
    }
    // Default: assume Dart/Flutter project
    return ['dart', 'pub', 'get'];
  }

  List<String> _extractTestCommand(WorkerExecutionRequest request) {
    final config = request.runtimeConfig;
    if (config != null) {
      final testCmd = config['testCommand'];
      if (testCmd != null) {
        try {
          final decoded = json.decode(testCmd);
          if (decoded is List) return decoded.cast<String>();
        } catch (_) {}
        return testCmd.split(' ');
      }
    }
    // Default: assume Dart/Flutter project
    return ['dart', 'test'];
  }

  Future<void> _runCommand(
    WorkerExecution execution,
    String phase,
    List<String> command,
    Duration timeout,
    String workingDirectory,
  ) async {
    await _event(
      execution,
      WorkerEventType.executionStarted,
      payload: {'phase': phase, 'command': command.join(' ')},
    );

    final result = await Process.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      environment: environmentPolicy.resolve(
        WorkerExecutionRequest(
          workerExecutionId: execution.workerExecutionId,
          workItemId: execution.workItemId,
          repositoryPath: execution.repositoryPath,
          startingRevision: execution.requestedStartingRevision,
          requiredCapabilities: execution.requiredCapabilities,
          role: AgentRole.implementer,
          instruction: '',
          timeoutSeconds: timeout.inSeconds,
          runtimeTypeId: 'onboarding',
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        ),
        hostEnv: Platform.environment,
      ),
    ).timeout(timeout, onTimeout: () {
      throw OnboardingPrepareException('$phase command timed out after $timeout');
    });

    if (result.exitCode != 0) {
      throw OnboardingPrepareException(
        '$phase exited ${result.exitCode}: ${result.stderr}',
      );
    }
  }

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
    String? endingRevision,
    List<ChangedFile> changedFiles = const [],
    String? diffSummary,
  }) async {
    final current =
        await workerStore.readWorkerExecution(execution.workerExecutionId) ??
        execution;
    final terminal = current.copyWith(
      status: finalStatus,
      workspaceId: current.workspaceId ?? '',
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
        agentExecutionId: null,
        agentResultStatus: null,
        verificationId: null,
        verificationPassed: finalStatus == WorkerExecutionStatus.executedPass,
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
}
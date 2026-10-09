import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart'
    show
        AgentEventRecord,
        AgentExecution,
        AgentResult,
        AgentWorkspace,
        DiagnosticEntry,
        PlatformVerification;
import 'package:serverpod/serverpod.dart';

import '../generated/agent_artifact_view.dart';
import '../generated/agent_claimed_check_view.dart';
import '../generated/agent_diagnostics_view.dart';
import '../generated/agent_event_view.dart';
import '../generated/agent_execution_inspection_view.dart';
import '../generated/agent_execution_list_view.dart';
import '../generated/agent_execution_record_view.dart';
import '../generated/agent_result_view.dart';
import '../generated/agent_workspace_view.dart';
import '../generated/changed_file_view.dart';
import '../generated/diagnostic_entry_view.dart';
import '../generated/platform_verification_view.dart';
import '../generated/resource_usage_view.dart';
import '../services/control_plane_service.dart';

/// Read endpoints for execution_coordinator durable state (agent executions,
/// events, results, verifications).
class ExecutionEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Lists agent executions, optionally filtered by work item. Reads only.
  Future<AgentExecutionListView> list(
    Session session, {
    String? workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final executions = await service.listAgentExecutions(
        workItemId: workItemId,
      );
      return AgentExecutionListView(
        executions: executions.map(_executionView).toList(growable: false),
      );
    } catch (error, stackTrace) {
      service.logger.error('execution.list.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns one execution, its events, result and verifications. Reads only.
  Future<AgentExecutionInspectionView> inspect(
    Session session, {
    required String executionId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final execution = await service.readAgentExecution(executionId);
      final events = await service.readAgentEvents(executionId);
      final result = await service.readAgentResult(executionId);
      final verifications = await service.readVerifications(executionId);
      return AgentExecutionInspectionView(
        execution: _executionView(execution),
        events: events.map(_eventView).toList(growable: false),
        result: result == null ? null : _resultView(result),
        verifications: verifications
            .map(_verificationView)
            .toList(growable: false),
      );
    } catch (error, stackTrace) {
      service.logger.error('execution.inspect.failed', {
        'executionId': executionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // ---------------------------------------------------------------------
  // Projections
  //
  // Named copies, not `toJson()`, so a field added to a domain type breaks this
  // build instead of silently widening a wire contract nobody has reviewed.
  // Enums travel as wire text, as everywhere else in `lib/src/models/`.
  //
  // THE OPEN-ENDED VALUES TRAVEL AS JSON TEXT: `AgentExecution.metadata`,
  // `AgentEventRecord.payload` and `AgentResult.structuredResult` are
  // `Map<String, dynamic>` on the domain types, and Serverpod 3.4.13 refuses
  // `dynamic` in a model schema outright ("The datatype \"dynamic\" is not
  // supported in models"), so no field type can hold parsed JSON. `jsonDecode`
  // recovers the original value exactly.
  // ---------------------------------------------------------------------

  AgentWorkspaceView _workspaceView(AgentWorkspace w) => AgentWorkspaceView(
    workspaceId: w.workspaceId,
    path: w.path,
    startingRevision: w.startingRevision,
    allowedPaths: w.allowedPaths,
  );

  AgentExecutionRecordView _executionView(AgentExecution e) =>
      AgentExecutionRecordView(
        executionId: e.executionId,
        workItemId: e.workItemId,
        requestId: e.requestId,
        runtimeTypeId: e.runtimeTypeId,
        role: e.role.wire,
        status: e.status.name,
        workspace: _workspaceView(e.workspace),
        sessionId: e.sessionId,
        resultId: e.resultId,
        startedAt: e.startedAt,
        completedAt: e.completedAt,
        reason: e.reason,
        metadataJson: e.metadata == null ? null : jsonEncode(e.metadata),
        version: e.version,
      );

  AgentEventView _eventView(AgentEventRecord e) => AgentEventView(
    eventId: e.eventId,
    executionId: e.executionId,
    workItemId: e.workItemId,
    sequence: e.sequence,
    type: e.type.wire,
    occurredAt: e.occurredAt,
    payloadJson: e.payload == null ? null : jsonEncode(e.payload),
  );

  AgentResultView _resultView(AgentResult r) => AgentResultView(
    resultId: r.resultId,
    sessionId: r.sessionId,
    workItemId: r.workItemId,
    status: r.status.wire,
    artifacts: r.artifacts
        .map(
          (a) => AgentArtifactView(
            artifactId: a.artifactId,
            type: a.type,
            path: a.path,
            sha256: a.sha256,
            sizeBytes: a.sizeBytes,
            mediaType: a.mediaType,
            description: a.description,
          ),
        )
        .toList(growable: false),
    diagnostics: AgentDiagnosticsView(
      exitCode: r.diagnostics.exitCode,
      durationMs: r.diagnostics.durationMs,
      toolCalls: r.diagnostics.toolCalls,
      errors: r.diagnostics.errors.map(_diagnosticView).toList(growable: false),
      warnings: r.diagnostics.warnings
          .map(_diagnosticView)
          .toList(growable: false),
      resourceUsage: r.diagnostics.resourceUsage == null
          ? null
          : ResourceUsageView(
              peakMemoryMb: r.diagnostics.resourceUsage!.peakMemoryMb,
              cpuSeconds: r.diagnostics.resourceUsage!.cpuSeconds,
              networkBytes: r.diagnostics.resourceUsage!.networkBytes,
            ),
    ),
    structuredResultJson: jsonEncode(r.structuredResult),
    executionId: r.executionId,
    role: r.role?.wire,
    changedFiles: r.changedFiles
        ?.map(
          (f) => ChangedFileView(
            path: f.path,
            operation: f.operation.wire,
            beforeSha: f.beforeSha,
            afterSha: f.afterSha,
          ),
        )
        .toList(growable: false),
    claimedChecks: r.claimedChecks
        ?.map(
          (c) => AgentClaimedCheckView(
            checkName: c.checkName,
            status: c.status.wire,
            evidenceKind: c.evidenceKind.wire,
            command: c.command,
            detail: c.detail,
          ),
        )
        .toList(growable: false),
    summary: r.summary,
    completedAt: r.completedAt,
    metadataJson: r.metadata == null ? null : jsonEncode(r.metadata),
  );

  DiagnosticEntryView _diagnosticView(DiagnosticEntry d) => DiagnosticEntryView(
    code: d.code,
    message: d.message,
    severity: d.severity,
    location: d.location,
    suggestion: d.suggestion,
  );

  PlatformVerificationView _verificationView(PlatformVerification v) =>
      PlatformVerificationView(
        verificationId: v.verificationId,
        executionId: v.executionId,
        workItemId: v.workItemId,
        checkName: v.checkName,
        status: v.status.wire,
        mechanism: v.mechanism,
        command: v.command,
        capturedAt: v.capturedAt,
        evidenceKind: v.evidenceKind.wire,
        outputRef: v.outputRef,
        detail: v.detail,
        resultPath: v.resultPath,
      );
}

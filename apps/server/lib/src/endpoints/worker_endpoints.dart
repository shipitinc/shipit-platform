import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart'
    show WorkerExecution, WorkerExecutionResult, WorkerEventRecord;
import 'package:serverpod/serverpod.dart';

import '../generated/artifact_cache_entry_view.dart';
import '../generated/capability_spec_view.dart';
import '../generated/changed_file_view.dart';
import '../generated/worker_event_view.dart';
import '../generated/worker_execution_inspection_view.dart';
import '../generated/worker_execution_list_view.dart';
import '../generated/worker_execution_result_view.dart';
import '../generated/worker_execution_view.dart';
import '../generated/worker_list_view.dart';
import '../generated/worker_registration_view.dart';
import '../services/control_plane_service.dart';
import 'package:worker_protocol/worker_protocol.dart'
    show CapabilitySpec, WorkerRegistration, ArtifactCacheEntry;

/// Read endpoints for worker_runtime durable state (registrations +
/// executions + results).
class WorkerEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Lists registered workers. Reads only.
  ///
  /// Was `Future<Map<String, dynamic>>`. It published
  /// `WorkerRegistrationCodec.toJson(...)` verbatim, whose nested `capabilities`
  /// and `artifactCache` objects are `Map<String, dynamic>`; those are now typed
  /// views keyed by their wire names.
  Future<WorkerListView> listWorkers(
    Session session,
  ) async {
    final service = ControlPlaneService(session);
    try {
      final workers = await service.listWorkers();
      return WorkerListView(
        workers: workers.map(_registrationView).toList(growable: false),
      );
    } catch (error, stackTrace) {
      service.logger.error('worker.list.failed', {'error': error.toString()});
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists worker executions, newest first. Reads only.
  Future<WorkerExecutionListView> listExecutions(
    Session session, {
    String? workItemId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final executions = await service.listWorkerExecutions();
      final filtered = workItemId == null
          ? executions
          : executions.where((e) => e.workItemId == workItemId).toList();
      return WorkerExecutionListView(
        executions: filtered.map(_executionView).toList(growable: false),
      );
    } catch (error, stackTrace) {
      service.logger.error('worker.executions.failed', {
        'workItemId': workItemId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns one execution, its events and (if present) its result. Reads only.
  Future<WorkerExecutionInspectionView> inspect(
    Session session, {
    required String workerExecutionId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final executions = await service.listWorkerExecutions();
      final execution = executions
          .where((e) => e.workerExecutionId == workerExecutionId)
          .firstOrNull;
      if (execution == null) {
        throw StateError('Unknown worker execution $workerExecutionId');
      }
      final result = await service.readWorkerResult(workerExecutionId);
      final events = await service.readWorkerEvents(workerExecutionId);
      return WorkerExecutionInspectionView(
        execution: _executionView(execution),
        events: events.map(_eventView).toList(growable: false),
        result: result == null ? null : _resultView(result),
      );
    } catch (error, stackTrace) {
      service.logger.error('worker.inspect.failed', {
        'workerExecutionId': workerExecutionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // ---------------------------------------------------------------------
  // Projections
  //
  // Named copies, not `WorkerRegistrationCodec.toJson(...)` or `toJson()`, so a
  // field added to a domain type breaks this build instead of silently widening
  // a wire contract. Enums travel as wire text, as everywhere else in
  // `lib/src/models/`; `WorkerRegistration.capabilities` is keyed by the enum on
  // the domain type and by the enum's wire name on the wire, because JSON object
  // keys are strings.
  //
  // `WorkerEventRecord.payload` is the one open-ended value and travels as JSON
  // TEXT: Serverpod 3.4.13 refuses `dynamic` in a model schema, so no field type
  // can hold parsed JSON. See `defect_endpoints.dart` for the same convention.
  // ---------------------------------------------------------------------

  CapabilitySpecView _capabilitySpecView(CapabilitySpec spec) =>
      CapabilitySpecView(
        capability: spec.capability.name,
        version: spec.version,
        metadata: spec.metadata,
        providedTools: spec.providedTools,
      );

  ArtifactCacheEntryView _cacheEntryView(ArtifactCacheEntry e) =>
      ArtifactCacheEntryView(
        artifactHash: e.artifactHash,
        localPath: e.localPath,
        cachedAt: e.cachedAt,
        sizeBytes: e.sizeBytes,
      );

  WorkerRegistrationView _registrationView(WorkerRegistration r) =>
      WorkerRegistrationView(
        workerId: r.workerId,
        poolId: r.poolId,
        capabilities: r.capabilities.map(
          (capability, spec) =>
              MapEntry(capability.name, _capabilitySpecView(spec)),
        ),
        status: r.status.name,
        currentLoad: r.currentLoad,
        maxConcurrency: r.maxConcurrency,
        lastHeartbeat: r.lastHeartbeat,
        artifactCache: r.artifactCache?.map(
          (key, entry) => MapEntry(key, _cacheEntryView(entry)),
        ),
        platform: r.platform,
      );

  WorkerExecutionView _executionView(WorkerExecution e) => WorkerExecutionView(
    workerExecutionId: e.workerExecutionId,
    workItemId: e.workItemId,
    repositoryPath: e.repositoryPath,
    requestedStartingRevision: e.requestedStartingRevision,
    requiredCapabilities: e.requiredCapabilities
        .map((c) => c.name)
        .toList(growable: false),
    status: e.status.name,
    cleanupPolicy: e.cleanupPolicy.name,
    workerId: e.workerId,
    workspaceId: e.workspaceId,
    agentExecutionId: e.agentExecutionId,
    resultId: e.resultId,
    endingRevision: e.endingRevision,
    cleanupStatus: e.cleanupStatus?.name,
    failureCode: e.failureCode?.name,
    createdAt: e.createdAt,
    startedAt: e.startedAt,
    endedAt: e.endedAt,
    reason: e.reason,
    version: e.version,
  );

  WorkerEventView _eventView(WorkerEventRecord e) => WorkerEventView(
    eventId: e.eventId,
    workerExecutionId: e.workerExecutionId,
    workItemId: e.workItemId,
    sequence: e.sequence,
    type: e.type.wire,
    occurredAt: e.occurredAt,
    payloadJson: e.payload == null ? null : jsonEncode(e.payload),
  );

  WorkerExecutionResultView _resultView(WorkerExecutionResult r) =>
      WorkerExecutionResultView(
        workerExecutionId: r.workerExecutionId,
        workItemId: r.workItemId,
        status: r.status.name,
        workerId: r.workerId,
        workspaceId: r.workspaceId,
        startingRevision: r.startingRevision,
        endingRevision: r.endingRevision,
        agentExecutionId: r.agentExecutionId,
        agentResultStatus: r.agentResultStatus?.wire,
        verificationId: r.verificationId,
        verificationPassed: r.verificationPassed,
        changedFiles: r.changedFiles
            .map(
              (f) => ChangedFileView(
                path: f.path,
                operation: f.operation.wire,
                beforeSha: f.beforeSha,
                afterSha: f.afterSha,
              ),
            )
            .toList(growable: false),
        diffSummary: r.diffSummary,
        diffRef: r.diffRef,
        cleanupStatus: r.cleanupStatus.name,
        failureCode: r.failureCode.name,
        failureDetail: r.failureDetail,
        startedAt: r.startedAt,
        endedAt: r.endedAt,
      );
}

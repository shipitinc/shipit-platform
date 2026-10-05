import 'dart:async';
import 'dart:convert';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

import '../persistence/persistence_database.dart';
import '../persistence/postgres_defect_store.dart'
    show DefectNotFoundException, PostgresDefectStore;
import '../persistence/postgres_triage_store.dart' show PostgresTriageStore;
import 'lane_e_design_remediation_work_item.dart'
    show DesignRemediationWorkItemProvisioner, designRemediationWorkItemId;

/// Processes completed triage jobs: parses the agent's structured result into
/// a durable [TriageResult], persists it, and enqueues clarifications if needed.
class TriageProcessor {
  TriageProcessor({
    required this.db,
    required this.workflowStore,
    required this.workflowEngine,
    required this.executionCoordinator,
    required this.defectStore,
    required this.triageStore,
    this.logger,
  });

  final PersistenceDatabase db;
  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final ExecutionCoordinator executionCoordinator;
  final PostgresDefectStore defectStore;
  final PostgresTriageStore triageStore;
  final void Function(String, Map<String, dynamic>)? logger;

  /// Processes a completed triage job by reading its agent execution result,
  /// parsing the structured output into a [TriageResult], and persisting it.
  ///
  /// Returns the created [TriageResult] if successful, null if the job wasn't
  /// a triage job or has no execution result yet. A `DESIGN_DEFECT`
  /// classification additionally opens a durable design remediation work item
  /// via [DesignRemediationWorkItemProvisioner]; that step is non-fatal and
  /// idempotent, so the returned [TriageResult] is the same either way.
  Future<TriageResult?> processCompletedTriageJob(Job job) async {
    if (job.jobType != JobType.triageDefect) return null;
    final agentExecutionId = job.executionReference?.agentExecutionId;
    if (agentExecutionId == null) return null;

    final execution = await executionCoordinator.store.readExecution(
      agentExecutionId,
    );
    if (!execution.isTerminal) return null;

    final result = await executionCoordinator.store.readResult(
      execution.executionId,
    );
    if (result == null) return null;

    // A terminal execution is not a successful one.
    //
    // `ExecutionCoordinator._complete` persists the role-stamped `AgentResult`
    // BEFORE `_completeSuccess` attempts the work-item transition, and the
    // catch in `execute` then records the execution as
    // `AgentSessionStatus.failed`. So the result stays durable (forensics, and
    // that part is deliberate) while the platform has declared the run itself
    // a failure. Reading that result as an authoritative classification
    // produces exactly the incoherent state this guards against: the job row
    // says PERMANENTLY FAILED, the execution row says failed, and the defect
    // has been given a confident classification anyway.
    //
    // The coordinator's result-before-transition ordering is kept. The
    // consumer is where the decision belongs, so the gate is here.
    //
    // BOTH signals are checked, and each catches a case the other misses:
    // `execution.status` is `failed` whenever finalization threw for ANY
    // reason (a refused transition, a store error), while a run that
    // completed normally can still have ended with a non-completed result —
    // `_completeSuccess` maps `AgentResultStatus.completed` to
    // `AgentEventType.executionCompleted` and anything else to
    // `executionFailed` even on a `completed` session.
    if (execution.status != AgentSessionStatus.completed ||
        result.status != AgentResultStatus.completed) {
      logger?.call('triage.execution_not_successful', {
        'jobId': job.jobId,
        'workItemId': job.workItemId,
        'defectId': _extractDefectId(job.workItemId),
        'executionId': execution.executionId,
        'executionStatus': execution.status.name,
        'resultId': result.resultId,
        'resultStatus': result.status.wire,
        'resultSummary': result.summary,
        'reason': execution.reason,
        'action': 'no TriageResult, no defect update, no clarifications',
      });
      return null;
    }

    final triageResult = _parseTriageResult(job, execution, result);
    if (triageResult == null) return null;

    await triageStore.saveTriageResult(triageResult);

    // The defect is the authoritative source for everything that follows: the
    // remediation work item's title and its product link. It is read ONCE,
    // here, and the loaded copy is what gets passed on. The copy saved below
    // carries the triage metadata merge, and re-reading after that would race
    // the CAS version.
    //
    // `readDefect` throws `DefectNotFoundException` rather than returning null
    // (there is no `defect-{id}` row to merge into), and `triage_result` /
    // `defect_clarification` carry no foreign key to `defect`, so this is a
    // reachable state: a triage job whose defect has since been deleted. The
    // TriageResult is already durable and must not be lost, so the outcome is
    // logged and the durable result returned unchanged. Every remaining step is
    // a write against the missing defect row, so none of them can honestly run.
    final Defect defect;
    try {
      defect = await defectStore.readDefect(triageResult.defectId);
    } on DefectNotFoundException catch (e) {
      logger?.call('triage.processed.defect_missing', {
        'jobId': job.jobId,
        'triageResultId': triageResult.resultId,
        'defectId': triageResult.defectId,
        'classification': triageResult.recommendedClassification.wire,
        'error': e.toString(),
      });
      return triageResult;
    }

    // Update defect with triage reference
    final updated = defect.copyWith(
      metadataJson: _mergeTriageMetadata(defect.metadataJson, triageResult),
      version: defect.version + 1,
    );
    await defectStore.saveDefect(updated, expectedVersion: defect.version);

    // If clarification is required, create defect clarifications
    if (triageResult.clarificationRequired.isNotEmpty) {
      await _createClarifications(triageResult, job.jobId);
    }

    logger?.call('triage.processed', {
      'jobId': job.jobId,
      'triageResultId': triageResult.resultId,
      'defectId': triageResult.defectId,
      'classification': triageResult.recommendedClassification.wire,
      'clarificationCount': triageResult.clarificationRequired.length,
    });

    // If classification is DESIGN_DEFECT, create a DesignRemediationRequest
    // and persist it as a WorkItem.
    //
    // Everything above is already committed, so a throw from here would not
    // undo the triage outcome — but it WOULD abort the caller's loop over the
    // jobs this tick touched, and a retry is not free either: the clarifications
    // above are appended under a time-based id, so every retry duplicates an
    // append-only side effect. The step is therefore non-fatal, and never
    // silent: the cause is logged under a greppable event naming the defect
    // and the work item it was provisioning, and the provisioner is idempotent
    // (read-before-create plus per-hop idempotency keys), so a later retry
    // converges on the same single remediation item.
    if (triageResult.recommendedClassification ==
        DefectClassification.designDefect) {
      try {
        await _createDesignRemediationRequest(triageResult, defect);
      } catch (e) {
        logger?.call('design_remediation.failed', {
          'jobId': job.jobId,
          'triageResultId': triageResult.resultId,
          'defectId': triageResult.defectId,
          'workItemId': designRemediationWorkItemId(triageResult.defectId),
          'error': e.toString(),
        });
      }
    }

    return triageResult;
  }

  TriageResult? _parseTriageResult(
    Job job,
    AgentExecution execution,
    AgentResult result,
  ) {
    final structured = result.structuredResult;
    if (structured.isEmpty) {
      logger?.call('triage.parse.empty_structured_result', {
        'jobId': job.jobId,
        'executionId': execution.executionId,
      });
      return null;
    }

    try {
      // Validate required fields
      final classificationStr = structured['classification'] as String?;
      if (classificationStr == null) {
        throw FormatException('Missing required field: classification');
      }
      final classification = DefectClassification.fromWire(classificationStr);

      final statusStr = structured['status'] as String?;
      if (statusStr == null) {
        throw FormatException('Missing required field: status');
      }
      final status = DefectStatus.fromWire(statusStr);

      final confidence = (structured['confidence'] as num?)?.toDouble();
      if (confidence == null) {
        throw FormatException('Missing required field: confidence');
      }
      // Per ADR 0020: confidence is recorded as advisory signal; no semantic
      // meaning is assigned by the platform. No range enforcement.

      final suspectedCategory = structured['suspectedCategory'] as String?;
      if (suspectedCategory == null) {
        throw FormatException('Missing required field: suspectedCategory');
      }

      final suspectedComponents =
          (structured['suspectedComponents'] as List?)?.cast<String>() ??
          <String>[];

      final reproductionSupported =
          structured['reproductionSupported'] as bool? ?? false;

      final evidenceUsed =
          (structured['evidenceUsed'] as List?)?.cast<String>() ?? <String>[];

      final clarificationList = <DefectClarificationRequest>[];
      if (structured['clarificationRequired'] is List) {
        for (final c in structured['clarificationRequired'] as List) {
          if (c is Map<String, dynamic>) {
            clarificationList.add(DefectClarificationRequest.fromJson(c));
          }
        }
      }

      final recommendedNextAction =
          structured['recommendedNextAction'] as String? ?? 'investigate';

      final now = DateTime.now().toUtc();
      return TriageResult(
        resultId: 'tr-${job.jobId}',
        defectId: _extractDefectId(job.workItemId),
        recommendedStatus: status,
        recommendedClassification: classification,
        confidence: confidence,
        suspectedCategory: suspectedCategory,
        suspectedComponents: suspectedComponents,
        reproductionSupported: reproductionSupported,
        evidenceUsed: evidenceUsed,
        clarificationRequired: clarificationList,
        recommendedNextAction: recommendedNextAction,
        possibleDuplicateDefectId:
            structured['possibleDuplicateDefectId'] as String?,
        recommendedWorkItemCategory:
            structured['recommendedWorkItemCategory'] as String?,
        summary: structured['summary'] as String? ?? 'Triage completed',
        jobId: job.jobId,
        executionId: execution.executionId,
        createdAt: now,
        completedAt: now,
        version: 1,
      );
    } on FormatException catch (e) {
      logger?.call('triage.parse.failed', {
        'jobId': job.jobId,
        'error': e.toString(),
      });
      return null;
    }
  }

  String _extractDefectId(String workItemId) {
    // Work item ID format for defects: "defect-{defectId}"
    if (workItemId.startsWith('defect-')) {
      return workItemId.substring('defect-'.length);
    }
    return workItemId;
  }

  String _mergeTriageMetadata(String? existingJson, TriageResult triageResult) {
    final existing = existingJson != null && existingJson.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(existingJson) as Map)
        : <String, dynamic>{};
    existing['triageResultId'] = triageResult.resultId;
    existing['triageClassification'] =
        triageResult.recommendedClassification.wire;
    existing['triageStatus'] = triageResult.recommendedStatus.wire;
    existing['triageCompletedAt'] = triageResult.completedAt?.toIso8601String();
    return jsonEncode(existing);
  }

  Future<void> _createClarifications(
    TriageResult triageResult,
    String jobId,
  ) async {
    final now = DateTime.now().toUtc();
    for (final req in triageResult.clarificationRequired) {
      final clarification = DefectClarification(
        clarificationId:
            'clar-${triageResult.resultId}-${DateTime.now().millisecondsSinceEpoch}',
        defectId: triageResult.defectId,
        question: req.question,
        reason: req.reason,
        status: ClarificationStatus.needsAnswer,
        requestedByTriageJobId: jobId,
        requestedAt: now,
        createdAt: now,
        version: 1,
      );
      await defectStore.saveClarification(clarification);
    }
  }

  /// Creates the durable design remediation record for a defect that triage
  /// classified as `DESIGN_DEFECT`.
  ///
  /// The [DesignRemediationWorkItemProvisioner] owns the product resolution,
  /// the `designRemediation-{defectId}` identity, the `draft -> planning ->
  /// planned` walk-up and the honest
  /// `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY` metadata; see that class for why
  /// the walk deliberately stops at `planned` instead of entering
  /// `designRequired` on a fabricated `designContractId`. [defect] is the copy
  /// already loaded by [processCompletedTriageJob] and is not re-read here.
  Future<void> _createDesignRemediationRequest(
    TriageResult triageResult,
    Defect defect,
  ) async {
    await DesignRemediationWorkItemProvisioner(
      workflowStore: workflowStore,
      workflowEngine: workflowEngine,
      log: logger,
    ).ensurePersisted(triageResult: triageResult, defect: defect);
  }
}

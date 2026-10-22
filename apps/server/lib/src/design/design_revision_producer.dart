import 'dart:convert';

import 'package:design_governance/design_governance.dart'
    show
        DesignRevisionNotFoundException,
        DesignRevisionStore,
        gateDesignRevisionWrite;
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:scheduler/scheduler.dart' show JobStore;
import 'package:workflow_store/workflow_store.dart'
    show DesignContractStore, DurableWorkflowEngine, WorkflowStore;

import '../persistence/postgres_defect_store.dart' show DefectNotFoundException;
import '../triage/lane_e_design_remediation_work_item.dart'
    show designRemediationRequiredKey;

/// The three keys the design agent's `structuredResult` is read through, and the
/// one place their wire spelling is fixed. Kept private because the contract is
/// the agent's, not a public Dart API.
const String _designSystemRevisionKey = 'designSystemRevision';
const String _providerKey = 'provider';
const String _penpotFileIdKey = 'penpotFileId';
const String _penpotPageIdKey = 'penpotPageId';
const String _boardIdsKey = 'boardIds';
const String _responsiveTargetsKey = 'responsiveTargets';
const String _statesRepresentedKey = 'statesRepresented';
const String _artifactRefsKey = 'artifactRefs';
const String _reviewExecutionIdsKey = 'reviewExecutionIds';
const String _parentRevisionIdKey = 'parentRevisionId';
const String _carriedForwardFromRevisionIdKey = 'carriedForwardFromRevisionId';
const String _reviewScopeKey = 'reviewScope';

/// The metadata keys Q3 requires on the work item, and the exact spelling the
/// design review scheduler reads (`designReviewDedupeKey`,
/// `designReviewRequest`). They are written together or not at all.
const String designRevisionIdMetadataKey = 'designRevisionId';
const String designerExecutionIdMetadataKey = 'designerExecutionId';

/// The outcome of one completed `designRevision` job.
enum DesignRevisionProducerOutcome {
  /// The revision was written, read back, the contract submitted, and the item
  /// advanced to `designInReview`.
  produced,

  /// A previous run already completed for this execution. No second revision
  /// was minted.
  alreadyProduced,

  /// A named precondition or postcondition failed. Nothing past the refusal ran.
  refused,

  /// The job was not a design-revision job. The dispatch table registers this
  /// handler only for `JobType.designRevision`, so this is defensive.
  notApplicable,
}

/// The structured outcome of [DesignRevisionProducer.processCompletedDesignRevisionJob].
///
/// A refusal is a VERDICT, not a thrown error: it names the condition that
/// failed (see [refusalCode]) and the handler returns normally, which is how
/// `drainTriageOutcomesFromTick` distinguishes "this job was considered and
/// deliberately refused" from "the handler broke". An exception is reserved for
/// a genuine store/engine failure.
class DesignRevisionProducerResult {
  const DesignRevisionProducerResult._({
    required this.outcome,
    this.revision,
    this.refusalCode,
    this.detail,
  });

  const DesignRevisionProducerResult.produced(DesignRevision revision)
    : this._(
        outcome: DesignRevisionProducerOutcome.produced,
        revision: revision,
      );

  const DesignRevisionProducerResult.alreadyProduced(DesignRevision revision)
    : this._(
        outcome: DesignRevisionProducerOutcome.alreadyProduced,
        revision: revision,
      );

  const DesignRevisionProducerResult.refused(
    String code, {
    String? detail,
  }) : this._(
         outcome: DesignRevisionProducerOutcome.refused,
         refusalCode: code,
         detail: detail,
       );

  const DesignRevisionProducerResult.notApplicable(String detail)
    : this._(
        outcome: DesignRevisionProducerOutcome.notApplicable,
        detail: detail,
      );

  final DesignRevisionProducerOutcome outcome;
  final DesignRevision? revision;
  final String? refusalCode;
  final String? detail;

  bool get isRefused => outcome == DesignRevisionProducerOutcome.refused;

  @override
  String toString() =>
      'DesignRevisionProducerResult(${outcome.name}'
      '${refusalCode == null ? '' : ', $refusalCode'}'
      '${detail == null ? '' : ': $detail'})';
}

/// The step-6 designer: consumes a terminal `designRevision` job, turns the
/// completed execution's `structuredResult` into a durable [DesignRevision],
/// submits the design contract for review, and advances the item
/// `agentCompleted -> designInReview`.
///
/// ## Why it is a terminal-job consumer
///
/// There is no `agentExecuting -> designInReview` edge, and `agentCompleted ->
/// designInReview` is guarded by `designContractUnderReview()`. So the producer
/// cannot run at dispatch; it runs from the tick drain once the execution is
/// durably completed, mirroring `TriageProcessor`. Registering it in the same
/// type-dispatch table is what makes step 8 a scheduler mount rather than
/// another wiring exercise.
///
/// ## Why it owns contract submission
///
/// Nothing else moves a design contract `draft -> underReview`. Without this
/// write the under-review guard refuses every completion, and every revision the
/// runtime produces is unreviewable. Submission is a real store write with a
/// read-back; a silent no-op is a refusal, and an already-`underReview`
/// contract is idempotent.
///
/// ## What it never does
///
/// It never reads `riskTier` or `designerExecutionId` from the agent, never
/// writes a revision that fails the fidelity anchor, and never forces a
/// transition past a guard. It is inert until step 8 mounts the scheduler: no
/// design job is enqueued in this composition.
class DesignRevisionProducer {
  DesignRevisionProducer({
    required this.workflowStore,
    required this.workflowEngine,
    required this.executionStore,
    required this.jobStore,
    required this.designRevisionStore,
    required this.designContractStore,
    required this.defectStore,
    this.logger,
    DateTime Function()? clock,
  }) : _clock = clock ?? _utcNow;

  final WorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final ExecutionStore executionStore;
  final JobStore jobStore;
  final DesignRevisionStore designRevisionStore;
  final DesignContractStore designContractStore;
  final DefectStore defectStore;
  final void Function(String event, Map<String, dynamic> data)? logger;
  final DateTime Function() _clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// The deterministic revision id for [executionId].
  ///
  /// Determinism is the idempotency mechanism: a crash after the revision write
  /// but before the transition leaves the item at `agentCompleted`, and the
  /// next run upserts the SAME row instead of minting a second revision for one
  /// execution.
  static String designRevisionIdForExecution(String executionId) =>
      'design-revision-$executionId';

  /// Runs the step-6 producer for one drained job.
  Future<DesignRevisionProducerResult> processCompletedDesignRevisionJob(
    Job job,
  ) async {
    if (job.jobType != JobType.designRevision) {
      return DesignRevisionProducerResult.notApplicable(
        'job type ${job.jobType.wire} is not ${JobType.designRevision.wire}',
      );
    }
    if (!job.isTerminal) {
      return _refuse(job, 'job.not-terminal', job.state.wire);
    }

    final executionId = job.executionReference?.agentExecutionId;
    if (executionId == null || executionId.isEmpty) {
      return _refuse(job, 'execution.reference-missing');
    }

    final execution = await executionStore.readExecutionOrNull(executionId);
    if (execution == null) {
      return _refuse(job, 'execution.missing', executionId);
    }
    if (execution.workItemId != job.workItemId) {
      // Q2: the execution must be THIS item's, never another item's.
      return _refuse(
        job,
        'q2.execution-work-item-mismatch',
        'execution ${execution.executionId} belongs to '
            '${execution.workItemId}, job to ${job.workItemId}',
      );
    }
    if (!execution.isTerminal) {
      return _refuse(job, 'execution.not-terminal', execution.status.name);
    }
    if (execution.status != AgentSessionStatus.completed) {
      // A terminal execution is not a successful one. A failed run still leaves
      // a durable result behind for forensics; it is never a revision.
      return _refuse(job, 'execution.not-completed', execution.status.name);
    }

    final result = await executionStore.readResult(execution.executionId);
    if (result == null) {
      return _refuse(job, 'result.missing', execution.executionId);
    }
    if (result.status != AgentResultStatus.completed) {
      return _refuse(job, 'result.not-completed', result.status.wire);
    }
    if (result.workItemId != job.workItemId) {
      return _refuse(
        job,
        'q2.result-work-item-mismatch',
        'result ${result.resultId} belongs to ${result.workItemId}, '
            'job to ${job.workItemId}',
      );
    }

    final item = await workflowStore.readWorkItem(job.workItemId);

    // Replay of a run that already completed. This is checked BEFORE P1 so a
    // second tick over the same execution reports the truth ("already done")
    // rather than refusing an item that is legitimately past `agentCompleted`.
    if (_alreadyStampedFor(item, execution)) {
      final existingId = item.metadata?[designRevisionIdMetadataKey] as String?;
      if (existingId == null || existingId.isEmpty) {
        return _refuse(job, 'already-produced.revision-id-missing');
      }
      try {
        final existing = await designRevisionStore.readDesignRevision(
          existingId,
        );
        logger?.call('design_revision.already_produced', {
          'jobId': job.jobId,
          'workItemId': job.workItemId,
          'executionId': execution.executionId,
          'revisionId': existing.revisionId,
        });
        return DesignRevisionProducerResult.alreadyProduced(existing);
      } on DesignRevisionNotFoundException catch (e) {
        return _refuse(job, 'already-produced.revision-unreadable', '$e');
      }
    }

    // ---- P1: the item is at agentCompleted, and its DURABLE contract id
    // resolves. The "at designRequired" half of P1 is dispatch-time (step 8),
    // not completion-time.
    if (item.state != WorkItemState.agentCompleted) {
      return _refuse(
        job,
        'p1.work-item-not-at-agent-completed',
        item.state.wire,
      );
    }
    final contractId = item.designContractId;
    if (contractId == null || contractId.isEmpty) {
      return _refuse(job, 'p1.design-contract-id-missing');
    }
    final contract = await designContractStore.readDesignContract(contractId);
    if (contract == null) {
      return _refuse(job, 'p1.design-contract-unresolved', contractId);
    }
    if (contract.workItemId != item.workItemId) {
      return _refuse(
        job,
        'p1.design-contract-work-item-mismatch',
        'contract ${contract.contractId} belongs to ${contract.workItemId}, '
            'item is ${item.workItemId}',
      );
    }

    // ---- The payload. Missing or malformed is a NAMED refusal, never a
    // default: a revision assembled from absent fields would be a claim the
    // platform invented.
    final _DesignRevisionPayload payload;
    try {
      payload = _decodePayload(result.structuredResult);
    } on _PayloadRefusal catch (e) {
      return _refuse(job, e.code, e.detail);
    }

    // ---- P2: a design-system revision is named, non-empty.
    //
    // The design's "and equals the product's declared design-system revision"
    // half has no readable source in this tree: no `Product` field and no store
    // records a declared design-system revision. Only the non-empty assertion is
    // enforceable here; the gap is named in [DesignRevisionProducer]'s
    // limitations rather than guessed at.
    final designSystemRevision = payload.designSystemRevision.trim();
    if (designSystemRevision.isEmpty) {
      return _refuse(job, 'p2.design-system-revision-missing');
    }

    // ---- P3: a named parent (a correction) must resolve and be the CURRENT
    // APPROVED revision for this item.
    DesignRevision? parent;
    final parentId = payload.parentRevisionId;
    if (parentId != null) {
      final approved = await designRevisionStore
          .readApprovedDesignRevisionForWorkItem(item.workItemId);
      if (approved == null || approved.revisionId != parentId) {
        DesignRevision? found;
        try {
          found = await designRevisionStore.readDesignRevision(parentId);
        } on DesignRevisionNotFoundException {
          found = null;
        }
        if (found == null) {
          return _refuse(job, 'p3.parent-revision-not-found', parentId);
        }
        return _refuse(
          job,
          'p3.parent-revision-not-current-approved',
          'parent $parentId is not the approved revision '
              '(${approved?.revisionId ?? 'none'}) for ${item.workItemId}',
        );
      }
      parent = approved;
    }

    // ---- P4: a design-remediation item's defect still resolves and is still
    // classified `designDefect`, and the item's `featureRef` agrees with it.
    if (item.metadata?[designRemediationRequiredKey] == true) {
      final defectId = item.metadata?['defectId'];
      if (defectId is! String || defectId.isEmpty) {
        return _refuse(job, 'p4.defect-id-missing');
      }
      if (item.featureRef != defectId) {
        return _refuse(
          job,
          'p4.feature-ref-defect-id-disagreement',
          'featureRef ${item.featureRef}, defectId $defectId',
        );
      }
      final Defect defect;
      try {
        defect = await defectStore.readDefect(defectId);
      } on DefectNotFoundException catch (e) {
        return _refuse(job, 'p4.defect-unresolved', '$e');
      }
      if (defect.classification != DefectClassification.designDefect) {
        return _refuse(
          job,
          'p4.defect-not-design-defect',
          defect.classification?.wire ?? 'unclassified',
        );
      }
    }

    // ---- P5: no OTHER live design-revision job for this item.
    final jobs = await jobStore.listJobsForWorkItem(item.workItemId);
    final live = jobs.where(
      (other) =>
          other.jobId != job.jobId &&
          other.jobType == JobType.designRevision &&
          !other.isTerminal,
    );
    if (live.isNotEmpty) {
      return _refuse(
        job,
        'p5.live-design-revision-job',
        live.map((j) => '${j.jobId}:${j.state.wire}').join(','),
      );
    }

    // ---- P6: no unresolved designReviewRequest / designApproval on the item.
    final decisions = await workflowStore.readHumanDecisionsForWorkItem(
      item.workItemId,
    );
    final unresolved = decisions.where(
      (decision) =>
          !_isClosedDecision(decision) &&
          (decision.decisionType == HumanDecisionType.designApproval ||
              decision.decisionType == HumanDecisionType.designReviewRequest),
    );
    if (unresolved.isNotEmpty) {
      return _refuse(
        job,
        'p6.unresolved-design-decision',
        unresolved
            .map(
              (d) => '${d.decisionId}:${d.decisionType.wire}:${d.status.wire}',
            )
            .join(','),
      );
    }

    // ---- Q5: Penpot references are coherent with the declared provider.
    if (payload.provider != DesignProviderType.penpot) {
      return _refuse(
        job,
        'q5.unsupported-provider',
        payload.provider.wire,
      );
    }
    final penpotFileId = payload.penpotFileId;
    final penpotPageId = payload.penpotPageId;
    if (penpotFileId == null || penpotFileId.isEmpty) {
      return _refuse(job, 'q5.penpot-file-id-missing');
    }
    if (penpotPageId == null || penpotPageId.isEmpty) {
      return _refuse(job, 'q5.penpot-page-id-missing');
    }

    // ---- Q6: the design-system revision does not change from the parent.
    if (parent != null && designSystemRevision != parent.designSystemRevision) {
      return _refuse(
        job,
        'q6.design-system-revision-changed',
        'parent ${parent.designSystemRevision}, '
            'child $designSystemRevision',
      );
    }

    final now = _clock();
    final revisionId = designRevisionIdForExecution(execution.executionId);
    final draft = DesignRevision(
      revisionId: revisionId,
      workItemId: item.workItemId,
      productId: item.productId,
      parentRevisionId: parentId,
      designSystemRevision: designSystemRevision,
      provider: payload.provider,
      penpotFileId: penpotFileId,
      penpotPageId: penpotPageId,
      boardIdsJson: jsonEncode(payload.boardIds),
      responsiveTargetsJson: jsonEncode(payload.responsiveTargets),
      statesRepresentedJson: jsonEncode(payload.statesRepresented),
      artifactRefsJson: jsonEncode(payload.artifactRefs),
      // Q2: ONLY the execution record's identity. Any value in the payload is
      // ignored, because a designer that asserts its own id can collapse the
      // reviewer's independence at the root.
      designerExecutionId: execution.executionId,
      reviewExecutionIdsJson: jsonEncode(payload.reviewExecutionIds),
      // Q4: status is draft and the risk tier is policy, never the agent's
      // claim. D4 fixes the tier at high for the whole lane.
      status: DesignRevisionStatus.draft,
      riskTier: DesignRiskTier.high,
      reviewScopeJson: payload.reviewScope,
      carriedForwardFromRevisionId: payload.carriedForwardFromRevisionId,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );

    // ---- Q7: the fidelity anchor. The gate canonicalises then re-asserts; a
    // violation is refused HERE, before anything is stored, so no unflagged
    // non-conforming row is ever readable.
    final DesignRevision gated;
    try {
      gated = gateDesignRevisionWrite(draft);
    } on DesignRevisionFidelityAnchorException catch (e) {
      return _refuse(
        job,
        'q7.fidelity-anchor-invalid',
        e.violations
            .map((v) => '${v.column}/${v.code}: ${v.detail}')
            .join(' | '),
      );
    }

    // ---- Q1: write, then READ BACK. A silent no-op is indistinguishable from
    // success without the read-back, so the read-back is the postcondition.
    await designRevisionStore.saveDesignRevision(gated);
    final DesignRevision readBack;
    try {
      readBack = await designRevisionStore.readDesignRevision(
        gated.revisionId,
      );
    } on DesignRevisionNotFoundException catch (e) {
      return _refuse(job, 'q1.revision-not-readable-after-write', '$e');
    }
    if (readBack.revisionId != gated.revisionId) {
      return _refuse(
        job,
        'q1.read-back-revision-id-mismatch',
        'wrote ${gated.revisionId}, read ${readBack.revisionId}',
      );
    }
    if (readBack.designerExecutionId != execution.executionId) {
      return _refuse(
        job,
        'q2.designer-execution-id-mismatch',
        'wrote ${execution.executionId}, '
            'read ${readBack.designerExecutionId}',
      );
    }

    // ---- Submission: draft -> underReview, with a read-back. Already
    // `underReview` is idempotent; any other status is refused rather than
    // forced.
    final submissionRefusal = await _submitForReview(job, contract, now);
    if (submissionRefusal != null) return submissionRefusal;

    // ---- Q3: both metadata keys, atomically with the transition.
    await workflowEngine.transition(
      workItemId: item.workItemId,
      to: WorkItemState.designInReview,
      trigger: TransitionTrigger.systemEvent,
      // Keyed by EXECUTION, not by job or attempt: a second drain of the same
      // completed execution (two server instances, or a tick retried after a
      // crash between the write and the transition) is the same act, so the
      // engine returns the already-transitioned item instead of rejecting
      // "already in designInReview" and recording a spurious job failure. The
      // revision id is derived from the same execution id, so the key and the
      // row it advances name one event.
      idempotencyKey: 'design-revision-transition-${execution.executionId}',
      metadataMerge: <String, dynamic>{
        designRevisionIdMetadataKey: readBack.revisionId,
        designerExecutionIdMetadataKey: execution.executionId,
      },
    );

    // Read the transition's result back. `metadataMerge` is applied inside the
    // transition, so a store that accepted the state change but dropped the
    // merge is exactly the G-E failure this postcondition exists to catch.
    final finished = await workflowStore.readWorkItem(item.workItemId);
    final stampedRevision = finished.metadata?[designRevisionIdMetadataKey];
    final stampedDesigner = finished.metadata?[designerExecutionIdMetadataKey];
    if (finished.state != WorkItemState.designInReview ||
        stampedRevision != readBack.revisionId ||
        stampedDesigner != execution.executionId) {
      return _refuse(
        job,
        'q3.metadata-not-stamped',
        'state ${finished.state.wire}, '
            '$designRevisionIdMetadataKey=$stampedRevision, '
            '$designerExecutionIdMetadataKey=$stampedDesigner',
      );
    }

    logger?.call('design_revision.produced', {
      'jobId': job.jobId,
      'workItemId': item.workItemId,
      'executionId': execution.executionId,
      'revisionId': readBack.revisionId,
      'contractId': contract.contractId,
      'status': readBack.status.wire,
      'riskTier': readBack.riskTier.name,
    });

    return DesignRevisionProducerResult.produced(readBack);
  }

  /// Moves [contract] to `underReview` and reads it back.
  ///
  /// A contract already under review needs no second write. Any terminal or
  /// non-draft status is refused: submitting an approved/rejected/expired
  /// contract would overwrite the decision that gave it that status.
  Future<DesignRevisionProducerResult?> _submitForReview(
    Job job,
    DesignContract contract,
    DateTime now,
  ) async {
    if (contract.status == DesignContractStatus.underReview) {
      return null;
    }
    if (contract.status != DesignContractStatus.draft) {
      return _refuse(
        job,
        'contract.not-draft',
        'contract ${contract.contractId} is ${contract.status.name}',
      );
    }

    final submitted = DesignContract(
      contractId: contract.contractId,
      workItemId: contract.workItemId,
      requiredArtifacts: contract.requiredArtifacts,
      reviewers: contract.reviewers,
      approvalThreshold: contract.approvalThreshold,
      status: DesignContractStatus.underReview,
      submittedArtifacts: contract.submittedArtifacts,
      decisions: contract.decisions,
      createdAt: contract.createdAt,
      updatedAt: now,
      expiresAt: contract.expiresAt,
      metadata: contract.metadata,
    );
    await designContractStore.saveDesignContract(submitted);

    final readBack = await designContractStore.readDesignContract(
      contract.contractId,
    );
    if (readBack == null) {
      return _refuse(
        job,
        'contract.submission-not-readable',
        contract.contractId,
      );
    }
    if (readBack.status != DesignContractStatus.underReview) {
      return _refuse(
        job,
        'contract.submission-not-under-review',
        '${contract.contractId} is ${readBack.status.name}',
      );
    }
    return null;
  }

  bool _alreadyStampedFor(WorkItem item, AgentExecution execution) {
    if (item.state != WorkItemState.designInReview) return false;
    final stampedRevision = item.metadata?[designRevisionIdMetadataKey];
    final stampedDesigner = item.metadata?[designerExecutionIdMetadataKey];
    return stampedRevision is String &&
        stampedRevision.isNotEmpty &&
        stampedDesigner == execution.executionId;
  }

  /// `resolved` and `cancelled` are the only two statuses that stop a decision
  /// from blocking. `deferred` and `escalated` are still live gates.
  static bool _isClosedDecision(HumanDecision decision) =>
      decision.status == HumanDecisionStatus.resolved ||
      decision.status == HumanDecisionStatus.cancelled;

  DesignRevisionProducerResult _refuse(
    Job job,
    String code, [
    String? detail,
  ]) {
    logger?.call('design_revision.refused', {
      'jobId': job.jobId,
      'workItemId': job.workItemId,
      'code': code,
      if (detail != null) 'detail': detail,
    });
    return DesignRevisionProducerResult.refused(code, detail: detail);
  }
}

/// The design agent's `structuredResult`, decoded and type-checked.
class _DesignRevisionPayload {
  const _DesignRevisionPayload({
    required this.designSystemRevision,
    required this.provider,
    required this.penpotFileId,
    required this.penpotPageId,
    required this.boardIds,
    required this.responsiveTargets,
    required this.statesRepresented,
    required this.artifactRefs,
    required this.reviewExecutionIds,
    required this.parentRevisionId,
    required this.carriedForwardFromRevisionId,
    required this.reviewScope,
  });

  final String designSystemRevision;
  final DesignProviderType provider;
  final String? penpotFileId;
  final String? penpotPageId;
  final List<dynamic> boardIds;
  final List<dynamic> responsiveTargets;
  final List<dynamic> statesRepresented;
  final List<dynamic> artifactRefs;
  final List<dynamic> reviewExecutionIds;
  final String? parentRevisionId;
  final String? carriedForwardFromRevisionId;
  final Map<String, dynamic>? reviewScope;
}

/// Internal: a payload failure, converted to a producer refusal by the caller.
class _PayloadRefusal implements Exception {
  const _PayloadRefusal(this.code, this.detail);

  final String code;
  final String detail;
}

_DesignRevisionPayload _decodePayload(Map<String, dynamic> structured) {
  if (structured.isEmpty) {
    throw const _PayloadRefusal(
      'payload.missing',
      'structuredResult is empty',
    );
  }

  final rawProvider = _requireString(structured, _providerKey);
  final DesignProviderType provider;
  try {
    provider = DesignProviderType.fromWire(rawProvider);
  } on FormatException catch (e) {
    throw _PayloadRefusal('payload.malformed', e.message);
  }

  return _DesignRevisionPayload(
    designSystemRevision: _requireString(
      structured,
      _designSystemRevisionKey,
    ),
    provider: provider,
    penpotFileId: _optionalString(structured, _penpotFileIdKey),
    penpotPageId: _optionalString(structured, _penpotPageIdKey),
    boardIds: _requireList(structured, _boardIdsKey),
    responsiveTargets: _requireList(structured, _responsiveTargetsKey),
    statesRepresented: _requireList(structured, _statesRepresentedKey),
    artifactRefs: _requireList(structured, _artifactRefsKey),
    reviewExecutionIds: _requireList(structured, _reviewExecutionIdsKey),
    parentRevisionId: _optionalString(structured, _parentRevisionIdKey),
    carriedForwardFromRevisionId: _optionalString(
      structured,
      _carriedForwardFromRevisionIdKey,
    ),
    reviewScope: _optionalMap(structured, _reviewScopeKey),
  );
}

String _requireString(Map<String, dynamic> map, String field) {
  if (!map.containsKey(field)) {
    throw _PayloadRefusal(
      'payload.missing',
      '$field is required',
    );
  }
  final value = map[field];
  if (value is! String) {
    throw _PayloadRefusal(
      'payload.malformed',
      '$field must be a string, got ${value.runtimeType}',
    );
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String field) {
  if (!map.containsKey(field) || map[field] == null) return null;
  final value = map[field];
  if (value is! String) {
    throw _PayloadRefusal(
      'payload.malformed',
      '$field must be a string or null, got ${value.runtimeType}',
    );
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<dynamic> _requireList(Map<String, dynamic> map, String field) {
  if (!map.containsKey(field)) {
    throw _PayloadRefusal(
      'payload.missing',
      '$field is required',
    );
  }
  final decoded = _decodeJsonish(map[field], field);
  if (decoded is! List) {
    throw _PayloadRefusal(
      'payload.malformed',
      '$field must be a JSON array, got ${decoded.runtimeType}',
    );
  }
  return decoded;
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> map, String field) {
  if (!map.containsKey(field) || map[field] == null) return null;
  final decoded = _decodeJsonish(map[field], field);
  if (decoded is! Map) {
    throw _PayloadRefusal(
      'payload.malformed',
      '$field must be a JSON object, got ${decoded.runtimeType}',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

/// Accepts the value itself, or a JSON-encoded string carrying it.
Object? _decodeJsonish(Object? value, String field) {
  if (value is! String) return value;
  try {
    return jsonDecode(value);
  } on FormatException catch (e) {
    throw _PayloadRefusal(
      'payload.malformed',
      '$field is a string but not valid JSON: ${e.message}',
    );
  }
}

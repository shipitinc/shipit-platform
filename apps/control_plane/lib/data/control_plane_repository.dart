import 'dart:convert';

import 'package:control_plane_client/control_plane_client.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// Handwritten repository for the operator UI.
///
/// Talks to the generated `control_plane_client`, mapping the typed Serverpod
/// wire models (Overview, WorkItemView, DecisionView, ...) onto the small
/// stable response objects the feature layers consume. The wire contract is
/// typed end-to-end, so the generated client needs no manual repair.
class ControlPlaneRepository {
  ControlPlaneRepository({required this._client});

  final Client _client;

  /// Bumped whenever this client writes durable state.
  ///
  /// Chrome that caches derived values (the rail's counts) can listen instead
  /// of polling, so resolving a decision in place updates the whole surface.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<OverviewResponse> getOverview() async {
    final result = await _client.homeEndpoints.overview();
    return OverviewResponse(
      running: result.running,
      waitingOnYou: result.waitingOnYou,
      recentlyFinished: result.recentlyFinished,
      finishedPassed: result.finishedPassed,
      finishedFailed: result.finishedFailed,
      generatedAt: result.generatedAt,
      machinesBusy: result.machinesBusy,
      machinesTotal: result.machinesTotal,
      jobs: result.jobs
          .map(
            (j) => JobSummaryResponse(
              jobId: j.jobId,
              workItemId: j.workItemId,
              state: j.state,
              jobType: j.jobType,
              createdAt: j.createdAt,
              availableAt: j.availableAt,
              blockedOnDecision: j.blockedOnDecision,
              attempt: j.attempt,
              maxAttempts: j.maxAttempts,
            ),
          )
          .toList(),
    );
  }

  /// One row per registered product, for the Products screen.
  ///
  /// `allowsDispatch` is mirrored from the engine rather than re-derived here;
  /// the UI must never disagree with `ProductState` about whether work may run.
  Future<List<ProductSummaryResponse>> listProductSummaries() async {
    final rows = await _client.productRegistryEndpoints.listProductSummaries();
    return rows
        .map(
          (r) => ProductSummaryResponse(
            productId: r.productId,
            name: r.name,
            state: r.state,
            allowsDispatch: r.allowsDispatch,
            activeBaselineId: r.activeBaselineId,
            activeBaselineRevision: r.activeBaselineRevision,
            pendingBaselineId: r.pendingBaselineId,
            pendingBaselineRevision: r.pendingBaselineRevision,
            pendingBaselineVerified: r.pendingBaselineVerified,
            baselineFactCount: r.baselineFactCount,
            openClarifications: r.openClarifications,
            repositoryCount: r.repositoryCount,
            reachableRepositoryCount: r.reachableRepositoryCount,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  /// Everything the Product Detail screen reads, in one call.
  Future<ProductDetailResponse> getProductDetail(String productId) async {
    final d = await _client.productRegistryEndpoints.productDetail(
      productId: productId,
    );
    return ProductDetailResponse(
      productId: d.product.productId,
      name: d.product.name,
      description: d.product.description,
      state: d.product.state,
      allowsDispatch: d.allowsDispatch,
      updatedAt: d.product.updatedAt,
      repositories: d.repositories
          .map(
            (r) => ProductRepositoryResponse(
              repositoryId: r.repositoryId,
              uri: r.uri,
              kind: r.kind,
              provider: r.provider,
            ),
          )
          .toList(),
      credentials: d.credentials
          .map(
            (c) => CredentialResponse(
              credentialId: c.credentialId,
              repositoryId: c.repositoryId,
              referenceName: c.referenceName,
              fingerprint: c.fingerprint,
              algorithm: c.algorithm,
              status: c.status,
              hostKeyStatus: c.hostKeyStatus,
              host: c.host,
              canReachRepository: c.canReachRepository,
              lastVerifiedAt: c.lastVerifiedAt,
              lastVerifiedBy: c.lastVerifiedBy,
              lastFailureReason: c.lastFailureReason,
              hostConfirmedAt: c.hostConfirmedAt,
              hostConfirmedBy: c.hostConfirmedBy,
            ),
          )
          .toList(),
      activeBaselineId: d.activeBaseline?.baselineId,
      activeBaselineRevision: d.activeBaseline?.revision,
      activeBaselineHash: d.activeBaseline?.contentHash,
      activeBaselineAcceptedAt: d.activeBaseline?.acceptedAt,
      activeBaselineAcceptedBy: d.activeBaseline?.acceptedBy,
      activeBaselineFactCount: d.activeBaseline?.facts.length ?? 0,
      pendingBaselineId: d.pendingBaseline?.baselineId,
      pendingBaselineRevision: d.pendingBaseline?.revision,
      pendingBaselineVerified: d.pendingBaselineVerified,
      pendingBaselineFacts: (d.pendingBaseline?.facts ?? const [])
          .map(BaselineFactClaim.fromProtocol)
          .toList(),
      pendingBaselineDecisionId: d.pendingBaselineDecisionId,
      openClarifications: d.openClarifications
          .map(
            (c) => ClarificationSummary(
              clarificationId: c.clarificationId,
              question: c.question,
              section: c.section,
            ),
          )
          .toList(),
      policies: d.policies.map(_policyResponse).toList(),
    );
  }

  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    String? productId,
    int? limit,
  }) async {
    final result = await _client.homeEndpoints.listWorkItems(
      state: state,
      productId: productId,
      limit: limit,
    );
    return result.map(_workItemResponse).toList();
  }

  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async {
    final result = await _client.homeEndpoints.pendingDecisions(limit: limit);
    return result.map(_decisionResponse).toList();
  }

  /// Decisions that already carry a durable outcome, newest first.
  Future<List<DecisionResponse>> recentDecisions({
    int? limit,
    int? offset,
  }) async {
    final result = await _client.homeEndpoints.recentDecisions(
      limit: limit,
      offset: offset,
    );
    return result.map(_decisionResponse).toList();
  }

  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async {
    final result = await _client.workflowEndpoints.inspect(
      workItemId: workItemId,
    );
    return WorkItemDetailResponse(
      workItem: _workItemResponse(result.workItem),
      transitionHistory: result.transitionHistory
          .map(
            (t) => TransitionResponse(
              transitionId: t.transitionId,
              workItemId: t.workItemId,
              fromState: t.fromState,
              toState: t.toState,
              transitionedAt: t.transitionedAt,
              reason: t.reason,
            ),
          )
          .toList(),
    );
  }

  /// Raises the durable gate that precedes a lifecycle transition.
  ///
  /// `action` is pause | resume | offboard. The engine refuses up front if
  /// the transition could never resolve, so an operator is never offered a
  /// gate nobody could action. Returns the gate to resolve.
  Future<DecisionResponse> requestLifecycleDecision({
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async {
    final m = await _client.productRegistryEndpoints.requestLifecycleDecision(
      productId: productId,
      action: action,
      drainInFlight: drainInFlight,
    );
    revision.value++;
    return _decisionResponse(m);
  }

  /// Resolves a lifecycle gate. On approve the engine performs the
  /// transition, and refuses if a required guard was never established —
  /// offboarding with work still in flight, for example.
  Future<DecisionResponse> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    bool noWorkInFlight = false,
  }) async {
    final now = DateTime.now();
    final m = await _client.productRegistryEndpoints.resolveLifecycleDecision(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      algorithm: 'ed25519',
      publicKey: 'operator-pub-key',
      signature: 'operator-sig-${now.millisecondsSinceEpoch}',
      signedAt: now,
      noWorkInFlight: noWorkInFlight,
    );
    revision.value++;
    return _decisionResponse(m);
  }

  /// Raises the gate that would create a standing policy (ADR 0019).
  ///
  /// `actions` may only contain push | merge. Production promotion, baseline
  /// approval and offboarding are non-delegable and are not expressible.
  Future<DecisionResponse> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) async {
    final m = await _client.productRegistryEndpoints.requestPolicyAuthorisation(
      productId: productId,
      actions: actions,
    );
    revision.value++;
    return _decisionResponse(m);
  }

  /// Resolves a policy gate. On approve a standing policy is created citing
  /// this decision; any policy already live over the same scope is
  /// superseded.
  Future<PolicyResponse> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    final now = DateTime.now();
    final m = await _client.productRegistryEndpoints.resolvePolicyAuthorisation(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      algorithm: 'ed25519',
      publicKey: 'operator-pub-key',
      signature: 'operator-sig-${now.millisecondsSinceEpoch}',
      signedAt: now,
    );
    revision.value++;
    return _policyResponse(m!);
  }

  /// Withdraws a standing policy. Revocation is itself recorded.
  Future<void> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async {
    await _client.productRegistryEndpoints.revokeStandingPolicy(
      productId: productId,
      policyId: policyId,
      revokedBy: revokedBy,
    );
    revision.value++;
  }

  /// Jobs belonging to a work item, newest first. Read-only.
  /// Jobs belonging to a work item, newest first. Read-only.
  Future<List<JobSummaryResponse>> jobsForWorkItem(String workItemId) async {
    final result = await _client.workflowEndpoints.jobsForWorkItem(
      workItemId: workItemId,
    );
    return result
        .map(
          (j) => JobSummaryResponse(
            jobId: j.jobId,
            workItemId: j.workItemId,
            state: j.state,
            jobType: j.jobType,
            createdAt: j.createdAt,
            availableAt: j.availableAt,
            blockedOnDecision: j.blockedOnDecision,
            attempt: j.attempt,
            maxAttempts: j.maxAttempts,
          ),
        )
        .toList();
  }

  Future<DecisionDetailResponse> inspectDecision(String workItemId) async {
    final result = await _client.workflowEndpoints.listDecisions(
      workItemId: workItemId,
    );
    if (result.isEmpty) {
      throw StateError('No decisions found for work item $workItemId');
    }
    return DecisionDetailResponse(
      decisionId: result.first.decisionId,
      workItemId: result.first.workItemId,
      workItemTitle: result.first.workItemTitle,
      workItemDescription: result.first.workItemDescription,
      decisionType: result.first.decisionType,
      status: result.first.status,
      question: result.first.question,
      context: result.first.context == null
          ? null
          : DecisionContext(
              workflowState: result.first.context!.workflowState,
              availableOptions: result.first.context!.availableOptions,
            ),
      options: result.first.options
          ?.map(
            (o) => DecisionOption(
              optionId: o.optionId,
              label: o.label,
              description: o.description,
              recommended: o.recommended,
            ),
          )
          .toList(),
      recommendation: result.first.recommendation,
      artifactRefs: result.first.artifactRefs
          ?.map(_artifactRefResponse)
          .toList(),
      blocking: result.first.blocking,
      requestedAt: result.first.requestedAt,
      expiration: result.first.expiration,
      choice: result.first.choice,
      decider: result.first.decider,
      rationale: result.first.rationale,
      resolvedAt: result.first.resolvedAt,
      signature: result.first.signature,
    );
  }

  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    final now = DateTime.now();
    await _client.workflowEndpoints.resolveDecision(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      algorithm: 'ed25519',
      publicKey: 'operator-pub-key',
      signature: 'operator-sig-${now.millisecondsSinceEpoch}',
      signedAt: now,
    );
    revision.value++;
  }

  WorkItemResponse _workItemResponse(WorkItemView m) {
    return WorkItemResponse(
      workItemId: m.workItemId,
      title: m.title,
      description: m.description,
      state: m.state,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      completedAt: m.completedAt,
      blockingHumanDecisionId: m.blockingHumanDecisionId,
      artifactRefs: m.artifactRefs?.map(_artifactRefResponse).toList(),
    );
  }

  /// Maps a standing policy as the durable record the operator cites. Same
  /// shape whether listed (search) or created (resolution) — one model, no
  /// special casing.
  PolicyResponse _policyResponse(StandingPolicyView m) {
    return PolicyResponse(
      policyId: m.policyId,
      actions: m.actions,
      authorisingDecisionId: m.authorisingDecisionId,
      authorisedBy: m.authorisedBy,
      rationale: m.rationale,
      authorisedAt: m.authorisedAt,
      isRevoked: m.isRevoked,
      revokedBy: m.revokedBy,
      revocationReason: m.revocationReason,
    );
  }

  DecisionResponse _decisionResponse(DecisionView m) {
    return DecisionResponse(
      decisionId: m.decisionId,
      workItemId: m.workItemId,
      workItemTitle: m.workItemTitle,
      workItemDescription: m.workItemDescription,
      decisionType: m.decisionType,
      status: m.status,
      question: m.question,
      context: m.context == null
          ? null
          : DecisionContext(
              workflowState: m.context!.workflowState,
              availableOptions: m.context!.availableOptions,
            ),
      options: m.options
          ?.map(
            (o) => DecisionOption(
              optionId: o.optionId,
              label: o.label,
              description: o.description,
              recommended: o.recommended,
            ),
          )
          .toList(),
      recommendation: m.recommendation,
      blocking: m.blocking,
      requestedAt: m.requestedAt,
      expiration: m.expiration,
      artifactRefs: m.artifactRefs?.map(_artifactRefResponse).toList(),
      choice: m.choice,
      decider: m.decider,
      rationale: m.rationale,
      resolvedAt: m.resolvedAt,
      signature: m.signature,
    );
  }

  Future<CreateDefectResponse> createDefect({
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) async {
    final result = await _client.defectEndpoints.create(
      title: title,
      description: description,
      expectedBehavior: expectedBehavior,
      reproductionSteps: reproductionSteps,
      severity: severity,
      intakeCategory: intakeCategory,
      productId: productId,
      affectedWorkItemId: affectedWorkItemId,
      affectedRunId: affectedRunId,
      clientContextJson: clientContextJson,
      reporter: reporter,
    );
    return CreateDefectResponse.fromJson(result.toJson());
  }

  Future<ListDefectsResponse> listDefects({
    String? productId,
    String? status,
    String? classification,
    int? limit,
    int? offset,
  }) async {
    final result = await _client.defectEndpoints.list(
      productId: productId,
      status: status,
      classification: classification,
      limit: limit,
      offset: offset,
    );
    return ListDefectsResponse.fromJson(result.toJson());
  }

  Future<InspectDefectResponse> inspectDefect(String defectId) async {
    final result = await _client.defectEndpoints.inspect(defectId: defectId);
    return InspectDefectResponse.fromJson(result.toJson());
  }

  // ------------------------------------------------- Reports · feature tab

  /// Files a feature request. The server creates a draft feature work item and
  /// its intake direction in one transaction, so a success here means the
  /// request is durably visible in both the register and the inbox.
  Future<CreateFeatureRequestResponse> createFeatureRequest({
    required String title,
    required String description,
    required String productId,
    required String reporter,
  }) async {
    final result = await _client.intakeEndpoints.createFeatureRequest(
      title: title,
      description: description,
      productId: productId,
      reporter: reporter,
    );
    revision.value++;
    return CreateFeatureRequestResponse(
      workItemId: result.workItemId,
      title: result.title,
      state: result.state,
      createdAt: result.createdAt,
    );
  }

  /// Feature requests, newest first — the Reports screen's second tab.
  Future<List<FeatureRequestSummaryResponse>> listFeatureRequests({
    String? productId,
    int? limit,
  }) async {
    final rows = await _client.intakeEndpoints.listFeatureRequests(
      productId: productId,
      limit: limit,
    );
    return rows
        .map(
          (r) => FeatureRequestSummaryResponse(
            workItemId: r.workItemId,
            title: r.title,
            description: r.description,
            state: r.state,
            productId: r.productId,
            productName: r.productName,
            reporter: r.reporter,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
            completedAt: r.completedAt,
          ),
        )
        .toList();
  }

  Future<DefectEvidenceResponse> addDefectEvidence({
    required String defectId,
    required String kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) async {
    final result = await _client.defectEndpoints.addEvidence(
      defectId: defectId,
      kind: kind,
      description: description,
      artifactId: artifactId,
      contentHash: contentHash,
      sourceRef: sourceRef,
    );
    return DefectEvidenceResponse.fromJson(result.toJson());
  }

  Future<void> answerClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async {
    await _client.defectEndpoints.answerClarification(
      clarificationId: clarificationId,
      answer: answer,
      answeredBy: answeredBy,
    );
    revision.value++;
  }

  Future<VerifyFixResponse> verifyFix({
    required String defectId,
    required String choice,
    String? rationale,
    required String decider,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async {
    final result = await _client.defectEndpoints.verifyFix(
      defectId: defectId,
      choice: choice,
      rationale: rationale,
      decider: decider,
      signature: signature,
      publicKey: publicKey,
      algorithm: algorithm,
      signedAt: signedAt,
    );
    revision.value++;
    return VerifyFixResponse.fromJson(result.toJson());
  }

  // Human Direction Inbox methods
  Future<List<HumanDirectionSummaryResponse>> listDirectionsByStatus({
    required String status,
    String? directionType,
    String? targetType,
    int? limit,
    int? offset,
  }) async {
    final result = await _client.humanDirectionEndpoints.listDirectionsByStatus(
      status: status,
      directionType: directionType,
      targetType: targetType,
      limit: limit,
      offset: offset,
    );
    return result
        .map(
          (d) => HumanDirectionSummaryResponse.fromJson({
            'directionId': d.directionId,
            'directionType': d.directionType,
            'targetType': d.targetType,
            'targetId': d.targetId,
            'title': d.payload.title,
            'description': d.payload.description,
            'contextJson': d.payload.contextJson,
            'attachments':
                d.payload.attachments
                    ?.map(
                      (a) => {
                        'artifactId': a.artifactId,
                        'artifactType': a.artifactType,
                        'description': a.description,
                      },
                    )
                    .toList() ??
                [],
            'createdBy': d.createdBy,
            'assignedTo': d.assignedTo,
            'status': d.status,
            'createdAt': d.createdAt.toIso8601String(),
            'acknowledgedAt': d.ackedAt?.toIso8601String(),
            'startedAt': d.startedAt?.toIso8601String(),
            'completedAt': d.completedAt?.toIso8601String(),
            'rejectedAt': d.rejectedAt?.toIso8601String(),
            'supersededAt': d.supersededAt?.toIso8601String(),
          }),
        )
        .toList();
  }

  Future<HumanDirectionSummaryResponse> createDirection({
    required String directionType,
    required String targetType,
    String? targetId,
    required String title,
    required String description,
    String? contextJson,
    List<Map<String, dynamic>>? attachments,
    String? createdBy,
    String? assignedTo,
  }) async {
    final result = await _client.humanDirectionEndpoints.createDirection(
      directionType: directionType,
      targetType: targetType,
      targetId: targetId,
      title: title,
      description: description,
      contextJson: contextJson,
      attachments: attachments
          ?.map(
            (a) => HumanDirectionAttachmentView(
              artifactId: a['artifactId'] as String,
              artifactType: a['artifactType'] as String,
              description: a['description'] as String?,
            ),
          )
          .toList(),
      createdBy: createdBy,
      assignedTo: assignedTo,
    );
    return HumanDirectionSummaryResponse.fromJson({
      'directionId': result.directionId,
      'directionType': result.directionType,
      'targetType': result.targetType,
      'targetId': result.targetId,
      'title': result.payload.title,
      'description': result.payload.description,
      'contextJson': result.payload.contextJson,
      'attachments':
          result.payload.attachments
              ?.map(
                (a) => {
                  'artifactId': a.artifactId,
                  'artifactType': a.artifactType,
                  'description': a.description,
                },
              )
              .toList() ??
          [],
      'createdBy': result.createdBy,
      'assignedTo': result.assignedTo,
      'status': result.status,
      'createdAt': result.createdAt.toIso8601String(),
      'acknowledgedAt': result.ackedAt?.toIso8601String(),
      'startedAt': result.startedAt?.toIso8601String(),
      'completedAt': result.completedAt?.toIso8601String(),
      'rejectedAt': result.rejectedAt?.toIso8601String(),
      'supersededAt': result.supersededAt?.toIso8601String(),
    });
  }

  Future<HumanDirectionSummaryResponse> acknowledgeDirection({
    required String directionId,
    required String acknowledgedBy,
  }) async {
    final result = await _client.humanDirectionEndpoints.acknowledgeDirection(
      directionId: directionId,
      acknowledgedBy: acknowledgedBy,
    );
    return HumanDirectionSummaryResponse.fromJson({
      'directionId': result.directionId,
      'directionType': result.directionType,
      'targetType': result.targetType,
      'targetId': result.targetId,
      'title': result.payload.title,
      'description': result.payload.description,
      'contextJson': result.payload.contextJson,
      'attachments':
          result.payload.attachments
              ?.map(
                (a) => {
                  'artifactId': a.artifactId,
                  'artifactType': a.artifactType,
                  'description': a.description,
                },
              )
              .toList() ??
          [],
      'createdBy': result.createdBy,
      'assignedTo': result.assignedTo,
      'status': result.status,
      'createdAt': result.createdAt.toIso8601String(),
      'acknowledgedAt': result.ackedAt?.toIso8601String(),
      'startedAt': result.startedAt?.toIso8601String(),
      'completedAt': result.completedAt?.toIso8601String(),
      'rejectedAt': result.rejectedAt?.toIso8601String(),
      'supersededAt': result.supersededAt?.toIso8601String(),
    });
  }

  Future<HumanDirectionSummaryResponse> startWorkingDirection({
    required String directionId,
    required String startedBy,
  }) async {
    final result = await _client.humanDirectionEndpoints.startWorkingDirection(
      directionId: directionId,
      startedBy: startedBy,
    );
    return HumanDirectionSummaryResponse.fromJson({
      'directionId': result.directionId,
      'directionType': result.directionType,
      'targetType': result.targetType,
      'targetId': result.targetId,
      'title': result.payload.title,
      'description': result.payload.description,
      'contextJson': result.payload.contextJson,
      'attachments':
          result.payload.attachments
              ?.map(
                (a) => {
                  'artifactId': a.artifactId,
                  'artifactType': a.artifactType,
                  'description': a.description,
                },
              )
              .toList() ??
          [],
      'createdBy': result.createdBy,
      'assignedTo': result.assignedTo,
      'status': result.status,
      'createdAt': result.createdAt.toIso8601String(),
      'acknowledgedAt': result.ackedAt?.toIso8601String(),
      'startedAt': result.startedAt?.toIso8601String(),
      'completedAt': result.completedAt?.toIso8601String(),
      'rejectedAt': result.rejectedAt?.toIso8601String(),
      'supersededAt': result.supersededAt?.toIso8601String(),
    });
  }

  Future<HumanDirectionSummaryResponse> completeDirection({
    required String directionId,
    required String completedBy,
    required String completionSummary,
  }) async {
    final result = await _client.humanDirectionEndpoints.completeDirection(
      directionId: directionId,
      completedBy: completedBy,
      completionSummary: completionSummary,
    );
    return HumanDirectionSummaryResponse.fromJson({
      'directionId': result.directionId,
      'directionType': result.directionType,
      'targetType': result.targetType,
      'targetId': result.targetId,
      'title': result.payload.title,
      'description': result.payload.description,
      'contextJson': result.payload.contextJson,
      'attachments':
          result.payload.attachments
              ?.map(
                (a) => {
                  'artifactId': a.artifactId,
                  'artifactType': a.artifactType,
                  'description': a.description,
                },
              )
              .toList() ??
          [],
      'createdBy': result.createdBy,
      'assignedTo': result.assignedTo,
      'status': result.status,
      'createdAt': result.createdAt.toIso8601String(),
      'acknowledgedAt': result.ackedAt?.toIso8601String(),
      'startedAt': result.startedAt?.toIso8601String(),
      'completedAt': result.completedAt?.toIso8601String(),
      'rejectedAt': result.rejectedAt?.toIso8601String(),
      'supersededAt': result.supersededAt?.toIso8601String(),
    });
  }

  Future<HumanDirectionSummaryResponse> rejectDirection({
    required String directionId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    final result = await _client.humanDirectionEndpoints.rejectDirection(
      directionId: directionId,
      rejectedBy: rejectedBy,
      rejectionReason: rejectionReason,
    );
    return HumanDirectionSummaryResponse.fromJson({
      'directionId': result.directionId,
      'directionType': result.directionType,
      'targetType': result.targetType,
      'targetId': result.targetId,
      'title': result.payload.title,
      'description': result.payload.description,
      'contextJson': result.payload.contextJson,
      'attachments':
          result.payload.attachments
              ?.map(
                (a) => {
                  'artifactId': a.artifactId,
                  'artifactType': a.artifactType,
                  'description': a.description,
                },
              )
              .toList() ??
          [],
      'createdBy': result.createdBy,
      'assignedTo': result.assignedTo,
      'status': result.status,
      'createdAt': result.createdAt.toIso8601String(),
      'acknowledgedAt': result.ackedAt?.toIso8601String(),
      'startedAt': result.startedAt?.toIso8601String(),
      'completedAt': result.completedAt?.toIso8601String(),
      'rejectedAt': result.rejectedAt?.toIso8601String(),
      'supersededAt': result.supersededAt?.toIso8601String(),
    });
  }

  Future<HumanDirectionSummaryResponse> supersedeDirection({
    required String directionId,
    required String supersededByDirectionId,
    required String supersededBy,
  }) async {
    final result = await _client.humanDirectionEndpoints.supersedeDirection(
      directionId: directionId,
      supersededByDirectionId: supersededByDirectionId,
      supersededBy: supersededBy,
    );
    return HumanDirectionSummaryResponse.fromJson({
      'directionId': result.directionId,
      'directionType': result.directionType,
      'targetType': result.targetType,
      'targetId': result.targetId,
      'title': result.payload.title,
      'description': result.payload.description,
      'contextJson': result.payload.contextJson,
      'attachments':
          result.payload.attachments
              ?.map(
                (a) => {
                  'artifactId': a.artifactId,
                  'artifactType': a.artifactType,
                  'description': a.description,
                },
              )
              .toList() ??
          [],
      'createdBy': result.createdBy,
      'assignedTo': result.assignedTo,
      'status': result.status,
      'createdAt': result.createdAt.toIso8601String(),
      'acknowledgedAt': result.ackedAt?.toIso8601String(),
      'startedAt': result.startedAt?.toIso8601String(),
      'completedAt': result.completedAt?.toIso8601String(),
      'rejectedAt': result.rejectedAt?.toIso8601String(),
      'supersededAt': result.supersededAt?.toIso8601String(),
    });
  }

  // Product Registry methods
  Future<DecisionResponse> proposeBaseline({
    required String productId,
    required List<Map<String, dynamic>> facts,
  }) async {
    final result = await _client.productRegistryEndpoints.proposeBaseline(
      productId: productId,
      facts: facts.map((f) => BaselineFact.fromJson(f)).toList(),
    );
    revision.value++;
    return _decisionResponse(result);
  }

  Future<DecisionResponse> addHumanBaselineClaim({
    required String productId,
    required String baselineId,
    required String section, // BaselineSectionKey.wire
    required String claim,
    required String author,
    List<String> evidenceRefs = const [],
    String?
    maturity, // BaselineMaturity.wire (e.g. 'implemented', 'policy', 'not_implemented')
  }) async {
    // The generated endpoint returns a ProductDetailView; the caller refetches
    // the detail surface, so the payload is deliberately not bound here. Only
    // the server-side write matters, so the call is awaited without capturing
    // its result.
    //
    // NOTE (lint cleanup, behaviour unchanged): this method fabricates a
    // DecisionView. Its id `baseline-claim:<microsecondsSinceEpoch>` exists
    // nowhere server-side, and `status`/`options` are hardcoded ('pending', [])
    // rather than read from a real decision, so the caller cannot resolve it.
    // The discarded ProductDetailView is no substitute: amending a baseline
    // only cancels unresolved approval decisions, it never opens a fresh gate,
    // and `pendingBaselineDecisionId` is derived from unresolved decisions only,
    // so it is normally null here. The caller must request approval again
    // against the new revision. Returning a real decision would change the
    // returned payload and is a product decision, not a lint fix -- reported,
    // not done here.
    await _client.productRegistryEndpoints.addHumanBaselineClaim(
      productId: productId,
      baselineId: baselineId,
      section: section,
      claim: claim,
      author: author,
      evidenceRefs: evidenceRefs,
      maturity: maturity,
    );
    revision.value++;
    return _decisionResponse(
      DecisionView(
        decisionId: 'baseline-claim:${DateTime.now().microsecondsSinceEpoch}',
        workItemId: 'product-baseline:$productId',
        workItemTitle: 'Baseline claim',
        decisionType: 'product_decision',
        status: 'pending',
        question: 'Operator claim added — request approval for new revision',
        context: null,
        options: [],
        recommendation: null,
        blocking: false,
        requestedAt: DateTime.now(),
        decider: null,
        choice: null,
        rationale: null,
      ),
    );
  }

  Future<DecisionResponse> requestBaselineApproval({
    required String productId,
    required String baselineId,
    String? decisionId,
  }) async {
    final result = await _client.productRegistryEndpoints
        .requestBaselineApproval(
          productId: productId,
          baselineId: baselineId,
          decisionId: decisionId,
        );
    revision.value++;
    return _decisionResponse(result);
  }

  /// Records the operator's resolution of a baseline-approval gate.
  ///
  /// The click is the human act: [decider] and [rationale] come from the
  /// operator, and the signature block is the same attestation the workflow
  /// decision resolver stamps for an in-app resolution. It is recorded for
  /// attribution, not cryptographically verified — see `DecisionSignature`.
  Future<DecisionResponse> resolveBaselineApproval({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    final now = DateTime.now();
    final result = await _client.productRegistryEndpoints
        .resolveBaselineApproval(
          decisionId: decisionId,
          choice: choice,
          decider: decider,
          rationale: rationale,
          algorithm: 'ed25519',
          publicKey: 'operator-pub-key',
          signature: 'operator-sig-${now.millisecondsSinceEpoch}',
          signedAt: now,
        );
    revision.value++;
    return _decisionResponse(result);
  }

  /// Records platform-verified evidence against a proposed baseline.
  ///
  /// `ProductRegistryEngine.verifyBaseline` refuses a baseline that has not
  /// been independently verified, so this must run before approval is
  /// requested.
  Future<void> verifyBaseline({
    required String productId,
    required String baselineId,
    required String verifiedBy,
  }) async {
    await _client.productRegistryEndpoints.verifyBaseline(
      productId: productId,
      baselineId: baselineId,
      verifiedBy: verifiedBy,
      kind: 'platform_verified_evidence',
    );
    revision.value++;
  }

  /// Creates a new product with its manifest.
  Future<ProductDetailResponse> createProduct({
    required String productId,
    required String name,
    String? description,
    required String manifestJson,
    String? manifestVersion,
  }) async {
    final d = await _client.productRegistryEndpoints.createProduct(
      productId: productId,
      name: name,
      description: description,
      manifestJson: manifestJson,
      manifestVersion: manifestVersion,
    );
    revision.value++;
    return ProductDetailResponse(
      productId: d.product.productId,
      name: d.product.name,
      description: d.product.description,
      state: d.product.state,
      allowsDispatch: d.allowsDispatch,
      updatedAt: d.product.updatedAt,
      repositories: d.repositories
          .map(
            (r) => ProductRepositoryResponse(
              repositoryId: r.repositoryId,
              uri: r.uri,
              kind: r.kind,
              provider: r.provider,
            ),
          )
          .toList(),
      credentials: d.credentials
          .map(
            (c) => CredentialResponse(
              credentialId: c.credentialId,
              repositoryId: c.repositoryId,
              referenceName: c.referenceName,
              fingerprint: c.fingerprint,
              algorithm: c.algorithm,
              status: c.status,
              hostKeyStatus: c.hostKeyStatus,
              host: c.host,
              canReachRepository: c.canReachRepository,
              lastVerifiedAt: c.lastVerifiedAt,
              lastVerifiedBy: c.lastVerifiedBy,
              lastFailureReason: c.lastFailureReason,
              hostConfirmedAt: c.hostConfirmedAt,
              hostConfirmedBy: c.hostConfirmedBy,
            ),
          )
          .toList(),
      activeBaselineId: d.activeBaseline?.baselineId,
      activeBaselineRevision: d.activeBaseline?.revision,
      activeBaselineHash: d.activeBaseline?.contentHash,
      activeBaselineAcceptedAt: d.activeBaseline?.acceptedAt,
      activeBaselineAcceptedBy: d.activeBaseline?.acceptedBy,
      activeBaselineFactCount: d.activeBaseline?.facts.length ?? 0,
      pendingBaselineId: d.pendingBaseline?.baselineId,
      pendingBaselineRevision: d.pendingBaseline?.revision,
      pendingBaselineVerified: d.pendingBaselineVerified,
      pendingBaselineFacts: (d.pendingBaseline?.facts ?? const [])
          .map(BaselineFactClaim.fromProtocol)
          .toList(),
      pendingBaselineDecisionId: d.pendingBaselineDecisionId,
      openClarifications: d.openClarifications
          .map(
            (c) => ClarificationSummary(
              clarificationId: c.clarificationId,
              question: c.question,
              section: c.section,
            ),
          )
          .toList(),
      policies: d.policies.map(_policyResponse).toList(),
    );
  }

  /// Adds a repository reference to a product.
  Future<void> addRepositoryReference({
    required String productId,
    required String repositoryId,
    required String uri,
    required String kind,
    required String provider,
  }) async {
    await _client.productRegistryEndpoints.addRepositoryReference(
      productId: productId,
      repositoryId: repositoryId,
      uri: uri,
      kind: kind,
      provider: provider,
    );
    revision.value++;
  }

  // ------------------------------------------------- Credentials · Add Product

  /// Mints a real ed25519 deploy key for one repository, on the server.
  ///
  /// The private half is written straight to the configured secret provider and
  /// is not in the response, so there is nothing for this client to leak: the
  /// endpoint's return type is a generated model whose field list IS the
  /// whitelist (`MintedCredentialView`) and [MintedDeployKey] narrows that
  /// further. See [MintedDeployKey] for why `referenceName` is not among the
  /// fields kept.
  ///
  /// Server-side this **writes the durable credential row** — the product
  /// registry engine's `recordGeneratedCredential`, at status `generated`. The
  /// private half is stored before the row is written, so a returned key always
  /// has somewhere to live.
  ///
  /// [result] is a `MintedCredentialView` rather than a `Map<String, dynamic>`,
  /// so these are field reads that the generated client's deserializer has
  /// already resolved. That matters beyond tidiness: the map form is what threw
  /// `No deserialization found for type dynamic` in the browser, so the reads
  /// below could not be reached at all. See `credential_endpoint_wire_test.dart`
  /// on the server for the wire-boundary proof.
  Future<MintedDeployKey> generateDeployKey({
    required String productId,
    required String repositoryId,
  }) async {
    final result = await _client.credentialEndpoints.generate(
      productId: productId,
      repositoryId: repositoryId,
    );
    revision.value++;
    return MintedDeployKey(
      credentialId: result.credentialId,
      publicKey: result.publicKey,
      fingerprint: result.fingerprint,
      algorithm: result.algorithm,
      status: result.status,
      hostKeyStatus: result.hostKeyStatus,
    );
  }

  /// Proves the minted credential reaches the repository, with a real clone.
  ///
  /// [hostKeyFingerprint] and [confirmedBy] are **operator assertions the server
  /// cannot authenticate** — see `OperatorAttestation`. They are passed through
  /// verbatim and this client adds no meaning to them.
  Future<DeployKeyAccessVerification> verifyDeployKeyAccess({
    required String productId,
    required String repositoryId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    String? checkedBy,
  }) async {
    final result = await _client.credentialEndpoints.verifyAccess(
      productId: productId,
      repositoryId: repositoryId,
      hostKeyFingerprint: hostKeyFingerprint,
      confirmedBy: confirmedBy,
      checkedBy: checkedBy,
    );
    revision.value++;
    return DeployKeyAccessVerification(
      credentialId: result.credentialId,
      status: result.status,
      canReachRepository: result.canReachRepository,
      secretMaterialRemoved: result.secretMaterialRemoved,
      hostKeyConfirmationProvenance: result.hostKeyConfirmationProvenance,
      failureReason: result.failureReason,
    );
  }

  ArtifactRefResponse _artifactRefResponse(ArtifactReferenceView a) {
    return ArtifactRefResponse(
      artifactId: a.artifactId,
      artifactType: a.artifactType,
      uri: a.uri,
      provider: a.provider,
      contentHash: a.contentHash,
      description: a.description,
      createdAt: a.createdAt,
    );
  }

  // Model Policy methods
  Future<List<ModelPolicyResponse>> listModelPolicies() async {
    final result = await _client.providerHealthEndpoints.listModelPolicies();
    return result.policies
        .map((p) => ModelPolicyResponse.fromJson(p.toJson()))
        .toList();
  }

  Future<ProviderHealthResponse> getProviderHealth() async {
    final result = await _client.providerHealthEndpoints.getProviderHealth();
    return ProviderHealthResponse.fromJson(result.toJson());
  }

  Future<ModelPolicyResponse> updateModelPolicy({
    required String role,
    required List<ModelStepRequest> chain,
    required int version,
    required String updatedByDecisionId,
  }) async {
    final result = await _client.providerHealthEndpoints.updateModelPolicy(
      role: role,
      chainJson: jsonEncode(chain.map((s) => s.toJson()).toList()),
      version: version,
      updatedByDecisionId: updatedByDecisionId,
    );
    revision.value++;
    return ModelPolicyResponse.fromJson(result.toJson());
  }

  // Model Executions methods
  Future<ModelExecutionsPageResponse> listModelExecutions({
    String? workItemId,
    String? provider,
    String? modelId,
    String? taskType,
    bool? success,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _client.providerHealthEndpoints.listModelExecutions(
      workItemId: workItemId,
      provider: provider,
      modelId: modelId,
      from: from,
      to: to,
      limit: limit,
      offset: offset,
    );
    return ModelExecutionsPageResponse.fromJson(result.toJson());
  }

  // Model Stats methods
  Future<ModelStatsResponse> getModelStats({
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) async {
    final result = await _client.providerHealthEndpoints.getModelStats(
      from: from,
      to: to,
      groupBy: groupBy,
    );
    return ModelStatsResponse.fromJson(result.toJson());
  }
}

class OverviewResponse {
  OverviewResponse({
    required this.running,
    required this.waitingOnYou,
    required this.recentlyFinished,
    this.finishedPassed = 0,
    this.finishedFailed = 0,
    this.generatedAt,
    this.jobs = const [],
    this.machinesBusy = 0,
    this.machinesTotal = 0,
  });

  final int running;
  final int waitingOnYou;
  final int recentlyFinished;

  /// Successful terminal states inside [recentlyFinished].
  final int finishedPassed;

  /// Cancelled/terminated states inside [recentlyFinished].
  final int finishedFailed;

  /// Server clock when the snapshot was assembled. The freshness stamp is
  /// measured against this, not against the browser clock.
  final DateTime? generatedAt;

  /// Queued/running jobs for the "Machines and next steps" strip.
  final List<JobSummaryResponse> jobs;

  final int machinesBusy;
  final int machinesTotal;
}

class JobSummaryResponse {
  JobSummaryResponse({
    required this.jobId,
    required this.workItemId,
    required this.state,
    required this.jobType,
    required this.createdAt,
    this.availableAt,
    required this.blockedOnDecision,
    required this.attempt,
    required this.maxAttempts,
  });

  final String jobId;
  final String workItemId;

  /// Durable `JobState` name. Shown verbatim only in technical details.
  final String state;
  final String jobType;
  final DateTime createdAt;
  final DateTime? availableAt;

  /// True when a pending human decision is what holds this job up.
  final bool blockedOnDecision;
  final int attempt;
  final int maxAttempts;
}

class ArtifactRefResponse {
  ArtifactRefResponse({
    required this.artifactId,
    required this.artifactType,
    required this.uri,
    this.provider,
    this.contentHash,
    this.description,
    this.createdAt,
  });

  final String artifactId;
  final String artifactType;
  final String uri;
  final String? provider;
  final String? contentHash;
  final String? description;
  final DateTime? createdAt;

  factory ArtifactRefResponse.fromJson(Map<String, dynamic> json) {
    return ArtifactRefResponse(
      artifactId: json['artifactId'] as String,
      artifactType: json['artifactType'] as String,
      uri: json['uri'] as String,
      provider: json['provider'] as String?,
      contentHash: json['contentHash'] as String?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}

class WorkItemResponse {
  WorkItemResponse({
    required this.workItemId,
    required this.title,
    this.description,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.blockingHumanDecisionId,
    this.artifactRefs,
  });

  final String workItemId;
  final String title;
  final String? description;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? blockingHumanDecisionId;
  final List<ArtifactRefResponse>? artifactRefs;
}

class DecisionResponse {
  DecisionResponse({
    required this.decisionId,
    required this.workItemId,
    required this.workItemTitle,
    this.workItemDescription,
    required this.decisionType,
    required this.status,
    this.question,
    this.context,
    this.options,
    this.recommendation,
    required this.blocking,
    this.requestedAt,
    this.expiration,
    this.artifactRefs,
    this.choice,
    this.decider,
    this.rationale,
    this.resolvedAt,
    this.signature,
  });

  final String decisionId;
  final String workItemId;
  final String workItemTitle;

  /// Plain-language description of the gated work item, when recorded.
  final String? workItemDescription;
  final String decisionType;
  final String status;
  final String? question;
  final DecisionContext? context;
  final List<DecisionOption>? options;
  final String? recommendation;
  final bool blocking;
  final DateTime? requestedAt;
  final DateTime? expiration;
  final List<ArtifactRefResponse>? artifactRefs;
  final String? choice;
  final String? decider;
  final String? rationale;
  final DateTime? resolvedAt;
  final String? signature;
}

class DecisionContext {
  DecisionContext({
    required this.workflowState,
    required this.availableOptions,
  });

  final String workflowState;
  final List<String> availableOptions;
}

class DecisionOption {
  DecisionOption({
    required this.optionId,
    required this.label,
    this.description,
    required this.recommended,
  });

  final String optionId;
  final String label;
  final String? description;
  final bool recommended;
}

class WorkItemDetailResponse {
  WorkItemDetailResponse({
    required this.workItem,
    required this.transitionHistory,
  });

  final WorkItemResponse workItem;
  final List<TransitionResponse> transitionHistory;
}

class TransitionResponse {
  TransitionResponse({
    required this.transitionId,
    required this.workItemId,
    required this.fromState,
    required this.toState,
    required this.transitionedAt,
    this.reason,
  });

  final String transitionId;
  final String workItemId;
  final String fromState;
  final String toState;
  final DateTime transitionedAt;
  final String? reason;
}

class DecisionDetailResponse {
  DecisionDetailResponse({
    required this.decisionId,
    required this.workItemId,
    this.workItemTitle,
    this.workItemDescription,
    required this.decisionType,
    required this.status,
    this.question,
    this.context,
    this.options,
    this.recommendation,
    this.artifactRefs,
    required this.blocking,
    this.requestedAt,
    this.expiration,
    this.choice,
    this.decider,
    this.rationale,
    this.resolvedAt,
    this.signature,
  });

  final String decisionId;
  final String workItemId;

  /// Title of the gated work item, so the decision screen can name what is
  /// being decided rather than printing an id.
  final String? workItemTitle;

  /// Plain-language description of the gated work item, when recorded.
  final String? workItemDescription;
  final String decisionType;
  final String status;
  final String? question;
  final DecisionContext? context;
  final List<DecisionOption>? options;
  final String? recommendation;

  /// What the operator is being asked to approve.
  final List<ArtifactRefResponse>? artifactRefs;
  final bool blocking;
  final DateTime? requestedAt;
  final DateTime? expiration;
  final String? choice;
  final String? decider;
  final String? rationale;
  final DateTime? resolvedAt;
  final String? signature;
}

/// One claim a pending baseline makes about its product.
///
/// [maturity] is part of the approved content hash, so a reviewer can tell an
/// implemented fact from an assumed one rather than reading every claim as
/// equally established.
class BaselineFactClaim {
  const BaselineFactClaim({
    required this.factId,
    required this.section,
    required this.claim,
    required this.provenance,
    required this.maturity,
    required this.evidenceRefs,
    this.assumptionNote,
    this.redacted = false,
  });

  factory BaselineFactClaim.fromProtocol(BaselineFactView v) =>
      BaselineFactClaim(
        factId: v.factId,
        section: v.section,
        claim: v.claim,
        provenance: v.provenance,
        maturity: v.maturity,
        evidenceRefs: v.evidenceRefs,
        assumptionNote: v.assumptionNote,
        redacted: v.redacted,
      );

  final String factId;

  /// One of the fixed baseline sections: repository, tech_stack, architecture,
  /// design, qa, ci_cd, environments, data, deployment, governance, known_gaps.
  final String section;
  final String claim;

  /// observed | human_provided | derived | assumed | unknown
  final String provenance;

  /// asserted | implemented | policy | not_implemented | unknown
  final String maturity;

  final List<String> evidenceRefs;
  final String? assumptionNote;
  final bool redacted;
}

/// One row of the Products screen, read straight from durable registry state.
class ProductSummaryResponse {
  const ProductSummaryResponse({
    required this.productId,
    required this.name,
    required this.state,
    required this.allowsDispatch,
    this.activeBaselineId,
    this.activeBaselineRevision,
    this.pendingBaselineId,
    this.pendingBaselineRevision,
    required this.pendingBaselineVerified,
    required this.baselineFactCount,
    required this.openClarifications,
    required this.repositoryCount,
    required this.reachableRepositoryCount,
    required this.updatedAt,
  });

  final String productId;
  final String name;

  /// `ProductState` wire value.
  final String state;

  /// True only for `governed`. Mirrors `ProductState.allowsDispatch`.
  final bool allowsDispatch;

  /// The accepted baseline. A product without one is not governed.
  final String? activeBaselineId;
  final int? activeBaselineRevision;

  /// The candidate awaiting a human, when in `baseline_review`.
  final String? pendingBaselineId;
  final int? pendingBaselineRevision;

  /// Whether a worker attested to the pending candidate (AGENTS.md §12). The
  /// approval gate refuses to open without it.
  final bool pendingBaselineVerified;

  /// Count of recorded baseline *claims*, not files — the registry does not
  /// track file counts.
  final int baselineFactCount;

  final int openClarifications;
  final int repositoryCount;

  /// Repositories whose credential is both host-confirmed and verified.
  final int reachableRepositoryCount;

  final DateTime updatedAt;
}

/// Everything the Product Detail screen reads.
class ProductDetailResponse {
  const ProductDetailResponse({
    required this.productId,
    required this.name,
    this.description,
    required this.state,
    required this.allowsDispatch,
    required this.updatedAt,
    required this.repositories,
    required this.credentials,
    this.activeBaselineId,
    this.activeBaselineRevision,
    this.activeBaselineHash,
    this.activeBaselineAcceptedAt,
    this.activeBaselineAcceptedBy,
    required this.activeBaselineFactCount,
    this.pendingBaselineId,
    this.pendingBaselineRevision,
    required this.pendingBaselineVerified,
    this.pendingBaselineFacts = const [],
    required this.openClarifications,
    required this.policies,
    this.pendingBaselineDecisionId,
  });

  final String productId;
  final String name;
  final String? description;
  final String state;
  final bool allowsDispatch;
  final DateTime updatedAt;
  final List<ProductRepositoryResponse> repositories;
  final List<CredentialResponse> credentials;
  final String? activeBaselineId;
  final int? activeBaselineRevision;
  final String? activeBaselineHash;
  final DateTime? activeBaselineAcceptedAt;
  final String? activeBaselineAcceptedBy;

  /// Recorded baseline claims, not files.
  final int activeBaselineFactCount;

  /// The claims the pending candidate actually asserts.
  ///
  /// The approval gate must show these. A count alone lets an empty baseline
  /// look identical to a well-evidenced one, which is how a candidate that
  /// asserts nothing reaches a human reviewer looking like a real proposal.
  final List<BaselineFactClaim> pendingBaselineFacts;
  final String? pendingBaselineId;
  final int? pendingBaselineRevision;
  final bool pendingBaselineVerified;

  /// Decision id of the unresolved baseline-approval gate, when one exists.
  /// Baseline decisions are scoped to `product-baseline:<productId>` rather
  /// than a WorkItem row, so this cannot be discovered by listing a work item's
  /// decisions — the screen needs it to submit a resolution.
  final String? pendingBaselineDecisionId;

  final List<ClarificationSummary> openClarifications;

  /// Active first, then revoked. Revoked policies are retained, not deleted.
  final List<PolicyResponse> policies;
}

class ProductRepositoryResponse {
  const ProductRepositoryResponse({
    required this.repositoryId,
    required this.uri,
    required this.kind,
    required this.provider,
  });

  final String repositoryId;
  final String uri;
  final String kind;
  final String provider;
}

/// A repository credential. Never carries key material.
class CredentialResponse {
  const CredentialResponse({
    required this.credentialId,
    required this.repositoryId,
    required this.referenceName,
    required this.fingerprint,
    required this.algorithm,
    required this.status,
    required this.hostKeyStatus,
    this.host,
    required this.canReachRepository,
    this.lastVerifiedAt,
    this.lastVerifiedBy,
    this.lastFailureReason,
    this.hostConfirmedAt,
    this.hostConfirmedBy,
  });

  final String credentialId;
  final String repositoryId;

  /// Name of the local secret-store entry. Never the value.
  final String referenceName;
  final String fingerprint;
  final String algorithm;
  final String status;
  final String hostKeyStatus;
  final String? host;

  /// Requires both a confirmed host and a proven connection.
  final bool canReachRepository;

  final DateTime? lastVerifiedAt;
  final String? lastVerifiedBy;
  final String? lastFailureReason;
  final DateTime? hostConfirmedAt;
  final String? hostConfirmedBy;
}

/// What the server minted for one repository. Every field here is public.
///
/// The shape is the leak policy. The endpoint returns a generated model whose
/// field list is the whitelist (`MintedCredentialView`) and this class narrows
/// it to the six fields the Add Product flow actually shows or keys off, so a
/// field added to the wire projection later cannot reach the UI by accident.
///
/// **`referenceName` is deliberately absent.** The server returns it and it is
/// still returned — removing that is decision `9417f8bf` gap **G-7**, which
/// records that the secret-manager reference is itself the sensitive artifact
/// under ADR 0018 §A3 and should not be exposed to a client. G-7 is open and
/// this lane does not decide it. What this lane does is not *add* a client-side
/// use of it: this class never reads the key, so the Add Product flow neither
/// displays it nor stores it. `CredentialResponse` above still carries it,
/// because the product detail screen already read it before this lane existed;
/// that pre-existing use is left exactly where it was.
class MintedDeployKey {
  const MintedDeployKey({
    required this.credentialId,
    required this.publicKey,
    required this.fingerprint,
    required this.algorithm,
    required this.status,
    required this.hostKeyStatus,
  });

  /// Durable identity of the credential row the server wrote.
  final String credentialId;

  /// The `ssh-ed25519 AAAA… shipit+<repositoryId>` line the operator installs
  /// as a deploy key.
  final String publicKey;

  /// `SHA256:…` of the public blob.
  final String fingerprint;

  final String algorithm;

  /// `CredentialStatus` wire value. Always `generated` at mint — never
  /// `verified`; access is not proved until [verifyDeployKeyAccess] runs.
  final String status;

  /// `unknown` at mint: a new credential cannot reach anything until a human
  /// confirms the host key.
  final String hostKeyStatus;
}

/// What a real clone concluded.
///
/// [isVerified] is the single value the Add Product state machine keys its
/// Register button off, and it is deliberately conjunctive: `canReachRepository`
/// alone would not say whether the credential is *currently* verified, and
/// `status` alone would be a string comparison a caller could get backwards.
class DeployKeyAccessVerification {
  const DeployKeyAccessVerification({
    required this.credentialId,
    required this.status,
    required this.canReachRepository,
    required this.secretMaterialRemoved,
    required this.hostKeyConfirmationProvenance,
    this.failureReason,
  });

  final String credentialId;

  /// `CredentialStatus` wire value — `verified`, `failing`, or unchanged
  /// (`generated`) when the check never completed.
  final String status;

  /// A confirmed host AND a proven connection.
  final bool canReachRepository;

  /// Whether the private half was destroyed with the clone's scratch tree.
  ///
  /// The server does not mark a credential verified when this is false — the
  /// connection worked, but a private identity file is still on disk — and this
  /// client inherits that: [isVerified] does not consult it separately because
  /// `status` is already `failing` in that case.
  final bool secretMaterialRemoved;

  /// Always a sentence saying the fingerprint was caller-supplied and is not
  /// authenticated by the server. Present so no consumer of this object can
  /// mistake the verification for proof of host identity.
  final String? hostKeyConfirmationProvenance;

  /// Why the clone failed. Documented server-side as safe to show an operator:
  /// git/ssh's own diagnostic with the scratch path replaced and truncated.
  final String? failureReason;

  /// The one predicate the UI keys off.
  ///
  /// `status == 'verified'` is the load-bearing half — it is what
  /// `recordCredentialCheck` writes only when a clone actually succeeded. The
  /// `canReachRepository` half is carried because a response claiming
  /// `verified` while reporting no reachability is inconsistent, and a client
  /// that ignores that would light a button on a contradictory record.
  bool get isVerified => status == 'verified' && canReachRepository;
}

class ClarificationSummary {
  const ClarificationSummary({
    required this.clarificationId,
    required this.question,
    required this.section,
  });

  final String clarificationId;
  final String question;
  final String section;
}

class PolicyResponse {
  const PolicyResponse({
    required this.policyId,
    required this.actions,
    required this.authorisingDecisionId,
    required this.authorisedBy,
    required this.rationale,
    required this.authorisedAt,
    required this.isRevoked,
    this.revokedBy,
    this.revocationReason,
  });

  final String policyId;
  final List<String> actions;

  /// The gated decision that created this policy — the citation.
  final String authorisingDecisionId;
  final String authorisedBy;
  final String rationale;
  final DateTime authorisedAt;
  final bool isRevoked;
  final String? revokedBy;
  final String? revocationReason;
}

class HumanDirectionSummaryResponse {
  HumanDirectionSummaryResponse({
    required this.directionId,
    required this.directionType,
    required this.targetType,
    this.targetId,
    required this.title,
    required this.description,
    this.contextJson,
    this.attachments = const [],
    this.createdBy,
    this.assignedTo,
    required this.status,
    required this.createdAt,
    this.acknowledgedAt,
    this.startedAt,
    this.completedAt,
    this.rejectedAt,
    this.supersededAt,
  });

  final String directionId;
  final String directionType;
  final String targetType;
  final String? targetId;
  final String title;
  final String description;
  final String? contextJson;
  final List<Map<String, dynamic>> attachments;
  final String? createdBy;
  final String? assignedTo;
  final String status;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? rejectedAt;
  final DateTime? supersededAt;

  factory HumanDirectionSummaryResponse.fromJson(Map<String, dynamic> json) {
    return HumanDirectionSummaryResponse(
      directionId: json['directionId'] as String,
      directionType: json['directionType'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      contextJson: json['contextJson'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((a) => a as Map<String, dynamic>)
              .toList() ??
          const [],
      createdBy: json['createdBy'] as String?,
      assignedTo: json['assignedTo'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.parse(json['acknowledgedAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.parse(json['rejectedAt'] as String)
          : null,
      supersededAt: json['supersededAt'] != null
          ? DateTime.parse(json['supersededAt'] as String)
          : null,
    );
  }
}

class DefectSummaryResponse {
  DefectSummaryResponse({
    required this.defectId,
    required this.title,
    required this.severity,
    required this.status,
    this.classification,
    required this.reporter,
    this.productId,
    this.productName,
    required this.createdAt,
    required this.updatedAt,
    this.affectedWorkItemId,
    this.affectedRunId,
    this.remediationWorkItemId,
  });

  final String defectId;
  final String title;
  final String severity;
  final String status;
  final String? classification;
  final String reporter;

  /// The product chosen when the defect was reported, when one was.
  final String? productId;
  final String? productName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? affectedWorkItemId;
  final String? affectedRunId;
  final String? remediationWorkItemId;

  factory DefectSummaryResponse.fromJson(Map<String, dynamic> json) {
    return DefectSummaryResponse(
      defectId: json['defectId'] as String,
      title: json['title'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      classification: json['classification'] as String?,
      reporter: json['reporter'] as String,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      affectedWorkItemId: json['affectedWorkItemId'] as String?,
      affectedRunId: json['affectedRunId'] as String?,
      remediationWorkItemId: json['remediationWorkItemId'] as String?,
    );
  }
}

class DefectEvidenceResponse {
  DefectEvidenceResponse({
    required this.evidenceId,
    required this.defectId,
    required this.kind,
    this.artifactId,
    this.contentHash,
    this.description,
    this.sourceRef,
    required this.capturedAt,
    required this.createdAt,
  });

  final String evidenceId;
  final String defectId;
  final String kind;
  final String? artifactId;
  final String? contentHash;
  final String? description;
  final String? sourceRef;
  final DateTime capturedAt;
  final DateTime createdAt;

  factory DefectEvidenceResponse.fromJson(Map<String, dynamic> json) {
    return DefectEvidenceResponse(
      evidenceId: json['evidenceId'] as String,
      defectId: json['defectId'] as String,
      kind: json['kind'] as String,
      artifactId: json['artifactId'] as String?,
      contentHash: json['contentHash'] as String?,
      description: json['description'] as String?,
      sourceRef: json['sourceRef'] as String?,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DefectClarificationResponse {
  DefectClarificationResponse({
    required this.clarificationId,
    required this.defectId,
    required this.question,
    required this.reason,
    required this.status,
    this.answer,
    this.humanDecisionId,
    this.requestedByTriageJobId,
    required this.requestedAt,
    this.answeredAt,
    required this.createdAt,
  });

  final String clarificationId;
  final String defectId;
  final String question;
  final String reason;
  final String status;
  final String? answer;
  final String? humanDecisionId;
  final String? requestedByTriageJobId;
  final DateTime requestedAt;
  final DateTime? answeredAt;
  final DateTime createdAt;

  factory DefectClarificationResponse.fromJson(Map<String, dynamic> json) {
    return DefectClarificationResponse(
      clarificationId: json['clarificationId'] as String,
      defectId: json['defectId'] as String,
      question: json['question'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      answer: json['answer'] as String?,
      humanDecisionId: json['humanDecisionId'] as String?,
      requestedByTriageJobId: json['requestedByTriageJobId'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      answeredAt: json['answeredAt'] != null
          ? DateTime.parse(json['answeredAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DefectEventResponse {
  DefectEventResponse({
    required this.eventId,
    required this.defectId,
    required this.sequence,
    required this.type,
    this.fromStatus,
    this.toStatus,
    required this.actorType,
    required this.actorId,
    this.payloadJson,
    required this.occurredAt,
  });

  final String eventId;
  final String defectId;
  final int sequence;
  final String type;
  final String? fromStatus;
  final String? toStatus;
  final String actorType;
  final String actorId;
  final String? payloadJson;
  final DateTime occurredAt;

  factory DefectEventResponse.fromJson(Map<String, dynamic> json) {
    return DefectEventResponse(
      eventId: json['eventId'] as String,
      defectId: json['defectId'] as String,
      sequence: json['sequence'] as int,
      type: json['type'] as String,
      fromStatus: json['fromStatus'] as String?,
      toStatus: json['toStatus'] as String?,
      actorType: json['actorType'] as String,
      actorId: json['actorId'] as String,
      payloadJson: json['payloadJson'] as String?,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }
}

class TriageResultResponse {
  TriageResultResponse({
    required this.triageResultId,
    required this.defectId,
    required this.triageJobId,
    this.classification,
    this.confidence,
    this.rationale,
    this.recommendedAction,
    this.needsClarification,
    this.clarificationQuestion,
    this.clarificationReason,
    required this.createdAt,
  });

  final String triageResultId;
  final String defectId;
  final String triageJobId;
  final String? classification;
  final double? confidence;
  final String? rationale;
  final String? recommendedAction;
  final bool? needsClarification;
  final String? clarificationQuestion;
  final String? clarificationReason;
  final DateTime createdAt;

  factory TriageResultResponse.fromJson(Map<String, dynamic> json) {
    return TriageResultResponse(
      triageResultId: json['triageResultId'] as String,
      defectId: json['defectId'] as String,
      triageJobId: json['triageJobId'] as String,
      classification: json['classification'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      rationale: json['rationale'] as String?,
      recommendedAction: json['recommendedAction'] as String?,
      needsClarification: json['needsClarification'] as bool?,
      clarificationQuestion: json['clarificationQuestion'] as String?,
      clarificationReason: json['clarificationReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class RemediationWorkItemResponse {
  RemediationWorkItemResponse({
    required this.workItemId,
    required this.title,
    this.description,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.blockingHumanDecisionId,
    this.artifactRefs = const [],
  });

  final String workItemId;
  final String title;
  final String? description;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? blockingHumanDecisionId;
  final List<ArtifactRefResponse> artifactRefs;

  factory RemediationWorkItemResponse.fromJson(Map<String, dynamic> json) {
    return RemediationWorkItemResponse(
      workItemId: json['workItemId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      state: json['state'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      blockingHumanDecisionId: json['blockingHumanDecisionId'] as String?,
      artifactRefs:
          (json['artifactRefs'] as List<dynamic>?)
              ?.map(
                (a) => ArtifactRefResponse.fromJson(a as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class CreateDefectResponse {
  CreateDefectResponse({required this.defectId});

  final String defectId;

  factory CreateDefectResponse.fromJson(Map<String, dynamic> json) {
    return CreateDefectResponse(defectId: json['defectId'] as String);
  }
}

class ListDefectsResponse {
  ListDefectsResponse({required this.defects, required this.totalCount});

  final List<DefectSummaryResponse> defects;
  final int totalCount;

  factory ListDefectsResponse.fromJson(Map<String, dynamic> json) {
    return ListDefectsResponse(
      defects:
          (json['defects'] as List<dynamic>?)
              ?.map(
                (d) =>
                    DefectSummaryResponse.fromJson(d as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      totalCount: json['totalCount'] as int,
    );
  }
}

class InspectDefectResponse {
  InspectDefectResponse({
    required this.defect,
    required this.evidence,
    required this.clarifications,
    required this.events,
    this.triageResult,
    this.remediationWorkItem,
  });

  final DefectSummaryResponse defect;
  final List<DefectEvidenceResponse> evidence;
  final List<DefectClarificationResponse> clarifications;
  final List<DefectEventResponse> events;
  final TriageResultResponse? triageResult;
  final RemediationWorkItemResponse? remediationWorkItem;

  factory InspectDefectResponse.fromJson(Map<String, dynamic> json) {
    return InspectDefectResponse(
      defect: DefectSummaryResponse.fromJson(
        json['defect'] as Map<String, dynamic>,
      ),
      evidence:
          (json['evidence'] as List<dynamic>?)
              ?.map(
                (e) =>
                    DefectEvidenceResponse.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      clarifications:
          (json['clarifications'] as List<dynamic>?)
              ?.map(
                (c) => DefectClarificationResponse.fromJson(
                  c as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      events:
          (json['events'] as List<dynamic>?)
              ?.map(
                (e) => DefectEventResponse.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      triageResult: json['triageResult'] != null
          ? TriageResultResponse.fromJson(
              json['triageResult'] as Map<String, dynamic>,
            )
          : null,
      remediationWorkItem: json['remediationWorkItem'] != null
          ? RemediationWorkItemResponse.fromJson(
              json['remediationWorkItem'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class AddDefectEvidenceResponse {
  AddDefectEvidenceResponse({required this.evidence});

  final DefectEvidenceResponse evidence;

  factory AddDefectEvidenceResponse.fromJson(Map<String, dynamic> json) {
    return AddDefectEvidenceResponse(
      evidence: DefectEvidenceResponse.fromJson(json),
    );
  }
}

class VerifyFixResponse {
  VerifyFixResponse({
    required this.success,
    required this.newStatus,
    required this.message,
  });

  final bool success;
  final String newStatus;
  final String message;

  factory VerifyFixResponse.fromJson(Map<String, dynamic> json) {
    return VerifyFixResponse(
      success: json['success'] as bool,
      newStatus: json['newStatus'] as String,
      message: json['message'] as String,
    );
  }
}

/// One row of the Reports screen's `Feature requests` tab.
///
/// A feature request is a `WorkItem(category: feature)`, so there is no
/// separate register behind this: [workItemId] is the durable work item, and
/// [state] is its `WorkflowState`. [productName] and [reporter] are resolved
/// server-side from the records written alongside the request.
class FeatureRequestSummaryResponse {
  const FeatureRequestSummaryResponse({
    required this.workItemId,
    required this.title,
    this.description,
    required this.state,
    required this.productId,
    this.productName,
    this.reporter,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String workItemId;
  final String title;

  /// The reporter's own words: what they want and why.
  final String? description;

  /// `WorkflowState` wire value. Stays `draft` until a human decides.
  final String state;

  final String productId;

  /// Absent when no registry row resolves. The screen owns the fallback copy
  /// for an unresolved product; the server never invents a label.
  final String? productName;

  final String? reporter;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
}

/// The durable record a successful [ControlPlaneRepository.createFeatureRequest]
/// wrote. The returned id is the work item, so the screen can link straight to
/// it rather than to a report-only row that no other surface can resolve.
class CreateFeatureRequestResponse {
  const CreateFeatureRequestResponse({
    required this.workItemId,
    required this.title,
    required this.state,
    required this.createdAt,
  });

  final String workItemId;
  final String title;
  final String state;
  final DateTime createdAt;
}

class ModelPolicyResponse {
  const ModelPolicyResponse({
    required this.role,
    required this.chain,
    required this.version,
    required this.updatedAt,
    required this.updatedByDecisionId,
    this.isActive = false,
  });

  final String role;
  final List<ModelStepResponse> chain;
  final int version;
  final DateTime updatedAt;
  final String updatedByDecisionId;
  final bool isActive;

  factory ModelPolicyResponse.fromJson(Map<String, dynamic> json) {
    return ModelPolicyResponse(
      role: json['role'] as String,
      chain:
          (json['chain'] as List<dynamic>?)
              ?.map(
                (s) => ModelStepResponse.fromJson(s as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      version: (json['version'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      updatedByDecisionId: json['updatedByDecisionId'] as String,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class ModelStepResponse {
  const ModelStepResponse({required this.modelId, required this.provider});

  final String modelId;
  final String provider;

  factory ModelStepResponse.fromJson(Map<String, dynamic> json) {
    return ModelStepResponse(
      modelId: json['modelId'] as String,
      provider: json['provider'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'modelId': modelId, 'provider': provider};
}

class ModelStepRequest {
  const ModelStepRequest({required this.modelId, required this.provider});

  final String modelId;
  final String provider;

  Map<String, dynamic> toJson() => {'modelId': modelId, 'provider': provider};
}

class ProviderHealthResponse {
  const ProviderHealthResponse({
    required this.providers,
    this.knownModels = const [],
  });

  final List<ProviderStatusResponse> providers;
  final List<KnownModelResponse> knownModels;

  factory ProviderHealthResponse.fromJson(Map<String, dynamic> json) {
    return ProviderHealthResponse(
      providers:
          (json['providers'] as List<dynamic>?)
              ?.map(
                (p) =>
                    ProviderStatusResponse.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      knownModels:
          (json['knownModels'] as List<dynamic>?)
              ?.map(
                (m) => KnownModelResponse.fromJson(m as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class ProviderStatusResponse {
  const ProviderStatusResponse({
    required this.provider,
    required this.status,
    this.lastChecked,
    this.error,
  });

  final String provider;
  final String status;
  final DateTime? lastChecked;
  final String? error;

  factory ProviderStatusResponse.fromJson(Map<String, dynamic> json) {
    return ProviderStatusResponse(
      provider: json['provider'] as String,
      status: json['status'] as String,
      lastChecked: json['lastChecked'] != null
          ? DateTime.parse(json['lastChecked'] as String)
          : null,
      error: json['error'] as String?,
    );
  }
}

class KnownModelResponse {
  const KnownModelResponse({
    required this.modelId,
    required this.provider,
    this.displayName,
  });

  final String modelId;
  final String provider;
  final String? displayName;

  factory KnownModelResponse.fromJson(Map<String, dynamic> json) {
    return KnownModelResponse(
      modelId: json['modelId'] as String,
      provider: json['provider'] as String,
      displayName: json['displayName'] as String?,
    );
  }
}

class ModelExecutionsPageResponse {
  const ModelExecutionsPageResponse({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  final List<ModelExecutionRecordResponse> items;
  final int totalCount;
  final int limit;
  final int offset;

  factory ModelExecutionsPageResponse.fromJson(Map<String, dynamic> json) {
    return ModelExecutionsPageResponse(
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => ModelExecutionRecordResponse.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class ModelExecutionRecordResponse {
  const ModelExecutionRecordResponse({
    required this.workItemId,
    required this.jobId,
    required this.agentExecutionId,
    required this.role,
    required this.modelId,
    required this.provider,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.cachedReadTokens,
    required this.costUsd,
    required this.currency,
    required this.startedAt,
    required this.finishedAt,
    required this.success,
    this.error,
    required this.escalationIndex,
    required this.taskType,
  });

  final String workItemId;
  final String jobId;
  final String agentExecutionId;
  final String role;
  final String modelId;
  final String provider;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int cachedReadTokens;
  final double costUsd;
  final String currency;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool success;
  final String? error;
  final int escalationIndex;
  final String taskType;

  factory ModelExecutionRecordResponse.fromJson(Map<String, dynamic> json) {
    return ModelExecutionRecordResponse(
      workItemId: json['workItemId'] as String,
      jobId: json['jobId'] as String,
      agentExecutionId: json['agentExecutionId'] as String,
      role: json['role'] as String,
      modelId: json['modelId'] as String,
      provider: json['provider'] as String,
      inputTokens: (json['inputTokens'] as num).toInt(),
      outputTokens: (json['outputTokens'] as num).toInt(),
      totalTokens: (json['totalTokens'] as num).toInt(),
      cachedReadTokens: (json['cachedReadTokens'] as num).toInt(),
      costUsd: (json['costUsd'] as num).toDouble(),
      currency: json['currency'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: DateTime.parse(json['finishedAt'] as String),
      success: json['success'] as bool,
      error: json['error'] as String?,
      escalationIndex: (json['escalationIndex'] as num).toInt(),
      taskType: json['taskType'] as String,
    );
  }
}

class ModelStatsResponse {
  const ModelStatsResponse({
    required this.totalCostUsd,
    required this.totalTokens,
    required this.totalExecutions,
    required this.successRate,
    required this.costOverTime,
    required this.tokensByProvider,
    required this.successRateByModel,
    required this.escalationFrequency,
    required this.costByTaskType,
  });

  final double totalCostUsd;
  final int totalTokens;
  final int totalExecutions;
  final double successRate;
  final List<TimeSeriesPointResponse> costOverTime;
  final List<GroupedStatResponse> tokensByProvider;
  final List<GroupedStatResponse> successRateByModel;
  final List<EscalationStatResponse> escalationFrequency;
  final List<GroupedStatResponse> costByTaskType;

  factory ModelStatsResponse.fromJson(Map<String, dynamic> json) {
    return ModelStatsResponse(
      totalCostUsd: (json['totalCostUsd'] as num?)?.toDouble() ?? 0.0,
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      totalExecutions: (json['totalExecutions'] as num?)?.toInt() ?? 0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 0.0,
      costOverTime:
          (json['costOverTime'] as List<dynamic>?)
              ?.map(
                (p) =>
                    TimeSeriesPointResponse.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      tokensByProvider:
          (json['tokensByProvider'] as List<dynamic>?)
              ?.map(
                (p) => GroupedStatResponse.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      successRateByModel:
          (json['successRateByModel'] as List<dynamic>?)
              ?.map(
                (p) => GroupedStatResponse.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      escalationFrequency:
          (json['escalationFrequency'] as List<dynamic>?)
              ?.map(
                (p) =>
                    EscalationStatResponse.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      costByTaskType:
          (json['costByTaskType'] as List<dynamic>?)
              ?.map(
                (p) => GroupedStatResponse.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }
}

class TimeSeriesPointResponse {
  const TimeSeriesPointResponse({required this.timestamp, required this.value});

  final DateTime timestamp;
  final double value;

  factory TimeSeriesPointResponse.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPointResponse(
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
    );
  }
}

class GroupedStatResponse {
  const GroupedStatResponse({
    required this.key,
    required this.value,
    this.count,
  });

  final String key;
  final double value;
  final int? count;

  factory GroupedStatResponse.fromJson(Map<String, dynamic> json) {
    return GroupedStatResponse(
      key: json['key'] as String,
      value: (json['value'] as num).toDouble(),
      count: (json['count'] as num?)?.toInt(),
    );
  }
}

class EscalationStatResponse {
  const EscalationStatResponse({
    required this.escalationIndex,
    required this.count,
  });

  final int escalationIndex;
  final int count;

  factory EscalationStatResponse.fromJson(Map<String, dynamic> json) {
    return EscalationStatResponse(
      escalationIndex: (json['escalationIndex'] as num).toInt(),
      count: (json['count'] as num).toInt(),
    );
  }
}

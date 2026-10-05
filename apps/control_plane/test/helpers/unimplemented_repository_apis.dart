import 'package:control_plane/data/control_plane_repository.dart';

mixin UnimplementedRepositoryApis {
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
  }) async => throw UnimplementedError();

  Future<ListDefectsResponse> listDefects({
    String? productId,
    String? status,
    String? classification,
    int? limit,
    int? offset,
  }) async => throw UnimplementedError();

  Future<List<FeatureRequestSummaryResponse>> listFeatureRequests({
    String? productId,
    int? limit,
  }) async => throw UnimplementedError();

  Future<CreateFeatureRequestResponse> createFeatureRequest({
    required String title,
    required String description,
    required String productId,
    required String reporter,
  }) async => throw UnimplementedError();

  Future<InspectDefectResponse> inspectDefect(String defectId) async =>
      throw UnimplementedError();

  Future<DefectEvidenceResponse> addDefectEvidence({
    required String defectId,
    required String kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) async => throw UnimplementedError();

  Future<void> answerClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async => throw UnimplementedError();

  Future<VerifyFixResponse> verifyFix({
    required String defectId,
    required String choice,
    String? rationale,
    required String decider,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();

  Future<List<HumanDirectionSummaryResponse>> listDirectionsByStatus({
    required String status,
    String? directionType,
    String? targetType,
    int? limit,
    int? offset,
  }) async => throw UnimplementedError();

  Future<HumanDirectionSummaryResponse> acknowledgeDirection({
    required String directionId,
    required String acknowledgedBy,
  }) async => throw UnimplementedError();

  Future<HumanDirectionSummaryResponse> startWorkingDirection({
    required String directionId,
    required String startedBy,
  }) async => throw UnimplementedError();

  Future<HumanDirectionSummaryResponse> completeDirection({
    required String directionId,
    required String completedBy,
    required String completionSummary,
  }) async => throw UnimplementedError();

  Future<HumanDirectionSummaryResponse> rejectDirection({
    required String directionId,
    required String rejectedBy,
    required String rejectionReason,
  }) async => throw UnimplementedError();

  Future<HumanDirectionSummaryResponse> supersedeDirection({
    required String directionId,
    required String supersededByDirectionId,
    required String supersededBy,
  }) async => throw UnimplementedError();

  Future<DecisionResponse> proposeBaseline({
    required String productId,
    required List<Map<String, dynamic>> facts,
  }) async => throw UnimplementedError();

  Future<DecisionResponse> requestBaselineApproval({
    required String productId,
    required String baselineId,
    String? decisionId,
  }) async => throw UnimplementedError();

  Future<DecisionResponse> resolveBaselineApproval({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async => throw UnimplementedError();

  Future<void> verifyBaseline({
    required String productId,
    required String baselineId,
    required String verifiedBy,
  }) async => throw UnimplementedError();

  Future<DecisionResponse> addHumanBaselineClaim({
    required String productId,
    required String baselineId,
    required String section,
    required String claim,
    required String author,
    List<String> evidenceRefs = const [],
    String? maturity,
  }) async => throw UnimplementedError();

// Model policy / execution tracking
  Future<ProviderHealthResponse> getProviderHealth() async =>
      throw UnimplementedError();

  Future<List<ModelPolicyResponse>> listModelPolicies() async =>
      throw UnimplementedError();

  Future<ModelPolicyResponse> updateModelPolicy({
    required String role,
    required List<ModelStepRequest> chain,
    required int version,
    required String updatedByDecisionId,
  }) async => throw UnimplementedError();

  /// Returns an empty page rather than throwing: a run that dispatched no
  /// agent execution has no model records, and that is a real state the run
  /// detail screen must render, not a missing fake.
  Future<ModelExecutionsPageResponse> listModelExecutions({
    String? workItemId,
    String? provider,
    String? modelId,
    String? taskType,
    bool? success,
    DateTime? from,
    DateTime? to,
    int? limit,
    int? offset,
  }) async => ModelExecutionsPageResponse(
    items: const [],
    totalCount: 0,
    limit: limit ?? 100,
    offset: offset ?? 0,
  );

  Future<ModelStatsResponse> getModelStats({
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) async => throw UnimplementedError();
}

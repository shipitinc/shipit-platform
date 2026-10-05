import '../../data/control_plane_repository.dart';

class DefectDetailState {
  DefectDetailState({
    required this.defectId,
    this.isLoading = false,
    this.defect,
    this.evidence = const [],
    this.clarifications = const [],
    this.events = const [],
    this.triageResult,
    this.remediationWorkItem,
    this.isSubmittingClarification = false,
    this.isSubmittingVerification = false,
    this.errorMessage,
    this.evidenceError,
  });

  final String defectId;
  final bool isLoading;
  final DefectSummaryResponse? defect;
  final List<DefectEvidenceResponse> evidence;
  final List<DefectClarificationResponse> clarifications;
  final List<DefectEventResponse> events;
  final TriageResultResponse? triageResult;
  final RemediationWorkItemResponse? remediationWorkItem;
  final bool isSubmittingClarification;
  final bool isSubmittingVerification;
  final String? errorMessage;
  final String? evidenceError;

  DefectDetailState copyWith({
    bool? isLoading,
    DefectSummaryResponse? defect,
    List<DefectEvidenceResponse>? evidence,
    List<DefectClarificationResponse>? clarifications,
    List<DefectEventResponse>? events,
    TriageResultResponse? triageResult,
    RemediationWorkItemResponse? remediationWorkItem,
    bool? isSubmittingClarification,
    bool? isSubmittingVerification,
    String? errorMessage,
    String? evidenceError,
    bool clearError = false,
  }) {
    return DefectDetailState(
      defectId: defectId,
      isLoading: isLoading ?? this.isLoading,
      defect: defect ?? this.defect,
      evidence: evidence ?? this.evidence,
      clarifications: clarifications ?? this.clarifications,
      events: events ?? this.events,
      triageResult: triageResult ?? this.triageResult,
      remediationWorkItem: remediationWorkItem ?? this.remediationWorkItem,
      isSubmittingClarification:
          isSubmittingClarification ?? this.isSubmittingClarification,
      isSubmittingVerification:
          isSubmittingVerification ?? this.isSubmittingVerification,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      evidenceError: evidenceError ?? this.evidenceError,
    );
  }

  bool get hasPendingClarifications =>
      clarifications.any((c) => c.status == 'needs_answer');

  bool get hasVerificationPending =>
      defect?.status == 'fix_ready_for_verification';
}

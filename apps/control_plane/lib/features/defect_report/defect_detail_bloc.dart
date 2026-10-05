import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';
import 'defect_detail_event.dart';
import 'defect_detail_state.dart';

/// Loads the Defect detail screen.
///
/// Fetches full defect detail including evidence, clarifications, triage result,
/// remediation work item, and event timeline.
class DefectDetailBloc extends Bloc<DefectDetailEvent, DefectDetailState> {
  DefectDetailBloc({
    required ControlPlaneRepository repository,
    required this.defectId,
  }) : _repository = repository,
       super(DefectDetailState(defectId: defectId)) {
    on<DefectDetailLoaded>(_onLoaded);
    on<DefectDetailRefreshed>(_onRefreshed);
    on<DefectDetailEvidenceAdded>(_onEvidenceAdded);
    on<DefectDetailClarificationAnswered>(_onClarificationAnswered);
    on<DefectDetailFixVerified>(_onFixVerified);
  }

  final ControlPlaneRepository _repository;
  final String defectId;

  Future<void> _onLoaded(
    DefectDetailLoaded event,
    Emitter<DefectDetailState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final response = await _repository.inspectDefect(defectId);
      emit(
        state.copyWith(
          isLoading: false,
          defect: response.defect,
          evidence: response.evidence,
          clarifications: response.clarifications,
          events: response.events,
          triageResult: response.triageResult,
          remediationWorkItem: response.remediationWorkItem,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefreshed(
    DefectDetailRefreshed event,
    Emitter<DefectDetailState> emit,
  ) async {
    add(DefectDetailLoaded());
  }

  Future<void> _onEvidenceAdded(
    DefectDetailEvidenceAdded event,
    Emitter<DefectDetailState> emit,
  ) async {
    try {
      final response = await _repository.addDefectEvidence(
        defectId: defectId,
        kind: event.kind,
        description: event.description,
        artifactId: event.artifactId,
      );
      emit(state.copyWith(evidence: [...state.evidence, response]));
    } catch (e) {
      emit(state.copyWith(evidenceError: e.toString()));
    }
  }

  Future<void> _onClarificationAnswered(
    DefectDetailClarificationAnswered event,
    Emitter<DefectDetailState> emit,
  ) async {
    emit(state.copyWith(isSubmittingClarification: true, clearError: true));
    try {
      await _repository.answerClarification(
        clarificationId: event.clarificationId,
        answer: event.answer,
        answeredBy: event.answeredBy,
      );
      // Update the clarification in the list
      final updated = state.clarifications.map((c) {
        if (c.clarificationId == event.clarificationId) {
          return DefectClarificationResponse(
            clarificationId: c.clarificationId,
            defectId: c.defectId,
            question: c.question,
            reason: c.reason,
            status: 'answered',
            answer: event.answer,
            humanDecisionId: c.humanDecisionId,
            requestedByTriageJobId: c.requestedByTriageJobId,
            requestedAt: c.requestedAt,
            answeredAt: DateTime.now(),
            createdAt: c.createdAt,
          );
        }
        return c;
      }).toList();

      // Also update defect status if it was needsClarification
      String? newStatus = state.defect?.status;
      if (newStatus == 'needs_clarification') {
        newStatus = 'triaging';
      }

      emit(
        state.copyWith(
          isSubmittingClarification: false,
          clarifications: updated,
          defect: state.defect != null
              ? DefectSummaryResponse(
                  defectId: state.defect!.defectId,
                  title: state.defect!.title,
                  severity: state.defect!.severity,
                  status: newStatus!,
                  classification: state.defect!.classification,
                  reporter: state.defect!.reporter,
                  createdAt: state.defect!.createdAt,
                  updatedAt: DateTime.now(),
                  affectedWorkItemId: state.defect!.affectedWorkItemId,
                  affectedRunId: state.defect!.affectedRunId,
                  remediationWorkItemId: state.defect!.remediationWorkItemId,
                )
              : null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmittingClarification: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onFixVerified(
    DefectDetailFixVerified event,
    Emitter<DefectDetailState> emit,
  ) async {
    emit(state.copyWith(isSubmittingVerification: true, clearError: true));
    try {
      final response = await _repository.verifyFix(
        defectId: defectId,
        choice: event.choice,
        rationale: event.rationale,
        decider: event.decider,
        signature: event.signature,
        publicKey: event.publicKey,
        algorithm: event.algorithm,
        signedAt: event.signedAt,
      );

      // Update defect status
      final defect = state.defect;
      if (defect != null) {
        emit(
          state.copyWith(
            isSubmittingVerification: false,
            defect: DefectSummaryResponse(
              defectId: defect.defectId,
              title: defect.title,
              severity: defect.severity,
              status: response.newStatus,
              classification: defect.classification,
              reporter: defect.reporter,
              createdAt: defect.createdAt,
              updatedAt: DateTime.now(),
              affectedWorkItemId: defect.affectedWorkItemId,
              affectedRunId: defect.affectedRunId,
              remediationWorkItemId: defect.remediationWorkItemId,
            ),
          ),
        );
      } else {
        emit(state.copyWith(isSubmittingVerification: false));
      }
    } catch (e) {
      emit(
        state.copyWith(
          isSubmittingVerification: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/plain_language.dart';
import '../../data/control_plane_repository.dart';
import 'create_defect_event.dart';
import 'create_defect_state.dart';

/// Manages the Create Defect form.
///
/// Handles form validation, option loading, client context capture, evidence
/// registration and submission to the backend.
class CreateDefectBloc extends Bloc<CreateDefectEvent, CreateDefectState> {
  CreateDefectBloc({
    required this._repository,
    required this._reporter,
    this.prefilledWorkItemId,
    this.prefilledRunId,
  }) : super(
         CreateDefectState(
           prefilledWorkItemId: prefilledWorkItemId,
           prefilledRunId: prefilledRunId,
         ),
       ) {
    on<CreateDefectTitleChanged>(_onTitleChanged);
    on<CreateDefectDescriptionChanged>(_onDescriptionChanged);
    on<CreateDefectExpectedBehaviorChanged>(_onExpectedBehaviorChanged);
    on<CreateDefectReproductionStepsChanged>(_onReproductionStepsChanged);
    on<CreateDefectSeverityChanged>(_onSeverityChanged);
    on<CreateDefectIntakeCategoryChanged>(_onIntakeCategoryChanged);
    on<CreateDefectProductChanged>(_onProductChanged);
    on<CreateDefectAffectedWorkItemChanged>(_onAffectedWorkItemChanged);
    on<CreateDefectEvidenceAdded>(_onEvidenceAdded);
    on<CreateDefectEvidenceRemoved>(_onEvidenceRemoved);
    on<CreateDefectOptionsRequested>(_onOptionsRequested);
    on<CreateDefectWorkItemsRequested>(_onWorkItemsRequested);
    on<CreateDefectSubmitted>(_onSubmitted);
    on<CreateDefectClientContextCaptured>(_onClientContextCaptured);
    add(CreateDefectOptionsRequested());
  }

  final ControlPlaneRepository _repository;
  final String _reporter;
  final String? prefilledWorkItemId;
  final String? prefilledRunId;

  void _onTitleChanged(
    CreateDefectTitleChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(state.copyWith(title: event.title, clearError: true));
  }

  void _onDescriptionChanged(
    CreateDefectDescriptionChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(state.copyWith(description: event.description, clearError: true));
  }

  void _onExpectedBehaviorChanged(
    CreateDefectExpectedBehaviorChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(
      state.copyWith(
        expectedBehavior: event.expectedBehavior,
        clearError: true,
      ),
    );
  }

  void _onReproductionStepsChanged(
    CreateDefectReproductionStepsChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(
      state.copyWith(
        reproductionSteps: event.reproductionSteps,
        clearError: true,
      ),
    );
  }

  void _onSeverityChanged(
    CreateDefectSeverityChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(state.copyWith(severity: event.severity, clearError: true));
  }

  void _onIntakeCategoryChanged(
    CreateDefectIntakeCategoryChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(
      state.copyWith(intakeCategory: event.intakeCategory, clearError: true),
    );
  }

  void _onProductChanged(
    CreateDefectProductChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    // The two fields describe one report; a work item from the previous
    // product must not survive the change.
    emit(
      state.copyWith(
        productId: event.productId,
        clearProduct: event.productId == null,
        clearAffectedWorkItem: true,
        clearError: true,
      ),
    );
    add(CreateDefectWorkItemsRequested());
  }

  void _onAffectedWorkItemChanged(
    CreateDefectAffectedWorkItemChanged event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(
      state.copyWith(
        affectedWorkItemId: event.workItemId,
        clearAffectedWorkItem: event.workItemId == null,
        clearError: true,
      ),
    );
  }

  void _onEvidenceAdded(
    CreateDefectEvidenceAdded event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(
      state.copyWith(
        evidence: [...state.evidence, ...event.files],
        clearError: true,
      ),
    );
  }

  void _onEvidenceRemoved(
    CreateDefectEvidenceRemoved event,
    Emitter<CreateDefectState> emit,
  ) {
    if (event.index < 0 || event.index >= state.evidence.length) return;
    final next = [...state.evidence]..removeAt(event.index);
    emit(state.copyWith(evidence: next));
  }

  /// The Product options load is best-effort but the field is required. If the
  /// load fails, the user cannot submit. AFFECTED WORK ITEM remains optional.
  Future<void> _onOptionsRequested(
    CreateDefectOptionsRequested event,
    Emitter<CreateDefectState> emit,
  ) async {
    emit(state.copyWith(optionsLoading: true));
    List<(String, String)> products = const [];
    try {
      final rows = await _repository.listProductSummaries();
      products = [for (final row in rows) (row.productId, row.name)];
    } catch (_) {
      products = const [];
    }
    emit(state.copyWith(optionsLoading: false, products: products));
    add(CreateDefectWorkItemsRequested());
  }

  Future<void> _onWorkItemsRequested(
    CreateDefectWorkItemsRequested event,
    Emitter<CreateDefectState> emit,
  ) async {
    List<(String, String)> items = const [];
    try {
      final rows = await _repository.listWorkItems(productId: state.productId);
      items = [
        for (final row in rows)
          (
            row.workItemId,
            '${PlainLanguage.refLabel(row.workItemId)}  ·  ${row.title}',
          ),
      ];
    } catch (_) {
      items = const [];
    }
    emit(state.copyWith(workItems: items));
  }

  void _onClientContextCaptured(
    CreateDefectClientContextCaptured event,
    Emitter<CreateDefectState> emit,
  ) {
    emit(state.copyWith(clientContextJson: event.clientContextJson));
  }

  Future<void> _onSubmitted(
    CreateDefectSubmitted event,
    Emitter<CreateDefectState> emit,
  ) async {
    // Validate
    if (state.title.trim().isEmpty) {
      emit(
        state.copyWith(isSubmitting: false, errorMessage: 'Title is required'),
      );
      return;
    }
    if (state.description.trim().isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Description is required',
        ),
      );
      return;
    }
    if (state.expectedBehavior.trim().isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Expected behavior is required',
        ),
      );
      return;
    }
    if (state.severity == null) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Severity is required',
        ),
      );
      return;
    }
    if (state.productId == null) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Product is required',
        ),
      );
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final response = await _repository.createDefect(
        title: state.title.trim(),
        description: state.description.trim(),
        expectedBehavior: state.expectedBehavior.trim(),
        reproductionSteps: state.reproductionSteps.trim(),
        severity: state.severity!,
        intakeCategory: state.intakeCategory,
        productId: state.productId!,
        affectedWorkItemId: state.effectiveWorkItemId,
        affectedRunId: state.prefilledRunId,
        clientContextJson: state.clientContextJson,
        reporter: _reporter,
      );

      // Evidence is registered after the defect exists, so a failure here
      // never loses the report — it is reported alongside the new reference.
      String? evidenceError;
      for (final file in state.evidence) {
        try {
          await _repository.addDefectEvidence(
            defectId: response.defectId,
            kind: 'screenshot',
            description: file.description,
            contentHash: file.sha256,
            sourceRef: 'file-picker',
          );
        } catch (error) {
          evidenceError = evidenceError == null
              ? 'Evidence "${file.name}" was not attached: $error'
              : '$evidenceError  ·  Evidence "${file.name}" was not attached: '
                    '$error';
        }
      }

      emit(
        state.copyWith(
          isSubmitting: false,
          createdDefectId: response.defectId,
          success: true,
          errorMessage: evidenceError,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}

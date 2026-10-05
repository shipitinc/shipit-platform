import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';
import 'create_feature_request_event.dart';
import 'create_feature_request_state.dart';

/// Manages the `Request a feature` form.
///
/// Filing a request is one call: the server writes a draft work item and the
/// intake direction in the same transaction, so this bloc validates, loads the
/// products the request can be filed against, and submits.
class CreateFeatureRequestBloc
    extends Bloc<CreateFeatureRequestEvent, CreateFeatureRequestState> {
  CreateFeatureRequestBloc({required this._repository, required this._reporter})
    : super(const CreateFeatureRequestState()) {
    on<CreateFeatureRequestTitleChanged>(_onTitleChanged);
    on<CreateFeatureRequestDescriptionChanged>(_onDescriptionChanged);
    on<CreateFeatureRequestProductChanged>(_onProductChanged);
    on<CreateFeatureRequestOptionsRequested>(_onOptionsRequested);
    on<CreateFeatureRequestSubmitted>(_onSubmitted);
    add(const CreateFeatureRequestOptionsRequested());
  }

  final ControlPlaneRepository _repository;
  final String _reporter;

  void _onTitleChanged(
    CreateFeatureRequestTitleChanged event,
    Emitter<CreateFeatureRequestState> emit,
  ) {
    emit(state.copyWith(title: event.title, clearError: true));
  }

  void _onDescriptionChanged(
    CreateFeatureRequestDescriptionChanged event,
    Emitter<CreateFeatureRequestState> emit,
  ) {
    emit(state.copyWith(description: event.description, clearError: true));
  }

  void _onProductChanged(
    CreateFeatureRequestProductChanged event,
    Emitter<CreateFeatureRequestState> emit,
  ) {
    emit(
      state.copyWith(
        productId: event.productId,
        clearProduct: event.productId.isEmpty,
        clearError: true,
      ),
    );
  }

  Future<void> _onOptionsRequested(
    CreateFeatureRequestOptionsRequested event,
    Emitter<CreateFeatureRequestState> emit,
  ) async {
    emit(state.copyWith(optionsLoading: true));
    List<(String, String)> products = const [];
    String? failure;
    try {
      final rows = await _repository.listProductSummaries();
      products = [for (final row in rows) (row.productId, row.name)];
    } catch (_) {
      // A request cannot be filed without a product, so a failure to read them
      // is reported on submit rather than silently leaving an empty dropdown.
      failure = 'The product list could not be read. Try again.';
    }
    emit(
      state.copyWith(
        optionsLoading: false,
        products: products,
        errorMessage: failure,
      ),
    );
  }

  Future<void> _onSubmitted(
    CreateFeatureRequestSubmitted event,
    Emitter<CreateFeatureRequestState> emit,
  ) async {
    if (state.isSubmitting || state.success) return;
    if (state.title.trim().isEmpty || state.productMissing) {
      // Nothing is written; `attemptedSubmit` is what turns the field-level
      // messages on, and it stays on until the field is valid.
      emit(state.copyWith(attemptedSubmit: true, clearError: true));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final created = await _repository.createFeatureRequest(
        title: state.title.trim(),
        description: state.description.trim(),
        productId: state.productId!,
        reporter: _reporter,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          success: true,
          createdWorkItemId: created.workItemId,
          createdTitle: created.title,
          createdState: created.state,
        ),
      );
    } catch (error) {
      emit(state.copyWith(isSubmitting: false, errorMessage: _readable(error)));
    }
  }

  /// The server's own wording, kept intact — a failed write is a fact about the
  /// system, not a phrasing problem.
  String _readable(Object error) => error.toString();
}

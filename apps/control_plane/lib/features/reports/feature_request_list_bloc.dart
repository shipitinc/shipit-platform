import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';
import 'feature_request.dart';
import 'feature_request_list_event.dart';
import 'feature_request_list_state.dart';

/// Loads the Reports screen's `Feature requests` register.
///
/// A feature request is a draft work item, so this is a read of the durable
/// work-item record filtered to `category: feature` — there is no separate
/// request table the UI could drift away from.
class FeatureRequestListBloc
    extends Bloc<FeatureRequestListEvent, FeatureRequestListState> {
  FeatureRequestListBloc({
    required this._repository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const FeatureRequestListState()) {
    on<FeatureRequestListRequested>(_onRequested);
  }

  final ControlPlaneRepository _repository;

  /// Injected for deterministic goldens: the freshness stamp must not move
  /// between two runs of the same seed.
  final DateTime Function() _clock;

  Future<void> _onRequested(
    FeatureRequestListRequested event,
    Emitter<FeatureRequestListState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, productId: event.productId));
    try {
      // The product list backs the filter control, so it is read alongside the
      // register rather than derived from the visible rows.
      final products = await _repository.listProductSummaries();
      final rows = await _repository.listFeatureRequests(
        productId: event.productId,
      );
      emit(
        state.copyWith(
          requests: [
            for (final row in rows)
              FeatureRequest(
                workItemId: row.workItemId,
                title: row.title,
                description: row.description,
                state: row.state,
                productId: row.productId,
                productName: row.productName,
                reporter: row.reporter,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
                completedAt: row.completedAt,
              ),
          ],
          isLoading: false,
          products: [for (final row in products) (row.productId, row.name)],
          lastSuccessAt: _clock(),
        ),
      );
    } on Object catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/control_plane_repository.dart';
import 'defect_list_event.dart';
import 'defect_list_state.dart';

/// Loads the Defects list screen.
///
/// Fetches the register with optional filters. Every event is a request to read
/// the register again under some set of filters, so the read itself lives in
/// [_read] and the events only decide which filters apply. That is what keeps a
/// fourth filter from becoming a fourth copy of the same fetch.
class DefectListBloc extends Bloc<DefectListEvent, DefectListState> {
  /// [initial] is a test seam: it lets a golden seed `lastSuccessAt`
  /// so the error panel can draw the `last successful reading …` stamp the
  /// board shows, without a two-step repository dance.
  DefectListBloc({
    required this._repository,
    DefectListState initial = const DefectListState(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(initial) {
    on<DefectListLoaded>(_onLoaded);
    on<DefectListFilterChanged>(_onFilterChanged);
    on<DefectListPageRequested>(_onPageRequested);
    on<DefectListRefreshed>(_onRefreshed);
  }

  final ControlPlaneRepository _repository;

  /// Supplies the freshness stamp. Injectable so goldens are deterministic.
  final DateTime Function() _clock;

  Future<void> _onLoaded(
    DefectListLoaded event,
    Emitter<DefectListState> emit,
  ) {
    return _read(
      emit,
      status: event.status,
      classification: event.classification,
      productId: event.productId,
      limit: event.limit,
    );
  }

  Future<void> _onFilterChanged(
    DefectListFilterChanged event,
    Emitter<DefectListState> emit,
  ) {
    return _read(
      emit,
      status: event.status,
      classification: event.classification,
      productId: event.productId,
      limit: event.limit,
    );
  }

  Future<void> _onPageRequested(
    DefectListPageRequested event,
    Emitter<DefectListState> emit,
  ) async {
    // TODO: Implement pagination when backend supports offset
    // For now, just reload with same filters
    add(
      DefectListFilterChanged(
        status: state.statusFilter,
        classification: state.classificationFilter,
        productId: state.productFilter,
      ),
    );
  }

  Future<void> _onRefreshed(
    DefectListRefreshed event,
    Emitter<DefectListState> emit,
  ) {
    return _read(
      emit,
      status: state.statusFilter,
      classification: state.classificationFilter,
      productId: state.productFilter,
      limit: 50,
    );
  }

  Future<void> _read(
    Emitter<DefectListState> emit, {
    String? status,
    String? classification,
    String? productId,
    int? limit,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      // The product list backs the filter control, so it is read alongside the
      // register rather than derived from the visible rows — a filtered read
      // would otherwise leave the filter offering only the selected product.
      final products = await _repository.listProductSummaries();
      final response = await _repository.listDefects(
        status: status,
        classification: classification,
        productId: productId,
        limit: limit,
      );
      emit(
        state.copyWith(
          isLoading: false,
          defects: response.defects,
          totalCount: response.totalCount,
          statusFilter: status,
          classificationFilter: classification,
          productFilter: productId,
          clearProductFilter: productId == null,
          products: [for (final row in products) (row.productId, row.name)],
          lastSuccessAt: _clock(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}

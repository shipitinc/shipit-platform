import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/product_language.dart';
import '../../data/control_plane_repository.dart';

sealed class ProductsEvent {
  const ProductsEvent();
}

/// Load (or reload) the registry.
class ProductsLoaded extends ProductsEvent {
  const ProductsLoaded();
}

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc({required ControlPlaneRepository repository})
    : _repository = repository,
      super(const ProductsState()) {
    on<ProductsLoaded>(_onLoaded);
  }

  final ControlPlaneRepository _repository;

  Future<void> _onLoaded(
    ProductsLoaded event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final rows = await _repository.listProductSummaries();
      emit(
        ProductsState(
          isLoading: false,
          products: rows.map(ProductRow.fromResponse).toList(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }
}

class ProductsState {
  const ProductsState({
    this.isLoading = false,
    this.products = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final List<ProductRow> products;
  final String? errorMessage;

  ProductsState copyWith({
    bool? isLoading,
    List<ProductRow>? products,
    String? errorMessage,
    bool clearError = false,
  }) => ProductsState(
    isLoading: isLoading ?? this.isLoading,
    products: products ?? this.products,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// One product, as the screen needs it.
///
/// Nothing here is computed for display beyond formatting: `allowsDispatch`
/// comes from the engine, and the counts are durable registry state.
class ProductRow {
  const ProductRow({
    required this.productId,
    required this.name,
    required this.stateWire,
    required this.allowsDispatch,
    required this.baselineLabel,
    required this.pendingBaselineVerified,
    required this.hasPendingBaseline,
    required this.factCount,
    required this.openClarifications,
    required this.repositoryCount,
    required this.reachableRepositoryCount,
  });

  factory ProductRow.fromResponse(ProductSummaryResponse r) => ProductRow(
    productId: r.productId,
    name: r.name,
    stateWire: r.state,
    allowsDispatch: r.allowsDispatch,
    baselineLabel: ProductLanguage.baselineLabel(
      activeId: r.activeBaselineId,
      activeRevision: r.activeBaselineRevision,
      pendingId: r.pendingBaselineId,
      pendingRevision: r.pendingBaselineRevision,
      pendingVerified: r.pendingBaselineVerified,
    ),
    pendingBaselineVerified: r.pendingBaselineVerified,
    hasPendingBaseline: r.pendingBaselineId != null,
    factCount: r.baselineFactCount,
    openClarifications: r.openClarifications,
    repositoryCount: r.repositoryCount,
    reachableRepositoryCount: r.reachableRepositoryCount,
  );

  final String productId;
  final String name;
  final String stateWire;
  final bool allowsDispatch;
  final String baselineLabel;

  /// Whether the candidate under review carries a worker attestation.
  final bool pendingBaselineVerified;
  final bool hasPendingBaseline;

  /// Recorded baseline claims. NOT a file count.
  final int factCount;

  final int openClarifications;
  final int repositoryCount;
  final int reachableRepositoryCount;

  ProductStatus get status => ProductLanguage.statusFor(stateWire);

  String get accessLabel => ProductLanguage.accessLabel(
    repositoryCount: repositoryCount,
    reachableCount: reachableRepositoryCount,
  );

  /// A product awaiting approval whose baseline has not been verified cannot
  /// actually be approved — the gate refuses to open. Worth saying out loud
  /// rather than showing a button that will fail.
  bool get isBlockedOnVerification =>
      status == ProductStatus.baselineReview &&
      hasPendingBaseline &&
      !pendingBaselineVerified;
}

/// Filters exposed by the Products board, in board order.
enum ProductFilter {
  all('All products'),
  governed('Governed'),
  onboarding('Onboarding'),
  paused('Paused'),
  archived('Archived'),
  needsYou('Needs you');

  const ProductFilter(this.label);

  final String label;

  bool matches(ProductStatus status) => switch (this) {
    ProductFilter.all => status != ProductStatus.archived,
    ProductFilter.governed => status == ProductStatus.governed,
    ProductFilter.onboarding => status.isOnboarding,
    ProductFilter.paused => status == ProductStatus.paused,
    ProductFilter.archived => status == ProductStatus.archived,
    ProductFilter.needsYou => status.isOperatorTurn,
  };

  /// Copy for an empty result under this filter.
  String get emptyMessage => switch (this) {
    ProductFilter.all => 'No products are registered yet.',
    ProductFilter.governed => 'No product is governed yet.',
    ProductFilter.onboarding => 'No product is onboarding.',
    ProductFilter.paused => 'No product is paused.',
    ProductFilter.archived => 'No product has been archived.',
    ProductFilter.needsYou => 'Nothing is waiting on you.',
  };
}

import '../../data/control_plane_repository.dart';
import '../../shared/design_primitives.dart';

class DefectListState {
  const DefectListState({
    this.isLoading = false,
    this.defects = const [],
    this.totalCount = 0,
    this.statusFilter,
    this.classificationFilter,
    this.productFilter,
    this.products = const [],
    this.errorMessage,
    this.lastSuccessAt,
  });

  final bool isLoading;
  final List<DefectSummaryResponse> defects;

  /// Size of the whole register, before the filters are applied. Kept apart
  /// from [defects.length] so the header can say what the register holds
  /// rather than what the current filter happens to show.
  final int totalCount;

  final String? statusFilter;
  final String? classificationFilter;

  /// The product the register is narrowed to, or null for all of them.
  final String? productFilter;

  /// `id` / `name` pairs the product filter offers.
  ///
  /// Read separately from [defects] so the filter keeps offering every product
  /// while a filter is applied — deriving the list from the visible rows would
  /// collapse it to the one product already selected.
  final List<(String, String)> products;

  final String? errorMessage;

  /// When the durable record was last read successfully. Drives the error
  /// panel's `last successful reading 2m ago` stamp; null while no read has
  /// succeeded yet, so the stamp is omitted rather than invented.
  final DateTime? lastSuccessAt;

  DefectListState copyWith({
    bool? isLoading,
    List<DefectSummaryResponse>? defects,
    int? totalCount,
    String? statusFilter,
    String? classificationFilter,
    String? productFilter,
    bool clearProductFilter = false,
    List<(String, String)>? products,
    String? errorMessage,
    DateTime? lastSuccessAt,
    bool clearError = false,
  }) {
    return DefectListState(
      isLoading: isLoading ?? this.isLoading,
      defects: defects ?? this.defects,
      totalCount: totalCount ?? this.totalCount,
      statusFilter: statusFilter ?? this.statusFilter,
      classificationFilter: classificationFilter ?? this.classificationFilter,
      productFilter: clearProductFilter
          ? null
          : (productFilter ?? this.productFilter),
      products: products ?? this.products,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    );
  }

  bool get hasFilters =>
      statusFilter != null ||
      classificationFilter != null ||
      productFilter != null;

  int get displayedCount => defects.length;

  /// `Product: Checkout` — the filter's own label, naming the choice rather
  /// than the mechanism. Null product reads `Product: All`.
  String get productFilterLabel =>
      ProductFilterLink.labelFor(productFilter, products);
}

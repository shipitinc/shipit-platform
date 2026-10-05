import 'package:flutter/foundation.dart';

import '../../shared/design_primitives.dart';
import 'feature_request.dart';

/// Snapshot of the `Feature requests` register.
@immutable
class FeatureRequestListState {
  const FeatureRequestListState({
    this.requests = const [],
    this.isLoading = false,
    this.errorMessage,
    this.productId,
    this.products = const [],
    this.lastSuccessAt,
  });

  final List<FeatureRequest> requests;
  final bool isLoading;
  final String? errorMessage;

  /// Product filter the rows were read under, echoed for the technical
  /// details block.
  final String? productId;

  /// `id` / `name` pairs the product filter offers, read separately from the
  /// rows so the filter keeps offering every product while one is applied.
  final List<(String, String)> products;

  /// `Product: All` / `Product: <name>` for the filter's own label.
  String get productFilterLabel =>
      ProductFilterLink.labelFor(productId, products);

  /// Set only by a read that actually succeeded, so the freshness stamp on the
  /// error panel is a fact rather than a made-up date.
  final DateTime? lastSuccessAt;

  bool get isEmpty => requests.isEmpty;

  bool get hasError => errorMessage != null;

  /// True only when the read failed *and* left nothing to show. A failed
  /// refresh over rows already on screen is not an error screen.
  bool get isErrorScreen => hasError && requests.isEmpty;

  bool get isLoadingScreen => isLoading && requests.isEmpty;

  FeatureRequestListState copyWith({
    List<FeatureRequest>? requests,
    bool? isLoading,
    String? errorMessage,
    String? productId,
    List<(String, String)>? products,
    DateTime? lastSuccessAt,
  }) {
    return FeatureRequestListState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      productId: productId ?? this.productId,
      products: products ?? this.products,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    );
  }
}

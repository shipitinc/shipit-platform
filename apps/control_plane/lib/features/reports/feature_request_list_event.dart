/// Why the feature-request register is being read.
sealed class FeatureRequestListEvent {
  const FeatureRequestListEvent();
}

/// First read of the register, and the read behind a retry.
class FeatureRequestListRequested extends FeatureRequestListEvent {
  const FeatureRequestListRequested({this.productId});

  /// Narrows the register to one product when the Reports screen has a product
  /// filter applied. Null reads the whole register.
  final String? productId;
}

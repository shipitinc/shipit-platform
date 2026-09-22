import 'package:meta/meta.dart';

/// The exact immutable candidate a human baseline-approval decision authorizes.
///
/// Persisted in [HumanDecision.metadata] (the existing decision-context carrier)
/// so that the authorization can be re-checked against the live baseline at
/// acceptance time. If any field here no longer matches the revision being
/// accepted — including [contentHashVersion] — the approval is stale and
/// acceptance must fail closed.
///
/// Since Hash Contract V3 was introduced, every NEW approval binds all five
/// fields:
/// productId, baselineId, baselineRevision, contentHash, contentHashVersion.
/// An approval authored against a defective/historical hash version is never a
/// valid authority for a Hash V3 baseline.
@immutable
class BaselineApprovalBinding {
  const BaselineApprovalBinding({
    required this.productId,
    required this.baselineId,
    required this.baselineRevision,
    required this.contentHash,
    required this.contentHashVersion,
  });

  final String productId;
  final String baselineId;
  final int baselineRevision;
  final String contentHash;

  /// Version of the content-hash contract the bound [contentHash] was computed
  /// under. An approval must bind the version explicitly — drifting between
  /// hash versions must never silently authorize a different digest.
  final int contentHashVersion;

  /// Discriminator recorded in decision metadata. A [HumanDecision] carrying a
  /// different routing value is not a product-baseline approval.
  static const String routingValue = 'product_baseline_approval';

  static const String _routingKey = 'routing';
  static const String _productIdKey = 'productId';
  static const String _baselineIdKey = 'baselineId';
  static const String _baselineRevisionKey = 'baselineRevision';
  static const String _contentHashKey = 'contentHash';
  static const String _contentHashVersionKey = 'contentHashVersion';

  /// Deterministic owning scope key recorded in `HumanDecision.workItemId`.
  static String scopeFor(String productId) => 'product-baseline:$productId';

  Map<String, dynamic> toMetadata() => <String, dynamic>{
    _routingKey: routingValue,
    _productIdKey: productId,
    _baselineIdKey: baselineId,
    _baselineRevisionKey: baselineRevision,
    _contentHashKey: contentHash,
    _contentHashVersionKey: contentHashVersion,
  };

  /// Parses a binding from decision metadata, or null when the metadata is not
  /// a product-baseline approval binding. An approval that omits the hash
  /// version is not a valid binding — it cannot be safely verified.
  static BaselineApprovalBinding? tryFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null || metadata[_routingKey] != routingValue) return null;
    final productId = metadata[_productIdKey];
    final baselineId = metadata[_baselineIdKey];
    final revision = metadata[_baselineRevisionKey];
    final contentHash = metadata[_contentHashKey];
    final contentHashVersion = metadata[_contentHashVersionKey];
    if (productId is! String ||
        baselineId is! String ||
        revision is! int ||
        contentHash is! String ||
        contentHashVersion is! int) {
      return null;
    }
    return BaselineApprovalBinding(
      productId: productId,
      baselineId: baselineId,
      baselineRevision: revision,
      contentHash: contentHash,
      contentHashVersion: contentHashVersion,
    );
  }

  bool matches({
    required String productId,
    required String baselineId,
    required int baselineRevision,
    required String contentHash,
    required int contentHashVersion,
  }) =>
      this.productId == productId &&
      this.baselineId == baselineId &&
      this.baselineRevision == baselineRevision &&
      this.contentHash == contentHash &&
      this.contentHashVersion == contentHashVersion;

  @override
  String toString() =>
      'BaselineApprovalBinding($productId/$baselineId@r$baselineRevision '
      'v$contentHashVersion $contentHash)';
}
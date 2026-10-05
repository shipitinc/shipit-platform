import 'package:flutter/foundation.dart';

/// One feature request as the register lists it.
@immutable
class FeatureRequest {
  const FeatureRequest({
    required this.workItemId,
    required this.title,
    this.description,
    required this.state,
    required this.productId,
    this.productName,
    this.reporter,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String workItemId;
  final String title;

  /// The reporter's own words. The register shows the title and a short
  /// excerpt; the full text is on the work item.
  final String? description;

  /// `WorkflowState` wire value. A request stays `draft` until a human decides.
  final String state;

  final String productId;

  /// Absent when no registry row resolves — the register prints the product id
  /// rather than inventing a name for it.
  final String? productName;

  final String? reporter;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// The product as the register names it, falling back to the id.
  String get productLabel => productName ?? productId;
}

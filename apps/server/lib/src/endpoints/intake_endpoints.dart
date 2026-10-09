import 'package:serverpod/serverpod.dart';

import '../generated/feature_request_created_view.dart';
import '../generated/feature_request_summary_view.dart';
import '../services/control_plane_service.dart';

/// Endpoints for unified human work intake (S-2 Feature Requests, etc.).
class IntakeEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Creates a new Feature Request.
  ///
  /// Instantiates a WorkItem with category: feature, and a corresponding
  /// HumanDirection to surface it in the inbox.
  ///
  /// Was `Future<Map<String, dynamic>>`. The Reports screen's Feature tab calls
  /// it, so it threw `No deserialization found for type dynamic` the first time
  /// anybody filed a request.
  Future<FeatureRequestCreatedView> createFeatureRequest(
    Session session, {
    required String title,
    required String description,
    required String productId,
    required String reporter,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final workItem = await service.createFeatureWorkItem(
        title: title,
        description: description,
        productId: productId,
        reporter: reporter,
      );

      return FeatureRequestCreatedView(
        workItemId: workItem.workItemId,
        title: workItem.title,
        state: workItem.state.wire,
        createdAt: workItem.createdAt,
      );
    } catch (error, stackTrace) {
      service.logger.error('intake.create_feature.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists feature requests for the Reports screen's `Feature requests` tab.
  ///
  /// Read-only and product-scoped like every other list on this surface: a
  /// caller that names no [productId] gets the whole register, and one that
  /// names an unregistered product gets nothing rather than a fabricated row.
  /// The envelope mirrors `defectEndpoints.list` so the client can read both
  /// tabs with the same shape.
  Future<List<FeatureRequestSummaryView>> listFeatureRequests(
    Session session, {
    String? productId,
    String? state,
    int? limit,
  }) async {
    final service = ControlPlaneService(session);
    try {
      return service.listFeatureRequests(
        productId: productId,
        state: state,
        limit: limit,
      );
    } catch (error, stackTrace) {
      service.logger.error('intake.list_features.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

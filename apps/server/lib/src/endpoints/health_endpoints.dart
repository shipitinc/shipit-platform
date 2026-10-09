import 'package:serverpod/serverpod.dart';

import '../generated/health_status_view.dart';

/// Simple health check endpoint for load balancers and monitoring.
class HealthEndpoints extends Endpoint {
  @override
  bool get logSessions => false;

  /// Returns a simple health check response.
  ///
  /// Was `Future<Map<String, dynamic>>`, so the generated client could not read
  /// it: `deserialize<dynamic>` has no entry in Serverpod's serialization
  /// manager. The `timestamp` therefore travels as a real `DateTime` rather than
  /// a pre-formatted string, which is what every other view in this directory
  /// does and what makes the type worth having.
  Future<HealthStatusView> health(Session session) async {
    return HealthStatusView(
      status: 'ok',
      timestamp: DateTime.now().toUtc(),
    );
  }
}

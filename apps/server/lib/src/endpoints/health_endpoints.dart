import 'package:serverpod/serverpod.dart';

/// Simple health check endpoint for load balancers and monitoring.
class HealthEndpoints extends Endpoint {
  @override
  bool get logSessions => false;

  /// Returns a simple health check response.
  Future<Map<String, dynamic>> health(Session session) async {
    return {
      'status': 'ok',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

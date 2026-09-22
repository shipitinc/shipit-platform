import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

/// Local-only E2E server for the real Flutter web operator UI run.
///
/// Binds the API server to a FIXED port so the built web app (built with
/// `--dart-define=CONTROL_PLANE_API=http://localhost:8190/`) and Playwright
/// can reach it without re-reading ephemeral ports, and points the database at
/// the same dedicated PostgreSQL instance the server test suite uses
/// (`docker compose` test database, :9090). NOT a deployment entry point —
/// production/staging use `bin/main.dart` with their own config.
///
/// SECURITY: Serverpod binds `anyIPv6` regardless of `publicHost`; only
/// connect from the local machine. This driver is for single-user dev
/// environments behind a trusted firewall. Never expose port 8190 on a
/// public interface.
Future<void> main(List<String> args) async {
  final pod = Serverpod(
    ['--mode', 'test', '--apply-migrations'],
    Protocol(),
    Endpoints(),
    configOverride: (config) => config.copyWith(
      apiServer: ServerConfig(
        port: 8190,
        publicHost: 'localhost',
        publicPort: 8190,
        publicScheme: 'http',
      ),
      insightsServer: null,
      webServer: null,
      redis: null,
    ),
  );
  await pod.start();
}

import 'package:control_plane_client/control_plane_client.dart';
import 'runtime_config_stub.dart'
    if (dart.library.js_interop) 'runtime_config_web.dart'
    as runtime_config;
import 'control_plane_repository.dart';

class ClientProvider {
  static Client? _client;
  static ControlPlaneRepository? _repository;

  static ControlPlaneRepository get repository {
    _repository ??= ControlPlaneRepository(client: _getClient());
    return _repository!;
  }

  static Client _getClient() {
    const fallback = String.fromEnvironment(
      'CONTROL_PLANE_API',
      defaultValue: 'http://localhost:8080/',
    );

    String apiBase;
    try {
      // Try to read from runtime config (window.SHIPIT_CONFIG).
      // In the browser this resolves after config.js has been loaded.
      final runtimeValue = runtime_config.readControlPlaneApi();
      if (runtimeValue == null || runtimeValue.isEmpty) {
        throw StateError('Empty CONTROL_PLANE_API from runtime config');
      }
      apiBase = runtimeValue;
    } catch (_) {
      // Fallback to build-time default for development/testing.
      // When running in Flutter dev mode (dart run), config.js won't be loaded.
      apiBase = fallback;
    }
    _client ??= Client(apiBase);
    return _client!;
  }
}

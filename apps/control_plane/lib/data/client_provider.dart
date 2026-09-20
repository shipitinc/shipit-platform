import 'package:control_plane_client/control_plane_client.dart';
import 'control_plane_repository.dart';

class ClientProvider {
  static Client? _client;
  static ControlPlaneRepository? _repository;

  static ControlPlaneRepository get repository {
    _repository ??= ControlPlaneRepository(client: _getClient());
    return _repository!;
  }

  static Client _getClient() {
    const apiBase = String.fromEnvironment(
      'CONTROL_PLANE_API',
      defaultValue: 'http://localhost:8080/',
    );
    _client ??= Client(apiBase);
    return _client!;
  }
}

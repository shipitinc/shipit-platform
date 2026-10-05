import 'package:serverpod/serverpod.dart';
import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';

void main() async {
  final pod = Serverpod(
    ['--mode', 'development', '--apply-migrations'],
    Protocol(),
    Endpoints(),
    configOverride: (config) => config.copyWith(
      database: DatabaseConfig(
        host: 'localhost',
        port: 5432,
        name: 'control_plane',
        user: 'postgres',
        password: 'fd6239170e2e5511e8ac0fa79a03695f28781037d4c8b644',
      ),
      redis: null,
      webServer: null,
      insightsServer: null,
    ),
  );
  print('Starting pod...');
  await pod.start();
  print('Pod started!');
  await pod.shutdown(exitProcess: true);
}
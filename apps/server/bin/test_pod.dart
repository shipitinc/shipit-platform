import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';

String _env(String key, String fallback) {
  final value = Platform.environment[key];
  return (value == null || value.isEmpty) ? fallback : value;
}

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
        password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit'),
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
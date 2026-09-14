import 'package:serverpod/serverpod.dart';

import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';

/// The starting point of the ShipIt control plane server.
///
/// Serverpod hosts the PostgreSQL persistence layer only. All workflow policy
/// authority lives in [workflow_engine]'s `DurableWorkflowEngine`; endpoints
/// never mutate `WorkItem.state` directly.
void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints());

  // No authentication services: the control plane API is intended for local
  // / trusted-network use (documented under SECURITY ASSUMPTION in the
  // control-plane persistence slice report).

  // Start the server.
  await pod.start();
}

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// The narrow seam through which the worker layer drives one agent execution.
/// Keeping the worker independent of [ExecutionCoordinator] internals makes
/// every worker test a pure unit test and keeps the worker layer free of
/// workflow policy by construction.
abstract interface class AgentExecutionDriver {
  Future<AgentExecution> execute(AgentExecutionRequest request);

  Future<AgentExecution> cancel(String executionId, String reason);

  Future<List<PlatformVerification>> verificationsFor(String executionId);
}

/// Default driver: forwards requests verbatim to [ExecutionCoordinator]. The
/// coordinator owns workflow-state transitions and durable execution records;
/// the driver adds no policy of its own.
class CoordinatorAgentExecutionDriver implements AgentExecutionDriver {
  CoordinatorAgentExecutionDriver(this._coordinator);

  final ExecutionCoordinator _coordinator;

  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) =>
      _coordinator.execute(request);

  @override
  Future<AgentExecution> cancel(String executionId, String reason) =>
      _coordinator.cancelExecution(executionId, reason);

  @override
  Future<List<PlatformVerification>> verificationsFor(String executionId) =>
      _coordinator.store.readVerifications(executionId);
}

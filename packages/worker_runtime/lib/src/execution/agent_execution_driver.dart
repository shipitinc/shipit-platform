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

/// Optional port an [AgentExecutionDriver] may implement when the durable
/// [AgentResult] behind an execution is readable from the driver layer.
///
/// Kept OUT of [AgentExecutionDriver] on purpose: that contract is
/// implemented by scripted doubles across this repository and in test code
/// outside the worker packages, so widening it is a breaking change for
/// implementers nobody here may edit. A driver that does not implement this
/// port is simply one whose results are not readable from the worker — the
/// honest answer downstream is "no evidence", never a guess. The worker
/// consults it for exactly one thing: the provider-dead signature that
/// separates "the model quota was exhausted" from "the work hung".
abstract interface class AgentResultReader {
  /// The persisted result for [executionId], or null when none exists.
  Future<AgentResult?> resultFor(String executionId);
}

/// Default driver: forwards requests verbatim to [ExecutionCoordinator]. The
/// coordinator owns workflow-state transitions and durable execution records;
/// the driver adds no policy of its own.
class CoordinatorAgentExecutionDriver
    implements AgentExecutionDriver, AgentResultReader {
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

  @override
  Future<AgentResult?> resultFor(String executionId) =>
      _coordinator.store.readResult(executionId);
}

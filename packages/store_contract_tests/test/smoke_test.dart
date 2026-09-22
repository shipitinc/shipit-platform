import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:scheduler/scheduler.dart';
import 'package:store_contract_tests/store_contract_tests.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

/// Smoke test that proves the shared contract suites execute against the
/// in-memory store implementations. The same suite functions are re-run in
/// `apps/server` against the PostgreSQL stores.
void main() {
  runWorkflowStoreSuite(
    groupName: 'WorkflowStore contract (InMemory)',
    createStore: () async => InMemoryWorkflowStore(),
  );

  runJobStoreSuite(
    groupName: 'JobStore contract (InMemory)',
    createStore: () async => InMemoryJobStore(),
  );

  runWorkerStoreSuite(
    groupName: 'WorkerStore contract (InMemory)',
    createStore: () async => InMemoryWorkerStore(),
  );

  runExecutionStoreSuite(
    groupName: 'ExecutionStore contract (InMemory)',
    createStore: () async => InMemoryExecutionStore(),
  );

  runWorkerRegistrationSuite(
    groupName: 'WorkerRegistrationStore contract (InMemory)',
    createStore: () async => InMemoryWorkerRegistrationStore(),
  );

  runDesignGovernanceStoreSuite(
    groupName: 'DesignGovernanceStore contract (InMemory)',
    createStore: () async => InMemoryDesignGovernanceStore(),
  );
}

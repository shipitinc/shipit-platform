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
    // DECLARED DEVIATION, found by this suite and not yet fixed — the
    // implementor is in `packages/workflow_store`, which the lane that found
    // it may not edit. See WorkflowStoreContractDeviations for the one-line
    // fix. This declaration becomes STALE the moment the fix lands, and the
    // suite asserts that: it fails if the order is chronological anyway, so
    // the deviation cannot quietly outlive its own reason for existing.
    //
    // The PostgreSQL run declares NO deviations, so it is held to the strict
    // ordering the interface promises.
    deviations: const WorkflowStoreContractDeviations(
      operatorActionsNotChronological: true,
    ),
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

  // The in-memory half of the design contract store's contract. The durable
  // half needs a real database and lives with the other PostgreSQL
  // instantiations of these suites, under `apps/server/test/integration/`;
  // running only this side is a real gap, and it is the same gap every other
  // suite in this file has. Declared rather than implied: a suite with one
  // runner proves the contract, not the implementation's durability.
  runDesignContractStoreSuite(
    groupName: 'DesignContractStore contract (InMemory)',
    createStore: () async => InMemoryDesignContractStore(),
  );
}

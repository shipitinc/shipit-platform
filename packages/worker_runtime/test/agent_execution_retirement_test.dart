import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// The store-backed [AgentExecutionRetirement] is the half of the F-235 fix
/// that can reach `agent_execution` at all: `execution_coordinator` may not be
/// a dependency of the scheduler, so the composition root injects this
/// function and the reclaim calls it. These tests pin the contract the caller
/// relies on — close the open row atomically, and treat "already settled",
/// "no such row" and "lost the CAS" as correct outcomes rather than errors.
void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);
  final t1 = t0.add(const Duration(minutes: 90));

  AgentExecution execution({
    String id = 'agx-wx-1',
    AgentSessionStatus status = AgentSessionStatus.running,
    DateTime? completedAt,
    int version = 1,
  }) => AgentExecution(
    executionId: id,
    workItemId: 'wi-1',
    requestId: id,
    runtimeTypeId: 'fake-runtime',
    role: AgentRole.implementer,
    status: status,
    workspace: const AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws'),
    startedAt: t0,
    completedAt: completedAt,
    version: version,
  );

  test('the derived id is the rule LocalWorker produces', () {
    expect(agentExecutionIdForWorkerExecution('wx-jb-1'), 'agx-wx-jb-1');
    expect(
      agentExecutionIdForWorkerExecution('wx-jb-1:a2'),
      'agx-wx-jb-1:a2',
      reason: 'attempt-scoped worker ids derive the same way',
    );
  });

  test('a still-open row is driven terminal: orphaned, completedAt stamped, '
      'reason recorded, and the close leaves an audit event', () async {
    final store = InMemoryExecutionStore();
    await store.saveExecution(execution());

    await storeBackedAgentExecutionRetirement(store)(
      'agx-wx-1',
      now: t1,
      reason: 'zombie execution reclaimed: nothing is running behind it',
    );

    final closed = await store.readExecution('agx-wx-1');
    expect(closed.isTerminal, isTrue);
    expect(closed.status, AgentSessionStatus.orphaned);
    expect(closed.completedAt, t1);
    expect(
      closed.reason,
      'zombie execution reclaimed: nothing is running behind it',
    );
    expect(closed.version, 2);

    final events = await store.readEvents('agx-wx-1');
    expect(events, hasLength(1));
    expect(events.single.type, AgentEventType.executionFailed);
    expect(events.single.payload?['kind'], 'orphaned');
  });

  test('an already-terminal row is a no-op — re-reclaim is idempotent, never '
      'a double-close or a rewritten verdict', () async {
    final store = InMemoryExecutionStore();
    await store.saveExecution(
      execution(
        status: AgentSessionStatus.completed,
        completedAt: t0,
        version: 3,
      ),
    );

    final retire = storeBackedAgentExecutionRetirement(store);
    await retire('agx-wx-1', now: t1, reason: 'zombie execution reclaimed');

    final row = await store.readExecution('agx-wx-1');
    expect(row.status, AgentSessionStatus.completed);
    expect(row.completedAt, t0);
    expect(row.version, 3);
    expect(await store.readEvents('agx-wx-1'), isEmpty);

    // And invoking it again is equally inert.
    await retire('agx-wx-1', now: t1, reason: 'zombie execution reclaimed');
    expect((await store.readExecution('agx-wx-1')).version, 3);
  });

  test('a missing row is a no-op — the worker row is only linked on its '
      'terminal write, so a derived id may name nothing', () async {
    final store = InMemoryExecutionStore();
    await storeBackedAgentExecutionRetirement(store)(
      'agx-wx-never-wrote',
      now: t1,
      reason: 'zombie execution reclaimed',
    );
    expect(await store.listExecutions(), isEmpty);
  });

  test('losing the compare-and-swap is swallowed: a concurrent writer that '
      'settled the row first keeps its verdict', () async {
    final store = _CasLosingStore();
    await store.saveExecution(execution());

    // The CAS check inside the retirement sees version 1 -> writes with
    // expectedVersion 1, but this store always reports a lost race.
    await storeBackedAgentExecutionRetirement(store)(
      'agx-wx-1',
      now: t1,
      reason: 'zombie execution reclaimed',
    );

    // The row was never rewritten by the loser.
    final row = await store.readExecution('agx-wx-1');
    expect(row.status, AgentSessionStatus.running);
  });

  test('a store failure that is NOT a CAS loss propagates — the caller must '
      'not write a terminal job over a still-open row', () async {
    final store = _BrokenStore();
    await store.seed(execution());

    expect(
      () => storeBackedAgentExecutionRetirement(store)(
        'agx-wx-1',
        now: t1,
        reason: 'zombie execution reclaimed',
      ),
      throwsA(isA<StateError>()),
    );
  });
}

/// A store whose CAS always loses, as if a concurrent writer advanced the row
/// between the retirement's read and its write.
class _CasLosingStore extends InMemoryExecutionStore {
  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      throw ConcurrentExecutionModificationException(
        executionId: execution.executionId,
        expectedVersion: expectedVersion,
        actualVersion: expectedVersion + 1,
      );
    }
    await super.saveExecution(execution);
  }
}

/// A store that fails outright — the failure the caller must see rather than
/// record a terminal job above.
class _BrokenStore extends InMemoryExecutionStore {
  Future<void> seed(AgentExecution execution) => super.saveExecution(execution);

  @override
  Future<T> inTransaction<T>(Future<T> Function(ExecutionStore store) body) =>
      throw StateError('execution store unreachable');
}

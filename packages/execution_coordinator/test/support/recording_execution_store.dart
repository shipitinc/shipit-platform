import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// Records every `AgentExecution` row this store is asked to persist, in order.
///
/// The resurrection defect is INVISIBLE to a test that only reads the final
/// row: a late drive path writes `running` over a terminal `failed`, and then
/// the finalize error handler writes `failed` again, so the last state looks
/// correct while the row spent time non-terminal — which is exactly the window
/// a liveness probe reads, and exactly what made a dead execution report alive.
///
/// Asserting on the WRITE SEQUENCE is what makes this observable.
class RecordingExecutionStore extends InMemoryExecutionStore {
  final writes = <RecordedExecutionWrite>[];

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) async {
    writes.add(
      RecordedExecutionWrite(
        status: execution.status,
        isTerminal: execution.isTerminal,
        version: execution.version,
        hasCompletedAt: execution.completedAt != null,
        expectedVersion: expectedVersion,
      ),
    );
    await super.saveExecution(execution, expectedVersion: expectedVersion);
  }

  /// Every write after the first terminal one whose own status is NOT terminal.
  ///
  /// Empty means no row ever left a terminal state — the invariant under test.
  List<RecordedExecutionWrite> get resurrections => writes
      .asMap()
      .entries
      .where(
        (e) =>
            e.key > 0 &&
            e.value.isTerminal == false &&
            writes.sublist(0, e.key).any((w) => w.isTerminal),
      )
      .map((e) => e.value)
      .toList();
}

/// One durable write to an [AgentExecution] row.
class RecordedExecutionWrite {
  const RecordedExecutionWrite({
    required this.status,
    required this.isTerminal,
    required this.version,
    required this.hasCompletedAt,
    this.expectedVersion,
  });

  final AgentSessionStatus status;
  final bool isTerminal;
  final int version;
  final bool hasCompletedAt;
  final int? expectedVersion;

  /// Mirrors the reviewer's measurement format: `WRITE v<version> <status>
  /// completedAt=<bool>`.
  @override
  String toString() =>
      'WRITE v$version ${status.name} (terminal=$isTerminal) '
      'completedAt=$hasCompletedAt expectedVersion=$expectedVersion';
}

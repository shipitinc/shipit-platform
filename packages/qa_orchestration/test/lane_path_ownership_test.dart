import 'package:platform_contracts/platform_contracts.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

import 'support/e3_fixtures.dart';

/// THE LANE'S PATH-OWNERSHIP DECLARATION, AS THE GATE SEES IT.
///
/// ## WHAT THIS FILE MEASURES
///
/// F2 refuses a gate whose `ownedPathGlobs` is empty — by design, and before
/// any path is examined. The shipped contract therefore cannot be evaluated at
/// all, and the platform records a fault instead of a verdict.
///
/// Decision `4e1c9b52` says the missing input is the lane's declared owned
/// paths, and that persisting them supplies the input without re-tuning the
/// gate. This file measures that the input REACHES the gate:
///
///   1. a declared owned set turns a refused evaluation into a real one, and
///      the gate then judges the diff against the DECLARATION — a path inside
///      it passes;
///   2. a path outside the declaration fails, which is the confinement the
///      gate exists for and the demonstration the decision asks for;
///   3. a lane that declared nothing is still refused, with a readable reason —
///      the fail-closed direction, unchanged;
///   4. a service with no declaration source judges the contract's own
///      declaration, exactly as it did before this change.
///
/// ## WHAT IT DOES NOT CLAIM
///
/// It does not claim the gate's semantics changed. The evaluator's file is not
/// touched by this lane, and the comparison, the forbidden half and the refusal
/// are the shipped ones — this file only supplies the input the gate was
/// missing.
void main() {
  group('a declared owned set reaches the gate', () {
    test(
      'the evaluation runs, and a path inside the declaration passes',
      () async {
        final service = _service(
          contract: _contractWithOwnedSet(const []),
          declaration: const ['apps/server/**'],
          changedPaths: const ['apps/server/lib/server.dart'],
        );

        final outcome = await service.evaluateForWorkItem(
          workItemId: 'work-1',
          qaContractId: 'contract-1',
          agentResult: agentResultFor(workItemId: 'work-1'),
        );

        final result = outcome.results.single;
        expect(result.status, QAGateStatus.passed);
        expect(outcome.isOverallPass, isTrue);
      },
    );

    test('a path OUTSIDE the declaration fails the gate', () async {
      final service = _service(
        contract: _contractWithOwnedSet(const []),
        declaration: const ['apps/server/**'],
        changedPaths: const [
          'packages/qa_orchestration/lib/qa_orchestration.dart',
        ],
      );

      final outcome = await service.evaluateForWorkItem(
        workItemId: 'work-1',
        qaContractId: 'contract-1',
        agentResult: agentResultFor(workItemId: 'work-1'),
      );

      final result = outcome.results.single;
      expect(result.status, QAGateStatus.failed);
      expect(result.metadata?['reason'], contains('matches no owned glob'));
      expect(outcome.isOverallPass, isFalse);
    });

    test(
      'the FORBIDDEN half still applies, whatever the lane declared',
      () async {
        // The declaration supplies the owned set only. The static forbidden set
        // from decision `c3f81b04` is not the lane's to change, and a path the
        // lane declared as owned is still refused when it is forbidden.
        final service = _service(
          contract: _contractWithOwnedSet(const []),
          declaration: const ['**'],
          changedPaths: const ['AGENTS.md'],
        );

        final outcome = await service.evaluateForWorkItem(
          workItemId: 'work-1',
          qaContractId: 'contract-1',
          agentResult: agentResultFor(workItemId: 'work-1'),
        );

        expect(outcome.results.single.status, QAGateStatus.failed);
        expect(
          outcome.results.single.metadata?['reason'],
          contains('forbidden'),
        );
      },
    );
  });

  group('an undeclared lane is still refused', () {
    test(
      'an EMPTY declaration refuses the gate with a readable reason',
      () async {
        final service = _service(
          contract: _contractWithOwnedSet(const []),
          declaration: const [],
          changedPaths: const ['apps/server/lib/server.dart'],
        );

        await expectLater(
          service.evaluateForWorkItem(
            workItemId: 'work-1',
            qaContractId: 'contract-1',
            agentResult: agentResultFor(workItemId: 'work-1'),
          ),
          throwsA(
            isA<QAGateEvaluationFault>()
                .having(
                  (f) => f.reason,
                  'reason',
                  contains('could not be completed'),
                )
                .having(
                  (f) => f.reason,
                  'reason',
                  contains('declared no owned paths'),
                )
                .having((f) => f.cause, 'cause', isA<FormatException>()),
          ),
        );
      },
    );

    test('a service with NO declaration source judges the contract\'s own '
        'declaration', () async {
      // The behaviour before this change: the contract's own owned set is what
      // the gate reads. A contract that declares one is judged against it.
      final service = _service(
        contract: _contractWithOwnedSet(const ['apps/server/**']),
        declaration: null,
        changedPaths: const ['apps/server/lib/server.dart'],
      );

      final outcome = await service.evaluateForWorkItem(
        workItemId: 'work-1',
        qaContractId: 'contract-1',
        agentResult: agentResultFor(workItemId: 'work-1'),
      );

      expect(outcome.results.single.status, QAGateStatus.passed);
      expect(outcome.lanePathOwnership, isNull);
    });
  });

  group('the durable record says what was judged', () {
    test(
      'the record carries the declaration and the reader that supplied it',
      () async {
        final service = _service(
          contract: _contractWithOwnedSet(const []),
          declaration: const ['apps/server/**'],
          changedPaths: const ['apps/server/lib/server.dart'],
        );

        final outcome = await service.evaluateForWorkItem(
          workItemId: 'work-1',
          qaContractId: 'contract-1',
          agentResult: agentResultFor(workItemId: 'work-1'),
        );

        final record = outcome.toDurableRecord();
        final ownership = record['lanePathOwnership'] as Map<String, dynamic>;
        expect(ownership['declaredOwnedPaths'], ['apps/server/**']);
        final source = ownership['source'] as Map<String, dynamic>;
        expect(source['kind'], 'fixture');
        expect(source['sourceId'], 'test/_FixedDeclarationSource');
      },
    );

    test('an EMPTY declaration is recorded as empty, not omitted', () async {
      // "The lane declared nothing" is a fact about the run. It is recorded,
      // so a reader can tell it from a record that never carried one.
      final service = _service(
        contract: _contractWithOwnedSet(const ['apps/server/**']),
        declaration: const [],
        changedPaths: const ['apps/server/lib/server.dart'],
      );

      final outcome = await service.evaluateForWorkItem(
        workItemId: 'work-1',
        qaContractId: 'contract-1',
        agentResult: agentResultFor(workItemId: 'work-1'),
      );

      final ownership =
          outcome.toDurableRecord()['lanePathOwnership']
              as Map<String, dynamic>;
      expect(ownership['declaredOwnedPaths'], isEmpty);
    });
  });
}

/// A contract whose F2 gate declares [ownedSet].
///
/// The default — an empty owned set — is the SHIPPED shape, and the shape the
/// gate refuses. It is what the declaration has to supply.
QAContract _contractWithOwnedSet(List<String> ownedSet) {
  return QAContract(
    contractId: 'contract-1',
    workItemCategory: WorkItemCategory.feature,
    gates: [
      QAGateDefinition(
        gateId: 'feature-change-scope-confined',
        type: 'change-scope-confinement',
        required: true,
        config: <String, dynamic>{
          'ownedPathGlobs': ownedSet,
          'forbiddenPathGlobs': const ['AGENTS.md'],
          'pathSource': 'git_diff_name_only',
        },
        evidenceTypes: const ['committed_diff_paths'],
      ),
    ],
    version: '1',
    createdAt: DateTime.utc(2026, 10, 21),
    updatedAt: DateTime.utc(2026, 10, 21),
  );
}

/// The service under test.
///
/// [declaration] is `null` for "no declaration source wired" — the shape a
/// service assembled without one has.
QAGateEvaluationService _service({
  required QAContract contract,
  required List<String>? declaration,
  required List<String> changedPaths,
}) {
  final scopeSource = _FixedScopeSource(changedPaths);
  final registry = GateRegistry()
    ..register(ChangeScopeConfinementGate(source: scopeSource));
  return QAGateEvaluationService(
    orchestration: QAOrchestration(registry: registry),
    contractStore: _InMemoryContractStore(contract),
    declaredOwnedPathsSource: declaration == null
        ? null
        : _FixedDeclarationSource(declaration),
  );
}

/// A scope source that reports a fixed path set.
class _FixedScopeSource implements ChangeScopeSource {
  _FixedScopeSource(this.paths);

  final List<String> paths;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.fixture('test/_FixedScopeSource');

  @override
  Future<CommittedDiffScopeBaseline?> readBaseline(String workItemId) async {
    return const CommittedDiffScopeBaseline(
      workingDirectory: '/work/workspace',
      startingRevision: 'aaa111start',
    );
  }

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async {
    return const WorkspaceHead(
      startingRevision: 'aaa111start',
      headRevision: 'bbb222produced',
      headMoved: true,
    );
  }

  @override
  Future<CommittedDiffPaths> collectPaths({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  }) async {
    return CommittedDiffPaths(
      startingRevision: startingRevision,
      producedRevision: producedRevision,
      paths: paths,
    );
  }
}

/// A declaration source that always answers with the same set.
class _FixedDeclarationSource implements DeclaredOwnedPathsSource {
  _FixedDeclarationSource(this.globs);

  final List<String> globs;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.fixture('test/_FixedDeclarationSource');

  @override
  Future<List<String>> readDeclaredOwnedPaths(String workItemId) async => globs;
}

/// A contract store that holds one contract.
class _InMemoryContractStore implements QAContractStore {
  _InMemoryContractStore(this.contract);

  final QAContract contract;

  @override
  Future<void> saveQAContract(QAContract contract) async {}

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async => contract;

  @override
  Future<QAContract?> readQAContract(String contractId) async =>
      contract.contractId == contractId ? contract : null;

  @override
  Future<bool> hasQAContract(String contractId) async =>
      contract.contractId == contractId;

  @override
  Future<List<QAContract>> listQAContractsForWorkItem(
    String workItemId,
  ) async => [contract];

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async => [contract];
}

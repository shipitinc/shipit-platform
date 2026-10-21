import 'package:control_plane_server/src/persistence/postgres_defect_store.dart'
    show DefectNotFoundException;
import 'package:control_plane_server/src/qa/production_qa_sources.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show
        CommittedDiffEnumeration,
        CommittedDiffPathCollectionException,
        CommittedDiffPathCollector,
        ExecutionNotFoundException,
        ExecutionStore,
        WorkspaceDelta,
        WorkspaceDeltaProbe;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart' show WorkerStore;
import 'package:workflow_store/workflow_store.dart';

/// The PRODUCTION QA adapters: the six readers that replace the fail-closed
/// stand-ins slice 3c removed from `qa_orchestration`'s `lib/`.
///
/// ## WHAT EACH ADAPTER OWES THE PLATFORM
///
/// * **F1** (`ProductionArtifactProvenanceSource`) maps the platform probe's
///   answer onto `ExecutionDelta` field for field, and its `headMoved` stays
///   THREE-VALUED — `null` means "the probe declined to look", which is not
///   the same claim as "HEAD did not move".
/// * **F2** (`ProductionChangeScopeSource`) returns the collector's answer
///   VERBATIM: a failed enumeration surfaces as the collector's exception,
///   never as a shorter list and never as an empty one.
/// * **F4** (`ProductionPlatformVerificationReader`) reads the platform's own
///   verification rows.
/// * **F5** (`ProductionRevisionIdentitySource`) answers "which revision did
///   the review approve" from the human decision that approved the review,
///   and refuses rather than guessing.
/// * **R1** (`ProductionDefectRowReader`) turns "no such defect" into the
///   `null` the interface declares, so one missing row fails one gate instead
///   of aborting the evaluation.
/// * **R2** (`ProductionDefectEvidenceReader`) reads the defect's evidence.
///
/// ## WHY PROVENANCE IS ASSERTED HERE, PER ADAPTER
///
/// F-204: a persisted gate result that cannot say whether the platform or a
/// stand-in produced it is not an auditable record. The provenance is the
/// structured answer to that question, and it is asserted PER ADAPTER — not
/// once for the registry — because two production adapters reading the same
/// table are different readers with different failure modes, and a record that
/// says only "production" cannot say which one answered.
void main() {
  group('every production adapter declares its own production provenance', () {
    test('each adapter names itself, and none of them is a stand-in', () async {
      final resolver = await _resolver();
      final adapters = <String, QASourceProvenance>{
        'F1': ProductionArtifactProvenanceSource(resolver: resolver).provenance,
        'F2': ProductionChangeScopeSource(resolver: resolver).provenance,
        'F4': ProductionPlatformVerificationReader(
          executionStore: _FakeExecutionStore(),
        ).provenance,
        'F5': ProductionRevisionIdentitySource(
          workflowStore: InMemoryWorkflowStore(),
          workerStore: _FakeWorkerStore(),
          resolver: resolver,
        ).provenance,
        'R1': ProductionDefectRowReader(
          defectStore: _FakeDefectStore(),
        ).provenance,
        'R2': ProductionDefectEvidenceReader(
          defectStore: _FakeDefectStore(),
        ).provenance,
      };

      for (final entry in adapters.entries) {
        expect(
          entry.value.kind,
          QASourceKind.production,
          reason: '${entry.key} declares itself as a stand-in',
        );
        expect(entry.value.sourceId, isNotEmpty);
      }

      // Distinct ids: two readers of the same table are different readers.
      final ids = adapters.values.map((p) => p.sourceId).toSet();
      expect(
        ids.length,
        adapters.length,
        reason:
            'two adapters share a source id, so a record cannot say which '
            'of them answered: $ids',
      );
    });
  });

  group('F1 maps the platform probe without inventing a fact', () {
    test(
      'an unreadable delta stays unreadable, with the probe\'s reason',
      () async {
        // "I could not look" is not "looked and saw nothing". Folding the first
        // into the second is how a run that produced nothing reads as a run
        // that was never inspected — and F1's failure is the only thing standing
        // between a claim of production and a checkable fact.
        final source = ProductionArtifactProvenanceSource(
          resolver: await _resolver(),
          probe: _FakeProbe(
            const WorkspaceDelta.unreadable(
              'the worktree is not a git worktree',
            ),
          ),
        );

        final delta = await source.readDelta(_workItemId);

        expect(delta.isReadable, isFalse);
        expect(delta.unreadableReason, 'the worktree is not a git worktree');
        expect(delta.headMoved, isNull, reason: 'nobody read HEAD');
        expect(delta.startingRevision, isNull);
      },
    );

    test('a CLEAN tree that never moved reads as unchanged', () async {
      final source = ProductionArtifactProvenanceSource(
        resolver: await _resolver(),
        probe: _FakeProbe(
          const WorkspaceDelta.unchanged(
            startingRevision: 'f58d6fb1',
            headRevision: 'f58d6fb1',
          ),
        ),
      );

      final delta = await source.readDelta(_workItemId);

      expect(delta.isReadable, isTrue);
      expect(delta.worktreeDirty, isFalse);
      expect(delta.headMoved, isFalse);
      expect(delta.startingRevision, 'f58d6fb1');
      expect(delta.headRevision, 'f58d6fb1');
    });

    test(
      'a DIRTY tree keeps headMoved as NULL when HEAD was not read',
      () async {
        // The three-valued fact: `null` means "not established", `false` means
        // "established as no". The probe short-circuits on a dirty tree and
        // never reads HEAD, so the adapter must carry `null` across. Mapping it
        // to `false` would assert that HEAD did not move — a claim nobody made.
        final source = ProductionArtifactProvenanceSource(
          resolver: await _resolver(),
          probe: _FakeProbe(
            const WorkspaceDelta.changed(
              startingRevision: 'f58d6fb1',
              headRevision: null,
              changedPaths: ['lib/src/thing.dart'],
            ),
          ),
        );

        final delta = await source.readDelta(_workItemId);

        expect(delta.isReadable, isTrue);
        expect(delta.worktreeDirty, isTrue);
        expect(delta.headMoved, isNull);
        expect(delta.headRevision, isNull);
      },
    );

    test('a DIRTY tree that DID move keeps the truth of both halves', () async {
      final source = ProductionArtifactProvenanceSource(
        resolver: await _resolver(),
        probe: _FakeProbe(
          const WorkspaceDelta.changed(
            startingRevision: 'f58d6fb1',
            headRevision: 'cdffdbda',
            changedPaths: ['lib/src/thing.dart'],
            headMoved: true,
          ),
        ),
      );

      final delta = await source.readDelta(_workItemId);

      expect(delta.worktreeDirty, isTrue);
      expect(delta.headMoved, isTrue);
      expect(delta.headRevision, 'cdffdbda');
    });

    test('a CLEAN tree whose HEAD moved reads as COMMITTED', () async {
      // The implementer committed its own work: the tree is clean and HEAD is
      // no longer the baseline. That is production, and it is a different fact
      // from "the tree is dirty".
      final source = ProductionArtifactProvenanceSource(
        resolver: await _resolver(),
        probe: _FakeProbe(
          const WorkspaceDelta.committed(
            startingRevision: 'f58d6fb1',
            headRevision: 'cdffdbda',
          ),
        ),
      );

      final delta = await source.readDelta(_workItemId);

      expect(delta.isReadable, isTrue);
      expect(delta.worktreeDirty, isFalse);
      expect(delta.headMoved, isTrue);
      expect(delta.headRevision, 'cdffdbda');
    });

    test('a producer that cannot be identified reads as UNREADABLE', () async {
      // No producer means no worktree, so there is nothing to inspect. The
      // adapter must NOT read some other run's tree to fill the gap.
      final source = ProductionArtifactProvenanceSource(
        resolver: await _resolver(producerMissing: true),
        probe: _FakeProbe(
          const WorkspaceDelta.unchanged(
            startingRevision: 'f58d6fb1',
            headRevision: 'f58d6fb1',
          ),
        ),
      );

      final delta = await source.readDelta(_workItemId);

      expect(delta.isReadable, isFalse);
      expect(delta.unreadableReason, contains('could not be identified'));
    });
  });

  group('F2 hands back the collector\'s answer unchanged', () {
    test(
      'a failed enumeration surfaces as the collector\'s exception',
      () async {
        // The collector's contract is that a failed read THROWS, because there
        // is no `CommittedDiffPaths` that can carry "the enumeration failed" as
        // an empty list. An adapter that swallowed the exception and returned an
        // empty set would rebuild the vacuous pass F2 exists to prevent: "no
        // path is out of bounds" out of "no path could be read".
        final source = ProductionChangeScopeSource(
          resolver: await _resolver(),
          collector: _ThrowingCollector(),
        );

        expect(
          () => source.collectPaths(
            workingDirectory: '/tmp/workspaces/ws-1',
            startingRevision: 'f58d6fb1',
            producedRevision: 'cdffdbda',
          ),
          throwsA(isA<CommittedDiffPathCollectionException>()),
        );
      },
    );

    test('the paths the collector found are the paths the gate sees', () async {
      final source = ProductionChangeScopeSource(
        resolver: await _resolver(),
        collector: _StubCollector(
          CommittedDiffPaths(
            startingRevision: 'f58d6fb1',
            producedRevision: 'cdffdbda',
            paths: ['lib/a.dart', 'lib/b.dart'],
          ),
        ),
      );

      final paths = await source.collectPaths(
        workingDirectory: '/tmp/workspaces/ws-1',
        startingRevision: 'f58d6fb1',
        producedRevision: 'cdffdbda',
      );

      expect(paths.paths, ['lib/a.dart', 'lib/b.dart']);
    });

    test('a producer with NO BASELINE reads as no baseline at all', () async {
      // Without a starting revision there is no range to enumerate, and the
      // collector's own failure would be the wrong place to learn that: the
      // adapter can see the missing fact before the collector is asked.
      final source = ProductionChangeScopeSource(
        resolver: await _resolver(producerWithoutBaseline: true),
      );

      expect(await source.readBaseline(_workItemId), isNull);
    });

    test(
      'a producer with a baseline reads the WORKTREE and the baseline',
      () async {
        final source = ProductionChangeScopeSource(
          resolver: await _resolver(),
        );

        final baseline = await source.readBaseline(_workItemId);

        expect(baseline, isNotNull);
        expect(baseline!.workingDirectory, '/tmp/workspaces/ws-1');
        expect(baseline.startingRevision, 'f58d6fb1');
      },
    );
  });

  group('F4 reads the platform\'s own verification rows', () {
    test('the rows the platform recorded are the rows the gate sees', () async {
      // F4 compares the declared check's COMMAND string for string. A reader
      // that renamed, re-ordered or dropped a row would turn a declared check
      // into an unevidenced one, so the reader must return what the platform
      // stored — not a summary of it.
      final verification = PlatformVerification(
        verificationId: 'verification-1',
        executionId: 'exec-producer-1',
        workItemId: _workItemId,
        checkName: 'dart_format_repo_root',
        status: AgentClaimStatus.passed,
        mechanism: 'process_dart_format',
        command: 'dart format --output=none --set-exit-if-changed .',
        capturedAt: DateTime.utc(2026, 10, 21),
      );
      final reader = ProductionPlatformVerificationReader(
        executionStore: _FakeExecutionStore(
          verifications: [verification],
        ),
      );

      final rows = await reader.readVerifications('exec-producer-1');

      expect(rows, hasLength(1));
      expect(rows.single.checkName, 'dart_format_repo_root');
      expect(
        rows.single.command,
        'dart format --output=none --set-exit-if-changed .',
      );
    });

    test('an execution with no recorded checks reads as NO rows', () async {
      // "No rows" and "rows that failed" are different facts, and F4's
      // completeness check reads the first as a failure with its own reason.
      final reader = ProductionPlatformVerificationReader(
        executionStore: _FakeExecutionStore(),
      );

      expect(await reader.readVerifications('exec-producer-1'), isEmpty);
    });
  });

  group(
    'F5 answers "which revision did the review approve" without guessing',
    () {
      test('the APPROVED DECISION names the review, and that review names the '
          'revision', () async {
        final workerStore = _FakeWorkerStore([
          _workerExecution(
            id: 'worker-review-1',
            agentExecutionId: 'exec-review-1',
            endingRevision: 'cdffdbda',
          ),
          _workerExecution(
            id: 'worker-other',
            agentExecutionId: 'exec-other',
            endingRevision: 'aaaaaaaa',
          ),
        ]);
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveHumanDecision(
          _reviewDecision(reviewExecutionId: 'exec-review-1'),
        );

        final source = ProductionRevisionIdentitySource(
          workflowStore: workflowStore,
          workerStore: workerStore,
          resolver: await _resolver(),
        );

        expect(await source.readReviewedRevision('WI-1'), 'cdffdbda');
      });

      test(
        'with no decision, the REVIEWER EXECUTION is the fallback',
        () async {
          final workerStore = _FakeWorkerStore([
            _workerExecution(
              id: 'worker-review-1',
              agentExecutionId: 'exec-review-1',
              endingRevision: 'cdffdbda',
              capabilities: {WorkerCapability.engineeringReview},
            ),
          ]);

          final source = ProductionRevisionIdentitySource(
            workflowStore: InMemoryWorkflowStore(),
            workerStore: workerStore,
            resolver: await _resolver(),
          );

          expect(await source.readReviewedRevision('WI-1'), 'cdffdbda');
        },
      );

      test(
        'two reviewer executions that DISAGREE produce no answer at all',
        () async {
          // Two reviews of two different revisions exist. Picking the newest one
          // would be a guess dressed as a fact, and F5's `nullRevisionIsFailure`
          // turns "no answer" into a failure — which is the correct verdict for
          // "the platform cannot say which revision was reviewed".
          final workerStore = _FakeWorkerStore([
            _workerExecution(
              id: 'worker-review-1',
              agentExecutionId: 'exec-review-1',
              endingRevision: 'cdffdbda',
              capabilities: {WorkerCapability.engineeringReview},
            ),
            _workerExecution(
              id: 'worker-review-2',
              agentExecutionId: 'exec-review-2',
              endingRevision: 'deadbeef',
              capabilities: {WorkerCapability.engineeringReview},
            ),
          ]);

          final source = ProductionRevisionIdentitySource(
            workflowStore: InMemoryWorkflowStore(),
            workerStore: workerStore,
            resolver: await _resolver(),
          );

          expect(await source.readReviewedRevision('WI-1'), isNull);
        },
      );

      test('an execution with no ending revision produces no answer', () async {
        final workerStore = _FakeWorkerStore([
          _workerExecution(
            id: 'worker-review-1',
            agentExecutionId: 'exec-review-1',
            endingRevision: null,
            capabilities: {WorkerCapability.engineeringReview},
          ),
        ]);

        final source = ProductionRevisionIdentitySource(
          workflowStore: InMemoryWorkflowStore(),
          workerStore: workerStore,
          resolver: await _resolver(),
        );

        expect(await source.readReviewedRevision('WI-1'), isNull);
      });
    },
  );

  group('R1 treats a missing defect as a value, not as an exception', () {
    test('a defect that does not exist reads as null', () async {
      final reader = ProductionDefectRowReader(
        defectStore: _FakeDefectStore(throwNotFound: true),
      );

      expect(await reader.readDefect('defect-missing'), isNull);
    });

    test('a defect that exists reads as itself', () async {
      final reader = ProductionDefectRowReader(
        defectStore: _FakeDefectStore(defect: _defect()),
      );

      expect((await reader.readDefect('defect-1'))?.defectId, 'defect-1');
    });
  });

  group('R2 hands back the defect\'s own evidence', () {
    test(
      'the evidence the defect cites is the evidence the gate sees',
      () async {
        final reader = ProductionDefectEvidenceReader(
          defectStore: _FakeDefectStore(evidence: [_evidence()]),
        );

        final evidence = await reader.readDefectEvidence('defect-1');

        expect(evidence, hasLength(1));
        expect(evidence.single.evidenceId, 'evidence-1');
        expect(evidence.single.defectId, 'defect-1');
      },
    );

    test('a defect with no evidence reads as NO evidence', () async {
      final reader = ProductionDefectEvidenceReader(
        defectStore: _FakeDefectStore(),
      );

      expect(await reader.readDefectEvidence('defect-1'), isEmpty);
    });
  });

  group('the production registry is built over the production adapters', () {
    test('it registers all seven evaluators, and no fabricating one', () async {
      final registry = buildProductionGateRegistry(
        resolver: await _resolver(),
        executionStore: _FakeExecutionStore(),
        workerStore: _FakeWorkerStore(),
        workflowStore: InMemoryWorkflowStore(),
        defectStore: _FakeDefectStore(),
      );

      final types = registry.all.map((e) => e.gateType).toSet();
      expect(
        types,
        containsAll(<String>[
          'implementation-artifact-provenance',
          'change-scope-confinement',
          'declared-validation-outcome',
          'revision-identity-match',
          'triage-classification-structure',
          'triage-defect-existence',
          'triage-evidence-grounding',
        ]),
      );
      // The four fabricating evaluators were de-registered in M1; a gate that
      // produced a constant PASSING must not be reachable by any registry.
      expect(types, isNot(contains('static-analysis')));
      expect(types, isNot(contains('unit-tests')));
      expect(types, isNot(contains('security-scan')));
      expect(types, isNot(contains('performance')));
    });
  });
}

const _workItemId = 'WI-1';
const _producerExecutionId = 'exec-producer-1';

/// A resolver whose work item carries the producer stamp the platform's own
/// rule reads.
///
/// The stamp is `work_item.metadata['producerActorId']` — the same field the
/// coordinator stamps in the transition that put the item where it is, and
/// the same field `producedCommitFor` reads. The resolver therefore answers
/// the way the platform answers, and a test that depended on a different rule
/// would fail here rather than pass by accident.
Future<ProducerWorkspaceResolver> _resolver({
  bool producerMissing = false,
  bool producerWithoutBaseline = false,
}) async {
  final store = _FakeExecutionStore(
    executions: producerMissing
        ? const []
        : [
            AgentExecution(
              executionId: _producerExecutionId,
              workItemId: _workItemId,
              requestId: 'request-1',
              runtimeTypeId: 'runtime-1',
              role: AgentRole.implementer,
              status: AgentSessionStatus.completed,
              workspace: AgentWorkspace(
                workspaceId: 'ws-1',
                path: '/tmp/workspaces/ws-1',
                startingRevision: producerWithoutBaseline ? null : 'f58d6fb1',
              ),
            ),
          ],
    results: producerMissing
        ? const {}
        : {_producerExecutionId: _agentResult()},
  );
  final workflowStore = InMemoryWorkflowStore();
  final now = DateTime.utc(2026, 10, 21);
  await workflowStore.saveWorkItem(
    WorkItem(
      workItemId: _workItemId,
      productId: 'shipit-platform',
      category: WorkItemCategory.feature,
      title: 'A work item',
      state: WorkItemState.agentCompleted,
      metadata: {
        if (!producerMissing) 'producerActorId': _producerExecutionId,
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
  return ProducerWorkspaceResolver(
    executionStore: store,
    workflowStore: workflowStore,
  );
}

/// A probe that answers with a fixed delta, so the adapter's MAPPING is under
/// test rather than git's behaviour.
class _FakeProbe implements WorkspaceDeltaProbe {
  const _FakeProbe(this.delta);

  final WorkspaceDelta delta;

  @override
  Future<WorkspaceDelta> probe({
    required String workingDirectory,
    required String? startingRevision,
  }) async => delta;
}

/// A collector whose enumeration failed.
class _ThrowingCollector extends CommittedDiffPathCollector {
  const _ThrowingCollector();

  @override
  Future<CommittedDiffPaths> collect({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  }) async => throw const CommittedDiffPathCollectionException(
    enumeration: CommittedDiffEnumeration.committedRange,
    workingDirectory: '/tmp/workspaces/ws-1',
    reason: 'git exited 128',
  );
}

/// A collector that found a fixed set of paths.
class _StubCollector extends CommittedDiffPathCollector {
  const _StubCollector(this.paths);

  final CommittedDiffPaths paths;

  @override
  Future<CommittedDiffPaths> collect({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  }) async => paths;
}

AgentResult _agentResult() {
  return AgentResult(
    resultId: 'result-1',
    sessionId: 'session-1',
    workItemId: _workItemId,
    status: AgentResultStatus.completed,
    artifacts: const [],
    diagnostics: const AgentDiagnostics(
      exitCode: 0,
      durationMs: 1,
      toolCalls: 0,
      errors: [],
      warnings: [],
    ),
    structuredResult: const {'classification': 'implementation_defect'},
    completedAt: DateTime.utc(2026, 10, 21),
  );
}

WorkerExecution _workerExecution({
  required String id,
  required String agentExecutionId,
  required String? endingRevision,
  Set<WorkerCapability> capabilities = const {},
}) {
  return WorkerExecution(
    workerExecutionId: id,
    workItemId: _workItemId,
    repositoryPath: '/tmp/repos/clone',
    requestedStartingRevision: 'f58d6fb1',
    requiredCapabilities: capabilities,
    status: WorkerExecutionStatus.executedPass,
    cleanupPolicy: WorkerCleanupPolicy.removeAlways,
    agentExecutionId: agentExecutionId,
    endingRevision: endingRevision,
  );
}

HumanDecision _reviewDecision({required String reviewExecutionId}) {
  return HumanDecision(
    decisionId: 'decision-1',
    workItemId: _workItemId,
    decisionType: HumanDecisionType.engineeringReview,
    status: HumanDecisionStatus.resolved,
    choice: HumanDecisionChoice.approve,
    decider: 'human-1',
    metadata: {'reviewExecutionId': reviewExecutionId},
    updatedAt: DateTime.utc(2026, 10, 21),
  );
}

Defect _defect() {
  final now = DateTime.utc(2026, 10, 21);
  return Defect(
    defectId: 'defect-1',
    title: 'A defect',
    description: 'A defect with a body',
    severity: 'medium',
    status: DefectStatus.reported,
    classification: DefectClassification.implementationDefect,
    reporter: 'the triage lane',
    productId: 'shipit-platform',
    createdAt: now,
    updatedAt: now,
    version: 1,
  );
}

/// An [ExecutionStore] that holds a few executions and their results.
///
/// The members the adapters do not call are answered by [noSuchMethod], which
/// throws — so a test that starts depending on one fails loudly instead of
/// silently reading `null`.
class _FakeExecutionStore implements ExecutionStore {
  _FakeExecutionStore({
    this.executions = const [],
    this.results = const {},
    this.verifications = const [],
  });

  final List<AgentExecution> executions;
  final Map<String, AgentResult> results;
  final List<PlatformVerification> verifications;

  @override
  Future<AgentExecution?> readExecutionOrNull(String executionId) async {
    for (final execution in executions) {
      if (execution.executionId == executionId) return execution;
    }
    return null;
  }

  @override
  Future<AgentExecution> readExecution(String executionId) async {
    final execution = await readExecutionOrNull(executionId);
    if (execution == null) {
      throw ExecutionNotFoundException(executionId);
    }
    return execution;
  }

  @override
  Future<List<AgentExecution>> listExecutions({String? workItemId}) async {
    if (workItemId == null) return executions;
    return executions.where((e) => e.workItemId == workItemId).toList();
  }

  @override
  Future<AgentResult?> readResult(String executionId) async =>
      results[executionId];

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async => verifications;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [WorkerStore] that holds a few worker executions.
class _FakeWorkerStore implements WorkerStore {
  _FakeWorkerStore([this.executions = const []]);

  final List<WorkerExecution> executions;

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() async => executions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DefectEvidence _evidence() {
  final now = DateTime.utc(2026, 10, 21);
  return DefectEvidence(
    evidenceId: 'evidence-1',
    defectId: 'defect-1',
    kind: EvidenceIntakeKind.screenshot,
    description: 'the screenshot that shows the defect',
    capturedAt: now,
    createdAt: now,
  );
}

/// A [DefectStore] that holds one defect, or refuses to.
class _FakeDefectStore implements DefectStore {
  _FakeDefectStore({
    this.defect,
    this.throwNotFound = false,
    this.evidence = const [],
  });

  final Defect? defect;
  final bool throwNotFound;
  final List<DefectEvidence> evidence;

  @override
  Future<Defect> readDefect(String defectId) async {
    if (throwNotFound) throw DefectNotFoundException(defectId);
    final held = defect;
    if (held == null) throw DefectNotFoundException(defectId);
    return held;
  }

  @override
  Future<List<DefectEvidence>> readEvidenceForDefect(String defectId) async =>
      evidence;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

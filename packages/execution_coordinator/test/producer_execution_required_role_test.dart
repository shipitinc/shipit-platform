import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// THE ROOT-CAUSE PROOF for F-253: a `qa-triage-*` contract was evaluated
/// against the wrong execution's `structuredResult`.
///
/// `resolveProducerExecution` was contract-blind: a stamped `producerActorId`
/// won outright, and the fallback was the newest IMPLEMENTER execution. A
/// defect item that went through a rework cycle (approve -> implement ->
/// contract fails -> waiver -> reject -> re-implement) carries both a
/// TRIAGE_DEFECT execution and a newer IMPLEMENTER execution, and the
/// implementer's completion re-stamps `producerActorId` — so every
/// `qa-triage-*` evaluation after a rework read the IMPLEMENTER's result.
/// Its gates (`triage-classification-admitted`,
/// `triage-evidence-grounded`) then failed a result carrying no triage
/// fields even though the triage output was correct.
///
/// The fix is the `requiredRole` scope: the caller declares which role's
/// output the contract judges, and the resolution reads the newest
/// execution OF THAT ROLE — still preferring the stamp when it names an
/// execution of the declared role.
///
/// ## WHAT IS ASSERTED
///
///  * A `qa-triage` scope resolves the TRIAGE execution even when the stamp
///    names a NEWER implementer — the live defect's exact shape.
///  * A stamp naming an execution OF the required role still wins — the
///    co-written identity is not discarded when it is the right one.
///  * With no stamp, the newest execution of the required role is taken —
///    never the newest of any other role.
///  * An item with no execution of the required role refuses, rather than
///    handing back some other role's result.
///  * The unscoped rule is unchanged (asserted in
///    `producer_execution_resolution_test.dart`).
void main() {
  late InMemoryExecutionStore store;

  setUp(() => store = InMemoryExecutionStore());

  final t0 = DateTime.utc(2026, 1, 1);

  Future<void> put({
    required String id,
    required AgentRole role,
    required Duration after,
    AgentResultStatus resultStatus = AgentResultStatus.completed,
    Map<String, dynamic> structuredResult = const {},
  }) async {
    await store.saveExecution(
      AgentExecution(
        executionId: id,
        workItemId: 'wi-1',
        requestId: id,
        runtimeTypeId: 'fake',
        role: role,
        status: AgentSessionStatus.completed,
        workspace: AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws-1'),
        startedAt: t0.add(after),
        version: 1,
      ),
    );
    await store.saveResult(
      id,
      AgentResult(
        resultId: 'res-$id',
        sessionId: 'ses-$id',
        workItemId: 'wi-1',
        status: resultStatus,
        artifacts: const [],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 1,
          toolCalls: 0,
          errors: [],
          warnings: [],
        ),
        structuredResult: structuredResult,
        completedAt: t0.add(after),
      ),
    );
  }

  /// The live defect's rows: a triage execution first, an implementer
  /// rework after — and the stamp pointing at the implementer.
  Future<void> reworkedDefectItem() async {
    await put(
      id: 'exec-triage',
      role: AgentRole.triageDefect,
      after: const Duration(minutes: 1),
      structuredResult: const {
        'classification': 'implementation_defect',
        'status': 'reported',
        'confidence': 0.9,
        'suspectedCategory': 'documentation',
        'evidenceUsed': ['EVD-DEF-1-1'],
      },
    );
    await put(
      id: 'exec-impl',
      role: AgentRole.implementer,
      after: const Duration(minutes: 2),
      structuredResult: const {'summary': 'reworked the defect fix'},
    );
  }

  group('a contract-scoped resolution', () {
    test('a stamp naming the IMPLEMENTER resolves the TRIAGE execution when '
        'the contract judges triage output — the F-253 rows', () async {
      await reworkedDefectItem();

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: 'exec-impl',
        requiredRole: AgentRole.triageDefect,
      );

      expect(resolved.how, ProducerResolution.requiredRole);
      expect(
        resolved.executionId,
        'exec-triage',
        reason:
            'a qa-triage contract evaluates the TRIAGE result. The stamp '
            'correctly names who completed the item last — the '
            'implementer — which is the wrong producer for this contract, '
            'and handing its result to triage gates is the defect',
      );
      expect(
        resolved.result?.structuredResult['classification'],
        'implementation_defect',
        reason: 'the result under evaluation is the triage classification',
      );
    });

    test('a stamp naming an execution OF the required role still wins over '
        'the role fallback', () async {
      await put(
        id: 'exec-triage',
        role: AgentRole.triageDefect,
        after: const Duration(minutes: 1),
        structuredResult: const {
          'classification': 'implementation_defect',
          'status': 'reported',
          'confidence': 0.9,
          'suspectedCategory': 'documentation',
        },
      );

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: 'exec-triage',
        requiredRole: AgentRole.triageDefect,
      );

      expect(resolved.how, ProducerResolution.stampedProducer);
      expect(resolved.executionId, 'exec-triage');
    });

    test('with no stamp, the newest execution OF THE REQUIRED ROLE is taken — '
        'never the newest of any other role', () async {
      await reworkedDefectItem();
      await put(
        id: 'exec-review',
        role: AgentRole.engineeringReviewer,
        after: const Duration(minutes: 3),
      );

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: null,
        requiredRole: AgentRole.triageDefect,
      );

      expect(resolved.how, ProducerResolution.requiredRole);
      expect(
        resolved.executionId,
        'exec-triage',
        reason:
            'the newest row of ANY role here is the reviewer; the '
            'required-role rule must skip it AND the newer implementer',
      );
    });

    test(
      'the newest of SEVERAL executions of the required role is taken',
      () async {
        await put(
          id: 'exec-triage-1',
          role: AgentRole.triageDefect,
          after: const Duration(minutes: 1),
        );
        await put(
          id: 'exec-impl',
          role: AgentRole.implementer,
          after: const Duration(minutes: 2),
        );
        await put(
          id: 'exec-triage-2',
          role: AgentRole.triageDefect,
          after: const Duration(minutes: 3),
          structuredResult: const {
            'classification': 'environment_issue',
            'status': 'reported',
            'confidence': 0.7,
            'suspectedCategory': 'tooling',
          },
        );

        final resolved = await resolveProducerExecution(
          store: store,
          workItemId: 'wi-1',
          producerActorId: 'exec-impl',
          requiredRole: AgentRole.triageDefect,
        );

        expect(resolved.executionId, 'exec-triage-2');
        expect(
          resolved.result?.structuredResult['classification'],
          'environment_issue',
        );
      },
    );

    test(
      'a stamp naming an execution of another role resolves by role even '
      'when the stamp names IMPLEMENTER and the required role IS '
      'implementer on a different item — symmetric for any declared role',
      () async {
        // A product contract judging implementer output: a stale stamp
        // naming the triage execution must not hand the triage result to
        // gates about the implementation.
        await reworkedDefectItem();

        final resolved = await resolveProducerExecution(
          store: store,
          workItemId: 'wi-1',
          producerActorId: 'exec-triage',
          requiredRole: AgentRole.implementer,
        );

        expect(resolved.how, ProducerResolution.requiredRole);
        expect(resolved.executionId, 'exec-impl');
      },
    );

    test('a dangling stamp falls to the role fallback rather than refusing, '
        'because the required-role question is still answerable', () async {
      await put(
        id: 'exec-triage',
        role: AgentRole.triageDefect,
        after: const Duration(minutes: 1),
      );

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: 'exec-vanished',
        requiredRole: AgentRole.triageDefect,
      );

      expect(resolved.how, ProducerResolution.requiredRole);
      expect(
        resolved.executionId,
        'exec-triage',
        reason:
            'the stamp names nothing, but the contract asks for the '
            'TRIAGE execution specifically and that row exists — '
            'answering it is not guessing at a producer',
      );
    });
  });

  group('refusal', () {
    test('an item with NO execution of the required role refuses — some '
        'other role\'s result is never substituted', () async {
      await put(
        id: 'exec-impl',
        role: AgentRole.implementer,
        after: const Duration(minutes: 1),
      );

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: 'exec-impl',
        requiredRole: AgentRole.triageDefect,
      );

      expect(resolved.how, ProducerResolution.none);
      expect(resolved.isResolved, isFalse);
      expect(resolved.result, isNull);
      expect(resolved.note, contains('TRIAGE_DEFECT'));
    });

    test('the required-role fallback also skips a required-role execution '
        'that exists but is not the newest', () async {
      await put(
        id: 'exec-triage-old',
        role: AgentRole.triageDefect,
        after: const Duration(minutes: 1),
        structuredResult: const {
          'classification': 'duplicate',
          'status': 'reported',
          'confidence': 0.5,
          'suspectedCategory': 'unknown',
        },
      );
      await put(
        id: 'exec-triage-new',
        role: AgentRole.triageDefect,
        after: const Duration(minutes: 2),
      );

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: null,
        requiredRole: AgentRole.triageDefect,
      );

      expect(resolved.executionId, 'exec-triage-new');
    });
  });
}

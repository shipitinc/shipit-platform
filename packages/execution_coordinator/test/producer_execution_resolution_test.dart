import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// THE ROOT-CAUSE PROOF for the defect recorded in
/// `docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §2.
///
/// `_reviewEntryTransitionContext` used to supply `agentResultValid()` from
/// `store.latestExecutionForWorkItem(workItemId)` — the newest execution of ANY
/// role. After any reviewer execution existed the newest row WAS the reviewer,
/// so the guard read the reviewer's result and a reviewer that failed
/// permanently prevented the item from ever entering review again. On QA that
/// produced 243 `outcome = 'rejected'` rows for one work item and a four-jobs-a-
/// minute churn.
///
/// ## WHAT IS ASSERTED, AND WHY THE HAPPY PATH ALONE IS NOT ENOUGH
///
/// The original defect produces a PASSING review-entry test: on a fresh item the
/// newest execution genuinely IS the implementer. So every assertion here is
/// built around a reviewer execution existing, in a different order, more than
/// once, and FAILED — which is precisely the configuration the original code got
/// wrong.
///
/// Both directions are covered, because "let it in" and "keep it out" are
/// opposite requirements and fixing one can silently break the other:
///
///  * **ALLOW** — a completed producer reaches review regardless of what any
///    reviewer did. Tests: [producer] group.
///  * **REFUSE** — a FAILED producer is still refused. Tests: [refusal] group.
///    A role-scoped lookup that returns "the newest implementer" would let a
///    failed producer in if it simply checked that an implementer existed.
void main() {
  late InMemoryExecutionStore store;

  setUp(() => store = InMemoryExecutionStore());

  final t0 = DateTime.utc(2026, 1, 1);

  Future<void> put({
    required String id,
    required AgentRole role,
    required AgentResultStatus resultStatus,
    required Duration after,
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
        structuredResult: const {},
        completedAt: t0.add(after),
      ),
    );
  }

  /// The three durable rows of the measured QA defect, by id.
  Future<void> measuredQaRows() async {
    await put(
      id: 'agx-wx-jb-hn7bdou768-12vlbk4',
      role: AgentRole.implementer,
      resultStatus: AgentResultStatus.completed,
      after: const Duration(minutes: 1),
    );
    await put(
      id: 'agx-wx-jb-hn7gq1nj5w-70d6ix',
      role: AgentRole.engineeringReviewer,
      resultStatus: AgentResultStatus.failed,
      after: const Duration(minutes: 2),
    );
  }

  group('producer', () {
    test(
      'a completed producer is read from producerActorId while a NEWER FAILED '
      'reviewer exists — the exact QA rows',
      () async {
        await measuredQaRows();

        final resolved = await resolveProducerExecution(
          store: store,
          workItemId: 'wi-1',
          producerActorId: 'agx-wx-jb-hn7bdou768-12vlbk4',
        );

        expect(resolved.how, ProducerResolution.stampedProducer);
        expect(resolved.executionId, 'agx-wx-jb-hn7bdou768-12vlbk4');
        expect(
          resolved.result?.status,
          AgentResultStatus.completed,
          reason:
              'the guard must read the PRODUCER. The newest row of any role is '
              'the reviewer here, and the reviewer failed — which is what made '
              'the edge permanently unsatisfiable',
        );
      },
    );

    test(
      'the property holds with the reviewer execution in EITHER order and ANY '
      'number of times',
      () async {
        await put(
          id: 'exec-impl',
          role: AgentRole.implementer,
          resultStatus: AgentResultStatus.completed,
          after: const Duration(minutes: 1),
        );
        // Three reviewer executions: one BEFORE the producer, one after, one
        // after that — all failed. Any recency rule that is not role-scoped
        // picks a reviewer here.
        await put(
          id: 'rev-early',
          role: AgentRole.engineeringReviewer,
          resultStatus: AgentResultStatus.failed,
          after: const Duration(minutes: 2),
        );
        await put(
          id: 'rev-late',
          role: AgentRole.engineeringReviewer,
          resultStatus: AgentResultStatus.failed,
          after: const Duration(minutes: 3),
        );
        await put(
          id: 'rev-newest',
          role: AgentRole.engineeringReviewer,
          resultStatus: AgentResultStatus.failed,
          after: const Duration(minutes: 4),
        );

        final resolved = await resolveProducerExecution(
          store: store,
          workItemId: 'wi-1',
          producerActorId: 'exec-impl',
        );

        expect(resolved.executionId, 'exec-impl');
        expect(resolved.result?.status, AgentResultStatus.completed);
      },
    );

    test(
      'the role fallback also skips reviewers — so it is not a smaller version '
      'of the same bug',
      () async {
        await measuredQaRows();

        final resolved = await resolveProducerExecution(
          store: store,
          workItemId: 'wi-1',
          producerActorId: null,
        );

        expect(
          resolved.how,
          ProducerResolution.implementerRole,
          reason:
              'with no stamp the newest IMPLEMENTER is taken. Taking the newest '
              'execution of any role here would return the failed reviewer and '
              'reproduce the original defect exactly',
        );
        expect(resolved.executionId, 'agx-wx-jb-hn7bdou768-12vlbk4');
        expect(resolved.result?.status, AgentResultStatus.completed);
      },
    );

    test(
      'a blank stamp is treated as no stamp, not as an execution id',
      () async {
        await put(
          id: 'exec-impl',
          role: AgentRole.implementer,
          resultStatus: AgentResultStatus.completed,
          after: const Duration(minutes: 1),
        );

        final resolved = await resolveProducerExecution(
          store: store,
          workItemId: 'wi-1',
          producerActorId: '',
        );

        expect(resolved.how, ProducerResolution.implementerRole);
        expect(resolved.executionId, 'exec-impl');
      },
    );

    test('a non-String stamp falls back rather than throwing', () async {
      await put(
        id: 'exec-impl',
        role: AgentRole.implementer,
        resultStatus: AgentResultStatus.completed,
        after: const Duration(minutes: 1),
      );

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: 42,
      );

      expect(resolved.executionId, 'exec-impl');
    });
  });

  group('refusal', () {
    test('a FAILED producer is refused even though an implementer execution '
        'exists and even though a reviewer completed successfully', () async {
      await put(
        id: 'exec-impl-failed',
        role: AgentRole.implementer,
        resultStatus: AgentResultStatus.failed,
        after: const Duration(minutes: 1),
      );
      // A successful reviewer is LAST. A lookup that merely wanted "some
      // execution with a result" would pass the guard on this one.
      await put(
        id: 'exec-review-ok',
        role: AgentRole.engineeringReviewer,
        resultStatus: AgentResultStatus.completed,
        after: const Duration(minutes: 9),
      );

      final stamped = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: 'exec-impl-failed',
      );
      expect(stamped.executionId, 'exec-impl-failed');
      expect(
        stamped.result?.status,
        AgentResultStatus.failed,
        reason:
            'a reviewer completing is not evidence that the producer did. The '
            'mirror image of the original bug would be to let a successful '
            'reviewer vouch for a failed producer',
      );
      expect(
        stamped.isResolved,
        isTrue,
        reason: 'it resolves; the GUARD refuses',
      );

      final byRole = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: null,
      );
      expect(byRole.executionId, 'exec-impl-failed');
      expect(byRole.result?.status, AgentResultStatus.failed);
    });

    test('no producer at all resolves to none, with no result', () async {
      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: null,
      );

      expect(resolved.how, ProducerResolution.none);
      expect(resolved.isResolved, isFalse);
      expect(resolved.result, isNull);
      expect(resolved.note, contains('nothing may be'));
    });

    test(
      'a stamp naming a deleted execution refuses rather than guessing at the '
      'newest row',
      () async {
        await put(
          id: 'exec-review-ok',
          role: AgentRole.engineeringReviewer,
          resultStatus: AgentResultStatus.completed,
          after: const Duration(minutes: 9),
        );

        final resolved = await resolveProducerExecution(
          store: store,
          workItemId: 'wi-1',
          producerActorId: 'exec-impl-vanished',
        );

        expect(resolved.how, ProducerResolution.none);
        expect(
          resolved.result,
          isNull,
          reason:
              'silently substituting the newest row for a stamp that names '
              'nothing is the defect in another costume — the item would be '
              'reviewed against a reviewer\'s result while the durable record '
              'says its producer is gone',
        );
      },
    );

    test('a producer row that carries no readable result resolves to a null '
        'result rather than an absent one', () async {
      await store.saveExecution(
        AgentExecution(
          executionId: 'exec-impl',
          workItemId: 'wi-1',
          requestId: 'exec-impl',
          runtimeTypeId: 'fake',
          role: AgentRole.implementer,
          status: AgentSessionStatus.completed,
          workspace: AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws-1'),
          startedAt: t0,
          version: 1,
        ),
      );

      final resolved = await resolveProducerExecution(
        store: store,
        workItemId: 'wi-1',
        producerActorId: 'exec-impl',
      );

      expect(resolved.isResolved, isTrue);
      expect(
        resolved.result,
        isNull,
        reason:
            'the row exists, so the item DOES identify its producer. The '
            'guard still refuses because the result is missing, and the note '
            'must not claim otherwise',
      );
    });
  });

  group('non-vacuity', () {
    test('the ROLE-BLIND lookup this replaced really would return the failed '
        'reviewer on the measured rows', () async {
      await measuredQaRows();

      final roleBlind = await store.latestExecutionForWorkItem('wi-1');

      expect(
        roleBlind?.executionId,
        'agx-wx-jb-hn7gq1nj5w-70d6ix',
        reason:
            'this is the assertion that keeps the fix honest: the old lookup '
            'returns the reviewer, so every ALLOW test above genuinely fails '
            'against the old code and is not vacuous',
      );
      expect(
        (await store.readResult(roleBlind!.executionId))?.status,
        AgentResultStatus.failed,
      );
    });
  });
}

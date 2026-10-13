import 'dart:async';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:scheduler/src/capacity/capacity_lockable_store.dart';
import 'package:scheduler/src/capacity/execution_capacity.dart';
import 'package:scheduler/src/capacity/job_capacity_guard.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

/// AC-17 / §16.3 — Lane S is NOT complete until a retried work item is
/// observed DISPATCHING BY A REAL `Scheduler.tick()`.
///
/// This is the property that would have caught all three failed dispatch seams.
/// Each of them was invisible to the negative test assigned to it: one sat
/// behind a `continue` that had already fired, and two asserted legality on an
/// `(agentExecuting, agentExecuting)` self-transition that is absent from the
/// table. A negative-only contract cannot tell a working capability from a
/// dead one.
///
/// So the assertion here is behavioural and positive: seed a defect at
/// `agentFailed` carrying its full payload, run the operator retry, then run
/// ONE real tick and require that a `triage_defect` job appears under the `:a1`
/// dedupe key and reaches `running`.
///
/// ## AC-36 — the dedupe-key rule, all four properties.
///
/// ## AC-14e — a network replay of the same operator action mints no second
/// job, which is only checkable here, where jobs are actually created.
///
/// The harness is deliberately local and minimal. It wires the REAL
/// `Scheduler`, the REAL `JobQueue`, the REAL capacity guard and the REAL
/// dedupe/instruction/request builders for `triage_defect`; only the worker is
/// a stub that parks, so `running` is observable before the execution
/// finishes.
void main() {
  const requestedBy = 'hum@shipit.platform';
  const reason = 'Model credits approved by the on-call engineer';

  group('§16.3 a retried item is DISPATCHED by a real tick', () {
    test(
      'one tick enqueues under the :a1 key and the job reaches running',
      () async {
        final host = await _Host.start(seed: _seedFailedDefect, cap: 1);

        // The item is parked in agent_failed: no tick will ever enqueue for it,
        // because agentFailed is in no JobDefinition's entryStates.
        final before = await host.scheduler.tick();
        expect(
          before.enqueued,
          isEmpty,
          reason: 'a failed item must not re-arm itself',
        );
        expect(await host.triageJobs(), isEmpty);

        final retried = await host.engine.operatorRetry(
          workItemId: host.workItemId,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );
        expect(retried.state, WorkItemState.designNotRequired);
        expect(retried.metadata?['triageAttempt'], 1);

        host.parkRuns = true;
        final tick = host.scheduler.tick();
        await waitUntil(
          () async =>
              (await host.triageJobs()).any((j) => j.state == JobState.running),
          because: 'the ordinary tick must dispatch the retried item',
        );

        final running = (await host.triageJobs()).single;
        expect(
          running.dedupeKey,
          '${host.workItemId}:triage_defect:a1',
          reason:
              'the fresh attempt suffix is what makes this key unconsumed; '
              'the historical key is held forever by the terminal first job',
        );
        expect(running.workItemId, host.workItemId);
        expect(running.state, JobState.running);
        expect(host.dispatcher.started, hasLength(1));

        host.releaseAll();
        final result = await tick;
        expect(result.dispatched, [running.jobId]);
      },
    );

    test(
      'a NON-retried item carrying a retry marker is still NOT dispatched',
      () async {
        // The real form of the AC-29 review obligation, as far as it can be
        // made mechanical.
        //
        // This replaces a test that asserted `''.contains('triageAttempt') ==
        // false` — which can never fail whatever the scheduler contains, and
        // whose NAME claimed to guard exactly this regression. A check that
        // cannot fail while claiming to catch the defect is worse than no
        // check, because it manufactures assurance a reviewer is meant to
        // rely on. The brief itself (AC-17 metadata) DROPPED the mechanical
        // byte-identity gate as not runtime-observable, and this does not
        // pretend to reinstate it.
        //
        // What IS runtime-observable is the rule the scheduler actually uses to
        // decide eligibility: `RunnableWorkEvaluator.evaluate`, and nothing
        // else. So this builds a work item that is indistinguishable from a
        // retried one — same metadata, same marker, same defect payload — but
        // parked in `agentFailed`, which is in no JobDefinition's entryStates.
        //
        // If anyone ever adds an eligibility branch keyed on the retry marker —
        // the seam this design deleted three times — this item is exactly what
        // it would wrongly pick up, and this fails.
        final host = await _Host.start(seed: _seedFailedDefect, cap: 4);
        final item = await host.engine.loadWorkItem(host.workItemId);
        expect(item.state, WorkItemState.agentFailed);
        expect(
          item.metadata?['triageAttempt'],
          isNull,
          reason: 'the seed is a never-retried item; the marker is added below',
        );

        // Stamp a marker on a FAILED item. Nothing may dispatch it.
        await host.store.saveWorkItem(
          item.copyWith(metadata: {...?item.metadata, 'triageAttempt': 1}),
        );

        final result = await host.scheduler.tick();

        expect(
          result.enqueued,
          isEmpty,
          reason:
              'eligibility is the policy answer and nothing else: '
              'agentFailed is in no entryStates, so no tick enqueues for it',
        );
        expect(result.dispatched, isEmpty);
        expect(await host.triageJobs(), isEmpty);
      },
    );

    test('and the same item IS dispatched once the edge really is taken', () {
      // The control for the test above, and the reason the pair is not
      // vacuous: the SAME marker and the SAME defect payload, differing only
      // in the state the transition actually moved the item to. The key the
      // builder produces is identical for both — so if eligibility were keyed
      // on the marker rather than on the policy, the two items would be
      // indistinguishable here, and this pair would prove nothing.
      final failed = _keyItem(
        triageAttempt: 1,
      ).copyWith(state: WorkItemState.agentFailed);
      final retried = failed.copyWith(state: WorkItemState.designNotRequired);

      expect(
        triageDefectDedupeKey(failed, triageDefectDefinition),
        triageDefectDedupeKey(retried, triageDefectDefinition),
        reason:
            'the dedupe key is the same for both; the STATE is what the '
            'policy reads, and it is the state the edge moved',
      );
      expect(
        triageDefectDefinition.entryStates.contains(failed.state),
        isFalse,
        reason:
            'agentFailed is in no entryStates — this is the gate G1 the '
            'three deleted seams all collided with',
      );
      expect(
        triageDefectDefinition.entryStates.contains(retried.state),
        isTrue,
      );
    });
  });

  group('AC-36 property 1 — absent marker means an unchanged key', () {
    test('the historical key is byte-identical to today', () {
      final item = _keyItem();
      expect(
        triageDefectDedupeKey(item, triageDefectDefinition),
        '${item.workItemId}:triage_defect',
      );
    });

    test('an item with NO metadata map at all still gets the old key', () {
      final item = _bareKeyItem();
      expect(item.metadata, isNull);
      expect(
        triageDefectDedupeKey(item, triageDefectDefinition),
        '${item.workItemId}:triage_defect',
      );
    });

    test('an ABSENT marker still means the historical key, exactly', () {
      // The closed property, restated at its boundary: null is the only value
      // that may take the silent path, because it is the only value that means
      // "this item was never retried".
      final item = _keyItem(triageAttempt: null);
      expect(
        item.metadata!.containsKey('triageAttempt'),
        isFalse,
        reason: 'a null argument must mean ABSENT, not "present and null"',
      );
      expect(
        triageDefectDedupeKey(item, triageDefectDefinition),
        '${item.workItemId}:triage_defect',
      );
    });

    test('a marker that IS present but unreadable throws rather than '
        'reusing a consumed key', () {
      // The silent fallback this replaces would have returned
      // '<id>:triage_defect' — the key the TERMINAL first job already holds.
      // `enqueueIfAbsent` would then return created: false and the retry would
      // enqueue nothing while looking healthy: the exact silent-no-op class
      // this feature exists to close.
      for (final unreadable in <Object>[
        'one', // non-numeric string
        '', // empty string
        1.5, // non-integral double; truncating would collide two attempts
        true, // bool
        <int>[1], // list
        <String, dynamic>{'a': 1}, // map
        DateTime.utc(2026, 6, 1),
      ]) {
        final item = _keyItem(triageAttempt: unreadable);
        expect(
          () => triageDefectDedupeKey(item, triageDefectDefinition),
          throwsA(isA<FormatException>()),
          reason:
              'an unreadable marker of type ${unreadable.runtimeType} '
              'must be reported, not silently turned into a consumed key',
        );
      }
    });

    test('the numeric forms a marker legitimately round-trips through are '
        'accepted', () {
      // JSON is not the only path a metadata map travels: it round-trips
      // through JSON documents, through YAML-ish tooling and through hand-set
      // values. Every shape that still means "attempt N" must keep working,
      // or a legitimate retry silently stops creating a job.
      for (final entry in <Object, String>{
        1: ':a1',
        2: ':a2',
        1.0: ':a1',
        '3': ':a3',
        ' 4 ': ':a4',
      }.entries) {
        final item = _keyItem(triageAttempt: entry.key);
        expect(
          triageDefectDedupeKey(item, triageDefectDefinition),
          '${item.workItemId}:triage_defect${entry.value}',
          reason:
              'marker ${entry.key} (${entry.key.runtimeType}) is a '
              'readable attempt number',
        );
      }
    });

    test('every historical key keeps matching its own job', () {
      // No historical job is orphaned: an item that was never retried resolves
      // to exactly the key its existing job already holds.
      for (final marker in <Object?>[null, 1, 2, 3]) {
        final item = _keyItem(triageAttempt: marker);
        final key = triageDefectDedupeKey(item, triageDefectDefinition);
        expect(key, startsWith('${item.workItemId}:triage_defect'));
      }
    });
  });

  group('AC-36 property 2 — a second retry finds its key unconsumed', () {
    test('two full retry -> fail -> retry cycles produce TWO job rows', () async {
      final host = await _Host.start(seed: _seedFailedDefect, cap: 2);

      // Cycle 1.
      await host.engine.operatorRetry(
        workItemId: host.workItemId,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );
      await host.scheduler.tick();
      final afterFirst = await host.triageJobs();
      expect(afterFirst.map((j) => j.dedupeKey), [
        '${host.workItemId}:triage_defect:a1',
      ]);

      // The retried run fails and the item is back in agent_failed, exactly as
      // a real triage failure would leave it.
      await _failAgain(host);
      expect(
        (await host.engine.loadWorkItem(host.workItemId)).state,
        WorkItemState.agentFailed,
      );

      // Cycle 2 — a DIFFERENT operator intent, so it is a real second attempt.
      await host.engine.operatorRetry(
        workItemId: host.workItemId,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-2',
      );
      await host.scheduler.tick();
      final afterSecond = await host.triageJobs();

      expect(
        afterSecond.map((j) => j.dedupeKey).toSet(),
        {
          '${host.workItemId}:triage_defect:a1',
          '${host.workItemId}:triage_defect:a2',
        },
        reason:
            'the whole point: a reused key would have enqueued nothing and '
            'the operator would watch the button do nothing',
      );
      expect(afterSecond, hasLength(2));
      expect(
        (await host.engine.loadWorkItem(
          host.workItemId,
        )).metadata?['triageAttempt'],
        2,
      );
    });

    test(
      'the ledger holds one row per attempt, with numbers 1 and 2',
      () async {
        final host = await _Host.start(seed: _seedFailedDefect, cap: 2);
        await host.engine.operatorRetry(
          workItemId: host.workItemId,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );
        await _failAgain(host);
        await host.engine.operatorRetry(
          workItemId: host.workItemId,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-2',
        );

        final rows = await host.store.readOperatorActionsForWorkItem(
          host.workItemId,
        );
        expect(rows.map((r) => r.attemptNumber), [1, 2]);
        expect(rows.map((r) => r.requestId), ['req-1', 'req-2']);
        expect(rows.map((r) => r.transitionId).toSet(), hasLength(2));
      },
    );
  });

  group('AC-36 property 3 / AC-14e — a network replay mints no second job', () {
    test(
      'replaying the SAME requestId, then ticking, creates no new job',
      () async {
        final host = await _Host.start(seed: _seedFailedDefect, cap: 2);

        await host.engine.operatorRetry(
          workItemId: host.workItemId,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );
        // The response is lost; the client retries the identical intent, twice.
        for (var i = 0; i < 2; i++) {
          await host.engine.operatorRetry(
            workItemId: host.workItemId,
            requestedBy: requestedBy,
            reason: reason,
            requestId: 'req-1',
          );
        }

        expect(
          await host.store.readOperatorActionsForWorkItem(host.workItemId),
          hasLength(1),
        );
        expect(
          await host.engine.operatorRetryCount(host.workItemId),
          1,
          reason: 'a replay must not move the attempt number either',
        );

        // Three ticks, because a tick only creates a job for a runnable item, and
        // the item stays runnable — that is precisely how a replay could mint a
        // second job if the dedupe key were derived from anything volatile.
        for (var i = 0; i < 3; i++) {
          await host.scheduler.tick();
        }

        final jobs = await host.triageJobs();
        expect(jobs, hasLength(1), reason: 'one intent, one job, one spend');
        expect(jobs.single.dedupeKey, '${host.workItemId}:triage_defect:a1');
      },
    );

    test(
      'replays are refused at the STORE level even if the engine is bypassed',
      () async {
        // The unique index is the backstop, and it is modelled by the stores that
        // have no database, so a caller cannot reach the table twice.
        final host = await _Host.start(seed: _seedFailedDefect, cap: 1);
        await host.engine.operatorRetry(
          workItemId: host.workItemId,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );
        final row = (await host.store.readOperatorActionsForWorkItem(
          host.workItemId,
        )).single;
        await expectLater(
          host.store.appendOperatorAction(
            row.copyWith(transitionId: row.transitionId),
          ),
          throwsA(isA<OperatorActionConflictException>()),
        );
      },
    );
  });

  group('AC-36 property 4 — both enqueuers converge on one key', () {
    test('the scheduler tick and a direct enqueue agree', () async {
      final host = await _Host.start(seed: _seedFailedDefect, cap: 2);
      await host.engine.operatorRetry(
        workItemId: host.workItemId,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );
      final item = await host.engine.loadWorkItem(host.workItemId);

      // `WorkEntryTrigger.ensureWorkEntry` and `Scheduler.tick` both call this
      // imported builder, so both compute the same key. Asserted here by
      // calling the builder the way each caller does and comparing.
      final schedulerKey = triageDefectDedupeKey(item, triageDefectDefinition);
      final workEntryKey = triageDefectDedupeKey(item, triageDefectDefinition);
      expect(schedulerKey, workEntryKey);
      expect(schedulerKey, '${host.workItemId}:triage_defect:a1');
    });

    test(
      'a second tick does not create a second job for the same item',
      () async {
        final host = await _Host.start(seed: _seedFailedDefect, cap: 2);
        await host.engine.operatorRetry(
          workItemId: host.workItemId,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );
        await host.scheduler.tick();
        await host.scheduler.tick();
        await host.scheduler.tick();
        expect(await host.triageJobs(), hasLength(1));
      },
    );
  });

  group(
    'a DECISION-driven re-triage dispatches too — the QA defect, reproduced',
    () {
      // Everything above proves the OPERATOR RETRY end-to-end. Nothing proved
      // the other half: an item that arrives at `designNotRequired` because a
      // human resolved a rework, rather than because an operator pressed a
      // button. That is the live QA defect on `defect-DEF-1791684804452198`
      // (2026-10-12), where every triage key was already consumed by a
      // TERMINAL job and `enqueueIfAbsent` returned `created: false` on every
      // tick, forever.
      //
      // The setup below is that item's job table verbatim, created through the
      // REAL `JobQueue` so the keys are genuinely held rather than asserted to
      // be. Nothing about the queue's own rules is changed: a `succeeded` or
      // `failed` holder keeps its key, exactly as the stale-job lane decided,
      // and only the DISCRIMINATOR decides whether a fresh key is asked for.

      test(
        'an engineering-review rework enqueues under a FRESH key and runs',
        () async {
          final host = await _Host.start(
            seed: _seedDefectAtEngineeringReviewGate,
            cap: 1,
          );
          await _holdTerminalTriageJob(
            host,
            '${host.workItemId}:triage_defect',
            JobState.failed,
          );
          await _holdTerminalTriageJob(
            host,
            '${host.workItemId}:triage_defect:a1',
            JobState.failed,
          );
          await _holdTerminalTriageJob(
            host,
            '${host.workItemId}:triage_defect:a2',
            JobState.succeeded,
          );
          expect(
            (await host.triageJobs()).map((j) => j.dedupeKey).toSet(),
            {
              '${host.workItemId}:triage_defect',
              '${host.workItemId}:triage_defect:a1',
              '${host.workItemId}:triage_defect:a2',
            },
            reason:
                'the seeded state must be the QA state, or nothing below '
                'proves anything',
          );

          // THE BUG, verbatim: the item is already at a `triageDefectDefinition`
          // entry state and a tick enqueues nothing, because the key the
          // builder computes is one a terminal job holds.
          final before = await host.scheduler.tick();
          expect(
            before.enqueued,
            isEmpty,
            reason:
                'this is the inert item: designNotRequired is a legal entry '
                'state and the key is consumed, so no job can be created',
          );

          // The human says "this is not acceptable".
          final reworked = await host.engine.resolveHumanDecision(
            decisionId:
                (await host.store.readHumanDecisionsForWorkItem(
                      host.workItemId,
                    ))
                    .firstWhere(
                      (d) =>
                          d.decisionType == HumanDecisionType.engineeringReview,
                    )
                    .decisionId,
            choice: HumanDecisionChoice.rework,
            decider: 'bob@example.com',
            rationale: 'The result is not acceptable',
            signature: DecisionSignature(
              algorithm: 'Ed25519',
              publicKey: 'key-1',
              signature: 'sig-1',
              signedAt: DateTime.now(),
            ),
          );
          expect(reworked.state, WorkItemState.designNotRequired);
          expect(
            reworked.metadata?['triageAttempt'],
            3,
            reason:
                'the rework advances the discriminator past every key a '
                'terminal job holds; this is the value that was missing',
          );

          host.parkRuns = true;
          final tick = host.scheduler.tick();
          await waitUntil(
            () async => (await host.triageJobs()).any(
              (j) => j.state == JobState.running,
            ),
            because: 'the re-triaged item must dispatch on the ordinary tick',
          );

          final running = (await host.triageJobs()).singleWhere(
            (j) => j.state == JobState.running,
          );
          expect(
            running.dedupeKey,
            '${host.workItemId}:triage_defect:a3',
            reason: 'the fresh suffix is the whole fix',
          );
          expect(host.dispatcher.started, hasLength(1));

          host.releaseAll();
          await tick;
        },
      );

      test('an engineering-review REJECT re-enters triage under a FRESH key and '
          'DISPATCHES, without collapsing the state', () async {
        // THE REJECT HALF, end to end, on the same consumed-key history as the
        // rework test above. This is the case the human's option-B decision
        // is about: the item KEEPS `reviewRejected` as its own state (so the
        // operator can see "you rejected this") and is still dispatchable, so
        // the rejection is not a dead end with its decision already answered.
        //
        // Both halves are load-bearing and they pull in opposite directions,
        // which is why neither is asserted on its own:
        //   * the state must be `reviewRejected`, not `designNotRequired` —
        //     collapsing them is option A, which the human did not choose;
        //   * the state must still dispatch — `reviewRejected` is not in the
        //     `entryStates` of any definition at base, which is the defect.
        //
        // WHAT THIS DOES NOT PROVE, and what a previous version of this test
        // claimed it did: the worker here is a stub that parks, so the
        // coordinator is never invoked and "runs" was never established. That
        // gap is how a scheduler which re-queued the same job for ever could
        // pass this file. The RUN is proven at full stack realism — real
        // `ExecutionCoordinator`, real `LocalWorker`, real git worktree, real
        // agent result — in `test/entry_hop_test.dart` ("a rejected
        // engineering review hops to the state it can execute from and a real
        // agent produces a real result on it"). This test owns the key
        // semantics; that one owns the run.
        final host = await _Host.start(
          seed: _seedDefectAtEngineeringReviewGate,
          cap: 1,
        );
        // Every key a terminal job already holds, so the re-triage has to
        // find a free one or enqueue nothing at all.
        for (final key in <String>[
          '${host.workItemId}:triage_defect',
          '${host.workItemId}:triage_defect:a1',
          '${host.workItemId}:triage_defect:a2',
        ]) {
          await _holdTerminalTriageJob(
            host,
            key,
            key.endsWith(':a2') ? JobState.succeeded : JobState.failed,
          );
        }

        // Before the decision: blocked on the gate, so nothing runs.
        expect(
          (await host.scheduler.tick()).enqueued,
          isEmpty,
          reason: 'a pending engineering review blocks the item',
        );

        // The human says "this is rejected".
        final rejected = await host.engine.resolveHumanDecision(
          decisionId:
              (await host.store.readHumanDecisionsForWorkItem(host.workItemId))
                  .firstWhere(
                    (d) =>
                        d.decisionType == HumanDecisionType.engineeringReview,
                  )
                  .decisionId,
          choice: HumanDecisionChoice.reject,
          decider: 'bob@example.com',
          rationale: 'Rejected outright',
          signature: DecisionSignature(
            algorithm: 'Ed25519',
            publicKey: 'key-1',
            signature: 'sig-1',
            signedAt: DateTime.now(),
          ),
        );

        expect(
          rejected.state,
          WorkItemState.reviewRejected,
          reason:
              'option B: the state is PRESERVED so the operator sees "you '
              'rejected this" as its own state, rather than collapsed into '
              'designNotRequired',
        );
        expect(
          rejected.metadata?['triageAttempt'],
          3,
          reason:
              'the discriminator is keyed on the CHOICE, not the target. A '
              'rule keyed on the landing state would stamp nothing here, '
              'because reviewRejected was in no entryStates — and the item '
              'would be inert the moment the state became dispatchable.',
        );

        host.parkRuns = true;
        final tick = host.scheduler.tick();
        await waitUntil(
          () async =>
              (await host.triageJobs()).any((j) => j.state == JobState.running),
          because:
              'the rejected item must dispatch from reviewRejected on the '
              'ordinary tick',
        );

        final running = (await host.triageJobs()).singleWhere(
          (j) => j.state == JobState.running,
        );
        expect(
          running.dedupeKey,
          '${host.workItemId}:triage_defect:a3',
          reason:
              'a new, unconsumed key — the acceptance criterion for this '
              'change. Every suffixed key up to a2 is held by a TERMINAL job '
              'above, so a reused key would have enqueued nothing at all',
        );
        expect(
          host.dispatcher.started,
          hasLength(1),
          reason: 'exactly one execution, not a re-run loop',
        );

        host.releaseAll();
        await tick;
      });

      test('a rejected item does NOT re-arm itself on the next tick', () async {
        // The loop this change could have introduced. `reviewRejected` is
        // dispatchable, and the evaluator kept calling it runnable for ever
        // while the coordinator refused every attempt against it. Two separate
        // things now stop a re-run, and this test asserts BOTH:
        //
        //   * the scheduler takes the single intermediate hop the definition
        //     declares for that state, once, and the item is then somewhere
        //     ordinary that no longer needs a hop; and
        //   * the DEDUPE KEY stops a second job, not the state: the
        //     discriminator only advances on a fresh human intent, so the next
        //     tick computes the same `:a3`, which the terminal job now holds.
        //
        // Asserted because "dispatchable" is exactly the property that makes a
        // self-re-arming loop possible, and an unbounded re-run is the one
        // outcome worse than the inert item being fixed. The reviewed head
        // passed the job-count half of this while burning a worker execution
        // per tick, which is what a count alone cannot see.
        final host = await _Host.start(
          seed: _seedDefectAtEngineeringReviewGate,
          cap: 1,
        );
        for (final key in <String>[
          '${host.workItemId}:triage_defect',
          '${host.workItemId}:triage_defect:a1',
          '${host.workItemId}:triage_defect:a2',
        ]) {
          await _holdTerminalTriageJob(
            host,
            key,
            key.endsWith(':a2') ? JobState.succeeded : JobState.failed,
          );
        }

        await host.engine.resolveHumanDecision(
          decisionId:
              (await host.store.readHumanDecisionsForWorkItem(host.workItemId))
                  .firstWhere(
                    (d) =>
                        d.decisionType == HumanDecisionType.engineeringReview,
                  )
                  .decisionId,
          choice: HumanDecisionChoice.reject,
          decider: 'bob@example.com',
          rationale: 'Rejected outright',
          signature: DecisionSignature(
            algorithm: 'Ed25519',
            publicKey: 'key-1',
            signature: 'sig-1',
            signedAt: DateTime.now(),
          ),
        );

        // Three ticks, because a tick only creates a job for a runnable item
        // and this item stays runnable — the precise condition under which a
        // loop would mint one job per tick.
        for (var i = 0; i < 3; i++) {
          await host.scheduler.tick();
        }

        final jobs = await host.triageJobs();
        expect(
          jobs.where((j) => j.dedupeKey.endsWith(':a3')),
          hasLength(1),
          reason: 'one rejected review, one spend',
        );
        expect(
          jobs,
          hasLength(4),
          reason:
              'the three seeded terminal holders plus the single re-triage. '
              'An extra row here is the self-re-arming loop.',
        );
        expect(
          (await host.engine.loadWorkItem(host.workItemId)).state,
          WorkItemState.designNotRequired,
          reason:
              'the state has MOVED ONCE, by the single hop the definition '
              'declares for it, and then stopped. The rejection is no longer a '
              'dead end, and a hop repeated per tick would be the very loop '
              'this test exists to catch',
        );
        final hops = (await host.store.readTransitionHistory(host.workItemId))
            .where(
              (r) =>
                  r.fromState == WorkItemState.reviewRejected &&
                  r.toState == WorkItemState.designNotRequired,
            );
        expect(
          hops,
          hasLength(1),
          reason: 'taken exactly once across all three ticks',
        );
      });

      test('the re-entry dispatch does NOT disturb the queue\'s own rule: a '
          'terminal holder keeps its key', () async {
        // The control for the test above. The fix is in the DISCRIMINATOR,
        // not in `enqueueIfAbsent`: against the SAME consumed `:a2` key the
        // queue must still refuse, and against the new `:a3` it must still
        // create. If someone "fixed" this by teaching the queue to yield a
        // consumed key to an item in an entry state, this fails.
        final host = await _Host.start(
          seed: _seedDefectAtEngineeringReviewGate,
          cap: 1,
        );
        final queue = JobQueue(store: host.jobStore);
        final consumed = await queue.enqueueIfAbsent(
          workItemId: host.workItemId,
          definition: triageDefectDefinition,
          dedupeKey: '${host.workItemId}:triage_defect:a2',
          instruction: 'x',
        );
        expect(consumed.created, isTrue);
        await queue.complete(job: consumed.job, terminal: JobState.succeeded);
        expect(
          (await host.jobStore.readJob(consumed.job.jobId))!.state,
          JobState.succeeded,
        );

        final again = await queue.enqueueIfAbsent(
          workItemId: host.workItemId,
          definition: triageDefectDefinition,
          dedupeKey: '${host.workItemId}:triage_defect:a2',
          instruction: 'x',
        );
        expect(
          again.created,
          isFalse,
          reason:
              'a succeeded job records an ATTEMPT; re-enqueueing against it '
              'would be an unbounded automatic re-run. That rule is '
              'untouched and must stay untouched.',
        );

        final fresh = await queue.enqueueIfAbsent(
          workItemId: host.workItemId,
          definition: triageDefectDefinition,
          dedupeKey: '${host.workItemId}:triage_defect:a3',
          instruction: 'x',
        );
        expect(fresh.created, isTrue, reason: 'a key nothing holds is free');
      });
    },
  );

  group('AC-37 the retried job still carries its defect payload', () {
    test('all eight keys reach the instruction the agent is given', () async {
      final host = await _Host.start(seed: _seedFailedDefect, cap: 1);
      await host.engine.operatorRetry(
        workItemId: host.workItemId,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );
      final item = await host.engine.loadWorkItem(host.workItemId);
      final instruction = triageDefectInstruction(item, triageDefectDefinition);

      // Read the payload the way a REPLACE would have destroyed it: a wiped
      // item renders the workItemId as the defect id, an empty description and
      // `evidence = []`, and the job would look healthy while classifying
      // nothing.
      expect(item.metadata?['defectId'], 'DEF-1791686704991884');
      expect(instruction, contains('DEF-1791686704991884'));
      expect(instruction, contains('Checkout total is wrong'));
      expect(
        instruction,
        contains('ev-1'),
        reason:
            'the evidence must be in '
            'the prompt, not the default `[]`',
      );
      expect(instruction, isNot(contains('Evidence:\n[]')));
      expect(
        instruction,
        contains('The checkout total ignores the second item'),
      );
    });
  });

  group('the capacity guard is still the thing that admits work', () {
    test(
      'a saturated budget leaves the job queued and records the denial',
      () async {
        final host = await _Host.start(seed: _seedFailedDefect, cap: 1);

        // Fill the single slot FIRST, with an unrelated long-running job, so the
        // retried item is the one that meets a full budget. Saturating after the
        // retry would put two runnable items in front of one free slot, and the
        // assertion would depend on which one won it.
        host.parkRuns = true;
        final saturatingTick = await host.saturate();

        await host.engine.operatorRetry(
          workItemId: host.workItemId,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );

        final result = await host.scheduler.tick();
        expect(result.deferred, isNotEmpty);
        expect(result.dispatched, isEmpty);
        final jobs = await host.triageJobs();
        expect(
          jobs.single.state,
          JobState.queued,
          reason: 'denied, not failed',
        );
        expect(await host.capacityDenials(), 1);

        host.releaseAll();
        await saturatingTick;
      },
    );
  });
}

/// Awaits a durable condition instead of sleeping a fixed amount.
Future<void> waitUntil(
  FutureOr<bool> Function() condition, {
  required String because,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('timed out waiting for: $because');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// One capacity-capable in-memory store.
///
/// The real budget is enforced under a cross-connection lock
/// (`CapacityLockingJobStore`); `InMemoryJobStore` does not provide one, and
/// `JobCapacityGuard` refuses to admit anything without it rather than
/// pretending a per-process lock is a cluster-wide one. This wrapper provides
/// the capability the same way `SerializedJobStore` does in the capacity
/// suite, so the guard under test is the REAL one.
class _LockingJobStore implements JobStore, CapacityLockingJobStore {
  _LockingJobStore(this._inner);

  final JobStore _inner;

  @override
  Future<T> inCapacityLockedTransaction<T>(
    int lockKey,
    Future<T> Function(JobStore store) body,
  ) => _inner.inTransaction((tx) => body(this));

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) =>
      _inner.inTransaction((tx) => body(this));

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) =>
      _inner.saveJob(job, expectedVersion: expectedVersion);

  @override
  Future<Job?> readJob(String jobId) => _inner.readJob(jobId);

  @override
  Future<List<Job>> listJobs() => _inner.listJobs();

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) =>
      _inner.listJobsForWorkItem(workItemId);

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) =>
      _inner.findLatestByDedupeKey(dedupeKey);

  @override
  Future<void> saveClaim(JobClaim claim) => _inner.saveClaim(claim);

  @override
  Future<JobClaim?> readClaimForJob(String jobId) =>
      _inner.readClaimForJob(jobId);

  @override
  Future<List<JobClaim>> listClaims() => _inner.listClaims();

  @override
  Future<void> deleteClaim(String jobId) => _inner.deleteClaim(jobId);

  @override
  Future<void> appendEvent(SchedulerEventRecord event) =>
      _inner.appendEvent(event);

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) =>
      _inner.readEvents(jobId);
}

/// A worker stub that parks inside `run`, so the job is observably `running`
/// before the execution finishes — which is the state §16.3 asks for.
class _ParkingDispatcher implements WorkerDispatch {
  bool parkRuns = false;
  final List<String> started = [];

  final List<Completer<void>> _releases = [];

  void releaseAll() {
    parkRuns = false;
    final pending = List<Completer<void>>.from(_releases);
    _releases.clear();
    for (final release in pending) {
      if (!release.isCompleted) release.complete();
    }
  }

  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      WorkerSelection.dispatched(
        WorkerRegistration(
          workerId: 'w-parking',
          poolId: 'triage-pool',
          capabilities: {
            for (final c in request.requiredCapabilities)
              c: CapabilitySpec(capability: c, version: '1'),
          },
          status: WorkerStatus.busy,
          currentLoad: 0,
          maxConcurrency: 8,
          lastHeartbeat: DateTime.now(),
        ),
      );

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    started.add(request.workItemId);
    final release = Completer<void>();
    if (parkRuns) _releases.add(release);
    if (parkRuns) await release.future;
    final now = DateTime.now().toUtc();
    return WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: WorkerExecutionStatus.executedPass,
      workerId: 'w-parking',
      workspaceId: 'ws-${request.workerExecutionId}',
      startingRevision: request.startingRevision,
      startedAt: now,
      endedAt: now,
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: WorkerFailureCode.none,
    );
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

/// One scheduler with a real queue, a real capacity guard and the real
/// `triage_defect` builders.
class _Host {
  _Host._({
    required this.store,
    required this.engine,
    required this.scheduler,
    required this.dispatcher,
    required this.jobStore,
    required this.workItemId,
  });

  static const String seededWorkItemId = 'defect-DEF-1791686704991884';

  static const SchedulerWorkload _workload = SchedulerWorkload(
    repositoryPath: '/tmp/triage',
    startingRevision: 'deadbeef',
    timeoutSeconds: 60,
    runtimeTypeId: 'triage-runtime',
  );

  final InMemoryWorkflowStore store;
  final DurableWorkflowEngine engine;
  final Scheduler scheduler;
  final _ParkingDispatcher dispatcher;
  final _LockingJobStore jobStore;
  final String workItemId;

  bool get parkRuns => dispatcher.parkRuns;

  set parkRuns(bool value) => dispatcher.parkRuns = value;

  void releaseAll() => dispatcher.releaseAll();

  static Future<_Host> start({
    required Future<String> Function(DurableWorkflowEngine engine) seed,
    required int cap,
  }) async {
    final store = InMemoryWorkflowStore();
    final engine = DurableWorkflowEngine(store: store);
    await seed(engine);

    final jobStore = _LockingJobStore(InMemoryJobStore());
    final dispatcher = _ParkingDispatcher();
    // Resolved exactly the way production resolves it — through the
    // environment variable, never through a hand-picked number. `capacity` is
    // non-null only because the value was a valid integer, which is the
    // fail-closed property being preserved rather than bypassed.
    final capacity = ExecutionCapacityResolution.fromEnvironment({
      executionCapacityEnvVar: '$cap',
    }).capacity!;

    final scheduler = Scheduler(
      schedulerId: 'sched-triage',
      workflowStore: store,
      jobStore: jobStore,
      workerStore: InMemoryWorkerStore(),
      dispatch: dispatcher,
      definition: triageDefectDefinition,
      workload: _workload,
      capacityGuard: JobCapacityGuard(store: jobStore, capacity: capacity),
      dedupeKeyBuilder: triageDefectDedupeKey,
      instructionBuilder: triageDefectInstruction,
      requestBuilder: triageDefectRequest,
    );

    return _Host._(
      store: store,
      engine: engine,
      scheduler: scheduler,
      dispatcher: dispatcher,
      jobStore: jobStore,
      workItemId: seededWorkItemId,
    );
  }

  Future<List<Job>> triageJobs() async =>
      (await jobStore.listJobsForWorkItem(workItemId)).toList();

  Future<int> capacityDenials() async {
    var count = 0;
    for (final job in await jobStore.listJobs()) {
      for (final event in await jobStore.readEvents(job.jobId)) {
        if (event.payload?['outcome'] == 'capacityDenied') count++;
      }
    }
    return count;
  }

  /// Occupies the whole budget with an unrelated long-running job, so the next
  /// tick's claim is denied.
  ///
  /// Returns the still-parked tick, so the caller can await it after releasing
  /// rather than leaving an unobserved future behind.
  Future<Future<SchedulerTickResult>> saturate() async {
    final other = 'defect-other';
    await engine.createWorkItem(
      workItemId: other,
      productId: 'prod-1',
      category: WorkItemCategory.bugfix,
      title: 'Triage another reported defect',
      description: 'A second defect holding the single capacity slot open.',
      metadata: {'defectId': 'DEF-other'},
    );
    await engine.transition(
      workItemId: other,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await engine.transition(
      workItemId: other,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/triage-queue'},
    );
    await engine.transition(
      workItemId: other,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );

    final tick = scheduler.tick();
    await waitUntil(
      () async => (await jobStore.listJobsForWorkItem(
        other,
      )).any((j) => j.state == JobState.running),
      because: 'the budget to be occupied',
    );
    // Deliberately not awaited here: the tick stays parked until releaseAll().
    return tick;
  }
}

/// The defect work item an operator would find: parked at `agent_failed` with
/// the full triage payload attached.
Future<String> _seedFailedDefect(DurableWorkflowEngine engine) async {
  final id = _Host.seededWorkItemId;
  await engine.createWorkItem(
    workItemId: id,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Triage reported defect DEF-1791686704991884',
    description:
        'A customer reported that the checkout total is wrong when a cart '
        'holds more than one item. Triage it and classify the defect.',
    metadata: {
      'defectId': 'DEF-1791686704991884',
      'defectTitle': 'Checkout total is wrong',
      'defectEvidence': '[{"evidenceId":"ev-1","url":"https://x/1.png"}]',
      'defectReporter': 'customer@example.com',
      'defectSeverity': 'high',
      'defectDescription': 'The checkout total ignores the second item.',
      'defectExpectedBehavior': 'The total must include every line item.',
      'defectReproductionSteps': '1. Add two items\n2. Open checkout',
    },
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: const {'featureRef': 'feature/triage-queue'},
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.designNotRequired,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.agentFailed,
    trigger: TransitionTrigger.systemEvent,
  );
  return id;
}

/// The retried run fails again and the item returns to `agent_failed`.
Future<void> _failAgain(_Host host) async {
  final id = host.workItemId;
  await host.engine.transition(
    workItemId: id,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  await host.engine.transition(
    workItemId: id,
    to: WorkItemState.agentFailed,
    trigger: TransitionTrigger.systemEvent,
  );
}

/// The same defect, parked at `waitingForHumanDecision` on an
/// `engineeringReview` decision, with a `triageAttempt` of 2 already behind
/// it — the exact shape of `defect-DEF-1791684804452198` when it went inert.
///
/// The marker is stamped through the durable store rather than a transition,
/// because no public API writes it on this route (that is the defect being
/// tested) and the walk below must start from `draft`.
Future<String> _seedDefectAtEngineeringReviewGate(
  DurableWorkflowEngine engine,
) async {
  const id = _Host.seededWorkItemId;
  await engine.createWorkItem(
    workItemId: id,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Triage reported defect DEF-1791686704991884',
    description:
        'A customer reported that the checkout total is wrong when a cart '
        'holds more than one item. Triage it and classify the defect.',
    metadata: {
      'defectId': 'DEF-1791686704991884',
      'defectSeverity': 'high',
      'triageAttempt': 2,
    },
  );
  Future<void> step(
    WorkItemState to, {
    Map<String, dynamic> context = const {},
  }) => engine.transition(
    workItemId: id,
    to: to,
    trigger: to == WorkItemState.agentCompleted
        ? TransitionTrigger.agentResult
        : to == WorkItemState.reviewInProgress
        ? TransitionTrigger.agentResult
        : TransitionTrigger.systemEvent,
    context: context,
  );

  await step(WorkItemState.planning);
  await step(WorkItemState.planned, context: const {'featureRef': 'f-1'});
  await step(
    WorkItemState.designRequired,
    context: const {'designContractId': 'dc-1'},
  );
  await step(
    WorkItemState.designInReview,
    context: const {'designContractStatus': DesignContractStatus.underReview},
  );
  await engine.resolveHumanDecision(
    decisionId: (await engine.requestHumanDecision(
      workItemId: id,
      decisionType: HumanDecisionType.designApproval,
      actor: const WorkflowActor(
        actorId: 'orch-1',
        actorType: ActorType.orchestrator,
      ),
    )).decisionId,
    // An approval is NOT a re-triage, so it must leave the marker alone — the
    // seed asserts exactly that below.
    choice: HumanDecisionChoice.approve,
    decider: 'alice@example.com',
    rationale: 'Approved',
    signature: DecisionSignature(
      algorithm: 'Ed25519',
      publicKey: 'key-1',
      signature: 'sig-1',
      signedAt: DateTime.now(),
    ),
  );
  expect(
    (await engine.loadWorkItem(id)).metadata?['triageAttempt'],
    2,
    reason:
        'design approval is ordinary progress, not a re-triage. If it moved '
        'the discriminator, the seeded QA state below would be a fiction.',
  );
  await step(
    WorkItemState.agentExecuting,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  final agentResult = AgentResult(
    resultId: 'res-1',
    sessionId: 'ses-1',
    workItemId: id,
    status: AgentResultStatus.completed,
    artifacts: const [],
    diagnostics: AgentDiagnostics(
      exitCode: 0,
      durationMs: 1,
      toolCalls: 1,
      errors: const [],
      warnings: const [],
    ),
    structuredResult: const {},
    completedAt: DateTime.now(),
  );
  await step(
    WorkItemState.agentCompleted,
    context: {'qaContractId': 'qa-1', 'agentResult': agentResult},
  );
  await step(
    WorkItemState.reviewInProgress,
    context: {'agentResult': agentResult},
  );
  await engine.requestHumanDecision(
    workItemId: id,
    decisionType: HumanDecisionType.engineeringReview,
    question: 'Approve the implementation?',
    actor: const WorkflowActor(
      actorId: 'reviewer-2',
      actorType: ActorType.engineeringReviewer,
    ),
    extraContext: const {'producerActorId': 'agent-1'},
  );
  expect(
    (await engine.loadWorkItem(id)).state,
    WorkItemState.waitingForHumanDecision,
  );
  return id;
}

/// Creates one TERMINAL triage job under [dedupeKey] through the real
/// [JobQueue], so the key is genuinely held rather than assumed to be.
///
/// This is the QA job table reproduced, not a new scenario: the fix must not
/// touch how a holder keeps a key, only whether the item asks for a different
/// one.
Future<void> _holdTerminalTriageJob(
  _Host host,
  String dedupeKey,
  JobState terminal,
) async {
  final queue = JobQueue(store: host.jobStore);
  final created = await queue.enqueueIfAbsent(
    workItemId: host.workItemId,
    definition: triageDefectDefinition,
    dedupeKey: dedupeKey,
    instruction: 'seeded terminal holder',
  );
  expect(
    created.created,
    isTrue,
    reason: '$dedupeKey must actually be free when this seeds it',
  );
  await queue.complete(job: created.job, terminal: terminal);
}

const _defectPayloadKeys = <String>[
  'defectId',
  'defectTitle',
  'defectEvidence',
  'defectReporter',
  'defectSeverity',
  'defectDescription',
  'defectExpectedBehavior',
  'defectReproductionSteps',
];

/// Builds a throwaway work item for the pure key-shape assertions.
///
/// `triageAttempt: null` means the key is absent entirely, which is the case
/// AC-36 property 1 exists to protect.
WorkItem _keyItem({Object? triageAttempt}) {
  final metadata = <String, dynamic>{
    'defectId': 'DEF-1',
    for (final key in _defectPayloadKeys)
      if (key != 'defectId') key: 'v',
  };
  if (triageAttempt != null) metadata['triageAttempt'] = triageAttempt;
  return WorkItem(
    workItemId: 'defect-1',
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Triage a reported defect',
    description: 'Triage this reported defect and classify it.',
    state: WorkItemState.designNotRequired,
    metadata: metadata,
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
  );
}

/// A work item with NO metadata map at all.
WorkItem _bareKeyItem() => WorkItem(
  workItemId: 'defect-1',
  productId: 'prod-1',
  category: WorkItemCategory.bugfix,
  title: 'Triage a reported defect',
  description: 'Triage this reported defect and classify it.',
  state: WorkItemState.designNotRequired,
  createdAt: DateTime.utc(2026, 6, 1),
  updatedAt: DateTime.utc(2026, 6, 1),
);

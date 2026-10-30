/// L2 — the two properties that make the execution cap trustworthy.
///
/// ## What this file covers
///
/// 1. **T6, single-flight.** `Timer.periodic` does not await its callback and a
///    tick blocks for a full agent execution (300 s), so without a guard every
///    30-second period starts another tick. The assertions are on the PEAK
///    number of ticks in flight, not on an end state — a tick that briefly
///    overlaps and then re-converges looks perfect to an end-state assertion,
///    and the peak is the only thing that exhausts a host.
/// 2. **The hold lease on that guard** — added after the 2026-10-18 wedged tick.
///    A guard released only by `runTick()` completing has NO BOUND: the tick
///    body awaits a chain in which several steps are unbounded, so a tick that
///    never returns holds the guard for ever and every later trigger is dropped
///    for ever. The lease takes the guard back. These tests assert both halves
///    that matter: it IS taken back, and taking it back cancels nothing.
/// 3. **T7, the composition root refuses to run unbounded.** An absent,
///    unparseable or non-positive cap must not reach a running server.
/// 4. **The advisory lock on `PostgresJobStore`.** What SQL is issued, when,
///    and that two schedulers over one durable store contend for one slot.
///
/// ## What this file does NOT cover, stated plainly
///
/// **No PostgreSQL was involved in any test below.** Docker and Compose are out
/// of bounds for this lane, so nothing here has ever been executed by a real
/// PostgreSQL server. Specifically UNVERIFIED here:
///
///  * that PostgreSQL actually BLOCKS the second caller of
///    `pg_advisory_xact_lock` rather than merely serialising the two statements;
///  * that the lock is shared across CONNECTIONS and processes, which is the
///    entire reason it is used over a per-process mutex;
///  * that `pg_advisory_xact_lock(bigint)` resolves against the real server —
///    the `::bigint` cast is asserted in the emitted SQL, not by a round trip;
///  * that a thrown body really rolls the transaction back and releases the
///    lock server-side.
///
/// What IS verified without a database: the exact statement this store issues,
/// that it is issued inside the open transaction, that it precedes the body,
/// and that its key is the one the budget derives.
///
/// ## And, stated plainly because it is the point of the lease tests
///
/// **No test below proves the live 2026-10-18 tick recovers.** Those tests
/// drive [TickSingleFlight] directly with a synthetic `runTick`, which is where
/// the defect is; what they cannot do is reproduce a real agent execution, a
/// real workspace clone or a real `git commit` hanging inside one. See the
/// `recovery` group for exactly what is and is not claimed.
library;

import 'dart:async';
import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;
import 'dart:isolate' show Isolate;

import 'package:control_plane_server/server.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
// The capacity API is not on the scheduler barrel; same note as in `server.dart`.
// ignore: implementation_imports
import 'package:scheduler/src/capacity/capacity_lockable_store.dart';
// ignore: implementation_imports
import 'package:scheduler/src/capacity/execution_capacity.dart';
// ignore: implementation_imports
import 'package:scheduler/src/capacity/job_capacity_guard.dart';
import 'package:serverpod/database.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

void main() {
  group('T6 — the tick is single-flight', () {
    test(
      'two concurrent triggers yield ONE pass and ONE visible drop',
      () async {
        final log = _LogCapture();
        final gate = _Gate();
        var passes = 0;

        final tick = TickSingleFlight(
          log: log.record,
          runTick: () async {
            passes++;
            // Stands in for a 300-second agent execution.
            await gate.wait();
            return TickOutcome();
          },
        );

        // Deliberately NOT awaited: this is exactly what `Timer.periodic` does.
        final first = tick.trigger();
        final second = tick.trigger();

        expect(
          passes,
          1,
          reason:
              'the second trigger must not start a second tick; this is the '
              'whole property, and without the guard this is 2',
        );
        expect(tick.isRunning, isTrue);

        gate.open();
        final results = await Future.wait([first, second]);

        expect(results.where((r) => r.ran), hasLength(1));
        expect(results.where((r) => !r.ran), hasLength(1));
        expect(
          tick.isRunning,
          isFalse,
          reason: 'the guard is released on exit',
        );
      },
    );

    test('a dropped tick cannot be read as a tick that found nothing', () async {
      final log = _LogCapture();
      final gate = _Gate();
      final tick = TickSingleFlight(
        log: log.record,
        runTick: () async {
          await gate.wait();
          return TickOutcome();
        },
      );

      final running = tick.trigger();
      final dropped = await tick.trigger();

      expect(dropped.ran, isFalse);
      expect(
        dropped.outcome,
        isNull,
        reason:
            'a drop has no outcome at all, so there is nothing a consumer can '
            'mistake for "it ran and found no work"',
      );
      expect(dropped.overlappedTicks, 1);
      expect(
        dropped.toString(),
        contains(tickOverlapDroppedCode),
        reason: 'even its own string form says it was dropped',
      );

      gate.open();
      await running;
    });

    test('the drop is greppable on its own, not only as a field', () async {
      final log = _LogCapture();
      final gate = _Gate();
      final tick = TickSingleFlight(
        log: log.record,
        runTick: () async {
          await gate.wait();
          return TickOutcome();
        },
      );

      final running = tick.trigger();
      await tick.trigger();
      gate.open();
      await running;

      final droppedEvents = log.eventsNamed('scheduler.tick.dropped_overlap');
      expect(droppedEvents, hasLength(1));
      expect(droppedEvents.single['code'], tickOverlapDroppedCode);
      expect(droppedEvents.single['overlappedTicks'], 1);
      expect(
        droppedEvents.single['ran'],
        isFalse,
        reason: 'the dedicated line states it did not run, in words',
      );
      expect(
        droppedEvents.single['action'],
        contains('did not run'),
        reason: 'and says what an operator should conclude from it',
      );
    });

    test('every completion line carries the count, including zero', () async {
      final log = _LogCapture();
      final tick = TickSingleFlight(
        log: log.record,
        runTick: () async => TickOutcome(),
      );

      // Two ticks that both run to completion.
      await tick.trigger();
      await tick.trigger();

      final completed = log.eventsNamed('scheduler.tick.completed');
      expect(completed, hasLength(2));
      for (final line in completed) {
        expect(
          line.containsKey('overlappedTicks'),
          isTrue,
          reason:
              'an ABSENT field is indistinguishable from a zero, so the '
              'field must be present on every line — that is the point of it',
        );
        expect(line['overlappedTicks'], 0);
        expect(line['ran'], isTrue);
      }
      expect(
        log.eventsNamed('scheduler.tick.dropped_overlap'),
        isEmpty,
        reason: 'nothing overlapped, so nothing may claim that it did',
      );
    });

    test(
      'a tick that throws releases the guard instead of wedging the loop',
      () async {
        final log = _LogCapture();
        var attempts = 0;
        final tick = TickSingleFlight(
          log: log.record,
          runTick: () async {
            attempts++;
            if (attempts == 1) {
              throw StateError('the job store was unreachable');
            }
            return TickOutcome();
          },
        );

        await expectLater(tick.trigger(), throwsStateError);

        expect(
          tick.isRunning,
          isFalse,
          reason:
              'a guard released only on success leaves the loop permanently '
              'stopped after the first failure, and every later tick then '
              'reports itself as overlapping against a tick that ended long ago',
        );

        // The loop is still alive: a later tick runs for real.
        final second = await tick.trigger();
        expect(second.ran, isTrue);
        expect(attempts, 2);

        // And the failing tick still left a completion line, so a quiet log is
        // not the signature of a wedged loop. The FAILING tick's line is the
        // first of the two, and it says which half gave up.
        final completed = log.eventsNamed('scheduler.tick.completed');
        expect(completed, hasLength(2));
        expect(completed.first['ran'], isTrue);
        expect(completed.first['overlappedTicks'], 0);
        expect(
          completed.first['failedSections'],
          ['tick'],
          reason:
              'the failing tick must still be accounted for on its own line',
        );
        expect(completed.last['failedSections'], isEmpty);
      },
    );

    test(
      'a tick that throws mid-flight releases the guard while others arrive',
      () async {
        final tick = TickSingleFlight(
          runTick: () async => throw StateError('boom'),
        );

        final first = tick.trigger();
        // Arrives while the first is unwinding, and must be dropped rather than
        // deadlocking against a guard nobody will release.
        final during = tick.trigger();
        await expectLater(first, throwsStateError);
        expect((await during).ran, isFalse);
        expect(tick.isRunning, isFalse);
      },
    );

    test(
      'a REAL Timer.periodic firing faster than a tick completes never runs '
      'two ticks at once',
      () async {
        // The root cause reproduced with the actual mechanism, not a hand-made
        // approximation of it: period 1 ms, tick blocked on a gate. Without the
        // guard this starts hundreds of concurrent "executions"; with it, one.
        const period = Duration(milliseconds: 1);
        var active = 0;
        var peak = 0;
        var started = 0;
        final log = _LogCapture();
        final gate = _Gate();

        final tick = TickSingleFlight(
          log: log.record,
          runTick: () async {
            started++;
            active++;
            if (active > peak) peak = active;
            await gate.wait();
            active--;
            return TickOutcome();
          },
        );

        final timer = Timer.periodic(period, (_) => unawaited(tick.trigger()));
        // The number of fires this REAL timer gets is the event loop's, not
        // ours: under load the isolate can be starved so badly that a 1 ms
        // timer fires twice in 120 ms of WALL CLOCK (measured, F-199 —
        // `Expected greater than <10>, Actual: <1>`). So this waits for the
        // fires to HAVE HAPPENED — the same evidence the assertion below
        // counts — instead of assuming they fit in a wall-clock window. The
        // wait does not weaken anything: a wedged or unguarded world produces
        // zero drops, so this then times out and the test FAILS with the
        // reason naming exactly what never happened.
        await _waitUntil(
          () => log.eventsNamed('scheduler.tick.dropped_overlap').length > 10,
          because:
              'the real 1 ms Timer.periodic to fire at least 11 times while '
              'the first tick holds the guard (one run + more than ten drops)',
          timeout: const Duration(seconds: 20),
        );
        timer.cancel();
        gate.open();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(started, 1, reason: 'exactly one tick may ever have started');
        expect(
          peak,
          1,
          reason:
              'at most one tick may be in flight at any instant; the timer '
              'fired many times and none of them may have overlapped',
        );
        // `started` counts ticks that RAN, so it cannot show that the timer
        // really did fire again. The drops are that evidence, and their count is
        // the overshoot this guard is preventing.
        final drops = log.eventsNamed('scheduler.tick.dropped_overlap');
        expect(
          drops.length,
          greaterThan(10),
          reason:
              'the wait above let the 1 ms timer trigger many times over; '
              'every one after the first should have been dropped, and '
              'only ${drops.length} were',
        );
        for (final line in drops) {
          expect(line['ran'], isFalse);
          expect(line['overlappedTicks'], 1);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('the hold LEASE on the guard — the 2026-10-18 wedged tick', () {
    // What the incident actually was, and what it was not. Asserted first,
    // because the fix below is easy to misread as "a release was missing on an
    // error path", and that is not what happened.
    test(
      'the release is NOT skipped on any path — it is the HOLD that had no bound',
      () async {
        final log = _LogCapture();
        var attempts = 0;
        final tick = TickSingleFlight(
          log: log.record,
          runTick: () async {
            attempts++;
            if (attempts == 1) throw StateError('the store was unreachable');
            return TickOutcome();
          },
        );

        await expectLater(tick.trigger(), throwsStateError);
        expect(
          tick.isRunning,
          isFalse,
          reason:
              'success and failure both release — `whenComplete` covers '
              'both, and the existing tests above already pin that',
        );
        expect((await tick.trigger()).ran, isTrue);

        // Now the shape that really wedged: no throw at all, and no return
        // either. Nothing is "skipped" — the release is simply waiting on a
        // future that never settles.
        final stuck = TickSingleFlight(
          log: log.record,
          runTick: () async => Completer<TickOutcome>().future,
        );
        final never = stuck.trigger();
        for (var i = 0; i < 50; i++) {
          expect((await stuck.trigger()).ran, isFalse);
        }
        expect(
          stuck.isRunning,
          isTrue,
          reason:
              'this is the whole defect: the guard is held for as long as the '
              'body takes, and the body can take for ever',
        );
        expect(never, isNotNull);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'the lease takes the guard back from a tick that never returns',
      () async {
        final log = _LogCapture();
        final gate = _Gate();
        final timers = _LeaseTimers();
        var pass = 0;
        final tick = TickSingleFlight(
          log: log.record,
          maxHold: const Duration(milliseconds: 40),
          leaseTimer: timers.create,
          runTick: () async {
            pass++;
            // ONLY the first pass parks. A later pass returning is what "the
            // next trigger is a real tick again" has to mean; parking every pass
            // would hang this test on its own second trigger.
            if (pass == 1) await gate.wait();
            return TickOutcome();
          },
        );

        final stuck = tick.trigger();
        expect(tick.isRunning, isTrue);
        expect(
          (await tick.trigger()).ran,
          isFalse,
          reason: 'sanity: inside the lease this is still an ordinary drop',
        );

        // The lease fires when the TEST says so, not when the wall clock and
        // the process scheduler happen to allow it: a real 40 ms timer racing
        // real work is the load flake this seam exists to remove (F-199).
        timers.advance(const Duration(milliseconds: 40));
        expect(
          tick.isRunning,
          isFalse,
          reason: 'the lease to expire',
        );
        expect(
          (await tick.trigger()).ran,
          isTrue,
          reason:
              'and after it the next trigger is a real tick again, not a drop '
              'against a guard held by a tick that is still stuck',
        );

        final expired = log.eventsNamed('scheduler.tick.hold_expired');
        expect(expired, hasLength(1));
        expect(expired.single['code'], tickHoldExpiredCode);
        expect(expired.single['maxHoldSeconds'], 0);
        expect(
          expired.single['cancelled'],
          isFalse,
          reason:
              'this is the field that keeps the fix honest: the lease releases '
              'the GUARD and must never touch the work',
        );
        expect(expired.single['action'], contains('NOT cancelled'));

        gate.open();
        await stuck;
      },
    );

    test(
      'expiry cancels NOTHING: the body keeps running and reports late',
      () async {
        final log = _LogCapture();
        final gate = _Gate();
        final timers = _LeaseTimers();
        var bodyFinished = false;
        final tick = TickSingleFlight(
          log: log.record,
          maxHold: const Duration(milliseconds: 40),
          leaseTimer: timers.create,
          runTick: () async {
            await gate.wait();
            bodyFinished = true;
            return TickOutcome();
          },
        );

        final stuck = tick.trigger();
        timers.advance(const Duration(milliseconds: 40));
        expect(
          tick.isRunning,
          isFalse,
          reason: 'the lease to expire',
        );
        expect(
          bodyFinished,
          isFalse,
          reason:
              'the abandoned tick is STILL RUNNING. Cancelling it would free '
              'the symptom, destroy the evidence and throw away the work.',
        );

        gate.open();
        final result = await stuck;

        expect(bodyFinished, isTrue, reason: 'and it really did finish');
        expect(result.ran, isTrue);
        expect(
          result.abandoned,
          isTrue,
          reason: 'so a consumer can tell this completion from a current one',
        );
        expect(
          log.eventsNamed('scheduler.tick.completed'),
          isEmpty,
          reason:
              'an abandoned tick must NOT appear on the normal completion line, '
              'or a consumer counting completions counts it as the current tick',
        );
        final late = log.eventsNamed('scheduler.tick.completed_late');
        expect(late, hasLength(1));
        expect(late.single['code'], tickCompletedLateCode);
        expect(late.single['ran'], isTrue);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'a tick INSIDE its lease is untouched — the lease cannot abandon work',
      () async {
        // The failure the other direction would produce, and the reason the
        // derived default is what it is: a lease short enough to be useful
        // must not also abandon ticks that are legitimately still working.
        final log = _LogCapture();
        final timers = _LeaseTimers();
        final tick = TickSingleFlight(
          log: log.record,
          maxHold: const Duration(seconds: 30),
          leaseTimer: timers.create,
          runTick: () async => TickOutcome(),
        );

        final result = await tick.trigger();

        expect(result.ran, isTrue);
        expect(result.abandoned, isFalse);
        expect(
          log.eventsNamed('scheduler.tick.hold_expired'),
          isEmpty,
          reason: 'a tick that finished inside its lease is not a held guard',
        );
        expect(log.eventsNamed('scheduler.tick.completed'), hasLength(1));
        expect(log.eventsNamed('scheduler.tick.completed_late'), isEmpty);
      },
    );

    test(
      'an abandoned tick finishing later does NOT release a newer tick\'s guard',
      () async {
        // The reason release is tokenised. A bare `_running = false` in the
        // expiry callback plus another in the abandoned tick's `whenComplete`
        // clears the guard TWICE, and the second clear happens while a fresh
        // tick holds it — two ticks in flight, and nothing anywhere says so.
        final log = _LogCapture();
        final firstGate = _Gate();
        final secondGate = _Gate();
        final timers = _LeaseTimers();
        var pass = 0;
        final tick = TickSingleFlight(
          log: log.record,
          maxHold: const Duration(milliseconds: 40),
          leaseTimer: timers.create,
          runTick: () async {
            pass++;
            await (pass == 1 ? firstGate.wait() : secondGate.wait());
            return TickOutcome();
          },
        );

        final first = tick.trigger();
        timers.advance(const Duration(milliseconds: 40));
        expect(
          tick.isRunning,
          isFalse,
          reason: 'the lease to expire',
        );

        final second = tick.trigger();
        expect(tick.isRunning, isTrue);

        // The abandoned tick finally settles, while the second one runs.
        firstGate.open();
        await first;
        expect(
          tick.isRunning,
          isTrue,
          reason:
              'a late release must not clear a guard a newer tick is holding, '
              'or the single-flight property this class exists to provide is '
              'gone the moment a tick is abandoned',
        );

        secondGate.open();
        await second;
        expect(tick.isRunning, isFalse);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('no lease is the library default, and is SAYS so', () {
      final unbounded = TickSingleFlight(runTick: () async => TickOutcome());
      expect(unbounded.maxHold, isNull);
      expect(
        unbounded.holdSummary,
        contains('NO LEASE'),
        reason:
            'absence has to be stated in words: "the field is missing" is '
            'exactly the ambiguity this summary exists to remove',
      );

      final bounded = TickSingleFlight(
        runTick: () async => TickOutcome(),
        maxHold: const Duration(seconds: 90),
      );
      expect(bounded.holdSummary, contains('90s'));
      expect(bounded.holdSummary, contains(tickHoldBoundEnvVar));
    });
  });

  group('resolving the tick hold lease', () {
    test('UNSET resolves to the derived default, never to unbounded', () {
      final log = _LogCapture();
      final bound = resolveTickHoldBound(const {}, log: log.record);

      expect(bound, AgentExecutionBudgets.tickHoldDefault);
      expect(
        bound,
        isNotNull,
        reason:
            'absent must not mean "no lease" — that is the exact state that '
            'stopped dispatch on 2026-10-18',
      );
      expect(log.eventsNamed('server.tick_hold.refused'), isEmpty);
      expect(log.eventsNamed('server.tick_hold.resolved'), hasLength(1));
    });

    test('the derived default is DERIVED, and is stated in seconds', () {
      final derived = AgentExecutionBudgets.tickHoldDefault;
      var largest = Duration.zero;
      for (final budget in AgentExecutionBudgets.byRole.values) {
        if (budget > largest) largest = budget;
      }
      expect(
        derived.inSeconds,
        greaterThanOrEqualTo(
          largest.inSeconds * AgentExecutionBudgets.rejectedStalenessMultiplier,
        ),
        reason:
            'it must scale with the budgets rather than being a literal here, '
            'or lowering a budget would silently leave a stale number in force',
      );
      expect(
        derived.inSeconds,
        greaterThan(largest.inSeconds),
        reason: 'and it must exceed the longest single agent budget',
      );
    });

    test('every unusable value REFUSES, each naming what was wrong', () {
      final cases = <String, String>{
        '': 'empty',
        '   ': 'empty',
        'soon': 'is not an integer',
        '3600.5': 'is not an integer',
        '0': 'is below the minimum of 1',
        '-1': 'is below the minimum of 1',
      };
      cases.forEach((value, why) {
        expect(
          () => resolveTickHoldBound({tickHoldBoundEnvVar: value}),
          throwsA(
            isA<UnusableTickHoldBound>().having(
              (e) => e.diagnostic,
              'diagnostic for "$value"',
              allOf(contains(tickHoldBoundEnvVar), contains(why)),
            ),
          ),
          reason: '$tickHoldBoundEnvVar="$value" must refuse',
        );
      });
    });

    test(
      'the refusal is logged and never silently replaced by another number',
      () {
        final log = _LogCapture();
        expect(
          () => resolveTickHoldBound(
            const {tickHoldBoundEnvVar: 'later'},
            log: log.record,
          ),
          throwsA(isA<UnusableTickHoldBound>()),
        );
        final refused = log.eventsNamed('server.tick_hold.refused');
        expect(refused, hasLength(1));
        expect(refused.single['bound'], contains('refusing to start'));
        expect(
          log.eventsNamed('server.tick_hold.resolved'),
          isEmpty,
          reason:
              'serving a different bound than the operator asked for is the '
              'same defect as no bound at all, wearing a different hat',
        );
      },
    );

    test('a configured value is honoured, surrounding whitespace and all', () {
      expect(
        resolveTickHoldBound({tickHoldBoundEnvVar: '3600'}).inSeconds,
        3600,
      );
      expect(
        resolveTickHoldBound({tickHoldBoundEnvVar: ' 900 '}).inSeconds,
        900,
      );
    });
  });

  group('the lease is WIRED into the composition', () {
    test(
      'the tick is constructed WITH a lease, and the banner states it',
      () async {
        // Wiring pins, not behaviour: booting the composition needs a database,
        // and a lease that was resolved and then not passed to the object would
        // leave the platform exactly as wedged as before while printing a
        // reassuring startup line.
        final source = await _readServerSource();
        expect(
          source,
          contains('maxHold: tickHoldBound,'),
          reason:
              'the resolved bound must reach the TickSingleFlight constructor',
        );
        expect(
          source,
          contains("'tickHold': tick.holdSummary,"),
          reason:
              "read back off the live object rather than off the local variable, "
              "so the banner cannot describe a lease the ticking object lacks",
        );
        expect(
          source,
          contains('resolveTickHoldBound(Platform.environment'),
          reason:
              'and it must be resolved from the environment, not hard-coded',
        );
      },
    );

    test('the lease is resolved BEFORE the process can bind a port', () async {
      final source = await _readServerSource();
      final resolveAt = source.indexOf('resolveTickHoldBound(Platform');
      final serverpodAt = source.indexOf('Serverpod(args,');
      final startAt = source.indexOf('pod.start()');

      expect(resolveAt, greaterThan(-1));
      expect(
        resolveAt,
        lessThan(serverpodAt),
        reason:
            'a refusal that happens after the process binds a port is a '
            'refusal an operator meets as a half-up server that looks healthy',
      );
      expect(resolveAt, lessThan(startAt));
    });
  });

  group('recovery — a tick that used to wedge now DISPATCHES', () {
    // The behavioural claim, as distinct from "the flag is released again".
    //
    // These drive a REAL `Scheduler.tick()` over real in-memory stores, wrapped
    // in the real `TickSingleFlight`. The wedge has TWO halves, because F-237
    // split the 2026-10-18 shape in two:
    //
    //  * a dispatcher that gives one work item an execution which never
    //    returns — the stuck execution, still real, still holding its
    //    capacity slot and its job at `running`. What it can no longer do
    //    is wedge the tick: detached dispatch returns from `_dispatchOne`
    //    the moment the run is started, so a parked `run` holds a claim,
    //    never the guard.
    //  * a durable store read that never returns — armed on the NEXT job's
    //    `readJob` inside `_dispatchOne`. That is the only shape left that
    //    still parks a real tick mid-body, so it is what the lease is
    //    exercised against.
    //
    // NO DATABASE WAS INVOLVED — see the file header. What is therefore NOT
    // proved: that a real `git` clone, a real agent process, a real
    // `ArtifactCommitter.commit` or a real Postgres call hangs in production
    // the way these hang here. That is a runtime observation and belongs to
    // the operator.

    test(
      'with the lease, a later tick RUNS and dispatches the next item',
      () async {
        final t0 = DateTime.utc(2026, 1, 1, 12);
        final host = _CapacityHost(clock: () => t0);
        host.applyCap(capacityOf(2));
        final jobs = await host.enqueueAll(['wi-stuck', 'wi-next']);

        // `wi-stuck` gets an execution that never returns; `wi-next` gets a
        // normal one. The queue therefore has to drain AROUND the stuck item,
        // which is the only way "recovery" can mean anything at all.
        //
        // The tick's own wedge is armed on wi-next's first `readJob` inside
        // `_dispatchOne` — before the claim, so wi-next stays `queued` and
        // unclaimed for whichever tick runs next. Pre-F-237 the parked run
        // itself was the wedge; detached dispatch made that impossible on
        // purpose, and a durable call the tick awaits is what remains.
        host.dispatch.parkRuns = true;
        host.dispatch.neverReleaseFor = <String>{'wi-stuck'};
        host.store.parkReadJobFor(
          jobs.firstWhere((j) => j.workItemId == 'wi-next').jobId,
        );

        final log = _LogCapture();
        final timers = _LeaseTimers();
        final scheduler = host.schedulers.first;
        final tick = TickSingleFlight(
          log: log.record,
          maxHold: const Duration(milliseconds: 40),
          leaseTimer: timers.create,
          runTick: () async {
            final outcome = TickOutcome(failedSections: <String>[]);
            outcome.dispatched = (await scheduler.tick()).dispatched.length;
            return outcome;
          },
        );

        final stuck = tick.trigger();
        await _waitUntil(
          () => host.dispatch.startedWorkItems.contains('wi-stuck'),
          because: 'tick 1 to dispatch the stuck item',
        );
        await _waitUntil(
          () => host.store.parkedReads == 1,
          because:
              'tick 1 to reach the durable read inside wi-next\'s dispatch '
              'and wedge there — observed, not assumed',
        );
        expect(
          host.dispatch.startedWorkItems,
          ['wi-stuck'],
          reason:
              'wi-stuck was dispatched and wi-next never reached its run: '
              'the tick is wedged inside the read between the two '
              'dispatches',
        );

        // Only `wi-stuck` is stuck. From here on, anything a later tick starts
        // runs to completion — otherwise the recovering tick would itself park,
        // and the test would be proving that a second wedged tick also wedges.
        host.dispatch.parkRuns = false;

        // The lease fires when the TEST says so. Waiting on a real 40 ms timer
        // here was the measured load flake (F-199): under starvation the
        // RECOVERED tick below arms its OWN 40 ms lease and can outlive it,
        // firing the lease twice and failing `hasLength(1)` further down.
        timers.advance(const Duration(milliseconds: 40));
        expect(
          tick.isRunning,
          isFalse,
          reason:
              'the tick is blocked inside `_dispatchOne` awaiting a store '
              'read that will never return; the lease is the only thing '
              'that ends it',
        );

        final recovered = await tick.trigger();

        expect(recovered.ran, isTrue, reason: 'the later tick really RAN');
        expect(recovered.outcome!.dispatched, 1, reason: 'and it DISPATCHED');
        expect(
          host.dispatch.startedWorkItems,
          containsAll(<String>['wi-stuck', 'wi-next']),
          reason:
              'the second item was dispatched while the first is still stuck — '
              'before this change nothing past the stuck item ever ran again',
        );
        expect(
          host.dispatch.observedMaxConcurrency,
          2,
          reason:
              'and the capacity cap is still what bounds concurrency, not this '
              'guard: taking the guard back never exceeded C',
        );
        expect(
          log.eventsNamed('scheduler.tick.hold_expired'),
          hasLength(1),
          reason: 'the recovery was announced, not silent',
        );
        expect(
          log.eventsNamed('scheduler.tick.dropped_overlap'),
          isEmpty,
          reason:
              'nothing was dropped while recovering: the queue drained rather '
              'than the triggers piling up and being discarded',
        );

        // Teardown only, after every assertion above. `stuck` is deliberately
        // NOT awaited: an abandoned tick is still running, which is the whole
        // point, and waiting for it here would assert the opposite of what this
        // test proves. Both halves of the wedge are released — the parked run
        // AND the parked read — so the abandoned body can unwind.
        host.dispatch.releaseStuck();
        host.store.releaseParkedReads();
        expect(stuck, isNotNull);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'WITHOUT the lease the same world stays stuck — the counterfactual',
      () async {
        // Non-vacuity for the test above, in the only form that counts: the
        // identical setup with the one thing removed, asserted to NOT recover.
        final t0 = DateTime.utc(2026, 1, 1, 12);
        final host = _CapacityHost(clock: () => t0);
        host.applyCap(capacityOf(2));
        final jobs = await host.enqueueAll(['wi-stuck', 'wi-next']);

        host.dispatch.parkRuns = true;
        host.dispatch.neverReleaseFor = <String>{'wi-stuck'};
        host.store.parkReadJobFor(
          jobs.firstWhere((j) => j.workItemId == 'wi-next').jobId,
        );

        final scheduler = host.schedulers.first;
        final tick = TickSingleFlight(
          runTick: () async {
            final outcome = TickOutcome(failedSections: <String>[]);
            outcome.dispatched = (await scheduler.tick()).dispatched.length;
            return outcome;
          },
        );

        final stuck = tick.trigger();
        await _waitUntil(
          () => host.store.parkedReads == 1,
          because:
              'tick 1 to dispatch the stuck item and wedge on the durable '
              'read inside the next dispatch',
        );

        // Twenty more triggers over a second. Every one is dropped, forever.
        var ranAfterwards = 0;
        for (var i = 0; i < 20; i++) {
          if ((await tick.trigger()).ran) ranAfterwards++;
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }

        expect(
          ranAfterwards,
          0,
          reason: 'nothing ran while the guard was held',
        );
        expect(
          host.dispatch.startedWorkItems,
          ['wi-stuck'],
          reason:
              'and the second item was NEVER dispatched: this is the wedge. The '
              'lease is the only difference between this world and the one above',
        );
        expect(tick.isRunning, isTrue);

        // Teardown only — release BOTH halves of the wedge (the parked read
        // that holds the tick, then the parked run) before awaiting the tick,
        // or `stuck` can never complete.
        host.store.releaseParkedReads();
        host.dispatch.releaseStuck();
        await stuck;
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('T7 — the composition root refuses to run unbounded', () {
    test('an UNSET cap refuses, and names the variable', () {
      expect(
        () => resolveDispatchCapacity(const {}),
        throwsA(
          isA<UnboundedDispatchRefused>().having(
            (e) => e.diagnostic,
            'diagnostic',
            allOf(
              contains(executionCapacityEnvVar),
              contains('unset'),
              // "Fail-closed: unset must not mean unbounded."
              contains('Refusing to dispatch agent executions unbounded'),
            ),
          ),
        ),
        reason:
            'an absent cap is the condition that exhausted the host on '
            '2026-10-10. It must not mean unbounded, and it must not mean a '
            'guessed 2 either.',
      );
    });

    test('every unusable value refuses, each naming what was wrong', () {
      final cases = <String, String>{
        '': 'empty',
        '   ': 'empty',
        'two': 'not an integer',
        '2.5': 'not an integer',
        '0': 'below the minimum of 1',
        '-1': 'below the minimum of 1',
      };
      cases.forEach((value, why) {
        expect(
          () => resolveDispatchCapacity({executionCapacityEnvVar: value}),
          throwsA(
            isA<UnboundedDispatchRefused>().having(
              (e) => e.diagnostic,
              'diagnostic for "$value"',
              allOf(contains(executionCapacityEnvVar), contains(why)),
            ),
          ),
          reason: 'SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS="$value" must refuse',
        );
      });
    });

    test('the decided value C = 2 resolves', () {
      // Human decision f8c8b67f: C = 2. It is the value an operator DEPLOYS,
      // not one this binary defaults to — see the refusal tests above.
      final capacity = resolveDispatchCapacity({
        executionCapacityEnvVar: '2',
      });
      expect(capacity.maxConcurrentExecutions, 2);
      expect(capacity.budget, agentExecutionBudget);
    });

    test('the cap is overridable for tuning after a watched run', () {
      for (final cap in [1, 2, 4, 9, 64]) {
        expect(
          resolveDispatchCapacity({
            executionCapacityEnvVar: '$cap',
          }).maxConcurrentExecutions,
          cap,
          reason: 'C=$cap must be settable without a code change',
        );
      }
      // Surrounding whitespace is a shell script's habit, not a mistake.
      expect(
        resolveDispatchCapacity({
          executionCapacityEnvVar: ' 3 ',
        }).maxConcurrentExecutions,
        3,
      );
    });

    test(
      'the refusal is itself logged, so it is visible and not just thrown',
      () {
        final log = _LogCapture();
        expect(
          () => resolveDispatchCapacity(const {}, log: log.record),
          throwsA(isA<UnboundedDispatchRefused>()),
        );
        final refused = log.eventsNamed('server.capacity.refused');
        expect(refused, hasLength(1));
        expect(refused.single['capacity'], contains('NOT CONFIGURED'));
        expect(
          refused.single['action'],
          contains('C = 2'),
          reason:
              'the operator who has to fix this should be told the decided value '
              'rather than left to invent one',
        );
      },
    );

    test(
      'the composition resolves the cap BEFORE the server can start',
      () async {
        // A wiring pin, not a behavioural test: booting the composition needs a
        // database, and a refusal that happens after `pod.start()` would be a
        // refusal an operator meets as a half-up server that looks healthy.
        final source = await _readServerSource();
        final resolveAt = source.indexOf('resolveDispatchCapacity(Platform');
        final serverpodAt = source.indexOf('Serverpod(args,');
        final startAt = source.indexOf('pod.start()');

        expect(resolveAt, greaterThan(-1), reason: 'the resolution must exist');
        expect(serverpodAt, greaterThan(-1));
        expect(startAt, greaterThan(-1));
        expect(
          resolveAt,
          lessThan(serverpodAt),
          reason: 'the cap must be resolved before Serverpod is constructed',
        );
        expect(
          resolveAt,
          lessThan(startAt),
          reason: 'the cap must be resolved before the process binds a port',
        );
      },
    );

    test('the Scheduler is constructed WITH the guard', () async {
      // The other wiring pin. `Scheduler` without a guard runs UNBOUNDED and
      // says so in `capacitySummary`; a composition that resolved a cap and
      // then failed to pass it would be exactly the shipped bug again, and
      // would still print a reassuring startup line.
      final source = await _readServerSource();
      expect(
        source,
        contains('capacityGuard: capacityGuard,'),
        reason: 'the resolved guard must reach the Scheduler constructor',
      );
      expect(
        source,
        contains("'capacity': scheduler.capacitySummary,"),
        reason:
            'the in-force cap must be visible in `server.composition`, read '
            'back off the scheduler rather than off the local variable',
      );
    });
  });

  group('the advisory lock on PostgresJobStore', () {
    test('the store IS a capacity-locking store', () {
      // If this ever goes false, `JobCapacityGuard` throws
      // `CapacityLockUnavailable` and denies every dispatch. Better that than
      // the degradation it refuses, but it is still an outage.
      final store = PostgresJobStore(PersistenceDatabase(_RecordingDatabase()));
      expect(store, isA<JobStore>());
      expect(
        storeCanLockCapacity(store),
        isTrue,
        reason:
            'a store that cannot make count-then-claim atomic cannot enforce a '
            'cluster-wide cap, and must not be allowed to pretend otherwise',
      );
    });

    test('the lock is taken INSIDE the transaction and BEFORE the body', () async {
      final db = _RecordingDatabase();
      final store = PostgresJobStore(PersistenceDatabase(db));

      await store.inCapacityLockedTransaction(-1234, (tx) async {
        // Any statement the body issues lands after the lock.
        await tx.readJob('job-1');
      });

      expect(db.statements, isNotEmpty);
      final lock = db.statements.first;
      expect(
        lock.sql,
        contains('pg_advisory_xact_lock'),
        reason: 'the first thing the transaction does is take the budget lock',
      );
      expect(
        lock.insideTransaction,
        isTrue,
        reason:
            'taken OUTSIDE the transaction, it would be released by the end of '
            'the implicit single-statement transaction — before the count and '
            'the claim had happened at all',
      );
      expect(
        db.statements.length,
        greaterThan(1),
        reason: 'the body must have run, after the lock',
      );
    });

    test('the lock key is the budget key, passed as a bigint', () async {
      final db = _RecordingDatabase();
      final store = PostgresJobStore(PersistenceDatabase(db));
      final budget = capacityOf(2);

      await store.inCapacityLockedTransaction(budget.advisoryLockKey, (
        tx,
      ) async {
        await tx.readJob('job-1');
      });

      final lock = db.statements.first;
      expect(
        lock.parameters?['lockKey'],
        budget.advisoryLockKey,
        reason:
            'every process must derive the SAME key from the SAME budget name, '
            'or two schedulers take two different locks and the cap is nothing',
      );
      expect(
        lock.sql,
        contains('::bigint'),
        reason:
            'pg_advisory_xact_lock has (bigint) and (int,int) overloads and no '
            '(int4) one; without the cast an integer-typed parameter resolves '
            'to no function at all and the cap fails open at claim time',
      );
      expect(
        lock.sql,
        contains('_xact_'),
        reason:
            'transaction-scoped, not session-scoped: a session lock survives a '
            'thrown error and would hold the budget for ever',
      );
    });

    test('the body receives a JobStore handle, and a throw propagates', () async {
      final db = _RecordingDatabase();
      final store = PostgresJobStore(PersistenceDatabase(db));

      final returned = await store.inCapacityLockedTransaction(
        capacityOf(2).advisoryLockKey,
        (tx) async {
          expect(tx, isA<JobStore>());
          expect(tx, same(store));
          return 'done';
        },
      );
      expect(returned, 'done');

      await expectLater(
        store.inCapacityLockedTransaction(capacityOf(2).advisoryLockKey, (
          tx,
        ) async {
          throw StateError('the claim failed');
        }),
        throwsStateError,
        reason:
            'swallowing this would leave the caller believing a slot was taken '
            'when the transaction rolled back',
      );
    });

    test(
      'two schedulers over ONE durable store contend for ONE slot — no overshoot '
      'by one',
      () async {
        // DOUBLE, NOT POSTGRES. See the file header: no database was involved.
        // [StoreScopedLockingJobStore] models `pg_advisory_xact_lock` as a lock
        // scoped to the DURABLE store — the `Expando` hangs off `inner`, so two
        // wrapper instances over one inner store share one lock, exactly as two
        // connections share one advisory lock in PostgreSQL. A per-wrapper
        // registry would model something else, and would model it wrongly in the
        // dangerous direction: two replicas would each take a private lock, both
        // would admit, and the overshoot this test exists to catch would be
        // invisible.
        //
        // What this proves: the guard admits exactly one of two simultaneous
        // claims against C=1, and the loser observes the winner holding the
        // slot rather than zero.
        // What it does NOT prove: that PostgreSQL blocks the second caller.
        // See the file header.
        final t0 = DateTime.utc(2026, 1, 1, 12);
        final host = _CapacityHost(clock: () => t0);
        final jobs = await host.enqueueAll(['wi-1', 'wi-2']);

        final guard = JobCapacityGuard(
          store: host.store,
          capacity: capacityOf(1),
        );

        final admissions = await Future.wait([
          guard.tryAdmit(
            job: jobs[0],
            ownerId: 'sched-a',
            now: t0,
            lease: const Duration(minutes: 10),
          ),
          guard.tryAdmit(
            job: jobs[1],
            ownerId: 'sched-b',
            now: t0,
            lease: const Duration(minutes: 10),
          ),
        ]);

        final admitted = admissions.where((a) => a.isAdmitted).toList();
        final denied = admissions.where((a) => a.isDenied).toList();

        expect(
          admitted,
          hasLength(1),
          reason:
              'two simultaneous claims against a cap of 1 must not both take '
              'the last slot; that is the overshoot by one',
        );
        expect(denied, hasLength(1));
        expect(
          (denied.single as CapacityDenied).inFlight,
          1,
          reason:
              'the loser must observe the winner holding the slot, not zero',
        );

        final holdingASlot = (await host.jobs())
            .where(
              (j) => j.state == JobState.claimed || j.state == JobState.running,
            )
            .toList();
        expect(
          holdingASlot,
          hasLength(1),
          reason: 'the durable truth must agree with the admission verdict',
        );
      },
    );

    test(
      'two scheduler REPLICAS over one store never put a second execution in '
      'flight',
      () async {
        // Again a DOUBLE — see the file header. Two whole Schedulers, not two
        // claims, because the cap has to survive the shape production actually
        // has: more than one scheduler process over one queue.
        final t0 = DateTime.utc(2026, 1, 1, 12);
        final host = _CapacityHost(clock: () => t0, replicas: 2);
        host.applyCap(capacityOf(1));
        await host.enqueueAll(['wi-1', 'wi-2']);

        host.dispatch.parkRuns = true;
        final ticks = [for (final s in host.schedulers) s.tick()];
        await _waitUntil(
          () => host.dispatch.parked >= 1,
          because: 'a dispatch',
        );
        // Give both replicas a genuine chance to race before anything is let go.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        host.dispatch.releaseAll();
        await _settleAll(ticks);

        expect(
          host.dispatch.observedMaxConcurrency,
          1,
          reason: 'C=1 means one execution, whatever the number of schedulers',
        );
      },
    );

    test('a store that cannot lock is REFUSED rather than degraded', () async {
      // The negative case for the whole mechanism: a store which does not
      // implement `CapacityLockingJobStore` must make the guard DENY, loudly,
      // rather than fall back to a per-process lock that looks like protection.
      final store = InMemoryJobStore();
      expect(
        storeCanLockCapacity(store),
        isFalse,
        reason: 'sanity: the plain in-memory store cannot enforce a global cap',
      );

      final guard = JobCapacityGuard(store: store, capacity: capacityOf(2));
      await expectLater(
        guard.tryAdmit(
          job: Job(
            jobId: 'job-1',
            workItemId: 'wi-1',
            jobType: JobType.triageDefect,
            requiredRole: AgentRole.triageDefect,
            requiredCapabilities: const {},
            priority: JobPriority.low,
            state: JobState.queued,
            dedupeKey: 'wi-1:dup',
            createdAt: DateTime.utc(2026),
            availableAt: DateTime.utc(2026),
            instruction: 'triage',
            attempt: 0,
            maxAttempts: 3,
            version: 0,
          ),
          ownerId: 'sched-a',
          now: DateTime.utc(2026),
          lease: const Duration(minutes: 10),
        ),
        throwsA(
          isA<CapacityLockUnavailable>().having(
            (e) => e.storeType,
            'storeType',
            contains('InMemoryJobStore'),
          ),
        ),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// TEST SUPPORT
// ---------------------------------------------------------------------------

/// Reads `lib/server.dart` as TEXT.
///
/// Resolved through the package URI rather than `File('lib/server.dart')`
/// because `dart test` may be invoked from the repository root OR from
/// `apps/server`, and a CWD-relative path passes in one and throws
/// `PathNotFoundException` in the other. A gate that only passes from one
/// directory is not a gate.
Future<String> _readServerSource() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  if (uri == null) {
    throw StateError('could not resolve the server composition source');
  }
  return File.fromUri(uri).readAsStringSync();
}

/// Collects log lines by event name.
class _LogCapture {
  final List<MapEntry<String, Map<String, dynamic>>> _lines = [];

  void record(String event, Map<String, dynamic> data) =>
      _lines.add(MapEntry(event, data));

  List<Map<String, dynamic>> eventsNamed(String event) =>
      _lines.where((e) => e.key == event).map((e) => e.value).toList();

  List<String> get names => _lines.map((e) => e.key).toList();
}

/// A tick that does not finish until [open] is called.
class _Gate {
  final Completer<void> _completer = Completer<void>();

  bool get isOpen => _completer.isCompleted;

  void open() {
    if (!_completer.isCompleted) _completer.complete();
  }

  Future<void> wait() => _completer.future;
}

/// Deterministic hold-lease timers for [TickSingleFlight].
///
/// The lease timer is the one piece of the guard these tests must CONTROL
/// rather than await. A real 40 ms timer is fine for "the lease eventually
/// fires", but the RECOVERED tick in the recovery test arms its OWN lease,
/// and under load that lease can expire before the recovered tick finishes —
/// firing the lease twice and failing the exact `hasLength(1)` (measured,
/// F-199: `Expected: an object with length of <1>, Actual: [.., ..]`).
/// The injected factory makes lease firing an explicit act of the test:
/// nothing fires until [advance] is called, so the counts these tests assert
/// are exact under any load, while the production default — the real
/// [Timer] — is untouched.
///
/// This is a CLOCK seam, not a weaker assertion: every `hold_expired`,
/// `cancelled` and `completed_late` expectation below is unchanged, and a
/// world where the lease never fires still fails them.
class _LeaseTimers {
  final List<_ManualTimer> _pending = <_ManualTimer>[];
  int _nowMs = 0;

  /// Matches the `Timer(Duration, void Function())` factory type the seam
  /// takes, so a test passes it directly as `leaseTimer: timers.create`.
  Timer create(Duration duration, void Function() callback) {
    final timer = _ManualTimer(_nowMs + duration.inMilliseconds, callback);
    _pending.add(timer);
    return timer;
  }

  /// Fires every armed lease due at or before [elapsed] from now, in due
  /// order, synchronously — the fake clock's only advancement mechanism.
  void advance(Duration elapsed) {
    _nowMs += elapsed.inMilliseconds;
    // Loop, not a single pass: a fired callback may itself arm another timer
    // that is already due. None does today; the loop keeps `advance` honest
    /// if one ever does.
    while (true) {
      final due =
          _pending.where((t) => !t.hasFired && t.dueAtMs <= _nowMs).toList()
            ..sort((a, b) => a.dueAtMs.compareTo(b.dueAtMs));
      if (due.isEmpty) break;
      for (final timer in due) {
        _pending.remove(timer);
        timer.fire();
      }
    }
  }
}

/// A [Timer] that only fires when [_LeaseTimers.advance] says so.
class _ManualTimer implements Timer {
  _ManualTimer(this.dueAtMs, this._callback);

  final int dueAtMs;
  final void Function() _callback;
  var _fired = false;
  var _cancelled = false;

  bool get hasFired => _fired;

  void fire() {
    if (_cancelled || _fired) return;
    _fired = true;
    _callback();
  }

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_fired && !_cancelled;

  @override
  int get tick => _fired ? 0 : -1;
}

/// A statement as it reached the database driver.
class _Statement {
  const _Statement(this.sql, {this.parameters, this.insideTransaction = false});

  final String sql;
  final Map<String, Object?>? parameters;

  /// Whether the driver was handed an open transaction — i.e. whether this ran
  /// INSIDE one rather than as a standalone statement.
  final bool insideTransaction;
}

/// A [Database] that records statements instead of executing them.
///
/// `Database` has a private constructor, so this implements the interface and
/// forwards every member it does not care about to `noSuchMethod`. Nothing here
/// emulates PostgreSQL: the point is to see what SQL the production store emits
/// and whether it was issued inside a transaction — a question a real server
/// answers identically and a double answers without a database.
class _RecordingDatabase implements Database {
  final List<_Statement> statements = <_Statement>[];

  void _record(
    String sql,
    QueryParameters? parameters,
    Transaction? transaction,
  ) => statements.add(
    _Statement(
      sql,
      parameters: parameters?.parameters as Map<String, Object?>?,
      insideTransaction: transaction != null,
    ),
  );

  @override
  Future<int> unsafeExecute(
    String query, {
    QueryParameters? parameters,
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    _record(query, parameters, transaction);
    return 0;
  }

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    QueryParameters? parameters,
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    _record(query, parameters, transaction);
    return _EmptyResult();
  }

  @override
  Future<R> transaction<R>(
    Future<R> Function(Transaction) transactionFn, {
    TransactionSettings? settings,
  }) => transactionFn(_FakeTransaction());

  /// Everything this double does not care about — the typed `find`/`insert`/
  /// `update` helpers, which no store in this file uses.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Present only so [PersistenceDatabase.inTransaction] has a `Transaction` to
/// attach to. Its identity is what `insideTransaction` observes.
class _FakeTransaction implements Transaction {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `unsafeQuery` must return something; every statement this double sees
/// returns no rows.
///
/// Extends `UnmodifiableListView` rather than merely implementing
/// [DatabaseResult]: the latter is an `interface` class, so it hands over
/// `isEmpty` and friends as bare declarations and every one of them would have
/// to be reimplemented here.
class _EmptyResult extends UnmodifiableListView<DatabaseResultRow>
    implements DatabaseResult {
  _EmptyResult() : super(const <DatabaseResultRow>[]);

  @override
  int get affectedRowCount => 0;

  @override
  DatabaseResultSchema get schema => throw StateError(
    'the recording database never parses a row description',
  );
}

/// Resolves a cap the way production does — through the environment variable,
/// never by constructing an `ExecutionCapacity` directly. Its constructor is
/// private precisely so that nothing, including a test, can hand the guard a
/// number that was never read from configuration.
ExecutionCapacity capacityOf(int cap) =>
    ExecutionCapacityResolution.fromEnvironment({
      executionCapacityEnvVar: '$cap',
    }).capacity!;

/// A [JobStore] that models `pg_advisory_xact_lock` as a lock scoped to the
/// DURABLE store.
///
/// ## Read this before believing the test that uses it
///
/// This is a DOUBLE. No PostgreSQL is involved anywhere in this file. It exists
/// because a faithful lock model needs a lock whose lifetime is the DATABASE's
/// rather than a wrapper's, and that needs a double — it is the only honest way
/// to exercise the contention from a lane with no Docker authority.
///
/// The `Expando` hangs off [inner], the durable store, NOT off the wrapper. That
/// is the whole point: two wrapper instances over one inner store share one
/// lock, which is how two connections share one advisory lock. A per-wrapper
/// registry would model a per-process mutex, and would model it in the
/// dangerous direction — two replicas would each take a private lock, both would
/// admit, and the overshoot these tests exist to catch would not reproduce.
class StoreScopedLockingJobStore implements JobStore, CapacityLockingJobStore {
  StoreScopedLockingJobStore(this.inner);

  final JobStore inner;

  /// Budget locks, scoped to the durable store.
  static final Expando<Map<int, Completer<void>>> _locksByDatabase =
      Expando<Map<int, Completer<void>>>('pg-advisory-xact-lock');

  Map<int, Completer<void>> get _locks =>
      _locksByDatabase[inner] ??= <int, Completer<void>>{};

  /// Simulates one durable round trip, so count and claim have a genuine
  /// interleaving point between them. Without one, the overshoot race could not
  /// happen even with the lock removed and these tests would pass vacuously.
  static Future<void> roundTrip() => Future<void>.delayed(Duration.zero);

  @override
  Future<T> inCapacityLockedTransaction<T>(
    int lockKey,
    Future<T> Function(JobStore store) body,
  ) async {
    final locks = _locks;
    final previous = locks[lockKey];
    final mine = Completer<void>();
    locks[lockKey] = mine;
    if (previous != null) await previous.future;
    try {
      return await inner.inTransaction((tx) => body(this));
    } finally {
      // Released on success AND on failure, exactly as COMMIT, ROLLBACK and
      // connection loss release a transaction-scoped advisory lock.
      if (identical(locks[lockKey], mine)) locks.remove(lockKey);
      if (!mine.isCompleted) mine.complete();
    }
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) async {
    await roundTrip();
    final result = await inner.inTransaction((tx) => body(this));
    await roundTrip();
    return result;
  }

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) =>
      inner.saveJob(job, expectedVersion: expectedVersion);

  /// Job ids whose next [readJob] hangs until [releaseParkedReads] —
  /// armed once per id, consumed by the first matching call.
  ///
  /// F-237 detached the run from the tick: a parked `WorkerDispatch.run`
  /// can no longer hold `tick()` open, because `_dispatchOne` returns the
  /// moment the run is STARTED. What can still hold a tick — and what the
  /// recovery tests therefore use as their wedge — is a durable call the
  /// tick body itself awaits. `readJob` is the first one `_dispatchOne`
  /// makes of the job it is about to dispatch, before the claim, so a
  /// parked read leaves that job `queued` and unclaimed for the next tick.
  final Set<String> _parkReadJobFor = <String>{};
  final List<Completer<void>> _parkedReads = <Completer<void>>[];

  /// Arms a one-shot hang on the next [readJob] of [jobId].
  void parkReadJobFor(String jobId) => _parkReadJobFor.add(jobId);

  /// How many reads are currently parked — the observable half of the
  /// wedge, so a test proves the tick is inside it rather than assuming.
  int get parkedReads => _parkedReads.length;

  /// TEARDOWN ONLY — completes every parked read so the tick holding it
  /// can unwind. Same discipline as `_InstrumentedDispatcher.releaseStuck`:
  /// releasing the wedge mid-test is exactly the bug these tests catch.
  void releaseParkedReads() {
    for (final parked in _parkedReads) {
      if (!parked.isCompleted) parked.complete();
    }
    _parkedReads.clear();
    _parkReadJobFor.clear();
  }

  @override
  Future<Job?> readJob(String jobId) async {
    if (_parkReadJobFor.remove(jobId)) {
      final gate = Completer<void>();
      _parkedReads.add(gate);
      await gate.future;
    }
    return inner.readJob(jobId);
  }

  @override
  Future<List<Job>> listJobs() => inner.listJobs();

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) =>
      inner.listJobsForWorkItem(workItemId);

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) =>
      inner.findLatestByDedupeKey(dedupeKey);

  @override
  Future<void> saveClaim(JobClaim claim) => inner.saveClaim(claim);

  @override
  Future<JobClaim?> readClaimForJob(String jobId) =>
      inner.readClaimForJob(jobId);

  @override
  Future<List<JobClaim>> listClaims() => inner.listClaims();

  @override
  Future<void> deleteClaim(String jobId) => inner.deleteClaim(jobId);

  @override
  Future<void> appendEvent(SchedulerEventRecord event) =>
      inner.appendEvent(event);

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) =>
      inner.readEvents(jobId);
}

/// A dispatcher that can park executions open, so simultaneous in-flight work
/// is observable rather than inferred.
class _InstrumentedDispatcher implements WorkerDispatch {
  var _active = 0;

  var observedMaxConcurrency = 0;
  final List<String> _parked = [];
  final List<Completer<void>> _releases = [];

  /// Stuck executions, keyed by work item. See [neverReleaseFor].
  final Map<String, Completer<void>> _neverRelease =
      <String, Completer<void>>{};

  bool parkRuns = false;

  /// Work items whose execution does not come back during the test.
  ///
  /// This is the shape the 2026-10-18 tick actually took: one job's execution
  /// that never returns. Parking EVERYTHING models a slow tick; parking exactly
  /// this item models a STUCK one, and is what lets the recovery test assert
  /// that the queue drains AROUND the stuck item rather than after it. Nothing
  /// here releases it mid-test; [releaseStuck] exists so a finished test can
  /// leave the runner no pending future.
  Set<String> neverReleaseFor = <String>{};

  /// Every work item an execution was actually started for, in order.
  final List<String> startedWorkItems = <String>[];

  int get parked => _parked.length;

  void releaseAll() {
    parkRuns = false;
    for (final release in List<Completer<void>>.from(_releases)) {
      if (!release.isCompleted) release.complete();
    }
    _releases.clear();
    _parked.clear();
  }

  /// TEARDOWN ONLY — lets a "stuck" execution finish once the test has finished
  /// asserting about it. Never call mid-test: doing so is exactly the bug the
  /// recovery tests exist to catch.
  void releaseStuck() {
    for (final stuck in List<Completer<void>>.from(_neverRelease.values)) {
      if (!stuck.isCompleted) stuck.complete();
    }
    _neverRelease.clear();
    releaseAll();
  }

  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      WorkerSelection.dispatched(
        WorkerRegistration(
          workerId: 'w-instrumented',
          poolId: 'instrumented-pool',
          capabilities: {
            for (final c in request.requiredCapabilities)
              c: CapabilitySpec(capability: c, version: '1'),
          },
          status: WorkerStatus.busy,
          currentLoad: _active,
          maxConcurrency: 8,
          lastHeartbeat: DateTime.now(),
        ),
      );

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    _active++;
    if (_active > observedMaxConcurrency) observedMaxConcurrency = _active;
    final release = Completer<void>();
    // Recorded for EVERY execution, parked or not — this list is how a test
    // observes that a dispatch happened at all.
    startedWorkItems.add(request.workItemId);
    if (parkRuns) {
      _parked.add(request.workItemId);
      _releases.add(release);
    }
    try {
      if (parkRuns) {
        if (neverReleaseFor.contains(request.workItemId)) {
          final stuck = Completer<void>();
          _neverRelease[request.workItemId] = stuck;
          await stuck.future;
        }
        await release.future;
      }
      await StoreScopedLockingJobStore.roundTrip();
      final now = DateTime.now().toUtc();
      return WorkerExecutionResult(
        workerExecutionId: request.workerExecutionId,
        workItemId: request.workItemId,
        status: WorkerExecutionStatus.executedPass,
        workerId: 'w-instrumented',
        workspaceId: 'ws-${request.workerExecutionId}',
        startingRevision: request.startingRevision,
        startedAt: now,
        endedAt: now,
        cleanupStatus: WorkerCleanupStatus.removed,
        failureCode: WorkerFailureCode.none,
      );
    } finally {
      _active--;
    }
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

/// One world: a shared durable store and however many replicas the test needs.
class _CapacityHost {
  _CapacityHost({required this._clock, int replicas = 1})
    : innerStore = InMemoryJobStore(),
      workflowStore = InMemoryWorkflowStore() {
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    store = StoreScopedLockingJobStore(innerStore);
    dispatch = _InstrumentedDispatcher();
    schedulers = [
      for (var i = 0; i < replicas; i++) _newScheduler('sched-${i + 1}'),
    ];
  }

  final DateTime Function() _clock;

  /// The durable truth a "restart" would find on disk.
  final InMemoryJobStore innerStore;
  final WorkflowStore workflowStore;

  late final DurableWorkflowEngine workflowEngine;
  late final StoreScopedLockingJobStore store;
  late final _InstrumentedDispatcher dispatch;
  late List<Scheduler> schedulers;

  static const SchedulerWorkload _workload = SchedulerWorkload(
    repositoryPath: '/tmp/capacity',
    startingRevision: 'deadbeef',
    timeoutSeconds: 60,
    runtimeTypeId: 'instrumented-runtime',
  );

  Scheduler _newScheduler(
    String id, {
    JobCapacityGuard? capacityGuard,
  }) => Scheduler(
    schedulerId: id,
    workflowStore: workflowStore,
    jobStore: store,
    workerStore: InMemoryWorkerStore(),
    dispatch: dispatch,
    definition: defaultImplementFeatureDefinition,
    workload: _workload,
    clock: _clock,
    capacityGuard: capacityGuard,
    dedupeKeyBuilder: (item, definition) => _dedupeKey(item),
  );

  void applyCap(ExecutionCapacity capacity) {
    schedulers = [
      for (final existing in schedulers)
        _newScheduler(
          existing.schedulerId,
          capacityGuard: JobCapacityGuard(store: store, capacity: capacity),
        ),
    ];
  }

  /// One dedupe key every job in these tests uses, so a test can name the key it
  /// enqueued under and be certain a tick will look for the same one.
  String _dedupeKey(WorkItem item) => '${item.workItemId}:capacity';

  /// Creates work items AND enqueues their jobs, sequentially.
  ///
  /// Sequential on purpose: `InMemoryJobStore` has no active-dedupe unique
  /// constraint (PostgreSQL has `job_active_dedupe_unique`), so two replicas
  /// enqueueing one work item at the same instant would both insert. That is a
  /// property of this in-memory double, not of the capacity cap, and letting it
  /// in would measure the wrong thing. These tests are about claim-time
  /// admission, so the queue starts full and deterministic.
  Future<List<Job>> enqueueAll(List<String> workItemIds) async {
    final queue = JobQueue(store: store, clock: _clock);
    final jobs = <Job>[];
    for (final id in workItemIds) {
      await _itemRunnable(id);
      jobs.add(
        (await queue.enqueueIfAbsent(
          workItemId: id,
          definition: defaultImplementFeatureDefinition,
          dedupeKey: _dedupeKey(await workflowEngine.loadWorkItem(id)),
          instruction: 'work on $id',
          now: _clock().toUtc(),
        )).job,
      );
    }
    return jobs;
  }

  /// Parks a work item at a RUNNABLE entry state.
  ///
  /// The `featureRef` context on the `planned` transition is not decoration:
  /// `Planning -> planned` is rejected without traceability, so omitting it
  /// fails at setup and never reaches the capacity assertion.
  Future<void> _itemRunnable(String workItemId) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Item $workItemId',
      description: 'Capacity-cap test item $workItemId',
      qaContractId: 'qa-$workItemId',
      featureRef: 'feature/$workItemId',
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: {'featureRef': 'feature/$workItemId'},
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  Future<List<Job>> jobs() => innerStore.listJobs();
}

Future<void> _waitUntil(
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

/// Awaits every one of [futures], failing with a named diagnostic instead of
/// hanging until the framework's blanket timeout.
Future<void> _settleAll(
  List<Future<Object?>> futures, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  var pending = futures.length;
  if (pending == 0) return;
  for (final f in futures) {
    unawaited(f.then((_) => pending--, onError: (_) => pending--));
  }
  final deadline = DateTime.now().add(timeout);
  while (pending > 0) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('timed out waiting for $pending tick(s) to settle');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

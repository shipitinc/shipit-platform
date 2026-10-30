import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:scheduler/src/capacity/capacity_lockable_store.dart';
import 'package:scheduler/src/capacity/job_capacity_guard.dart';
import 'package:test/test.dart';

import 'capacity_harness.dart';

/// The global concurrency cap, T1-T5 and T11 from the design's test table.
///
/// The workload this file exists to make impossible: N queued defects, more of
/// them arriving at once than there are slots, on a host that cannot absorb the
/// difference. The assertions are on the PEAK number of simultaneous agent
/// executions, not on any end state, because a cap that is briefly exceeded and
/// then re-converges looks perfect to an end-state assertion — and the peak is
/// the only thing that exhausts a host.
void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);
  DateTime clock() => t0;

  group('global execution-capacity cap', () {
    test(
      'T1: with N > C queued jobs the observed maximum concurrency is exactly C '
      'and never exceeds it',
      () async {
        // Three replicas over one durable store: more schedulers than slots, so
        // the cap has to be doing the work rather than the tick topology.
        final host = CapacityHost(clock: clock, replicas: 3);
        host.applyCap(2);
        await host.enqueueAll(['wi-1', 'wi-2', 'wi-3', 'wi-4', 'wi-5']);
        host.dispatch.parkRuns = true;

        // Tick one, which enqueues all five and starts the first execution.
        final a = host.schedulers[0].tick();
        await waitUntil(
          () => host.dispatch.parked >= 1,
          because: 'the first execution to enter the runtime',
        );

        // Tick two admits the second slot — or the first tick already did:
        // detached dispatch starts every admitted run inside the same tick,
        // and the budget — not the tick topology — is what caps it at two.
        final b = host.schedulers[1].tick();
        await waitUntil(
          () => host.dispatch.parked == 2,
          because: 'the second execution to enter the runtime',
        );

        // Tick three finds the budget full and completes. Every remaining job
        // it considers must be refused rather than admitted — so it is awaited
        // rather than sampled, or the assertions below would race it.
        final c = host.schedulers[2].tick();
        await c;
        expect(
          await capacityDenials(host.innerStore),
          greaterThanOrEqualTo(1),
          reason: 'the third tick must refuse work, not idle',
        );

        // THE ASSERTION: the peak, not the final count.
        expect(
          host.dispatch.observedMaxConcurrency,
          2,
          reason:
              'five queued jobs and a cap of two must never put a third '
              'execution in flight',
        );
        expect(
          host.dispatch.started,
          hasLength(2),
          reason: 'only two executions may ever have entered the runtime',
        );

        // Assessed while both slots are still HELD. Once the runs are released
        // the ticks carry on and drain the backlog, which is correct and would
        // hide the state the test is actually about.
        final allStates =
            (await host.jobs())
                .map((j) => '${j.workItemId}=${j.state.wire}')
                .toList()
              ..sort();
        expect(
          allStates,
          [
            'wi-1=running',
            'wi-2=running',
            'wi-3=queued',
            'wi-4=queued',
            'wi-5=queued',
          ],
          reason:
              'a denied job stays queued; it is never failed and never '
              'discarded',
        );
        for (final job in await host.jobs()) {
          if (job.workItemId != 'wi-1' && job.workItemId != 'wi-2') {
            expect(
              job.failure,
              isNull,
              reason:
                  'capacity denial is not a failure and must never be '
                  'recorded as one',
            );
          }
        }

        host.dispatch.releaseAll();
        await settleAll([a, b], because: 'the two saturated ticks');
      },
    );

    test(
      'T2: the cap holds across ticks, not merely within one tick',
      () async {
        // Overlapping ticks are the mechanism the design identifies as the
        // amplifier (§1.5): one tick's dispatch loop awaits each execution, so
        // concurrency comes from a SECOND tick running while the first is still
        // inside one. A cap enforced only within a tick would reset every tick
        // and let the backlog drain at whatever rate the queue offered.
        //
        // Two replicas over one store; four ticks in sequence; the assertion is
        // on the peak across the WHOLE run.
        final host = CapacityHost(clock: clock, replicas: 2);
        host.applyCap(2);
        await host.enqueueAll(['wi-1', 'wi-2', 'wi-3', 'wi-4', 'wi-5', 'wi-6']);

        host.dispatch.parkRuns = true;

        // Two overlapping ticks fill the budget and park.
        final first = host.schedulers[0].tick();
        await waitUntil(
          () => host.dispatch.parked >= 1,
          because: 'the first slot',
        );
        final second = host.schedulers[1].tick();
        await waitUntil(
          () => host.dispatch.parked == 2,
          because: 'the second slot',
        );

        // Two more ticks run WHILE both slots are held. Neither may admit.
        final duringA = host.schedulers[0].tick();
        final duringB = host.schedulers[1].tick();
        await waitUntil(
          () => host.dispatch.started.length >= 2,
          because: 'the budget to saturate',
        );
        for (var i = 0; i < 10; i++) {
          await SerializedJobStore.roundTrip();
        }

        expect(
          host.dispatch.observedMaxConcurrency,
          2,
          reason:
              'a tick that starts while the budget is full must not '
              'overrun it',
        );
        expect(
          host.dispatch.started,
          hasLength(2),
          reason: 'no job may enter the runtime while two already are',
        );

        host.dispatch.releaseAll();
        await settleAll([
          first,
          second,
          duringA,
          duringB,
        ], because: 'the ticks that ran against a full budget');

        // Later ticks, with the budget free again, drain the rest — and the
        // peak over the entire run still never exceeded C. Detached dispatch
        // (F-237): each completed run settles through reconcile-adoption on
        // the tick after its claim is released, which is what frees its slot.
        for (var i = 0; i < 4; i++) {
          await settleHeldJobs(host.store, host.schedulers[i % 2]);
        }

        expect(
          host.dispatch.observedMaxConcurrency,
          2,
          reason: 'across every tick of the run, the peak stayed at the cap',
        );
        expect(
          host.dispatch.started,
          hasLength(6),
          reason:
              'the backlog drains eventually — the cap delays, it never '
              'drops work',
        );
      },
    );

    test('T3: a job refused a slot stays queued, is reported as deferred, and '
        'succeeds on a later tick', () async {
      final host = CapacityHost(clock: clock, replicas: 2);
      host.applyCap(1);
      await host.enqueueAll(['wi-1', 'wi-2']);
      host.dispatch.parkRuns = true;

      // Fill the single slot from the first replica.
      final holder = host.schedulers[0].tick();
      await waitUntil(
        () => host.dispatch.parked == 1,
        because: 'the single slot to be taken',
      );

      // The second replica finds the budget full.
      final denied = host.schedulers[1].tick();
      final deniedResult = await denied;

      expect(deniedResult.dispatched, isEmpty);
      expect(
        deniedResult.deferred,
        isNotEmpty,
        reason:
            'a refused job is reported through the existing deferred '
            'channel, which is the honest-reporting path already used for '
            '"no worker was free"',
      );
      expect(
        deniedResult.terminal,
        isEmpty,
        reason: 'refusal is not a terminal outcome',
      );

      // Exactly what state the refused job is in.
      final jobs = (await host.jobs())
        ..sort((a, b) => a.jobId.compareTo(b.jobId));
      final refused = jobs.firstWhere((j) => j.workItemId == 'wi-2');
      expect(refused.state, JobState.queued);
      expect(
        refused.failure,
        isNull,
        reason:
            'no capacity is not a failure and must never be recorded as '
            'one',
      );
      expect(
        await host.innerStore.readClaimForJob(refused.jobId),
        isNull,
        reason: 'a refused job takes no lease',
      );

      host.dispatch.releaseAll();
      await settleAll([holder], because: 'the tick that held the slot');

      // A later tick, with the budget free, picks the refused job up and it
      // completes. Nothing was lost and nothing needed intervention. The
      // holder's run settles through reconcile-adoption first — that is what
      // frees the slot — and the refused job's own run settles a tick later
      // (F-237).
      host.dispatch.parkRuns = false;
      await settleHeldJobs(host.store, host.schedulers[1]);
      await settleHeldJobs(host.store, host.schedulers[1]);

      expect(
        (await host.innerStore.readJob(refused.jobId))!.state,
        JobState.succeeded,
        reason: 'the refused job is retried on a later tick and succeeds',
      );
    });

    test(
      'T4: two concurrent claims cannot both take the last slot (no overshoot '
      'by one)',
      () async {
        // The classic semaphore race, aimed straight at the guard: C=1, two
        // queued jobs, two claims attempted at the same instant. With the
        // budget lock removed, both read inFlight = 0 and both admit — which is
        // what makes this a test of the lock and not of the arithmetic.
        final host = CapacityHost(clock: clock);
        final jobs = await host.enqueueAll(['wi-1', 'wi-2']);

        final guard = host.guardFor(1);
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
              'exactly one of two simultaneous claims may take the last '
              'slot; two would exceed the cap of 1',
        );
        expect(denied, hasLength(1));
        expect(
          (denied.single as CapacityDenied).inFlight,
          1,
          reason: 'the loser observed the winner holding the slot, not zero',
        );

        // And the durable truth agrees: exactly one job holds a lease.
        final held = (await host.jobs())
            .where(
              (j) => j.state == JobState.claimed || j.state == JobState.running,
            )
            .toList();
        expect(held, hasLength(1));
      },
    );

    test(
      'T4b: two scheduler replicas racing the same queue with C=1 never put a '
      'second execution in flight',
      () async {
        final host = CapacityHost(clock: clock, replicas: 2);
        host.applyCap(1);
        await host.enqueueAll(['wi-1', 'wi-2']);
        host.dispatch.parkRuns = true;

        // Both replicas tick at once, against one slot. Whichever wins takes
        // it; the other must be refused WHILE the winner is still inside the
        // runtime. Parking is what makes "still inside the runtime" a real
        // interval rather than a timing accident.
        final a = host.schedulers[0].tick();
        final b = host.schedulers[1].tick();

        await waitUntil(
          () => host.dispatch.started.length >= 1,
          because: 'a replica to take the single slot',
        );
        // Wait for the loser to have been refused, so the assertion below is
        // about a completed decision rather than a race not yet made.
        await waitUntil(
          () async => await capacityDenials(host.innerStore) >= 1,
          because: 'the losing replica to be refused',
        );
        for (var i = 0; i < 10; i++) {
          await SerializedJobStore.roundTrip();
        }

        expect(
          host.dispatch.observedMaxConcurrency,
          1,
          reason:
              'two replicas, two queued jobs, one slot: the loser must be '
              'refused, or the cap is exceeded by exactly one',
        );
        expect(
          host.dispatch.started,
          hasLength(1),
          reason:
              'only one replica may enter the runtime while the slot is '
              'held',
        );

        host.dispatch.releaseAll();
        await settleAll([a, b], because: 'the two racing ticks');

        // Whichever was refused is queued and picked up by a later tick; the
        // winner settles through reconcile-adoption (F-237) before its slot
        // frees for the runner-up.
        await settleHeldJobs(host.store, host.schedulers[0]);
        await settleHeldJobs(host.store, host.schedulers[0]);
        expect(
          (await host.jobs()).where((j) => j.state == JobState.succeeded),
          hasLength(2),
          reason: 'the runner-up is queued for a later tick, never lost',
        );
      },
    );

    test(
      'T5: the cap survives a restart — a fresh scheduler counts running jobs '
      'from the store, not from memory',
      () async {
        // An in-process counter would read zero here and admit a third
        // execution on top of the two durably recorded as running. That is
        // exactly the post-crash state the host died in.
        final host = CapacityHost(clock: clock, replicas: 2);
        host.applyCap(2);
        await host.enqueueAll(['wi-1', 'wi-2', 'wi-3']);
        host.dispatch.parkRuns = true;

        final first = host.schedulers[0].tick();
        await waitUntil(
          () => host.dispatch.parked >= 1,
          because: 'the first slot',
        );
        final second = host.schedulers[1].tick();
        await waitUntil(
          () => host.dispatch.parked == 2,
          because: 'the second slot',
        );
        expect(host.dispatch.observedMaxConcurrency, 2);

        // Restart: a brand-new store wrapper, a brand-new scheduler, a
        // brand-new dispatcher, over the SAME durable state. Nothing in-process
        // carries over — in particular no capacity counter could survive this.
        final restarted = host.restart(cap: 2);
        restarted.dispatch.parkRuns = true;
        final third = restarted.scheduler.tick();
        for (var i = 0; i < 10; i++) {
          await SerializedJobStore.roundTrip();
        }

        expect(
          restarted.dispatch.started,
          isEmpty,
          reason:
              'the restarted process must count the two durably running '
              'jobs and admit nothing; an in-memory counter would read zero '
              'here and let a third execution start on top of two',
        );

        expect(
          restarted.dispatch.observedMaxConcurrency,
          0,
          reason: 'the restarted process never entered the runtime at all',
        );

        // Release the two held executions. Their slots free, and the
        // RESTARTED process — which had been refused while they were held —
        // takes the next one. This is the other half of restart-stability:
        // the cap neither blocks a restarted process nor loses its accounting
        // when the work it was counting finishes.
        host.dispatch.releaseAll();
        // The RESTARTED process does the adopting tick: its reconcile frees
        // the two held slots and the same tick's dispatch phase takes one for
        // wi-3 — settleHeldJobs waits for the claim releases and then drives
        // exactly that tick (F-237).
        await settleHeldJobs(host.store, restarted.scheduler);
        await waitUntil(() async {
          await restarted.scheduler.tick();
          return restarted.dispatch.started.length >= 1;
        }, because: 'the restarted process to take a freed slot');

        expect(
          restarted.dispatch.started,
          hasLength(1),
          reason:
              'the restarted process admits one job once capacity frees, '
              'not three',
        );
        expect(
          restarted.dispatch.observedMaxConcurrency,
          1,
          reason: 'and never runs two at once',
        );

        restarted.dispatch.releaseAll();
        await settleAll([
          first,
          second,
          third,
        ], because: 'every tick to finish once the executions were released');
        await settleHeldJobs(host.store, host.schedulers[0]);

        expect(
          host.dispatch.observedMaxConcurrency,
          2,
          reason: 'the pre-restart process never exceeded the cap either',
        );
        expect(
          (await host.jobs()).every((j) => j.state == JobState.succeeded),
          isTrue,
          reason:
              'every queued job eventually completes across the restart; '
              'the cap delays work, it never destroys it',
        );
      },
    );

    test(
      'T11: every capacity denial is recorded in the audit log with the job, '
      'the budget, the observed count and the cap',
      () async {
        final host = CapacityHost(clock: clock, replicas: 2);
        host.applyCap(1);
        await host.enqueueAll(['wi-1', 'wi-2']);
        host.dispatch.parkRuns = true;

        final holder = host.schedulers[0].tick();
        await waitUntil(() => host.dispatch.parked == 1);
        await host.schedulers[1].tick();

        final refused = (await host.jobs()).firstWhere(
          (j) => j.workItemId == 'wi-2',
        );
        final events = await host.innerStore.readEvents(refused.jobId);
        final denial = events
            .where((e) => e.payload?['outcome'] == 'capacityDenied')
            .toList();

        expect(
          denial,
          isNotEmpty,
          reason:
              'a silent denial is the failure '
              'mode this record exists to prevent',
        );
        final payload = denial.first.payload!;
        expect(payload['jobId'], refused.jobId);
        expect(payload['budget'], 'agent_executions');
        expect(payload['inFlight'], 1);
        expect(payload['cap'], 1);

        host.dispatch.releaseAll();
        await settleAll([holder], because: 'the tick that held the slot');
      },
    );

    test(
      'the cap is global: nine queued defects for one product are still bounded '
      'by one budget',
      () async {
        // Per-product scoping would bound nothing at the host while reading as
        // if it did: nine defects, one product, still nine slots of one budget.
        final host = CapacityHost(clock: clock, replicas: 4);
        host.applyCap(2);
        await host.enqueueAll([
          'wi-1',
          'wi-2',
          'wi-3',
          'wi-4',
          'wi-5',
          'wi-6',
          'wi-7',
          'wi-8',
          'wi-9',
        ]);
        host.dispatch.parkRuns = true;

        final ticks = [
          host.schedulers[0].tick(),
          host.schedulers[1].tick(),
          host.schedulers[2].tick(),
          host.schedulers[3].tick(),
        ];
        await waitUntil(
          () => host.dispatch.parked == 2,
          because: 'the budget to saturate',
        );
        for (var i = 0; i < 6; i++) {
          await SerializedJobStore.roundTrip();
        }

        expect(
          host.dispatch.observedMaxConcurrency,
          2,
          reason:
              'nine defects of a single product must not produce nine '
              'concurrent agent executions',
        );

        host.dispatch.releaseAll();
        await settleAll(ticks, because: 'the four racing ticks');
      },
    );

    test(
      'a store that cannot lock the budget denies loudly rather than running '
      'unbounded',
      () async {
        // An in-memory store cannot make count-then-claim atomic across
        // processes. Silently admitting here would be a cap that cannot be
        // enforced while reporting that it was.
        final guard = JobCapacityGuard(
          store: InMemoryJobStore(),
          capacity: capacityOf(1),
        );
        expect(storeCanLockCapacity(InMemoryJobStore()), isFalse);
        await expectLater(
          guard.tryAdmit(
            job: _job('jb-1'),
            ownerId: 'sched-1',
            now: t0,
            lease: const Duration(minutes: 10),
          ),
          throwsA(isA<CapacityLockUnavailable>()),
        );
      },
    );

    test(
      'a scheduler with no capacity guard reports itself as UNBOUNDED rather '
      'than claiming a cap it does not have',
      () async {
        final host = CapacityHost(clock: clock);
        expect(
          host.scheduler.capacitySummary,
          allOf(
            contains('NOT configured'),
            contains('UNBOUNDED'),
            contains('SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS'),
          ),
        );
        expect(host.scheduler.capacitySummary, isNot(contains('C=')));
      },
    );

    test(
      'a scheduler with a guard names the resolved cap in both directions',
      () async {
        final host = CapacityHost(clock: clock);
        host.applyCap(2);
        expect(
          host.scheduler.capacitySummary,
          allOf(
            contains('budget=agent_executions'),
            contains('SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS=2'),
            contains('global'),
          ),
        );
      },
    );
  });
}

Job _job(String id) => Job(
  jobId: id,
  workItemId: 'wi-1',
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {WorkerCapability.linux},
  priority: JobPriority.normal,
  state: JobState.queued,
  dedupeKey: 'k-$id',
  createdAt: DateTime.utc(2026, 1, 1),
  instruction: 'x',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

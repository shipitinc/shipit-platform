import 'dart:async';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/src/health/provider_health_monitor.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import 'health_store.dart';

/// The rules that decide whether a provider is DOWN.
///
/// Every case here is about the direction a failure travels. A probe that could
/// not run must never close the platform's dispatch; a probe that ran and
/// failed must still be able to open an infrastructure decision. Getting either
/// half wrong stops the platform doing any work, which is what shipped: an
/// absent `OPENCODE_<PROVIDER>_API_KEY` was reported as an outage, 48 blocking
/// `hd-all-down-*` decisions accumulated, and `_eligibleRunnableJobs` skipped
/// every job for every role with nothing in any log.
void main() {
  /// A monitor over in-memory stores, a scripted probe and a capturing log.
  ///
  /// [InMemoryModelPolicyStore] seeds every role onto the single provider
  /// `opencode`, which is the production shape: one provider serving all
  /// thirteen roles.
  ({ProviderHealthMonitor monitor, InMemoryWorkflowStore store, _Logs logs})
  harness({required ProviderProbe probe, int failureThreshold = 2}) {
    final store = InMemoryWorkflowStore();
    final logs = _Logs();
    final monitor = ProviderHealthMonitor(
      modelPolicyStore: InMemoryModelPolicyStore(),
      workflowStore: store,
      humanDecisionStore: WorkflowStoreHumanDecisionStore(store),
      probe: probe,
      failureThreshold: failureThreshold,
      log: logs.record,
    );
    return (monitor: monitor, store: store, logs: logs);
  }

  ProviderProbe always(ProviderProbeResult result) =>
      (_) async => result;

  group('a probe that never ran', () {
    test(
      'is not a down provider and raises nothing, however many cycles pass',
      () async {
        final h = harness(
          probe: always(
            const ProviderProbeResult.unknown(
              'probe could not start "opencode"',
            ),
          ),
        );

        for (var i = 0; i < 5; i++) {
          await h.monitor.checkAll();
        }

        final health = h.monitor.getProviderHealth()['opencode']!;
        expect(health.verdict, ProviderProbeVerdict.unknown);
        expect(health.isDown, isFalse);
        expect(health.isUnknown, isTrue);
        expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isFalse);
        expect(h.monitor.hasAllProvidersDown(AgentRole.implementer), isFalse);
        expect(h.monitor.getAllProvidersDownTickets(), isEmpty);
        expect(await _decisions(h.store), isEmpty);
      },
    );

    test('is never allowed to accumulate into a down verdict', () async {
      // The counter is evidence, and an absent observation is not evidence.
      // Interleaving unrunnable probes with failing ones must not make the
      // provider down sooner than the failing probes alone would.
      var cycle = 0;
      final h = harness(
        probe: (_) async {
          cycle++;
          return cycle.isEven
              ? const ProviderProbeResult.unknown('no observation')
              : const ProviderProbeResult.unhealthy('probe exited 1');
        },
        failureThreshold: 3,
      );

      for (var i = 0; i < 4; i++) {
        await h.monitor.checkAll();
        expect(
          h.monitor.getProviderHealth()['opencode']!.isDown,
          isFalse,
          reason: 'cycle $i must not be down on one failure at threshold 3',
        );
      }
    });
  });

  group('a probe that ran and failed', () {
    test('marks the provider down once the threshold is reached', () async {
      final h = harness(
        probe: always(
          const ProviderProbeResult.unhealthy('probe exited 1: unauthorized'),
        ),
      );

      await h.monitor.checkAll();
      final afterOne = h.monitor.getProviderHealth()['opencode']!;
      expect(afterOne.verdict, ProviderProbeVerdict.unhealthy);
      expect(afterOne.consecutiveFailures, 1);
      expect(
        afterOne.isDown,
        isFalse,
        reason: 'one failing probe is not an outage',
      );
      expect(await _decisions(h.store), isEmpty);

      await h.monitor.checkAll();
      final afterTwo = h.monitor.getProviderHealth()['opencode']!;
      expect(afterTwo.consecutiveFailures, 2);
      expect(afterTwo.isDown, isTrue);

      final decisions = await _decisions(h.store);
      expect(
        decisions.where((d) => d.decisionId.startsWith('hd-provider-')),
        hasLength(1),
      );
      expect(
        decisions.where((d) => d.decisionId.startsWith('hd-all-down-')),
        hasLength(AgentRole.values.length),
      );
      expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isTrue);
    });

    test(
      'records the observed reason rather than a guessed category',
      () async {
        final h = harness(
          probe: always(
            const ProviderProbeResult.unhealthy('probe exited 3: credit error'),
          ),
        );
        await h.monitor.checkAll();
        await h.monitor.checkAll();

        final ticket = (await _decisions(
          h.store,
        )).firstWhere((d) => d.decisionId.startsWith('hd-provider-'));
        expect(ticket.metadata?['error'], 'probe exited 3: credit error');
      },
    );

    test('a recovery resets the counter', () async {
      var fail = true;
      final h = harness(
        probe: (_) async => fail
            ? const ProviderProbeResult.unhealthy('probe exited 1')
            : const ProviderProbeResult.healthy(),
      );

      await h.monitor.checkAll();
      expect(h.monitor.getProviderHealth()['opencode']!.consecutiveFailures, 1);

      fail = false;
      await h.monitor.checkAll();
      expect(h.monitor.getProviderHealth()['opencode']!.consecutiveFailures, 0);
      expect(h.monitor.getProviderHealth()['opencode']!.isDown, isFalse);
    });
  });

  group('observability', () {
    test('a provider going down is logged', () async {
      final h = harness(
        probe: always(
          const ProviderProbeResult.unhealthy('probe exited 1: unauthorized'),
        ),
      );

      await h.monitor.checkAll();
      await h.monitor.checkAll();

      final down = h.logs.linesFor('provider_health.provider_down');
      expect(down, hasLength(1));
      expect(down.single['provider'], 'opencode');
      expect(down.single['reason'], 'probe exited 1: unauthorized');
      expect(down.single['consecutiveFailures'], 2);
    });

    test(
      'a probe that could not run is logged, and says it changed nothing',
      () async {
        final h = harness(
          probe: always(
            const ProviderProbeResult.unknown('probe could not start'),
          ),
        );

        await h.monitor.checkAll();

        final unknown = h.logs.linesFor('provider_health.probe_unknown');
        expect(unknown, hasLength(1));
        expect(unknown.single['provider'], 'opencode');
        expect(unknown.single['action'], contains('NOT marked down'));
      },
    );

    test(
      'a role going all-down is logged with the evidence behind it',
      () async {
        final h = harness(
          probe: always(
            const ProviderProbeResult.unhealthy('probe exited 1: unauthorized'),
          ),
        );

        await h.monitor.checkAll();
        await h.monitor.checkAll();

        final allDown = h.logs.linesFor('provider_health.all_providers_down');
        expect(allDown, isNotEmpty);
        expect(
          allDown.map((l) => l['role']),
          containsAll(AgentRole.values.map((r) => r.wire)),
        );
        final triage = allDown.firstWhere(
          (l) => l['role'] == AgentRole.triageDefect.wire,
        );
        expect(triage['downProviders'], ['opencode']);
        expect(triage['evidence'], {'opencode': contains('unauthorized')});
      },
    );

    test(
      'the steady state logs nothing, so the signal is the transitions',
      () async {
        final h = harness(
          probe: always(const ProviderProbeResult.unknown('not installed')),
        );

        await h.monitor.checkAll();
        await h.monitor.checkAll();
        await h.monitor.checkAll();

        expect(h.logs.events, hasLength(1));
      },
    );
  });

  group('recovery', () {
    test(
      'clears the role and releases it without a human acknowledgement',
      () async {
        var healthy = false;
        final h = harness(
          probe: (_) async => healthy
              ? const ProviderProbeResult.healthy()
              : const ProviderProbeResult.unhealthy('probe exited 1'),
        );

        await h.monitor.checkAll();
        await h.monitor.checkAll();
        expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isTrue);

        healthy = true;
        await h.monitor.checkAll();

        expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isFalse);
        expect(h.monitor.getAllProvidersDownTickets(), isEmpty);

        final recovered = h.logs.linesFor(
          'provider_health.all_providers_recovered',
        );
        expect(recovered, isNotEmpty);
        expect(
          recovered.map((l) => l['role']),
          containsAll(AgentRole.values.map((r) => r.wire)),
        );
        expect(
          h.logs
              .linesFor('provider_health.provider_recovered')
              .first['provider'],
          'opencode',
        );
      },
    );
  });

  group('a second monitor over the same durable store', () {
    // `failureThreshold: 1` so a single failing probe is enough: this models a
    // LONG outage spanning several process lifetimes, which is the shape that
    // produced the ticket pile-up.
    ProviderHealthMonitor build(WorkflowStore store) => ProviderHealthMonitor(
      modelPolicyStore: InMemoryModelPolicyStore(),
      workflowStore: store,
      humanDecisionStore: WorkflowStoreHumanDecisionStore(store),
      probe: always(const ProviderProbeResult.unhealthy('probe exited 1')),
      failureThreshold: 1,
      log: (_, _) {},
    );

    test('adopts the open ticket instead of minting a duplicate', () async {
      final store = InMemoryWorkflowStore();

      await build(store).checkAll();
      await build(store).checkAll();
      await build(store).checkAll();

      // Three process lifetimes, one outage, one ticket per role. The previous
      // behaviour keyed the in-memory map only, so every restart minted a
      // fresh blocking decision for a role that was already blocked.
      final allDown = (await _decisions(
        store,
      )).where((d) => d.decisionId.startsWith('hd-all-down-')).toList();
      expect(allDown, hasLength(AgentRole.values.length));
    });

    test(
      'a stale ticket alone does not block: adoption needs fresh evidence',
      () async {
        final store = InMemoryWorkflowStore();
        await build(store).checkAll();
        expect(
          (await _decisions(
            store,
          )).where((d) => d.decisionId.startsWith('hd-all-down-')),
          isNotEmpty,
        );

        // A new process in which the provider is healthy again: the stale
        // durable record must not keep the role dark.
        final restarted = ProviderHealthMonitor(
          modelPolicyStore: InMemoryModelPolicyStore(),
          workflowStore: store,
          humanDecisionStore: WorkflowStoreHumanDecisionStore(store),
          probe: always(const ProviderProbeResult.healthy()),
          log: (_, _) {},
        );
        await restarted.checkAll();

        expect(restarted.hasAllProvidersDown(AgentRole.triageDefect), isFalse);
      },
    );

    test('adoption is not a weakening: a real outage still blocks', () async {
      final store = InMemoryWorkflowStore();
      await build(store).checkAll();

      final monitor = build(store);
      await monitor.checkAll();
      expect(monitor.hasAllProvidersDown(AgentRole.triageDefect), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // A CLOSED DATABASE CONNECTION.
  //
  // Reproduces the 2026-10-17 QA outage, in which the whole scheduler isolate
  // died silently and took the 30-second tick with it.
  //
  // What is being pinned here is NOT "the monitor logs something". It is the
  // weaker and much more important property: **a failing future that escapes
  // here must not escape the monitor at all**. In a Dart isolate with no
  // `runZonedGuarded` guard, an unhandled asynchronous error TERMINATES the
  // isolate — and `package:test` reports an unhandled error as a test failure,
  // which makes the test framework itself the detector. A regression re-opens
  // the production outage and these tests go red without any assertion change.
  // ---------------------------------------------------------------------------
  group('a closed database connection', () {
    test('is reproduced by a REAL locally-closed socket, not a hand-written '
        'stand-in', () async {
      // The production stack is `Bad state: StreamSink is closed` thrown from
      // `_StreamSinkImpl.add` (dart:io/io_sink.dart) via `_Socket.add`. That
      // is dart:io's own error for a CLOSED LOCAL SINK, so it is reproduced
      // here by actually closing a socket — on loopback, with no docker, no
      // psql and no database. Every assertion below is then made against the
      // genuine error object rather than a mock that merely looks like it.
      final error = await realClosedSinkError();

      expect(error, isStateError);
      expect(
        '$error',
        'Bad state: StreamSink is closed',
        reason:
            'this is the exact error in the 2026-10-17 crash log; if '
            'dart:io changes it, the fixtures below are wrong and this is '
            'where it should be noticed',
      );
    });

    test('a write against a closed sink is caught, not propagated out of '
        'checkAll()', () async {
      // The production shape, in order: the probe runs and reports, and THEN
      // the asynchronous write fires against a connection that has already
      // closed. `saveHumanDecision` is that write.
      final logs = _Logs();
      final workflow = InMemoryWorkflowStore();
      final store = _FaultyWorkflowStore(
        workflow,
        faults: {'saveHumanDecision'},
      );
      final monitor = ProviderHealthMonitor(
        modelPolicyStore: InMemoryModelPolicyStore(),
        workflowStore: store,
        humanDecisionStore: WorkflowStoreHumanDecisionStore(store),
        // Down on the FIRST probe so a ticket is attempted, which is what
        // reaches the write. `failureThreshold: 1` is the whole setup: with
        // the default of 2 there is no write on cycle one and the failure
        // this test pins could not occur.
        probe: always(const ProviderProbeResult.unhealthy('probe exited 1')),
        failureThreshold: 1,
        log: logs.record,
      );

      await expectLater(
        monitor.checkAll(),
        completes,
        reason: 'a dead connection must cost one write, not the cycle',
      );

      final failed = logs.linesFor('provider_health.check.failed');
      expect(failed, isNotEmpty);
      expect(failed.first['operation'], 'provider_ticket');
      expect(
        '${failed.first['error']}',
        'Bad state: StreamSink is closed',
        reason:
            'the log line must carry the real error, not "something '
            'went wrong" — this outage was invisible partly because nothing '
            'named a cause',
      );
      expect(failed.first['stack'], isNotEmpty);

      // The cycle still PROBED: a failed write must not stop the monitor
      // observing. Without this the monitor would keep running while quietly
      // checking nothing, which is the failure this whole class exists to
      // refuse and looks identical from the outside.
      expect(monitor.getProviderHealth()['opencode']!.isDown, isTrue);
    });

    test(
      'one failed step does not stop the remaining providers being probed',
      () async {
        final logs = _Logs();
        final workflow = InMemoryWorkflowStore();
        final store = _FaultyWorkflowStore(
          workflow,
          faults: {'readHumanDecisionsForWorkItem', 'saveHumanDecision'},
        );
        final monitor = ProviderHealthMonitor(
          modelPolicyStore: InMemoryModelPolicyStore(),
          workflowStore: store,
          humanDecisionStore: WorkflowStoreHumanDecisionStore(store),
          probe: always(const ProviderProbeResult.unhealthy('probe exited 1')),
          failureThreshold: 1,
          log: logs.record,
        );

        await monitor.checkAll();

        // Every role is on `opencode`, so one provider — but the ticket write
        // is attempted once per ROLE inside `_checkAllProvidersDown`, and all
        // of those must have been reached and contained, not aborted by the
        // first one.
        final operations = logs
            .linesFor('provider_health.check.failed')
            .map((l) => l['operation'])
            .toSet();
        expect(
          operations,
          containsAll(<String>['provider_ticket', 'all_providers_down']),
          reason: 'a step that fails must not skip the steps after it',
        );
        expect(monitor.getProviderHealth()['opencode']!.isDown, isTrue);
      },
    );

    test('an unreadable policy set fails the CYCLE, not the process', () async {
      final logs = _Logs();
      final monitor = ProviderHealthMonitor(
        modelPolicyStore: _FaultyModelPolicyStore(
          InMemoryModelPolicyStore(),
          faults: {'getAllPolicies'},
        ),
        workflowStore: InMemoryWorkflowStore(),
        humanDecisionStore: WorkflowStoreHumanDecisionStore(
          InMemoryWorkflowStore(),
        ),
        probe: always(const ProviderProbeResult.healthy()),
        log: logs.record,
      );

      await expectLater(monitor.checkAll(), completes);

      final failed = logs.linesFor('provider_health.check.failed');
      expect(failed, hasLength(1));
      expect(failed.single['operation'], 'read_model_policies');
      // No verdict may be invented from a cycle that read nothing.
      expect(monitor.getProviderHealth(), isEmpty);
    });

    test('a probe that THROWS is unknown, never down', () async {
      // Direction matters more than containment here: mapping a thrown probe
      // to `unhealthy` would mark a provider down on the strength of the
      // OBSERVER failing, which is the one inference this class exists to
      // refuse.
      final logs = _Logs();
      final monitor = ProviderHealthMonitor(
        modelPolicyStore: InMemoryModelPolicyStore(),
        workflowStore: InMemoryWorkflowStore(),
        humanDecisionStore: WorkflowStoreHumanDecisionStore(
          InMemoryWorkflowStore(),
        ),
        probe: (_) async => throw StateError('probe blew up'),
        failureThreshold: 1,
        log: logs.record,
      );

      for (var i = 0; i < 3; i++) {
        await monitor.checkAll();
      }

      final health = monitor.getProviderHealth()['opencode']!;
      expect(health.verdict, ProviderProbeVerdict.unknown);
      expect(health.isDown, isFalse);
      expect(health.isUnknown, isTrue);
      // Three absent observations are not three failures.
      expect(health.consecutiveFailures, 0);
      expect(monitor.getAllProvidersDownTickets(), isEmpty);
      expect(
        logs.linesFor('provider_health.check.failed').first['operation'],
        'probe',
      );
    });

    test('start() does not let it escape: the crash itself', () async {
      // THE REGRESSION TEST. This is the production call path — `start()`,
      // its self-rearming `Timer.periodic`, and a write that fails — and it
      // asserts nothing directly. `package:test` fails a test on an unhandled
      // asynchronous error, so if this future ever escapes `checkAll` again
      // the isolate dies here instead of in QA and the suite goes red.
      final logs = _Logs();
      final store = _FaultyWorkflowStore(
        InMemoryWorkflowStore(),
        faults: {'saveHumanDecision'},
      );
      final wrote = Completer<void>();
      final monitor = ProviderHealthMonitor(
        modelPolicyStore: InMemoryModelPolicyStore(),
        workflowStore: store,
        humanDecisionStore: _SignallingDecisionStore(
          WorkflowStoreHumanDecisionStore(store),
          onWrite: () {
            if (!wrote.isCompleted) wrote.complete();
          },
        ),
        probe: always(const ProviderProbeResult.unhealthy('probe exited 1')),
        failureThreshold: 1,
        // Short enough that the test does not wait a production interval,
        // and the monitor is stopped below regardless.
        checkInterval: const Duration(milliseconds: 5),
        log: logs.record,
      );

      monitor.start();
      addTearDown(monitor.stop);

      // A cycle really ran, reached the write, and the write really failed.
      await wrote.future;
      // Give the error delivery the turns it needs. If it is unhandled, it
      // is reported to the zone during this window and fails the test.
      await _flushAsyncErrorDelivery();

      expect(
        logs
            .linesFor('provider_health.check.failed')
            .map((l) => l['operation']),
        isNotEmpty,
        reason:
            'the failure must be reported, not merely survived — the '
            'outage was invisible because nothing was logged',
      );
    });

    test(
      'a recovered monitor keeps working after the connection returns',
      () async {
        // Containment must not be a one-way door: the monitor has to resume
        // doing its job once the connection is back, or "graceful degradation"
        // is just a quieter outage.
        final logs = _Logs();
        final workflow = InMemoryWorkflowStore();
        final store = _FaultyWorkflowStore(
          workflow,
          faults: {'saveHumanDecision'},
        );
        final monitor = ProviderHealthMonitor(
          modelPolicyStore: InMemoryModelPolicyStore(),
          workflowStore: store,
          humanDecisionStore: WorkflowStoreHumanDecisionStore(store),
          probe: always(const ProviderProbeResult.unhealthy('probe exited 1')),
          failureThreshold: 1,
          log: logs.record,
        );

        await monitor.checkAll();
        expect(logs.linesFor('provider_health.check.failed'), isNotEmpty);

        store.faults.clear();
        await monitor.checkAll();

        expect(
          await _decisions(workflow),
          isNotEmpty,
          reason: 'with the connection restored the ticket must actually land',
        );
      },
    );
  });

  group('runOpencodeProviderProbe', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('provider_probe_test');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    /// A stub standing in for the `opencode` binary.
    String stub(String body) {
      final file = File('${temp.path}/opencode-stub');
      file.writeAsStringSync('#!/bin/sh\n$body\n');
      Process.runSync('chmod', ['+x', file.path]);
      return file.path;
    }

    /// Writes [bytes] DIRECTLY to the stub's own stdout.
    ///
    /// Directly, and not through a pipeline such as `yes a | head -c N`: a
    /// pipeline puts the writer in a separate process, so the SIGPIPE lands on
    /// `yes` and the stub still exits 0. `exec` is equally load-bearing — in a
    /// plain shell script the SIGPIPE kills `dd` and the script carries on to
    /// its own `exit 0`, so the probe would never observe the kill. Only
    /// `exec`, where the stub process IS the writer, reproduces what the real
    /// `opencode models` process is.
    String bulkStdout(int bytes) =>
        'exec dd if=/dev/zero bs=1024 count=${bytes ~/ 1024} 2>/dev/null';

    /// Writes [bytes] directly to the stub's own stderr.
    String bulkStderr(int bytes) =>
        'dd if=/dev/zero bs=1024 count=${bytes ~/ 1024} 1>&2 2>/dev/null\n'
        'exit 3';

    test(
      'reads no OPENCODE_* credential: a stub exiting 0 is healthy',
      () async {
        // No `OPENCODE_<PROVIDER>_API_KEY` anywhere: the variable the old probe
        // gated on. The QA container exports none, and that is what made every
        // probe for the `opencode` provider report an outage.
        expect(
          Platform.environment.keys.where(
            (k) => k.startsWith('OPENCODE_') && k.endsWith('_API_KEY'),
          ),
          isEmpty,
        );

        final result = await runOpencodeProviderProbe(
          'opencode',
          executable: stub('exit 0'),
        );

        expect(result.isHealthy, isTrue, reason: result.reason);
      },
    );

    test(
      'inherits the parent environment, exactly like the dispatch path',
      () async {
        // `OpenCodeProcessTransport._spawn` spawns with
        // `includeParentEnvironment: true`; the probe must inherit the same
        // environment, or it tests a different thing than the runtime uses.
        // `PATH` is the consequential inheritance for a probe at all — without
        // it, neither the probe nor `opencode acp` can be found.
        expect(Platform.environment['PATH'], isNotNull);
        final result = await runOpencodeProviderProbe(
          'opencode',
          executable: stub(
            r'test -n "$PATH" || exit 9'
            '\nexit 0',
          ),
        );
        expect(result.isHealthy, isTrue, reason: result.reason);
      },
    );

    test(
      'a stub exiting non-zero is unhealthy and names the exit code',
      () async {
        final result = await runOpencodeProviderProbe(
          'opencode',
          executable: stub('echo "401 unauthorized" >&2\nexit 3'),
        );

        expect(result.isUnhealthy, isTrue);
        expect(result.reason, contains('exited 3'));
        expect(result.reason, contains('401 unauthorized'));
      },
    );

    test('a missing executable is unknown, not unhealthy', () async {
      final result = await runOpencodeProviderProbe(
        'opencode',
        executable: '${temp.path}/definitely-not-installed',
      );

      expect(
        result.isUnknown,
        isTrue,
        reason: 'an absent binary is an absent observation',
      );
      expect(result.isUnhealthy, isFalse);
    });

    test(
      'a probe that hangs is unhealthy: it ran and did not finish',
      () async {
        final result = await runOpencodeProviderProbe(
          'opencode',
          executable: stub('sleep 30'),
          timeout: const Duration(milliseconds: 300),
        );

        expect(result.isUnhealthy, isTrue);
        expect(result.reason, contains('did not finish'));
      },
    );

    test(
      'a child that writes far more than a pipe buffer is still healthy',
      () async {
        // 64 KiB is the classic pipe capacity. A probe that stops reading once
        // it has retained enough closes the READ end of the pipe; the child is
        // SIGPIPEd and exits non-zero, and a perfectly healthy provider is
        // reported as an outage. Two consecutive such probes mark every role
        // all-providers-down and halt dispatch platform-wide — the exact
        // failure this change exists to eliminate, reintroduced inside the
        // probe. Real `opencode models` output is only ~328 B today, but it
        // scales with the configured providers and models.
        for (final bytes in const [1000, 200 * 1024, 1024 * 1024]) {
          final result = await runOpencodeProviderProbe(
            'opencode',
            executable: stub(bulkStdout(bytes)),
            timeout: const Duration(seconds: 30),
          );

          expect(
            result.isHealthy,
            isTrue,
            reason: '$bytes bytes of stdout: ${result.reason}',
          );
        }
      },
    );

    test(
      'the retained output stays bounded however much the child writes',
      () async {
        const written = 1024 * 1024;
        final result = await runOpencodeProviderProbe(
          'opencode',
          executable: stub(bulkStderr(written)),
          timeout: const Duration(seconds: 30),
        );

        // The verdict is still a genuine failure — the child did exit 3.
        expect(result.isUnhealthy, isTrue);
        expect(result.reason, contains('exited 3'));
        // And the reason carries a BOUNDED excerpt of 1 MiB of stderr, not the
        // whole megabyte. A test that only asserted the verdict would pass
        // against an unbounded buffer, which is its own memory hazard.
        expect(result.reason, contains('truncated'));
        expect(
          result.reason.length,
          lessThan(probeOutputTailLimit + 120),
          reason: '1 MiB written, ${result.reason.length} chars retained',
        );
      },
    );
  });
}

/// Every human decision the monitor wrote, in creation order.
Future<List<HumanDecision>> _decisions(WorkflowStore store) async {
  final all = await store.readHumanDecisionsForWorkItem(
    'system:provider-health',
  );
  return all..sort((a, b) => a.decisionId.compareTo(b.decisionId));
}

/// Opens a loopback socket, closes its sink LOCALLY, and returns the ACTUAL
/// error the next write throws.
///
/// This is the crash, reproduced by the same `dart:io` code path the stack
/// trace names: `_Socket.add` → `_StreamSinkImpl.add` (`dart:io/io_sink.dart`).
/// A locally-closed sink is the only thing that produces this error — a peer
/// that merely went away fails later, in the kernel, with a different error —
/// so closing the socket here is what makes the reproduction faithful rather
/// than approximate.
///
/// No docker, no compose, no psql, no database: loopback only, and the socket
/// is closed by this function on every path.
Future<Object> realClosedSinkError() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((_) {});
  try {
    final client = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    // Closed early, and not awaited on the peer: the reproduction needs the
    // client sink to be closed, and nothing else.
    await server.close();

    // One byte out and back, so the write path is genuinely live before it is
    // closed. A sink that was never written to has not exercised `add`.
    client.add(const [0]);
    await client.flush();

    client.close();
    await client.done;

    try {
      client.add(const [0]);
    } on Object catch (error) {
      return error;
    }
    throw StateError(
      'the closed socket accepted a write, so this reproduction no longer '
      'exercises the failure it exists to produce',
    );
  } finally {
    // Idempotent: already closed on the normal path, and closing an
    // already-closed listener is what keeps the failure path from leaking it.
    await server.close();
  }
}

/// The error a closed socket throws, CONSTRUCTED rather than observed.
///
/// [realClosedSinkError] proves this is byte-identical — same runtime type,
/// same `toString()` — to what `dart:io` throws from `_StreamSinkImpl.add`, so
/// the fakes below cannot quietly drift into testing a different failure than
/// the one that killed the process.
///
/// The message is `'StreamSink is closed'` and NOT
/// `'Bad state: StreamSink is closed'`: `StateError.toString()` supplies the
/// `Bad state: ` prefix itself, so supplying it here would double it and the
/// fixture would no longer match the log line an operator reads.
StateError closedSinkError() => StateError('StreamSink is closed');

/// Yields enough event-loop turns for an unhandled asynchronous error to be
/// delivered to the zone.
///
/// Deliberately event-loop (`Future.delayed`) rather than microtask turns: an
/// uncaught error is reported through the event queue, so a microtask-only
/// flush would let a regression pass.
Future<void> _flushAsyncErrorDelivery({int turns = 20}) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A [ModelPolicyStore] that fails the named operations the way Postgres fails
/// when its connection has closed, and delegates everything else.
///
/// Failures are INJECTED rather than raised by a real server because the
/// assertion is about containment at this boundary; [realClosedSinkError]
/// separately proves the injected error is the genuine `dart:io` one.
class _FaultyModelPolicyStore implements ModelPolicyStore {
  _FaultyModelPolicyStore(this._inner, {required this.faults});

  final ModelPolicyStore _inner;

  /// Operation names that fail instead of reaching [_inner].
  final Set<String> faults;

  Future<T> _guard<T>(String operation, Future<T> Function() body) async {
    if (faults.contains(operation)) {
      throw closedSinkError();
    }
    return body();
  }

  @override
  Future<ModelPolicy?> getPolicy(AgentRole role) =>
      _guard('getPolicy', () => _inner.getPolicy(role));

  @override
  Future<void> upsertPolicy(ModelPolicy policy) =>
      _guard('upsertPolicy', () => _inner.upsertPolicy(policy));

  @override
  Future<List<ModelPolicy>> getAllPolicies() =>
      _guard('getAllPolicies', _inner.getAllPolicies);
}

/// A [WorkflowStore] that fails the named operations and delegates the rest.
class _FaultyWorkflowStore implements WorkflowStore {
  _FaultyWorkflowStore(this._inner, {required this.faults});

  final WorkflowStore _inner;

  /// Mutable on purpose: the "connection came back" test clears it in place.
  final Set<String> faults;

  Future<T> _guard<T>(String operation, Future<T> Function() body) async {
    if (faults.contains(operation)) {
      throw closedSinkError();
    }
    return body();
  }

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _guard(
    'readHumanDecisionsForWorkItem',
    () => _inner.readHumanDecisionsForWorkItem(workItemId),
  );

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _guard('saveHumanDecision', () => _inner.saveHumanDecision(decision));

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _guard('readWorkItem', () => _inner.readWorkItem(workItemId));

  @override
  Future<List<WorkItem>> readAllWorkItems() =>
      _guard('readAllWorkItems', _inner.readAllWorkItems);

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) => _guard(
    'saveWorkItem',
    () => _inner.saveWorkItem(item, expectedVersion: expectedVersion),
  );

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _guard('readHumanDecision', () => _inner.readHumanDecision(decisionId));

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _guard(
    'readTransitionHistory',
    () => _inner.readTransitionHistory(workItemId),
  );

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _guard(
    'findTransitionByIdempotencyKey',
    () => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey),
  );

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _guard(
        'appendTransitionRecord',
        () => _inner.appendTransitionRecord(record),
      );

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) =>
      _guard('appendOperatorAction', () => _inner.appendOperatorAction(record));

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) => _guard(
    'readOperatorActionsForWorkItem',
    () => _inner.readOperatorActionsForWorkItem(workItemId),
  );

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      _guard('inTransaction', () => _inner.inTransaction<T>(body));
}

/// Reports the moment a human-decision WRITE is attempted, then delegates.
///
/// The write is what the production crash died on, so the regression test waits
/// for the attempt rather than for a timer — the test cannot pass or fail
/// without the code path having actually run.
class _SignallingDecisionStore implements HumanDecisionStore {
  const _SignallingDecisionStore(this._inner, {required this.onWrite});

  final HumanDecisionStore _inner;
  final void Function() onWrite;

  @override
  Future<void> saveHumanDecision(HumanDecision decision) {
    onWrite();
    return _inner.saveHumanDecision(decision);
  }
}

/// Captures the operator log so a test can assert that a state change was
/// actually reported rather than merely recorded.
class _Logs {
  final List<String> events = [];
  final List<Map<String, dynamic>> lines = [];

  void record(String event, Map<String, dynamic> data) {
    events.add(event);
    lines.add({'event': event, ...data});
  }

  List<Map<String, dynamic>> linesFor(String event) =>
      lines.where((l) => l['event'] == event).toList();
}

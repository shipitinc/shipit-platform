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
  });
}

/// Every human decision the monitor wrote, in creation order.
Future<List<HumanDecision>> _decisions(WorkflowStore store) async {
  final all = await store.readHumanDecisionsForWorkItem(
    'system:provider-health',
  );
  return all..sort((a, b) => a.decisionId.compareTo(b.decisionId));
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

import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:scheduler/src/health/provider_health_monitor.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

import '../support/controlled_dispatcher.dart';
import '../support/file_host.dart';
import 'health_store.dart';

/// The monitor against the thing it actually gates: dispatch.
///
/// `scheduler.dart:583-589` skips every job whose role reads as
/// all-providers-down, with a bare `continue` — no deferral, no event, no
/// count. That is the path that left a retried defect `queued` with
/// `dispatched: 0` on every tick for as long as the bug was live. These tests
/// drive a real [Scheduler] over real stores, with the production triage job
/// definition and enqueue path, so what is asserted is the verdict's effect on
/// dispatch and not the monitor's opinion of its own verdict.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('provider_health_dispatch_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// A scheduler whose dispatch is gated by [monitor], over stores that persist
  /// for the duration of the test.
  ({
    Scheduler scheduler,
    ProviderHealthMonitor monitor,
    FileRestartHarness harness,
    ControlledDispatcher dispatch,
    List<String> events,
  })
  build({required ProviderProbe probe, int failureThreshold = 2}) {
    final events = <String>[];
    final harness = FileRestartHarness(dir, clock: () => t0);
    final dispatch = ControlledDispatcher(
      capabilities: const {WorkerCapability.linux, WorkerCapability.git},
    );
    final monitor = ProviderHealthMonitor(
      modelPolicyStore: InMemoryModelPolicyStore(),
      workflowStore: harness.workflowStore,
      humanDecisionStore: WorkflowStoreHumanDecisionStore(
        harness.workflowStore,
      ),
      probe: probe,
      failureThreshold: failureThreshold,
      log: (event, data) => events.add('$event $data'),
    );
    final scheduler = Scheduler(
      schedulerId: 'sched-1',
      workflowStore: harness.workflowStore,
      jobStore: harness.jobStore,
      workerStore: harness.workerStore,
      dispatch: dispatch,
      definition: triageDefectDefinition,
      workload: SchedulerWorkload(
        repositoryPath: '${dir.path}/repo',
        startingRevision: 'deadbeef',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake-runtime',
      ),
      clock: () => t0,
      modelSelection: ModelSelectionService(InMemoryModelPolicyStore()),
      dedupeKeyBuilder: triageDefectDedupeKey,
      instructionBuilder: triageDefectInstruction,
      providerHealthMonitor: monitor,
    );
    return (
      scheduler: scheduler,
      monitor: monitor,
      harness: harness,
      dispatch: dispatch,
      events: events,
    );
  }

  /// A runnable defect item — the shape whose job sat queued in QA behind
  /// `hd-all-down-TRIAGE_DEFECT-*`.
  Future<void> defect(FileRestartHarness harness, String workItemId) =>
      harness.itemRunnable(workItemId: workItemId);

  Future<Job> jobOf(FileRestartHarness harness, String workItemId) async =>
      (await harness.jobStore.listJobsForWorkItem(workItemId)).single;

  test(
    'with no credential env var the provider is probed, found healthy, and the '
    'triage job dispatches',
    () async {
      // No `OPENCODE_<PROVIDER>_API_KEY` anywhere: the variable the old probe
      // gated on, and the reason every probe reported an outage.
      expect(
        Platform.environment.keys.where(
          (k) => k.startsWith('OPENCODE_') && k.endsWith('_API_KEY'),
        ),
        isEmpty,
      );

      final h = build(probe: (_) async => const ProviderProbeResult.healthy());
      await defect(h.harness, 'wi-defect-1');

      await h.monitor.checkAll();
      final tick = await h.scheduler.tick();

      final job = await jobOf(h.harness, 'wi-defect-1');
      expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isFalse);
      expect(tick.dispatched, contains(job.jobId));
      expect(h.dispatch.runs, hasLength(1));
      expect(
        (await h.harness.jobStore.readJob(job.jobId))!.state,
        JobState.succeeded,
      );
    },
  );

  test('a genuinely failing provider holds a queued triage job, and recovery '
      'releases it without a human acknowledging anything', () async {
    var healthy = true;
    final h = build(
      probe: (_) async => healthy
          ? const ProviderProbeResult.healthy()
          : const ProviderProbeResult.unhealthy('probe exited 1: 401'),
    );

    // Healthy: the first defect classifies.
    await defect(h.harness, 'wi-defect-1');
    await h.monitor.checkAll();
    final healthyTick = await h.scheduler.tick();
    final first = await jobOf(h.harness, 'wi-defect-1');
    expect(
      healthyTick.dispatched,
      contains(first.jobId),
      reason: 'a healthy provider dispatches',
    );

    // The provider goes down for real. One failing probe is a blip.
    healthy = false;
    await defect(h.harness, 'wi-defect-2');
    await h.monitor.checkAll();
    final blipTick = await h.scheduler.tick();
    expect(
      blipTick.dispatched,
      contains((await jobOf(h.harness, 'wi-defect-2')).jobId),
      reason: 'a single failing probe must not halt dispatch',
    );

    // The threshold is crossed: TRIAGE_DEFECT is all-providers-down, and a
    // third defect arrives.
    await h.monitor.checkAll();
    expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isTrue);
    await defect(h.harness, 'wi-defect-3');

    final blocked = await h.scheduler.tick();
    final stranded = await jobOf(h.harness, 'wi-defect-3');
    expect(blocked.dispatched, isEmpty);
    expect(
      (await h.harness.jobStore.readJob(stranded.jobId))!.state,
      JobState.queued,
      reason: 'held in the queue, never dispatched',
    );

    // Recovery. No ticket is acknowledged and no decision is resolved by a
    // human: a probe succeeding is the whole release condition.
    healthy = true;
    await h.monitor.checkAll();
    expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isFalse);

    final released = await h.scheduler.tick();
    expect(released.dispatched, contains(stranded.jobId));
    expect(
      (await h.harness.jobStore.readJob(stranded.jobId))!.state,
      JobState.succeeded,
    );

    expect(
      h.events.where((e) => e.startsWith('provider_health.all_providers_down')),
      isNotEmpty,
      reason: 'the role going dark was reported',
    );
    expect(
      h.events.where(
        (e) => e.startsWith('provider_health.all_providers_recovered'),
      ),
      isNotEmpty,
      reason: 'the role coming back was reported',
    );
  });

  test('a probe that cannot run never blocks dispatch', () async {
    final h = build(
      probe: (_) async =>
          const ProviderProbeResult.unknown('probe could not start'),
    );
    await defect(h.harness, 'wi-defect-1');

    for (var i = 0; i < 5; i++) {
      await h.monitor.checkAll();
    }
    final tick = await h.scheduler.tick();

    expect(h.monitor.hasAllProvidersDown(AgentRole.triageDefect), isFalse);
    expect(
      tick.dispatched,
      contains((await jobOf(h.harness, 'wi-defect-1')).jobId),
    );
    expect(
      h.events.where((e) => e.startsWith('provider_health.all_providers_down')),
      isEmpty,
    );
  });
}

final t0 = DateTime.utc(2026, 1, 1, 12);

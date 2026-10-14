import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:control_plane_server/server.dart';

/// ## WHY THIS FILE IS IN `apps/server` AND NOT IN `packages/scheduler`
///
/// "Did this run produce something reviewable?" is now ONE function,
/// `producedCommitFor`, called by both lanes — that is what
/// `engineeringReviewWorkloadResolver` does, and the duplication a reviewer
/// flagged as unacceptable is gone rather than asserted against. Sharing could
/// not invert a dependency: `apps/server` already depends on
/// `packages/scheduler`, so the call runs in the direction that already exists.
///
/// What sharing did NOT remove is the MAPPING from that verdict to each lane's
/// action:
///
///  * `completionRouteFor` — commit ⇒ `reviewInProgress`, refusal ⇒
///    `implementationReady`. It lives in `packages/scheduler`.
///  * `engineeringReviewWorkloadResolver` — commit ⇒ a workload, refusal ⇒
///    `null`. It lives in `apps/server`.
///
/// No single function can assert those two are complementary, because they are
/// in different packages. So this file CALLS both, over the same durable rows,
/// and fails if there is any input on which both lanes would act. This is the
/// executing test the scheduler package could not host: before the sharing, the
/// scheduler-side "divergence" test re-spelled `completionRouteFor`'s own switch
/// and derived the review side from the verdict under test, so it could not
/// detect divergence from the real resolver at all.
///
/// It also pins the resolver's delegation, which is the property the sharing
/// exists to guarantee. A future edit that re-inlines the rule into
/// `engineering_review_gate.dart` would pass every behavioural test here and
/// silently restore the duplication, so the delegation is asserted directly.
const _startRevision = 'start-rev';

WorkItem _item({String? producerActorId, String workItemId = 'wi-1'}) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 't',
    state: WorkItemState.agentCompleted,
    metadata: producerActorId == null
        ? null
        : {'producerActorId': producerActorId},
    createdAt: now,
    updatedAt: now,
  );
}

Job _job(String workItemId) => Job(
  jobId: 'job-$workItemId',
  workItemId: workItemId,
  jobType: JobType.engineeringReview,
  requiredRole: AgentRole.engineeringReviewer,
  requiredCapabilities: const {WorkerCapability.engineeringReview},
  priority: JobPriority.normal,
  state: JobState.queued,
  dedupeKey: 'dedupe',
  createdAt: DateTime.utc(2026, 1, 1),
  instruction: 'review',
  attempt: 0,
  maxAttempts: 3,
  version: 1,
);

WorkerExecution _exec({
  required String id,
  required String workItemId,
  String startingRevision = _startRevision,
  String? endingRevision,
  Set<WorkerCapability> capabilities = const {
    WorkerCapability.linux,
    WorkerCapability.git,
  },
  String repositoryPath = '/impl/repo',
  String? agentExecutionId,
}) => WorkerExecution(
  workerExecutionId: id,
  workItemId: workItemId,
  repositoryPath: repositoryPath,
  requestedStartingRevision: startingRevision,
  requiredCapabilities: capabilities,
  status: WorkerExecutionStatus.executedPass,
  cleanupPolicy: WorkerCleanupPolicy.removeAlways,
  endingRevision: endingRevision,
  agentExecutionId: agentExecutionId,
);

WorkloadResolver _resolver(WorkerStore store) =>
    engineeringReviewWorkloadResolver(
      workerStore: store,
      runtimeTypeId: 'rt-review',
      // The one production budget, named so the resolver holds no literal of
      // its own. See `AgentExecutionBudgets` — PROVISIONAL.
      timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
    );

/// One durable input, described once and fed to both lanes.
typedef _Input = ({
  String label,
  WorkItem item,
  List<WorkerExecution> executions,
});

Future<List<_Input>> _inputs() async {
  return <_Input>[
    (
      label: 'no anchor at all',
      item: _item(),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: 'a-commit',
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'the anchor is the empty string',
      item: _item(producerActorId: ''),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: 'a-commit',
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'no execution carries the anchor',
      item: _item(producerActorId: 'agx-unknown'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: 'a-commit',
          agentExecutionId: 'agx-other',
        ),
      ],
    ),
    (
      label: 'the only matching execution is another item\'s',
      item: _item(producerActorId: 'agx-1'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-other',
          endingRevision: 'a-commit',
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'two executions carry the anchor',
      item: _item(producerActorId: 'agx-1'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: 'a-commit',
          agentExecutionId: 'agx-1',
        ),
        _exec(
          id: 'wx-2',
          workItemId: 'wi-1',
          endingRevision: 'b-commit',
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'the anchored execution is a reviewer',
      item: _item(producerActorId: 'agx-1'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: 'a-commit',
          capabilities: const {WorkerCapability.engineeringReview},
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'the producer ran and ended where it started',
      item: _item(producerActorId: 'agx-1'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: _startRevision,
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'the producer ran and recorded no ending revision',
      item: _item(producerActorId: 'agx-1'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: null,
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'THE TRIAGE SHAPE — a report, not an artifact',
      item: _item(producerActorId: 'agx-1'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          startingRevision: 'triage-start',
          endingRevision: null,
          repositoryPath: '/triage-repo',
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
    (
      label: 'the producer committed — review owns it',
      item: _item(producerActorId: 'agx-1'),
      executions: [
        _exec(
          id: 'wx-1',
          workItemId: 'wi-1',
          endingRevision: 'a-real-commit',
          agentExecutionId: 'agx-1',
        ),
      ],
    ),
  ];
}

void main() {
  group('the two lane mappings are complementary on every durable input', () {
    test('no input makes both lanes act', () async {
      for (final input in await _inputs()) {
        final store = InMemoryWorkerStore();
        for (final execution in input.executions) {
          await store.saveWorkerExecution(execution);
        }

        // The REAL resolver, called through the composition's own signature.
        final workload = await _resolver(store)(
          _job(input.item.workItemId),
          input.item,
        );
        // The REAL scheduler discriminator, and the REAL scheduler mapping.
        final verdict = await producedCommitFor(store, input.item);
        final inflowRoute = completionRouteFor(verdict);

        final reviewActs = workload != null;
        final inflowRoutes = inflowRoute == WorkItemState.implementationReady;

        expect(
          reviewActs && inflowRoutes,
          isFalse,
          reason:
              'input "${input.label}": review dispatched AND the inflow routed. '
              'That is the one shape on which the two lanes contend for a '
              'single work item in a single tick — and which of them wins '
              'would be decided by the order of two `await`s. '
              'workload=$workload verdict=$verdict route=$inflowRoute',
        );

        // And the halves are not vacuous: across the whole table both lanes
        // must actually act somewhere, or "complementary" would also be
        // satisfied by two functions that both do nothing.
        expect(
          reviewActs,
          equals(input.label == 'the producer committed — review owns it'),
          reason: 'input "${input.label}"',
        );
        expect(
          inflowRoutes,
          isNot(input.label == 'the producer committed — review owns it'),
          reason: 'input "${input.label}"',
        );
      }
    });

    test('the resolver DELEGATES; it does not re-state the rule', () async {
      // Behavioural tests cannot see a re-inlined rule: a copy of
      // `producedCommitFor` inside the gate would pass every assertion above.
      // The sharing IS the property, so it is asserted directly.
      //
      // Read as text because the alternative is a behavioural test that is
      // indistinguishable from the duplicated implementation it is meant to
      // catch — the same reasoning `implementation_composition_wiring_test.dart`
      // in `packages/scheduler` uses for this file.
      final resolver = _resolverSource();
      expect(
        resolver,
        contains('await producedCommitFor(workerStore, item);'),
        reason:
            'the review resolver must CALL the scheduler\'s discriminator. A '
            'second copy of the rule is how a real commit reaches the build '
            'queue while a reviewer is sent to a revision nobody committed.',
      );
      expect(
        resolver,
        isNot(contains("item.metadata?['producerActorId']")),
        reason:
            'reading the anchor inside the resolver means the rule has been '
            're-stated there. The anchor belongs to the discriminator, not to '
            'the mapping — and the tick handler reading it for its own '
            'actorIsNotSelf() argument is a different thing entirely.',
      );
      expect(
        resolver,
        isNot(contains('listWorkerExecutions')),
        reason:
            'the candidate loop lives in the discriminator now. Re-adding it '
            'here is the duplication this assertion exists to prevent.',
      );
    });
  });
}

/// The gate source, located relative to this package so the test does not
/// depend on the working directory `dart test` happens to run from.
String _gateSource() {
  for (final candidate in const [
    'lib/src/review/engineering_review_gate.dart',
    '../lib/src/review/engineering_review_gate.dart',
  ]) {
    final file = File(candidate);
    if (file.existsSync()) return file.readAsStringSync();
  }
  fail(
    'could not locate lib/src/review/engineering_review_gate.dart from '
    '${Directory.current.path}',
  );
}

/// The BODY of `engineeringReviewWorkloadResolver` only.
///
/// Scoped deliberately: the gate's other functions legitimately read
/// `producerActorId` (the park path needs it for `actorIsNotSelf()`), and a
/// whole-file grep would fail on correct code.
String _resolverSource() {
  final source = _gateSource();
  const declaration = 'WorkloadResolver engineeringReviewWorkloadResolver(';
  final start = source.indexOf(declaration);
  if (start < 0) {
    fail('engineeringReviewWorkloadResolver is not declared in the gate');
  }
  final end = source.indexOf('\n}\n', start);
  if (end < 0) fail('engineeringReviewWorkloadResolver does not close');
  return source.substring(start, end);
}

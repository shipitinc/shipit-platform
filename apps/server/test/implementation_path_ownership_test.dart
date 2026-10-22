import 'package:control_plane_server/src/implementation/implementation_path_ownership.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart' show SchedulerWorkload;
import 'package:test/test.dart';

/// THE GRANT REACHES THE DISPATCH REQUEST.
///
/// ## WHAT THIS FILE MEASURES
///
/// The dispatch-time boundary for the implementation lane: the last place
/// where the work item (which carries the grant) and the worker request (which
/// carries it to the worker) are both in hand.
///
/// The grant is authored on the WORK ITEM, before the work is known. It has to
/// arrive at the worker in the request, because the request is what the
/// worker writes into the durable execution record — and that record is what
/// the QA gate later reads to know what the lane was GRANTED.
///
/// ## WHY AN EMPTY GRANT IS NOT AN ERROR HERE
///
/// A work item with no grant produces a request with no grant, and the gate
/// that judges it refuses an empty owned set. That is the fail-closed
/// direction, and it is reached by doing nothing — not by inventing a set
/// here, which would be the platform granting itself permission.
void main() {
  Job job() => Job(
    jobId: 'job-1',
    workItemId: 'wi-1',
    jobType: JobType.implementFeature,
    requiredRole: AgentRole.implementer,
    requiredCapabilities: {WorkerCapability.linux},
    priority: JobPriority.normal,
    state: JobState.queued,
    dedupeKey: 'dedupe-1',
    createdAt: _at(),
    instruction: 'implement the thing',
    attempt: 1,
    maxAttempts: 3,
    version: 1,
  );

  SchedulerWorkload workload() => const SchedulerWorkload(
    repositoryPath: '/repo',
    startingRevision: 'abc123',
    timeoutSeconds: 900,
    runtimeTypeId: 'opencode',
  );

  WorkItem item({List<String>? declaredOwnedPaths}) => WorkItem(
    workItemId: 'wi-1',
    productId: 'shipit-platform',
    category: WorkItemCategory.feature,
    title: 'A lane with a grant',
    state: WorkItemState.agentExecuting,
    createdAt: _at(),
    updatedAt: _at(),
    metadata: declaredOwnedPaths == null
        ? null
        : declaredOwnedPathsMetadata(declaredOwnedPaths),
  );

  group('the grant is carried onto the request', () {
    test(
      'a work item with a grant produces a request with that grant',
      () async {
        final request = await implementationRequestWithPathOwnership(
          job(),
          workload(),
          item(
            declaredOwnedPaths: const [
              'apps/server/**',
              'packages/qa_orchestration/**',
            ],
          ),
          null,
        );

        expect(request.declaredOwnedPaths, [
          'apps/server/**',
          'packages/qa_orchestration/**',
        ]);
      },
    );

    test(
      'a work item with NO grant produces a request with no grant',
      () async {
        final request = await implementationRequestWithPathOwnership(
          job(),
          workload(),
          item(),
          null,
        );

        expect(
          request.declaredOwnedPaths,
          isEmpty,
          reason:
              'the platform does not invent a grant: an ungranted lane stays '
              'ungranted, and the gate refuses it',
        );
      },
    );

    test('an EMPTY grant produces a request with no grant', () async {
      final request = await implementationRequestWithPathOwnership(
        job(),
        workload(),
        item(declaredOwnedPaths: const []),
        null,
      );

      expect(request.declaredOwnedPaths, isEmpty);
    });
  });

  group('the rest of the request is the scheduler\'s, unchanged', () {
    test('the wrapper adds one field and drops none', () async {
      final request = await implementationRequestWithPathOwnership(
        job(),
        workload(),
        item(declaredOwnedPaths: const ['apps/server/**']),
        null,
      );

      expect(request.workerExecutionId, 'wx-job-1');
      expect(request.workItemId, 'wi-1');
      expect(request.repositoryPath, '/repo');
      expect(request.startingRevision, 'abc123');
      expect(request.requiredCapabilities, {WorkerCapability.linux});
      expect(request.role, AgentRole.implementer);
      expect(request.instruction, 'implement the thing');
      expect(request.timeoutSeconds, 900);
      expect(request.runtimeTypeId, 'opencode');
    });
  });
}

DateTime _at() => DateTime.utc(2026, 10, 21);
